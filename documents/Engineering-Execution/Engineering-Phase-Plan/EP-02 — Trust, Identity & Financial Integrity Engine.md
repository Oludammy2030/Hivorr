# EP-02 — Trust, Identity & Financial Integrity Engine
## Engineering Phase Plan

**Planning basis:** `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` (approved 4 Nov 2026, §6.5), `documents/Context/AGENTS.md`, `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`, `VISUAL-IDENTITY.md`, `Business-Development-Roadmap.md`, and the approved Control Portal workstream plan.

> **Phase status verdict: `Not started`.** EP-02 cannot become `Ready`. EP-01 is still `In build`, not exited: its own evidence pack records `C4` and `C12` unmet, `C16`/`C17` open, a stale staging API (`F-49`) and an undeployed slice bundle (`F-50`). The EES §3.4 one-phase-in-build rule therefore blocks EP-02. In addition, four EP-02 entry conditions remain open: the funds-custody register correction (`ARCHITECTURE.md` §16.4 #2), VFD’s written licence-scope confirmation, the KYC tier ladder (#6), and the verification vendor (#15).
>
> **Repository observation.** The repository already contains CP P0/P1 governance work — admin authorisation, cases, evidence, approvals, staff, partners and an `admin.verification` queue — built ahead of EP-02’s entry gate. Those are reusable foundations and cross-phase `CP` artefacts. They are **not** EP-02 evidence, and this plan neither ratifies nor replans them.

---

## 1. Phase definition

| Field | Detail |
| --- | --- |
| **Phase ID** | EP-02 |
| **Phase name** | Trust, Identity & Financial Integrity Engine |
| **Roadmap phase served** | Phase 0 → Phase 1 |
| **Phase priority** | Critical — blocks every marketplace phase |
| **Phase status** | `Not started` — entry gate not met |
| **Entry gate** | EP-01 G5 signed; funds-custody register updated to record BD-D01 partner-held custody; VFD written licence-scope confirmation obtained per BD-D11 conditions; KYC tier ladder decided (`ARCHITECTURE.md` §16.4 #6); verification vendor decided (#15); reviewer capacity / second reviewer recorded. |
| **Exit gate** | A test account registers, submits evidence for each of the six lanes, is reviewed in `control.`, and reaches `APPROVED` or `REJECTED` with an audit trail. The ledger balances under property-based invariant tests. A sandbox deposit is matched by payer name and posted; a mismatched payer is rejected. A payout to an unbound or unverified account is refused by the service layer and by RLS independently. The VFD adapter passes sandbox certification. |
| **Closure authority** | Founder, on the architect’s recommendation, through G5. |
| **Duration** | Not estimated. A phase is a gate, not a date (ED-01). |
| **Production release** | Out of scope. EP-02 exits on staging; G4 is a later decision. |

---

## 2. Phase objective and business capability

### 2.1 Phase objective

Build the verification, KYC, taxonomy, ledger and payout infrastructure that makes a stranger-to-stranger transaction safe **before any marketplace flow exists**. The phase delivers six independent verification lanes, immutable verification decisions, a private evidence store, a control review capability with dual control, two admin-configurable taxonomies, a provider-agnostic append-only double-entry ledger, bound payout accounts, the VFD adapter behind a provider port, payer-name-matched deposits, and evidence-producing reconciliation.

### 2.2 Business capability being enabled

EP-02 is the capability bridge between foundation and first transaction:

- **Roadmap Phase 0 exit** — reviewer capacity able to process the target supply volume, and a settled funds structure in which Hivorr never takes possession of customer money.
- **Roadmap Phase 1 entry** — verification operations can approve or reject real people, trades, sellers, logistics providers and businesses before money moves.
- **Trust proposition** — a participant’s eligibility is a server-computed, review-backed fact, not a self-declaration.
- **Financial integrity** — obligations are recorded in a ledger that reconciles to the licensed provider; money can only be paid out to a bound, verified destination.
- **Operational governance** — verification overrides and manual financial actions are scoped, dual-controlled and audited.
- **Platform configurability** — professions and product categories are administered as data, not code.

The phase does **not** enable any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction. It makes those transactions safe to build later.

---

## 3. Engineering objectives

1. **Six lanes, six state machines.** Identity, KYC, trade, seller, logistics and business verification are independent rows with independent states and decisions. They never collapse into one account status.
2. **One active submission per lane.** Concurrency is rejected by constraint, not by hope.
3. **Decisions are immutable evidence.** Every approval or rejection records actor, timestamp, evidence reference, reason and lane; no update or delete path exists.
4. **Evidence is private by construction.** Documents live in private object storage; the database holds references only; every read is signed, short-lived and audited.
5. **KYC gates money, never access.** `tier_0` performs no financial writes; `tier_1+` is subject to configured limits; dashboards remain open.
6. **One ledger, no balances.** Double-entry, append-only, currency-dimensioned; displayed balances are derived views.
7. **Provider-agnostic by boundary.** VFD is the launch adapter, not the domain. A second provider is a new adapter plus a provider-reference column.
8. **Payouts only to proven destinations.** Bound, verified, name-matched accounts; enforced in the service layer and independently by RLS.
9. **Deposits match the payer.** `Payer Name == Entity Profile Name` is enforced server-side with an explicit manual-review path, never fuzzy auto-approval.
10. **Reconciliation is an output, not an intention.** Every run records period, provider totals, ledger totals, differences and owners.
11. **Taxonomy is data.** Profession and product classifications are admin-configurable, versioned and audited; adding a vertical does not require a deploy.
12. **Control is a separate authority.** Admin scopes are orthogonal to activities; high-risk actions require dual control and no self-approval.
13. **Every verification and financial mutation writes audit.** The audit record and the effect commit or roll back together.
14. **The visual identity survives.** Verification and wallet surfaces are extracted without visual change and protected by regression tests.
15. **Evidence rule.** No roadmap item moves above `Not started` without a linked artefact.

---

## 4. Technical goals

| ID | Technical goal | Measure |
| --- | --- | --- |
| **TG-01** | Lane independence | Table-driven tests prove approving or rejecting lane X changes no other lane’s state. |
| **TG-02** | Single active submission | A partial unique index rejects a second active submission per lane per account; concurrency test passes. |
| **TG-03** | Immutable decisions | No update/delete grant or path exists for decision records; correction is a new decision. |
| **TG-04** | Evidence privacy | Unsigned access fails; signed URLs are short-lived and object-scoped; every read emits an audit record; unscanned files are unusable. |
| **TG-05** | KYC gating | `tier_0` is denied every financial write; `tier_1` is allowed only within configured limits; unset limits deny. |
| **TG-06** | Ledger balance | Every journal entry balances to zero per currency under property-based tests, including reversal and rounding cases. |
| **TG-07** | Append-only ledger | No update/delete path for journal entries or postings; correction is a reversing entry. |
| **TG-08** | Idempotency | Replaying the same provider event or client key moves value once; the test proves the second application is a no-op. |
| **TG-09** | Provider agnosticism | Domain and ledger compile and test without VFD imports; adapter contract tests run against a fake provider. |
| **TG-10** | Payer match | Normalised exact match posts; mismatch is rejected and queued for review; no fuzzy auto-approval exists. |
| **TG-11** | Payout destination | Service layer and RLS independently refuse an unbound, unverified or name-mismatched payout account. |
| **TG-12** | Reconciliation | A scheduled run produces a report with provider totals, ledger totals, differences and named owners. |
| **TG-13** | Control authority | Verification override and manual financial adjustment require a second approver; self-approval is impossible. |
| **TG-14** | Taxonomy configurability | A new profession or product node is added by admin action with version, effective date and audit; no deploy. |
| **TG-15** | Audit completeness | Every action on the EP-02 audit list produces an event in the same transaction as its effect. |
| **TG-16** | RLS fails closed | Every EP-02 table has `FORCE ROW LEVEL SECURITY`, one policy per operation, and an allow **and** deny test. |
| **TG-17** | Visual fidelity | Verification and wallet screens are pixel-identical to the prototype at 375 / 768 / 1280. |
| **TG-18** | No marketplace leakage | Route manifest, import boundaries and tests prove EP-02 added no transaction flow. |
| **TG-19** | Staging proof | The exit-gate E2E runs against the deployed staging digest, not a local build. |
| **TG-20** | VFD certification | A sandbox certification record exists for the exact adapter commit and credential set. |

---

## 5. Scope guard

### 5.1 In scope

- **Profiles & Verification (`profile`)** — six verification lanes, lane state machines, submissions, evidence references, KYC tier state, decision records, freeze and resubmission rules.
- **Evidence** — private R2 bucket, pre-signed upload, type/size validation, asynchronous scanning, signed read, access audit, immutability and retention hold.
- **Control review** — integration with the existing `control.` case/evidence/approval spine; verification queue; decision effects; overrides; dual control; scoped admin enforcement.
- **Taxonomy (`platform`)** — Profession registry (Industry → Profession) and Product registry (vertical → category → subcategory → product type → attributes), admin-configurable, versioned, audited.
- **Finance (`finance`)** — double-entry append-only ledger; ledger accounts; journal entries; postings; currency dimension; escrow accounts; payout accounts; limits; reconciliation; dispute record; financial audit.
- **Provider integration (`integrations/vfd`)** — `PaymentProvider` port, VFD authentication, collection accounts, inward credits, payouts, status queries, webhook intake and sandbox certification.
- **Deposits and payouts** — payer-name match, deposit posting, payout eligibility, payout execution, reconciliation.
- **Frontend** — verification centre, wallet and payout-account surfaces, financial-action dialogs and deny states, visual regression.
- **Staging and evidence** — E2E, invariant report, certification record, reconciliation report, phase review and G5 record.

### 5.2 Out of scope — EP-02 must not build these

- Any marketplace transaction: Buy, Hire, Errand, Sell, Offer services, Logistics, dispatch, orders, jobs, engagements, milestones or carts.
- Escrow **release timing**, dispute **outcomes**, refund policy or cancellation policy. BD-D03 remains open; the state machine ships only with transitions the decision defines.
- Fee computation, take-rate application, commission calculation or promoted placement. BD-D02 rates are open.
- Multi-currency conversion or FX. The ledger carries a currency dimension; only the approved launch currency is enabled.
- Lending, credit, crypto or digital assets.
- A second payment provider. VFD is the launch adapter.
- A full wallet transaction history generated by marketplace activity — none exists yet.
- Production deployment or G4.
- Rebuilding the Control Portal case spine, evidence service, approval engine or role catalogue. Those are `CP` packages and are consumed as dependencies.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.

### 5.3 Scope interpretations to confirm at G0

Recorded rather than resolved silently:

1. **Taxonomy depth.** The approved phase scope names the five-level product model, while `VISION.md` §10 Q10 still records “two levels at launch, or full five-level model” as open. EP-02-001 must record which governs. The registry is built to support the configured depth; **no marketplace binding or production reference data is seeded** in EP-02.
2. **“Six verification lanes.”** The matrix names Identity, KYC tier, Trade, Seller, Logistics and Business. KYC is a review lane **and** an account-level tier; it is not an activity lane. EP-02 must model both without collapsing them.
3. **Payer name.** `AGENTS.md` Rule 3 says `Payer Name == Entity Profile Name`. The matrix separates legal name from public display name. Recommended reading for G0 confirmation: match against the **verified legal name**, normalised for case/whitespace/order, exact match only; mismatch goes to review, never auto-approval.
4. **Control portal reuse.** The `control.` review queue is delivered through CP-016/017/019/020. EP-02 owns the lane submission, decision effect and immutable record; it does not duplicate the case or approval UI.
5. **Escrow policy.** EP-02 builds the escrow account and state model but **disables release and refund transitions** until BD-D03 is decided. A disabled transition is explicit, not a default.
6. **Limits.** KYC tier limits are configuration with effective dates. No numeric threshold is invented. Missing configuration denies.

---

## 6. Required systems, modules and components

### 6.1 Systems

| System | Responsibility in EP-02 |
| --- | --- |
| **API** | Verification, KYC, taxonomy, wallet, payout-account, deposit and payout endpoints; capability enforcement inside transactions; OpenAPI contract. |
| **Worker** | Evidence scanning, webhook processing, outbox consumers, reconciliation job, retry and dead-letter. |
| **PostgreSQL** | `profile`, `finance`, `platform` and `admin` read-model tables; RLS; grants; migrations. |
| **Private object storage (R2)** | `private-documents` bucket for identity, KYC, trade, seller, logistics and business evidence. |
| **VFD / PSL BaaS** | Sandbox collection accounts, inward credits, transfers/payouts, status queries, bank/account enquiry and certification. |
| **`control.`** | Verification queue, case workspace, evidence viewer, approvals, configuration and audit access. |
| **`web`** | Verification centre, wallet and payout-account surfaces. |
| **Secret store** | VFD credentials, storage keys and signing secrets per environment. |
| **Observability** | Correlation IDs, redaction, queue health, reconciliation alerts, provider error metrics. |
| **CI** | Typecheck, lint, tests, contract diff, migration lint, RLS tests, secret/dependency scanning, visual regression. |

### 6.2 Modules and disposition

| # | Module | Schema | EP-02 disposition |
| --- | --- | --- | --- |
| 1 | Identity & Authentication | `identity` | **Consumed.** Sessions, grants, audience and capability context already exist. EP-02 reads grant and tier inputs; it does not rebuild auth. |
| 2 | Profiles & Verification | `profile` | **Implemented.** Lane registry, submissions, evidence references, state machines, KYC tiers, decisions and freeze rules. |
| 7 | Wallet & Financial Operations | `finance` | **Implemented.** Ledger, escrow accounts, payout accounts, limits, disputes, reconciliation and provider references. |
| 9 | Administration & Governance | `admin` | **Extended through CP.** Review queue, case link, evidence access, approvals and read models. EP-02 integrates; CP owns the surfaces. |
| 10 | Shared Platform Services | `platform` | **Extended.** Taxonomy registry, reference numbers, idempotency, audit and outbox. |
| — | Provider integration | `integrations/vfd` | **Implemented.** VFD adapter behind the `PaymentProvider` port. |
| — | Frontend | `web`, `control` | **Implemented.** Verification and wallet surfaces in `web`; taxonomy and review surfaces in `control` through the CP shell. |

### 6.3 Key components

- Verification lane registry and transition tables.
- Submission/evidence service with signed upload and read.
- KYC tier resolver and financial-limit resolver.
- Control review integration service and decision recorder.
- Dual-control request types for verification override and manual financial adjustment.
- Taxonomy node/attribute registry with versioning.
- Ledger posting engine, account resolver and derived-balance views.
- Escrow account and state model.
- Idempotency and provider-reference service.
- Payout-account binding and bank-account verification port.
- Payer-name normaliser and match service.
- Payment provider port, VFD adapter, webhook intake, status verifier.
- Reconciliation job and exception read model.
- Audit emitters for every verification and financial mutation.
- Verification centre and wallet UI components.

### 6.4 Test stack

Vitest unit and property-based tests; Testcontainers PostgreSQL for migration, RLS and ledger integration; contract tests for OpenAPI and the provider port; Playwright E2E and visual regression; seeded failing fixtures for every blocking gate.

---

## 7. Recommended engineering development order

No dates. Order is by dependency and by what produces evidence earliest.

| Stage | Work | Why this order |
| --- | --- | --- |
| **A — Entry and contracts** | EP-02-001 → 002 | Nothing starts until EP-01 is exited and every entry decision is recorded. Shared contracts prevent divergent vocabulary. |
| **B — Verification and KYC** | 010 → 011 → 012 → 013 → 014 → 015 → 016 | Schema, state machines, evidence, API and tier inputs must exist before review can decide anything. |
| **C — Taxonomy** | 020 → 021 → 022 | The registry is independent of money and can run in parallel with Stage B once contracts exist. |
| **D — Ledger foundation** | 030 → 031 → 032 → 033 → 034 → 035 → 036 | Ledger correctness must be proven on an empty system before provider money touches it. |
| **E — Provider adapter** | 040 → 041 → 042 → 043 → 044 → 045 | The port comes first; VFD implements it; webhooks and certification follow. |
| **F — Deposits, payouts and reconciliation** | 050 → 051 → 052 → 053 → 054 → 055 → 056 | These consume both the ledger and the adapter; each step produces an invariant or control. |
| **G — Frontend** | 060 → 061 → 062 → 063 | UI waits for real contracts and denial semantics; visual work is last to avoid churn. |
| **H — Exit evidence** | 070 → 071 → 072 → 073 | Evidence is produced by a running system, not assembled from intentions. |

### 7.1 Parallelism rules

- Stage B and Stage C may run in parallel after EP-02-002.
- Within Stage D, ledger schema (030) blocks everything; posting engine (031), wallet views (032), escrow (033), idempotency (034), limits (035) and disputes (036) may overlap only where they do not change the same contract.
- Stage E starts after the ledger posting contract (031/034) is stable. VFD authentication and the provider port can overlap.
- Stage F deposit work (050–051) and payout work (052–053) may overlap after the adapter is certified in sandbox; reconciliation (054) waits for both.
- Frontend extraction may begin once the API contract is generated, but no screen is accepted before its deny states exist.
- Exactly one phase may be `In build`; EP-02 does not run alongside EP-01 or EP-03.

### 7.2 Critical path

`001 → 002 → 010 → 011 → 012 → 013 → 014 → 015 → 030 → 031 → 034 → 040 → 041 → 042 → 050 → 051 → 052 → 053 → 054 → 070 → 071 → 072 → 073`

Taxonomy (`020–022`), escrow (`033`), limits (`035`), disputes (`036`), override (`016`) and frontend (`060–063`) run off the critical path but are on the phase-exit path.

---

## 8. Dependencies

### 8.1 Internal dependencies

| Dependency | Effect |
| --- | --- |
| **EP-01 G5** | Hard blocker. EP-01 must exit with `C4` and `C12` met and the stale staging artefact resolved. |
| **EP-01 identity, capability engine and audit** | EP-02 consumes sessions, grants, capability computation and append-only audit; it does not rebuild them. |
| **EP-01 RLS pattern, roles and transaction foundation** | Every new table follows the same policy and grant pattern. |
| **EP-01 worker, queue and outbox** | Scanning, webhook processing and reconciliation use the existing worker seam. |
| **CP-002 / CP-003 / CP-005 / CP-006 / CP-012** | Admin authorisation, capability context, audit contract, admin schema and role administration. |
| **CP-016 / CP-017 / CP-019 / CP-020** | Case spine, evidence, verification review and approvals. |
| **CP-022** | Configuration versioning and approval for taxonomy and limits. |
| **Design system and visual baseline** | Verification and wallet screens consume approved tokens and primitives. |
| **Second reviewer** | Verification and financial changes are `[REVIEW]`/`[FOUNDER]` and require a reviewer who did not author them. |

### 8.2 External dependencies

| Dependency | Needed by | Status |
| --- | --- | --- |
| VFD / PSL sandbox credentials and onboarding | Adapter, certification | Required; not recorded as available |
| VFD written licence-scope confirmation | Entry gate | **Open** — BD-D11 conditions 1–6 |
| KYC tier ladder and limits | Tier configuration | **Decided 2026-11-26** — ladder settled; naira caps provisional pending counsel — `ARCHITECTURE.md` §16.4 #6 |
| Verification vendor | Identity/KYC lane | **Open** — #15 |
| NIBSS / bank-account name enquiry through VFD | Payout-account binding | Depends on VFD product scope |
| Cloudflare R2 private bucket | Evidence | Decided; provisioning required |
| Counsel on custody, KYC/AML applicability and retention | Entry gate and data protection | **Open** — R1/R2 items |
| Reviewer capacity / operating SLA | Control review | Phase 0 exit condition |
| VFD settlement SLA and status-query contract | Reconciliation | Vendor documentation incomplete |
| Cloudflare / Fly.io staging | E2E and certification | Existing EP-01 topology |

### 8.3 Open decisions that block or shape EP-02

| Decision | Register | Effect |
| --- | --- | --- |
| Funds custody — register must record BD-D01 partner-held | `ARCHITECTURE.md` §16.4 #2 | Entry gate |
| KYC tier ladder and limits | #6 — decided 2026-11-26; naira caps provisional | Tier configuration and financial gating |
| Verification vendor | #15 | Identity lane implementation |
| Escrow timing and dispute rules (BD-D03) | Roadmap §21 | Release/refund transitions only |
| Fee model numbers (BD-D02) | Roadmap §21 | Out of scope; no fee computation |
| Currency model (BD-D07) | #8 | Ledger dimension only; no conversion |
| Taxonomy depth | `VISION.md` §10 Q10 | Registry depth and seed data |
| Payer-name matching policy | AGENTS Rule 3 + matrix §7.5 | Deposit match rule |
| VFD webhook authentication gap | Standards API-24 | Compensating controls and recorded deviation |
| Retention periods | #7 | No purge; retain-and-hold |
| KYC/AML applicability | Standards §16 #25 | No reporting path on assumption |

---

## 9. Risks, assumptions and engineering considerations

### 9.1 Risks

| # | Risk | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| R1 | **EP-01 is not closed.** `C4`/`C12` unmet, staging stale, G5 unsigned. | EP-02 cannot start; any work would be unverifiable. | Do not open EP-02. Close EP-01 and link its evidence in EP-02-001. | Founder / architect |
| R2 | **Four entry decisions remain open.** | Verification, tiering and custody work would be built on assumptions. | EP-02-001 records each decision; dependent packages stay `Not started`. | Founder |
| R3 | **VFD licence scope is unconfirmed.** | Escrow and payout design may exceed what the licensed entity may do. | Obtain written confirmation from VFD MFB, not only PSL. No money moves before it. | Founder / counsel |
| R4 | **VFD webhooks have no documented signature.** | Forgery and replay could corrupt the ledger. | Verify every event against the status API before posting; raw-payload store; dedupe on reference/session ID; IP allowlist; founder-approved deviation. | Architect |
| R5 | **VFD documentation is incomplete.** No OpenAPI, idempotency contract, rate limits, retry schedule or error registry. | Adapter behaviour is guesswork. | Adapter contract tests, conservative retries, status polling, explicit error mapping, vendor clarification list. | Architect |
| R6 | **Payer-name matching is ambiguous.** Display name vs legal name, normalisation and false positives. | Wrong person credited or legitimate deposit rejected. | G0 ruling; match verified legal name; exact normalised match; mismatch to review; no fuzzy auto-approval. | Founder / architect |
| R7 | **KYC evidence is sensitive personal data.** | Breach or unlawful retention. | Private bucket, signed reads, access audit, scanning, retention hold, no purge, classification and impact note. | Architect |
| R8 | **Ledger defects compound.** | Every later phase inherits them. | Property-based invariants, append-only enforcement, reversal-only correction, idempotency tests, second review. | Architect |
| R9 | **Escrow release policy is open.** | An invented default could release funds wrongly. | Build the state model; disable release/refund; require BD-D03 before enabling. | Founder |
| R10 | **Taxonomy scope explodes.** Five levels plus attributes can become an EAV platform. | Phase becomes a catalogue build. | Configured depth, typed attribute definitions, no marketplace binding, no production seed beyond approved structure. | Architect |
| R11 | **Control portal circularity.** CP-019 needs lanes; EP-02 exit needs review. | Phase stalls waiting on itself. | Define the lane/decision contract in 010–015; CP-019 consumes it; E2E proves both. | Architect |
| R12 | **Reviewer capacity and dual control.** | Queue backlog; self-approval pressure. | Record reviewer SLA, enforce maker-checker, no self-approval, escalation path. | Founder |
| R13 | **Payout RLS is weaker than the service layer.** | A second-line defence that does not deny. | Deny test proves RLS refuses unbound/unverified payout independently. | Architect |
| R14 | **Limits are invented or left unset.** | Financial writes either blocked unexpectedly or allowed without authority. | Configuration with effective dates; unset denies; no numeric default in code. | Founder / architect |
| R15 | **Frontend extraction drifts.** | Visual identity fails. | Baseline first; extract on touch; pixel parity at three widths; no new hex or font. | Developer |
| R16 | **Reconciliation has no clean provider source.** | Differences cannot be explained. | Store raw events, query status, record period and owners, treat mismatch as incident. | Architect |
| R17 | **Secrets leak or sandbox credentials reach production.** | Provider compromise. | Per-environment secrets, rotation, no secret in bundle/log, certification uses sandbox only. | Architect |
| R18 | **Phase declared done without certification or evidence.** | Repeats the v1 failure mode. | Evidence index; no status above `Not started` without artefact; G5 is a founder signature. | Founder / architect |

### 9.2 Assumptions

1. EP-01 exits before EP-02 starts, with a protected `main`, green CI and a deployed staging digest.
2. VFD is the launch provider and sandbox access is available before adapter work begins.
3. BD-D01 partner-held custody is confirmed in the architecture register before any ledger code.
4. Hivorr never holds customer money; the ledger records obligations and instructs the licensed provider.
5. The KYC ladder has at least `tier_0` (zero financial limits) and `tier_1` (verified, configured limits); higher tiers are configuration.
6. Verification may be review-queue-only if #15 selects that option; a vendor adapter is a seam, not a prerequisite for manual lanes.
7. NGN is the only enabled currency at launch; the schema carries a currency dimension.
8. The private evidence bucket and the VFD sandbox are isolated from production.
9. Staging uses synthetic identities and evidence only; no real personal data.
10. BD-D03 remains open; EP-02 exit does not require escrow release.
11. Fee computation remains out of scope; no fee posting is required for the exit gate.
12. The CP P0/P1 foundations remain available and are not rolled back during EP-02.
13. A second reviewer is available, or a recorded deviation with compensating controls exists before verification and finance work.
14. No production release occurs in EP-02.

### 9.3 Engineering considerations

- **Default deny.** Every new endpoint, lane, table, bucket and provider event starts closed.
- **Service layer is authoritative.** RLS is a second line; a passing policy does not replace a service check.
- **No client authority.** Lane state, KYC tier and payout eligibility are server-computed; the client only presents them.
- **No shared tables.** `profile`, `finance`, `platform` and `admin` read models do not join across schemas in feature code.
- **Migrations are self-contained.** A verification or finance migration creates columns, keys, constraints, indexes, RLS, policies, grants and comments together.
- **Forward-only and expand/contract.** Rollback is a previous artefact digest; no production down script.
- **Every RLS policy needs a deny test.** Allow-only coverage is untested.
- **Audit is written inside the transaction.** A record written after commit is not evidence.
- **No balance column.** Wallet figures are derived; a screen that shows a balance is not a control.
- **Correction is a reversing entry.** The ledger never updates or deletes a posting.
- **Provider payloads are untrusted.** Validate, store raw, verify against status, then translate.
- **VFD identifiers never enter the domain.** The adapter maps them to Hivorr states and references.
- **Evidence is referenced, not stored in the database.** The database holds metadata and object keys only.
- **Payout bank details are field-level encrypted.** Never projected, logged or returned in full.
- **Limits are data.** No threshold is hard-coded; missing limit denies.
- **Taxonomy is reference data.** It never becomes a generic EAV store for every entity.
- **Control is not an activity.** Admin scope never grants an activity capability.
- **No self-approval.** Maker and checker are distinct actors with distinct audit records.
- **Extraction is not redesign.** Verification and wallet screens are wired or extended only.
- **Evidence is an artefact a third party can inspect.** A status sentence is not evidence.

---

## 10. Roadmap items

Each item is a candidate work package under the EES §8 protocol. Before G0 it must still be elaborated with class, scope-in/out, reuse check, test plan, evidence, audit-readiness impact, rollback and approver. The fields below are planning-level, not a G0 record.

**Reasoning levels:** *Planning* = reasoning needed to define the package at G0. *Coding* = reasoning needed to implement and verify it. Use the higher level when a security, financial or architectural property is involved.

---

### Stage A — Entry and contracts

#### EP-02-001 — Entry gate closure and decision register
- **Objective:** Verify EP-01’s G5 evidence and record every decision EP-02 depends on before any package becomes `Ready`.
- **Engineering purpose:** Satisfies G0, prevents work on an open decision, and establishes the phase’s true starting position.
- **Dependencies:** EP-01 G5; founder for funds custody register, VFD scope, KYC ladder and verification vendor; architect for taxonomy depth, payer-name policy, second reviewer and CP integration.
- **Expected outcome:** A signed entry record linking EP-01 evidence, the four entry decisions, the scope readings in §5.3, and the blocker list. EP-02 becomes `Ready`, or `Blocked` with named owners.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Low

#### EP-02-002 — Shared contracts, capability inputs and error semantics
- **Objective:** Define shared types and schemas for lanes, submission states, KYC tiers, evidence references, ledger operations, payout accounts and provider references; extend the capability context with verification and tier inputs.
- **Engineering purpose:** One vocabulary across API, worker and clients; no hand-duplicated enums and no divergent validation.
- **Dependencies:** EP-02-001; EP-01-003; EP-01-034.
- **Expected outcome:** `@hivorr/shared` exposes lane, tier, ledger and payout contracts; the capability context consumes lane states and tier without trusting the client; allow/deny tests pass for the extended inputs; no marketplace capability is enabled.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

---

### Stage B — Verification and KYC

#### EP-02-010 — Verification schema, lane registry and constraints
- **Objective:** Create `profile` verification tables for lane cases, submissions, evidence references, decisions, KYC tiers and freeze state, with constraints, indexes, RLS and grants.
- **Engineering purpose:** Makes lane independence and one-active-submission structural, not conventional.
- **Dependencies:** EP-02-002; EP-01-021/022/025.
- **Expected outcome:** Six lanes exist as rows; a partial unique index enforces one active submission per lane; decision rows are append-only; every table has `FORCE RLS` and allow/deny tests; `db diff` is clean.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-011 — Lane state machines and submission domain
- **Objective:** Implement the six lane state machines (`NOT_STARTED`, `DRAFT`, `SUBMITTED`, `UNDER_REVIEW`, `APPROVED`, `REJECTED`, `EXPIRED`) and the domain rules for submission, resubmission, freeze and expiry.
- **Engineering purpose:** Keeps verification invariants pure and independent of HTTP, ORM and provider SDKs.
- **Dependencies:** EP-02-010.
- **Expected outcome:** Invalid transitions are rejected in domain and by constraint; approving one lane changes no other; a rejected lane reopens for resubmission; an approved lane is not silently reopened; duplicate active submissions are rejected.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-012 — Evidence storage, scanning and signed access
- **Objective:** Add the private evidence store: pre-signed upload, type/size validation, asynchronous scanning, signed short-lived read, access audit and retention hold.
- **Engineering purpose:** Verification evidence is the highest-sensitivity data in the phase; it must be private by construction and auditable on every read.
- **Dependencies:** EP-02-010; EP-01 object-storage interface; R2 provisioning.
- **Expected outcome:** Unsigned access fails; an unscanned file is unusable; a signed URL is object-scoped and short-lived; every read writes an audit record; oversize and disallowed types are rejected; no public URL exists; no deletion path is built.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-013 — Verification submission and status API
- **Objective:** Expose user-facing endpoints to start a lane, upload evidence, submit, withdraw a draft, resubmit after rejection, and read lane status.
- **Engineering purpose:** Gives the user a resumable verification path without granting any capability before approval.
- **Dependencies:** EP-02-011, EP-02-012; EP-01-011/013.
- **Expected outcome:** Submission creates no capability; identity fields freeze under review; status read returns per-lane state and reason, never another account’s data; OpenAPI contract is generated; rate limits and idempotency apply.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-014 — KYC tier model and financial gating inputs
- **Objective:** Implement account-level KYC tier state and expose it to the capability engine as a financial-gating input, with configuration-driven tiers and limits.
- **Engineering purpose:** Money is gated by tier, not by activity; no numeric ladder is invented in code.
- **Dependencies:** EP-02-010, EP-02-013; entry decision #6.
- **Expected outcome:** `tier_0` denies every financial write; `tier_1+` is allowed only within configured limits; an unset limit denies; tier changes are audited; KYC tier is independent of every activity lane.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-015 — Control review integration and immutable decision record
- **Objective:** Connect lane submissions to the existing `control.` case spine and verification queue, and make approval/rejection atomically update lane state and KYC tier with an immutable decision record.
- **Engineering purpose:** Verification is only real when a second authorised actor decides it and the effect is evidenced.
- **Dependencies:** EP-02-011/012/013/014; CP-016/017/019; `admin.verification` queue.
- **Expected outcome:** Submission creates a typed verification case; the queue reads lane, subject and evidence count; a decision records actor, timestamp, reason, evidence references and prior/next state; no user action or automated job approves; the decision and lane change commit together.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-016 — Verification override and dual control
- **Objective:** Add a verification-override request that requires a second authorised approver, a reason and an immutable audit record.
- **Engineering purpose:** High-risk overrides must never be a single-person action, even for the founder.
- **Dependencies:** EP-02-015; CP-020 approvals; CP-012 role administration.
- **Expected outcome:** Requester and approver are distinct; self-approval is impossible; the override records both actors and timestamps; a rejected override leaves lane state unchanged; the action is audited.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

---

### Stage C — Taxonomy

#### EP-02-020 — Taxonomy registry schema and hierarchy domain
- **Objective:** Create the `platform` taxonomy registry for `profession` and `product` taxonomies, with typed levels, parent-child integrity, attribute definitions and version metadata.
- **Engineering purpose:** Makes profession and product classification data-driven without building a generic EAV platform.
- **Dependencies:** EP-02-002; EP-01-021/022/025; G0 ruling on depth.
- **Expected outcome:** Industry → Profession and vertical → category → subcategory → product type → attributes are representable; cycles and orphan nodes are rejected; attribute definitions are typed; RLS and grants are applied; no marketplace table is created.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-021 — Taxonomy administration API, versioning and control UI
- **Objective:** Provide admin-configurable taxonomy CRUD with version, effective date, approval and audit, plus the `control.` management surface.
- **Engineering purpose:** Taxonomies must change without a deploy and without silent drift.
- **Dependencies:** EP-02-020; CP-022 configuration; CP-012 roles.
- **Expected outcome:** An authorised admin adds or edits a node; the change carries a version, effective date and audit record; approval follows the configuration policy; a new vertical requires no code change; the control screen is permission-aware and responsive.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-02-022 — Taxonomy seed data and read contracts
- **Objective:** Publish read contracts for the two taxonomies and seed only approved structural reference data.
- **Engineering purpose:** Later modules need a stable read interface without inheriting admin write access.
- **Dependencies:** EP-02-020, EP-02-021.
- **Expected outcome:** Read contracts return active nodes for a given taxonomy and level; no production category or profession values are invented; test fixtures cover both taxonomies; no listing or activity binding is built.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage D — Ledger foundation

#### EP-02-030 — Finance schema, ledger accounts and RLS
- **Objective:** Create `finance` tables for ledger accounts, journal entries, postings, provider references, escrow accounts, payout accounts, limits and reconciliation records, with constraints and RLS.
- **Engineering purpose:** The ledger is the source of truth; its schema must make invalid states unrepresentable.
- **Dependencies:** EP-02-002; EP-01-021/022/025.
- **Outcome:** No mutable balance column exists; money is `numeric(20,4)` plus currency; entries and postings are append-only; account kinds match the approved list; every table has RLS and deny tests; field-level encryption is specified for bank details.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-031 — Posting engine, double-entry invariants and property tests
- **Objective:** Implement the pure ledger posting engine that validates an entry, writes balanced postings and derives account effects inside one transaction.
- **Engineering purpose:** Every later money flow depends on this arithmetic being correct on an empty system.
- **Dependencies:** EP-02-030.
- **Expected outcome:** Every entry balances to zero per currency; invalid directions and currency mixtures are rejected; correction is a reversing entry; property-based tests cover rounding, reversal and multi-posting cases; no update/delete path exists.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-032 — Wallet derived views and statement read model
- **Objective:** Provide derived wallet figures — total, available, pending, withdrawable — and a ledger-backed statement read model per account.
- **Engineering purpose:** The prototype’s wallet semantics must be produced from entries, never from an editable balance.
- **Dependencies:** EP-02-031.
- **Expected outcome:** Views reconcile to the underlying postings; an empty wallet reads zero; statement rows include activity attribution where present; no client can mutate a balance; read access is owner-scoped and RLS-tested.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-033 — Escrow account model and state machine
- **Objective:** Model escrow ledger accounts and the escrow lifecycle states, with transitions enabled only where policy is decided.
- **Engineering purpose:** The escrow structure must exist before transactions, but its release policy is not EP-02’s to invent.
- **Dependencies:** EP-02-031; BD-D03 for transition enablement.
- **Expected outcome:** Held balances are represented as ledger accounts; release and refund transitions are defined but disabled by default; an attempted release without an approved policy is rejected; no fee or split calculation exists.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-034 — Money idempotency and provider reference model
- **Objective:** Implement idempotency keys and provider-reference storage for every money-moving operation.
- **Engineering purpose:** Providers retry; duplicate application of an event is a financial defect.
- **Dependencies:** EP-02-030, EP-02-031.
- **Expected outcome:** The same key or provider event applies once; a conflicting reuse is rejected; the provider reference is unique where required; the test proves a second application is a no-op; references are traceable to journal entries.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-035 — Financial limits, KYC gating and capability enforcement
- **Objective:** Resolve per-tier financial limits from configuration and enforce them, with KYC tier, inside the transaction for every financial write.
- **Engineering purpose:** Tier gating is a service-layer decision; configuration, not code, holds the numbers.
- **Dependencies:** EP-02-014, EP-02-032, EP-02-034.
- **Expected outcome:** `tier_0` is denied; `tier_1` is allowed only within its configured limit; unset configuration denies; denials carry stable codes; the check and the write share a transaction; limits have effective dates and audit.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-036 — Dispute case record and evidence linkage
- **Objective:** Add a typed dispute record linked to the admin case spine and private evidence, without implementing outcomes or refund rules.
- **Engineering purpose:** Disputes must have an evidentiary home before transactions exist; the policy remains BD-D03.
- **Dependencies:** EP-02-030; CP-016, CP-017.
- **Expected outcome:** A dispute references parties, a case, evidence and status; no resolution or refund transition exists; evidence access is signed and audited; the record is readable by scoped admin only.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

---

### Stage E — Provider adapter

#### EP-02-040 — PaymentProvider port and adapter contract
- **Objective:** Define the provider-agnostic port for collection accounts, deposits, payouts, status queries and account-name enquiry, with contract tests against a fake provider.
- **Engineering purpose:** VFD must be replaceable without touching the ledger.
- **Dependencies:** EP-02-031, EP-02-034.
- **Expected outcome:** The domain imports no VFD type; the port covers the phase’s operations; a fake adapter passes the contract suite; a second adapter can be added without schema change beyond provider references.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

#### EP-02-041 — VFD authentication and resilience client
- **Objective:** Implement VFD token acquisition, caching, refresh, timeout, retry and error mapping without a non-expiring token.
- **Engineering purpose:** A leaked non-expiring token grants indefinite access; the adapter must bound it.
- **Dependencies:** EP-02-040; VFD sandbox credentials.
- **Expected outcome:** Tokens are short-lived and refreshed safely; timeouts and retries are bounded; errors map to Hivorr codes; secrets never appear in logs; a failed token request fails closed.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-042 — VFD collections adapter
- **Objective:** Implement collection-account provisioning, virtual-account lookup and inward-credit normalisation through the provider port.
- **Engineering purpose:** Enables payer-matched deposits without letting VFD envelopes enter the domain.
- **Dependencies:** EP-02-041, EP-02-050.
- **Expected outcome:** A test account receives a sandbox credit; the adapter returns a normalised deposit event with payer name, reference and amount; duplicate references are detectable; no card or PAN data is handled.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-043 — VFD payouts adapter
- **Objective:** Implement single-transfer payouts, bank list and account-name enquiry through the provider port.
- **Engineering purpose:** Payout execution is the highest-risk outbound operation; it must be bounded, idempotent and reconcilable.
- **Dependencies:** EP-02-041, EP-02-053.
- **Expected outcome:** A sandbox payout to a verified account succeeds; a duplicate reference is rejected; a failed transfer returns a mapped failure and no ledger side effect; account enquiry returns the name used for binding.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-044 — VFD webhook intake, raw storage and dedupe
- **Objective:** Add the inbound webhook endpoint, raw-payload store, deduplication, status verification and asynchronous processing.
- **Engineering purpose:** The public write path must not be able to forge value; VFD provides no documented signature.
- **Dependencies:** EP-02-042, EP-02-043, EP-02-034; founder approval for the new inbound webhook.
- **Expected outcome:** Every event is stored raw before interpretation; the handler acknowledges quickly and processes asynchronously; dedupe is on a stable identifier; the event is verified against the status API before posting; a failed verification does not move value; the compensating control is recorded as a deviation.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-045 — VFD sandbox certification and settlement evidence
- **Objective:** Run VFD’s sandbox certification for the implemented collection, payout and enquiry operations and record the result.
- **Engineering purpose:** The exit gate requires a certification record, not an assertion that the adapter works.
- **Dependencies:** EP-02-042/043/044.
- **Expected outcome:** A certification record names the adapter commit, credentials (redacted), operations tested, results and vendor confirmation; known sandbox/production differences are recorded; failures are open findings.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage F — Deposits, payouts and reconciliation

#### EP-02-050 — Payout account binding, encryption and name enquiry
- **Objective:** Let an account bind a payout bank account, verify the account name through the provider, encrypt the bank details and enforce name match.
- **Engineering purpose:** Money may only leave to a destination the account proved it owns.
- **Dependencies:** EP-02-035, EP-02-040, EP-02-043.
- **Expected outcome:** Binding requires `tier_1+`; the resolved account name must match the verified legal name; bank details are field-level encrypted and never projected; a mismatch is rejected; binding and changes are audited; one account can hold the approved number of destinations.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-051 — Payer-name match rule and manual review path
- **Objective:** Implement the deposit payer-name rule with normalisation, exact matching and a review path for mismatches.
- **Engineering purpose:** The deposit rule is the primary defence against crediting the wrong person.
- **Dependencies:** EP-02-042, EP-02-050; G0 payer-name ruling.
- **Expected outcome:** A normalised exact match is accepted; a mismatch is rejected from automatic posting and queued for review; no fuzzy auto-approval exists; the decision and reason are audited; test cases cover case, spacing, ordering and legal-name variants.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-052 — Deposit posting and idempotent ledger flow
- **Objective:** Post a matched sandbox deposit to the ledger exactly once, with provider reference, idempotency key and audit.
- **Engineering purpose:** Proves the collection-to-ledger path before any transaction uses it.
- **Dependencies:** EP-02-031, EP-02-034, EP-02-051.
- **Expected outcome:** A matched deposit debits provider clearing and credits the user wallet; a replay posts nothing; a mismatch posts nothing; the journal entry balances; the wallet view reflects the posting; the traceability chain is complete.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-053 — Payout execution workflow and dual control
- **Objective:** Implement the payout request, eligibility check, approval and execution workflow with maker-checker on manual payouts.
- **Engineering purpose:** Outbound money requires both a policy check and a second human decision where the matrix requires it.
- **Dependencies:** EP-02-043, EP-02-050, EP-02-035; CP-020.
- **Expected outcome:** A payout request is refused for an unbound or unverified account; a manual payout requires a distinct approver; execution is idempotent; a provider failure leaves no half-posted state; the payout and its approval are audited.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-054 — Payout eligibility gate in service and RLS
- **Objective:** Enforce payout eligibility twice: in the finance service inside the transaction and in the database policy for the payout-account/payout tables.
- **Engineering purpose:** The exit gate requires the second line of defence to refuse independently.
- **Dependencies:** EP-02-030, EP-02-050, EP-02-053.
- **Expected outcome:** A service-layer bypass still cannot write an ineligible payout; the RLS deny test fails closed; unbound, unverified, mismatched and `tier_0` cases each have a deny test; no policy uses `auth.uid()`.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-02-055 — Reconciliation job and exception reporting
- **Objective:** Schedule a reconciliation run that compares provider settlement/status data with the ledger and produces a report with differences and owners.
- **Engineering purpose:** A ledger that is not reconciled is a belief, not a control.
- **Dependencies:** EP-02-043/044/052/053; worker.
- **Expected outcome:** Each run records period, provider totals, ledger totals, differences, owner and resolution; a seeded mismatch is detected and alerted; a clean run produces zero differences; the report is retained as evidence.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-056 — Financial audit coverage and traceability
- **Objective:** Ensure every verification decision and financial mutation emits an audit event with actor, target, before/after summary, reason, correlation ID and capability.
- **Engineering purpose:** The audit trail is the evidence that the controls operated.
- **Dependencies:** EP-02-015/016/031/052/053/055; EP-01-036; CP-005.
- **Expected outcome:** The audit list is complete for EP-02 actions; a missing event fails a test; the event and effect share a transaction; no update/delete path exists; traceability links action → entry → posting → provider reference → reconciliation.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

---

### Stage G — Frontend

#### EP-02-060 — Verification centre UI
- **Objective:** Build the user-facing verification centre for the six lanes: status, required evidence, upload, submit, freeze, rejection reason and resubmission.
- **Engineering purpose:** A user must be able to complete verification without a support ticket, and without gaining dashboard access from it.
- **Dependencies:** EP-02-013/015; design system; EP-01-052.
- **Expected outcome:** Each lane renders its own state and evidence requirements; actions call the generated client; denial and pending states are labelled, not colour-only; the dashboard remains accessible while unverified; no dead controls; pixel parity at three widths.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-02-061 — Wallet and payout account UI
- **Objective:** Build the wallet overview, statement, payout-account list and binding flow using derived figures and server-computed eligibility.
- **Engineering purpose:** The user sees financial state without the client becoming an authority.
- **Dependencies:** EP-02-032/035/050; design system.
- **Expected outcome:** Total, available, pending and withdrawable are server-derived; an empty wallet is coherent; binding shows the resolved/verified state; a `tier_0` account sees the reason, not a broken form; no amount is calculated in the client.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-02-062 — Financial action dialogs and deny-state UX
- **Objective:** Wire the approved financial-action dialog pattern for payout-account binding, payout request and verification submission confirmation, with explicit denial reasons.
- **Engineering purpose:** Prevents client-side financial logic and ambiguous failures.
- **Dependencies:** EP-02-013/050/053; prototype `FinancialActionDialog`.
- **Expected outcome:** Dialogs use server-returned eligibility and limits; confirmation is explicit; every denial maps to a stable code and a human explanation; keyboard focus is visible; no financial calculation lives in the component.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-02-063 — Visual regression and responsive verification
- **Objective:** Extend the visual regression baseline to every EP-02 screen at 375 / 768 / 1280 and prove parity.
- **Engineering purpose:** The prototype remains the visual authority as new surfaces are added.
- **Dependencies:** EP-02-060/061/062; EP-01-050.
- **Expected outcome:** Deterministic screenshots cover verification and wallet states; a deliberate 1 px change fails; no new hex, font family, size or radius is introduced; the baseline is approved.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — Medium · Coding — Medium

---

### Stage H — Exit evidence and closure

#### EP-02-070 — EP-02 E2E suite and staging verification
- **Objective:** Run the full exit-gate flow on staging: registration → six lane submissions → control review → approve/reject → audit → sandbox deposit match/mismatch → payout refusal for unbound/unverified → VFD certification.
- **Engineering purpose:** Proves the deployed system, not the local build, satisfies the phase gate.
- **Dependencies:** EP-02-015/016/045/052/053/054/055/060/061; staging deployment.
- **Expected outcome:** The E2E suite passes against the deployed digest; every deny branch is asserted; the staging digest is recorded; failures block closure.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-02-071 — Phase evidence pack and traceability index
- **Objective:** Assemble an index mapping every EP-02 objective, technical goal and completion criterion to an inspectable artefact.
- **Engineering purpose:** Makes the exit gate auditable by a third party instead of asserted by the team.
- **Dependencies:** Every EP-02 item.
- **Expected outcome:** One index links lane tests, ledger invariant report, VFD certification, reconciliation report, control E2E, RLS deny test, visual baseline, audit samples and the staging run; every criterion has an artefact or is explicitly unmet.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Low

#### EP-02-072 — Phase security and quality review
- **Objective:** Conduct the end-of-phase review of verification, KYC data handling, ledger invariants, payout gating, RLS, audit immutability, provider security and test adequacy.
- **Engineering purpose:** Catches systemic gaps that per-package reviews cannot see before closure.
- **Dependencies:** EP-02-071; second reviewer; OWASP and standards checklists.
- **Expected outcome:** A review record listing each checked rule, findings, and either remediation or an approved recorded deviation; no unmitigated critical or high finding remains; residual risks are named.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Low

#### EP-02-073 — G5 phase closure record
- **Objective:** Present the evidence pack and review outcome to the founder for phase closure.
- **Engineering purpose:** Makes closure an explicit, signed decision rather than an inference from finished tasks.
- **Dependencies:** EP-02-071, EP-02-072.
- **Expected outcome:** A signed closure record states the phase outcome, the staging digest that satisfied it, accepted residual risks and the entry conditions EP-03 inherits; or a documented decision to hold.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Low

---

## 11. Expected phase outcome

EP-02 succeeds when the following are true, demonstrated on staging, not described:

1. **A test account can complete verification.** For each of the six lanes, evidence is submitted, reviewed in `control.`, and decided as `APPROVED` or `REJECTED`.
2. **Lanes are independent.** Approving identity does not approve trade, seller, logistics or business; rejecting a trade leaves identity and KYC unchanged.
3. **Decisions are evidenced.** Every decision records the actor, timestamp, evidence reference, reason and lane, and cannot be edited or deleted.
4. **Evidence is private.** No unsigned or public access works; every read is signed and audited; unscanned files are unusable.
5. **KYC gates money.** A `tier_0` account can browse and prepare but cannot withdraw, receive earnings or bind a payout destination; a `tier_1` account operates within configured limits.
6. **The ledger balances.** Property-based tests prove every entry balances per currency, reversals correct without edits, and derived balances reconcile to postings.
7. **Deposits are payer-matched.** A sandbox deposit whose payer name matches the verified legal name posts once; a mismatch is rejected and queued.
8. **Payouts are destination-safe.** An unbound, unverified, mismatched or `tier_0` payout is refused by the service layer and independently by RLS.
9. **The provider is replaceable.** The domain and ledger contain no VFD-specific type; the adapter passes its contract suite and sandbox certification.
10. **Reconciliation is real.** A run produces a report with provider totals, ledger totals, differences and owners, and a seeded mismatch is detected.
11. **Taxonomy is configurable.** An authorised admin adds a profession or product node with version, effective date and audit; no deploy is required.
12. **Control authority holds.** Verification overrides and manual financial adjustments require a second approver; no one approves their own action.
13. **Audit is complete.** Every verification and financial mutation has an event written in the same transaction.
14. **The UI is unaltered.** Verification and wallet surfaces are pixel-identical to the prototype at three widths.
15. **No marketplace flow exists.** No Buy, Hire, Errand, Sell, Offer-services or Logistics transaction was built.

---

## 12. Phase completion criteria

EP-02 is complete only when all of the following hold, each with a linked artefact in EP-02-071.

| # | Criterion | Evidence |
| --- | --- | --- |
| C1 | Entry gate satisfied | Signed EP-02-001 record; EP-01 G5 linked; four decisions recorded |
| C2 | Six lanes implemented | Schema and state-machine tests for every lane, including every deny branch |
| C3 | Lane independence proven | Table-driven test showing one lane’s decision changes no other lane |
| C4 | One active submission enforced | Constraint and concurrency test |
| C5 | Decisions immutable | No update/delete path; decision record and audit sample |
| C6 | Evidence private | Unsigned denial, signed access, audit-on-read, scan-before-use tests |
| C7 | KYC gating proven | `tier_0` deny and `tier_1` allow tests; unset-limit deny |
| C8 | Ledger balances | Property-based invariant report |
| C9 | Ledger append-only | No update/delete path; reversal test |
| C10 | Idempotency proven | Duplicate event applies once |
| C11 | Provider-agnostic | Port contract suite; no VFD type in domain |
| C12 | Payer match proven | Match and mismatch tests; review path |
| C13 | Payout gate proven twice | Service-layer deny and independent RLS deny test |
| C14 | VFD certified | Sandbox certification record for the adapter commit |
| C15 | Reconciliation proven | Report with totals, differences, owner; seeded mismatch detected |
| C16 | Control review proven | `control.` E2E for all six lanes; dual control; no self-approval |
| C17 | Taxonomy admin-configurable | Add/edit/version/audit test; no deploy |
| C18 | Audit complete | Every EP-02 action emits an event; missing event fails a test |
| C19 | Visual identity preserved | Baseline approved; pixel parity at 375 / 768 / 1280 |
| C20 | No marketplace flow | Route/import/boundary checks |
| C21 | Staging E2E green | EP-02-070 run against the recorded digest |
| C22 | Quality gates honest | Typecheck, lint, tests, contract, migration, RLS, visual, dependency and secret scans all blocking and proven to fail when seeded |
| C23 | Review complete | EP-02-072 record with no unmitigated critical or high finding |
| C24 | Closure signed | EP-02-073 founder signature with artefacts and accepted residual risks |

**A criterion without an artefact is unmet. A phase is not `Completed` because its tasks are `Completed`.**

---

## 13. What EP-02 deliberately does not prove

Recorded so the exit gate is not overread:

- That a marketplace transaction can complete — no Buy, Hire, Errand, Sell, Offer-services or Logistics flow exists.
- That escrow release, refund or dispute outcomes work — BD-D03 is open; only the structure and record exist.
- That fees or splits can be calculated — fee computation is out of scope.
- That multi-currency or FX works — only the ledger currency dimension exists.
- That the platform is production-ready — EP-02 exits on staging; G4 is a later phase.
- That VFD production behaviour matches sandbox — certification is sandbox evidence, not production proof.
- That KYC/AML obligations are satisfied — applicability is an R1/R2 question for counsel.

## 14. Transition handed to EP-03

EP-03 inherits, and must not need to rebuild: the six verification lanes and decisions, the KYC tier input, the private evidence store, the control review integration and dual-control pattern, the two taxonomy read contracts, the ledger and posting engine, escrow accounts, payout-account binding, the provider port and VFD adapter, payer-matched deposits, reconciliation, and the EP-02 audit and RLS patterns.

EP-03 must still build the two-party transaction flow, escrow release policy (BD-D03), fee application (BD-D02 numbers), contract/milestone state, reviews, messaging and earnings visibility. EP-02 does not pre-build any of them.

---

**Plan status:** complete for EP-02 only. No future phase has been analysed, expanded or planned, no implementation documentation has been produced, and no production code has been written.

**Before this becomes actionable:** EP-01 must exit through G5; the funds-custody register must record BD-D01; VFD must confirm its licence scope in writing; the KYC ladder and verification vendor must be decided; and a second reviewer must be recorded. Until then EP-02 remains `Not started`.
