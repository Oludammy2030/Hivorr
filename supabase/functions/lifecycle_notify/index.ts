// lifecycle_notify (EP-03-18, cron + on-demand, service-role drain).
//
// Drains notification_outbox (durable, exactly-once intents written by
// DEFINER triggers + notification_enqueue RPC) into notification_events
// (the EP-01-18 Realtime push channel filtered by entity_id).
//
// INVOCATION (service-role only — never an end-user JWT):
//   POST /functions/v1/lifecycle_notify
//   Authorization: Bearer <SERVICE_ROLE_KEY>
//   Body: { "limit": 50 }
//
// FLOW per row (leased with FOR UPDATE SKIP LOCKED via
// notification_claim_batch, bounded to 100):
//   1. INSERT into notification_events (service_role grant).
//   2. notification_ack(id, true) on success; notification_ack(id, false)
//      on failure (backoff 30s * attempts, failed after 5).
//
// IDEMPOTENCY: outbox dedup_key UNIQUE prevents duplicate intents;
// notification_events rows are append-only facts. Re-running over a
// sent row is a no-op (claim only selects pending).
//
// PII: titles/bodies arrive pre-redacted (***last4, no emails/phones/
// amounts/message bodies/review text). This function never decrypts
// body_encrypted and never invents recipients.
//
// ENV (secret store only, never hardcoded):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// RESPONSE: { success, code: 'PLT000'|'PLT999', message, data }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

type OutboxRow = {
  id: string;
  dedup_key: string;
  recipient_entity_id: string;
  event_type: string;
  title: string;
  body: string;
  channel_id: string;
  priority: string;
  action_route: string | null;
  payload: Record<string, unknown>;
  attempts: number;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (SUPABASE_URL === '' || SERVICE_ROLE_KEY === '') {
    return json({ success: false, code: 'PLT999', message: 'Notify service is not configured.' }, 500);
  }
  if (req.method !== 'POST') {
    return json({ success: false, code: 'PLT003', message: 'POST with a JSON body is required.' }, 405);
  }

  let limit = 50;
  try {
    const body = (await req.json()) as { limit?: number };
    if (typeof body.limit === 'number' && body.limit >= 1 && body.limit <= 100) {
      limit = Math.floor(body.limit);
    }
  } catch {
    // Empty/invalid body -> default drain window.
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const { data: claim, error: claimError } = await supabase.rpc(
    'notification_claim_batch',
    { p_limit: limit },
  );
  if (claimError) {
    return json({ success: false, code: 'PLT999', message: 'Claim batch failed.' }, 500);
  }
  const envelope = (claim ?? {}) as { success?: boolean; data?: { items?: OutboxRow[] } };
  const items: OutboxRow[] = envelope.data?.items ?? [];

  let delivered = 0;
  const failed: Array<{ id: string; reason: string }> = [];

  for (const row of items) {
    const { error: insertError } = await supabase
      .from('notification_events')
      .insert({
        entity_id: row.recipient_entity_id,
        title: row.title,
        body: row.body,
        channel_id: row.channel_id,
        priority: row.priority,
        action_route: row.action_route,
        payload: { ...(row.payload ?? {}), dedup_key: row.dedup_key, event: row.event_type },
      });
    if (insertError) {
      await supabase.rpc('notification_ack', { p_id: row.id, p_ok: false });
      failed.push({ id: row.id, reason: 'insert-failed' });
      continue;
    }
    await supabase.rpc('notification_ack', { p_id: row.id, p_ok: true });
    delivered += 1;
  }

  return json({
    success: true,
    code: 'PLT000',
    message: 'Lifecycle drain completed.',
    data: { claimed: items.length, delivered, failed },
  });
});
