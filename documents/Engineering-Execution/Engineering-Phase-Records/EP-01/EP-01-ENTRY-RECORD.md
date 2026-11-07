# EP-01 Entry Record — Entry gate closure and decision register

| Field | Value |
|---|---|
| **Document ID** | `EP-01-001` |
| **Phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Task name** | Entry gate closure and decision register |
| **Record version** | `0.5` — entry gate closed; EP-01 opened; `R-P1` resolved |
| **Record status** | `Approved` — architect review and founder signature recorded 2026-11-07 |
| **Phase status** | **`Ready`** — all nine §9.3 items settled or explicitly accepted |
| **Class** | `[FOUNDER]` |
| **Author** | AI implementation agent (drafting role) |
| **Date drafted** | 2026-11-06 |
| **Date updated** | 2026-11-07 |
| **Approvers** | Architect / project technical owner — Prince Abidemi Oluwadamilare, 2026-11-07; Founder — Prince Abidemi Oluwadamilare, 2026-11-07. The same person holds both roles; they are recorded separately (`EES` §5.1) |

> **What this record is.** It records the true starting position of EP-01, re-verifies EP-00's exit
> evidence criterion by criterion, lists every decision EP-01 depends on by reference to the register
> that owns it, and sets EP-01 to one status. It approves nothing, decides nothing, signs nothing and
> creates no runtime asset.
>
> **Update — 2026-11-07.** EP-00's G5 was signed by the founder on 2026-11-07. C8 is accepted as
> `DEV-002` in `standards` §13.3; C10 is accepted as a recorded limitation; C14 is met. EP-00 has
> therefore exited.
>
> **Update — 2026-11-07 (version 0.4).** Every EP-01 entry item is now recorded. The founder decided
> `#1` (Supabase, managed Postgres only), `#17` (Cloudflare edge, Fly.io API and worker) and `#14`
> (email-first); `standards` §16 `#1`, `#2`, `#3`, `#6`, `#8` and `#9` are decided; the `EX-10`
> residual is approved in full; rulings R1 and R2 are recorded; the five technical selections are
> named; and `DEV-003` records the second-reviewer position. The values are folded into
> `ARCHITECTURE.md` §16.4 and `standards` §16 as a separate act. **EP-01 is `Ready`.**


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
| **Signature state** | `SIGNED` — architect and founder roles approved 2026-11-07 (§11.1), recorded separately. No independent second reviewer exists; `DEV-003` records that position. |
| **Decision state** | 16 of 16 recorded — §5; no row remains `PENDING` |
| **Phase state** | `Ready` — see §9; the entry gate is met and the phase-opening signature is recorded |

---

## 2. Authority basis

This record relies on the following approved documents. Where a document and this record disagree,
the owning document wins and the conflict is recorded, not resolved (`GOV-05`).

| Document | Version / status | Sections relied on |
|---|---|---|
| `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` | Approved phase plan | §1 phase definition and entry gate; §4.2 out of scope; §4.3 scope readings; §5.2 module disposition; §7 dependencies; §9 items `001`–`072`; §12–§13 expected outcome and completion criteria |
| `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` | v2.0, approved 2026-11-04 | §5.1 roles, §5.2 decision rights, §5.6 AI boundaries; §7.1 G0–G5, §7.2 evidence, §7.3 gate exceptions; §8.1–§8.5 work-package protocol; §9.1–§9.3 status vocabulary and evidence rule; §10 ED-01–ED-10; §11.1–§11.2 open decisions |
| `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | v2.1, approved 2026-11-06; §13.3 `DEV-002` and `DEV-003` added 2026-11-07; §16 six rows decided 2026-11-07 | §1.4 governance classes; §1.5–§1.6 rule application and identifiers; §13.2 deviations; §13.3 accepted exceptions (`EX-02`, `EX-10`, `DEV-001`–`DEV-003`); §13.4 enforcement; §16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9`,`#16`; §19.3 AR-0 impact note; §19.2 requirement classes |
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
| 2 | Managed Postgres provider decided (`#1`) | **Met** | `ARCHITECTURE.md` §16.4 `#1` — **DECIDED 2026-11-07**: Supabase, managed Postgres only |
| 3 | Hosting, DNS and TLS decided (`#17`) | **Met** | `ARCHITECTURE.md` §16.4 `#17` — **DECIDED 2026-11-07**: Cloudflare edge, Fly.io API and worker |
| 4 | Sign-in identifier decided (`#14`) | **Met** | `ARCHITECTURE.md` §16.4 `#14` — **DECIDED 2026-11-07**: email-first |

**Result.** The entry gate is **met**. All nine §9.3 items are settled or explicitly accepted, and
the phase-opening signature is recorded in §11. EP-01 is `Ready`, and `002` may start.


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

That did not open EP-01 by itself. The phase-opening act is separate, and it is now recorded: `#1`,
`#17`, `#14`, the second reviewer (`DEV-003`) and the G0 rulings are settled, and §11.1 carries the
signature. `DEV-002` covers EP-00's exit only and does not make `main` protected.


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
| EP-00 has not exited | **No longer true** — G5 signed 2026-11-07; C8 accepted as `DEV-002`; C10 limitation accepted; C14 met | The plan is not edited; EP-01 opened on its own entry decisions 2026-11-07 |
| Toolchain available as pinned | Restored 2026-11-07: node 22.23.4, pnpm 10.34.9; parity OK | R-P1 resolved; `pnpm verify` exit 0 |

**R-P1 in detail — RESOLVED 2026-11-07.** `scripts/version-parity.mjs` could not resolve `pnpm.cmd`
because `%LOCALAPPDATA%\mise\bin` was not on the process `PATH`, so the shims could not find
`mise.exe` and `node` fell through to the global 26.13.0. The binary was present all along. With
`%LOCALAPPDATA%\mise\shims` and `%LOCALAPPDATA%\mise\bin` on the User `PATH`, the pin resolves:
`node 22.23.4`, `pnpm 10.34.9`, parity OK, and `pnpm verify` exits 0. Evidence:
`evidence/local-gates.log` §6. No repository change was needed; the fix is workstation configuration.
CI on Linux remains the shared reference environment.

---

## 5. Decision closure

**Status key:** `RECORDED` = decision text, approver and date exist; `PENDING` = no decision exists
and no default has been adopted. In this version every row is `RECORDED`: the EP-00 exit basis on
2026-11-07, and the fifteen EP-01 decisions on the founder's instruction of the same date. No row is
a recommendation, and no default was adopted without the founder's authorisation.

| Owning ID | Decision | Owning register | Outcome | Class | Owner | Date | Evidence | Blocks | Follow-up |
|---|---|---|---|---|---|---|---|---|---|
| `#1` | Managed Postgres provider — Neon, Supabase or RDS | `ARCHITECTURE.md` §16.4 `#1` | **`RECORDED`** — Supabase, managed Postgres only (Position A); Data API, Auth and Storage not used | `[FOUNDER]` | Founder + architect | 2026-11-07 | §16.4 `#1`; this record §5 | `020`–`026`, `060`, `062` | Folded into the register 2026-11-07 |
| `#17` | Hosting platform, DNS provider, TLS issuance | `ARCHITECTURE.md` §16.4 `#17` | **`RECORDED`** — Cloudflare for DNS, TLS and the edge (Pages); Fly.io for the API and worker; `/api/*` proxied same-origin at the edge | `[FOUNDER]` | Founder + architect | 2026-11-07 | §16.4 `#17`; this record §5 | `041`, `054`, `060`, `063` | Folded into the register 2026-11-07 |
| `#14` | Sign-in identifier — email-first, phone-first, or either | `ARCHITECTURE.md` §16.4 `#14` | **`RECORDED`** — email-first; email and password required at registration, phone optional until a phone-dependent action | `[FOUNDER]` | Founder | 2026-11-07 | §16.4 `#14`; §9.7; this record §5 | `031`, `032`, `053` | Folded into the register 2026-11-07 |
| `EES §11.2 #2` / `DEV-001` | Second reviewer for EP-01 authentication, capability and migration changes — appoint, or re-deviate | `EES` §11.2 `#2`; `standards` §13.3 `DEV-001`, `DEV-003` | **`RECORDED`** — `DEV-003` in force for EP-01 sensitive changes (auth, authorisation, session, identity, capability, migration, deployment, CI). Ends when a reviewer is appointed or at EP-01 `G5`, whichever is earlier; no `G4` extension. `DEV-001` keeps its own EP-00 scope and is not renewed | `[FOUNDER]` | Founder + architect | 2026-11-07 | `standards` §13.3 `DEV-003` | `023`, `025`, `030`–`036`, `041`, `043`, `060`, `063`, `071` | Re-review at `GOV-16` cycle; close at appointment or `G5` |
| EP-00 exit basis | Whether the recorded C8 compensating control, C10 partial and unsigned C14 are an accepted basis for opening EP-01, or EP-00 must complete first | This record §3; `EP-00-011` §6 | **`RECORDED`** — EP-00 closed 2026-11-07; G5 signed; C8 accepted as `DEV-002`; C10 limitation accepted; C14 met | `[FOUNDER]` | Founder | 2026-11-07 | `EP-00-011` §6; `standards` §13.3 `DEV-002`; `protection-403.log` | The phase status itself | Complete; `DEV-002` must be closed or renewed before EP-01 G5 |
| Phase opening | EP-01 opened for build | `EES` §5.2, §9.2 | **`RECORDED`** — opened 2026-11-07 | `[FOUNDER]` | Founder | 2026-11-07 | This record §11.1 | Every item | Complete; `002` may start |
| `standards #1` | Validation and client-data library — confirm the `zod` recommendation | `standards` §16 `#1` | **`RECORDED`** — `zod` and TanStack Query | `[REVIEW]` | Architect | 2026-11-07 | `standards` §16 `#1` | `003`, `011` | Folded into `standards` §16 |
| `standards #2` | API versioning scheme | `standards` §16 `#2` | **`RECORDED`** — additive-only within v1 | `[REVIEW]` | Architect | 2026-11-07 | `standards` §16 `#2` | `011`, `013` | Folded into `standards` §16 |
| `standards #3` | Session lifetimes — absolute and idle, per audience | `standards` §16 `#3` | **`RECORDED`** — public 12 h / 30 min idle; privileged 8 h / 15 min idle; re-authentication to start a privileged session | `[FOUNDER]` + `[REVIEW]` | Founder + architect | 2026-11-07 | `standards` §16 `#3` | `032` | Folded into `standards` §16 |
| `standards #6` | CSP posture given `EX-02` — accept `style-src 'unsafe-inline'` until migration | `standards` §16 `#6`; §13.3 `EX-01`, `EX-02` | **`RECORDED`** — accept `unsafe-inline` for styles until `EX-01` completes; `script-src` stays strict | `[FOUNDER]` + `[REVIEW]` | Architect + founder | 2026-11-07 | `standards` §16 `#6` | `041` | Folded into `standards` §16; `EX-02` remains |
| `standards #8` | Secret manager — provider choice and rotation mechanism | `standards` §16 `#8` | **`RECORDED`** — Doppler, per-environment scoping, recorded rotation, founder break-glass | `[FOUNDER]` + `[REVIEW]` | Founder + architect | 2026-11-07 | `standards` §16 `#8` | `020`, `043`, `060` | Folded into `standards` §16 |
| `standards #9` | Error-tracking and APM vendor, and whether it receives personal data | `standards` §16 `#9` | **`RECORDED`** — Sentry; no personal data; PII scrubbing verified before first use | `[FOUNDER]` | Founder | 2026-11-07 | `standards` §16 `#9` | `040` | Folded into `standards` §16 |
| `EX-10` residual | Test toolchain — Playwright, Testcontainers, Testing Library | `standards` §13.3 `EX-10`; `GOV-09` | **`RECORDED`** — ruling 3: the full residual is approved; the row closes when all three are installed and gated in CI | `[REVIEW]` via `GOV-09` | Architect | 2026-11-07 | `standards` §13.3 `EX-10` | `004`, `025`, `050`, `063` | Close `EX-10` when the residual lands |
| `EP-01 §4.3-R1` | "Five frontend bundles" — four bundles, five deployments | This record §6.1 | **`RECORDED`** — four bundles, five deployments | `[REVIEW]` | Architect | 2026-11-07 | This record §6.1 | `002`, `054` | Ruling text is the phase interpretation |
| `EP-01 §4.3-R2` | "Screens extracted without visual change" — slice-only extraction | This record §6.2 | **`RECORDED`** — slice-only extraction; later phases extract on touch | `[REVIEW]` | Architect | 2026-11-07 | This record §6.2 | `050`–`053` | Ruling text is the phase interpretation |
| Technical selections | DB driver, migration runner, queue, OpenAPI generator, boundary lint | `EP-01` §9 `002` and `021` dependencies | **`RECORDED`** — `pg`; Supabase CLI migrations; `graphile-worker`; `@nestjs/swagger`; `dependency-cruiser` | `[REVIEW]` | Architect | 2026-11-07 | This record §5 | `002`, `014`, `021` | Named in `002`'s G0 record |

### 5.1 Deliberately not carried as entry blockers

> **Founder statement — 2026-11-07.** In the implementation session on 2026-11-07 the founder
> stated: *"there is no second reviewer for now, am the only one."* This is recorded as a fact, not
> as a decision, and on its own it waives neither `QUA-29` nor `QUA-31`. The arrangement that does
> clear the row is `DEV-003`, approved by the founder on 2026-11-07 and recorded in `standards`
> §13.3. `DEV-003` is a time-boxed deviation with an owner, compensating controls and a condition-based
> expiry; it does not amend `QUA-29` or `QUA-31`, and it ends at the earlier of a reviewer appointment
> or the EP-01 `G5` signature, never at `G4`.

Examined and excluded so scope does not expand: `standards` §16 `#4` (MFA policy — EP-01 builds
MFA-*ready schema* only, no MFA flow), `#5` (rate-limit thresholds — belongs to `042`), `#10` (log
and audit retention — no purge is built), `#16` (coverage gate — EP-02/EP-03 exit), `#17` (fonts),
and `ARCHITECTURE.md` §16.4 `#2`, `#6`, `#8` (funds custody, KYC tiers, currency — no money or KYC
code exists in EP-01).

---

## 6. G0 rulings

The EP-01 plan requires two scope interpretations to be ruled before work starts. Both were ruled in
writing on 2026-11-07 and are recorded verbatim in §6.1 and §6.2.

### 6.1 Ruling R1 — bundle count

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Question, as written in EP-01 §4.3** | *"**"Five frontend bundles."** `ARCHITECTURE.md` §8.12 enumerates **four** bundles (`web`, `control`, `staff`, `partners`) and treats `staging` as a deployment target. This plan follows the architecture: **four bundles, five deployments**. The wording must be confirmed at G0."* |
| **Ruling** | *"Four bundles and five deployments. `ARCHITECTURE.md` §8.12 stands; the plan's wording is read as four bundles deployed to five targets, with `staging.` a deployment target and not a fifth bundle."* |
| **Decided by** | Architect (`[REVIEW]`) — Prince Abidemi Oluwadamilare |
| **Date** | 2026-11-07 |
| **Effect of no ruling** | `002` and `054` cannot start; the bundle count stays ambiguous in the plan |
| **Evidence** | This record; `ARCHITECTURE.md` §8.12, §16.3 #1 |

### 6.2 Ruling R2 — extraction scope

| Field | Value |
|---|---|
| **Status** | `RECORDED` |
| **Question, as written in EP-01 §4.3** | *"**"Screens extracted from `App.tsx` without visual change."** Extracting all 82 screens would be a rewrite and would violate bounded scope. This plan establishes the design package and extracts **only the screens and primitives the vertical slice uses**. Later phases extract on touch, as the architecture requires. The architect must confirm this reading at G0."* |
| **Ruling** | *"Slice-only extraction. EP-01 extracts the screens and primitives the vertical slice uses and no more; later phases extract on touch. Extracting all 82 screens in EP-01 would be a rewrite and is rejected."* |
| **Decided by** | Architect (`[REVIEW]`) — Prince Abidemi Oluwadamilare |
| **Date** | 2026-11-07 |
| **Effect of no ruling** | `050`–`053` cannot start; the extraction boundary stays unconfirmed |
| **Evidence** | This record; `AGENTS.md` §3 |

---

## 7. Second reviewer

**Status: `RECORDED` — `DEV-003` is in force for EP-01 sensitive changes.**

| Field | Content |
|---|---|
| **ID** | `DEV-003` |
| **Rule** | `QUA-29` (no self-merge) and `QUA-31` (two reviewers for authentication, authorisation, money, migrations, crypto, uploads, webhooks and CI configuration) |
| **Scope** | EP-01 pull requests that change authentication, authorisation, session handling, identity or capability computation, a schema migration, a deployment workflow or CI configuration — `023`, `025`, `030`–`036`, `041`, `043`, `060`, `063`, `071` |
| **Reason** | One-person team; the founder holds both the architect and founder roles; no second person exists; `QUA-31`'s two seats cannot both be filled |
| **Risk** | A sensitive change merges with one human review; no customer or financial data is exposed in EP-01 |
| **Compensating control** | Founder reads every diff against the `QUA-33` checklist; independent agent review recorded on each PR; seeded-failure proof per gate; full CI gates; branch guard; no self-approval; migration items pass the database-rules §9–§10 checklist and reach staging first |
| **Owner** | Prince Abidemi Oluwadamilare (Founder) |
| **Expiry** | Ends when a second reviewer is appointed, or when the EP-01 `G5` closure record is signed, whichever is earlier |
| **G4** | Does **not** extend to G4 (production release) |
| **Filing** | `standards` §13.3 — recorded 2026-11-07 |

`DEV-001` remains in `standards` §13.3 with its own EP-00 scope and its own expiry. It is not renewed
and not extended by `DEV-003` (`GOV-18`).

### 7.1 Expiry test against this record's date

| Limb | Test on 2026-11-07 | Result |
|---|---|---|
| `DEV-001` date limb — no later than 2026-12-31 | 2026-11-07 < 2026-12-31 | Not yet reached |
| `DEV-001` scope limb — before EP-01 touches authentication, capability or migration code | `023` is the first such item | **Would bind at `023`; superseded for EP-01 by `DEV-003`** |
| `DEV-003` scope limb — authentication, capability, migration, deployment or CI changes | Covers `023`, `025`, `030`–`036`, `041`, `043`, `060`, `063`, `071` | In force |
| `DEV-003` expiry — reviewer appointed or EP-01 `G5` signed | Neither has occurred | Not reached |

**Consequence.** `DEV-001` no longer gates EP-01: every item it would have bound is inside
`DEV-003`'s scope. No silent continuation is permitted, and no agent may act as the second reviewer
(`EES` §5.6, `AI-20`).

---

## 8. Item blocker matrix

Statuses use the `EES` §9.1 vocabulary only. All items are `Not started`; the phase is `Ready` (§9).
No item may move to `Ready` until its own G0 record exists (`EES` §7.1, §8.2).

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
| **023** | Identity schema | `Not started` | `021`, `022`; `DEV-003` | Architect; developer | Prior items verified; `DEV-003` in force |
| **024** | Profile, activity and platform schema | `Not started` | `021`, `022` | Developer | Both verified |
| **025** | RLS pattern, identity context and policy tests | `Not started` | `022`, `023`, `024`; `DEV-003`; `EX-10` (Testcontainers) | Architect; developer | Prior items verified; `DEV-003` in force; test toolchain approved |
| **026** | Repository and transaction foundation | `Not started` | `021`–`025` | Developer | All five verified |
| **030** | Identity domain and repositories | `Not started` | `023`, `026`; `DEV-003` | Architect; developer | Both verified; `DEV-003` in force |
| **031** | Registration, credentials and account recovery | `Not started` | `030`; `#14`; delivery adapter | Founder; developer | `030` verified; email-first recorded |
| **032** | Session lifecycle, audiences and session endpoint | `Not started` | `031`; `standards #3` | Founder; architect | `031` verified; lifetimes decided |
| **033** | Activity registry and activation state machine | `Not started` | `024`, `030` | Developer | Both verified |
| **034** | Capability computation engine | `Not started` | `033`; `DEV-003` | Architect; developer | `033` verified; `DEV-003` in force |
| **035** | Service-layer enforcement and vertical-slice endpoints | `Not started` | `032`, `034`, `036` | Developer | All three verified |
| **036** | Audit logging service and immutability | `Not started` | `024`, `026`; `DEV-003` (migration review) | Architect; developer | Both verified; `DEV-003` in force |
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
| **071** | Phase-level security and quality review | `Not started` | `070`; `DEV-003` | Architect | `070` verified; `DEV-003` in force |
| **072** | G5 phase closure record | `Not started` | `070`, `071`; architect recommendation | Founder; architect | Evidence complete; architect recommends closure |

**Notes.**

- `001` is this record. It is `Approved` at version `0.4`, and it is not the phase-closure record.
- The critical path in EP-01 §6.2 begins `001 → 002 → 003 → 020 …`; `001` is `Ready`, so `002` may
  start.
- `040` no longer needs the no-op adapter: `standards` §16 `#9` records Sentry with PII scrubbing
  before first use. The no-op adapter remains a permitted seam, not the decision.

---

## 9. Phase status determination

### 9.1 Checklist

The logic is the approved plan §6.3, applied line by line.

| Condition | State |
|---|---|
| EP-00 exit evidenced (G5 signed, C1–C14 met or accepted) | **Yes** — G5 signed 2026-11-07; C8 accepted as `DEV-002`; C10 accepted as a recorded limitation; C14 met |
| `#1` managed Postgres provider recorded | **Yes** — Supabase, managed Postgres only |
| `#17` hosting/DNS/TLS recorded | **Yes** — Cloudflare edge, Fly.io API and worker |
| `#14` sign-in identifier recorded | **Yes** — email-first |
| Second reviewer settled for EP-01 | **Yes** — `DEV-003` recorded in `standards` §13.3, with owner and expiry |
| `standards` §16 `#1`, `#2`, `#3`, `#6`, `#8`, `#9` recorded | **Yes** — all six decided |
| `EX-10` residual approved | **Yes** — ruling 3: Playwright, Testcontainers, Testing Library |
| §4.3 rulings R1 and R2 recorded | **Yes** — §6.1 and §6.2 |
| Technical selections recorded | **Yes** — `pg`, Supabase CLI, `graphile-worker`, `@nestjs/swagger`, `dependency-cruiser` |
| Local hook present but host protection absent | **Yes** — a compensating control only; accepted as `DEV-002`, does not satisfy C8 |
| Record re-issued with outcomes folded in | **Yes** — version `0.4` |
| Phase-opening signature | **Yes** — §11.1, 2026-11-07 |

### 9.2 Result

**Phase status: `Ready`.**

All nine items in §9.3 are settled or explicitly accepted, and the phase-opening signature is
recorded in §11.1. Per `EES` §9.1, `Ready` means the phase's entry conditions are met and work may
start; `002` is the first item.

Two limits remain, recorded rather than hidden: `DEV-002` (host protection) and `DEV-003` (second
reviewer) are both time-boxed and both end at the EP-01 `G5` closure record or earlier. Neither
extends to `G4`, which has no deviation path.

This is not a continuation of EP-00's blockers. C8, C10 and C14 are resolved for EP-00 through
`DEV-002`, the accepted limitation and the G5 signature. The remaining blockers belong to EP-01.

### 9.3 Missing items and owners

**Resolved on 2026-11-07 (EP-00):** the G5 signature (C14); the C8 acceptance via `DEV-002`; the C10
limitation; and the architect review of `EP-00-012`, `EP-00-013` and the CI configuration. These are
recorded in `EP-00-011` §3 and §6 and in `standards` §13.3.

**Resolved on 2026-11-07 (EP-01), on the founder's instruction:** all nine rows below. Each is
recorded in the section named in the last column.

| # | Item | Owner | State | Where recorded |
|---|---|---|---|---|
| 1 | `#1` managed Postgres provider | Founder + architect | **Settled** — Supabase, managed Postgres only | §5; `ARCHITECTURE.md` §16.4 `#1` |
| 2 | `#17` hosting, DNS and TLS | Founder + architect | **Settled** — Cloudflare edge; Fly.io API and worker | §5; `ARCHITECTURE.md` §16.4 `#17` |
| 3 | `#14` sign-in identifier | Founder | **Settled** — email-first | §5; `ARCHITECTURE.md` §16.4 `#14`, §9.7 |
| 4 | Second reviewer for EP-01 | Founder + architect | **Settled by deviation** — `DEV-003`; ends at appointment or EP-01 `G5` | §5, §7; `standards` §13.3 |
| 5 | `standards` §16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9` | Architect (+ founder where noted) | **Settled** — all six decided | §5; `standards` §16 |
| 6 | `EX-10` residual — Playwright, Testcontainers, Testing Library | Architect | **Approved in full** — ruling 3 | §5; `standards` §13.3 `EX-10` |
| 7 | §4.3 rulings R1 and R2 | Architect | **Recorded** — four bundles/five deployments; slice-only extraction | §6.1, §6.2 |
| 8 | Technical selections — DB driver, migration runner, queue, OpenAPI generator, boundary lint | Architect | **Recorded** — `pg`; Supabase CLI; `graphile-worker`; `@nestjs/swagger`; `dependency-cruiser` | §5 |
| 9 | Phase opening | Founder | **Signed** — 2026-11-07 | §11.1 |

### 9.4 What this record does not do

- It did not exit EP-00 or sign G5; those acts are recorded in `EP-00-011` §6 on 2026-11-07. It does
  not claim that `main` is protected: C8 is accepted only as `DEV-002`.
- It records the decisions listed in §5 and adopts no default that the founder did not authorise.
- It opens EP-01 for build: the phase-opening signature is recorded in §11.1 on 2026-11-07.
- It does not create a database, API, worker, module, package, bundle, screen or configuration.
- It does not authorise deployment; no staging or production environment exists for EP-01.
- It does not build the evidence index (`070`) or the closure record (`072`).

---

## 10. Residual risks and carried conditions

### 10.1 Residual risks

| # | Risk | Impact | Owner | Handling |
|---|---|---|---|---|
| **R-P1** | Pinned toolchain unavailable locally: `mise` not on `PATH`, global Node 26.13.0, no `pnpm`; `scripts/version-parity.mjs` fails | Local build/parity claims cannot be made; "works on my machine" drift | Developer; architect | **Resolved 2026-11-07** — `%LOCALAPPDATA%\mise\shims` and `mise\bin` added to the User `PATH`; node 22.23.4 and pnpm 10.34.9 resolve; parity OK; `pnpm verify` exit 0 (`evidence/local-gates.log` §6). No repository change; CI on Linux remains the reference |
| **R-P2** | EP-00 exit needed a paid host capability or a visibility/host change that contradicts decision #18 | EP-01 could not open while EP-00 was unsigned | Founder | **Resolved 2026-11-07** — EP-00 closed through G5; C8 accepted as `DEV-002` in `standards` §13.3 with compensating controls and a condition-based expiry. Not a claim that `main` is protected |
| **R-P3** | `DEV-001` expires before `023` | Authentication, capability and migration changes would merge without a second reviewer | Founder + architect | **Resolved 2026-11-07** — `DEV-003` recorded in `standards` §13.3 and covers every item `DEV-001` would have bound. Re-review at each `GOV-16` cycle; close at appointment or EP-01 `G5` |
| **R-P4** | Two evidence roots exist (`Engineering-Phase-Records/EP-00/evidence/` and `Engineering-Execution/evidence/`) | `070` may index an inconsistent set | Architect | Recorded as a finding; `070` adopts one convention. Not fixed here |
| **R-P5** | Register fold-in conflicts with EP-01 §4.2, which forbids editing `ARCHITECTURE.md` | Settled decisions could live only in this record, creating a second source of truth | Architect + founder | **Resolved 2026-11-07** — the fold-in was performed as a separate recorded act under §10.4: `ARCHITECTURE.md` §16.4 `#1`, `#14`, `#17` and §9.7 were updated, with a §16.6 changelog entry |
| **R-P6** | C10 is permanently partial: the tag predates CI | A third party cannot see a green run on the tagged SHA | Architect | **Accepted 2026-11-07** as the recorded C10 limitation in `EP-00-011` §1 and §3; history and the tag are not rewritten |
| **R-P7** | Fifteen decisions were pending in one record | The entry record becomes the bottleneck for the whole phase | Founder + architect | **Resolved 2026-11-07** — all sixteen rows in §5 are `RECORDED` |

### 10.2 Carried from EP-00 — do not rebuild

Repository history and tag; the branch model, local hook and CI guard; the six-job pipeline; the
toolchain contract and committed lockfile; the Vitest runner; the lint/format gate and baseline;
both scanning controls; the developer bootstrap; the evidence-index convention; the `EP-`
identifier convention.

### 10.3 Carried forward — EP-01 must add

Workspace topology and package boundaries; the ten-module skeleton; PostgreSQL and the migration
runner; Playwright, Testcontainers and Testing Library; the visual-regression baseline; the OpenAPI
diff stage; migration lint and `db diff`; staging topology; build-once artifact digests. The entry
decisions this record listed as pending are recorded in §5.

### 10.4 Conflicts and findings recorded, not resolved

1. **Register fold-in vs. scope guard.** `QUA-38`/`QUA-39` require a settled decision to be folded
   into its owning register; EP-01 §4.2 forbids editing `ARCHITECTURE.md`. **Resolved 2026-11-07:**
   the fold-in was performed as a separate recorded act, following the `#18` → `§16.4 #25`
   precedent — `ARCHITECTURE.md` §16.4 `#1`, `#14`, `#17` and §9.7 updated, with a §16.6 entry.
2. **Stale planning snapshot.** The EP-01 plan's "zero commits, no CI, no test runner" statement is
   no longer true. Recorded as drift in §4.3. The plan is not edited.
3. **Evidence-root divergence.** Two evidence roots exist. Recorded for `070`; not merged here.
4. **Toolchain drift.** Recorded as R-P1 with the failing command output.

### 10.5 Audit-readiness impact note (AR-0, `standards` §19.3)

| Field | Entry |
|---|---|
| **Change** | A governance record that records decisions and opens a phase; no code, schema, API or configuration |
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
| **Architect / project technical owner** | Prince Abidemi Oluwadamilare | **Approved** | Fidelity, completeness, class and scope of *this record*; rulings R1–R2; §5 architect rows; technical selections | 2026-11-07 |
| **Founder** | Prince Abidemi Oluwadamilare | **Approved — phase opened** | *This record*: `#1`, `#17`, `#14`, second reviewer, phase status, class `[FOUNDER]` | 2026-11-07 |

**Role separation.** The architect and founder decisions are recorded separately although one person
holds both roles (`EES` §5.1). Recording them separately keeps the decision-rights table meaningful;
it does not create an independent second reviewer, and it does not satisfy `QUA-29` or `QUA-31` — that
is what `DEV-003` records.

**Basis of the signature.** The founder approved the entry decisions on 2026-11-07 with the
instruction to settle everything required to open EP-01 without a second reviewer and without a
later block. The options recorded in §5 are the ones put to the founder in `EP-01-DECISION-PACK.md`;
the pack is a working document and does not itself decide anything.

**Signature limitation.** This record is signed by the founder in both governance roles. The author
is an AI agent and cannot hold an approver role (`EES` §5.6, `AI-20`). No independent second human
reviewer exists; `DEV-003` records that position, with an owner, compensating controls and an expiry,
and it does not amend `QUA-29` or `QUA-31`.

### 11.2 Amendment log

| Version | Date | Change | Author | Approval |
|---|---|---|---|---|
| **0.1** | 2026-11-06 | Initial draft. EP-00 exit re-verified; 16 decisions recorded as `PENDING` with owners; §4.3 rulings recorded as `PENDING`; 38-item blocker matrix; phase set to `Blocked`. No decision invented, no default adopted, no register edited. | AI implementation agent | None — draft only |
| **0.2** | 2026-11-06 | CI evidence attached. Commit `8210f98` pushed on `docs/ep-01-001-entry-record`; PR #19 opened into `staging`; CI run `42289296520` green on all six jobs. §11.3 E12 updated from "does not exist" to the recorded run and E13 added for the pull request. No decision outcome, status, blocker or signature changed. | AI implementation agent | None — draft only |
| **0.3** | 2026-11-07 | EP-00 G5 signed and `DEV-002` recorded; EP-00 exit basis moved to `RECORDED`; §3 criteria C8/C10/C14 dispositions updated; §3.2, §4.3, §5, §5.1, §9.1–§9.4, §10.1 and §11.1 re-issued; E12 refreshed, E14 and E15 added. The founder's 2026-11-07 statement that no second reviewer exists is recorded as fact, not as a waiver. EP-01 remains `Blocked` on `#1`, `#17`, `#14`, the second reviewer and the G0 rulings. No `[OPEN]` decision was settled and this record's own approvals remain `PENDING`. | AI implementation agent | None — draft only |
| **0.4** | 2026-11-07 | Entry gate closed on the founder's instruction. `DEV-003` recorded; `#1` (Supabase), `#17` (Cloudflare/Fly.io) and `#14` (email-first) decided; six `standards` §16 rows decided; `EX-10` residual approved in full; rulings R1 and R2 recorded; five technical selections named. §3, §5, §5.1, §6, §7, §9.1–§9.4, §10.1, §10.3–§10.5 and §11 re-issued. Register fold-in performed as a separate act. Phase status `Ready`; `002` may start. | AI implementation agent | Founder, 2026-11-07 §11.1 |
| **0.5** | 2026-11-07 | Factual amendment: `R-P1` resolved. The pinned toolchain was restored on the workstation by adding `%LOCALAPPDATA%\mise\shims` and `mise\bin` to the User `PATH`; node 22.23.4 and pnpm 10.34.9 now resolve, parity passes and `pnpm verify` exits 0. §4.3 and §10.1 updated; E19 added; `evidence/local-gates.log` §6 records the run. No decision changed, no rule changed meaning, no register edited, and the phase status is unchanged. | AI implementation agent | Founder instruction 2026-11-07 (“fix it”); no decision re-signed |

### 11.3 Evidence attached to this record

| # | Evidence | Path | State |
|---|---|---|---|
| E1 | Git history, tag, prototype integrity, working-tree position | `evidence/git-and-tag.log` | Recorded |
| E2 | Protection `403` reproduction and compensating-control limits | `evidence/protection-403.log` | Recorded |
| E3 | CI runs, including the EP-00 evidence run and current HEAD | `evidence/ci-runs.log` | Recorded |
| E4 | Local gates — typecheck, tests, lint, secret scan, toolchain parity failure | `evidence/local-gates.log` | Recorded |
| E5 | Seeded-failure proofs | `evidence/seeded-failures.log` | Recorded |
| E6 | Entry-gate verification (§3) | This record | Recorded |
| E7 | Decision register (§5) | This record | 16 of 16 `RECORDED`; none `PENDING` |
| E8 | Blocker matrix (§8) | This record | Complete for `002`–`072` |
| E9 | Phase-status determination (§9) | This record | `Ready` |
| E10 | Architect review of *this record* | This record §11.1 | **Recorded** — approved 2026-11-07 by Prince Abidemi Oluwadamilare |
| E11 | Founder signature of *this record* | This record §11.1 | **Recorded** — 2026-11-07; phase opened |
| E12 | CI run for this record's commits | PR #19 | **Recorded** — run `42340031780`, success, all six jobs, on commit `a7ddca3` (v0.3), branch `docs/ep-01-001-entry-record` into `staging`; earlier run `42289296520` green on `8210f98` (v0.2). Later evidence-only commits are covered by the same PR checks |
| E13 | Pull request for this record | [PR #19](https://github.com/Oludammy2030/Hivorr/pull/19); [PR #22](https://github.com/Oludammy2030/Hivorr/pull/22) | **Merged** — PR #19 into `staging` (merge commit `e129a2b`), PR #22 into `main` (merge commit `3034c83`); CI green on both |
| E14 | EP-00 G5 signature and C8 acceptance | `EP-00-011` §6; `standards` §13.3 `DEV-002`; `EP-00-011` §3–§4 | **Recorded** — signed 2026-11-07 by Prince Abidemi Oluwadamilare (founder and architect roles, separately recorded); EP-00 closed; C10 limitation and residual risks R-1–R-6 accepted; R-3 resolved |
| E15 | Founder statement on the second reviewer | This record §5, §5.1, §9.3 | **Recorded** — 2026-11-07: no second reviewer exists; the founder is the only person holding the architect and founder roles. Recorded as fact; satisfies neither `QUA-29` nor `QUA-31` |
| E16 | `DEV-003` — second-reviewer deviation for EP-01 | `standards` §13.3 | **Recorded** — approved 2026-11-07; owner, compensating controls and condition-based expiry stated; ends at reviewer appointment or EP-01 `G5`; no `G4` extension |
| E17 | Register fold-in | `ARCHITECTURE.md` §16.4 `#1`, `#14`, `#17`, §9.7, §16.6 | **Recorded** — separate act, 2026-11-07, with a changelog entry |
| E18 | This record's own approval | This record §11.1 | **Recorded** — architect and founder roles approved 2026-11-07 by Prince Abidemi Oluwadamilare, recorded separately; no independent second reviewer |
| E19 | Local pinned toolchain restored | `evidence/local-gates.log` §6 | **Recorded** — 2026-11-07: node 22.23.4, pnpm 10.34.9, parity OK, `pnpm verify` exit 0 |

---

**Record version:** `0.5` — entry gate closed; EP-01 opened; `R-P1` resolved.
**Record status:** `Approved` — architect and founder approvals recorded 2026-11-07 in §11.1.
**Phase status:** **`Ready`** — all nine §9.3 items settled or explicitly accepted.
**Next action:** `002` may start. `DEV-002` and `DEV-003` remain in force and both end at the EP-01 `G5` closure record or earlier; neither extends to `G4`. The pinned toolchain resolves locally as of 2026-11-07 (`pnpm verify` exit 0); CI on Linux remains the shared reference.
