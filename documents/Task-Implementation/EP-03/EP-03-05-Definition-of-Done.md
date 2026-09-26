# Definition of Done — EP-03-05: Scheduling & Availability Schema & Server-Side Rules

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-05 |
| **Task Name** | Scheduling & Availability Schema & Server-Side Rules |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 1 Marketplace Server Schema Foundation (parallelizable after EP-03-02) |
| **Priority** | High |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:1` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:290-299` + `88` + `180` + `294` |
| **Dependencies** | EP-03-02 `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43-67`), EP-01-06 `entities`/`professions`/`industries` (`supabase/migrations/20260821090001_entity_taxonomy_tables.sql:15-55`, `supabase/migrations/20260821090002_entity_core_tables.sql:20-256`), EP-02-04 financial rails not mutated, platform helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37-82` + `supabase/migrations/20260819090003_foundational_rpcs.sql:159-192`), EP-03-01 `service_listings` published gate (`supabase/migrations/20260921090001_service_marketplace_schema.sql:42-95`) |
| **Delivery Scope** | `CREATE EXTENSION btree_gist` (first) + 3 tables `availability_slots` / `appointments` / `appointment_events` (append-only) + `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN ('pending','confirmed'))` + 5 RPCs `SECURITY INVOKER` (`availability_upsert`, `availability_list`, `appointment_book`, `appointment_reschedule`, `appointment_cancel`) + participant/owner RLS + `REVOKE EXECUTE` re-baseline + `COMMENT ON`×5/3 + realtime exclusion (`DO $$ DROP`) + 2 pgTAP suites `031`/`032`. **Zero** `lib/` Dart, **zero** mutations to `service_listings`/`service_contracts`/`financial_*`/`service_reviews`. Unblocks EP-03-14 `lib/systems/scheduling`. |
| **Guardrails** | `documents/Context/AGENT.md:13` Rule 4 Database-First Zero-Trust, `documents/Context/AGENT.md:8` Rule 2 Two-Tier Taxonomy (via `professions.is_active`), `documents/Context/AGENT.md:7` Deterministic Core (no AI decides booking), `documents/Context/ARCHITECTURE.md:160-162` DB-First, `documents/Context/ARCHITECTURE.md:102` `lib/systems/scheduling` |

**How to use this document:** Check each box only after executing the listed verification (SQL query, `supabase db test`, PostgREST `/rpc/` call) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

Verifies user/system behaviors and RPC workflows defined in `EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:3` + `§7.2` + `§7.3`.

### 2.1 Required Functionality

- [ ] **availability_upsert** — Authenticated owner calls `availability_upsert(p_profession_id uuid, p_weekday smallint, p_start_time time, p_end_time time, p_slot_duration_min int DEFAULT 60, p_timezone text DEFAULT 'Africa/Lagos')` and receives `PLT000` with row `entity_id=auth.uid()`, `profession_id` validated `professions.is_active=true` else `PLT004` identical to unknown (no oracle `supabase/migrations/20260921090001_service_marketplace_schema.sql:1141` precedent), `weekday 0-6` else `PLT003`, `start_time < end_time` else `PLT003`, `slot_duration_min 15-480` (and `%15==0` optional) else `PLT003`, `timezone` IANA `~ '^[A-Za-z/_]+$'` + `EXISTS pg_timezone_names` else `PLT003`, `is_active` default true, `UNIQUE(entity_id, profession_id, weekday, start_time)` via `INSERT ... ON CONFLICT DO UPDATE`. Second upsert same key updates `end_time/duration/timezone` not duplicate.

- [ ] **availability_list** — `availability_list(p_entity_id uuid DEFAULT NULL, p_profession_id uuid DEFAULT NULL)` as `authenticated` returns `PLT000` with `{slots[]}` ordered `(weekday, start_time)`. Own slots always visible. Other entity's slots visible only if `EXISTS service_listings WHERE entity_id=p_entity_id AND status='published'` (published gate `supabase/migrations/20260921090001_service_marketplace_schema.sql:1141` `PLT004` no oracle). Inactive profession slots still returned but `upsert` blocked for that profession. No pagination — weekly set small.

- [ ] **appointment_book** — Participant (`service_contracts.client_entity_id=auth.uid() OR professional_entity_id=auth.uid()`) calls `appointment_book(p_contract_id uuid, p_slot_id uuid DEFAULT NULL, p_starts_at timestamptz, p_ends_at timestamptz, p_idempotency_key uuid DEFAULT gen_random_uuid())` when `service_contracts.status='active'` (not `disputed/cancelled/completed`) and `p_starts_at > now()` else `PLT003`, `p_ends_at > p_starts_at` else `PLT003`, `p_ends_at - p_starts_at <= 24h` else `PLT003`, with `FOR UPDATE` on `service_contracts` + `availability_slots` (if slot), `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING RETURNING id` dedups second replay same id `PLT000`, else relies on `EXCLUDE` `23P01` → `PLT005` `Slot taken. Pick another time.` On success `status='pending'` default, `professional_entity_id/client_entity_id` derived from contract not client-supplied, plus `appointment_events` `booked` + `platform_audit_log_add`.

- [ ] **appointment_reschedule** — Participant calls `appointment_reschedule(p_appointment_id uuid, p_new_starts_at timestamptz, p_new_ends_at timestamptz, p_idempotency_key uuid)` when `appointments.status IN ('pending','confirmed')` else `PLT005`, `new window > now()` `PLT003`, with `FOR UPDATE` on `appointments` + `service_contracts`. Sets old row `status='rescheduled'` (removes from `EXCLUDE WHERE`), inserts new row `status='pending'` with `reschedule_of=old.id`, same `EXCLUDE` check on new `tstzrange` `23P01 → PLT005`, idempotent via `idempotency_key`. Emits two `appointment_events` `rescheduled`.

- [ ] **appointment_cancel** — Participant calls `appointment_cancel(p_appointment_id uuid, p_reason text)` when `status IN ('pending','confirmed')` else `PLT005` (already `cancelled/rescheduled/completed` blocked), with `FOR UPDATE`. Sets `status='cancelled'` (frees `EXCLUDE WHERE status IN ('pending','confirmed')` for rebooking), inserts `appointment_events` `cancelled` with `details {reason}`.

### 2.2 Expected Workflows (End-to-End)

- [ ] **Owner template → discovery → book happy path:** (1) Pro `P` (owns `published` listing `L` in `corporate-lawyer`) `availability_upsert(profession_id=L.profession_id, weekday=1 (Mon), start=09:00, end=12:00, duration=60, timezone='Africa/Lagos')` → `PLT000` slot. (2) `availability_list(p_entity_id=P)` as consumer `C` (contract participant will be) → sees Mon 09:00 slot (via published gate). (3) `C` previously offered + `P` accepted `service_contracts` contract `CT` (`active` `supabase/migrations/20260923090001_service_contract_schema.sql:54`). (4) `C` calls `appointment_book(CT, slot_id, starts_at='2025-10-06 10:00+01:00', ends_at='2025-10-06 11:00+01:00')` → `PLT000` `pending` `professional=P` `client=C`. (5) `appointment_events` has `booked`.

- [ ] **Double-book race:** Same `P` same `CT1` book 10:00-11:00 → `PLT000`. Concurrent second book on same `P` overlapping 10:30-11:30 (different `CT2` but same `professional_entity_id`) → `PLT005` `Slot taken` via `EXCLUDE` `23P01` (`documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:180`). No double `pending` for same professional overlapping.

- [ ] **Cancel frees:** Book 10:00-11:00 → `appointment_cancel` → `cancelled`. Re-book 10:00-11:00 same `P` → `PLT000` (WHERE clause excluded `cancelled`, so no `23P01`).

- [ ] **Reschedule frees old window:** Book 10:00-11:00 → `appointment_reschedule` to 14:00-15:00 → old `rescheduled` + new `pending` 14:00. New book 10:00-11:00 now succeeds (old removed from active set).

- [ ] **Idempotency replay:** `appointment_book` with `p_idempotency_key=X` → `PLT000` id `A`. Immediate second `appointment_book` same `X` same payload (double-tap/offline replay `lib/core/sync/action_queue.dart` `uuid:4.5.1` `pubspec.yaml:82`) → `PLT000` same id `A`, no duplicate row (`ON CONFLICT DO NOTHING`).

- [ ] **Timezone round-trip:** Slot `timezone='Africa/Lagos'` 09:00 WAT. Book `2025-09-30 09:00 Africa/Lagos` (`09:00+01:00`) → stored `starts_at` `08:00 UTC` `timestamptz`. `SELECT starts_at AT TIME ZONE 'Africa/Lagos'` → `09:00` (`documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:297` `repo tests assert timestamptz round-trip`).

### 2.3 Success Conditions

- [ ] Every write RPC (`upsert/book/reschedule/cancel`) returns `{success:true, code:'PLT000', message:'...', data: to_jsonb(row)}` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19`).
- [ ] `availability_list` returns `{success:true, code:'PLT000', data:{slots[]}}` ordered `weekday, start_time`; `appointment_book` returns `{appointment {id, contract_id, professional_entity_id, client_entity_id, starts_at, ends_at, status, reschedule_of, idempotency_key}, contract_id}`.
- [ ] `appointments` concrete `starts_at/ends_at` are `timestamptz` concrete instances, not weekday template, so `tstzrange(starts_at, ends_at) WITH &&` catches ad-hoc overlap regardless of `availability_slots` template.
- [ ] `appointment_events` append-only: each state transition inserts one row `event_type IN ('booked','confirmed','rescheduled','cancelled','completed')` + `from_status/to_status` reflecting RPC, `actor_id=auth.uid()`.

### 2.4 Error Handling Scenarios

- [ ] `p_profession_id` NULL → `PLT003`; unknown `profession_id` → `PLT004` identical to inactive profession `is_active=false` → `PLT004` (no oracle).
- [ ] `weekday` 7 / -1 → `PLT003` (`CHECK weekday BETWEEN 0 AND 6` `EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:3`).
- [ ] `p_start_time >= p_end_time` (08:00-08:00) → `PLT003` `start must be before end`.
- [ ] `p_slot_duration_min` 5 / 600 → `PLT003` `15-480`; `p_slot_duration_min` 17 (not %15) → `PLT003` if strict.
- [ ] `p_timezone` `''` / `Invalid/Zone` / `123` → `PLT003` `Invalid timezone` via `pg_timezone_names`.
- [ ] `p_contract_id` NULL → `PLT003`; unknown `contract_id` → `PLT004` identical to foreign contract not owned → `PLT004` (`supabase/migrations/20260923090001_service_contract_schema.sql:811` precedent).
- [ ] `p_contract_id` targets `service_contracts` where `status='offered'` not `active` → `PLT005` `Contract not active`; `status='disputed'/'cancelled'` → `PLT005`; `status='disputed'` future `EP-03-17` trigger blocks `book`.
- [ ] `p_slot_id` foreign not owned by `professional` or not `EXISTS availability_slots` → `PLT004` (identical to unknown).
- [ ] `p_starts_at` `NULL` / `<= now()` / past `2024-01-01` → `PLT003`; `p_ends_at <= p_starts_at` → `PLT003`; `ends-starts >24h` (09:00 → next day 10:00) → `PLT003`.
- [ ] Non-participant `C2` calls `appointment_book` on `CT` owned by `C/P` → `PLT004` identical to unknown.
- [ ] `appointment_reschedule` on `cancelled`/`completed`/`rescheduled` → `PLT005` `not pending/confirmed`; `reschedule` by non-participant → `PLT004`.
- [ ] `appointment_cancel` on already `cancelled` → `PLT005`; non-participant → `PLT004`; `NULL p_appointment_id` → `PLT003`.

### 2.5 Important User Interactions (Downstream UX Contracts)

- [ ] Double-book receives `PLT005` `Slot taken. Pick another time.` → `HivorrErrorState` (`lib/shared/widgets/hivorr_error_state.dart:1`) + `Pick another time` CTA per `EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:144` (`HivorrChip` days + `HivorrFormField` time via `lib/shared/layouts/hivorr_content_pane.dart:720dp`).
- [ ] Past time receives `PLT003` `Start time must be in future` → inline calendar error on `appointment_book_screen.dart` (`lib/shared/components/hivorr_form_field.dart:1`).
- [ ] `idempotency_key` duplicate replay shows `PLT000` same id not `PLT005` → optimistic `pending → confirmed` tick via `fake_async:1.3.1` + `connectivity_plus:6.1.0` `lib/core/sync/connectivity_plus_provider.dart:1`.
- [ ] `availability_list` `weekday, start_time` ordered enables Mon-Sun rows; `timezone Africa/Lagos` hint drives `HivorrFormatters.time()` (`lib/shared/helpers/hivorr_formatters.dart:34`) + `lib/core/localization`.

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **Server-side enforcement** `documents/Context/AGENT.md:13` Rule 4 — All weekday/start/end/duration/timezone, `tstzrange` overlap, participant, active status, idempotency dedup execute inside `SECURITY INVOKER` RPCs. No `lib/` Dart (`git diff --stat lib/` shows zero `lib/systems/scheduling` changes, only `.gitkeep` `lib/systems/scheduling/.gitkeep:1`).
- [ ] **Separation of concerns** `documents/Context/AGENT.md:5` — No pricing/escrow math in scheduling; `financial_escrow` untouched.
- [ ] **File placement** `documents/Context/ARCHITECTURE.md:39` — Single migration `supabase/migrations/20260926090001_service_scheduling_schema.sql:1` after `20260925090001_service_messaging_schema.sql:1` (lexicographically greater). No top-level `lib/` outside schema.
- [ ] **Environment isolation** `documents/Context/ARCHITECTURE.md:164` ENV-002 — `supabase db reset` on isolated Dev `supabase db reset:18` `Applying migration ... Finished` idempotent via `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION`.

### 3.2 Required System Behavior

- [ ] **Execution model:** 5 RPCs `SECURITY INVOKER` `prosecdef=false` (`supabase/tests/database/027_service_review_schema_posture.sql:202` pattern `031:prosecdef 0`, only `portfolio_public_profile_get:120` whitelisted `SECURITY DEFINER` `supabase/migrations/20260913090001_portfolio_public_profile.sql:120`).
- [ ] **Volatility:** `availability_list` `STABLE` (PostgREST cacheable), `availability_upsert/book/reschedule/cancel` `VOLATILE`.
- [ ] **Module integration:** `EP-03-14` can consume `availability_list` + `appointment_book` via `supabase_scheduling_remote_data_source.dart`; EP-04 rider reuses without migration.
- [ ] **Grant re-baseline:** `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` + `GRANT EXECUTE` 5× `authenticated, service_role` `anon 0` `supabase/tests/database/025_service_contract_schema_posture.sql:282/293/304` + `COMMENT ON FUNCTION`×5.
- [ ] **Realtime exclusion:** Guarded `DO $$` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:799` pattern) `DROP TABLE public.availability_slots, appointments, appointment_events FROM supabase_realtime` if present → `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('availability_slots','appointments','appointment_events')` → `0` (`supabase/tests/database/025_service_contract_schema_posture.sql:258`).

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43`) | `appointments.contract_id → service_contracts CASCADE`; `professional/client` derived from contract not supplied. Orphan `SELECT * FROM appointments WHERE contract_id NOT IN (SELECT id FROM service_contracts)` → 0. |
| `entities` (`supabase/migrations/20260821090002_entity_core_tables.sql:20`) | `availability_slots.entity_id CASCADE`; `appointments.professional/client RESTRICT`. Orphan → 0. |
| `professions` (`supabase/migrations/20260821090001_entity_taxonomy_tables.sql:58`) | `availability_slots.profession_id RESTRICT` + `professions.is_active` gate via `availability_upsert`. Deactivating profession → `PLT004`. |
| `service_listings` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:42`) | `availability_list` published gate `EXISTS service_listings status='published'` — `draft` professional slots not visible to stranger via RPC `PLT004` no oracle. |
| `platform_*` helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37`) | RPCs call `platform_is_authenticated()` `PLT001`, `platform_raise_error` `PLT003/004/005`, `platform_set_updated_at` triggers. `grep -c platform_ supabase/migrations/20260926090001*` ≥3. |

### 3.4 Technical Requirements from Plan §7.1

- [ ] Header block documents EP-03-05, `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, `timestamptz+btree_gist+EXCLUDE` rationale (`documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:180,294`), `FOR UPDATE` + `idempotency_key`, grants, Realtime DROP.
- [ ] No prior DDL: `git diff -- supabase/migrations/202608* supabase/migrations/2026092*` shows only new `20260926090001`.
- [ ] `CREATE EXTENSION IF NOT EXISTS btree_gist` first, idempotent, before `EXCLUDE`.
- [ ] `DROP POLICY IF EXISTS` before `CREATE POLICY` (`supabase/migrations/20260830100001_storage_buckets.sql:96` pattern) + `COMMENT ON TABLE/COLUMN/FUNCTION`.

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] `availability_slots` `INSERT` via `availability_upsert` creates `id gen_random_uuid()`, `entity_id=auth.uid()`, `profession_id` provided, `weekday 0-6`, `start_time time`, `end_time time`, `slot_duration_min 15-480`, `timezone 'Africa/Lagos'` default, `is_active true`, `created_at/updated_at now()`, `created_by auth.uid()`. No `created_by` client-supplied.

- [ ] `appointments` `INSERT` via `appointment_book` creates `id gen_random_uuid()`, `contract_id` provided & participant-validated, `slot_id` optionally `availability_slots.id SET NULL` preserved, `professional_entity_id/client_entity_id` derived from `service_contracts`, `starts_at/ends_at timestamptz` with `CHECK starts<ends`, `status='pending'` default, `reschedule_of NULL`, `idempotency_key gen_random_uuid()` `uuid:4.5.1` `pubspec.yaml:82`, `created_at/updated_at now()`.

- [ ] `appointment_events` row via `book/reschedule/cancel` creates `id gen_random_uuid()`, `appointment_id` FK, `contract_id` FK, `event_type booked/confirmed/rescheduled/cancelled/completed`, `from_status/to_status` reflecting transition, `actor_id=auth.uid()`, `details jsonb {starts_at, ends_at, slot_id, reschedule_of, reason}`, `created_at now()`.

### 4.2 Data Updates

- [ ] `availability_slots updated_at` touch via `platform_set_updated_at()` (`supabase/migrations/20260819090001_enforcement_foundation.sql:54`) on `UPDATE`; `appointments updated_at` touch after `reschedule/cancel` (status flip).
- [ ] `appointment_events` has **no** `updated_at` + **no** `UPDATE` trigger — `information_schema.columns WHERE table_name='appointment_events' AND column_name='updated_at'` → 0; immutable append-only `role_table_grants privilege_type='UPDATE'` → 0.
- [ ] `appointments.status` transitions RPC-only: `pending → rescheduled` + new `pending` (`reschedule`), `pending/confirmed → cancelled` (`cancel`). Direct `UPDATE appointments SET status='confirmed'` as stranger → 0 rows (RLS `USING` fails) or `42501`.
- [ ] `appointments.idempotency_key` never changes after insert; second `book` same key returns same id via `ON CONFLICT DO NOTHING RETURNING`.
- [ ] `appointments starts_at/ends_at` never mutated after insert — `GRANT UPDATE(status, reschedule_of, updated_at)` (`EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:10.3`) column-level blocks `starts_at`/`ends_at` via direct REST `UPDATE`.

### 4.3 Data Relationships

- [ ] `availability_slots.profession_id → professions RESTRICT` — deleting referenced profession → `foreign_key_violation`.
- [ ] `appointments.contract_id → service_contracts CASCADE` — deleting contract cascades appointments + events.
- [ ] `appointments.slot_id → availability_slots SET NULL` — deleting slot keeps appointment `slot_id` becomes NULL.
- [ ] `appointments.reschedule_of → appointments SET NULL` — deleting old appointment nulls chain.
- [ ] `appointments` rows always have `professional_entity_id = service_contracts.professional_entity_id` and `client_entity_id = client_entity_id` — `SELECT * FROM appointments a JOIN service_contracts c ON c.id=a.contract_id WHERE a.professional_entity_id <> c.professional_entity_id` → 0.

### 4.4 Data Accuracy

- [ ] Weekday 0-6 `CHECK`; start<end `CHECK` holds `SELECT count(*) FROM availability_slots WHERE start_time >= end_time` → 0; duration 15-480 `CHECK` `WHERE slot_duration_min NOT BETWEEN 15 AND 480` → 0.
- [ ] Timezone regex `~ '^[A-Za-z/_]+$'` + `EXISTS pg_timezone_names` — `availability_upsert(timezone='123')` → `PLT003`.
- [ ] `UNIQUE(entity_id, profession_id, weekday, start_time)` — duplicate `INSERT` same key → `23505` via `ON CONFLICT DO UPDATE` not leaked as `PLT005` but handled idempotently.
- [ ] `UNIQUE(idempotency_key)` — `SELECT entity_id, idempotency_key, count(*) FROM appointments GROUP BY 1,2 HAVING count>1` → 0.
- [ ] `EXCLUDE` overlap — `SELECT a1.id, a2.id FROM appointments a1 JOIN appointments a2 ON a1.professional_entity_id=a2.professional_entity_id AND a1.id<a2.id AND tstzrange(a1.starts_at, a1.ends_at) && tstzrange(a2.starts_at, a2.ends_at) WHERE a1.status IN ('pending','confirmed') AND a2.status IN ('pending','confirmed')` → 0.

### 4.5 Data Integrity

- [ ] FK integrity 0 orphans for `availability_slots → professions/entities`, `appointments → service_contracts/entities`, `appointment_events → appointments/service_contracts`.
- [ ] `EXCLUDE` `appointments_no_overlap` `USING gist` exists `SELECT conname FROM pg_constraint WHERE conname='appointments_no_overlap'` → 1.
- [ ] `btree_gist` extension `SELECT extname FROM pg_extension WHERE extname='btree_gist'` → 1.
- [ ] Immutable `appointment_events` `role_table_grants privilege_type='UPDATE/DELETE'` → 0.
- [ ] Direct `INSERT availability_slots` as `authenticated` stranger with `entity_id != auth.uid()` → `42501` RLS `WITH CHECK (entity_id=auth.uid())`.

---

## 5. Security Verification

### 5.1 Authentication

- [ ] 5 write RPCs without JWT (`auth.uid() IS NULL`) → `{success:false, code:'PLT001', message:'Authentication required.'}` via `platform_is_authenticated()` `PLT001` (`supabase/migrations/20260819090001_enforcement_foundation.sql:37` `supabase/tests/database/025_service_contract_schema_posture.sql:282` anon 0 path `42501` before body; `authenticated` without JWT → `PLT001`).

### 5.2 Authorization (EXECUTE Grants)

- [ ] `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` baseline → `anon 0` `supabase/tests/database/025_service_contract_schema_posture.sql:282`, `authenticated 5` `025:293`, `service_role 5` `025:304`.
- [ ] `anon` cannot call 5 scheduling RPCs via `/rpc/availability_upsert` `apikey` only → `42501`.
- [ ] `service_role` JWT can call all 5 RPCs regardless of participant.

### 5.3 Access Control (RLS Default-Deny `supabase/migrations/20260819090001_enforcement_foundation.sql:18`)

- [ ] `relrowsecurity=true` =3 (`supabase/tests/database/025_service_contract_schema_posture.sql:23`).
- [ ] `anon` zero `INSERT/UPDATE/DELETE` on 3 tables `025:36`.
- [ ] `authenticated` `SELECT,INSERT,UPDATE,DELETE` on `availability_slots` but RLS `entity_id=auth.uid()` narrows; `appointments` `SELECT,INSERT` + `UPDATE(status...)` column-level `031:70`; `appointment_events` `SELECT,INSERT` `025:72` (no UPDATE).
- [ ] Policies 6-7: `availability_slots_select` owner or published listing `OR EXISTS` (`EP-03-05 Scheduling & Availability Schema & Server-Side Rules.md:10.3`), `insert/update/delete` owner `entity_id=auth.uid()`; `appointments_select/insert` participant `EXISTS service_contracts`; `appointment_events_select/insert` participant + `actor_id=auth.uid()`.
- [ ] `service_role` bypass no policy `supabase/migrations/20260829100004_financial_integrity_schema.sql:568`.

### 5.4 Sensitive Data Protection

- [ ] No `legal_name`, `kyc`, `secret` in RPC comments — `grep -i legal_name|kyc|secret` `20260926090001` → 0 non-COMMENT.
- [ ] `starts_at/ends_at` `timestamptz` not leaked via `EXCLUDE` error detail — RPC maps `23P01` to static `PLT005 Slot taken.` no `detail` value.
- [ ] Slot access via `availability_list` never returns `draft` professional's `service_listings.title` for non-published case (returns `PLT004`).

### 5.5 Security Rules

- [ ] No `SECURITY DEFINER` `SELECT count(*) FROM pg_proc WHERE proname LIKE '%scheduling%' AND prosecdef=true` → 0 (`supabase/tests/database/025_service_contract_schema_posture.sql:234` only `portfolio_public_profile_get:120` whitelisted `supabase/migrations/20260913090001_portfolio_public_profile.sql:120`).
- [ ] Oracle identical `PLT004` for unknown vs foreign `p_contract_id`/`p_appointment_id` — `032:10` stranger contract `PLT004`, unknown same.
- [ ] `EXCLUDE` `professional_entity_id WITH =` requires `btree_gist` else `gist` error — extension probe ensures not bypassed.
- [ ] SQL injection `::uuid/::timestamptz/::time` casts, no `EXECUTE format(...)` — `grep EXECUTE 20260926090001` only `EXECUTE FUNCTION platform_set_updated_at`.

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] `availability_list` with `WHERE entity_id=auth.uid()` uses `availability_slots_entity_prof_idx (entity_id, profession_id, weekday)` `Index Scan` not Seq Scan.
- [ ] `appointment_book` `INSERT` `EXCLUDE` check `gist` `Index Scan` — `EXPLAIN INSERT ...` shows `appointments_no_overlap` constraint check via gist.
- [ ] `appointment_list_mine` equivalent keyset `(starts_at DESC, id)` via `appointments_professional_starts_idx` `Index Scan` no SORT.

### 6.2 Resource Usage

- [ ] Indexes 3 (`availability_slots`) + 4 + gist (`appointments`) + 2 (`appointment_events`) = 9-10 btree +1 gist ≤ `supabase/tests/database/025_service_contract_schema_posture.sql:161 6` + `025:178 3` + `025:193 3` budget.

- [ ] No bloat on re-run — `INSERT ON CONFLICT DO UPDATE` for `availability_upsert` + `ON CONFLICT DO NOTHING` for `appointments` idempotency ensures second `supabase db reset` stable `pg_policies 6-7`.

### 6.3 System Reliability

- [ ] Concurrent `appointment_book` same `professional` overlap → one `PLT000`, other `PLT005` `23P01` via `FOR UPDATE` + `EXCLUDE` no double pending.
- [ ] `reschedule` sets old `rescheduled` before new `pending` insert — new can occupy freed old window without `23P01` even same transaction.
- [ ] `cancel` → `cancelled` not `WHERE status IN pending,confirmed` so immediate re-book same window `PLT000`.
- [ ] Volatility `STABLE` on `availability_list` cacheable; `VOLATILE` on writes no stale cache.

### 6.4 Performance Expectations

- [ ] `p95 <400ms` (`documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:55`) for `appointment_book` under 1k active appointments on Dev — recorded in validation report.

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements

Execute against Dev (`supabase start` + `supabase db reset:18` before Staging promotion — record `psql` stdout as evidence):

- [ ] **Manual `psql`/`supabase sql` — participant matrix:** Create test users `client_C` (`22222222-2222-2222-2222-222222222222`) and `pro_P` (`11111111-1111-1111-1111-111111111111`, owns `published` listing `L` via `service_listing_create`+`publish` as `verified_prof`), plus stranger `S` (`33333333-3333-3333-3333-333333333333`) and `active` contract `CT` (`offered→active` `supabase/migrations/20260923090001_service_contract_schema.sql:54`). As each JWT: (a) `P` `SELECT availability_upsert(L.profession_id, 1, '09:00', '12:00', 60, 'Africa/Lagos')` → `PLT000` slot; (b) `P` `SELECT availability_list()` → 1 slot; `C` `SELECT availability_list(P_id)` → 1 slot via published gate; `S` on draft professional → `PLT004`; (c) `C` `SELECT appointment_book(CT, slot_id, '2025-10-06 10:00+01:00'::timestamptz, '2025-10-06 11:00+01:00'::timestamptz)` → `PLT000` `pending`; (d) second `appointment_book` overlapping 10:30-11:30 same `P` → `PLT005` `Slot taken`; (e) `SELECT appointment_cancel(appointment_id)` → `cancelled`; re-book 10:00-11:00 → `PLT000`; (f) book 10:00-11:00 → `appointment_reschedule(old_id, '2025-10-06 14:00+01:00'::timestamptz, '2025-10-06 15:00+01:00'::timestamptz)` → old `rescheduled` + new `pending` `reschedule_of=old_id`; (g) timezone `SELECT starts_at AT TIME ZONE 'Africa/Lagos' FROM appointments WHERE id=new_id` → `14:00` / `09:00` round-trip.

- [ ] **Manual negative paths:** As `S` call `SELECT appointment_book(CT_of_C/P, ...)` → `PLT004`; as `S` call `SELECT availability_upsert(inactive_profession_id, 1, '09:00','10:00',60,'Africa/Lagos')` → `PLT004`; as `P` call `appointment_book` with `p_starts_at <= now()` → `PLT003`; `timezone 'Invalid/Zone'` → `PLT003`.

- [ ] **PostgREST curl manual:** `curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $C_JWT" https://127.0.0.1:54321/rest/v1/rpc/appointment_book -d '{"p_contract_id":"<active_uuid>","p_starts_at":"2025-10-06T10:00:00+01:00","p_ends_at":"2025-10-06T11:00:00+01:00","p_idempotency_key":"<uuid>"}'` as participant → `PLT000`; same with `p_contract_id` of `S`'s contract as `C` → `PLT004`; without JWT → `PLT001`; second same `p_idempotency_key` → `PLT000` same id.

### 7.2 Automated Testing Requirements

Two pgTAP suites must exist and pass — mirrors `supabase/tests/database/013_financial_schema_posture.sql` + `014_financial_rpc_enforcement.sql` pattern (`025:45 All tests successful. Files=1, Tests=29` + `026:1 All tests successful. Files=1, Tests=68`):

**`supabase/tests/database/031_service_scheduling_schema_posture.sql:1` — schema posture (`plan 30-34` `025:45`):**

- [ ] `has_table('public','availability_slots')` + `has_table('public','appointments')` + `has_table('public','appointment_events')` — all 3 exist (`025:18 3`).
- [ ] `relrowsecurity=true` count `3` (`025:23 3`).
- [ ] `anon 0 INSERT/UPDATE/DELETE` on 3 tables (`025:36 anon 0`).
- [ ] `authenticated` `SELECT,INSERT,UPDATE,DELETE` on `availability_slots` `025:60 have:3` owner; `appointments` `SELECT,INSERT` + `UPDATE(status,reschedule_of)` column-level `031:70`; `appointment_events` `SELECT,INSERT` only `025:72 0` for `UPDATE/DELETE` (append-only).
- [ ] `has_check` `availability_slots_weekday_range`, `slot_start_before_end`, `slot_duration_range`, `appointments_status_allowed`, `appointment_events_event_type_allowed`, `appointments_starts_before_ends` (`025:84 1`).
- [ ] `has_unique` `availability_slots_entity_prof_weekday_start_key` + `appointments_idempotency_key_key` `025:127`.
- [ ] `has_extension` `btree_gist` `031:extension 1`.
- [ ] `has_constraint` `appointments_no_overlap` `EXCLUDE USING gist` `031:EXCLUDE 1`.
- [ ] `has_index` `availability_slots` 3 (`025:161 3`), `appointments` 4 (`025:178 4` + gist), `appointment_events` 2 (`025:193 2`), `appointments_idempotency_idx` `UNIQUE`.
- [ ] `has_trigger` 2 (`availability_slots_set_updated_at`, `appointments_set_updated_at` `025:208 2`) + 0 on `appointment_events` (`025:223 0`).
- [ ] `prosecdef=0` `scheduling_%` (`025:234 0`).
- [ ] `5 RPCs` `jsonb` (`025:246 5`) — `availability_upsert`, `availability_list`, `appointment_book`, `appointment_reschedule`, `appointment_cancel`.
- [ ] `supabase_realtime` `0` (`025:258 0` for 3 scheduling tables).
- [ ] `obj_description` 3 (`025:269 3`).
- [ ] `anon 0`, `authenticated 5`, `service_role 5` (`025:282 0`, `025:293 5`, `025:304 5`).
- [ ] `6-7 RLS policies` (`025:242 7` after `availability_slots_delete`).

**`supabase/tests/database/032_service_scheduling_rpc_enforcement.sql:1` — RPC enforcement (`plan ~78` `026:1`):**

- [ ] Authz `anon 42501×5` (`026:30 anon cannot call...`), stranger `appointment_book` `PLT004` not `42501` (`026:30 stranger get returns PLT004` precedent), `service_role 5×` `026:66`.
- [ ] Validation matrix (§2.4): `weekday 7 PLT003`, unknown/inactive `profession_id PLT004`, `start>=end PLT003`, duration 5/600 `PLT003`, bad timezone `PLT003`, unknown `contract_id PLT004`, foreign contract `PLT004`, `offered` not active `PLT005`, `disputed PLT005`, past starts `PLT003`, ends<=starts `PLT003`, 24h exceed `PLT003`, `slot_id foreign PLT004`, stranger `PLT004`, `reschedule` not pending `PLT005`, `cancel` on cancelled `PLT005`.
- [ ] Functional `PLT000` (`026:30`): `availability_upsert Mon 09:00-12:00 Africa/Lagos` → slot `PLT000`; `availability_list` own + published other `PLT000` vs draft `PLT004`; `appointment_book` 10:00-11:00 `pending` `PLT000`; second overlapping 10:30-11:30 → `PLT005 Slot taken 23P01`; `cancel` → `cancelled` + re-book freed window `PLT000`; `reschedule` 10:00→14:00 `rescheduled` + new `pending` `reschedule_of` `PLT000` + freed old window re-book `PLT000`; `idempotency_key` duplicate → `PLT000` same id not duplicate row.

**Regression:** `supabase test db --local:1` `Files=26, Tests=917` `Result: PASS` `EXIT:0` (`023:215 7→15 fix 023:215 exactly 15 service_% RPCs` now +5 =20 scheduling).

### 7.3 Edge Cases

- [ ] `p_start_time` `null` vs `00:00` — null → `PLT003` not `00:00`; `end_time` `null` → `PLT003`.
- [ ] `timezone` `''` whitespace-only (`btrim=''`) → default `Africa/Lagos` or `PLT003` not `CHECK violation`.
- [ ] `weekday` `0` (Sunday) midnight `00:00-01:00` vs `24:00` — `24:00` invalid `time` → `PLT003`; `00:00-23:59` allowed.
- [ ] `p_starts_at` exactly `now()` → `PLT003` (`>` not `>=`); `ends==starts` → `PLT003`.
- [ ] `availability_upsert` same key with `is_active` flip `true→false→true` — last wins no duplicate via `ON CONFLICT DO UPDATE`.
- [ ] Concurrent `availability_upsert` same key → `UNIQUE` `ON CONFLICT DO UPDATE` last wins no duplicate.
- [ ] Concurrent `appointment_book` same `idempotency_key` from offline replay → `ON CONFLICT DO NOTHING` second returns existing not `23P01`.
- [ ] `reschedule` new window exactly touching old `ends_at == new starts_at` (`10:00-11:00` → `11:00-12:00`) — no `&&` overlap so `PLT000` (exclusive upper bound via `tstzrange`).

### 7.4 Failure Scenarios

- [ ] `btree_gist` not installed on staging — migration `CREATE EXTENSION IF NOT EXISTS btree_gist` before `EXCLUDE` prevents `uuid has no default operator class for gist` — verify `SELECT extname FROM pg_extension WHERE extname='btree_gist'` →1 before `appointments_no_overlap` created; without it deployment fails deterministic not silent.
- [ ] `appointment_book` with `p_starts_at` in `Africa/Lagos` DST nonexistent hour (if DST ever) — `timestamptz` stores valid UTC instant; no `PLT003` unless `starts_at <= now()`.
- [ ] Direct `INSERT appointments` as `authenticated` stranger bypassing `EXISTS service_contracts` → `42501` RLS (`WITH CHECK` participant).
- [ ] `EXCLUDE` violation detail not leaked — RPC `EXCEPTION WHEN exclusion_violation THEN platform_raise_error('PLT005','Slot taken. Pick another time.')` not raw `23P01 DETAIL: conflicting key (professional_entity_id, tstzrange(...))`.
- [ ] Migration re-run `supabase db reset` second time — no `already exists` error, idempotent via `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION` / `CREATE EXTENSION IF NOT EXISTS`.

---

## 8. User Acceptance Verification

Real-world usage checks required before project-lead approval — validates the task delivers business value under production-like conditions (Staging or Dev with two test entities).

- [ ] **Professional weekly template:** As `pro_P` (owns `published` listing `L` `status='published'` `service_listings:42`), create Mon-Fri 09:00-17:00 slots via `availability_upsert` weekday 1-5 each (`slot_duration_min=60`, `timezone='Africa/Lagos'`) → `availability_list` shows 5 slots Mon-Sun ordered `weekday, start_time`; toggling one `is_active=false` hides from consumer `availability_list` but owner still sees; changing `timezone` to `Africa/Lagos` vs `Europe/London` preserves wall-clock via `timestamptz` round-trip `SELECT starts_at AT TIME ZONE timezone`.

- [ ] **Consumer books with active contract:** As `client_C` with `active` contract `CT` (`service_contracts:43`), call `appointment_book(CT, starts_at='2025-10-06 10:00+01:00', ends_at='2025-10-06 11:00+01:00')` → `appointment_events` `booked` emitted; professional sees same via `SELECT * FROM appointments WHERE professional_entity_id=P_id` RLS `EXISTS` participant.

- [ ] **Reschedule with audit:** Professional reschedules 10:00→14:00 via `appointment_reschedule` → old `rescheduled` + new `pending` `reschedule_of=old_id` visible in `appointment_events` (`SELECT event_type, from_status, to_status FROM appointment_events WHERE appointment_id IN (old_id, new_id) ORDER BY created_at` shows `booked` → `rescheduled` → `booked`); new 10:00 now bookable for another contract — gap proven not double-booked `SELECT count(*) FROM appointments WHERE professional_entity_id=P_id AND tstzrange(starts_at, ends_at) && tstzrange('2025-10-06 10:00+01:00','2025-10-06 11:00+01:00') AND status IN ('pending','confirmed')` →0 after `rescheduled`.

- [ ] **Downstream unblock:** `SELECT a.id, a.starts_at, a.ends_at, a.status, a.contract_id FROM appointments a WHERE a.contract_id = (SELECT id FROM service_contracts WHERE status='active' LIMIT 1)` returns row usable as `EP-03-14` `lib/systems/scheduling/services/scheduling_service.dart` calendar data source without new migration; `availability_slots` ready for `availability_editor_screen.dart` `HivorrChip` days.

---

## 9. Final Approval Checklist

All conditions must be satisfied before marking EP-03-05 as `Completed`. Each line is a blocking gate.

| # | Condition | Evidence Required | Status |
|---|---||---|
| 1 | Migration file exists as `supabase/migrations/20260926090001_service_scheduling_schema.sql` ordered after `20260925090001_service_messaging_schema.sql` | File path + `ls -l supabase/migrations \| tail -n 5` stdout shows 20260926090001 | ☐ |
| 2 | 3 tables exist with RLS enabled + `btree_gist` + `EXCLUDE USING gist` `appointments_no_overlap` + triggers `platform_set_updated_at` 2+0 + comments 3 | `031` posture `has_table 3`, `has_extension 1`, `has_constraint 1`, `has_trigger 2+0` green | ☐ |
| 3 | `anon` zero `INSERT/UPDATE/DELETE` on 3 tables; `authenticated` narrow grants `SELECT,INSERT,UPDATE(status...)` on `appointments` column-level; `appointment_events` no `UPDATE/DELETE` | `031:36 anon 0`, `031:50/60 authenticated narrow`, `031:70 UPDATE(status)` `031:72 0` green | ☐ |
| 4 | `btree_gist` provisioned + `EXCLUDE` `appointments_no_overlap` `USING gist (professional_entity_id WITH =, tstzrange(...)) WHERE status IN pending,confirmed` | `SELECT extname FROM pg_extension WHERE extname='btree_gist'` →1 + `SELECT conname FROM pg_constraint WHERE conname='appointments_no_overlap'` →1 — `031` green | ☐ |
| 5 | 5 RPCs exist all `SECURITY INVOKER` (`prosecdef=false`) — no `scheduling_% SECURITY DEFINER` introduced | `SELECT proname, prosecdef FROM pg_proc WHERE proname LIKE '%scheduling%' OR proname IN ('availability_upsert','availability_list','appointment_book','appointment_reschedule','appointment_cancel')` — `031:234 0` green | ☐ |
| 6 | `EXECUTE` grants correct: 5 RPCs → `authenticated,service_role`; `anon` 0 → `anon 42501×5` + `PLT004` oracle | `031:282 anon 0`, `031:293 authenticated 5`, `031:304 service_role 5` + `032:30 anon 42501` green | ☐ |
| 7 | Double-book invariant enforced: overlap second `appointment_book` → `PLT005 23P01` `Slot taken`; `cancel` frees `WHERE` for rebooking; `reschedule` frees old window; `idempotency_key` dedup `PLT000` same id | `032` race `PLT005`, cancel re-book `PLT000`, reschedule frees `PLT000`, idempotency same id `PLT000` green | ☐ |
| 8 | Enumeration oracle not present: `availability_upsert` inactive profession `PLT004` identical to unknown; `appointment_book` foreign contract `PLT004` identical unknown; `appointment_cancel` foreign `PLT004` | `032:10`/`032:12`/`032:30` `results_eq PLT004` oracle green | ☐ |
| 9 | Full pgTAP suite green: new `031_service_scheduling_schema_posture.sql` + `032_service_scheduling_rpc_enforcement.sql` + regression `001`–`030` (`008_full_schema_posture_audit`, `013_financial_schema_posture`, `025_service_contract_schema_posture`, `027_service_review_schema_posture`, `029_service_messaging_schema_posture`) | `supabase test db --local` stdout `ok` all suites `Files=33` `932` tests | ☐ |
| 10 | No DDL on prior tables/functions/policies; no `financial_*` `SECURITY DEFINER`; no `lib/` Dart created; envelope `{success,code,message,data}` uniform, messages static | `git diff --stat supabase/migrations/` shows only new `20260926090001` + new `031/032` tests; `dart analyze` `No issues found!` — no Dart changed | ☐ |
| 11 | EP-03-14 unblocked: `appointments.contract_id → service_contracts.id` FK ready + `availability_slots` FK ready for `supabase_scheduling_remote_data_source.dart` | `SELECT conname, contype FROM pg_constraint WHERE conrelid='appointments'::regclass` — 2 FKs ready + `availability_slots` FK ready `031` | ☐ |
| 12 | Realtime exclusion verified — 3 tables not in `supabase_realtime` publication | `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('availability_slots','appointments','appointment_events')` → 0 rows — `031:258 0` green | ☐ |

**Lead sign-off:** `Completed` only when every box in §2–§9 is checked and evidence (`pgTAP stdout` `031/032` + migration file path `20260926090001` + manual verification SQL `PLT000/PLT003/004/005` + `SELECT tstzrange && 0` + `SELECT starts_at AT TIME ZONE 'Africa/Lagos' 09:00`) is attached to the task review. Any unchecked box → task remains `In Progress` and blocks `EP-03-14`.

---

> **Notes for reviewer:** This DoD is task-specific per `documents/Context/AGENT.md:4` Bounded Scope. It does not replace the universal engineering gates (`CI`, `dart analyze`, `VISUAL-IDENTITY.md:7` token checks) — those are N/A here (server-side task `Zero lib/`). For `EP-03-05` financial integrity is not ledger (`appointments` no `financial_escrow`); deterministic core is not invoked (ranking `EP-03-06`). Treat any `SECURITY DEFINER scheduling_%` or hardcoded `timezone` string in client code or missing `btree_gist` as automatic DoD failure. `supabase db reset --local` before `supabase test db --local` per `documents/Context/ARCHITECTURE.md:164` ENV-002.

