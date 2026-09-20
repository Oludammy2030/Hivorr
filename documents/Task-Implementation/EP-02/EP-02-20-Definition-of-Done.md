# Definition of Done — EP-02-20: Phase Integration Validation & Trust System Verification

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-20 | **Status:** Completed � verified 2026-09-20 (GO)
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-20-Phase Integration Validation & Trust System Verification.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-20 |
| **Task Name** | Phase Integration Validation & Trust System Verification |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 8 — Validation |
| **Priority** | Critical — Phase Gate (blocks EP-03) |
| **Dependencies** | All EP-02 items (EP-02-01 through EP-02-19) |
| **Blocks** | EP-03 (marketplace discovery) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-20-Phase Integration Validation & Trust System Verification.md` |

**Server surface (validation-only — zero new migrations):** `git diff --stat supabase/migrations/` must be `0`. No DDL, RLS, RPC, storage-bucket, Edge Function, or webhook creation/modification. All EP-02 server surfaces remain frozen and are **re-audited, never edited**.

**Frozen server references (read-only, never modified):** `20260821090003_entity_model_rls_policies.sql:24-27` (anon zero grants) | `20260829090002_taxonomy_management_rpcs.sql:35,64` (taxonomy list RPCs) | `20260829090003_verification_admin_review_schema.sql:244-246,364-381,591-625,791-796` (verification schema default-deny + submit/review/limits) | `20260829100004_financial_integrity_schema.sql` + `014_financial_rpc_enforcement.sql` (financial schema, double-entry, server-only balance mutation) | `20260829120005/06_dispute_resolution_schema.sql` (dispute + withdraw scoping) | `20260830100001_storage_buckets.sql` (private `credential-documents` / public `profile-avatars`+`portfolio-items`) | `20260913090001_portfolio_public_profile.sql` (anon SECURITY DEFINER `portfolio_public_profile_get` whitelist + `PLT004` non-oracle) | `20260915090001_onboarding_authoritative_state.sql` + `019_onboarding_authoritative_state.sql` | pgTAP suite `supabase/tests/database/001-022`.

---

## 2. Functional Verification

This task is the **EP-02 phase gate**: it proves the 19 individually-completed trust, identity and financial subsystems interoperate as an integrated trust platform by exercising each validation point defined in `EP-02:463` (12-point suite) plus 7 cross-cutting verification scripts, and it records evidence in the Trust System Verification Report. Functional verification confirms each Validation Point (VP1-VP12) drives real `*Service → Repository → RemoteDataSource → EnvelopeParser → Mapper → Provider → Widget` compositions with only the transport/storage/rate boundary faked — proving wiring that unit tests cannot.

### 2.1 Required Functionality — VP1 Full Onboarding Flow (EP-02-18 composition)

- [x] **FV-01:** Fresh authenticated entity at `/` is guard-redirected by `RouteGuard._onboardingResumeRedirect` (`lib/app/router/route_guard.dart:184-213`) to `RoutePaths.onboardingRouteFor(OnboardingStepCode.profile)`; 5-step wizard (`profile → capability → industry → identityDocument → tradeProof → complete`) loops with real route transitions and `OnboardingCompleteScreen` trust-loop education panel (DoD-VP1a)
- [x] **FV-02:** Exit via `OnboardingExitConfirmDialog` saveAndExit + relaunch resumes at the exact step — `OnboardingProgressStore` key `onboarding_progress:{entityId}` + lifecycle `didChangeAppLifecycleState` pause save; avatar `StorageService.upload` (public `profile-avatars`, `StoragePaths.avatar`, `upsert: true`, 5 MiB jpeg/png/webp) precedes the `entity_profile_update` RPC (DoD-VP1b)

### 2.2 Required Functionality — VP2 Taxonomy Browse → Select → Bind

- [x] **FV-03:** `taxonomy_industries_list`→`taxonomy_professions_list` (`20260829090002:35,64`) → search via `TaxonomyProvider.filteredProfessions` (debounced) → select → `entity_profession_bind` (lands `trade_verification_status = unverified`) → duplicate `PLT005` inline guidance (no fire-hammer); `TaxonomyProvider.selectedProfession` survives navigation and resume (DoD-VP2)

### 2.3 Required Functionality — VP3 Identity Verification

- [x] **FV-04:** `IdentityVerificationService.submitIdentityDocument` (5 `DocumentType` values, private `credential-documents` upload via `StoragePaths.credentialDocument`, `onProgress`) → `verification_submit` (`submission_type = identity_document`) → `pending`
- [x] **FV-05:** Mock admin approve via `AdminReviewProvider` → `verification_status_get` / `kyc_level_get` reflect approved + KYC tier upgrade in `VerificationStatusScreen` / `KycStatusScreen` / verification timeline (DoD-VP3); submissions logged via `HivorrLogger` + `PiiRedactor` (`entityId suffix` only)

### 2.4 Required Functionality — VP4 Trade Verification + Bid-Lock

- [x] **FV-06:** `TradeVerificationService.submitTradeProof` (5 `TradeProofType`, profession-bound, `submission_type = trade_proof`) → `pending` → admin approve → `trade_verification_status == approved` → `TradeVerifiedBadge` / `TradeVerificationGate` (`lib/systems/verification/gate/trade_verification_gate.dart`) reports bidding unlocked; rejected path surfaces `rejection_reason` inline; client never mutates gate columns (DoD-VP4)

### 2.5 Required Functionality — VP5 KYC Level → Limit Increase

- [x] **FV-07:** `KycProvider` / `KycLimitGuard` limits scale with mocked tier upgrade (`verification_limits_get` authoritative via `entity_kyc_levels`↔`kyc_tiers`); over-limit operation blocked at `KycLimitGuard` + server `PLT003`; `KycLimitsCard`/`kyc_limits_card` render reflects the tier (DoD-VP5)

### 2.6 Required Functionality — VP6 Financial Profile → Currency Accounts → Balances

- [x] **FV-08:** `FinancialProvider` multi-currency profile (NGN primary + GHS/USD/GBP secondary per EP-02 assumptions) → `financial_currency_account_request` per currency
- [x] **FV-09:** `financial_balances_get` → `FinancialProfileScreen` renders `BalanceOverviewCard` + `CurrencyAccountCard` per currency with available/held/pending correctly derived (DoD-VP6)

### 2.7 Required Functionality — VP7 Escrow Lifecycle + Milestone + Audit

- [x] **FV-10:** `EscrowService` escrow with 2 `EscrowMilestoneInput` → `financial_escrow_create` → fund via the abstract `PaymentGateway` seam (intercepted `MockDioAdapter`) → `financial_escrow_fund` → milestone completion → release via `financial_escrow_release` (and refund variant); state machine verified `draft→funded→held→released/refunded/disputed`
- [x] **FV-11:** `financial_transactions` double-entry + `financial_audit_trail` immutable row present; **no client computes amounts** (server `financial_transactions` insert is sole mutator) (DoD-VP7)
- [x] **FV-12:** Partial-release edge case (`financial_escrow_milestone_release`) asserted with balances derived correctly

### 2.8 Required Functionality — VP8 Currency Conversion

- [x] **FV-13:** `ConversionProvider` available pairs (NGN↔GHS/NGN↔USD/NGN↔GBP) → preview (rate + fees via `ConversionRateSource`, server-validated) → execute → source debited / destination credited atomically via double-entry → `ConversionHistoryList` entry; server rate validated, not client calculation (DoD-VP8)

### 2.9 Required Functionality — VP9 Bound Payout + Name Enquiry + Cashout Limit

- [x] **FV-14:** `FinancialPayoutProvider` bind bank account (`bank_account_number_validator`) → `NameEnquiryService` → `NibssNameEnquiryAdapter` (`lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart`) verify accountNumber ↔ legalName (mock `MockDioAdapter`) → bound `PayoutAccountCard` shows verified chip
- [x] **FV-15:** Withdraw within `kyc_tiers.cashout_limit` succeeds; over-limit blocked (`KycLimitGuard` + server `PLT003`); payout to unbound account blocked server-side; `PayoutAccountLimitDisplay` renders limit (DoD-VP9)

### 2.10 Required Functionality — VP10 Deposit Name-Matching (AGENT.md Rule 3)

- [x] **FV-16:** `FinancialDepositProvider` records `financial_deposits` with `payer_name`; matching `payer_name == legal_name` (normalized) → accepted; mismatched → `flagged`/`blocked` → `DepositNameMatchIndicator` variant + hold observable via `financial_deposits.status`; `legal_name` never leaves the server except redacted logs (DoD-VP10)

### 2.11 Required Functionality — VP11 Dispute File → Evidence → Resolve → Escrow Action

- [x] **FV-17:** `DisputeProvider` files dispute linked to escrow (`dispute_file` → `case_status = open`) → automatic escrow hold (`EscrowFrozenBanner`) → evidence submit (`EvidenceAttachmentCard`, private-path only)
- [x] **FV-18:** `dispute_resolve` (service-role mock) → escrow action per resolution: release to payee OR refund to payer + `dispute_audit_trail` / `financial_audit_trail` reflect action; `DisputeStatusBadge` variant renders (DoD-VP11)

### 2.12 Required Functionality — VP12 Professional Profile Public Display

- [x] **FV-19:** Anon GET `/p/:slug/:id` for an approved entity (≥1 `trade_verification_status = approved` profession) traverses the **single** `portfolio_public_profile_get(p_entity_id uuid)` RPC (SECURITY DEFINER + STABLE, anon EXECUTE, whitelisted projection `display_name`/`avatar_path`/`bio`/`country_code` + approved professions/credentials + `portfolio_items`; never `legal_name`/`document_path`) → `ProfessionalProfileScreen` renders header/badges/credentials/`PortfolioGrid` at 390px and 1280px without overflow (DoD-VP12a)
- [x] **FV-20:** `RouteGuard._isPublicContentView` (`lib/app/router/route_guard.dart:215-216`) allows `/p/` signed-out; `PLT004` for unknown / inactive / zero-approved renders identical `ProfileNotFoundState` (no existence oracle — mirrors `018_portfolio_public_profile.sql:23-29` negatives) (DoD-VP12b)
- [x] **FV-21:** `portfolio_seo_meta.dart` builds `title` (`displayName · professionName`), `description`, `og:*`, canonical from the RPC payload — never `legal_name` (SEO-404 semantics for hidden profiles)

### 2.13 Required Functionality — Cross-Cutting Verification Scripts

- [x] **FV-22:** `trust_financial_logic_scan` → 0 client-side financial arithmetic hits in `lib/systems/` + `lib/data/` (adapters excepted); `trust_legal_name_document_scan` → 0 `legal_name` in `lib/systems/portfolio/` + `lib/data/providers/portfolio_provider.dart` and 0 `document_path` in public projection; `grep -rn "service_role" lib/` = 0 (DoD-C1/C2)
- [x] **FV-23:** `trust_theme_token_scan` → 0 `Colors.` / `Color(0xFF` / `fontFamily:` in `lib/systems/{onboarding,verification,finance,support,portfolio}/` (AGENT.md Rule 5); `trust_storage_posture` matches `storage_config.dart:39,66,97` + `017`/`018` pgTAP (private `credential-documents` signed-URL only; public `profile-avatars`/`portfolio-items`) (DoD-C3/C4)
- [x] **FV-24:** `trust_gateway_abstraction` → 0 direct `paystack_gateway.dart`/`flutterwave_gateway.dart` imports in `lib/systems/` + `lib/data/` (abstract `payment_gateway.dart` via `payment_gateway_factory.dart` only); `onboarding_resume_redirect_verification` guards pass (home→resume / complete→home / `exited` flag honored / `currentStep==null` no redirect); `secret_scan_verification` re-run → 0 genuine findings (DoD-C5/C6/C7)

### 2.14 Required Functionality — Phase Completion + Report

- [x] **FV-25:** `ep02_phase_completion_checklist.dart` — all **21** EP-02 completion criteria (`EP-02:214-241`) PASS with structured map criterion → evidence → pass/fail (DoD-C8)
- [x] **FV-26:** `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md` created with all §5.19 sections (executive summary, VP1-12 results, cross-cutting results, env/platform notes, issues, remediation, EP-03 readiness checklist, recommendations) + `GO`/`NO-GO` verdict (DoD-R1)

### 2.15 Expected Workflows

- [x] **FV-27:** The full trust loop composes end-to-end — onboarding → taxonomy → identity/trade verification → KYC → financial profile → escrow → conversion → bound payout + name enquiry → deposit Rule 3 → dispute → public trust display — without any opaque seam break (what the 12 VPs prove jointly)
- [x] **FV-28:** Escrow funding / payout transfers / name enquiry flow through the provider-agnostic `PaymentGateway` + `NameEnquiryService` abstraction (intercepted via `MockDioAdapter` scripted responses) — never direct provider SDK calls from business logic

### 2.16 Error Handling Scenarios

- [x] **FV-29:** Envelope normalization asserted per VP — `PLT000`→domain entity, `PLT003`→inline field error, `PLT004`→not-found, `PLT005`→conflict guidance, `PLT999`→retry state; raw Supabase/Dio exceptions never escape `*RemoteDataSource` → `DataExceptionMapper`
- [x] **FV-30:** `PLT005` (duplicate profession bind `entity_professions_entity_profession_key`, active-verification partial index) surfaces inline guidance + status escape — no silent retry, no fire-hammer
- [x] **FV-31:** Over-limit cashout → `KycLimitGuard` + server `PLT003`; withdrawal to an unbound account blocked server-side (VP9)
- [x] **FV-32:** Wiring gaps discovered by any VP → minimal fixes confined to `lib/app/app.dart`, `lib/app/router/app_router.dart`, `lib/app/router/route_guard.dart`, `lib/data/data_layer.dart` (register*Layer / `initialize*()` order / barrel export) only; then full gates re-run from `flutter analyze` (Plan §5.18)

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **TV-01:** New files ONLY under `test/integration/trust/` (12 VP tests), `test/integration/verification/` (`trust_*` 7 scripts + `ep02_phase_completion_checklist.dart`), and `documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md`; **no files in `lib/` by default** — `lib/` additions only the minimal wiring fix set (if any) in `lib/app/` + `lib/data/data_layer.dart`
- [x] **TV-02:** `git diff --stat -- supabase/migrations/` = 0; `pubspec.yaml` diff = 0 (no new dependencies); zero edits to `ARCHITECTURE.md`/`AGENT.md`/phase documents
- [x] **TV-03:** Integration tests compose **real** system objects (`*Service → Repository → RemoteDataSource → EnvelopeParser → Mapper → Provider → Widget`); only transport/storage/rate is faked (`MockSupabaseClientFactory` rpcHandlers, `MockDioAdapter`, `FakeStorageService`) — this validates wiring that unit tests cannot (Plan §5.1 "Real composition at the seam")
- [x] **TV-04:** Reuses the EP-01-19/EP-02 test infrastructure wholesale — `test/support/fakes/*`, `factories/mock_supabase_client_factory.dart`, `harnesses/widget_harness.dart` + `router_harness.dart`, `builders/*`, `matchers/*`; existing `test/integration/finance/*`, `support/*`, `verification/*`, `portfolio_public_profile_flow_test.dart`, `onboarding_flow_integration_test.dart` extended/composed, not duplicated

### 3.2 Required System Behavior

- [x] **TV-05:** Server-authoritative — tests assert server state drives UI; client never mutates `trade_verification_status`, `verification_submissions.status`, `financial_balances`, escrow state, or dispute state (read-only renders via status enums)
- [x] **TV-06:** Envelope normalization via shared `*EnvelopeParser` / `DataExceptionMapper` — `PLT000/003/004/005/999` mapped to typed outcomes; no raw `DioException`/SQL surfaces in any VP
- [x] **TV-07:** Widget-through verification at 390px and 1280px via `widget_harness.dart` (`HivorrResponsiveScaffold`); branded 4-states (`HivorrLoadingState` wrapping `HivorrLoader` pulse `VISUAL-IDENTITY.md:148`) — never bare `CircularProgressIndicator`
- [x] **TV-08:** Redacted logging via `HivorrLogger` + `PiiRedactor` (`entityId suffix` only); `PerformanceTracer` spans `onboarding.*`, `portfolio.public_profile.load`, `finance.escrow.*`, `finance.conversion.*`, `support.dispute.*` sampled via `MonitoringConfig` (no PII tags)

### 3.3 Module Integration

- [x] **TV-09:** `RouteGuard` resume logic correct — home→resume, complete→home, `exited` flag honored, `currentStep==null` → no redirect (`onboarding_resume_redirect_verification.dart` via `route_guard_test.dart` pattern)
- [x] **TV-10:** GoRoutes for `onboarding*`, `finance`/`escrow`/`convert`, `disputes*`, `/p/:slug/:id` registered with correct guarding; `_onboardingResumeRedirect` + `_isPublicContentView` cover the trust routes
- [x] **TV-11:** Payment-gateway abstraction boundary — business logic imports only `payment_gateway.dart` abstract via `payment_gateway_factory.dart`; provider adapters confined to `lib/integrations/payment_gateways/`
- [x] **TV-12:** Storage posture honored — private evidence (`credential-documents`) via signed URL only; public playback (`profile-avatars`/`portfolio-items`) via `getPublicUrl`; `StorageBuckets`/`StoragePaths`/`StorageValidators` reused, not duplicated
- [x] **TV-13:** Onboarding ↔ authoritative-state seam (`20260915090001_onboarding_authoritative_state.sql` + `019` pgTAP) respected via `OnboardingProvider` ↔ `EntryStateStore` in VP1 resume scenarios
- [x] **TV-14:** Any minimal wiring fix diff restricted to `lib/app/app.dart`, `lib/app/router/app_router.dart`, `lib/app/router/route_guard.dart`, `lib/data/data_layer.dart` (register*Layer / init order / barrel export) — no system logic, no business rule, no `supabase/` edit

### 3.4 Technical Requirements from Plan

- [x] **TV-15:** `flutter analyze` + `dart analyze` clean (0 issues)
- [x] **TV-16:** Each `test/integration/trust/*` test dartdoc documents the frozen seam, RPC envelope contract, fake boundary, and assertions it exercises
- [x] **TV-17:** `ep02_phase_completion_checklist.dart` is a structured map per `EP-02:214-241` criterion → evidence → PASS/FAIL (same style as `EP-01-20 §5.18` `phase_completion_checklist.dart`)
- [x] **TV-18:** Trust System Verification Report reuses the EP-01-20 report template (`EP-01-20-Foundation-Verification-Report.md:350-364`) for like-for-like cross-phase comparison

---

## 4. Data Verification

### 4.1 Data Creation

- [x] **DV-01:** Integration fixtures use placeholder values only — no real PII, no real legal names, no real account numbers (bank numbers use `0000000000`-style placeholders validated by `bank_account_number_validator`)
- [x] **DV-02:** Where a VP needs seeded trust state (approved entity for VP12, funded escrow for VP11), the fake Supabase handler seeds in-memory rows mirroring the real schema columns — never via a live migration
- [x] **DV-03:** No trust/business/financial data is persisted to a live database; all mutations remain inside `FakeSupabaseClient` in-memory handlers

### 4.2 Data Updates

- [x] **DV-04:** `OnboardingProgress` persistence uses `InMemoryOnboardingProgressStore` + temp-dir `HiveOnboardingProgressStore` — no live Hive box cross-contamination; key stays `onboarding_progress:{entityId}`
- [x] **DV-05:** Balance/escrow/transaction mutations asserted to originate server-side (`financial_transactions` insert is sole mutator) — no client-side `balance =`/`amount ±` writes (DV presumes scan; `trust_financial_logic_scan` proves it)

### 4.3 Data Relationships

- [x] **DV-06:** `entity_profession_bind` lands `entity_professions(entity_id, profession_id, is_primary=false, trade_verification_status='unverified')` — envelope asserted; trade-proof carries the bound `professionId` end-to-end
- [x] **DV-07:** Escrow milestone → transaction → audit-trail relationships asserted (double-entry rows + immutable `financial_audit_trail` row per mutation; `dispute_audit_trail` for dispute actions)
- [x] **DV-08:** Deposit `payer_name` → server matcher → `entity_profiles.legal_name` comparison path exercised (matching accepted; mismatched flagged); NIBSS `accountNumber ↔ legalName` ownership verify exercised via mocked `MockDioAdapter`
- [x] **DV-09:** KYC tier → `kyc_tiers.cashout_limit` scaling asserted as server-authoritative (`verification_limits_get`), drives `KycLimitGuard` + UI limit displays

### 4.4 Data Accuracy

- [x] **DV-10:** `portfolio_public_profile_get` payload structural whitelist proven in VP12 — `display_name`/`avatar_path`/`bio`/`country_code` + approved professions/credentials + `portfolio_items` present; `legal_name`/`document_path`/review+limit fields structurally absent
- [x] **DV-11:** Per-currency balances (`available`/`held`/`pending`) render exactly as `financial_balances_get` returns; conversion atomicity (source debited, destination credited) asserted from server state

### 4.5 Data Integrity

- [x] **DV-12:** Trust System Verification Report contains factual pass/fail + test-output summaries only — no `legal_name`, no `document_path`, no credential bytes, no sensitive values anywhere in artefacts

---

## 5. Security Verification

- [x] **SV-01:** Server surface frozen — zero DDL/RLS/RPC/bucket edits; `git diff --stat -- supabase/migrations/` = 0; `supabase db test` `001-022` re-run green is the authoritative default-deny evidence
- [x] **SV-02:** Default-deny preserved — anon/authenticated retain zero table grants (re-audited via `001_rls_leakage_matrix` + `trust_storage_posture_verification.dart`); public reads occur only inside SECURITY DEFINER RPCs (AGENT.md Rule 4)
- [x] **SV-03:** `legal_name` (Rule 3 financial anchor) + `document_path` (private evidence) never in public projection — `trust_legal_name_document_scan` + `018_portfolio_public_profile.sql` negative `jsonb_path_exists` asserts re-run
- [x] **SV-04:** `PLT004` non-oracle — identical message for unknown / inactive / zero-approved entities; no endpoint or rendering distinguishes why a profile is hidden (VP12 + `018` behavior asserts)
- [x] **SV-05:** No `service_role` string in client code — `grep -rn "service_role" lib/` = 0 (gate in `trust_legal_name_document_scan` + `flutter analyze` lens); admin/service-role paths remain server-side only
- [x] **SV-06:** No hardcoded secrets/tokens — `secret_scan_verification.dart` re-run (private-key + 20-char `*.supabase.co` + multi-segment JWT + secret-typed literal scans over `lib/` + `test/`) = 0 genuine findings; placeholder env values only; `.gitignore` covers `.env*`
- [x] **SV-07:** Financial logic confined to server — `trust_financial_logic_scan` = 0 arithmetic mutation patterns in `lib/systems/` + `lib/data/` (adapters excepted); double-entry/escrow invariant zero client-side
- [x] **SV-08:** Gateway abstraction — 0 direct `paystack_gateway.dart`/`flutterwave_gateway.dart` imports in `lib/systems/` + `lib/data/`; provider adapters live only in `lib/integrations/payment_gateways/`
- [x] **SV-09:** Gateway webhook-signature / name-enquiry spoof paths validated — signature-verification precedent reused (`payment_gateway_transport_test.dart`) and NIBSS name enquiry via bearer-auth adapter, both intercepted via scripted `MockDioAdapter`
- [x] **SV-10:** PII discipline in artefacts — placeholder entity data only; logs redacted to `entityId suffix`; report/tests contain no credential bytes, no real names, no real account numbers
- [x] **SV-11:** Wiring fixes (if any) introduce no bypass — diff review restricted to `lib/app/` + `lib/data/data_layer.dart`; no gate-column writes, no new anon surface, no weakening of grant posture

---

## 6. Performance Verification

- [x] **PV-01:** Suite cost bounded — 12 VPs × ~8s + 7 scripts × ~3s ≈ 2–3 min for `flutter test test/integration/trust/`
- [x] **PV-02:** Full `flutter test` stays within the CI 20-minute timeout (EP-01-20 baseline 682 tests; EP-02-20 adds ~90–120 assertions, total project ~800)
- [x] **PV-03:** In-memory simulation only — `MockSupabaseClientFactory` + `MockDioAdapter` + `Fake*RemoteDataSource` = no network latency, no real storage I/O
- [x] **PV-04:** Hive stores use temp-dir or in-memory fallback per test (precedent `onboarding_progress_store_test.dart`) — no cross-test contamination, no live box
- [x] **PV-05:** Verification scripts are file-system walks (sub-second to ~10s each) run as `flutter test` verification tests — no widget-pump cost added
- [x] **PV-06:** `PerformanceTracer` spans sampled via `MonitoringConfig` — zero overhead when disabled; no polling/timers introduced by the suite
- [x] **PV-07:** No new dependencies → zero impact on the 15–20 MB installer target (EP-01-20 `app_size_verification.dart` estimate re-reported in the report for continuity)

---

## 7. Testing Verification

### 7.1 Automated Integration Suite — `test/integration/trust/` (12 VPs, ≥86 assertions)

Pattern (per VP): `MockSupabaseClientFactory` scripted `rpcHandlers` → real `*RemoteDataSource` → real `*RepositoryImpl` → real `*Provider` (ChangeNotifier under `Provider`) → real screens/widgets pumped via `widget_harness.dart` + `router_harness.dart`; `FakeStorageService`/`FakeConversionRateSource` at the boundary.

- [x] **TT-01:** VP1 `onboarding_trust_flow_integration_test.dart` ≥8 — fresh→guard redirect→wizard loop all 5 steps→`OnboardingCompleteScreen` `HivorrSuccessState`; exit@step3→resume@exact step; `notifyListeners` per advance; guard redirect home→resume, complete→home
- [x] **TT-02:** VP2 `taxonomy_browse_bind_integration_test.dart` ≥6 — industries listed → profession search filtered → bind succeeds → `selectedProfession` survives route pop; duplicate `PLT005` guidance
- [x] **TT-03:** VP3 `identity_verification_flow_integration_test.dart` ≥6 — identity doc upload (`onProgress`) → `verification_submit` pending → mock admin approve → `KycProvider.tier` upgraded; redacted log assertion
- [x] **TT-04:** VP4 `trade_verification_gate_integration_test.dart` ≥6 — trade proof bound to profession → pending → approve → `TradeVerificationStatus.approved` → `TradeVerifiedBadge` unlocked copy; client never writes gate columns
- [x] **TT-05:** VP5 `kyc_level_limit_integration_test.dart` ≥6 — limits fetched → over-limit blocked by `KycLimitGuard` → upgraded tier lifts limit → `KycLimitsCard` reflects
- [x] **TT-06:** VP6 `financial_profile_flow_integration_test.dart` ≥8 — financial profile create → 2 currency accounts → `financial_balances_get` → `BalanceOverviewCard` per currency correct
- [x] **TT-07:** VP7 `escrow_lifecycle_integration_test.dart` ≥10 — escrow with 2 milestones → funded → milestone→release → `financial_transactions` double-entry + `financial_audit_trail` row; partial-release + refund variants; no client arithmetic
- [x] **TT-08:** VP8 `conversion_flow_integration_test.dart` ≥6 — available pairs → preview (rate+fees) → execute → source debited/dest credited atomically → history entry
- [x] **TT-09:** VP9 `payout_account_flow_integration_test.dart` ≥8 — bind account → NIBSS name enquiry mocked → verified chip → withdraw within limit succeeds, over-limit blocked → `PayoutAccountLimitDisplay`
- [x] **TT-10:** VP10 `deposit_name_match_integration_test.dart` ≥6 — matching payer accepted → mismatched flagged → `DepositNameMatchIndicator` variant
- [x] **TT-11:** VP11 `dispute_escrow_integration_test.dart` ≥10 — file linked to escrow → escrow frozen → evidence submit → resolve→release vs refund branches → `EscrowFrozenBanner` + audit trails
- [x] **TT-12:** VP12 `public_profile_integration_test.dart` ≥12 — anon `/p/slug/id` → single RPC renders badges + grid @390 and 1280; signed-out allowed; `PLT004`→identical not-found; SEO meta never `legal_name`
- [x] **TT-13:** Total ≥86 trust integration assertions; each VP asserts envelope normalization `PLT000→domain entity`, `PLT003→inline field error`, `PLT004→not-found`, `PLT005→conflict guidance`, `PLT999→retry state` — never raw Exceptions escaping `*RemoteDataSource`→`DataExceptionMapper`

### 7.2 Verification Scripts — `test/integration/verification/` (7 scripts)

- [x] **TT-14:** `trust_financial_logic_scan_verification.dart` → 0 hits (`amount\s*[\+\-\*\/]`, `balance\s*=` in `lib/systems/`+`lib/data/`, adapters excepted)
- [x] **TT-15:** `trust_legal_name_document_scan_verification.dart` → 0 hits (`legal_name`/`document_path` in `lib/systems/portfolio/` + `lib/data/providers/portfolio_provider.dart`; `service_role` in `lib/` = 0)
- [x] **TT-16:** `trust_theme_token_scan_verification.dart` → 0 hits (`Colors.`/`Color(0xFF`/`fontFamily:` in `lib/systems/{onboarding,verification,finance,support,portfolio}/`)
- [x] **TT-17:** `trust_storage_posture_verification.dart` → bucket/size/MIME posture matches `storage_config.dart:39,66,97` + `017`/`018` pgTAP
- [x] **TT-18:** `trust_gateway_abstraction_verification.dart` → 0 direct `paystack_gateway.dart`/`flutterwave_gateway.dart` imports in `lib/systems/` + `lib/data/`
- [x] **TT-19:** `onboarding_resume_redirect_verification.dart` → home→resume / complete→home / `exited` flag honored / `currentStep==null` no redirect — all pass
- [x] **TT-20:** `secret_scan_verification.dart` (re-run) → 0 genuine findings; `ep02_phase_completion_checklist.dart` → 21 EP-02 criteria (`EP-02:214-241`) all PASS with evidence

### 7.3 Regression + Failure Scenarios

- [x] **TT-21:** Full gates green and scope validated — `flutter analyze` 0 issues; complete `flutter test` green (unit + widget + 12 new trust integration + existing integration, ~800); `supabase db test` `001-022` green; `git diff --stat -- supabase/migrations/` = 0; `pubspec.yaml` diff = 0; any VP failure remediated per Plan §5.18 (wiring only) and re-run from step 16 of the Plan sequence before the phase gate is signed

---

## 8. User Acceptance Verification

This task delivers the **EP-02 phase gate evidence**: proof that the integrated trust platform is production-ready and EP-03-ready, captured in code (12 VPs + 7 scripts) and in the Trust System Verification Report. User acceptance is measured by the end-to-end trust experience working as one coherent platform and by the fail-closed gate being documented.

- [x] **UA-01:** The project lead can run the full 12-VP trust suite and observe the whole loop interoperate — onboarding → taxonomy → identity/trade verification → KYC → financial profile → escrow → conversion → bound payout + name enquiry → deposit Rule 3 → dispute → public trust display — with no opaque composition break
- [x] **UA-02:** Onboarding is resumable and reliable — exit at any step and relaunch returns to the exact step with prior inputs intact; lifecycle backgrounding saves progress; the wizard completes to the trust-loop education panel
- [x] **UA-03:** Trust signals are server-truthful and instant — identity/trade badges, KYC tier, per-currency balances, escrow milestones, and portfolio credentials all reflect verified state; bidding stays locked (Rule 2) until `approved`, never faked unlocked
- [x] **UA-04:** Financial trust is tangible — escrow milestone-gated release with dispute freeze, withdrawals only to bound pre-verified accounts within KYC limits, deposits flagged when `Payer Name != legal_name`; no client-side money arithmetic anywhere
- [x] **UA-05:** Public trust display is discoverable and shareable — `/p/:profession_slug/:entity_id` opens signed-out, renders cleanly at 390px and 1280px, and never surfaces `legal_name` or private evidence; SEO meta emitted on web
- [x] **UA-06:** Design-token discipline holds across every trust subsystem (Rule 5) — `grep` lens clean for `Colors.`/`Color(0xFF`/`fontFamily:` across `lib/systems/{onboarding,verification,finance,support,portfolio}/`; branded states + `HivorrLoader` pulse
- [x] **UA-07:** Security posture re-verified — zero `service_role` in client, zero `legal_name`/`document_path` leakage, default-deny RLS intact, gateway abstraction boundary honored, secret scan clean
- [x] **UA-08:** The gate is fail-closed and documented — any VP failure blocks EP-03; the Trust System Verification Report carries per-VP pass/fail + evidence and an explicit `GO`/`NO-GO` verdict for the project lead
- [x] **UA-09:** Downstream unblocked — EP-02 can be marked `Completed` and EP-03 can proceed on the verified trust stack; the 21 phase-completion criteria (`EP-02:214-241`) are evidenced PASS by the checklist script

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-20 can be marked **Completed** (and EP-02 can be signed `Complete` / EP-03 unblocked).

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `git diff --stat -- supabase/migrations/` = 0 — zero DDL/RLS/RPC/bucket/Edge Function change; `pubspec.yaml` diff = 0 | `git diff --stat` | ☑ |
| 2 | New files ONLY under `test/integration/trust/` (12 VPs), `test/integration/verification/` (`trust_*` 7 scripts + `ep02_phase_completion_checklist.dart`), `documents/Task-Implementation/EP-02/` (report); `lib/` additions limited to the minimal wiring set (if any) | Diff review | ☑ |
| 3 | All 12 VP integration tests green composing **real** `*Service→Repository→DataSource→EnvelopeParser→Provider→Widget` stacks (@390/1280) with only transport/storage/rate faked | `flutter test` | ☑ |
| 4 | Envelope normalization per VP — `PLT000/003/004/005/999` mapped; no raw Supabase/Dio exception escapes `*RemoteDataSource`→`DataExceptionMapper` | Code + test review | ☑ |
| 5 | VP1 onboarding: fresh→guard redirect→wizard loop→complete; exit@step3→resume exact step; lifecycle pause save; avatar upload precedes RPC | VP1 test | ☑ |
| 6 | VP2 taxonomy: browse→search→bind (`unverified`)→`PLT005` dedup guidance; selection survives navigation/resume | VP2 test | ☑ |
| 7 | VP3 identity: upload (`onProgress`)→pending→mock admin approve→KYC tier upgrade reflected | VP3 test | ☑ |
| 8 | VP4 trade: proof→pending→approve→`approved`→bid-lock released (`TradeVerifiedBadge`/gate); client never mutates gate columns | VP4 test | ☑ |
| 9 | VP5 KYC: limits fetched server-authoritative; over-limit blocked; tier upgrade lifts limit (`KycLimitsCard`) | VP5 test | ☑ |
| 10 | VP6 financial: multi-currency profile + currency accounts + per-currency `BalanceOverviewCard`/`CurrencyAccountCard` correct | VP6 test | ☑ |
| 11 | VP7 escrow: create→fund→milestone→release/refund; `financial_transactions` double-entry + immutable `financial_audit_trail`; no client computes amounts | VP7 test | ☑ |
| 12 | VP8 conversion: pairs→preview (rate+fees)→execute→atomic balances→history; server rate validated, not client math | VP8 test | ☑ |
| 13 | VP9 payout: bind + NIBSS name enquiry mocked→verified chip; withdraw within `cashout_limit` succeeds, over-limit/unbound blocked | VP9 test | ☑ |
| 14 | VP10 deposit Rule 3: `payer_name==legal_name` matched / mismatched flagged; `DepositNameMatchIndicator` variant; `legal_name` stays server-side | VP10 test | ☑ |
| 15 | VP11 dispute: file→escrow automatic hold→evidence (private path)→resolve→release OR refund; `dispute_audit_trail`/`financial_audit_trail` | VP11 test | ☑ |
| 16 | VP12 public profile: anon `/p/:slug/:id` single RPC renders @390/1280 signed-out; `PLT004` identical not-found (non-oracle); SEO meta never `legal_name` | VP12 test | ☑ |
| 17 | 7 verification scripts green — financial-logic 0 | legal_name/document_path 0 | `service_role` 0 | theme-token 0 | storage-posture match | gateway-abstraction 0 | resume-redirect pass | secret-scan 0 findings | phase-checklist 21 PASS | `flutter test` (verification) | ☑ |
| 18 | Wiring fixes (if any) confined to `lib/app/` + `lib/data/data_layer.dart` (register*Layer / init order / router guard / barrel) — no system logic, no server edit | Diff review | ☑ |
| 19 | `flutter analyze` 0 issues; full `flutter test` green (~800); `supabase db test` `001-022` green | CI + `supabase db test` | ☑ |
| 20 | `EP-02-20-Trust-System-Verification-Report.md` created — all §5.19 sections, per-VP pass/fail + evidence, issues/remediation, EP-03 readiness checklist, `GO`/`NO-GO` verdict; EP-02 ready for `Completed`; **stop before EP-03** | File + review | ☑ |

---

> **Sign-off:** Task EP-02-20 marked **Completed** — all 20 conditions in the Final Approval Checklist verified and signed off by the project lead; EP-02 eligible for phase `Completed` with EP-03 unblocked per the Trust System Verification Report verdict.

---

**Post-Implementation Audit Commands (run by project lead)**

```
[ ] flutter analyze                                              -> 0 issues
[ ] flutter test test/integration/trust/                         -> 12 VPs green (>=86 assertions)
[ ] flutter test test/integration/verification/trust_*           -> 7 scripts green
[ ] flutter test                                                 -> full suite green (unit + widget + all integration, ~800)
[ ] supabase db test                                             -> 001-022 green
[ ] git diff --stat -- supabase/migrations/                      -> 0
[ ] grep -rn "service_role" lib/                                 -> 0
[ ] grep -rn "legal_name" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "document_path" lib/systems/portfolio/ lib/data/providers/portfolio_provider.dart -> 0
[ ] grep -rn "Colors\{\.\}\|Color(0xFF\|fontFamily:" lib/systems/{onboarding,verification,finance,support,portfolio}/ -> 0
[ ] grep -rn "paystack_gateway\|flutterwave_gateway" lib/systems/ lib/data/ -> 0 (integrations/ and test/ only)
[ ] Signed-out /p/:slug/:id opens (guard bypass); PLT004 identical not-found; SEO meta (title/description/canonical/og) emitted, never legal_name
[ ] Onboarding resume redirect: home->step, complete->home, exited flag honored, currentStep==null no redirect
[ ] ep02_phase_completion_checklist -> 21/21 PASS (EP-02:214-241)
[ ] documents/Task-Implementation/EP-02/EP-02-20-Trust-System-Verification-Report.md present with VP1-12 + cross-cutting evidence and GO/NO-GO verdict
```