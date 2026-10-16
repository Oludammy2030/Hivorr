# lifecycle_notify

Durable drain for EP-03-18 lifecycle notifications.

## What it does

Leases `notification_outbox` rows (`pending`, `next_retry_at <= now()`,
`FOR UPDATE SKIP LOCKED`, bounded to 100) via `notification_claim_batch`,
inserts one `notification_events` row per intent (recipient-scoped Realtime
push), then `notification_ack(id, true/false)` with backoff
(30s * attempts, `failed` after 5).

Outbox rows are written server-side only (DEFINER triggers on
`contract_events` / `appointment_events` / `messages` / `service_reviews` /
`contract_milestones` / `service_listings` + `notification_enqueue` RPC).
Titles/bodies arrive pre-redacted (`***last4`, no PII).

## What it does not do

- No FCM/APNS delivery (offline devices learn on next sync).
- No fund movement, ranking, or escrow state changes.
- No arbitrary recipients: recipient is stored in the outbox row by the
  trigger/RPC that validated participation.

## Deploy

```bash
supabase functions deploy lifecycle_notify
```

Cron (platform scheduler, outside this repo per ENV-006):

```text
*/1 * * * * -> POST /functions/v1/lifecycle_notify
Authorization: Bearer <SERVICE_ROLE_KEY>
Body: { "limit": 50 }
```

Required secrets (per environment, never hardcoded):

```bash
supabase secrets set SUPABASE_URL=<url> SUPABASE_SERVICE_ROLE_KEY=<service-role>
```

## Invoke contract (service-role cron)

```ts
POST /functions/v1/lifecycle_notify
Authorization: Bearer <SERVICE_ROLE_KEY>
{ "limit": 50 }
```

Responses mirror the platform envelope (`PLT000` success, `PLT999` service
failure). Disputes stay on `dispute_notify` (direct path, no duplicate).
