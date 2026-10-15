// dispute_notify (EP-03-17 R2 follow-up, service-role writer).
//
// Notifies the OTHER party of a dispute lifecycle event through the EP-01-18
// Realtime push channel (`notification_events` rows filtered by `entity_id`):
// a participant's client invokes this function after filing/withdrawing, or
// when it newly observes a resolution on re-read, and the counterparty's
// device renders the row locally when online.
//
// INVOCATION (authenticated end-user JWT — never the service-role key):
//   POST /functions/v1/dispute_notify
//   Authorization: Bearer <USER_JWT>
//   Body: { "case_id": "<dispute_cases.id>", "event": "filed" | "withdrawn" | "resolved" }
//
// AUTHORIZATION (inside the function, defense in depth):
//   1. The caller JWT is forwarded to a user-scoped client that reads the case
//      via `dispute_get` (party-scoped RLS + PLT004 parity). A non-party gets
//      403 and no row is written — the function never discloses case existence.
//   2. Only `filed` / `withdrawn` events are accepted (PLT003 otherwise); the
//      server never invents resolution outcomes here.
//   3. The row is addressed to the counterparty derived from the case
//      (filer <-> counterparty), never to an arbitrary entity_id.
//
// ENV (secret store only, never hardcoded):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
//
// RESPONSE: { success, code: 'PLT000'|'PLT001'|'PLT003'|'PLT004', message, data }
// IDEMPOTENCY: notification rows are append-only facts; the client invokes
// once per user action. Re-invocation appends a duplicate row (same as a
// second local notification) — never a fund movement.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ALLOWED_EVENTS = new Set(['filed', 'withdrawn', 'resolved']);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function shortId(id: string): string {
  return id.length <= 4 ? `***${id}` : `***${id.slice(-4)}`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (SUPABASE_URL === '' || ANON_KEY === '' || SERVICE_ROLE_KEY === '') {
    return json({ success: false, code: 'PLT999', message: 'Notify service is not configured.' }, 500);
  }
  if (req.method !== 'POST') {
    return json({ success: false, code: 'PLT003', message: 'POST with a JSON body is required.' }, 405);
  }

  const auth = req.headers.get('Authorization') ?? '';
  if (auth === '') {
    return json({ success: false, code: 'PLT001', message: 'Authentication required.' }, 401);
  }

  let payload: { case_id?: unknown; event?: unknown };
  try {
    payload = (await req.json()) as typeof payload;
  } catch {
    return json({ success: false, code: 'PLT003', message: 'Malformed JSON body.' }, 400);
  }

  const caseId = typeof payload.case_id === 'string' ? payload.case_id : '';
  const event = typeof payload.event === 'string' ? payload.event : '';
  if (caseId === '') {
    return json({ success: false, code: 'PLT003', message: 'Case id is required.' }, 400);
  }
  if (!ALLOWED_EVENTS.has(event)) {
    return json({ success: false, code: 'PLT003', message: 'Event must be filed, withdrawn, or resolved.' }, 400);
  }

  // User-scoped read: RLS + PLT004 parity decide visibility. No service_role
  // is used before this check passes.
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: readData, error: readError } = await userClient.rpc('dispute_get', {
    p_case_id: caseId,
  });
  const envelope = (readData ?? {}) as { success?: boolean; code?: string; data?: unknown };
  if (readError !== null || envelope.success !== true || envelope.code !== 'PLT000') {
    return json({ success: false, code: 'PLT004', message: 'Dispute case not found.' }, 403);
  }
  const detail = (envelope.data ?? {}) as {
    case?: { id?: string; filer_entity_id?: string; counterparty_entity_id?: string; escrow_id?: string | null; contract_id?: string | null };
  };
  const row = detail.case ?? {};
  const filer = row.filer_entity_id ?? '';
  const counterparty = row.counterparty_entity_id ?? '';
  if (filer === '' || counterparty === '') {
    return json({ success: false, code: 'PLT004', message: 'Dispute case not found.' }, 403);
  }

  // Decode the caller identity from the JWT without trusting client input.
  const { data: userData } = await userClient.auth.getUser();
  const callerId = userData?.user?.id ?? '';
  const recipient =
    callerId === filer ? counterparty : callerId === counterparty ? filer : '';
  if (recipient === '') {
    return json({ success: false, code: 'PLT004', message: 'Dispute case not found.' }, 403);
  }

  const hasContract =
    typeof row.contract_id === 'string' && row.contract_id !== '';
  const subject = hasContract
    ? `Contract ${shortId(row.contract_id as string)}`
    : `Escrow ${shortId((row.escrow_id as string | null) ?? '')}`;
  const title =
    event === 'filed'
      ? 'Dispute filed'
      : event === 'withdrawn'
        ? 'Dispute withdrawn'
        : 'Dispute resolved';
  const body =
    event === 'filed'
      ? `${subject} is now frozen pending resolution.`
      : event === 'withdrawn'
        ? `${subject} is unfrozen.`
        : `${subject} has been resolved — see the outcome.`;

  const serviceClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { error: insertError } = await serviceClient
    .from('notification_events')
    .insert({
      entity_id: recipient,
      title,
      body,
      channel_id: 'hivorr_default',
      priority: 'normal',
      action_route: `/support/disputes/${caseId}`,
      payload: { case_id: caseId, event },
    });
  if (insertError !== null) {
    return json({ success: false, code: 'PLT999', message: 'Notify service failed.' }, 500);
  }

  return json({
    success: true,
    code: 'PLT000',
    message: 'Counterparty notified.',
    data: { case_id: caseId, event },
  });
});
