# EP-00 Entry Record — Phase entry, G0 rulings and decision closure

| Field | Value |
|---|---|
| **Document ID** | `EP-00-000` |
| **Phase** | `EP-00` — Execution Readiness |
| **Task name** | Phase entry record, G0 rulings and decision closure |
| **Record version** | `0.9` — DoD approved |
| **Record status** | `Verified` — reviewed and approved by role on 2026-11-04 |
| **Phase status** | **`In build`** |
| **Class** | `[FOUNDER]` — confirmed 2026-11-04 |
| **Author** | AI implementation agent (drafting role) |
| **Date drafted** | 2026-11-04 |
| **Date approved** | 2026-11-04 |
| **Approvers** | Prince Abidemi Oluwadamilare — Architect / project technical owner (`[REVIEW]`) and Founder (`[FOUNDER]`) |

> **Approval basis.** This record records decisions approved by explicit written instruction in the implementation session on 2026-11-04 ("approve all"), attributed to the named roles below. It does not approve anything beyond what is recorded, does not create the remote, does not enable CI and does not authorise deployment. The signatory is Prince Abidemi Oluwadamilare, who holds the architect and founder roles for this record; the roles remain separately recorded.

---

## 1. Identity

| Field | Value |
|---|---|
| **Record ID** | `EP-00-000` |
| **Related phase** | `EP-00` — Execution Readiness |
| **Roadmap phase served** | Phase 0 — Foundation and preparation |
| **Record type** | Phase entry record and decision closure |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-00 — Execution Readiness.md` |
| **Approved implementation plan** | `documents/Task-Implementation/EP-00/EP-00-000 — Phase entry record, G0 rulings and decision closure.md` |
| **Definition of Done** | `documents/Task-Implementation/EP-00/EP-00-000 — Definition of Done.md` |
| **Author role** | Developer (AI agent, drafting only) |
| **Reviewer role** | Architect / project technical owner |
| **Approver role** | Founder |
| **Signature state** | `SIGNED` — Prince Abidemi Oluwadamilare, 2026-11-04 (architect and founder roles) |
| **Decision state** | 7 of 7 recorded; no decision pending |
| **Phase state** | `In build` |

---

## 2. Authority basis

This record relies on the following approved documents. Where a document and this record disagree, the owning document wins and the conflict is recorded, not resolved (`GOV-05`).

| Document | Version / status | Sections relied on |
|---|---|---|
| `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` | v2.0, approved 2026-11-04 | §5 roles and decision rights; §7 gates G0–G5; §8 work-package protocol; §9 status vocabulary and evidence rule; §11 open decisions |
| `documents/Engineering-Execution/Engineering-Phase-Plan/EP-00 — Execution Readiness.md` | Approved phase plan | §1 phase definition; §4.3 scope interpretations; §6 order; §7 dependencies; §9 items; §11 completion criteria; §13 transition |
| `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | v2.0, approved 2026-11-04 | `GOV-05`, `GOV-08`–`GOV-19`, `QUA-29`–`QUA-37`, `TEC-12`, §12 AI compliance, §13.3 exceptions, §16 #18 |
| `documents/Context/ARCHITECTURE.md` | Approved | §2.3 database provider; §2.5 dependency policy; §11.6 local development; §12.1–§12.8 CI/CD; §15.5 infrastructure; §16.3 #6/#8; §16.4 consolidated open decisions |
| `documents/Context/AGENTS.md` | Approved 2026-11-01 | §1 source-of-truth hierarchy; §3 bounded scope and reuse; §7 open decisions |
| `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` | Approved | Not engaged — no schema, migration, grant or RLS work in EP-00-000 |
| `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` | Approved | Not engaged — no capability, account or permission work in EP-00-000 |
| `documents/Context/VISION.md` | Approved | Context only |
| `documents/Business-Roadmap/Business-Development-Roadmap.md` | — | §14 Phase 0 context only |

**Register ownership.** This record is not a decision register. Each settled decision must be folded into the register that owns it (`QUA-38`, `QUA-39`). `ARCHITECTURE.md` §16.4 remains the single consolidated list; `standards` §16 adds only what is new; deviations belong in `standards` §13.3 (`GOV-15`).

---

## 3. Entry-gate verification

EP-00 §1 defines the entry gate as:

> Execution structure approved; founder available to approve the CI provider and repository hosting (`standards` §16 #18).

| # | Entry-gate condition | State | Evidence |
|---|---|---|---|
| 1 | Execution structure approved | **Met** | `ENGINEERING_EXECUTION_STRUCTURE.md` v2.0, approved 2026-11-04 |
| 2 | Standards document approved | **Met** | `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` v2.0, approved 2026-11-04; EES §11.2 #1 closed |
| 3 | Founder available and decision #18 recorded | **Met** | #18 recorded in §5–§6, approved 2026-11-04 |
| 4 | Founder has opened EP-00 for build | **Met** | Founder opening recorded in §11, 2026-11-04 |

**Result.** The entry gate is met and the phase is opened. EP-00 is `In build` from 2026-11-04. `ED-03` is satisfied: EP-00 is the only phase `In build`; EP-01 remains `Not started`.

---

## 4. Verified starting position

Re-verified on **2026-11-04** with read-only commands. These facts describe the repository **before this record was created**.

### 4.1 Commands and outputs

| Command | Output |
|---|---|
| `git status --porcelain=v1` | 19 untracked top-level entries; no tracked files |
| `git log --oneline -5` | `fatal: your current branch 'main' does not have any commits yet` |
| `git branch --show-current` | `main` |
| `git remote -v` | Empty — no remote configured |
| `git rev-parse --is-inside-work-tree` | `true` |
| `Get-Command node` | Absent from `PATH` |
| `Get-Command pnpm` | Absent from `PATH` |
| `Get-Command npm` | Absent from `PATH` |
| `Get-Command mise` | Absent from `PATH` |
| `Get-Command git` | `C:\Program Files\Git\cmd\git.exe` |
| `Test-Path .github` | `False` |
| `Get-ChildItem -Recurse -File -Include *.test.*,*.spec.*` | 0 files |
| `Test-Path documents/Engineering-Execution/Engineering-Phase-Records` | `False` (before this record) |
| `Test-Path documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` | `False` (before this record) |

### 4.2 Verified facts

| Area | State |
|---|---|
| Git history | `.git` exists, branch `main`, **zero commits**, no remote |
| Tracked files | None |
| Application code | Prototype only: `src/app/App.tsx` and the unused shadcn kit |
| API / worker / database | Do not exist |
| CI/CD | No `.github/`, no pipeline, no required checks |
| Tests | Zero test files; no test runner installed |
| Lint | No `lint` script; no lint configuration |
| Toolchain | Node, pnpm, npm and mise absent; `git` present |
| Lockfile | `pnpm-lock.yaml` present; `EX-19` open (importer mismatch) |
| Prototype build | Documented as working; **not verified in this environment** |
| Figma Make preview | `vite.figma.config.ts` present; unchanged |

### 4.3 Drift from the EP-00 §9 snapshot

No drift was observed in the facts above. The EP-00 plan's 4 November 2026 snapshot remains accurate.

**Post-draft state.** This record is the only artifact created by `EP-00-000`. The records directory did not exist before it. No other file was created or modified.

**Post-record note.** The toolchain was provisioned on 2026-11-04 after this record was signed: **Node v22.23.4** via **mise 2026.11.0**, and **pnpm 10.34.9** via mise. The pnpm pin was amended from `10.34.3` to `10.34.9` because `10.34.3` carries no npm attestation and mise's `no-downgrade` trust policy correctly refused it; `10.34.9` is a same-line patch published by GitHub Actions with an attestation and is older than the 7-day `minimumReleaseAge`. The historical snapshot above is unchanged. The external prerequisite that blocked `EP-00-001` is cleared.

---

## 5. Decision closure

**Status key:** `RECORDED` = decision text and approver exist; `PENDING` = no decision exists and no default has been adopted. As of 2026-11-04 there are no `PENDING` decisions.

| ID | Decision | Owning register | Outcome | Decided by | Date | Class | Evidence | Follow-up |
|---|---|---|---|---|---|---|---|---|
| **D-01** | Repository hosting and CI provider (#18) | `standards` §16 #18; consolidated list `ARCHITECTURE.md` §16.4 | **RECORDED** — GitHub, GitHub Actions, private repository, protected `main`, native scanning, `staging`/`production` definitions only, no deployment | Founder | 2026-11-04 | `[FOUNDER]` | Written approval in the implementation session, 2026-11-04 | Folded into `ARCHITECTURE.md` §16.4 #25; `standards` §16 #18 marked decided, 2026-11-04 |
| **D-02** | Ruling 1 — local-run scope and Postgres/API/worker reassignment | `EP-00` §4.3 ruling 1 | **RECORDED** — EP-00 delivers the verified existing bootstrap; Postgres/API/worker reassigned to EP-01 | Founder | 2026-11-04 | `[FOUNDER]` | Written approval, 2026-11-04 | None — phase record is the ruling of record |
| **D-03** | Ruling 2 — `EX-10` closure at EP-00 | `EP-00` §4.3 ruling 2; `standards` §13.3 `EX-10` | **RECORDED** — `EX-10` partially closed at EP-00 (runner only); Playwright, Testcontainers and component DOM are EP-01 work | Architect / project technical owner | 2026-11-04 | `[REVIEW]` | Written approval, 2026-11-04 | Ruling recorded against `EX-10` in `standards` §13.3, 2026-11-04; the row stays open for the EP-01 residual |
| **D-04** | Ruling 3 — linter as gate, `oxfmt` as formatter, choice deferred to `EP-00-004` | `EP-00` §4.3 ruling 3 | **RECORDED** — real linter is the gate; `oxfmt` remains the formatter; linter choice is made in `EP-00-004` | Architect / project technical owner | 2026-11-04 | `[REVIEW]` | Written approval, 2026-11-04 | Linter selection remains an `EP-00-004` decision |
| **D-05** | Ruling 4 — work-package identifier convention | `ENGINEERING_EXECUTION_STRUCTURE.md` §8.1 | **RECORDED** — `EP-<phase>-<nnn>`; `EP-00-000`–`EP-00-011`; `WP-` retired | Founder | 2026-11-04 | `[FOUNDER]` | EES §8.1 and §13 changelog entry, 2026-11-04 | None — already amended |
| **D-06** | Second-reviewer arrangement | `EES` §11.2 #2; risk R6; `standards` §13.3 | **RECORDED** — `DEV-001` approved, time-boxed, with compensating controls; no `G4` extension; filed in `standards` §13.3 | Founder | 2026-11-04 | `[FOUNDER]` | Written approval, 2026-11-04 | None before `EP-00-007`; the deviation is filed |
| **D-07** | Phase opening | `EES` §5.2, §9.2 | **RECORDED** — EP-00 opened for build | Founder | 2026-11-04 | `[FOUNDER]` | §11 signature block | None |

### 5.1 What was decided, and what remains outside this record

**Decided on 2026-11-04:**

- #18: GitHub as host and GitHub Actions as CI, private repository, protected `main`, native secret and dependency scanning, environments as definitions only, no deployment.
- Ruling 1: EP-00 covers the existing bootstrap; Postgres, API and worker move to EP-01 in writing.
- Ruling 2: `EX-10` is partially closed at EP-00.
- Ruling 3: a real linter is the gate; `oxfmt` remains the formatter; the linter is chosen in `EP-00-004`.
- `DEV-001`: time-boxed second-reviewer deviation.
- EP-00 is opened for build.

**Deliberately not decided here:**

- The specific linter and rule set (`EP-00-004`).
- The specific test toolchain versions (`EP-00-003`).
- The Postgres provider, hosting/DNS/TLS and sign-in identifier (`EP-01` entry decisions).
- Any dependency, scan vendor or deployment configuration.
- Any implementation of the remote, CI, protection or scanning; `EP-00-005`–`008` execute.

`ARCHITECTURE.md` §15.5 and §16.3 #8 recommended GitHub Actions and a protected GitHub Environment. That recommendation is now the recorded #18 decision. It created no remote and enabled nothing; execution remains `EP-00-005`.

---

## 6. G0 rulings

### 6.1 Ruling 1 — Local-run scope

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Decision** | EP-00 delivers a verified developer bootstrap for what exists today (clone → pinned toolchain → frozen install → typecheck → lint → test → build → dev server), plus a stated contract for how EP-01 extends it to Postgres, API and worker. The Postgres/API/worker clause is reassigned to EP-01 explicitly, in writing. |
| **Decided by** | Founder |
| **Date** | 2026-11-04 |
| **Class** | `[FOUNDER]` — phase-scope change (`EES` §5.2) |
| **Effect** | `EP-00-009` is deliverable; EP-01 inherits the Postgres/API/worker bootstrap |
| **Evidence** | Written approval, 2026-11-04 |

### 6.2 Ruling 2 — `EX-10` closure

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Decision** | `EX-10` is recorded as partially closed at EP-00 — runner installed and gating — with Playwright, Testcontainers and component-test DOM named as EP-01 work against the same register row. |
| **Decided by** | Architect / project technical owner |
| **Date** | 2026-11-04 |
| **Class** | `[REVIEW]` |
| **Effect** | EP-00 can exit without pulling visual-regression and integration tooling ahead of the code they test; `EX-10` remains open for its EP-01 residual |
| **Evidence** | Written approval, 2026-11-04 |

### 6.3 Ruling 3 — Linter and formatter

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Decision** | Add a real linter as the gate, keep `oxfmt` as the formatter, and wire both. Linter choice is an architect `[REVIEW]` decision under `GOV-09`, evaluated against `TEC-05`/§3.3, and is made in `EP-00-004`. This record does not name a linter. |
| **Decided by** | Architect / project technical owner |
| **Date** | 2026-11-04 |
| **Class** | `[REVIEW]` |
| **Effect** | `EP-00-004` proceeds with a defined gate and an open tool choice |
| **Evidence** | Written approval, 2026-11-04 |

### 6.4 Ruling 4 — Identifier convention

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Decision** | Work-package identifiers take the `EP-` prefix: `EP-<phase>-<nnn>`. This plan's items are `EP-00-000` to `EP-00-011`. The `WP-` form is retired, and an identifier in either form is never reused. |
| **Decided by** | Founder |
| **Date** | 2026-11-04 |
| **Authority** | `ENGINEERING_EXECUTION_STRUCTURE.md` §8.1, amended 2026-11-04; §13 changelog |
| **Evidence** | EES §8.1 text and changelog entry |
| **Follow-up** | None — already amended |

---

## 7. Second reviewer

**Status:** `RECORDED — FILED` — `DEV-001` approved and filed in `standards` §13.3 on 2026-11-04.

Because the approval instruction did not name an external reviewer, the time-boxed `GOV-13` deviation is the recorded arrangement. It is cited here by ID only; its full record belongs in `standards` §13.3 (`GOV-15`).

| Field | Content |
|---|---|
| **ID** | `DEV-001` |
| **Rule** | `QUA-29` (no self-merge) and `QUA-31` (two reviewers for CI configuration) |
| **Scope** | EP-00 CI configuration and review steps: `EP-00-006`, `EP-00-007`, `EP-00-008` |
| **Reason** | One-person team plus AI agents; no second human reviewer is available. The author is an agent and the approver is the human, but `QUA-31` requires two reviewers for CI configuration. |
| **Risk** | A CI defect or gate bypass could merge without the second human review; protection could be configured incorrectly. |
| **Compensating control** | Founder review of every diff; agent-assisted review checklist; seeded-failure proof for every gate; required status checks; no self-approval by the author; protection settings exported as evidence. |
| **Owner** | Founder |
| **Expiry** | Before EP-01 touches authentication, capability or migration code, and no later than 2026-12-31, whichever is earlier |
| **Approval** | Founder, 2026-11-04 |
| **G4** | Does **not** extend to `G4` (production release) |
| **Filing** | `standards` §13.3 — **FILED** 2026-11-04; recorded under the deviation records section |

**Residual.** `DEV-001` is filed in `standards` §13.3 as of 2026-11-04. The deviation remains time-boxed: it expires before EP-01 touches authentication, capability or migration code, and no later than 2026-12-31. It does not extend to `G4`.

---

## 8. Item blocker matrix

Statuses use the `EES` §9.1 vocabulary only. The phase is `In build`; item-level blockers remain.

| Item | Name | Status | Blockers | Owner | Clearing condition |
|---|---|---|---|---|---|
| **EP-00-001** | Toolchain, lockfile and first commit | `Ready` | None — toolchain provisioned 2026-11-04 | Executing owner | Frozen install, typecheck, build, first commit and tag |
| **EP-00-002** | Toolchain contract and CI/local parity | `Not started` | `EP-00-001`; CI half deferred to `EP-00-006` | Developer; architect | `001` complete; `packageManager`/`engines` drafted |
| **EP-00-003** | Vitest, scripts and proven-failing test | `Not started` | `001`, `002`; architect approval of the test toolchain (`GOV-09`); versions ≥7 days (`TEC-09`) | Architect; developer | Written `[REVIEW]` approval; `001`/`002` complete |
| **EP-00-004** | Linter, format check and baseline register | `Not started` | `001`, `002`; linter selection and rule set decided within `004` | Architect; developer | `001`/`002` complete; linter and rule set approved in `004` |
| **EP-00-005** | CI provider, hosting and environment placeholders | `Ready` | None — #18 recorded | Founder | Execute the #18 decision: create the remote, configure the host features, record the settings export |
| **EP-00-006** | Pipeline skeleton and per-stage failure proof | `Not started` | `002`, `003`, `004`, `005` | Developer; architect | All four complete; remote and CI exist |
| **EP-00-007** | Branch model, protected `main`, review settings | `Not started` | `005`, `006` | Architect; founder | Green pipeline on the tagged commit; protection enabled and demonstrated |
| **EP-00-008** | Secret and dependency scanning | `Not started` | `005`, `006` | Developer; architect | Native secret scanning and dependency scanning enabled and proven with controlled fixtures |
| **EP-00-009** | Developer bootstrap and local-run instruction | `Not started` | `002`–`006` | Developer; architect | Stages 1–3 green; bootstrap executed on a clean machine |
| **EP-00-010** | Phase evidence pack and traceability index | `Not started` | `000`–`009` | Developer; architect | All prior items complete and evidenced |
| **EP-00-011** | G5 phase closure record | `Not started` | `010`; architect's recommendation | Founder; architect | Evidence index complete; architect recommends closure |

**Notes.**

- `EP-00-005` is a founder act, not engineering work. It is `Ready` but must not create a deployment or a deploy workflow.
- `EP-00-001` is now `Ready`: the toolchain prerequisite is met (Node v22.23.4, pnpm 10.34.3). It is no longer `Blocked`.
- The critical path remains `001 → 002 → 003/004 → 006 → 008 → 007 → 010 → 011`, with `005` gating `006`–`008`.
- Exactly one phase is `In build` (`ED-03`): EP-00. EP-01 remains `Not started`.

---

## 9. Phase status determination

### 9.1 Gate checklist

| Condition | State |
|---|---|
| Founder has opened EP-00 for build | **Yes** — 2026-11-04 |
| #18 recorded with all required content | **Yes** — §5 D-01 |
| Rulings 1–3 recorded | **Yes** — §6 |
| Second-reviewer arrangement recorded | **Yes** — `DEV-001`, filed in `standards` §13.3 |
| Toolchain available (R1) | **No** — blocks `001`+, not the phase opening |

### 9.2 Result

**Phase status: `In build`.**

The phase opened on 2026-11-04. The toolchain was provisioned after signing — Node v22.23.4 and pnpm 10.34.3 — so `EP-00-001` may begin. No item may claim progress above its evidence.

### 9.3 Class of this record

**Class applied: `[FOUNDER]`.**

Under `GOV-08`, the class is the highest among the rules engaged. This record carries:

- `#18`, a `[FOUNDER]` decision (`GOV-09`, `standards` §16 #18);
- ruling 1, a phase-scope change and therefore a founder decision (`EES` §5.2);
- the phase-opening act (`EES` §5.2).

### 9.4 What this record does not do

- It does not create the remote, enable CI, enable scanning or change branch protection; `EP-00-005`–`008` do.
- It does not select a linter, test runner, scan vendor or dependency.
- It does not resolve any `[OPEN]` decision; the `[OPEN]` items listed in §5.1 remain open where they belong.
- It does not satisfy the EP-00 exit gate; only `EP-00-010` and `EP-00-011` can evidence closure.
- It does not authorise deployment; there is no staging or production environment in EP-00.

---

## 10. Residual risks and carried conditions

| # | Risk / condition | Impact | Owner | Handling |
|---|---|---|---|---|
| **R-A** | Personal signatory names were not supplied | **Resolved 2026-11-04** — signatory recorded as Prince Abidemi Oluwadamilare, holding the architect and founder roles | Project lead | Closed; roles remain separately recorded |
| **R-B** | `DEV-001` was not filed in `standards` §13.3 | **Resolved 2026-11-04** — filed in §13.3; the deviation is valid and time-boxed | Architect | Closed; re-open at expiry |
| **R-C** | Record was drafted before the plan's step-3 inputs, then completed on approval | A reader may treat the draft as unauthorised if the amendment log is skipped | Architect | Deviation accepted; see §11.2 |
| **R-D** | #18 chose native scanning; no third-party scanner | If a third-party scanner is later proposed, it becomes a `TEC-12` vendor decision | Founder / architect | Native preferred; record data flow, region and retention before any vendor is added |
| **R-E** | No toolchain on the drafting machine | **Resolved 2026-11-04** — Node v22.23.4 and pnpm 10.34.9, both mise-managed | Executing owner | Closed |
| **R-F** | Second-reviewer capacity remains a one-person constraint | `DEV-001` is time-boxed; the underlying conflict returns before EP-01 authentication work | Founder / architect | Appoint an external reviewer before the expiry; do not extend to `G4` |
| **R-G** | Windows workstation versus Linux CI | "Works on my machine" drift; lockfile resolves linux-only optional dependencies | Architect | CI is the reference; document the pin; record any native optional dependency |
| **R-H** | `minimumReleaseAge` blocks chosen tool versions | Pressure to lower a `[FOUNDER]` supply-chain control | Developer / architect | Choose versions older than 7 days; never lower the setting |
| **R-I** | Bootstrap exception R7 | First commit is direct to `main`; a precedent could survive | Architect | Record the exception explicitly in `007`; protect `main` immediately after |
| **R-J** | Scope creep into EP-01 | Playwright, Postgres, workspace packages and staging look like next steps | Architect | §3.2 scope guard and the stop-and-report rule |
| **R-K** | Register consolidation missed | **Resolved 2026-11-04** — `#18` folded into `ARCHITECTURE.md` §16.4 #25 and marked decided in `standards` §16; ruling 2 recorded against `EX-10` | Architect | Closed; `EX-10` remains open for its EP-01 residual |
| **R-L** | Record becomes a second register | Conflicts with `QUA-39` and `EES` §11.1 | Architect | Reference-only rows; no new decision IDs beyond owning registers |
| **R-M** | Personal names absent | **Resolved 2026-11-04** — signatory name recorded | Project lead | Closed |
| **R-N** | No CI run and no automated test exist | The record cannot claim a green pipeline or tested behaviour | Developer | State the absence explicitly; evidence arrives with `006` and later items |
| **R-O** | `mise install` refused `npm:pnpm@10.34.3`: its `no-downgrade` trust policy found no npm attestation, while `10.20.0` was published by GitHub Actions with attestation | **Resolved 2026-11-04** — the pin was amended to `10.34.9`, a same-line patch published by GitHub Actions with an attestation, 10 days old. No `trust_policy_excludes` and no `npm.shell_out` bypass were used | Founder / architect | Closed; the phase plan's `10.34.3` reference is superseded by this amendment |

### 10.1 Carried to EP-01

EP-01 inherits, and must not rebuild: repository history and the `v0.0.1-bootstrap` tag once `001` produces them; the protected trunk and review settings once `007` lands; the five-stage pipeline once `006` lands; the toolchain contract once `002` lands; the committed lockfile; Vitest once `003` lands; the lint/format gate once `004` lands; both scanning gates once `008` lands; the developer bootstrap once `009` lands; the evidence-index convention from `010`; and the `EP-` identifier convention.

EP-01 must add, and EP-00 must not pre-empt: workspace topology and package boundaries; the ten-module skeleton; PostgreSQL and the migration runner; Playwright, Testcontainers and Testing Library; the visual-regression baseline; the OpenAPI diff stage; migration lint and `db diff`; staging topology; build-once artifact digests; and the entry decisions EP-01 is blocked on (#1 provider, #17 hosting/DNS/TLS, #14 sign-in identifier).

`EX-10` is carried forward as **partially closed** per ruling 2. The second-reviewer arrangement is time-boxed by `DEV-001` and must be settled or re-deviated before EP-01 touches authentication, capability or migration code.

---

## 11. Signature and amendment log

### 11.1 Approval block

| Role | Name | Decision | Scope of approval | Date |
|---|---|---|---|---|
| **Author** | AI implementation agent (drafting role) | Drafted | Record text only; no decision approved | 2026-11-04 |
| **Architect / project technical owner** | Prince Abidemi Oluwadamilare | **Approved** | Fidelity, completeness, class and scope; rulings 2–3 | 2026-11-04 |
| **Founder** | Prince Abidemi Oluwadamilare (AfriNova) | **Approved** | #18, rulings 1 and 4, `DEV-001`, phase opening, class `[FOUNDER]` | 2026-11-04 |

**Approval source.** Explicit written instruction in the implementation session on 2026-11-04 ("approve all"), interpreted against the decision sheet presented immediately before it. The instruction approved the recommended #18 configuration, rulings 1–3, the `GOV-13` deviation option for the second reviewer (no external reviewer was named), the phase opening, class `[FOUNDER]`, and acceptance of the blocked-draft deviation.

**Signature limitation.** The same individual, Prince Abidemi Oluwadamilare, holds the architect and founder roles for this record. The roles are recorded separately and are not merged (`EES` §5.1). No independent second human reviewer exists; `DEV-001` addresses that gap and remains time-boxed.

At signature, the founder states:

1. the class applied is `[FOUNDER]`;
2. EP-00 is opened for build (`In build`);
3. #18 is the recorded GitHub configuration in §5 D-01;
4. rulings 1–3 are the recorded text in §6.

### 11.2 Amendment log

| Version | Date | Change | Author | Approval |
|---|---|---|---|---|
| **0.1** | 2026-11-04 | Initial draft. Created in `Blocked` form with all undecided items marked `PENDING` and owned. Drafted before the plan's step-3 decision inputs existed, under an explicit project-lead approval to create the blocked draft. | AI implementation agent | Project lead approved drafting in this form, 2026-11-04 |
| **0.2** | 2026-11-04 | Decisions D-01–D-07 recorded; phase set to `In build`; record set to `Verified`; `DEV-001` recorded; signature block completed by role; residual risks updated. | AI implementation agent | Founder and architect approvals recorded 2026-11-04 |
| **0.3** | 2026-11-04 | Signatory name recorded: Prince Abidemi Oluwadamilare, holding the architect and founder roles. Roles remain separately recorded. Risks R-A and R-M closed. | AI implementation agent | Founder/architect approval, 2026-11-04 |
| **0.4** | 2026-11-04 | `DEV-001` filed in `standards` §13.3; `EP-00-007` blocker and risk R-B closed; record version advanced. | AI implementation agent | Founder approval, 2026-11-04 |
| **0.5** | 2026-11-04 | `#18` folded into `ARCHITECTURE.md` §16.4 #25 and marked decided in `standards` §16; ruling 2 recorded against `EX-10`; risk R-K closed; evidence E11–E12 added. | AI implementation agent | Founder approval, 2026-11-04 |
| **0.6** | 2026-11-04 | Toolchain provisioned: Node v22.23.4 and pnpm 10.34.3, matching `.mise.toml`. `EP-00-001` moved to `Ready`; risk R-E closed; evidence E13 added. | AI implementation agent | Toolchain provisioning authorised by the founder, 2026-11-04 |
| **0.7** | 2026-11-04 | mise 2026.11.0 installed and trusted; Node 22.23.4 installed via mise. `mise install` blocked on `npm:pnpm@10.34.3` by the `no-downgrade` trust policy; no bypass applied. Risk R-O added; evidence E14 added. | AI implementation agent | mise installation authorised by the founder, 2026-11-04 |
| **0.8** | 2026-11-04 | pnpm pin amended from `10.34.3` to `10.34.9` in `.mise.toml` because `10.34.3` lacks npm attestation. `10.34.9` is a same-line patch published by GitHub Actions with attestation, 10 days old. `mise install` completed; risk R-O closed; evidence E15 added. No trust exclusion or `npm.shell_out` bypass used. | AI implementation agent | Founder approved the pin amendment, 2026-11-04 |
| **0.9** | 2026-11-06 | `EP-00-000` DoD approved by the project lead with the FA-14 recorded exception; TV-13 seeded-failure proof executed; evidence E16 added. | AI implementation agent | Project lead approval, 2026-11-06 |

**Deviation note.** The approved implementation plan said: "If #18 or any ruling is not provided, stop at step 3. Do not draft a speculative record." The draft was created under the alternative the plan identified as requiring explicit approval: create the artifact in `Blocked` form with `PENDING` placeholders. No decision was invented, no default was chosen, and the phase was not marked `In build` until the approvals existed. The deviation is now accepted by the same 2026-11-04 approval and is recorded here for audit.

### 11.3 Evidence attached to this record

| # | Evidence | State |
|---|---|---|
| E1 | Read-only starting-position commands in §4 | Recorded |
| E2 | Entry-gate verification in §3 | Recorded |
| E3 | Decision closure in §5 | 7 of 7 recorded |
| E4 | Blocker matrix in §8 | Complete for `001`–`011` |
| E5 | Phase status determination in §9 | `In build` |
| E6 | Founder signature | Recorded: Prince Abidemi Oluwadamilare, 2026-11-04 |
| E7 | Architect review | Recorded: Prince Abidemi Oluwadamilare, 2026-11-04 |
| E8 | CI run | **Does not exist** — no pipeline at this point |
| E9 | Automated test result | **Does not exist** — no test runner at this point |
| E10 | `DEV-001` filing in `standards` §13.3 | **Filed** 2026-11-04, §13.3 deviation records |
| E11 | `#18` consolidated decision | **Filed** 2026-11-04 — `ARCHITECTURE.md` §16.4 #25; `standards` §16 #18 marked decided |
| E12 | `EX-10` ruling record | **Filed** 2026-11-04 — `standards` §13.3 `EX-10` exit condition updated; row remains open |
| E13 | Toolchain verification | **Recorded** 2026-11-04 — `node -v` = `v22.23.4`; `pnpm -v` = `10.34.3` |
| E14 | `mise` verification | **Recorded** 2026-11-04 — mise `2026.11.0`; `mise ls` shows `node 22.23.4` and `npm:pnpm 10.34.9` installed |
| E15 | mise-managed pnpm verification | **Recorded** 2026-11-04 — `mise exec -- node -v` = `v22.23.4`; `mise exec -- pnpm -v` = `10.34.9`; `mise which pnpm` resolves to the mise install |
| E16 | `EP-00-000` DoD approval | **Approved** 2026-11-06 by Prince Abidemi Oluwadamilare, with the FA-14 recorded exception; see the DoD §9 approval record |

---

**Record status:** `Verified` — approved by role on 2026-11-04; phase `In build`.
**Next action:** Start `EP-00-001` (frozen install, typecheck, build, first commit and tag) now that the toolchain is present and mise-managed. `EP-00-005` remains a founder act: create the remote and configure the host per #18. `DEV-001` is filed; no further action is required before `EP-00-007`.
