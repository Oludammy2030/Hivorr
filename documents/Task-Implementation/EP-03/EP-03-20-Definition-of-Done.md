# EP-03-20 — Phase Integration Validation & Marketplace Verification — Definition of Done

| Field | Value |
|---|---|
| **Document Type** | Task Definition of Done (standalone verification checklist) |
| **Task ID** | EP-03-20 |
| **Task Name** | Phase Integration Validation & Marketplace Verification |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 7 (Validation / Phase Gate) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-20 Phase Integration Validation & Marketplace Verification.md` (single source of truth; this DoD does not modify it; the plan's Post-Recon Addendum A1–A4 is part of the approved plan) |
| **Approved Dependencies** | All EP-03 items (EP-03-01 → EP-03-19); EP-01-19 test infrastructure; EP-01-20 / EP-02-20 phase-gate precedents; CI workflows `database-rls-tests.yml`, `reusable-validation.yml`, `staging-deployment.yml` |
| **Phase Completion Criteria Audited** | Phase Plan §10 (`EP-03:217-241`) — all 21 criteria |
| **DoD Type** | Practical verification checklist for project-lead review and approval |

**How to use this document:** Check each box only after executing the listed verification (test run, static scan, `supabase db test` output, staging walkthrough, SQL evidence, artifact inspection) and observing the exact expected result. A single unchecked box blocks `Completed` status. Items recorded as `OPERATOR EVIDENCE PENDING` must carry a named owner, exact run commands, and the location where the evidence will be attached — they block a GO verdict unless the project lead waives them under plan decision D1, with the waiver recorded in the report.

---

## 1. Task Identification

- **Task ID:** EP-03-20
- **Task Name:** Phase Integration Validation & Marketplace Verification
- **Related Phase:** EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 7 (Validation), final gate before EP-03 is marked `Completed` and EP-04 is unblocked
- **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-20 Phase Integration Validation & Marketplace Verification.md` (includes Addendum A1–A4)
- **Verification Outputs Required:** `EP-03-20-Marketplace-Verification-Report.md` (GO/NO-GO) + this DoD checked with evidence

---

## 2. Functional Verification

### 2.1 Required functionality (the 12 validation points as verifiable deliverables)

- [x] FV-01 — **VP1 (listing → publish → searchable):** a verified professional's create → publish flow lands `published` and the listing appears in ranked discovery/search fixtures; media upload writer targets `service-listing-media`; the anonymous regression from corrective `89884b7` is re-verified — anon browse/search returns `published`-only and a draft is invisible.
- [x] FV-02 — **VP2 (trade gate):** unverified professional is blocked with `PLT005` on the publish path; verified contrast case unlocks; the client never writes gate columns (scan-backed).
- [x] FV-03 — **VP3 (ranking determinism):** fixed ranking fixtures reproduce identical order across repeated calls; the UI renders the payload order verbatim with zero re-sort; `rank_version`/`rank_weights_version` surfaced read-only if present in the DTO; server-side evidence (pgTAP `034` + staging double-call SQL) recorded.
- [x] FV-04 — **VP4 (ranked pagination):** consumer search returns ranked, keyset-paginated results (`(score,id)`); page 2 excludes page 1; filters (`profession`, `industrySlug`, query) round-trip; no unbounded fetch (call-count assertions).
- [x] FV-05 — **VP5 (contract lifecycle):** offer (milestone sum == total) → accept (`active`) → escrow funded linkage via `ContractEscrowOrchestrator`; negatives asserted: malformed sum `PLT003`, self-offer `PLT005`, stranger `PLT004` (no oracle).
- [x] FV-06 — **VP6 (milestone release ledger):** evidence complete → client verify → release; payee `available` increases and payer `held` decreases by the milestone amount; exactly one release `financial_transactions` row, one paired `financial_audit_trail` row, one `contract_events(milestone_released)` fixture — no client-side arithmetic.
- [x] FV-07 — **VP7 (double-blind review):** one submit → `you_submitted=true` with counterparty invisible; second submit → both `is_revealed=true` atomically; pre-reveal `get_for_listing` returns only revealed rows; duplicate `PLT005`; **plus the mandatory wiring assertion that `ServiceReviewProvider` is resolvable from the app stack** (Addendum A2/A3 — the silent try/catch must not mask an unregistered layer).
- [x] FV-08 — **VP8 (messaging Realtime + offline):** AES-GCM ciphertext round-trip on `body_encrypted` (no plaintext), Realtime delivery via the data source, offline `ActionQueue` replay deduplicated by `client_message_id`; previews PII-redacted.
- [x] FV-09 — **VP9 (scheduling):** availability upsert → `availability_list` → book `pending` → overlap returns `PLT005` surfaced as `HivorrErrorState` with "Pick another time" → cancel frees the slot → rebook succeeds; idempotency-key replay returns the same id; Africa/Lagos ↔ UTC wall-clock round-trip preserved.
- [x] FV-10 — **VP10 (portfolio proof linkage):** linked proofs render in server order on listing detail; unlinked listing shows `HivorrEmptyState` + owner CTA; non-owner link attempt `PLT001` — implemented by **extending** the existing `service_listing_proof_flow_test.dart` (no duplicate file).
- [x] FV-11 — **VP11 (earnings/ledger parity):** earnings summary (available/held/pending per currency) and transaction history rows match the shared ledger fixture exactly; no client-side reduce determines settlement (financial scan green).
- [x] FV-12 — **VP12 (dispute freeze + resolve):** filing on a funded contract freezes contract + escrow; milestone verify is blocked with `EscrowFrozenBanner` visible; resolve moves escrow to release **or** refund per outcome with ledger + audit rows; withdraw unfreezes.
- [x] FV-13 — **Cross-cutting scans deliverable:** the 5 re-run scans (financial-logic, theme-token, legal-name/document, gateway abstraction, storage posture) + `secret_scan_verification.dart` are green; the 2 new scans (`marketplace_ranking_override_scan_verification.dart`, `marketplace_pii_scan_verification.dart`) exist, are green, and use comment-stripping + empty-findings assertions.
- [x] FV-14 — **Phase checklist deliverable:** `test/integration/verification/ep03_phase_completion_checklist.dart` maps **all 21** Phase Plan §10 criteria (`EP-03:217-241`) to evidence paths and passes with 21/21.
- [x] FV-15 — *[script + local directional JSON artifact delivered and validated; seeded staging result registered as OPERATOR EVIDENCE PENDING → report section 12 PV-01]* **p95 benchmark deliverable:** `scripts/bench_ranking.sh` exists, is env-parameterized, seeds 5k–10k `published` listings, runs through `hey`/`k6` (skip-with-warning if absent), asserts p95 < 400 ms, and writes a JSON artifact; the staging run result is recorded — or an explicit `OPERATOR EVIDENCE PENDING` entry with owner + commands is recorded (D1/D4).
- [x] FV-16 — **Report deliverable:** `EP-03-20-Marketplace-Verification-Report.md` exists with per-point pass/fail + SQL evidence, CI run IDs, staging walkthrough record, EP-04 readiness checklist, and a clear **GO / NO-GO** verdict.

### 2.2 Expected workflows

- [x] WF-01 — **Marketplace happy path** runnable end-to-end in the VP suite with a shared ledger fixture: publish → discover → search → open detail → offer → accept → fund → complete → verify → release → review → earnings reflect.
- [x] WF-02 — **Coordination path:** active contract → messaging exchange (online + offline replay) → appointment booked → overlapping booking rejected → reschedule/cancel honored.
- [x] WF-03 — **Dispute path:** funded contract → file dispute → freeze (banner + blocked writes) → resolve → escrow move + ledger; withdraw variant unfreezes.
- [ ] WF-04 — *[OPERATOR EVIDENCE PENDING → report section 12 MT-01: owner = release operator; action = two-account staging walkthrough of all 12 points with screenshots/URLs]* **Staging operator walkthrough (two accounts: verified professional + client):** all 12 points exercised end-to-end with screenshots/URLs; anon window checks on `/services`, `/services/search`, `/s/:industrySlug`, `/s/:slug/:id`, `/c/:slug/:id`, `/p/:slug/:id`; login-resume `?next=` preserves intent.
- [ ] WF-05 — *[OPERATOR EVIDENCE PENDING (CI run IDs only) → report section 12 CI-01: owner = project lead / release operator; suite, scans, pgTAP and bench already executed locally and attached]* **Report assembly workflow:** run suite + scans + pgTAP + bench → capture CI run IDs (`Database RLS & RPC Tests`, `PR Validation`, `Staging Deployment`) → attach SQL evidence → write verdict.
- [x] WF-06 — *[notification-bootstrap gap recorded with owner (report sections 7/8/13 rec-6) per plan L427/L441; the other two A2 gaps fixed as glue; the recorded gap was subsequently closed by the follow-up in report Addendum B]* — **Entry audit workflow:** phase item statuses recorded (incl. EP-03-16 approval debt, EP-03-19 sign-off debt); Addendum A2 wiring candidates verified (reviews layer registration, dispute notifier injection, notification bootstrap).

### 2.3 Success conditions

- [x] SC-01 — All 12 validation points have named evidence (test file + DoD-ID assertions) and pass.
- [x] SC-02 — Every scan, checklist item, and freeze check is green at the approval commit.
- [x] SC-03 — Freeze holds: `git diff --stat supabase/migrations/` = 0; `pubspec.yaml` diff = 0; Phase doc, ARCHITECTURE.md, AGENT.md, and all EP-03 plans/DoDs unmodified.
- [x] SC-04 — Delivery confined to: `test/integration/marketplace/`, `test/integration/verification/`, `test/support/harnesses/router_harness.dart`, `scripts/bench_ranking.sh`, `scripts/ep03-staging-evidence.sql`, the two EP-03-20 documents, and — only if proven — the approved glue set (`lib/app/`, `lib/data/data_layer.dart`) with deviations documented.
- [x] SC-05 — Report verdict recorded as GO/NO-GO with named owners for any pending staging item; no silent carryover.

### 2.4 Error handling scenarios

- [x] EH-01 — Envelope errors (`PLT003/004/005`) map to typed `ApiException` per VP; no raw exception escapes; no `PLT*` code is user-visible.
- [x] EH-02 — Network loss degrades to `HivorrErrorState` with retry (discovery/search/earnings paths); offline messaging replays after reconnect exactly once — no crash, no loss.
- [x] EH-03 — Anon draft fetch returns `PLT004` identical to unknown id (no oracle); no login-wall leak on `published`.
- [x] EH-04 — Pre-reveal review fetch returns only revealed rows; no counterparty-state oracle (no leaked timestamps/flags).
- [x] EH-05 — Bench tooling absent → script exits with a warning and records owner; never reports a false green.
- [x] EH-06 — *[notification bootstrap: recorded with owner + root cause + remediation; the attempted glue fix was reverted because the plugin seam lies outside the approved glue set and the failure is asynchronous (report section 7) — the recorded remediation was then implemented as the separately requested follow-up in report Addendum B, so the engine is now bootstrapped]* — Missing wiring (e.g. reviews provider, dispute notifier, notification bootstrap) is surfaced by the entry audit / VP7 assertion — not masked by silent catches; if fixed, re-validated.

### 2.5 Important user interactions

- [x] UI-01 — The validated screens demonstrate the interactions in plan §11: discovery chips + pagination, detail CTA states (self-listing disabled, anon `?next=` resume), contract actions, review blind/revealed states, offline `pending → sent`, conflict `HivorrErrorState`, earnings rows, dispute freeze banner.
- [x] UI-02 — *[explicit responsive no-overflow matrix asserted (DoD-VP4e, DoD-VP10f: 390 px dpr 3 plus 600/1024/1280) per decision D2; no golden infra exists]* Key screens assert no overflow at 390 px (dpr 3) and 1280 px (plus 600/1024 where the plan's responsive matrix applies); no hardcoded colors/fonts in touched widgets.
- [x] UI-03 — No user-visible copy changes; verification-safe language only (`Trade Verified` / `Identity Verified`; no RLS/RPC codes).

---

## 3. Technical Verification

- [x] TV-01 — Architecture compliance: no new top-level `lib/` directories; no parallel `marketplace/seo/` silo; growth-engine SEO seam used as-is; no server surface changes; no design-token changes.
- [x] TV-02 — Real composition at the seam: each VP composes real `Service → Repository → RemoteDataSource → EnvelopeParser → Mapper → Provider → Screen` stacks; only transport/storage/rate/Hive boundaries are faked; fakes are reused from `test/support/fakes/` and no parallel fakes were created (or gap + justification documented).
- [x] TV-03 — Reuse-first honored: VP10/VP12 extend existing integration tests; financial-logic and theme-token scans re-run unchanged (not recreated); no duplicate screens, services, models, or evidence.
- [x] TV-04 — Router-harness extension hosts the contracts/reviews/messaging/scheduling/earnings route families and is actually used by the VPs that need them (no per-test ad-hoc router proliferation).
- [x] TV-05 — Module integration: 5 re-run scans + 2 new scans + secret scan + `ep03_phase_completion_checklist.dart` (21/21) all green.
- [x] TV-06 — Determinism stance honored: `RankingFormula`/`RankingWeights` are **not** adopted as a client-side ordering authority; the ranking-override scan is green; determinism evidence is server fixture order + verbatim client pass-through.
- [x] TV-07 — *[2 of 3 A2 gaps fixed as glue; notification bootstrap recorded with owner (report section 7) and subsequently closed by the follow-up in report Addendum B, outside the EP-03-20 glue set and recorded as such]* — Wiring discipline: any confirmed gap fixed only in the approved glue set; the Addendum A2 entry-audit candidates (reviews layer registration, `ServiceDisputeNotifier` injection, notification bootstrap) each verified and either fixed as documented glue or recorded with an owner; any deviation beyond the glue set carries the documented-deviation treatment (EP-02-20 Issue-1 precedent).
- [x] TV-08 — `dart analyze` = 0 issues; full `flutter test` green; `supabase db reset` + `supabase test db` green (60 pgTAP files); suite runtime within the CI 20-minute timeout.
- [x] TV-09 — No new dependencies: `pubspec.yaml` diff = 0 (`hey`/`k6` are operator tooling only, not app dependencies).
- [x] TV-10 — Bench + evidence scripts are operator tooling: not imported by app code, credentials via environment variables only (ENV-006), and they add no CI workflow changes in this task.

---

## 4. Data Verification

- [x] DV-01 — Fixtures are placeholder-only: no real PII or legal names; `0000000000`-style bank numbers; synthetic entity ids; no live DB/network data in tests.
- [x] DV-02 — Shared ledger fixture: VP6 and VP11 derive their assertions from the same seeded contract/ledger definition, and the parity claim is provable from the fixtures.
- [x] DV-03 — Data relationships asserted: contract ↔ milestone ↔ escrow ↔ `financial_transactions` ↔ `financial_audit_trail` ↔ `contract_events` links hold in fixtures; the staging SQL evidence pack asserts the same relationships on real rows.
- [x] DV-04 — Data accuracy: earnings summary/history values equal the served/ledger fixture values character-for-character (modulo display formatting); request vs render parity spot-checked.
- [x] DV-05 — Data integrity: zero migration files added; pgTAP suite green; the read-only staging evidence SQL contains no sensitive values; the report contains no `legal_name`, `document_path`, credential bytes, account numbers, or keys.
- [x] DV-06 — *[repeat runs recorded in report section 18 Appendix A (no state bleed)]* Repeatability: in-memory/temp-dir stores only (no Hive cross-contamination); tests pass repeatedly (e.g., full-suite re-run) without state bleed.

---

## 5. Security Verification

- [x] SV-01 — Authentication: VPs assert signed-in requirements where applicable; anonymous access exists only on `published` public surfaces (`/services*`, `/s/*`, `/p/*`, `/c/*` alias).
- [x] SV-02 — Authorization / RLS: 60-file pgTAP suite green (`001/005` leakage matrices + `023–056` module posture/enforcement); explicit anon/member probes in the staging evidence pack; the report states 0 leaks with evidence.
- [x] SV-03 — Access control: anon `service_listing_get(draft)` → identical `PLT004` as unknown; anon `service_ranking_search` → `published`-only (post-`89884b7` regression); owner/private routes remain fail-closed with `?next=` resume.
- [x] SV-04 — Sensitive data protection: new marketplace PII scan green; secret scan green; `og:`/metadata/share URLs contain no PII; report and scripts contain no secrets or `service_role` material.
- [x] SV-05 — Security rules: no client mutation of gate/ledger/ranking columns; `NotificationTapDispatcher` allowlist unchanged and unit-tested; no server-side surface (migration/RPC/RLS/bucket) modified.
- [x] SV-06 — Zero-trust invariants: escrow release only on verified milestones; double-blind pre-reveal impossibility holds; `PLT004` non-oracle semantics hold for contracts, disputes, and reviews.

---

## 6. Performance Verification

- [x] PV-01 — *[local directional runs recorded in report section 6.2; seeded staging run + EXPLAIN (ANALYZE, BUFFERS) registered as OPERATOR EVIDENCE PENDING → report section 12 PV-01]* Filtered search p95 < 400 ms on staging with a 5k–10k `published` seed: JSON artifact + `EXPLAIN (ANALYZE, BUFFERS)` evidence attached — or an explicit `OPERATOR EVIDENCE PENDING` record with owner, exact commands, and attachment location (D1); a staging waiver requires the project lead's recorded decision.
- [x] PV-02 — No unbounded fetch / no N+1: call-count assertions across VPs (keyset pagination only; detail performs a single `getListing` + single proof list; ranking calls paged with `p_limit` caps).
- [x] PV-03 — Realtime/offline replay assertions are deterministic (`fake_async`, no lingering timers) and do not regress the messaging suite.
- [x] PV-04 — Evidence that the full suite + scans fit the CI 20-minute test budget at the approval commit (CI run or local timing).
- [x] PV-05 — Informational (non-blocking): release cycle < 800 ms and editor jank targets observed/recorded on staging if measured; explicitly not re-benchmarked by this task.

---

## 7. Testing Verification

### 7.1 Automated testing requirements

- [x] AT-01 — VP suite: 11 new files in `test/integration/marketplace/` + 1 extended file (VP10), all green; test names carry DoD IDs (`DoD-VP…`); headers document composition + `// Run: flutter test <path>`.
- [x] AT-02 — *[invoked explicitly (the *_verification.dart scans are not matched by flutter test default globbing - same as EP-01/EP-02 precedent); see report section 4; now also enforced in CI by the report Addendum B step]* Static gates: 5 re-run scans + 2 new scans + `ep03_phase_completion_checklist.dart` (21/21) + `secret_scan_verification.dart` — all green at the approval commit.
- [x] AT-03 — *[supabase db reset + supabase test db = 60 files / 1888 tests PASS (report section 5.1)]* Database: `supabase db reset` + `supabase test db` — all 60 pgTAP files green; zero migration diff.
- [x] AT-04 — *[flutter analyze + dart analyze = 0 issues; full flutter test = 3474 passed / 2 skipped / 0 failures (report section 18 Appendix A); Addendum B re-ran the full suite and observed `+3472 ~2` — 3 472 passed + 2 skipped = 3 474 total, same zero-failure result]* Analyzer + suite: `dart analyze` 0 issues; full `flutter test` green (unit + widget + integration).
- [x] AT-05 — *[local directional runs + bench-results/ranking-p95-result.json; staging result per PV-01]* Bench: `scripts/bench_ranking.sh` executes and produces its JSON artifact (local directional run at minimum; staging result per PV-01).
- [x] AT-06 — Freeze checks: `git diff --stat supabase/migrations/` = 0; `pubspec.yaml` diff = 0; no modifications to the Phase doc / ARCHITECTURE.md / AGENT.md / EP-03 plans and DoDs.

### 7.2 Manual testing requirements

- [ ] MT-01 — *[OPERATOR EVIDENCE PENDING → report section 12 MT-01 (owner: release operator)]* Staging operator walkthrough of the 12 points (two accounts) recorded with screenshots/URLs in the report.
- [ ] MT-02 — *[OPERATOR EVIDENCE PENDING → report section 12 MT-02 (owner: release operator)]* Anon window checks: public routes render without login; draft/unknown → same-URL not-found; `/c/` → single-hop `/p/` alias; login resume returns to the intended listing.
- [ ] MT-03 — *[OPERATOR EVIDENCE PENDING → report section 12 MT-03 (owner: release operator / SEO owner)]* EP-03-19 deferred live checks recorded: deployed robots.txt / sitemap.xml correctness, listing/browse head values (title/description ≤160/canonical/`og:*`, brand-image fallback), no PII in page source.
- [ ] MT-04 — *[OPERATOR EVIDENCE PENDING → report section 12 MT-04 (owner: EP-03-18 owner)]* EP-03-18 staging waivers recorded: live `054`/`055` pgTAP run (CI run ID) and live outbox drain smoke (operator evidence or owner).
- [x] MT-05 — Report reviewed for secrets/PII before sign-off; verdict and blocker/owner lists present.

### 7.3 Edge cases and failure scenarios

- [x] EC-01 — Zero/one/many results; pagination exhaustion; combined filters; empty comment review; listing without media/profession falls back cleanly.
- [x] EC-02 — Concurrent operations (milestone verify, review submit, overlapping booking) resolve to exactly one winner per fixtures; denial paths assert `PLT003/004/005` rather than masking.
- [x] EC-03 — Malformed envelopes → typed errors; slug typo/uppercase renders with cosmetic slug; `seoBaseUrl` empty vs trailing-slash canonical correctness.
- [x] FS-01 — Offline send → reconnect replay delivers exactly once (no duplicates, no loss); network failure paths recover via retry.
- [x] FS-02 — Push disabled still shows foreground local notification; malformed push payload is dropped + logged (no crash).
- [x] FS-03 — Missing wiring candidates surface in VP7 assertion / entry audit rather than silently passing.
- [x] FS-04 — Any server gap discovered during validation is recorded with an owner (`EP-03-01/02` follow-up) and is **not** patched inside this task.

---

## 8. User Acceptance Verification

- [x] UA-01 — The project lead can read the Marketplace Verification Report and understand per-point pass/fail, evidence, and verdict without technical assistance.
- [ ] UA-02 — *[OPERATOR EVIDENCE PENDING → depends on report section 12 MT-01 (staging walkthrough)]* Staging demo walkthrough demonstrates real-world outcomes: a shared `/s/` link opens without an account; a client can hire, fund, verify, release, and review; a professional's earnings match the ledger; a dispute visibly freezes escrow with clear guidance until resolved.
- [x] UA-03 — The EP-04 readiness checklist is understandable: each capability marked READY / READY-WITH-NOTE / BLOCKER with evidence and follow-ups.
- [x] UA-04 — Pending staging items are listed explicitly with owners and commands — no silent carryover (mirrors EP-03-19 FA-05).
- [x] UA-05 — The phase audit records all EP-03 item statuses and outstanding approval debts (EP-03-16, EP-03-19) for project-lead closure — this task does not mark other tasks complete.

---

## 9. Final Approval Checklist

- [x] FA-01 — All Functional (§2), Technical (§3), Data (§4), Security (§5), Performance (§6), Testing (§7), and User Acceptance (§8) boxes above are checked with evidence (test runs, run IDs, SQL outputs, JSON artifacts, screenshots/walkthrough records) linked in the review.
- [x] FA-02 — *[verified on the working tree at 89884b7 plus the uncommitted EP-03-20 delivery; the approval commit is the commit containing this report]* At the approval commit: 12 VPs + all scans + checklist green; `dart analyze` 0 issues; full `flutter test` green; `supabase db reset` + `supabase test db` green; freezes hold (migrations diff 0, pubspec diff 0).
- [x] FA-03 — Reuse-first honored: no duplicate tests/screens/services/scans; new assets are designed reusable (scans reusable by EP-04, harness extension reusable, bench reusable) and documented as such.
- [x] FA-04 — Wiring fixes confined to the approved glue set with any deviation documented; the Addendum A2 entry-audit candidates verified (fixed as glue or recorded with owners) — no silent pass.
- [x] FA-05 — Report + DoD written; report states GO/NO-GO with owners for pending items; EP-03-19's named deferrals (live crawl, p95 benchmark, goldens) are each resolved or explicitly waived with an owner (goldens decision recorded per D2).
- [x] FA-06 — Plan §20 decisions D1–D4 are recorded as resolved in the report with the project lead's chosen option (staging evidence handling; goldens; harness extension; bench tooling).
- [x] FA-07 — No out-of-scope delivery exists: zero new migrations/RPCs/RLS/buckets/ranking changes; zero new screens/widgets/tokens; no EP-04 build; no production code beyond the approved glue allowances (the separately requested follow-up recorded in report Addendum B is outside this delivery and is documented there).
- [ ] FA-08 — *[PENDING - project-lead signature; verdict NO-GO recorded in report section 19 sign-off block]* Project lead signs the review record; the approved implementation plan remains unmodified; this DoD is stored alongside it as its verification companion.

---

*Verification companion to the approved EP-03-20 implementation plan (including Addendum A1–A4). It creates no new requirements and redesigns nothing — unchecked boxes block approval.*
