# Work Package Record — EP-00-008
## Secret scanning and dependency scanning

| Field | Value |
|---|---|
| **ID** | `EP-00-008` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Make secret detection and a High/Critical vulnerability gate real, each proven with a controlled fixture. |
| **Class** | `[REVIEW]` — supply-chain gate; a third-party scanner would be `[FOUNDER]` under `TEC-12`. |
| **Status** | `Verified` — both gates implemented, proven, and green in CI 2026-11-06. |
| **Origin** | `EP-00` §9; `SEC-54`/`SEC-55`/`GOV-19`; `EP-00-005` findings `F-05-01`–`F-05-03`; `EP-00-013`. |

### Secret detection

| Layer | Control |
|---|---|
| Local push | `.githooks/pre-push` runs `scripts/secret-scan.mjs` over tracked content and blocks on a match. |
| CI | `pnpm security:secrets` runs the same scanner in the `security` job. |
| Provider | GitHub native secret scanning is **not available** on a private repository on this account's plan (`F-05-01`). The local and CI controls are the compensating measures; this limitation is explicit. |

The scanner recognises GitHub tokens, fine-grained PATs, AWS access keys, private-key headers, Slack
tokens, Google API keys, OpenAI-shaped keys, and VFD/Paystack-shaped secrets. It scans tracked text
content only; it is a guard, not a guarantee, and it does not scan full history.

### Dependency gate

`pnpm security:deps` runs `pnpm audit --audit-level=high`. High and Critical findings exit non-zero;
Moderate and Low are reported but do not block, matching `SEC-54`. The committed tree currently has
**zero** known advisories after the `minimatch` override.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | Local clean scan | **Pass** — `secret-scan: clean` |
| 2 | Local seeded GitHub-shaped non-live token | **Pass (blocks)** — exit 1, `github-token` |
| 3 | Local seeded private-key header | **Pass (blocks)** — exit 1, `private-key-block` |
| 4 | CI seeded non-live token on a throwaway branch | **Pass (blocks)** — run 42256348422, `security` job failed |
| 5 | CI clean security job | **Pass** — run 42257026623, `security` success |
| 6 | `pnpm audit --audit-level=high` on the committed tree | **Pass** — `No known vulnerabilities found` |
| 7 | Seeded High advisory in a scratch repository (`lodash` 4.17.21) | **Pass (fails as intended)** — exit 1, High advisory reported |
| 8 | Fixture removed from lasting history | **Pass** — branch and pull request closed/deleted; never merged or tagged |

### Evidence

- `scripts/secret-scan.mjs`, `.githooks/pre-push`, `scripts/security` entry in `package.json`,
  `.github/workflows/ci.yml`.
- `.../evidence/secrets.log`, `.../evidence/deps.log`,
  `.../evidence/seeded-dependency-gate-failure.log`.
- CI seeded secret failure: <https://github.com/Oludammy2030/Hivorr/actions/runs/42256348422>.
- CI green security job: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623>.

### Dependabot status

GitHub reports 25 open alerts on the default branch. Inspection of the alert metadata shows that
**all 24 High/Moderate/Low alerts on runtime packages are in the dormant `.figma/backup/package.json`**
(react-router and vite copies), which is committed as-is under `EX-06`/`EX-07` and is not installed by
the build. The only root-lockfile alert was `minimatch` Moderate, now patched by an exact override to
`11.0.1`. No High/Critical advisory remains in the shipped/lockfile tree. The dormant backup is
recorded, not deleted, because retiring it is a separate scope decision.

### Residual and accepted risk

- Native GitHub secret scanning/push protection remains unavailable until GitHub Secret Protection or
  a CI-provider-native equivalent is approved. Owner: project lead. Revisit at the next provider
  review; the local and CI scans are the controls in force.
- The local hook must be enabled once per clone (`git config core.hooksPath .githooks`). The bootstrap
  instruction says so. A contributor who skips it is still covered by the CI job on push/PR.
- Dependabot alerts on `.figma/backup` are dormant-tree noise; they are not production dependencies.
  Owner: architect; remove with the dormant artefacts in a later approved change.

### Rollback

Remove the hook wiring, scanner invocation and audit step. The seeded fixtures were never merged. No
production data or real credential was involved.

### Approver

Architect (`[REVIEW]`); native scanning remains a `[FOUNDER]` cost decision if the provider route is
chosen instead of the CI/local control.
