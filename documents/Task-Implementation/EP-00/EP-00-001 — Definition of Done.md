# Task Definition of Done — EP-00-001
## Toolchain, lockfile and first commit

| Field | Value |
|---|---|
| **Task ID** | `EP-00-001` |
| **Task Name** | Toolchain, lockfile and first commit |
| **Related Phase** | `EP-00` — Execution Readiness |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-00/EP-00-001 — Toolchain, lockfile and first commit.md` |
| **Governing phase plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-00 — Execution Readiness.md` §9, `EP-00-001` |
| **Artifact under verification** | The repository state after `EP-00-001`: regenerated `pnpm-lock.yaml`, corrected `.gitignore` comment, first commit on `main`, annotated tag `v0.0.1-bootstrap`, and evidence `E1`–`E10` |
| **Change class** | `[REVIEW]` — architect approval required; founder not required (no dependency added, no vendor or infrastructure chosen, `minimumReleaseAge` untouched) |
| **Verification owner** | Project lead, with architect review |
| **Verification date** | ____________________ |
| **Overall result** | ☐ Pass  ☐ Fail  ☐ Pass with recorded deviation (`DEV-___`) |

**Verification boundary.** This DoD verifies only `EP-00-001`. It does not verify `EP-00-002`–`EP-00-011`, the toolchain contract (`packageManager`/`engines`), Vitest, the linter, CI, branch protection, scanning, the bootstrap document, the evidence index or phase closure. Those remain `Not started` or `Ready` per the phase record.

**Evidence rule.** A criterion without an inspectable artefact is unmet (`EES` §9.3). Where the approved plan names evidence `E1`–`E10`, this DoD verifies that artefact rather than accepting a status sentence.

**Approved evidence identifiers (do not renumber).**

| # | Artefact |
|---|---|
| **E1** | Clean-clone `pnpm install --frozen-lockfile` log |
| **E2** | Lockfile diff summary — four removals, five exact specifier corrections, two `@types` resolutions, and every ripple explicitly called out |
| **E3** | `pnpm typecheck` output, exit 0 |
| **E4** | `pnpm build` output, exit 0 |
| **E5** | `git check-ignore -v` output |
| **E6** | Commit SHA, `git show --stat v0.0.1-bootstrap`, and the tag in `git tag --list` |
| **E7** | Empty `git status --porcelain` after the commit |
| **E8** | Toolchain version proof — `mise`, `node`, `pnpm` |
| **E9** | Staged-content review — full staged path list and deny-pattern scan |
| **E10** | Before/after protected-file manifest (SHA-256) and the external lockfile backup |

---

## 0. Pre-conditions verified before approval

These are the four blockers the approved plan requires to be settled **before** work begins. If any is unresolved, the task is not verifiable and the result is `Fail`, regardless of the tree state.

| ID | Pre-condition | Pass condition | Evidence |
|---|---|---|---|
| **PC-01** | Platform path (finding F-01) | A written decision records **Option A** (Linux/WSL2), **B** (architect-approved `supportedArchitectures` amendment) or **C** (local `--force` with the parity gap recorded). No option was chosen silently | Decision note + the build evidence consistent with it |
| **PC-02** | Commit identity | `user.name` and `user.email` supplied by the founder/architect and set with `git config --local` only; no global change; no impersonation | `git config --local --get user.name/email`; `git log -1 --format='%an <%ae>'` |
| **PC-03** | Commit message and tag style | Message names `EP-00-001` and `Class: [REVIEW]`; tag is **annotated** | `git log -1 --format=%B`; `git cat-file -t v0.0.1-bootstrap` = `tag` |
| **PC-04** | Line-ending policy | Either (a) a recorded decision to defer to `EP-00-004` with the risk noted, or (b) an architect-approved `* text=auto eol=lf` addition **before** the first commit, recorded as a scope amendment | Decision note + `.gitattributes` state |

**Fail condition.** Any pre-condition marked "not applicable" without a written reason, or any option selected by the implementing agent rather than the architect/founder.

---

## 1. Functional Verification

### 1.1 Required functionality

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **F-01** | Toolchain matches the repository pin | `mise --version` = `2026.11.0`; `node -v` = `v22.23.4`; `pnpm -v` = `10.34.9`, all via the mise-managed toolchain | E8 |
| **F-02** | Toolchain is not silently substituted | No system-wide Node/pnpm was used; the version proof resolves through mise; no `sudo`, no global install | E8 + session transcript |
| **F-03** | Lockfile regenerated from exact pins, not hand-edited | `package.json` unchanged; the lockfile change is produced by `pnpm install`; re-running `pnpm install` produces no further diff | E2 + idempotence check |
| **F-04** | Importer parity is exact | Importer equals `package.json`: **53 dependencies + 9 devDependencies**, every specifier exact, **nothing extra** | E2 |
| **F-05** | The four stale entries are gone | `@emotion/react`, `@emotion/styled`, `@mui/icons-material`, `@mui/material` no longer appear in the importer | E2 |
| **F-06** | The five caret specifiers are exact | `@types/node` 22.20.5, `@types/react` 18.3.31, `@types/react-dom` 18.3.7, `oxfmt` 0.2.0, `typescript` 5.9.3 | E2 |
| **F-07** | Frozen install passes | `pnpm install --frozen-lockfile` exits 0 in the working tree **and** in a clean clone, with no lockfile mutation | E1 |
| **F-08** | Frozen install failed before the change | The pre-regeneration run fails with an outdated-lockfile/importer error and is retained | T1-before transcript |
| **F-09** | Typecheck is green and unsuppressed | `pnpm typecheck` exits 0; the diff adds no `@ts-ignore`, `@ts-expect-error`, `any` widening or `skipLibCheck` change | E3 + diff review |
| **F-10** | Build is green | `pnpm build` exits 0 via the unchanged `vite.figma.config.ts`; `dist/` is produced | E4 |
| **F-11** | Build output is ignored | `dist/` does not appear in `git status`; no build artefact is committed | E5, E7 |
| **F-12** | `.gitignore` stale comment is corrected | The "no version control yet (EX-12)" sentence is replaced; **no other ignore rule changed** | Diff review |
| **F-13** | Ignore rules are proven | `git check-ignore -v node_modules/ dist/ .env coverage/ .pnpm-store/` matches every path; `.env.example` is **negated**, not ignored | E5 |
| **F-14** | First commit exists | Exactly one commit exists on `main`; it is the repository's root commit | E6 |
| **F-15** | Tag exists and is correct | Annotated tag `v0.0.1-bootstrap` resolves to the commit SHA; `git rev-parse v0.0.1-bootstrap` equals `git rev-parse HEAD` | E6 |
| **F-16** | Working tree is clean | `git status --porcelain` is empty after the commit | E7 |
| **F-17** | No push occurred | `git remote -v` is empty; no branch was pushed; no CI run is claimed | Command output |
| **F-18** | Rollback exists | The pre-change `pnpm-lock.yaml` copy exists **outside** the working tree | E10 |
| **F-19** | Evidence is complete | E1–E10 exist, are linked, and contain no unlinked claim | Evidence index in progress (final index is `EP-00-010`) |

### 1.2 Expected workflows

| ID | Workflow | Pass condition |
|---|---|---|
| **W-01** | Pre-conditions → toolchain proof → backup/manifest → failure proof → install → diff review → frozen proof → typecheck → build | Each step has an artefact; the order matches approved plan §6.1 |
| **W-02** | Failure-first proof | The stale lockfile is shown failing **before** regeneration, then passing |
| **W-03** | Diff review before commit | The lockfile diff is reviewed against §6.2 of the plan before `git add`; the review is recorded in E2 |
| **W-04** | Staged-content review before commit | The staged list is inspected and scanned **before** the commit object is created |
| **W-05** | Clean-clone replay | A clone of the committed repository installs, typechecks and builds from the tag |
| **W-06** | Stop-and-report on out-of-budget change | Any unexpected transitive change halts the task; no silent acceptance |
| **W-07** | Rollback path | The documented rollback is executable and was confirmed, even if not exercised |

### 1.3 Success conditions

| ID | Condition | Pass condition |
|---|---|---|
| **S-01** | `EX-19` lockfile defect closed | Frozen install passes and importer parity is exact |
| **S-02** | Commit half of `EX-12` closed | Root commit exists and is tagged |
| **S-03** | `EP-00-002` is unblocked | A real installed tree and a committed lockfile exist to contract against |
| **S-04** | `EP-00-010` can index the task | Commit SHA, tag and E1–E10 are stable and inspectable |
| **S-05** | The base is reproducible | The clean-clone replay succeeds from the tag alone |
| **S-06** | No product change | No screen, token, copy, behaviour, schema or endpoint changed |
| **S-07** | No collateral asset | No new script, config, hook or dependency was introduced |

### 1.4 Error handling scenarios

| ID | Scenario | Required behaviour | Verify |
|---|---|---|---|
| **E-01** | Node/pnpm absent or wrong version | Stop before any install; report the resolved versions | E8, transcript |
| **E-02** | Registry unreachable | Stop; do not substitute a mirror or lower `minimumReleaseAge` | Transcript |
| **E-03** | `pnpm install` modifies `package.json` | Stop; restore it; report | `git diff` / SHA-256 |
| **E-04** | Lockfile change outside the approved budget | Stop and report the exact unexpected change; do not commit | E2 |
| **E-05** | Typecheck fails in `src/app/App.tsx` | Stop; do not edit the prototype; do not suppress; open a separate work package | E3 + report |
| **E-06** | Typecheck fails elsewhere | Fix only genuine, bounded errors; no suppression; otherwise stop | E3 + diff |
| **E-07** | Build fails on a missing native optional package (F-01) | Stop; apply the PC-01 decision; never silently change `pnpm-workspace.yaml` or use `--force` without approval | E4 + decision note |
| **E-08** | Commit identity unset | Stop; do not invent one | PC-02 |
| **E-09** | Secret-like content appears staged | Remove it before commit; never commit it; record the check | E9, T6 |
| **E-10** | A protected file changed | Revert or stop and report; no protected file may differ | E10, T8 |
| **E-11** | Tag created lightweight or on the wrong object | Delete and recreate as annotated on `HEAD`; record the correction | E6 |
| **E-12** | Rollback needed after the commit | `git tag -d` then `git update-ref -d HEAD`; the branch returns to unborn | Rollback transcript (if exercised) |

### 1.5 Important user interactions

| ID | Consumer | Pass condition |
|---|---|---|
| **U-01** | Project lead | Can confirm reproducibility, parity, typecheck, build, commit and tag from E1–E10 in one read |
| **U-02** | Architect reviewer | Can see that the lockfile diff contains only the approved budget and that `.gitignore` changed only in its comment |
| **U-03** | New developer | Can go from clone to green using only the documented `package.json` scripts |
| **U-04** | `EP-00-002` implementer | Has a stable installed tree and lockfile to add `packageManager`/`engines` against |
| **U-05** | `EP-00-010` evidence owner | Can index the task by SHA, tag and E1–E10 without reconstructing the work |
| **U-06** | Future maintainer | Can understand why the lockfile changed and what was deliberately excluded |

---

## 2. Technical Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **A-01** | Architecture compliance | No module, service, API, worker, database, schema, migration, queue, container, auth component or UI component was created or modified | Full file list + `git ls-tree -r --name-only HEAD` |
| **A-02** | Approved documents untouched | `documents/Context/*`, `AGENTS.md`, `CLAUDE.md`, the EP-00 and EP-01 phase plans, and `EP-00-000`'s record are byte-identical | E10 manifest |
| **A-03** | Prototype untouched | `src/app/App.tsx` is byte-identical | E10 manifest |
| **A-04** | Change surface is exactly two files | Only `pnpm-lock.yaml` and the `.gitignore` comment differ from the starting tree | E10 manifest + diff |
| **A-05** | Toolchain and workspace config unchanged | `.mise.toml`, `pnpm-workspace.yaml` (including `minimumReleaseAge: 10080` and `supportedArchitectures`), `tsconfig.json`, `vite.config.ts`, `vite.figma.config.ts` are byte-identical | E10 manifest |
| **A-06** | Dependency declarations unchanged | `package.json` is byte-identical; no dependency added, removed, upgraded, downgraded or deduplicated | E10 manifest |
| **A-07** | Lockfile integrity | `lockfileVersion` unchanged; no hand edit; no unexplained `settings` key; re-running install is idempotent | E2 + idempotence check |
| **A-08** | Commit is the complete reviewed tree | `git ls-tree -r --name-only HEAD` equals the reviewed allow-list; no `node_modules/`, `dist/`, `.env*`, logs or coverage | E6, E9 |
| **A-09** | Root commit only | `git rev-list --count HEAD` = `1`; no parent commit | E6 |
| **A-10** | Tag targets the reviewed commit | `git cat-file -t v0.0.1-bootstrap` = `tag`; peeled target equals `HEAD` | E6 |
| **A-11** | Build still uses the Figma wrapper | `package.json` `build` script unchanged (`vite build --config vite.figma.config.ts`); preview path intact (`ARCHITECTURE.md` §8.11) | A-06 + E4 |
| **A-12** | No tooling was invented | No new script, checker, hook or committed helper exists | File list |
| **A-13** | Platform decision is internally consistent | The PC-01 decision matches the build evidence: if the build only works on Linux, the evidence says so; if a config amendment occurred, it is approved and recorded | PC-01 + E4 |
| **A-14** | No CI claim | No workflow file, run URL or pipeline result is presented as evidence | Repository + evidence review |
| **A-15** | Evidence identifiers are stable | E1–E10 match the approved plan; no renumbering or parallel scheme | Evidence review |

---

## 3. Data Verification

Applicable in the artefact sense. No database exists and none is created; the "data" is the lockfile, the commit object and the evidence.

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **D-01** | Lockfile created/updated correctly | The regenerated lockfile is valid, installable and consistent with `package.json` | E1, E2 |
| **D-02** | Importer relationships are exact | 53 runtime + 9 dev entries under the single `.` importer; no extras, no omissions; `packages: ['.']` unchanged | E2 |
| **D-03** | Resolutions are accurate | `@types/react` 18.3.31 and `@types/react-dom` 18.3.7; React 18 line preserved; `@types/node` 22.20.5 | E2 |
| **D-04** | Diff data is complete | Every removed, corrected and rewritten entry is explained; no unexplained transitive version change | E2 |
| **D-05** | Data integrity | Before/after SHA-256 manifest matches for every protected file; lockfile backup exists outside the tree | E10 |
| **D-06** | Commit data is accurate | Commit SHA, author identity, message and staged list agree with the reviewed work | E6, E9 |
| **D-07** | No invented data | No evidence, timestamp, approval or dependency claim beyond what was produced | Evidence review |
| **D-08** | No database artefact | No table, schema, migration, grant, RLS policy or Supabase project was created | File list |
| **D-09** | Evidence is durable | E1–E10 exist outside transient terminal history (files, transcripts, hashes) and are readable by a third party | Evidence pack |

---

## 4. Security Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **SEC-01** | No secrets committed | No `.env*`, `*.pem`, `*.key`, credential, token or connection string in the commit or the evidence | E9 + secret-pattern scan |
| **SEC-02** | No token-bearing URLs | No URL with a token, signed parameter or embedded credential in logs or evidence | Evidence review |
| **SEC-03** | Supply chain preserved | Exact pins only; `minimumReleaseAge: 10080` untouched; no dependency added or upgraded; frozen install is the gate | A-05, A-06, E1 |
| **SEC-04** | No unreviewed transitive change | Every lockfile change is inside the approved budget and explained | E2 |
| **SEC-05** | Commit integrity | No `--no-verify`, no hook bypass, no force operation, no global git config change | Command transcript |
| **SEC-06** | Identity is not impersonated | Commit author matches the supplied governance identity; an agent did not invent one | PC-02, E6 |
| **SEC-07** | Agent boundary respected | The agent ran commands and produced evidence; it did not approve the diff, sign the task or decide the platform path | Approval record |
| **SEC-08** | Seeded fixture is non-live and removed | Any fake credential used to prove T6 was synthetic, outside the tree, deleted, and never committed | T6 transcript |
| **SEC-09** | Scanning residual is recorded | The absence of secret/vulnerability scanning is stated; scanning is `EP-00-008` | Task record |
| **SEC-10** | No privilege escalation | No `sudo`/elevation, no system-wide install, no environment variable weakening of a control | Transcript |
| **SEC-11** | Evidence redaction | Absolute user-home paths are redacted where evidence is attached | Evidence review |

---

## 5. Performance Verification

No runtime performance claim is made. The checks are about reproducibility cost and reviewability.

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **P-01** | No runtime impact | No shipped source changed; build succeeds; the preview path is unchanged | A-03, A-11, E4 |
| **P-02** | Baseline recorded | Install and build wall-clock are recorded as the first baseline for `EP-00-006` comparison | E4 + timing note |
| **P-03** | Failure is fast | The frozen-install check fails quickly before the slower typecheck/build steps | Transcript |
| **P-04** | Review is feasible | The lockfile review is mechanical and the hand-edited surface is one comment; the review is done in one sitting (`QUA-32`) | E2 + reviewer note |
| **P-05** | Clean-clone replay completes | The clone install/typecheck/build completes without timeout or manual repair | E1 |
| **P-06** | No performance regression claim | No benchmark or bundle-size claim is made beyond "builds and runs" | Evidence review |

---

## 6. Testing Verification

Manual execution only. No test runner exists at this point (`EP-00-003`), so unit tests are **not** expected and must not be demanded. Each check below must be capable of failing.

| ID | Test | Pass condition | Evidence |
|---|---|---|---|
| **TV-01** | T1 — frozen install, before and after | Fails before regeneration with an importer/outdated-lockfile error; exits 0 after, in the working tree and in a clean clone | T1 transcripts, E1 |
| **TV-02** | T2 — importer parity | 53 + 9 exact parity; **deny both ways**: a missing package and an extra package both fail the check; the pre-install lockfile demonstrates the failure | E2 |
| **TV-03** | T3 — typecheck | Exit 0 with output recorded; no suppression added | E3 |
| **TV-04** | T4 — build | Exit 0; `dist/` produced and ignored | E4, E5 |
| **TV-05** | T5 — ignore coverage | Every directory path matches with the trailing slash; `.env.example` is negated, not ignored; `node_modules/` absent from status after install | E5 |
| **TV-06** | T6 — staged content | Deny list clear; staged list equals the reviewed tree; a seeded non-live credential is flagged and removed before commit | E9 + seed transcript |
| **TV-07** | T7 — LFS safety | `git add` completes with no filter error; no unexpected binary tracked | Transcript |
| **TV-08** | T8 — protected files | Manifest matches; only the lockfile and `.gitignore` comment differ | E10 |
| **TV-09** | T9 — history integrity | One root commit; annotated tag on `HEAD`; `git show --stat` matches the staged list; clean tree | E6, E7 |
| **TV-10** | T10 — clean-clone replay | Frozen install, typecheck and build all exit 0 from the tag | E1 |
| **TV-11** | Seeded failure demonstrated | At least one gate was deliberately broken and detected: T1-before, T2-before or the T6 fixture; the transcript is retained | Seed note |
| **TV-12** | Edge cases exercised | (a) directory pattern without trailing slash does not match — the real command is used; (b) `.env.example` negation; (c) CRLF checkout under `core.autocrlf=true` does not produce a dirty tree; (d) missing/extra lockfile entry fails parity | Verification note |
| **TV-13** | Failure scenarios exercised | Each stop condition in plan §16 was considered; any that occurred produced a stop, not a workaround | Verification note |
| **TV-14** | No false automated claim | The record does not claim a CI run, scanner result or test suite that does not exist | Evidence review |
| **TV-15** | Idempotence | A second `pnpm install` produces no lockfile diff | Transcript |

---

## 7. User Acceptance Verification

| ID | Real-world check | Pass condition |
|---|---|---|
| **UA-01** | Project lead reproducibility check | From the tag alone, the lead can reproduce frozen install, typecheck and build |
| **UA-02** | Reviewer diff check | The architect confirms the diff is within the approved budget and the only hand edit is the `.gitignore` comment |
| **UA-03** | Newcomer check | A developer who did not do the work can follow the existing scripts without undocumented steps |
| **UA-04** | Downstream check | The `EP-00-002` owner confirms the installed tree and lockfile are usable as the base |
| **UA-05** | Evidence check | The `EP-00-010` owner confirms the SHA, tag and E1–E10 are indexable without rework |
| **UA-06** | No-surprise check | The file list contains nothing outside the reviewed tree; no unrelated cleanup, refactor or dependency change |
| **UA-07** | Platform check | The chosen platform path is documented, reproducible by a second person, and consistent with the build evidence |
| **UA-08** | Rollback check | The lead confirms the rollback procedure is correct and cheap, and that it was not needed or was correctly executed |

---

## 8. Final Approval Checklist

A single unchecked item blocks approval.

- [ ] **FA-01** PC-01 to PC-04 are settled in writing and match the evidence.
- [ ] **FA-02** All Functional checks F-01–F-19 pass.
- [ ] **FA-03** All workflow checks W-01–W-07 pass.
- [ ] **FA-04** All success conditions S-01–S-07 pass.
- [ ] **FA-05** All error scenarios E-01–E-12 were either not triggered or handled as required.
- [ ] **FA-06** All consumer checks U-01–U-06 pass.
- [ ] **FA-07** All Technical checks A-01–A-15 pass.
- [ ] **FA-08** All Data checks D-01–D-09 pass.
- [ ] **FA-09** All Security checks SEC-01–SEC-11 pass.
- [ ] **FA-10** All Performance checks P-01–P-06 pass.
- [ ] **FA-11** All Testing checks TV-01–TV-15 pass, including a demonstrated failure.
- [ ] **FA-12** All User Acceptance checks UA-01–UA-08 pass.
- [ ] **FA-13** `package.json`, `src/app/App.tsx`, `documents/Context/*`, the phase plans and `EP-00-000` are byte-identical.
- [ ] **FA-14** Only `pnpm-lock.yaml` and the `.gitignore` comment differ from the starting tree.
- [ ] **FA-15** Frozen install passes in a clean clone with no lockfile mutation.
- [ ] **FA-16** Typecheck and build are green with no suppression.
- [ ] **FA-17** The root commit exists and the annotated tag resolves to it; the tree is clean.
- [ ] **FA-18** No push, remote, CI, dependency addition or tooling addition occurred.
- [ ] **FA-19** E1–E10 exist and are linked; no claim exceeds its artefact.
- [ ] **FA-20** The task status is `In review` or `Verified` only on the evidence; the phase remains `In build`, and closure stays with `EP-00-010`/`011`.
- [ ] **FA-21** The architect's `[REVIEW]` approval is recorded; no agent approved its own work.
- [ ] **FA-22** The project lead has signed the approval record below.

### Mandatory stop conditions — do not approve if any is true

- The lockfile was hand-edited, or an unexplained transitive change was accepted.
- `package.json`, `App.tsx`, a governance document or a config changed.
- A type error was suppressed, an `any` widening was added, or `skipLibCheck` changed.
- The build only passes because of an unapproved `pnpm-workspace.yaml` change, `--force`, or a platform workaround that was not recorded.
- The commit contains a secret, `node_modules/`, `dist/`, a log or a local-only file.
- The tag is lightweight, missing, or points at a different commit.
- Evidence is a status sentence rather than a transcript, hash, SHA or command output.
- A CI run, test suite or scanner result is claimed where none exists.
- The commit identity was invented by an agent, or global git config was changed.
- The task was pushed, or a remote/CI was created ahead of `EP-00-005`.

---

## 9. Approval Record

| Field | Value |
|---|---|
| **Project lead** | ____________________ |
| **Decision** | ☐ Approved  ☐ Approved with deviation `DEV-___`  ☐ Rejected |
| **Conditions / notes** | ________________________________________________ |
| **Date** | ____________________ |
| **Next action** | ☐ Release `EP-00-002`  ☐ Return to `EP-00-001`  ☐ Hold |

---

This DoD is specific to `EP-00-001`. It verifies the reproducible base, the lockfile correction, the first commit and its tag, and the integrity of the surrounding tree — nothing from `EP-00-002` onward.
