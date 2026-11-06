# Work Package Record — EP-00-003
## Test toolchain: Vitest, scripts and a proven-failing test

| Field | Value |
|---|---|
| **ID** | `EP-00-003` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Install Vitest, add the `test` script, and land tests that pass now and fail when the asserted behaviour is removed. |
| **Class** | `[REVIEW]` — test toolchain (`GOV-09`). |
| **Status** | `Verified` — implemented and evidenced 2026-11-06. Formal independent review remains under `DEV-001`. |
| **Origin** | `EP-00` §9; `EX-10` runner half; ruling `D-03`. |

### Scope — in

1. Exact-pinned `vitest` `4.1.12` (published 2026-10-15, older than the 7-day cutoff).
2. `test` and `test:watch` scripts.
3. `tests/readiness.test.ts`, covering the repository contract and the secret-scan control.
4. A seeded-failure proof that removes an asserted behaviour and makes `pnpm test` fail.

### Scope — out

No DOM/component testing library, no jsdom, no Playwright, no Testcontainers, no coverage threshold.
Those are EP-01 work under ruling `D-03` and `QUA-20`.

### Reuse check

Reused the existing `pnpm` runner, the repository's own `scripts/secret-scan.mjs`, and Node's built-in
`child_process`/`fs` modules. No application module was modified to create a test seam, and no test
framework beyond Vitest was added.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | `pnpm test` on the clean tree | **Pass** — 1 file, 8 tests |
| 2 | Repository contract: `packageManager`, `engines`, required scripts, exact direct dependencies, `minimumReleaseAge`, Linux architecture, mise alignment | **Pass** |
| 3 | Secret-scan control: clean file passes | **Pass** |
| 4 | Secret-scan control: GitHub-shaped non-live token blocks | **Pass** — exit 1, `github-token` |
| 5 | Secret-scan control: private-key header blocks | **Pass** — exit 1, `private-key-block` |
| 6 | Seeded failure: remove the `github-token` rule from the scanner, run `pnpm test` | **Pass (fails as intended)** — exit 1, 1 failed / 7 passed |
| 7 | Restore the scanner and rerun | **Pass** — exit 0, 8 tests |
| 8 | CI test stage | **Pass** — run 42257026623, job `test` |
| 9 | Seeded CI failure: broken assertion on a throwaway branch | **Pass (fails as intended)** — run 42255635543, job `test` failed, later stages skipped |

### Evidence

- `package.json` — `vitest` `4.1.12`, `test`, `test:watch`.
- `tests/readiness.test.ts`.
- `.../evidence/test.log`.
- `.../evidence/seeded-test-failure.log`.
- CI green: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623>.
- CI seeded failure: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255635543>.

### Rollback

Remove the test file and the devDependency, restore the scripts, run `pnpm install`. The seeded branch
was deleted and never merged.

### Approver

Architect (`[REVIEW]`); time-boxed deviation `DEV-001`.

### Residual

The suite proves the runner and the repository/security contract, not application behaviour. This is
stated in `EP-00` §12 and is not a defect in this task.
