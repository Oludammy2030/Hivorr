# Task Implementation Plan — EP-00-001
## Toolchain, lockfile and first commit

> Planning artifact only. No repository file was created or modified. The approved Phase document is unchanged.

---

### 0. Verified starting position (inspected today, 4 November 2026)

| Fact | Verified state |
|---|---|
| Git | `.git` exists; branch `main`; **zero commits**; no remote; no tags |
| Working tree | **99 untracked files** across 19 top-level entries; nothing tracked; nothing staged |
| Toolchain | `mise 2026.11.0` at `%LOCALAPPDATA%\mise\mise\bin\mise.exe`; `node v22.23.4`; `pnpm 10.34.9` via `mise exec`. **None on `PATH`**; the mise shims fail until `mise` is on `PATH` |
| Toolchain documents | `.mise.toml` pins `node = "22"` and `npm:pnpm = "10.34.9"`. The EP-00 plan and `ARCHITECTURE.md` §2.1 still say **10.34.3**; EP-00-000 amendment v0.8 supersedes that pin. This plan follows **10.34.9** |
| `package.json` | 53 dependencies + 9 devDependencies, all **exact**; no `packageManager`/`engines`; scripts `build`, `dev`, `preview`, `format`, `typecheck`. **Byte-state to be preserved** |
| Lockfile | `lockfileVersion: 9.0`; importer has **66 entries** where `package.json` expects **62**; the four extras are `@emotion/react`, `@emotion/styled`, `@mui/icons-material`, `@mui/material`; **five caret specifiers** (`@types/node ^22.0.0`, `@types/react ^19.0.0`, `@types/react-dom ^19.0.0`, `oxfmt ^0.2.0`, `typescript ^5.7.0`); resolved `@types/react` **19.2.6**, `@types/react-dom` **19.3.0** (`EX-19`) |
| `node_modules` | Absent |
| `.gitignore` | Present, functional; still carries the stale line *"There is no version control yet (EX-12); this file is ready for the day there is."* Directory patterns only match when queried with a trailing slash (`node_modules/`, `dist/`) |
| `.gitattributes` | LFS filter rules only; **no `* text=auto`**; no LFS-tracked binary exists |
| Git identity | `user.name` and `user.email` are **unset** (local and global); `core.autocrlf = true` at system level; all source files currently LF |
| Platform | Windows workstation; `pnpm-workspace.yaml` restricts `supportedArchitectures` to **linux / x64+arm64 / glibc**. WSL2 and Docker are **not installed** |
| CI / quality tooling | No `.github/`, no pipeline, no `lint`/`test` script, no remote |
| Governance input | `EP-00-000` is `Verified`; EP-00 is `In build`; the phase authorises `EP-00-001` to begin |

**Consequence.** The work is executable on this machine only after four pre-conditions are settled: toolchain on `PATH`, a commit identity, a platform path for the build (finding F-01 below), and package-registry access. Everything else is deterministic.

---

### 1. Task Objective

Make the repository install reproducibly from its committed lockfile, prove it type-checks and builds on the pinned toolchain, and create its first commit and tag `v0.0.1-bootstrap` — closing the lockfile half of `EX-19` and the commit half of `EX-12`.

After this task is true:

1. `pnpm install --frozen-lockfile` exits 0 on a **clean clone** with no lockfile mutation.
2. The lockfile importer is **exactly** `package.json`: 53 + 9 entries, every specifier exact, nothing extra.
3. `pnpm typecheck` and `pnpm build` exit 0 with recorded output and no suppression added.
4. `.gitignore` is proven by `git check-ignore`, and its stale comment is corrected.
5. The reviewed tree exists as one commit on `main`, tagged `v0.0.1-bootstrap`, with a clean working tree.

---

### 2. Business Problem Being Solved

The repository is currently **unbuildable and unprovable**. `package.json` was edited on 3 November 2026 and the lockfile was never regenerated, so `pnpm install --frozen-lockfile` fails; no type check has ever run against the React 18 type pins; and the project has no commit, no tag and therefore no provenance.

This is the exact v1 failure mode in miniature: the tree *looks* complete, and every later phase would measure a state that cannot be rebuilt. EP-00 exists so that "done" rests on an artifact. `EP-00-001` is the first artifact: a reviewed, reproducible base and a first commit that every later gate can attach to.

Without it, `EP-00-002` has no installed tree to contract against, `EP-00-003`/`004` have nothing to test or lint, `EP-00-005`/`006` have nothing to push or run, and `EP-00-010` has no SHA to index.

---

### 3. Scope

#### 3.1 In scope — exactly the approved G0 scope

| # | Work | Notes |
|---|---|---|
| 1 | Copy `pnpm-lock.yaml` outside the working tree as the rollback artefact | Evidence and rollback only; not committed |
| 2 | Run `pnpm install` on the pinned toolchain, changing **no specifier** in `package.json` | Regeneration is the only way to fix `EX-19`; hand-editing the lockfile is forbidden (`TEC-08`) |
| 3 | Review the lockfile diff against the approved budget (§6.2) and commit it | Includes importer parity and peer-resolution ripples |
| 4 | Run `pnpm typecheck` | `tsc --noEmit`, strict, unsuppressed |
| 5 | Run `pnpm build` as a smoke check | Existing `vite.figma.config.ts`, unchanged |
| 6 | Verify `.gitignore` with `git check-ignore`; correct its stale "no version control yet" comment | The **only** hand-edited file besides the generated lockfile |
| 7 | Stage, verify the staged list, commit, and tag `v0.0.1-bootstrap` | First commit; no push |

#### 3.2 Out of scope — must not be done here

- Any edit to `src/app/App.tsx`, any screen, token, copy or behaviour.
- Any edit to `documents/Context/*`, the approved phase plans, or `EP-00-000`.
- Any change to `package.json`: no dependency added, removed, upgraded, downgraded or deduplicated; no `packageManager`/`engines` (that is `EP-00-002`); no `onlyBuiltDependencies`/`pnpm.approvedBuilds`.
- Any change to `pnpm-workspace.yaml` (including `supportedArchitectures`), `.mise.toml`, `tsconfig.json`, `vite.config.ts` or `vite.figma.config.ts` — unless a separate architect decision is recorded first (§6.4, §20).
- Vitest, linter, format gate, CI, scanning, remote, push, branch protection (`EP-00-003`–`008`).
- Postgres, API, worker, schema, migration, RLS, container — none exist and none is created.
- Removing dormant artefacts (shadcn kit, `default_shadcn_theme.css`, `.figma/backup/*`, `@popperjs/core`, `react-popper`) — `EX-06`, `EX-07`, `EX-17`.
- Rewriting history, amending after push (there is no push), or creating an evidence index (`EP-00-010`).
- Any new script, hook, config file or helper committed to the repository.

---

### 4. Existing Asset and Dependency Analysis

#### 4.1 Assets inspected

| Asset | Path | What it provides | Decision |
|---|---|---|---|
| Toolchain pin | `.mise.toml` | Node 22, pnpm 10.34.9, verifiable via `mise exec` | **Reuse as-is** |
| Install/build/check commands | `package.json` scripts | `typecheck` (`tsc --noEmit`), `build` (`vite build --config vite.figma.config.ts`) | **Reuse as-is** |
| Dependency declarations | `package.json` | 53 + 9 exact pins — the parity source of truth | **Reuse; do not edit** |
| Lockfile | `pnpm-lock.yaml` | Stale importer + resolved tree | **Regenerate** (cannot be hand-written, `TEC-08`) |
| Workspace/supply-chain settings | `pnpm-workspace.yaml` | `packages: ['.']`, `supportedArchitectures`, `minimumReleaseAge: 10080` | **Reuse; do not edit** |
| Ignore rules | `.gitignore` | Full deny list for deps, build output, env, logs, coverage, caches, editors | **Reuse; correct one stale comment** |
| LFS rules | `.gitattributes` | Binary handling; inert today | **Reuse; no edit** |
| Type/build config | `tsconfig.json`, `vite.config.ts`, `vite.figma.config.ts` | Strict TS over `src` + both Vite configs; Figma wrapper | **Reuse; no edit** |
| Figma wrappers | `.figma/make/install`, `dev`, `format` | Not a project pipeline: `install` runs `--ignore-scripts --prefer-offline --no-frozen-lockfile` | **Rejected for reuse** — it deliberately defeats the frozen-lockfile contract (`SEC-56`) |
| Phase authority | `EP-00 - Execution Readiness.md` §9 (`EP-00-001`) | Objective, scope, test plan, evidence, rollback, approver | **Reuse as the single source of truth** |
| Phase record | `EP-00-ENTRY-RECORD.md` | Phase `In build`, item `Ready`, pnpm pin amendment to 10.34.9 | **Reuse as authority** |
| Standards | `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | `TEC-08`–`TEC-11`, `SEC-56`, `GOV-08`/`GOV-09`, `QUA-29`–`QUA-37` | **Constraint** |
| Architecture | `ARCHITECTURE.md` §2.1, §2.5, §8.11, §12.1, §14.2 | Stack, dependency policy, Figma build must keep working, trunk model | **Constraint** |
| Governance plans | `EP-00-000` plan and DoD | Format precedent; first-commit inclusion rule (DoD A-10) | **Reuse as pattern**; both enter the first commit |

**Nothing in the tree performs lockfile regeneration, verification or history creation today.** There is no script to reuse and none should be invented — the work is a sequence of existing commands, not a new tool.

#### 4.2 Dependencies

| Dependency | Type | Effect |
|---|---|---|
| `EP-00-000` complete, phase `In build` | Governance | **Met** |
| Node 22.23.4 + pnpm 10.34.9 available | External prerequisite | **Installed but not on `PATH`** — step 0 |
| Commit identity (`user.name`, `user.email`) | Human decision | **Absent** — commit cannot be created |
| Platform path for native optional packages | Architecture/platform decision | **Unresolved** — finding F-01 |
| Registry access for pnpm | External | Required for install; unverified here |
| Architect `[REVIEW]` approval of the plan and the lockfile diff | Governance | Required before commit |
| `minimumReleaseAge: 10080` | Constraint | Must not be lowered or bypassed |

---

### 5. Reuse / Extension / Refactoring Assessment

| Proposed need | Options considered | Decision | Justification |
|---|---|---|---|
| Toolchain definition | Reuse `.mise.toml`; edit it; add `.nvmrc`/`.node-version` | **Reuse, no edit** | Already authoritative and installed; `packageManager`/`engines` is `EP-00-002` |
| Install path | Reuse `.figma/make/install`; use `pnpm install` directly | **Use `pnpm install` directly** | The wrapper passes `--no-frozen-lockfile` and `--ignore-scripts`, which contradicts `SEC-56`; it is a Figma convenience script, not a project gate |
| Lockfile | Reuse stale; hand-edit; regenerate | **Regenerate** | Hand-editing is explicitly forbidden (`TEC-08`); the stale file is the defect being closed |
| Typecheck/build | New script; existing scripts | **Reuse existing scripts** | Both already exist and are the contract the pipeline will call in `EP-00-006` |
| Ignore verification | New script; `git check-ignore` | **Reuse `git check-ignore`** | Built into git; no asset needed |
| Importer parity check | New committed script; inline/temp Node; `--frozen-lockfile` | **`--frozen-lockfile` as the authoritative gate + an inline/temporary check outside the repo** | A committed checker would be a new tool outside scope and would pre-empt `EP-00-006`; frozen install already fails on any mismatch |
| History | Amend nothing; create first commit and tag | **Create — genuinely new** | No commit exists; this is the task's product, not a reusable module |
| `.gitignore` | Reuse whole file; correct comment only | **Reuse + one comment correction** | The deny list is correct; only its outdated preamble is wrong |
| `.gitattributes` | Add `* text=auto eol=lf`; leave alone | **Leave alone in this task** | Line endings are a real risk, but the change is a repository-wide policy decision (§20, decision 4) |
| CI/quality assets | Add now | **Defer** | Owned by `EP-00-003`–`008`; adding here is scope creep (R14) |

**Genuine new asset:** the first commit and its tag. There is no existing provenance object to reuse, because the repository has zero commits. Its design constraint is that every later phase attaches to this SHA, so it must contain the complete reviewed tree and nothing unreviewed.

---

### 6. Recommended Technical Approach

#### 6.0 Pre-conditions and stop rules

| Pre-condition | Command / action | Stop if |
|---|---|---|
| Toolchain on `PATH` | Prepend `%LOCALAPPDATA%\mise\mise\bin` for the session only | `node -v` ≠ `v22.23.4` or `pnpm -v` ≠ `10.34.9` |
| Registry reachable | `pnpm install` fetch phase | Offline / auth error |
| Commit identity | `git config --local user.name/user.email` from the supplied governance identity | No identity supplied |
| Platform path | §6.4 decision | Build fails on a missing native optional package |
| Working tree understood | Manifest of protected files; `git status -uall` | Any tracked file or unexpected staged content |

Do **not** use `sudo`, global git config, `--no-verify`, `--ignore-workspace`, `--no-frozen-lockfile` for the verification run, or any pnpm trust-policy bypass.

#### 6.1 Exact sequence

| Step | Action | Expected result |
|---|---|---|
| 1 | `$env:PATH = "$env:LOCALAPPDATA\mise\mise\bin;$env:PATH"`; `mise --version`, `mise exec -- node -v`, `mise exec -- pnpm -v` | `2026.11.0`, `v22.23.4`, `10.34.9` — record as **E8** |
| 2 | Copy `pnpm-lock.yaml` to `%TEMP%\ep-00-001\pnpm-lock.yaml.bak`; SHA-256 the protected files (`package.json`, `pnpm-workspace.yaml`, `.mise.toml`, `tsconfig.json`, both Vite configs, `src/app/App.tsx`, `documents/Context/*`, both phase plans, `EP-00-ENTRY-RECORD.md`) | Rollback artefact **and** before-manifest **E10** |
| 3 | `pnpm install --frozen-lockfile` **before** regenerating | **Fails** with an outdated-lockfile/importer error — the natural "before" proof for **T1**; capture output |
| 4 | `pnpm install` (no `--frozen-lockfile`), no `package.json` change | Exit 0; lockfile regenerated; note any ignored-build-script warning |
| 5 | Review the diff against §6.2; summarise it | **E2** — importer parity + allowed ripples only |
| 6 | `pnpm install --frozen-lockfile` again in the working tree | Exit 0, no lockfile mutation (**T1 after**) |
| 7 | `pnpm typecheck` | Exit 0 — **E3**; on failure follow §6.5 |
| 8 | `pnpm build` | Exit 0, `dist/` produced and ignored — **E4**; platform gate §6.4 |
| 9 | Correct the `.gitignore` preamble (replace the "no version control yet" sentence); no other ignore change | Diff is comment-only |
| 10 | `git check-ignore -v node_modules/ dist/ .env coverage/ .pnpm-store/`; confirm `.env.example` is **negated**, not ignored | Every path matches the intended rule — **E5** |
| 11 | `git add -A`; review `git diff --cached --stat` and the full staged path list; scan staged content for deny patterns (`.env*`, `*.pem`, `*.key`, `node_modules/`, `dist/`, credential prefixes) | Staged list equals the reviewed tree — **E9** |
| 12 | Commit (§6.3); tag `v0.0.1-bootstrap` | Commit SHA + tag — **E6** |
| 13 | `git status --porcelain` | Empty — **E7** |
| 14 | Clean-clone replay: `git clone --no-hardlinks . %TEMP%\ep-00-001\clone`; in it `pnpm install --frozen-lockfile`, `pnpm typecheck`, `pnpm build` | All exit 0 — **E1**; proves the commit is self-contained |
| 15 | Confirm protected files against the before-manifest | Only `pnpm-lock.yaml` and the `.gitignore` comment differ — **T8** |

**Why the clone is local:** there is no remote until `EP-00-005`. Cloning the local repository into the temp directory proves the committed tree, avoids a nested repository, and is repeatable.

#### 6.2 Lockfile diff budget

The approved plan's budget ("four removals, five specifier corrections, two `@types` resolutions") is the **substantive** budget, not a line count. Accept only:

| Change | Expected |
|---|---|
| Importer `dependencies` | 4 entries removed (`@emotion/react`, `@emotion/styled`, `@mui/icons-material`, `@mui/material`); every remaining specifier exact and equal to `package.json` |
| Importer `devDependencies` | 5 caret specifiers replaced by the exact pins (`@types/node` 22.20.5, `@types/react` 18.3.31, `@types/react-dom` 18.3.7, `oxfmt` 0.2.0, `typescript` 5.9.3) |
| `@types/react` / `@types/react-dom` resolution | 19.2.6 → **18.3.31**; 19.3.0 → **18.3.7** |
| Peer-resolution snapshot keys | Mechanical rewrite of `(@types/react-dom@…)(@types/react@…)` keys on Radix/cmdk/vaul snapshots; these are the *consequence*, not new decisions |
| Pruning | MUI/emotion snapshots and `@types/react@19`/`@types/react-dom@19` snapshots removed if unreferenced |
| `settings:` block | Unchanged, or a pnpm-written normalisation that is explained in E2 |

**Stop and report (`R2`) if:** any package version changes beyond those listed; any package is added; any package is removed beyond the four; `package.json` is modified by pnpm; or a new `pnpm-lock.yaml` setting appears that is not explained. The lockfile is a supply-chain artefact: an unreviewed transitive change is an unapproved change.

#### 6.3 Commit and tag specification

- **Identity:** supplied by the founder/architect; set with `git config --local`, never `--global`. An agent must not invent or impersonate an identity.
- **Message (proposal, no policy exists yet):**

```text
chore(ep-00-001): regenerate lockfile and create bootstrap commit

- regenerate pnpm-lock.yaml from the exact package.json pins (EX-19)
- verify frozen install, typecheck and build on the pinned toolchain
- correct the stale .gitignore comment (EX-12)
- first commit of the reviewed tree; tag v0.0.1-bootstrap

Class: [REVIEW]
```

- **Tag:** annotated, `v0.0.1-bootstrap`, with a message naming the task, the toolchain versions and the verification result. Annotated because provenance (tagger + date) is the point of a bootstrap tag; a lightweight tag records neither.
- **No push.** The remote does not exist (`EP-00-005`).

#### 6.4 Finding F-01 — platform constraint versus native optional dependencies

`pnpm-workspace.yaml` sets `supportedArchitectures.os: [linux]`. In the installed pnpm 10.34.9 bundle, `checkPlatform` builds the supported list with `dedupeCurrent`, which **maps `"current"` but does not add the running platform** — so on this Windows machine the effective list is `["linux"]`. The Vite toolchain depends on platform-specific optional packages (`@esbuild/win32-x64`, `@rollup/rollup-win32-x64-msvc`, `lightningcss-win32-x64-msvc`). Those are present in the lockfile and will be **skipped at install**.

Likely result: `pnpm install --frozen-lockfile` exits 0 (T1 passes) while `pnpm build` fails on a missing native module (T4 fails). The EP-00 plan's R10 states the constraint is inert "because no native optional dependency is installed" — that premise is incorrect, because the native packages are transitive through Vite, Tailwind and Rollup.

| Option | Description | Assessment |
|---|---|---|
| **A — Linux execution (recommended)** | Install WSL2 Ubuntu, install mise/Node/pnpm there, run the task against the same checkout (or clone inside WSL) | Matches the pinned architecture, matches CI (which is the reference), changes no repository file. Cost: environment provisioning |
| **B — Architect-approved config amendment** | Add `win32` (and optionally `darwin`) to `supportedArchitectures` | Makes Windows viable, but changes the committed platform contract and requires an explicit scope amendment to `EP-00-001`; `[REVIEW]`. CI remains Linux |
| **C — Local-only workaround** | `pnpm install --force`, which installs optional dependencies regardless of platform | No committed change, but the local tree diverges from CI, `--force` may rewrite the lockfile, and it proves less than T1/T4 claim. Only with written approval, and the lockfile must be re-verified afterwards |

**Do not** choose silently. Run steps 1–8 first; if `pnpm build` fails with a missing platform binary, stop and record the failure as the evidence that selects the option.

#### 6.5 If typecheck or build fails (`R3`)

- Fix only genuine errors **inside bounded scope**, and only where the fix is not a prototype edit.
- Never add `@ts-ignore`, `@ts-expect-error`, an `any` widening, or change `skipLibCheck`.
- A required fix to `src/app/App.tsx` is `[FOUNDER]` and therefore **out of scope**: stop, report the exact error, and open it as a separate work package. Do not "fix it while we are here".
- A build failure caused by the Figma wrapper is reported, not worked around; the preview must keep working (`ARCHITECTURE.md` §8.11).

#### 6.6 Rollback

| Point | Rollback |
|---|---|
| Before commit | Restore `pnpm-lock.yaml` from the temp copy; revert the comment-only `.gitignore` edit from the before-manifest; delete `node_modules/` and `dist/` if desired (both ignored). `EX-19` returns to its recorded state |
| After commit, before any push | `git tag -d v0.0.1-bootstrap`, then `git update-ref -d HEAD`. The branch is unborn again; no parent exists |
| After a push (not in this task) | Out of scope; no remote exists |

No data, schema, environment or host is involved, so rollback is complete and cheap.

---

### 7. Required Systems, Modules and Components

| Component | Role in this task | New? |
|---|---|---|
| Local git repository | Holds the reviewed tree; produces commit and tag | Existing |
| mise-managed Node 22 + pnpm 10.34.9 | Runs install, typecheck, build | Existing (provisioned) |
| `pnpm-lock.yaml` | Regenerated supply-chain artefact | **Regenerated** (not new in kind) |
| `package.json` scripts | `typecheck`, `build` | Existing, unchanged |
| `.gitignore` | Deny list; comment corrected | Existing, comment-only edit |
| `git` CLI + `git-lfs` | Staging, commit, tag, ignore proof | Existing |
| Temp directory outside the tree | Lockfile backup, before-manifest, clone replay, logs | Environment only |

**No application module, service, API, worker, database, schema, migration, queue, container, auth component or UI component is created or modified.**

---

### 8. Data Requirements

The "data" is the lockfile, the commit object and the evidence.

- **Parity source:** `package.json` (53 + 9 exact entries) is the only authority. The importer must equal it exactly.
- **Lockfile integrity:** `lockfileVersion` unchanged; all resolved versions either unchanged or inside the approved budget (§6.2).
- **Commit content:** the complete reviewed tree, including `EP-00-000`'s record and this task's plan and DoD; no `node_modules/`, `dist/`, logs, coverage or local secret.
- **Evidence records:** E1–E10, stored outside the tree until `EP-00-010` indexes them. No credentials, tokens or token-bearing URLs in any log.
- **No personal data** beyond the governance commit identity.

---

### 9. Database Considerations

**None.** No table, schema, migration, grant, RLS policy, Supabase project or data API is created or touched. The task does not open a database connection. This must be stated in the task record so a later reader does not assume a persistence layer arrived with the lockfile.

---

### 10. API Requirements

**None.** No endpoint, contract, OpenAPI document or versioning decision. The task changes no server code, because no server exists. It does not pre-empt the API versioning decision (`standards` §16 #2).

---

### 11. User Interface Requirements

**None user-facing.** No screen, token, colour, type size, spacing or copy change. `src/app/App.tsx` must be **byte-identical** (verified in T8/T6), and `pnpm build` must still produce the preview bundle (`ARCHITECTURE.md` §8.11). This is a `C12`-relevant constraint for the phase.

---

### 12. User Experience Considerations (developer and reviewer)

- **Newcomer:** after this task, `clone → frozen install → typecheck → build` works from the tag alone. That is the first honest "it builds" claim the project can make.
- **Reviewer:** the diff must be reviewable in one sitting (`QUA-32`). The lockfile diff is mechanical; the review substance is the budget in §6.2 and the single comment edit. The commit message names the task, the class and the closure of `EX-19`/`EX-12`.
- **Failure clarity:** when the importer is stale, `--frozen-lockfile` fails loudly with an outdated-lockfile error. That is preferable to a silent re-resolution, and it is why the frozen install is the gate rather than a wrapper.
- **No hidden steps:** every command used is a documented `package.json` script or a git command. No bespoke script is introduced for the next person to discover.
- **Platform honesty:** if F-01 forces a Linux-only execution or a config amendment, the chosen path must be written down where the next contributor looks — not discovered by a failed build.

---

### 13. Security Considerations

| Concern | Control |
|---|---|
| Supply chain | Regenerate from exact pins only; `minimumReleaseAge: 10080` untouched; no dependency added or upgraded; frozen install as the verification gate (`SEC-56`, `TEC-08`, `TEC-09`) |
| Unreviewed transitive change | §6.2 budget; stop-and-report rule (`R2`); no `--force` without approval |
| Secrets | No `.env*`, `*.pem`, `*.key`; staged-content scan before commit; `.env.example` is negation-only and **not created** here |
| Seeded secret test | Any fake credential used to prove T6 is non-live, created in the temp directory, never committed or pushed (`R8`) |
| Evidence leakage | Logs can contain absolute Windows paths; redact the user-home segment before attaching. No token-bearing URLs |
| Commit integrity | No `--no-verify`; no hook bypass; no global config; identity supplied by governance, not invented by an agent |
| Agent boundary | An agent may run the commands and produce evidence; it may not approve the diff, sign the phase, or decide the platform path (`EES` §5.6, `AI-20`) |
| Scanning gap | Secret/vulnerability scanning is `EP-00-008`; until then the manual staged-content check is the only control. Record this residual honestly |
| Build scripts | pnpm 10 may ignore dependency build scripts. Do **not** run `pnpm approve-builds` (it edits `package.json`); if a build needs it, stop and raise it |
| Prototype integrity | `App.tsx` byte-identical; no visual or security-surface change |

---

### 14. Performance Considerations

- **CI relevance:** this task fixes the input all later pipeline timings are measured against. Record install and build wall-clock as the first baseline for `EP-00-006` comparison.
- **No runtime impact:** no shipped code changes; bundle output is unchanged in content.
- **Review cost:** the commit is the largest single diff the project will ever have (whole tree), but it is an initial import, not a change; the review focuses on the allow-list and the lockfile budget.
- **Local feedback:** steps 3–8 are cheap and ordered so the fastest failure (frozen install) comes before typecheck and build.

---

### 15. Testing Strategy

Every gate must be capable of failing. T1 and T2 fail **before** the change; the rest are new.

| # | Test | Before → after | Deny path / seeded failure |
|---|---|---|---|
| **T1** | `pnpm install --frozen-lockfile`, in the working tree before the commit and in a clean clone after | Fails on importer mismatch (`EX-19`) → exit 0 both times, no lockfile mutation | Fails if the lockfile is stale, missing, or mutated by the install |
| **T2** | Importer parity: every `package.json` dependency/devDependency appears with the same exact specifier; nothing extra remains | 4 extras + 5 carets + 2 wrong `@types` resolutions → exact 53 + 9 parity, `@types/react` 18.3.31, `@types/react-dom` 18.3.7 | **Deny both ways:** a missing package fails; an extra package also fails. Run the comparison against the pre-install lockfile to prove the check can fail |
| **T3** | `pnpm typecheck` | Never run → exit 0, output recorded | Fails on any real type error; no suppression may make it pass |
| **T4** | `pnpm build` | Never run → exit 0, `dist/` produced and ignored | Fails on a missing native module (F-01), a broken Figma wrapper, or a type error |
| **T5** | `git check-ignore -v node_modules/ dist/ .env coverage/ .pnpm-store/`; verify `.env.example` is **negated** | Untested → every directory path matches; `git status` after install lists no `node_modules/` | Fails when a path is **not** ignored. Directory patterns require the trailing slash — test the real command, not an approximation |
| **T6** | Staged-content check: no `.env*`, `*.pem`, `*.key`, `node_modules/`, `dist/`; staged list equals the reviewed tree | N/A → exact list, nothing unexpected | Seed a fake, non-live credential in the temp directory, confirm the scan flags it, delete it, never stage it |
| **T7** | LFS safety: `git add` completes without filter errors | N/A → no error | Fails on a missing LFS filter or an unexpected binary |
| **T8** | Protected-file byte-identity against the before-manifest | N/A → only `pnpm-lock.yaml` and the `.gitignore` comment differ | Fails on any edit to `App.tsx`, `package.json`, configs, `documents/Context/*`, phase plans or the `EP-00-000` record |
| **T9** | History integrity: commit exists; annotated tag resolves to `HEAD`; `git show --stat` matches the staged list; tree clean | No commit → one commit + tag + empty `status` | Fails on a lightweight/missing tag, a dirty tree, or an extra commit |
| **T10** | Clean-clone replay from the tag: frozen install → typecheck → build | Unprovable → all exit 0 | Fails if the commit omits a needed file or the install is not reproducible |

**Evidence:** E1 clean-clone frozen-install log · E2 lockfile diff summary · E3 typecheck output · E4 build output · E5 `check-ignore` output · E6 commit SHA + `git show --stat` + `git tag --list` · E7 empty `git status --porcelain` · E8 toolchain versions · E9 staged-content review · E10 before/after protected-file manifest.

---

### 16. Recommended Implementation Sequence

| Step | Work | Owner | Gate |
|---|---|---|---|
| **0** | Settle §20 decisions: platform path, commit identity, line-ending policy, tag style | Architect / founder | **Hard stop** if identity or platform is unresolved |
| **1** | Put the pinned toolchain on the session `PATH`; record versions (E8) | Developer | — |
| **2** | Back up the lockfile and take the protected-file manifest (E10) | Developer | — |
| **3** | Prove the failure: `--frozen-lockfile` before regeneration | Developer | T1-before |
| **4** | `pnpm install`; review the diff against §6.2 (E2) | Developer | T2 |
| **5** | Re-run frozen install (E1 in the working tree) | Developer | T1-after |
| **6** | `pnpm typecheck` (E3) | Developer | T3 |
| **7** | `pnpm build` (E4); if it fails, apply §6.4/§6.5 and stop | Developer | T4 / F-01 |
| **8** | Correct the `.gitignore` comment; prove ignores (E5) | Developer | T5 |
| **9** | Stage, review, scan staged content (E9) | Developer | T6, T7, T8 |
| **10** | Commit and annotate the tag (E6) | Developer | T9 |
| **11** | Clean-clone replay from the tag (E1) | Developer | T10 |
| **12** | Architect reviews the diff, the budget and the evidence; class `[REVIEW]` | Architect | G1 → G2 |
| **13** | Hand off to `EP-00-002`; the SHA is the base every later gate attaches to | Developer / architect | — |

**Critical path:** `0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12`.

**Stop conditions:** unresolved commit identity; unresolved platform path; any lockfile change outside §6.2; any typecheck/build failure that would require a prototype edit or a suppression; any protected file change; any unexpected staged content.

---

### 17. Expected Outcome

- A clean clone installs from the committed lockfile with **zero resolution drift**, and the importer matches `package.json` exactly.
- `pnpm typecheck` and `pnpm build` are green on the pinned toolchain, with recorded output and no suppression.
- `.gitignore` is proven by `git check-ignore`, and its stale preamble is corrected.
- The complete reviewed tree exists as the repository's first commit on `main`, tagged `v0.0.1-bootstrap`, with a clean working tree.
- `EX-19` is closed; the commit half of `EX-12` is closed.
- `EP-00-010` has a SHA and a tag to index; `EP-00-002` has a real installed tree to contract against.

---

### 18. Definition of Done

- [ ] `pnpm install --frozen-lockfile` exits 0 in the working tree and in a clean clone, with no lockfile mutation.
- [ ] The importer matches `package.json` exactly: 53 dependencies + 9 devDependencies, every specifier exact, nothing extra.
- [ ] The lockfile diff contains only the §6.2 budget; every ripple is explained in E2; nothing outside the budget changed.
- [ ] `package.json` is **byte-identical** (SHA-256 in E10).
- [ ] `pnpm typecheck` exits 0; no `@ts-ignore`, `@ts-expect-error`, `any` widening or `skipLibCheck` change was introduced.
- [ ] `pnpm build` exits 0 via the unchanged `vite.figma.config.ts`; `dist/` is produced and ignored.
- [ ] `.gitignore` is proven by `git check-ignore` for dependencies, build output, env and coverage; `.env.example` is negated, not created.
- [ ] Only `pnpm-lock.yaml` and the `.gitignore` comment differ from the starting tree; `src/app/App.tsx`, `documents/Context/*`, the phase plans, `EP-00-000` and all configs are unchanged.
- [ ] Commit exists on `main`; annotated tag `v0.0.1-bootstrap` resolves to that commit; `git show --stat` matches the staged list.
- [ ] `git status --porcelain` is empty after the commit.
- [ ] No secret, credential, token-bearing URL or `.env` content is staged, committed or attached to evidence.
- [ ] No push, no remote, no CI, no dependency addition, no `package.json` edit, no `pnpm-workspace.yaml`/`.mise.toml` edit.
- [ ] Rollback is recorded and executable; the lockfile backup exists outside the tree.
- [ ] T1–T10 pass, including at least one demonstrated failure (T1 before, T2 before, and the T6 seeded fixture).
- [ ] E1–E10 exist and are linked; the status is not advanced beyond the evidence (`EES` §9.3).
- [ ] Architect `[REVIEW]` approval is recorded; no agent self-approval.
- [ ] `EP-00-001` is `Verified` only after G2; the phase remains `In build` (`QUA-37`).

---

### 19. Implementation AI Execution Profile

| Field | Recommendation |
|---|---|
| **Recommended coding reasoning level** | **Medium** |
| **Justification** | The work is a deterministic command sequence over an existing toolchain, with one generated artefact and one comment edit. The technical complexity is low; the dominant risks are **discipline and judgement at the edges**: not hand-editing the lockfile, not widening scope into `App.tsx`, not suppressing a type error, not accepting an unexplained transitive change, and not bypassing the frozen-lockfile contract. Those are caught by the explicit diff budget, the stop rules and architect review — not by a higher reasoning tier. The approved EP-00 plan specifies `Planning — High → Coding — Medium`, and this profile follows it. **Escalate to High and stop** if the platform decision (F-01) requires a configuration change, or if typecheck/build reveals an error that would need design judgement; both are decisions for the architect, not reasoning problems to solve mid-task. |

---

### 20. Decisions Needed Before Implementation

1. **Platform path (F-01) — blocking.** Recommended: **Option A**, execute in WSL2/Linux, because it matches the pinned `supportedArchitectures` and the Linux CI reference and changes no repository file. Alternatives B (architect-approved `win32` addition, a scope amendment) and C (local `--force`, parity gap recorded) are available but need explicit approval. I cannot choose this for you.
2. **Commit identity — blocking.** Supply the `user.name` and `user.email` for the first commit. An agent must not invent or impersonate one. It will be set with `git config --local` only.
3. **Commit message and tag style — minor.** Confirm the proposed message (§6.3) and an **annotated** `v0.0.1-bootstrap` tag. No commit-message policy exists yet.
4. **Line endings — minor but best decided now.** `core.autocrlf = true` and `.gitattributes` has no `* text=auto`. Current files are LF; a Windows clone will check them out as CRLF, which will surface as noise in `EP-00-004`'s format gate. Options: (a) leave it, record the risk, decide in `EP-00-004`; (b) architect approves adding `* text=auto eol=lf` **before** the first commit, the only cheap moment to set repository-wide normalisation. My recommendation is (b) if it is approved as a scope amendment; otherwise (a) with the risk recorded.
5. **"Clean clone" proof.** Confirm a local clone into the temp directory is acceptable evidence while no remote exists. Recommended: yes — it proves the committed tree without pre-empting `EP-00-005`.
6. **Documentation drift — follow-up, not part of this task.** `.mise.toml` and `EP-00-000` say pnpm **10.34.9**, while the EP-00 plan and `ARCHITECTURE.md` §2.1 still say **10.34.3**. This plan follows 10.34.9. Amending the owning documents is a `QUA-38` follow-up for the architect; I have not touched them.

---

**Plan status:** complete for `EP-00-001` only. No other task has been planned, no production code has been written, no repository file has been created or modified, and the approved Phase document is untouched.
