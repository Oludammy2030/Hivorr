# EP-00 Evidence Pack and Traceability Index

| Field | Value |
|---|---|
| **Document ID** | `EP-00-010` |
| **Phase** | `EP-00` — Execution Readiness |
| **Class** | `[REC]` |
| **Status** | `Verified` for the index itself; it records both met and unmet criteria. |
| **Date** | 2026-11-06 |
| **Verified code commit** | `1668c30` (`chore(security): override minimatch to the patched line`) |
| **Green CI run** | <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623> |

> This index does not turn an unmet criterion into a met one. C8, C14 and the tag-run part of C10 are
> explicitly unmet; EP-00 is therefore not closed. See `EP-00-011`.

## 1. Work-package evidence

| Item | Document | Status | Primary artifact |
|---|---|---|---|
| `EP-00-000` | `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` | `Verified` | Signed entry record, decisions D-01–D-07 |
| `EP-00-001` | `documents/Task-Implementation/EP-00/EP-00-001 — Toolchain, lockfile and first commit.md` | `Verified` | Commit `8029466`, tag `v0.0.1-bootstrap` |
| `EP-00-002` | `EP-00-002 — Toolchain contract and CI-local parity.md` | `Verified` | `package.json`, parity script, CI install job |
| `EP-00-003` | `EP-00-003 — Test toolchain, scripts and a proven-failing test.md` | `Verified` | `tests/readiness.test.ts`, seeded test run |
| `EP-00-004` | `EP-00-004 — Linter, format check and baseline register.md` | `Verified` | `eslint.config.js`, `.lint-baseline.json`, seeded lint run |
| `EP-00-005` | `EP-00-005 — CI provider, repository hosting and environment placeholders.md` | `Verified` (implementation; see record) | Remote, private visibility, Dependabot status |
| `EP-00-006` | `EP-00-006 — CI pipeline skeleton and per-stage failure proof.md` | `Verified` | `.github/workflows/ci.yml`, six run URLs |
| `EP-00-007` | `EP-00-007 — Branch model, protected main and bootstrap exception.md` | **`Blocked`** | GitHub 403: plan does not allow private-repo protection |
| `EP-00-008` | `EP-00-008 — Secret scanning and dependency scanning.md` | `Verified` | Scanner, CI security job, seeded secret run, audit |
| `EP-00-009` | `EP-00-009 — Developer bootstrap and local-run instruction.md` | `Verified` | `DEVELOPER_BOOTSTRAP.md`, clean-clone transcript |
| `EP-00-010` | this document | `Verified` | This index |
| `EP-00-011` | `EP-00-011 — G5 phase closure record.md` | **`Blocked`** | No founder signature; depends on `007` |
| `EP-00-012` | `EP-00-012 — Prototype typecheck remediation.md` | `Verified` | Type-only corrections in `8029466` |
| `EP-00-013` | `EP-00-013 — Dependency security remediation.md` | `Verified` (implementation; review pending) | Zero-advisory audit, bundle hash equality |

## 2. Completion criteria traceability

| # | Criterion | Artifact | Status |
|---|---|---|---|
| **C1** | Entry gate satisfied and phase opened | `EP-00-ENTRY-RECORD.md` §3, §5, §11 | **Met** |
| **C2** | Lockfile correct and frozen | `.../evidence/clean-clone-install-force.log`, `install.log`, CI install job 42257026623 | **Met** |
| **C3** | Toolchain enforced, not documented | `package.json`, `scripts/version-parity.mjs`, `toolchain.log`, `seeded-toolchain-failure.log`, CI install job | **Met** |
| **C4** | Typecheck green and unsuppressed | `typecheck.log`, CI typecheck job, suppression scan in `EP-00-012` | **Met** |
| **C5** | Test gate works | `test.log`, `seeded-test-failure.log`, CI run 42255635543 | **Met** |
| **C6** | Lint and format gate works | `lint.log`, `format.log`, seeded failures, `.lint-baseline.json`, App hash equality | **Met** |
| **C7** | Pipeline blocks per stage | Five seeded runs: 42255323075, 42255491891, 42256095641, 42255635543, 42255596119; green 42257026623 | **Met** |
| **C8** | `main` is protected | GitHub API 403 for both branch protection and ruleset creation; direct pushes succeeded | **UNMET** — paid host capability |
| **C9** | Supply chain watched | `secrets.log`, `deps.log`, CI secret run 42256348422, scratch High-advisory failure | **Met** (provider-native scanning unavailable; CI/local control in force) |
| **C10** | First commit exists and tagged | Tag `v0.0.1-bootstrap` → `8029466`; green run on `1668c30` | **Partially met** — tag and SHA are exact; no green run can exist on the tag because the pipeline did not exist then |
| **C11** | A newcomer can work | `DEVELOPER_BOOTSTRAP.md`; clean-clone transcript; dev server HTTP 200 | **Met** |
| **C12** | No visual, copy or behavioural change in prototype | `git diff v0.0.1-bootstrap..HEAD -- src/app/App.tsx` empty; no `EP-00-012`-era visual edit | **Met** |
| **C13** | Evidence complete | This index; every row links an artifact or is marked unmet | **Met** |
| **C14** | Closure signed | None | **UNMET** — founder G5 signature not provided; `007` blocked |

## 3. Run index

| Purpose | Run |
|---|---|
| Green pipeline on `1668c30` | <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623> |
| Stage failure — install | <https://github.com/Oludammy2030/Hivorr/actions/runs/42255323075> |
| Stage failure — lint | <https://github.com/Oludammy2030/Hivorr/actions/runs/42255491891> |
| Stage failure — typecheck | <https://github.com/Oludammy2030/Hivorr/actions/runs/42256095641> |
| Stage failure — test | <https://github.com/Oludammy2030/Hivorr/actions/runs/42255635543> |
| Stage failure — build | <https://github.com/Oludammy2030/Hivorr/actions/runs/42255596119> |
| Stage failure — secret scan | <https://github.com/Oludammy2030/Hivorr/actions/runs/42256348422> |

All seeded branches and pull requests were closed and deleted; none was merged. The tag and root commit
were not touched.

## 4. Commit and tag evidence

| Artefact | Value |
|---|---|
| Root commit | `8029466` |
| Annotated tag object | `e6fcd38` |
| Tag peeled commit | `8029466` |
| Verified evidence commit | `1668c30` |
| Remote | `https://github.com/Oludammy2030/Hivorr.git` |
| Visibility | private |

Verify locally:

```sh
git rev-parse v0.0.1-bootstrap          # tag object
git rev-parse 'v0.0.1-bootstrap^{}'     # commit
git show --stat v0.0.1-bootstrap
```

## 5. Evidence directory

Sanitized local transcripts are committed under:

`documents/Engineering-Execution/Engineering-Phase-Records/EP-00/evidence/`

They cover install, toolchain parity, lint, format, typecheck, test, build, secret scan, dependency
audit, every seeded failure, clean-clone replay and the dev-server HTTP check. They are transcripts,
not substitutes for the CI run URLs.

## 6. Unmet items — explicit statement

EP-00 is **not** 100% complete and is not closed. The reasons are external to the code:

1. **C8 / `EP-00-007`** — GitHub requires Pro (paid) for branch protection on a private repository.
   The founder decision #18 forbids making the repository public. No engineering change can create
   the feature.
2. **C14 / `EP-00-011`** — G5 is a founder signature. The founder has not reviewed and signed the
   closure record, and the record cannot be signed while C8 is unmet.
3. **C10** — the bootstrap tag predates CI. The pipeline is green on the evidence commit, but a run
   URL on `8029466` cannot be produced without rewriting history or the tag; neither is permitted.

Everything else in EP-00 is implemented and evidenced. The phase remains `In build` until the two
external conditions are resolved.
