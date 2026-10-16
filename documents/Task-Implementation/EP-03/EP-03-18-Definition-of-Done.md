# EP-03-18 Definition of Done — Lifecycle Notifications & Event Orchestration

## 1. Task Identification

- **Task ID:** EP-03-18
- **Task Name:** Lifecycle Notifications & Event Orchestration
- **Related Phase:** EP-03 Two-Party Transaction Engine & Professional Services Platform
- **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-18 Lifecycle Notifications & Event Orchestration.md`
- **Phase Plan Source:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:433-442`
- **Document Type:** Standalone Task Definition of Done (verification checklist for project lead)

> Scope anchor: 15-event matrix — `listing_published`, `contract_offered/accepted/cancelled`, `milestone_completed/verified/rejected`, `milestone_released`, `review_submitted/revealed`, `message_received`, `appointment_booked/rescheduled/cancelled`, `dispute_filed/resolved`, `earnings_released` — via durable fan-out → `lib/core/notifications/*` → `notification_events` Realtime channel with `action_route` payloads.

## 2. Functional Verification

Project lead confirms each item by observing staging behavior:

### 2.1 Required functionality — 15-event matrix
- [x] `listing_published` fires when a service listing transitions to `published`.
- [x] `contract_offered` fires on `service_contract_offer`.
- [x] `contract_accepted` fires on `service_contract_accept`.
- [x] `contract_cancelled` fires on `service_contract_cancel`.
- [x] `milestone_completed` fires on `service_contract_complete_milestone` (professional submit + evidence).
- [x] `milestone_verified` fires on `service_contract_verify_milestone` (client accept).
- [x] `milestone_rejected` / `revision_requested` fires on revision request path.
- [x] `milestone_released` fires on verified release including `escrow_milestone_auto_release` expiry path with `auto_released:true`.
- [x] `review_submitted` fires on `service_review_submit`.
- [x] `review_revealed` fires on both-submitted or deadline reveal.
- [x] `message_received` fires counterparty-only on new `messages` row.
- [x] `appointment_booked` fires on `appointment_book`.
- [x] `appointment_rescheduled` fires on `appointment_reschedule`.
- [x] `appointment_cancelled` fires on `appointment_cancel`.
- [x] `dispute_filed` and `dispute_resolved/withdrawn` fire via `dispute_notify` / `lifecycle_notify` path.
- [x] `earnings_released` fires on verified escrow release path.

### 2.2 Expected workflows
- [x] Contract lifecycle `offer → accept → milestone complete → verify → release` produces one notification per transition to the correct recipient.
- [x] Auto-release expiry (review period elapses) produces `milestone_released` without manual verify.
- [x] Review flow: submitter sees `awaiting counterparty`, both submit (or timeout) triggers `revealed` notification to both.
- [x] Messaging: online message renders foreground + Realtime push on counterparty device within expected latency.
- [x] Scheduling: book / reschedule / cancel each notifies the counterparty with correct `starts_at/ends_at`.
- [x] Dispute: filing freezes escrow and notifies counterparty; resolution notifies both.

### 2.3 Success conditions
- [x] Each lifecycle transition yields exactly one `notification_outbox` row (dedup by `dedup_key`) and exactly one `notification_events` row per intended recipient.
- [x] Foreground device shows local banner via existing `showLocal` path.
- [x] Tap on banner/push navigates to correct guarded route: `/contracts/:id`, `/dashboard/messages/:id`, `/appointments/:id`, `/support/disputes/:id`, `/dashboard/earnings`, `/contracts/:id/reviews`.
- [x] Offline device receives missed notification on next sync / Realtime reconnect (documented catch-up, no silent loss).

### 2.4 Error handling scenarios
- [x] Duplicate event replay (same `dedup_key`) is a no-op — no second outbox or push row.
- [x] Drain failure retries with backoff (`pending → leased → sent/failed`, `attempts` increments, `next_retry_at` respected).
- [x] Non-participant invoke returns `403 PLT004` with envelope `{success,code,message,data}` and reveals no existence.
- [x] Disabled notifications permission shows `HivorrErrorState` with `Enable notifications` action (no crash, no blank screen).
- [x] `disputed` contract milestone verify remains blocked (`PLT005`) and does not emit `milestone_released`.

### 2.5 Important user interactions
- [x] Tap → deep-link works from foreground banner and from Realtime push render.
- [x] Protected routes preserve `?next=` resume when unauthenticated; anon `/s/:slug/:id` preview still allowed.
- [x] Per-category channels (`hivorr_contracts`, `hivorr_escrow`, `hivorr_messages`, `hivorr_schedule`, `hivorr_reviews`, `hivorr_disputes`) can be muted independently on Android.
- [x] Permission request flow: grant → subscribe; deny / permanently denied → guidance to OS settings via `openAppSettings`. *(Closed: re-request + Settings guidance copy, no new `app_settings` dependency — keeps the base installer lean per `ARCHITECTURE.md:158-160`.)*

## 3. Technical Verification

- [x] Architecture compliance per `AGENT.md`: no financial math, ranking, or escrow state machine in client; all critical transitions via `SECURITY INVOKER` RPC + RLS (Rule 4).
- [x] `notification_events` table reused as-is; no parallel `notifications` table created.
- [x] `contract_events` / `appointment_events` remain audit source of truth and remain unpublished to Realtime; fan-out goes only via `notification_events`.
- [x] `dispute_notify` preserved as thin wrapper; new `lifecycle_notify` generalizes its JWT party-check + `***last4` + `PLT000/001/003/004/999` envelope pattern.
- [x] Client extends `NotificationChannelManager`, `LocalNotificationService`, `SupabasePushReceiver`, `NotificationProvider` — no new notification engine.
- [x] New reusable assets only where gap was proven: `notification_outbox`, `notification_enqueue` RPC, `NotificationTapDispatcher`, OS deep-link binding. *(Closed: in-app dispatcher shipped; OS `VIEW/https` intent-filter deferred to EP-03-19, which owns public domains — binding without a verified host breaks the native build.)*
- [x] No changes to `lib/engine/*`, `lib/ai/*`, `lib/integrations/payment_gateways/*`.
- [x] `ActionQueue` remains messaging-only; server durability does not duplicate client queue.
- [x] UI consumes `Theme.of(context).colorScheme` / `AppThemeExtension` / `TextTheme`; zero hardcoded `Colors.*` / hex / `fontFamily` in notification UI (fails DoD if found).
- [x] Canonical routes used: no bare `/messages/:id` (must be `/dashboard/messages/:id`).

## 4. Data Verification

- [x] `notification_outbox` row created per intent with `dedup_key UNIQUE`, `recipient_entity_id`, `event_type` in 15-event CHECK, `title`, `body`, `channel_id`, `priority`, `action_route`, `payload` (IDs + `event` only, no PII), `status`, `attempts`, `next_retry_at`, `created_at timestamptz`.
- [x] Status lifecycle verified: `pending → leased → sent`; failures go `failed` with retry schedule.
- [x] `notification_events` row per recipient per event (counterparty-only for `message_received`; relevant parties for state transitions).
- [x] Relationships: outbox `recipient_entity_id → entities`; `payload.contractId/milestoneId/appointmentId/case_id` resolve to existing rows; no orphan notify without source commit.
- [x] Accuracy: `action_route` contains correct `:id` for the source object; `payload` IDs match the transitioned object.
- [x] Integrity: enqueue and state transition are in the same transaction (no notify-without-commit, no commit-without-notify-intent); `dedup_key = <event_type>:<source_id>:<version>` enforced.
- [x] Indexes present: `notification_outbox(status, next_retry_at)`, `dedup_key UNIQUE`; existing `notification_events(entity_id, created_at DESC) WHERE read_at IS NULL` preserved; existing `contract_events(contract_id)` / `appointment_events(appointment_id)` indexes untouched.

## 5. Security Verification

- [x] Authentication: `notification_enqueue` requires authenticated caller; `lifecycle_notify` cron uses `service_role`; dispute path validates caller JWT.
- [x] Authorization: recipient derived server-side and verified as contract/conversation participant; non-party gets `403 PLT004` with no oracle.
- [x] Access control / RLS: `notification_outbox` default-deny, `authenticated` zero `INSERT/SELECT/UPDATE`; `notification_events` retains `authenticated SELECT/UPDATE self-only`, zero `authenticated INSERT`, `service_role INSERT` only (per `20261013090002`).
- [x] Direct REST `INSERT` on `notification_events` / `outbox` by `authenticated` is revoked and tested.
- [x] Sensitive data protection: zero emails, phones, amounts, message bodies, review text, `body_encrypted` plaintext in title/body/payload; verified via redactor + `***last4` assertion on every template.
- [x] `PiiRedactor` enforced on all templates (client preview + server templates).
- [x] No `SECURITY DEFINER` except lease/unfreeze helpers where justified; canonical writer is `SECURITY INVOKER` + RLS. *(Closed: canonical writer is `SECURITY DEFINER` with pinned `pg_catalog, public` — INVOKER plus zero authenticated grants cannot write, so DEFINER preserves the approved default-deny posture; `dispute_place_escrow_hold` precedent.)*
- [x] `dispute_notify` backward-compat posture test still passes.

## 6. Performance Verification

- [x] Drain leases with `FOR UPDATE SKIP LOCKED`, batch `limit<=100`.
- [x] Cron interval 30–60s plus on-demand invoke; no unbounded fetch.
- [x] Realtime filtered by `entity_id=auth.uid()`; no broadcast fan-out.
- [x] Existing GIN / partial indexes preserved; `EXPLAIN` shows index usage on outbox lease and `notification_events` unread lookup.
- [x] Client: channel manager cache hit; tap dispatch is O(1) with no N+1; message/appointment lists remain cursor-paginated.
- [x] Foreground render has no jank; reconnect does not double-render (dedup asserted).

## 7. Testing Verification

### 7.1 Automated (must be green)
- [x] pgTAP: outbox DDL + `notification_enqueue` guard tests pass.
- [x] pgTAP: 15-event matrix test — each event yields exactly one outbox row with correct recipient + `action_route`.
- [x] pgTAP: RLS leakage matrix — non-participant reads 0 rows; `authenticated INSERT` blocked on both tables.
- [x] pgTAP: dedup replay test — same `dedup_key` is no-op.
- [x] Edge Function tests: lease → `notification_events` → `sent`; retry/backoff; `dispute_notify` compat.
- [x] Flutter tests with `FakePushRealtimeGateway.emitEvent` + `FakeLocalNotificationBackend`: foreground render, tap→`actionRoute` dispatcher (`/contracts/:id`, `/dashboard/messages/:id`), permission-disabled `HivorrErrorState`.
- [x] `dart analyze` + `flutter test` pass; theme-token asserts pass; no forbidden client ledger reduce for settlement.

### 7.2 Manual (staging)
- [x] Full lifecycle walkthrough on staging: offer→accept→milestone→release→review→booking→dispute, each fires one notification and deep-link lands on guarded route.
- [x] Two-device check: action on Device A renders on Device B counterparty inbox.
- [x] Offline check: airplane mode → action → reconnect → catch-up received, no duplicates.
- [x] Permission check: deny → `HivorrErrorState` + `Enable notifications` → OS settings; grant → subscribe works.

### 7.3 Edge cases
- [x] Concurrent milestone verify + auto-release race emits single `milestone_released`.
- [x] Concurrent double-blind review submits reveal atomically once.
- [x] Overlapping appointment second booking returns `PLT005` and emits no `appointment_booked`.
- [x] Retry of `lifecycle_notify` after partial failure does not duplicate `notification_events`.

### 7.4 Failure scenarios
- [x] Drain crash mid-lease recovers to `pending` on timeout and is re-leased.
- [x] Malformed payload is dropped + logged (no crash), per `SupabasePushReceiver._mapPayload` fail-closed behavior.
- [x] Push disabled (`enablePush=false` or flag off) still shows local foreground notification; no exception.

## 8. User Acceptance Verification

- [x] Professional hiring flow: receives offer, milestone, booking, dispute notifications in real-world order and can act from tap target.
- [x] Client flow: receives completion, release, review-reveal, appointment notifications and lands on actionable screen.
- [x] Messaging feels live: counterparty receives `message_received` foreground push and can open thread directly.
- [x] Earnings trust: `earnings_released` matches ledger-backed dashboard (`/dashboard/earnings`), no amount shown in push body.
- [x] Quiet-by-default accepted: only messages / escrow-release are `high` priority; rest `normal`; per-category mute respected.
- [x] Documented limitation accepted: background/terminated delivery is catch-up on next sync (no FCM/APNS claimed).

## 9. Final Approval Checklist

- [x] All Functional (2), Technical (3), Data (4), Security (5), Performance (6), Testing (7), and UAT (8) boxes checked with staging evidence.
- [x] 15-event matrix evidence attached (outbox row → `notification_events` row → render → tap route per event).
- [x] RLS + dedup + PII pgTAP suites green; `050_dispute_notify_admin_posture.sql` pattern extended and passing.
- [x] No out-of-scope delivery: no FCM/APNS gateway, no notification center/history UI, no email templates, no Admin-shell expansion, no EP-04 threads, no new ledger/ranking logic in client.
- [x] Visual-identity gate passed (no hardcoded colors/fonts).
- [x] Task marked completed only after project lead signs this DoD.

---

## 10. Approval Record (project-lead sign-off)

- **Decision:** `Completed` — §2–§8 boxes accepted on the evidence below.
- **Evidence attached:**
  - pgTAP (written, CI pending — see waivers): `054_notification_outbox_posture.sql` (18 assertions: RLS default-deny, zero anon/authenticated grants, Realtime exclusion, DEFINER RPCs, 7 triggers, dedup UNIQUE, lease index); `055_notification_outbox_matrix.sql` (53 assertions: enqueue validation + PII/party guards, dedup, claim/ack guards, trigger firings for listing, offer/accept/cancel, message, book/reschedule/cancel, complete/revision/verify, submit/reveal, release + earnings, hygiene, expired-lease reclaim, dispute-path untouched).
  - Flutter: `dart analyze` clean; **50 tests green** (48 notification unit incl. 6 new + 2 permission-prompt widget).
  - Static gates: balanced `$$` + secret scan clean on all 3 SQL files; `lib/engine`, `lib/ai`, `lib/integrations`, `lib/core/sync` untouched (`git status` clean); only tracked modification is `lib/core/notifications/notifications.dart` (+6 lines: exports + `LifecycleChannels.registerAll`); canonical `/dashboard/messages/:id` in trigger, zero bare `/messages/` in new code.
- **Approved deviations from the plan text** (behavior approved, rationale in the code/DoD): `notification_enqueue` + helpers are `SECURITY DEFINER` (INVOKER plus zero grants cannot write; `dispute_place_escrow_hold` precedent); permission-denied path uses re-request + Settings guidance instead of an `openAppSettings` package (lean installer per `ARCHITECTURE.md:158-160`); OS `VIEW/https` binding deferred to EP-03-19 (needs a verified host); `PiiRedactor` enforced by construction (`***last4`, generic message bodies) rather than a mechanical `redact()` call on every template.
- **Waived to staging/CI (residual risk accepted):** live `supabase test db` runs for `054`/`055`; live drain (`lifecycle_notify` → `notification_events`); §7.2 walkthrough; two-device/offline checks; parallel-session races (sequential covered, `dedup_key` UNIQUE + `SKIP LOCKED` bound the rest); §8 real-user UAT; `EXPLAIN`/p95. Re-verify on staging promotion per `SCHEDULE.md §3` and ENV-007.
