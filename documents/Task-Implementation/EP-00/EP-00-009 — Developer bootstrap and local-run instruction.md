# Work Package Record — EP-00-009
## Developer bootstrap and local-run instruction

| Field | Value |
|---|---|
| **ID** | `EP-00-009` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Write the clone-to-green instruction for what exists today, execute it on a clean clone, and state exactly what EP-01 adds. |
| **Class** | `[REC]` — documentation only. |
| **Status** | `Verified` — instruction written and executed on a clean clone 2026-11-06. |
| **Origin** | `EP-00` §9; ruling `D-02`; `DEP-31`/`EX-16` (dev-server exposure warning). |

### Scope — in

1. Root `DEVELOPER_BOOTSTRAP.md`.
2. Provision toolchain → clone → frozen install → typecheck → lint → test → build → dev server.
3. Exact expected output and failure explanations.
4. The Windows `--force` note for native optional packages (`PC-01`).
5. The `0.0.0.0:8443` local-only warning.
6. The explicit EP-01 extension list (Postgres, API, worker, seed data, Playwright, Testcontainers,
   Testing Library, visual baseline, OpenAPI diff).

### Scope — out

No Postgres, API, worker, seed data or integration-test tooling is created. Those do not exist in
EP-00 and are explicitly reassigned to EP-01 by ruling `D-02`.

### Reuse check

Reused the repository's existing `pnpm` scripts and `.mise.toml`; no second bootstrap script or
wrapper was created. The instruction calls the same commands CI calls, so it cannot drift from the
pipeline without becoming visibly wrong.

### Test plan and result — clean-clone execution

The work was executed in `C:\Users\user\AppData\Local\Temp\ep00-clean-clone`, cloned from the local
repository at commit `673b71c` (the code commit before the evidence documents).

| # | Step | Result |
|---|---|---|
| 1 | `git clone --no-hardlinks . <temp>` | **Pass** |
| 2 | `pnpm install --frozen-lockfile` (plain, Windows) | **Pass** install; native Rollup binding absent, so test/build cannot run |
| 3 | `pnpm install --force --frozen-lockfile` (recorded Windows workaround) | **Pass**; lockfile unchanged |
| 4 | `pnpm check:toolchain` | **Pass** — Node 22.23.4, pnpm 10.34.9 |
| 5 | `pnpm typecheck` | **Pass** — exit 0 |
| 6 | `pnpm lint` | **Pass** — 20 baseline, 0 new |
| 7 | `pnpm test` | **Pass** — 8/8 |
| 8 | `pnpm build` | **Pass** — `dist/` produced |
| 9 | `pnpm dev`, HTTP `GET http://127.0.0.1:8443/` | **Pass** — HTTP 200, `id="root"` present |
| 10 | Server stopped after the check | **Pass** |
| 11 | Instruction references no component that does not exist | **Pass** — Postgres/API/worker are explicitly marked EP-01 |

### Evidence

- `DEVELOPER_BOOTSTRAP.md`.
- `.../evidence/clean-clone-install.log` — plain install and the Windows native-package limitation.
- `.../evidence/clean-clone-install-force.log`.
- `.../evidence/clean-clone-toolchain.log`.
- `.../evidence/clean-clone-typecheck.log`.
- `.../evidence/clean-clone-lint.log`.
- `.../evidence/clean-clone-test-after-force.log`.
- `.../evidence/clean-clone-build-after-force.log`.
- `.../evidence/dev-server.log` — HTTP 200 check.

### Rollback

Delete `DEVELOPER_BOOTSTRAP.md`. No code or configuration depends on it.

### Approver

Architect (`[REC]`, reviewed as documentation); no founder decision required.

### Residual

The clean machine was a clean **clone** on the same Windows workstation, not a fresh operating-system
image. The Linux CI run is the reference for the toolchain and build. The Windows `--force` path is
recorded rather than hidden, and CI remains the authoritative Linux proof.
