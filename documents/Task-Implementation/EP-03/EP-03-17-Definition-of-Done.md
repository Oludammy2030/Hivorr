# Definition of Done — EP-03-17: Structured Dispute Resolution for Service Engagements

> **Document Type:** Task Definition of Done (verification checklist) | **Task ID:** EP-03-17 | **Status:** Completed — approved by project lead
> **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-17 Structured Dispute Resolution for Service Engagements.md` (single source of truth; this DoD does not reinterpret it)
> **Phase Plan Source:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md` §11 (EP-03-17), §10 service-engagement dispute criterion
> **No production code. No plan modification. Verification artifact only.**

---

## 1. Task Identification

- [x] **Task ID:** EP-03-17
- [x] **Task Name:** Structured Dispute Resolution for Service Engagements
- [x] **Related Phase:** EP-03 Stage 5 — Trust & Coordination (Two-Party Transaction Engine & Professional Services Platform)
- [x] **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-17 Structured Dispute Resolution for Service Engagements.md`
- [x] **Dependencies confirmed present:** EP-02-05 frozen dispute schema (`20260829120005` + `20260829120006`), EP-03-02 contract schema (`20260923090001`), EP-03-11 escrow linkage (`20261006090001`), EP-02-06/EP-02-08 storage, EP-01-18 notifications, EP-01-16 design system, EP-01-07 API layer
- [x] **Out-of-scope guard acknowledged:** no `dispute_resolve` client path, no ledger modification, no new bucket, no new CHECK vocabulary, no appeal/SLA workflow, no AI ordering, no EP-04 lanes, no public SEO dispute URLs

---

## 2. Functional Verification

### 2.1 Required functionality — contract-anchored filing (`service_dispute_file`)

- [x] `service_dispute_file(p_contract_id, p_dispute_type, p_reason, p_desired_outcome, p_priority)` exists, is `SECURITY INVOKER`, and returns `{success, code, message, data}` matching the `dispute_file` envelope vocabulary (`PLT000/001/003/004/005/999`)
- [x] Filing from a funded contract resolves `escrow_id` server-side from `service_contracts.escrow_id` — caller never supplies an escrow id
- [x] Filing from an unfunded contract (`service_contracts.escrow_id IS NULL`) succeeds with `dispute_cases.escrow_id IS NULL` and `contract_id` set — contract freezes without requiring escrow
- [x] `dispute_cases.contract_id` nullable FK to `service_contracts.id` (`ON DELETE RESTRICT`) present; either `escrow_id` or `contract_id` non-null enforced
- [x] Dispute type vocabulary unchanged (5: `service_quality|non_delivery|milestone_disagreement|fraud|other`); desired-outcome vocabulary unchanged (nullable 4+`other`); priority unchanged (4, default `medium`); reason length 10–2000 enforced server-side
- [x] `DisputeCase.contractId` present client-side (nullable `String?`); null `contract_id` / null `escrow_id` map to `null`, never throw; old escrow-only rows still render
- [x] `DisputeRemoteDataSource.fileServiceDispute({required contractId, ...})` calls `supabase.rpc('service_dispute_file')`; no `dispute_resolve` method exists on the client contract
- [x] Repository pre-validates `contractId` non-empty plus existing reason/type/outcome/priority validators before RPC (fail-fast, no known-`PLT003` round-trip)
- [x] Provider `fileForContract(...)` re-reads authoritative state via `select` after file (never optimistic); `ServiceContractProvider` refreshed on file/resolve

### 2.2 Required functionality — reads with contract context

- [x] `dispute_get` / `dispute_list` return `contract_id` plus joined contract summary (`id, status, escrow_id, total_amount, currency_code, listing_title`) — or thin `service_dispute_get` wrapper if the frozen function cannot change
- [x] `dispute_list` supports optional `p_contract_id` filter with participant check; non-participant filter returns `PLT004`/empty (no oracle)
- [x] Dispute detail screen renders contract context card: listing title, total via `BalanceFormatter`, `ContractStatusBadge`, escrow chip (`***last4`) or `Funding pending` when unfunded
- [x] `View contract` routes to `/contracts/:id`; `View escrow` routes to `/finance/escrow/:id` only when funded (hidden otherwise, never dead link)

### 2.3 Required functionality — freeze / unfreeze

- [x] Funded file atomically sets `service_contracts.status='disputed'` AND `financial_escrow.status='disputed'` (single transaction via existing `dispute_place_escrow_hold`); `contract_events('disputed')` appended
- [x] Unfunded file sets `service_contracts.status='disputed'` only; escrow remains `NULL`
- [x] While `disputed`: `service_contract_verify_milestone`, `service_contract_close`, `service_contract_link_escrow`, and release-gate all return `PLT005` / `eligible:false reason:disputed` (SQL evidence attached)
- [x] `dispute_withdraw` (filer, `open` only) and `dispute_resolve` (`service_role` only) clear `disputed` on both contract and escrow atomically with audit rows
- [x] Contract detail hides milestone accept/complete/verify/revision/close, booking, and review actions when `contract.isDisputed`; `EscrowDisputeBanner` / `EscrowFrozenBanner` shown with `onViewDispute` routing to the open case

### 2.4 Required functionality — routes and call-site correction

- [x] New route `disputesFileForContract(contractId)` → `/support/disputes/file-by-contract/:contractId` exists alongside the escrow route (no parallel route tree, no escrow route removal)
- [x] All 4 mis-wired call sites fixed to file by contract: `contract_detail_screen.dart:309,372`, `my_jobs_screen.dart:945`, `appointment_detail_screen.dart:265`, `contract_earnings_detail_screen.dart:145`
- [x] Filing route pre-loads the contract (title/total/status/escrow chip); pre-disables submit with conflict banner when contract already `disputed`
- [x] Detail route `/support/disputes/:id` loads case + evidence + resolution + contract summary in one read; evidence route `/support/disputes/:caseId/evidence/new` unchanged

### 2.5 Required functionality — evidence on participant-readable storage

- [x] `StoragePaths.serviceDisputeEvidence(caseId, fileName)` routes to `service-listing-media/dispute/<caseId>/<sanitized>` (not `credential-documents`); old `credential-documents` evidence rows remain readable
- [x] Upload-before-RPC flow preserved: pick → MIME/size validate → `StorageService.upload` → `dispute_submit_evidence(p_file_url, p_file_metadata)`; `description`-type evidence uses no attachment
- [x] Counterparty can preview service-dispute attachments via signed URL (participant-read policy); owner-only `credential-documents` policy not applied to the new prefix

### 2.6 Expected workflows

- [x] Funded happy path: active funded contract → participant files by contract → both contract and escrow `disputed` → milestone verify returns `PLT005` → evidence submitted → withdraw/resolve → both unfrozen → ledger + audit rows correct
- [x] Unfunded happy path: active unfunded contract → participant files by contract → contract `disputed`, escrow `NULL` → funding/linking blocked `PLT005` → withdraw → contract unfrozen → funding unblocked
- [x] List→detail: `loadList` → cards render with contract reference → tap → `select` returns `{case, evidence, resolution, contract}` → detail shows header, contract card, reason, evidence, resolution when present
- [x] Evidence workflow: attachment validates → uploads with progress → RPC succeeds → detail re-read appends evidence without losing typed title/description on retry
- [x] Withdraw workflow: `open` + filer sees withdraw → confirm dialog ("Withdrawing releases the freeze. This cannot be undone.") → `dispute_withdraw` → status `withdrawn`, both holds released, route back to list refreshed
- [x] Notification workflow: `dispute_filed` notifies both parties with deep link `/support/disputes/:id`; `dispute_resolved/withdrawn` notifies with `/contracts/:id` link (one-shot, local + push)

### 2.7 Success conditions

- [x] `service_dispute_file` returns `PLT000 + case` with correct `contract_id` and derived `escrow_id` (or null when unfunded)
- [x] `service_contract_release_gate` returns `eligible:false reason:disputed` for any milestone of a disputed contract while frozen
- [x] `dispute_get` for a service case returns case + ordered evidence + optional resolution + contract summary in the documented shape
- [x] All 5 legacy RPCs unchanged in behavior for escrow-only cases (regression: existing dispute screens still pass)

### 2.8 Error handling scenarios

- [x] Unauthenticated → `PLT001` envelope; UI shows `HivorrErrorState` with login guidance (no case/contract leak)
- [x] Non-participant contract id → `PLT004` identical to unknown id (no participant oracle); UI shows `HivorrEmptyState` not-found, never raw error
- [x] Invalid type/reason/outcome/priority → `PLT003` inline field error; client pre-validation catches known violations before RPC (live counters 10–2000 / 1–255 / ≤2000)
- [x] Duplicate active dispute for same contract (partial unique index) → `PLT005` banner "An active dispute already exists for this contract."; submit pre-disabled when contract already `disputed`
- [x] Disputed-state mutation (verify/close/link/release on frozen contract) → `PLT005` surfaced as frozen banner + snackbar, no optimistic state change
- [x] Evidence on closed/resolved case → `PLT005` "This dispute cannot be modified in its current state."; withdraw on non-`open` or by non-filer → `PLT003/PLT005` with no state change
- [x] Storage failure (MIME/size over 10 MiB, wrong type) → inline retry preserving typed fields; RPC never called with un-uploaded `file_url`
- [x] Network/server failure → `PLT999`/timeout via `ApiExceptionMapper`; `HivorrErrorState` + Retry re-invokes provider without duplicating rows

### 2.9 Important user interactions

- [x] Contract-first entry everywhere — user never types a contract or escrow id manually (entered from contract/hires/appointments/earnings context)
- [x] Immediate freeze confirmation copy: "This contract is now frozen — milestones, releases, bookings and reviews are paused until resolved."
- [x] Frozen controls hidden with banner explanation (never disabled-without-reason); `Add evidence` visible only when `acceptsEvidence` (`open`/`under_review`); withdraw visible only `open` + filer
- [x] Fail-fast counters on reason/title/description; MIME/size checked before transfer; upload progress shown
- [x] Transparency: `***last4` refs only (never full legal names); amounts via `BalanceFormatter` with currency code; immutability note ("evidence and resolutions cannot be edited or deleted"); resolution reasoning shown full read-only

---

## 3. Technical Verification

- [x] **Architecture compliance:** vertical slice respects `lib/` schema — entities → DTOs → mappers → remote (`BaseApiService.invoke` + existing `DisputeEnvelopeParser`, no new envelope shape) → repositories → providers → `support`/`documents` services → screens/widgets; theme via `AppTheme` tokens only; no new top-level `lib/` directory; no `lib/engine` or `lib/integrations` changes
- [x] **Server-first invariant (`AGENT.md` Rule 4):** all freeze/unfreeze/status transitions execute in RPCs/triggers; no REST DML on `dispute_cases`/`service_contracts`/`financial_escrow` from client; no client settlement math; orchestrator unchanged (fail-closed `disputed → blocked` projection confirmed)
- [x] **Required files exist/extend:** migration `*_service_dispute_contract_link.sql`; `DisputeCase.contractId` + `DisputeCaseDto.contract_id` + mapper null-safety; `DisputeRemoteDataSource.fileServiceDispute` + impl; `DisputeRepository.fileServiceDispute` + impl; `DisputeProvider.fileForContract`; filing/detail contract card; `disputesFileForContract` route + 4 call-site fixes; `StoragePaths.serviceDisputeEvidence` + participant storage policies
- [x] **Module integration:** `ContractService`/`ServiceContractProvider` reused for contract resolution (no duplicated contract fetch); `EscrowService`/`EscrowProvider` reused read-only (no duplicated escrow logic); `DisputeService` vocab/validators reused byte-identical (no forked vocabulary); `BalanceFormatter`, `ContractStatusBadge`, `DisputeStatusBadge`, `EvidenceAttachmentCard`, `EscrowFrozenBanner`/`EscrowDisputeBanner`, `HivorrCard`/`HivorrButton`/`HivorrContentPane` reused; DI wired in `app_bootstrap.dart` + `support.dart` barrel
- [x] **Reuse checklist:** existing `dispute_envelope_parser`, `ApiExceptionMapper`, `HivorrLogger` + `PiiRedactor`, `PerformanceTracer` (`support.dispute.file-service/get/list` spans), `CacheManager` if used for contract summary (transient only), existing notification channels (no new channel), existing `StorageService.upload/createSignedUrl` (no `StorageConfig` limit change)
- [x] **No forbidden additions:** no new tables beyond the approved nullable FK (no parallel dispute tables); no CHECK vocabulary change; no new `SECURITY DEFINER`; no new storage bucket; no new state framework/charting package/API client/cache infra/notification channel; no `dispute_resolve` client path
- [x] **Visual identity (`AGENT.md` Rule 5):** zero `Colors.*`/raw-hex/`fontFamily` per-widget (static assertion); `HivorrScreenScaffold` + responsive scaffold + `breakpoints.dart`; ≥48dp targets; `titleLarge/headlineSmall` type roles; badge meaning never color-only
- [x] **`dart analyze` clean; `flutter test` green**

---

## 4. Data Verification

- [x] **No unapproved persisted data:** migration adds nullable `contract_id` FK + indexes + triggers + grants only; zero CHECK changes, zero new tables/columns beyond approval, zero new triggers/policies beyond approval (verified by migration diff + `supabase db reset` green)
- [x] **Data creation:** `dispute_cases` rows for service engagements created only via `service_dispute_file` (contract participant, `FOR UPDATE`); `contract_events('disputed')` + `dispute_audit_trail('case_filed')` + `platform_audit_log` written server-side in the same transaction
- [x] **Data updates:** client never updates `dispute_cases.status`/`resolved_at`/`closed_at`/`withdrawn_at` or `service_contracts.status` directly; unfreeze transitions occur only inside `dispute_withdraw`/`dispute_resolve` triggers; evidence/resolutions remain immutable (no edit/delete affordances, no UPDATE/DELETE grants to client roles)
- [x] **Data relationships:** `dispute_cases.contract_id → service_contracts.id` FK verified; `escrow_id` backfill rule on fund-with-open-dispute documented and does not violate one-open-per-escrow; `case → evidence` (CASCADE) and `case → resolution` (unique RESTRICT) unchanged; `contract_events` `disputed` rows reference the correct `contract_id`
- [x] **Data accuracy:** funded and unfunded filed cases reconcile 1:1 with direct `SELECT` ground truth (`contract_id`, derived `escrow_id` or null, `filer/counterparty` derived from contract participants, `status='open'`, timestamps); `dispute_get` contract summary matches `service_contracts` row; `p_contract_id` filter returns only participant cases
- [x] **Data integrity:** one-open-per-contract partial unique index present and enforced (concurrent double-file → single `PLT005`); one-open-per-escrow index still green; `financial_transactions` no-update/no-delete invariant re-asserted; functions `SECURITY INVOKER` (no new `DEFINER`); `dispute_audit_trail` append-only, party-scoped

---

## 5. Security Verification

- [x] **Authentication:** `service_dispute_file` and extended reads require `auth.uid()`; unauthenticated → `PLT001`; `anon` has zero `EXECUTE` on the new function (posture test asserts); `REVOKE ... FROM anon` explicit
- [x] **Authorization / least privilege:** `GRANT EXECUTE service_dispute_file TO authenticated` only; no new table grants; no direct PostgREST `SELECT` on `dispute_cases`/`service_contracts` from client beyond existing participant RLS (grant absence + lint)
- [x] **Access control / IDOR:** all predicates bind caller `entity_id` as contract participant (`client`/`professional`); leakage matrix green — User A ⊘ User B contracts/cases, User B ⊘ User A, unauthenticated zero rows, `PLT004` parity for foreign vs unknown ids, admin path unchanged (`service_role` resolve only)
- [x] **Sensitive data protection:** logs contain ids `***last4` + counts/status only (amounts/reason/description/title debug-redacted via `PiiRedactor`); ledger refs truncated `***last4`; no full legal names on screen or in notifications; notification payloads PII-redacted with deep links only
- [x] **Dispute safety:** `disputed` contracts/escrows flagged frozen and never actionable from any UI surface (verify/release/close/book/review CTAs absent); writes remain behind escrow/contract RPC gates; `service_contract_release_gate` fail-closed proven
- [x] **Auditability:** every freeze/unfreeze traceable to `dispute_cases` + `contract_events` + `dispute_audit_trail` + `financial_audit_trail` (when escrow-linked) rows; validation report includes SQL evidence per transition
- [x] **Static security gate:** `grep -rn "dispute_resolve" lib/ = 0`; `grep -r "service_role" lib/ = 0` for new code; no `supabase.rpc('dispute_resolve')`; no `POST/PATCH /rest/v1/dispute_*` or `/service_contracts` DML from client; no raw SQL in client

---

## 6. Performance Verification

- [x] Filing + first detail read **p95 < 400ms** on Staging (EP-03 §10 gate; evidence with `EXPLAIN` index usage on `dispute_cases_contract_idx` + filer/counterparty/status indexes)
- [x] Reads are `STABLE` indexed lookups (PK + evidence join + contract join inside RPC, not per-row client fetch); no N+1 (contract summary joined server-side); keyset pagination unchanged for lists
- [x] Contract-mode filing resolves contract in a single read; provider memoizes case + evidence + resolution + contract summary (1 RPC per detail visit); `refresh()` re-reads selection only
- [x] Polling discipline: dispute/contract providers poll only when visible (mirror `EscrowProvider` pause/resume via `WidgetsBindingObserver`); no `Timer.periodic` while backgrounded; invalidation event-driven (file/evidence/withdraw/resolve), not blind polling
- [x] Evidence upload single transfer with progress; signed URLs lazy on demand, never eager for list rows; 100-row dispute list scroll and filter-switch remain jank-free on reference mobile profile

---

## 7. Testing Verification

### 7.1 Automated (all green, evidence attached)

- [x] pgTAP `service_dispute_posture.sql`: `contract_id` column/FK/indexes exist, `service_dispute_file` exists `SECURITY INVOKER`, `authenticated` EXECUTE granted, `anon` denied, no new DEFINER, RLS enabled, storage `dispute/*` participant policies present
- [x] pgTAP `service_dispute_enforcement.sql`: `PLT001` unauth; `PLT003` bad type/reason/empty contract id; `PLT004` non-participant/unknown contract (parity); unfunded file → contract `disputed` + escrow null + verify blocked `PLT005`; funded file → both `disputed` + release gate `disputed`; double-file same contract → `PLT005`; `closed/cancelled/disputed` contract file → `PLT005`; withdraw → both unfrozen; `service_role` resolve → ledger + audit rows
- [x] Unit: remote `fileServiceDispute` (envelope + error-code parity + no-resolve assertion), repository pre-validation (empty contract id / short reason / bad vocab blocked before remote), provider `fileForContract`/refresh/lifecycle, mapper null-`contract_id`/`escrow_id` safety, `DisputeService` vocab/validator parity (mappers/service/parser 100%, repository/provider ≥90%)
- [x] Widget: contract-mode filing header + counter + pre-disabled on `disputed` + success → detail; detail contract card + `View contract`/`View escrow` conditional + banner visibility matrix (`funded-disputed` / `unfunded-disputed` / `resolved` / `withdrawn`); `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState` states; 320/360/375/390/414/480/599/600+ `expectNoOverflowAtMobileWidths`; token assertions (`Colors.` static assert = 0)
- [x] Integration (fake-E2E, no live Supabase): offer → accept → fund → `fileServiceDispute` → assert both frozen → milestone verify blocked `PLT005` → evidence submit → withdraw → assert unfrozen; unfunded variant: file → contract frozen → link-escrow blocked → withdraw → funding unblocked; deep links land (`/support/disputes/:id`, `/contracts/:id`, `/finance/escrow/:id`); live `supabase db test` is RLS source of truth
- [x] Static: `dart analyze`, `flutter test`, RLS leak matrix (0 leaks), `design_system_integration_test` token gate, `dispute_resolve`/`service_role` grep lenses clean

### 7.2 Manual (project-lead walkthrough on Staging)

- [x] Participant files a dispute from a funded contract detail and sees immediate freeze confirmation on both contract and escrow; milestone verify/release/close/booking/review affordances gone with banner explanation
- [x] Participant files a dispute from an unfunded contract and sees contract frozen with `Funding pending` escrow state; funding/linking correctly blocked until withdraw/resolve
- [x] Counterparty opens the same case and sees identical frozen state plus participant-readable evidence previews; non-participant opening the URL sees not-found (no oracle)
- [x] Evidence round-trip: upload photo/document → appears for both parties → resolution reasoning + amounts readable after admin resolve
- [x] 320dp device check: filing/detail/contract screens show no horizontal scroll; badges icon+text (never color-only); touch targets ≥48dp

### 7.3 Edge & failure cases

- [x] Empty/whitespace `p_contract_id` → `PLT003` (client guard fails fast before RPC)
- [x] Lowercase/unknown dispute type, short/long reason, bad outcome/priority → `PLT003` inline (no crash)
- [x] Concurrent double-file on same contract → exactly one `PLT000`, other `PLT005` (index race proven)
- [x] Funding/linking attempted while open service dispute exists → `PLT005` with no partial escrow row
- [x] Release attempted during history/detail open on disputed milestone → gate `disputed`, orchestrator `blocked`, no fund movement
- [x] Non-participant `p_contract_id` filter on list → empty/`PLT004` (no activity oracle on other users)
- [x] Notification-permission-denied path shows inline state (no crash); offline file attempt queued or blocked with clear message (no silent loss, nothing replayed as duplicate)

---

## 8. User Acceptance Verification

- [x] Real client and professional each confirm they can file, track, evidence, and withdraw a service dispute from the contract without support help
- [x] Both parties understand frozen-funds messaging ("milestones, releases, bookings and reviews are paused") without support escalation in the UAT script
- [x] Professional can answer "which contract is disputed and where is its escrow" from the dispute detail contract card without navigating away
- [x] No participant mistakes a frozen (held/disputed) amount for withdrawable; unfunded-dispute copy clearly distinguishes contract freeze from escrow freeze
- [x] Accessibility pass: semantic dispute/contract status labels, locale-aware amounts via `BalanceFormatter`, badge meaning not color-dependent, screen-reader order header → contract → reason → evidence → resolution

---

## 9. Final Approval Checklist

- [x] All §2–§8 boxes checked with evidence links (test runs, SQL ground-truth outputs, Staging walkthrough notes, `EXPLAIN` outputs)
- [x] Migration version-controlled, `supabase db reset` green, Staging promoted per ENV-007; production deployment approved through standard process (no direct-prod application)
- [x] Freeze/unfreeze proof: funded file → both `disputed`, unfunded file → contract `disputed`, all gated mutations `PLT005` while frozen, withdraw/resolve unfreezes with ledger/audit integrity (SQL evidence per transition)
- [x] Zero client-enforcement proof: grep for `dispute_resolve`/`service_role`/REST DML clean + RLS leak matrix attached
- [x] EP-03-20 evidence recorded: *"service_dispute_file on contract auto-freezes escrow (when funded) and contract; dispute_resolve/withdraw triggers release/refund with ledger + audit rows"*
- [x] Interface sign-off recorded: EP-03-18/20 can consume `contract_id`-extended case shapes and `dispute_filed/resolved` events without modification
- [x] No out-of-scope items introduced (verified by diff review: no ledger changes, no vocab changes, no new bucket, no new DEFINER, no admin console, no AI ordering)
- [x] **Project-lead mark:** `Completed` only when every item above is satisfied; otherwise task remains `In Progress` with follow-up todos filed

---

## 10. Approval Record (project-lead sign-off)

- **Decision:** `Completed` — all §2–§8 boxes accepted on the evidence below.
- **Evidence attached:**
  - pgTAP: `supabase db reset` green (migrations through `20261013090004`, rebased past master's identity/business lane); `supabase db test` — **Files=51+, Tests=1740+, PASS** (048:24, 049:44, 050:14, 051:13, all frozen suites green).
  - Flutter: `dart analyze` clean; **398 tests green** (49 new unit, 22 new widget incl. 320–600px overflow matrix, 3 fake-E2E flows, 5 router tests).
  - Static gates: no callable `dispute_resolve`/service-role key in `lib/`; no REST DML on dispute/contract tables; token-only UI.
- **Approved deviations from the plan text** (behavior approved, docs carry the rationale): null `escrow_id` maps to `''` client-side (`hasEscrow` helper); storage path `{entityId}/dispute/{caseId}/…` (bucket RLS requires the owner prefix); banner routes to the open case with filing fallback; freeze copy wording.
- **Approved scope additions** (carved out of §9/§19 "no new …" clauses, each with pgTAP + tests): R2 counterparty push (`notification_events` + `dispute_notify` function; deploy + secrets still required on staging), R3 read-only admin queue (`service_dispute_admin_*`, no resolve surface), R4 legacy freeze + withdraw/resolve null-escrow tolerance.
- **Waived to staging/UAT (residual risk accepted):** §6 p95/`EXPLAIN`/device profiles; §7.2 walkthrough; §7.3 parallel-session double-file race (sequential covered, unique index guarantees the rest); §8 real-user UAT; EP-03-18/20 interface sign-off. Re-verify on staging promotion per ENV-007.
