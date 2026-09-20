# Task Implementation Plan — EP-02-20: Phase Integration Validation & Trust System Verification

**Task ID:** EP-02-20 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Not Started (plan for approval) | **Priority:** Critical — Phase Gate | **Dependencies:** All EP-02 items (EP-02-01 through EP-02-19) | **Stage:** 8 — Validation

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:456-465` (objective, 12-point validation, deps), `EP-02:147-148` (dependency matrix, EP-02-20 depends on All), `EP-02:240` (completion criteria) | Architecture: `documents/Context/ARCHITECTURE.md:95-110,131-138` (`lib/systems/`, `lib/data/`), `ARCHITECTURE.md:147-150` (SEO public routes), `ARCHITECTURE.md:151-153` (payment gateway abstraction boundary) | Guardrails: `documents/Context/AGENT.md` Rules 2,3,4,5 (trade gate, financial guardrails, zero-trust RPC+RLS, design tokens) | Precedent: `documents/Task-Implementation/EP-02/EP-02-19-Professional Profile & Credential Display System.md`, `documents/Task-Implementation/EP-01/EP-01-20-Phase Integration Validation & Foundation Verification.md` + `EP-01-20-Foundation-Verification-Report.md` | Current schema: `supabase/migrations/20260821090001_entity_taxonomy_tables.sql` through `20260917090002_manage_user.sql` (22 migrations), `supabase/tests/database/001-022` | Existing integration harness: `test/support/fakes/`, `test/support/harnesses/`, `test/integration/`

---

## 1. Task Objective

Perform comprehensive end-to-end integration validation of all EP-02 systems, proving that the 19 individually-implemented trust, identity and financial subsystems operate correctly **as an integrated trust platform** — not merely in isolation — before EP-02 is marked complete and EP-03 is unblocked:

- **12-Point Trust Integration Validation Suite** — structured integration tests exercising each validation point defined in `EP-02:463` (see §5.2-5.13).
- **Cross-Cutting Verification Scripts** — static scans and posture audits re-verifying zero financial logic in client, RLS default-deny, no `legal_name`/`document_path` leakage, design-token compliance, and no hardcoded secrets.
- **Trust System Verification Report** — `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md` recording pass/fail per validation point, issues, remediation, and EP-03 readiness verdict.
- **Minimal wiring fixes only** — where validation discovers missing provider registration or bootstrap init-order gaps, apply minimal glue fixes in `lib/app/` / `lib/data/data_layer.dart` (see §5.18).

**Dependency note:** EP-02-20 consumes ALL prior EP-02 deliverables. It validates integrated operation. It does not design new financial schema, create RPCs/RLS, add storage buckets, or modify frozen server surfaces. Where gaps are found, this task creates targeted integration tests and verification scripts, and may apply minimal fixes to wiring/glue code that were not covered by individual task scopes.

---

## 2. Business Problem Being Solved

Per `EP-02:461-463`, individual EP-02 systems may work in isolation but fail when composed. Without a phase-gate validation:

- **Onboarding→Taxonomy→Verification seam breaks silently.** `lib/systems/onboarding/services/onboarding_service.dart` composes `TaxonomyProvider`, `IdentityVerificationService`, `TradeVerificationService`, `StorageService`. A missing DI registration or wrong init order breaks the 5-step wizard end-to-end while each unit suite stays green.
- **Trust gate is unverified.** AGENT.md Rule 2 (`trade_verification_status == approved` unlocks bidding) is server-enforced via `20260829090003_verification_admin_review_schema.sql`. Without an integrated test that drives `entity_profession_bind` → `verification_submit` (trade_proof) → admin review approve → `tradeVerificationStatus` propagation → bid-lock released, a client bypass or stale provider cache goes undetected until EP-03 marketplace activation.
- **Financial integrity is unverified at composition.** `20260829100004_financial_integrity_schema.sql` holds 11+ tables (profiles, currency_accounts, balances, transactions, escrow, escrow_milestones, payout_accounts, payouts, deposits, conversions, audit_trail). Escrow lifecycle (create→fund→milestone→release/refund/dispute-hold), conversion preview→execute, bound payout + KYC-driven cashout limits, and deposit `Payer Name == legal_name` matching (AGENT.md Rule 3) each have their own RPCs. Only a cross-system flow (financial profile → escrow funded → dispute filed → escrow frozen → dispute resolved → escrow released/refunded) proves audit-trail immutability and double-entry integrity across the provider-agnostic abstraction in `lib/integrations/payment_gateways/` and `lib/systems/finance/`.
- **Phase completion is unverifiable.** `EP-02:214-241` lists 21 phase completion criteria. Without structured evidence there is no auditable basis to mark EP-02 "Complete" — a false-positive gates EP-03 on a broken trust foundation; a false-negative blocks EP-03 unnecessarily.
- **Security posture unverified.** `entity_profiles.legal_name` is the Rule 3 anchor (`20260821090002_entity_core_tables.sql:82-85`). The public profile RPC `portfolio_public_profile_get(uuid)` (`20260913090001_portfolio_public_profile.sql`) is the only anon path and must whitelist columns (never `legal_name`, never `document_path`). Storage buckets `credential-documents` (private) vs `profile-avatars`/`portfolio-items` (public) (`20260830100001_storage_buckets.sql`, `supabase/tests/database/017_storage_posture.sql`) must remain correctly isolated. Without a posture scan, a mis-granted SELECT or leaky widget render could expose PII/evidence.
- **No regression baseline for trust.** EP-03/04 build directly on verified entities, taxonomy, and escrow. Without integration tests that exercise the trust→finance→dispute seams, future changes break them silently.

This is the **EP-02 phase gate** that converts 19 individual completions into verified EP-03 readiness.

---

## 3. Scope

### In Scope

| Area | Detail | Location |
|---|---|---|
| **Validation Point 1 — Full onboarding flow** | Fresh authenticated entity → 5-step wizard (`profile` legal/display/bio/avatar → `capability` → `industry` → `identityDocument` → `tradeProof`) → progress resumability (Hive key `onboarding_progress:{entityId}` per `lib/data/local/onboarding_progress_store.dart` + `lib/data/providers/onboarding_provider.dart`) → completion screen. Verifies ordering contract, `entity_profession_bind` landing `unverified`, and `OnboardingProgressStore` resume after exit. | `test/integration/trust/onboarding_trust_flow_integration_test.dart` (new) |
| **Validation Point 2 — Taxonomy browse→select→bind** | `TaxonomyProvider.loadIndustries` → `loadProfessions(industryId)` → search/filter (`filteredProfessions`) → `ProfessionRegistryBrowser` reuse → `entity_profession_bind` → duplicate `PLT005` guidance. Exercises `lib/workspace/profession_registry/` + `20260829090002_taxonomy_management_rpcs.sql` list RPCs. | `test/integration/trust/taxonomy_browse_bind_integration_test.dart` |
| **Validation Point 3 — Identity verification submit→review→approve** | `IdentityVerificationService.submitIdentityDocument` (5 `DocumentType` values, `credential-documents` upload via `StoragePaths.credentialDocument`, `verification_submit` → `pending` → admin review `approve` via `admin_review_queue` seam → `verification_status_get` reflects approved + KYC tier. | `test/integration/trust/identity_verification_flow_integration_test.dart` (extends existing `test/integration/verification/verification_flow_test.dart`) |
| **Validation Point 4 — Trade verification + bid-lock** | `TradeVerificationService.submitTradeProof` (5 `TradeProofType`, profession-bound `submission_type=trade_proof`) → `pending` → admin review → `trade_verification_status=approved` propagation → `TradeVerificationGate`/`TradeVerifiedBadge` shows bidding unlocked, bid-lock enforcement reflected in `TradeVerificationProvider`/`TradeVerificationStatus`. | `test/integration/trust/trade_verification_gate_integration_test.dart` (extends `trade_verification_flow_test.dart`) |
| **Validation Point 5 — KYC level → limit increase** | `KycService`/`KycProvider` reading `entity_kyc_levels`↔`kyc_tiers` (`20260829090003_verification_admin_review_schema.sql`) → `KycLimitGuard` check → cashout/transaction limits scale with tier upgrade; `verification_limits_get` verified server-side. Uses `test/support/fakes/fake_kyc_remote_data_source.dart` pattern. | `test/integration/trust/kyc_level_limit_integration_test.dart` (extends `kyc_flow_test.dart`) |
| **Validation Point 6 — Financial profile → currency accounts → balances** | `FinancialService`/`FinancialProvider` → `financial_profiles` create → `financial_currency_accounts` request per currency (NGN primary, GHS/USD/GBP secondary per EP-02 assumptions) → `financial_balances` (available/held/pending per currency) display via `BalanceOverviewCard`/`CurrencyAccountCard`; verifies `supabase/tests/database/013_financial_schema_posture.sql` + `014_financial_rpc_enforcement.sql` contracts client-side. | `test/integration/trust/financial_profile_flow_integration_test.dart` (extends `test/integration/finance/financial_profile_flow_test.dart`) |
| **Validation Point 7 — Escrow lifecycle + milestone release + audit** | `EscrowService`/`EscrowProvider` → `financial_escrow` create with `EscrowMilestone` inputs → fund → `escrow_milestones` completion tracking → release (or refund) → `financial_transactions` double-entry + `financial_audit_trail` immutability; escrow state machine verified (fund→hold→release/refund). Reuses `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` + `lib/systems/finance/services/escrow_service.dart`. | `test/integration/trust/escrow_lifecycle_integration_test.dart` (extends `escrow_proxy_seam_test.dart`) |
| **Validation Point 8 — Currency conversion infrastructure** | `ConversionService`/`ConversionProvider` → `getAvailablePairs` → `previewConversion` (rate + fees from `ConversionRateSource`) → `executeConversion` → balances atomically updated; server-side rate validation path exercised. Reuses `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart`. | `test/integration/trust/conversion_flow_integration_test.dart` (extends `test/integration/finance/conversion_flow_test.dart`) |
| **Validation Point 9 — Bound payout + KYC-driven cashout limits + name enquiry** | `FinancialPayoutService`/`FinancialPayoutProvider` + `PayoutAccountLocalStore` → `financial_payout_accounts` bind → `NameEnquiryService`/`NibssNameEnquiryAdapter` (`lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart`) ownership verify → `KycLimitGuard` limits check → withdrawal within limit succeeds, over-limit `PLT003`/limit error, payout status tracking via `PayoutStatus`/`PayoutAccountCard`/`PayoutWithdrawFormView`. | `test/integration/trust/payout_account_flow_integration_test.dart` |
| **Validation Point 10 — Deposit name-matching (Rule 3)** | `FinancialDepositService`/`FinancialDepositProvider` → `financial_deposits` record with `payer_name` → server-side `Payer Name == entity_profiles.legal_name` comparison → matching accepted, mismatched flagged/blocked; `DepositNameMatchStatus` + `DepositNameMatchIndicator`/`DepositDetailsPanel` render. Covers `financial_deposit_remote_data_source.dart` path. | `test/integration/trust/deposit_name_match_integration_test.dart` |
| **Validation Point 11 — Dispute file → evidence → resolve → escrow action** | `DisputeService`/`DisputeProvider` (`lib/systems/support/services/dispute_service.dart`) → `dispute_file` (linked `escrowId`) → auto `financial_escrow` hold → `dispute_submit_evidence` (private storage) → `dispute_resolve` (admin/service-role) → escrow release OR refund per resolution, with `dispute_audit_trail`. Reuses `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart`. | `test/integration/trust/dispute_escrow_integration_test.dart` (extends `test/integration/support/dispute_flow_test.dart`) |
| **Validation Point 12 — Professional profile public display + SEO + responsive** | `ProfessionalProfileService`/`PortfolioProvider` → anon `portfolio_public_profile_get(p_entity_id uuid)` (`20260913090001_portfolio_public_profile.sql`: SECURITY DEFINER, `STABLE`, approved-gate, whitelisted columns `display_name`/`avatar_path`/`bio`/`country_code` + approved professions/credentials + `portfolio_items`) → `RoutePaths.publicProfile(slug,id)` (`lib/app/router/route_paths.dart:104-115`) renders at 390px and 1280px via `shared/layouts/` (`ProfessionalProfileScreen` + `ProfileHeaderCard`/`VerificationBadgesRow`/`CredentialCard`/`PortfolioGrid`) → `portfolio_seo_meta.dart` emits `title/description/og:*/canonical` (never `legal_name`). `RouteGuard._isPublicContentView` (`lib/app/router/route_guard.dart:215-216`) already bypasses `/p/` while signed-out. | `test/integration/trust/public_profile_integration_test.dart` (extends `test/integration/portfolio_public_profile_flow_test.dart`) |
| **Cross-cutting verifications** | Secret scan, financial-logic scan (zero client math), private-path scan (`document_path` never public), theme-token scan (Rule 5), RLS/posture re-audit, onboarding-resume redirect, payment-gateway abstraction boundary, phase completion checklist. | `test/integration/verification/trust_*` (see §14) |
| **Trust System Verification Report** | `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md` | Report (new) |
| **Minimal wiring fixes** | Where validation finds missing `register*Layer` in `lib/data/data_layer.dart`, missing provider in `lib/app/app.dart:MultiProvider`, onboarding resume gate missing in `lib/app/router/route_guard.dart:_onboardingResumeRedirect`, or `supabase/tests/database/` import missing → minimal fixes in `lib/app/` + `lib/data/data_layer.dart` only. | Files: `lib/app/router/app_router.dart`, `lib/app/router/route_guard.dart`, `lib/app/app.dart`, `lib/data/data_layer.dart` (if needed) |
| **Quality gates** | `flutter analyze` 0 issues, `flutter test` (unit+widget+integration) all green, `supabase db test` `001-022` all green, grep lenses clean. | CI-equivalent verification |

### Scope — explicit inclusions (evidence artefacts)

- Integration tests compose **real** system objects (`*Service`, `*Provider`, `*Repository`, `*Mapper`) with EP-01-19/EP-02 fakes at the transport/storage boundary: `FakeSupabaseClient`/`MockSupabaseClientFactory`, `FakeStorageService` (`test/support/fakes/fake_storage.dart`), `FakeTaxonomyRepository`, `FakeVerificationRepository`/`FakeTradeVerificationRepository`, `FakeKycRemoteDataSource`, `FakeConversionRateSource`, `FakePortfolio`/`FakeDispute` (see §6).
- Widget assertions that render the trust screens (`lib/systems/onboarding/screens/`, `lib/systems/verification/screens/`, `lib/systems/finance/screens/`, `lib/systems/portfolio/screens/professional_profile_screen.dart`, `lib/systems/support/screens/`) through the real `GoRouter` harness `test/support/harnesses/router_harness.dart` + `widget_harness.dart`.
- Reuse of existing EP-02 integration tests where they already cover the seam (the new VP tests extend/compose them rather than duplicate them).

---

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| New `supabase/migrations/*.sql` DDL, RLS, RPC creation or modification | All EP-02 server surfaces frozen (`20260829090003_verification_admin_review_schema.sql`, `20260829100004_financial_integrity_schema.sql`, `20260829120005_dispute_resolution_schema.sql`, `20260830100001_storage_buckets.sql`, `20260913090001_portfolio_public_profile.sql`, `20260915090001_onboarding_authoritative_state.sql`). This task is validation-only; `git diff --stat supabase/migrations/` must be `0`. |
| New storage bucket or bucket policy, Edge Functions, webhook handlers | EP-02-06/08 + `20260830100001_storage_buckets.sql` already provisioned; EP-02-20 does not modify storage posture (validated by `017_storage_posture.sql` + `018_portfolio_public_profile.sql`). |
| Direct table SELECT by anon/authenticated to verify trust data | Default-deny (`20260821090003_entity_model_rls_policies.sql:24-27`, `20260829090003:244-246`, `20260829100004:` RLS) — public reads remain via SECURITY DEFINER RPCs (`portfolio_public_profile_get`, `taxonomy_*_list`, `financial_*`, etc.) only (AGENT.md Rule 4). |
| End-to-end live Supabase connection, live Paystack/Flutterwave/NIBSS calls | Uses `MockSupabaseClientFactory` scripted `rpcHandlers` + `Fake*DataSource` + `MockDioAdapter` — no network, no real credentials. Provider surface (EP-02-09) is exercised via `lib/integrations/payment_gateways/*` fakes (`payment_gateway_factory_test.dart` precedent). |
| Business logic implementation (pricing, matching, financial splits, escrow arithmetic) | Deterministic core supremacy (AGENT.md). Validated only that client does not contain it (financial-logic scan). |
| KYC provider selection / live SmileID/Dojah adapter | EP-02-11 assumption — EP-02 delivers the abstract `KycProvider` seam + mock adapter (`lib/integrations/kyc/kyc_provider_seam_test.dart`); live provider is beyond EP-02. |
| Admin console hardening beyond EP-02-11 simplified queue | `lib/systems/verification/screens/admin_review_queue_screen.dart` + `admin_review_detail_screen.dart` + `lib/data/providers/admin_review_provider.dart` are validated as-is; full RBAC admin panel is a later phase. |
| Performance/load benchmarking, pen-testing, physical device E2E | EP-01-20 scope precedent — deferred. |
| `VISUAL-IDENTITY.md` token changes, new design-system widgets | Only verifies existing widgets meet Rule 5. |
| Phase-document/ARCHITECTURE.md/AGENT.md edits | Frozen. |

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| **Validate, don't implement** | Follows EP-01-20 precedent. Proves existing trust systems interoperate; does not build new features. |
| **Reuse EP-01-19 + EP-02 test infrastructure** | `test/support/fakes/*`, `factories/mock_supabase_client_factory.dart`, `harnesses/widget_harness.dart` & `router_harness.dart`, `builders/entity_builders.dart`, `matchers/*`. New fakes extend the same seam (see §6). |
| **Real composition at the seam** | Integration tests compose real `*Service`→`Repository`→`RemoteDataSource`→`EnvelopeParser`→`Mapper`→`Provider`→`Widget` stacks; only the Supabase client / Dio adapter / Storage / Hive store is faked. This validates wiring that unit tests cannot. |
| **Server is authoritative** | `trade_verification_status`, `verification_submissions.status`, `financial_balances`, escrow state, dispute resolution are **read-only** client renders (`TradeVerificationStatus`, `VerificationStatus`, `EscrowStatus`, `DisputeStatus`). Tests assert server state drives UI; no client mutates gate columns. |
| **Minimal wiring fixes only** | If `HivorrApp` `MultiProvider` or `RouteGuard._onboardingResumeRedirect` (`lib/app/router/route_guard.dart:184-213`) or `register*Layer` in `lib/data/data_layer.dart:198-475` is missing a registration, fix that glue. Do not rewrite system logic. |
| **Evidence-based gate** | Every VP produces test output; report (§5.19) documents pass/fail with evidence. Gate is fail-closed — any VP failure blocks EP-03. |
| **No hardcoded secrets or PII** | Placeholder entity data only; secret scan re-run; `PiiRedactor` + `HivorrLogger` redacted logs (`entityId suffix` only). |

### 5.2 Proposed Repository Structure (new files only)

```text
test/integration/trust/
├── onboarding_trust_flow_integration_test.dart          # VP1
├── taxonomy_browse_bind_integration_test.dart           # VP2
├── identity_verification_flow_integration_test.dart     # VP3
├── trade_verification_gate_integration_test.dart        # VP4
├── kyc_level_limit_integration_test.dart                # VP5
├── financial_profile_flow_integration_test.dart         # VP6
├── escrow_lifecycle_integration_test.dart               # VP7
├── conversion_flow_integration_test.dart                # VP8
├── payout_account_flow_integration_test.dart            # VP9
├── deposit_name_match_integration_test.dart             # VP10
├── dispute_escrow_integration_test.dart                 # VP11
└── public_profile_integration_test.dart                 # VP12

test/integration/verification/
├── trust_financial_logic_scan_verification.dart         # no client math
├── trust_legal_name_document_scan_verification.dart     # no leakage
├── trust_theme_token_scan_verification.dart             # Rule 5
├── trust_storage_posture_verification.dart              # bucket RLS
├── trust_gateway_abstraction_verification.dart          # no direct provider calls
├── onboarding_resume_redirect_verification.dart         # guard redirect
└── ep02_phase_completion_checklist.dart                 # 21 criteria from EP-02:214-241

documents/Task-Implementation/EP-02/
└── EP-02-20-Trust-System-Verification-Report.md         # report (new)

# Reused (no new file, composed in VPs):
test/integration/finance/        # financial_profile_flow_test, conversion_flow_test, escrow_proxy_seam_test
test/integration/support/dispute_flow_test.dart
test/integration/verification/*  # existing kyc/trade/verification flow tests
test/integration/portfolio_public_profile_flow_test.dart
test/integration/onboarding_flow_integration_test.dart
test/support/onboarding/onboarding_test_support.dart
test/support/portfolio/portfolio_test_support.dart
```

`lib/` additions: **none by default**. Minimal wiring fixes touch at most `lib/app/app.dart`, `lib/app/router/route_guard.dart`, `lib/data/data_layer.dart` barrel re-exports if discovered.

### 5.3–5.17 Per-Validation-Point Integration Approach

Each VP follows the same composition pattern: `MockSupabaseClientFactory` with scripted `rpcHandlers` → real `Supabase*RemoteDataSource` → real `*RepositoryImpl` → real `*Provider` (ChangeNotifier under `Provider`) → real screens/widgets pumped via `widget_harness.dart` + `router_harness.dart`. `FakeStorageService` + `FakeConversionRateSource` where storage/rate is needed. Detailed scenarios:

#### VP1 — Full Onboarding Flow End-to-End (extends EP-02-18 TIP)

**Seams:** `entity_profile_update` (`20260821090004_entity_model_rpcs.sql:16-79`) + self-scoped `entity_profiles.avatar_path` update (`20260821090003:88`), `entity_profession_bind` (`20260821090004:202-257`), `TaxonomyProvider.loadIndustries/loadProfessions`, `IdentityVerificationService.submitIdentityDocument`, `TradeVerificationService.submitTradeProof`, `OnboardingService` ordering contract + `OnboardingProvider.loadProgress` resume, `RouteGuard._onboardingResumeRedirect` (`lib/app/router/route_guard.dart:184-213`), `OnboardingProgressStore` Hive/in-memory.

**Scenarios:** (a) fresh entity `!isComplete` at `/` → guard redirects to `RoutePaths.onboardingRouteFor(OnboardingStepCode.profile)` → wizard loops `profile→capability→industry→identityDocument→tradeProof→complete` with real route transitions, progress persisted per `advance()`; (b) exit at step 3 (trigger `OnboardingExitConfirmDialog` saveAndExit) → relaunch → resumes at `tradeProof` with steps 1-2 marked complete; (c) lifecycle `didChangeAppLifecycleState` pause saves progress; (d) avatar `StorageService.upload(bucket: profileAvatars, path: StoragePaths.avatar, upsert:true)` precedes RPC (5 MiB jpeg/png/webp validation). Fails if `entity_profession_bind` missing profession → `PLT004`.

#### VP2 — Taxonomy Browse → Select → Bind

**Seams:** `taxonomy_industries_list` / `taxonomy_professions_list` (`20260829090002_taxonomy_management_rpcs.sql:35,64`), `TaxonomyEnvelopeParser` (`lib/data/datasources/remote/taxonomy_envelope_parser.dart`), `TaxonomyProvider.selectedIndustry/selectedProfession` across navigation (`lib/data/providers/taxonomy_provider.dart:29`), `ProfessionRegistryBrowser` (`lib/workspace/profession_registry/widgets/profession_registry_browser.dart`), `entity_profession_bind`.

**Scenarios:** list industries → select → loadProfessions(industryId) → search via `filteredProfessions` (debounced) → select profession → bind RPC → provider `selectedProfession` survives navigation + `OnboardingProvider` resume; duplicate bind → `PLT005` conflict surfaces as inline guidance (no fire-hammer).

#### VP3 — Identity Verification Submit → Review → Approve → KYC Tier

**Seams:** `entity_credentials` + `verification_submissions` + `verification_reviews` + `verification_audit_trail` + `entity_kyc_levels↔kyc_tiers` (`20260829090003_verification_admin_review_schema.sql`), `VerificationRemoteDataSource`→`verification_submit` (`submission_type=identity_document`), `VerificationProvider`/`KycProvider` (`lib/data/providers/verification_provider.dart`, `kyc_provider.dart`), `KycService`/`KycLimitGuard`.

**Scenarios:** upload identity doc (5 `DocumentType`, 10 MiB jpeg/png/webp/pdf via `StoragePaths.credentialDocument`) → `verification_submit` pending → fake admin approves via `AdminReviewProvider` → `verification_status_get`/`kyc_level_get` reflects tier upgrade → `KycUpgradeScreen`/`VerificationStatusScreen` timeline updates. Exercises the same `SentryRecordingHarness` boundary as EP-01-20 VP6: submissions are logged via `HivorrLogger`+`PiiRedactor` with `entityId suffix` only.

#### VP4 — Trade Verification Submit → Admin Review → Bid-Lock Released

**Seams:** `entity_professions.trade_verification_status` gate (`20260821090004` bind lands `unverified`; `20260829090003` transitions `unverified→pending→approved/rejected`), `TradeVerificationService.submitTradeProof` (5 `TradeProofType`, `professionId`-bound), `TradeVerificationGate` (`lib/systems/verification/gate/trade_verification_gate.dart`), `TradeVerificationProvider`/`TradeVerificationStatus` (`lib/data/entities/trade_verification_status.dart`).

**Scenarios:** bind profession → submit trade proof → pending → admin approve → provider `tradeVerificationStatus==approved` → `TradeVerifiedBadge` + `trade_verification_gate` reports bidding unlocked; rejected path surfaces `rejection_reason` inline. Ensures client never writes gate columns (confirmed by `trust_financial_logic_scan`).

#### VP5 — KYC Level Upgrade → Limit Increase (server-enforced)

**Seams:** `entity_kyc_levels`, `kyc_tiers` (tier 0-3), `KycRepository`→`KycRemoteDataSource`→`KycEnvelopeParser`, `KycLimitGuard.isAllowed(amount)` pre-checks, `FinancialPayoutService` + `EscrowService` call limit enforcement before mutation.

**Scenarios:** current tier → fetch `limits_get` → attempt cashout above limit → blocked (client guard + server `PLT003`); after mocked tier upgrade → higher limits apply → same cashout succeeds; `KycLimitGuard`/`kyc_limits_card` render reflects tier.

#### VP6 — Financial Profile → Currency Accounts → Balances

**Seams:** `financial_profiles`, `financial_currency_accounts` (NGN/GHS/USD/GBP), `financial_balances` (available/held/pending), `FinancialRemoteDataSource`→`FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart`), `FinancialProvider`/`FinancialRepository` (`lib/data/providers/financial_provider.dart`).

**Scenarios:** create financial profile → request receiving accounts per currency → `financial_balances_get` returns per-currency balances → `FinancialProfileScreen` (`lib/systems/finance/screens/financial_profile_screen.dart`) renders `BalanceOverviewCard` + `CurrencyAccountCard` per currency; verified via `FakeFinancialRemoteDataSource` seeded with distinct-currency balances.

#### VP7 — Escrow Lifecycle (with Milestone + Audit)

**Seams:** `financial_escrow` (state machine `draft→funded→held→released/refunded/disputed`), `financial_escrow_milestones`, `financial_transactions` (double-entry), `financial_audit_trail`, `EscrowRemoteDataSource`→`EscrowRepository`→`EscrowProvider`→`EscrowService`, `RoutePaths.escrow`/`escrowDetail` (`lib/app/router/route_paths.dart:89-91`), `EscrowStatus`/`MilestoneListCard`.

**Scenarios:** create escrow with 2 `EscrowMilestoneInput` → `financial_escrow_create` → fund (via abstract gateway, see §9) → `financial_escrow_fund` → report milestone completion → request release → `financial_escrow_release` → balances derived correctly + immutable audit row present; partial-release edge case (`financial_escrow_milestone_release`); refund path; audited that no client computes amounts (server `financial_transactions` insert is sole mutator).

#### VP8 — Currency Conversion (preview→execute→balances)

**Seams:** `financial_conversions`, `financial_conversions_audit`, `ConversionRemoteDataSource` (`lib/data/datasources/remote/supabase_conversion_remote_data_source.dart`), `ConversionPreviewDto`→`ConversionMapper`, `ConversionProvider` (`lib/data/providers/conversion_provider.dart`), `ConversionRateSource` (`lib/systems/finance/services/conversion_rate_source.dart` + `test/support/fakes/fake_conversion_rate_source.dart`).

**Scenarios:** fetch available pairs (NGN↔GHS, NGN↔USD, NGN↔GBP) → preview `NGN→GHS` (rate + fees, server-validated) → execute → `financial_balances` updated atomically per currency (source debited, dest credited via double-entry) → history via `ConversionHistoryList`. Validates server rate, not client calculation.

#### VP9 — Bound Payout Account (bind → name enquiry → withdraw within limit)

**Seams:** `financial_payout_accounts` (bound, ownership-verified, `payout_account_status`), `financial_payouts`, `FinancialPayoutRemoteDataSource` (`lib/data/datasources/remote/supabase_financial_payout_remote_data_source.dart`), `PayoutAccountLocalStore` (`lib/data/local/payout_account_local_store.dart`), `FinancialPayoutService`/`FinancialPayoutProvider`, `NameEnquiryService` (`lib/integrations/payment_gateways/name_enquiry_service.dart`) → `NibssNameEnquiryAdapter` (`lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart`) + `PaystackGateway`/`FlutterwaveGateway` (`lib/integrations/payment_gateways/paystack_gateway.dart:NameEnquiry`), `KycLimitGuard`.

**Scenarios:** bind bank account (`bank_account_number_validator`) → name enquiry `accountNumber↔entity legalName` verify (mock `MockDioAdapter`) → bound account shows `PayoutAccountCard` verified chip → initiate withdrawal within `kyc_tiers.cashout_limit` → `withdrawal_result` success; over-limit → `PLT003` limit breach; unbound/withdrawal to unbound account blocked server-side. Uses `test/support/fakes/finance/*` pattern.

#### VP10 — Deposit Name-Matching (AGENT.md Rule 3)

**Seams:** `financial_deposits` (`payer_name` captured), `financial_deposits.name_match_status`, `FinancialDepositRemoteDataSource` (`lib/data/datasources/remote/supabase_financial_deposit_remote_data_source.dart`), `DepositNameMatchStatus` (`lib/systems/finance/models/deposit_name_match_status.dart`), `FinancialDepositService`.

**Scenarios:** record deposit with `payer_name == legal_name` (normalized) → server matcher returns `matched` → accepted; record with mismatched `payer_name` → `flagged`/`blocked` → `DepositNameMatchIndicator` renders flagged banner, webhook-equivalent hold is observable via `financial_deposits.status`. Verifies `legal_name` never leaves server except in redacted logs.

#### VP11 — Dispute Filing → Evidence → Resolution → Escrow Action

**Seams:** `dispute_cases`, `dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail` (`20260829120005_dispute_resolution_schema.sql` + `20260829120006_dispute_withdraw_definer.sql`), `SupabaseDisputeRemoteDataSource` (`lib/data/datasources/remote/supabase_dispute_remote_data_source.dart`) sealed via `DisputeEnvelopeParser` (`lib/data/datasources/remote/dispute_envelope_parser.dart`), `DisputeService` (`lib/systems/support/services/dispute_service.dart`)/`DisputeProvider` (`lib/data/providers/dispute_provider.dart`), `RoutePaths.disputes*` (`lib/app/router/route_paths.dart:93-99`).

**Scenarios:** file dispute linked to escrow (`dispute_file` → `case_status=open`) → verify escrow `status==held/disputed` (automatic hold) → submit evidence (private `credential-documents`-style path, `EvidenceAttachmentCard`) → resolve (service-role mock `dispute_resolve`) → escrow action per resolution: release to payee OR refund to payer → `dispute_audit_trail` + `financial_audit_trail` reflect action; `EscrowFrozenBanner`/`DisputeStatusBadge` render.

#### VP12 — Professional Profile Public Display (anon, SEO, responsive)

**Seams:** `portfolio_public_profile_get(p_entity_id uuid)` (`20260913090001_portfolio_public_profile.sql`: SECURITY DEFINER+STABLE, anon `GRANT EXECUTE`, approved-gate `PLT004`, whitelisted projection never `legal_name`/`document_path`), `PortfolioEnvelopeParser` (`lib/data/datasources/remote/portfolio_envelope_parser.dart`), `PortfolioProvider` (`lib/data/providers/portfolio_provider.dart`) + `ProfessionalProfileService` (`lib/systems/portfolio/services/professional_profile_service.dart`), `RoutePaths.publicProfileRoute`/`publicProfile()` + `RouteGuard._isPublicContentView` (`lib/app/router/route_guard.dart:215-216`), `ProfessionalProfileScreen` (`lib/systems/portfolio/screens/professional_profile_screen.dart`) + `ProfileHeaderCard`/`VerificationBadgesRow`/`CredentialCard`/`PortfolioGrid`, `portfolio_seo_meta.dart`.

**Scenarios:** anon GET `/p/:slug/:id` with approved entity → single RPC returns complete graph → renders `displayName` + avatar (public URL), profession/industry badges, KYC/identity badges, approved credentials (public-safe `kind/title` only), portfolio grid — at 390px and 1280px (`shared/layouts/`) without overflow; signed-out allowed, `PLT004` for unknown/inactive/not-approved renders `ProfileNotFoundState` with identical message (no oracle — verified against `supabase/tests/database/018_portfolio_public_profile.sql` negative asserts); SEO meta builder consumes `profession_slug`/`industry_name` (never `legal_name`).

#### Cross-Cutting Verification Scripts (mirrors `test/integration/verification/` EP-01-20 pattern)

| Script | Replaces/Extends | Lenses |
|---|---|---|
| `trust_financial_logic_scan_verification.dart` | new | Walks `lib/` scanning `balance`, `amount`, `total`, `fee`, `escrow_split`, `conversion_rate` mutation patterns inside `lib/systems/`, `lib/data/` (excluding `lib/integrations/payment_gateways/` adapters where rate *fetch* is allowed) — **zero** client-side financial arithmetic expected. |
| `trust_legal_name_document_scan_verification.dart` | new | `grep -rn "legal_name\|document_path" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart` → 0; anon table SELECT on `portfolio_items`/`entity_credentials` still rejected (mirrors `018` pgTAP negative). |
| `trust_theme_token_scan_verification.dart` | new (replaces `secret_scan` token check) | Walks `lib/systems/portfolio/`, `lib/systems/onboarding/`, `lib/systems/finance/`, `lib/systems/verification/`, `lib/systems/support/` asserting no `Colors.*`, `Color(0xFF`, `fontFamily:` (AGENT.md Rule 5); all widgets use `Theme.of(...).colorScheme/textTheme/AppThemeExtension`. |
| `trust_storage_posture_verification.dart` | re-runs `017`+`018` lens | Private `credential-documents` requires signed URL (private, 10 MiB, jpeg/png/webp/pdf), public `profile-avatars`/`portfolio-items` public read (validated via `supabase/tests/database/017_storage_posture.sql` asserts). |
| `trust_gateway_abstraction_verification.dart` | new | No file in `lib/systems/` or `lib/data/` imports `lib/integrations/payment_gateways/paystack_gateway.dart` or `flutterwave_gateway.dart` directly — only `payment_gateway.dart` abstract + factory (`lib/integrations/payment_gateways/payment_gateway_factory.dart` boundary). |
| `ep02_phase_completion_checklist.dart` | `phase_completion_checklist.dart` | Structured checklist for each `EP-02:214-241` criterion, same `EP-01-20 §5.18` style (map criterion→evidence→pass/fail). |

### 5.18 Minimal Wiring Fixes Strategy

| Gap Type | Fix Location | Example |
|---|---|---|
| Missing provider registration | `lib/app/app.dart` or `lib/data/data_layer.dart:register*Layer` | Add `ChangeNotifierProvider<ConversionProvider>` or `DisputeProvider` to `MultiProvider`; wire `registerPortfolioLayer`/`registerDisputeLayer` in `HivorrApp` |
| Missing initialization | `lib/app/app_bootstrap.dart` or `lib/data/data_layer.dart` | Add `initialize*()` call order respecting `apiLayer → auth → taxonomy → verification → finance → support → portfolio` |
| Router missing route/guard | `lib/app/router/app_router.dart` + `route_paths.dart` + `route_guard.dart` | Register `finance`, `escrow`, `convert`, `disputes*`, `publicProfile` GoRoutes; ensure `_onboardingResumeRedirect` + `_isPublicContentView` covers new trust routes |
| Missing barrel export | Module barrel `lib/systems/*/finance.dart` etc. | Add export so integration test import resolves |

**Constraint:** wiring only. No system logic, no business rules, no `supabase/migrations` edits.

### 5.19 Trust System Verification Report (mirrors `EP-01-20-Foundation-Verification-Report.md:350-364`)

Report documents:

| Section | Content |
|---|---|
| Executive Summary | Overall pass/fail, critical issues, EP-03 readiness verdict (GO / NO-GO) |
| Validation Point Results (VP1-VP12) | Pass/fail per VP + evidence (test name, assertions exercised, fake seams used) |
| Cross-Cutting Verification Results | secret scan, financial-logic scan, legal/doc scan, theme-token scan, storage posture, gateway abstraction boundary, onboarding resume redirect, phase completion checklist |
| Environment / Platform Notes | Delegates to EP-01-20 report (env isolation + cross-platform already validated); notes any delta |
| Issues Discovered | Integration gaps found, severity (trust/financial/security vs harness) |
| Remediation Actions | Fixes applied to `lib/app/` / `lib/data/data_layer.dart`, re-validation results |
| EP-03 Readiness Checklist | Structured assessment of each trust capability EP-03 depends on (verified entities, taxonomy, financial integrity, escrow, dispute, public trust display) |
| Recommendations | Outstanding items for EP-03+ (e.g., CI size gate, live webhook Edge Function, admin RBAC hardening) |

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility | Action |
|---|---|---|---|
| VP1 onboarding trust flow | `test/integration/trust/onboarding_trust_flow_integration_test.dart` | 5-step wizard + resumability + guard redirect | **Create** — §5.3 |
| VP2 taxonomy browse/bind | `test/integration/trust/taxonomy_browse_bind_integration_test.dart` | Registry browse + bind + dedup | **Create** |
| VP3 identity flow | `test/integration/trust/identity_verification_flow_integration_test.dart` | Identity submit → admin approve → KYC tier | **Create** |
| VP4 trade gate | `test/integration/trust/trade_verification_gate_integration_test.dart` | Trade proof → bid-lock release | **Create** |
| VP5 KYC→limits | `test/integration/trust/kyc_level_limit_integration_test.dart` | Tier upgrade drives limit increase | **Create** |
| VP6 financial profile | `test/integration/trust/financial_profile_flow_integration_test.dart` | Profile + currency accounts + balances | **Create** |
| VP7 escrow lifecycle | `test/integration/trust/escrow_lifecycle_integration_test.dart` | Escrow+milestones+audit | **Create** |
| VP8 conversion | `test/integration/trust/conversion_flow_integration_test.dart` | Preview→execute→balances | **Create** |
| VP9 payout + name enquiry | `test/integration/trust/payout_account_flow_integration_test.dart` | Bound payout + KYC limits + NIBSS | **Create** |
| VP10 deposit Rule 3 | `test/integration/trust/deposit_name_match_integration_test.dart` | Payer==legal_name matching | **Create** |
| VP11 dispute→escrow | `test/integration/trust/dispute_escrow_integration_test.dart` | Dispute filing→resolve→escrow hold/release | **Create** |
| VP12 public profile | `test/integration/trust/public_profile_integration_test.dart` | Anon RPC + SEO + responsive | **Create** |
| Cross-cutting scripts | `test/integration/verification/trust_*` + `ep02_phase_completion_checklist.dart` | Scans + posture + checklist | **Create** — §14 |
| Trust System Verification Report | `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md` | Comprehensive validation results | **Create** |
| Minimal wiring fixes | `lib/app/` + `lib/data/data_layer.dart` | Bootstrap / provider / router glue only | **Conditional Update** |
| Reused EP-01-19/EP-02 infrastructure | `test/support/fakes/*`, `factories/mock_supabase_client_factory.dart`, `harnesses/*`, `builders/*`, `matchers/*`, existing `test/integration/finance/*`, `test/integration/support/*`, `test/integration/verification/*`, `test/support/onboarding/*`, `test/support/portfolio/*` | Mock composition, harness, builders, matchers | **Reuse** |
| Frozen server surfaces | `supabase/migrations/*`, `supabase/tests/database/001-022` | RLS/RPC/bucket contracts | **No change** (validated) |

No new dependencies. All tests use `flutter_test` + existing test infrastructure.

---

## 7. Data Requirements

- All integration tests use EP-01-19 builders (`EntityProfileBuilder`, `FinancialProfileBuilder`, `EscrowBuilder`, `DisputeCaseBuilder` in `test/support/builders/`) + portfolio/onboarding test support (`test/support/portfolio/portfolio_test_support.dart`, `test/support/onboarding/onboarding_test_support.dart`) with **placeholder values only** — no real PII, no real legal names, no real account numbers (bank numbers use `0000000000`-style placeholders validated by `bank_account_number_validator`).
- No real Supabase connections, no real Paystack/Flutterwave/NIBSS network calls. Gateway calls intercepted via `MockDioAdapter` (`test/support/mocks/mock_dio_adapter.dart`) seeded with scripted JSON (Paystack `transferrecipient`/`transfer`, Flutterwave `transfers`, NIBSS `nameEnquiry` responses) matching `lib/integrations/payment_gateways/models/` shapes.
- `OnboardingProgress` persistence uses `InMemoryOnboardingProgressStore` + temp-dir `HiveOnboardingProgressStore` (`test/unit/data/onboarding/onboarding_progress_store_test.dart` precedent) — no live Hive box cross-contamination.
- Trust System Verification Report contains factual pass/fail and test output summaries — no sensitive data, no `legal_name`/`document_path`, no credential bytes.
- No business/financial/escrow domain data is persisted to a live database; all mutations remain in `FakeSupabaseClient` in-memory handlers.

---

## 8. Database Considerations

**No direct schema changes by this task.** `supabase/migrations/` remains untouched. `supabase/tests/database/` suite (`001_rls_leakage_matrix.sql` through `022_manage_user.sql`) stays green and is the authoritative server-side posture proof.

**Integration contract verified client-side:** EP-02-20 validates that client code correctly invokes RPCs through the abstract seams and processes `{success,code,message,data}` envelopes via `*EnvelopeParser` (`taxonomy_envelope_parser.dart`, `financial_envelope_parser.dart`, `portfolio_envelope_parser.dart:success PLT000→domain, PLT003 validation, PLT004 not found, PLT005 conflict`) and `DataExceptionMapper`. Server-side enforcement (RLS policies, RPC logic, `SECURITY DEFINER` scoping, `platform_raise_error` codes) remains the responsibility of `supabase/tests/database/` + `database-rls-tests.yml` workflow (AGENT.md Rule 4).

Specifically re-audited (not modified):

| Table / RPC | Migration | Client path exercised |
|---|---|---|
| `entity_professions.trade_verification_status` gate, `entity_profession_bind` | `20260821090004_entity_model_rpcs.sql:202-257` | `OnboardingService.bindProfession`, `TradeVerificationService` |
| `taxonomy_*_list` public reads | `20260829090002_taxonomy_management_rpcs.sql` | `TaxonomyProvider` |
| `verification_submissions`/`verification_reviews`/`entity_kyc_levels↔kyc_tiers` + `verification_submit/review/status/limits` | `20260829090003_verification_admin_review_schema.sql` | `VerificationProvider`/`KycProvider` |
| `financial_profiles/currency_accounts/balances/transactions/escrow(+milestones)/payout_accounts/payouts/deposits/conversions/audit_trail` + all `financial_*` RPCs (atomic, double-entry, server-side balance mutation) | `20260829100004_financial_integrity_schema.sql` + `014_financial_rpc_enforcement.sql` | `FinancialProvider`/`EscrowProvider`/`ConversionProvider`/`FinancialPayoutProvider`/`FinancialDepositProvider` |
| `dispute_cases/evidence/resolutions/audit_trail` + `dispute_file/submit_evidence/resolve` + `20260829120006_dispute_withdraw_definer.sql` scoping | `20260829120005/06_dispute_resolution_schema.sql` | `DisputeProvider`/`SupabaseDisputeRemoteDataSource` |
| `portfolio_items` + `portfolio_public_profile_get(uuid)` SECURITY DEFINER+STABLE, anon EXECUTE, whitelisted columns, `PLT004` non-oracle | `20260913090001_portfolio_public_profile.sql` | `PortfolioProvider`/`ProfessionalProfileService` |
| `onboarding_authoritative_state` Hive↔server authoritative-state seam | `20260915090001_onboarding_authoritative_state.sql` + `019_onboarding_authoritative_state.sql` | `OnboardingProvider`↔`EntryStateStore` |
| Storage buckets + RLS (`credential-documents` private, `profile-avatars`/`portfolio-items` public) | `20260830100001_storage_buckets.sql` | `StorageService`/`StoragePaths` |

Where a VP needs seeded trust state (e.g., an approved entity for VP12, a funded escrow for VP11), the fake Supabase handler seeds in-memory rows mirroring the real schema columns — never via a live migration.

---

## 9. API Requirements

**No new API endpoints or RPCs.** Integration tests exercise existing EP-02 API surface through the established abstraction layers:

| Operation | Seam | Client path | Error→ApiExceptionKind (via `lib/core/api/api_exception_mapper.dart`) |
|---|---|---|---|
| Taxonomy browse | `taxonomy_industries_list`, `taxonomy_professions_list` | `SupabaseTaxonomyRemoteDataSource` → `TaxonomyEnvelopeParser` | `PLT003` validation, `PLT004` not found |
| Profile update + bind | `entity_profile_update`, `entity_profession_bind`, self-scoped `entity_profiles` REST | `SupabaseEntityRemoteDataSource` + `OnboardingService` | `PLT003` length, `PLT004` inactive/missing, `PLT005` duplicate |
| Identity/trade submit | `verification_submit(p_credential_id, p_submission_type)` | `IdentityVerificationService`/`TradeVerificationService`→`SupabaseVerificationRemoteDataSource`/`SupabaseTradeVerificationRemoteDataSource` | `PLT005` active-exists |
| Admin review | `verification_review_approve/reject`, `verification_status_get`, `kyc_level_get`, `verification_limits_get` | `SupabaseAdminReviewRemoteDataSource`→`AdminReviewProvider` | `PLT001` auth, `PLT004` queue |
| Financial | `financial_profile_create`, `financial_currency_account_request`, `financial_balances_get`, `financial_escrow_create/fund/release/refund`, `financial_payout_*`, `financial_deposit_record/name_match`, `financial_conversion_preview/execute` | `SupabaseFinancialRemoteDataSource`/`SupabaseEscrowRemoteDataSource`/`SupabaseConversionRemoteDataSource`/`SupabaseFinancialPayoutRemoteDataSource`/`SupabaseFinancialDepositRemoteDataSource` + envelope parsers | `PLT003` validation, `PLT004`, `PLT005` insufficient balance, limit breach |
| Dispute | `dispute_file`, `dispute_submit_evidence`, `dispute_resolve`, `dispute_get/list` | `SupabaseDisputeRemoteDataSource`→`DisputeEnvelopeParser` | `PLT003`, `PLT004` escrow not found |
| Public profile | `portfolio_public_profile_get(p_entity_id uuid)` | `SupabasePortfolioRemoteDataSource`→`PortfolioEnvelopeParser` | `PLT003` null, `PLT004` not approved (identical message — no oracle) |
| Payment abstraction | `PaymentGateway.initializePayment/verifyPayment/createTransfer/verifyTransfer` + `NameEnquiryService.enquire` | `PaystackGateway`/`FlutterwaveGateway` + `NibssNameEnquiryAdapter` via `PaymentGatewayFactory` (`lib/integrations/payment_gateways/payment_gateway_factory.dart`) — intercepted via `MockDioAdapter` | Gateway `PLT999` mapped to `serverError` |

No live HTTP. All calls intercepted in-memory via `MockSupabaseClientFactory` `rpcHandlers` + `MockDioAdapter` scripted responses.

---

## 10. User Interface Requirements

No new UI screens or widgets are created. Design-system + trust-screen integration is **validated**, not invented:

| Screen/Widget validated | Route | Rendering verified | Key assertions |
|---|---|---|---|
| `OnboardingShellScreen` + `ProfileSetupScreen` + `IndustryProfessionSelectionScreen` + `IdentityVerificationStepScreen` + `TradeProofStepScreen` + `OnboardingCompleteScreen` | `RoutePaths.onboarding*` (`lib/app/router/route_paths.dart:66-83`) — private, auth-required via `RouteGuard` | Shell hosts `OnboardingProgressIndicator` + `IndexedStack` step body + CTA bar; `ProfileSetupScreen` legal/display (≤255)+bio(≤5000) counters + `OnboardingAvatarPicker`→`HivorrAvatar`; profession step reuses `ProfessionRegistryBrowser` | Providers notify, router guard resume, theme tokens (no hardcoded colors) |
| `IdentityDocumentUploadScreen` + `TradeProofUploadScreen` + `VerificationStatusScreen` + `KycStatusScreen` + `KycUpgradeScreen` + `AdminReviewQueueScreen`/`AdminReviewDetailScreen` | `RoutePaths.verificationIdentity/verificationStatus/tradeProofUpload/tradeVerificationStatus/adminReviewQueue/adminManageUserDetail/kycStatus/kycUpgrade` | `DocumentTypePicker`/`TradeProofTypePicker`, `LinearProgressIndicator` `onProgress`, `VerificationTimeline`/`TradeVerificationTimeline`, `TradeVerifiedBadge`, `KycLevelCard`/`KycLimitsCard` | Status propagation, timeline ordering, badge variants |
| `FinancialProfileScreen` + `FinancialProfileCreationFlow` + `EscrowListScreen`/`EscrowDetailScreen` + `ConversionScreen` + `PayoutAccountView`/`PayoutWithdrawFormView` + `DepositDetailsPanel` | `RoutePaths.finance/financeCreate/escrow/escrowDetail/convert` | `BalanceOverviewCard`, `CurrencyAccountCard`, `EscrowCard`+`EscrowStatusBadge`+`MilestoneListCard`+`EscrowWriteCtaPanel` (when disallowed), `ConversionPairSelector`/`ConversionPreviewCard`/`ConversionResultCard`, `PayoutAccountCard`+`PayoutAccountLimitDisplay`, `DepositNameMatchIndicator` | Per-currency balances, escrow states, conversion fees, limit-gated withdraw |
| `DisputeFilingScreen` + `DisputeEvidenceFormScreen` + `DisputeListScreen` + `DisputeDetailScreen` | `RoutePaths.disputes/disputesNew/disputeDetail/disputesEvidenceNew` | `DisputeStatusBadge`, `EscrowFrozenBanner`, `EvidenceAttachmentCard` (private-path only) | Filing linked to escrow, evidence attachment, frozen banner when disputed |
| `ProfessionalProfileScreen` | `RoutePaths.publicProfileRoute` (`/p/:slug/:id`) — **public**, guard-bypassed (`lib/app/router/route_guard.dart:215-216`) | `ProfileHeaderCard` (`HivorrAvatar`), `VerificationBadgesRow`, `CredentialCard` list (approved only), `PortfolioGrid` (responsive `shared/layouts/` 16dp mobile / 24dp web) | Approved-gate, whitelisted columns only (never `legal_name`), SEO meta from `portfolio_seo_meta.dart`, anon reads RPC only |

All UI assertions run through `widget_harness.dart` `pumpApp` + `router_harness.dart` with viewport 390px (mobile) and 1280px (web), per AGENT.md Rule 5 (tokens from `Theme.of(context).colorScheme`/`textTheme`/`AppThemeExtension`, never `Colors.*`/`Color(0xFF`/`fontFamily:`).

---

## 11. User Experience Considerations

**Developer/operator experience:**
- 12 focused integration tests expose the exact seam where a trust composition breaks (e.g., `VP7 escrow release after VP11 dispute resolve` pinpoints double-entry vs state-machine faults) instead of surfacing as opaque EP-03 marketplace failures.
- Verification scripts are re-runnable in CI as regression gates; the `ep02_phase_completion_checklist.dart` checklist becomes the auditable artefact attached to the phase-close PR.
- Trust System Verification Report reuses the EP-01-20 report template (`EP-01-20-Foundation-Verification-Report.md:350-364`), so reviewers compare like-for-like across phases.

**End-user experience (what is being validated):**
- New entities reach productivity in one coherent 5-step wizard without hunting separate screens, and can exit/resume reliably (progress persisted per `advance()` + lifecycle `pause`).
- Trust signals are instant and server-truthful: identity/trade badges, KYC tier, per-currency balances, escrow milestones, and portfolio credentials reflect verified state — unverified pros still have dashboard access but bidding remains locked (Rule 2) until `approved`.
- Financial trust is tangible: escrow protects funds (milestone-gated release, dispute-frozen until resolved), withdrawals only to bound pre-verified accounts within KYC limits, deposits flagged when `Payer Name != legal_name`.
- Public trust display is discoverable and shareable (`/p/:profession_slug/:entity_id` SEO URL), responsive on mobile and web, without ever surfacing `legal_name` or private evidence.

---

## 12. Security Considerations

| Risk | Required Control | Verified by |
|---|---|---|
| Integration tests exposing `legal_name`/`document_path` | Tests use placeholder display names only; private-table grants remain `REVOKE ALL FROM anon, authenticated` (see §8); public reads via whitelisted RPC only; `PiiRedactor` redacts logs to `entityId suffix` | `trust_legal_name_document_scan_verification.dart` + `supabase/tests/database/018` negative `jsonb_path_exists` asserts re-run |
| Anon escalation via mis-granted SELECT on trust tables | Default-deny preserved; new migration count `git diff --stat supabase/migrations/` = 0; anon has no `SELECT/INSERT/UPDATE/DELETE` on `portfolio_items`, `entity_credentials`, `verification_submissions`, `financial_*`, `dispute_*` (001-022 RLS audits) | `trust_storage_posture_verification.dart` + `supabase db test` |
| Public profile oracle leaking which entity exists vs why hidden | `portfolio_public_profile_get` returns identical `PLT004` for unknown/inactive/zero-approved-profession (per §5.12 implementation) | `018_portfolio_public_profile.sql:23-29` behavior asserts + VP12 widget `ProfileNotFoundState` |
| Financial logic leak into client | Double-entry + fee/rate arithmetic must not appear in `lib/systems/` or `lib/data/` (adapters excepted); escrow state is provider-agnostic, not gateway-driven | `trust_financial_logic_scan_verification.dart` string/regex walk |
| Direct Paystack/Flutterwave/NIBSS calls from business logic | Business logic imports only `payment_gateway.dart` abstract (`lib/integrations/payment_gateways/payment_gateway.dart`) via `payment_gateway_factory.dart`; provider adapters live only in `lib/integrations/payment_gateways/` | `trust_gateway_abstraction_verification.dart` import scan |
| Gateway webhook forgery / name-enquiry spoof | Gateway adapters verify `X-Paystack-Signature`/`Flutterwave signature` in server/webhook tests (`payment_gateway_transport_test.dart`); NIBSS name enquiry verified via `NibssNameEnquiryAdapter` with bearer auth rotation | `VP9` `MockDioAdapter` signature path + `supabase/tests/database/014_financial_rpc_enforcement.sql` server matcher test |
| `service_role` string in client | Forbidden | `grep -rn "service_role" lib/` = 0 (gate in `trust_legal_name_document_scan_verification.dart` + `flutter analyze` lens) |
| Hardcoded secrets / gateway tokens | Tests use placeholder env values only; `.gitignore` covers `.env*` | `secret_scan_verification.dart` (re-run from EP-01-20 VP10: private-key + 20-char `*.supabase.co` + multi-segment JWT + secret-typed literal scan, 0 findings expected) |
| Wiring fixes introducing bypass | Fixes limited to init order/provider registration/router guard; no business logic, no RLS/RPC column writes, no `trade_verification_status` mutation | Diff review: only `lib/app/` + `lib/data/data_layer.dart` wiring (if any) |
| Cross-env contamination in trust flows | Trust flows never connect to live Supabase; `EnvironmentLoader` validation already passed at EP-01-20 and is re-checked by `ep02_phase_completion_checklist.dart` criterion | `environment_isolation_integration_test.dart` (EP-01-20) + no new live connects |

---

## 13. Performance Considerations

- Integration suite is heavier than unit tests. Estimated: **12 VPs × ~8s + 7 verification scripts × ~3s ≈ 2–3 min** for `flutter test test/integration/trust/`. Full project `flutter test` remains within the existing CI 20-minute timeout (EP-01-20 `flutter test` = 682 tests, 0 failures; EP-02-20 adds ~90-120 integration assertions, total project ~800).
- `MockSupabaseClientFactory` + `MockDioAdapter` + `Fake*RemoteDataSource` provide fast in-memory simulation — no network latency, no real storage I/O. Hive stores use temp-dir or in-memory fallback per test (same as `test/unit/data/onboarding/onboarding_progress_store_test.dart`).
- Verification scripts are file-system walks (sub-second to ~10s each) — run as `flutter test` verification tests or as `dart` scripts under `test/integration/verification/` and do not add widget pump cost.
- `PerformanceTracer` spans introduced for trust flows (`onboarding.*`, `portfolio.public_profile.load`, `finance.escrow.*`, `finance.conversion.*`, `support.dispute.*`) remain sampled via `MonitoringConfig` — no overhead when disabled.
- No new dependencies → zero impact on the 15–20 MB installer target (re-reported in the Trust System Verification Report along with the EP-01-20 `app_size_verification.dart` estimate for continuity).

---

## 14. Testing Strategy

### 14.1 Per-VP Integration (12 points — each VP: compose real objects, pump real widgets, assert end state)

| VP | File | Min assertions | Core asserts |
|---|---|---|---|
| 1 | `onboarding_trust_flow_integration_test.dart` | 8 | fresh→wizard loop completes all 5 steps → `OnboardingCompleteScreen` HivorrSuccessState; exit@step3→resume@same step; `notifyListeners` per advance; guard redirect home→resume, complete→home |
| 2 | `taxonomy_browse_bind_integration_test.dart` | 6 | industries listed → profession search filtered → bind succeeds → `TaxonomyProvider.selectedProfession` survives route pop; duplicate shows `PLT005` guidance |
| 3 | `identity_verification_flow_integration_test.dart` | 6 | identity doc upload (onProgress) → `verification_submit` pending → admin approve → `KycProvider.tier` upgraded |
| 4 | `trade_verification_gate_integration_test.dart` | 6 | trade proof bound to profession → pending → approve → `TradeVerificationStatus.approved` → `TradeVerifiedBadge` unlocked copy |
| 5 | `kyc_level_limit_integration_test.dart` | 6 | current limits fetched → over-limit blocked by `KycLimitGuard` → upgraded tier lifts limit → `KycLimitsCard` reflects |
| 6 | `financial_profile_flow_integration_test.dart` | 8 | financial profile create → 2 currency accounts → `financial_balances_get` → `BalanceOverviewCard` per currency correct |
| 7 | `escrow_lifecycle_integration_test.dart` | 10 | escrow with 2 milestones → funded → milestone→release → `financial_transactions` double-entry + `financial_audit_trail` row; partial-release & refund variants |
| 8 | `conversion_flow_integration_test.dart` | 6 | available pairs → preview (rate+fees) → execute → source debited/dest credited atomically → history entry |
| 9 | `payout_account_flow_integration_test.dart` | 8 | bind account → NIBSS name enquiry mocked → verified → withdraw within limit succeeds, over-limit blocked → `PayoutAccountLimitDisplay` |
| 10 | `deposit_name_match_integration_test.dart` | 6 | matching payer accepted → mismatched flagged → `DepositNameMatchIndicator` variant |
| 11 | `dispute_escrow_integration_test.dart` | 10 | file linked to escrow → escrow frozen → evidence submit → resolve→release vs refund branches → `EscrowFrozenBanner` + audit trail |
| 12 | `public_profile_integration_test.dart` | 12 | anon `/p/slug/id` → single RPC renders badges+grid @390 and 1280; signed-out allowed; `PLT004`→not-found; SEO meta never `legal_name` |

≥86 trust integration assertions. Each VP also asserts envelope normalization: `PLT000`→domain entity, `PLT003`→inline field error, `PLT004`→not-found, `PLT005`→conflict guidance, `PLT999`→retry state — never raw Supabase/Dio exceptions escaping `*RemoteDataSource`→`DataExceptionMapper`.

### 14.2 Widget-Through Verification (embedded in VPs)

- Viewport 390px + 1280px via `widget_harness.dart` (`HivorrResponsiveScaffold`).
- Branded 4-states (`HivorrLoadingState` wrapping `HivorrLoader` pulse `VISUAL-IDENTITY.md:148`, never raw `CircularProgressIndicator`).
- `ProfileHeaderCard` avatar via `StorageService.getPublicUrl` (public bucket); credential/escrow/dispute evidence uses signed URL path only.

### 14.3 Verification Scripts — `test/integration/verification/` (7 scripts)

| Script | Lens | Pass condition |
|---|---|---|
| `trust_financial_logic_scan_verification.dart` | Regex walk `lib/systems/` + `lib/data/` (excluding `lib/integrations/payment_gateways/` adapters) for `amount\s*[\+\-\*\/]` / `balance\s*=` mutations | 0 hits |
| `trust_legal_name_document_scan_verification.dart` | `legal_name` absent from `lib/systems/portfolio/` + `lib/data/providers/portfolio_provider.dart`; `document_path` absent from public projection; `grep -rn "service_role" lib/` = 0 | 0 hits |
| `trust_theme_token_scan_verification.dart` | No `Colors.` / `Color(0xFF` / `fontFamily:` in `lib/systems/{onboarding,verification,finance,support,portfolio}/` | 0 hits |
| `trust_storage_posture_verification.dart` | `credential-documents` private / `profile-avatars`+`portfolio-items` public (+ size/MIME constraints 5/10 MiB, jpeg/png/webp/pdf) | Matches `storage_config.dart:39,66,97` + `017/018` pgTAP |
| `trust_gateway_abstraction_verification.dart` | No import of `paystack_gateway.dart`/`flutterwave_gateway.dart` in `lib/systems/` or `lib/data/` | 0 hits |
| `onboarding_resume_redirect_verification.dart` | `RouteGuard.redirectResolver` home→resume, complete→home, `exited` flag honors home, `currentStep==null` no redirect | Guards pass via `route_guard_test.dart` pattern |
| `secret_scan_verification.dart` (re-run) | Private-key + 20-char supabase project ref + multi-segment JWT + secret-typed literal scans over `lib/` + `test/` | 0 genuine findings |
| `ep02_phase_completion_checklist.dart` | 21 EP-02 `EP-02:214-241` criteria → evidence → PASS/FAIL | All 21 PASS |

### 14.4 Server-Side Regression (no `supabase/` change, but re-run gates)

| Gate | Command / Assertion |
|---|---|
| DB suite | `supabase db test` — `001-022` green (RLS, RPC, taxonomy integrity/seed, verification posture, financial posture, dispute posture, storage posture, portfolio, onboarding authoritative state, super_admin, admin_review, manage_user) |
| New integration gate | `supabase db test --test-file 018_portfolio_public_profile.sql` anon whitelist + `PLT004` non-oracle negatives |
| Full client suite | `flutter test` — all unit + widget + 12 new integration + existing trust integration green |

### 14.5 Scope Validation

Diff review: only `test/integration/trust/` (new), `test/integration/verification/trust_*` + `ep02_phase_completion_checklist.dart`, `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md`, and minimal `lib/app/` + `lib/data/data_layer.dart` wiring (if any). No `supabase/migrations` change, no new dependency (`pubspec.yaml` diff = 0), no `ARCHITECTURE.md`/`AGENT.md`/phase-document edit.

---

## 15. Recommended Implementation Sequence

1. **Audit EP-02 deliverables** — catalog EP-02-01..19 `Completed` status; read `supabase/migrations/` list (22 files) + `001-022` pgTAP to confirm frozen server contract; snapshot `lib/systems/{onboarding,verification,finance,support,portfolio}`, `lib/integrations/payment_gateways/`, `lib/data/` public interfaces for test composition.
2. **Inspect `lib/app/app.dart` + `app_bootstrap.dart` + `lib/data/data_layer.dart:register*Layer` + `lib/app/router/app_router.dart` + `route_guard.dart`** — verify all 19 systems' providers are registered in `MultiProvider`, initialization order respects `apiLayer→auth→taxonomy→verification→kyc→finance→support→portfolio`, and GoRoutes for `onboarding`, `finance/escrow/convert`, `support/disputes*/`, `/p/:slug/:id` exist with correct guarding. Document gaps.
3. **Apply minimal wiring fixes** — if missing, add the absent registration/init/route/guard seam in the files above only (step 2). No system-logic edit.
4. **Implement `trust_financial_logic_scan_verification.dart` + `trust_legal_name_document_scan_verification.dart` + `trust_gateway_abstraction_verification.dart`** — fast scans that gate all other VPs.
5. **Implement VP2 taxonomy** (`taxonomy_browse_bind_integration_test.dart`) — foundational registry wiring before flows that bind professions.
6. **Implement VP3 + VP4 verification flows** (identity then trade) — extend existing `verification_flow_test.dart`/`trade_verification_flow_test.dart` patterns with real provider→widget composition.
7. **Implement VP5 kyc→limits** — extend `kyc_flow_test.dart`.
8. **Implement VP6 financial profile** — extend `financial_profile_flow_test.dart`.
9. **Implement VP7 escrow lifecycle** — extend `escrow_proxy_seam_test.dart` with 2-milestone + partial/release/refund variants.
10. **Implement VP8 conversion** — extend `conversion_flow_test.dart` (preview→execute→balances atomicity).
11. **Implement VP9 payout + VP10 deposit name-match** — new bound-payout and Rule 3 pair (share `KycLimitGuard` + NIBSS mock).
12. **Implement VP11 dispute→escrow** — extend `dispute_flow_test.dart` with frozen/release/refund branches and evidence attachment.
13. **Implement VP1 onboarding full wizard** — composes VP2-4 seams; validates resume + progress store + guard redirect end-to-end.
14. **Implement VP12 public profile** — extend `portfolio_public_profile_flow_test.dart` with anon+S EO+responsive (390/1280) asserts.
15. **Implement remaining verification scripts** (`trust_storage_posture`, `trust_theme_token_scan`, `onboarding_resume_redirect_verification`, `ep02_phase_completion_checklist`).
16. **Run `flutter analyze`** — 0 issues.
17. **Run `supabase db test`** — `001-022` all green; confirm `git diff --stat supabase/migrations/` = 0.
18. **Run `flutter test test/integration/trust/`** — all 12 VPs green.
19. **Run `flutter test test/integration/verification/trust_*` + `ep02_phase_completion_checklist`** — all pass, grep lenses 0 hits.
20. **Run full `flutter test`** — unit + widget + existing integration + new trust integration green; re-run verification scripts as tests.
21. **Trigger CI equivalence** — confirm `pr-validation.yml` (lint + analyze + test + build) would pass; build stage delegated to CI per EP-01-20 precedent.
22. **Remediate any VP failures** — if a VP reveals a wiring gap, fix under §5.18 and re-run from step 16.
23. **Generate `EP-02-20-Trust-System-Verification-Report.md`** — document per-VP pass/fail + evidence, cross-cutting scan results, issues (§5.19), EP-03 readiness checklist.
24. **Final scope + lint + grep review:** `git diff --stat supabase/` = 0; `grep -rn "service_role" lib/` = 0; `grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart` = 0; no `Colors.|Color(0xFF|fontFamily:` in trust widgets; no `PaystackGateway` direct import in `lib/systems/`.
25. **Self-review DoD checklist (§16)** — all criteria checked, report attached to PR.
26. **Stop at the approval gate** — do not begin EP-03.

---

## 16. Expected Outcome

- **12 integration tests** (≈86+ assertions) proving the full trust stack interoperates: onboarding→taxonomy→identity/ trade verification→KYC→financial profile→escrow lifecycle→conversion→bound payout + name enquiry→deposit Rule 3→dispute→public trust display.
- **7 verification scripts** confirming no client financial logic, no `legal_name`/`document_path` leakage, Rule 5 design-token compliance, storage posture, payment-gateway abstraction boundary, onboarding resume redirect, and EP-02 phase-completion checklist (21 criteria).
- **Minimal wiring fixes** (if any) in `lib/app/` + `lib/data/data_layer.dart` only — no server surface change, no new migration.
- **Trust System Verification Report** with per-VP pass/fail, cross-cutting results, issues discovered and remediation, and a `GO`/`NO-GO` EP-03 readiness verdict.
- **`flutter analyze` + `flutter test` + `supabase db test` all green; no `supabase/migrations` diff; EP-02 ready to mark `Completed` and unblock EP-03.
- **Regression baseline** established: trust integration suite + verification scripts become the EP-02+ regression gate (same role as EP-01-20 suite).

---

## 17. Definition of Done (DoD)

### VP1 — Full Onboarding Flow
- [ ] **DoD-VP1a:** Fresh entity at `/` is guard-redirected to `RoutePaths.onboardingRouteFor(currentStep)`; 5-step wizard (`profile→capability→industry→identityDocument→tradeProof→complete`) completes with real route transitions and `OnboardingCompleteScreen` trust-loop education panel.
- [ ] **DoD-VP1b:** Exit via `OnboardingExitConfirmDialog` + relaunch resumes at same step (`OnboardingProgressStore` Hive key `onboarding_progress:{entityId}` + lifecycle `pause` save).

### VP2 — Taxonomy
- [ ] **DoD-VP2:** `taxonomy_industries_list`→`taxonomy_professions_list`→search→select→`entity_profession_bind` (landing `unverified`)→duplicate `PLT005` inline guidance; `TaxonomyProvider.selectedProfession` survives navigation.

### VP3 — Identity Verification
- [ ] **DoD-VP3:** `IdentityVerificationService.submitIdentityDocument` (5 DocumentTypes, `credential-documents` private upload, `onProgress`) → pending → mock admin approve → `verification_status_get`/`kyc_level_get` reflected in `VerificationStatusScreen`/`KycStatusScreen`.

### VP4 — Trade Verification + Bid-Lock
- [ ] **DoD-VP4:** `TradeVerificationService.submitTradeProof` (5 TradeProofTypes, profession-bound) → pending → admin approve → `trade_verification_status==approved` → `TradeVerifiedBadge`/`TradeVerificationGate` reports bidding unlocked; client never mutates gate columns.

### VP5 — KYC → Limits
- [ ] **DoD-VP5:** `KycProvider`/`KycLimitGuard` limits scale with mocked tier upgrade (server `verification_limits_get` authoritative); over-limit operation blocked at `KycLimitGuard` + server `PLT003`.

### VP6 — Financial Profile
- [ ] **DoD-VP6:** `FinancialProvider` multi-currency (NGN+GHS/USD/GBP) profile → currency accounts → `BalanceOverviewCard`/`CurrencyAccountCard` per-currency (available/held/pending) render correctly.

### VP7 — Escrow Lifecycle
- [ ] **DoD-VP7:** `EscrowService` escrow with 2 milestones → funded → milestone completion → release (and refund variant) → `financial_transactions` double-entry + `financial_audit_trail` immutable; no client computes amounts.

### VP8 — Currency Conversion
- [ ] **DoD-VP8:** `ConversionProvider` available pairs → preview (rate+fees server-validated via `ConversionRateSource`) → execute → source/dest balances updated atomically → `ConversionHistoryList` entry.

### VP9 — Bound Payout + Name Enquiry
- [ ] **DoD-VP9:** `FinancialPayoutProvider` bind bank account → `NameEnquiryService` mock verify → bound card verified; withdraw within KYC `cashout_limit` succeeds, over-limit blocked; direct payout to unbound account prevented.

### VP10 — Deposit Name-Matching (Rule 3)
- [ ] **DoD-VP10:** `FinancialDepositProvider` matching `payer_name==legal_name` accepted, mismatched flagged → `DepositNameMatchIndicator` variant renders.

### VP11 — Dispute → Escrow Action
- [ ] **DoD-VP11:** `DisputeProvider` file linked to escrow → automatic escrow hold (`EscrowFrozenBanner`) → evidence submit (`EvidenceAttachmentCard`) → resolve → escrow release OR refund per resolution + `dispute_audit_trail`.

### VP12 — Professional Profile Public Display
- [ ] **DoD-VP12a:** Anon GET `/p/:slug/:id` with ≥1 `trade_verification_status=approved` profession traverses single `portfolio_public_profile_get` RPC (SECURITY DEFINER+STABLE, whitelisted `display_name`/`avatar_path`/`bio`/`country_code`+approved professions/credentials+`portfolio_items`; never `legal_name`/`document_path`) → renders at 390px and 1280px without overflow.
- [ ] **DoD-VP12b:** `RouteGuard._isPublicContentView` allows `/p/` signed-out; `PLT004` for unknown/inactive/not-approved renders identical not-found state (no oracle); `portfolio_seo_meta.dart` emits canonical/title from RPC payload.

### Cross-Cutting Verification
- [ ] **DoD-C1:** `trust_financial_logic_scan` → 0 client-side financial arithmetic hits in `lib/systems/`+`lib/data/`.
- [ ] **DoD-C2:** `trust_legal_name_document_scan` → 0 `legal_name` in `lib/systems/portfolio/` + `lib/data/providers/portfolio_provider.dart`; `grep service_role lib/` = 0; `document_path` never in public payload.
- [ ] **DoD-C3:** `trust_theme_token_scan` → 0 `Colors.|Color(0xFF|fontFamily:` in `lib/systems/{onboarding,verification,finance,support,portfolio}/` — all widgets `colorScheme`/`textTheme`/`AppThemeExtension`.
- [ ] **DoD-C4:** `trust_storage_posture` → private `credential-documents` signed-URL only, public `profile-avatars`/`portfolio-items`, size/MIME gates verified.
- [ ] **DoD-C5:** `trust_gateway_abstraction` → 0 direct `PaystackGateway`/`FlutterwaveGateway` imports in `lib/systems/`+`lib/data/`; only abstract `payment_gateway.dart` via factory.
- [ ] **DoD-C6:** `onboarding_resume_redirect_verification` → home→resume / complete→home / `exited` flag honored / `currentStep==null` no redirect.
- [ ] **DoD-C7:** `secret_scan_verification` (re-run) → 0 genuine findings.
- [ ] **DoD-C8:** `ep02_phase_completion_checklist` → 21 EP-02 `EP-02:214-241` criteria PASS with evidence.

### Report + Quality Gates
- [ ] **DoD-R1:** `EP-02-20-Trust-System-Verification-Report.md` created with all §5.19 sections; per-VP pass/fail+evidence, cross-cutting results, issues/remediation, EP-03 readiness checklist, recommendations.
- [ ] **DoD-R2:** `flutter analyze` 0 issues; `flutter test` (unit+widget+new integration+existing integration) all green; `supabase db test` `001-022` all green.
- [ ] **DoD-R3:** Scope validated: `git diff --stat supabase/migrations/` = 0; `pubspec.yaml` diff = 0; `git diff --stat -- lib/app/ lib/data/data_layer.dart` only wiring if any; no `ARCHITECTURE.md`/`AGENT.md`/phase-document edit.
- [ ] **DoD-R4:** Each VP uses scripted fakes at the correct boundary (no live DB/network, no real gateway tokens, no live env credentials); logs redacted to `entityId suffix` only.

---

## 18. AI Execution Profile

| Attribute | Recommended | Justification |
|---|---|---|
| **Reasoning Level** | **High** | |
| **Planning reasoning** | High | **Matches approved Phase Plan** `EP-02:491` (Planning High) + `EP-02:465` (Coding High). **Technical complexity High-leaning-Very High** — 12 cross-system VPs spanning onboarding→taxonomy→verification→KYC→multi-currency→escrow state machine→conversion→bound payout+name enquiry→deposit Rule 3→dispute→public profile, each composing real `Service→Repository→DataSource→Parser→Provider→Widget` stacks via `MockSupabaseClientFactory` rpcHandlers + `FakeStorage/FakeGateway`. **Security sensitivity High → Very High-adjacent**: zero financial logic in client (AGENT.md Rule 4), double-entry escrow invariants, anon `SECURITY DEFINER` whitelist, `PLT004` non-oracle, private-bucket evidence isolation — asserted via pgTAP negatives + scan gates. **Why not Very High / Extremely High:** this task **does not design** catastrophic-risk surfaces (financial DDL, new RPC state machines, dispute `SECURITY DEFINER` scoping, provider abstraction) — `EP-02-03/04/05/09/14/16` already carried those Extremely High designs and their `001-022` pgTAP suites. It **composes** frozen, proven server contracts and validates wiring — rigorous, security-elevated composition, not green-field catastrophic-risk invention. |
| **Coding reasoning** | High | Same distribution: careful mock composition, async `notifyListeners`/`GoRouter` harness pumping, dual-viewport (390/1280) theme-token asserts, envelope `{success,code,message,data}` `PLT00x` normalization mapping, redacted logging. No new migration, no new provider-hostile RPC, no multi-actor financial edge-case design — mirrors EP-01-20 (High) integration-composition pattern at trust-domain scale. |
| **Phase Plan parity** | Planning High / Coding High | Exactly aligned to `EP-02:491,505-506` (EP-02-20 row) and the EP-02-19 TIP precedent where an anon `SECURITY DEFINER` RPC with whitelist stayed `High` for the same reason (additive single RPC + layered client, not multi-actor write-path Extremely High). |

**Where it would escalate to Very High:** if EP-02-20 had to re-design escrow partial-release/dispute-hold branching, re-scope any `SECURITY DEFINER`, or add a live webhook Edge Function. It does not — the phase gate is composition + evidence.

---

## 19. Review & Approval

| Role | Action |
|---|---|
| Task Lead | Confirm wiring audit (step 2), assemble 12 VP + 7-script suite in dev env, run §14.4 gates, self-review DoD-VP1..DoD-R4 |
| Architecture Review | Confirm no `supabase/migrations` diff, `lib/` placement per `ARCHITECTURE.md:95-110,131-138`, unidirectional `data→systems`, route guard seam scope, gateway abstraction boundary |
| Security Review | Verify anon no table grants, RPC whitelist/revokes preserved, `PLT004` oracle-negative, `legal_name`/`document_path` negatives, `service_role` absence, redacted logs |
| Lead Approval | Sign off DoD 1–R4 + Trust System Verification Report before EP-02 `Completed` and EP-03 unblock |

Approved plan — implementation begins in the Development environment. This document is owned by `documents/Task-Implementation/EP-02/`; server-chain changes require a new migration proposal, never an edit here.

---

## 20. Post-Implementation Audit Checklist

```
[ ] flutter analyze                         -> 0 issues
[ ] flutter test test/integration/trust/    -> 12 VPs green (≥86 assertions)
[ ] flutter test test/integration/verification/trust_* -> 7 scripts green
[ ] flutter test                             -> full suite green (unit+widget+all integration, ≥800)
[ ] supabase db test                         -> 001-022 green
[ ] git diff --stat -- supabase/migrations/  -> 0
[ ] grep -rn "service_role" lib/             -> 0
[ ] grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "document_path" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/{onboarding,verification,finance,support,portfolio}/ -> 0
[ ] grep -rn "paystack_gateway\|flutterwave_gateway" lib/systems/ lib/data/ -> 0 (only integrations/ and test/ may import)
[ ] signed-out /p/:slug/:id opens (guard bypass) and PLT004 not-found identical message
[ ] SEO meta (title/description/canonical/og) emitted on web from portfolio RPC payload (never legal_name)
[ ] onboarding resume redirect: home→step, complete→home, exited flag honored
[ ] 21-criterion ep02_phase_completion_checklist -> all PASS
[ ] documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md created with VP1-12 + cross-cutting evidence
```