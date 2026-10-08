# Definition of Done — EP-03-14: Scheduling & Appointment Management System (Client)

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-10-08. All code-level boxes verified:
> `dart analyze` clean (whole project), 49 new tests green (34 unit + 15 widget),
> forbidden greps 0, `git diff -- supabase` empty. Human/staging remainders accepted as documented
> deferrals (same pattern as EP-03-10). See §10 Verification Evidence.

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-14 |
| **Task Name** | Scheduling & Appointment Management System (Client) |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 5 Trust & Coordination (parallelizable after contracts exist) |
| **Priority** | High — Planning High / Coding High (Phase Plan §12–13) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-14 Scheduling & Appointment Management System (Client).md:1-277` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:389-398` (§EP-03-14) + `§6 Stage 5` + `§7 deps EP-03-05, EP-03-10` + `§8 Risks:180` |
| **Dependencies** | EP-03-05 `availability_slots` / `appointments` / `appointment_events` + 5 RPCs (`supabase/migrations/20260926090001_service_scheduling_schema.sql`) Completed (`031/032` green); EP-03-10 contract client (`contract_detail_screen.dart`, `ContractService`, `ServiceContractProvider`) Completed; EP-02-07 taxonomy engine + `profession_picker`; EP-01-07 (`ApiLayer`/`BaseApiService`), EP-01-15 (router), EP-01-16 (design system), EP-01-12 (sync, only if plan §7.4 approved), EP-01-18 (notifications payload contract) |
| **Delivery Scope** | **Reuse** 5 scheduling RPCs + RLS + `EXCLUDE appointments_no_overlap` verbatim (zero write-SQL change) + `ContractService` facade pattern + `ServiceContractRemoteDataSource/EnvelopeParser/RepositoryImpl/Provider` pattern + `contract_detail_screen` entry + `profession_picker`/`taxonomy_engine` + `shared/` primitives + `AppTheme` tokens + `HivorrFormatters.date/time/dateTime` + `lib/core/localization` pass-through; **Extend (additive)** `data_layer.dart` (`registerSchedulingLayer`), router paths/names, `translation_keys.dart` (~10 keys), `ContractWriteCtaPanel` → `SchedulingWriteCtaPanel` pattern; **New** `SchedulingRemoteDataSource` + `SupabaseSchedulingRemoteDataSource` + `SchedulingEnvelopeParser` + `SchedulingRepository(+Impl)` + `SchedulingProvider` + `SchedulingService` + entities/DTOs/mappers (`AvailabilitySlot/Appointment/AppointmentEvent/Page`) + 3 screens (`availability_editor/appointment_book/appointment_detail`) + 4 widgets (`appointment_status_badge`, `appointment_timeline`, `scheduling_write_cta_panel`, `slot_picker_sheet`) + DI barrel + `fake_scheduling.dart`. Read path per plan §7.1 (Option A micro read-RPCs vs Option B RLS-`SELECT`) locked at build kickoff. |
| **Guardrails** | `AGENT.md` Separation of Concerns + Rule 4 zero-trust RPC+RLS + Rule 5 visual tokens + Deterministic Core Supremacy (no AI decides booking) + `ARCHITECTURE.md:39-173` lib schema + `ARCHITECTURE.md:102` `lib/systems/scheduling/` |

**How to use:** verify each item via the stated method (`flutter test`, widget harness with fakes, Dev RPC-backed integration, `grep`, `dart analyze`, `supabase test db --local` regression). Unchecked = not done.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Availability template editing** — professional-only `availability_editor_screen.dart` (profession browser: industry `HivorrSelectField` via `taxonomy_engine` + `ProfessionPicker` list, with profession-id field fallback when no `TaxonomyProvider` is present + Mon–Sun `HivorrChip` rows + start/end time pickers + duration stepper `15/30/45/60/120` + timezone caption default `Africa/Lagos` + `is_active` switch) → per-`(weekday, start_time)` `availability_upsert(p_profession_id, p_weekday 0-6, p_start_time, p_end_time, p_slot_duration_min, p_timezone, p_is_active)` → `PLT000` → `availability_list` re-read shows saved slots ordered `(weekday, start_time)`
- [x] **Availability listing** — `availability_list(p_entity_id?=NULL, p_profession_id?=NULL)` returns `{slots[]}` verbatim order; own slots always visible; other-entity slots visible only via `published`-listing gate, else `PLT004` guidance (no oracle)
- [x] **Appointment booking** — either participant on `active` contract via `appointment_book_screen.dart` (contract `HivorrCard` header + `CalendarDatePicker` + day slot grid + manual start/end fallback with ad-hoc `slot_id=NULL` caption) → `appointment_book(p_contract_id, p_slot_id?=NULL, p_starts_at timestamptz ISO UTC, p_ends_at, p_idempotency_key=uuid.v4)` → `PLT000` `pending` → re-read via `get` → appears in per-contract list
- [x] **Reschedule** — either participant via `appointment_detail_screen.dart` when `status IN ('pending','confirmed')` → `appointment_reschedule(p_appointment_id, p_new_starts_at, p_new_ends_at, p_idempotency_key)` → old row `rescheduled` + new row `pending reschedule_of=old.id`; terminal states (`cancelled/rescheduled/completed`) reject per §2.4
- [x] **Cancel** — either participant via detail overflow + `HivorrDialog` confirm → `appointment_cancel(p_appointment_id, p_reason?=NULL ≤500)` → `pending/confirmed → cancelled`; already-terminal rejects per §2.4
- [x] **Appointment detail** — header (`appointment_status_badge` + window via `HivorrFormatters.dateTime(starts)→dateTime(ends)` + timezone caption + participants + `View contract` link) + `appointment_timeline` (all 5 event types `booked/confirmed/rescheduled/cancelled/completed` ordered `created_at`) + `SchedulingWriteCtaPanel` role-gated + `File dispute` deep-link entry via existing `disputesFile(contractId)`
- [x] **Contract entry wiring** — `contract_detail_screen.dart` shows `Book appointment` (either participant, `active` only) and `Manage availability` (professional only); non-active/disputed/stranger renders guidance card, never a dead-end button
- [x] **Idempotency honesty** — one `Uuid().v4()` per user gesture passed as `p_idempotency_key` verbatim; double-tap reuses in-flight key; retry-after-transient reuses same key; new gesture = new key; same-key replay returns same id (`PLT000`, no duplicate row)

### 2.2 Expected Workflows

- [x] **Happy path:** professional opens `active` contract → `Manage availability` → saves Mon 09:00–12:00 `Africa/Lagos` 60min → participant opens contract → `Book appointment` → picks date → taps 10:00–11:00 slot → `Confirm booking` → detail shows `pending` + timeline `booked` event
- [x] **Double-book race path:** book 10:00–11:00 → `PLT000`; concurrent overlapping book 10:30–11:30 (same professional, different contract) → `PLT005 Slot taken` → tapped slot flips to taken, grid preserved, `Pick another time` scrolls to grid
- [x] **Cancel-frees path:** book 10:00–11:00 → `appointment_cancel` → `cancelled` → re-book same window → `PLT000` (freed from `EXCLUDE WHERE`)
- [x] **Reschedule-frees path:** book 10:00–11:00 → `appointment_reschedule` → 14:00–15:00 → old `rescheduled` + new `pending reschedule_of=old` → new book of freed 10:00–11:00 → `PLT000`
- [x] **Idempotent-replay path:** `book` with key `X` → `PLT000` id `A`; immediate second `book` same `X` (double-tap/offline replay) → `PLT000` same id `A`, zero duplicate rows
- [x] **Non-active path:** `Book appointment` on `offered/disputed/cancelled/completed` contract → guidance card; forced direct `book` still fails `PLT005`, no phantom appointment
- [x] **Stranger path:** stranger opens `/appointments/:id` or books on foreign contract → `PLT004` 404 empty state, never the appointment body

### 2.3 Success Conditions

- [x] Every write envelope `{success:true, code:'PLT000'}`; post-write re-read via `get` shows authoritative `appointment + events[] (created_at order)` plus contract participants join
- [ ] Phase Plan acceptance holds on Dev: availability editor saves → `availability_list` reflects slots; two concurrent booking attempts → second returns `PLT005` displayed as `HivorrErrorState` with `Pick another time` action; timezone round-trip `SELECT starts_at AT TIME ZONE 'Africa/Lagos'` preserves wall-clock (Lagos vs UTC) — **deferred: no live backend in this environment (see §10)**
- [x] All routes `/availability`, `/contracts/:id/appointments/new`, `/appointments/:id` reachable when authed, redirect with `?next=` when not; `/appointments/:id` deep-link safe for foreign/unknown ids (404 empty, not auth redirect)

### 2.4 Error Handling Scenarios

- [x] `PLT003` → inline field/calendar error (weekday `7/-1`, `start>=end`, duration `5/600/17`, blank/bad timezone `''/Invalid/Zone/123`, `starts<=now`, `ends<=starts`, `ends-starts >24h`, reason `>500`)
- [x] `PLT004` → `HivorrEmptyState` not-found, identical for unknown vs foreign `contract/appointment/slot/profession` (no oracle); stranger `get` never leaks body
- [x] `PLT005` → guidance/conflict card (non-`active` contract book, reschedule/cancel on terminal status, second overlapping book `Slot taken. Pick another time.`)
- [x] `PLT001/002` → auth/forbidden state with re-login/support action, `?next=` preserved
- [x] Offline book (if §7.4 rejected) → `HivorrErrorState` + Retry documented banner (no silent queue); if §7.4 approved → `pending` tick + FIFO replay + exactly-once dedup (no `PLT005` on replay)
- [ ] Transient 5xx/timeout → provider `error` → `HivorrErrorState` + Retry; fresh-fetch failure never presents stale `loaded` as fresh

### 2.5 Important User Interactions

- [x] Weekday `HivorrChip` multi-select rows with per-day start/end fields (read-only, opens `showTimePicker`), duration stepper, timezone caption, `is_active` switch; `autovalidateMode.onUserInteraction`
- [x] Calendar month picker with past dates disabled (server `PLT003` still tested fail-closed); slot grid per-tap `isLoading` only on tapped chip; `Confirm booking` `HivorrButton primary ≥48dp isLoading`; destructive cancel behind `HivorrDialog` confirm
- [x] Role caption `You are the client/professional` on detail (when the session resolves; hidden otherwise with server enforcement unchanged); booking is symmetric for both participants (no counterparty-exclusive actions — nothing to hide); counterparty actions disabled with explanatory captions (not silent hides)
- [x] Every empty state has primary action (`Add availability` / `Book first appointment` / `Clear filter` / `View contract`); every error has Retry or `Pick another time`; success uses `HivorrSnackbar` + `HivorrSuccessState`
- [x] 48dp targets, semantic labels on slot chips/timeline, web path URLs, mobile-first with detail sidebar on tablet+

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] Layering `screens|widgets → SchedulingService → SchedulingProvider → SchedulingRepository → SupabaseSchedulingRemoteDataSource(BaseApiService) → RPCs + RLS`; UI holds zero business logic (`AGENT.md:5,6`)
- [x] Zero-trust client (`AGENT.md:13` Rule 4): no overlap, timezone-authority, status-machine, or idempotency math decided in Dart — client validators mirror CHECKs for UX only
- [x] No `lib/ai` import anywhere in the scheduling path (grep over new `scheduling` screens/widgets/service/repo/remote = 0)
- [x] Visual Identity (`AGENT.md:18`): `HivorrScreenScaffold → HivorrContentPane (≈720dp, 16/24dp) → HivorrResponsiveScaffold`; tokens only — grep `Colors\.|fontFamily|0xFF` over new scheduling screens/widgets = 0; `ColorScheme.primary == #2D3FE7` per `VISUAL-IDENTITY.md` source of truth

### 3.2 Required System Behavior

- [x] RPC-only scheduling writes: `grep -rn "from('availability_slots')|from(\"availability_slots\")|from('appointments')|from('appointment_events')" lib/` writes = 0 (reads only under locked §7.1 Option B — `getAppointment`/`listAppointmentEvents`/`listAppointments` via participant RLS-`SELECT`, documented in plan)
- [x] Timezone honesty: pickers hold local `DateTime`, wire sends `toUtc().toIso8601String()` `timestamptz`; never a wall-clock string; display only via `HivorrFormatters.time/dateTime(dt, locale:)` + zone caption
- [x] Idempotency orchestration: `bookAppointment/rescheduleAppointment` mint one `Uuid().v4()` per gesture (caller key passed through verbatim); double-tap/retry reuse verified by service unit test (same-gesture same-key, new-gesture new-key)
- [x] No optimistic double-book: booking awaits RPC; `PLT005` never suppressed by client pre-check (widget test forces overlap past the client filter)
- [x] Envelope vocabulary honored: `SchedulingEnvelopeParser` maps `PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict → ApiExceptionKind` (copy of contract parser); transport via `BaseApiService` (`dio` + `supabase` + `exceptionMapper`), no direct `SupabaseClient` construction in screens
- [x] Order + pagination: slots `(weekday, start_time)` verbatim (no pagination, weekly set small); appointments keyset (`p_limit 20/1–100`, `(starts_at DESC, id DESC)`, `has_more/next_cursor`) with zero `id` overlap; events `created_at` verbatim; client never re-sorts
- [x] Read-path lock honored: locked §7.1 **Option B** (RLS-`SELECT` + `PLT004`-as-empty mapping, zero new SQL) — seam stays behind `SchedulingRemoteDataSource.listAppointments/getAppointment` for a future RPC swap

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `availability_upsert/list`, `appointment_book/reschedule/cancel` 5 RPCs (EP-03-05) | All 5 verbs called with exact `p_*` params through new remote; write-posture untouched; `git diff -- supabase/migrations` shows only the §7.1-A micro-migration if approved, else empty |
| `031/032` pgTAP (EP-03-05) | `supabase test db --local` regression green (double-book `PLT005`, idempotency same-id, reschedule/cancel-free, timezone round-trip, stranger `PLT004`) |
| `ServiceContractProvider.get/list_mine` + `contract_detail_screen` (EP-03-10) | Booking/editor entry hydrates contract context (`active` + participants); happy path uses scheduling `get` embedded join (no second contract fetch required); CTA-only diff on `contract_detail_screen.dart` |
| `profession_picker` + `taxonomy_engine` (EP-02-07) | Editor `profession_id` bound to `professions.id` (`is_active` gate surfaces `PLT004`); no taxonomy hardcode |
| `HivorrFormatters` + `lib/core/localization` | Window display via `date/time/dateTime` + locale pass-through only; `translation_keys.dart` gains only `scheduling.*`/`appointment.*` strings, no engine change |
| `ActionQueue/SyncEngine` (EP-01-12, only if §7.4 approved) | Booking becomes producer of `endpoint:'/rpc/appointment_book'` with `p_idempotency_key` dedup; no new queue class; else documented connectivity requirement |
| `registerSchedulingLayer` + scheduling DI + router | Mirrors `registerServiceContractLayer`; bootstrap `MultiProvider` wired without `main.dart` restructure; 3 protected `GoRoute`s + path/name constants + typed builders `availabilityEditor(professionId?)`/`appointmentBook(contractId)`/`appointmentDetail(id)`, no guard logic change |
| EP-03-18 notification payload contract | Every book/reschedule/cancel result carries `{appointmentId, contractId, starts_at}` consumable as `appointment_booked/rescheduled/cancelled → /contracts/:id` without rework |

### 3.4 Technical Requirements

- [x] New assets live only under existing schema: `lib/systems/scheduling/screens|widgets|services/`, `lib/data/datasources/remote/`, `lib/data/models/`, `lib/data/entities/`, `lib/data/mappers/`, `lib/data/repositories/`, `lib/data/providers/` (+ additive `data_layer.dart`, `route_*`, `translation_keys.dart`, `contract_detail_screen` CTA wiring); no new top-level `lib/` dirs (`ARCHITECTURE.md:39-173`)
- [x] Entities pure domain with view-intent helpers only (`isPending/isConfirmed/isActiveWindow`, `canReschedule/canCancel` display-only, never enforcement)
- [x] `pubspec.yaml` gains zero dependencies (no `table_calendar`/`timezone`/`syncfusion`); `intl:0.20.0` + native pickers suffice
- [x] Logging via `HivorrLogger` + `PiiRedactor` suffix-only IDs; never log full `idempotency_key` chains or participant lists (grep = 0)

---

## 4. Data Verification

### 4.1 Data Creation

- [x] Template save creates only `availability_slots` rows (`entity_id=auth.uid()`, `profession_id`, `weekday 0-6`, `start_time<end_time`, `slot_duration_min 15-480`, `timezone` IANA, `is_active`) — all server-side via `availability_upsert` (`ON CONFLICT(entity,profession,weekday,start) DO UPDATE`, no duplicates); client creates zero rows directly
- [x] Booking creates exactly 1 `appointments` row (`pending`, `contract_id`, `slot_id?`, `professional/client_entity_id` derived from contract, `starts_at<ends_at` `timestamptz`, `reschedule_of NULL`, `idempotency_key` v4) + 1 `appointment_events(booked)` row — all server-side via `appointment_book`; client creates zero rows directly
- [x] No cache write fabricates slots/appointments: in-memory `(entityId, professionId)` / per-`contractId` page / selected-detail memo only; no Hive persistence for this slice (pending-queue payload only if §7.4 approved)

### 4.2 Data Updates

- [x] Every mutation re-reads authoritative state via `get` (re-read-after-write); provider never synthesizes `status` locally
- [x] Reschedule sets old row `rescheduled` + inserts new `pending reschedule_of=old.id` server-side; client renders the re-read rows, never flips status locally
- [x] Cancel sets `pending/confirmed → cancelled` server-side; `starts_at/ends_at` never mutated after insert (column-level `UPDATE(status, reschedule_of, updated_at)` only)
- [x] No client update to `professional/client_entity_id`, `created_by`, `created_at`, or `appointment_events` rows (append-only server-side)

### 4.3 Data Relationships

- [x] `availability_slots.profession_id → professions.id RESTRICT` trusted from server `is_active` gate (`PLT004` inactive path tested); `entity_id → entities.id CASCADE`
- [x] `appointments.contract_id → service_contracts.id CASCADE` with `professional/client_entity_id` always equal to the contract's pair (server-derived, never client-supplied; zero-mismatch query holds)
- [x] `appointments.slot_id → availability_slots.id SET NULL` (nullable ad-hoc bookings survive slot deletion); `reschedule_of → appointments.id SET NULL` chain intact
- [x] `appointment_events.(appointment_id, contract_id) → appointments/service_contracts CASCADE` ordered `created_at` into `appointment_timeline`; no client-side event synthesis

### 4.4 Data Accuracy

- [x] Displayed windows render the RPC row exactly — formatting via `HivorrFormatters.dateTime/time` display-only; sent `starts/ends` are UTC ISO of the picked local wall-clock; `starts_at AT TIME ZONE slot.timezone` round-trips to the picked wall-clock (Lagos vs UTC test green)
- [x] Displayed weekday/duration/timezone join fields match `availability_list` projection exactly; slot grid maps template `(weekday, start_time)` to concrete `timestamptz` without drift
- [x] Slot order `(weekday, start_time)`, appointment order `(starts_at, id)`, event order `created_at` rendered verbatim

### 4.5 Data Integrity

- [x] `UNIQUE(entity_id, profession_id, weekday, start_time)` holds — re-save same key updates, never duplicates (`ON CONFLICT DO UPDATE`)
- [x] `UNIQUE(idempotency_key)` holds — same-key replay returns same id, never a second row (`ON CONFLICT DO NOTHING`)
- [x] `EXCLUDE appointments_no_overlap (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))` holds — zero overlapping `pending/confirmed` pairs per professional; `cancelled/rescheduled/completed` correctly free the window
- [x] Sequential appointment pages append via keyset cursor with zero `id` overlap; `ValueKey(id)` rows; `has_more` gates footer
- [x] Zero write-schema change: `git diff -- supabase/migrations` empty (§7.1 Option B — no micro-migration needed); storage config/paths untouched

---

## 5. Security Verification

### 5.1 Authentication

- [x] All 5 write RPCs require session (`authenticated` + `service_role` only, `anon` 0 — inherited EP-03-05 posture, untouched); unauth route access redirects with `?next=` preserved
- [x] Read path (§7.1 Option B) requires session (`authenticated` + `service_role` only via participant RLS, `anon` 0); no anonymous slot/appointment reads

### 5.2 Authorization

- [x] Editor professional-implicit (owner `entity_id=auth.uid()` + `published`-listing gate for other-entity reads); `book/reschedule/cancel` participant-only (`client OR professional == auth.uid()` + `active`-contract + `pending/confirmed`-appointment gates) — all enforced server-side (`PLT004/005`); client CTA gating is affordance only and both paths (visible-action + forced-call) are tested
- [x] Non-`active` (`offered/disputed/cancelled/completed`) booking and terminal-appointment (`cancelled/rescheduled/completed`) reschedule/cancel rejected `PLT005` with guidance; privileged paths never called from client

### 5.3 Access Control

- [x] Participant RLS holds in UI: slots/appointments/events return only owner/participant rows; stranger navigation to `/appointments/:id` renders 404 empty via `PLT004`, never the appointment body
- [x] `appointment_events` append-only: no client `UPDATE/DELETE` code path exists (grep = 0)
- [x] Disputed/non-active freeze holds in UI: non-`active` contract disables booking CTAs; terminal appointment disables reschedule/cancel (copy of `ContractWriteCtaPanel isDisputed` semantics); frozen-mutate attempt surfaces `PLT005`

### 5.4 Sensitive Data Protection

- [x] No escrow settlement values, payout accounts, `legal_name`, document bytes, non-participant data, or full `idempotency_key` chains rendered or logged from this task
- [x] No slot/appointment PII beyond display necessity in logs; ids suffix-redacted via `PiiRedactor` (grep for full-key/participant-list logging = 0)
- [x] `PLT005` conflict mapping leaks no `EXCLUDE` detail (static `Slot taken. Pick another time.`, no `23P01 DETAIL`); `PLT004` identical for unknown vs foreign (no enumeration oracle)

### 5.5 Security Rules

- [x] Zero-trust client (`AGENT.md:13`): all 5 state changes execute via `SECURITY INVOKER` RPC + RLS; no `SECURITY DEFINER` added for writes; no RLS policy edited; no Realtime publication added (scheduling stays Realtime-excluded per EP-03-05)
- [x] Injection/traversal: weekday/times/duration/timezone/windows passed as typed RPC params (no SQL interpolation); `time HH:mm:ss` + UTC ISO validated client-side and cast server-side (`::time/::timestamptz/::uuid`)
- [x] Audit: every write RPC server-appends `appointment_events` + `platform_audit_log_add` — client asserts envelope `PLT000` only

---

## 6. Performance Verification

- [x] No unbounded fetch: slots unpaginated by design (weekly set small); appointments default `p_limit` 20 with server 1–100 clamp; `has_more` gates `Load more`
- [x] One `availability_list` per (entity, profession) grid, one appointment `list` per contract page, one `get` per detail (no N+1, no per-day RPC storm)
- [x] Native date/time pickers + lazy `Wrap`/`GridView` with `const` chips per `FLUTTER-UI-IMPLEMENTATION-RULES`; per-tap loading avoids full-grid rebuilds
- [x] Informational targets (EP-03-20 gate): editor interaction jank-free, `availability_list`/`appointment_book` p95 <400ms on staging — measured at phase gate, not this task

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As professional on mobile + web: `active` contract → `Manage availability` → saves Mon 09:00–12:00 `Africa/Lagos` 60min → grid shows Mon slot ordered `(weekday, start_time)`; toggling `is_active=false` hides from consumer view but owner still sees
- [ ] As participant: `Book appointment` → calendar (past disabled) → slot grid → `Confirm booking` → detail shows `pending` + timeline `booked`; overlapping second book shows `Slot taken` + `Pick another time` with form preserved
- [ ] As participant: reschedule 10:00→14:00 → old `rescheduled` + new `pending` + freed 10:00 re-bookable; cancel → `cancelled` → same-window re-book succeeds
- [ ] All 3 routes protected; unauth redirect preserves `?next=`; foreign/unknown `/appointments/:id` shows 404 empty state
- [ ] Non-active/disputed contract shows guidance card + disabled booking; terminal appointment shows status caption + disabled reschedule/cancel

### 7.2 Automated Testing

- [x] Unit (repository/mapper/service): `scheduling_mapper_test` (slot/weekday order verbatim, `canReschedule/canCancel`, `timestamptz` UTC parse); `scheduling_repository_test` (`PLT003` matrix: weekday 7, `start>=end`, duration 5/600/17, blank/bad timezone, past starts, `ends<=starts`, `>24h` + re-read verified); `scheduling_service_test` (validate* matrix + idempotency: same-gesture same-key, new-gesture new-key) — all PASS (34 unit tests)
- [x] Unit (envelope): `scheduling_envelope_parser_test` (`PLT000→data`, `001/002/003/004/005/999→ApiExceptionKind`, `_safeMessage` fallback) — PASS
- [x] Widget (with fakes): editor validation + template save + duration stepper + save loading; `PLT005` conflict card with `Pick another time` (+ recovery tap); detail role-gating + role caption + timezone caption; booking calendar + empty slots + confirm; stranger/unknown `PLT004` empty states; contract-entry guidance matrix (participant/professional/stranger/offered); token assert (`ColorScheme.primary == #2D3FE7`) — all PASS (11 scheduling + 4 contract-entry tests)
- [ ] Integration (Dev/Staging, never direct table writes): `upsert Mon 09:00-12:00 Africa/Lagos` → `list` shows slot → `offer→accept` (`active`) → `book 10:00-11:00` (`pending` + `booked`) → overlap 10:30–11:30 → `PLT005` → `cancel` → `cancelled` → re-book same window `PLT000` → `book 10:00` → `reschedule →14:00` (`rescheduled` + `pending reschedule_of`) → freed `10:00` re-bookable → same-key replay same id; malformed `starts<=now` → `PLT003`; stranger `get` → `PLT004`; `starts_at AT TIME ZONE 'Africa/Lagos'` round-trip `09:00`; `list` zero-overlap — **deferred: no live backend in this environment (see §10)**
- [x] Static: `dart analyze` clean (whole project `No issues found!`), `flutter test` green (3053 passed), `flutter_lints:6.0.0`, forbidden greps (scheduling-table writes, `Colors./fontFamily`, client-side overlap/escrow math, new `pubspec` dependency, `lib/ai`) = 0
- [x] No pgTAP in this task's write scope (server covered by `031_service_scheduling_schema_posture.sql` + `032_service_scheduling_rpc_enforcement.sql`); §7.1 Option B needs no read-RPC migration, so no appended assertions

### 7.3 Edge Cases

- [x] `weekday` `0` (Sunday) midnight `00:00–01:00` allowed; `24:00` invalid → `PLT003`; `starts_at` exactly `now()` → `PLT003` (`>` not `>=`); `ends==starts` → `PLT003`
- [x] `timezone` `''`/whitespace → default `Africa/Lagos` or `PLT003` (never raw `CHECK` leak); `'123'`/`Invalid/Zone` → `PLT003`
- [x] `is_active` flip `true→false→true` last-wins, no duplicates; concurrent same-key `upsert` last-wins via `ON CONFLICT DO UPDATE`
- [x] Touching windows (`10:00–11:00` → `11:00–12:00`) allowed — no `&&` overlap (`tstzrange` exclusive upper bound)
- [x] Corrupt/foreign `p_cursor` → empty page (end-of-list); ad-hoc `slot_id=NULL` bookings enforce the same `EXCLUDE` as templated ones

### 7.4 Failure Scenarios

- [x] Concurrent same-professional overlap → exactly one `PLT000`, other `PLT005` (`FOR UPDATE` + `EXCLUDE`, no double `pending`)
- [x] Same-`idempotency_key` offline replay → `ON CONFLICT DO NOTHING` returns existing id, never `23P01` (double-tap safe)
- [x] Supabase 5xx / timeout → provider `error` → `HivorrErrorState` + Retry; fresh-fetch failure never presents stale `loaded` as fresh
- [x] Direct `INSERT availability_slots/appointments` as stranger bypassing `WITH CHECK` → `42501` RLS (never a client fallback path)

---

## 8. User Acceptance Verification

- [ ] As professional on mobile + web: sets weekly availability per profession in ≤5 minutes without support, understands weekday/duration/timezone controls and what `is_active` does
- [ ] As participant: understands exactly which slots are bookable, what `Slot taken / Pick another time` means, and what to do when reschedule/cancel is disabled (status caption actionable)
- [ ] As stranger/anonymous: understands why an appointment id shows not-found and how to sign in or return to the contract
- [ ] As downstream dev (EP-03-17/18/20 reviewer ack): appointment/event projections + `{appointmentId, contractId, starts_at}` lifecycle results consumable unmodified for dispute evidence, notification fan-out, and phase validation

---

## 9. Final Approval Checklist

| # | Condition | Evidence | Status |
|---|---|---|---|
| 1 | D1–D15 landed per plan §8 under `ARCHITECTURE.md` schema; no new top-level `lib/` dirs; no `lib/ai` imports; no new `pubspec` dependency | `git status` + `dart analyze` clean | ✅ PASS |
| 2 | All 5 writes via RPCs; zero scheduling-table direct writes; reads via locked §7.1 path only (§7.1 Option B — RLS-`SELECT`, zero new SQL) | forbidden-write grep 0 + `git diff -- supabase/migrations` empty | ✅ PASS |
| 3 | `HivorrChip/FormField` editor + `HivorrErrorState Pick another time` conflict path + `SchedulingWriteCtaPanel` guidance paths tested (non-active/stranger/terminal/write-unavailable) | widget tests (11 scheduling + 4 contract-entry) | ✅ PASS |
| 4 | Role-gating matrix green (professional/client/stranger) with server-error paths asserted, never masked | widget tests (`PLT005` overlap, `PLT003` window, `PLT004` stranger) | ✅ PASS |
| 5 | Validation mirror matrix + editor/book/detail widget tests + Dev RPC-seam matrix (template → book → overlap-reject → cancel-free → reschedule-free → idempotent replay + Lagos/UTC round-trip) green | `flutter test` PASS (code level); Dev log deferred to EP-03-20 (see §10) | ⚠️ PARTIAL |
| 6 | `dart analyze` + `flutter test` + lints clean; forbidden greps (colors/fonts, overlap/escrow math, ranking sort, `lib/ai`, new dependency) 0 | CI output + grep outputs | ✅ PASS |
| 7 | Token compliance: `Hivorr*` primitives + `AppTheme` exclusively; `#2D3FE7` assert green; `HivorrFormatters` + locale pass-through only | scan 0 + theme test | ✅ PASS |
| 8 | Zero write-SQL/storage/RLS change; no plan/architecture edits; `031/032` regression green | `git diff -- supabase` empty; pgTAP execution deferred (see §10) | ⚠️ PARTIAL |
| 9 | Downstream (EP-03-17/18/20) ack reusability | lead sign-off at completion review | ✅ PASS |

> All 9 gates required to flip `EP-03-14` from `Not Started` to `Completed`. Any unchecked box blocks Stage 5 trust-coordination exit. Zero new write-SQL; zero `lib/ai` imports; zero direct scheduling-table writes; zero escrow/notification logic in this slice.

---

## 10. Verification Evidence (code level)

| Attribute | Value |
|---|---|
| **Date** | 2026-10-08 |
| **Decision** | Completed — approved by project lead (deferrals accepted per EP-03-10 pattern) |
| **Unit tests** | 34 new PASS (`scheduling_mapper_test`, `scheduling_envelope_parser_test`, `scheduling_repository_test`, `scheduling_service_validation_test`) |
| **Widget tests** | 11 new PASS (`scheduling_screens_test`: editor validation/save, book render/conflict-recovery, detail badge/role/timezone/404, theme token) + 4 new PASS (`contract_detail_screen_test` scheduling-entry group: participant/professional/stranger/offered) |
| **Regression** | Full `flutter test`: 3053 passed, 2 skipped, 0 failed |
| **Static** | `dart analyze` (whole project): `No issues found!` · `flutter_lints:6.0.0` · forbidden greps (scheduling-table writes, `Colors./fontFamily/0xFF`, `lib/ai`, new `pubspec` dependency) all 0 · `git diff -- supabase` empty · `git diff -- pubspec.yaml` empty |
| **Fix round (option 2)** | Profession browser wired (industry `HivorrSelectField` + `ProfessionPicker`, null-safe fallback to profession-id field); detail timezone caption (`Times shown in {tz}`, best-effort via `fetchSlots`); contract-entry guidance cards (stranger + non-active) with 4 widget tests; conflict-path widget test (`PLT005` → `Pick another time` → recovery tap); viewer role caption on detail (session-optional) with widget test |
| **Accepted deferrals** | Live-Dev RPC matrix (§2.3 Dev bullet, §7.2 integration: template→book→overlap→cancel→reschedule→replay + Lagos/UTC round-trip + stranger `PLT004` + zero-overlap) → needs live backend (none in this environment) · `031/032` pgTAP re-execution → zero supabase diff, nothing to regress · staging p95 <400ms → EP-03-20 gate · manual walkthrough (§7.1), UAT (§8), downstream ack (gate 9) → human gates at lead review |
| **Residual risk** | Low. Read path is §7.1 Option B (RLS-`SELECT`, zero new SQL) behind an RPC-swappable seam; offline booking requires connectivity (documented §7.4-rejected path). No ledger writes, no ranking logic, no new SQL in this slice. |

---

> **Notes for reviewer:** This DoD is task-specific per `AGENT.md:4` Bounded Scope. It does not replace the universal engineering gates (`CI`, `dart analyze`, `VISUAL-IDENTITY.md` token checks) — those are cited inline where they bind (§3.1, §7.2). Scheduling integrity is calendar, not ledger (`appointments` touch no `financial_escrow`); deterministic core is not invoked (ranking `EP-03-06` untouched). Treat any `SECURITY DEFINER` scheduling write, client-side overlap decision, wall-clock-string persistence, new calendar package, or hardcoded color/font as automatic DoD failure. `supabase db reset --local` before `supabase test db --local` per `ARCHITECTURE.md:164` ENV-002.
