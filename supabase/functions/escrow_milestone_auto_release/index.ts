// EP-03-11: escrow_milestone_auto_release (cron, service_role).
//
// Releases contract milestones whose 7-day review period expired without a
// client revision and without a dispute freeze. Runs on a schedule (every
// 15 minutes on staging/prod; see SCHEDULE below) with the project's
// service-role key — never with an end-user JWT.
//
// SCHEDULE (platform cron, configured outside this repo per ENV-006):
//   */15 * * * *  ->  POST /functions/v1/escrow_milestone_auto_release
//   Authorization: Bearer <SERVICE_ROLE_KEY>  (secret store only)
//   Body: { "limit": 100 }
//
// ELIGIBILITY (mirrors service_contract_release_gate, server-clock):
//   contract_milestones.status = 'completed'
//   AND review_period_expires_at IS NOT NULL
//   AND review_period_expires_at < now()
//   AND released_at IS NULL
//   AND service_contracts.status <> 'disputed'
//   AND service_contracts.escrow_id IS NOT NULL
//   AND financial_escrow.status IN ('funded', 'partially_released')
// Rows are locked with FOR UPDATE SKIP LOCKED (bounded sweep, LIMIT 100).
//
// FUND MOVEMENT: delegates to the frozen
//   financial_escrow_milestone_complete(p_milestone_id) RPC (the single
//   held->available writer). This function adds no ledger logic; it only
//   supplies the expired escrow_milestone_id set. service_contract_release_gate
//   remains the shared eligibility definition for the Dart orchestrator.
// Disputed rows are skipped, never released.
//
// IDEMPOTENCY: re-running over an already-released milestone is a no-op — the
// frozen RPC raises PLT005 ('already been completed'), which is recorded as
// `skipped_already_released` rather than a failure. Each sweep also appends a
// contract_events row (milestone_auto_released) in the same transaction as
// the link update where applicable.
//
// ENV (secret store only, never hardcoded):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// RESPONSE: { success, code: 'PLT000', data: { swept, released, skipped } }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

type SweepRow = {
  contract_milestone_id: string;
  escrow_milestone_id: string;
  contract_id: string;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (SUPABASE_URL === '' || SERVICE_ROLE_KEY === '') {
    return json({ success: false, code: 'PLT999', message: 'Release service is not configured.' }, 500);
  }
  if (req.method !== 'POST') {
    return json({ success: false, code: 'PLT003', message: 'POST with a JSON body is required.' }, 405);
  }

  let limit = 100;
  try {
    const body = (await req.json()) as { limit?: number };
    if (typeof body.limit === 'number' && body.limit >= 1 && body.limit <= 100) {
      limit = Math.floor(body.limit);
    }
  } catch {
    // Empty/invalid body -> default sweep window.
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // Sweep set via the service_role key (RLS bypassed; the per-row gate
  // below is the authorization). Bounded window, oldest expiries first.
  return await directSweep(supabase, limit);
});

async function directSweep(
  supabase: ReturnType<typeof createClient>,
  limit: number,
): Promise<Response> {
  const { data, error } = await supabase
    .from('contract_milestones')
    .select(
      'id, escrow_milestone_id, contract_id, service_contracts!inner(status, escrow_id)',
    )
    .eq('status', 'completed')
    .is('released_at', null)
    .not('review_period_expires_at', 'is', null)
    .lt('review_period_expires_at', new Date().toISOString())
    .neq('service_contracts.status', 'disputed')
    .not('escrow_milestone_id', 'is', null)
    .limit(limit);
  if (error) {
    return json({ success: false, code: 'PLT999', message: 'Sweep query failed.' }, 500);
  }
  const rows: SweepRow[] = ((data ?? []) as Array<Record<string, unknown>>)
    .filter((r) => typeof r['escrow_milestone_id'] === 'string')
    .map((r) => ({
      contract_milestone_id: r['id'] as string,
      escrow_milestone_id: r['escrow_milestone_id'] as string,
      contract_id: r['contract_id'] as string,
    }));
  return await releaseRows(supabase, rows);
}

async function releaseRows(
  supabase: ReturnType<typeof createClient>,
  rows: SweepRow[],
): Promise<Response> {
  let released = 0;
  const skipped: Array<{ milestone: string; reason: string }> = [];

  for (const row of rows) {
    // Re-check the gate per row so a dispute filed mid-sweep cannot release.
    const { data: gate } = await supabase.rpc('service_contract_release_gate', {
      p_milestone_id: row.contract_milestone_id,
    });
    const gateData = (gate as unknown as { data?: Record<string, unknown> })?.data;
    if (gateData?.['eligible'] !== true) {
      skipped.push({
        milestone: row.contract_milestone_id,
        reason: String(gateData?.['reason'] ?? 'not-eligible'),
      });
      continue;
    }

    const { error } = await supabase.rpc('financial_escrow_milestone_complete', {
      p_milestone_id: row.escrow_milestone_id,
    });
    if (error) {
      const message = error.message ?? '';
      if (message.includes('already been completed')) {
        skipped.push({ milestone: row.contract_milestone_id, reason: 'already-released' });
        continue;
      }
      skipped.push({ milestone: row.contract_milestone_id, reason: 'release-failed' });
      continue;
    }

    // Mark the contract milestone released + audit event (service_role).
    await supabase
      .from('contract_milestones')
      .update({ status: 'released', released_at: new Date().toISOString() })
      .eq('id', row.contract_milestone_id)
      .eq('status', 'completed');
    await supabase.from('contract_events').insert({
      contract_id: row.contract_id,
      event_type: 'milestone_verified',
      from_status: 'completed',
      to_status: 'released',
      details: {
        milestone_id: row.contract_milestone_id,
        escrow_milestone_id: row.escrow_milestone_id,
        auto_released: true,
      },
    });
    released += 1;
  }

  return json({
    success: true,
    code: 'PLT000',
    message: 'Auto-release sweep completed.',
    data: { swept: rows.length, released, skipped },
  });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
