# EP-02 — Entry Record

| Field | Value |
|---|---|
| **Record ID** | `EP-02-001` |
| **Record type** | Phase entry gate record and decision register |
| **Phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Task** | `EP-02-001` — Entry gate closure and decision register |
| **Record status** | **`BLOCKED`** — entry gate not met; phase not opened |
| **Phase status** | `Not started` |
| **Date** | 2026-11-15 |
| **Author** | AI implementation agent (drafting role) |
| **Approvers** | None — no approval was sought because the gate is not met |
| **Signature state** | `UNSIGNED` |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 — Trust, Identity & Financial Integrity Engine.md` |
| **Authority** | `ENGINEERING_EXECUTION_STRUCTURE.md` §6.5, §7, §8, §9 |

> **What this record is.** It verifies the EP-02 entry gate against the repository and the approved documents, records every decision EP-02 depends on, and records why the phase cannot open. It approves nothing, decides nothing, signs nothing and creates no runtime asset.

---

## 1. Entry-gate verification

EP-02 §1 defines the entry gate as:

> EP-01 G5 signed; funds-custody register updated to record BD-D01 partner-held custody; VFD written licence-scope confirmation obtained per BD-D11 conditions; KYC tier ladder decided (`ARCHITECTURE.md` §16.4 #6); verification vendor decided (#15); reviewer capacity / second reviewer recorded.

| # | Entry-gate condition | State | Evidence inspected | Owner |
|---|---|---|---|---|
| 1 | EP-01 G5 signed | **MET** | `EP-01-G5-CLOSURE.md` signed 2026-11-15; EP-01 closed through G5 | Founder |
| 2 | Funds-custody model recorded | **MET** — founder decision 2026-11-15: pooled collection/settlement account, internal wallets and internal escrow; legal/regulatory confirmation remains open | `PAYMENT-WALLET-ESCROW-ARCHITECTURE.md`; `ARCHITECTURE.md` §16.4 #2 | Founder / counsel |
| 3 | VFD written licence-scope confirmation | **UNMET** | BD-D11 conditions 1–6; `documents/integrations/vfd/VFD_INTEGRATION_NOTES.md` records the missing written scope, licence category and settlement terms | Founder / counsel |
| 4 | KYC tier ladder and limits decided | **UNMET** | `ARCHITECTURE.md` §16.4 #6; matrix §7.4 and §18 #6; BD-D05 is a recommendation, not a decision | Founder |
| 5 | Verification vendor decided | **UNMET** | `ARCHITECTURE.md` §16.4 #15; matrix §18 #12 | Founder |
| 6 | Reviewer capacity / second reviewer recorded | **UNMET** | `DEV-003` remains in force; EES §11.2 #2 records the one-person-plus-agents problem | Founder / architect |

**Result:** 2 of 6 entry conditions met. EP-01 is closed and the custody model is recorded, but EP-02 still cannot start verification or provider work without the remaining decisions.

---

## 2. EP-01 position

EP-01 is **closed through G5** on 2026-11-15. The closure record is
`Engineering-Phase-Records/EP-01/EP-01-G5-CLOSURE.md`.

- `F-49` — closed; staging reports the candidate release and the session/activity routes return `401`.
- `F-50` — closed; the four bundles are deployed and slice E2E passes 5/5.
- `F-28` / `C4` — closed; `supabase/schema-baseline.txt` is committed and `db diff --fail-on-change` passes.
- `C12` — met; smoke 13/13 (including CSP/HSTS) and E2E 5/5 against staging.
- Review queue — 39/39 tasks `COMPLETED`; no critical/high finding remains.
- Partial criteria C5, C11 and C14 and residuals R-1–R-9 are accepted in the closure record.

EP-01 closure does not open EP-02. The remaining EP-02 blockers are its own decisions, not EP-01.

---

## 3. Decision register

No row is decided by this record. `ARCHITECTURE.md` §16.4 remains the single consolidated register.

| # | Decision | Register | State | Effect on EP-02 | Owner |
|---|---|---|---|---|---|
| 1 | Funds custody — pooled collection/settlement account, internal wallets and internal escrow | `ARCHITECTURE.md` §16.4 #2; `PAYMENT-WALLET-ESCROW-ARCHITECTURE.md` | **DECIDED 2026-11-15** — product/custody model approved; legal/regulatory confirmation open | Unblocks ledger, wallet and internal escrow design; provider tasks still need VFD confirmation | Founder / counsel |
| 2 | VFD written licence scope — marketplace escrow, nationwide operation, third-party release, licence category and limits | BD-D11 conditions 1–6 | **NOT OBTAINED** | Blocks provider integration and any money movement | Founder / counsel |
| 3 | KYC tier ladder and per-tier limits | `ARCHITECTURE.md` §16.4 #6; BD-D05 | **OPEN** | Blocks tier configuration and financial gating | Founder |
| 4 | Verification vendor — review queue only, or identity provider | `ARCHITECTURE.md` §16.4 #15 | **OPEN** | Blocks identity/KYC lane implementation | Founder |
| 5 | Second reviewer / reviewer capacity | EES §11.2 #2; `DEV-003` | **OPEN** | Blocks G2 on verification and finance changes | Founder / architect |
| 6 | Taxonomy depth — two levels or five-level model | `VISION.md` §10 Q10; EP-02 plan §5.3 | **OPEN** | Shapes the registry and seed data | Founder / architect |
| 7 | Payer-name matching policy — verified legal name, normalisation, mismatch handling | `AGENTS.md` Rule 3; matrix §7.5; EP-02 plan §5.3 | **OPEN** | Shapes deposit matching and review | Founder / architect |
| 8 | Escrow release timing, dispute outcomes and refund rules | BD-D03; `ARCHITECTURE.md` §16.4 #11 | **OPEN** | Release/refund transitions remain disabled | Founder |
| 9 | Fee and take-rate numbers | BD-D02 | **OPEN** | Out of EP-02 scope; no fee computation | Founder |
| 10 | Currency model | `ARCHITECTURE.md` §16.4 #8; BD-D07 | **OPEN** | Ledger carries a currency dimension; no conversion | Founder |
| 11 | Retention periods | `ARCHITECTURE.md` §16.4 #7 | **OPEN** | Retain-and-hold; no purge | Founder / counsel |
| 12 | KYC/AML applicability | Standards §16 #25 | **OPEN** | No reporting path is built | Founder / counsel |
| 13 | VFD webhook authentication gap | Standards API-24; VFD webhook documentation | **OPEN** | Requires compensating controls and a recorded deviation | Architect |

---

## 4. G0 scope readings

The approved plan §5.3 records readings that need confirmation before implementation. This record does not resolve them.

| # | Reading | Status |
|---|---|---|
| 1 | Taxonomy depth | **Open** — the phase scope names five levels; `VISION.md` §10 Q10 still records two vs five as open. The registry will support the confirmed depth; no production reference data is seeded. |
| 2 | Six verification lanes | **Proposed** — KYC is a review lane and an account-level tier; it is not an activity lane. |
| 3 | Payer name | **Proposed** — match the verified legal name, normalised for case/whitespace/order, exact only; mismatch goes to review. |
| 4 | Control portal reuse | **Proposed** — CP-016/017/019/020 own the case, evidence, review and approval surfaces; EP-02 owns lane submission, decision effect and immutable record. |
| 5 | Escrow policy | **Proposed** — build the account and state model; disable release and refund until BD-D03. |
| 6 | Limits | **Proposed** — configuration with effective dates; unset configuration denies. |

---

## 4A. Partial-start decision — 2026-11-15

The founder approved the pooled wallet and internal escrow model and instructed that non-provider
EP-02 work may start while the remaining entry decisions are recorded.

| Scope | State |
|---|---|
| Shared contracts (`EP-02-002`) | **Eligible** |
| Finance schema, ledger, wallet views, escrow, idempotency, limits, disputes (`EP-02-030`–`036`) | **Eligible** |
| Verification lanes (`EP-02-010`–`016`) | **Blocked** on KYC ladder (#6) and verification vendor (#15) |
| VFD adapter (`EP-02-040`–`045` and deposit/payout tasks that call it) | **Blocked** on VFD written API/account confirmation |
| Frontend (`EP-02-060`–`063`) | **Blocked** until its API dependencies are built |
| Exit and G5 (`EP-02-070`–`073`) | **Blocked** until the phase capability is complete |

This is a recorded partial start, not a declaration that the full entry gate is met.

---

## 5. Repository observations

- The repository already contains CP P0/P1 governance work: admin authorisation, cases, evidence, approvals, staff, partners and an `admin.verification` queue.
- Those artefacts are reusable foundations and cross-phase `CP` packages. They are **not** EP-02 evidence and this record does not ratify them.
- `server/src/modules/finance` is a boundary only; no ledger exists.
- `server/src/modules/profile` contains activity activation only; no verification lane exists.
- `pnpm docs:check` initially rejected the approved EP-02 stage-block IDs because the checker defaulted new phases to contiguous. **Resolved 2026-11-15** by adding EP-02 to the stage-block scheme; no identifier was renumbered. The gate now passes with 3 phase plans and 93 allocated identifiers.

---

## 6. Blockers and owners

| # | Blocker | Owner | Closure evidence |
|---|---|---|---|
| B-01 | EP-01 G5 not signed; `F-49` and `F-50` remain high | Founder / architect | **CLOSED 2026-11-15** — G5 signed; staging current; slice deployed |
| B-02 | Funds-custody register still open | Founder / architect | `ARCHITECTURE.md` §16.4 #2 updated to record BD-D01 |
| B-03 | VFD written licence scope missing | Founder / counsel | Written confirmation from VFD MFB covering escrow, nationwide operation, third-party release, licence category and limits |
| B-04 | KYC tier ladder undecided | Founder | Recorded tier ladder and limits in the owning register |
| B-05 | Verification vendor undecided | Founder | Recorded decision, including a review-queue-only option |
| B-06 | Second reviewer not appointed | Founder / architect | Appointment record or a `DEV-003` deviation with compensating controls |

---

## 7. What this record does not do

- It does not open EP-02.
- It does not mark any EP-02 task `Ready` or `COMPLETED`.
- It does not decide an `[OPEN]` item.
- It does not edit `ARCHITECTURE.md`, `VISION.md`, the matrix or the database rules.
- It does not create a second decision register.
- It does not claim that CP P0/P1 work is EP-02 evidence.

---

## 8. Next action

1. ~~Founder/architect closes B-01~~ — **closed 2026-11-15**; EP-01 G5 signed.
2. Founder records B-02, B-04 and B-05 in the owning registers.
3. Founder/counsel obtains B-03.
4. Founder/architect records B-06.
5. Re-execute `EP-02-001`; only then may EP-02 become `Ready`.

**Signature:** none. The phase is blocked.

---

**Record status:** `BLOCKED`. No phase was opened and no implementation was authorised.
