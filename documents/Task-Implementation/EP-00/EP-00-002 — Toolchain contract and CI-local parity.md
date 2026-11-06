# Work Package Record — EP-00-002
## Reproducible toolchain contract and CI/local parity

| Field | Value |
|---|---|
| **ID** | `EP-00-002` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Turn `.mise.toml` into an enforced contract: pin pnpm in `packageManager`, reject a wrong Node major in `engines`, add a parity check, and prove local and CI report the same pair. |
| **Class** | `[REVIEW]` — toolchain and quality-gate configuration (`GOV-09`). |
| **Status** | `Verified` — implementation and evidence recorded 2026-11-06. Formal independent review is covered by the time-boxed deviation `DEV-001`. |
| **Origin** | `EP-00` §9; `EP-00-000` amendment v0.8 (`10.34.9` pin); risk R1. |

### Scope — in

1. `packageManager: "pnpm@10.34.9"` in `package.json`.
2. `engines.node: ">=22.0.0 <23"` and `engines.pnpm: "10.34.9"`.
3. `scripts/check:toolchain` backed by `scripts/version-parity.mjs`.
4. A CI step that runs the same check after a frozen install.
5. A negative test proving a wrong version fails.

### Scope — out

No dependency version change beyond the tool additions approved by `EP-00-003`/`004`; no change to
`minimumReleaseAge`, `supportedArchitectures`, the Node pin in `.mise.toml`, the lockfile contract or
any application source.

### Reuse check

Reused `.mise.toml` as the pin of record; reused the existing `pnpm` invocation and CI job shape; no
new version manager was introduced. The parity script uses Node's built-in `child_process` and reads
`package.json`; no third-party dependency was added for it.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | `pnpm check:toolchain` with Node 22.23.4 and pnpm 10.34.9 | **Pass** — `toolchain: OK — node 22.23.4, pnpm 10.34.9` |
| 2 | Negative: `node scripts/version-parity.mjs --node=20.0.0 --pnpm=10.34.3` | **Pass (fails as intended)** — exit 1, both mismatches reported |
| 3 | CI parity after frozen install | **Pass** — `install` job green in run 42257026623 |
| 4 | `minimumReleaseAge: 10080` unchanged | **Pass** — present in `pnpm-workspace.yaml`; no bypass used |
| 5 | Wrong pnpm is rejected rather than silently used | **Pass** — exact string compare against `packageManager` |

### Evidence

- `package.json` — `packageManager`, `engines`, `check:toolchain`.
- `scripts/version-parity.mjs`.
- `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/evidence/toolchain.log`.
- `.../evidence/seeded-toolchain-failure.log`.
- CI green run: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623> on `1668c30`.
- CI job name: `install (frozen lockfile and toolchain parity)`.

### Rollback

Remove the `packageManager`/`engines` fields and the script/CI step. No data, schema or environment is
involved.

### Approver

Architect (`[REVIEW]`). `DEV-001` covers the second-reviewer gap until `EP-00-007`.

### Residual

The workstation's PATH `pnpm` is 10.34.3; the mise-managed 10.34.9 is the verified runner. The parity
gate is what makes that visible rather than silent. CI uses 10.34.9 from the workflow and passes.
