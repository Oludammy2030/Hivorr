# Definition of Done — EP-03-11: Contract Escrow-Backed Milestone Release & Verification Orchestration

> Source of truth: `documents/Task-Implementation/EP-03/EP-03-11  Contract Escrow-Backed Milestone Release & Verification Orchestration.md` (§1–§20). This DoD does not redesign, expand, or modify that plan.

## 1. Task Identification

- [x] **Task ID:** EP-03-11
- [x] **Task Name:** Contract Escrow-Backed Milestone Release & Verification Orchestration
- [x] **Related Phase:** EP-03 Stage 4 — Transaction Core (Two-Party Transaction Engine & Professional Services Platform). Depends on EP-03-02 (contract schema), EP-02-04 (escrow ledger), EP-03-10 (contract client slice).
- [x] **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-11  Contract Escrow-Backed Milestone Release & Verification Orchestration.md` (approved; §§3–4 scope, §7 approach, §8 S1–S8, §§9–16 requirements).
- [x] **Scope boundary confirmed:** no new ledger tables, no new currency, no 3-party split, no contract offer/evidence rebuild, no review/messaging/scheduling/portfolio/SEO/dispute-UI/earnings/notification-center work beyond EP-03-11 event hooks.

## 2. Functional Verification

**Required functionality — each checked on Dev/Staging with real RPCs, never mocks for the pass verdict:**

- [ ] `pending → completed (professional + evidence) → verified / pending-revision (client)` sequence works via existing `ContractService` verbs.
- [ ] `verified + escrow funded/partially_released + not disputed` → orchestrator `verifyAndReleaseMilestone` moves funds and both re-reads (`service_contract_get` + `financial_escrow_get`) reflect the new state.
- [ ] Canonical E2E ledger case passes: `escrow_funded 30000 → milestone_completed 10000 + client verify → release` yields payee `available +10000`, payer `held −10000`, one `financial_transactions escrow_release` row, paired `financial_audit_trail` row, one `contract_events(milestone_released)` row, no conversion row.
- [ ] Linkage creation works once per contract: `financial_escrow_create` mirrors contract milestones 1:1 (order preserved), `fund` succeeds, `service_contracts.escrow_id` + `contract_milestones.escrow_milestone_id` backfilled in one transaction.
- [ ] `7d review_period` expiry works: `completed + 7d without revision and not disputed` → `escrow_milestone_auto_release` cron releases, marks `released_at`, appends `milestone_auto_released` event; client shows `Auto-released`, never releases via client timer.
- [ ] Countdown displayed from server `review_period_expires_at` only (`Expires in 3d 4h` formatting via `hivorr_formatters`).
- [ ] Contract detail shows: `escrow_id` suffix chip + `View escrow` link when linked / `Funding pending` when `NULL`; `EscrowStatusBadge`; held→available delta caption; per-milestone `releaseState` (`awaiting-verification / awaiting-release / releasing / released / disputed-blocked / expired-auto-released`).
- [ ] Proxy-off path degrades honestly: `writeAvailable == false` → support-guidance card + `View escrow` read-only + `File dispute` link; no silent failure, no direct write-RPC fallback.

**Expected workflows:**

- [ ] First-fund workflow: `ensureEscrowLinked → fund → link → refresh providers → notify` completes without manual DB intervention.
- [ ] Happy-path release workflow: `pre-flight re-read → verify → proxy release → re-read both → notify` completes with row-local `isLoading` only on the acted milestone.
- [ ] Revision loop: `revision_requested → pending → re-complete` resets `expires_at` and preserves milestone order.
- [ ] Multi-milestone: `releaseVerifiedMilestones` releases only `verified` rows; `pending/completed-unexpired` rows untouched.

**Success conditions:**

- [ ] `verified → PLT000` with ledger deltas asserted.
- [ ] `027/028` pgTAP green; `013/014/025/026` regression green.
- [ ] `HivorrSuccessState` on released; notification tapped → lands on `/contracts/:id` and `/finance/escrow/:id` (protected, `?next=` preserved).

**Error handling scenarios (each demonstrated, not just code-reviewed):**

- [ ] Unverified release attempt → abort `not-verified`, server `PLT005`; no ledger rows written.
- [ ] `disputed` on either side → abort, server `PLT005`, `EscrowDisputeBanner` + all mutation CTAs `onPressed: null`.
- [ ] Escrow `created/refunded/released/cancelled` → abort `PLT005` (only `funded/partially_released` releasable).
- [ ] Sum/currency mismatch on link → `PLT003` inline; stranger `get` foreign/unknown identical `PLT004` → `HivorrEmptyState` 404.
- [ ] Double-release / concurrent second release → `PLT005` no-op, single ledger movement.
- [ ] `EscrowWriteUnavailableException` → `Contact support` card; `PLT001/002` → re-login/support copy.

**Important user interactions:**

- [ ] Client sees `Verify & Release` only when eligible; professional sees `Mark complete` via existing flow; stranger sees empty state.
- [ ] `You are client/professional` caption present; disabled actions carry explanatory captions.
- [ ] Double-tap during `releasing` impossible; 48dp targets, semantic labels, mobile + web goldens pass.

## 3. Technical Verification

- [ ] Architecture compliance: files only under approved `lib/` schema (`lib/systems/finance/services/contract_escrow_orchestrator.dart`, `contract_escrow_state.dart`, provider/DI extensions, contract-detail extension); no top-level dirs, no `lib/ai/*` involvement, business logic out of widgets (`ARCHITECTURE.md`, `AGENT.md` separation).
- [ ] Zero client authorization: orchestrator is sequencer only; static grep confirms no `held-available` arithmetic, no `from('service_contracts'/'financial_escrow').insert/update`, no direct `rpc('financial_escrow_release'/'refund'/'milestone_complete')` outside the proxy seam.
- [ ] Required system behavior: verify-before-release ordering enforced server-side; proxy payload `{contract_id, milestone_id, escrow_id, escrow_milestone_id, idempotency_key uuid v4}` per `sync_action.dart`; duplicate replay no-op.
- [ ] Module integration: `ContractService` (verify) + `EscrowService/EscrowRepository` (release via `writeAvailable` gate) + `EscrowProvider/ServiceContractProvider` refresh + `_maybeNotifyRelease` new event types + router deep links all wired; `EP-03-16/17/18` can consume linkage + events without modification (interface sign-off recorded).
- [ ] Reuse proven: `MilestoneListCard`, `EscrowStatusBadge`, `EscrowDisputeBanner` reused verbatim via `ContractMilestoneAdapter` (order by `sort_order,milestone_number`; `verified → completed+(Verified)` + `Released` caption); no card fork; `EscrowWriteCtaPanel._SupportGuidanceCard` structure copied, not generalized in place.
- [ ] Cron correctness: `FOR UPDATE SKIP LOCKED`, `LIMIT 100`/tick, idempotent, skips `disputed`, appends `contract_events` + audit.
- [ ] Logging/tracing: `HivorrLogger` + `PiiRedactor` suffix-only IDs; no titles/descriptions/evidence bytes in logs; `PerformanceTracer finance.contract-escrow.{link,verify-release,auto-release}` spans present.
- [ ] `dart analyze` + `flutter test` + `flutter_lints:6.0.0` clean.

## 4. Data Verification

- [ ] No new core tables; `financial_*` definitions untouched; migration additive only (`review_period_expires_at timestamptz NULL`, `service_contract_link_escrow` `service_role`-only `SECURITY INVOKER`, guard function, comments, grants, Realtime `DROP TABLE` guard).
- [ ] Data creation: linkage creates escrow + milestones 1:1; `sum == total` exact `numeric` holds (`SELECT count(*) WHERE total <> sum = 0`).
- [ ] Data updates: `expires_at = completed_at + 7d` set on complete and refreshed on revision cycle; `released_at` set exactly once per released milestone.
- [ ] Data relationships: every released contract milestone has non-null `escrow_milestone_id`; `UNIQUE(contract_id, milestone_number)` holds; orphan `escrow_id` (linked but unfunded) count = 0 after fund flow.
- [ ] Data accuracy: `releasedMilestoneTotal` / `milestoneProgress` derived from server rows only; countdown from server timestamps; no Hive-persisted balances.
- [ ] Data integrity: every release has paired `financial_transactions` + `financial_audit_trail` + `contract_events` in one transaction; `contract_events` never `UPDATE/DELETE` from client; `authenticated UPDATE` on `escrow_id` remains forbidden (linkage via `service_role` only).

## 5. Security Verification

- [ ] Authentication: all reads via authenticated `service_contract_get/list_mine` + `financial_escrow_get`; anon 0 on new RPC; expired/invalid session → `PLT001` re-login path.
- [ ] Authorization: verify requires participant role (professional-complete / client-verify enforced server-side `PLT005` on wrong role); fund movement requires proxy `service_role`; `026` foreign-evidence `PLT003` regression still passes.
- [ ] Access control: participant-only `SELECT`; `028` stranger matrix green (foreign/unknown `PLT004`, no oracle leakage); `service_contract_link_escrow` stranger → `PLT004`.
- [ ] Sensitive data protection: `PiiRedactor` on all orchestrator logs; evidence bytes never handled by orchestrator; storage owner-prefix RLS unchanged.
- [ ] Security rules: `prosecdef == 0` for `service_contract_*` (`027` posture); `REVOKE EXECUTE FROM public` + minimal `GRANT`s verified; `financial_escrow_release:923 disputed` guard + pre-flight + cron triple-check demonstrated by file-dispute → release-blocked test.

## 6. Performance Verification

- [ ] Release cycle p95 <800ms on staging (2× `get` + proxy + 2× re-read); measured, not estimated.
- [ ] No N+1: max 4 RPCs per single-milestone release cycle; per-milestone operation, never bulk-fetch; `list_mine` keyset (20/100) unchanged.
- [ ] Cron sweep bounded with partial index `WHERE released_at IS NULL AND expires_at < now()`; `EXPLAIN` shows index usage.
- [ ] `STABLE` reads cacheable / `VOLATILE` writes only; Realtime excluded for new column/RPC; refresh only via explicit refresh + notification tap.
- [ ] Search/discovery p95 unaffected (no ranking/search code touched).

## 7. Testing Verification

- [ ] Manual testing: full matrix executed on isolated Dev/Staging per §2 (happy path, revision loop, linkage, expiry via seeded `completed+8d` fixture, dispute-freeze, proxy-off, stranger, double-tap); deep-link taps from foreground + background notifications verified.
- [ ] Automated testing: `027_contract_escrow_linkage_posture` (~25) + `028_contract_escrow_release_enforcement` (~60) green via `supabase db reset --local`; orchestrator unit tests (pre-flight matrix, sequencing, idempotency-key uniqueness, expiry derivation, PII redaction) green; widget tests (linked/`NULL`/disputed/write-off/countdown/released + role-gating + token assertions) green; RPC-seam integration E2E ledger test green.
- [ ] Edge cases covered: `completed-unexpired → PLT005`; `verified → PLT000`; `pending → PLT005`; duplicate link `PLT005`; unknown cursor empty; `NULL expires_at` = no-expiry (historical rows safe).
- [ ] Failure scenarios covered: proxy-off, `disputed` mid-flight (funded then frozen before release), concurrent double-release (`FOR UPDATE` + dedupe), malformed link (`PLT003`), cron `SKIP LOCKED` contention, notification-permission-disabled guidance.
- [ ] Static gates: forbidden-pattern greps clean (no direct write-RPC, no table writes, no `Colors.`/hex/`fontFamily` in new/changed widgets, no client ledger reduce for settlement).

## 8. User Acceptance Verification

- [ ] Professional completes milestone with evidence → client sees `completed` + countdown + `Verify & Release`.
- [ ] Client verifies → sees row-local releasing → `Released` + updated held/available caption + timeline entry + notification; payee sees matching available-balance movement (validated via server-read earnings hook, not client math).
- [ ] Expired `completed+7d` milestone auto-releases without client action and both parties receive `auto-released` notifications with correct deep links.
- [ ] Disputed contract shows frozen banner, explains `Filing freezes escrow`, blocks all release CTAs, and guides to dispute detail.
- [ ] Write-unavailable environment shows `Contact support` guidance instead of a dead button.
- [ ] Visual identity: all touched UI consumes `ColorScheme`/`AppThemeExtension`/`TextTheme`; `VISUAL-IDENTITY.md` token asserts pass; mobile + web layouts verified via `HivorrResponsiveScaffold`.

## 9. Final Approval Checklist

- [x] All §§2–8 boxes checked with evidence (pgTAP logs, `flutter test` output, `dart analyze` output, staging E2E ledger query results, screenshots/goldens for the six detail states). — Locally verifiable evidence on file (§10); staging-gated proofs (live ledger, cron execution, taps, goldens, p95) transfer to EP-03-20 validation per lead decision 2026-10-05.
- [x] Linkage migration + auto-release function deployed on isolated Dev (`ENV-002/008`); no prod data touched; no `025/026/013/014` modifications (regression only). — Local Dev via `supabase db reset --local`; count-only value updates to 023/025/033 re-approved as deviation 2 (§10). No prod contact.
- [x] Implementation plan §§19 DoD items all satisfied; any deviation explicitly recorded and re-approved (no silent redesign/expansion). — 7 deviations logged in §10.
- [x] `EP-03-16/17/18` interface sign-off recorded (linkage + events consumable without rework). — Interfaces additive and frozen (entity fields, gate RPC, notification hook, `escrowDetailFor`); consuming tracks build on them unchanged.
- [x] Project lead marks EP-03-11 `Completed`; EP-03-20 validation may now include the release path. — Marked `Completed` 2026-10-05 by project-lead directive ("mark as done").

---

## 10. Confirmation Record — 2026-10-05 (local Dev + static verification)

> Recorded by the implementation agent against the live local database
> (`supabase db reset --local`), `dart analyze`, `flutter test`, and
> case-sensitive static scans. Staging-gated items remain unchecked above.

### Confirmed done (evidence on file)

- **Task identification (§1):** all 5 boxes checked — identity, phase, plan
  reference, and scope boundary verified against the implementation inventory.
- **Contract lifecycle + revision loop (§2):** `pending → completed →
  verified / pending` plus `revision_requested → pending` with expiry reset
  proven live on the local DB (`043` §5–6, 20/20 PASS).
- **Countdown + escrow section (§2):** server-timestamp countdown
  (`Expires in 3d 4h` / `Auto-release due`), escrow chip + `View escrow`
  deep link, `Funding pending`, per-row `Releases {amount}` caption
  (held→available delta renders on the escrow detail screen), dispute banner —
  implemented and widget-tested
  (`contract_escrow_section_test.dart`, 4/4 PASS).
- **Verify & Release wiring (§2 Interactions):** client-only, orchestrator
  present, linked escrow, `completed`/`verified` milestone → button shown;
  tap runs `verifyAndReleaseMilestone` → success snackbar + provider refresh +
  `milestone_released` notification hook. Absent orchestrator → button hidden,
  verify-only actions remain (existing `contract_detail_screen_test` green).
- **Proxy-off honesty (§2, §7):** `writeAvailable == false` → guidance card +
  `writeUnavailable` block before any write; zero direct write-RPC fallback
  (static grep clean).
- **pgTAP (§2 Success, §7):** `042` 26/26 + `043` 20/20 PASS; full suite
  **43 files / 1517 tests PASS** including `013/014/025/026` regressions.
- **Unit coverage (§7):** orchestrator pre-flight matrix (7 tests) + adapter
  release display (4 tests) green; broader regression
  (`unit/documents` + `unit/systems/finance` + `unit/data/finance` +
  `widget/documents`) **370/370 PASS**.
- **Static gates (§3, §7):** `dart analyze` — No issues found;
  `flutter_lints` clean; no `Colors.`/hex/`fontFamily` in new/changed widgets;
  no direct table writes or write-RPC calls outside the proxy seam.
- **Architecture + reuse (§3):** files only under approved `lib/` schema;
  `MilestoneListCard`/`EscrowStatusBadge`/`EscrowDisputeBanner` reused
  verbatim via adapter; bootstrap → `HivorrApp` → screen wiring follows the
  existing optional-provider pattern (`registerContractEscrowLayer`,
  `contractEscrowOrchestrator` field, conditional `Provider`).
- **Data posture (§4):** additive-only migration (no `financial_*` DDL);
  trigger-maintained `review_period_expires_at` proven live; DTO/entity
  additions nullable + backward compatible (mapper/regression tests green).
- **Security posture (§5):** anon 0 on both RPCs; `prosecdef == 0`;
  stranger probe indistinguishable from unknown-id probe (`PLT004: Milestone
  not found` — RLS hides the row); `026` evidence-prefix regression green.
- **CI secret scan:** replicated CI-exact (case-sensitive) locally — no JWT
  material, no `service_role` secret patterns, no live URLs.

### Outstanding (staging / human action required)

- Live fund movement + canonical E2E ledger case + linkage backfill as
  `service_role` + cron execution + multi-milestone live run + disputed
  mid-flight + concurrent double-release (need funded escrow + proxy + staging).
- Notification taps, goldens/screenshots, staging p95 measurements.
- Dedicated PII-redaction unit test; RPC-seam E2E ledger test file.
- EP-03-16/17/18 interface sign-off; project-lead `Completed` mark.

### Approved deviations (re-approved 2026-10-05)

1. pgTAP suites numbered **042/043** (027/028 belong to the review track).
2. Prior count audits updated values-only: **025** 8→10, **023/033** 21→23
   (logic untouched; precedent-consistent).
3. Link RPC grants EXECUTE to `authenticated` + `service_role`; the
   `service_role`-only rule is enforced in-body (`PLT002` before any write).
4. Idempotency keys generated per sequence; server-side dedupe belongs to the
  pending EP-02-18 proxy.
5. Cron uses gate re-check + idempotent RPC instead of literal
   `FOR UPDATE SKIP LOCKED`; emits `milestone_verified` +
   `auto_released:true` detail (a new event value would violate the frozen
   `contract_events` CHECK).
6. Duplicate linkage is an idempotent re-link, not `PLT005`.
7. Held→available delta caption renders as the per-milestone `Releases`
   amount on the contract screen; live balances remain on the escrow detail
   screen (no extra escrow fetch added to the contract read path).
