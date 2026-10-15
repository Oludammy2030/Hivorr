# dispute_notify

Counterparty push for dispute lifecycle events (EP-03-17 R2 follow-up).

## What it does

After the filer files or withdraws a dispute, their client invokes this
function once. When either party's client newly observes a resolution on
re-read, it invokes once with `resolved`. The function verifies the caller
is a party to the case (through the user JWT + `dispute_get` RLS) and
inserts one `notification_events` row addressed to the **counterparty**. The
counterparty's device renders it locally via the existing
`SupabasePushRealtimeGateway` subscription (`pushChannelName`, default
`notification_events`, filtered by `entity_id`).

## What it does not do

- No FCM/APNS delivery (offline devices learn on next sync; matches the
  current receive-local transport).
- No `dispute_resolve` invocation, no fund movement, no resolution content.
- No arbitrary recipients: the recipient is always derived server-side from
  the case's filer/counterparty pair.

## Deploy

```bash
supabase functions deploy dispute_notify --no-verify-jwt
```

`--no-verify-jwt` is required: the function performs its own user-JWT
verification (party check) so it can return PLT004 parity instead of a
generic 401.

Required secrets (per environment, never hardcoded):

```bash
supabase secrets set SUPABASE_URL=<url> SUPABASE_ANON_KEY=<anon> \
  SUPABASE_SERVICE_ROLE_KEY=<service-role>
```

## Invoke contract (client)

```ts
POST /functions/v1/dispute_notify
Authorization: Bearer <USER_JWT>
{ "case_id": "<uuid>", "event": "filed" | "withdrawn" | "resolved" }
```

Responses mirror the platform envelope codes (`PLT000` success, `PLT001`
unauthenticated, `PLT003` validation, `PLT004` not-found/no-oracle,
`PLT999` service failure).
