# Work Package Record — EP-00-004
## Linter, format check and the incremental baseline policy

| Field | Value |
|---|---|
| **ID** | `EP-00-004` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Add a real lint gate and a changed-files format gate, and record the pre-existing violations in a written baseline instead of suppressing or reformatting the prototype. |
| **Class** | `[REVIEW]` — lint rule set and CI gate (`GOV-09`). |
| **Status** | `Verified` — implemented and evidenced 2026-11-06. Formal independent review remains under `DEV-001`. |
| **Origin** | `EP-00` §9; ruling `D-04`; risk R4 and `EX-01`. |

### Decision — linter selected

ESLint `9.39.5` with a curated correctness rule set. It is a real, widely used linter, runs on the
pinned Node line, and produces no native-platform dependency (unlike `oxlint`, whose native bindings
are skipped by the repository's Linux-only `supportedArchitectures`). `oxfmt` remains the formatter
(`D-04`). This decision is recorded here because `EP-00-000` deliberately deferred the choice to this
package.

### Scope — in

1. `eslint.config.js` with a curated rule set over all source, test and script files.
2. `scripts/lint.mjs` — runs ESLint and fails on any violation not in the baseline.
3. `.lint-baseline.json` — 20 pre-existing `@typescript-eslint/no-unused-vars` entries in
   `src/app/App.tsx`, each with file, rule, line and message, plus a removal condition and
   `2026-12-31` expiry.
4. `scripts/format-check.mjs` — runs `oxfmt --check` on changed JavaScript/TypeScript files only.
5. Seeded-failure proofs for lint and format.

### Scope — out

No global rule disable; no `/* eslint-disable */`; no reformat of `src/app/App.tsx`; no change to its
content. Formatting rules are deliberately left to `oxfmt`, not duplicated in ESLint.

### Reuse check

Reused `oxfmt` `0.2.0` already in the project, the existing `format` script, and the existing
`src/app/App.tsx` without editing it. No second formatter, style guide or config format was added.
The baseline mechanism reads ESLint's own JSON results; it does not introduce a separate lint engine.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | `pnpm lint` on the clean tree | **Pass** — 20 known baseline violations, 0 new, 0 stale |
| 2 | Seeded lint violation in `src/ep00-lint-seed.ts` | **Pass (fails as intended)** — exit 1 |
| 3 | Remove the seed and rerun | **Pass** — exit 0 |
| 4 | `pnpm format:check` on the clean tree | **Pass** — 5 changed files formatted |
| 5 | Seeded unformatted changed file | **Pass (fails as intended)** — exit 1 |
| 6 | Remove the seed and rerun | **Pass** — exit 0 |
| 7 | Untouched `src/app/App.tsx` is not reformatted | **Pass** — skipped by the changed-files scope; no diff |
| 8 | `src/app/App.tsx` byte-identical to `v0.0.1-bootstrap` | **Pass** — `git diff` empty for that path |
| 9 | Baseline expiry is enforced | **Implemented** — expiry `2026-12-31`; expiry check fails closed |
| 10 | CI lint and format stage | **Pass** — run 42257026623 |
| 11 | Seeded CI lint failure | **Pass (fails as intended)** — run 42255491891 |

### Evidence

- `eslint.config.js`, `scripts/lint.mjs`, `.lint-baseline.json`, `scripts/format-check.mjs`.
- `.../evidence/lint.log`, `.../evidence/format.log`.
- `.../evidence/seeded-lint-failure.log`, `.../evidence/seeded-format-failure.log`.
- CI green: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623>.
- CI seeded lint failure: <https://github.com/Oludammy2030/Hivorr/actions/runs/42255491891>.

### Baseline register

The baseline exists because the prototype is a single 3,814-line founder-owned file. Fixing unused
locals or reformatting it is not an EP-00 change. `EP-01` removes the baseline as the prototype is
decomposed; the expiry forces that review by 2026-12-31.

### Known limitation

`oxfmt` `0.2.0` mishandled a TypeScript object-type literal during this work (it removed the
separators between members). The affected test was corrected to use newline separators. This is a
formatter limitation, not a change to the lint policy; it is recorded so a future contributor does
not mistake the failure for a type error.

### Rollback

Remove the ESLint config, scripts, baseline and format script; restore the scripts block. No
application source is affected.

### Approver

Architect (`[REVIEW]`); `DEV-001` for the second-reviewer gap.
