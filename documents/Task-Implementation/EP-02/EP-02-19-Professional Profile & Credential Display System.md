# Task Implementation Plan — EP-02-19: Professional Profile & Credential Display System

**Task ID:** EP-02-19 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Approved | **Priority:** High | **Dependencies:** EP-02-10 (identity verification), EP-02-11 (trade verification), EP-02-07 (taxonomy), EP-02-06 (storage) | **Stage:** 7 — User-Facing Workflows

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:445-454` | Architecture: `documents/Context/ARCHITECTURE.md:95-110,147-150` (`lib/systems/portfolio/`, SEO URL `/p/:profession_slug/:entity_id`) | Guardrails: `documents/Context/AGENT.md` (Rule 2 trade gate, Rule 4 server-side logic, Rule 5 design tokens) | Storage: `lib/core/storage/storage_config.dart`, `storage_paths.dart`, `supabase/migrations/20260830100001_storage_buckets.sql` | Seams: `20260821090003_entity_model_rls_policies.sql`, `20260829090003_verification_admin_review_schema.sql`, `20260821090002_entity_core_tables.sql` | Precedent: EP-02-18 TIP (fake-stack testing, frozen server references)

---

## 1. Objective

Build the **professional profile & credential display system** in a new `lib/systems/portfolio/` system — the trust-visible output of the entire EP-02 verification stack, and the foundation for EP-03 marketplace discovery. Per `EP-02:445-454`, the system delivers a **public-facing professional profile page** showing:

1. **Entity display info** — display name, avatar, bio, country.
2. **Profession + industry badges** — from the EP-02-07 two-tier registry, bound via `entity_professions`.
3. **Verification status badges** — identity verified (`entity_credentials` kind `identity_document` approved + KYC level) and trade approved (`entity_professions.trade_verification_status = 'approved'`, AGENT.md Rule 2).
4. **Credential display** — approved credentials referenced by the whitelisted public RPC.
5. **Portfolio showcase** — work samples/project descriptions from the new `portfolio_items` table, rendered as a responsive grid.
6. **Trust signals** — KYC level indicator, verification status, per-profession trade gate.

The profile is **SEO-friendly** (public URL `/p/:profession_slug/:entity_id` per `ARCHITECTURE.md:150`) and **responsive** across mobile and web.

Deliverables:

- **Server (exactly one migration):** `supabase/migrations/20260913090001_portfolio_public_profile.sql` — the `portfolio_items` table (RLS default-deny, owner self-CRUD, `media_path` CHECK `portfolio-items/{entityId}/%`, realtime-excluded) + one anon-executable SECURITY DEFINER RPC `portfolio_public_profile_get(p_entity_id uuid)` returning the `{success, code, message, data}` PLT envelope with **whitelisted columns only** (never `legal_name`, never `document_path`).
- **Data layer:** `PublicProfile` / `PublicProfession` / `PublicCredential` / `PortfolioItem` DTOs + entities, mappers, `PortfolioEnvelopeParser`, `PortfolioRemoteDataSource` + Supabase impl, `PortfolioRepository` + impl, `PortfolioProvider` in `lib/data/`.
- **System layer:** `ProfessionalProfileService`, screens, widgets, `seo/portfolio_seo_meta.dart`, barrel `lib/systems/portfolio/portfolio.dart`, `registerPortfolioLayer` DI factory in `lib/systems/portfolio/`.
- **Routing:** replace the `publicProfile` placeholder at `app_router.dart:190-198`; no `RouteGuard` change (`route_guard.dart:168-169` already public-bypasses `/p/`).
- **Tests:** pgTAP `supabase/tests/database/018_portfolio_public_profile.sql` (aligned to the existing `001-017` suite) + fake-stack Flutter unit/widget/integration tests (EP-02-18 precedent).

## 2. Business Problem Being Solved

`EP-02:449-450` assigns EP-02-19 as the **trust-visible output** of the entire verification system. The professional profile signals credibility to potential clients and is the **foundation for EP-03 marketplace discovery**. Today this output does not exist:

- Every verification step (identity approval, trade approval, KYC tier) produces server-visible trust state, but there is **no public surface** that renders it. A client cannot discover or evaluate a professional before EP-03.
- `route_paths.dart:91` and `app_router.dart:190-198` already define the SEO route `/p/:slug/:id`, but it renders a **placeholder** — the actual profile system is unimplemented.
- **`legal_name` is the Rule 3 financial anchor** (`entity_profiles.legal_name`, `20260821090002_entity_core_tables.sql:82-85`). It must never be exposed to anonymous readers — the public RPC must whitelist display columns only.
- `document_path` is a private verification-evidence reference (`20260821090002_entity_core_tables.sql:166-169`) — it must never be exposed to anonymous readers either.
- EP-02-03/10/11 created identity, trade, and KYC verification state under **default-deny RLS** — `anon`/`authenticated` have zero table grants on all nine entity-model tables (`20260821090003_entity_model_rls_policies.sql:24-27`) and zero grants on the verification schema tables (`20260829090003_verification_admin_review_schema.sql:244-246`). A public reader **cannot** read any entity/profile/credential/profession row directly — a dedicated anon-executable server RPC is the only compliant read path.
- There is **no portfolio data model** anywhere in the schema (`lib/systems/portfolio/` contains only `.gitkeep`; no `portfolio_items` table exists in any migration).

**This task is the Stage 7 trust-display seam** that turns verified state into a discoverable, SEO-friendly public artifact while preserving AGENT.md Rule 4 (database-first logic, zero-trust client): every public read goes through the whitelisting SECURITY DEFINER RPC; anon never touches the underlying tables.

## 3. Scope

| In Scope | Detail |
|---|---|
| `portfolio_items` table (server) | New table in `20260913090001_portfolio_public_profile.sql`: `id uuid pk default gen_random_uuid()`, `entity_id uuid not null references public.entities(id) on delete cascade`, `item_type text`, `title text`, `description text`, `media_path text`, `sort_order int`, audit columns (`created_at`, `updated_at`, `created_by`), `platform_set_updated_at` trigger, CHECK constraints (title/bio lengths mirror profile conventions), **`media_path` CHECK `media_path LIKE 'portfolio-items/' || entity_id::text || '/%'`** (path-RLS parity with `20260830100001_storage_buckets.sql:181-186`), index `(entity_id, sort_order)` |
| `portfolio_items` RLS | `alter table ... enable row level security`; owner `insert`/`update`/`delete` via `auth.uid() = entity_id` policies + `is_owner_or_admin`-style USING/WITH CHECK where applicable; **default-deny** anon; **no public select** (public reads only via the RPC); realtime-excluded via the `do $$` guard |
| `portfolio_items` grants | `revoke all ... from anon, authenticated` belt-and-suspenders; `grant select, insert, update, delete on + `grant update` (owner-scoped) / self-CRUD to `authenticated` matching the `entity_professions` non-gate pattern (`20260829090003_verification_admin_review_schema.sql:257-262`); anon gets **nothing**; `service_role` full |
| `portfolio_public_profile_get(p_entity_id uuid)` RPC | Anon-executable **SECURITY DEFINER** RPC returning the `{success, code, message, data}` PLT envelope. **Approved-gate:** entity `status = 'active'` AND ≥1 `entity_professions` row with `trade_verification_status = 'approved'`, else `PLT004`. **Whitelisted columns only:** profile `display_name`, `avatar_path`, `bio`, `country_code` (never `legal_name`); profession `id`, `profession_id`, `is_primary`, `trade_verification_status` (approved cards only per gate); credentials with `verification_status = 'approved'` projected to **public-safe fields** (`kind`, `title`, `issued/expiry` derived, never `document_path`); KYC tier code/status via `entity_kyc_levels` join to `kyc_tiers` read; portfolio items (`id`, `item_type`, `title`, `description`, `media_path`, `sort_order`); `profession_slug`/`industry_slug`/`industry_name` for the SEO route and badges. `PLT001`/`PLT003` validation, `PLT004` unknown/inactive/not-approved |
| RPC grants | `revoke execute ... from public` + `grant execute on function public.portfolio_public_profile_get(uuid) to anon, authenticated, service_role` |
| `lib/data` additions | `PublicProfile`, `PublicProfession`, `PublicCredential`, `PortfolioItem` DTOs + entities; mappers (`PortfolioMappers`); `PortfolioEnvelopeParser` (mirrors `TaxonomyEnvelopeParser`); `PortfolioRemoteDataSource` abstract + `SupabasePortfolioRemoteDataSource`; `PortfolioRepository` + `PortfolioRepositoryImpl`; `PortfolioProvider` (ChangeNotifier) |
| `lib/systems/portfolio/` | `ProfessionalProfileService` facade, `ProfessionalProfileScreen`, widgets (`ProfileHeaderCard`, `VerificationBadgesRow`, `CredentialCard`, `PortfolioItemCard`, `PortfolioGrid`), `seo/portfolio_seo_meta.dart` (SEO meta builders), `portfolio.dart` barrel, `registerPortfolioLayer(...)` DI factory |
| Routing | Replace placeholder at `app_router.dart:190-198` with `ProfessionalProfileScreen` bound to `state.pathParameters['slug']` / `['id']`; **no** `RouteGuard` change (`route_guard.dart:168-169` `_isPublicContentView` already allows `/p/` while signed-out); no `route_paths.dart` change needed (constants already exist at `route_paths.dart:91,98-102`) |
| SEO | `portfolio_seo_meta.dart` emits `title`/`description`/`og:*`/canonical from the RPC payload (display name + profession slug + industry name — never legal name); consumed by the web head/meta layer per `ARCHITECTURE.md:147-150` |
| Tests | pgTAP `018_portfolio_public_profile.sql`; fake-stack Flutter unit/widget/integration (EP-02-18 precedent: fake `SupabaseClient`-derived `PortfolioRemoteDataSource`, fake repository) |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| Modifying any frozen EP-01/EP-02 server surface | All existing migrations (`20260821090001`..`20260830100001`, `20260911*`) remain byte-for-byte unchanged — the new migration is additive, ordered after `20260911090002_demo_identity_seed.sql` |
| Direct anon/authenticated table SELECT on entity/profile/credential/portfolio tables | Default-deny posture preserved (`20260821090003:24-27`, `20260829090003:244-246`); the RPC is the only public read path |
| Exposing `legal_name` or `document_path` to any public reader | Rule 3 financial anchor + private evidence; whitelist excludes both, enforced structurally by the RPC projection |
| Any new write surface for anonymous users | Public route is read-only; portfolio self-CRUD is owner-scoped on `portfolio_items` only |
| Profile editing / item management UI | EP-02-19 is *display*; portfolio item CRUD UI + multi-profession management are profile-workspace features (EP-02-18 relied on; future task). This task ships the `portfolio_items` write grants/RPC-projection so the data model is ready |
| Edge Functions, buckets, bucket policy changes | Portfolio upload path/validators already exist (EP-02-06 `portfolio-items` public bucket, 10 MiB, jpeg/png/webp/pdf — `storage_config.dart:42-43,73-79,100-101`); no serverless code |
| Verification/credential submission flows | EP-02-10/11 completed; this task *reads* approved outcome via the RPC |
| KYC tier changes, financial limits display | EP-02-12 — public profile renders the KYC *level indicator* read-only, no limits/balances |
| Public store route `/store/:storeId` | Separate EP-02 roadmap item; placeholder stays |
| Non-approved trade professions on the public page | Approved-gate (`trade_verification_status = 'approved'`) means only approved professions render as trade-verified profiles — aligns AGENT.md Rule 2 |
| Any hardcoded business logic in UI | All public vocabulary/verification classification flows from the RPC payload via `ProfessionalProfileService` |
| Creating files outside `supabase/migrations/`, `supabase/tests/database/`, `lib/`, `test/`, `documents/Task-Implementation/EP-02/` | Scope boundary |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/portfolio/` vs `lib/data/`

`ARCHITECTURE.md:95-110,131-138` assigns `lib/data/` = DTO/entity/repository/provider and `lib/systems/<name>/` = business systems. Rules:

- **Data layer** (`lib/data/`) owns the public-profile/portfolio DTOs, entities, mappers, envelope parser, remote data source, repository, and `PortfolioProvider` — reusable by any consumer (this profile now; EP-03 marketplace later).
- **Systems layer** (`lib/systems/portfolio/`) owns the display orchestration (`ProfessionalProfileService`), the screen, widgets, SEO meta, barrel, and the `registerPortfolioLayer` DI factory. It *composes* the repository — it does **not** re-implement transport or re-parse envelopes (the parser lives in data).
- **Unidirectional** `data → systems`: `PortfolioProvider` depends on the repository (data); `ProfessionalProfileService`/screen depend on `PortfolioProvider`; widgets depend on the screen/service — no `lib/systems/` imports inside `lib/data/`.

No new top-level `lib/` directory. `lib/systems/portfolio/` already exists (`.gitkeep`, `ARCHITECTURE.md:108`) — it is activated as a barrel alongside `verification/`, `finance/`, `support/`.

### 5.2 Server-Side Contract (New, Single Migration, Read-Only Everything Else)

`EP-02:147` lists EP-02-19 dependencies as EP-02-10/11/06 (plus taxonomy EP-02-07 for slugs/badges). Because **anon has zero grants on every trust table** (`20260821090003:24-27`, `20260829090003:244-246`), a public profile **cannot** be served by REST/PostgREST on any entity-model table. The approved approach is exactly **one** additive migration:

**Migration `20260913090001_portfolio_public_profile.sql`:**
1. `portfolio_items` table + RLS + grants + realtime exclusion (owner self-CRUD only; anon nothing).
2. `portfolio_public_profile_get(p_entity_id uuid)` — `SECURITY DEFINER`, `STABLE`, `LANGUAGE plpgsql`, returns `jsonb` envelope `{success, code, message, data}`.
3. `revoke execute on all functions in schema public from public` is **NOT** re-run (would churn frozen posture); the migration grants execute on the new function to `anon, authenticated, service_role` only, and the existing `20260829090003:789` revocation already covers new functions by default (functions created after a public-revoke inherit no public grant — an explicit grant to anon is required and provided).

### 5.3 Server RPC — `portfolio_public_profile_get`

```sql
create or replace function public.portfolio_public_profile_get(
  p_entity_id uuid
)
returns jsonb
language plpgsql
security definer
stable
as $$
declare
  v_entity public.entities;
  v_profile public.entity_profiles;
  v_approved_count int;
  v_kyc jsonb;
  v_data jsonb;
begin
  -- Validation
  if p_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Entity id is required.');
  end if;

  -- Entity must exist and be active
  select * into v_entity from public.entities where id = p_entity_id;
  if not found or v_entity.status <> 'active' then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- Approved-gate: at least one approved trade profession (AGENT.md Rule 2)
  select count(*) into v_approved_count
    from public.entity_professions ep
   where ep.entity_id = p_entity_id
     and ep.trade_verification_status = 'approved';
  if v_approved_count = 0 then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- Profile (whitelisted columns only — never legal_name, never document_path)
  select * into v_profile from public.entity_profiles where entity_id = p_entity_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- KYC level indicator (read-only tier code + status)
  select jsonb_build_object(
           'tier_code', kt.tier_code,
           'status', ekl.status
         ) into v_kyc
    from public.entity_kyc_levels ekl
    left join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = p_entity_id;

  -- Assembly: entity + profile(whitelist) + approved professions(+profession slug + industry slug/name)
  --           + approved credentials(public-safe projection) + kyc + portfolio_items + seo_seo_slugs
  select jsonb_build_object(...) into v_data;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Professional profile retrieved.',
    'data', v_data
  );
end;
$$;
```

**Column whitelist (authoritative):**

| Source | Exposed to anon | Never exposed |
|---|---|---|
| `entities` | `id`, `status` (implied active by gate) | — |
| `entity_profiles` | `display_name`, `avatar_path`, `bio`, `country_code` | `legal_name` |
| `entity_professions` | `id`, `profession_id`, `is_primary` (approved rows only; `trade_verification_status = 'approved'` implied) | `verified_at`, `verified_by` (internal review metadata) |
| `professions` / `industries` | `slug` (profession), `name` (profession + industry), `industry.slug`, `industry.name` | `sort_order` internal ordering only when not needed |
| `entity_credentials` | `kind`, `title`, `verification_status` (approved only) | `document_path`, `id` (evidence pointer), `reviewed_by`, `rejection_reason` |
| `entity_kyc_levels` / `kyc_tiers` | `tier_code`, `status` | limits (`daily/weekly/monthly/cashout`), `id` |
| `portfolio_items` | `id`, `item_type`, `title`, `description`, `media_path`, `sort_order` | `created_by` only when redundant; `entity_id` implied |

**Error contract:** `PLT003` null/malformed id; `PLT004` unknown/inactive/not-approved entity (identical message — do not leak *why*); success envelope `PLT000`. SECURITY DEFINER executes as the migration owner, so RLS is bypassed *inside* the function while anon still holds **no** table grants outside it; the whitelist is enforced by explicit `SELECT` of listed columns only.

### 5.4 Data Layer Contract

```dart
// lib/data/entities/public_profile.dart
class PublicProfile {
  final String entityId;
  final String displayName;
  final String? avatarPath;
  final String? bio;
  final String? countryCode;
  final List<PublicProfession> professions;
  final List<PublicCredential> credentials;
  final String? kycTierCode;
  final String? kycStatus;
  final List<PortfolioItem> portfolioItems;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;
}
```

DTOs mirror the entity shape (`lib/data/models/`) with JSON `fromJson`; mappers (`lib/data/mappers/portfolio_mappers.dart`) convert DTO → entity; `PortfolioEnvelopeParser` (`lib/data/datasources/portfolio_envelope_parser.dart`) unwraps `{success, code, message, data}` and throws normalized `ApiException` (`PLT000`→success, `PLT003`→validation, `PLT004`→not-found, `PLT999`→internal) mirroring `TaxonomyEnvelopeParser` conventions.

```dart
// lib/data/datasources/portfolio_remote_data_source.dart
abstract class PortfolioRemoteDataSource {
  Future<PortfolioEnvelope> fetchPublicProfile(String entityId);
}

class SupabasePortfolioRemoteDataSource implements PortfolioRemoteDataSource {
  // rpc('portfolio_public_profile_get', params: {'p_entity_id': entityId})
}
```

`PortfolioRepository` (+ `PortfolioRepositoryImpl`) exposes `Future<PublicProfile?> getPublicProfile(String entityId)`; `PortfolioProvider` (`NotifierProvider`/`ChangeNotifier` mirroring `TaxonomyProvider`) holds `AsyncState`, `PublicProfile?`, `ApiException?` and a `load(entityId)` that throws normalized exceptions for the screen to map (404 → `ProfileNotFoundScreen`).

### 5.5 Systems Facade — `ProfessionalProfileService`

Thin orchestration consumed by the screen only — never imported by widgets:
- `load(String entityId)` → delegates to `PortfolioProvider.load`; maps `PLT004` to a not-found UI state (SEO-friendly `404` semantics — same URL, no legal-name leak).
- Exposes derived view-model fields: `verifiedIdentity` (any approved identity credential or KYC tier ≥ base), `tradeVerified` (any approved profession — always true given the gate), `primaryProfession`, `primaryIndustry`, `seoMeta` (from `portfolio_seo_meta.dart`).
- Adds `HivorrLogger` + `PiiRedactor` redacted logs (`entityId suffix` only) + `PerformanceTracer` span `portfolio.public_profile.load`.

### 5.6 UI — `lib/systems/portfolio/screens/` + `widgets/`

| Screen/Widget | Purpose | Key Elements |
|---|---|---|
| `ProfessionalProfileScreen` | Public profile page (route `/p/:slug/:id`) | Reads `state.pathParameters['id']` → `ProfessionalProfileService.load`; renders `ProfileHeaderCard`, `VerificationBadgesRow`, `CredentialCard` list, `PortfolioGrid`, `HivorrErrorState` (retry), `ProfileNotFoundState` on `PLT004`; responsive via `shared/layouts/` |
| `ProfileHeaderCard` | Identity summary | `HivorrAvatar` (avatar_path public URL), `displayName` (never legal name), bio, country chip, profession + industry badges |
| `VerificationBadgesRow` | Trust signals | Identity-verified badge (KYC tier code + status), trade-approved badge, credential count |
| `CredentialCard` | Approved credential display | Title, kind icon, read-only approved chip (`verification_status`, kind vocabulary) |
| `PortfolioItemCard` | Single work sample | Thumb (`media_path` public URL), type chip, title, description, sort order |
| `PortfolioGrid` | Responsive showcase | SliverGrid/`Wrap` adapting mobile ↔ web via `shared/layouts/` breakpoints |

All widgets use `Theme.of(context).colorScheme`/`textTheme`/`AppThemeExtension` only (AGENT.md Rule 5; `VISUAL-IDENTITY.md`) — never `Colors.*`, never per-widget `fontFamily`; 4 states via branded primitives wrapping `HivorrLoader` pulse, never bare `CircularProgressIndicator`.

### 5.7 Routing — `lib/app/router/app_router.dart:190-198`

Replace the `publicProfile` `PlaceholderScreen` builder with `ProfessionalProfileScreen`:

```dart
GoRoute(
  path: RoutePaths.publicProfileRoute,
  name: RouteNames.publicProfile,
  builder: (BuildContext context, GoRouterState state) =>
      ProfessionalProfileScreen(profileId: state.pathParameters['id'] ?? ''),
)
```

`RoutePaths.publicProfileRoute = '/p/:slug/:id'` (`route_paths.dart:91`) and the typed builder `RoutePaths.publicProfile(...)` (`route_paths.dart:98-102`) already exist — **no route_paths.dart change**. `RouteGuard` already treats `/p/` as public content (`route_guard.dart:168-169`) — **no RouteGuard change**. The `slug` parameter is used for SEO/canonical context and, when present, cross-checked against the RPC `professionSlug` (mismatch → still render; slug is cosmetic, entity id is authoritative).

### 5.8 DI — `registerPortfolioLayer`

```dart
({PortfolioRemoteDataSource dataSource, PortfolioRepository repository, PortfolioProvider provider, ProfessionalProfileService service})
registerPortfolioLayer({
  required ApiLayer apiLayer,
  PortfolioRemoteDataSource? dataSource,
  HivorrLogger? logger,
}) { ... }
```

Registered in `HivorrApp` MultiProvider (mirrors `TaxonomyProvider`/`OnboardingProvider` wiring). No new network client branches; the Supabase data source reuses the existing `ApiLayer`/client path.

### 5.9 Config & Logging

- No new feature flags or ENV keys; sole server addition is the migration (guarded idempotently).
- Errors via `ApiExceptionMapper` kinds: `404→PLT004`, `400/422→PLT003`, `5xx→PLT999`; service rethrows normalized `ApiException`; provider surfaces `message` without `stack`/SQL.
- `HivorrLogger` + `PiiRedactor`: log `entityId suffix` only — never `displayName`/bio/avatar path in full; no payload logging.
- `PerformanceTracer` span `portfolio.public_profile.load` sampled via `MonitoringConfig`.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `portfolio_items` DDL + RLS + grants + realtime guard | `supabase/migrations/20260913090001_portfolio_public_profile.sql` | **Create** — §5.2/§5.3 |
| `portfolio_public_profile_get(uuid)` RPC | same migration | **Create** — §5.3 |
| `PublicProfile`/`PublicProfession`/`PublicCredential`/`PortfolioItem` entities | `lib/data/entities/*` | **Create** — §5.4 |
| DTOs | `lib/data/models/` | **Create** — §5.4 |
| `PortfolioMappers` | `lib/data/mappers/portfolio_mappers.dart` | **Create** |
| `PortfolioEnvelopeParser` | `lib/data/datasources/portfolio_envelope_parser.dart` | **Create** |
| `PortfolioRemoteDataSource` + `SupabasePortfolioRemoteDataSource` | `lib/data/datasources/portfolio_remote_data_source.dart` | **Create** |
| `PortfolioRepository` + `PortfolioRepositoryImpl` | `lib/data/repositories/portfolio_repository.dart` | **Create** |
| `PortfolioProvider` | `lib/data/providers/portfolio_provider.dart` | **Create** |
| `ProfessionalProfileService` | `lib/systems/portfolio/services/professional_profile_service.dart` | **Create** |
| Screen + widgets | `lib/systems/portfolio/screens/professional_profile_screen.dart`, `widgets/{profile_header_card,verification_badges_row,credential_card,portfolio_item_card,portfolio_grid}.dart` | **Create** — §5.6 |
| SEO meta | `lib/systems/portfolio/seo/portfolio_seo_meta.dart` | **Create** |
| Barrel + DI | `lib/systems/portfolio/portfolio.dart` + `lib/data/data_layer.dart` re-exports | **Create/Update** |
| Route | `lib/app/router/app_router.dart:190-198` | **Update** — replace placeholder |
| Reuses (no change) | `RoutePaths.publicProfileRoute`, `RouteNames.publicProfile`, `RouteGuard._isPublicContentView`, `HivorrAvatar`, `StorageBuckets.portfolioItems`/`StoragePaths.portfolioItem`, branded states/`HivorrLoader`, `AppThemeExtension` | **Reuse** |
| Server tests | `supabase/tests/database/018_portfolio_public_profile.sql` | **Create** — §14 |
| Client tests + fakes | `test/unit/data/portfolio/*`, `test/unit/systems/portfolio/*`, `test/widget/systems/portfolio/*`, `test/integration/portfolio_profile_integration_test.dart`, `test/support/fakes/fake_portfolio*` | **Create** — §14 |

## 7. Data Requirements

### 7.1 Server Data Read (all via the SECURITY DEFINER RPC)

| Table | Read by RPC (whitelist) | Notes |
|---|---|---|
| `entities` | `id`, `status` | Active gate |
| `entity_profiles` | `display_name`, `avatar_path`, `bio`, `country_code` | `legal_name` excluded (Rule 3) |
| `entity_professions` | approved rows: `profession_id`, `is_primary` | Gate source (`trade_verification_status = 'approved'`) |
| `professions` / `industries` | `slug`, `name` | SEO route slugs + badges |
| `entity_credentials` | approved rows: `kind`, `title`, `verification_status` | `document_path` excluded |
| `entity_kyc_levels` / `kyc_tiers` | `tier_code`, `status` | Trust indicator; limits excluded |
| `portfolio_items` | `id`, `item_type`, `title`, `description`, `media_path`, `sort_order` | New table (§6) |

### 7.2 Server Data Written (this task)

| Table | Written by | Seam |
|---|---|---|
| `portfolio_items` | owner self-CRUD (RLS `auth.uid() = entity_id`) | New — this migration |

No existing table columns are modified; no storage objects are touched. Media uploads reuse the EP-02-06/08 `portfolio-items` contract (public, 10 MiB, jpeg/png/webp/pdf, `{entityId}/{itemId}/{file}` via `StoragePaths.portfolioItem`).

## 8. Database Considerations

- **Exactly one additive migration** `20260913090001_portfolio_public_profile.sql`, ordered after `20260911090002_demo_identity_seed.sql`. No frozen file is edited.
- **RLS posture:** `portfolio_items` enabled + default-deny; owner `insert`/`update`/`delete` via `auth.uid() = entity_id` (`WITH CHECK` on insert/update); **no anon/authenticated SELECT** — the RPC is the only read path (even for the owning entity, the public page reads via RPC).
- **Realtime exclusion:** appended to the existing `do $$` publication guard style (`20260830100001:219-233`, `20260829090003:798-816`) so `portfolio_items` never enters `supabase_realtime`.
- **`media_path` CHECK parity:** `media_path LIKE 'portfolio-items/' || entity_id::text || '/%'` enforces at the DB layer what storage RLS enforces on objects (`20260830100001:181-186`) — an owner cannot point a row at another entity's bucket path.
- **SECURITY DEFINER discipline:** `portfolio_public_profile_get` is `SECURITY DEFINER` + `STABLE`; it selects only whitelisted columns; no client-facing write; comment documents the anon execute grant and the never-expose columns.
- **Full pgTAP suite stays green:** `supabase db test` `001-018` — the new `018` test must not break `014_financial_rpc_enforcement.sql`/`015` publics-revoke assumptions (RPC grants are scoped to the new function only).
- **No migration churn risk:** grants on the new function are issued in the same migration; the function is created fresh (no `create or replace` collision with any prior migration).

## 9. API Requirements

### 9.1 New RPC

| Operation | Seam | Method | Params | Anon? | Errors → ApiExceptionKind |
|---|---|---|---|---|---|
| Public profile fetch | `portfolio_public_profile_get` | `POST`/`rpc` | `p_entity_id: uuid` | Yes | `PLT003` (validation), `PLT004` (not found/not approved), `PLT999` (internal) |

### 9.2 Reused (no change)

| Operation | Seam | Client path |
|---|---|---|
| Portfolio media render | Storage public URL (`getPublicUrl`) | `portfolio-items` public bucket (`storage_config.dart:100-101`) |
| Avatar render | Public URL | `profile-avatars` public bucket |

### 9.3 Error Contract

Every public `ProfessionalProfileService` method throws only normalized `ApiException` (or `DataException`). `PLT004` → not-found screen with SEO 404 semantics; `PLT003` → validation state (should be unreachable from a valid entity id); network → retry state. No raw Supabase/Dio exceptions escape the data layer.

## 10. User Interface Requirements

Widgets introduce UI — AGENT.md Rule 5 applies (`VISUAL-IDENTITY.md`). Every widget uses `Theme.of(context).colorScheme`/`textTheme`/`AppThemeExtension` only.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `ProfessionalProfileScreen` | `GET /p/:slug/:id` | Public profile page | Loads via service; `ProfileHeaderCard` + `VerificationBadgesRow` + `CredentialCard` list + `PortfolioGrid`; empty-state, error-retry, not-found states |
| `ProfileHeaderCard` | — | Identity + profession summary | `HivorrAvatar`, display name (never legal), bio, country chip, profession/industry badges |
| `VerificationBadgesRow` | — | Trust signals | Identity-verified (KYC tier + status), trade-approved badge, approved-credential count |
| `CredentialCard` | — | Approved credential | Title, kind chip, approved state chip (read-only) |
| `PortfolioItemCard` | — | Work sample | Media thumb (public URL), type chip, title, description |
| `PortfolioGrid` | — | Showcase layout | Responsive grid via `shared/layouts/` breakpoints |

Responsive: 16dp padding mobile, 24dp web pane (`shared/layouts/`). No money/identity-legal values surfaced (per §2/§5.3 whitelist).

## 11. User Experience Considerations

- **Instant trust comprehension:** header + badges encode "verified professional" in one glance; KYC indicator and approved-credential list reinforce credibility without UI claims — all state comes from the RPC.
- **SEO-first rendering:** canonical slug/entity URL, meta title = `displayName · {professionName}` (never legal name), meta description from bio (truncated) — `portfolio_seo_meta.dart`.
- **Graceful not-found:** `PLT004` renders a clean not-found state (no legal-name hint, no raw entity id echo), preserving SEO + privacy.
- **Always-public:** signed-out visitors can read the profile (guard already bypasses `/p/`); no signup wall.
- **Responsive continuity:** mobile single column → web multi-column grid using `shared/layouts/` (EP-02-18 TIP §10 precedent).
- **Retry without leak:** network errors show branded retry; aborted/failed loads never cache partial payloads.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Zero public table grants** | anon/authenticated retain zero grants on all trust tables (`20260821090003:24-27`, `20260829090003:244-246`); public reads happen only inside `portfolio_public_profile_get` (SECURITY DEFINER) |
| **Column whitelist is authoritative** | The RPC selects only whitelisted columns; `legal_name` and `document_path` and all internal review/limit fields are structurally absent from the projection — verified by pgTAP assertions, not convention |
| **Approved-gate privacy** | Unknown/inactive/no-approved-profession entities all return the identical `PLT004` message — no enumeration/oracle of which entities exist or why a profile is hidden |
| **Write surface** | New writes restricted to owner self-CRUD on `portfolio_items` (`auth.uid() = entity_id`, `media_path` CHECK); anon has no write path anywhere; RPC is read-only (`STABLE`) |
| **Path-RLS parity** | `media_path` cannot reference another entity's storage folder (DB CHECK mirrors storage policy) |
| **SECURITY DEFINER hygiene** | `SET search_path` scoping to `public, pg_temp`; explicit column projections (no `SELECT *` into public response); comment documents grants; `revoke execute` posture for `public` preserved |
| **No PII escalation** | Public payload carries display-level data only; bio is user-authored public text; logging redacts to `entityId suffix` |
| **SLUG/oracle** | Entity id is authoritative; slug is cosmetic — mismatch still renders with canonical slug, never redirect-chains |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **Single RPC per view** | One `portfolio_public_profile_get` call returns the complete profile graph (badges + credentials + KYC + portfolio) — no N+1 REST reads; no client joins |
| **`STABLE` function + PostgREST caching** | Declared `STABLE` so PostgREST can reuse; client may add short TTL cache in the repository (optional, default off) |
| **Portfolio payload cap** | RPC orders by `sort_order` and returns the full owner set (owner-managed, small); no pagination in EP-02-19 scope |
| **Media is URL-only** | Public URLs served from Supabase Storage CDN; the profile page never ships bytes |
| **State churn** | `PortfolioProvider` holds one immutable `PublicProfile`; no per-frame allocations; view-models derived once |
| **Tracer overhead** | `PerformanceTracer` span `portfolio.public_profile.load` sampled via `MonitoringConfig`; no PII tags |

## 14. Testing Strategy

### 14.1 Server — pgTAP `supabase/tests/database/018_portfolio_public_profile.sql`

Style mirrors `017_storage_posture.sql` (`begin; set search_path to extensions, public, storage; select plan(N); ... finish(); rollback;`). Aligned to the `001-017` suite naming.

| # | Assertion | Method |
|---|---|---|
| 1–4 | `portfolio_items` table exists; RLS enabled; audit columns; `platform_set_updated_at` trigger | `has_table`, `col_is_pk`, `col_has_default`, `col_not_null`, `has_trigger` |
| 5–8 | CHECK constraints: `item_type` vocabulary, title/description lengths, `media_path` starts with `portfolio-items/{entity}/` | `col_has_check`, custom `throws_ok`/query guards |
| 9–13 | Default-deny: anon has no SELECT/INSERT/UPDATE/DELETE grants on `portfolio_items`; authenticated self-CRUD present; anon has no table SELECT on any entity-model table (001-style regression stays) | information_schema / pg_policies asserts |
| 14–16 | Rows policies: insert WITH CHECK `auth.uid() = entity_id`; update/delete owner-scoped; no anon select policy | `pg_policies` rows |
| 17–22 | `portfolio_public_profile_get` identity: exists; `security definer`; `stable`; execute granted to `anon, authenticated, service_role`; no `public` grant | `has_function`, `function_returns`, `function_security`, `function_lang`, `has_function_privilege` |
| 23–29 | Behavior: `PLT003` null id; `PLT004` nonexistent; `PLT004` inactive entity; `PLT004` active with zero approved professions; `PLT000` with ≥1 approved profession; payload contains whitelisted fields | seeded rows + `results_eq`/`is` on envelope jsonb paths |
| 30–34 | Whitelist negative: `legal_name` absent; `document_path` absent; `reviewed_by`/`rejection_reason` absent; KYC limits absent; raw table select by anon still fails | `throws_ok` on `set role anon` table reads; `NOT` `jsonb_path_exists` on payload |

### 14.2 Client — fake-stack (EP-02-18 precedent)

| Suite | Files | Cases (min) |
|---|---|---|
| Unit — data | `test/unit/data/portfolio/*` — envelope parser (success/`PLT003`/`PLT004`/malformed), mappers, DTO↔entity round-trip, repo delegation, data source RPC params | ≥18 |
| Unit — systems | `test/unit/systems/portfolio/*` — service derived view-models (`verifiedIdentity`, trade gate), `PLT004`→not-found mapping, SEO meta builder, redacted log assertions | ≥10 |
| Widget | `test/widget/systems/portfolio/*` — header/badges/credential/grid rendering, theme token compliance (grep: no `Colors.*`/`Color(0xFF`/`fontFamily:`), empty/error/not-found states, responsive breakpoint render | ≥20 |
| Integration | `test/integration/portfolio_profile_integration_test.dart` — real route `/p/slug/id` with fake data source → screen loads → badges + grid render; `PLT004` → not-found; retry on network failure | 3 flows |

### 14.3 Verification Gates

| Gate | Command / Assertion |
|---|---|
| Analyzer clean | `flutter analyze` — 0 issues |
| Full client suite | `flutter test` — all green |
| DB regression + new test | `supabase db test` — `001-018` green |
| Server diff scoped | `git diff --stat -- supabase/migrations/` shows exactly one new file (optionally verify `018` added) |
| Grep lenses | `grep -rn "service_role" lib/` = 0; `grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart` = 0; no `Colors.\|Color(0xFF\|fontFamily:` in portfolio widgets |
| No-DDL outside new migration | No edits to any pre-existing `supabase/migrations/*.sql` |

## 15. Definition of Done (DoD)

**Server (New Migration — Exact Scope)**
- [ ] **DoD-1:** Exactly one new migration `20260913090001_portfolio_public_profile.sql` exists; zero edits to any pre-existing migration (verified `git diff --stat -- supabase/migrations/` = one new file).
- [ ] **DoD-2:** `portfolio_items` table created with audit columns + `platform_set_updated_at` trigger; RLS enabled; `media_path` CHECK `portfolio-items/{entityId}/%`; realtime-excluded.
- [ ] **DoD-3:** Default-deny preserved — anon has zero grants on `portfolio_items`; owner self-CRUD via RLS (`auth.uid() = entity_id`).
- [ ] **DoD-4:** `portfolio_public_profile_get(uuid)` is SECURITY DEFINER + STABLE; execute granted to `anon, authenticated, service_role` only; no `public` grant.

**Trust & Privacy**
- [ ] **DoD-5:** Approved-gate enforced — `PLT004` for nonexistent, inactive, or zero-approved-profession entities with identical message (no oracle).
- [ ] **DoD-6:** Column whitelist authoritative — `legal_name`, `document_path`, `reviewed_by`, `rejection_reason`, KYC limits never appear in the payload (pgTAP negative asserts).
- [ ] **DoD-7:** No `service_role` string in `lib/`; no legal-name reference in `lib/systems/portfolio/` or `lib/data/providers/portfolio_provider.dart` (grep lenses clean).

**Data Layer**
- [ ] **DoD-8:** Entities + DTOs (`PublicProfile`, `PublicProfession`, `PublicCredential`, `PortfolioItem`), mappers, `PortfolioEnvelopeParser`, data source (+ Supabase impl), repository (+ impl), `PortfolioProvider` in `lib/data/` — unidirectional `data → systems`, no widget imports.
- [ ] **DoD-9:** Parser mirrors the envelope contract (`{success, code, message, data}`) and maps `PLT003`/`PLT004`/`PLT999` to normalized `ApiException` kinds.

**System + UI**
- [ ] **DoD-10:** `lib/systems/portfolio/` activated — `ProfessionalProfileService`, `ProfessionalProfileScreen`, 5 widgets, `seo/portfolio_seo_meta.dart`, `portfolio.dart` barrel, `registerPortfolioLayer`.
- [ ] **DoD-11:** Screen renders header, verification badges, approved credentials, portfolio grid; display name only (never legal); public URLs via Storage public buckets.
- [ ] **DoD-12:** All widgets consume theme tokens only (Rule 5) — grep asserts no `Colors.*`, `Color(0xFF`, or `fontFamily:` in portfolio widgets; 4 states via branded primitives + `HivorrLoader`.

**Routing & SEO**
- [ ] **DoD-13:** Placeholder replaced at `app_router.dart:190-198` with `ProfessionalProfileScreen`; `RoutePaths.publicProfileRoute`/`RouteNames.publicProfile`/`RouteGuard` unchanged (verified no diff at `route_paths.dart`/`route_guard.dart`).
- [ ] **DoD-14:** Signed-out visitors can open `/p/:slug/:id` (guard bypass verified by test); `portfolio_seo_meta.dart` emits title/description/canonical from payload.

**Tests & Quality**
- [ ] **DoD-15:** pgTAP `018_portfolio_public_profile.sql` in the `001-018` suite (schema/RLS/grants/whitelist/behavior incl. negative leaks) — `supabase db test` green.
- [ ] **DoD-16:** Client unit (≥28), widget (≥20), and 3-flow integration tests green; `flutter analyze` 0 issues; full `flutter test` green.
- [ ] **DoD-17:** Redacted logging (`entityId suffix` only); `PerformanceTracer` span `portfolio.public_profile.load`; no PII in logs.

## 16. Expected Outcome

- A public, SEO-friendly professional profile at `/p/:profession_slug/:entity_id` that renders entity display info, profession + industry badges, verification status badges (identity + trade), approved credentials, KYC level indicator, and a portfolio grid — fully responsive on mobile and web.
- Public reads traverse **only** `portfolio_public_profile_get` (SECURITY DEFINER, whitelisted projection, approved-gate); anon never touches any trust table directly; `legal_name`/`document_path`/limits never leave the server.
- EP-03 marketplace discovery is unblocked — the profile RPC + `portfolio_items` model are consumable by future systems without further server migration.
- Verified per the DoD checklist (17 criteria) and the verification gates (§14.3) in the development environment.

## 17. AI Execution Profile

| Attribute | Recommended | Justification |
|---|---|---|
| **Reasoning Level** | **High** | **Technical complexity High** — one additive migration + one SECURITY DEFINER RPC with a precise column whitelist and approved-gate, plus a layered client slice (entities/DTOs/mappers/parser/data source/repository/provider/service/screen/widgets/SEO/DI). **Security sensitivity High → Very High-adjacent**: this is the first **anon-executable SECURITY DEFINER** function in the codebase, so whitelist discipline, gate privacy (identical `PLT004`), and pgTAP negative-leak asserts are mandatory. **Where it could become Very High:** if the RPC grew write paths, multi-actor state transitions, or financial projections — it does not. **Business impact High** — public trust display + EP-03 foundation (`EP-02:450`). **Performance sensitivity Medium** — single RPC, `STABLE`, CDN media. **Data complexity Medium** — one new table + 7-table read projection. Phase Plan assigns EP-02-19 **Planning High / Coding High** (`EP-02:491,502`); `High` is calibrated: rigorous, security-elevated, but not the catastrophic multi-actor financial reasoning of escrow/payouts (EP-02-03/04/14/16). |
| **Phase Plan parity** | Planning High / Coding High | Matches `EP-02:454` (Planning Reasoning High, Coding Reasoning High) and the roadmap matrix (`EP-02:491`). |

## 18. Review & Approval

| Role | Action |
|---|---|
| Task Lead | Assemble implementation in dev env; run gate suite; self-review DoD 1–17 |
| Architecture Review | Confirm single-migration server surface, `lib/` placement, unidirectional deps, RPC whitelist, frozen-file no-diff |
| Security Review | Verify approved-gate non-oracle behavior, column whitelist pgTAP negatives, SECURITY DEFINER hygiene, zero PII logs |
| Lead Approval | Sign off DoD 1–17 before transfer to code review |

Approved plan — implementation begins in the Development environment. This document is owned by `documents/Task-Implementation/EP-02/`; server-chain changes require a new migration proposal, never an edit here.

## 19. Post-Implementation Audit Checklist

```
[ ] flutter analyze              -> 0 issues
[ ] flutter test                 -> all green (unit ≥28 + widget ≥20 + 3 integration flows)
[ ] supabase db test             -> 001-018 green
[ ] git diff --stat -- supabase/migrations/  -> exactly one new file
[ ] grep -rn "service_role" lib/                     -> 0
[ ] grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/portfolio/ -> 0
[ ] Signed-out /p/:slug/:id opens (guard bypass verified in integration test)
[ ] PLT004 not-found state renders for inactive/unknown/not-approved entities
[ ] SEO meta (title/description/canonical) emitted on web from payload
```