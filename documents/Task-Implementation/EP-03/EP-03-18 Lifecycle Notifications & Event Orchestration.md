# EP-03-18: Lifecycle Notifications & Event Orchestration — Task Implementation Plan

## 1. Task Objective

Implement reliable, PII-redacted, deep-linked lifecycle notifications for the 2-party Services Marketplace, per `EP-03 Two-Party Transaction Engine & Professional Services Platform.md:433-442`:

Event matrix: `listing_published`, `contract_offered/accepted/cancelled`, `milestone_completed/verified/rejected`, `milestone_released`, `review_submitted/revealed`, `message_received`, `appointment_booked/rescheduled/cancelled`, `dispute_filed/resolved`, `earnings_released`.

Wiring: server event sources → durable fan-out → `lib/core/notifications/*` (`EP-01-18` foundation) → local + push (`notification_events` Realtime channel) with `action_route` payloads (`/contracts/:id`, `/dashboard/messages/:id`, etc.) via per-category channels in `lib/core/notifications/channels/notification_channel_manager.dart`.

## 2. Business Problem Being Solved

Contracts, escrow releases, reviews, messages, appointments, and disputes are currently silent cross-device. Audit rows exist (`contract_events`, `appointment_events`) but only one event (`dispute_filed`) fans out to the counterparty. Without orchestration:

* Professionals miss offers, milestone verifications, bookings.
* Clients miss completions, releases, review reveals.
* SLA coordination (`Business-Roadmap:242-246`) fails on unreliable connectivity.

## 3. Scope

* Server-side fan-out for all 15 EP-03-18 events from authoritative sources (`service_contracts`, `contract_milestones`, `service_reviews`, `messages`, `appointments`, `dispute_cases`, `financial_escrow`).
* Durable delivery: exactly-once intent, retry, offline-device catch-up on next sync.
* Client: per-category Android channels, foreground local render, Realtime push render via existing `lib/core/notifications/push/supabase_push_receiver.dart`, tap → protected-route navigation, permission-disabled UX.
* PII redaction on every title/body/payload via `lib/core/logging/pii_redactor.dart`.
* pgTAP + integration coverage for the full matrix.

## 4. Out of Scope

* No FCM/APNS sender, no `entity_devices` push gateway — confirmed missing; background/terminated delivery remains Realtime-foreground + catch-up on sync (same limitation as `supabase/functions/dispute_notify/README.md`).
* No new financial math, ranking, or escrow state machine — reuse `EP-02-04` and `EP-03-02/11` RPCs.
* No full notification center/history UI — `/dashboard/notifications` (`lib/systems/dashboard/screens/notifications_screen.dart`) stays an activity feed; `read_at` write path is out of scope except policy preservation.
* No `supabase/templates/*` email templates, no Admin-shell expansion, no EP-04 3-party threads.
* No bare `/messages/:id` route — canonical is `/dashboard/messages/:id`.

## 5. Existing Asset and Dependency Analysis

Inspected via codebase audit (no assumptions):

**Reusable notification foundation (`EP-01-18`, all present):**

* `lib/core/notifications/notifications.dart:30-124` — `initializeNotifications()` bootstrap.
* `lib/core/notifications/services/local_notification_service.dart:18-301` — `show/cancel/tap-payload` with channel-aware details.
* `lib/core/notifications/push/supabase_push_receiver.dart:16-172` — Realtime `INSERT on notification_events WHERE entity_id=auth.uid()` + `_mapPayload` (`action_route` → `actionRoute`).
* `lib/core/notifications/channels/notification_channel_manager.dart:14-82` — validated channel creation (`^[a-zA-Z0-9_]+$`).
* `lib/core/notifications/providers/notification_provider.dart:17-153`, `lib/core/notifications/permission/notification_permission_manager.dart:9-105`, `lib/core/notifications/models/hivorr_notification.dart:9-96`.
* `lib/config/constants/app_constants.dart:291-343` — `pushChannelName=notification_events`, fail-closed `enablePush=false`.
* `test/unit/core/notifications/*` (11 files) + `test/support/fakes/fake_notifications.dart:15-233`.

**Reusable server transport (exists — reuse, do not duplicate):**

* `supabase/migrations/20261013090002_dispute_notify_channel.sql:24-79` — `notification_events(entity_id,title,body,channel_id,priority,action_route,payload,read_at)` + RLS (`authenticated SELECT/UPDATE self-only`, zero `authenticated INSERT`, `service_role INSERT`) + Realtime publication. Sole writer is `supabase/functions/dispute_notify/index.ts:1-150`.
* `supabase/tests/database/050_dispute_notify_admin_posture.sql:1-78` — posture pattern to extend.

**Reusable event sources (audit rows exist, zero fan-out except disputes):**

* `supabase/migrations/20260923090001_service_contract_schema.sql:150-162` — `contract_events(offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed)`; explicitly `DROP`ped from Realtime `:957-962`.
* `supabase/migrations/20260926090001_service_scheduling_schema.sql:167-180` — `appointment_events(booked/confirmed/rescheduled/cancelled/completed)`; not published `:805-810`.
* `supabase/migrations/20260829100004_financial_integrity_schema.sql:387-413` — `financial_audit_trail` (never a notification source).
* `supabase/migrations/20260925090001_service_messaging_schema.sql:53,82,106` — `conversations/participants/messages`; only `messages` is Realtime-published.
* `supabase/functions/escrow_milestone_auto_release/index.ts:1-175` — emits `contract_events` only, zero `notification_events`.

**Reusable local-only hooks (pattern to generalize, not duplicate):**

* `lib/data/providers/escrow_provider.dart:282-354` — `notifyContractMilestoneEvent()` (`/contracts/:id`).
* `lib/data/providers/earnings_provider.dart:208-240` — `notifyEarningsReleased()` (`/dashboard/earnings`).
* `lib/data/providers/messaging_provider.dart:727-746` — `_maybeNotify()` (`/dashboard/messages/:id`).
* `lib/data/providers/dispute_provider.dart:397-447` + `lib/systems/support/services/service_dispute_notifier.dart:12-43` — only server fan-out in codebase.
* `lib/systems/reviews/screens/review_submit_screen.dart:183-207`, `review_reveal_screen.dart:76-99` — self-notify only.
* `lib/core/sync/action_queue.dart:17-184` — client offline queue; only messaging uses it. No server `notification_outbox`.
* `lib/app/router/route_paths.dart`, `app_router.dart:812`, `route_guard.dart:210-346` — all deep-link targets exist; `_handleTap` in `notification_provider.dart:135-139` never navigates; `AndroidManifest.xml:1-51` has no `VIEW/https` intent-filter; no `app_links` handler.

**Reusable UI/theming:**

* `lib/shared/widgets/hivorr_error_state.dart`, `hivorr_empty_state.dart` — no permission-disabled variant exists.
* `lib/app/theme/app_colors.dart`, `app_theme.dart:373` — compliant tokens, no notification-specific channel-color mapping.

**Dependencies:** `EP-03-10/11/13/14` (event producers), `EP-01-18` (notification engine), `EP-01-15` (router/guard), `EP-02-04/05` (escrow/dispute freeze).

## 6. Reuse / Extension / Refactoring Assessment

| Asset | Decision | Rationale |
|---|---|---|
| `notification_events` table + RLS + Realtime | **Reuse as-is** | Proven push channel; creating a parallel `notifications` table would duplicate responsibility. No DDL change except optional `idempotency_key` column (see below). |
| `dispute_notify` Edge Function | **Extend → generic `lifecycle_notify`** | Sole proven `service_role INSERT` pattern with JWT party check + `***last4` redaction + `PLT000/001/003/004/999` envelope. Generalize recipient derivation + template registry; keep `dispute_notify` as thin wrapper for backward compat. |
| `contract_events` / `appointment_events` | **Reuse as source of truth** | Authoritative audit; notification fan-out derives from them, never replaces them. Do not publish them to Realtime — fan-out goes via `notification_events`. |
| `NotificationChannelManager`, `LocalNotificationService`, `SupabasePushReceiver`, `NotificationProvider` | **Extend** | Add per-category channel registration (`hivorr_contracts`, `hivorr_escrow`, `hivorr_messages`, `hivorr_schedule`, `hivorr_reviews`, `hivorr_disputes`), `IMPORTANCE_HIGH` for messages, tap→`actionRoute` dispatcher, permission-disabled branch. No new engine. |
| `PiiRedactor` | **Reuse** | Enforce on every template; forbid `body_preview`/amounts/PII in bodies (existing `SentryLogSink` leak path). |
| `ActionQueue` (client) | **Reuse pattern only for idempotency keys** | Server durability is new; client queue stays messaging-only. |
| `notification_outbox` table | **New — genuine gap** | Inspected: zero hits in `supabase/migrations/*`, `supabase/functions/*`, `lib/*`; only doc references (`EP-03:437`, `EP-03-14:47`). `notification_events` is append-only with documented duplicates on retry, no `status/attempts/next_retry/lease`. Outbox is a durable queue (different responsibility), not a duplicate. Designed as reusable platform capability for EP-04. |
| Tap→router dispatcher + OS deep-link binding | **New (small, reusable)** | `NotificationProvider._handleTap` is a no-op for navigation; no central dispatcher, no `VIEW/https` intent-filter exists. |
| Permission-disabled `HivorrErrorState` + `Open Settings` | **Extend shared widgets usage** | Widgets exist; the disabled-permission branch + `app_settings` opener is missing. |

## 7. Recommended Technical Approach

1. **Durable outbox (server, new):** `notification_outbox(id uuid, dedup_key unique, recipient_entity_id, event_type CHECK (15-event enum), title, body, channel_id, priority, action_route, payload jsonb, status pending/leased/sent/failed, attempts, next_retry_at, created_at)` + RLS default-deny (`service_role` full, `authenticated` none). Writer is a `SECURITY INVOKER` RPC `notification_enqueue(...)` called post-commit from existing lifecycle RPCs (contract offer/accept/cancel, milestone complete/verify, review submit/reveal, appointment book/reschedule/cancel, escrow release, dispute file/resolve) or from AFTER INSERT triggers on `contract_events`/`appointment_events` where RPC touch is riskier. `dedup_key = <event_type>:<source_id>:<version>` gives exactly-once.
2. **Drain function (extend pattern):** new Edge Function `lifecycle_notify` (modeled on `dispute_notify`): leases `pending WHERE next_retry_at<=now()` with `FOR UPDATE SKIP LOCKED`, validates recipient is a contract/conversation participant server-side (no oracle — `403 PLT004` on non-party), applies PII-redacted template registry, `INSERT`s `notification_events`, marks `sent`. Cron every 30–60s + on-demand invoke from RPCs for low latency. `escrow_milestone_auto_release` adds a `notification_enqueue(milestone_released, auto_released:true)` call instead of silent audit.
3. **Client (extend):** register per-category channels on bootstrap; `SupabasePushReceiver` mapping unchanged; add `NotificationTapDispatcher(actionRoute → GoRouter.go + RouteGuard ?next= preservation)`; wire `onNotificationTapped` → dispatcher; add permission-disabled screen branch (`permanentlyDenied/denied` → `HivorrErrorState` + `Enable notifications` → `openAppSettings`).
4. **Templates:** central `lifecycle_notification_templates` map (server TS + mirrored Dart preview strings for local echo): e.g. `contract_offered: {title: "New contract offer", body: "Contract ***{last4} awaiting your review", route: "/contracts/{id}"}`. Never include emails, phone, amounts, message bodies, review text.

## 8. Required Systems, Modules, and Components

* Server: `supabase/migrations/*_notification_outbox.sql`, `notification_enqueue` RPC, `lifecycle_notify` Edge Function + cron, `notification_events` optional `dedup_key` migration, template registry.
* Client: `lib/core/notifications/channels/` (category registration), `lib/core/notifications/navigation/notification_tap_dispatcher.dart` (new, reusable), `lib/data/providers/notification_provider` extension, permission-disabled UI in `notifications_screen.dart` / `conversation` entry points.
* No changes to `lib/engine/*`, `lib/ai/*`, `lib/integrations/payment_gateways/*`.

## 9. Data Requirements

* Outbox row per delivery intent; `payload` carries only IDs + `event_type` (`{contractId, milestoneId, appointmentId, case_id, event}`), never PII.
* `notification_events` row per recipient per event (1:1 for 2-party; counterparty-only for `message_received`, both parties for state transitions where relevant).

## 10. Database Considerations

* Reuse existing indexes on `contract_events(contract_id)`, `appointment_events(appointment_id)`; add `notification_outbox(status, next_retry_at)` + `dedup_key UNIQUE` + `notification_events(entity_id, created_at DESC) WHERE read_at IS NULL` (already exists — preserve).
* All timestamps `timestamptz`; all writes in same transaction as state transition where RPC-enqueued (no notify-without-commit, no commit-without-notify-intent).
* RLS audit: extend `050_dispute_notify_admin_posture.sql` pattern to outbox + per-event fan-out matrix; assert `authenticated` cannot `INSERT notification_events/notification_outbox` directly.

## 11. API Requirements

* One canonical RPC: `notification_enqueue(p_dedup_key, p_recipient, p_event_type, p_title, p_body, p_channel, p_priority, p_action_route, p_payload)` — `SECURITY INVOKER`, envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999`), recipient-participant check inside.
* No direct REST `INSERT` on `notification_events/outbox` for `authenticated` (retain `REVOKE` + grants from `20261013090002`).
* Edge: `POST /functions/v1/lifecycle_notify {limit}` (`service_role` cron) + reuse `dispute_notify` contract for dispute events.

## 12. User Interface Requirements

* No new screens. Changes: channel-aware foreground banners (existing `showLocal` path), tap navigates to existing routes (`contractDetail(id)`, `dashboardMessageThread(id)`, `appointmentDetail(id)`, `disputeDetail`, `earningsHistoryFor()`, `contractReviewsFor`), disabled-permission `HivorrErrorState` + `Enable notifications` action → `openAppSettings`; no new widget, reuse `lib/shared/widgets/hivorr_error_state.dart`.
* All banners/cards consume `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` per `AGENT.md:18`; no `Colors.*`/hex/`fontFamily` per-widget. Channel→semantic color mapping only via theme tokens (e.g. dispute → `colorScheme.error`, earnings → success token).

## 13. User Experience Considerations

* Exactly-one local render per event (foreground) + one Realtime push payload; dedup by `dedup_key`/`client_message_id` pattern, no double-banners on reconnect.
* Deep-link tap preserves auth: `lib/app/router/route_guard.dart:210-346` `?next=` resume; anon `/s/:slug/:id` preview allowed, `/contracts/:id` requires auth.
* Offline devices catch up on next sync — documented limitation (no FCM/APNS), same as `dispute_notify` behavior.
* Quiet by default: `normal` priority except messages/escrow-release `high`; per-category channels let users mute without disabling all.

## 14. Security Considerations

* `AGENT.md:13` zero-trust: recipient derivation + participant check server-side; `403 PLT004` on non-party with no existence oracle (reuse `dispute_notify/index.ts` pattern).
* RLS: `notification_outbox` default-deny, `authenticated` zero `INSERT`; `notification_events` grants unchanged (`SELECT authenticated self-only`, `INSERT service_role` only) per `20261013090002_dispute_notify_channel.sql:24-79`.
* PII: every template through `lib/core/logging/pii_redactor.dart:1-150` + server `***last4` redaction; forbid message `body_encrypted` plaintext, review text, amounts, emails/phones in title/body/payload.
* No `SECURITY DEFINER` except lease/unfreeze helpers where needed; prefer `SECURITY INVOKER` + RLS.

## 15. Performance Considerations

* Outbox lease with `FOR UPDATE SKIP LOCKED`, batch `limit<=100` (same as `escrow_milestone_auto_release`), partial index `(status, next_retry_at)`.
* Preserve existing GIN/partial indexes; Realtime filtered by `entity_id=auth.uid()` — no broadcast fan-out.
* Client: `NotificationChannelManager` cache, no N+1 on tap dispatch; cursor pagination unchanged for message/appointment lists.

## 16. Testing Strategy

* pgTAP: outbox DDL + `notification_enqueue` guard tests; per-event matrix test (15 events → exactly-one outbox row with correct `recipient/action_route`); RLS leakage matrix (non-participant 0 rows, `authenticated INSERT` blocked); dedup replay test.
* Edge Function: lease→`notification_events`→`sent` test; retry/backoff test; `dispute_notify` backward-compat test.
* Flutter: `FakePushRealtimeGateway.emitEvent` + `FakeLocalNotificationBackend` — foreground render test, tap→`actionRoute` dispatcher test (`/contracts/:id`, `/dashboard/messages/:id`), permission-disabled `HivorrErrorState` test.
* Integration: full lifecycle on staging — offer→accept→milestone→release→review→booking→dispute each fires one notification; deep-link lands on guarded route.

## 17. Recommended Implementation Sequence

1. Migration `notification_outbox` + `notification_enqueue` RPC + pgTAP posture.
2. `lifecycle_notify` Edge Function + cron + `escrow_milestone_auto_release` hook-up.
3. Per-event wiring in existing RPCs/triggers (contracts → milestones → reviews/appointments/disputes/earnings).
4. Client: category channels + tap dispatcher + permission-disabled UI.
5. Matrix integration test + RLS audit + staging validation.

## 18. Expected Outcome

Every EP-03-18 lifecycle transition produces one durable, redacted, deep-linked notification deliverable foreground + Realtime push, with counterparty coverage for all 15 events (vs 1/17 today), no duplicate tables, no client-side financial/ranking logic.

## 19. Definition of Done

* Outbox + RPC live with RLS default-deny; pgTAP matrix green.
* Each of 15 events verified: outbox row → `notification_events` row → local/push render → tap navigates to correct guarded route.
* Zero PII in titles/bodies/payloads (redactor + `***last4` asserted).
* Zero `authenticated` direct `INSERT` on `notification_events/outbox`; `dart analyze` + `flutter test` + theme-token asserts pass.
* No new ledger/ranking logic in client; `dispute_notify` still passes.

## 20. Implementation AI Execution Profile

* **Recommended Coding Reasoning Level: High**
* **Justification:** High integration complexity (15 producers → 1 durable pipeline → 2 render paths + router) and medium-high security risk (RLS, cross-party delivery, PII redaction), but no new financial settlement atomicity or deterministic ranking formula — those stay in reused `EP-02-04`/`EP-03-02/11` RPCs. Matches approved phase allocation (`EP-03:489,501` — High/High). `Very High`/`Extremely High` not warranted; `Medium` insufficient for exactly-once + RLS + deep-link guarantees.
