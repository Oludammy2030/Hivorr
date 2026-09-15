# Definition of Done — EP-02-19: Professional Profile & Credential Display System

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-19 | **Status:** Pending
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-19-Professional Profile & Credential Display System.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-19 |
| **Task Name** | Professional Profile & Credential Display System |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 7 — User-Facing Workflows |
| **Priority** | High |
| **Dependencies** | EP-02-10 (`entity_credentials` identity approval), EP-02-11 (`entity_professions.trade_verification_status` trade gate), EP-02-07 (`professions`/`industries` taxonomy + slugs), EP-02-06 (`portfolio-items` public storage bucket) |
| **Blocks** | EP-03 (marketplace discovery — profile RPC + `portfolio_items` model consumed) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-19-Professional Profile & Credential Display System.md` |

**Server surface (new — exactly one migration):** `supabase/migrations/20260913090001_portfolio_public_profile.sql` (additive, ordered after `20260911090002_demo_identity_seed.sql`; no pre-existing migration edited).

**Frozen server references (read-only, never modified):** `20260821090003_entity_model_rls_policies.sql:24-27` (anon zero grants on entity-model tables), `20260829090003_verification_admin_review_schema.sql:244-246,591-625,791-796` (verification schema default-deny + `verification_status_get` + EXECUTE grants), `20260821090002_entity_core_tables.sql:82-85,166-169` (legal_name Rule 3 anchor; document_path private), `20260830100001_storage_buckets.sql:176-204` (`portfolio-items` public read/owner write + `{entityId}` path gate).

---

## 2. Functional Verification

This task delivers the **Stage 7 trust-display output**: a public, SEO-friendly professional profile at `/p/:profession_slug/:entity_id` that renders entity display info, profession + industry badges, verification badges, approved credentials, KYC level indicator, and a portfolio grid. All public reads flow through exactly one anon-executable SECURITY DEFINER RPC (`portfolio_public_profile_get`) with a whitelisted column projection; anon never touches any trust table directly. Functional verification confirms the data layer, service, screen, widgets, SEO, routing, and the server RPC act correctly and never leak guarded columns.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `PortfolioItem` entity defines `item_type`, `title`, `description`, `media_path`, `sort_order` matching the `portfolio_items` table contract (no DTO leakage into entities)
- [ ] **FV-02:** `PublicCredential` exposes only public-safe fields (`kind`, `title`, `verificationStatus`) — never `document_path`, never internal review metadata
- [ ] **FV-03:** `PublicProfile` aggregates `entityId`, `displayName`, `avatarPath`, `bio`, `countryCode`, `professions`, `credentials`, `kycTierCode`, `kycStatus`, `portfolioItems`, `professionSlug`, `professionName`, `industrySlug`, `industryName` — pure Dart, no Flutter/Supabase imports

### 2.2 Required Functionality — Server RPC (`portfolio_public_profile_get`)

- [ ] **FV-04:** `portfolio_public_profile_get(p_entity_id uuid)` is `SECURITY DEFINER`, `STABLE`, `LANGUAGE plpgsql`, returns `jsonb` `{success, code, message, data}` envelope; execute granted to `anon, authenticated, service_role` only (no `public` grant)
- [ ] **FV-05:** Approved-gate enforced — entity must exist, `status = 'active'`, **and** have ≥1 `entity_professions` row with `trade_verification_status = 'approved'`; any failure returns the identical `PLT004` message (no existence/enumeration oracle)
- [ ] **FV-06:** Column whitelist authoritative — payload contains `display_name`, `avatar_path`, `bio`, `country_code` from `entity_profiles`; approved `entity_professions.profession_id`/`is_primary`; `professions`/`industries` slug + name; approved `entity_credentials.kind/title/verification_status`; `entity_kyc_levels`/`kyc_tiers` `tier_code`/`status` (no limits); `portfolio_items` showcase fields
- [ ] **FV-07:** Guarded columns structurally absent — `legal_name`, `document_path`, `verified_at`, `verified_by`, `reviewed_by`, `rejection_reason`, KYC limits never appear in the payload (pgTAP negative asserts enforce this)
- [ ] **FV-08:** `portfolio_items` table exists with audit columns (`created_at`, `updated_at`, `created_by`), `platform_set_updated_at` trigger, RLS enabled, `media_path` CHECK `media_path LIKE 'portfolio-items/' || entity_id::text || '/%'`, index `(entity_id, sort_order)`, realtime-excluded

### 2.3 Required Functionality — Data Layer

- [ ] **FV-09:** `lib/data/entities/*` — `PublicProfile`, `PublicProfession`, `PublicCredential`, `PortfolioItem` entities created (§5.4 plan)
- [ ] **FV-10:** `lib/data/models/*` DTOs mirror the RPC payload shape with `fromJson`; `lib/data/mappers/portfolio_mappers.dart` maps DTO → entity without leaking RPC JSON shape
- [ ] **FV-11:** `PortfolioEnvelopeParser` (`lib/data/datasources/portfolio_envelope_parser.dart`) validates `success == true && code == 'PLT000'` before mapping; maps `PLT003`/`PLT004`/`PLT999` to normalized `ApiException` kinds (mirrors `TaxonomyEnvelopeParser`); malformed envelope → `DataException`
- [ ] **FV-12:** `PortfolioRemoteDataSource` abstract + `SupabasePortfolioRemoteDataSource` — single method `fetchPublicProfile(String entityId)` via `supabase.rpc('portfolio_public_profile_get', params: {'p_entity_id': entityId})`
- [ ] **FV-13:** `PortfolioRepository` + `PortfolioRepositoryImpl` — `getPublicProfile(String entityId)` returning `PublicProfile?` (`null` on `PLT004`); `PortfolioProvider` (ChangeNotifier) holds `AsyncState`, `PublicProfile?`, `ApiException?` and `load(entityId)`

### 2.4 Required Functionality — Systems Facade & UI

- [ ] **FV-14:** `lib/systems/portfolio/services/professional_profile_service.dart` — thin orchestration consumed by the screen only (never imported by widgets); maps `PLT004` → not-found UI state; derives `verifiedIdentity`, `tradeVerified`, `primaryProfession`, `primaryIndustry`, `seoMeta`
- [ ] **FV-15:** `ProfessionalProfileScreen` (replaces placeholder at `app_router.dart:190-198`) reads `state.pathParameters['id']`, loads via service, renders header + badges + credentials + portfolio grid
- [ ] **FV-16:** 5 widgets exist under `lib/systems/portfolio/widgets/` — `ProfileHeaderCard` (`HivorrAvatar` from public `avatar_path`, display name — never legal name, bio, country chip), `VerificationBadgesRow` (identity / trade / credential-count), `CredentialCard` (title + kind chip + read-only approved state), `PortfolioItemCard` (public-URL media thumb + type + title + description), `PortfolioGrid` (responsive)
- [ ] **FV-17:** `seo/portfolio_seo_meta.dart` builds `title` (`displayName · professionName`), `description` (truncated bio), canonical URL from the RPC payload — never containing legal name

### 2.5 Required Functionality — Routing & DI

- [ ] **FV-18:** Placeholder replaced at `app_router.dart:190-198`; `RoutePaths.publicProfileRoute = '/p/:slug/:id'` (`route_paths.dart:91`) and `RouteNames.publicProfile` unchanged; **no diff** to `route_paths.dart` / `route_guard.dart`
- [ ] **FV-19:** Signed-out visitors open `/p/:slug/:id` (guard already public-bypasses via `route_guard.dart:168-169`); entity `id` is authoritative, `slug` cosmetic/canonical
- [ ] **FV-20:** Barrel `lib/systems/portfolio/portfolio.dart` re-exports all new symbols; `registerPortfolioLayer({required ApiLayer apiLayer, PortfolioRemoteDataSource? dataSource, HivorrLogger? logger})` returns `({dataSource, repository, provider, service})`; wired in `HivorrApp`/bootstrap MultiProvider; `lib/data/data_layer.dart` re-exports data-layer symbols

### 2.6 Expected Workflows

- [ ] **FV-21:** Signed-out visitor loads `GET /p/:slug/:id` → single RPC → full profile renders (header, badges, credentials, portfolio grid) without any auth prompt
- [ ] **FV-22:** Approved trade professional (entity active + ≥1 approved profession) → `PLT000` → profile visible; badges reflect identity/trade/KYC state from the payload
- [ ] **FV-23:** Unknown entity / inactive entity / active with zero approved professions → identical `PLT004` → branded not-found screen (no state leak, SEO-404 semantics)
- [ ] **FV-24:** Network failure on load → branded retry state; retry re-issues the single RPC; no partial/cached payload rendered
- [ ] **FV-25:** Portfolio grid reorders by `sort_order`; media rendered via public Storage URLs (no bytes over the profile path)

### 2.7 Success Conditions

- [ ] **FV-26:** `portfolio_public_profile_get` returns `{success:true, code:'PLT000', data:{...}}` containing only whitelisted fields for an eligible entity
- [ ] **FV-27:** Screen renders display name, avatar, profession + industry badges, verification badges, approved credentials, and portfolio grid; `legal_name` never present anywhere in client UI/logs
- [ ] **FV-28:** SEO meta emitted on web for the profile URL (title/description/canonical derived from payload)

### 2.8 Error Handling Scenarios

- [ ] **FV-29:** `PLT003` (null/malformed id) → validation state; `PLT004` (not found/not approved) → not-found screen; `PLT999`/network → retry state; raw `DioException`/SQL never reaches the UI (`ApiExceptionMapper` normalized)
- [ ] **FV-30:** RPC returns missing/`null` optional fields (`bio`, `countryCode`, `kyc`: null; empty `portfolioItems`) → rendered gracefully (placeholder/omitted), never crash
- [ ] **FV-31:** Malformed envelope / unexpected JSON shape → `DataException` surfaced via error state, never `FormatException` leak
- [ ] **FV-32:** `state.pathParameters['id']` empty/missing → screen guards to not-found/validation rather than issuing a `null` RPC param

### 2.9 Important User Interactions

- [ ] **FV-33:** Profile header + badge row communicate "verified professional" at a glance; all trust state sourced read-only from the RPC payload (no fabricated gate UI)
- [ ] **FV-34:** Responsive: 16dp mobile / 24dp web via `shared/layouts/`; branded states (`HivorrLoaded`/`HivorrLoading`/`HivorrError`) wrapping `HivorrLoader` pulse (`VISUAL-IDENTITY.md:148`) — never bare `CircularProgressIndicator`; ≥48dp touch targets; WCAG AA contrast
- [ ] **FV-35:** Not-found state is clean and informative without echoing raw entity ids or legal names

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Exactly one new migration `20260913090001_portfolio_public_profile.sql`; `git diff --stat -- supabase/migrations/` = exactly one new file; zero edits to any pre-existing migration
- [ ] **TV-02:** Files added ONLY under `supabase/migrations/20260913090001_portfolio_public_profile.sql`, `supabase/tests/database/018_portfolio_public_profile.sql`, `lib/data/` (entities/models/mappers/datasources/repositories/providers), `lib/systems/portfolio/`, `lib/app/router/app_router.dart` (route swap), `lib/data/data_layer.dart` (barrel), and `test/**` — no files in `lib/core/`, `lib/engine/`, `lib/integrations/`, `lib/workspace/`
- [ ] **TV-03:** Unidirectional `data → systems` — `lib/data/` never imports `lib/systems/` widgets; `ProfessionalProfileService` never imported by widgets; screen depends on `PortfolioProvider`/service only
- [ ] **TV-04:** No `.supabase/functions/*`, no Edge Functions, no bucket changes, no `lib/core/storage/*` modification (EP-02-06/08 surface reused read-only)

### 3.2 Required System Behavior

- [ ] **TV-05:** RPC is `SECURITY DEFINER` + `STABLE`; `revoke execute` posture preserved; grant issued to `anon, authenticated, service_role` only
- [ ] **TV-06:** `SET search_path` hygiene in the RPC; explicit column projections only (no `SELECT *` into the public response)
- [ ] **TV-07:** `portfolio_items.media_path` CHECK enforces the storage-path prefix parity with `20260830100001:181-186` (owner cannot reference another entity's folder)
- [ ] **TV-08:** `PortfolioProvider` holds one immutable `PublicProfile`; no per-frame allocations; derived view-models built once per load
- [ ] **TV-09:** Redacted logging via `HivorrLogger` + `PiiRedactor` — `entityId` suffix (`***last4`) only; never `displayName`, never bio, never avatar path in full, never payload body; `PerformanceTracer` span `portfolio.public_profile.load` sampled via `MonitoringConfig`

### 3.3 Module Integration

- [ ] **TV-10:** Data source reuses the registered `ApiLayer`/`SupabaseClientProvider` client path — no `Supabase.instance.client` leakage into `lib/systems/portfolio/`
- [ ] **TV-11:** `PortfolioEnvelopeParser` mirrors the `TaxonomyEnvelopeParser`/`FinancialEnvelopeParser` envelope pattern (`{success, code, message, data}`)
- [ ] **TV-12:** Reuses `HivorrAvatar`, `StorageBuckets.portfolioItems`, public-URL dispatch (`getPublicUrl`) — no duplicate storage/media logic
- [ ] **TV-13:** No conflict with `RouteGuard`/`RoutePaths`/`RouteNames` — constants and guard bypass already exist; only `app_router.dart:190-198` changes
- [ ] **TV-14:** `lib/systems/portfolio/` consumable downstream — EP-03 can reuse `PortfolioRepository`/RPC without further server migration

### 3.4 Technical Requirements from Plan

- [ ] **TV-15:** `flutter analyze` + `dart analyze` clean (0 issues)
- [ ] **TV-16:** `ProfessionalProfileService` dartdoc documents the RPC contract, `PLT004` not-found mapping, whitelist, and redaction policy
- [ ] **TV-17:** `portfolio_public_profile_get` comment documents the anon execute grant and never-expose columns (`legal_name`, `document_path`, review/limit fields)
- [ ] **TV-18:** `registerPortfolioLayer` DI wiring documented in `data_layer.dart` matches the frozen seam contracts

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `portfolio_items` table created in the single new migration with `entity_id` FK → `public.entities(id) on delete cascade`, `item_type` CHECK (jpeg/png/webp/pdf-aligned vocabulary), title/description length CHECKs, `media_path` prefix CHECK, audit columns, trigger
- [ ] **DV-02:** No data row is created by the task (no seed/test-data DML beyond pgTAP transaction-scoped fixtures); `portfolio_items` writes are owner self-CRUD via RLS

### 4.2 Data Updates

- [ ] **DV-03:** Client never writes any `public.*` trust table directly — public profile is read-only; owner CRUD on `portfolio_items` is the only new write surface, RLS-scoped to `auth.uid() = entity_id`
- [ ] **DV-04:** No existing table column altered; no `create or replace` collision with any prior migration

### 4.3 Data Relationships

- [ ] **DV-05:** Approved-gate uses the real FK relationship `entity_professions.entity_id → entities.id` with `trade_verification_status = 'approved'` filter (Rule 2: bidding gate only for approved professions)
- [ ] **DV-06:** `profession_id`/`industry_id` joins resolve slugs + names for the SEO route and badges; missing/lapsed join → omitted card, not crash
- [ ] **DV-07:** KYC indicator joins `entity_kyc_levels` → `kyc_tiers` for `tier_code`/`status` only — limits excluded by projection

### 4.4 Data Accuracy

- [ ] **DV-08:** Payload reflects server truth at call time (single `STABLE` RPC); no client-side verification assertions, no cached trust claims
- [ ] **DV-09:** `portfolio_items.sort_order` ordering exact; credential list includes approved-only rows

### 4.5 Data Integrity

- [ ] **DV-10:** Whitelist integrity proven by pgTAP negative asserts — `legal_name`, `document_path`, review/limit fields absent from payload; anon table read still raises
- [ ] **DV-11:** RLS + grants on `portfolio_items` verified — anon zero grants; authenticated self-CRUD present; no anon SELECT policy
- [ ] **DV-12:** Realtime exclusion verified — `portfolio_items` not present in `supabase_realtime`

---

## 5. Security Verification

- [ ] **SV-01:** Zero public table grants — anon/authenticated retain zero grants on all entity-model, verification-schema, and `portfolio_items` tables (`20260821090003:24-27`, `20260829090003:244-246`, new migration); public reads occur only inside the SECURITY DEFINER RPC
- [ ] **SV-02:** Column whitelist is structurally enforced — only whitelisted columns selected; `legal_name` (Rule 3 financial anchor) and `document_path` (private evidence) never in the projection
- [ ] **SV-03:** Approved-gate is non-oracle — identical `PLT004` for unknown / inactive / zero-approved entities; no endpoint distinguishes why a profile is hidden
- [ ] **SV-04:** RPC is read-only (`STABLE`, no write statements); anon write surface remains zero everywhere
- [ ] **SV-05:** SECURITY DEFINER hygiene — `SET search_path` scoping; explicit projections; no dynamic SQL; grants scoped to the new function; `public` revoke posture preserved
- [ ] **SV-06:** `media_path` CHECK blocks cross-entity path references (path-RLS parity with storage policy)
- [ ] **SV-07:** No `service_role` string in `lib/` (grep lens = 0); no `legal_name` reference in `lib/systems/portfolio/` or `lib/data/providers/portfolio_provider.dart` (grep lens = 0)
- [ ] **SV-08:** PII discipline — only display-level public data leaves the server; bio is user-authored public text; logs redact to `entityId` suffix; no payload logging
- [ ] **SV-09:** Slug is cosmetic only — entity id is authoritative; no redirect-chains, no oracle via slug validation

---

## 6. Performance Verification

- [ ] **PV-01:** Single RPC per page view returns the full profile graph (badges + credentials + KYC + portfolio) — no N+1 REST reads, no client joins
- [ ] **PV-02:** RPC declared `STABLE` (PostgREST-friendly); optional short TTL client cache permitted via repository (default off)
- [ ] **PV-03:** Media rendered via public Storage/CDN URLs — profile page never ships bytes
- [ ] **PV-04:** `PortfolioProvider` holds immutable single-payload state; no per-frame allocations; view-models derived once
- [ ] **PV-05:** `PerformanceTracer` span sampled via `MonitoringConfig`, no PII tags; no polling, no timers, no realtime subscription introduced
- [ ] **PV-06:** Portfolio payload bounded by owner-managed row count + `sort_order` (no pagination required in EP-02-19 scope)

---

## 7. Testing Verification

### 7.1 Automated Server Suite — `supabase/tests/database/018_portfolio_public_profile.sql`

Aligned to the `001-017` suite style (`begin; set search_path to extensions, public, storage; select plan(N); ... finish(); rollback;`).

- [ ] **TT-01:** `portfolio_items` schema asserts — table exists, RLS enabled, PK, audit columns, trigger, indexes, CHECKs (item_type, title/description lengths, `media_path` prefix)
- [ ] **TT-02:** Grant/RLS asserts — anon zero grants on `portfolio_items`; authenticated self-CRUD policies present; no anon SELECT policy; realtime-excluded
- [ ] **TT-03:** Function identity asserts — `portfolio_public_profile_get` exists, `security definer`, `stable`, execute granted to `anon, authenticated, service_role` only, no `public` grant
- [ ] **TT-04:** Behavior asserts — `PLT003` null id; `PLT004` unknown / inactive / zero-approved (identical message); `PLT000` for eligible entity with whitelisted fields present
- [ ] **TT-05:** Whitelist negative asserts — `legal_name`, `document_path`, `reviewed_by`, `rejection_reason`, KYC limits absent from payload; anon `SELECT` on `entity_profiles`/`entity_credentials`/`portfolio_items` still raises
- [ ] **TT-06:** `supabase db test` — `001-018` all green (new test must not break `014`/`015` publics-revoke assumptions; grants scoped to the new function only)

### 7.2 Automated Client Suite

- [ ] **TT-07:** Unit — data ≥18: `portfolio_envelope_parser_test.dart` (success / `PLT003` / `PLT004` / malformed), mapper DTO↔entity round-trip, repo delegation + `null` on `PLT004`, data source RPC params `('portfolio_public_profile_get', {'p_entity_id': ...})`
- [ ] **TT-08:** Unit — systems ≥10: `professional_profile_service_test.dart` — `verifiedIdentity`/`tradeVerified` derivation, `PLT004` → not-found mapping, `seoMeta` builder (title/description/canonical), redacted log assertions (no displayName in output)
- [ ] **TT-09:** Widget ≥20: `professional_profile_screen_test.dart` + widget tests — header/badges/credential/grid rendering; theme token compliance (`grep Colors./Color(0xFF/fontFamily:` = 0); empty/error/not-found state renders; responsive breakpoint render
- [ ] **TT-10:** Integration 3 flows — `test/integration/portfolio_profile_integration_test.dart` with fake data source: (1) real route `/p/slug/id` → screen loads → badges + grid render; (2) `PLT004` → not-found state; (3) network failure → retry → success
- [ ] **TT-11:** `flutter analyze` + `dart analyze` clean; full `flutter test` green; unit ≥28 + widget ≥20 onboarding-equivalent assertions for portfolio

### 7.3 Edge Cases

- [ ] **TT-12:** Null/empty optional fields (`bio`, `countryCode`, kyc, credentials list, portfolio list) rendered gracefully
- [ ] **TT-13:** `state.pathParameters['id']` empty → guard, no null RPC param; slug/entity mismatch → renders with canonical slug (no redirect loop)
- [ ] **TT-14:** Entity with approved profession but missing `entity_profiles` row → `PLT004` (no partial payload)
- [ ] **TT-15:** RPC envelope with `success:false` non-`PLT004` codes (`PLT999`) → normalized error state with retry

### 7.4 Failure Scenarios

- [ ] **TT-16:** RPC network timeout → `ApiExceptionKind.timeout` → branded retry; retry re-issues once per tap (no auto-fire-hammer)
- [ ] **TT-17:** `401` unauthenticated (signed-out visitor with stale session) → still serves public profile (public bypass) or fails gracefully to retry — never a login redirect for an SEO public URL
- [ ] **TT-18:** Malformed/truncated JSON payload → `DataException` surfaced in error state; no crash, no partial render

### 7.5 Manual Testing (dev env)

- [ ] **TT-19:** Manual spot-check — open `/p/:slug/:id` signed-out for an approved professional (dev seed) → full profile renders; verify not-found for inactive/unknown; verify SEO meta via web head inspector; responsive check mobile + web

---

## 8. User Acceptance Verification

This task delivers the **trust-visible output** of the entire verification system — the credibility signal clients see before hiring, and the foundation for EP-03 discovery. User acceptance verifies trust comprehension, privacy, SEO, and responsiveness.

- [ ] **UA-01:** The project lead can open a professional's public URL signed-out and immediately understand: who they are (display name/avatar/bio/country), what professions they hold (badges), their verification status (identity/trade/KYC), approved credentials, and their work samples — all without signing in
- [ ] **UA-02:** The page never shows `legal_name`, document paths, internal review metadata, or KYC limits — verified by reading the payload shape and rendered UI
- [ ] **UA-03:** Only trade-approved professionals are discoverable publicly; unknown/inactive/not-approved URLs show a clean not-found state (never a hint of why)
- [ ] **UA-04:** SEO meta (title = `displayName · professionName`, description, canonical) is emitted on web for the profile URL; slug is canonical and readable (`/p/electrician/<id>`)
- [ ] **UA-05:** Responsive polish — mobile single-column → web multi-column portfolio grid via `shared/layouts/`; branded states + `HivorrLoader` pulse; WCAG AA contrast; no hardcoded colors/fonts (`VISUAL-IDENTITY.md`)
- [ ] **UA-06:** No financial data on the page — no balances, escrow, or payout references; the profile is display-only trust content
- [ ] **UA-07:** Downstream unblocked — EP-03 can consume `PortfolioRepository`/`portfolio_public_profile_get`/`portfolio_items` without further server migration

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-19 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Exactly one new migration `20260913090001_portfolio_public_profile.sql`; `git diff --stat -- supabase/migrations/` = one new file; zero pre-existing migration edits | `git diff --stat` | ☐ |
| 2 | `portfolio_items` table: RLS enabled, audit columns + trigger, `media_path` CHECK prefix, `(entity_id, sort_order)` index, realtime-excluded | File inspection + pgTAP | ☐ |
| 3 | Default-deny preserved — anon zero grants on `portfolio_items`; authenticated owner self-CRUD via RLS; no anon SELECT policy | pgTAP + code review | ☐ |
| 4 | `portfolio_public_profile_get(uuid)` SECURITY DEFINER + STABLE; execute granted to `anon, authenticated, service_role` only; no `public` grant | pgTAP | ☐ |
| 5 | Approved-gate non-oracle — identical `PLT004` for unknown/inactive/zero-approved; pgTAP behavior asserts | pgTAP | ☐ |
| 6 | Column whitelist structural — `legal_name`, `document_path`, review/limit fields absent from payload (pgTAP negative asserts) | pgTAP | ☐ |
| 7 | Entities + DTOs + mappers + `PortfolioEnvelopeParser` + data source + repository + `PortfolioProvider` in `lib/data/`; unidirectional `data → systems` | File inspection + unit tests | ☐ |
| 8 | `lib/systems/portfolio/` activated — service, screen, 5 widgets, `seo/portfolio_seo_meta.dart`, barrel, `registerPortfolioLayer` | File inspection | ☐ |
| 9 | `app_router.dart:190-198` placeholder replaced; `route_paths.dart`/`route_guard.dart` unchanged (`git diff` clean for both) | `git diff` | ☐ |
| 10 | Signed-out `/p/:slug/:id` opens (guard bypass verified in integration test); display name only — never legal name | Integration test + code review | ☐ |
| 11 | Theme tokens only — `grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/portfolio/` = 0; branded states + `HivorrLoader` | `grep` + widget test | ☐ |
| 12 | No `service_role` in `lib/`; no `legal_name` in `lib/systems/portfolio/` or `lib/data/providers/portfolio_provider.dart` | `grep` lenses | ☐ |
| 13 | Client unit ≥28 + widget ≥20 + 3 integration flows green; `flutter analyze` 0 issues; full `flutter test` green | `flutter test` | ☐ |
| 14 | `supabase db test` — `001-018` green | `supabase db test` | ☐ |
| 15 | SEO meta emitted on web (title/description/canonical from payload, no legal name) | Code review + manual | ☐ |
| 16 | Redacted logging + `PerformanceTracer` span `portfolio.public_profile.load`; no PII in logs | Code review | ☐ |
| 17 | DoD-1..17 of the approved plan satisfied as specified in `EP-02-19-Professional Profile & Credential Display System.md` §15 | Cross-check vs plan | ☐ |

---

> **Sign-off:** Task EP-02-19 marked **Completed** — all 17 conditions in the Final Approval Checklist verified and signed off by the project lead.

---

**Post-Implementation Audit Commands (run by project lead)**

```
[ ] flutter analyze                            -> 0 issues
[ ] flutter test                               -> all green (portfolio unit ≥28 + widget ≥20 + 3 integration flows)
[ ] supabase db test                           -> 001-018 green
[ ] git diff --stat -- supabase/migrations/    -> exactly one new file (20260913090001_portfolio_public_profile.sql)
[ ] grep -rn "service_role" lib/                                    -> 0
[ ] grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/portfolio/ -> 0
[ ] git diff -- lib/app/router/route_paths.dart lib/app/router/route_guard.dart -> 0 (no change)
[ ] Signed-out /p/:slug/:id opens; PLT004 not-found for guarded entities; SEO meta present
```