# Work Package Record — EP-00-006
## CI pipeline skeleton and per-stage failure proof

| Field | Value |
|---|---|
| **ID** | `EP-00-006` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Implement install → lint → typecheck → test → build on GitHub Actions and prove each stage independently blocks the run when broken. |
| **Class** | `[REVIEW]` — CI gate definition (`QUA-35`). |
| **Status** | `Verified` — green run and five seeded-failure runs recorded 2026-11-06. Formal independent review remains under `DEV-001`. |
| **Origin** | `EP-00` §9; decision #18 (GitHub / GitHub Actions); `EX-12`. |

### Scope — in

1. `.github/workflows/ci.yml` with jobs: `install`, `lint`, `typecheck`, `test`, `build`, `security`.
2. Frozen-lockfile install in every job.
3. Toolchain parity in `install`.
4. No `continue-on-error`; later jobs depend on earlier jobs.
5. Per-stage seeded-failure runs on throwaway pull-request branches.

### Scope — out

No deployment, environment promotion, staging resource, coverage threshold, Playwright,
Testcontainers, migration lint, OpenAPI diff or visual-regression stage.

### Reuse check

Reused the existing `pnpm` scripts, the existing `vite.figma.config.ts` build, and the repository's
own security scripts. No bespoke CI shell library or composite action was added. Actions are pinned to
commit SHAs, not floating tags.

### Pipeline

| Job | Depends on | Commands |
|---|---|---|
| `install` | — | `pnpm install --frozen-lockfile`, `pnpm check:toolchain` |
| `lint` | `install` | `pnpm lint`, `pnpm format:check` |
| `typecheck` | `lint` | `pnpm typecheck` |
| `test` | `typecheck` | `pnpm test` |
| `build` | `test` | `pnpm build` |
| `security` | `install` | `pnpm security:secrets`, `pnpm security:deps` |

### Test plan and result

| Stage | Green evidence | Seeded-failure evidence | Result |
|---|---|---|---|
| install | run 42257026623, job `install` success | run 42255323075, job `install` failure, all later jobs skipped | **Pass** |
| lint | run 42257026623, job `lint` success | run 42255491891, job `lint` failure | **Pass** |
| typecheck | run 42257026623, job `typecheck` success | run 42256095641, job `typecheck` failure | **Pass** |
| test | run 42257026623, job `test` success | run 42255635543, job `test` failure, build skipped | **Pass** |
| build | run 42257026623, job `build` success | run 42255596119, job `build` failure, install/lint/typecheck/test all passed first | **Pass** |
| security | run 42257026623, job `security` success | run 42256348422, job `security` failure on a non-live fixture | **Pass** |

### Evidence

- `.github/workflows/ci.yml`.
- Green run on `1668c30`: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623>.
- Seeded install: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255323075>.
- Seeded lint: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255491891>.
- Seeded typecheck: <https://github.com/Oludammy2030/Hivorr/actions/runs/42256095641>.
- Seeded test: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255635543>.
- Seeded build: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255596119>.
- Seeded secret scan: <https://github.com/Oludammy2030/Hivorr/actions/runs/42256348422>.
- Sanitized local transcripts in `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/evidence/`.

### Runtime baseline

The green run completed in about two minutes across six jobs on GitHub-hosted runners. This is the
first CI runtime baseline; later phases compare against it rather than against an estimate.

### Rollback

Delete the workflow file. No application source, dependency or environment is involved. The seeded
branches and pull requests were closed and deleted; none was merged.

### Approver

Architect (`[REVIEW]`); `DEV-001` covers the second-reviewer gap for CI configuration.

### Residual

The green run is on the EP-00 evidence commit, not on `v0.0.1-bootstrap`; that tag predates the
workflow and cannot be retroactively run without rewriting provenance. See `EP-00` C10 and
`EP-00-010`.
