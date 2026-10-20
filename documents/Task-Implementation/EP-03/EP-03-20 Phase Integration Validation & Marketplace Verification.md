# Task Implementation Plan — EP-03-20: Phase Integration Validation & Marketplace Verification

**Task ID:** EP-03-20 | **Phase:** EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 7 (Validation / Phase Gate) | **Priority:** Critical | **Dependencies:** All EP-03 items (EP-03-01 → EP-03-19) | **Plan Reasoning / Coding Reasoning (approved):** High / High

**Status:** Planning artifact only — no production code written, no Phase doc modified. Awaiting approval.

---

## 1. Task Objective

Execute the approved EP-03-20 objective (Phase Plan §11, lines 455–464) and produce the auditable evidence that closes EP-03 and unblocks EP-04:

1. **12-point end-to-end marketplace validation** across the full stack (mirrors the EP-02-20 trust-validation pattern, locally executable at code level; staging-gated items executed by operator and recorded with owners):
   1. Verified pro creates listing → `published` + searchable
   2. Unverified pro blocked (`PLT005`)
   3. Deterministic ranking fixtures reproduce identical order
   4. Consumer search → ranked, paginated results
   5. Contract offer → accept → escrow funded
   6. Milestone evidence → client verify → milestone release; ledger correct
   7. Double-blind review submit → reveal
   8. Encrypted messaging: Realtime + offline replay
   9. Scheduling: availability → booking → conflict rejection
   10. Portfolio proof linkage renders on listing detail
   11. Earnings/transaction history matches ledger
   12. Dispute freeze + resolve moves escrow
2. **Performance & security gates:** filtered search p95 < 400 ms (staging, 5k–10k seeded `published` listings), RLS leak matrix 0 leaks, `dart analyze` + `flutter test` + VISUAL-IDENTITY token asserts green.
3. **Cross-cutting verification scripts + EP-03 phase-completion checklist** re-verifying zero client-side financial/matching logic, no PII leakage, RLS default-deny, design-token compliance, no hardcoded secrets, and all 21 §10 phase completion criteria.
4. **Marketplace Verification Report** (`documents/Task-Implementation/EP-03/EP-03-20-Marketplace-Verification-Report.md`) with per-point pass/fail + SQL evidence, CI workflow run artifacts, staging demo walkthrough record, EP-04 readiness checklist, and a **GO / NO-GO** verdict.
5. **Minimal wiring/glue fixes only** where validation surfaces integration gaps (bootstrap/provider registration, test-harness routes) — never system logic.

---

## 2. Business Problem Being Solved

EP-03's 19 subsystems were each approved individually, mostly with **live staging evidence explicitly deferred to EP-03-20** (EP-03-06/07/08/09/10/11/12/13/14/15/16/18/19 DoDs all name this gate). Without this task:

- **Composition failures stay invisible.** Listing publish → ranking → discovery → contract → escrow release → review → messaging → scheduling → earnings → dispute is a 6-system chain; each unit suite can stay green while the chain breaks (missing provider registration, stale caches, envelope normalization drift).
- **The 12-point marketplace promise is unproven.** Phase §9/§10 commit to a functioning 2-party marketplace "under real transaction conditions". Only an integrated validation proves the escrow release ledger, double-blind invariant, trade gate, and offline messaging actually interoperate.
- **Deferred debts have no owner.** The p95 <400 ms gate (`scripts/bench_ranking.sh` — currently **absent from the repo**), the LIVE crawl/head check deferred by EP-03-19 (FA-05), the EP-03-18 staging waivers (`054`/`055` live runs, live drain), and goldens named in the EP-03-19 DoD are all orphaned without EP-03-20.
- **EP-04 cannot safely start.** Local Market (product taxonomy, store catalog, 3-party) builds directly on listing/escrow/notification/ranking patterns; a false-positive gate ships structural debt into EP-04.
- **Phase status is unverifiable.** §10's 21 completion criteria + "all EP-03 items Completed" need a structured, auditable checklist — currently EP-03-16 is "Proposed — pending approval" and EP-03-19's DoD is unchecked with an approved §10 scope amendment.

---

## 3. Scope

### In scope

| Area | Detail | Location |
|---|---|---|
| VP1–VP12 integration suite | 12 fake-E2E tests composing the REAL `*Service → Repository → RemoteDataSource → EnvelopeParser → Mapper → Provider → Screen` stacks; only transport/storage/rate boundaries faked (EP-02-20 §5.1 "real composition at the seam") | `test/integration/marketplace/` (new dir) |
| VP reuse where already covered | VP10 (proof linkage) reuses `test/integration/service_listing_proof_flow_test.dart`; VP12 extends `test/integration/support/service_dispute_flow_test.dart`; VP6/VP7 reuse `test/integration/finance/escrow_proxy_seam_test.dart` + `test/integration/trust/escrow_lifecycle_integration_test.dart` composition patterns | Extend, don't fork |
| Cross-cutting verification scripts | EP-03-wide re-runs of the existing `trust_*` scans (they already walk all of `lib/systems` + `lib/data`); new targeted scans only where a real gap is proven (ranking-override scan, marketplace PII scan) | `test/integration/verification/` |
| Phase completion checklist | `ep03_phase_completion_checklist.dart` mapping all 21 criteria (`EP-03:217-241`) → evidence path, mirroring `ep02_phase_completion_checklist.dart` | new |
| p95 benchmark | `scripts/bench_ranking.sh` (seed + `hey`/`k6` + p95 assertion + JSON artifact) against a 5k–10k `published` local/staging seed; staging run recorded in report | new (named deferred gate; does not exist today) |
| Staging evidence pack | CI run IDs (`Database RLS & RPC Tests`, `PR Validation`, `Staging Deployment`), operator 12-point walkthrough on staging (two accounts), read-only SQL evidence queries (ledger rows, escrow transitions, anon/member RLS probes), robots/sitemap/head live checks (EP-03-19 deferrals) | Operator-run + report |
| Marketplace Verification Report | Per-point pass/fail, SQL evidence, issues/remediation, EP-04 readiness checklist, GO/NO-GO | `documents/Task-Implementation/EP-03/EP-03-20-Marketplace-Verification-Report.md` (new) |
| Definition of Done | Verification companion checklist for project-lead sign-off | `documents/Task-Implementation/EP-03/EP-03-20-Definition-of-Done.md` (new) |
| Minimal wiring fixes | Only where validation proves a gap: provider/registration glue in `lib/app/` + `lib/data/data_layer.dart`; test-harness route coverage in `test/support/harnesses/router_harness.dart`. Documented-deviation clause for shared-widget defects surfaced by responsive gates (EP-02-20 Issue-1 precedent) | Conditional |

### Out of scope

- **No new `supabase/migrations/*.sql`** — all EP-03 server surfaces frozen; `git diff --stat supabase/migrations/` = 0 must hold at approval. Any server gap found is recorded in the report with owner (EP-03-01/02 follow-up), not patched here.
- No new RPCs, RLS policies, storage buckets, or ranking-formula changes; no new `pubspec.yaml` dependencies (§18-CI "format/analyze/test" posture and lean-installer stance preserved; `hey`/`k6` are operator tooling, not app deps).
- No new screens, widgets, or design tokens; no redesign of any EP-03 system logic.
- No SSR/prerender (SPA + static shell remains, per EP-03-19).
- No EP-04 build (Local Market/products/stores/3-party) — only readiness assessment.
- No modification of the approved Phase doc, ARCHITECTURE.md, AGENT.md, or any EP-03 task plan/DoD.
- No live payment-gateway calls, no real PII, no real network in automated tests (EP-02-20 boundary discipline).

---

## 4. Existing Asset and Dependency Analysis

Inspected (read-only) before proposing anything new:

| Asset | Path | Finding — how it is reused |
|---|---|---|
| **EP-02-20 pattern (the template)** | `documents/Task-Implementation/EP-02/EP-02-20-Phase Integration Validation & Trust System Verification.md` + `EP-02-20-Trust-System-Verification-Report.md` | Proven structure: 12 VPs in a per-domain integration dir, 7 cross-cutting scans, 21-criteria checklist, report with GO/NO-GO. EP-03-20 mirrors this shape exactly (VPs → `test/integration/marketplace/`, report → EP-03-20 report). |
| **EP-01-20 report** | `documents/Task-Implementation/EP-01/EP-01-20-Foundation-Verification-Report.md` | Report format template named by the Phase doc. |
| **EP-02-20 VP composition** | `test/integration/trust/*` (12 files, 62 tests) | Real-stack composition with `MockSupabaseClientFactory` closure-state handlers; widget VPs at 390/1280 via `widget_harness`. Reused pattern verbatim. |
| **Mock transport** | `test/support/factories/mock_supabase_client_factory.dart` (`create({currentUser, rpcHandlers, queryResults, queryError})`) — scripted RPC handlers with closure state, PLT-envelope injection, `FakeGoTrueClient` auth seam | **Reuse as-is.** No in-memory DB needed; handlers own state (proven in `kyc_flow_test.dart`, `service_dispute_flow_test.dart`). |
| **Marketplace fakes** | `test/support/fakes/fake_service_listing.dart`, `fake_service_search.dart`, `fake_service_contract.dart`, `fake_service_review.dart`, `fake_scheduling.dart`, `fake_contract_escrow.dart`, `fake_earnings_repository.dart`, `fake_escrow_repository.dart`, `fake_financial_repository.dart`, `fake_dispute_repository.dart`, `fake_admin_review.dart`, `fake_kyc_remote_data_source.dart` | All EP-03 legs have scripted fakes with call counters, error injection (`PLT003/004/005`), and realistic state machines (e.g. `FakeServiceReviewRemoteDataSource` implements blind-reveal; `FakeSchedulingRemoteDataSource` implements idempotent replay + overlap `PLT005`). **Reuse; extend a fake only if a capability is proven missing.** |
| **Platform fakes** | `fake_auth.dart` (`FakeAuthProvider.sessionOverride`), `fake_taxonomy.dart`, `fake_storage.dart`, `fake_notifications.dart`, `fake_portfolio.dart`, `fake_network.dart` (`FakeConnectivityMonitor`, `ScriptedHttpClient`), `fake_verification.dart` | Cover auth/taxonomy/storage/push/connectivity seams needed by VPs. **Reuse.** |
| **Harnesses** | `test/support/harnesses/widget_harness.dart` (`pumpApp/pumpScreen` 390×844), `router_harness.dart` (`doorRouter` — hosts `/services`, `/s/...`, `/c/...`, `/p/...` but **lacks contracts, reviews, messaging, scheduling, earnings**), `responsive_harness.dart`, `async_harness.dart` | `widget_harness` reused as-is. `router_harness` **extended** with the missing authenticated families (one reusable test-infra change instead of 6 ad-hoc routers). |
| **Builders/matchers** | `test/support/builders/entity_builders.dart`, `dto_builders.dart`; `test/support/matchers/*` | Reused for fixtures; marketplace DTO row builders already live in the fakes (`FakeServiceListingRepository.listing()`, contract/review/scheduling `row()` statics). |
| **Existing EP-03 integration tests** | `test/integration/service_listing_proof_flow_test.dart` (EP-03-15, 3 flows), `test/integration/support/service_dispute_flow_test.dart` (EP-03-17 freeze/unfreeze state machine), `test/integration/finance/escrow_proxy_seam_test.dart`, `test/integration/trust/escrow_lifecycle_integration_test.dart`, `test/integration/trust/dispute_escrow_integration_test.dart` | VP10 and VP12 **extend/compose these** rather than duplicating; escrow/ledger composition pattern lifted for VP5/VP6/VP11. |
| **Cross-cutting scans** | `test/integration/verification/trust_financial_logic_scan_verification.dart` (walks **all** of `lib/systems` + `lib/data` with arithmetic-adjacency regex + documented exceptions), `trust_theme_token_scan_verification.dart` (walks all `lib/` except `lib/app/theme/`, shrink-only allowlist), `trust_legal_name_document_scan_verification.dart`, `trust_gateway_abstraction_verification.dart`, `trust_storage_posture_verification.dart`, `secret_scan_verification.dart` | Financial + theme scans **already cover EP-03 paths** — re-run, don't recreate. Gaps proven only for ranking-override and EP-03 PII breadth (see §6). |
| **Phase checklist pattern** | `test/integration/verification/ep02_phase_completion_checklist.dart` (file-existence + evidence mapping, 21 entries) | **Create sibling** `ep03_phase_completion_checklist.dart` for `EP-03:217-241`. |
| **Router/guard + SEO seam** | `lib/app/router/*` (`route_paths.dart`, `route_guard.dart`), `lib/engine/growth_engine/*` (`listing_seo_meta.dart`, `seo_head.dart`, conditional `seo_service` web/stub), `web/robots.txt`, `web/sitemap.xml`, `web/index.html`, `web/manifest.json` | Validated at code level by existing tests (`route_ep0319_test.dart`, `listing_seo_meta_test.dart`, `seo_head_test.dart`, `seo_router_shapes_test.dart`, `marketplace_discovery_seo_test.dart`); EP-03-20 adds only the deferred **live** checks (crawl/head/robots on staging). |
| **DB test surface** | `supabase/tests/database/001…056` (60 pgTAP files; 56 = SEO posture incl. positive anon-ranking assert; 054/055 notification outbox; 023–046 marketplace/contract/review/messaging/scheduling/ranking/earnings/dispute posture+enforcement) | Re-run full suite as the authoritative server proof; **no new SQL migrations**. Read-only staging evidence queries go in an operator script, not CI. |
| **CI** | `.github/workflows/database-rls-tests.yml` (`supabase db reset` → `supabase test db` + migration secret scan), `reusable-validation.yml` (`flutter analyze` + `flutter test --coverage` + secret scan), `staging-deployment.yml` (migrate → web build → Cloudflare deploy → 200 smoke), `production-promotion.yml` (staged-commit check + manual approval) | EP-03-20 cites run IDs as artifacts and required-check names in the checklist; adds **no** workflow changes (bench is operator-run; converting it to CI is a recommendation, not this task). |
| **Latest risk context** | `89884b7` (EP-03-19 anon-browse corrective: `service_ranking_search` → `SECURITY DEFINER`, `20261017090001`) | VP1/VP4/VP2 must regression-verify **anonymous** ranking/search (`/services`, `/s/:industrySlug`) as part of the gate. |
| **Missing assets (genuine gaps)** | `scripts/bench_ranking.sh` (referenced by EP-03-06/07 DoDs, **does not exist**), `supabase/seed.sql` (**absent**), EP-03-20 doc/DoD/report (**absent**), `test/integration/marketplace/` (**absent**), harness routes for contracts/reviews/messaging/scheduling/earnings (**absent**), no golden infra (`golden_toolkit`/`matchesGoldenFile` = 0 hits repo-wide) | Each addressed explicitly in §6. |

**Dependency status (phase audit input, verified from DoD headers/commits):** EP-03-07/08/09/10/11/14/15/17/18 record `Completed` (some with documented waivers to this gate); **EP-03-16 DoD is "Proposed — pending project-lead approval"**; **EP-03-19's DoD is unchecked** with a §10 approved scope amendment. EP-03-20's criterion-21 audit must record these as entry debts owned by the project lead — this task cannot mark other tasks complete.

---

## 5. Reuse / Extension / Refactoring Assessment

| Proposed need | Verdict | Rationale (why not the alternatives) |
|---|---|---|
| 12 VP integration tests | **Reuse pattern → create sibling files** in `test/integration/marketplace/` | EP-02-20 files are trust-domain-specific; no existing marketplace E2E exists for contracts/reviews/messaging/scheduling/earnings (unit/widget only). New files are the evidence artifact — not duplication. |
| VP10 proof linkage | **Reuse + extend** `service_listing_proof_flow_test.dart` | The 3 flows already exist; duplicating them in a new VP file would fork evidence. Extend with gate assertions (responsive 390 check if absent). |
| VP12 dispute→escrow | **Compose** `service_dispute_flow_test.dart` + `trust/dispute_escrow_integration_test.dart` patterns | Contract-freeze and escrow-move legs each proven; the VP adds the joined ledger assertion. |
| Test transport / fakes | **Reuse as-is** | Recon verified each EP-03 fake exposes injection (`nextError`, magic ids, `overlapNextBook`) and counters needed for all 12 VPs. Extend only on proven gap; no parallel fakes. |
| `router_harness` route coverage | **Extend** | Currently hosts only public/marketplace-discovery placeholders; 8+ VPs need contracts/reviews/messaging/scheduling/earnings screens under a real GoRouter. One shared extension beats per-test ad-hoc routers (existing precedent uses ad-hoc only where unavoidable). |
| Financial-logic scan | **Reuse verbatim** (`trust_financial_logic_scan_verification.dart` already walks `lib/systems` + `lib/data`) | Recreating it would duplicate a proven scanner; its exception list already documents gateway adapters + conversion-preview. |
| Theme-token scan | **Reuse verbatim** (walks all `lib/`) | Already the Rule-5 gate; adding a marketplace twin violates reuse-first. |
| Ranking-override scan | **New (small, genuine gap)** | Nothing asserts "client never re-sorts ranking results / AI never influences order" (`AGENT.md:7`). No existing scanner covers ordering. Designed as a narrow static scan + behavior assertion reusable by EP-04. |
| EP-03 PII scan | **New (small, genuine gap)** | `trust_legal_name_document_scan_verification.dart` scopes to portfolio only; EP-03 adds `legal_name`-adjacent surfaces (listing detail, contracts, messaging previews, earnings). New scan walks EP-03 dirs with the same comment-stripping + empty-findings pattern; keeps the portfolio scanner untouched. |
| p95 benchmark | **New (named deferred gate)** | `scripts/bench_ranking.sh` documented in EP-03-06/07 DoDs and phase §8/§10 but absent. No seed fixture exists. Designed as env-parameterized operator tooling (`hey`/`k6` + SQL seed loop) with JSON artifact; does not touch app deps. |
| Phase checklist | **New, pattern-reused** | `ep02_*` is EP-02-bound; structure cloned. |
| Report + DoD | **New, template-reused** | EP-02-20 report/DoD templates. |
| DB posture | **Reuse** existing 60 pgTAP files | All 12 server legs already have posture/enforcement suites (023–056 + 001/005/008 leak matrices). No new pgTAP required; the checklist maps them as evidence. |
| Minimal wiring fixes | **Conditional** | EP-02-20 §5.18 discipline: glue only (`lib/app/`, `lib/data/data_layer.dart`), plus documented-deviation clause for shared-widget defects surfaced by responsive gates (EP-02-20 Issue-1 precedent). |

No duplicate data models, validations, authorization rules, status systems, APIs, or services are proposed. Every new asset is test/validation tooling or a documentation artifact — the production surface stays frozen.

---

## 6. Recommended Technical Approach

### 6.1 Design principles (binding)

| Principle | Source |
|---|---|
| Validate, don't implement | EP-01-20/EP-02-20 precedent |
| Real composition at the seam | Only Supabase client / Dio / storage / Hive faked |
| Server-authoritative assertions | Tests assert server state drives UI; client never mutates gate/ledger/ranking columns |
| Reuse-first | §5 assessment; extend before create |
| Fail-closed gate | Any VP/scan/criterion failure blocks GO; report records NO-GO with owner |
| Evidence-based | Every VP produces named evidence (test file + assertion IDs); SQL evidence, CI run IDs, bench JSON, walkthrough records attached |
| Staging-gate honesty | Where live staging is required (p95, crawl, live drain, operator walkthrough), the report records `OPERATOR EVIDENCE PENDING` with named owner + run instructions — never a silent green (EP-03-18 waiver precedent, ENV-007) |

### 6.2 Proposed repository structure (new/changed files only)

```text
test/integration/marketplace/
├── listing_publish_discovery_integration_test.dart     # VP1 + anon regression of ranking/search
├── trade_gate_block_integration_test.dart              # VP2 (PLT005 unverified publish/bid gate)
├── ranking_determinism_integration_test.dart           # VP3 (fixture order verbatim + no re-sort)
├── search_pagination_integration_test.dart             # VP4 (ranked, keyset paginated, filters)
├── contract_lifecycle_integration_test.dart            # VP5 (offer→accept→escrow funded linkage)
├── milestone_release_ledger_integration_test.dart      # VP6 (evidence→verify→release ledger parity)
├── double_blind_review_integration_test.dart           # VP7 (submit→blind→both→reveal, no oracle)
├── messaging_realtime_offline_integration_test.dart    # VP8 (ciphertext + Realtime + offline replay dedup)
├── scheduling_booking_conflict_integration_test.dart   # VP9 (book→overlap PLT005→cancel→rebook, TZ)
├── earnings_ledger_parity_integration_test.dart        # VP11 (summary/history == ledger fixture, no client reduce)
└── dispute_freeze_resolve_gate_integration_test.dart   # VP12 (file→freeze→resolve→release/refund + ledger)
# VP10: extend test/integration/service_listing_proof_flow_test.dart (no new file)

test/integration/verification/
├── ep03_phase_completion_checklist.dart                # 21 criteria (EP-03:217-241) → evidence paths
├── marketplace_ranking_override_scan_verification.dart # new gap: no client re-sort / no AI ordering
└── marketplace_pii_scan_verification.dart              # new gap: no legal_name/document_path/escrow echo in EP-03 UI paths

test/support/harnesses/router_harness.dart              # extend: contracts/reviews/messaging/scheduling/earnings
scripts/bench_ranking.sh                                # new: seed + hey/k6 + p95<400ms + JSON artifact
scripts/ep03-staging-evidence.sql                       # new: read-only SQL evidence pack (operator, not CI)

documents/Task-Implementation/EP-03/
├── EP-03-20 Phase Integration Validation & Marketplace Verification.md   # this plan (persisted at handoff)
├── EP-03-20-Definition-of-Done.md                      # verification companion
└── EP-03-20-Marketplace-Verification-Report.md         # final artifact w/ GO/NO-GO
```

`lib/` additions: **none by default**. Conditional glue only (§6.8).

### 6.3 Per-VP approach (composition + key assertions)

Each VP: `MockSupabaseClientFactory` scripted handlers (or scripted fakes where the platform seam is the fake, e.g. messaging queue) → real datasource → real repository → real provider → real screen via `pumpApp`/`router_harness`. Test names carry DoD IDs (`DoD-VP1a…`), file headers document composition + `// Run: flutter test <path>`.

- **VP1 — Verified pro publish → searchable.** Real `ServiceListingService`/provider + `FakeServiceListingRepository` + `FakeServiceSearchRepository`: create → publish → handler flips `published` → search/browse returns it; media upload via `FakeStorageService` to `service-listing-media`; **anonymous** browse regression (post-`89884b7`): anon handler path returns published-only, draft invisible.
- **VP2 — Unverified blocked.** Service-level surface of `PLT005` + `TradeVerificationGate`/`TradeVerificationBadge` widget assertion; verified-unlock contrast case; client never writes gate columns (asserted by scan).
- **VP3 — Determinism.** Fixed fixture set → identical order across repeated calls (handler + `FakeServiceSearchRepository` verbatim order); UI renders payload order with zero re-sort; `rank_weights_version`/`rank_version` surfaced read-only if present in DTO; server-side determinism evidence = pgTAP `034` + staging SQL double-call (operator).
- **VP4 — Ranked pagination.** Keyset `(score,id)` pages: page 2 excludes page 1, `hasMore` exhaustion, filters (`profession`, `industrySlug`, query) round-trip; no unbounded fetch (call-count asserts); p95 remains a staging gate (not re-benchmarked here).
- **VP5 — Contract lifecycle.** `FakeServiceContractRepository` (seeded `contractDetailRow`) + real service: offer (sum==total) → accept (`active`) → escrow linkage via `ContractEscrowOrchestrator` (`FakeEscrowRepository` funded detail); negatives: malformed sum `PLT003`, self-offer `PLT005`, stranger `PLT004` (no oracle).
- **VP6 — Milestone release ledger.** `FakeEscrowRepository` (writeAvailable) + orchestrator: evidence complete → client verify → release; assert payee `available +amount`, payer `held −amount`, one release ledger row, paired audit row, `contract_events(milestone_released)` fixture — **no client arithmetic** (scan-backed).
- **VP7 — Double-blind.** `FakeServiceReviewRemoteDataSource` blind-reveal server rule: one submit → `you_submitted=true`, counterparty invisible; second submit → both `is_revealed=true` atomically; pre-reveal `get_for_listing` returns only revealed rows; `DoubleBlindStatusCard` states; duplicate `PLT005`.
- **VP8 — Messaging.** `AesCipher` round-trip on `body_encrypted` (no plaintext), `FakePushRealtimeGateway` delivery, offline `ActionQueue` (+`FakeStorageEngine`/Hive box) → replay dedup by `client_message_id`; PII-redacted preview (`***last4`-class bodies); non-participant read path absent from client seams.
- **VP9 — Scheduling.** `FakeSchedulingRepository`/remote: availability upsert → `availability_list` → book `pending` → overlap `PLT005` → cancel frees → rebook; idempotency-key replay returns same id; Lagos/UTC wall-clock round-trip; `HivorrErrorState` "Pick another time" surfacing.
- **VP10 — Proof linkage.** Extend existing flow test: linked proof carousel order verbatim, unlinked → `HivorrEmptyState` + owner CTA, non-owner `PLT001`; ensure responsive assertion present.
- **VP11 — Earnings parity.** `FakeEarningsRepository` seeded from the same ledger fixture as VP6: summary/available/held/pending and history rows match fixture exactly; static scan asserts no client reduce determines settlement (existing financial scan); `earnings_released` notification hookup smoke via `FakeNotificationService`.
- **VP12 — Dispute→escrow.** Compose `service_dispute_flow_test.dart` state machine: file on funded contract → contract + escrow freeze; milestone verify blocked with `EscrowFrozenBanner`; resolve → release **or** refund per outcome with ledger + audit fixtures; withdraw unfreezes.

### 6.4 Cross-cutting verification scripts

| Script | Action | Lenses |
|---|---|---|
| `trust_financial_logic_scan_verification.dart` | **Re-run unchanged** | 0 client-side financial arithmetic across `lib/systems` + `lib/data` |
| `trust_theme_token_scan_verification.dart` | **Re-run unchanged** | 0 `Colors.*`/hex/`fontFamily`/`FontWeight.w800` (allowlist shrink-only) |
| `secret_scan_verification.dart` | **Re-run unchanged** | 0 secrets in `lib/`+`test/`+config |
| `trust_gateway_abstraction_verification.dart`, `trust_storage_posture_verification.dart` | **Re-run unchanged** | gateway boundary + bucket posture still hold |
| `marketplace_ranking_override_scan_verification.dart` | **New** (narrow) | no client re-sort of ranking/search results in marketplace discovery/search paths; no `lib/ai/` influence on ordering; order passes through verbatim |
| `marketplace_pii_scan_verification.dart` | **New** (narrow) | 0 `legal_name`/`document_path`/`account_number`/escrow-amount echoes in EP-03 UI paths (`marketplace`, `documents`, `reviews`, `communication`, `scheduling` + earnings provider); comment-stripped, empty-findings assert |
| `ep03_phase_completion_checklist.dart` | **New** (clone of `ep02_*`) | All 21 §10 criteria → evidence file/test/SQL mapping; aggregate fail lists misses |

### 6.5 Performance benchmark (`p95 < 400 ms`)

- `scripts/bench_ranking.sh` (new): parameterized (`SUPABASE_URL`, anon key, `N=100`, `Q='legal'`, `LIMIT`), seeds 5k–10k `published` listings via SQL loop (dev/staging only), runs sequential `POST /rpc/service_ranking_search` through `hey` or `k6` (skip-with-warning if neither installed), asserts p95 < 400 ms, writes `bench_ranking_<env>_<date>.json`.
- Local run on `supabase start` + `db reset` gives a directional number; the **staging** run (seeded volume) is the §10 gate — recorded in the report with the JSON artifact; owner named if environment access is unavailable at execution time.
- `EXPLAIN (ANALYZE, BUFFERS)` capture (`Bitmap Index Scan on service_listings_search_vector_gin` when query present; ranking partial index otherwise) as SQL evidence.

### 6.6 Staging evidence pack (operator, fail-closed record)

- **CI artifacts:** run IDs for `Database RLS & RPC Tests` (60 pgTAP files), `PR Validation` (`Format, Analyze, Test` + builds), `Staging Deployment`.
- **Operator walkthrough (two accounts: verified professional + client):** the 12 points end-to-end on staging with screenshots/URLs; anon window for `/services`, `/s/:industrySlug`, `/s/:slug/:id`, `/c/:slug/:id` (post-fix regression); draft/unknown → not-found; one-hop alias; login-resume `?next=`.
- **SQL evidence** (`scripts/ep03-staging-evidence.sql`, read-only): escrow state transitions + `financial_transactions` release rows + `financial_audit_trail` pairs; contract/milestone statuses; review `is_revealed` invariant; appointment overlap rejection; dispute freeze (escrow + contract); earnings summary vs ledger `SELECT`s; anon draft-fetch returns `PLT004` (indistinguishable) and anon search returns `published`-only.
- **EP-03-19 deferred items:** live crawl/head/robots/sitemap check on deployed staging web; p95 (above); goldens — see decision D2.

### 6.7 EP-04 readiness assessment (report section)

Structured readiness checklist covering: listing/contract/review/messaging/scheduling patterns reusable for product/store/order equivalents; taxonomy universality (seed-not-migration proof); provider-agnostic escrow + ledger discipline reusable for 3-party; notification outbox fan-out reusable; ranking engine extension path (`service_listings.profession_id` → `product_listings.product_id` mirror); storage bucket/RLS pattern reuse; design-system + test-infrastructure reuse. Each item marked READY / READY-WITH-NOTE / BLOCKER with evidence.

### 6.8 Minimal wiring-fix strategy

| Gap type | Fix location | Example |
|---|---|---|
| Missing provider/registration | `lib/app/app.dart`, `lib/data/data_layer.dart` `register*Layer` | a VP-required provider not reachable in-app |
| Bootstrap init order | `lib/app/` | ordering violating api → auth → taxonomy → … |
| Missing test-harness route | `test/support/harnesses/router_harness.dart` | contract/review/messaging/scheduling/earnings routes |
| Shared-widget responsive defect surfaced by 390 px gates | `lib/shared/widgets/*` **only with documented deviation** in the report (EP-02-20 Issue-1 precedent) | `Flexible`-wrap class of fix |

Constraint: wiring/glue only — no system logic, no server surface, no scope expansion.

---

## 7. Required Systems, Modules, and Components

| Component | Location | Responsibility | Action |
|---|---|---|---|
| VP1–VP12 suite | `test/integration/marketplace/` (11 new files) + VP10 extension | 12-point integrated validation | Create / Extend |
| Marketplace test stack support (if needed) | `test/support/marketplace/` (only if ad-hoc composition repeats >2×) | shared `buildMarketplaceStack` + `marketplaceTestRouter` (mirrors `portfolio_test_support.dart`) | Conditional create (reuse-first checked first) |
| Cross-cutting scans | `test/integration/verification/` (2 new + 5 re-runs) | static gates | Create / Reuse |
| Phase checklist | `test/integration/verification/ep03_phase_completion_checklist.dart` | 21-criteria audit | Create |
| Benchmark + seed | `scripts/bench_ranking.sh` | p95 gate | Create |
| Staging evidence pack | `scripts/ep03-staging-evidence.sql` | read-only SQL evidence | Create |
| Router harness extension | `test/support/harnesses/router_harness.dart` | authenticated route coverage for VPs | Extend |
| Verification report | `documents/Task-Implementation/EP-03/EP-03-20-Marketplace-Verification-Report.md` | GO/NO-GO artifact | Create |
| DoD | `documents/Task-Implementation/EP-03/EP-03-20-Definition-of-Done.md` | sign-off checklist | Create |
| Reused infrastructure | fakes, factories, harnesses, builders, matchers, existing integration tests, pgTAP suites, CI workflows | composition + evidence | Reuse (no change unless gap proven) |
| Frozen surfaces | `supabase/migrations/*`, `supabase/tests/database/*`, `lib/systems/**` (logic), `web/*` | validated, not modified | No change |

No new dependencies.

---

## 8. Data Requirements

- All fixtures use placeholder values: no real PII, no real legal names, `0000000000`-style bank numbers, synthetic `entity_id`s. Ledger/review/scheduling fixtures derive from the same seeded contract per VP to prove cross-system parity (VP6 ↔ VP11 share the ledger fixture definition).
- No live Supabase/network in automated tests; staging SQL evidence is read-only `SELECT`s executed by the operator.
- Report contains only pass/fail facts, file paths, run IDs, and non-sensitive SQL outputs — no `legal_name`, `document_path`, credential bytes, account numbers, or keys.
- No Hive cross-contamination: in-memory/temp-dir stores (existing `InMemoryOnboardingProgressStore` precedent; `FakeStorageEngine`).

---

## 9. Database Considerations

- **No migrations; freeze enforced.** `git diff --stat supabase/migrations/` = 0 is an approval gate.
- Authoritative server proof = full `supabase db reset` + `supabase test db`: 60 pgTAP files including `001/005` leakage matrices, `023–046` marketplace/contract/review/messaging/scheduling/ranking/earnings/dispute posture+enforcement, `034` ranking enforcement, `042/043` contract-escrow linkage/release, `045/046` earnings, `048–051` service disputes, `054/055` notification outbox, `056` listing SEO posture (incl. positive anon-ranking assertion). RLS leak gate = suite green **plus** the explicit anon/member probes in `scripts/ep03-staging-evidence.sql`.
- Read-only evidence queries: escrow/ledger/audit joins; `is_revealed` invariant; appointment exclusion; anon `service_listing_get(draft)` → identical `PLT004`; anon `service_ranking_search` published-only.
- Any server gap discovered is recorded with owner (`EP-03-01/02` follow-up) — not patched in this task.

---

## 10. API Requirements

**No new endpoints/RPCs.** Consumed (verified-existing) surface per VP:

| Leg | RPC / seam |
|---|---|
| VP1/VP2/VP3/VP4 | `service_listing_create/update/publish/unpublish/list_mine`, `service_listing_get`, `service_ranking_search` (now `SECURITY DEFINER`, anon-granted), `service_search`/FTS via ranking RPC, `service_favorite_toggle` |
| VP5/VP6/VP12 | `service_contract_offer/accept/cancel/complete_milestone/verify_milestone/close`, `financial_escrow_*` (create/fund/milestone/release/refund), `service_dispute_file/submit_evidence/resolve/withdraw` |
| VP7 | `service_review_submit/get_mine/get_for_listing`, reveal RPC |
| VP8 | `conversation_ensure_for_contract`, `message_send/list`, `conversation_list`, Realtime channel |
| VP9 | `availability_upsert/list`, `appointment_book/reschedule/cancel` |
| VP10 | `service_listing_link_portfolio_items`, `service_listing_portfolio_list` |
| VP11 | `service_earnings_summary`, `service_transaction_history` |
| All | Envelope `{success,code,message,data}` normalized through the existing `*EnvelopeParser`s (`PLT000/001/003/004/005`) |

---

## 11. User Interface Requirements

No new screens/widgets. Validation renders the real EP-03 screens:

- **Discovery/search:** `MarketplaceDiscoveryScreen`, `MarketplaceSearchScreen` (ranking order verbatim, chips, keyset pagination, `HivorrEmptyState`/`HivorrErrorState`).
- **Detail:** `ServiceDetailScreen` (media carousel order, `TradeVerifiedBadge`, review aggregate, `ServiceProofSection`, `Book/Request Proposal` CTA, self-listing disabled).
- **Contracts:** contract detail/offer/candidate screens (`contract_list/detail/offer_screen.dart` family).
- **Reviews:** reveal screen with `DoubleBlindStatusCard` states.
- **Messaging:** conversation list/thread (pending→sent offline states).
- **Scheduling:** availability editor, book, detail (conflict `HivorrErrorState`).
- **Earnings:** `EarningsDashboardScreen`, `TransactionHistoryScreen`, `ContractEarningsDetailScreen`.
- **Support:** service dispute filing/detail with `EscrowFrozenBanner`.
- **Public routes:** `/services`, `/services/search`, `/services/:id`, `/s/:slug/:id`, `/s/:industrySlug`, `/c/:slug/:id`, `/p/:slug/:id`.
- All assertions hold at 390 px (dpr 3) and 1280 px with no overflow (extending the EP-02-20 VP12 pattern; key screens also at 600/1024 via the existing responsive-matrix precedent).

---

## 12. User Experience Considerations

- The gate is expressed as user-visible outcomes: a shared `/s/` link opens without login; a client can hire, fund, verify, release, and review without seeing a technical error string; a professional sees earnings that match the ledger; a dispute visibly freezes escrow and shows guidance until resolved.
- No user-visible copy changes; `PLT*` codes never surface (friendly not-found/conflict states only); verification-safe badge language (`Trade Verified`/`Identity Verified`).
- Operator walkthrough doubles as a UAT sanity pass for the release readiness narrative.

---

## 13. Security Considerations

- Zero-trust: no pricing/ranking/escrow/review decisions in client code (scans enforce); server remains sole mutator.
- Anon surface strictly `published`-only; `PLT004` indistinguishability preserved for draft/unknown (assertions both client- and SQL-side); no oracle in reviews pre-reveal or contracts (stranger `PLT004`).
- PII: no `legal_name`/`document_path`/account data/escrow amounts in any UI path, log, meta, or share URL (new PII scan + `PiiRedactor` assertions + secret scan).
- Notification dispatcher allowlist unchanged; malformed payload → drop (existing unit tests re-run).
- RLS leak matrix: 0 leaks (pgTAP + explicit staging probes); storage posture re-verified (private evidence vs public playback).
- Financial integrity: release only via verified-milestone precondition; ledger + audit pairs asserted; double-blind invariant asserted server-rule-faithful.
- No secrets in scripts/report; bench credentials via env only (ENV-006); staging/production access unchanged.

---

## 14. Performance Considerations

- p95 < 400 ms filtered search on staging with 5k–10k `published` seed (`scripts/bench_ranking.sh`), with `EXPLAIN` index evidence.
- Keyset pagination only; call-count asserts prove no unbounded fetch/N+1 across 12 VPs (single `getListing` + single proof list per detail open; paged ranking calls).
- Realtime/offline replay asserts remain deterministic via fake_async; no new timers left un-drained.
- Test-suite runtime stays within the 20-minute CI timeout (VP suite sized like EP-02-20's 62 tests; scans are file walks).

---

## 15. Testing Strategy

| Layer | Cases |
|---|---|
| Unit | Existing EP-03 unit suites re-run as regression; no new unit layer except pure builders already covered (SEO meta). |
| Widget | VP screens at 390/1280 (600/1024 matrix for discovery/detail/contract); states: empty/error/not-found/conflict; token compliance enforced by scan. |
| Integration (new) | VP1–VP12 per §6.3, real composition at the seam, DoD-ID-named tests, envelope normalization asserted per VP (`PLT003/004/005`), no raw exceptions escape. |
| Static/scan | 5 re-used scans + 2 new scans + `ep03_phase_completion_checklist.dart` (21 criteria) + secret scan. |
| Database | Full `supabase db reset` + `supabase test db` (60 files) — the authoritative RLS/RPC proof; zero migration diff. |
| Performance | `scripts/bench_ranking.sh` local + staging; `EXPLAIN` capture. |
| Staging (operator) | 12-point walkthrough, anon vs authenticated, crawl/head/robots/sitemap live checks, SQL evidence pack, CI run ID capture. |
| Failure scenarios | Network loss via `FakeConnectivityMonitor`; malformed envelopes → typed `ApiException`; server push disabled; draft/unknown/stranger paths; offline replay after reconnect. |

---

## 16. Recommended Implementation Sequence

1. **Entry audit + harness gap-fill** — record phase item status (incl. EP-03-16 approval + EP-03-19 sign-off debts); extend `router_harness` with authenticated route families; smoke-compose one VP to prove the pattern (unblocks the rest).
2. **Discovery legs (VP1–VP4)** — incl. the anonymous ranking regression from commit `89884b7`.
3. **Transaction legs (VP5–VP7)** — contract → escrow → release → review, with shared ledger fixture.
4. **Coordination legs (VP8–VP9)** — messaging (crypto/Realtime/offline) + scheduling (conflict/TZ).
5. **Trust/ledger legs (VP10–VP12)** — proof linkage extension, earnings parity, dispute freeze/resolve.
6. **Cross-cutting gate** — two new scans + checklist + re-run all `trust_*` scans + `dart analyze` + full `flutter test` + `supabase db reset/test db` + freeze checks (`supabase/migrations` diff = 0, `pubspec.yaml` diff = 0).
7. **Benchmark + staging evidence** — `scripts/bench_ranking.sh` (+seed) local run; staging run + operator walkthrough + SQL evidence + live crawl checks; capture CI run IDs.
8. **Report + DoD + GO/NO-GO** — write `EP-03-20-Marketplace-Verification-Report.md` + `EP-03-20-Definition-of-Done.md`; fix wiring defects found (re-validate); state verdict. Stop before EP-04.

---

## 17. Expected Outcome

A **Marketplace Verification Report** (EP-01-20/EP-02-20-style markdown) proving the 2-party services marketplace operates as one integrated system under transaction conditions: per-point pass/fail with SQL evidence, 12 VP suites green with real composition, 0 RLS leaks, p95 < 400 ms on staging (or recorded operator evidence with owner), clean `dart analyze`/`flutter test`/token asserts, all 21 §10 criteria mapped to evidence, EP-03-19's named deferrals (live crawl, p95, goldens) resolved or explicitly waived with owners, and an **EP-04 readiness checklist with a GO/NO-GO verdict** — unblocking EP-04 only on GO.

---

## 18. Definition of Done

- [ ] All 12 validation points pass with named evidence (test file + assertion IDs); VP10/VP12 extend existing suites without duplication.
- [ ] Cross-cutting scans green: 5 re-run `trust_*`/secret scans + 2 new scans (ranking override, EP-03 PII) + `ep03_phase_completion_checklist.dart` (21/21 with evidence).
- [ ] p95 < 400 ms filtered search evidenced (JSON artifact + `EXPLAIN`) on staging seed, or recorded `OPERATOR EVIDENCE PENDING` with named owner + exact run commands (no silent green).
- [ ] RLS leak matrix: 0 leaks (60-file pgTAP suite green + explicit anon/member probes in the evidence pack); anon `published`-only including the `service_ranking_search` regression.
- [ ] `dart analyze` 0 issues; full `flutter test` green; `supabase db reset` + `supabase test db` green; `git diff --stat supabase/migrations/` = 0 and `pubspec.yaml` diff = 0 at approval commit.
- [ ] Zero `Colors.*`/hex/`fontFamily` in touched widgets; Rule-5 scan green; no `legal_name`/`document_path`/secrets in code, fixtures, scripts, or report.
- [ ] Staging evidence pack attached: CI run IDs, operator walkthrough record (anon + two accounts), SQL evidence outputs, live robots/sitemap/head checks; EP-03-19 named deferrals each resolved or waived with owner; goldens decision recorded.
- [ ] Report + DoD written; issues/remediation logged; any wiring fixes confined to `lib/app/`, `lib/data/data_layer.dart`, test harness (shared-widget deviation documented if needed).
- [ ] EP-04 readiness checklist complete with verdict; report ends **GO** or **NO-GO** (with blockers + owners); other EP-03 items' approval debts (EP-03-16/19) recorded for project-lead closure — this task does not mark other tasks complete.
- [ ] Project lead signs; Phase doc, ARCHITECTURE.md, AGENT.md, and all EP-03 plans/DoDs unmodified by this task.

---

## 19. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High** (matches the approved Phase Plan row for EP-03-20).
- **Justification:** The task introduces no new financial state machine, ranking math, or cryptographic code (rules out Very/Extremely High), but it is **integration-critical and adversarially sensitive**: 12 cross-system compositions (listing→ranking→contract→escrow→review→messaging→scheduling→earnings→dispute), server-authoritative assertions where a false green would gate EP-04 on a broken chain, RLS/`PLT004` non-oracle discipline, PII/secret scans with comment-stripping and shrink-only allowlists, environment-gated evidence handling (staging vs local) that must never overclaim, and disciplined reuse of a large existing test infrastructure. `High` provides the rigor for evidence integrity and composition correctness without the ledger-grade exhaustive matrices reserved for EP-03-01/02/06/11.

---

## 20. Decisions to Confirm (recommended defaults)

- **D1 — Staging availability:** default = code-level VPs + scans run fully locally; staging items recorded as operator-evidence entries with owners if no staging access exists at execution (EP-03-18 waiver precedent). Confirm who executes the staging walkthrough.
- **D2 — Goldens (EP-03-19 named deferral):** default = substitute the repo's proven responsive no-overflow matrix (390/600/1024/1280) for "golden visual" checks and record "golden image infrastructure" as an accepted, named deviation (no golden tooling exists repo-wide; adding `golden_toolkit` conflicts with the no-new-deps/lean-installer stance). Alternative: approve adding golden infra.
- **D3 — Harness extension vs ad-hoc routers:** default = extend `router_harness.dart` once (reusable by EP-04) rather than per-test routers.
- **D4 — Bench tooling:** default = `scripts/bench_ranking.sh` auto-detecting `hey`/`k6`, skip-with-warning + record-owner if neither is installed; no CI workflow change in this task.

---

*Planning artifact only. No production code written, no Phase doc modified, no other files touched. On approval, this plan would be persisted (e.g. `documents/Task-Implementation/EP-03/EP-03-20 Phase Integration Validation & Marketplace Verification.md`) and implementation would begin by switching out of Plan mode to a build agent. A background recon agent is still mapping the marketplace/slice file paths; if it returns details that refine §4/§6, I'll surface them as a short addendum.*

---

# Addendum to EP-03-20 Plan — Post-Recon Refinements

## A1. §4 asset precision (verified paths)

The implementation surface is fully mapped; the compose-real-stacks approach is feasible for all 12 VPs with the exact seams below:

| Leg | Real production seams to compose | Existing fakes to reuse |
|---|---|---|
| VP1–VP4 | `ServiceListingService` (`lib/systems/marketplace/services/`), `MarketplaceSearchProvider` (`lib/data/providers/marketplace_search_provider.dart`, 250 ms debounce, verbatim RPC order), `ServiceSearchRepositoryImpl` (cache-first browse, network-first FTS, `weights_version` invalidation), `ServiceSearchIndex.warmBrowse` (`lib/engine/search_engine/`), screens `marketplace_discovery_screen.dart` / `marketplace_search_screen.dart` / `service_detail_screen.dart` | `fake_service_listing.dart`, `fake_service_search.dart` |
| VP5–VP7 | `ContractService` + `ServiceContractProvider`, `ContractEscrowOrchestrator` (`lib/systems/finance/services/`, phases `not-funded → not-verified → ready`), `EscrowService` proxy seam, `ServiceReviewService` | `fake_service_contract.dart`, `fake_contract_escrow.dart`, `fake_escrow_repository.dart`, `fake_service_review.dart` |
| VP8 | `MessagingService` + `MessageCrypto` (AES-GCM) + `MessagingProvider` (Realtime inserts, outbox replay) + `ActionQueue`; thread UI lives in `lib/systems/dashboard/screens/messages_screen.dart` / `conversation_screen.dart` | `fake_storage.dart` (`FakeStorageEngine`), `fake_network.dart`, real `MessageCrypto` |
| VP9 | `SchedulingService` (idempotency keys, Africa/Lagos default) + `SchedulingProvider` + 4 screens | `fake_scheduling.dart` |
| VP10 | `service_listing_portfolio_list` via `ServiceListingService.fetchProofs`/`ServiceProofProvider` + `ServiceProofSection` | existing `service_listing_proof_flow_test.dart` composition |
| VP11 | `ServiceEarningsService` + `EarningsProvider` + `TransactionHistoryProvider` + `EarningsDashboardScreen`/`TransactionHistoryScreen` | `finance/fake_earnings_repository.dart` |
| VP12 | `DisputeService.fileServiceDispute/getServiceCase` + `SupabaseServiceDisputeNotifier` fan-out + `DisputeProvider` + `EscrowFrozenBanner` | `support/fake_dispute_repository.dart` |
| Public/anon regression | `/services`, `/services/search`, `/s/:slug/:id`, `/s/:industrySlug`, `/c/:slug/:id`, `/p/:slug/:id` + `ListingSeoMetaBuilder`/`SeoHead` | `seo_router_shapes_test.dart`, `marketplace_discovery_seo_test.dart` (extend, don't fork) |

Confirmed absent today (so no duplication risk): `test/integration/marketplace/`, any EP-03 phase checklist, any integration test importing `ServiceContract/ContractService/SchedulingProvider/EarningsProvider/MessagingProvider/ServiceSearchRepository`, and `scripts/bench_ranking.sh`.

## A2. §6.8 wiring fixes — candidate gaps already visible (Step 1 will confirm)

The map surfaced exactly the kind of integration debt this gate is designed to expose. Step 1 (entry audit) must verify each; if confirmed, they are **minimal glue fixes**, not new features:

| Candidate gap (verify first) | Evidence | Likely fix if confirmed |
|---|---|---|
| **Reviews layer never registered**: `registerServiceReviewLayer` (data_layer) and `registerReviewsLayer` (system) are defined but never invoked in `app_bootstrap.dart`; `HivorrApp` MultiProvider has no review providers; `review_submit_screen.dart` / `review_reveal_screen.dart` read `ServiceReviewProvider` in a silent try/catch (degrades to no-op) | recon §11 + §3 | Register the layer/provider in `app_bootstrap.dart` / `app.dart` (glue only). **VP7 must assert provider presence so the silent catch cannot mask this.** |
| **Dispute notifier not injected**: `ServiceDisputeNotifier`/`SupabaseServiceDisputeNotifier` (`dispute_notify` fan-out) not passed into `registerDisputeLayer` | recon §7 | Pass the notifier in `registerDisputeLayer` (glue) — or record as designed-later if inspection shows an intentional decision. |
| **Notification engine not bootstrapped**: `initializeNotifications` has no caller in `lib/main.dart`/bootstrap; `NotificationProvider` not in `HivorrApp`; templates/tap dispatcher have no runtime consumers (consumption path is `SupabasePushReceiver` → `notification_events`) | recon §8 | Wire `NotificationLayer` init + provider registration if confirmed missing (glue); otherwise record the actual consumption wiring as the finding. |
| Unused alternates: `registerMarketplaceLayer`, `registerDocumentsLayer`, system `registerSchedulingLayer` (data_layer equivalents win) | recon §11 | No action; note in report as non-defects. |

These findings do **not** change scope: fixes stay inside the approved glue set (`lib/app/`, `lib/data/data_layer.dart`), and any deviation beyond it requires the same documented-deviation treatment EP-02-20 used.

## A3. Testing-strategy refinements

- **VP7 (reviews)** gains a mandatory wiring assertion (`ServiceReviewProvider` resolvable from the app stack) in addition to the blind-reveal behavior — directly targeting the silent-catch risk above.
- **VP3 (determinism)** explicitly does **not** adopt `RankingFormula`/`RankingWeights` (`lib/engine/recommendation_engine/`, pure-Dart mirror, currently unused in `lib/`) as a client-side ordering authority. Determinism evidence = server fixture order + verbatim client pass-through + no-re-sort scan. The untested/unused mirror goes into the report's EP-04 recommendations, not into scope.
- **New widget coverage gaps noted** (not blockers): `review_submit_screen`, `review_reveal_screen`, `service_listing_media_screen`, `milestone_editor_screen` lack dedicated widget tests. Where a VP renders them, the VP file carries the assertion; no separate test-creation detour.
- **VP8** composes the real `MessageCrypto` + `ActionQueue` and asserts `client_message_id` dedup on replay (matching the EP-03-13 DoD offline claim).

## A4. DoD amendment

Add to §18 DoD: *"Entry-audit wiring findings (reviews layer registration, dispute notifier injection, notification bootstrap) verified; confirmed gaps fixed as documented glue or recorded with owners in the report — no silent pass."*
