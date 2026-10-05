# escrow_milestone_auto_release — schedule & secrets (EP-03-11 S2)

Cron-owned Edge Function. Code: `index.ts` (Deno, `service_role` only).

## Schedule (configured in the hosting project, not in this repo)

Per `ARCHITECTURE.md` ENV-006 (no secrets in code/config):

```text
*/15 * * * *  ->  POST /functions/v1/escrow_milestone_auto_release
Authorization: Bearer <SERVICE_ROLE_KEY>   # secret store only
Content-Type: application/json
Body: { "limit": 100 }
```

Local rehearsal:

```bash
supabase functions serve escrow_milestone_auto_release
curl -X POST http://127.0.0.1:54321/functions/v1/escrow_milestone_auto_release \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```

Seed an expirable fixture by completing a milestone, then (as `service_role`
in a staging console only) backdating its `review_period_expires_at` past
`now()` — the next sweep must return it in `released` with a
`contract_events(milestone_verified -> released, auto_released: true)` row.
Production data is never backdated.

## Secrets (secret store only)

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Missing secrets -> `PLT999`
`Release service is not configured.` No end-user JWT is accepted for fund
movement; per-row `service_contract_release_gate` re-checks precede every
`financial_escrow_milestone_complete` call so mid-sweep disputes cannot
release.
