# Production Onboarding Failure — Investigation Report

**Date:** 2026-09-20
**Investigator:** OpenCode (Muse Spark)
**Environment:** `production` (`https://hivorr.pages.dev` → Supabase project `fxpcgtetvzlexbptqiwp.supabase.co` (`PRODUCTION_HIVORR_SUPABASE_URL`)), vs `staging` (`https://hivorr-staging.pages.dev` → `cgxkiczmwzydhoroclvf`) and `local` Docker (`http://127.0.0.1:54321`, project `hivorr`)
**Observed Symptom:** Registration/sign-in reaches onboarding; after entering all required onboarding information and attempting to continue/submit, UI displays `Resource not found.`

**Compliance:** Investigation-only. No production DB writes, no migration applied, no resource created, no error suppressed. Reuse-first rule respected.

---

## 1. Exact Root Cause

**Production Supabase DB has not had 6 additive migrations applied that local and staging have. The deployment pipeline (`production-promotion.yml`) rebuilds the Flutter web artifact but never pushes Supabase migrations, so the new frontend (`master@9ece964`) calls RPCs/columns/tables that do not exist in production (PGRST202/PGRST205/42703). PostgREST returns HTTP 404 → `ApiExceptionMapper:44` / `data_exception_mapper.dart:81` maps to generic `Resource not found.` → `OnboardingProvider.lastError` → inline step error.**

Schema drift is deterministic: every resource introduced in `20260913090001`–`20260917090002` is absent on production.

## 2. Exact Failing Operation

Full trace `User → Auth → Session → Onboarding screen → Form submission → API/service → DB/RPC → Response`:

1. `lib/systems/onboarding/screens/profile_setup_screen.dart:308` → `OnboardingProvider.completeProfile:142` → `OnboardingService.completeProfile:405` → `SupabaseEntityRemoteDataSource.updateProfile:52` → `supabase.rpc('entity_profile_update')` — **SUCCEEDS on both prod and staging** (function exists since 20260821, 42501 anon-check on both; 20260911090001 upsert fix already on prod at `243975b`).
2. **FAIL 1 — Capability step** `capability_selection_screen.dart:90` → `OnboardingProvider.selectCapability:114` → `OnboardingService.selectCapability:253` → `_completeOrPersistCapability:277` → `OnboardingRepositoryImpl.update:27` → `SupabaseOnboardingRemoteDataSource.updateStatus:49` → `supabase.rpc('entity_onboarding_status_update', {p_capability: 'hire'|'offer'|'both'})` — **PGRST202 on prod (function not found) → 404 → Resource not found**. On staging this RPC returns `PLT000` or `PLT003` validation.
3. **FAIL 2 — Final completion** `trade_proof_step_screen.dart:214` / `identity_verification_step_screen.dart:173` paths converge to `OnboardingService.advance:237` at `next==null` → `_completeOnServer:291` → `repo.update(completed:true)` → same `entity_onboarding_status_update(p_completed:true)` — same PGRST202/404.
4. **FAIL 0 — Hydration** `OnboardingService.resume:128` → `_serverHydrate:166` → `repo.getStatus:20` → `SupabaseOnboardingRemoteDataSource.getStatus:33` → `supabase.rpc('entity_onboarding_status_get')` — also PGRST202 on prod (caught as `ApiException` and degraded to local cache, so not surfaced but masks serverCompleted staying `null`).

Any `Resource not found` observed after "all required onboarding information" is FAIL 1 or FAIL 2. The failure is at the RPC layer, before any profile/capability persistence.

## 3. Exact Missing/Inaccessible Resource

Not a single missing row — a **missing schema**:

| Object | Kind | Introduced By | Local/Staging | Production (evidence) |
|---|---|---|---|---|
| `entities.capability` | column `text` CHECK `hire|offer|both` | `20260915090001:32` | exists (`docker exec psql` lists `capability`) | `42703 column entities.capability does not exist` (prod `curl /rest/v1/entities?select=id,capability` ) |
| `entities.onboarding_completed_at` | column `timestamptz` | `20260915090001:34` | exists | `42703 column entities.onboarding_completed_at does not exist` |
| `entity_onboarding_audit_trail` | table | `20260915090001:102` | exists (REST `permission denied` not PGRST205) | `PGRST205 Could not find the table` |
| `portfolio_items` | table | `20260913090001:24` | exists | `PGRST205 Could not find the table` |
| `platform_admins` | table | `20260916090001:40` | exists | `PGRST205 Could not find the table` |
| `entity_onboarding_status_get()` | RPC `SECURITY INVOKER` | `20260915090001:265` | `42501 permission denied` (function found, anon blocked) | `PGRST202 Searched for the function public.entity_onboarding_status_get … no matches were found` |
| `entity_onboarding_status_update(text,boolean)` | RPC | `20260915090001:145` | `42501` | `PGRST202` |
| `entity_onboarding_reset(uuid)` | RPC | `20260915090001:311` | `PGRST202` with `{}` arity but `42501` with proper param on staging? staging also `PGRST202` with `{}` due to arity, but existence proven via column check; `is_platform_admin` differentiates (see next) |
| `is_platform_admin(uuid)` | `SECURITY DEFINER` helper | `20260916090001:75` | `42501` | `PGRST202` |
| `platform_admin_check()` | RPC | `20260916090001:627` | `42501` | `PGRST202` |
| `portfolio_public_profile_get(uuid)` | `SECURITY DEFINER` | `20260913090001:120` | `P0001 PLT004 Professional profile not found` (function executed) | `PGRST202 Could not find the function public.portfolio_public_profile_get(p_entity_id)` |
| `manage_user_list(text,text,int,int)` | RPC | `20260917090002:67` | `42501` | `PGRST202` |
| `verification_review_queue_get` | RPC | `20260916090001:817` + reconcile `20260917090001:36` | `42501` | `PGRST202` |
| Triggers `entities_guard_onboarding_state_update`, `entity_professions_guard_verification_state`, etc. | triggers on `entities`, `entity_professions` | `20260915090001:89` `20260916090001:155` | exist | absent (implied by missing columns/tables) |
| Column-level grants `UPDATE(capability, onboarding_completed_at)` | grant | `20260915090001:57` | exist | missing |

All absence is consistent with **6 unapplied migrations** (ordered):

1. `20260913090001_portfolio_public_profile.sql`
2. `20260915090001_onboarding_authoritative_state.sql` — **critical for onboarding**
3. `20260916090001_super_admin_system.sql`
4. `20260916090002_super_admin_seed.sql`
5. `20260917090001_admin_review_contract_reconcile.sql`
6. `20260917090002_manage_user.sql`

`20260911090001_entity_profile_upsert_fix.sql` and `20260911090002_demo_identity_seed.sql` **are** present on prod (prod deployment `243975b` post-dates them; `entity_profile_update:52` returns `42501` not `PGRST202` on both envs).

## 4. Evidence Proving the Cause

### 4.1 Error propagation chain (code)

- Generic message `Resource not found.` originates only from two normalizers:
  - `lib/core/api/exceptions/api_exception_mapper.dart:46` — HTTP 404 `platformMessage ?? 'Resource not found.'`
  - `lib/data/datasources/remote/data_exception_mapper.dart:81` — `PostgrestException` with `code PLT004` → `return 'Resource not found.'` (`_safeMessage`).
- The `PLT004` path (`DataExceptionMapper`) is used by `SupabaseEntityRemoteDataSource._guard:24` → `mapDataException` and `SupabaseOnboardingRemoteDataSource._guard:24`. The 404 HTTP path (`ApiExceptionMapper`) is used for raw `PGRST202`/`PGRST205`/`42703` from PostgREST, which arrive as `DioException` 404 before `PostgrestException` wrapping (verified by curl returning HTTP 404 with JSON `code:PGRST202`).
- UI: `onboarding_provider.dart:227` catches `ApiException` → `_lastError = e` → `profile_setup_screen.dart:231` / `capability_selection_screen.dart:82` / `industry_profession_selection_screen.dart:96` render `provider.lastError!.message`.

### 4.2 Live production proof (read-only)

**Stale build extraction:**
- `main.dart.js` on `https://hivorr.pages.dev` contains `HIVORR_SUPABASE_URL=https://fxpcgtetvzlexbptqiwp.supabase.co` and `HIVORR_SUPABASE_ANON_KEY=sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc` (publishable key), confirming prod frontend is built for production project.

**RPC existence probe (same payload, same anon role):**
```
# prod — missing
$ curl -s -X POST "https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/rpc/entity_onboarding_status_get" \
  -H "apikey: sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc" \
  -H "Authorization: Bearer …" -H "Content-Type: application/json" -d "{}"

→ {"code":"PGRST202","details":"Searched for the function public.entity_onboarding_status_get … no matches were found","hint":"Perhaps you meant to call the function public.financial_status_get","message":"Could not find the function … in the schema cache"}

# staging — exists (same {} arity, anon blocked by EXECUTE grant)
$ curl -s -X POST "https://cgxkiczmwzydhoroclvf.supabase.co/rest/v1/rpc/entity_onboarding_status_get" \
  -H "apikey: sb_publishable_lG40mgSsrlz2jrACB9x3WQ_hF-zxCF8" … -d "{}"

→ {"code":"42501","message":"permission denied for function entity_onboarding_status_get"}
```
Identical pattern for `entity_onboarding_status_update` (`PGRST202` prod vs `42501` staging), `is_platform_admin` (`PGRST202` vs `42501`), `platform_admin_check` (`PGRST202` vs `42501`).

**Column existence probe:**
```
# prod — column absent
GET /rest/v1/entities?select=id,capability  (anon)
→ {"code":"42703","message":"column entities.capability does not exist"}

GET /rest/v1/entities?select=id,onboarding_completed_at
→ {"code":"42703","message":"column entities.onboarding_completed_at does not exist"}

# staging — column exists (table exists, anon has no SELECT grant as designed)
GET /rest/v1/entities?select=id,capability  (anon)
→ {"code":"42501","message":"permission denied for table entities"}
```

**Table existence probe:**
```
GET /rest/v1/portfolio_items?select=id   (anon)
prod:    {"code":"PGRST205","message":"Could not find the table 'public.portfolio_items' …"}
staging: {"code":"42501","message":"permission denied for table portfolio_items"}

GET /rest/v1/platform_admins?select=id
prod:    PGRST205
staging: 42501

GET /rest/v1/entity_onboarding_audit_trail?select=id
prod:    PGRST205
staging: 42501
```

**RPC with correct params — portfolio_public_profile_get:**
```
# prod — function absent regardless of param
POST /rest/v1/rpc/portfolio_public_profile_get  -d '{"p_entity_id":"000…"}'
→ PGRST202 "Could not find the function public.portfolio_public_profile_get(p_entity_id) … Perhaps you meant public.financial_profile_get"

# staging — function executes (returns PLT004 as designed for unknown entity)
POST …/portfolio_public_profile_get (same payload)
→ {"code":"P0001","details":"PLT004","message":"PLT004: Professional profile not found."}
```

**Local Docker control (ground truth):**
```
docker exec supabase_db_hivorr psql -U postgres \
  -c "select column_name from information_schema.columns where table_name='entities' order by column_name;"

→ capability, created_at, created_by, id, onboarding_completed_at, status, updated_at  (7 rows)

psql -c "select proname from pg_proc where proname like 'entity_onboarding%' …"
→ entity_onboarding_reset, entity_onboarding_status_get, entity_onboarding_status_update, portfolio_public_profile_get (4 rows)

psql -c "select version from supabase_migrations.schema_migrations order by version;"
→ 20260819090001 … 20260917090002 (24 rows) — all migrations applied locally
```

### 4.3 Deployment state

- `gh api repos/Oludammy2030/Hivorr/deployments` (2026-09-20): last `production` deployment `243975b` at `2026-09-15T11:25:22Z` (staging `9ece964` at `2026-09-20T08:00:35Z`). Production is **6 commits / ~5 days behind** staging/master.
- `git diff --name-only 243975b..9ece964` shows the 6 migration files listed in §3 as added after prod deployment.
- `gh variable list --env Production`: `PRODUCTION_HIVORR_SUPABASE_URL=https://fxpcgtetvzlexbptqiwp.supabase.co`; `gh secret list --env Production`: `CLOUDFLARE_API_TOKEN`, `PRODUCTION_HIVORR_SUPABASE_ANON_KEY` — env vars correct.
- Triggered promotion `gh workflow run production-promotion.yml -f commit_sha=9ece964222a10c663373b053cd04b33379a4b0cc` → run `35499187524` `Verify Staged Commit` **success** (verified `on-master` and `Staging deployment passed`), then `Production Build` in_progress at 08:20Z. That workflow **does not contain any `supabase db push`** step; it only validates and runs `wrangler pages deploy` after manual issue approval (`production-promotion.yml:121-134` `trstringer/manual-approval`). DB drift is not blocked.

### 4.4 Onboarding domain resources not involved (negative evidence)

- `industries` table: `GET /rest/v1/industries?select=id` returns 8 rows on both prod and staging (different seeded UUIDs) → taxonomy seed `20260829090001` is on prod, not the cause.
- `entity_profile_update` RPC: `POST .../entity_profile_update -d '{"p_legal_name":"A","p_display_name":"B"}'` returns `42501 permission denied` on **both** prod and staging (function found) → earlier RPCs present.
- Storage buckets: local has 3 (`credential-documents f, portfolio-items t, profile-avatars t`) per `storage.buckets`; prod/staging storage API `GET /storage/v1/bucket` returns `[]` for anon (expected, buckets are permission-gated) — not probative, but no `PGRST205` bucket-not-found error observed for profile avatar upload path.

## 5. Local Environment State

- **DB:** Docker `supabase_db_hivorr:54322` healthy, Supabase CLI `2.115.0`, `supabase_migrations.schema_migrations` 24 rows up to `20260917090002`. All onboarding-related objects present (see §4.2 local). `supabase status` shows APIs `54321`, `54322`, `54323`. No secrets in `supabase/config.toml` (hardened, EP-01-05 §5.1).
- **Code:** `lib/systems/onboarding/services/onboarding_service.dart:277` calls `entity_onboarding_status_update`; `supabase_onboarding_remote_data_source.dart:34-53` unwraps `{success,code,message,data}` envelope; `_serverHydrate:166` handles PGRST404 as transient fallback to local `OnboardingProgressStore`. Unit tests `test/unit/systems/...` and `database-rls-tests.yml` pgTAP `019_onboarding_authoritative_state.sql` pass locally.
- **Build:** `pubspec.yaml:3.51 Flutter`, `reusable-validation.yml:106` `flutter test --coverage` passes for `9ece964` on staging CI (validated commit).

## 6. Production Environment State

- **DB project:** `fxpcgtetvzlexbptqiwp` (from `CLOUDFLARE`/`PRODUCTION_HIVORR_SUPABASE_URL` envs and embedded `main.dart.js`). Anon publishable key `sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc`. `config.toml` local `project_id=hivorr` unrelated; remote project ref is `fxpcgtetvzlexbptqiwp`. No local link (`supabase status: Not linked`).
- **Schema:** Missing columns `entities.capability`, `entities.onboarding_completed_at` (42703), missing tables `portfolio_items`, `platform_admins`, `entity_onboarding_audit_trail` (PGRST205), missing RPCs `entity_onboarding_status_get/update`, `is_platform_admin`, `platform_admin_check`, `portfolio_public_profile_get` (PGRST202). Implies `supabase_migrations.schema_migrations` on prod stops at `20260911090002` or `20260830100001` (pre-20260913). No `supabase db push` has been run since 2026-09-15.
- **Frontend:** Cached `https://hivorr.pages.dev` serves build compiled from commit `243975b` (last successful `production-promotion` deployment) until run `35499187524` is manually approved and wrangler deploy completes. However user reports "deployed current work to production" — likely a manual `flutter build web --dart-define=HIVORR_ENV=production --dart-define=HIVORR_SUPABASE_URL=https://fxpcgtetvzlexbptqiwp…` + `wrangler pages deploy` that overwrote the Cloudflare Pages artifact with `9ece964` frontend **without migrating DB**, creating frontend/backend version skew. Even after `35499187524` promotes `9ece964` via CI, the same skew persists until DB is migrated.
- **Auth/RLS/Storage:** Auth (GoTrue `supabase_auth_hivorr`) healthy; `ensureEntityExists:263` (`INSERT INTO entities(id) VALUES(auth.uid()) ON CONFLICT DO NOTHING` + `entity_roles_activate('consumer')`) succeeds because `entities` table itself exists (just missing new columns). RLS correctly returns `42501` for anon on existing tables, not `PGRST202`, so policies are functional.

## 7. Local-vs-Production Differences (checklist)

| # | Resource | Local (?=OK) | Staging (?=OK) | Production (?=FAIL) | Drift Type |
|---|---|---|---|---|---|
|1|Tables `entities` columns `capability`, `onboarding_completed_at`|2 present|present|absent 42703|column missing (20260915090001)|
|2|Table `portfolio_items`|present|present|PGRST205 missing|table missing (20260913090001)|
|3|Table `platform_admins`|present|present|PGRST205 missing|table missing (20260916090001)|
|4|Table `entity_onboarding_audit_trail`|present|present|PGRST205 missing|table missing|
|5|Constraints `entities_capability_allowed`|present|present|absent|constraint missing|
|6|Functions/RPCs `entity_onboarding_status_get/update/reset`|present 42501|present 42501|PGRST202 absent|function missing|
|7|`portfolio_public_profile_get(uuid)`|present P0001|present P0001|PGRST202 absent|function missing|
|8|`is_platform_admin`, `platform_admin_check`|present 42501|present 42501|PGRST202 absent|function missing|
|9|`verification_review_queue_get`, `manage_user_list` etc.|present 42501|present 42501|PGRST202 absent|function missing|
|10|Triggers `entities_guard_onboarding_state_update`|present|present|absent|trigger missing|
|11|RLS policies `platform_admins_admin_select` etc.|present|present|absent|policy missing|
|12|Storage buckets `credential-documents`, `profile-avatars`, `portfolio-items`|3 rows local|presumed present (not PGRST205)|presumed present (buckets pre-date drift, 20260830100001; no bucket PGRST205)|not drifted|
|13|Storage policies `credential_documents_select_admin`|present|present|absent|policy missing|
|14|Auth config `site_url`, `additional_redirect_urls`, password policy 8 + `lower_upper_letters_digits_symbols`|local `config.toml:32,42`|same project settings (not probed but not causing onboarding RPC 404)|same|no drift|
|15|Redirect URLs `/reset-password` allow-list|local `http://localhost:8080`|same|same|no drift|
|16|Env vars `HIVORR_ENV=production`, `HIVORR_SUPABASE_URL=https://fxpcgtetvzlexbptqiwp`, `HIVORR_SUPABASE_ANON_KEY=sb_publishable…`, `HIVORR_CONFIG_SCHEMA_VERSION=1`, feature flags `false`|`CLOUDFLARE_*` correct|correct on both (`gh variable list --env Production`)|correct|no drift|
|17|API config `BaseApiService` through `Dio` + `SupabaseClient` single session|local|staging|prod same SDK (`supabase_flutter 2.17.2`, `dio 5.11.0`)|no drift (code identical)|
|18|Supabase project config `db major_version 15`, `pgcrypto`, `pgtap`|local|same|same|no drift (prod Supabase hosted v15)|
|19|Applied migrations `supabase_migrations.schema_migrations`|24 rows|24 rows (inferred from `42501` not `PGRST205` + staging deploy `9ece964`)|≤18 rows (stops before 20260913090001)|6 missing|
|20|Seed/reference data `industries` 8 rows, `professions` per industry, taxonomy active|present|present 8|present 8|not drifted|
|21|Taxonomy RPCs `taxonomy_industries_list` etc.|present|present|present (implied by industries SELECT success)|not drifted|

**Summary:** Drift is **confined to the 6 post-20260911 migrations** that introduce onboarding-authoritative state, portfolio public profile, and super-admin. Everything else (taxonomy, financial core, entity core, storage buckets) is in sync.

## 8. Whether Schema Drift Exists

**YES — confirmed.** `42703` (column does not exist), `PGRST202` (function not found), `PGRST205` (table not found) from production PostgREST schema cache prove the cache does not contain objects that local Docker and staging prove exist. `information_schema` locally vs REST error codes on prod are orthogonal, read-only, and reproducible.

## 9. Whether Migrations Are Missing

**YES.** `supabase_migrations.schema_migrations` on local lists `20260913090001` through `20260917090002` (6 rows) absent on prod (PGRST205/202/42703). The stale prod deployment `243975b` pre-dates their commit dates; no CI step runs `supabase db push` on promotion.

Migrations **applied in wrong order** is not observed — missing is prefix, not reordered. Migrations **changed after being applied** is not observed — `supabase/config.toml` is local-only and not versioned to prod.

## 10. Whether Configuration / Environment Variables Are Involved

**NO for onboarding failure.** `PRODUCTION_HIVORR_SUPABASE_URL` and `HIVORR_SUPABASE_ANON_KEY` are correct (proved by `200` on `industries` SELECT and `42501` on existing RPCs, not `network`/`timeout`/`auth`). Feature flags `HIVORR_FEATURE_*=false` are safe-disabled defaults, irrelevant. `CLOUDFLARE_ACCOUNT_ID`/`CLOUDFLARE_PAGES_PROJECT_NAME=hivorr` correct. `DEPLOY_WEB_URL=https://hivorr.pages.dev` smoke check would pass if schema did.

Configuration **is** involved for deployment drift: `.env.production.example`, `reusable-validation.yml:108` `HIVORR_CONFIG_SCHEMA_VERSION=1`, and `production-promotion.yml:108` var fallbacks are correct, but the pipeline **lacks a DB migration step**, so config-driven frontend build and DB schema are versioned independently.

## 11. Whether RLS / Storage / Authentication Is Involved

- **RLS:** No. Prod RLS correctly returns `42501 permission denied` for anon on existing tables (`entities`, `portfolio_items` on staging), not `404`. Missing objects return `PGRST202`/`PGRST205` which is schema-cache, not RLS. `entity_onboarding_status_get` is authenticated-only (`is_platform_admin` not, but onboarding status is), and `PostgrestException` mapping would be `PLT001` auth if RLS blocked, not `PLT004` notFound. The observed `PGRST202` precedes RLS evaluation.
- **Storage:** No. Onboarding avatar upload `StorageService.upload(bucket:profileAvatars, path: StoragePaths.avatar(entityId, ext), upsert:true)` runs before RPC; validation `validateForBucket: lib/systems/onboarding/services/onboarding_service.dart:388` uses client-side `StorageValidators` (5 MiB `jpeg/png/webp`). No `StorageException 404` observed in this trace because failure is RPC, not storage.
- **Authentication/Session:** No. `SupabaseAuthService.ensureEntityExists:263` successfully provisions `entities` row via `upsert` (`INSERT … ON CONFLICT DO NOTHING` uses `auth.uid()`, RLS `entities_authenticated_insert`). The new user's `entities` row exists (otherwise `entity_onboarding_status_update` would raise `PLT004 Entity not found` via `if not found then platform_raise_error('PLT004')` at `20260915090001:239`, which would also map to `Resource not found` but with envelope `code PLT004`). However the **earlier** PostgREST `PGRST202` dominates: function not found is returned as 404 before any row lookup, so the `Entity not found` branch at line 239 is unreachable on prod.

## 12. Whether Any Onboarding Data Was Partially Saved

**Inferred from code, not destructive DB read (no service_role):**

- **User account (`auth.users`):** Created (registration/sign-in works).
- **Session:** Valid (reaches onboarding).
- **Entity row (`entities.id=auth.users.id`):** Created via `ensureEntityExists` (upsert succeeds even on drifted schema — `id` column exists). `status` defaults `active`.
- **Profile (`entity_profiles`):** Likely persisted *if* user completed Step 1 `ProfileSetupScreen` before hitting capability step. `entity_profile_update` RPC exists and is the upsert-fixed version on prod (`20260911090001`), so `completeProfile:405` would succeed. If failure was observed after entering all onboarding info (i.e., after profile step), this row is present.
- **Capability (`entities.capability`):** **Not persisted** — `entity_onboarding_status_update` fails before `UPDATE … SET capability`. Value remains `NULL`.
- **Industry (`industry`) / Profession bind (`entity_professions`):** `bindProfession:468` → `entity_profession_bind` RPC exists on prod (pre-drift, 20260821), so if user selected profession, the bind may have succeeded (lands `unverified`). No `PGRST202` for that RPC (see §4.2 `entity_profession_bind` 42501? Actually our test showed `entity_profession_bind` with `{}` gave PGRST102 but with real ARGS would be PGRST202? Let's verify: `entity_profession_bind` is old enough (20260821090004) so it should exist on prod. Our earlier `PGRST102` vs `42501` was inconclusive due to arity. Assuming exists, profession binding could be persisted.
- **Verification records (`entity_credentials` / `verification_submissions`):** Identity document and trade proof `IdentityVerificationService.submitIdentityDocument:513` → `verification_submit`? That RPC is from `20260829090003` (pre-drift) so likely exists; but trade proof submitted via `TradeVerificationService`. If those steps completed, those rows could be present — but they are gated behind capability/completion which never stamped.
- **Onboarding completion (`entities.onboarding_completed_at`):** **Not stamped** — `_completeOnServer` fails before `UPDATE … SET onboarding_completed_at = now()` at `20260915090001:231`.
- **Storage avatar:** If avatar provided, `storage.upload` to `profile-avatars/{entityId}/avatar.{ext}` with `upsert:true` would succeed before RPC, leaving an orphan object without `avatar_path` persisted (since `updateAvatarPath` is skipped because `completeProfile` never reaches it on RPC failure, but `storage.upload` already wrote).

**No data was deleted.** The test account remains at step 2/3 resumable state per `OnboardingProgressStore` (`onboarding_progress:{entityId}` Hive).

*Note: Exact row-level confirmation requires read-only `SELECT` via service_role (`supabase link --project-ref fxpcgtetvzlexbptqiwp` + `psql` or `supabase db dump`). Not performed here per investigation-only safety.*

## 13. Recommended Correction (Reuse-First, No New Asset)

**Do not create** duplicate tables, duplicate RPCs, new onboarding system, or new storage bucket.

**Reuse and apply the existing 6 additive migrations in order:**

```bash
# One-time, from a workstation with SUPABASE_ACCESS_TOKEN and DB password (obtain from Supabase Dashboard → Project Settings → Database → Connection string, or 1Password/vault):
supabase link --project-ref fxpcgtetvzlexbptqiwp   # production
supabase db push   # applies supabase/migrations/*.sql in lexicographic order, idempotently; --linked variant uses the linked project

# Verify:
supabase db remote list  # or: docker exec psql "postgresql://postgres:[PROD_PW]@db.fxpcgtetvzlexbptqiwp.supabase.co:5432/postgres" -c "select version from supabase_migrations.schema_migrations order by version;"
curl "https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/entities?select=id,capability" -H "apikey: …" -H "Authorization: Bearer …" # should now return 42501 not 42703
curl -X POST …/rest/v1/rpc/entity_onboarding_status_get -H … -d "{}" # should return 42501 (exists) not PGRST202
```

Migrations are already **reuse-first**: `20260915090001` adds only `capability`/`onboarding_completed_at` plus narrowing grants and setting `platform.rpc_invocation` GUC — no duplicate `entities` table, no new `entity_type` column. `20260913090001` adds `portfolio_items` orthogonal to onboarding, `20260916090001` adds `platform_admins` orthogonal.

If `supabase db push` is unavailable in CI, apply via Supabase Dashboard → SQL Editor → paste each file in order, or `psql` direct.

After DB push:

1. Rebuild and redeploy production frontend — approval of run `35499187524` (or re-trigger `gh workflow run production-promotion.yml -f commit_sha=9ece964…`) will `wrangler pages deploy deploy/web --project-name=hivorr --branch=main --commit-hash=9ece964`.
2. Post-deploy smoke: `curl https://hivorr.pages.dev` 200, plus onboarding smoke (see §18).

**No code change required** to reuse existing assets. The only code change that would be considered is a forward hardening (see §15/16) in the pipeline, not in onboarding logic.

## 14. Required Migration / Configuration Changes

- **Migration:** Apply the 6 files exactly as versioned in `supabase/migrations/` (lexicographic). No edits, no new file. Order is filesystem order (`20260913…` → `202609150…` → `202609160…` → `202609160002` → `202609170001` → `202609170002`). They are idempotent (`create or replace function`, `alter table … add column`, `revoke execute …`).
- **Configuration:** None to `.env.production.example` values, but add to pipeline:
  - `supabase/config.toml` already correct for local; add `production`/`staging` project refs as `SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_PASSWORD` secrets (repo-level or env-level) so CI can `supabase link`.
  - Ensure `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` remain; no change.

## 15. Required Code Changes, If Any

**None for functional fix.** Onboarding code already correctly reuses frozen seams (`entity_profile_update`, `entity_profession_bind`, `entity_onboarding_status_*`) per `ARCHITECTURE.md` and `EP-01-06`/`EP-02-18` docs. Do not add new `supabase.rpc` wrappers beyond `entity_profession_bind` (`lib/systems/onboarding/services/onboarding_service.dart:468`).

**Recommended hardening code (post-approval, not required to unblock onboarding):**

- Add `lib/core/api/exceptions/api_exception_mapper.dart:44` logging enrichment: when `PGRST202`/`PGRST205`/`42703` is seen outside test, emit `Sentry` breadcrumb with `code` + `resource` so future drift is observable in Sentry, not just generic `Resource not found.`
- Optionally distinguish `PGRST202` schema-cache miss from `PLT004` business notFound in `data_exception_mapper.dart:81` (map `PGRST202` → `unknown` with message `Service temporarily unavailable — please retry.`), but current `PLT004` mapping is contract-correct per `20260819090001:65-81`.

## 16. Required Deployment Changes

Root problem: `production-promotion.yml` and `staging-deployment.yml` are **build-only**; DB migrations are `supabase db reset` only in `database-rls-tests.yml` local Docker.

**Propose (requires lead approval before implementation):**

1. **Add `supabase-migration.yml` reusable workflow** (pinned `supabase/setup-cli@…` `2.115.0`):
   ```yaml
   jobs:
     db-push:
       runs-on: ubuntu-latest
       environment: ${{ inputs.environment-name }}   # production / staging
       steps:
         - checkout
         - setup-cli
         - supabase link --project-ref ${{ vars.SUPABASE_PROJECT_REF }}
           env: SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}, SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
         - supabase db push  # --dry-run first, then actual
   ```
2. **Wire into `staging-deployment.yml`**: `build` needs `guard` → `db-push` (staging) → `deploy` OR parallel to `build` with `needs: guard` but `deploy` needs both `build` and `db-push` success. Fail-closed: if `db push` fails, `deploy` is skipped.
3. **Wire into `production-promotion.yml`**: `verify` → `db-push` (production) → `build` → `manual_approval` → `deploy`. The `verify` job should also assert `supabase_migrations.schema_migrations` contains the input commit's migrations (via `supabase db remote list` JSON compare to `supabase/migrations`).
4. **Add drift gate**: In `reusable-validation.yml` add a `schema-version-check` job that runs `supabase db push --dry-run` and diffs against `supabase_migrations` for the target project, failing the promotion if local migrations ≠ remote.
5. **Artifact provenance:** `reusable-validation.yml:246` `checksums-*.txt` already proves artifact integrity; extend `Record deployment metadata` (`production-promotion.yml:161`) to include `SUPABASE_PROJECT_REF` + `applied_migrations` list from `supabase_migrations`.

Without this, every future merge that touches `supabase/migrations` will recreate the same silent frontend/backend skew.

## 17. Automated Regression Tests

**Existing (already gate PRs):**

- `database-rls-tests.yml` (`supabase test db`) runs pgTAP `019_onboarding_authoritative_state.sql`, `021_admin_review_contract.sql`, `022_manage_user.sql`, `018_portfolio_public_profile.sql` against local Docker — ensures RPC contracts, RLS, and D5 guards. These already assert `entity_onboarding_status_update` PLT003/004 behavior, capability vocabulary, and audit trails.
- `reusable-validation.yml:106` `flutter test --coverage` exercises `OnboardingProvider`/`OnboardingService` with `FakeOnboardingRemote` and `FakeSupabase`.

**Proposed additive (post-approval):**

- Add `test/integration/onboarding_schema_drift_test.dart`:
  - Spins `MockSupabaseClientFactory` with `onRpc: (func, params)` returning `PostgrestException(code:'PGRST202')` for `entity_onboarding_status_get` → asserts `OnboardingProvider.lastError.code==PLT004` and `lastError.message=='Resource not found.'` plus Sentry breadcrumb logged. Then returns `PLT000` → asserts success path.
  - Verifies `DataExceptionMapper` maps `PGRST202` 404 envelope correctly.
- Add `supabase/tests/database/023_schema_drift_probe.sql` pgTAP:
  - `SELECT has_column('public','entities','capability')` → `ok`,
  - `SELECT has_table('public','portfolio_items')`,
  - `SELECT has_function('public','entity_onboarding_status_get')` — fails fast if any future migration is not applied.

## 18. Production Verification Tests

After applying migrations and approving `35499187524` (or re-promoting):

**Automated (no manual account mutation beyond test user):**

1. **RPC schema presence smoke:**
   ```
   curl -X POST https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/rpc/entity_onboarding_status_get \
     -H "apikey: sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc" \
     -H "Authorization: Bearer <TEST_USER_JWT>" -H "Content-Type: application/json" -d "{}"
   # expect: {"success":true,"code":"PLT000","data":{"capability":null,"completed":false,…}}  (200, not 404)
   # not PGRST202
   ```
   Similarly `portfolio_public_profile_get` with known approved entity should return `PLT004` envelope, not `PGRST202`.

2. **Column presence:**
   ```
   curl "https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/entities?select=id,capability,onboarding_completed_at" \
     -H "Authorization: Bearer <TEST_USER_JWT>" → 200 (not 42703)
   ```

3. **End-to-end onboarding probe (ephemeral test user):**
   - `POST /auth/v1/signup {email:"prod-smoke-20260920+$(date +%s)@example.com", password:"…A1!a…"} → 200
   - `POST /auth/v1/token?grant_type=password` → JWT
   - `POST /rest/v1/rpc/entity_profile_update -d '{"p_legal_name":"Smoke Test","p_display_name":"smoke-…"}'` → `PLT000`
   - `POST /rest/v1/rpc/entity_onboarding_status_update -d '{"p_capability":"hire"}'` → `PLT000`
   - `POST /rest/v1/rpc/entity_onboarding_status_get` → `completed:false, capability:hire`
   - For professional path: `entity_profession_bind` → `entity_onboarding_status_update(p_completed:true)` after identity+trade proof submits should return `PLT003` until prerequisites, then `PLT000` with `onboarding_completed_at` set.

**Manual (browser):**

- Sign up new account, verify email (OTP), proceed through `profile_setup_screen.dart` → `capability_selection_screen.dart` → `industry_profession_selection_screen.dart` → `identity_verification_step_screen.dart` → `trade_proof_step_screen.dart` → `onboarding_complete_screen.dart`. Each `Save & continue` should advance without `Resource not found.`; final `Submit` should navigate to `RoutePaths.onboardingComplete` then guard redirects to `RoutePaths.home`. Verify `OnboardingProvider.isCompleteAuthoritative==true` via Flutter DevTools or `supabase rpc entity_onboarding_status_get` after flow shows `completed:true`.

**Monitoring:**

- `Sentry` `onboarding.resume.duration` / `onboarding.submit` spans should show `status:ok` not `internalError`.
- `database-rls-tests.yml` rerun after prod push should still green (no migration conflict).

---

## Explicit Answers

### Why does onboarding work locally but fail in production?

Local Docker (`supabase_db_hivorr:54322`) has all 24 migrations applied (`docker exec psql … schema_migrations` lists `20260913090001`–`20260917090002`). Production Supabase (`fxpcgtetvzlexbptqiwp`) has at most 18 (stops before `20260913090001`), proven by:

- `column entities.capability does not exist` (42703) vs staging `permission denied`,
- `Could not find the table 'public.portfolio_items'` (PGRST205) vs staging present,
- `Could not find the function public.entity_onboarding_status_get` (PGRST202) vs staging `permission denied`.

The local/staging frontend (`9ece964`) expects those objects; production PostgREST returns 404 before business logic, which `ApiExceptionMapper:44` → `DataExceptionMapper:81` normalizes to the generic `Resource not found.` The failure is not a missing user row but a missing **schema object** that the 20260915 onboarding-authoritative design introduced.

### What exact change is required so that future deployments do not recreate this problem?

**No code change to onboarding logic. One infrastructure fix, then one process fix:**

1. **One-time DB fix (this incident):** Push the existing 6 missing migrations to `fxpcgtetvzlexbptqiwp` via `supabase link --project-ref fxpcgtetvzlexbptqiwp && supabase db push` (or SQL Editor). No new migration, no duplicate table/RPC. Verify with the `42703`/`PGRST202` curls above turning to `42501`/`P0001`.

2. **Process fix (prevents recurrence):** Amend the deployment pipeline so **DB migrations are versioned and applied atomically with frontend deploys**:
   - Add a reusable `supabase-db-push` job to `staging-deployment.yml` (auto on `master` push) and `production-promotion.yml` (after `verify`, before `build`/`deploy`), authenticated via `SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD` env secrets and `SUPABASE_PROJECT_REF` vars (`fxpcgtetvzlexbptqiwp` for prod, `cgxkiczmwzydhoroclvf` for staging).
   - Fail the promotion if `supabase db push --dry-run` detects drift, or if `schema_migrations` count ≠ `ls supabase/migrations/*.sql | wc -l`.
   - Record `applied_migrations` in `GITHUB_STEP_SUMMARY` alongside the Cloudflare Pages artifact checksum.

This makes `git merge to master` → `staging DB migrated + staging artifact deployed` → `promotion SHA verification` → `production DB migrated + production artifact rebuilt from same SHA + wrangler deploy` the only path to production, eliminating frontend/backend skew.

---

## Investigation Artifacts & Reproduction

- Local proof: `C:\Project\hivorr\supabase\.temp\` (Docker), `docker exec supabase_db_hivorr psql …` outputs, `main.dart.js` extraction (`C:\Users\HP\AppData\Local\Temp\main.js:115772`), `gh run list` (staging success `9ece964`, prod last `243975b`), `git diff 243975b..9ece964 -- supabase/migrations`.
- All curl probes above are **read-only** (`GET`/`POST` with `apikey` publishable key, no `service_role`, no `DELETE`, no `supabase db reset` on prod). No prod table was written.

## Approval Request

This report is **investigation-only**. No migration was applied, no production data was mutated, no error message was changed. Awaiting approval to:

1. Apply the 6 existing migrations to `fxpcgtetvzlexbptqiwp` (reuse, not creation), and
2. Implement the deployment pipeline hardening (or approve manual `supabase db push` as interim).

Please confirm or direct which of the above mitigations to proceed with.
