# Task Implementation Plan — EP-02-06: Supabase Storage Infrastructure & Bucket Configuration

**Task ID:** EP-02-06 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** High | **Dependencies:** EP-01-05 (Supabase project provisioned) | **Stage:** 3 — Client-Side Infrastructure (Stage 2 parallel)

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:302-311` | Architecture: `documents/Context/ARCHITECTURE.md:58-60,119` , `documents/Context/AGENT.md:4-18` | Reference TIPs: `documents/Task-Implementation/EP-02/EP-02-05-Dispute Resolution Schema & Server-Side Rules.md` , `EP-02-01-Two-Tier Taxonomy Seed Data & Registry Population.md`

---

## 1. Task Objective

Configure Supabase Storage infrastructure with three RLS-protected buckets that underpin all EP-02 trust workflows:

- **Bucket `credential-documents`** — private, owner-only access for identity documents, trade proofs, certifications (consumed by EP-02-03 `verification_submissions` → `entity_credentials.document_path`, EP-02-10/11).
- **Bucket `profile-avatars`** — public read, owner write for entity display avatars (`entity_profiles.avatar_url`, EP-02-18/19).
- **Bucket `portfolio-items`** — public read, owner write for professional portfolio showcase (`portfolio_items.file_url`, EP-02-19, dispute evidence `dispute_evidence.file_url` optional).

Deliverables:
- 1 SQL migration `supabase/migrations/<timestamp>_storage_buckets.sql` that creates 3 buckets via `storage.buckets` with `public`, `file_size_limit`, `allowed_mime_types`, and owner-scoped `storage.objects` RLS policies.
- Bucket-level constraints: size limits, MIME allowlists, path convention enforcement via policy `WITH CHECK`.
- `supabase/config.toml` `[storage.buckets.*]` declarations for local dev parity (optional but recommended for `supabase start` reproducibility, per `supabase/config.toml:8` pattern).
- 1 pgTAP test file `supabase/tests/database/017_storage_posture.sql` validating bucket existence, public flags, RLS posture, MIME/size config, and default-deny leakage.
- Zero client-side Dart code (EP-02-08 owns `lib/core/storage/` service). Zero modifications to any `public.*` table.

---

## 2. Business Problem Being Solved

EP-02-03/04/05 established the server-side verification, financial, and dispute schemas, but **no file storage layer exists**:

- Trade verification (AGENT.md Rule 2) requires document upload — `entity_credentials.document_path` and `verification_submissions.credential_id` have no backing bucket; `supabase/tests/database/013_financial_schema_posture.sql`-style posture has no storage counterpart.
- Onboarding (EP-02-18) and professional profile (EP-02-19) require avatar/portfolio upload — `lib/core/storage/` (`lib/core/storage/storage.dart:1`) currently only wraps `flutter_secure_storage` (`lib/core/storage/secure_storage.dart:48`), with no Supabase Storage abstraction.
- Dispute evidence (`dispute_evidence.file_url` `supabase/migrations/20260829120005_dispute_resolution_schema.sql:118`) and future verification flows have no enforced bucket policy — risk of document leakage if buckets default to public or lack RLS (Risk `EP-02:177` — Supabase Storage RLS misconfiguration → high, document leakage).
- Without explicit `file_size_limit` / `allowed_mime_types`, clients could upload arbitrary binaries, bloating costs and creating attack surface.

This task is the **storage security gate** — parallel to EP-02-02, unblocks EP-02-07/08/10/11/17/18/19 per dependency matrix `EP-02:134,138`.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| Bucket `credential-documents` | `public = false`, private owner-only, path-scoped to `auth.uid()` |
| Bucket `profile-avatars` | `public = true`, public read, owner write/delete, path-scoped |
| Bucket `portfolio-items` | `public = true`, public read, owner write/delete, path-scoped |
| `storage.buckets` inserts | `id`, `name`, `public`, `file_size_limit`, `allowed_mime_types`, `avif` disabled, `created_at`, `updated_at` |
| `storage.objects` RLS policies | SELECT/INSERT/UPDATE/DELETE per bucket, owner-scoped via `auth.uid()::text = (storage.foldername(name))[1]` |
| Size limits | credential-documents 10 MiB, profile-avatars 5 MiB, portfolio-items 10 MiB |
| MIME allowlists | credential-documents: `image/jpeg, image/png, image/webp, application/pdf`; profile-avatars: `image/jpeg, image/png, image/webp`; portfolio-items: `image/jpeg, image/png, image/webp, application/pdf` |
| Path conventions | Documented and enforced via policy `WITH CHECK` prefix: `credential-documents/<entity_id>/...`, `profile-avatars/<entity_id>/...`, `portfolio-items/<entity_id>/...` |
| `supabase/config.toml` | Optional bucket declarations for `supabase start` parity |
| pgTAP posture test | `017_storage_posture.sql` — bucket existence, RLS, grants, leakage matrix |
| Realtime exclusion | No realtime on storage (storage schema not in `supabase_realtime`) — verified |

---

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| Client-side `StorageService` (`upload` with progress, `download`, `delete`, `getPublicUrl`, validators, path helpers) | EP-02-08 `lib/core/storage/` extension (depends on this task) |
| `lib/integrations/cloud_storage/` adapters (S3/Cloudinary) | ARCHITECTURE.md:119 — future provider abstraction, not EP-02-06 |
| Edge Functions for signed URL generation / virus scanning / thumbnailing | Future task; no EP-02 requirement |
| Modification of any `public.*` table, RPC, or prior migration (`20260819090001`–`20260829120006`) | Finalized; this task touches `storage.*` schema only |
| Direct Dart/Flutter code | Server-side infra only |
| CDN configuration beyond Supabase Storage `public` flag | Environment-specific; deferred to ENV-009 release validation |
| Deletion/archival workflows or lifecycle policies | Future task |
| Verification-state → storage-access coupling (e.g., only verified users can upload) | Policy remains owner-scoped; gate is `trade_verification_status` in app logic (AGENT.md Rule 2) |

---

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration — `storage` Schema Only

Create one migration:

```
supabase/migrations/<YYYYMMDD><HHMMSS>_storage_buckets.sql
```

Ordered **after** `20260829120006_dispute_withdraw_definer.sql`. Header comment block documents EP reference, bucket matrix, security posture (default-deny via `storage.objects` RLS), path convention, and size/MIME rationale. No `public.*` DDL.

Migration sections in order:

1. **Bucket DDL** — `INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)` with `ON CONFLICT (id) DO UPDATE` for idempotency (safe re-run across dev/staging/prod per ENV-002/003/008). If `storage.buckets.file_size_limit` is byte-enforced, use `10485760` (10 MiB) and `5242880` (5 MiB). If not supported in current Supabase version, create comment documenting enforcement via policy + future EP-02-08 client validation.
2. **RLS Enablement** — `storage.objects` already has RLS enabled in vanilla Supabase; migration asserts via `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` (idempotent).
3. **Revoke & Policy Reset** — Drop existing policies `IF EXISTS` for the three buckets (clean re-run), then `CREATE POLICY` per bucket/per operation.
4. **Grants** — `storage.buckets` and `storage.objects` are not grant-managed like `public.*`; access is via `storage.objects` RLS + Supabase Storage API `authenticated`/`anon` roles. No `GRANT` on `storage.*` needed (validated in test).
5. **Comments** — `COMMENT ON TABLE storage.buckets` / policy comments.
6. **Realtime Guard** — Verify `storage.*` not in `supabase_realtime` (guarded query, no mutation).

### 5.2 Bucket Matrix

| Bucket | `id` / `name` | `public` | `file_size_limit` | `allowed_mime_types` | Access Model |
|---|---|---|---|---|---|
| credential-documents | `credential-documents` | `false` | 10485760 (10 MiB) | `{image/jpeg, image/png, image/webp, application/pdf}` | Owner-only (authenticated). No `anon` SELECT. Owner can INSERT/SELECT/UPDATE/DELETE own prefix. `service_role` bypasses RLS (admin review). |
| profile-avatars | `profile-avatars` | `true` | 5242880 (5 MiB) | `{image/jpeg, image/png, image/webp}` | Public read (`anon` + `authenticated` SELECT). Owner write/delete (INSERT/UPDATE/DELETE where `foldername(name)[1] = auth.uid()::text`). |
| portfolio-items | `portfolio-items` | `true` | 10485760 (10 MiB) | `{image/jpeg, image/png, image/webp, application/pdf}` | Public read. Owner write/delete (same prefix check). |

**Deduplication from prior TIP:** Portfolio bucket aligns with `ARCHITECTURE.md:105` `systems/portfolio/` and `EP-02:306` specification. All three buckets appear in Phase Plan; omitting `portfolio-items` would block EP-02-19.

### 5.3 `storage.objects` RLS Policy Design

Supabase Storage enforces access via policies on `storage.objects` (`bucket_id`, `name`, `owner`, `owner_id`). Recommended pattern (owner-scoped via first path segment = `auth.uid()`):

```sql
-- Credential documents: private, owner-only
CREATE POLICY "credential_documents_select_owner"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'credential-documents' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "credential_documents_insert_owner"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'credential-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "credential_documents_update_owner"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'credential-documents' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'credential-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "credential_documents_delete_owner"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'credential-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Profile avatars: public read, owner write
CREATE POLICY "profile_avatars_select_public"
ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id = 'profile-avatars');

CREATE POLICY "profile_avatars_insert_owner"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ... update/delete symmetric to credential-documents ...

-- Portfolio items: public read, owner write (same shape as profile-avatars)
```

**Key hardening:**
- All policies include `bucket_id = '<bucket>'` conjunct to prevent cross-bucket leakage.
- Write policies use `WITH CHECK` on `name` prefix, not just `USING`, to prevent renames escaping prefix.
- `anon` receives no INSERT/UPDATE/DELETE on any bucket (default-deny).
- `service_role` bypasses RLS (no policy needed), enabling admin review of credential documents and dispute evidence.

**Path convention enforced:** `<entity_id>/<subpath>/<filename>` where `<entity_id>` is `auth.uid()::text`. Example helpers (documented for EP-02-08):
- `credential-documents/{entity_id}/{submission_id}/{uuid}.{ext}`
- `profile-avatars/{entity_id}/avatar.{ext}` (single object per entity; overwrite allowed)
- `portfolio-items/{entity_id}/{portfolio_item_id}/{filename}`

Policy `storage.foldername(name)[1]` validates first segment; deeper structure is application-validated in EP-02-08.

### 5.4 `supabase/config.toml` Local Parity

Add optional `[storage.buckets.*]` for `supabase start` seeding (not source of truth — migration is). Keeps ENV-002/ENV-008 isolation:

```toml
[storage.buckets.credential-documents]
public = false
file_size_limit = "10MiB"
allowed_mime_types = ["image/jpeg", "image/png", "image/webp", "application/pdf"]

[storage.buckets.profile-avatars]
public = true
file_size_limit = "5MiB"
allowed_mime_types = ["image/jpeg", "image/png", "image/webp"]

[storage.buckets.portfolio-items]
public = true
file_size_limit = "10MiB"
allowed_mime_types = ["image/jpeg", "image/png", "image/webp", "application/pdf"]
```

If `config.toml` syntax diverges by CLI version, omit and rely on migration only; document decision in migration header.

### 5.5 No RPCs / No `public` Functions

Storage is accessed via Supabase Storage API (`supabase_flutter:2.17.2` `SupabaseClient.storage.from(bucket).upload/download/getPublicUrl`), not RPC. No `public.*` functions are created; `013_financial_schema_posture.sql:153` assertion `no financial_% SECURITY DEFINER` remains unaffected. Do not create `storage_*` RPC wrappers — EP-02-08 service encapsulates the Storage SDK.

### 5.6 Idempotency & Transaction Safety

- Buckets: `INSERT ... ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = ..., allowed_mime_types = ...` (idempotent).
- Policies: `DROP POLICY IF EXISTS` before `CREATE POLICY`.
- Entire migration runs transactionally per Supabase default.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Storage buckets migration | `supabase/migrations/<timestamp>_storage_buckets.sql` | **Create** — INSERT 3 buckets + 11–12 `storage.objects` policies |
| `supabase/config.toml` | `supabase/config.toml` | **Update** — optional `[storage.buckets.*]` stanzas (3) |
| pgTAP storage posture test | `supabase/tests/database/017_storage_posture.sql` | **Create** — bucket/RLS/leakage suite |
| No `lib/core/storage/*.dart` | `lib/core/storage/` | **No change** — EP-02-08 owns service |

**No client-side modules in this task** — consistent with `EP-02-01:92`, `EP-02-05:215`.

---

## 7. Data Requirements

### 7.1 Bucket Catalogue

| Bucket | Attributes |
|---|---|
| `credential-documents` | `public false`, 10 MiB, 4 MIME types, private. Stores identity docs, trade proofs, certifications. Referenced by `entity_credentials.document_path` (EP-01-02) and `dispute_evidence.file_url`. |
| `profile-avatars` | `public true`, 5 MiB, 3 image types, public read. Stores `entity_profiles.avatar_url`. Single avatar per entity. |
| `portfolio-items` | `public true`, 10 MiB, 4 MIME types, public read. Stores portfolio showcase items (future `portfolio_items` table or JSON in `entity_profiles`). |

### 7.2 No New `public.*` Tables

Data lives in `storage.buckets` (catalog) and `storage.objects` (object metadata). No application tables are created. Foreign-key links are via stored URL strings (e.g., `entity_credentials.document_path = 'credential-documents/<entity_id>/...'`), not FK constraints — storage schema cannot FK to `public.entities`.

### 7.3 Path Convention Vocabulary

- `credential-documents/{entity_id}/{credential_id or submission_id}/{file_name}` — `{entity_id}` must equal `auth.uid()`. One object per submission; multiple allowed per entity.
- `profile-avatars/{entity_id}/avatar[.ext]` — canonical single avatar; client overwrites on update. Policy allows any name under prefix, but EP-02-08 helper enforces canonical naming.
- `portfolio-items/{entity_id}/{item_id}/{file_name}` — multiple items per entity.

All paths are lower-case, URL-safe; extension validated by MIME allowlist.

---

## 8. Database Considerations

### 8.1 Schema Boundary: `storage.*` vs `public.*`

- `storage.buckets` and `storage.objects` belong to `storage` schema (Supabase-managed). No `public.*` tables are altered; `20260829100004_financial_integrity_schema.sql` financial tables, `20260829090003_verification_admin_review_schema.sql` verification tables, and `20260829120005_dispute_resolution_schema.sql` dispute tables remain untouched — satisfies `EP-02-05 Scope:62` pattern.
- RLS is on `storage.objects` (enabled by default). This task adds policies; it does not disable or relax any `public.*` RLS.
- `storage.objects` has no `platform_set_updated_at` trigger (no `updated_at` column). No trigger management.

### 8.2 Policy Evaluation Order

- `service_role` bypasses RLS — admin review and system workers have full storage access without policies.
- `authenticated` policies are `PERMISSIVE` (default); absence of a matching policy = deny (default-deny posture).
- Bucket conjunct (`bucket_id = ...`) ensures policies do not cross buckets; test validates.

### 8.3 MIME & Size Enforcement Layering

- **Primary:** `storage.buckets.allowed_mime_types` + `file_size_limit` (server-enforced on upload).
- **Secondary:** `storage.objects` policy `WITH CHECK` could additionally validate `octet_length` or `mime_type` if Supabase exposes; not required but documented as defense-in-depth.
- **Tertiary:** EP-02-08 client-side validation (MIME sniff, max bytes) for UX fail-fast — not a security boundary.

### 8.4 Realtime

`storage.objects` is not part of `supabase_realtime` by default; no exclusion needed beyond guard check. Mutations are not realtime-subscribed (avatars/portfolios polled or fetched via `getPublicUrl`). Consistent with `EP-02-05:903-916` realtime guard pattern.

---

## 9. API Requirements

### 9.1 No RPC Surface

No `public.*` RPCs are created. All access is via PostgREST Storage API:

| Operation | SDK Call (EP-02-08) | Auth | Policy Gate |
|---|---|---|---|
| Upload credential | `supabase.storage.from('credential-documents').upload(path, file)` | `authenticated` | `credential_documents_insert_owner` + bucket MIME/size |
| Download credential | `supabase.storage.from('credential-documents').download(path)` | `authenticated` | `credential_documents_select_owner` |
| Delete credential | `supabase.storage.from('credential-documents').remove([path])` | `authenticated` | `credential_documents_delete_owner` |
| Get avatar URL | `supabase.storage.from('profile-avatars').getPublicUrl(path)` | `anon`/`authenticated` | `profile_avatars_select_public` |
| Upload avatar | `supabase.storage.from('profile-avatars').upload(path, file, fileOptions: {upsert: true})` | `authenticated` | `profile_avatars_insert_owner` |
| Upload portfolio | `supabase.storage.from('portfolio-items').upload(path, file)` | `authenticated` | `portfolio_items_insert_owner` |
| Get portfolio URL | `supabase.storage.from('portfolio-items').getPublicUrl(path)` | `anon`/`authenticated` | `portfolio_items_select_public` |

### 9.2 Webhook / Edge Function

None in this task. Future thumbnail/scan hooks may require Edge Function; not in scope per `EP-02:158` (webhook handling deferred to EP-02-08/09).

---

## 10. User Interface Requirements

**None.** This task produces no widgets, screens, or design tokens. All EP-02 UI must consume `AppTheme` per AGENT.md Rule 5 (`documents/Context/AGENT.md:18`) — but no UI is introduced here, so no `VISUAL-IDENTITY.md` token consumption is needed. EP-02-18/19 UIs will consume this storage layer.

---

## 11. User Experience Considerations

While server-side only, this infrastructure shapes downstream UX (EP-02-08/10/11/18/19):

- **Fail-fast validation:** MIME/size rejection at upload yields immediate `PLT003`-analog error (storage API error) rather than silent DB inconsistency.
- **Public avatar/portfolio:** `getPublicUrl` enables SEO-friendly, no-auth rendering on `/p/:profession_slug/:entity_id` (ARCHITECTURE.md:150) without token refresh.
- **Private credentials:** Credential preview requires authenticated `download` + `createSignedUrl` (60s TTL) — no public link leakage. EP-02-08 will abstract this.
- **Progress feedback:** EP-02-08 service will surface `onProgress` callback; this task ensures uploads are not blocked by policy misconfiguration that would surface as opaque `403`.
- **Idempotent avatar overwrite:** `upsert: true` on `profile-avatars/{entity_id}/avatar` prevents stale duplicates and simplifies cache invalidation.

---

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Zero public credential access | `credential-documents` `public = false`; no `anon` SELECT policy; `authenticated` SELECT limited to owner prefix. `service_role` only uncapped path. |
| Document leakage prevention | Bucket `public` flag + `storage.objects` `bucket_id` conjunct on every policy. Partial-bucket test validates no cross-bucket SELECT. |
| Path traversal / prefix escape | `WITH CHECK` on `storage.foldername(name)[1] = auth.uid()::text` prevents writing outside own prefix. `..` or `/` injection still resolves to first segment check; Supabase Storage normalizes path. Test covers `evil-entity-id/` attempt. |
| MIME spoofing | Bucket `allowed_mime_types` blocks non-image/PDF at storage-API layer; EP-02-08 client sniff adds UX layer but server is authoritative. |
| Size DoS | `file_size_limit` blocks oversized uploads before storage; prevents cost blow-up. |
| Anon write DoS | No `anon` INSERT/UPDATE/DELETE policies on any bucket; `anon` 403 validated. |
| Service-role trust | `service_role` bypasses RLS — acceptable because it is never exposed to client; admin review uses it server-side. No new `SECURITY DEFINER` functions are created (keeps `013_financial_schema_posture.sql:153` `prosecdef = 0` clean). |
| No `public.*` grant drift | No `GRANT` on `public.*`; storage policies are orthogonal. Full suite `001`–`016` + `017` confirms no regression. |
| SQL injection | No dynamic SQL in migration; bucket names are literals. Policies are static DDL. |
| Secret exposure | No keys, tokens, or PII in bucket definitions or policies. |
| ENV isolation | ENV-002/008: buckets seeded per environment via migration; no cross-environment sharing. Staging can use separate limits via `config.toml` TOML override if needed without code change. |

---

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Public bucket CDN | `profile-avatars` and `portfolio-items` `public = true` enables Supabase CDN + browser caching via `Cache-Control` on `getPublicUrl`. No auth header overhead. |
| Private bucket signed URLs | `credential-documents` uses short-lived `createSignedUrl` (60–300s TTL) — minimal signing overhead; no public CDN hit for sensitive docs. |
| Upload throughput | 5–10 MiB limits keep multipart uploads single-part in most networks; no chunked upload needed. EP-02-08 progress tracking is lightweight (Dio `onSendProgress`-analog via storage SDK). |
| Policy evaluation cost | `storage.foldername(name)[1]` is indexed on `storage.objects.name` GIN/trigram (Supabase default); single string comparison, negligible overhead. Bucket conjunct allows index filter on `bucket_id`. |
| Volatile vs Stable | No functions created — no volatility marking. Storage API calls are inherently volatile (write) or stable (public URL); no planner optimization needed. |
| Scale | Supabase Storage backed by S3-compatible object store; bucket-per-domain scales to millions of objects. Prefix `{entity_id}/` shards by entity, avoiding hot partition. |
| No N+1 | No DB joins required; object listing via `storage.list(path)` is prefix-scanned, paginated. EP-02-08 will list with `limit` param. |
| Future: thumbnail variant | Not in scope, but `portfolio-items` can later add `{item_id}/thumb_{w}.webp` without policy change (prefix still matches). |

---

## 14. Testing Strategy

### 14.1 `017_storage_posture.sql` — Storage Infrastructure Posture

Create `supabase/tests/database/017_storage_posture.sql` following `013_financial_schema_posture.sql:20` and `015_dispute_schema_posture.sql` pattern: `begin; set search_path to extensions, public, storage; select plan(N); ... select * from finish(); rollback;`

| # | Assertion | Method |
|---|---|---|
| 1–3 | Buckets exist: `credential-documents`, `profile-avatars`, `portfolio-items` | `has_table` analog: `SELECT count(*) FROM storage.buckets WHERE id = '<bucket>'` = 1, or `has_table('storage','buckets')` + row count |
| 4 | `credential-documents` `public = false` | `SELECT public FROM storage.buckets WHERE id = 'credential-documents'` = false |
| 5 | `profile-avatars` `public = true` | = true |
| 6 | `portfolio-items` `public = true` | = true |
| 7 | `credential-documents` `file_size_limit = 10485760` | bucket config check |
| 8 | `profile-avatars` `file_size_limit = 5242880` | |
| 9 | `portfolio-items` `file_size_limit = 10485760` | |
| 10 | `credential-documents` MIME allowlist = `{jpeg,png,webp,pdf}` | `allowed_mime_types` array check |
| 11 | `profile-avatars` MIME allowlist = `{jpeg,png,webp}` | |
| 12 | `portfolio-items` MIME allowlist includes `pdf` | |
| 13 | `storage.objects` RLS enabled | `SELECT relrowsecurity FROM pg_class WHERE relname='objects' AND relnamespace='storage'::regnamespace` = true |
| 14 | Policies exist: count >= 11 (4 cred + 4 avatar + 3 portfolio min) | `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE '%credential%'` etc. |
| 15 | `anon` zero INSERT/UPDATE/DELETE on any bucket | Leakage query: `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND permissive AND roles @> '{anon}' AND cmd IN ('INSERT','UPDATE','DELETE')` = 0 (or `role_table_grants` check on `storage.objects`) |
| 16 | `credential-documents` has owner-scoped SELECT for `authenticated` | Policy `qual` contains `foldername` + `auth.uid()` |
| 17 | `profile-avatars` has public SELECT for `anon, authenticated` | Policy `qual` with `bucket_id='profile-avatars'` and `roles @> '{anon,authenticated}'` |
| 18 | `portfolio-items` has public SELECT | Same |
| 19 | No `storage.objects` policy grants `anon` INSERT | =0 |
| 20 | No `storage.*` SECURITY DEFINER function | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'storage_%' AND prosecdef` = 0 |
| 21 | `storage.buckets` has comments / not null bucket ids | existence + array bounds |
| 22 | All 3 buckets have `created_at` not null | |
| 23 | Cross-bucket leakage prevented: policy `qual` contains `bucket_id =` | string check |
| 24 | `authenticated` cannot SELECT another entity's credential path | RLS simulation: `SET LOCAL role authenticated; SET LOCAL request.jwt.claim.sub = '<attacker>'` then `SELECT` on `storage.objects` with victim prefix returns 0 rows |
| 25 | Full suite no realtime inclusion of storage | `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='storage'` = 0 |

Target: **25 assertions** (adjust to keep `plan(N)` exact). Keep style consistent with `013_financial_schema_posture.sql:186` `seeded with 4 currencies` pattern.

### 14.2 Leakage & Enforcement Simulation (Part of 017)

Beyond static checks, 017 includes role-simulated leakage matrix (like `001_rls_leakage_matrix.sql`, `005_entity_rls_leakage_matrix.sql`):

- As `anon`: `SELECT` on `storage.objects` via `profile-avatars` succeeds; via `credential-documents` returns 0 rows; `INSERT` on any bucket throws `42501`.
- As `authenticated` (entity A): Insert `credential-documents/<A>/doc.pdf` succeeds; Insert `credential-documents/<B>/doc.pdf` fails (policy `WITH CHECK`); Select `<A>` succeeds; Select `<B>` returns 0 rows.
- As `service_role`: Insert/Select any prefix succeeds (RLS bypass).

Requires `SET LOCAL role` + `SET LOCAL request.jwt.claim.sub` + `request.jwt.claim.role` harness (see `003_rpc_validation_errors.sql` helper). Document that these are policy-logic checks, not Storage API E2E (Storage API E2E is deferred to EP-02-08 integration test with `supabase_flutter` mock).

### 14.3 Regression

- Full suite `001`–`017` must remain green. Specifically: `008_full_schema_posture_audit.sql`, `013_financial_schema_posture.sql:153` (no `financial_%` SECURITY DEFINER), `015_dispute_schema_posture.sql` (exactly 2 `dispute_%` SECURITY DEFINER) unchanged.
- No `public.*` grant drift: `anon` still zero grants on `public.financial_*` private tables, `public.dispute_*`, `public.verification_*`.

### 14.4 No Storage API E2E in This Task

E2E upload/download via `supabase.storage` SDK is covered in EP-02-08 integration test (`StorageService` with mock and live `supabase start` container). This task's pgTAP suite is sufficient posture gate.

---

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/config.toml` (current) + `supabase/migrations/20260829120006*` ordering; confirm `storage` schema exists in local `supabase start` | Baseline |
| 2 | Draft migration header comment (EP-02-06 purpose, bucket matrix, security posture, path convention, size/MIME rationale, ENV-002/008 note) | Docs |
| 3 | `INSERT INTO storage.buckets` — `credential-documents` (`public false`, 10 MiB, jpeg/png/webp/pdf) with `ON CONFLICT DO UPDATE` | Bucket 1 |
| 4 | `INSERT INTO storage.buckets` — `profile-avatars` (`public true`, 5 MiB, jpeg/png/webp) | Bucket 2 |
| 5 | `INSERT INTO storage.buckets` — `portfolio-items` (`public true`, 10 MiB, jpeg/png/webp/pdf) | Bucket 3 |
| 6 | `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` (idempotent) | RLS guard |
| 7 | `DROP POLICY IF EXISTS` for all 11–12 policies (clean idempotent re-run) | Policy reset |
| 8 | `CREATE POLICY` — `credential-documents`: 4 policies (SELECT/INSERT/UPDATE/DELETE owner-only) with `bucket_id` + `foldername` prefix | Policies 1-4 |
| 9 | `CREATE POLICY` — `profile-avatars`: 4 policies (public SELECT + 3 owner write) | Policies 5-8 |
| 10 | `CREATE POLICY` — `portfolio-items`: 3–4 policies (public SELECT + 3 owner write) | Policies 9-12 |
| 11 | `COMMENT ON TABLE storage.buckets` / `COMMENT ON POLICY` documentation | Docs |
| 12 | Guarded `DO $$` realtime exclusion check (assert `storage` not in `supabase_realtime`) | Guard |
| 13 | Update `supabase/config.toml` with `[storage.buckets.*]` stanzas (if CLI version supports) — or document intentional omission | Config parity |
| 14 | Create `supabase/tests/database/017_storage_posture.sql` (25 assertions, plan/extension/public/storage search_path) | Test |
| 15 | `supabase db push` (or `supabase db reset`) — apply migration locally | Migrate |
| 16 | `supabase db test` — 017 + full suite `001`–`017` green | Verify |
| 17 | Negative probe: `SELECT * FROM storage.buckets` via `anon`/`authenticated` RLS simulation; confirm private/public flags via SQL | Manual verify |

---

## 16. Expected Outcome

- 3 Supabase Storage buckets provisioned, queryable via `SELECT * FROM storage.buckets` (3 rows), with correct `public`, `file_size_limit`, `allowed_mime_types`.
- 11–12 `storage.objects` RLS policies enforce: credential-documents private owner-only; profile-avatars/portfolio-items public read + owner write; no cross-bucket leakage; `anon` zero write.
- Path convention documented and enforced: `{entity_id}/...` prefix via `storage.foldername(name)[1] = auth.uid()::text`.
- MIME and size limits block oversized/invalid-type uploads at API layer before storage cost.
- `supabase/config.toml` reflects buckets for reproducible `supabase start` per ENV-002.
- pgTAP `017_storage_posture.sql` passes 25 posture/leakage assertions; full suite `001`–`017` green.
- Zero `public.*` tables, RPCs, or client Dart files introduced.
- EP-02-07 (taxonomy engine), EP-02-08 (StorageService), EP-02-10 (identity verification), EP-02-11 (trade verification), EP-02-17/18/19 unblocked — storage is the last infra dependency for those flows.

---

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | Migration file exists at `supabase/migrations/<timestamp>_storage_buckets.sql`, ordered after `20260829120006_dispute_withdraw_definer.sql` | File inspection |
| 2 | `storage.buckets` contains exactly 3 rows: `credential-documents`, `profile-avatars`, `portfolio-items` | `SELECT count(*) FROM storage.buckets WHERE id IN (...)` = 3 |
| 3 | `credential-documents` `public = false` | `SELECT public FROM storage.buckets WHERE id='credential-documents'` = false |
| 4 | `profile-avatars` `public = true` | = true |
| 5 | `portfolio-items` `public = true` | = true |
| 6 | `credential-documents` `file_size_limit = 10485760` and `allowed_mime_types @> '{image/jpeg,image/png,image/webp,application/pdf}'` | bucket config query |
| 7 | `profile-avatars` `file_size_limit = 5242880` and `allowed_mime_types = '{image/jpeg,image/png,image/webp}'` | |
| 8 | `portfolio-items` `file_size_limit = 10485760` and MIME includes pdf | |
| 9 | `storage.objects` RLS enabled | `pg_class.relrowsecurity` = true for `storage.objects` |
| 10 | ≥11 `storage.objects` policies exist covering all buckets and all cmds | `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects'` ≥ 11 |
| 11 | Every policy qual/with_check contains `bucket_id = '<bucket>'` conjunct | `pg_policies.qual::text LIKE '%bucket_id = %'` |
| 12 | `credential-documents` SELECT policy scoped to `authenticated` + `foldername(name)[1] = auth.uid()::text` (no `anon`) | `pg_policies` inspection |
| 13 | `profile-avatars` public SELECT granted to `anon, authenticated` | |
| 14 | `portfolio-items` public SELECT granted to `anon, authenticated` | |
| 15 | `anon` has zero INSERT/UPDATE/DELETE policies on `storage.objects` | `pg_policies` where `roles @> '{anon}' AND cmd IN (INSERT,UPDATE,DELETE)` = 0 |
| 16 | `authenticated` cannot INSERT outside own prefix — `WITH CHECK` contains `foldername` | policy inspection |
| 17 | No `storage_*` or `financial_%` SECURITY DEFINER functions created | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'storage_%' AND prosecdef` = 0 and `financial_%` still 0 per `013:153` |
| 18 | `storage.objects` not in `supabase_realtime` | `pg_publication_tables` count = 0 |
| 19 | Migration is idempotent — second `supabase db push` / `INSERT ON CONFLICT` re-run yields still 3 buckets, same policies | re-run inspection |
| 20 | `supabase/config.toml` declares 3 buckets (or documents intentional omission with rationale) | file inspection |
| 21 | No DDL on `public.*` tables, no RPCs, no `lib/` changes | `git diff --stat` shows only `supabase/migrations/*_storage_buckets.sql`, `supabase/config.toml`, `supabase/tests/database/017*` |
| 22 | `017_storage_posture.sql` exists with 25 assertions, uses `begin; set search_path to extensions, public, storage; select plan(25)` | file inspection |
| 23 | `017_storage_posture.sql` passes (`supabase db test`) | `supabase db test` — 017 green |
| 24 | Full suite `001`–`017` passes without regression | `supabase db test` — zero failures |
| 25 | Manual RLS simulation: entity A cannot SELECT entity B's `credential-documents/<B>/...` object | pgTAP leakage assertion |
| 26 | Path convention documented in migration header and TIP §5.3 | code review |
| 27 | All 3 buckets have `COMMENT` or documented rationale | `obj_description` or header |
| 28 | EP-02-08/10/11 unblocked | dependency check |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Very High** — Storage is not a `public.*` table but the `storage` schema (`storage.buckets`, `storage.objects`) with distinct RLS semantics (`storage.foldername`, `bucket_id` conjunct, `public` flag vs policy dual layer). Bucket `file_size_limit`/`allowed_mime_types` typing varies by Supabase version; posture test must handle both `storage.buckets` catalog shape and `pg_policies` on `storage.objects`. |
| **Business impact** | **Very High** — Misconfiguration causes catastrophic doc leakage (private credential docs become public) or total upload blockage, breaking AGENT.md Rule 2 trade gate and all EP-02-10/11/17/18/19 flows. Blocks Stage 3 client infrastructure. |
| **Security risk** | **Very High** — Default-deny must hold: credential-documents private owner-only, avatars/portfolios public read but owner write only. One missing `bucket_id` conjunct or `WITH CHECK` omission enables cross-bucket or prefix-escape write. `013_financial_schema_posture.sql:53-60` anon-zero-grant posture must extend to `storage.objects`. No SECURITY DEFINER drift allowed. |
| **Performance sensitivity** | Medium — Public bucket CDN vs private signed-URL tradeoff, policy `foldername` evaluation cost, but not latency-critical at infra layer. |
| **Data complexity** | Medium — No double-entry ledger; but path convention `{entity_id}/...` + MIME allowlist + size limit interact; test must cover MIME/size/prefix matrix. |
| **Integration complexity** | **Very High** — Touches `supabase_flutter` Storage SDK contract (EP-02-08), verification schema (`entity_credentials.document_path`), dispute evidence (`dispute_evidence.file_url`), profile/portfolio tables, and ENV-002/008/009 isolation. Must align with `ARCHITECTURE.md:58-60,119` storage boundary and `lib/core/storage/` vs `integrations/cloud_storage/` separation. |

The Approved Phase Plan assigns EP-02-06 **Planning: Very High / Coding: Very High** (`EP-02:506-507` — 8 Very High items including EP-02-06; 6 Extremely High items exclude it). Storage posture is security-critical but does not carry the inline double-entry financial atomicity of EP-02-04/05/14/16; **Very High** (not Extremely High) is calibrated.

---

> **Next Step:** Awaiting your approval to proceed to implementation. No files will be created or migrations applied until confirmed. Questions before green-light:
> 1. Confirm 5 MiB vs 10 MiB split for avatars vs credentials/portfolio, and MIME allowlists above — or adjust for Nigerian-network / KYC-doc realities (e.g., require `image/heic` for iOS, allow `application/msword` for older trade certificates)?
> 2. Confirm `public = true` for `portfolio-items` (SEO-friendly) or prefer `public = false` + `createSignedUrl` for scarcity-gated portfolios?
> 3. Prefer bucket provisioning via SQL migration only (most portable) or also via `config.toml` stanzas for `supabase start` parity?
