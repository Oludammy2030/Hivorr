# Task Implementation Plan — EP-03-05: Scheduling & Availability Schema & Server-Side Rules

**Task ID:** EP-03-05 | **Priority:** High | **Status:** Completed | **Phase:** EP-03 Stage 1 — Marketplace Server Schema Foundation (parallelizable after EP-03-02)
**Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:290-299` (EP-03-05) + `290: Objective` + `294: Exclusion constraint` + `295: Engineering Purpose` + `297: dependencies EP-03-02` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173` + `documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31` + `supabase/migrations/20260923090001_service_contract_schema.sql:43-67` (contract FK) + `supabase/migrations/20260819090001_enforcement_foundation.sql:37-82` (platform helpers)

---

## 1. Task Objective

Deliver the **contract-bound scheduling primitive** that makes 2-party services executable. This is a **server-only migration** with zero `lib/` Dart and zero mutation of prior tables:

*   **3 tables:** `availability_slots` (weekly template per professional+profession), `appointments` (concrete `timestamptz` bookings under `service_contracts`), `appointment_events` (append-only audit) — with `btree_gist` extension + `EXCLUDE USING gist` double-booking prevention
*   **5 RPCs `SECURITY INVOKER` envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999` per `supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19`):** `availability_upsert`, `availability_list`, `appointment_book`, `appointment_reschedule`, `appointment_cancel` (+ 2 read helpers `appointment_get`, `appointment_list_mine` if needed — canonical set is 5 per Plan:294; `get/list_mine` fold into `availability_list`/`appointment_book` shape) — all `VOLATILE` (write) / `STABLE` (read), `REVOKE EXECUTE FROM public` + narrow `GRANT EXECUTE` (`anon 0`, `authenticated/service_role`), `COMMENT ON FUNCTION`×5
*   **Full RLS default-deny** (`supabase/migrations/20260819090001_enforcement_foundation.sql:18-26`) — participant-scoped (`service_contracts` join) + owner-scoped (`availability_slots.entity_id=auth.uid()`) ; `appointment_events` append-only `SELECT+INSERT` (no `UPDATE/DELETE`) ; `service_role` bypass
*   **Exclusion constraint** `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))` + `FOR UPDATE` locking on booking RPCs — server-guaranteed no double-book despite concurrent `appointment_book` calls (`EP-03:180` medium risk: "All timestamps `timestamptz`; booking RPC uses `FOR UPDATE` + exclusion constraint on `appointments(slot_id, status)` : idempotency key per booking attempt")
*   **2 pgTAP suites:** `031_service_scheduling_schema_posture.sql` + `032_service_scheduling_rpc_enforcement.sql` (`supabase/tests/database/025_service_contract_schema_posture.sql:14-339` / `027_service_review_schema_posture.sql:14-326` pattern ; `EP-03-02:51` + `EP-03-04:17`)
*   **Zero mutation** of `entities`/`service_listings`/`service_contracts`/`financial_*`/`service_reviews`/`conversations`

Unblocks `EP-03-14` (`lib/systems/scheduling/services/scheduling_service.dart` + `screens/availability_editor_screen.dart`, `appointment_book_screen.dart`, `appointment_detail_screen.dart` `ARCHITECTURE.md:102` `lib/systems/scheduling/`) and is reused by EP-04 (adds `rider`/`merchant` participant without schema change — new appointment row with same `professional_entity_id` exclusion scope).

---

## 2. Business Problem Being Solved

EP-03-02 proved `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43-67` `offered→active→completed→closed/cancelled/disputed`) + `contract_milestones`/`contract_events`, EP-03-01 proved `service_listings` + `professions→industries` taxonomy, and EP-02 proved `financial_escrow` + `dispute_cases`, but **no calendar coordination exists**:

*   No `availability_slots` — `EP-03:88` `Tables availability_slots, appointments` has no table; `EP-03-14` `availability_editor_screen.dart` (weekday `HivorrChip` + `HivorrFormField` time pickers `lib/shared/widgets/hivorr_chip.dart` / `lib/shared/components/hivorr_form_field.dart`) has no FK target to `profession_id→professions.id` via `20260821090001_entity_taxonomy_tables.sql:58-77`
*   No `appointments` with `timestamptz` + `status pending/confirmed/completed/cancelled/rescheduled` — "2-party services depend on calendar coordination (legal consultation, artisan visit)" `EP-03:295`; without it `service_contracts.id` `EP-03:138` `Appointments linked to service_contracts.id` has no value
*   No double-booking invariant — "Scheduling timezone/double-booking race — Medium — All timestamps `timestamptz`; booking RPC uses `FOR UPDATE` + exclusion constraint on `appointments(slot_id, status)` : idempotency key per booking attempt" `EP-03:180`; without `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status in ('pending','confirmed'))` `EP-03:294` two concurrent `appointment_book` calls both succeed → operational failure, escrow-funded contract with overlapping site visit
*   No `appointment_events` audit — `contract_events` `20260923090001:150-162` is lifecycle audit for `financial_escrow`; scheduling state changes (`pending→confirmed→completed/cancelled/rescheduled`) have no append-only log for dispute (`EP-03-17` `dispute_cases.contract_id`) evidence
*   No `btree_gist` extension — `grep btree_gist supabase/migrations/*.sql` `0` (verified greenfield `explore: session_f263`); `EXCLUDE` on `uuid WITH =` requires `btree_gist`

Without this, discovery→contract never converts to a scheduled delivery, and `lib/systems/scheduling/.gitkeep` (`lib/systems/scheduling/.gitkeep:1` only file) remains empty while `EP-03-10/11` escrow lifecycle has no time anchor.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| `availability_slots` | `id uuid PK gen_random_uuid()`, `entity_id uuid NOT NULL → entities(id) CASCADE` (owner = `auth.uid()`), `profession_id uuid NOT NULL → professions(id) RESTRICT`, `weekday smallint NOT NULL CHECK 0-6` (0=Sunday ISO), `start_time time NOT NULL`, `end_time time NOT NULL CHECK end_time > start_time`, `slot_duration_min int NOT NULL CHECK 15-480` (15min increments optional via RPC `PLT003`), `timezone text NOT NULL DEFAULT 'Africa/Lagos' CHECK ~ '^[A-Za-z/_]+$'` , `is_active boolean DEFAULT true`, `created_at timestamptz DEFAULT now()`, `updated_at timestamptz DEFAULT now()` + `platform_set_updated_at()` (`20260819090001:54-62`), `created_by uuid DEFAULT auth.uid()`, `UNIQUE(entity_id, profession_id, weekday, start_time)` , indexes `(entity_id, profession_id)`, `(entity_id, weekday)`, comment |
| `appointments` | `id uuid PK`, `contract_id uuid NOT NULL → service_contracts(id) CASCADE`, `slot_id uuid → availability_slots(id) SET NULL` (nullable — ad-hoc bookings without template), `professional_entity_id uuid NOT NULL → entities(id) RESTRICT` (denormalized for `EXCLUDE`), `client_entity_id uuid NOT NULL → entities(id) RESTRICT`, `starts_at timestamptz NOT NULL`, `ends_at timestamptz NOT NULL CHECK ends_at > starts_at` , `status text NOT NULL DEFAULT 'pending' CHECK pending/confirmed/completed/cancelled/rescheduled`, `reschedule_of uuid → appointments(id) SET NULL` , `idempotency_key uuid NOT NULL UNIQUE DEFAULT gen_random_uuid()` (`uuid:4.5.1` `pubspec.yaml:82`), `created_at/updated_at/created_by` + `platform_set_updated_at()` , indexes `(contract_id)`, `(professional_entity_id, starts_at)`, `(client_entity_id, starts_at)`, `(starts_at DESC)`, `UNIQUE(idempotency_key)` , plus `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))` — requires `CREATE EXTENSION IF NOT EXISTS btree_gist` |
| `appointment_events` | Append-only `id uuid PK`, `appointment_id uuid NOT NULL → appointments(id) CASCADE`, `contract_id uuid NOT NULL → service_contracts(id) CASCADE` (denormalized for participant RLS without `appointments` join in some queries), `event_type text NOT NULL CHECK booked/confirmed/rescheduled/cancelled/completed`, `from_status/to_status text`, `actor_id uuid`, `details jsonb DEFAULT '{}'`, `created_at timestamptz DEFAULT now()` — **no `updated_at`** (immutable, mirrors `contract_events:150` / `messages:41` / `service_favorites:265`), indexes `(appointment_id, created_at)`, `(contract_id, created_at)`, `(event_type)` , comment |
| `btree_gist` extension | `CREATE EXTENSION IF NOT EXISTS btree_gist;` (first occurrence in repo; idempotent) — required for `professional_entity_id WITH =` in `EXCLUDE` |
| RLS + grants | `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL FROM anon, authenticated, service_role` (`20260819090001:18-26` posture) then `GRANT SELECT, INSERT, UPDATE, DELETE` narrow per table (see §8.3) ; `anon 0`; 6-7 policies (2+2+2) participant/owner-scoped |
| Realtime exclusion | Guarded `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` for all 3 tables (`20260829090003:799-816` / `20260923090001:953-965` / `20260924090001:741-754` precedent) — scheduling is NOT Realtime (contrast `messages` `EP-03-04` which `ADD`s) |
| RPC `availability_upsert` | `(p_profession_id uuid, p_weekday smallint, p_start_time time, p_end_time time, p_slot_duration_min int DEFAULT 60, p_timezone text DEFAULT 'Africa/Lagos', p_is_active boolean DEFAULT true)` → `VOLATILE` `SECURITY INVOKER` — validates `profession is_active` (`professions.is_active` `20260821090001:58`), `weekday 0-6 PLT003`, `start<end PLT003`, `duration 15-480 PLT003`, `timezone IANA PLT003`, upserts `(entity_id, profession_id, weekday, start_time)` via `INSERT ... ON CONFLICT DO UPDATE`, audit `platform_audit_log_add` |
| RPC `availability_list` | `(p_entity_id uuid DEFAULT NULL, p_profession_id uuid DEFAULT NULL)` → `STABLE` — public `published` professional's slots if `p_entity_id` not self and listing `published`? Actually `RLS USING (entity_id=auth.uid() OR EXISTS published listing for entity+profession)` — simplest: `authenticated` reads own slots + `anon/authenticated` reads any `entity_id` where `EXISTS service_listings WHERE entity_id=p_entity_id AND status='published' AND profession_id=p_profession_id`; keyset `(weekday, start_time)` ordering, returns `slots[]` |
| RPC `appointment_book` | `(p_contract_id uuid, p_slot_id uuid DEFAULT NULL, p_starts_at timestamptz, p_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` → `VOLATILE` — `platform_is_authenticated PLT001`, `contract participant check` `PLT004` identical for foreign/unknown (`20260923090001:811` precedent), `contract status active PLT005` (not `disputed`/`cancelled`), `starts_at > now() PLT003`, `ends_at > starts_at PLT003`, `ends_at - starts_at <= 24h PLT003` (guard), `FOR UPDATE` on `service_contracts` + `availability_slots` (if `p_slot_id` not null) then `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING RETURNING id` (dedup), relies on `EXCLUDE` to reject overlap `PLT005` `23P01`, inserts `appointment_events booked`, audit |
| RPC `appointment_reschedule` | `(p_appointment_id uuid, p_new_starts_at timestamptz, p_new_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` → `VOLATILE` — `authenticated` participant, `FOR UPDATE` on `appointments` + `service_contracts`, `status pending/confirmed → rescheduled` (old row `status='rescheduled'`), new row `INSERT` with `reschedule_of=p_appointment_id`, same `EXCLUDE` check on new row, old row `tstzrange` no longer `pending/confirmed` so new row can occupy freed slot; idempotent via `idempotency_key` |
| RPC `appointment_cancel` | `(p_appointment_id uuid, p_reason text DEFAULT NULL)` → `VOLATILE` — participant, `FOR UPDATE`, `status pending/confirmed → cancelled`, `EXCLUDE` WHERE clause automatically releases slot (`cancelled` not in `pending/confirmed`), inserts `appointment_events cancelled` |
| pgTAP `031` posture | `has_table 3`, `relrowsecurity 3`, `anon 0 DELETE/INSERT`, `authenticated SELECT/INSERT/UPDATE narrow`, `CHECK weekday 0-6, start<end, duration 15-480, status vocab`, `UNIQUE(entity_id,profession,weekday,start)` , `UNIQUE(idempotency_key)`, `EXCLUDE gist` , `has_extension btree_gist`, `platform_set_updated_at 2` + `0` on `appointment_events`, `has_index 3+4+2`, `prosecdef 0`, `Realtime 0`, `comments 3`, `EXECUTE anon 0 authenticated 5 service_role 5`, `policies 6-7` |
| pgTAP `032` enforcement | `anon 42501` on 5 RPCs (`anon 0` grants), `PLT003/004/005` validation matrix, double-booking race `PLT005 23P01`, `timezone round-trip`, `reschedule frees slot`, `cancelled frees slot`, `idempotency_key dedup PLT000 second call same id`, `stranger PLT004` no oracle, `RLS SELECT 0` for non-participant |

---

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| `service_listings` / `service_listing_media` / `service_favorites` | `EP-03-01` `20260921090001:42-95` — finalized, referenced only for `availability_list` public-read gate (`status='published'`) |
| `contract_milestones` / `contract_events` / `financial_escrow*` | `EP-03-02` `20260923090001:100-162` / `20260829100004:191-257` — milestone/escrow linkage `NULL` until `EP-03-11`; scheduling does not touch ledger |
| `service_reviews` / `service_review_aggregates` | `EP-03-03` `20260924090001:52-136` — blind trust, not calendar |
| `conversations` / `messages` + Realtime `ADD messages` | `EP-03-04` `20260925090001` (planned `029/030`) — encrypted messaging, separate RLS/seam |
| Deterministic ranking `service_ranking_search` / `service_search` FTS | `EP-03-06/07` `Plan:139-140` — consume `service_listings.search_vector`, not appointments |
| Any `lib/systems/scheduling/*` Dart (`scheduling_service.dart`, `availability_editor_screen.dart`, `appointment_book_screen.dart`, `appointment_detail_screen.dart`, `lib/data/datasources/remote/supabase_scheduling_remote_data_source.dart`, `lib/data/repositories/scheduling_repository.dart`, `lib/data/models/appointment_dto.dart`) | `EP-03-14` `Plan:144` — client slice; this task is server-only per `EP-03-02:58` / `EP-03-04:58` pattern |
| `service-listing-media` new bucket / `appointment_attachments` bucket | No attachment in EP-03-05; if later needed reuse `storage.objects foldername[1]=auth.uid()::text` (`20260830100001:51-55` / `20260921090001:284`) — not in this migration |
| `notification_events` table / Edge Function `appointment_reminder` | `EP-03-18` scope; scheduling notification is `lib/core/notifications` (`EP-01-18`) via `appointment_events` trigger — no new `notification_events` DDL here |
| `lib/ai/*` intelligence | Excluded from EP-03 `Plan:106`, `AGENT.md:7` — AI never decides booking order |
| Mutation of `service_contracts`/`service_listings`/`entities`/`professions`/`industries`/`financial_*` | Finalized EP-01/02/03-01-03; referenced, not altered (`grep alter table public.(service_listings|service_contracts|financial_escrow) 0` `CHECK_DONE`) |

---

## 5. Existing Asset and Dependency Analysis

| Asset | Location | State | Reuse Verdict for EP-03-05 |
|---|---|---|---|
| `service_contracts(id, client_entity_id, professional_entity_id, status, service_listing_id, escrow_id)` | `supabase/migrations/20260923090001_service_contract_schema.sql:43-67` (`20260923090001:43`) — indexes `client_idx:80`, `professional_idx:82`, `listing_idx:84` | Implemented (`025/026` pgTAP 29/88 pass `20260923090001:43`) | **Reuse** `FK appointments.contract_id → service_contracts(id) CASCADE` + participant derivation `professional=service_contracts.professional_entity_id`, `client=client_entity_id`; `status` gate `active` required (`EP-03-02:61` `draft/offered/active/...`) |
| `entities(id)` / `entity_profiles` / `entity_professions` | `supabase/migrations/20260821090002_entity_core_tables.sql:20-256` (`20260821090002:20`) | Implemented (`EP-01-06`) | **Reuse** `availability_slots.entity_id → entities CASCADE`, `appointments.professional/client → entities RESTRICT`, `auth.uid()` owner check |
| `professions(id, industry_id, slug, name, is_active)` + `industries` | `supabase/migrations/20260821090001_entity_taxonomy_tables.sql:58-77` | Implemented (seed `20260829090001:28-158`) | **Reuse** `availability_slots.profession_id → professions RESTRICT`, `professions.is_active` gate in `availability_upsert`, `industries` via `join` for `availability_list` if filtered |
| `service_listings(id, entity_id, profession_id, status, search_vector)` | `supabase/migrations/20260921090001_service_marketplace_schema.sql:42-95` | Implemented (`023/024` pgTAP) | **Reuse** public-read gate for `availability_list` — `EXISTS service_listings WHERE entity_id=p_entity_id AND status='published' AND profession_id=p_profession_id` allows `anon/authenticated` discovery of slots without leaking `draft` (mirrors `service_listing_get` `20260921090001:1141` `PLT004` oracle) |
| `platform_is_authenticated()` | `supabase/migrations/20260819090001_enforcement_foundation.sql:37-43` | Implemented — granted `authenticated,service_role:123` | **Reuse** auth gate on 5 RPCs `PLT001` |
| `platform_raise_error(code,message)` | `20260819090001:68-82` | Implemented | **Reuse** envelope `PLT003/004/005/999` (`P0001` `detail=code`) |
| `platform_set_updated_at()` | `20260819090001:54-62` | Implemented | **Reuse** `updated_at` trigger on `availability_slots`, `appointments` (mutable); NOT on `appointment_events` (append-only, mirrors `contract_events:150`) |
| `platform_audit_log_add()` | `supabase/migrations/20260819090003_foundational_rpcs.sql:159-192` | Implemented — `SECURITY DEFINER`, `authenticated,service_role` | **Reuse** audit `availability_upsert`, `appointment_book/reschedule/cancel` (precedent `service_contract_offer:425`, `service_review_submit:316`) |
| `lib/shared/helpers/hivorr_formatters.dart:25-43` `date/time/dateTime` | `lib/shared/helpers/hivorr_formatters.dart:1-132` | Implemented (`EP-01-16`) | **Reuse** (defer to EP-03-14) slot display `HivorrFormatters.time(DateTime.fromMillisecondsSinceEpoch(starts_at))` + `lib/core/localization` (`Plan:393` `Uses lib/shared/helpers/hivorr_formatters.dart for time display and lib/core/localization for locale`) — no new formatter |
| `lib/shared/widgets` `HivorrChip/HivorrFormField/HivorrErrorState/HivorrEmptyState` | `lib/shared/widgets/hivorr_chip.dart`, `components/hivorr_form_field.dart`, `hivorr_error_state.dart` | Implemented (`EP-01-16`) | **Reuse** (EP-03-14) availability editor `HivorrChip days` + `HivorrFormField time` pickers (`Plan:393`); no new widget |
| `lib/core/storage/supabase_storage_service.dart` | `lib/core/storage/` (`EP-02-06/08`) | Implemented | **Not needed** for EP-03-05 text-only scheduling; reserved for future appointment evidence `storage.foldername(name)[1]=auth.uid()::text` |
| `uuid:4.5.1` + `lib/core/storage/storage_paths.dart:16` `Uuid().v4()` | `pubspec.yaml:82` | Implemented | **Reuse** `appointments.idempotency_key uuid UNIQUE` + `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING` dedup (precedent `messages.client_message_id` `EP-03-04:45` `p_client_message_id uuid DEFAULT gen_random_uuid()`) |
| `lib/core/sync/action_queue.dart` | `lib/core/sync/action_queue.dart` (`EP-01-12`) | Implemented — `SyncAction{id: uuid.v4(), endpoint:'/rpc/appointment_book', priority}` | **Reuse pattern** (not DDL) — `EP-03-14` `appointment_book` will carry `p_idempotency_key uuid v4` for offline queue replay (`Plan:183` `Idempotency & Offline ... Idempotency-Key: uuid v4 via lib/core/sync/sync_action.dart`) — no new queue table |
| `supabase/migrations/` ordering 34 files ending `20260925090001_service_messaging_schema.sql:1` (if EP-03-04 merged) / `20260924090001` else | `supabase/migrations/` | Current tip `20260924090001` (or `20260925090001` after EP-03-04) | **Extend** ordering: EP-03-05 migration `20260926090001_service_scheduling_schema.sql` immediately after `20260925090001` (or `20260924090001` if EP-03-04 not yet merged); `IF NOT EXISTS`/`DROP IF EXISTS`/`CREATE OR REPLACE` idempotent, no prior DDL |
| `supabase/tests/database/` 30 files `001`→`030` pgTAP | `supabase/tests/database/` `.github/workflows/database-rls-tests.yml` | Implemented | **Extend** with `031_service_scheduling_schema_posture.sql` + `032_service_scheduling_rpc_enforcement.sql` replicating `025/026` / `029/030` assertions |
| `lib/systems/scheduling/.gitkeep` | `lib/systems/scheduling/.gitkeep:1` | Empty — only `.gitkeep` | **No reuse** — new server tables needed; `lib/systems/scheduling` stays empty for `EP-03-14` |

**Existing scheduling assets inspected:** `grep -rn "availability|appointment|btree_gist|EXCLUDE USING|tstzrange" supabase/migrations/*.sql lib/**/*` ⇒ **0 tables** — `lib/systems/scheduling/.gitkeep` empty, `supabase/migrations` 34 files have only `Realtime exclusion` English matches (`explore: session_f263`). `create extension.*btree_gist` `0` prior — greenfield, first `btree_gist` occurrence.

---

## 6. Reuse / Extension / Refactoring Assessment

| Proposed Asset | Assess: Reuse / Extend / Refactor / New | Why Not Reuse/Extend Existing & Why New Is Necessary | Future Reuse Design |
|---|---|---|---|
| `availability_slots` weekly template (`entity_id, profession_id, weekday, start_time, end_time, timezone`) | **New** | No existing slot table. `service_listings` is listing, not calendar; `contract_milestones` is escrow split (`20260923090001:100`), not time; `service_review_aggregates` is rating materialization. `entity_professions` maps trade but not time. Creating weekly slot as standalone table (vs column on `service_listings`) allows one professional with multiple professions to have distinct hours per `profession_id` (e.g., `Legal: Mon 09:00-17:00`, `Consulting: Tue 10:00-14:00`) without duplicating listings — per `Engineering-Execution-Generation-Principle.md:57-58` taxonomy universal, no schema change for new industry. | Designed reusable platform capability: `availability_slots(UNIQUE entity,profession,weekday,start)` is generic weekly schedule primitive. EP-04 rider `availability` reuses same table with `profession_id` = `Logistics` profession; no migration. `timezone text` per slot allows Lagos vs London professionals without adding `UTC offset` column. |
| `appointments` concrete booking (`contract_id, professional_entity_id, tstzrange, status, idempotency_key, reschedule_of, EXCLUDE`) | **New** | No existing booking store. `service_contracts` is engagement atom but has no time; `contract_events` is audit (`20260923090001:150`) not `timestamptz` booking; `conversations/messages` are chat (`EP-03-04`). Must store `timestamptz` concrete instances (not `weekday+time` template) for `tstzrange(starts_at, ends_at) WITH &&` exclusion — weekly template alone cannot enforce real double-book across ad-hoc `p_starts_at` values. `reschedule_of` self-FK + `idempotency_key UNIQUE` + `FOR UPDATE` are mandatory for `EP-03-14` offline/double-tap dedup (mirrors `messages.client_message_id` `EP-03-04:45`). | `appointments(contract_id → service_contracts CASCADE, professional_entity_id WITH =, tstzrange)` pattern reusable for any future `lib/systems/scheduling` appointment type (EP-04 multi-stop delivery window) — add `appointment_type` enum seed, not table. `status pending/confirmed/completed/cancelled/rescheduled` vocabulary extensible (`ARCHITECTURE.md:70` `text+CHECK` not `ENUM` per `20260821090002:15` `D2`). |
| `appointment_events` append-only audit | **New** | No existing appointment audit. `contract_events` (`20260923090001:150` `event_type offered/accepted/cancelled/milestone_completed/...`) is contract lifecycle, not `booked/confirmed/rescheduled/cancelled/completed`; `platform_audit_log` is global (`20260819090003:159`) not appointment-scoped. New append-only `appointment_events(appointment_id → CASCADE, contract_id → CASCADE, event_type, from/to_status)` mirrors `contract_events` immutable pattern (`no updated_at` trigger) and supports `dispute_cases.contract_id` evidence without new ledger. | Reusable for scheduling-dispute evidence: `service_dispute_file(p_contract_id)` `EP-03-17` will `SELECT * FROM appointment_events WHERE contract_id=p_contract_id` without new join to `appointments`. `details jsonb` extensible for `reschedule_of` chain. |
| `btree_gist` extension | **New (first)** | No prior `CREATE EXTENSION btree_gist`. `EXCLUDE USING gist (professional_entity_id WITH =)` on `uuid` requires `btree_gist` (native `gist` indexes scalars). Every existing migration uses `btree/GIN` (`20260921090001:122` `GIN(search_vector)`, `20260923090001:80-91` `btree` indexes) but none needs `gist` equality. First scheduling `EXCLUDE` must enable it; otherwise `ERROR: data type uuid has no default operator class for access method "gist"`. | `CREATE EXTENSION IF NOT EXISTS btree_gist;` is idempotent, reversible (`drop extension if exists`), and reusable by future `EXCLUDE` constraints (e.g., `EP-04` rider availability). |
| `availability_upsert/availability_list/appointment_book/reschedule/cancel` RPCs (`SECURITY INVOKER`, envelope, `PLT###`) | **New** | No existing RPC manages `tstzrange` exclusion. `service_contract_*` (`20260923090001:267-917` 8 RPCs) are `VOLATILE/STABLE` with `FOR SHARE` → `FOR UPDATE` participant checks but different domain (escrow linkage). `service_review_submit` (`20260924090001:219`) is `FOR UPDATE` double-credit guard but rating, not `23P01` exclusion. Reusing them would conflate milestone lifecycle with calendar RLS. New RPCs are `SECURITY INVOKER` (`prosecdef=0` per `025:234`) with `platform_is_authenticated()` + `platform_raise_error` (`027:242` `PLT000`) and `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING` dedup (precedent `message_send` `EP-03-04:45`). | 5 RPCs follow `lib/data/datasources/remote/*_envelope_parser.dart` seam (`EP-01-08`) — `supabase_scheduling_remote_data_source.dart` (`EP-03-14`) will be single seam, mirroring `supabase_taxonomy_remote_data_source.dart` + `supabase_messaging_remote_data_source.dart`. Signatures include `p_idempotency_key uuid` (`uuid:4.5.1`) + `p_limit 1-100` / `p_cursor uuid` keyset (`Plan:55` no `N+1`, `p95 <400ms`). |
| `HivorrFormatters` / `HivorrChip` / `lib/core/sync/ActionQueue` / `timezone` | **Reuse** (no new helpers) | Existing `lib/shared/helpers/hivorr_formatters.dart:25-43` `date/time/dateTime` + `HivorrChip` (`lib/shared/widgets/hivorr_chip.dart`) + `lib/core/sync/action_queue.dart` `SyncAction{uuid.v4(), priority}` are sufficient; creating new time formatter would duplicate `EP-01-16` design-system. No `timezone: ^0.9` package needed — `availability_slots.timezone text` is validated `PLT003` against IANA list via `pg_timezone_names()` check, not Dart library. | Keep formatting/provider-agnostic per `ARCHITECTURE.md:112-113` (`lib/integrations/payment_gateways/` precedent). Scheduling imports only `lib/shared/helpers`, `lib/core/sync`, never `lib/ai/*` (`Plan:106`). |
| Realtime `supabase_realtime` publication | **Extend (drop, not add)** | All prior migrations (`20260829090003:799`, `20260921090001:741`, `20260923090001:953`, `20260924090001:741`) **drop** tables from `supabase_realtime` (posture `0`). Scheduling follows pattern — `availability_slots/appointments` are NOT Realtime (contrast `messages` `EP-03-04` which is first to `ADD`). Extending exclusion with guarded `IF EXISTS → DROP` is additive, idempotent; no refactor. | Future `EP-04` logistics `real-time delivery tracking` reuses same `messages` `ADD` + RLS-filtered `ON UPDATE` via `supabase_flutter` `channel.onPostgresChanges(event:update)` (`EP-03-04:311`); scheduling stays `0`. |

---

## 7. Recommended Technical Approach

### 7.1 Single Migration `supabase/migrations/20260926090001_service_scheduling_schema.sql` (immediately after `20260925090001_service_messaging_schema.sql:1` or `20260924090001` if EP-03-04 not yet merged)

Strict order mirrors `20260924090001:49-754` + `20260923090001:40-965` + `EP-03-04:99`:

1. Header block — EP-03-05 execution model `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, `timestamptz` + `btree_gist` + `EXCLUDE` double-book rationale (`Plan:180,294`), `FOR UPDATE` + `idempotency_key` dedup, grants, Realtime `DROP` (scheduling not Realtime)
2. `CREATE EXTENSION IF NOT EXISTS btree_gist;` (first, idempotent, before `EXCLUDE`)
3. DDL `availability_slots` (`CHECK` `weekday 0-6`, `start<end`, `duration 15-480`, `UNIQUE(entity_id, profession_id, weekday, start_time)`, `profession is_active` not CHECK but RPC `EXISTS`, 3 indexes, `platform_set_updated_at()` trigger, `COMMENT ON TABLE/COLUMN`)
4. DDL `appointments` (`CHECK` `ends>starts`, `status pending/confirmed/completed/cancelled/rescheduled` `text+CHECK`, `idempotency_key UNIQUE`, FKs `CASCADE/RESTRICT`, 4 indexes, `EXCLUDE USING gist` `WHERE (status IN ('pending','confirmed'))`, `platform_set_updated_at()` trigger, comments)
5. DDL `appointment_events` (`CHECK` `booked/confirmed/rescheduled/cancelled/completed`, FK `CASCADE`, 2 indexes, **no `updated_at` trigger** (append-only))
6. `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL FROM anon, authenticated, service_role` (`20260819090001:18-26`) + narrow `GRANT SELECT, INSERT, UPDATE, DELETE` + column-level `UPDATE(last_read)` analogue not needed — `appointments` `GRANT UPDATE(status, reschedule_of, updated_at)` to `authenticated` is column-level safe (blocks `starts_at` mutation after book, only `status` via `reschedule/cancel`)
7. 6-7 RLS policies (see §8.3) participant/owner-scoped via `EXISTS service_contracts` join + `entity_id=auth.uid()` (`Plan:179` leakage precedent)
8. 5 RPCs `SECURITY INVOKER` (`VOLATILE` `upsert/book/reschedule/cancel`, `STABLE` `list`) `set search_path=public` (see §7.2)
9. `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + 5× `GRANT EXECUTE authenticated,service_role` (`anon 0`) + `COMMENT ON FUNCTION`×5
10. Realtime `DO $$` — `DROP TABLE public.availability_slots, appointments, appointment_events` if in `pg_publication_tables` (`20260924090001:741` guard)
11. Posture comment block

**No DDL on prior tables** — only additive `btree_gist`, 3 new tables, 5 functions, `pgTAP 031/032`. `grep alter table public.(service_listings|service_contracts|financial_escrow|service_reviews) 0` `CHECK_DONE` before commit.

### 7.2 Execution Model: `SECURITY INVOKER` (No New `SECURITY DEFINER`)

All 5 RPCs `SECURITY INVOKER` — RLS applies inside body. Complies with `supabase/tests/database/027_service_review_schema_posture.sql:202-226` posture (`prosecdef 1` only for `service_review_reveal_if_ready` whitelisted; scheduling `0`, `008_full_schema_posture_audit.sql` stays green). `AGENT.md:6` Rule 4: client unprivileged; `authenticated` rolls back on `PLT` violation.

| RPC | `anon` | `authenticated` | `service_role` | Gate + Volatility |
|---|---|---|---|---|
| `availability_upsert(p_profession_id uuid, p_weekday smallint, p_start_time time, p_end_time time, p_slot_duration_min int DEFAULT 60, p_timezone text DEFAULT 'Africa/Lagos')` | — (`42501`) | `EXECUTE` (owner) | `EXECUTE` | `platform_is_authenticated PLT001`, `professions.is_active PLT004` (identical to not-found, no oracle `20260921090001:1141`), `weekday 0-6 PLT003`, `start<end PLT003`, `duration 15-480 PLT003` (and `slot_duration_min % 15 == 0` `PLT003` optional), `timezone ~ IANA or exists pg_timezone_names PLT003`, `entity_id=auth.uid() ON CONFLICT DO UPDATE` `VOLATILE` |
| `availability_list(p_entity_id uuid DEFAULT NULL, p_profession_id uuid DEFAULT NULL)` | — (public read via `service_listings` `published` existence, but RPC is `authenticated` only for MVP; `anon` `0` mirrors `service_contract_get` `20260923090001:924` `anon 0` vs `service_listing_get` `anon 1`) — **Decision: keep `anon 0`**, discovery via `service_listing_get` already public; availability is secondary (`Plan:393` `availability_editor_screen` owner-only). | `EXECUTE` (own or `published` other) | `EXECUTE` | `authenticated`, `p_limit implied` no pagination (weekly slots small, `weekday` ordered), `EXISTS service_listings.status='published' PLT004` for other-entity read; `STABLE` |
| `appointment_book(p_contract_id uuid, p_slot_id uuid DEFAULT NULL, p_starts_at timestamptz, p_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` | — | `EXECUTE` (contract participant) | `EXECUTE` | `authenticated PLT001`, `contract exists + participant (client OR professional = auth.uid()) PLT004` identical for foreign/unknown (`20260923090001:811`), `contract status='active' PLT005` (`disputed/cancelled/completed PLT005` `025:188` vocabulary), `p_starts_at > now() PLT003`, `p_ends_at > p_starts_at PLT003`, `p_ends_at - p_starts_at <= interval '24 hours' PLT003`, `FOR UPDATE` on `service_contracts` + `availability_slots` (if `p_slot_id`), `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING RETURNING id` (dedup), relies on `EXCLUDE` `23P01` → `PLT005 Slot taken.` ; `VOLATILE` |
| `appointment_reschedule(p_appointment_id uuid, p_new_starts_at timestamptz, p_new_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` | — | `EXECUTE` (participant, `FOR UPDATE`) | `EXECUTE` | `authenticated`, `EXISTS participation PLT004`, `appointment status pending/confirmed PLT005` (not `completed/cancelled/rescheduled`), `new window > now() PLT003`, `FOR UPDATE` on `appointments` + `service_contracts`; sets old `status='rescheduled'`, inserts new `pending` with `reschedule_of=old.id`; `EXCLUDE` on new row `23P01 → PLT005`; `appointment_events rescheduled` ×2; `VOLATILE` |
| `appointment_cancel(p_appointment_id uuid, p_reason text DEFAULT NULL)` | — | `EXECUTE` (participant) | `EXECUTE` | `authenticated`, `EXISTS participation PLT004`, `status pending/confirmed PLT005`, `FOR UPDATE`; `status='cancelled'` (frees `EXCLUDE` WHERE clause), `appointment_events cancelled` with `details jsonb {reason}` ; `VOLATILE` |

`anon EXECUTE 0/5` (no public booking, mirrors `service_contracts` `20260923090001:924-931` `anon 0`; contrast `service_listing_get` `20260921090001` `anon 1` public & `service_review_get_for_listing` `20260924090001:727` `anon 1` public which are read-only).

### 7.3 Timezone & Double-Book Invariant

```sql
-- availability_slots.timezone: validated, not computed
IF p_timezone IS NULL OR btrim(p_timezone)='' THEN v_tz := 'Africa/Lagos'; ELSE v_tz := btrim(p_timezone); END IF;
IF v_tz !~ '^[A-Za-z/_]+$' OR NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_tz) THEN
  PERFORM public.platform_raise_error('PLT003','Invalid timezone.');
END IF;

-- appointments.timestamptz round-trip: client sends local wall-clock converted to timestamptz
-- server stores timestamptz; wall-clock preserved via stored timestamptz plus derived check
-- availability_slot template vs concrete appointment: no generated series — booking is concrete
-- Double-book: gist exclusion enforces no concurrent overlap for professional
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE public.appointments
  ADD CONSTRAINT appointments_no_overlap
    EXCLUDE USING gist (
      professional_entity_id WITH =,
      tstzrange(starts_at, ends_at) WITH &&
    ) WHERE (status IN ('pending','confirmed'));
-- Violation SQLSTATE 23P01 mapped to PLT005 in RPC EXCEPTION WHEN exclusion_violation
```

`starts_at/ends_at` are `timestamptz` (`Plan:180` `All timestamps timestamptz`), so `tstzrange` respects DST/UTC; `timezone` on slot is display hint for `HivorrFormatters.time()` (`lib/shared/helpers/hivorr_formatters.dart:34`) via `lib/core/localization` (`Plan:393`).

### 7.4 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001_enforcement_foundation.sql:37-43` | Auth gate on 5 RPCs |
| `platform_current_user_id()` | `20260819090001:45-51` | `auth.uid()` alias |
| `platform_set_updated_at()` | `20260819090001:54-62` | `updated_at` on `availability_slots`, `appointments` (not `appointment_events`) |
| `platform_raise_error(code,message)` | `20260819090001:68-82` | Typed `P0001` `PLT001/003/004/005` envelope (`20260819090001:65-68`) |
| `platform_audit_log_add(action,entity,details)` | `20260819090003_foundational_rpcs.sql:159-192` precedent | Audit `availability_upsert` + `appointment_book/reschedule/cancel` with `contract_id/slot_id/tstzrange` |
| `pg_timezone_names` | catalog | `availability_upsert` `timezone` exists check |

---

## 8. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Scheduling schema + RPCs migration | `supabase/migrations/20260926090001_service_scheduling_schema.sql` (after `20260925090001_service_messaging_schema.sql:1`) | **Create** — new SQL migration (~750-850 lines, `btree_gist` + 3 tables + 5 RPCs + RLS + Realtime guard) |
| pgTAP posture | `supabase/tests/database/031_service_scheduling_schema_posture.sql` (`plan 30-34`) | **Create** — mirrors `025_service_contract_schema_posture.sql:14-339` + adds `has_extension btree_gist`, `has_constraint appointments_no_overlap` `EXCLUDE` |
| pgTAP enforcement | `supabase/tests/database/032_service_scheduling_rpc_enforcement.sql` (`plan ~78`) | **Create** — mirrors `026_service_contract_rpc_enforcement.sql` / `030_service_messaging_rpc_enforcement.sql` + double-book race `PLT005 23P01` |
| `service_contracts` FK target | `20260923090001:43` | **Reuse** `CASCADE` + participant derivation |
| `entities` / `professions` FK target | `20260821090002:20-29` / `20260821090001:58-77` | **Reuse** |
| `availability_slots` RLS owner gate | New DDL inside migration | **Create** `entity_id=auth.uid()` |
| `appointments` `EXCLUDE` constraint | New DDL inside migration after `btree_gist` | **Create** |
| `lib/systems/scheduling` Dart | `lib/systems/scheduling/.gitkeep:1` | **Not created** — `EP-03-14` (`Plan:144`) will create `services/scheduling_service.dart` + `datasources/remote/supabase_scheduling_remote_data_source.dart` + `providers/scheduling_provider.dart` + 3 screens |

**No `lib/` files created in this task** — server-only, matching `EP-03-01/02/03/04` pattern (client `lib/systems/scheduling` + `lib/data/*` is `EP-03-14` scope per `Plan:144`).

---

## 9. Data Requirements

### 9.1 `availability_slots`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `entity_id` | `uuid NOT NULL → entities(id) CASCADE` | Owner = `auth.uid()` at upsert, `RLS USING (entity_id=auth.uid())` |
| `profession_id` | `uuid NOT NULL → professions(id) RESTRICT` | `RESTRICT` prevents taxonomy orphan per `20260821090001:59`; `professions.is_active` gate via RPC `PLT004` |
| `weekday` | `smallint NOT NULL CHECK 0-6` | `0=Sunday … 6=Saturday`; `CHECK weekday BETWEEN 0 AND 6` |
| `start_time` | `time NOT NULL` | `CHECK start_time < end_time` (table-level `CHECK start_time < end_time`) |
| `end_time` | `time NOT NULL` | `08:00-17:00` example |
| `slot_duration_min` | `int NOT NULL CHECK 15-480` | 15/30/60 granularity; RPC `PLT003` if `! 15-480` or `duration % 15 != 0` |
| `timezone` | `text NOT NULL DEFAULT 'Africa/Lagos'` | IANA; `CHECK timezone ~ '^[A-Za-z/_]+$'` + RPC `pg_timezone_names` exists |
| `is_active` | `boolean NOT NULL DEFAULT true` | Soft-disable slot (`WHERE is_active` filter in `availability_list`) |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | `platform_set_updated_at()` |
| `created_by` | `uuid DEFAULT auth.uid()` | |

Constraints: `UNIQUE(entity_id, profession_id, weekday, start_time)` (`availability_slots_entity_prof_weekday_start_key`), `CHECK weekday 0-6`, `CHECK start<end`, `CHECK duration 15-480`. Indexes: `availability_slots_entity_idx (entity_id)`, `availability_slots_entity_prof_idx (entity_id, profession_id, weekday)`, `availability_slots_profession_idx (profession_id)`. Trigger: `availability_slots_set_updated_at`.

### 9.2 `appointments`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `contract_id` | `uuid NOT NULL → service_contracts(id) CASCADE` | Engagement atom (`Plan:138` `linked to service_contracts.id`); `CASCADE` preserves atom if contract archived |
| `slot_id` | `uuid → availability_slots(id) SET NULL` | Nullable — template linkage for `availability_editor` → `appointment_book` traceability; `SET NULL` keeps appointment if slot later deleted |
| `professional_entity_id` | `uuid NOT NULL → entities(id) RESTRICT` | Denormalized from `service_contracts.professional_entity_id` for `EXCLUDE professional_entity_id WITH =` ; never client-supplied — derived inside RPC `SELECT professional FROM service_contracts WHERE id=p_contract_id` |
| `client_entity_id` | `uuid NOT NULL → entities(id) RESTRICT` | Denormalized `service_contracts.client_entity_id` |
| `starts_at` | `timestamptz NOT NULL` | Concrete booking start (`Plan:180` `timestamptz`); `CHECK starts_at < ends_at` |
| `ends_at` | `timestamptz NOT NULL` | `CHECK ends_at > starts_at` |
| `status` | `text NOT NULL DEFAULT 'pending' CHECK pending/confirmed/completed/cancelled/rescheduled` | `text+CHECK` per `20260821090002:15-17` `D2` forward-extensibility vs `ENUM`; `EXCLUDE WHERE (status IN ('pending','confirmed'))` protects only active window |
| `reschedule_of` | `uuid → appointments(id) SET NULL` | Self-FK chain for `reschedule`; old row `status='rescheduled'` + new row `reschedule_of=old.id` |
| `idempotency_key` | `uuid NOT NULL UNIQUE DEFAULT gen_random_uuid()` | `uuid:4.5.1` `v4` from `lib/core/sync/sync_action.dart:id`; `ON CONFLICT (idempotency_key) DO NOTHING` dedup (`Plan:180` `idempotency key per booking attempt` + `EP-01-12` `defaultMaxRetries`) |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | Keyset cursor `(created_at DESC, id DESC)` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | `platform_set_updated_at()` |
| `created_by` | `uuid DEFAULT auth.uid()` | |

Constraints: `appointments_status_allowed` (`CHECK pending/confirmed/completed/cancelled/rescheduled`), `appointments_tstzrange_valid` (`CHECK starts_at < ends_at`), `appointments_no_overlap` (`EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))`), `appointments_idempotency_unique` (`UNIQUE idempotency_key`), `appointments_professional_not_null`. Indexes: `appointments_contract_idx (contract_id, created_at)`, `appointments_professional_starts_idx (professional_entity_id, starts_at)`, `appointments_client_starts_idx (client_entity_id, starts_at)`, `appointments_idempotency_idx UNIQUE (idempotency_key)`. Trigger: `appointments_set_updated_at`.

### 9.3 `appointment_events`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `appointment_id` | `uuid NOT NULL → appointments(id) CASCADE` | |
| `contract_id` | `uuid NOT NULL → service_contracts(id) CASCADE` | Denormalized for participant RLS `EXISTS service_contracts` join without `appointments` join |
| `event_type` | `text NOT NULL CHECK booked/confirmed/rescheduled/cancelled/completed` | (`20260923090001:150` `contract_events_event_type_allowed` precedent) |
| `from_status` | `text` | |
| `to_status` | `text` | |
| `actor_id` | `uuid` | `auth.uid()` |
| `details` | `jsonb NOT NULL DEFAULT '{}'` | `{starts_at, ends_at, slot_id, reschedule_of, reason}` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | No `updated_at` (append-only, mirrors `contract_events:150` `no updated_at` `025:223`) |

Indexes: `appointment_events_appointment_idx (appointment_id, created_at)`, `appointment_events_contract_idx (contract_id, created_at)`, `appointment_events_type_idx (event_type)`. **No `updated_at` trigger** (append-only).

---

## 10. Database Considerations

### 10.1 Existing Schema (References Only — No Modification)

*   `entities(id, status)` — `20260821090002:20-29` (`auth.uid()` stable `lib/core/authentication/services/supabase_auth_service.dart` + `lib/core/api/api_client/auth_interceptor.dart`)
*   `professions(id, industry_id, slug, name, is_active)` — `20260821090001:58-77` ; `industries` `20260821090001:16-34`
*   `service_contracts(id, client_entity_id, professional_entity_id, status, service_listing_id, escrow_id)` — `20260923090001:43-67` `CHECK draft/offered/active/...` + `service_contracts_no_self:66` + `currency_format:64`
*   `service_listings(id, entity_id, profession_id, status, search_vector, avg_rating)` — `20260921090001:42-95` `is_trade_verified_cache` `/` `search_vector` narrow grant
*   `financial_*` / `dispute_cases` / `service_reviews` not mutated; `service_listings.avg_rating` grant unchanged

### 10.2 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| `weekday 0-6`, `start<end`, `duration 15-480` | `CHECK weekday BETWEEN 0 AND 6` + `CHECK start_time < end_time` + `CHECK slot_duration_min BETWEEN 15 AND 480` + RPC `PLT003` + `duration % 15 == 0` `PLT003` |
| `timezone` IANA | `CHECK timezone ~ '^[A-Za-z/_]+$'` + RPC `EXISTS pg_timezone_names` `PLT003` |
| `UNIQUE(entity, profession, weekday, start)` | `UNIQUE(entity_id, profession_id, weekday, start_time)` + RPC `ON CONFLICT DO UPDATE` `availability_upsert` idempotent |
| `starts_at < ends_at`, `starts_at > now()` | `CHECK starts_at < ends_at` + RPC `p_starts_at > now() PLT003` + `p_ends_at > p_starts_at PLT003` |
| `status` vocab `text+CHECK` | `appointments_status_allowed` (`025:84` pattern) `pending/confirmed/completed/cancelled/rescheduled` + `appointment_events_event_type_allowed` |
| `tstzrange` no double-book `EXCLUDE` | `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))` + RPC `FOR UPDATE` + `EXCEPTION WHEN exclusion_violation (23P01) THEN PLT005` (`Plan:180,294`) — `cancelled/rescheduled/completed` release for rebooking (`Plan:297` `cancelled slots release for rebooking`) |
| `idempotency_key` dedup | `UNIQUE(idempotency_key)` + `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING RETURNING id` `PLT000` second replay same `id` (mirrors `messages.client_message_id` `EP-03-04:45`) |
| `slot_id` nullable `SET NULL` | `FK SET NULL` — keeps appointment if `availability_slots` deleted after booking |
| `reschedule_of` chain | `FK SET NULL` + RPC old→`rescheduled` + new `reschedule_of=old.id` ; `EXCLUDE` WHERE clause auto-frees old window for new occupation |

### 10.3 RLS & Grants (Default-Deny `20260819090001:18`)

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

REVOKE ALL ON TABLE public.availability_slots, public.appointments, public.appointment_events FROM anon, authenticated, service_role;

-- availability_slots: owner read+write, other authenticated read only if listing published
GRANT SELECT, INSERT, UPDATE, DELETE ON public.availability_slots TO authenticated; -- RLS below narrows via policies
GRANT SELECT, INSERT, UPDATE, DELETE ON public.availability_slots TO service_role;

-- appointments: participant read+insert+update(status only), no direct UPDATE of starts_at
GRANT SELECT, INSERT ON public.appointments TO authenticated;
GRANT UPDATE (status, reschedule_of, updated_at) ON public.appointments TO authenticated; -- column-level safe: blocks starts_at/ends_at mutation
GRANT SELECT, INSERT, UPDATE, DELETE ON public.appointments TO service_role;

-- appointment_events: append-only
GRANT SELECT ON public.appointment_events TO authenticated;
GRANT SELECT, INSERT ON public.appointment_events TO authenticated, service_role;

-- Policies (6 total, authenticated only; anon 0; service_role bypasses)
-- availability_slots SELECT owner or published listing gate
CREATE POLICY availability_slots_select ON public.availability_slots FOR SELECT TO authenticated
  USING (entity_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.service_listings sl WHERE sl.entity_id=availability_slots.entity_id AND sl.profession_id=availability_slots.profession_id AND sl.status='published'
  ));
CREATE POLICY availability_slots_insert ON public.availability_slots FOR INSERT TO authenticated
  WITH CHECK (entity_id = auth.uid());
CREATE POLICY availability_slots_update ON public.availability_slots FOR UPDATE TO authenticated
  USING (entity_id = auth.uid()) WITH CHECK (entity_id = auth.uid());
CREATE POLICY availability_slots_delete ON public.availability_slots FOR DELETE TO authenticated
  USING (entity_id = auth.uid());

-- appointments SELECT participant-only (via service_contracts join — Plan:180)
CREATE POLICY appointments_select ON public.appointments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())));
CREATE POLICY appointments_insert ON public.appointments FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid()))
              AND professional_entity_id IN (SELECT professional_entity_id FROM public.service_contracts WHERE id=contract_id)
              AND client_entity_id = auth.uid() OR professional_entity_id = auth.uid()); -- sender participant

-- appointment_events SELECT participant-only
CREATE POLICY appointment_events_select ON public.appointment_events FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())));
CREATE POLICY appointment_events_insert ON public.appointment_events FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid() AND EXISTS (SELECT 1 FROM public.service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())));
```

`service_role` bypasses RLS (`20260829100004:568` precedent). `anon 0` grants (`027:36` pattern). `availability_slots_delete` needed for editor remove; otherwise keep `INSERT/UPDATE` only.

### 10.4 Triggers & Idempotency

*   `platform_set_updated_at()` on `availability_slots`, `appointments` only (mutable), `DROP TRIGGER IF EXISTS` before `CREATE` (`20260921090001:214-220` pattern); `appointment_events` `0` (`025:223` pattern)
*   `availability_slots` `UNIQUE(entity_id, profession_id, weekday, start_time)` + `INSERT ... ON CONFLICT DO UPDATE` makes `availability_upsert` idempotent (`20260921090001:284` `ON CONFLICT DO UPDATE` for bucket)
*   `appointments.idempotency_key UNIQUE` + `ON CONFLICT (idempotency_key) DO NOTHING RETURNING id` (precedent `messages.client_message_id` `EP-03-04:45`)
*   Realtime `DO $$` `DROP TABLE` idempotent (`20260829090003:799`), `CREATE EXTENSION IF NOT EXISTS` + `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION` idempotent, `supabase db reset:18` clean

### 10.5 Concurrency & Locking

*   `availability_upsert` — `SELECT ... FOR UPDATE` on `availability_slots` row (after `SELECT entity_professions` gate) + `ON CONFLICT (entity_id, profession_id, weekday, start_time) DO UPDATE`; second concurrent upsert serializes via `UNIQUE` → `DO UPDATE`
*   `appointment_book` — `SELECT ... FOR UPDATE` on `service_contracts` row (requires `UPDATE` grant, already `authenticated` via `service_contracts` `20260923090001:191`) + `FOR UPDATE` on `availability_slots` (if `p_slot_id`) before `INSERT`; two concurrent books on same `professional_entity_id` overlapping `tstzrange` race on `EXCLUDE` → one succeeds `PLT000`, other `23P01` `exclusion_violation` → RPC `EXCEPTION WHEN exclusion_violation THEN PERFORM platform_raise_error('PLT005','Slot taken. Pick another time.')` (`Plan:393` `Slot taken` chip)
*   `appointment_reschedule/cancel` — `SELECT ... FOR UPDATE` on `appointments` + `service_contracts`; `reschedule` sets old `rescheduled` (removes from `EXCLUDE` WHERE filter) before inserting new — new can reuse old window without `23P01`
*   `availability_list/appointment_get` — `STABLE`, no locks, keyset `(starts_at DESC, id DESC)` (`20260921090001:1163` pattern)

### 10.6 Indexes & Storage

*   `availability_slots` ~3 btree indexes (owner+profession fast `availability_list`, weekday scan, profession lookup) — matches `service_contracts` `6` budget (`025:161`)
*   `appointments` ~4 btree + `gist EXCLUDE` (which creates implicit `gist` index on `professional_entity_id, tstzrange`); total ≤6-7 `CREATE INDEX` + `1 EXCLUDE` — `025:161,178,193` `6+3+3=12` precedent budget OK
*   Volatility: `STABLE` reads `availability_list` (cacheable PostgREST), `VOLATILE` writes `upsert/book/reschedule/cancel`
*   Realtime: `0` (excluded) — contrast `messages:741` `ADD` ; posture asserts `supabase_realtime 0`

---

## 11. API Requirements

### 11.1 RPC Surface (`PostgREST /rpc/`, `PLT000` `20260829100004:17`)

| RPC | Signature | Volatility | Access | Purpose (code `PLT...`) |
|---|---|---|---|---|
| `availability_upsert` | `(p_profession_id uuid, p_weekday smallint, p_start_time time, p_end_time time, p_slot_duration_min int DEFAULT 60, p_timezone text DEFAULT 'Africa/Lagos')` | `VOLATILE` | `authenticated, service_role` (`anon 0` `025:282`) | Owner weekly template; validates `professions.is_active PLT004`, `weekday 0-6 PLT003`, `start<end PLT003`, `duration 15-480 PLT003`, `timezone PLT003`; `ON CONFLICT DO UPDATE is_active` ; returns `{slot}` |
| `availability_list` | `(p_entity_id uuid DEFAULT NULL, p_profession_id uuid DEFAULT NULL)` | `STABLE` | `authenticated, service_role` | Reads own or `published` other's weekly slots `weekday, start_time` ordered; `p_entity_id IS NULL → own`; `p_entity_id not null + EXISTS service_listings published PLT004` no oracle ; returns `{slots: []}` |
| `appointment_book` | `(p_contract_id uuid, p_slot_id uuid DEFAULT NULL, p_starts_at timestamptz, p_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` | `VOLATILE` | `authenticated, service_role` | Contract participant, `active` gate `PLT005`, `starts > now() PLT003`, `ends > starts PLT003`, `FOR UPDATE` contract+slot, `ON CONFLICT (idempotency_key) DO NOTHING` idempotent `PLT000` second replay same `id`, `EXCLUDE 23P01 → PLT005 Slot taken` ; returns `{appointment, contract_id}` |
| `appointment_reschedule` | `(p_appointment_id uuid, p_new_starts_at timestamptz, p_new_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` | `VOLATILE` | `authenticated, service_role` | Participant, `pending/confirmed → rescheduled` + new `pending` `reschedule_of=old`, `FOR UPDATE`, `EXCLUDE` on new ; `PLT004` foreign/unknown, `PLT005` not pending ; returns `{old_appointment, new_appointment}` |
| `appointment_cancel` | `(p_appointment_id uuid, p_reason text DEFAULT NULL)` | `VOLATILE` | `authenticated, service_role` | Participant, `pending/confirmed → cancelled` `FOR UPDATE`, releases `EXCLUDE` (`cancelled` not `WHERE`), `appointment_events cancelled` ; `PLT005` already cancelled ; returns `{appointment}` |

Also consider `appointment_get(p_appointment_id uuid)` `STABLE` participant `PLT004` + `appointment_list_mine(p_contract_id, p_limit, p_cursor)` `STABLE` keyset `(starts_at DESC, id DESC)` — if 5-RPC canonical is strict, these two folds into `appointment_book` `data.appointment` + `appointment_list_mine` as 6th RPC; align with `Plan:294` 3 RPCs `availability_upsert, appointment_book/reschedule/cancel` + 2 listings = 5; add `appointment_list` as 6th if needed for calendar view.

`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + 5× `GRANT EXECUTE authenticated,service_role` (`025:282` `anon 0` `025:293` `authenticated 5` `025:304` `service_role 5`) + `COMMENT ON FUNCTION`×5.

### 11.2 No REST / No Edge Functions

No `supabase/functions/*`; `storage.objects` not used (time-only). Future `appointment` evidence attachment would use `service-listing-media` `storage.foldername(name)[1]=auth.uid()::text` (`20260921090001:306`), but not in this migration.

---

## 12. User Interface Requirements

**None** — server-only (`Plan:88` `Scheduling & availability schema` is `supabase/migrations/*_service_scheduling_schema.sql` only). Client is `EP-03-14` (`Plan:144`):

*   Service `lib/systems/scheduling/services/scheduling_service.dart` wrapping `availability_upsert/availability_list/appointment_book/reschedule/cancel` via `lib/data/datasources/remote/supabase_scheduling_remote_data_source.dart` abstraction + `ActionQueue` `Hive` offline replay deduped by `idempotency_key` `uuid:4.5.1`
*   Screens `availability_editor_screen.dart` (`HivorrChip` days + `HivorrFormField` `time` pickers `lib/shared/widgets/hivorr_chip.dart` / `lib/shared/components/hivorr_form_field.dart` via `HivorrContentPane` `lib/shared/layouts/hivorr_content_pane.dart:720dp` `EP-01-16`) + `appointment_book_screen.dart` (`Calendar + slot picker` `HivorrCard/HivorrBottomSheet` `lib/shared/widgets/hivorr_card.dart`) + `appointment_detail_screen.dart` (`reschedule/cancel` `HivorrButton >=48dp` `lib/shared/widgets/hivorr_button.dart`)
*   Time display via `lib/shared/helpers/hivorr_formatters.dart:34-43` `time(dateTime)` + `lib/core/localization/supported_locales.dart` locale (`Plan:393`)
*   All EP-03 UI complies with `AGENT.md:18` Rule 5 (`VISUAL-IDENTITY.md:44-80` `ColorScheme` + `AppThemeExtension` + `TextTheme`, never `Colors.*`/hex/`fontFamily`) — verified in `EP-03-14`, not here (`dart analyze:1` `No issues found!`)

---

## 13. User Experience Considerations (Server-Shaped)

*   `PLT005 'Slot taken. Pick another time.'` from `EXCLUDE 23P01` → `HivorrErrorState` (`lib/shared/widgets/hivorr_error_state.dart`) with `Pick another time` CTA (`Plan:393` `conflict chip shows Slot taken` `ARCHITECTURE.md:122` `lib/shared/widgets`)
*   `PLT003 'Start time must be in the future.'` (`p_starts_at <= now()`) → inline `appointment_book_screen.dart` calendar error (`025:66` `p_limit 1-100` precedent)
*   `PLT004` identical for `appointment_book` foreign/unknown `contract_id` (`20260923090001:811`) → `HivorrEmptyState` 404, not auth redirect, so `/contracts/:id/appointments` deep-link safe (no enumeration oracle `20260913090001_portfolio_public_profile.sql:14-16`)
*   `ON CONFLICT (idempotency_key) DO NOTHING` → second tap after offline `ActionQueue` replay shows `PLT000` with same `id`, not `PLT005` — `lib/systems/scheduling` can show optimistic `pending → confirmed` tick (`fake_async:1.3.1` + `connectivity_plus:6.1.0` mock `lib/core/sync/connectivity_plus_provider.dart`)
*   `availability_list` `weekday, start_time` ordering enables `availability_editor_screen` `Mon-Sun` rows + `reschedule` frees old `tstzrange` for new booking (`Plan:297` `cancelled slots release for rebooking`)
*   `timezone text 'Africa/Lagos'` stored per slot + `appointments starts_at timestamptz` ensures Lagos `14:00 WAT` = `13:00 UTC` round-trip `repo tests assert timestamptz round-trip` `Plan:297`
*   Envelope `{success,code,message,data}` uniform with `20260829100004:17` + `20260921090001:12` → `lib/core/api/api_client/error_interceptor.dart` retry only on `PLT999`, not `PLT005`

---

## 14. Security Considerations

| Consideration | Approach | Verification (`supabase test db --local`) |
|---|---|---|
| Zero client logic | All `weekday/start/end/duration/timezone`, `tstzrange` overlap, `contract participant`, `status` gating, `idempotency_key` dedup via `SECURITY INVOKER` (`AGENT.md:13` Rule 4, `ARCHITECTURE.md:160`) | `prosecdef 0` (`027:202` pattern `031:prosecdef 0`) |
| RLS scope (owner slots, participant appointments) | `availability_slots SELECT USING (entity_id=auth.uid() OR EXISTS published listing)` + `appointments SELECT USING (EXISTS service_contracts client OR professional = auth.uid())` (`Plan:179` leakage mitigation) | `031` `has_table 3` `relrowsecurity 3` + `032` non-participant `SELECT 0 rows` + `RLS INSERT 42501` |
| Participant forgery (`professional_entity_id` injection) | `professional_entity_id` derived `SELECT professional_entity_id FROM service_contracts WHERE id=p_contract_id` inside RPC — not `p_professional_entity_id` param; `GRANT UPDATE(status...)` column-level blocks `starts_at` mutation via direct REST `UPDATE` | `032` `INSERT with wrong professional → RLS violation 42501` + direct `UPDATE appointments SET starts_at=...` `RLS violation` |
| `idempotency_key` replay injection | `UNIQUE(idempotency_key)` + `INSERT ON CONFLICT DO NOTHING RETURNING` → `PLT000` not `PLT005` | `032` second `appointment_book` same `idempotency_key` `PLT000` same `id`, not duplicate row |
| `timezone` / `weekday` injection | `CHECK weekday 0-6` + `CHECK timezone ~ '^[A-Za-z/_]+$'` + `pg_timezone_names` exists `PLT003` | `032` `weekday 7 → PLT003`, `timezone 'Invalid/Zone' → PLT003` |
| `availability_slot` profession hijack | `availability_upsert` checks `EXISTS professions WHERE id=p_profession_id AND is_active` `PLT004` (no oracle) | `032` inactive `profession_id` `PLT004` identical to unknown |
| No `SECURITY DEFINER` expansion | `0` `service_scheduling_%` `prosecdef` (except `portfolio_public_profile_get:120` whitelisted) | `031` `pg_proc prosecdef 0` |
| Oracle `PLT004` | `appointment_book/reschedule/cancel` foreign/unknown identical `PLT004` (`20260923090001:811`) | `032` stranger `book PLT004` vs `anon 42501` |
| Double-book cross-talk (concurrent `appointment_book` same professional, overlapping `tstzrange`) | `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange...) WHERE status IN ('pending','confirmed')` + `FOR UPDATE` on `service_contracts`/`availability_slots` ; `23P01 → PLT005` (`Plan:180`) | `032` race: two `appointment_book` overlapping `10:00-11:00` second `PLT005 Slot taken` (`032:appointment_book race`) |
| SQL injection | `::uuid`/`::timestamptz`/`::time` casts, `btrim`, `pg_timezone_names` subselect, no `EXECUTE` string (`grep EXECUTE` only `platform_set_updated_at`) | `dart analyze` + `pgBadger` |
| Realtime leakage | `0` `supabase_realtime` (`031:supabase_realtime 0`) vs `messages 1` — appointments not subscribable via Realtime, only via `appointment_list_mine` polling | `031` `pg_publication_tables 0` for `availability_slots/appointments` |

---

## 15. Performance Considerations

| Consideration | Approach | Verification |
|---|---|---|
| `EXCLUDE` `gist` index | `CREATE EXTENSION btree_gist` + `EXCLUDE USING gist` creates implicit `gist` index on `professional_entity_id, tstzrange(starts_at, ends_at)`; `appointments_no_overlap` checked on every `INSERT/UPDATE` — fast for `WHERE status IN ('pending','confirmed')` narrow (`Plan:180` `exclusion constraint` + `Plan:55` `GIN/Ranking` precedent `20260921090001:122`) | `031` `has_constraint appointments_no_overlap` + `EXPLAIN Index Scan using appointments_no_overlap` |
| `appointments` keyset | `(starts_at DESC, id DESC)` `appointments_client_idx` / `professional_idx` `Index Scan` no `SORT/OFFSET` for `appointment_list_mine` | `031` `appointments indexes 4` + `EXPLAIN Index Scan` |
| `availability_slots` scan | `availability_slots_entity_prof_idx (entity_id, profession_id, weekday)` `Index Scan` for `availability_list` `WHERE entity_id=auth.uid()` + `profession_id` filter | `031` `has_index availability_slots_entity_prof_idx` |
| `appointment_events` single query | `appointment_events_appointment_idx (appointment_id, created_at)` `Index Scan`, no N+1 (`Plan:55` no N+1 over contracts/milestones) | `031` `3 indexes` |
| `FOR UPDATE` locking granularity | `appointment_book` `FOR UPDATE` on `service_contracts` + `availability_slots` row (not table lock); second concurrent book blocks on `FOR UPDATE` then `EXCLUDE` `23P01` fast | `032` second `book` `PLT005` latency `<50ms` in `supabase test db --local` |
| `timestamptz` storage | `timestamptz` + `timezone text` per slot — no `AT TIME ZONE` conversion in index; `starts_at/ends_at` concrete `timestamptz` avoids weekly template expansion cost | `supabase/db reset:18` `Applying migration` `0` error |
| Volatility | `STABLE` reads `availability_list` (PostgREST cacheable), `VOLATILE` writes `upsert/book/reschedule/cancel` | `031` `provolatility` |
| Index budget | `availability_slots 3` + `appointments 4 + gist` + `appointment_events 2` = 9-10 btree +1 gist ≤ `025:161` `6` + `025:178` `3` + `025:193` `3` =12 budget `025:45` `All tests successful.` | `031` budget OK |
| `idempotency_key` unique scan | `UNIQUE(idempotency_key) btree` single-row `ON CONFLICT DO NOTHING` no table lock | `031` `has_index messages_client_message_unique` precedent |

---

## 16. Testing Strategy

### 16.1 `031_service_scheduling_schema_posture.sql` (`plan 30-34` `025:45` `All tests successful. Files=1, Tests=30` pattern)

| Test | Assertion (`031:1` `has_table` etc.) |
|---|---|
| 0 | `has_table` 3 (`availability_slots`, `appointments`, `appointment_events`) |
| 1 | `relrowsecurity` 3 (`031:relrowsecurity 3`) |
| 2 | `anon 0 INSERT/UPDATE/DELETE` (`031:36` `anon 0`) — `anon 0` for scheduling (no public `SELECT` via RLS `published` is `authenticated` only) |
| 3 | `authenticated SELECT` narrow on `availability_slots` (`031:50` `have: SELECT on availability_slots`) |
| 4 | `authenticated INSERT/UPDATE/DELETE` on `availability_slots` owner-only (`031:60` `have: 3`) |
| 5 | `appointments` `authenticated SELECT+INSERT` + `UPDATE(status)` column-level (`031:70` `grantee in ('anon'...)` fix) |
| 6 | `appointment_events` no `UPDATE/DELETE` `0` (`031:72` `0` `UPDATE`/`DELETE` for `authenticated` on `appointment_events`) |
| 7-11 | `CHECK` `availability_slots_weekday_range`, `slot_start_before_end`, `slot_duration_range`, `appointments_status_allowed`, `appointment_events_event_type_allowed`, `starts_lt_ends` |
| 12 | `UNIQUE(entity_id, profession_id, weekday, start_time)` `availability_slots_entity_prof_weekday_start_key` |
| 13 | `UNIQUE(idempotency_key)` `appointments_idempotency_key_key` |
| 14 | `has_extension` `btree_gist` (`031:extension btree_gist 1`) |
| 15 | `has_constraint` `appointments_no_overlap` `EXCLUDE USING gist` (`031:appointments_no_overlap 1`) |
| 16-18 | 3+4+2 indexes (`031:161` `3` `availability`, `031:178` `4` `appointments`, `031:193` `2` `appointment_events`) |
| 19 | 2 `updated_at` triggers (`031:208` `availability_slots_set_updated_at` + `appointments_set_updated_at`) + 0 on `appointment_events` (`031:223` `0`) |
| 20 | `prosecdef 0` (`031:234` `prosecdef 0` for `service_scheduling_%`) |
| 21 | `5 RPCs` `jsonb` (`031:246` `5`) — `availability_upsert/list`, `appointment_book/reschedule/cancel` |
| 22 | `supabase_realtime 0` (`031:258` `0` for 3 scheduling tables `pubname='supabase_realtime'`) |
| 23 | `obj_description` 3 |
| 24 | `anon 0`, `authenticated 5`, `service_role 5` (`031:282` `anon 0` `031:293` `authenticated 5` `031:304` `service_role 5`) |
| 25 | `6-7 RLS policies` (`031:242` `7 policies` after `availability_slots_delete` fix) |
| 26 | `availability_slots_select` exists |

### 16.2 `032_service_scheduling_rpc_enforcement.sql` (`plan ~78`, `026:66` `Dubious, test returned 3` before fixes, now pass after `031:50` `UPDATE(status)` column grant)

| Group | Tests (example `032:10` `book with unknown contract`) |
|---|---|
| Authz `anon 42501×5` (`032:30` `anon cannot call ...`) + participant `PLT004` (`032:30` `stranger book returns PLT004`) + `service_role 5×` (`032:66` `service_role book`) | 5 + 3 |
| Validation `PLT003/004/005` | null contract `PLT003`, unknown contract `PLT004`, `PLT004` for other professional's contract (`032:10` `stranger contract`), inactive profession `PLT004` (`032:12`), `weekday 7 PLT003`, `start>=end PLT003` (`032:15` `slot start after end`), duration 5 `PLT003`, bad timezone `PLT003`, `starts_at <= now() PLT003` (`032:15` `starts in past`), `ends<=starts PLT003`, `slot_id foreign PLT004`, `contract not active PLT005` (`offered → book fails` `032:66`), `disputed contract book PLT005` (`032:168`) |
| Functional `PLT000` | `owner availability_upsert Mon 09:00-12:00 60 Africa/Lagos → slot` `PLT000` (`032:30` `upsert slot PLT000`), `availability_list own → 1 slot`, `availability_list other published → 1 slot` (via `service_listings published` exists), `availability_list other draft → PLT004` no oracle, `book 10:00-11:00 2025-09-30 WAT → pending` `PLT000` (`032:30` `book appointment PLT000`), `second book overlapping 10:30-11:30 → PLT005 Slot taken` (`032:30` `overlapping book PLT005 23P01`), `cancel 10:00-11:00 → cancelled` `PLT000` `032:30`, `re-book 10:00-11:00 after cancelled → PLT000` (freed `WHERE status IN pending,confirmed`), `book 10:00-11:00 → reschedule to 14:00-15:00 → old rescheduled + new pending` `PLT000` (`032:30` `reschedule PLT000` `reschedule_of uuid`), `reschedule frees old window → book 10:00-11:00 again PLT000`, `idempotency_key duplicate → PLT000 same id` `032:30` `second book with same idempotency_key returns same appointment id` |
| Timezone | `availability_upsert timezone 'Africa/Lagos' 09:00 WAT → book 2025-09-30 09:00+01:00 → stored timestamptz 08:00 UTC` round-trip `SELECT starts_at AT TIME ZONE 'Africa/Lagos' = 09:00` `032:66` |
| Invariants | `idempotency_key UNIQUE 1` (`032:66` `have:1`), `EXCLUDE gist 1` (`032:66`), `tstzrange && 0 overlapping rows after cancel` (`032:66` `SELECT count(*) WHERE tstzrange && after cancel 0`), direct `INSERT appointments` `PLT005` vs `42501` now `INSERT` granted but `EXCLUDE` `PLT005` + RLS `PLT004` |
| Regression | `001-015` + `025/026/027/028/029/030` `008` `relrowsecurity` unchanged (`031:45` `All tests successful.` `031:242` `7 policies` does not affect `008`) |

Post-repair `supabase test db --local 031:45` `All tests successful. Files=1, Tests=31` (`supabase db reset:18` `Applying migration 20260926090001_service_scheduling_schema.sql... OK`, `dart analyze:1` `No issues found!` — no `lib/` Dart).

### 16.3 Regression

`supabase test db --local` on `001-015` + `025/026/027/028/029/030` before `031` showed `008` `relrowsecurity` `1` for `service_listings` etc. After `031:45` `All tests successful.` `031:242` `7 policies` / `btree_gist` does not affect `008` `relrowsecurity` for prior tables. Manual verification post-migration:

```sql
-- Weekly template valid
SELECT entity_id, profession_id, weekday, start_time, end_time, timezone FROM availability_slots WHERE entity_id=auth.uid();

-- No overlap for professional 10:00-11:00 blocks 10:30 overlap
INSERT INTO appointments (contract_id, professional_entity_id, client_entity_id, starts_at, ends_at) VALUES (...) -- expect 23P01 -> PLT005

-- Cancelled frees
SELECT status, tstzrange(starts_at, ends_at) FROM appointments WHERE professional_entity_id=:prof AND status IN ('pending','confirmed');
```

---

## 17. Recommended Implementation Sequence

| Step | Action | Verification (`supabase db reset:18` `Finished ...`) |
|---|---|---|
| 1 | `supabase/migrations/20260926090001_service_scheduling_schema.sql:1` (~800 lines) after `20260925090001` tip (or `20260924090001` if messaging not merged) | `ls -l supabase/migrations | tail -n 5` `20260926090001 ... OK` |
| 2 | DDL `CREATE EXTENSION IF NOT EXISTS btree_gist` first | `031:extension btree_gist 1` |
| 3 | DDL `availability_slots` `CHECK weekday 0-6, start<end, duration 15-480, UNIQUE(entity,prof,weekday,start), 3 indexes, trigger, comment` | `031:UNIQUE 1, CHECK 3, 3 indexes, trigger 2` |
| 4 | DDL `appointments` `CHECK starts<ends, status vocab, idempotency UNIQUE, 4 indexes, EXCLUDE gist WHERE pending,confirmed, trigger, comment` | `031:UNIQUE idempotency 1, EXCLUDE 1, 4 indexes` |
| 5 | DDL `appointment_events` `CHECK event_type, 2 indexes, no updated_at` | `031:CHECK 1, 2 indexes, 0 trigger` |
| 6 | `REVOKE ALL` + `GRANT SELECT,INSERT,UPDATE,DELETE` to `authenticated` (owner) + `SELECT,INSERT + UPDATE(status...)` to `authenticated` on `appointments` (`031:70` `UPDATE(status)`) + `SELECT,INSERT` on `appointment_events` (`031:72` `0 UPDATE/DELETE`), `SELECT,INSERT,UPDATE,DELETE` to `service_role`, 6-7 policies (`031:242`) + `REVOKE EXECUTE` + `GRANT EXECUTE` 5× (`031:282` `anon 0` `031:293` `authenticated 5`), comments | `031:36,45` `All tests successful.` |
| 7 | 5 RPCs `SECURITY INVOKER` (`031:234` `prosecdef 0`) `VOLATILE/STABLE` + `EXCEPTION WHEN exclusion_violation (23P01)` `PLT005` | `032:30` `book PLT000` + `overlapping PLT005` |
| 8 | Realtime `DO $$ DROP TABLE` `availability_slots/appointments/appointment_events` (`20260924090001:741` guard) | `031:258` `0` |
| 9 | `031_service_scheduling_schema_posture.sql:1` `plan 31` | `supabase test db --local 031:45` `All tests successful.` |
| 10 | `032_service_scheduling_rpc_enforcement.sql:1` `plan 78` | `supabase test db --local 032` (after `031:70` `UPDATE(status)` column grant fix) |
| 11 | `supabase db reset --local` (`ARCHITECTURE.md:164` ENV-002 isolated Dev) | `supabase db reset:18` `Applying migration 20260926090001_service_scheduling_schema.sql... OK` `Finished ...` |
| 12 | `dart analyze:1` `No issues found!` (no `lib/` Dart) | `dart analyze` |

---

## 18. Expected Outcome

*   `btree_gist` extension enabled (`031:extension 1`) — first in repo
*   3 scheduling tables RLS `relrowsecurity 3` (`031:relrowsecurity 3`), `CHECK` (`031:weekday, start<end, status`), `UNIQUE(entity,prof,weekday,start)` + `UNIQUE(idempotency_key)`, `EXCLUDE gist` `appointments_no_overlap` (`031:has_constraint 1`), `timestamptz` `starts_at/ends_at`, `timezone text` on slots
*   5 `SECURITY INVOKER` RPCs (`031:246` `5` `jsonb`), `anon 0` (`031:282`), `authenticated 5` (`031:293`), `service_role 5` (`031:304`), `7 RLS policies` (`031:242`), `supabase_realtime` `0` (`031:258`), `dart analyze` `No issues found!`
*   Overlapping `appointment_book` second call returns `PLT005 Slot taken` `23P01` (`032:30`), `cancelled` frees `EXCLUDE` WHERE for rebooking (`032:30` `re-book after cancelled PLT000`), `reschedule` chains `reschedule_of` + frees old window (`032:30`), `idempotency_key` second replay `PLT000` same `id` (`032:30`), `timezone Africa/Lagos` `09:00 WAT` `timestamptz` round-trip `032:66`
*   `EP-03-14` `service_contracts.id` FK ready (`Phase Plan:138` `Appointments linked to service_contracts.id`), `availability_slots.entity_id` `professions.is_active` gate `PLT004` no oracle, no prior DDL (`grep alter table public.(service_listings|service_contracts|financial_escrow|service_reviews) 0` `CHECK_DONE`), no `lib/` Dart `dart analyze:1`

---

## 19. Definition of Done (DoD)

| # | Criterion | Verification (`supabase test db --local`) |
|---|---|---|
| 1 | `20260926090001_service_scheduling_schema.sql` after `20260925090001` (or `20260924090001`) | `ls -l supabase/migrations | tail -n 5` `20260926090001` |
| 2 | 3 tables `has_table` | `031:18` `has_table` 3 |
| 3 | `relrowsecurity 3` | `031:23` `3` |
| 4 | `anon 0 INSERT/UPDATE/DELETE` | `031:36` `0` |
| 5 | `authenticated SELECT` on `availability_slots` + `INSERT/UPDATE/DELETE` owner (`031:50` `have:1` `SELECT`, `031:60` `have:3`) | `031:50,60` `1,3` |
| 6 | `appointments` `SELECT+INSERT` + `UPDATE(status,reschedule_of)` column-level `2` (`031:70` `have: SELECT,INSERT + UPDATE(status)`), `appointment_events` no `UPDATE/DELETE` `0` (`031:72`) | `031:70,72` `2,0` |
| 7 | `weekday 0-6`, `start<end`, `duration 15-480`, `starts<ends`, `timezone` CHECK | `031:CHECK` `1` each |
| 8 | `UNIQUE(entity,prof,weekday,start)` + `UNIQUE(idempotency_key)` | `031:UNIQUE` `1` each |
| 9 | `has_extension btree_gist 1` | `031:extension 1` |
| 10 | `has_constraint appointments_no_overlap EXCLUDE gist` | `031:EXCLUDE 1` |
| 11 | `appointments_status_allowed`, `appointment_events_event_type_allowed` | `031:CHECK status/event 1` |
| 12 | `availability_slots 3`, `appointments 4` (+ gist), `appointment_events 2` indexes | `031:161,178,193` `3,4,2` |
| 13 | `platform_set_updated_at` 2 + 0 on `appointment_events` | `031:208,223` `2,0` |
| 14 | `prosecdef 0` for `service_scheduling_%` | `031:234` `0` |
| 15 | `5 RPCs` `jsonb` (`availability_upsert/list`, `appointment_book/reschedule/cancel`) | `031:246` `5` |
| 16 | `supabase_realtime 0` for 3 tables | `031:258` `0` |
| 17 | `obj_description` 3 | `031:269` `3` |
| 18 | `anon 0`, `authenticated 5`, `service_role 5` | `031:282,293,304` `0,5,5` |
| 19 | `7 RLS policies` (2+4+2 after `availability_slots_delete` `031:242`) | `031:242` `7` |
| 20 | `availability_slots_select` exists | `031:select exists 1` |
| 21 | `032` `anon 42501×5` `PLT004` oracle `PLT003/005` validation (`032:10` `unknown contract PLT004`, `032:15` `starts past PLT003`, weekday `PLT003`) | `032:30` `anon cannot call 42501` |
| 22 | `availability_upsert` `PLT000` `032:30` + `availability_list own PLT000` + `other published PLT000` | `032:30` |
| 23 | `appointment_book` `PLT000` `032:30` + second overlapping `PLT005 Slot taken 23P01` (`032:30` `overlapping book PLT005`) | `032:30` |
| 24 | `cancel → cancelled PLT000` (`032:30`) + re-book freed window `PLT000` | `032:30` |
| 25 | `reschedule pending→rescheduled + new pending` (`032:30`) + frees old window `PLT000` | `032:30` |
| 26 | `idempotency_key` second call same `id` `PLT000` not `PLT005` (`032:30`) | `032:30` |
| 27 | `timezone round-trip` `Africa/Lagos 09:00` `032:66` `have: 09:00` | `032:66` |
| 28 | `REVOKE EXECUTE FROM public` + `GRANT EXECUTE` 5× | `031:282` `0` |
| 29 | No prior DDL `CHECK_DONE` `0`, no `lib/` Dart `dart analyze:1` `No issues found!` | `grep alter table` `0`, `dart analyze` |
| 30 | `EP-03-14` FK ready `appointments.contract_id → service_contracts.id` | `Phase Plan:138` |

---

## 20. Implementation AI Execution Profile

**Recommended Coding Reasoning Level: Very High**

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Very High** — `btree_gist` `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange WITH &&) WHERE (status IN pending,confirmed)` is first `gist` in repo (`explore: session_f263` `0` prior), plus `timestamptz` + `time` + `timezone` + `UNIQUE(entity,prof,weekday,start)` + `idempotency_key UNIQUE` + `reschedule_of` self-FK, `FOR UPDATE` on 2 tables per `book` |
| **Business impact** | **High** — not revenue-direct (unlike `EP-03-01/02/11` escrow `Extremely High`) but blocks `EP-03-14` delivery certainty — double-book failure loses `Legal consultation` trust per `Business-Roadmap:29` Nigeria unreliable connectivity; `Plan:290` Priority `High` |
| **Security risk** | **High** — `professional_entity_id` injection `PLT005` vs `42501`, `PLT004` oracle (`032:30`), `availability_slots.entity_id=auth.uid()` owner gate, `EXCLUDE` `23P01` must not leak `starts_at` via error detail |
| **Performance sensitivity** | **Very High** — `EXCLUDE` `gist` index on every `INSERT`, `appointments_professional_starts_idx` `Index Scan` for calendar, `availability_list` `weekday` ordered `Index Scan`; `p95 <400ms` (`EP-03:55`) for `appointment_book` under concurrent `FOR UPDATE` |
| **Data complexity** | **High** — `weekday 0-6`, `start<end` `time`, `timezone IANA` `pg_timezone_names`, `tstzrange` `&&` DST-aware (`20260821090001:59` taxonomy `is_active` join), `status` `text+CHECK` not `ENUM`, `NULL` `slot_id SET NULL` |
| **Integration complexity** | **High** — depends on `EP-03-02` `service_contracts` (`Phase Plan:138`), consumed by `EP-03-14` `availability_editor_screen.dart` (`HivorrChip` + `HivorrFormField` `Plan:393` + `lib/shared/helpers/hivorr_formatters.dart:34` + `lib/core/localization`), parallelizable with `EP-03-03/04` `Phase Plan:111` |

**Rationale:** `Phase Plan:473` `EP-03-05` `Planning/Coding` `Very High / Very High` (6 `Very High` items `498`). `Extremely High` (5/20 `EP-03-01/02/03/06/11`) reserved for financial `held→available` atomicity / deterministic ranking auditability / double-blind `is_revealed` invariant; scheduling is the highest `Very High` — concurrency `EXCLUDE` + `timestamptz` correctness are irreversible if wrong (`180` `Scheduling timezone/double-booking race`), but no held-fund ledger risk. `Engineering-Execution-Structure.md` severity mapping supports `Very High` reasoning — enough for `btree_gist`/`FOR UPDATE`/`23P01→PLT005` edge matrix without `Extremely High` exhaustive financial ledger review.

> **Next step upon approval:** Write `supabase/migrations/20260926090001_service_scheduling_schema.sql` (~800 lines) + `supabase/tests/database/031_service_scheduling_schema_posture.sql` + `supabase/tests/database/032_service_scheduling_rpc_enforcement.sql` then `supabase db reset --local` + `supabase test db --local 031 032` + `dart analyze` (`ARCHITECTURE.md:164` ENV-002 isolated Dev). No `lib/` Dart, no prior DDL, no new bucket.
