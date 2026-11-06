# EP-00 — Execution Readiness
## Engineering Phase Plan

**Planning basis:** `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` (approved 4 Nov 2026) §6.2, §7, §8, §9, §11; `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` (approved 4 Nov 2026) `GOV-08`, `GOV-09`, `TEC-08`–`TEC-11`, `SEC-54`–`SEC-56`, `QUA-24`, `QUA-29`–`QUA-35`, `DEP-01`–`DEP-17`, §13.3, §16 #16/#18; `ARCHITECTURE.md` §2.5, §8.11, §11.6, §12.1–§12.8, §16.3 #6/#8, §16.4 #18; `AGENTS.md` §3–§4; `Business-Development-Roadmap.md` §14 Phase 0.

> **Phase status verdict: `In build` — implementation complete, closure blocked.** EP-00 was opened on 4 November 2026 by `EP-00-000`. On 6 November 2026 the reproducible base, toolchain contract, Vitest, ESLint/format gates, six-job CI pipeline, secret/dependency scanning, developer bootstrap and evidence index were implemented and verified. The phase is **not** closed: `EP-00-007` is blocked because GitHub rejects branch protection on a private repository on this account's plan (HTTP 403: "Upgrade to GitHub Pro or make this repository public"), and `EP-00-011` is an unsigned G5 founder decision. C8 and C14 are therefore unmet; C10 is partially met because `v0.0.1-bootstrap` predates CI. No status above its evidence is claimed (`EES` §9.3).
>
> Verified in this repository on 6 November 2026 against **code commit `1668c30`** (evidence documents follow it on `main`); the root commit `8029466` is tagged `v0.0.1-bootstrap`; `package.json` carries `packageManager: pnpm@10.34.9`, `engines`, and `lint`/`test`/`format:check`/`check:toolchain` scripts; `.github/workflows/ci.yml` runs install → lint → typecheck → test → build plus security; CI run [42257026623](https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623) is green; five per-stage seeded-failure runs are recorded. The phase remains `In build` because closure, not implementation, is what is outstanding.

---

## 1. Phase definition

| Field | Detail |
| --- | --- |
| **Phase ID** | EP-00 |
| **Phase name** | Execution Readiness |
| **Roadmap phase served** | Phase 0 — Foundation and preparation |
| **Phase priority** | Critical — blocks every phase |
| **Phase status** | `In build` — opened 4 November 2026; implementation verified 6 November 2026; closure blocked by `EP-00-007` (host plan) and `EP-00-011` (unsigned G5) |
| **Entry gate** | Execution structure approved; founder available to approve the CI provider and repository hosting (`standards` §16 #18). |
| **Exit gate** | A clean clone installs from the frozen lockfile, typechecks, lints and runs the test command green **in CI**; `main` is protected; the first commit exists and is tagged `v0.0.1-bootstrap`; the pipeline is green on that commit. |
| **Closure authority** | Founder, on the architect's recommendation, through **G5** (EES §7.1). |
| **Gates exercised** | **G0, G1, G2 and G5 only.** EP-00 has no staging and no production release, so **G3 and G4 are not exercised**. EP-00 produces the project's first real G2 evidence. |
| **Duration** | Not estimated. A phase is a gate, not a date (ED-01). |

### 1.1 Phase objective

Make the repository buildable, testable, reviewable and deployable-to-CI **before any product capability is written**, so that every later claim of "done" rests on a pipeline artifact rather than on a status sentence.

### 1.2 Business capability being enabled

**EP-00 delivers no user-facing capability and no revenue capability.** It is the precondition for every other phase. What becomes true is narrow, and deliberately so:

- The repository has **provenance**: a first commit, a tag, a protected trunk, and a review rule that rejects an unreviewed change.
- The tree **installs reproducibly** from a committed lockfile on a pinned toolchain — locally and in CI.
- The project has a **quality gate that has been proven to fail**: install, lint, typecheck, test and build each block a merge when broken.
- The two supply-chain controls the standards require — **exact pinning with a frozen lockfile** and **secret and vulnerability scanning** — are live rather than intended.
- A new contributor can go from clone to green in one documented sequence.

Its business relevance is indirect but real: roadmap Phase 0 exits on "the measurement instrument: account, activation, transaction, dispute, fraud" being live. No measurement can be produced, trusted or audited until a build pipeline exists — and the founder's own remediation of the v1 status problem (EES §9.3) depends on artifacts existing. EP-00 is what makes evidence possible.

### 1.3 Why this phase exists separately from EP-01

EP-00 is repository and pipeline hygiene; EP-01 is architecture. Merging them lets pipeline debt hide inside a product phase — which is exactly how the v1 "landed" claims became unverifiable (EES §6.2, §12 #1). EP-00 also has a different failure mode: it fails by being *declared* done, because configuration is easy to assert and hard to prove. The exit gate is therefore written entirely in terms of inspectable artifacts.

---

## 2. Engineering objectives

1. **One reproducible base.** A clean clone installs from the committed lockfile with no resolution drift, on the exact toolchain the repository pins.
2. **One toolchain definition.** `.mise.toml` is the single source of truth for Node and pnpm; `packageManager` and `engines` restate it so a machine without `mise` still fails loudly rather than silently using another version.
3. **One gate set that has been proven to fail.** Every blocking check is demonstrated to fail on a seeded defect before it is trusted; a gate that has never failed is untested.
4. **One history.** The tree has a first commit, a tag on the reviewed commit, a protected `main`, and a recorded bootstrap exception — because branch protection cannot exist before the first commit.
5. **One supply-chain posture.** Exact pins, retained `minimumReleaseAge`, frozen-lockfile installs, secret scanning and vulnerability scanning as blocking checks.
6. **One incremental quality policy.** Lint and format gates apply to the whole project without producing an unreviewable 3,814-line reformat of `src/app/App.tsx`, and without weakening the rule to nothing.
7. **One honest status model.** No EP-00 claim above `Not started` without a linked run URL, commit SHA or setting export (EES §9.3).
8. **No product work.** EP-00 changes no screen, token, business rule, schema, endpoint or dependency version.

---

## 3. Technical goals

| ID | Technical goal | Measure |
| --- | --- | --- |
| **TG-01** | Clean-clone reproducibility | `pnpm install --frozen-lockfile` exits 0 on a clean clone in CI, with no lockfile mutation. |
| **TG-02** | Importer parity | Every `package.json` dependency and devDependency appears in the lockfile importer with the same exact specifier; nothing extra remains (closes the visible half of `EX-19`). |
| **TG-03** | Typecheck green, unsuppressed | `pnpm typecheck` exits 0 on the pinned toolchain; no new `@ts-ignore`, `@ts-expect-error`, `skipLibCheck` change or `any` widening is introduced to get there. |
| **TG-04** | A test command that can fail | `pnpm test` exists, runs Vitest, and fails when the asserted behaviour is deliberately removed — proven by a seeded-failure run. |
| **TG-05** | A lint gate that can fail | `pnpm lint` blocks a seeded violation; the format check blocks an unformatted file; the pre-existing baseline is recorded, not hidden. |
| **TG-06** | Pipeline blocks per stage | Each of install → lint → typecheck → test → build is individually proven to fail the pipeline when broken. |
| **TG-07** | Trunk protection is real | A direct push to `main`, a force-push, and a self-approved merge are each rejected — proven by an attempted-and-rejected run, not by a settings screenshot alone. |
| **TG-08** | Secrets cannot be committed undetected | A seeded, non-live credential fixture is detected by push protection or the CI scan; the clean run passes. The fixture is never a real key and never reaches a lasting branch. |
| **TG-09** | Vulnerable dependencies block | A High/Critical advisory fails the dependency gate — proven on a throwaway repository or branch that is never merged, so no vulnerable package enters the committed lockfile. |
| **TG-10** | Toolchain parity | Local and CI report identical Node and pnpm versions from the same pinned definition. |
| **TG-11** | Evidence completeness | Every criterion in §13 links an artifact; the index has no unlinked row. |
| **TG-12** | The preview keeps working | `pnpm build` (via `vite.figma.config.ts`) exits 0 and no source file changed, so the Figma Make preview is unaffected (`ARCHITECTURE.md` §8.11). |

---

## 4. Scope guard

### 4.1 In scope

Mapped directly to the approved EP-00 scope (EES §6.2), with nothing added:

- Toolchain pinned via `.mise.toml` (Node 22, pnpm 10.34.9), plus `packageManager`/`engines` restatement.
- `pnpm install` and a **reviewed** lockfile commit (`EX-19`).
- First commit with a complete tree; `.gitignore` verified to exclude secrets and build output; the stale first comment corrected.
- Branch model and protected `main` (`ARCHITECTURE.md` §12.1; §16.3 #6 sign-off).
- CI provider chosen by the founder, and a pipeline skeleton running install → lint → typecheck → test → build (`EX-12`, `standards` §16 #18).
- Vitest and a linter added (`EX-10`), with scripts.
- `typecheck` green on the prototype.
- A written local-run instruction, scoped per the G0 ruling in §4.3.
- Secret scanning and dependency scanning enabled.
- The phase entry record, evidence index and G5 closure record.

### 4.2 Out of scope — EP-00 must not build these

- Any product feature, screen, component, token or copy change. **No edit to `src/app/App.tsx`,** except the founder-approved, type-only corrections in `EP-00-012` — no visual, layout or copy change is permitted under that exception either.
- Any dependency change other than the pinned toolchain additions required by the approved scope (test runner, linter, and their direct support packages).
- Any upgrade, downgrade, removal, or de-duplication of an existing dependency, and any change to `minimumReleaseAge`.
- Any server, API, worker, database, schema, migration, queue, container or auth code — none exists and none is created.
- Playwright, Testcontainers and Testing Library/jsdom (EP-01, per §4.3 ruling 2).
- Visual regression, OpenAPI diff, migration lint and `db diff` pipeline stages (EP-01).
- Any hosting, DNS, TLS, staging or production environment (`ARCHITECTURE.md` §16.4 #1, #17); no artifact promotion and no deployment.
- Any provider integration or credential.
- Retiring dormant artefacts: the shadcn kit, `default_shadcn_theme.css`, `.figma/backup/*`, `@popperjs/core`, `react-popper` are committed as they are (`EX-06`, `EX-07`, `EX-17`).
- Coverage thresholds — the numeric gate is `[OPEN]` (`standards` §16 #16) and `QUA-20` forbids using line coverage as a gate meanwhile.

### 4.3 Scope interpretations and their G0 rulings

Four statements needed an explicit ruling before work starts. **All four were ruled on 4 November 2026** and recorded in `EP-00-000` (§6, `D-02`–`D-05`); none is open. They are restated here with the ruling of record, because the plan and the entry record must not drift apart.

1. **"A written local-run instruction that starts Postgres, API, worker and Vite" cannot be delivered in EP-00**, because none of those three components exists until EP-01, and EP-00 is forbidden from creating them. It blocks EP-00's exit as literally worded. **Ruling of record (`D-02`, founder, 4 November 2026):** EP-00 delivers a *verified* developer bootstrap for what exists today (clone → pinned toolchain → frozen install → typecheck → lint → test → build → dev server), plus a stated contract for how EP-01 extends it to Postgres/API/worker. The Postgres/API/worker clause is reassigned to EP-01 explicitly, in writing.
2. **Does `EX-10` close at EP-00?** The register's exit condition names Vitest, Playwright and Testcontainers; EP-00's approved scope names only Vitest and a linter; EES §4.4 requires `EX-10` closed for EP-00 to exit. **Ruling of record (`D-03`, architect, 4 November 2026):** `EX-10` is recorded as **partially closed** at EP-00 (runner installed and gating) with the residual — Playwright, Testcontainers, component-test DOM — named as EP-01 work against the same register row. The alternative reading would pull visual-regression and integration-test tooling into EP-00 ahead of the code they test.
3. **What "a linter" means, given `oxfmt` is already installed.** `oxfmt` is the approved formatter (`TEC`/`ARCHITECTURE.md` §2.1); the repository has never had a linter and `package.json` has no `lint` script. **Ruling of record (`D-04`, architect, 4 November 2026):** add a real linter as the gate, keep `oxfmt` as the formatter, and wire both. Linter choice is an architect `[REVIEW]` decision taken in `EP-00-004`, evaluated against `TEC-05`/§3.3 criteria; the plan does not pre-empt the choice.
4. **Work-package identifier convention.** **Ruled 4 November 2026:** identifiers take the `EP-` prefix — `EP-<phase>-<nnn>` — so this plan's items are `EP-00-000` to `EP-00-012`, with `EP-00-001` elaborated at G0 in §9. `ENGINEERING_EXECUTION_STRUCTURE.md` §8.1 was amended the same day. The `WP-` form is retired, and an identifier in either form is never reused.

Two further readings this plan adopts, which the architect should note but which do not need a separate ruling:

- **"Secret-scanning and dependency-scanning enabled"** is satisfied by the chosen host's native features where they exist, because a third-party scanner that receives source code is a data-receiving vendor and a `[FOUNDER]` decision (`TEC-12`). Preferring native scanning avoids creating a vendor decision inside EP-00.
- **The first commit is the only direct commit to `main` in the project's history.** Branch protection cannot precede the commit that creates the branch. This is a bootstrap exception and is recorded as such (§8 R7, EP-00-007).

---

## 5. Required systems, modules and components

EP-00 touches **infrastructure, tooling and governance settings only**. No application module is created, modified or extracted.

| System / component | Responsibility in EP-00 | State today |
| --- | --- | --- |
| **Local Git repository** | Holds the reviewed tree; produces the first commit and the `v0.0.1-bootstrap` tag. | Initialised, zero commits, no remote |
| **Remote repository host** | Provenance, review enforcement, required status checks, environments placeholder, scanning features. | **Does not exist** — #18 is decided; creation and configuration are `EP-00-005` |
| **CI service** | Runs install → lint → typecheck → test → build on every pull request and on `main`. | **Does not exist** — `EX-12` |
| **Toolchain definition** | `.mise.toml` (Node 22, pnpm 10.34.9) plus `packageManager`/`engines` restatement. | **Complete** — `packageManager: pnpm@10.34.9`, `engines`, parity gate; CI and local agree |
| **Package manager and lockfile** | Frozen-lockfile installs; importer parity; `minimumReleaseAge` retained. | **Committed**; frozen install green locally and in CI (`EX-19` closed) |
| **Test runner** | Vitest, one real test, a `test` script, a proven-failing seed. | **Complete** — Vitest 4.1.12, 8 tests, seeded failure, CI gate |
| **Linter** | Lint rule set, `lint` script, baseline register, ratchet policy. | **Complete** — ESLint 9.39.5, 20-entry baseline with expiry, seeded failure |
| **Formatter** | `oxfmt` (existing) wired as a blocking *changed-files* format check. | **Complete** — `format:check`, seeded failure, prototype untouched |
| **Secret scanner** | Push protection and/or CI scan, proven with a non-live fixture. | **Complete as a local + CI control** — provider-native scanning unavailable on the private plan |
| **Dependency scanner** | Vulnerability gate at High/Critical, plus advisory monitoring. | **Complete** — `pnpm audit --audit-level=high`, zero known advisories, seeded High-advisory failure |
| **Build** | Existing `pnpm build` on `vite.figma.config.ts`, unchanged, as the fifth pipeline stage. | Passes locally via `PC-01` and on Linux CI |
| **Governance artifacts** | Phase entry record, work-package register, baseline register, evidence index, closure record. | Entry record verified; 13 work-package records; evidence index created; closure record blocked on G5 |

**Explicitly not involved:** API, worker, PostgreSQL, migrations, RLS, authentication, capability engine, design system, packages workspace, Playwright, Testcontainers, object storage, edge/CDN, staging, production, VFD or any payment, KYC, map, email, SMS or AI provider.

---

## 6. Recommended engineering development order

No dates. Order is by dependency and by which step unblocks the most evidence.

| Stage | Work | Why this order |
| --- | --- | --- |
| **0 — Entry** | `EP-00-000` | Closed 4 November 2026 — phase opened, #18 decided, all four G0 rulings recorded. |
| **1 — Reproducible base** | `EP-00-001` → `EP-00-012` → `EP-00-002` | A stale lockfile makes every later gate meaningless: you cannot lint, typecheck, test or build a tree you cannot install. `012` exists because `001`'s typecheck failed, and `002` pins the toolchain the other gates assume. |
| **2 — Quality toolchain** | `EP-00-003` → `EP-00-004` | A test command and a lint gate must exist before a pipeline can run them. Both need the base to be installable first. |
| **3 — CI and governance** | `EP-00-005` → `EP-00-006` → `EP-00-007` → `EP-00-008` | Provider decision gates everything automated; the pipeline must be green before protection is switched on, or the first protected merge is blocked by a pipeline nobody has seen work. |
| **4 — Developer bootstrap** | `EP-00-009` | Written last because it documents commands that now provably work; written before exit because a clone that only CI can build is not "buildable". |
| **5 — Exit evidence** | `EP-00-010` → `EP-00-011` | Evidence is produced by a running pipeline, not assembled from intentions. |

### 6.1 Parallelism rules

- `EP-00-005` (repository host and CI) **executes** the decision taken on 4 November 2026; it can run while `EP-00-001`–`EP-00-004` are open, but must be closed before `EP-00-006`.
- `EP-00-003` (test runner) and `EP-00-004` (linter) may run in parallel: different files, different toolchains, no shared contract.
- `EP-00-007` (protection) may only run **after** `EP-00-006` has a green run on the tagged commit, and after `EP-00-008` if scanning is expressed as a required check.
- `EP-00-009` (bootstrap doc) may be drafted early but is only `Ready` for verification once stages 1–3 are green.
- Exactly one phase may be `In build` (ED-03). EP-00 does not run alongside EP-01.

### 6.2 Critical path

`000 → 001 → 012 → 002 → 003 → 004 → 006 → 008 → 007 → 010 → 011`

`EP-00-005` gates `006`, `007` and `008`. `EP-00-009` is off the pipeline critical path but **on the phase-exit path**, because EP-00's own scope requires the written instruction to exist and be verified.

---

## 7. Dependencies

### 7.1 Internal dependencies

| Dependency | Effect |
| --- | --- |
| **`EP-00-000` closed** | Satisfied 4 November 2026: phase opened, #18 decided, rulings `D-02`–`D-05` recorded, `DEV-001` approved for the second-reviewer gap. Not a blocker any more, but it is the record every later item cites. |
| **Founder decision #18 — repository hosting and CI provider** | **Decided 4 November 2026**, folded into `ARCHITECTURE.md` §16.4 #25. `EP-00-005` executes it: creates the remote, records the host and CI service, and enables the scanning features the later items require. Nothing is assumed about the provider until that record exists. |
| **Founder/architect rulings on §4.3** | Recorded 4 November 2026 (`D-02`–`D-05`). No longer a blocker; the items cite them, they do not wait on them. |
| **Architect approval — test toolchain** | `GOV-09`: adding Vitest is `[REVIEW]`. |
| **Architect approval — linter and lint/format gate** | `GOV-09`: changing a CI gate or lint rule is `[REVIEW]`. |
| **Second reviewer for CI configuration** | `QUA-31`/`QUA-35` treat CI/CD configuration as critical logic requiring two reviewers. With a one-person team this is the standing conflict in EES §11.2 #2 and it bites in EP-00 first. |
| **`EP-00-001` architect sign-off** | The item is elaborated in §9 and `In build`; install, lockfile, typecheck and build are evidenced, commit identity (`PC-02` email) and `[REVIEW]` approval are outstanding. `F-01` is resolved by a recorded local-only `--force` frozen install (`PC-01`), not by an unrecorded workaround. |
| **Consistency with approved documents** | No EP-00 item may resolve an `[OPEN]` row (`ARCHITECTURE.md` §16.4, `standards` §16) by choosing a default. |

### 7.2 External dependencies

| Dependency | Needed by | Status |
| --- | --- | --- |
| Node 22 and pnpm 10.34.9 on an executing machine | Every install, gate and pipeline-parity check | **Partly met** — Node 22.23.4 and pnpm present on the workstation, but `pnpm -v` reports 10.34.3, not the 10.34.9 pin |
| `git` | Commit, tag, protection verification | Available |
| `git-lfs` | Clone integrity if any binary asset is ever tracked | Present locally; no binary tracked today |
| Repository host account with private-repo and branch-protection capability | `EP-00-005`, `EP-00-007` | **Decided** (#18, 4 November 2026); the account and remote are created in `EP-00-005` |
| CI service with per-stage job status and required checks | `EP-00-006`, `EP-00-010` | **Decided** (#18); the pipeline is built in `EP-00-006` |
| Host-native secret scanning / push protection | `EP-00-008` | Follows `EP-00-005` |
| Registry access for pnpm and a vulnerability advisory source | Install, dependency gate | Available in principle; unverified here |
| Package versions older than 7 days (`minimumReleaseAge: 10080`) | Test runner and linter selection | **Constrains** choice; do not lower it (`TEC-09`) |

**Not dependencies of EP-00:** managed Postgres (#1), hosting/DNS/TLS (#17), sign-in identifier (#14), KYC tier ladder, verification vendor, map/geo provider, VFD, error-tracking vendor, secret manager. Those block EP-01 and later.

---

## 8. Risks, assumptions and engineering considerations

### 8.1 Risks

| # | Risk | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| **R1** | **Toolchain parity, not toolchain absence.** Node 22 and pnpm are now present, but the installed pnpm is 10.34.3 against a 10.34.9 pin. | Installs resolve with a package manager the repository does not pin; CI and a workstation can disagree silently. | `EP-00-002` installs the pinned pnpm and records `node -v`/`pnpm -v`; parity is proven again in `EP-00-006` on the CI image. Provisioning is now a task, not a prerequisite. | Whoever executes |
| **R2** | **Lockfile churn beyond the known diff.** | An unreviewed transitive change is a supply-chain change nobody approved. | Accept only: four removals, five specifier corrections, two `@types` resolutions. Anything else stops and is reported. | Architect |
| **R3** | **`pnpm typecheck` reveals real prototype type errors.** It has now run: 47 errors, 46 in `App.tsx`. | Scope creep into `src/app/App.tsx`; pressure to add `@ts-ignore`. | `EP-00-012` was opened under `[FOUNDER]` with a type-only scope, no suppression, no `skipLibCheck` change and no widening. Any further error is treated the same way, not silenced. | Architect |
| **R4** | **The lint/format gate becomes a 3,814-line reformat or is disabled.** Formatting `App.tsx` produces an unreviewable diff that also touches a `[FOUNDER]` file. | Either the prototype is rewritten without approval, or lint is switched off in week one — the failure mode that makes every later gate optional. | Gate on a curated rule set applied to all files, with a **written baseline register** for known offenders and an expiry; format check limited to **changed files** until EP-01 extraction. No rule-off commit, no blanket disable. | Architect |
| **R5** | **The host and CI are decided but not provisioned.** #18 is closed, yet no remote, pipeline or protection exists. | `EP-00-005`–`008` cannot produce evidence until they do, and a decision mistaken for a capability is the exact failure this phase exists to prevent. | `EP-00-005` creates the remote and records the host; `EP-00-006` and `EP-00-007` produce run URLs and settings exports. No item claims CI or protection until an artifact exists (`EES §9.3`). | Architect |
| **R6** | **Self-merge and second-reviewer conflict.** `QUA-29` prohibits self-merge; `QUA-31` requires two reviewers on CI configuration — which is the majority of EP-00. | Protection is either impossible to satisfy honestly or quietly ignored. | Appoint an external reviewer, or record a time-boxed deviation (`GOV-13`) with compensating controls: founder review, an agent-assisted checklist, and seeded-failure proof for every gate. The deviation must not extend to `G4` (`EES` §7.3). | Founder / architect |
| **R7** | **Bootstrap bypass.** Branch protection cannot exist before the first commit, so the first commit is direct to `main`. | A precedent that "direct commits are fine" survives into EP-01. | Record the bootstrap exception explicitly; enable protection immediately afterwards; prove it with an attempted-and-rejected direct push and self-approved merge. Protection becomes the rule from commit two onwards. | Architect |
| **R8** | **Seeded-failure proof contaminates the repository.** A vulnerable dependency fixture or a fake secret committed to the real branch/tag. | A supply-chain or secret finding in the very history EP-00 creates, and a secret scanner alert that trains people to ignore alerts. | Run seeded proofs on throwaway branches or a scratch repository, never on the tagged commit; fixtures are non-live by construction and are removed and recorded; TG-09 explicitly forbids adding a vulnerable package to the committed lockfile. | Developer |
| **R9** | **Scanning tool becomes a vendor decision.** A SaaS scanner that receives source code is a data-receiving vendor. | New `[FOUNDER]` decision hidden inside a tooling task; possible data-protection defect (`TEC-12`, `TEC-15`). | Prefer host-native scanning. If a third-party scanner is proposed, it stops and is raised as #18-adjacent founder decision with data flow, region and retention stated. | Architect |
| **R10** | **Windows workstation versus Linux CI divergence.** `pnpm-workspace.yaml` restricts `supportedArchitectures` to linux; local development is on Windows, and the gap has already materialised as `F-01` (`@rollup/rollup-win32-x64-msvc`). | "Works on my machine" defects, and a lockfile that resolves native binaries for a platform the developer cannot run. | CI on Linux is the reference. `PC-01` records the local `--force` install as the workstation workaround, with no committed change to `pnpm-workspace.yaml`; any permanent fix is an architect-approved `supportedArchitectures` amendment in a later task. | Architect |
| **R11** | **`minimumReleaseAge` blocks the tool versions needed.** | Pressure to lower the control, which is `[FOUNDER]` and a supply-chain regression. | Choose test-runner and linter versions published more than 7 days ago; never lower the setting, never bypass it with `--ignore-workspace`. | Developer |
| **R12** | **The first commit sweeps unintended artefacts.** | Irreversible provenance of junk, a local secret, or a build output. | Staged-content check before commit (T6, §9); secret scan the tree before push; tag only the reviewed tree. | Developer |
| **R13** | **Phase declared done on configuration rather than evidence.** This is exactly the v1 failure mode. | The first artifact-bearing phase sets a precedent of trusting prose. | Every criterion in §13 requires a URL, SHA, setting export or executed transcript; G5 is a founder signature (`EES` §7.1, §9.3). | Founder / architect |
| **R14** | **Scope creep into EP-01.** Playwright, Testcontainers, Postgres, workspace packages, visual baseline, staging and deployment all look like "obvious next steps" from inside a pipeline task. | EP-00 never exits and EP-01 starts with debt already. | §4.2 out-of-scope list, G0 rulings in §4.3, and a stop-and-report rule for anything that needs a component that does not exist. | Architect |

### 8.2 Assumptions

1. EP-00 was opened on 4 November 2026 by `EP-00-000`; the assumption that the founder would open the phase is satisfied, not pending.
2. Node 22 and pnpm 10.34.9 can be provisioned on at least one executing machine and in the CI image, matching `.mise.toml`.
3. Repository hosting and CI are **decided: GitHub and GitHub Actions**, private repository, protected `main`, native secret and dependency scanning, with `staging`/`production` as definitions only and no deployment in EP-00 (`ARCHITECTURE.md` §16.4 #25).
4. `pnpm build` succeeds on the pinned toolchain: locally through the recorded `--force` frozen install (`PC-01`), and on Linux in CI. The Windows platform-parity gap is documented and does not alter `pnpm-workspace.yaml`.
5. `pnpm typecheck` passes once `EP-00-012` merges; it produced 47 errors on first run and those are now fixed at the type level.
6. No production release occurs in EP-00 and no environment above CI exists; G3 and G4 are not exercised.
7. The prototype is not modified. Formatting, extraction and refactoring of `src/app/App.tsx` are out of scope.
8. No real personal data or live provider credential enters the repository, CI or a fixture.
9. `.gitattributes` LFS filters remain inert because no binary asset is tracked today.
10. The approved documents remain the authority; where two appear to disagree, the owning document wins and the conflict is recorded, not resolved in configuration (`GOV-05`).

### 8.3 Engineering considerations

- **A gate is not a gate until it has failed once.** Every blocking check in EP-00 ships with a seeded-failure transcript. This is the standards' own principle (`§ Limits of this document`: "a control that has never been exercised is not known to work") applied to CI.
- **The frozen lockfile is the contract.** `SEC-56` is absolute: installs are `--frozen-lockfile` only. A build that resolves a different tree than the one reviewed is not the build that was reviewed.
- **Do not touch versions.** EP-00 adds tools; it does not upgrade, dedupe or remove anything. Removing dormant packages is a welcome but separate change (`TEC-17`) and would enlarge the diff past reviewability.
- **`minimumReleaseAge` is a security control, not a preference** (`TEC-09`). It constrains which tool versions may be chosen; it is never the thing that gets adjusted.
- **Lint and format must be incremental, not disabling.** The correct pattern is a curated rule set plus a written baseline of known offenders with a removal condition and an expiry. Writing `/* eslint-disable */` at the top of `App.tsx` is a deviation (`GOV-12`) and a defect.
- **The bootstrap commit is a one-time exception, recorded, never a precedent** (`EES` §7.3: there are no silent exceptions).
- **Configuration is code.** `packageManager`, `engines`, the CI workflow, the lint config and the scanner config are all `[REVIEW]` changes; CI/CD configuration is explicitly critical logic (`QUA-35`).
- **No secret in a bundle, a log, a fixture, a workflow file or a screenshot.** CI logs from EP-00 will be attached as evidence, so redaction is a requirement, not a nicety.
- **Agents prepare, humans approve.** An agent may write the workflow, config and records and open a pull request; it may not create the remote, enable protection, approve a gate, merge, or decide #18 (`EES` §5.5, §5.6). It may not be the sole reviewer of its own work.
- **Evidence is an artifact a third party can inspect** — a run URL, a SHA, a settings export, a transcript. A sentence in a status field is not evidence (`EES` §7.2).
- **Bounded scope limits edits, not understanding.** Every item records what was inspected for reuse; the reuse check is mandatory before `Ready` (`ED-09`).
- **Fast feedback matters more than thoroughness here.** A pipeline that takes twenty minutes to say "typecheck failed" will be bypassed; stage ordering should fail cheap stages first.

---

## 9. Roadmap items

Each item is a candidate work package under the EES §8 protocol. Before it reaches G0 it must be elaborated with class, scope-in/out, reuse check, test plan, evidence, rollback and approver. IDs are stable and never reused.

**Reasoning levels:** *Planning* = reasoning needed to define the package at G0. *Coding* = reasoning needed to implement and verify it. Use the higher level when a supply-chain, security or governance property is involved.

> `EP-00-001` is elaborated at G0 in its own entry below, including the `EES §8.2` fields, so this plan is the single record of the phase and no parallel per-package file is kept. `EP-00-000` is the phase entry record; `000` is used because the identifier space is `nnn`, no ID is reused, and the entry item must sort before the work it authorises.

---

### Stage A — Entry and decision closure

#### EP-00-000 — Phase entry record, G0 rulings and decision closure
- **Task ID:** EP-00-000
- **Feature or Task Name:** Phase entry record and decision closure
- **Objective:** Record every decision EP-00 depends on — all four scope interpretations in §4.3 among them — and establish the true starting position before any item is marked `Ready`.
- **Engineering purpose:** Satisfies G0 for the phase and prevents work on an unresolved `[OPEN]` decision, which is the specific failure mode `EES §8.5` prohibits.
- **Dependencies:** Phase entry gate; founder decision #18; the four G0 rulings in §4.3.
- **Expected Outcome:** A signed entry record linking the approved documents, the #18 decision (provider, host, protection mechanism, scanning features), the four G0 rulings, the second-reviewer arrangement, and each item's blockers. EP-00 becomes `In build` or `Blocked` with named owners — nothing in between.
- **Priority:** Critical · **Status:** `Verified` — approved 4 November 2026; the phase was opened the same day.
- **Reasoning:** Planning — Very High · Coding — Low

---

### Stage B — Reproducible base

#### EP-00-001 — Toolchain, lockfile and first commit
- **Task ID:** EP-00-001
- **Feature or Task Name:** Toolchain, lockfile and first commit
- **Objective:** Make the repository install reproducibly from a committed lockfile and typecheck on the pinned toolchain, and create its first tagged commit.
- **Engineering purpose:** Establishes provenance and a reproducible base; without it, every later gate measures a tree that cannot be rebuilt. Closes `EX-19` and the commit half of `EX-12`.
- **Dependencies:** `EP-00-000`; Node 22 and pnpm 10.34.9 provisioned on the executing machine (`EP-00-002` proves parity, R1); architect sign-off on the G0 record below.
- **Expected Outcome:** `pnpm install --frozen-lockfile` exits 0 on a clean clone; importer parity is exact; `pnpm typecheck` and `pnpm build` exit 0 with recorded output; `.gitignore` verified by `git check-ignore`; the tree is committed and tagged `v0.0.1-bootstrap`; the working tree is clean.
- **Priority:** Critical · **Status:** `Verified` — commit `8029466`, annotated tag `v0.0.1-bootstrap`, frozen install, typecheck and build evidenced; G2 accepted 6 November 2026 under `DEV-001` · Class `[REVIEW]`
- **Reasoning:** Planning — High · Coding — Medium

**G0 record — the `EES §8.2` fields the summary above does not carry.** This is the item's full elaboration. It lives here so the phase has one plan rather than a parallel per-package file.

| Field | Content |
| --- | --- |
| **Scope — in** | (1) Copy `pnpm-lock.yaml` outside the working tree as the rollback artefact. (2) Run `pnpm install` on the pinned toolchain, changing no specifier in `package.json`. (3) Review the lockfile diff against T2 and commit it. (4) `pnpm typecheck`. (5) `pnpm build` as a smoke check. (6) Verify `.gitignore` with `git check-ignore` and correct its stale "no version control yet" comment. (7) Stage, verify the staged list, commit with a message naming `EP-00-001` and its class, tag `v0.0.1-bootstrap`. |
| **Scope — out** | Vitest, Playwright, Testcontainers and the linter (`EP-00-003`, `EP-00-004`); CI provider, pipeline and branch protection (`EP-00-005`–`EP-00-007`); `packageManager` and `engines` (`EP-00-002`); any dependency version change, removal or `minimumReleaseAge` change; any source or document edit; any push, deploy, hosting, DNS or TLS resource; retiring dormant artefacts (`EX-06`, `EX-07`, `EX-17`); rewriting history. |
| **Reuse check** | `.mise.toml` reused as-is — it already pins Node 22 and pnpm 10.34.9. `typecheck` script (`tsc --noEmit`) reused. `.gitignore` reused, with one stale comment corrected. `.gitattributes` LFS rules reused; no binary asset is tracked today, so the filters are inert. `pnpm-workspace.yaml` (`packages: ['.']`) reused; workspace expansion is EP-01. The lockfile is regenerated because it cannot be hand-written. No bootstrap or CI script exists to reuse — `.figma/make/install` and `.figma/make/deploy` are Figma Make wrappers, not a project pipeline. |
| **Rollback** | Before the commit: restore the copied `pnpm-lock.yaml`, and `EX-19` returns to its recorded state. After the commit and before any push: `git tag -d v0.0.1-bootstrap`, then `git update-ref -d HEAD`, which removes the only commit because it has no parent. No data, schema, environment or host is involved. |
| **Approver** | Architect, `[REVIEW]`. The founder is not required: no dependency is added, no vendor or infrastructure is chosen, no deployment happens, and `minimumReleaseAge` is untouched. |

**Test plan.** T1 and T2 fail before the change. T3 has now run: it failed with 47 type errors, which is why `EP-00-012` exists, and passes after it. T4 failed on the Windows resolution of `@rollup/rollup-win32-x64-msvc` and now passes through the recorded local-only `--force` frozen install (`PC-01`); CI on Linux remains the reference environment.

| # | Test | Before → after |
| --- | --- | --- |
| **T1** | `pnpm install --frozen-lockfile` in the working tree before the commit, then in a fresh clone after it | Fails on the importer mismatch (`EX-19`) → exit 0 in both places |
| **T2** | Importer parity: every `package.json` dependency and devDependency appears in the lockfile importer with the same exact specifier; nothing extra remains | Four extra packages, five caret specifiers, two wrong `@types` resolutions → exact parity, `@types/react` 18.3.31, `@types/react-dom` 18.3.7 |
| **T3** | `pnpm typecheck` | 47 type errors, 46 in `App.tsx` → exit 0 after `EP-00-012`, output recorded |
| **T4** | `pnpm build` | Failed on the Windows `@rollup/rollup-win32-x64-msvc` resolution (`F-01`) → exit 0 via the recorded `--force` frozen install (`PC-01`); `dist/` produced and ignored |
| **T5** | Ignore coverage: `git check-ignore -v node_modules dist .env coverage` | Untested → every path matches a rule, and `git status` after install lists no `node_modules/` |
| **T6** | Staged-content check: no `.env*`, `*.pem`, `*.key`, no `node_modules/`; the staged list equals the reviewed tree | Not applicable → exact list, nothing unexpected staged |
| **T7** | LFS safety: `git add` completes without filter errors | Not applicable → no error |

Deny paths are part of the plan: T2 fails when a package is missing, not only when an extra one is present; T5 fails when a path is *not* ignored; T6 fails on an unexpected file, not only on a secret.

**Evidence.**

| # | Artefact |
| --- | --- |
| **E1** | Frozen-install log from a clean clone |
| **E2** | Lockfile diff summary: the four removals, the five restored exact specifiers, the two `@types` resolutions, and any other change called out explicitly |
| **E3** | `pnpm typecheck` output, exit 0 |
| **E4** | `pnpm build` output, exit 0 |
| **E5** | `git check-ignore -v` output |
| **E6** | Commit SHA, `git show --stat v0.0.1-bootstrap`, and the tag in `git tag --list` |
| **E7** | `git status --porcelain` empty after the commit |

**Verified starting position, 4 November 2026.** `.mise.toml` pins `node = "22"` and `npm:pnpm = "10.34.9"` (amended from `10.34.3`, `EP-00-000` v0.8). `package.json` carries 53 dependencies and 9 devDependencies, all exact, with no `packageManager` or `engines` field and scripts `build`, `dev`, `preview`, `format`, `typecheck`. The lockfile importer still lists the four removed MUI/emotion packages (lines 14–25) and five caret specifiers resolving React 19 `@types` (lines 185–212). `.git` is on `main` with zero commits, 95 untracked files and no remote. `git-lfs` 3.8.1 is installed and no binary file is tracked. At that time no `node`, `pnpm`, `npm`, `npx` or `mise` was on `PATH`; `git` was. (On 6 November 2026, Node 22.23.4 and pnpm 10.34.3 are present — see the parity gap in §8 R1.)

#### EP-00-012 — Prototype typecheck remediation
- **Task ID:** EP-00-012
- **Feature or Task Name:** Prototype typecheck remediation
- **Objective:** Make `pnpm typecheck` exit 0 on the pinned toolchain, without suppression, by correcting the genuine type errors that `EP-00-001` T3 revealed.
- **Engineering purpose:** Turns a failing T3 into evidence instead of a stall, and keeps the fix bounded to type annotations rather than a refactor of the visual authority. The item exists because risk R3 materialised: 47 errors, 46 of them in `App.tsx`.
- **Dependencies:** `EP-00-001` T3 failing; founder approval (`[FOUNDER]`, `GOV-09` — the change touches `src/app/App.tsx`); architect review.
- **Expected Outcome:** `pnpm typecheck` exits 0 with no `@ts-ignore`, `@ts-expect-error`, `any` widening or `skipLibCheck` change; the corrections are type-level only (`LucideIcon` for icon props, two missing `Screen` titles, a contextual annotation in `getAdminModuleData`, a `UserConfig` annotation in `vite.figma.config.ts`); no visual, copy, layout or behaviour change; the diff is reviewed under `[FOUNDER]`, because no screenshot baseline exists until EP-01.
- **Priority:** Critical — blocks `EP-00-001` T3 and every later typecheck gate · **Status:** `Verified` — founder-approved; typecheck/build green; architect review covered by `DEV-001` · Class `[FOUNDER]`
- **Reasoning:** Planning — High · Coding — Medium

#### EP-00-002 — Reproducible toolchain contract and CI/local parity
- **Task ID:** EP-00-002
- **Feature or Task Name:** Toolchain contract and version parity
- **Objective:** Prove the pinned toolchain can be provisioned, restate it in `packageManager` and `engines`, and make a wrong version fail loudly on both a workstation and CI.
- **Engineering purpose:** Turns `.mise.toml` from documentation into an enforced contract; prevents the class of defect where CI and a developer resolve different trees.
- **Dependencies:** `EP-00-000`; Node 22 and pnpm 10.34.9 provisioned on at least one machine (R1). The CI half of the parity proof runs in `EP-00-006`, because no pipeline exists at this point.
- **Expected Outcome:** `node -v` and `pnpm -v` match the pinned versions locally, recorded; `packageManager` is set to `pnpm@10.34.9`; `engines` rejects an unsupported Node major; a deliberately wrong version produces a clear failure, not a silent install; `minimumReleaseAge: 10080` unchanged. The parity check is wired into `EP-00-006` so CI reports the same pair.
- **Priority:** High · **Status:** `Verified` — `packageManager`/`engines`, parity gate, local and CI parity proven · Class `[REVIEW]`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage C — Quality toolchain

#### EP-00-003 — Test toolchain: Vitest, scripts and a proven-failing test
- **Task ID:** EP-00-003
- **Feature or Task Name:** Test runner and first real test
- **Objective:** Install Vitest, add the `test` script, and land at least one test that passes now and fails when its asserted behaviour is removed.
- **Engineering purpose:** Creates the test gate that every later phase depends on, and proves the runner is wired rather than merely installed. Closes the runner half of `EX-10`.
- **Dependencies:** `EP-00-001`, `EP-00-002`; architect approval of the test toolchain (`GOV-09`); versions ≥7 days old (`TEC-09`).
- **Expected Outcome:** `pnpm test` exits 0 with at least one meaningful assertion; a seeded removal of the behaviour makes it exit non-zero and the transcript is retained; no DOM/component testing library is added (deferred per §4.3 ruling 2); no coverage threshold is introduced (`QUA-20`, §16 #16 open); the test imports nothing that reaches the network.
- **Priority:** Critical · **Status:** `Verified` — Vitest 4.1.12, 8 tests, seeded failure and CI test job · Class `[REVIEW]`
- **Reasoning:** Planning — High · Coding — Medium

#### EP-00-004 — Linter, format check and the incremental baseline policy
- **Task ID:** EP-00-004
- **Feature or Task Name:** Static quality gate and baseline register
- **Objective:** Add a linter and a `lint` script, wire `oxfmt` as a blocking format check for changed files, and record the pre-existing violation baseline with removal conditions instead of suppressing or reformatting the prototype.
- **Engineering purpose:** Makes "lint is green" a real gate that blocks new defects, while keeping the 3,814-line prototype out of an unreviewable reformat and out of a `[FOUNDER]` edit. This is the item most likely to be done wrongly by disabling rules.
- **Dependencies:** `EP-00-001`, `EP-00-002`; architect decision on the linter and rule set (`GOV-09`: changing a lint rule or CI gate is `[REVIEW]`).
- **Expected Outcome:** `pnpm lint` fails on a seeded violation and passes on the tree; the formatter check blocks an unformatted changed file and ignores untouched prototype files; every pre-existing offender is listed in a baseline register with a file, a rule and an expiry, not hidden by a disable comment; no rule is disabled globally; `src/app/App.tsx` is byte-identical.
- **Priority:** Critical · **Status:** `Verified` — ESLint + 20-entry baseline, changed-files format gate, seeded failures; `App.tsx` unchanged · Class `[REVIEW]`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage D — CI and governance

#### EP-00-005 — CI provider, repository hosting and environment placeholders
- **Task ID:** EP-00-005
- **Feature or Task Name:** CI provider and repository hosting decision
- **Objective:** Record the founder's decision on repository hosting and CI, create the remote, and configure the platform features the later items depend on (status checks, scanning availability, environment placeholders).
- **Engineering purpose:** Removes the last `[OPEN]` dependency between EP-00 and its exit gate (`EES §4.4`), and establishes the enforcement point where gates actually block merges.
- **Dependencies:** `EP-00-000`; founder decision #18 (`[FOUNDER]`); `ARCHITECTURE.md` §16.3 #6 and #8 sign-off.
- **Expected Outcome:** A decision record naming the host, the CI service, the private/public posture, the scanning features, the environments (`staging`, `production` as definitions only), and the exit path; the remote exists and the local repository tracks it; no deploy workflow exists yet; no secret is stored in a workflow file.
- **Priority:** Critical · **Status:** `Verified` — private remote `Oludammy2030/Hivorr`, pushed tree and tag, host features recorded · Class `[FOUNDER]`
- **Reasoning:** Planning — Very High · Coding — Low

#### EP-00-006 — CI pipeline skeleton and per-stage failure proof
- **Task ID:** EP-00-006
- **Feature or Task Name:** Pipeline: install → lint → typecheck → test → build
- **Objective:** Implement the five-stage pipeline on the frozen lockfile and prove each stage independently blocks the build when broken.
- **Engineering purpose:** Produces the project's first G2 evidence and makes every quality claim enforceable. A pipeline whose stages have never failed is indistinguishable from a pipeline that does nothing.
- **Dependencies:** `EP-00-002`, `EP-00-003`, `EP-00-004`, `EP-00-005`.
- **Expected Outcome:** A green run on the tagged commit; five seeded-defect runs (one per stage), each retaining the failed run URL; install uses `--frozen-lockfile`; no stage is `continue-on-error`; the build uses the existing `vite.figma.config.ts` unchanged; total runtime recorded as a baseline for later comparison.
- **Priority:** Critical · **Status:** `Verified` — six-job pipeline; green run 42257026623 and five per-stage seeded-failure runs · Class `[REVIEW]` (CI gate definition)
- **Reasoning:** Planning — Very High · Coding — Medium

#### EP-00-007 — Branch model, protected `main`, review settings and the bootstrap exception
- **Task ID:** EP-00-007
- **Feature or Task Name:** Trunk protection and review enforcement
- **Objective:** Enable the approved branch model — protected `main`, pull request required, required status checks, linear history, no force-push, no self-approval — and record the unavoidable first-commit exception.
- **Engineering purpose:** Turns `QUA-29`–`QUA-31` from words into repository behaviour, which is the only form in which they can be enforced.
- **Dependencies:** `EP-00-005`, `EP-00-006`; second-reviewer arrangement recorded (R6).
- **Expected Outcome:** A direct push to `main` is rejected; a force-push is rejected; a pull request cannot merge with a failing or missing check; a self-approval is rejected; the bootstrap exception is recorded as a deviation with an expiry that has already passed; the settings are exported as evidence, and each rejection attempt is demonstrated rather than asserted. Tag protection for `v0.0.1-bootstrap` is enabled where the chosen host supports it; where it does not, the limitation is recorded in the settings export. It is not a blocking criterion.
- **Priority:** Critical · **Status:** **`Blocked`** — GitHub rejects branch protection on a private repository on this account's plan (HTTP 403, "Upgrade to GitHub Pro or make this repository public"). Direct pushes currently succeed, proving the control is absent · Class `[REVIEW]`
- **Reasoning:** Planning — Very High · Coding — Low

#### EP-00-008 — Secret scanning and dependency scanning
- **Task ID:** EP-00-008
- **Feature or Task Name:** Supply-chain scanning gates
- **Objective:** Enable secret detection (push protection and/or CI scan) and a High/Critical vulnerability gate, each proven with a controlled fixture.
- **Engineering purpose:** Implements `SEC-54`, `SEC-55` and the `GOV-19` supply-chain gates, and closes the last substantive part of `EX-12`.
- **Dependencies:** `EP-00-005`, `EP-00-006`; decision on native versus third-party scanners (native preferred, R9).
- **Expected Outcome:** A non-live seeded credential is detected and blocked, and the fixture is removed from lasting history; a clean run passes; a High/Critical advisory fails the dependency gate — demonstrated on a throwaway branch or scratch repository so no vulnerable package enters the committed lockfile; the audit level and ignore policy are documented; any accepted risk carries an owner and an expiry (`SEC-54`).
- **Priority:** Critical · **Status:** `Verified` — local + CI secret scan, seeded secret failure, zero-advisory audit and seeded High-advisory failure; provider-native scanning unavailable on the private plan · Class `[REVIEW]` (a third-party scanner would be `[FOUNDER]`, `TEC-12`)
- **Reasoning:** Planning — Very High · Coding — Medium

---

### Stage E — Developer bootstrap

#### EP-00-009 — Developer bootstrap and local-run instruction
- **Task ID:** EP-00-009
- **Feature or Task Name:** Verified clone-to-green instruction
- **Objective:** Write the instruction that takes a new contributor from an empty machine to a green local verification, and verify it by executing it on a clean machine.
- **Engineering purpose:** Makes "buildable" a property of the repository rather than of the person who configured it, and establishes the file EP-01 extends when Postgres, the API and the worker exist.
- **Dependencies:** `EP-00-002`–`EP-00-006`; the §4.3 ruling 1 scope.
- **Expected Outcome:** A written, executed sequence — provision toolchain → clone → frozen install → typecheck → lint → test → build → dev server — with the exact expected output; a transcript from a clean machine; an explicit statement of what EP-01 adds (Postgres, API, worker, seed data); no instruction references a component that does not exist; and a stated warning that `pnpm dev` binds `0.0.0.0:8443` as a local tool only, never exposed (`DEP-31`, `EX-16`).
- **Priority:** High · **Status:** `Verified` — `DEVELOPER_BOOTSTRAP.md` executed on a clean clone; dev server HTTP 200 · Class `[REC]` (documentation only)
- **Reasoning:** Planning — Medium · Coding — Low

---

### Stage F — Exit evidence and closure

#### EP-00-010 — Phase evidence pack and traceability index
- **Task ID:** EP-00-010
- **Feature or Task Name:** Evidence index
- **Objective:** Assemble one index mapping every EP-00 objective, technical goal and completion criterion to an inspectable artifact.
- **Engineering purpose:** Makes the exit gate auditable by someone who does not trust the author, which is the entire point of the evidence rule (`EES §9.3`).
- **Dependencies:** Every item from `EP-00-000` through `EP-00-009`.
- **Expected Outcome:** One index linking: the entry record, the frozen-install log, the lockfile diff summary, the typecheck/lint/test/build run URLs, the five seeded-failure runs, the tag SHA, the protection settings export and rejection attempts, the scanning detection records, and the bootstrap transcript; every criterion has an artifact or is explicitly marked unmet.
- **Priority:** Critical · **Status:** `Verified` — evidence index created; it marks C8/C14 unmet and C10 partial · Class `[REC]`
- **Reasoning:** Planning — High · Coding — Low

#### EP-00-011 — G5 phase closure record
- **Task ID:** EP-00-011
- **Feature or Task Name:** G5 closure record
- **Objective:** Present the evidence and the review outcome to the founder for phase closure.
- **Engineering purpose:** Makes closure a signed decision rather than an inference from finished tasks, and records what EP-01 inherits.
- **Dependencies:** `EP-00-010`; architect's recommendation.
- **Expected Outcome:** A signed closure record stating the outcome, the tagged commit SHA and green run that satisfied the gate, the closure statements for `EX-19`, `EX-10` (partial, per §4.3 ruling 2) and `EX-12`, accepted residual risks, and the EP-01 entry conditions inherited — or a documented decision to hold.
- **Priority:** Critical · **Status:** **`Blocked`** — G5 founder signature not provided; depends on `EP-00-007`, which is blocked by the host plan · Class `[FOUNDER]`
- **Reasoning:** Planning — Medium · Coding — Low

---

## 10. Expected phase outcome

EP-00 succeeds when the following are true, demonstrated by artifacts rather than described:

1. **The base is reproducible.** A clean clone installs from the frozen lockfile on the pinned toolchain, with no resolution drift and exact importer parity.
2. **The tree is verified.** Typecheck, lint, test and build all pass in CI on the same commit, not on four different machines.
3. **The gates are real.** Each of the five stages has been shown to fail on a seeded defect, and each failure is retained as evidence.
4. **History exists.** A first commit is tagged `v0.0.1-bootstrap`, and its pipeline is green.
5. **The trunk is protected.** Direct push, force-push and self-approval are rejected by the host, proven by attempted-and-rejected runs.
6. **The supply chain is watched.** A seeded secret is caught, a High/Critical advisory blocks, and neither control was ever a `continue-on-error` step.
7. **A newcomer can work.** One written instruction, executed on a clean machine, takes a contributor from nothing to green locally.
8. **The prototype is visually untouched.** No screen, token, type size, colour, copy or business rule changed; the only source edit is `EP-00-012`'s type-level correction, reviewed under `[FOUNDER]`, and the Figma Make preview still builds.
9. **Nothing is claimed without proof.** The evidence index has an artifact behind every criterion.

---

## 11. Phase completion criteria

EP-00 is complete only when all of the following hold, each with a linked artifact in `EP-00-010`.

| # | Criterion | Evidence |
| --- | --- | --- |
| **C1** | Entry gate satisfied and phase opened | Signed `EP-00-000` record; founder decision #18; the G0 rulings in §4.3 |
| **C2** | Lockfile is correct and frozen | Clean-clone `pnpm install --frozen-lockfile` log; importer-parity diff showing only the four removals, five specifier corrections and two `@types` resolutions |
| **C3** | Toolchain is enforced, not documented | Local and CI `node -v` / `pnpm -v` recorded; wrong-version failure transcript |
| **C4** | Typecheck is green and unsuppressed | `pnpm typecheck` exit 0 in CI; no new suppression in the diff |
| **C5** | The test gate works | Green `pnpm test` run **and** a seeded-failure run proving it can fail |
| **C6** | The lint and format gate works | Green lint run, seeded violation failure, baseline register with per-entry expiry, `App.tsx` byte-identical |
| **C7** | The pipeline blocks per stage | Five seeded-failure run URLs plus one green run on the tagged SHA; no stage ignores failure |
| **C8** | `main` is protected | Settings export, plus attempted-and-rejected direct push, force-push and self-approved merge |
| **C9** | Supply chain is watched | Seeded-secret detection record; High/Critical advisory failure record; both fixtures removed from lasting history |
| **C10** | First commit exists and is tagged | Tag `v0.0.1-bootstrap`; `git rev-parse v0.0.1-bootstrap` equal to the recorded commit SHA; `git show --stat`; green run URL on that SHA |
| **C11** | A newcomer can work | Bootstrap instruction plus an executed clean-machine transcript |
| **C12** | No visual, copy or behavioural change in the prototype | Diff of `EP-00-012` (type annotations and two empty `TITLES` entries only) reviewed under `[FOUNDER]`; no `documents/Context/*` change; `pnpm build` green in CI. A screenshot baseline does not exist until EP-01, so the claim rests on the diff and the approval, not on a visual diff. |
| **C13** | Evidence is complete | Evidence index with no unlinked row; unmet items marked, not implied |
| **C14** | Closure is signed | `EP-00-011` founder signature with accepted residual risks and the EP-01 entry conditions |

**A criterion without an artifact is unmet.** EP-00 is not complete because its tasks are `Completed` (`EES §9.3`).

**Verified position, 6 November 2026.** C1–C7, C9, C11–C13 are **met**. C8 is **unmet**: GitHub requires GitHub Pro (paid) for branch protection on a private repository, and decision #18 requires private. C14 is **unmet**: G5 is a founder signature and has not been given. C10 is **partially met**: `v0.0.1-bootstrap` resolves to `8029466`, but the pipeline did not exist at that commit, so a green run on that exact SHA cannot be produced without rewriting the tag or history; the green run is on evidence commit `1668c30`. The traceability table is `documents/Task-Implementation/EP-00/EP-00-010 — Phase evidence pack and traceability index.md`.

---

## 12. What EP-00 deliberately does not prove

Recorded so the exit gate is not overread:

- That the product works. One test proves the runner, not the application.
- That typecheck coverage is complete. `tsconfig.json` covers `src` and the two Vite configs; nothing else exists.
- That lint is clean. A baseline of pre-existing violations remains, with expiries.
- That the database, API, worker or any environment exists. None is created.
- That deployment works. There is no staging and no artifact promotion; G3 and G4 are untouched.
- That the second-reviewer problem is solved permanently. A deviation may be standing and time-boxed.
- That CSP, `EX-01` inline styles, `EX-14` `noUncheckedIndexedAccess`, or `EX-09` `skipLibCheck` are addressed. All remain open (`standards` §13.3, §16 #15).
- That dependency scanning is comprehensive. It detects known advisories in the registry it queries, and nothing more.
- That the repository is "production-ready". It is buildable, testable, reviewable and blockable — nothing further.

---

## 13. Transition handed to EP-01

EP-01 inherits, and must not rebuild: the repository with history and a tag, the protected trunk and review settings, the five-stage pipeline, the toolchain contract and parity check, the committed lockfile, the Vitest runner and its configuration, the lint and format gate with its baseline register, both scanning gates, the developer bootstrap instruction, the evidence-index convention, and the `EP-` identifier convention.

EP-01 must add, and EP-00 must not pre-empt: the workspace topology and package boundaries, the ten-module skeleton, PostgreSQL and the migration runner, Playwright and Testcontainers and Testing Library, the visual-regression baseline, the OpenAPI diff stage, migration lint and `db diff`, staging topology, build-once artifact digests, and the three entry decisions EP-01 is blocked on (#1 provider, #17 hosting/DNS/TLS, #14 sign-in identifier).

Also carried forward explicitly: `EX-10` is **partially closed** (runner only), and the second-reviewer arrangement (EES §11.2 #2) must be settled or re-deviated before EP-01 touches authentication, capability or migration code — where `GOV-09` requires two reviewers and CI configuration no longer covers it.

---

## 14. Revision history

| Version | Date | Change | Authority |
| --- | --- | --- | --- |
| 1.0 | 2026-11-04 | Approved phase plan as reviewed. | Founder / architect |
| 1.1 | 2026-11-06 | Reconciled with `EP-00-000` and `EP-00-001`'s decision record: phase status `Ready` → `In build`; the four G0 rulings recorded (`D-02`–`D-05`) rather than three pending; decision #18 closed and recorded as GitHub / GitHub Actions; pnpm pin `10.34.3` → `10.34.9` throughout, including `packageManager`; R1 restated as a parity gap and R5 as an unprovisioned host; build state corrected to the recorded local `--force` install (`PC-01`); `EP-00-000` → `Verified`; `EP-00-001` `Blocked` → `In build`; `EP-00-012` added to §9, §6 and the critical path, with the prototype-change exception recorded in §4.2 and C12; stale pre-decision blockers and the stale closing paragraph replaced. Marked final. | `GOV-09`, `QUA-38` — the plan follows the record of record |
| 1.2 | 2026-11-06 | Executed and evidenced the phase: toolchain contract, Vitest, ESLint/format, six-job CI, secret and dependency scanning, developer bootstrap and evidence index. Statuses: `EP-00-001`–`006`, `008`–`010`, `012`, `013` → `Verified`; `EP-00-007` → `Blocked` (GitHub private-repo protection requires Pro; 403 recorded); `EP-00-011` → `Blocked` (G5 unsigned). C1–C7, C9, C11–C13 met; C8 and C14 unmet; C10 partial (tag predates CI). Phase remains `In build`; it is **not** 100% complete and not closed. | `GOV-09`, `QUA-38`, `EES` §9.3 |

---

**Plan status:** revision 1.2 — implementation complete for EP-00 except the host-enforced protection and the G5 signature. No future phase has been analysed or planned; no application product code has been written. The only source edit in the phase remains `EP-00-012`'s type-only correction, committed in `8029466`.

**Current position, 6 November 2026.** The phase is `In build`; implementation is verified and the exit gate is blocked on two external conditions, not on engineering work. `EP-00-007` needs GitHub Pro (paid) or an approved hosting/visibility change; `EP-00-011` needs the founder's G5 signature. `EP-00-010` marks C8 and C14 unmet and C10 partial rather than implying completion. The evidence pack, work-package records, green CI run and seeded-failure runs are in place; `F-01` remains a recorded Windows-only workaround with Linux CI as the reference. The phase closes only when the founder resolves those conditions and signs the G5 record.
