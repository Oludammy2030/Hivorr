# Definition of Done — EP-02-06: Supabase Storage Infrastructure & Bucket Configuration

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-06 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-06-Supabase Storage Infrastructure & Bucket Configuration.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-06 |
| **Task Name** | Supabase Storage Infrastructure & Bucket Configuration |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 3 — Client-Side Infrastructure (Stage 2 parallel) |
| **Priority** | High |
| **Dependencies** | EP-01-05 (Supabase project provisioned) |
| **Blocks** | EP-02-07, EP-02-08, EP-02-10, EP-02-11, EP-02-17, EP-02-18, EP-02-19 |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-06-Supabase Storage Infrastructure & Bucket Configuration.md` |

---

## 2. Functional Verification

This task is a server-side storage infrastructure change (SQL migration + optional `supabase/config.toml` stanzas + pgTAP test). There are no user-facing workflows, UI interactions, or production client code. Functional verification confirms the storage layer is provisioned correctly and enforces the documented access model.

### 2.1 Required Functionality

- [ ] **FV-01:** Migration file exists at `supabase/migrations/<YYYYMMDD><HHMMSS>_storage_buckets.sql` following the established naming convention
- [ ] **FV-02:** Migration is ordered after `20260829120006_dispute_withdraw_definer.sql`
- [ ] **FV-03:** `storage.buckets` contains exactly 3 rows: `credential-documents`, `profile-avatars`, `portfolio-items`
- [ ] **FV-04:** `credential-documents` has `public = false` (private, owner-only)
- [ ] **FV-05:** `profile-avatars` has `public = true` (public read, owner write)
- [ ] **FV-06:** `portfolio-items` has `public = true` (public read, owner write)
- [ ] **FV-07:** `credential-documents` `file_size_limit = 10485760` (10 MiB) and `allowed_mime_types` = `{image/jpeg,image/png,image/webp,application/pdf}`
- [ ] **FV-08:** `profile-avatars` `file_size_limit = 5242880` (5 MiB) and `allowed_mime_types` = `{image/jpeg,image/png,image/webp}`
- [ ] **FV-09:** `portfolio-items` `file_size_limit = 10485760` (10 MiB) and `allowed_mime_types` includes `application/pdf`
- [ ] **FV-10:** `storage.objects` RLS is enabled (idempotent `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
- [ ] **FV-11:** At least 11 `storage.objects` RLS policies exist covering all 3 buckets and all commands (SELECT/INSERT/UPDATE/DELETE)
- [ ] **FV-12:** `supabase/config.toml` declares 3 `[storage.buckets.*]` stanzas (or documents intentional omission with rationale)

### 2.2 Expected Workflows

- [ ] **FV-13:** Migration applies in a single transactional execution (no partial state on success)
- [ ] **FV-14:** Migration is idempotent — `ON CONFLICT (id) DO UPDATE` re-run yields still 3 buckets with identical policies
- [ ] **FV-15:** Migration applies cleanly to a fresh database
- [ ] **FV-16:** Migration applies cleanly to a database where the buckets already exist (idempotent re-run)

### 2.3 Success Conditions

- [ ] **FV-17:** `SELECT * FROM storage.buckets` returns exactly 3 rows with the correct `public`, `file_size_limit`, and `allowed_mime_types`
- [ ] **FV-18:** Public read works for `profile-avatars` and `portfolio-items` (via `getPublicUrl`, no auth)
- [ ] **FV-19:** Credential documents are NOT publicly accessible (private bucket, owner-only SELECT)

### 2.4 Error Handling Scenarios

- [ ] **FV-20:** `anon` INSERT on any bucket throws `42501` (default-deny, no anon write policy)
- [ ] **FV-21:** `authenticated` inserting outside own prefix (`storage.foldername(name)[1] != auth.uid()`) is rejected by policy `WITH CHECK`
- [ ] **FV-22:** Oversized or non-allowlisted MIME uploads are rejected at the storage API layer by `file_size_limit` / `allowed_mime_types`

### 2.5 Important Interactions

- [ ] **FV-23:** Downstream SDK calls (`supabase.storage.from(bucket).upload` / `.download` / `.getPublicUrl` / `.createSignedUrl`) are gated correctly by the `storage.objects` policies and bucket access model

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Migration is located in `supabase/migrations/` — no other migration directories modified
- [ ] **TV-02:** Migration filename follows `<YYYYMMDD><HHMMSS>_storage_buckets.sql` and is ordered after `20260829120006`
- [ ] **TV-03:** Migration touches the `storage` schema only — no DDL on any `public.*` table, RPC, or prior migration (`20260819090001`–`20260829120006`)
- [ ] **TV-04:** No `SECURITY DEFINER` functions created; no `storage_*` or `financial_%` `prosecdef` drift
- [ ] **TV-05:** No GRANT statements on `public.*` or `storage.*` issued (RLS is the access mechanism)
- [ ] **TV-06:** No `lib/` (Dart) files created or modified — client `StorageService` is EP-02-08
- [ ] **TV-07:** Migration header comment block documents EP reference, bucket matrix, security posture (default-deny via RLS), path convention, and size/MIME rationale

### 3.2 Required System Behavior

- [ ] **TV-08:** Buckets created via `INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)` with `ON CONFLICT (id) DO UPDATE` for idempotency
- [ ] **TV-09:** `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` issued (idempotent)
- [ ] **TV-10:** All policies use `DROP POLICY IF EXISTS` before `CREATE POLICY` (clean, idempotent re-run)
- [ ] **TV-11:** Every `storage.objects` policy qual/with_check contains the `bucket_id = '<bucket>'` conjunct to prevent cross-bucket leakage
- [ ] **TV-12:** Owner scope enforced via `(storage.foldername(name))[1] = auth.uid()::text` on all non-public-write policies
- [ ] **TV-13:** Write policies use `WITH CHECK` on `name` prefix (not just `USING`) to prevent rename/prefix escape
- [ ] **TV-14:** `service_role` bypasses RLS (no policy needed) — enabling admin review of credential documents
- [ ] **TV-15:** Realtime excluded — `storage` schema not present in `supabase_realtime` (guarded check, no mutation)

### 3.3 Module Integration

- [ ] **TV-16:** Migration does not conflict with existing migrations `20260819090001`–`20260829120006`
- [ ] **TV-17:** `supabase/config.toml` `[storage.buckets.*]` stanzas (3) added for local `supabase start` parity, or intentional omission documented
- [ ] **TV-18:** No new RPC surface / no `public.*` functions created (Storage API accessed via SDK, not RPC)
- [ ] **TV-19:** `013_financial_schema_posture.sql:153` assertion (no `financial_%` SECURITY DEFINER) remains unaffected

### 3.4 Technical Requirements

- [ ] **TV-20:** Policy counts per bucket: `credential-documents` 4 (SELECT/INSERT/UPDATE/DELETE owner-only), `profile-avatars` 4 (public SELECT + 3 owner write), `portfolio-items` 3–4 (public SELECT + owner write) — total ≥ 11
- [ ] **TV-21:** Size/MIME limits enforced at bucket layer and documented in migration header

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** 3 bucket rows exist in `storage.buckets` with `id = name` for each bucket
- [ ] **DV-02:** Each bucket has correct `public` flag (credential=false, avatar=true, portfolio=true)
- [ ] **DV-03:** Each bucket has correct `file_size_limit` (10 MiB / 5 MiB / 10 MiB)
- [ ] **DV-04:** Each bucket has the correct `allowed_mime_types` array

### 4.2 Data Updates

- [ ] **DV-05:** `ON CONFLICT (id) DO UPDATE` idempotency confirmed — re-run yields unchanged bucket rows

### 4.3 Data Relationships

- [ ] **DV-06:** Object-to-bucket relationship via `bucket_id` conjunct enforced on every policy
- [ ] **DV-07:** No FK from storage schema to `public.entities` — references are via stored URL strings (e.g., `entity_credentials.document_path = 'credential-documents/<entity_id>/...'`)

### 4.4 Data Accuracy

- [ ] **DV-08:** `allowed_mime_types` arrays match the approved plan exactly per bucket (4/3/4 MIME types)
- [ ] **DV-09:** `file_size_limit` byte values exact (10485760 / 5242880 / 10485760)

### 4.5 Data Integrity

- [ ] **DV-10:** Migration is idempotent — second apply yields still 3 buckets, same policies, no duplicates
- [ ] **DV-11:** No mutation of any `public.*` table; `storage.objects` has no `updated_at` trigger to manage

---

## 5. Security Verification

### 5.1 Authentication

- [ ] **SV-01:** Migration does not alter any authentication configuration or `auth.*` tables

### 5.2 Authorization & Access Control

- [ ] **SV-02:** `credential-documents` SELECT policy scoped to `authenticated` + `foldername(name)[1] = auth.uid()::text` — no `anon` SELECT
- [ ] **SV-03:** `profile-avatars` public SELECT granted to `anon, authenticated`
- [ ] **SV-04:** `portfolio-items` public SELECT granted to `anon, authenticated`
- [ ] **SV-05:** `anon` has zero INSERT/UPDATE/DELETE policies on `storage.objects` (default-deny)
- [ ] **SV-06:** `authenticated` can only INSERT/UPDATE/DELETE within own prefix (`WITH CHECK` on `foldername`)

### 5.3 Access Control Hardening

- [ ] **SV-07:** Every policy includes `bucket_id = '<bucket>'` conjunct (no cross-bucket leakage)
- [ ] **SV-08:** `authenticated` cannot SELECT another entity's credential path (RLS simulation)
- [ ] **SV-09:** Path traversal / prefix escape blocked via `WITH CHECK` first-segment check
- [ ] **SV-10:** `service_role` is the only uncapped path (never exposed to client)

### 5.4 Sensitive Data Protection

- [ ] **SV-11:** No keys, tokens, secrets, or PII in migration or policies
- [ ] **SV-12:** `credential-documents` is private (public = false) — zero public credential access
- [ ] **SV-13:** MIME/size DoS prevented via `allowed_mime_types` and `file_size_limit` at API layer

### 5.5 Security Rules

- [ ] **SV-14:** No `SECURITY DEFINER` functions created; no GRANT on `public.*`
- [ ] **SV-15:** `storage.objects` RLS maintains default-deny posture (absence of matching policy = deny)
- [ ] **SV-16:** Full suite `001`–`017` confirms no regression to prior posture (008/013/015 unchanged)

---

## 6. Performance Verification

- [ ] **PV-01:** Public buckets (`profile-avatars`, `portfolio-items`) `public = true` enable CDN + browser caching via `getPublicUrl` — no auth header overhead
- [ ] **PV-02:** Private bucket (`credential-documents`) uses short-lived `createSignedUrl` (60–300s TTL) — no public CDN hit for sensitive docs
- [ ] **PV-03:** 5–10 MiB limits keep uploads single-part in most networks — no chunked upload needed
- [ ] **PV-04:** `storage.foldername(name)[1]` filters on indexed `storage.objects.name` (GIN/trigram default) — negligible policy evaluation cost
- [ ] **PV-05:** Prefix `{entity_id}/` shards by entity, avoiding hot partition; bucket-per-domain scales to millions of objects
- [ ] **PV-06:** No N+1 — object listing via `storage.list(path)` is prefix-scanned and paginated

---

## 7. Testing Verification

### 7.1 Automated Testing — pgTAP Storage Posture

- [ ] **TT-01:** Test file exists at `supabase/tests/database/017_storage_posture.sql`
- [ ] **TT-02:** Test follows the established pgTAP pattern: `begin; set search_path to extensions, public, storage; select plan(25); ... select * from finish(); rollback;`
- [ ] **TT-03:** Buckets exist: `credential-documents`, `profile-avatars`, `portfolio-items` (3 assertions)
- [ ] **TT-04:** Public flags asserted (credential=false, avatar=true, portfolio=true) (3 assertions)
- [ ] **TT-05:** `file_size_limit` asserted per bucket (10485760 / 5242880 / 10485760) (3 assertions)
- [ ] **TT-06:** `allowed_mime_types` arrays asserted per bucket (3 assertions)
- [ ] **TT-07:** `storage.objects` RLS enabled (`pg_class.relrowsecurity`) (1 assertion)
- [ ] **TT-08:** ≥ 11 `storage.objects` policies exist across buckets (1 assertion)
- [ ] **TT-09:** `anon` zero INSERT/UPDATE/DELETE on `storage.objects` (1 assertion)
- [ ] **TT-10:** `credential-documents` owner-scoped SELECT for `authenticated` (qual contains `foldername` + `auth.uid()`) (1 assertion)
- [ ] **TT-11:** `profile-avatars` / `portfolio-items` public SELECT for `anon, authenticated` (2 assertions)
- [ ] **TT-12:** No `storage.*` SECURITY DEFINER function (`proname LIKE 'storage_%' AND prosecdef` = 0) (1 assertion)
- [ ] **TT-13:** Cross-bucket leakage prevented — policy qual contains `bucket_id =` (1 assertion)
- [ ] **TT-14:** RLS leakage simulation — `authenticated` as attacker cannot SELECT victim's credential path (1 assertion)
- [ ] **TT-15:** Realtime exclusion — `storage` not in `supabase_realtime` (1 assertion)
- [ ] **TT-16:** Total assertions = 25, with `plan(25)` exactly matched
- [ ] **TT-17:** `017_storage_posture.sql` passes via `supabase db test`

### 7.2 Regression Testing — Existing pgTAP Suite

- [ ] **TT-18:** `008_full_schema_posture_audit.sql` passes without regression
- [ ] **TT-19:** `013_financial_schema_posture.sql` passes — no `financial_%` SECURITY DEFINER (per line 153)
- [ ] **TT-20:** `015_dispute_schema_posture.sql` passes — exactly 2 `dispute_%` SECURITY DEFINER unchanged
- [ ] **TT-21:** Full test suite `001`–`017` reports zero failures via `supabase db test`

### 7.3 Edge Cases

- [ ] **TT-22:** Migration re-run idempotency (second push yields same 3 buckets, same policies)
- [ ] **TT-23:** `evil-entity-id/` prefix attempt — `authenticated` cannot write outside own prefix (RLS simulation)
- [ ] **TT-24:** Oversized upload / MIME spoof rejected via `file_size_limit` / `allowed_mime_types`
- [ ] **TT-25:** Public vs private read verified — avatars/portfolio public, credentials private

### 7.4 Failure Scenarios

- [ ] **TT-26:** Policy `WITH CHECK` violation yields `42501` for out-of-prefix insert
- [ ] **TT-27:** Size/MIME rejection at storage API layer; `service_role` still succeeds (RLS bypass)

### 7.5 Manual Testing

- [ ] **TT-28:** Manual verification:
  ```sql
  SELECT * FROM storage.buckets;  -- 3 rows
  SELECT * FROM pg_policies WHERE schemaname = 'storage';  -- posture review
  ```
  RLS simulation with `SET LOCAL role authenticated; SET LOCAL request.jwt.claim.sub = '<uuid>';`

---

## 8. User Acceptance Verification

This task has no direct user interface. User acceptance is verified indirectly through storage correctness, security posture, and downstream readiness.

- [ ] **UA-01:** Fail-fast validation — MIME/size rejection yields an immediate storage API error, not silent DB inconsistency or opaque `403`
- [ ] **UA-02:** Public avatar/portfolio renders via `getPublicUrl` without auth (SEO-friendly, no token refresh) on `/p/:profession_slug/:entity_id`
- [ ] **UA-03:** Private credential preview uses authenticated `download` + `createSignedUrl` (60s TTL) — no public link leakage
- [ ] **UA-04:** Uploads are not blocked by policy misconfiguration that would surface as opaque `403` — EP-02-08 progress feedback will function
- [ ] **UA-05:** Idempotent avatar overwrite via `upsert: true` on `profile-avatars/{entity_id}/avatar` prevents stale duplicates
- [ ] **UA-06:** Storage layer is sufficient to unblock EP-02-07/08/10/11/17/18/19 — last infra dependency for those flows
- [ ] **UA-07:** No UI introduced, so AGENT.md Rule 5 (AppTheme token consumption, `VISUAL-IDENTITY.md`) is vacuously satisfied

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-06 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Migration file exists at `supabase/migrations/<timestamp>_storage_buckets.sql`, ordered after `20260829120006` | File inspection | ✅ |
| 2 | `storage.buckets` contains exactly 3 rows: `credential-documents`, `profile-avatars`, `portfolio-items` | `SELECT count(*)` = 3 | ✅ |
| 3 | `credential-documents` `public = false` | Query verification | ✅ |
| 4 | `profile-avatars` `public = true` | Query verification | ✅ |
| 5 | `portfolio-items` `public = true` | Query verification | ✅ |
| 6 | `credential-documents` `file_size_limit = 10485760` and MIME = `{jpeg,png,webp,pdf}` | Bucket config query | ✅ |
| 7 | `profile-avatars` `file_size_limit = 5242880` and MIME = `{jpeg,png,webp}` | Bucket config query | ✅ |
| 8 | `portfolio-items` `file_size_limit = 10485760` and MIME includes pdf | Bucket config query | ✅ |
| 9 | `storage.objects` RLS enabled (`relrowsecurity` = true) | Query verification | ✅ |
| 10 | ≥ 11 `storage.objects` policies exist covering all buckets and all cmds | `pg_policies` count | ✅ |
| 11 | Every policy qual/with_check contains `bucket_id = '<bucket>'` conjunct | `pg_policies.qual` inspection | ✅ |
| 12 | `credential-documents` SELECT owned-scoped to `authenticated` + `foldername(name)[1] = auth.uid()` (no `anon`) | `pg_policies` inspection | ✅ |
| 13 | `profile-avatars` public SELECT granted to `anon, authenticated` | `pg_policies` inspection | ✅ |
| 14 | `portfolio-items` public SELECT granted to `anon, authenticated` | `pg_policies` inspection | ✅ |
| 15 | `anon` zero INSERT/UPDATE/DELETE on `storage.objects` | `pg_policies` role query | ✅ |
| 16 | `authenticated` cannot INSERT outside own prefix — `WITH CHECK` contains `foldername` | Policy inspection | ✅ |
| 17 | No `storage_*` or `financial_%` SECURITY DEFINER functions created | `pg_proc` count = 0 | ✅ |
| 18 | `storage.objects` not in `supabase_realtime` | `pg_publication_tables` count = 0 | ✅ |
| 19 | Migration is idempotent — second apply yields still 3 buckets, same policies | Re-run inspection | ✅ |
| 20 | `supabase/config.toml` declares 3 buckets (or documents intentional omission) | File inspection | ✅ |
| 21 | No DDL on `public.*`, no RPCs, no `lib/` changes | `git diff --stat` | ✅ |
| 22 | `017_storage_posture.sql` exists with 25 assertions, uses `plan(25)` with extensions/public/storage search_path | File inspection | ✅ |
| 23 | `017_storage_posture.sql` passes | `supabase db test` | ✅ |
| 24 | Full suite `001`–`017` passes without regression | `supabase db test` — zero failures | ✅ |
| 25 | RLS simulation: entity A cannot SELECT entity B's `credential-documents/<B>/...` object | pgTAP leakage assertion | ✅ |
| 26 | Path convention documented in migration header and TIP §5.3 | Code review | ✅ |
| 27 | All 3 buckets have `COMMENT` or documented rationale | `obj_description` or header | ✅ |
| 28 | EP-02-07/08/10/11/17/18/19 unblocked | Dependency check | ✅ |

---

> **Sign-off:** Task EP-02-06 marked **Completed** -- all 28 conditions in the Final Approval Checklist are verified and signed off by the project lead.
