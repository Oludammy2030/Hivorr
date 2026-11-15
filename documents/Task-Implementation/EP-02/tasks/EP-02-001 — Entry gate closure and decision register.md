# EP-02-001 — Entry gate closure and decision register

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-001` |
| **Task title** | Entry gate closure and decision register |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | Critical |
| **GOV-09 class** | `[REVIEW]` — phase gate record; any decision that widens authority remains `[FOUNDER]` |
| **Execution order** | 1 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage A |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Verify EP-01’s G5 evidence and record every decision EP-02 depends on before any work package becomes `Ready`. The task outcome is either a signed entry record that opens EP-02, or a `BLOCKED` record naming every unmet condition and its owner.

## 3. Scope

### 3.1 Included

- Verification of EP-01’s G5 evidence: the phase evidence pack, the security and quality review, and the closure record.
- Recording the funds-custody register correction required by BD-D01 and `ARCHITECTURE.md` §16.4 #2.
- Recording VFD’s written licence-scope position under BD-D11 conditions 1–6.
- Recording the KYC tier ladder and limits decision (`ARCHITECTURE.md` §16.4 #6).
- Recording the verification vendor decision (`ARCHITECTURE.md` §16.4 #15).
- Recording the second-reviewer position under `DEV-003` and EES §11.2 #2.
- Recording the G0 scope readings: taxonomy depth, payer-name policy, control-portal reuse, escrow policy and limits.
- Setting EP-02 to `Ready`, or to `BLOCKED` with named owners.

### 3.2 Excluded

- Making any founder decision or choosing a default for an `[OPEN]` item.
- Signing EP-01’s G5 or EP-02’s G5.
- Implementing any verification, financial, taxonomy, provider or frontend task.
- Editing `ARCHITECTURE.md`, `VISION.md`, the permission matrix or the database rules.
- Creating a fake decision record or treating a verbal position as recorded.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | EP-01 exits through G5 with `C4` and `C12` met and no open high finding. | EP-02 plan §1, §8.1 |
| R-02 | The funds-custody register records BD-D01 partner-held custody. | EP-02 plan §1, §8.3 |
| R-03 | VFD’s written licence scope confirms marketplace escrow, nationwide operation and third-party release. | BD-D11 conditions 1–6 |
| R-04 | The KYC tier ladder and limits are decided, not invented. | `ARCHITECTURE.md` §16.4 #6 |
| R-05 | The verification vendor is decided, including a review-queue-only option. | `ARCHITECTURE.md` §16.4 #15 |
| R-06 | A second reviewer or a recorded compensating deviation exists for verification and finance changes. | EES §11.2 #2; `DEV-003` |
| R-07 | Every G0 scope reading is recorded, including taxonomy depth and payer-name matching. | EP-02 plan §5.3 |
| R-08 | No decision is made by an agent; each is attributable to the founder or architect. | EES §5.6 |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-072` G5 closure | **PENDING** — cannot be signed while `F-49` and `F-50` remain high findings |
| `EP-01-071` phase security and quality review | **REQUIRES_REVIEW** — 0 critical, 2 high findings |
| `EP-01-070` evidence pack | **REQUIRES_REVIEW** — `C4` and `C12` unmet, `C16`/`C17` open |
| Funds-custody register correction | **OPEN** — `ARCHITECTURE.md` §16.4 #2 |
| VFD written licence scope | **NOT OBTAINED** — BD-D11 conditions 1–6 |
| KYC tier ladder and limits | **OPEN** — #6 |
| Verification vendor | **OPEN** — #15 |
| Second reviewer | **OPEN** — `DEV-003` remains in force |

## 6. Implementation plan

1. Read the approved EP-02 plan, EES §6.5 and §7, `AGENTS.md`, and the EP-01 evidence pack and tracker.
2. Inspect `EP-01-070`, `EP-01-071` and `EP-01-072`; do not infer G5 from commit activity.
3. Inspect `ARCHITECTURE.md` §16.4 #2, #6, #15 and #8; confirm which rows are still open.
4. Inspect BD-D01 and BD-D11; separate the decision already made from the evidence still required.
5. Inspect the permission matrix §7, §9.5 and §14 for lane, tier and admin-scope inputs.
6. Record every open decision, its owner and its blocking effect in `EP-02-ENTRY-RECORD.md`.
7. Record the §5.3 scope readings as proposed readings requiring architect confirmation; do not resolve them silently.
8. Set EP-02 to `BLOCKED` (or `Ready` only if every condition is evidenced), update the tracker and write the execution record.

## 7. Existing components and reusability

| Component | Use |
|---|---|
| `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` | Structure, decision-register table, authority basis and signature block |
| `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-EVIDENCE-PACK.md` | Criterion-by-criterion evidence format |
| `documents/Task-Implementation/EP-01/PHASE_EXECUTION_TRACKER.md` | Status vocabulary and next-eligible-task format |
| `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` | §6.5 entry gate, §7 gates, §8 work-package protocol, §9 status vocabulary |
| `documents/Business-Roadmap/Business-Development-Roadmap.md` | BD-D01, BD-D11 and the conditions still open |
| `documents/Context/ARCHITECTURE.md` | §16.4 open-decision register |
| `documents/Task-Implementation/EP-02/PHASE_OVERVIEW.md` | Phase scope and task sequence |
| `documents/Task-Implementation/EP-02/PHASE_EXECUTION_TRACKER.md` | Tracker to update |

No new decision register is created. `ARCHITECTURE.md` §16.4 remains the single consolidated register.

## 8. Files and systems affected

| Path | State |
|---|---|
| `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` | Created — `BLOCKED` |
| `documents/Task-Implementation/EP-02/PHASE_OVERVIEW.md` | Created — phase status and blockers |
| `documents/Task-Implementation/EP-02/PHASE_EXECUTION_TRACKER.md` | Created — task 001 `BLOCKED` |
| `documents/Task-Implementation/EP-02/tasks/EP-02-001 — Entry gate closure and decision register.md` | This document |
| `documents/Task-Implementation/EP-02/execution-records/EP-02-001.md` | Created — execution record |
| `scripts/check-work-packages.mjs` | Updated — EP-02 stage-block recognition; no identifier renumbering |

No application code, schema, migration, capability or configuration was changed.

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | EP-01 G5 is verified from the closure record, not from commit activity | Linked `EP-01-072` record |
| DoD-02 | Every entry decision is recorded with its owner and evidence | `EP-02-ENTRY-RECORD.md` decision table |
| DoD-03 | The funds-custody register correction is recorded or explicitly blocked | Architecture register reference |
| DoD-04 | VFD’s written licence-scope position is recorded or explicitly blocked | BD-D11 evidence |
| DoD-05 | KYC ladder, verification vendor and second reviewer are recorded or explicitly blocked | Decision table |
| DoD-06 | The §5.3 scope readings are recorded for architect confirmation | Entry record |
| DoD-07 | Phase status is one of `Ready` or `Blocked`, with named owners | Entry record + tracker |
| DoD-08 | No decision is invented, defaulted or attributed to an agent | Review of the record |
| DoD-09 | `pnpm docs:check` passes and every task ID traces to the phase plan | Command output |
| DoD-10 | Task document, tracker and execution record are current | Links |

**DoD result: not met.** DoD-01, DoD-03, DoD-04, DoD-05 and DoD-07 cannot be satisfied. The task is `BLOCKED`.

## 10. Acceptance criteria

- The entry record names every unmet condition and the person who owns it.
- A third party can inspect the record and see that no open decision was defaulted.
- EP-02 remains `Not started` and no implementation task is eligible.
- The governance gate recognises the approved EP-02 stage-block identifiers without renumbering the plan.
- The record states what evidence will close each blocker.

## 11. Testing and validation

| Test | Method | Result |
|---|---|---|
| T-01 | Inspect `EP-01-070`, `EP-01-071`, `EP-01-072` | **Fail** — G5 PENDING; 2 high findings (`F-49`, `F-50`) |
| T-02 | Inspect `ARCHITECTURE.md` §16.4 #2, #6, #15 | **Fail** — custody, KYC ladder and vendor remain open |
| T-03 | Inspect BD-D11 conditions 1–6 | **Fail** — written licence-scope confirmation not obtained |
| T-04 | Inspect `DEV-003` / EES §11.2 #2 | **Fail** — second reviewer not appointed |
| T-05 | `pnpm docs:check` after adding EP-02 stage-block support | **Pass** — 3 phase plans, 93 allocated identifiers |
| T-06 | Trace every task filename to a phase-plan heading | **Pass** — 40 task headings, 40 task documents |
| T-07 | Confirm no application code changed | **Pass** — documentation and governance script only |

## 12. Risks and considerations

| Risk | Impact | Handling |
|---|---|---|
| EP-01 remains open | EP-02 cannot start; every task stays `PENDING` | Do not open EP-02; close EP-01 `F-49`/`F-50` and sign G5 |
| An open decision is defaulted | Implementation encodes an assumption | Record it as `OPEN`; no code until the owner decides |
| The control-portal dependency becomes circular | Verification review cannot be evidenced | Confirm CP-016/017/019/020 sequencing in the entry record |
| The docs gate rejects the approved IDs | Task documentation cannot be added | Fixed by adding EP-02 to the stage-block scheme; no ID changed |
| The founder is also the architect and reviewer | One person holds several roles | Record the roles separately and keep `DEV-003` compensating controls |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `BLOCKED` |
| **Execution date** | 2026-11-15 |
| **Execution record** | `execution-records/EP-02-001.md` |
| **Blocked by** | EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer |
| **Next action** | Founder/architect closes the blockers, then this task is re-executed to produce the signed entry record |
