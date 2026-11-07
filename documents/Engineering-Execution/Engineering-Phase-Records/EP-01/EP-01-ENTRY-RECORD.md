# EP-01 Entry Record — Entry gate closure and decision register

| Field | Value |
|---|---|
| **Document ID** | `EP-01-001` |
| **Phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Task name** | Entry gate closure and decision register |
| **Record version** | `0.3` — EP-00 G5 signed; C8 accepted via `DEV-002` |
| **Record status** | `In review` — drafted and self-checked; the EP-01 record's own architect review and founder signature remain outstanding |
| **Phase status** | **`Blocked`** — EP-00 has exited, but `#1`, `#17`, `#14`, the second reviewer and the G0 rulings are still pending |
| **Class** | `[FOUNDER]` |
| **Author** | AI implementation agent (drafting role) |
| **Date drafted** | 2026-11-06 |
| **Date updated** | 2026-11-07 |
| **Approvers** | Architect / project technical owner (`[REVIEW]`); Founder (`[FOUNDER]`) — both `PENDING` for this record |

> **What this record is.** It records the true starting position of EP-01, re-verifies EP-00's exit
> evidence criterion by criterion, lists every decision EP-01 depends on by reference to the register
> that owns it, and sets EP-01 to one status. It approves nothing, decides nothing, signs nothing and
> creates no runtime asset.
>
> **Update — 2026-11-07.** EP-00's G5 was signed by the founder on 2026-11-07. C8 is accepted as
> `DEV-002` in `standards` §13.3; C10 is accepted as a recorded limitation; C14 is met. EP-00 has
> therefore exited. This record's *own* EP-01 entry gate is not met: `#1`, `#17`, `#14`, the second
> reviewer and the G0 rulings remain `PENDING`, so EP-01 stays `Blocked`.


---

## 1. Identity

| Field | Value |
|---|---|
| **Record ID** | `EP-01-001` |
| **Related phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Roadmap phase served** | Phase 0 → Phase 1 |
| **Record type** | Phase entry record and decision register |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` |
| **Approved implementation plan** | `documents/Task-Implementation/EP-01/EP-01-001 — Entry gate closure and decision register.md` |
| **Definition of Done** | `documents/Task-Implementation/EP-01/EP-01-001 — Definition of Done.md` |
| **Author role** | Developer (AI agent, drafting only) |
| **Reviewer role** | Architect / project technical owner |
| **Approver role** | Founder |
| **Signature state** | `UNSIGNED` — architect review `PENDING`; founder signature `PENDING` for this record. The EP-00 G5 is `SIGNED` separately (2026-11-07). |
| **Decision state** | 1 of 16 recorded (the EP-00 exit basis); 15 pending, each with a named owner |
| **Phase state** | `Blocked` — see §9; EP-00 has exited but EP-01's own entry gate is not met |

---

## 2. Authority basis

This record relies on the following approved documents. Where a document and this record disagree,
the owning document wins and the conflict is recorded, not resolved (`GOV-05`).

| Document | Version / status | Sections relied on |
|---|---|---|
| `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` | Approved phase plan | §1 phase definition and entry gate; §4.2 out of scope; §4.3 scope readings; §5.2 module disposition; §7 dependencies; §9 items `001`–`072`; §12–§13 expected outcome and completion criteria |
| `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` | v2.0, approved 2026-11-04 | §5.1 roles, §5.2 decision rights, §5.6 AI boundaries; §7.1 G0–G5, §7.2 evidence, §7.3 gate exceptions; §8.1–§8.5 work-package protocol; §9.1–§9.3 status vocabulary and evidence rule; §10 ED-01–ED-10; §11.1–§11.2 open decisions |
| `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | v2.1, approved 2026-11-06; §13.3 `DEV-002` added 2026-11-07 | §1.4 governance classes; §1.5–§1.6 rule application and identifiers; §13.2 deviations; §13.3 accepted exceptions (`EX-02`, `EX-10`, `DEV-001`, `DEV-002`); §13.4 enforcement; §16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9`,`#16`; §19.3 AR-0 impact note; §19.2 requirement classes |
| `documents/Context/ARCHITECTURE.md` | Approved | §4.9 hostnames and same-origin API; §5.4 session audiences; §8.12 bundles; §9.2 modules; §9.4 database strategy; §9.6 RLS; §10.2 enforcement layers; §11 environments; §12.1 branching, §12.3 environment protection, §12.7 artifact provenance; §14.1 layout; §16.3 recommendations; §16.4 `#1`,`#14`,`#17`,`#25` |
| `documents/Context/AGENTS.md` | Approved 2026-11-01 | §1 source-of-truth hierarchy; §3 bounded scope and reuse; §4A OWASP obligations; §7 open decisions |
| `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` | Approved | Not engaged by this task — no schema, migration, grant or policy work is performed |
| `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` | Approved | Not engaged by this task — no capability or permission is implemented |
| `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` | `Verified`, 2026-11-04 | §3 entry-gate verification; §5 decision closure; §8 blocker matrix; §11 signature |
| `documents/Task-Implementation/EP-00/EP-00-010 — Phase evidence pack and traceability index.md` | `Verified` for the index | §1 work-package evidence; §2 completion criteria C1–C14; §3 run index; §4 commit and tag evidence |
| `documents/Task-Implementation/EP-00/EP-00-011 — G5 phase closure record.md` | `Verified` — G5 signed 2026-11-07 | §1 closure decision; §3 dispositions; §4 accepted residual risks; §5 EP-01 entry conditions; §6 signature |
| `documents/Engineering-Execution/BRANCH_PROTECTION.md` | Implemented 2026-11-06 | §2 local pre-push control; §3 CI-side guard; §5 GitHub Free capability findings; §6 limitations; §8–§9 tests and evidence |
| `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` §13.3 `DEV-002` | Recorded 2026-11-07 | C8 acceptance; compensating controls; condition-based expiry; no G4 extension |

**Register ownership.** This record is not a decision register. Each settled decision must be folded
into the register that owns it (`QUA-38`, `QUA-39`). `ARCHITECTURE.md` §16.4 remains the single
consolidated list; `standards` §16 adds only what is new; deviations belong in `standards` §13.3
(`GOV-15`). The fold-in is a follow-up owned by the architect or founder — see §10.4.

---

## 3. Entry-gate verification

EP-01 §1 defines the entry gate as:

> EP-00 exit evidenced; managed Postgres provider decided (`ARCHITECTURE.md` §16.4 #1); hosting, DNS
> and TLS decided (#17); sign-in identifier decided (#14).

| # | Entry-gate condition | State | Evidence |
|---|---|---|---|
| 1 | EP-00 exit evidenced (its own exit gate and C1–C14) | **Met** | §3.1 below: G5 signed 2026-11-07 (`EP-00-011` §6); C8 accepted as `DEV-002`; C10 accepted as a recorded limitation; C14 met |
| 2 | Managed Postgres provider decided (`#1`) | **Not met** | `ARCHITECTURE.md` §16.4 `#1` — `[OPEN]`; no written decision supplied |
| 3 | Hosting, DNS and TLS decided (`#17`) | **Not met** | `ARCHITECTURE.md` §16.4 `#17` — `[OPEN]`; no written decision supplied |
| 4 | Sign-in identifier decided (`#14`) | **Not met** | `ARCHITECTURE.md` §16.4 `#14` — `[OPEN]`; no written decision supplied |

**Result.** The entry gate is **not met**. EP-00 has exited, but EP-01 does not open: `#1`, `#17` and
`#14` remain `PENDING`, and the second-reviewer arrangement and the G0 rulings are also outstanding.
See §9.


### 3.1 EP-00 exit verification — C1–C14

Every row was checked against an artifact on 2026-11-06 and dispositioned on 2026-11-07. Where a
command could not be re-executed in this environment, the row says so rather than presenting the
prior artifact as a fresh result.

| # | EP-00 criterion | Artifact inspected today | Result |
|---|---|---|---|
| **C1** | Entry gate satisfied and phase opened | `EP-00-ENTRY-RECORD.md` §3, §5, §11 (signed 2026-11-04; D-01–D-07) | **Met** |
| **C2** | Lockfile correct and frozen | `EP-00-010` §2 row C2; `evidence/clean-clone-install*.log`; lockfile SHA-256 `DAF9…7167` | **Met** — not re-executed: the pinned `pnpm` is unavailable locally (§4.3, R-P1) |
| **C3** | Toolchain enforced, not documented | `EP-00-010` §2 C3; `package.json` `packageManager`/`engines`; `scripts/version-parity.mjs`; CI `install` job | **Met in CI** — local parity failed today (§4.3, R-P1) |
| **C4** | Typecheck green and unsuppressed | `node node_modules/typescript/bin/tsc --noEmit` → exit 0, no output (today) | **Met** |
| **C5** | Test gate works | `vitest run` → 2 files, 18 tests passed (today); seeded failure run `42255635543` | **Met** |
| **C6** | Lint and format gate works | `node scripts/lint.mjs` → 20 baseline, 0 new, 0 stale (today); `App.tsx` diff empty | **Met** |
| **C7** | Pipeline blocks per stage | Six seeded-failure runs `42255323075`, `42255491891`, `42256095641`, `42255635543`, `42255596119`, `42256348422`; green run `42272912504` on `1abdbb5` | **Met** |
| **C8** | `main` is protected | `gh api …/branches/main/protection` → `403` "Upgrade to GitHub Pro or make this repository public…" (reproduced 2026-11-06); `BRANCH_PROTECTION.md` §5–§6; `standards` §13.3 `DEV-002` | **Accepted 2026-11-07** — not met; the founder accepted the gap as `DEV-002` with compensating controls and a condition-based expiry. This is not a claim that `main` is protected. |
| **C9** | Supply chain watched | `node scripts/secret-scan.mjs` → clean, 193 files (2026-11-06); CI `secret and dependency scan` job; `EP-00-010` C9 | **Met** — local/pre-push control, not provider-native scanning |
| **C10** | First commit exists and is tagged | Tag object `e6fcd38` → commit `8029466`; 103 files / 30,055 insertions; green run `42257026623` targets `1668c30`, not `8029466` | **Partially met — accepted 2026-11-07** — tag and SHA exact; the tag predates CI, so no run can exist on it without rewriting provenance |
| **C11** | A newcomer can work | `DEVELOPER_BOOTSTRAP.md`; `EP-00-010` C11 and clean-clone transcript | **Met** |
| **C12** | No visual, copy or behavioural change in the prototype | `git diff --stat v0.0.1-bootstrap..HEAD -- src/app/App.tsx` → empty; `git status` shows no tracked modification | **Met** |
| **C13** | Evidence complete | `EP-00-010` index; every row links an artifact or is marked unmet | **Met** |
| **C14** | Closure signed | `EP-00-011` §6 — signed by Prince Abidemi Oluwadamilare, founder and architect, 2026-11-07; status `Verified`, phase outcome `Closed` | **Met** |

**Result.** EP-00 **has exited** (G5 signed 2026-11-07): twelve criteria are met, C8 is accepted by
the recorded deviation `DEV-002`, and C10 is accepted as a recorded limitation. The local pre-push
hook and the CI `verify-pr` guard are a compensating control (`BRANCH_PROTECTION.md` §6), not
protection; neither this record nor `DEV-002` converts C8 into a pass.


### 3.2 What EES §7.3 means here

`EES §7.3`: a gate may be passed by deviation only, with a `GOV-13` record and an expiry; **a
deviation on G4 or on a `[FOUNDER]` decision is invalid**. G5 is a founder signature. It was signed
on 2026-11-07, so EP-00's exit is no longer an unsigned founder act. The C8 gap was not converted
into a pass by an agent: the founder accepted it as `DEV-002`, in `standards` §13.3, with an owner,
compensating controls, a condition-based expiry and no G4 extension.

That does not open EP-01. The phase-opening act is separate and remains `PENDING`, as do `#1`, `#17`,
`#14`, the second reviewer and the G0 rulings. `DEV-002` does not authorise EP-01 work, and it does
not make `main` protected.


---

## 4. Verified starting position

Re-verified on **2026-11-06** with read-only commands. Transcripts are in
`documents/Engineering-Execution/Engineering-Phase-Records/EP-01/evidence/`.

### 4.1 Commands and outputs

| Command | Output |
|---|---|
| `git log --oneline -20` | 20 commits; HEAD `1abdbb5` |
| `git rev-parse HEAD` | `1abdbb55b4113c2477f95ef1e13d1e9d7e578c91` |
| `git rev-parse v0.0.1-bootstrap` | `e6fcd389036615e6f02e04a8d60a020d2dcdba82` (tag object) |
| `git rev-parse 'v0.0.1-bootstrap^{}'` | `80294661ef138c8dc0aaa8b5098998d690deae3c` (commit) |
| `git show --stat --oneline v0.0.1-bootstrap` | 103 files changed, 30,055 insertions |
| `git diff --stat v0.0.1-bootstrap..HEAD -- src/app/App.tsx` | empty |
| `git branch -a` | local `main`; remotes `origin/main`, `origin/staging`, two dependabot branches |
| `git status --porcelain=v1` | `?? documents/Task-Implementation/EP-01/` only |
| `gh repo view … --json isPrivate,defaultBranchRef` | `isPrivate: true`, `defaultBranchRef: main` |
| `gh api …/branches/main/protection` | `403` upgrade message |
| `gh run list --limit 8` | green CI `42272912504` and guard `42272912469` on `1abdbb5` |
| `gh run view 42257026623` | success, `headSha` `1668c30` |
| `node node_modules/typescript/bin/tsc --noEmit` | exit 0 |
| `node node_modules/vitest/vitest.mjs run` | 2 files, 18 tests passed |
| `node scripts/lint.mjs` | 20 baseline, 0 new, 0 stale |
| `node scripts/secret-scan.mjs` | clean, 193 files |
| `node scripts/version-parity.mjs` | **FAILED** — `pnpm.cmd` not found |
| `node -v` | `v26.13.0` |

### 4.2 Verified facts

| Area | State on 2026-11-06 |
|---|---|
| Git history | 20 commits on `main`; merge-based flow `feature → staging → main` |
| Provenance | Annotated tag `v0.0.1-bootstrap` at root commit `8029466` |
| CI | `.github/workflows/ci.yml` — six jobs; green on current HEAD |
| Branch guard | `.github/workflows/branch-guard.yml` — green on current HEAD; local `.githooks/pre-push` |
| Deployments | `deploy-staging.yml` (gate only, no host), `deploy-production.yml` (manual, founder-gated) |
| Tests | Vitest 4.1.12; 2 files, 18 tests |
| Lint | ESLint gate with `.lint-baseline.json`, 20 entries, expiry 2026-12-31 |
| Secret scan | Local scanner over tracked files; clean |
| Toolchain | Pin: Node 22 / pnpm 10.34.9. Session: `mise` absent, global Node 26.13.0, no pnpm |
| Server / schema / auth | **Do not exist** — unchanged from the plan snapshot |
| EP-01 artifacts | `EP-01` was absent from `Engineering-Phase-Records/` before this task |

### 4.3 Drift from the EP-01 planning snapshot

The EP-01 plan opens with: *"The repository currently has **zero commits, no CI, no test runner, no
server, no schema and no authentication**; EP-00 has not exited."*

| Claim in the plan | State today | Effect on the plan |
|---|---|---|
| Zero commits | 20 commits; protected-flow history with merged PRs #14–#18 | Planning snapshot stale; recorded, plan not edited |
| No CI | Six-job pipeline plus branch guard and two deployment workflows, all present | Item `004` extends an existing pipeline rather than creating one |
| No test runner | Vitest installed; 18 tests across 2 files | Item `003` publishes contracts into an existing runner |
| No lint | ESLint gate with a reviewed baseline | Item `004` extends the existing gate |
| No branch model | `main`/`staging` with hook and CI guard (`BRANCH_PROTECTION.md`) | C8 remains unmet; accepted 2026-11-07 as `DEV-002`; the control is compensating only |
| No server, no schema, no authentication | Still true | Unchanged |
| EP-00 has not exited | **No longer true** — G5 signed 2026-11-07; C8 accepted as `DEV-002`; C10 limitation accepted; C14 met | The plan is not edited; EP-01 still stays `Blocked` on its own entry decisions |
| Toolchain available as pinned | `mise` missing; Node 26 on PATH; `pnpm` absent | New drift, R-P1; local build claims cannot be made |

**R-P1 in detail.** `scripts/version-parity.mjs` cannot resolve `pnpm.cmd`, and `mise` is not on
`PATH` although `%LOCALAPPDATA%\mise\shims` exists. The shims report `mise-shim: failed to execute
mise: program not found`. CI on Linux with the pinned versions remains the reference environment.
This must be restored before any item that requires a local build.

---

## 5. Decision closure

**Status key:** `RECORDED` = decision text, approver and date exist; `PENDING` = no decision exists
and no default has been adopted. In this version one decision was supplied in writing: the EP-00 exit
basis, recorded on 2026-11-07. Every other row remains `PENDING` with a named owner. Nothing below is a
recommendation.

| Owning ID | Decision | Owning register | Outcome | Class | Owner | Date | Evidence | Blocks | Follow-up |
|---|---|---|---|---|---|---|---|---|---|
| `#1` | Managed Postgres provider — Neon, Supabase or RDS | `ARCHITECTURE.md` §16.4 `#1` | `PENDING` | `[FOUNDER]` | Founder + architect | — | None supplied | `020`–`026`, `060`, `062` | Fold into §16.4 `#1` when decided |
| `#17` | Hosting platform, DNS provider, TLS issuance | `ARCHITECTURE.md` §16.4 `#17` | `PENDING` | `[FOUNDER]` | Founder + architect | — | None supplied | `041`, `054`, `060`, `063` | Fold into §16.4 `#17` |
| `#14` | Sign-in identifier — email-first, phone-first, or either | `ARCHITECTURE.md` §16.4 `#14` | `PENDING` | `[FOUNDER]` | Founder | — | None supplied | `031`, `032`, `053` | Fold into §16.4 `#14` |
| `EES §11.2 #2` / `DEV-001` | Second reviewer for EP-01 authentication, capability and migration changes — appoint, or re-deviate | `EES` §11.2 `#2`; `standards` §13.3 `DEV-001` | `PENDING` — `DEV-001` in force, time-boxed, not replaced. **Founder statement 2026-11-07: no second reviewer exists; the founder is the only person holding the architect and founder roles.** That is a statement of fact, not a decision, and it satisfies neither `QUA-29` nor `QUA-31` | `[FOUNDER]` | Founder + architect | — | `standards` §13.3 `DEV-001` (approved 2026-11-04); founder statement 2026-11-07 | `023`, `025`, `030`–`036` | Appointment is unavailable while no second person exists; the only remaining route is a complete `GOV-13` deviation with an owner and expiry; no G4 extension |
| EP-00 exit basis | Whether the recorded C8 compensating control, C10 partial and unsigned C14 are an accepted basis for opening EP-01, or EP-00 must complete first | This record §3; `EP-00-011` §6 | **`RECORDED`** — EP-00 closed 2026-11-07; G5 signed; C8 accepted as `DEV-002`; C10 limitation accepted; C14 met | `[FOUNDER]` | Founder | 2026-11-07 | `EP-00-011` §6; `standards` §13.3 `DEV-002`; `protection-403.log` | The phase status itself | Complete; `DEV-002` must be closed or renewed before EP-01 G5 |
| Phase opening | EP-01 opened for build | `EES` §5.2, §9.2 | `PENDING` | `[FOUNDER]` | Founder | — | None supplied | Every item | Signature in §11 |
| `standards #1` | Validation and client-data library — confirm the `zod` recommendation | `standards` §16 `#1` | `PENDING` | `[REVIEW]` | Architect | — | None supplied | `003`, `011` | Fold into `standards` §16 `#1` |
| `standards #2` | API versioning scheme | `standards` §16 `#2` | `PENDING` | `[REVIEW]` | Architect | — | None supplied | `011`, `013` | Fold into `standards` §16 `#2` |
| `standards #3` | Session lifetimes — absolute and idle, per audience | `standards` §16 `#3` | `PENDING` | `[FOUNDER]` + `[REVIEW]` | Founder + architect | — | None supplied | `032` | Fold into `standards` §16 `#3` |
| `standards #6` | CSP posture given `EX-02` — accept `style-src 'unsafe-inline'` until migration | `standards` §16 `#6`; §13.3 `EX-02` | `PENDING` | `[FOUNDER]` + `[REVIEW]` | Architect + founder | — | `EX-02` recorded | `041` | Fold into `standards` §16 `#6` |
| `standards #8` | Secret manager — provider choice and rotation mechanism | `standards` §16 `#8` | `PENDING` | `[FOUNDER]` + `[REVIEW]` | Founder + architect | — | None supplied | `020`, `043`, `060` | Fold into `standards` §16 `#8` |
| `standards #9` | Error-tracking and APM vendor, and whether it receives personal data | `standards` §16 `#9` | `PENDING` | `[FOUNDER]` | Founder | — | None supplied | `040` (the seam can ship with the no-op adapter) | Fold into `standards` §16 `#9` |
| `EX-10` residual | Test toolchain — Playwright, Testcontainers, Testing Library | `standards` §13.3 `EX-10`; `GOV-09` | `PENDING` | `[REVIEW]` via `GOV-09` | Architect | — | Ruling 2, 2026-11-04, leaves the residual open | `004`, `025`, `050`, `063` | Close `EX-10` when the residual lands |
| `EP-01 §4.3-R1` | "Five frontend bundles" — four bundles, five deployments | This record §6 | `PENDING` | `[REVIEW]` | Architect | — | None supplied | `002`, `054` | Recorded ruling text becomes the phase interpretation |
| `EP-01 §4.3-R2` | "Screens extracted without visual change" — slice-only extraction | This record §6 | `PENDING` | `[REVIEW]` | Architect | — | None supplied | `050`–`053` | Recorded ruling text becomes the phase interpretation |
| Technical selections | DB driver, migration runner, queue, OpenAPI generator, boundary lint | `EP-01` §9 `002` and `021` dependencies | `PENDING` | `[REVIEW]` | Architect | — | None supplied | `002`, `014`, `021` | Named in `002`'s G0 record when decided |

### 5.1 Deliberately not carried as entry blockers

> **Founder statement — 2026-11-07.** In the implementation session on 2026-11-07 the founder
> stated: *"there is no second reviewer for now, am the only one."* This is recorded as a fact, not
> as a decision. It means the second-reviewer row above cannot be cleared by appointment, and that
> the only remaining route is a `GOV-13` deviation approved by the founder with an owner and an
> expiry. It does not waive `QUA-29` or `QUA-31`, and it does not change the phase status.

Examined and excluded so scope does not expand: `standards` §16 `#4` (MFA policy — EP-01 builds
MFA-*ready schema* only, no MFA flow), `#5` (rate-limit thresholds — belongs to `042`), `#10` (log
and audit retention — no purge is built), `#16` (coverage gate — EP-02/EP-03 exit), `#17` (fonts),
and `ARCHITECTURE.md` §16.4 `#2`, `#6`, `#8` (funds custody, KYC tiers, currency — no money or KYC
code exists in EP-01).

---

## 6. G0 rulings

The EP-01 plan requires two scope interpretations to be ruled before work starts. Neither ruling has
been supplied in writing; both are recorded here as `PENDING` with the ruling text quoted verbatim.

### 6.1 Ruling R1 — bundle count

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Question, as written in EP-01 §4.3** | *"**"Five frontend bundles."** `ARCHITECTURE.md` §8.12 enumerates **four** bundles (`web`, `control`, `staff`, `partners`) and treats `staging` as a deployment target. This plan follows the architecture: **four bundles, five deployments**. The wording must be confirmed at G0."* |
| **Decided by** | Architect (`[REVIEW]`) |
| **Date** | — |
| **Effect of no ruling** | `002` and `054` cannot start; the bundle count stays ambiguous in the plan |
| **Evidence** | None supplied |

### 6.2 Ruling R2 — extraction scope

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Question, as written in EP-01 §4.3** | *"**"Screens extracted from `App.tsx` without visual change."** Extracting all 82 screens would be a rewrite and would violate bounded scope. This plan establishes the design package and extracts **only the screens and primitives the vertical slice uses**. Later phases extract on touch, as the architecture requires. The architect must confirm this reading at G0."* |
| **Decided by** | Architect (`[REVIEW]`) |
| **Date** | — |
| **Effect of no ruling** | `050`–`053` cannot start; the extraction boundary stays unconfirmed |
| **Evidence** | None supplied |

---

## 7. Second reviewer

**Status: `PENDING` — `DEV-001` is in force but time-boxed and not a substitute for the EP-01 arrangement.**

| Field | Content |
|---|---|
| **ID** | `DEV-001` |
| **Rule** | `QUA-29` (no self-merge) and `QUA-31` (two reviewers for CI configuration) |
| **Scope** | EP-00 CI configuration and review steps: `EP-00-006`, `EP-00-007`, `EP-00-008` |
| **Reason** | One-person team plus AI agents; no second human reviewer available |
| **Risk** | A CI defect or gate bypass could merge without second human review |
| **Compensating control** | Founder review of every diff; agent-assisted review checklist; seeded-failure proof for every gate; required status checks; no self-approval by the author; protection settings exported as evidence |
| **Owner** | Founder |
| **Expiry** | **Before EP-01 touches authentication, capability or migration code, and no later than 2026-12-31, whichever is earlier** |
| **G4** | Does **not** extend to G4 (production release) |
| **Filing** | `standards` §13.3 — filed 2026-11-04 |

### 7.1 Expiry test against this record's date

| Limb | Test on 2026-11-07 | Result |
|---|---|---|
| Date limb — no later than 2026-12-31 | 2026-11-07 < 2026-12-31 | Not yet reached |
| Scope limb — before EP-01 touches authentication, capability or migration code | EP-01 has not started; the first such item is `023` (identity schema), then `025`, `030`–`036` | **Binds at `023`** |

**Consequence.** `DEV-001` is still valid today, but it expires before `023`. Items `023`, `025` and
`030`–`036` are blocked until the founder appoints a reviewer or records a complete `GOV-13`
re-deviation for EP-01. No silent continuation is permitted, and no agent may act as the second
reviewer (`EES` §5.6, `AI-20`).

---

## 8. Item blocker matrix

Statuses use the `EES` §9.1 vocabulary only. All items are `Not started`; the phase itself is
`Blocked` (§9). No item may move to `Ready` until its own G0 record exists (`EES` §7.1, §8.2).

| Item | Name | Status | Blockers | Owner | Clearing condition |
|---|---|---|---|---|---|
| **002** | Workspace topology and package boundaries | `Not started` | Phase gate; `004`-independent but needs `002` selections; §4.3 R1 | Architect; developer | Phase opened; DB driver, migration runner, queue, OpenAPI generator, boundary lint recorded; R1 ruled |
| **003** | Shared contracts package | `Not started` | `002`; `standards #1` | Architect; developer | `002` verified; validation library decided |
| **004** | CI pipeline extension | `Not started` | `002`, `003`; `EX-10` residual | Architect; developer | `002`/`003` verified; test toolchain approved |
| **010** | API bootstrap and runtime configuration | `Not started` | `002`, `004` | Developer | Both verified |
| **011** | Common request pipeline and error contract | `Not started` | `010`; `standards #1`, `#2` | Architect; developer | `010` verified; validation and versioning decided |
| **012** | Ten-module boundary skeleton | `Not started` | `010`, `011` | Developer | Both verified |
| **013** | OpenAPI 3.1 contract and generated client | `Not started` | `010`, `011`, `012`; `standards #2` | Developer | All three verified; versioning decided |
| **014** | Worker, PostgreSQL queue and outbox | `Not started` | `012`, `024`; queue selection | Developer | Both verified; queue recorded |
| **020** | Managed PostgreSQL and environment configuration | `Not started` | Phase gate; `#1`, `standards #8` | Founder; architect | Provider and secret manager decided |
| **021** | Migration runner and baseline schemas | `Not started` | `020`; migration-runner selection | Architect; developer | `020` verified; runner recorded |
| **022** | Database roles, grants and default privileges | `Not started` | `021` | Developer | `021` verified |
| **023** | Identity schema | `Not started` | `021`, `022`; second reviewer (`DEV-001` scope limb) | Architect; developer | Prior items verified; reviewer appointed or re-deviated |
| **024** | Profile, activity and platform schema | `Not started` | `021`, `022` | Developer | Both verified |
| **025** | RLS pattern, identity context and policy tests | `Not started` | `022`, `023`, `024`; second reviewer; `EX-10` (Testcontainers) | Architect; developer | Prior items verified; reviewer settled; test toolchain approved |
| **026** | Repository and transaction foundation | `Not started` | `021`–`025` | Developer | All five verified |
| **030** | Identity domain and repositories | `Not started` | `023`, `026`; second reviewer | Architect; developer | Both verified; reviewer settled |
| **031** | Registration, credentials and account recovery | `Not started` | `030`; `#14`; delivery adapter | Founder; developer | `030` verified; sign-in identifier decided |
| **032** | Session lifecycle, audiences and session endpoint | `Not started` | `031`; `standards #3` | Founder; architect | `031` verified; lifetimes decided |
| **033** | Activity registry and activation state machine | `Not started` | `024`, `030` | Developer | Both verified |
| **034** | Capability computation engine | `Not started` | `033`; second reviewer | Architect; developer | `033` verified; reviewer settled |
| **035** | Service-layer enforcement and vertical-slice endpoints | `Not started` | `032`, `034`, `036` | Developer | All three verified |
| **036** | Audit logging service and immutability | `Not started` | `024`, `026`; second reviewer (migration review) | Architect; developer | Both verified; reviewer settled |
| **040** | Structured logging, correlation and error-tracking seam | `Not started` | `010`, `011`; `standards #9` (vendor optional — no-op adapter permitted) | Architect; developer | Prior items verified; vendor position recorded |
| **041** | Edge and origin security posture | `Not started` | `032`, `060`; `standards #6`; `#17` | Architect | Dependencies verified; CSP posture ruled |
| **042** | Authentication abuse controls | `Not started` | `032`; `standards #5` thresholds (recorded inside `042`) | Architect; developer | `032` verified; thresholds recorded |
| **043** | Secret management and configuration contract | `Not started` | `020`; `standards #8` | Founder; architect | Provider decided; secret manager decided |
| **050** | Visual regression baseline and harness | `Not started` | `004`; `EX-10` residual; §4.3 R2; founder baseline approval | Architect; developer | CI extended; toolchain approved; R2 ruled |
| **051** | Design tokens and primitive extraction for the slice | `Not started` | `050`, `002` | Developer | Both verified |
| **052** | Route manifest, router and providers | `Not started` | `003`, `013`, `050`, `051` | Developer | All four verified |
| **053** | Vertical-slice screens | `Not started` | `032`, `034`, `035`, `051`, `052` | Developer | All five verified |
| **054** | Four-bundle build and deployment targets | `Not started` | `002`, `052`; §4.3 R1; `#17` | Architect; developer | R1 ruled; dependencies verified |
| **060** | Environment topology and staging provisioning | `Not started` | `#17`, `#1`; `020`, `043` | Founder; architect | All four settled |
| **061** | Build-once artifact and promotion | `Not started` | `004`, `054`, `060` | Developer | All three verified |
| **062** | Migration application pipeline | `Not started` | `021`, `022`, `060`, `061`; `#1` | Architect; developer | All four verified |
| **063** | Staging smoke, E2E and gate wiring | `Not started` | `061`, `062`, `053`; `EX-10` (Playwright) | Developer | All three verified; Playwright approved |
| **070** | Phase evidence pack and traceability index | `Not started` | Every item `001`–`063` | Developer; architect | All prior items closed with artifacts |
| **071** | Phase-level security and quality review | `Not started` | `070`; second reviewer | Architect | `070` verified; reviewer settled |
| **072** | G5 phase closure record | `Not started` | `070`, `071`; architect recommendation | Founder; architect | Evidence complete; architect recommends closure |

**Notes.**

- `001` is this record. It is `In review`, not `Verified`.
- The critical path in EP-01 §6.2 begins `001 → 002 → 003 → 020 …`; with `001` `Blocked`, nothing
  after it can start.
- `040` can proceed with the no-op error-tracking adapter if the founder prefers to defer `#9`; the
  row is still gated by the phase.

---

## 9. Phase status determination

### 9.1 Checklist

The logic is the approved plan §6.3, applied line by line.

| Condition | State |
|---|---|
| EP-00 exit evidenced (G5 signed, C1–C14 met or accepted) | **Yes** — G5 signed 2026-11-07; C8 accepted as `DEV-002`; C10 accepted as a recorded limitation; C14 met |
| `#1` managed Postgres provider recorded | **No** — `PENDING` |
| `#17` hosting/DNS/TLS recorded | **No** — `PENDING` |
| `#14` sign-in identifier recorded | **No** — `PENDING` |
| Second reviewer settled for EP-01 | **No** — `DEV-001` in force, expires before `023` |
| §4.3 rulings R1 and R2 recorded | **No** — both `PENDING` |
| Local hook present but host protection absent | **Yes** — a compensating control only; accepted as `DEV-002`, does not satisfy C8 |
| Record drafted with `PENDING` rows | **Yes** — 15 of 16 pending; the EP-00 exit basis is `RECORDED` |

### 9.2 Result

**Phase status: `Blocked`.**

EP-00 has exited (G5 signed 2026-11-07). EP-01 does not open because its own entry conditions are
unmet. Per `EES` §9.2, `Blocked` is reachable from any state and returns to the state it left: EP-01
remains at `Not started` for every item, and this record is what explains why. EP-01 does not become
`In build`.

This is not a continuation of EP-00's blockers. C8, C10 and C14 are resolved for EP-00 through
`DEV-002`, the accepted limitation and the G5 signature. The remaining blockers belong to EP-01.

### 9.3 Missing items and owners

**Resolved on 2026-11-07 (EP-00):** the G5 signature (C14); the C8 acceptance via `DEV-002`; the C10
limitation; and the architect review of `EP-00-012`, `EP-00-013` and the CI configuration. These are
recorded in `EP-00-011` §3 and §6 and in `standards` §13.3.

| # | Missing | Owner | Clearing condition |
|---|---|---|---|
| 1 | `#1` managed Postgres provider | Founder + architect | Written decision; fold into §16.4 `#1` |
| 2 | `#17` hosting, DNS and TLS | Founder + architect | Written decision; fold into §16.4 `#17` |
| 3 | `#14` sign-in identifier | Founder | Written decision; fold into §16.4 `#14` |
| 4 | Second reviewer for EP-01 | Founder + architect | No second reviewer exists (founder statement, 2026-11-07), so appointment is unavailable. Clearing requires a complete `GOV-13` deviation with an owner and expiry; no G4 extension |
| 5 | `standards` §16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9` | Architect (+ founder where noted) | Written decisions; fold into `standards` §16 |
| 6 | `EX-10` residual — Playwright, Testcontainers, Testing Library | Architect | `GOV-09` approval recorded |
| 7 | §4.3 rulings R1 and R2 | Architect | Rulings recorded verbatim in this record §6 |
| 8 | Technical selections — DB driver, migration runner, queue, OpenAPI generator, boundary lint | Architect | Recorded, then consumed by `002`, `014`, `021` |
| 9 | Phase opening | Founder | Signature in §11 after items 1–8 are settled or explicitly accepted |

### 9.4 What this record does not do

- It did not exit EP-00 or sign G5; those acts are recorded in `EP-00-011` §6 on 2026-11-07. It does
  not claim that `main` is protected: C8 is accepted only as `DEV-002`.
- It does not resolve any `[OPEN]` decision or adopt any default.
- It does not open EP-01 for build, and it cannot: the phase-opening act is a founder signature.
- It does not create a database, API, worker, module, package, bundle, screen or configuration.
- It does not authorise deployment; no staging or production environment exists for EP-01.
- It does not build the evidence index (`070`) or the closure record (`072`).

---

## 10. Residual risks and carried conditions

### 10.1 Residual risks

| # | Risk | Impact | Owner | Handling |
|---|---|---|---|---|
| **R-P1** | Pinned toolchain unavailable locally: `mise` not on `PATH`, global Node 26.13.0, no `pnpm`; `scripts/version-parity.mjs` fails | Local build/parity claims cannot be made; "works on my machine" drift | Developer; architect | CI on Linux is the reference. Restore the pin before any item needing a local build. Do not lower a supply-chain control to compensate |
| **R-P2** | EP-00 exit needed a paid host capability or a visibility/host change that contradicts decision #18 | EP-01 could not open while EP-00 was unsigned | Founder | **Resolved 2026-11-07** — EP-00 closed through G5; C8 accepted as `DEV-002` in `standards` §13.3 with compensating controls and a condition-based expiry. Not a claim that `main` is protected |
| **R-P3** | `DEV-001` expires before `023` | Authentication, capability and migration changes would merge without a second reviewer | Founder + architect | Appoint a reviewer or record a new time-boxed deviation before `023` |
| **R-P4** | Two evidence roots exist (`Engineering-Phase-Records/EP-00/evidence/` and `Engineering-Execution/evidence/`) | `070` may index an inconsistent set | Architect | Recorded as a finding; `070` adopts one convention. Not fixed here |
| **R-P5** | Register fold-in conflicts with EP-01 §4.2, which forbids editing `ARCHITECTURE.md` | Settled decisions could live only in this record, creating a second source of truth | Architect + founder | Perform the fold-in as a separate recorded act (§10.4). Never edit the register from inside an EP-01 task |
| **R-P6** | C10 is permanently partial: the tag predates CI | A third party cannot see a green run on the tagged SHA | Architect | **Accepted 2026-11-07** as the recorded C10 limitation in `EP-00-011` §1 and §3; history and the tag are not rewritten |
| **R-P7** | Fifteen decisions are pending in one record | The entry record becomes the bottleneck for the whole phase | Founder + architect | Decide in the owner order in §9.3; each item unblocks on its own decision, not on the whole set |

### 10.2 Carried from EP-00 — do not rebuild

Repository history and tag; the branch model, local hook and CI guard; the six-job pipeline; the
toolchain contract and committed lockfile; the Vitest runner; the lint/format gate and baseline;
both scanning controls; the developer bootstrap; the evidence-index convention; the `EP-`
identifier convention.

### 10.3 Carried forward — EP-01 must add

Workspace topology and package boundaries; the ten-module skeleton; PostgreSQL and the migration
runner; Playwright, Testcontainers and Testing Library; the visual-regression baseline; the OpenAPI
diff stage; migration lint and `db diff`; staging topology; build-once artifact digests; and the
entry decisions this record lists as pending.

### 10.4 Conflicts and findings recorded, not resolved

1. **Register fold-in vs. scope guard.** `QUA-38`/`QUA-39` require a settled decision to be folded
   into its owning register; EP-01 §4.2 forbids editing `ARCHITECTURE.md`. Follow-up: the fold-in is
   performed by the architect or founder as a separate recorded act, following the `#18` →
   `§16.4 #25` precedent. An implementing agent must not edit the register inside an EP-01 task.
2. **Stale planning snapshot.** The EP-01 plan's "zero commits, no CI, no test runner" statement is
   no longer true. Recorded as drift in §4.3. The plan is not edited.
3. **Evidence-root divergence.** Two evidence roots exist. Recorded for `070`; not merged here.
4. **Toolchain drift.** Recorded as R-P1 with the failing command output.

### 10.5 Audit-readiness impact note (AR-0, `standards` §19.3)

| Field | Entry |
|---|---|
| **Change** | A governance record that records decisions and blocks a phase; no code, schema, API or configuration |
| **Trust boundaries touched** | None implemented. The record *authorises* future identity, authentication, authorisation, migration and audit work |
| **Data classes** | None processed. Governance identities only (approver names) |
| **Assets** | Repository decisions; no customer or financial data |
| **Requirement classes engaged** | `R3` (internal engineering controls) and `[OPEN]` for anything legal, regulatory or contractual — no obligation is asserted |
| **Audit events produced** | None at runtime; the record itself is the evidence artefact |
| **AR gate** | `AR-0` supports G0 |
| **Open R1/R2 questions** | None raised by this task. Retention, KYC applicability and data-protection scope remain `[OPEN]` in `standards` §16 and are not decided here |

### 10.6 Non-implementation statement

`EP-01-001` created no database, schema, migration, role, grant, RLS policy, API, endpoint, worker,
queue, package, bundle, screen, component, dependency or configuration. The only artifacts are this
record, its evidence transcripts and the approved plan and DoD that precede it.

---

## 11. Signature and amendment log

### 11.1 Approval block

| Role | Name | Decision | Scope of approval | Date |
|---|---|---|---|---|
| **Author** | AI implementation agent (drafting role) | Drafted and self-checked | Record text and evidence only; no decision approved | 2026-11-06 |
| **Architect / project technical owner** | — | **PENDING** | Fidelity, completeness, class and scope of *this record*; rulings R1–R2; §5 architect rows | — |
| **Founder** | — | **PENDING** | *This record*: `#1`, `#17`, `#14`, second reviewer, phase status, class `[FOUNDER]` | — |

**Separate act, not an approval of this record.** The founder signed EP-00's G5 on 2026-11-07
(`EP-00-011` §6) and accepted C8 as `DEV-002`. That closes EP-00 and settles the EP-00 exit basis
recorded in §5. It does **not** approve this record, does not open EP-01, and does not decide `#1`,
`#17`, `#14`, the second reviewer or the §4.3 G0 rulings.

**Signature limitation.** No signature of *this record* is recorded. This document must not be read
as an approval, a phase opening, or a claim that EP-01 is open. The author is an AI agent and cannot
hold an approver role (`EES` §5.6, `AI-20`). No independent second human reviewer exists: the founder
stated on 2026-11-07 that he is the only person holding the roles (§5.1). That statement is a fact,
not a waiver of `QUA-29` or `QUA-31`.

### 11.2 Amendment log

| Version | Date | Change | Author | Approval |
|---|---|---|---|---|
| **0.1** | 2026-11-06 | Initial draft. EP-00 exit re-verified; 16 decisions recorded as `PENDING` with owners; §4.3 rulings recorded as `PENDING`; 38-item blocker matrix; phase set to `Blocked`. No decision invented, no default adopted, no register edited. | AI implementation agent | None — draft only |
| **0.2** | 2026-11-06 | CI evidence attached. Commit `8210f98` pushed on `docs/ep-01-001-entry-record`; PR #19 opened into `staging`; CI run `42289296520` green on all six jobs. §11.3 E12 updated from "does not exist" to the recorded run and E13 added for the pull request. No decision outcome, status, blocker or signature changed. | AI implementation agent | None — draft only |
| **0.3** | 2026-11-07 | EP-00 G5 signed and `DEV-002` recorded; EP-00 exit basis moved to `RECORDED`; §3 criteria C8/C10/C14 dispositions updated; §3.2, §4.3, §5, §5.1, §9.1–§9.4, §10.1 and §11.1 re-issued; E12 refreshed, E14 and E15 added. The founder's 2026-11-07 statement that no second reviewer exists is recorded as fact, not as a waiver. EP-01 remains `Blocked` on `#1`, `#17`, `#14`, the second reviewer and the G0 rulings. No `[OPEN]` decision was settled and this record's own approvals remain `PENDING`. | AI implementation agent | None — draft only |

### 11.3 Evidence attached to this record

| # | Evidence | Path | State |
|---|---|---|---|
| E1 | Git history, tag, prototype integrity, working-tree position | `evidence/git-and-tag.log` | Recorded |
| E2 | Protection `403` reproduction and compensating-control limits | `evidence/protection-403.log` | Recorded |
| E3 | CI runs, including the EP-00 evidence run and current HEAD | `evidence/ci-runs.log` | Recorded |
| E4 | Local gates — typecheck, tests, lint, secret scan, toolchain parity failure | `evidence/local-gates.log` | Recorded |
| E5 | Seeded-failure proofs | `evidence/seeded-failures.log` | Recorded |
| E6 | Entry-gate verification (§3) | This record | Recorded |
| E7 | Decision register (§5) | This record | 1 of 16 `RECORDED`; 15 of 16 `PENDING` |
| E8 | Blocker matrix (§8) | This record | Complete for `002`–`072` |
| E9 | Phase-status determination (§9) | This record | `Blocked` |
| E10 | Architect review of *this record* | — | **Does not exist** |
| E11 | Founder signature of *this record* | — | **Does not exist** |
| E12 | CI run for this record's commits | PR #19 | **Recorded** — run `42340031780`, success, all six jobs, on commit `a7ddca3` (v0.3), branch `docs/ep-01-001-entry-record` into `staging`; earlier run `42289296520` green on `8210f98` (v0.2). Later evidence-only commits are covered by the same PR checks |
| E13 | Pull request for this record | [PR #19](https://github.com/Oludammy2030/Hivorr/pull/19) | **Open** — `MERGEABLE`; all six CI jobs green; no review decision recorded |
| E14 | EP-00 G5 signature and C8 acceptance | `EP-00-011` §6; `standards` §13.3 `DEV-002`; `EP-00-011` §3–§4 | **Recorded** — signed 2026-11-07 by Prince Abidemi Oluwadamilare (founder and architect roles, separately recorded); EP-00 closed; C10 limitation and residual risks R-1–R-6 accepted; R-3 resolved |
| E15 | Founder statement on the second reviewer | This record §5, §5.1, §9.3 | **Recorded** — 2026-11-07: no second reviewer exists; the founder is the only person holding the architect and founder roles. Recorded as fact; satisfies neither `QUA-29` nor `QUA-31` |

---

**Record version:** `0.3` — EP-00 G5 signed; C8 accepted via `DEV-002`.
**Record status:** `In review` — drafted and self-checked; this record's own architect review and founder signature remain `PENDING`.
**Phase status:** `Blocked` — nine items outstanding in §9.3, each with a named owner. EP-00 has exited; EP-01's own entry gate has not.
**Next action:** PR #19 is open into `staging` with green CI. `#1`, `#17`, `#14`, the second reviewer and the §4.3 G0 rulings remain `PENDING`. When §9.1 is fully satisfied, this record is re-issued as version `0.4` with the outcomes folded in and signed; only then may `002` start.
