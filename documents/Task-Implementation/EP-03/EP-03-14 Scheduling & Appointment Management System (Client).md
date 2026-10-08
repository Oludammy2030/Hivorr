# Task Implementation Plan — EP-03-14: Scheduling & Appointment Management System (Client)

**Task ID:** EP-03-14 | **Priority:** High | **Status:** Completed | **Phase:** EP-03 Stage 5 — Trust & Coordination (parallelizable after contracts exist)
**Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:389-398` (§EP-03-14) + `§6 Stage 5`, `§7 deps (EP-03-05, EP-03-10)`, `§8 Risks:180` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-178` + `documents/Context/VISUAL-IDENTITY.md` + `documents/Context/FLUTTER-UI-IMPLEMENTATION-RULES.md`
**Plan Mode:** Planning artifact only. No production code. No Phase doc mutation. Awaiting approval before implementation.

---

## 1. Task Objective

Build the **client-side, unprivileged presentation layer** for contract-bound scheduling on top of the completed EP-03-05 server fabric (`supabase/migrations/20260926090001_service_scheduling_schema.sql`, 813 lines: 3 tables + 5 `SECURITY INVOKER` RPCs + `EXCLUDE` + pgTAP `031/032`):

> Service `lib/systems/scheduling/services/scheduling_service.dart` + screens `availability_editor_screen.dart` (weekday slots editor via `HivorrChip` days + `HivorrFormField` time pickers), `appointment_book_screen.dart` (calendar + slot picker), `appointment_detail_screen.dart` (reschedule/cancel). Validates `starts_at/ends_at` in local TZ but stores `timestamptz`; conflict chip shows `Slot taken`. Uses `lib/shared/helpers/hivorr_formatters.dart` for time display and `lib/core/localization` for locale.

Success is: a professional edits a weekly template per profession → a contract participant books a concrete `timestamptz` window under an `active` contract → concurrent overlap returns `PLT005 Slot taken. Pick another time.` rendered as `HivorrErrorState` with `Pick another time` action → reschedule/cancel free the `EXCLUDE WHERE (status IN ('pending','confirmed'))` window for rebooking → double-tap/offline replay with the same `p_idempotency_key uuid v4` returns the same appointment id (`PLT000`, no duplicate) → Lagos-vs-UTC round-trips losslessly → all UI consumes `AppTheme` tokens.

Per `AGENT.md:5,6,13` (Separation of Concerns, Rule 4 Zero-Trust): **no availability math, overlap decision, timezone conversion authority, status machine, or idempotency logic decided in the client.** All authoritative checks stay server-side; client mirrors them only for fast UX feedback.

## 2. Business Problem Being Solved

EP-03-02 proved contracts, EP-03-05 proved `availability_slots` / `appointments (timestamptz + EXCLUDE)` / `appointment_events` + 5 RPCs, and EP-03-10 proved the contract client (`contract_offer/detail/milestone_editor`, `ContractService`, `ServiceContractProvider`). But **no usable client calendar exists**:

- `lib/systems/scheduling/.gitkeep` is the only file — empty. No `scheduling_service.dart`, no editor/book/detail screens, no `supabase_scheduling_remote_data_source.dart`, no `scheduling_repository.dart`, no `scheduling_provider.dart` (`glob lib/**/*schedul*|*appoint*` → 0 files; verified by two independent explore agents).
- No weekly-template editor — `availability_upsert/list` have no UI caller; `profession_id → professions.id` has no picker wiring.
- No booking flow — `appointment_book/reschedule/cancel` have no UI caller; `service_contracts.id` has no `Book appointment` entry from `contract_detail_screen.dart`.
- Only scheduling-adjacent client code is the discovery filter `ServiceSearchFilters.availabilityDate: DateTime?` (`lib/data/entities/service_listing.dart:154-249`, `discovery_filter_sheet.dart:122-527`, `client_find_service_screen.dart:572-579`) — a search filter, not a booking.
- Without this, discovery → contract never converts to a scheduled delivery, and escrow-funded contracts have no time anchor for `EP-03-17` dispute evidence or `EP-03-18` `appointment_booked/rescheduled/cancelled` notifications.

## 3. Scope

**In scope (exactly EP-03-14):**

1. Scheduling data slice over the 5 EP-03-05 RPCs: `availability_upsert`, `availability_list`, `appointment_book`, `appointment_reschedule`, `appointment_cancel` (+ read path decision in §7.1 — either 2 additive `STABLE` read RPCs `appointment_get/list_mine` or RLS-`SELECT`; no write-RPC change either way).
2. `SchedulingService` thin facade with static validators mirroring server CHECKs (`validateWeekday 0-6`, `validateTimeRange start<end`, `validateDuration 15-480 + %15`, `validateTimezone IANA`, `validateWindow starts>now, ends>starts, ≤24h`, `validateReason ≤500`).
3. Three screens + status/event widgets + DI (`registerSchedulingLayer()` in `lib/data/data_layer.dart` mirroring `registerServiceContractLayer`/`registerMessagingLayer`) + protected router routes.
4. Contract-detail entry wiring: `Book appointment` / `View appointments` CTA from `contract_detail_screen.dart` (participant-only, `active`-contract gate is UX only; server `PLT005` stays authoritative).
5. `HivorrFormatters.date/time/dateTime` display + `lib/core/localization` locale pass-through + `uuid v4` idempotency per booking attempt.
6. Unit + widget + RPC-seam integration tests (see §16). No pgTAP work (server already covered by `031/032` — must stay green).

## 4. Out of Scope

Explicitly **not** in EP-03-14 (deferred, no silent expansion):

- Any new table / constraint / index / RLS policy / trigger / bucket / `EXCLUDE` change — EP-03-05 reused verbatim (except the §7.1 read-RPC micro-decision, which is additive `STABLE` reads only, never a constraint/grant relaxation).
- Escrow fund/release (`EP-03-11`), review submit/reveal (`EP-03-12`), messaging thread (`EP-03-13` — only deep-link context, no thread fork), portfolio link (`EP-03-15`), earnings (`EP-03-16`), dispute filing (`EP-03-17` — only schedule-as-evidence read), notifications fan-out (`EP-03-18` — only payload contract `appointment_booked/rescheduled/cancelled → /contracts/:id`), public SEO (`EP-03-19`).
- `lib/ai/*` scheduling assistance or auto-slot suggestion (excluded from EP-03 per Phase Plan §5:106 + `AGENT.md:7` — AI never decides booking order/availability).
- Push-cron reminders / `notification_outbox` table / Edge Function `appointment_reminder` (EP-03-18 owns).
- New calendar package (`table_calendar`, `timezone`, `syncfusion`) — `pubspec.yaml` gains zero dependencies (EP-01-16 DoD precedent; `HivorrFormatters` + Flutter `showDatePicker/showTimePicker` + `intl:0.20.0` already present suffice).
- Admin moderation of slots/appointments (reuses EP-02-11 Admin shell if ever needed; no marketplace-embedded admin).

## 5. Existing Asset and Dependency Analysis

Inspected live codebase read-only (reuse-first mandate). `lib/systems/scheduling/` is a genuine gap; everything else below is reusable.

| Asset (exact path) | Status | Relevance to EP-03-14 |
|---|---|---|
| `supabase/migrations/20260926090001_service_scheduling_schema.sql` (3 tables, `btree_gist`, `EXCLUDE appointments_no_overlap`, 5 `SECURITY INVOKER` RPCs, envelope `PLT000/001/003/004/005/999`, Realtime-excluded) | **Reuse verbatim** | Canonical scheduling backend. `availability_upsert(p_profession_id, p_weekday, p_start_time, p_end_time, p_slot_duration_min=60, p_timezone='Africa/Lagos', p_is_active=true)`, `availability_list(p_entity_id=NULL, p_profession_id=NULL)`, `appointment_book(p_contract_id, p_slot_id=NULL, p_starts_at, p_ends_at, p_idempotency_key=gen_random_uuid())`, `appointment_reschedule(p_appointment_id, p_new_starts_at, p_new_ends_at, p_idempotency_key)`, `appointment_cancel(p_appointment_id, p_reason=NULL)`. `anon EXECUTE 0`. Zero new SQL for writes. |
| `supabase/tests/database/031_service_scheduling_schema_posture.sql` + `032_service_scheduling_rpc_enforcement.sql` | **Reuse (stay green, no new DB tests)** | Server enforcement already proven (double-book `PLT005 23P01`, idempotency same-id, reschedule/cancel free, timezone round-trip, stranger `PLT004` oracle). Client task adds no SQL except possibly §7.1 reads. |
| `lib/systems/scheduling/.gitkeep` | **Empty gap** | New home for `services/scheduling_service.dart`, `screens/*` (3), `widgets/*` (3-4), `scheduling.dart` barrel, `scheduling_dependency_injection.dart`. |
| `lib/systems/documents/*` (`contract_service.dart` 384 lines validators + storage-before-RPC + PII-safe logs + `PerformanceTracer`; `contract_list/detail/offer/milestone_editor` screens; `contract_status_badge/timeline/write_cta_panel` widgets; `documents_dependency_injection.dart`) | **Reuse pattern** | Closest template: service-facade shape, provider wiring, role-gated detail screen, timeline widget, CTA-panel-when-unavailable pattern. Contract-detail is the scheduling entry host. |
| `lib/data/datasources/remote/service_contract_remote_data_source.dart` + `supabase_service_contract_remote_data_source.dart` (`BaseApiService`, `_guard(mapDataException)`, `supabase.rpc('service_contract_*', p_*)`) + `service_contract_envelope_parser.dart` (`unwrap`, `PLT001→auth … 005→conflict`) | **Reuse pattern** | Template for new `SchedulingRemoteDataSource` + `SupabaseSchedulingRemoteDataSource` + `SchedulingEnvelopeParser` (identical envelope, identical `_guard`). |
| `lib/data/repositories/service_contract_repository{,_impl}.dart` (vocab `Set`, fail-fast `_require*` → `ApiException(PLT003/005)`, write-then-`get` re-read) | **Reuse pattern** | Template for new `SchedulingRepository(+Impl)` (fail-fast weekday/time/duration/timezone/window checks, no direct table writes). |
| `lib/data/providers/service_contract_provider.dart` (312 lines: `ChangeNotifier + WidgetsBindingObserver`, load/select/pagination, `lastError: ApiException?`, pause gate) | **Reuse pattern** | Template for new `SchedulingProvider` (slots list + appointments-per-contract list + selected detail + book/reschedule/cancel actions). Messaging provider's `ActionQueue` outbox is the offline reference if §7.4 is approved. |
| `lib/data/entities/service_contract.dart`, `contract_milestone.dart`, `contract_event.dart` + `lib/data/models/contract_envelopes_dto.dart`, `service_contract_dto.dart` + `lib/data/mappers/contract_mapper.dart` | **Reuse pattern** | Template for new `AvailabilitySlot`, `Appointment`, `AppointmentEvent`, `AppointmentPage` entities + `scheduling_dto.dart`/`scheduling_envelopes_dto.dart` + `scheduling_mapper.dart`. Pure domain, no I/O. |
| `lib/data/data_layer.dart` (`registerServiceContractLayer:803`, `registerMessagingLayer`, `registerDisputeLayer`) | **Extend (additive)** | Add `registerSchedulingLayer()` identical shape. No existing registration touched. |
| `lib/shared/*` (`hivorr_button/card/chip/badge/text_field/empty/error/loading/success_state/snackbar/divider/list_tile/section_header/select_field/form_field/dialog/bottom_sheet`, `layouts/hivorr_content_pane:720dp/screen_scaffold/responsive_scaffold/breakpoints`, `helpers/hivorr_formatters.dart:25-43 date/time/dateTime`, `helpers/hivorr_spacing.dart`, `validators/hivorr_validators`, `mixins/form_validation_mixin/loading_state_mixin`, `extensions/`) + `lib/app/theme/*` (`AppThemeExtension`, `RoleThemeExtension`, `ColorScheme`) | **Reuse verbatim** | Entire scheduling UI composed from tokens. Weekday editor = `HivorrChip` days + `HivorrFormField` time pickers (Phase Plan verbatim). Conflict = `HivorrErrorState + Pick another time`. No new primitives. Rule 5 binding. |
| `lib/app/router/route_paths.dart` (`contracts`, `contractDetail(id)`, `contractOfferFor`), `route_names.dart`, `app_router.dart`, `route_guard.dart` | **Extend (additive)** | Add scheduling routes + typed builders. No guard-logic change. |
| `lib/core/sync/action_queue.dart` + `sync_engine.dart` + `sync_action.dart` (`SyncAction{id: uuid.v4(), endpoint, priority}`) + `connectivity_plus_provider.dart` | **Reuse pattern (decision §7.4)** | `appointments.idempotency_key uuid UNIQUE + ON CONFLICT DO NOTHING` is already offline-replay-safe. If offline booking is approved, EP-03-14 becomes a producer of `endpoint:'/rpc/appointment_book'` actions (first scheduling caller; messaging `EP-03-13` is the pattern precedent). No new queue class. |
| `lib/core/localization/*` (`localization.dart` barrel, `translation_keys.dart`, `supported_locales.dart`, `localization_service.dart`) | **Reuse (pass-through)** | `HivorrFormatters.time(dt, locale: locale)` already accepts `locale`; `TranslationKeys` has zero scheduling keys — add ~10 keys (`scheduling.*`, `appointment.*`) only, no engine change. |
| `lib/core/notifications/*` (`notification_service.dart`, `local_notification_service.dart`, `supabase_push_receiver.dart`, `notification_channel_manager.dart`, `hivorr_notification.dart`) | **Reuse (payload contract only)** | EP-03-14 emits no notifications itself; it guarantees every book/reschedule/cancel result carries `{appointmentId, contractId, starts_at}` so EP-03-18 can fan out `appointment_booked/rescheduled/cancelled → /contracts/:id`. |
| `lib/systems/marketplace/screens/service_detail_screen.dart` + `discovery_filter_sheet.dart` (`availabilityDate` filter) + `profession_picker.dart` + `taxonomy_engine.dart` | **Reuse as context (extend CTA wiring only)** | Availability editor reuses `profession_picker` + `taxonomy_engine` for `profession_id`; booking entry reuses `ServiceListingService.getListing` context. Filter's `availabilityDate` display (`HivorrFormatters.date`) is the formatting precedent. |
| `test/support/fakes/*` (`fake_service_contract.dart`, `fake_supabase_storage.dart`, `fake_api/network/logging`) + `harnesses/widget_harness.dart`, `router_harness.dart`, `async_harness.dart` + `pubspec.yaml (supabase_flutter 2.17.2, connectivity_plus 6.1.0, uuid 4.5.1, hive 2.2.3, fake_async 1.3.1, intl 0.20.0)` | **Reuse + extend** | Add `fake_scheduling.dart` (`FakeSchedulingRepository/Remote` with counts + verbatim pages). No new packages. |

**Dependencies (must be available):** EP-03-05 (server — landed, `031/032` green), EP-03-10 (contract client — landed, entry host + `get/list_mine` context), EP-02-07 taxonomy engine + EP-02-08 storage-validators pattern (profession picker only), EP-01-07 (`ApiLayer`/`BaseApiService`), EP-01-15 (router), EP-01-16 (design system), EP-01-12 (sync, only if §7.4 approved), EP-01-18 (notifications payload contract).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed asset | Verdict | Why not the alternatives + future reuse |
|---|---|---|
| Server tables/RPCs/RLS/`EXCLUDE`/grants | **Reuse** — zero write-SQL change | Landed + pgTAP-covered. Parallel tables or client-side overlap math would violate Rule 4 and reintroduce the double-book race `EP-03:180` already closed server-side. |
| Appointment list reads (§7.1 gap: no `appointment_list_mine` RPC exists — confirmed `SELECT proname` → exactly 5 functions) | **Extend (minimal, read-only)** — add `appointment_get(p_appointment_id)` + `appointment_list_mine(p_contract_id?, p_status?, p_limit 1-100, p_cursor?)` as `STABLE SECURITY INVOKER` micro-migration **or** defer to RLS-`SELECT` with written justification | Reusing `availability_list` for appointments conflates weekly template with concrete bookings (domain separation, `ARCHITECTURE.md lib/systems/scheduling` vs listing taxonomy). Reusing `service_contract_get` projection would bloat the contract seam EP-03-11/12/13/17 already consume. New reads are participant-scoped, keyset-paginated, index-backed (`appointments_contract_idx`, `professional_starts_idx`), designed for EP-04 rider-window reuse. Decision locked at build kickoff; writes stay untouched either way. |
| `HivorrFormatters`, `HivorrChip/FormField/Error/Empty/LoadingState`, `HivorrContentPane/ResponsiveScaffold`, `profession_picker`, `RouteGuard`, `TranslationKeys` engine | **Reuse verbatim** | Fit for purpose as-is. Forking formatters/chips would duplicate the single time-render source of truth. |
| `ContractService` validators/logging/tracing → `SchedulingService` | **Extend (pattern copy, new file)** | Contract vocab (`milestone title/sum/currency`) is engagement-specific and must not be generalized in place (would break EP-03-10 semantics). New service copies the traced-facade + fail-fast-validator + PII-safe-log structure with scheduling vocab. |
| `ServiceContractEnvelopeParser/RepositoryImpl/Provider` → scheduling slice | **New (genuine gap)** — modeled line-for-line | No remote wraps the 5 scheduling RPCs; extending `ServiceContractRemoteDataSource` would conflate engagement lifecycle with calendar (domain separation). New slice owns the scheduling mirror. |
| Entities `AvailabilitySlot/Appointment/AppointmentEvent/Page` + DTOs + `scheduling_mapper.dart` | **New (genuine gap)** | No `lib/data/entities/*appointment*|*slot*` exists (glob confirms). `ContractMilestone` is fund-centric and cannot represent `tstzrange + idempotency_key + reschedule_of` without breaking EP-03-10. |
| Screens `availability_editor/appointment_book/appointment_detail` + `appointment_status_badge/appointment_timeline/scheduling_write_cta_panel/slot_picker_sheet` | **New (genuine gap)** — 100% composed from `shared/` | `lib/systems/scheduling/` is empty; `contract_detail_screen` is engagement-centric and cannot be generalized without breaking its contract. |
| `registerSchedulingLayer` + `scheduling.dart` barrel + router paths/names/routes | **Extend (additive)** | Follows `registerServiceContractLayer` / `route_paths` builder pattern. |
| `ActionQueue` offline booking | **Extend (wire, don't fork) — needs approval** | Generic queue has a messaging precedent (EP-03-13 design). Scheduling becomes second producer with `p_idempotency_key` as dedup key. No new queue class. If rejected, booking requires connectivity (documented limitation, messaging owns the queue pattern). |

No refactoring of existing assets recommended — all reused assets are fit for purpose as-is.

## 7. Recommended Technical Approach

Layering (`ARCHITECTURE.md lib/` schema + `AGENT.md` separation):

```
UI (lib/systems/scheduling/screens|widgets)
  → SchedulingService (validation mirror + idempotency orchestration: uuid-then-RPC)
  → SchedulingProvider (ChangeNotifier, slots + per-contract appointments, selection)
  → SchedulingRepository (entity-only, PLT003 fail-fast, re-read-after-write via get)
  → SupabaseSchedulingRemoteDataSource (BaseApiService, supabase.rpc, envelope unwrap)
  → Supabase RPCs (authoritative) + RLS
```

Key rules:

1. **RPC-only writes.** Never `from('availability_slots'/'appointments'/'appointment_events').insert/update`. Reads go through §7.1 path only.
2. **Timezone honesty:** client holds local `DateTime` for pickers, sends `timestamptz` ISO8601 UTC (`toUtc().toIso8601String()`); server stores `timestamptz`; display via `HivorrFormatters.time/dateTime(dt, locale: localeName)` + `starts_at AT TIME ZONE slot.timezone` round-trip asserted in tests. Never store wall-clock strings.
3. **Client validation mirrors, never replaces, server CHECKs:** weekday `0-6`, `start<end`, duration `15-480` (+ `%15==0` strict to match server if enforced), timezone non-blank + IANA-shaped (server checks `pg_timezone_names`), window `starts>now`, `ends>starts`, `ends-starts ≤24h`, reason `≤500`. Server re-checks everything (`PLT003/004/005`).
4. **Idempotency per attempt:** `SchedulingService.book()` generates `Uuid().v4()` once per user gesture, passes `p_idempotency_key` verbatim; double-tap reuses the in-flight key (no second UUID); retry-after-transient reuses the same key; new gesture = new key. Server `ON CONFLICT (idempotency_key) DO NOTHING` makes replay same-id.
5. **No optimistic double-book:** booking waits for RPC (calendar sensitivity); slot grid shows `isLoading` on the tapped slot only; `PLT005` never hidden by client pre-check.
6. **Role-gating from the authoritative contract row only:** editor visible to `professional_entity_id`; book visible to either participant when `contract.status=='active'`; reschedule/cancel visible when `appointment.status IN ('pending','confirmed')`; stranger/expired/disputed paths render guidance cards (copy `ContractWriteCtaPanel` structure), enforcement stays server-side (`PLT004/005`).
7. **Order preservation:** slots by `(weekday, start_time)` verbatim; appointments by `(starts_at, id)` verbatim; events by `created_at` verbatim; never re-sort.

### 7.1 Read-path decision (first build step — locks §8 D1/D2)

`appointment_book` returns a single row; there is **no** `appointment_get/list_mine` RPC (verified). Two options:

- **Option A (Recommended):** additive micro-migration `20260927090001_scheduling_read_rpcs.sql` with `appointment_get(p_appointment_id)` + `appointment_list_mine(p_contract_id DEFAULT NULL, p_status DEFAULT NULL, p_limit INT DEFAULT 20, p_cursor TIMESTAMPTZ DEFAULT NULL)` — both `STABLE SECURITY INVOKER`, participant-scoped (`EXISTS service_contracts`), keyset `(starts_at DESC, id DESC)`, `GRANT EXECUTE authenticated,service_role`, `anon 0`, plus 6-10 pgTAP assertions appended to `032` style. Cost: ~120 lines SQL + review. Benefit: RPC-only reads (Rule 4 purity), pagination parity with `list_mine`, index-backed (`appointments_contract_idx`), EP-04-reusable.
- **Option B (Fallback, zero SQL):** reads via `supabase.from('appointments').select()` + `from('appointment_events').select()` under existing participant `SELECT` RLS + client keyset (`limit 20`, cursor `(starts_at, id)`). Benefit: no migration. Cost: diverges from RPC-only pattern; client must replicate the `PLT004` no-oracle mapping (empty page, not error, for foreign/unknown).

Lock A vs B at build kickoff with the reviewer; the plan supports either without changing screens/providers (seam is behind `SchedulingRemoteDataSource.listAppointments/getAppointment`).

### 7.2 Availability editor flow

`contract_detail (professional) → Manage availability → availability_editor_screen (profession dropdown via profession_picker + Mon-Sun HivorrChip multi-row + start/end HivorrFormField time pickers + duration stepper 15/30/60 + timezone caption default Africa/Lagos + is_active toggle) → validate → availability_upsert per (weekday, start_time) key → availability_list re-read → provider replace`. `UNIQUE(entity,profession,weekday,start)` makes re-save idempotent (`ON CONFLICT DO UPDATE`).

### 7.3 Booking flow

`contract_detail (active contract) → Book appointment → appointment_book_screen (month calendar showDatePicker + day slot grid derived from availability_list mapped to concrete timestamptz + manual start/end fallback when slot_id NULL (ad-hoc) + idempotency-key issuance) → validate → appointment_book(p_contract_id, p_slot_id?, p_starts_at, p_ends_at, p_idempotency_key) → get re-read → provider prepend`. Overlap → `PLT005` → `HivorrErrorState` + `Pick another time` (scrolls to grid, preserves form).

### 7.4 Offline posture (needs approval)

If approved: offline/transient-failure `book` enqueues `SyncAction{type:create, endpoint:'/rpc/appointment_book', method:'POST', payload:{p_contract_id, p_slot_id, p_starts_at, p_ends_at, p_idempotency_key}, headers:{'Idempotency-Key': key}, priority:2}` persisted via `ActionQueue`; UI shows `pending`; `SyncEngine.drain` on `ConnectivityProvider.online` replays FIFO; `ON CONFLICT DO NOTHING` keeps exactly-once. If rejected: booking requires connectivity with a documented `HivorrErrorState + Retry` offline banner (messaging owns the queue proof).

### 7.5 Logging

`HivorrLogger` + `PiiRedactor` suffix-only IDs (copy `contract_service.dart`); never log slot times as PII beyond display necessity, never log `idempotency_key` full values in success paths beyond debug.

## 8. Required Systems, Modules, and Components

| # | Component | Location (new unless noted) | Notes |
|---|---|---|---|
| D1 | `SchedulingRemoteDataSource` (abstract) + `SupabaseSchedulingRemoteDataSource` + `SchedulingEnvelopeParser` | `lib/data/datasources/remote/scheduling_remote_data_source.dart`, `supabase_scheduling_remote_data_source.dart`, `scheduling_envelope_parser.dart` | 5 RPCs with exact `p_*` params + §7.1 reads; `_guard(mapDataException)`; copy of contract-remote shape |
| D2 | `AvailabilitySlotDto`, `AppointmentDto`, `AppointmentEventDto`, `AppointmentPageDto` | `lib/data/models/scheduling_dto.dart` (or split `availability_slot_dto.dart` / `appointment_dto.dart` / `appointment_event_dto.dart` mirroring `contract_*_dto.dart`) | Match `availability_list {slots[]}` + `appointment_book {appointment, contract_id}` + §7.1 page envelope; null-safe parsers; `timestamptz` ↔ `DateTime` UTC ISO |
| D3 | `AvailabilitySlot`, `Appointment`, `AppointmentEvent`, `AppointmentPage` entities + `scheduling_mapper.dart` | `lib/data/entities/availability_slot.dart`, `appointment.dart`, `appointment_event.dart` + `lib/data/mappers/scheduling_mapper.dart` | Pure domain; `isPending/isConfirmed/isActiveWindow`, `canReschedule/canCancel` view-intent helpers (display only, never enforcement) |
| D4 | `SchedulingRepository` + `SchedulingRepositoryImpl` | `lib/data/repositories/scheduling_repository.dart`, `scheduling_repository_impl.dart` | Entity-only; `_requireWeekday/_requireTimeRange/_requireDuration/_requireTimezone/_requireWindow` → `PLT003`; re-read via `get` after every write |
| D5 | `SchedulingProvider` | `lib/data/providers/scheduling_provider.dart` | `idle/loading/loaded/error`; `loadSlots(entityId?, professionId?)/loadAppointments(contractId)/loadMore()/select()/upsertSlot/book/reschedule/cancel/refresh`; `lastError: ApiException?`; pause gate copy |
| D6 | `SchedulingService` | `lib/systems/scheduling/services/scheduling_service.dart` | `weekdays/statuses/eventTypes` vocabs + static validators + `bookWithIdempotency/rescheduleWithIdempotency` orchestration + `weekdayLabel/slotLabel` display helpers via `HivorrFormatters` |
| D7 | Availability editor screen | `lib/systems/scheduling/screens/availability_editor_screen.dart` | Profession dropdown + weekday `HivorrChip` row + start/end time fields + duration stepper + timezone caption + `is_active` switch + `HivorrButton(isLoading)`; entry `/availability?professionId=` (professional) |
| D8 | Booking screen | `lib/systems/scheduling/screens/appointment_book_screen.dart` | Contract header + calendar + slot grid + manual window fallback + conflict `HivorrErrorState`; entry `/contracts/:id/appointments/new` |
| D9 | Detail screen | `lib/systems/scheduling/screens/appointment_detail_screen.dart` | Header (`appointment_status_badge` + window via `HivorrFormatters.dateTime` + participants) + `appointment_timeline` + `SchedulingWriteCtaPanel` (role-gated reschedule/cancel) |
| D10 | Widgets | `lib/systems/scheduling/widgets/appointment_status_badge.dart` (thin `HivorrBadge`), `appointment_timeline.dart`, `scheduling_write_cta_panel.dart`, `slot_picker_sheet.dart` (`HivorrBottomSheet`) | Pure display; tokens only |
| D11 | DI + barrel | Extend `lib/data/data_layer.dart` (`registerSchedulingLayer`); new `lib/systems/scheduling/scheduling.dart`, `scheduling_dependency_injection.dart` | Mirror contract/dispute DI |
| D12 | Router | Extend `route_paths.dart`, `route_names.dart`, `app_router.dart` | `/availability`, `/contracts/:id/appointments/new`, `/appointments/:id` (protected; `?next=` preserved); typed builders `availabilityEditor(professionId?)`, `appointmentBook(contractId)`, `appointmentDetail(id)` |
| D13 | Contract-detail CTA wiring | Extend `contract_detail_screen.dart` CTA only | `Book appointment` → `appointmentBook(contractId)`; `Manage availability` (professional) → `availabilityEditor`; non-active/disputed/stranger renders guidance card (UX only) |
| D14 | Localization keys | Extend `translation_keys.dart` (~10 keys) | `scheduling.*`, `appointment.*` strings only; no engine change |
| D15 | Test fakes | New `test/support/fakes/fake_scheduling.dart` | `FakeSchedulingRepository/Remote` with counts + verbatim pages |

## 9. Data Requirements

- **Entities:** `AvailabilitySlot{id, entityId, professionId, weekday 0-6, startTime TimeOfDay-as-String HH:mm, endTime, slotDurationMin, timezone, isActive}`, `Appointment{id, contractId, slotId?, professionalEntityId, clientEntityId, startsAt DateTime (UTC), endsAt, status: pending/confirmed/completed/cancelled/rescheduled, rescheduleOf?, idempotencyKey, createdAt}`, `AppointmentEvent{id, appointmentId, contractId, eventType: booked/confirmed/rescheduled/cancelled/completed, fromStatus?, toStatus?, actorId?, details, createdAt}`, `AppointmentPage{items, hasMore, nextCursor}`.
- **DTOs:** match `availability_list {slots[] ordered weekday,start_time}` and `appointment_book {appointment{…timestamptz ISO…}}` and §7.1 page envelope; `book` returns `{appointment, contract_id}`.
- **Enums/vocabs (client mirrors, server authoritative):** appointment `pending/confirmed/completed/cancelled/rescheduled`; event `booked/confirmed/rescheduled/cancelled/completed`; weekdays `0=Sunday…6=Saturday`; timezones default `Africa/Lagos` (IANA only).
- **Validation matrix (client pre-check → server RPC):** weekday `7/-1` → `PLT003`; `start>=end` → `PLT003`; duration `5/600` or `17 (%15)` → `PLT003`; timezone `''/Invalid/Zone/123` → `PLT003`; `contract NULL/unknown/foreign` → `PLT003`/`PLT004` (identical, no oracle); non-`active` (`offered/disputed/cancelled`) → `PLT005`; `starts<=now` / `ends<=starts` / `>24h` → `PLT003`; foreign `slot_id` → `PLT004`; stranger book/reschedule/cancel → `PLT004`; reschedule/cancel on `cancelled/completed/rescheduled` → `PLT005`; second overlapping book → `PLT005 Slot taken`.
- **Caching:** in-memory slots per `(entityId, professionId)` + appointments per `contractId` page + selected-detail memo with explicit `refresh/invalidate`; no Hive persistence for appointments (participant-scoped, short-lived; Hive thread-window precedent stays messaging-only unless §7.4 approved for pending-queue only).

## 10. Database Considerations

**No new tables, constraints, RLS, indexes, triggers, or bucket policies.** EP-03-05 is the complete write backend:

- Tables reused: `availability_slots` (`UNIQUE(entity,profession,weekday,start)`, 3 indexes), `appointments` (`UNIQUE(idempotency_key)`, `EXCLUDE appointments_no_overlap`, 4 indexes), `appointment_events` (append-only, 3 indexes, no `updated_at`).
- RLS posture reused: slots owner + `published`-listing gate; appointments/events participant via `EXISTS service_contracts`; `service_role` bypass. Client writes exclusively via 5 RPCs; reads via §7.1 path.
- Integrity notes: `professional/client_entity_id` derived from contract, never client-supplied; `starts_at/ends_at` immutable after insert (column-level `UPDATE(status, reschedule_of, updated_at)` only); `cancelled/rescheduled/completed` free the `EXCLUDE WHERE` window for rebooking; `timezone` is a display hint, `timestamptz` is truth.
- Future-proofing: EP-03-17 dispute evidence reads `appointment_events WHERE contract_id=`; EP-03-18 consumes book/reschedule/cancel results; EP-04 rider windows reuse the same `EXCLUDE` without migration.
- If Option A (§7.1) is approved, the micro-migration is additive `STABLE` reads only: no `ALTER TABLE`, no grant relaxation (`anon 0` preserved), `CREATE OR REPLACE FUNCTION` × 2 + `COMMENT ON FUNCTION` × 2 + `GRANT EXECUTE authenticated,service_role` × 2.

## 11. API Requirements

| RPC | Params | Used by | Client handling |
|---|---|---|---|
| `availability_upsert` | `p_profession_id, p_weekday, p_start_time (time HH:mm:ss), p_end_time, p_slot_duration_min=60, p_timezone='Africa/Lagos', p_is_active=true` | Editor screen → Save | Pre-validate → RPC → `availability_list` re-read → provider replace; `PLT003` time/duration/timezone → inline field errors; `PLT004` inactive/unknown profession → not-found guidance |
| `availability_list` | `p_entity_id?=NULL (self), p_profession_id?=NULL` | Editor grid + booking slot source | Key `(entityId, professionId)` memo; `PLT004` draft-professional stranger → empty guidance (no oracle leak); ordered `(weekday, start_time)` verbatim |
| `appointment_book` | `p_contract_id, p_slot_id?=NULL, p_starts_at (timestamptz ISO UTC), p_ends_at, p_idempotency_key=uuid.v4` | Booking screen → Confirm | Single key per gesture; `PLT005 Slot taken` → conflict state + `Pick another time`; `PLT003` past/inverted/>24h → inline calendar errors; `PLT004` foreign → 404 empty state; `PLT000` → `get` re-read → provider prepend |
| `appointment_reschedule` | `p_appointment_id, p_new_starts_at, p_new_ends_at, p_idempotency_key=uuid.v4` | Detail CTA (either participant) | Old → `rescheduled` + new `pending reschedule_of=old`; `PLT005` collision → conflict state; non-`pending/confirmed` → `PLT005` disabled CTA with status caption |
| `appointment_cancel` | `p_appointment_id, p_reason?=NULL` | Detail overflow + `HivorrDialog` confirm | `pending/confirmed → cancelled`; already-terminal → `PLT005` guidance |
| `appointment_get` / `appointment_list_mine` (§7.1 A) | `p_appointment_id` / `p_contract_id?, p_status?, p_limit 1-100, p_cursor?` | Detail/list screens | Keyset append; `has_more/next_cursor`; unknown cursor → empty page (no oracle) |

Envelope `{success, code, message, data}` unwrapped by new `SchedulingEnvelopeParser` (copy of `ServiceContractEnvelopeParser`: `PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict` → `ApiExceptionKind`). Transport: `BaseApiService` (`dio` + `supabase` + `exceptionMapper` injected); no direct `SupabaseClient` construction in screens.

## 12. User Interface Requirements

All screens: `HivorrScreenScaffold` → `HivorrContentPane` (≈720dp max, 16/24dp gutters) → `HivorrResponsiveScaffold` for tablet/desktop; `Theme.of(context).colorScheme` + `AppThemeExtension`/`RoleThemeExtension` + `TextTheme` exclusively (Rule 5; no `Colors.*`/hex/`fontFamily` per-widget).

- **`availability_editor_screen.dart`:** profession `HivorrSelectField` (via `profession_picker`) + Mon–Sun `HivorrChip` multi-select rows each with start/end `HivorrFormField` (read-only, opens `showTimePicker`) + duration stepper (`15/30/45/60/120`) + timezone caption (`Africa/Lagos` default, `HivorrFormatters` hint) + `is_active` `Switch` + `HivorrButton primary ≥48dp Save availability (isLoading)`. `autovalidateMode.onUserInteraction`.
- **`appointment_book_screen.dart`:** contract context `HivorrCard` (contract id suffix, counterparty, `active` badge) + month `CalendarDatePicker` + day slot grid (`HivorrChip` per concrete window, taken state disabled with `Slot taken` caption on `PLT005` refresh) + manual start/end fallback (`showDatePicker+showTimePicker`, ad-hoc `slot_id=NULL` caption) + `HivorrButton primary ≥48dp Confirm booking (isLoading)`. Past dates disabled client-side (server `PLT003` stays tested).
- **`appointment_detail_screen.dart`:** header `HivorrCard` (`appointment_status_badge`, window via `HivorrFormatters.dateTime(starts)→dateTime(ends)` + timezone caption, participants + `View contract` link) + `appointment_timeline` (event dots `booked→rescheduled/cancelled` + timestamps) + `SchedulingWriteCtaPanel` (role-gated `Reschedule`/`Cancel` + `File dispute` deep-link entry via `RoutePaths.disputesFile(contractId)`). States: `HivorrLoadingState` / `HivorrErrorState(kind→message + Retry/Pick another time)` / `HivorrEmptyState` 404.
- **Shared:** `HivorrSnackbar.success/error` for `PLT000/PLT00x`; `HivorrSuccessState` on saved/booked/rescheduled/cancelled.

## 13. User Experience Considerations

- **Progressive disclosure:** profession first → weekdays → times → duration → save; contract context first → date → slot → confirm; fail fast on inverted times/past windows with inline guidance rather than late `PLT003`.
- **Conflict honesty:** `Slot taken` never silently retried — the tapped slot flips to taken, grid preserves the rest, `Pick another time` scrolls to grid. Second overlapping attempt in tests surfaces `PLT005` inline (never hidden).
- **Optimistic restraint:** no optimistic book/reschedule/cancel — every transition waits for RPC (calendar sensitivity protects escrow-anchored delivery); rows show `isLoading` on the acted item only.
- **Role clarity:** each screen states `You are the client/professional` and disables counterparty actions with explanatory captions (not silent hides), so `PLT004` stranger paths are unreachable by accident yet still tested.
- **Timezone clarity:** every window shows both wall-clock (`HivorrFormatters.time`) and zone caption (`Africa/Lagos`); round-trip Lagos↔UTC covered by widget + integration tests.
- **Error translatability:** `PLT003→field error`, `PLT004→not-found empty state`, `PLT005→guidance/conflict card`, `PLT001/002→auth/forbidden` (re-login/support). Preserve `?next=` on auth redirects.
- **Accessibility/responsive:** 48dp targets, semantic labels on slot chips/timeline, web path URLs via existing `pathUrlStrategy`; mobile-first, detail sidebar on tablet+.
- **Empty→action:** every empty state carries a primary action (`Add availability`, `Book first appointment`, `Clear filter`, `View contract`).

## 14. Security Considerations

- **Zero-trust client (Rule 4):** all 5 writes via `SECURITY INVOKER` RPCs; client holds no overlap, timezone-authority, status-machine, or idempotency math for settlement.
- **Stranger/participant oracles:** participant-only reads + `PLT004`-identical foreign/unknown enforced server-side; client CTA gating is UX only and must never mask the server error path in tests (assert both).
- **Time-travel safety:** `starts_at > now()` enforced server-side (`PLT003`); client calendar disables past dates but tests still drive past-window RPCs to prove fail-closed.
- **Disputed/expired freeze:** non-`active` contract disables booking CTAs (copy `ContractWriteCtaPanel isDisputed` semantics); terminal appointments (`cancelled/rescheduled/completed`) disable reschedule/cancel with status captions.
- **PII/logging:** `PiiRedactor` on all logs; never log full `idempotency_key` chains or participant lists beyond suffix IDs.
- **Audit:** every write RPC server-audit-logs (`platform_audit_log_add`) + appends `appointment_events` — client asserts envelope `PLT000` only.

## 15. Performance Considerations

- `availability_list` unpaginated (weekly set small, `weekday` ordered, `availability_slots_entity_prof_idx` Index Scan); appointments keyset (`limit 20`, max 100) on `(starts_at DESC, id DESC)` via `appointments_contract_idx`/`professional_starts_idx`; no unbounded fetch; `has_more` gate on `loadMore`.
- Single-query detail (appointment + `events[]` ordered `created_at`); no N+1 — one `list` per contract page, one `get` per detail; slot grid hydrated from one `availability_list` (no per-day RPC).
- Time pickers are native dialogs (no jank); slot grid is lazy `Wrap`/`GridView` with `const` chips per `FLUTTER-UI-IMPLEMENTATION-RULES`.
- Client preserves server order verbatim (slots by `(weekday,start_time)`, appointments by `(starts_at,id)`, events by `created_at`); never re-sorts.
- Target: editor interaction jank-free, `availability_list`/`appointment_book` p95 <400ms on staging (measured in EP-03-20, not this task).

## 16. Testing Strategy

| Layer | New tests (mirror existing patterns) |
|---|---|
| Unit (repository/mapper/service) | `scheduling_mapper_test` (slot/weekday order verbatim, `canReschedule/canCancel` derivation, `timestamptz` UTC parse); `scheduling_repository_test` (fail-fast `PLT003` matrix: weekday 7, `start>=end`, duration 5/600/17, blank/bad timezone, past starts, `ends<=starts`, `>24h`; re-read-after-write verified via fake remote — copy `service_contract_repository_test` harness); `scheduling_service_test` (validate* matrix + idempotency orchestration: same-gesture same-key, new-gesture new-key) |
| Unit (envelope) | `scheduling_envelope_parser_test` (`PLT000→data`, `001/002/003/004/005/999→ApiExceptionKind`, `_safeMessage` fallback) |
| Widget | Editor validation (weekday chip states, time inline errors, duration stepper, save loading); `PLT005` conflict card with `Pick another time`; detail role-gating (professional sees editor entry, stranger sees empty — all via fakes); booking calendar past-disable + slot-tap loading + oversize reason; list empty/error/loaded + status filter → `p_status` asserted on fake; theme-token assertion (no `Colors.*`/hex/`fontFamily` — grep + `ColorScheme.primary == #2D3FE7` assert per `VISUAL-IDENTITY.md`); goldens mobile + web |
| Integration (RPC seam) | Live-RPC matrix on Dev/Staging, never direct table writes: `upsert Mon 09:00-12:00 Africa/Lagos` → `list` shows slot → `offer→accept` contract (`active`) → `book 10:00-11:00` → `pending` + `booked` event → concurrent overlap `10:30-11:30` → `PLT005` → `cancel` → `cancelled` → re-book same window `PLT000` → `book 10:00-11:00` → `reschedule →14:00` → old `rescheduled` + new `pending reschedule_of` → freed `10:00` re-bookable → same-key replay same id; malformed `starts<=now` → `PLT003`; stranger `get` → `PLT004`; timezone `starts_at AT TIME ZONE 'Africa/Lagos'` round-trip `09:00`. Uses `FakeSchedulingRepository` + live-RPC switch |
| Static | `dart analyze`, `flutter test`, `flutter_lints:6.0.0`; forbidden-pattern grep: no `from('availability_slots'/'appointments'/'appointment_events')` writes (reads only under Option B with justification), no `Colors.`/hex in new widgets, no client-side overlap/escrow math, no new `pubspec` dependency |

No pgTAP work in EP-03-14 writes scope (server already covered by `031/032`); if Option A is approved, append 6-10 read-RPC assertions in the micro-migration review (not a full suite rewrite).

## 17. Recommended Implementation Sequence

1. **§7.1 read-path lock** — confirm Option A (micro read-RPCs) vs B (RLS-`SELECT`); if A, land the 2 `STABLE` functions + grants + spot pgTAP first (reviewer-gated, additive only).
2. **DTOs/entities/mapper + envelope parser** (D2–D3, D1 parser) + mapper/parser tests — establishes the scheduling language (`timestamptz` ↔ UTC `DateTime` contract).
3. **Remote + repository + provider + service** (D1–D6) + unit tests with new fakes (`fake_scheduling.dart`).
4. **`registerSchedulingLayer` + `scheduling` barrel/DI** (D11) — wire into bootstrap `MultiProvider` (no `main.dart` restructure).
5. **Router paths/names/routes** (D12) + redirect test (protected; `?next=` preserved).
6. **Widgets** (`appointment_status_badge`, `appointment_timeline`, `scheduling_write_cta_panel`, `slot_picker_sheet`) (D10) + widget tests + token assertions.
7. **Screens** (editor → book → detail) (D7–D9) + `contract_detail_screen` CTA wiring (D13) + localization keys (D14) + widget tests + goldens (mobile + web).
8. **Integration pass** (live RPC matrix on Dev incl. double-book race + idempotency replay + Lagos/UTC round-trip) + `dart analyze` + full `flutter test` + static-grep gates.
9. Handoff to EP-03-17 (schedule-as-evidence reads `appointment_events`), EP-03-18 (payload contract `appointment_booked/rescheduled/cancelled`), EP-03-20 (scheduling leg of the 12-point validation) — all consume this slice without rework.

## 18. Expected Outcome

A professional can: open an `active` contract → manage a per-profession weekly template with weekday chips + time pickers → publish slots discoverable via `availability_list` — while either participant can book a concrete `timestamptz` window, see `pending→confirmed/completed/cancelled/rescheduled` in a role-aware timeline, and reschedule/cancel with server-guaranteed no-double-book, all through server-authoritative RPCs, token-compliant UI, and fully tested seams that EP-03-17/18/20 build on without rework. Phase Plan acceptance holds: availability editor saves → `availability_list` reflects slots; two concurrent bookings → second returns `PLT005` displayed as `HivorrErrorState` with `Pick another time`; Lagos↔UTC round-trips.

## 19. Definition of Done (DoD)

- [ ] `registerSchedulingLayer` + 3 screens + provider/service/repo/remote/parser + entities/DTOs/mappers + 4 widgets landed under `ARCHITECTURE.md lib/` schema (no top-level dirs, business logic out of widgets, no `lib/ai/*`, no hardcoded colors/fonts, no new `pubspec` dependency).
- [ ] All 5 writes via RPCs; no `availability_slots`/`appointments`/`appointment_events` direct writes in client (grep-clean; reads via locked §7.1 path only).
- [ ] `HivorrChip/FormField` editor + `HivorrErrorState Pick another time` conflict path + `SchedulingWriteCtaPanel` guidance paths tested (non-active/stranger/terminal/write-unavailable).
- [ ] Role-gating matrix green (professional/client/stranger) with server-error paths asserted (never masked by client hides); overlap `PLT005`, past-window `PLT003`, stranger `PLT004` all covered.
- [ ] Validation mirror matrix green (unit); editor/book/detail widget tests green; RPC-seam integration matrix green on Dev (template → book → overlap-reject → cancel-free → reschedule-free → idempotent replay + timezone round-trip).
- [ ] `Hivorr*` primitives + `AppTheme` tokens exclusively (static scan clean; `VISUAL-IDENTITY` assert passes); `HivorrFormatters` + locale pass-through only (no new formatter/package).
- [ ] `dart analyze` + `flutter test` clean; `flutter_lints` clean; `031/032` pgTAP still green (`supabase test db --local` regression).
- [ ] Docs: plan handoff note only (no final feature docs — forbidden in plan mode).
- [ ] EP-03-17/18/20 can consume appointment/event projections + lifecycle results without modification (interface review sign-off).

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High**
- **Reasoning Level Justification:** Matches the approved Phase Plan matrix (`EP-03-14: Planning High / Coding High`, §12–13). Rationale: bounded client slice over a proven server primitive (no new financial settlement, ranking, or crypto — unlike `Extremely High` items EP-03-01/02/03/06/11, and below the Realtime/offline-crypto hybrid complexity that lifts EP-03-13 to `Very High`); yet carries **real concurrency sensitivity** (`EXCLUDE` race + `FOR UPDATE` + idempotency dedup must never be masked by optimistic UI) and **timezone correctness burden** (`timestamptz` authority, Lagos↔UTC fidelity) plus **moderate integration surface** (5 RPCs + §7.1 reads + contract entry + 3 screens + provider/DI/router across ~15 components + 3 downstream consumers). `High` provides rigorous cross-layer consistency and edge-case coverage (overlap, reschedule-chain, cancel-free, replay, stranger, past-window) without the formal-verification overhead reserved for ledger atomicity and double-blind invariants. `Very High` would be disproportionate (no fund movement, no Realtime fan-out owned here); `Medium`/`Low` would underweight the double-book invariant that is the task's single load-bearing guarantee.

---

**Awaiting your approval to proceed to implementation on exit from plan mode.**

Open questions for approval (no assumptions made): (1) §7.1 read path — Option A additive `appointment_get/list_mine` RPCs vs Option B RLS-`SELECT` reads? (2) §7.4 offline booking — wire `ActionQueue` with `p_idempotency_key` dedup, or require connectivity with documented banner?
