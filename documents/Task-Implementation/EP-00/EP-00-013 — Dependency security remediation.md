# Work Package Record — EP-00-013
## Dependency security remediation

| Field | Value |
|---|---|
| **ID** | `EP-00-013` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Remove the known vulnerabilities from the pinned dependency tree without changing application behaviour, so the dependency gate required by `EP-00-006`/`EP-00-008` can be green on the bootstrap commit. |
| **Class** | `[REVIEW]` — supply-chain change (`TEC-08`, `TEC-09`, `SEC-54`). Opened as a scope amendment to `EP-00`, which otherwise forbids dependency changes (`EP-00` §8.3, `TEC-17`); approved by the project lead on 2026-11-06. |
| **Status** | `In review` — implemented and verified; awaiting architect review before merge. |
| **Origin** | `EP-00-005` findings `F-05-02` and `F-05-03`. Enabling Dependabot surfaced 30+ advisories in the pinned tree, including High and Critical severities. |

### Scope — in

Version moves only, all within the already-installed major line, all pinned exactly:

| Package | From | To | Advisories addressed |
|---|---|---|---|
| `react-router` | 7.13.0 | 7.18.5 | XSS, DoS, turbo-stream (High) |
| `vite` | 6.3.5 | 6.4.5 | dev-server file read (High), low |
| `rollup` | 4.52.2 | 4.59.0 | path traversal (High) |
| `tar` | 7.5.1 | 7.5.22 | arbitrary file write, DoS (**Critical**) |
| `lodash` | 4.17.21 | 4.18.1 | code injection (High) |
| `nanoid` | 3.3.11 | 3.3.20 | High |
| `picomatch` | 4.0.3 | 4.0.7 | ReDoS (High) |
| `browserslist` | 4.26.2 | 4.29.5 | High |
| `source-map-js` | 1.2.1 | 1.2.2 | High |
| `postcss` | 8.5.6 | 8.5.32 | moderate |
| `baseline-browser-mapping` | 2.8.32 | 2.11.34 | moderate |
| `@babel/core` | 7.28.4 | 7.29.6 | low |

Ripple updates, all consequences rather than decisions: the `@babel/*` family, `caniuse-lite`, `electron-to-chromium`, `node-releases`, `update-browserslist-db`.

### Scope — out

Any major-version upgrade; any removal or replacement of a package; any change to `minimumReleaseAge`, `supportedArchitectures` or the frozen-lockfile contract; any source, UI, token or behaviour change; any new dependency; any CI configuration; any automated-merge of a Dependabot pull request.

### Reuse check

Reused the existing `pnpm.overrides` mechanism already present in `package.json` (it pinned `vite` for supply-chain reasons). Reused the existing scripts — `typecheck`, `build`, `install --frozen-lockfile` — and `pnpm audit`. No new tool, script or configuration was added for the dependency work. The only new repository asset in this change is `scripts/secret-scan.mjs` and `.githooks/pre-push`, which belong to `EP-00-005` finding `F-05-01`, not to this item.

### Dependencies

`EP-00-005` (repository live, Dependabot enabled); `EP-00-001` lockfile; `EP-00-012` closed so the typecheck baseline is trustworthy; project-lead approval of the scope amendment.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | `pnpm audit` before | **54 advisories** — 1 critical, 27 high, 21 moderate, 5 low |
| 2 | All targets published ≥ 7 days (`minimumReleaseAge: 10080`) | **Pass** — newest target published 2026-10-28, cutoff 2026-10-30 |
| 3 | All targets within the installed major line | **Pass** — no major bump |
| 4 | `pnpm install` | **Pass** |
| 5 | `pnpm audit` after | **0 advisories** |
| 6 | `pnpm typecheck` | **Pass** — exit 0 |
| 7 | `pnpm build` | **Pass** — exit 0, and the emitted bundle hashes are **identical** to the pre-upgrade build (`index-HWyG1aKw.js`, `index-BCGXCL5Z.css`), which is the strongest available evidence that application behaviour did not move |
| 8 | `pnpm install --frozen-lockfile` | **Pass** — exit 0 |
| 9 | Lockfile shape | **Pass** — 0 packages added, 0 removed; only the listed versions changed |
| 10 | `package.json` diff | **Pass** — exactly two pins and the override block |

### Evidence

- `pnpm audit` before: 54 advisories (`pnpm-audit.json`), reproduced by GitHub as 94 vulnerabilities / 37 high
- `pnpm audit` after: 0 advisories (`pnpm-audit-3.json`)
- `pnpm typecheck`, `pnpm build`, `pnpm install --frozen-lockfile`: all exit 0
- Bundle hash equality across the upgrade: `dist/assets/index-HWyG1aKw.js`, `dist/assets/index-BCGXCL5Z.css`
- Rollback artefacts: `package.json.bak`, `pnpm-lock.yaml.bak`

### Finding — `rollup` 4.66.0 breaks this Vite version

The first attempt pinned the newest patched Rollup, `4.66.0`. `pnpm build` then failed:

```
Source phase import "vite/modulepreload-polyfill" in "index.html" must be external.
Source phase imports are only supported for external modules.
```

Rollup 4.66 is newer than Vite 6.4.5 expects. The override was moved back to the **minimum patched** version, `4.59.0`, which satisfies the advisory and builds. Recorded because "newest patched" is the intuitive choice and is wrong here; `EP-00-002`'s toolchain contract work should note the Vite/Rollup pairing.

### Rollback

Restore `package.json` and `pnpm-lock.yaml` from the backups, then `pnpm install --frozen-lockfile`. No database, schema, secret or environment is involved. Reverting the commit achieves the same result.

### Approver

Architect, `[REVIEW]`, for the supply-chain diff and the lockfile shape. The scope amendment itself was approved by the project lead on 2026-11-06. `DEV-001` covers the second-reviewer gap until `EP-00-007`.

### Follow-up

- Close `EP-00-005` findings `F-05-02` and `F-05-03` by citing this record.
- Do **not** merge Dependabot pull requests created before this change; they are superseded.
- Re-run `pnpm audit` in `EP-00-006` as the dependency gate, and in `EP-00-008` as the scanning evidence.
- Record the Vite/Rollup pairing constraint in `EP-00-002`.
