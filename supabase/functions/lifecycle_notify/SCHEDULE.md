# lifecycle_notify — deploy, schedule & staging verification (EP-03-18)

Cron-owned Edge Function. Code: `index.ts` (Deno, `service_role` only).

## 1. Deploy (staging first, then production)

Per `ARCHITECTURE.md` ENV-006/ENV-007 (no secrets in code/config, staging
before production):

```bash
# Staging
supabase functions deploy lifecycle_notify
supabase secrets set SUPABASE_URL=<staging-url> SUPABASE_SERVICE_ROLE_KEY=<staging-service-role>

# Production (only after staging verification below is green)
supabase functions deploy lifecycle_notify
supabase secrets set SUPABASE_URL=<prod-url> SUPABASE_SERVICE_ROLE_KEY=<prod-service-role>
```

Verify deploy (service-role only):

```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/lifecycle_notify \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit": 5}'
# Expect: {"success":true,"code":"PLT000","message":"Lifecycle drain completed.",...}
```

Local rehearsal (no secrets in repo):

```bash
supabase functions serve lifecycle_notify
curl -X POST http://127.0.0.1:54321/functions/v1/lifecycle_notify \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit": 5}'
```

## 2. Schedule (hosting project, not in this repo)

Two drains, different cadences (existing `escrow_milestone_auto_release`
stays at `*/15`; lifecycle notifications need fresher delivery):

```text
*/1 * * * *   ->  POST /functions/v1/lifecycle_notify
Authorization: Bearer <SERVICE_ROLE_KEY>   # secret store only
Content-Type: application/json
Body: { "limit": 50 }
```

Configure in the Supabase Dashboard (Edge Functions → Schedules / Cron)
or the platform scheduler. Backoff inside `notification_ack` is
30s × attempts (`failed` after 5); a 1-minute cadence bounds worst-case
delivery lag to ~2 minutes with retries.

## 3. Staging verification checklist (project lead)

Run in order on staging; do not promote until all are green.

- [ ] Migrations applied: `supabase migration list --linked` shows
      `20261014090001_notification_outbox` as applied.
- [ ] pgTAP posture: `supabase test db supabase/tests/database/054_notification_outbox_posture.sql`
      (18 assertions) green in CI.
- [ ] pgTAP matrix: `supabase test db supabase/tests/database/055_notification_outbox_matrix.sql`
      (43 assertions) green in CI — covers enqueue validation, dedup,
      claim/ack guards, and trigger firings for listing, contract
      offer/accept/cancel, message, appointment, milestone
      complete/verify/release, review submit/reveal, earnings.
- [ ] Drain smoke: invoke `lifecycle_notify` with `{"limit": 5}` on staging;
      expect `PLT000` and `notification_outbox` rows moving
      `pending → leased → sent` (query as `service_role` in a staging
      console only).
- [ ] End-to-end: offer → accept → message → book → complete → verify →
      review → release on staging; each step yields exactly one
      `notification_events` row for the counterparty with the canonical
      `action_route` (`/contracts/:id`, `/dashboard/messages/:id`,
      `/appointments/:id`, `/finance/earnings`).
- [ ] `dispute_notify` backward-compat: file untouched since EP-03-17
      (`git log -- supabase/functions/dispute_notify` shows no EP-03-18
      change); `050_dispute_notify_admin_posture.sql` still green;
      dispute filing still notifies the counterparty immediately via the
      direct path (no outbox duplicate by design).
- [ ] Flutter: `flutter test test/unit/core/notifications
      test/widget/notifications` green; `dart analyze` clean.

## 4. Rollback

- Function: redeploy the previous version
  (`supabase functions deploy lifecycle_notify` from the prior commit).
- Schedule: pause the 1-minute trigger in the Dashboard.
- Database: outbox rows are inert facts — pausing the drain stops delivery
  without touching ledger state. Triggers only INSERT outbox rows; no
  rollback of `notification_events` is needed. A migration rollback is not
  required and not recommended once staging data exists.
