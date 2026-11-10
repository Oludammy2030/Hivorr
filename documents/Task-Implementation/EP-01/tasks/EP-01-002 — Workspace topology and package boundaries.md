# EP-01-002 — Workspace topology and package boundaries

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-002` |
| **Task title** | Workspace topology and package boundaries |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — build graph and import boundaries |
| **Execution order** | 2 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage A |
| **Related phase record** | `EP-01-ENTRY-RECORD.md` §5 (technical selections), §6.3 (four bundles, eight deployments) |

## 2. Objective

Establish one pnpm workspace in which the root web app (the Figma Make prototype host), `server/`,
`packages/design`, `packages/shared`, `packages/api-client`, `apps/control`, `apps/staff` and
`apps/partner` install, typecheck, build and lint together, while the prototype and the Figma Make
preview remain untouched. Import boundaries between the apps, the server and the shared packages must
be structurally enforceable from the first commit.

## 3. Scope

### 3.1 Included

- `pnpm-workspace.yaml` package globs and workspace-wide install behaviour.
- Package identity and exports for every workspace package.
- One root TypeScript program that resolves every workspace package.
- Boundary lint that fails on cross-app imports, app→server imports and shared→framework imports.
- Root build scripts that build the main bundle plus the three privileged bundles and the server.
- Verification that the prototype and its Figma Make configuration are unchanged.

### 3.2 Excluded

- The ten backend module folders, module layering and the dependency-cruiser-style acyclic module
  graph — that is `012`.
- OpenAPI generation and the generated client — that is `013`.
- Extracting design primitives — that is `051`.
- Changing the prototype, `theme.css`, the Figma config or the visual identity.
- Deploying any bundle — that is `060`–`063`.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The root web app stays at the repository root so the Figma Make preview keeps working. | Plan §5.1, §14.2 |
| R-02 | `server/`, `packages/*` and `apps/*` are members of the pnpm workspace. | Plan §1, §4.1 |
| R-03 | Every workspace package has a unique, stable package name and a resolvable entry. | Plan §11, `002` |
| R-04 | Import boundaries are enforced by a command that CI runs and that fails when violated. | `AGENTS.md` §1; plan §11 |
| R-05 | `pnpm typecheck` resolves server, packages and apps in one program and exits 0. | Plan TG-01 |
| R-06 | `pnpm build:all` builds the main bundle and `control`, `staff`, `partner`. | Plan §5.3, `054` |
| R-07 | The frozen lockfile installs every workspace dependency. | Plan TG-01 |
| R-08 | `src/app/App.tsx`, `src/styles/theme.css` and the Figma Make configuration are not modified. | `AGENTS.md` §2; plan §4.2 |
| R-09 | The four-bundle / eight-deployment ruling is reflected in package names and hosts. | Entry record §6.3 |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-001` entry gate | **COMPLETED** — phase `Ready`, opened 2026-11-07 |
| Managed Postgres provider | Decided — Supabase |
| Boundary-lint selection | Recorded as `dependency-cruiser`; as-built is `scripts/lint-boundaries.mjs` — deviation `F-03` |
| Test stack | Vitest 4.1.12 present; `EX-10` full residual approved |
| Toolchain | node 22.23.4, pnpm 10.34.9, parity green |

## 6. Implementation plan

Because the workspace was built before this record existed, the plan is expressed as
**verify → close gaps → evidence**, not as fresh construction.

1. Read the approved plan, entry record, `ARCHITECTURE.md` §8.12, §14.1 and the workspace files.
2. Confirm the workspace globs cover `.`, `apps/*`, `server`, `packages/*`.
3. Enumerate every workspace package and confirm package name, `type`, `exports`, `types`.
4. Confirm the root `tsconfig.json` includes `src`, `apps`, `packages`, `server` and both Vite configs,
   and that `@hivorr/shared` resolves through `paths` while the other packages resolve through their
   `exports`.
5. Run the boundary lint and confirm it detects violations by seeding a deliberate one.
6. Run `pnpm install --frozen-lockfile`, `pnpm typecheck`, `pnpm build:all`, `pnpm build:server`.
7. Verify `src/app/App.tsx`, `src/styles/theme.css` and `vite.figma.config.ts` are unchanged against
   the bootstrap tag.
8. Record findings (`F-03`, `F-10`) and update the tracker.

**Gap closure performed in this execution:** none required in the repository. The only failure was
workstation state: the server dependencies had never been installed locally. The frozen install
resolved it without a repository change.

## 7. Existing components and reusability

| Component | Use |
|---|---|
| `pnpm-workspace.yaml` | Workspace membership and the Linux-only architecture policy |
| Root `tsconfig.json` | Single program across `src`, `apps`, `packages`, `server` |
| `packages/shared/tsconfig.json` + `tsconfig.build.json` | Per-package typecheck and declaration build |
| `scripts/lint-boundaries.mjs` | Structural import enforcement (reused, not replaced) |
| `scripts/build-portals.mjs` | Builds the three privileged bundles |
| `scripts/finalize-server-build.mjs` | Finalises the server output |
| `scripts/version-parity.mjs` | Toolchain parity gate |
| `.github/workflows/ci.yml` | Runs install, lint, boundaries, typecheck and build |
| `tests/readiness.test.ts` | Repository contract, including the Linux reference architecture |

No new dependency, tool or package was added.

## 8. Files and systems affected

| Path | State |
|---|---|
| `pnpm-workspace.yaml` | Existing; verified |
| `pnpm-lock.yaml` | Existing; frozen install verified |
| `tsconfig.json` | Existing; verified |
| `packages/shared/package.json`, `tsconfig.json`, `tsconfig.build.json` | Existing; verified |
| `packages/design/package.json`, `src/index.ts` | Existing; boundary only |
| `packages/api-client/package.json`, `src/index.ts` | Existing; boundary only |
| `server/package.json`, `tsconfig.build.json` | Existing; verified |
| `apps/control|staff|partner/package.json`, `vite.config.ts` | Existing; verified |
| `scripts/lint-boundaries.mjs` | Existing; verified |
| `scripts/build-portals.mjs` | Existing; verified |
| `src/app/App.tsx`, `src/styles/theme.css`, `vite.figma.config.ts` | Untouched |
| `documents/Task-Implementation/EP-01/*` | Created by this record |

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | Workspace globs include `.`, `apps/*`, `server`, `packages/*` | `pnpm-workspace.yaml` |
| DoD-02 | All seven workspace packages exist with unique names and resolvable entries | package manifests |
| DoD-03 | `pnpm install --frozen-lockfile` succeeds from the committed lockfile | command output |
| DoD-04 | `pnpm typecheck` exits 0 | command output |
| DoD-05 | `pnpm build:all` produces the main bundle and `control`, `staff`, `partner` | build output |
| DoD-06 | `pnpm build:server` exits 0 | command output |
| DoD-07 | `pnpm lint:boundaries` exits 0 and a seeded violation makes it exit non-zero | two transcripts |
| DoD-08 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap` | `git diff --stat` empty |
| DoD-09 | No new dependency, font, colour or framework introduced | manifest diff |
| DoD-10 | Findings `F-03` and `F-10` recorded | tracker + overview |

## 10. Acceptance criteria

- A new contributor can run one install and one typecheck and have every workspace package compile.
- Importing `@hivorr/app-control` from `packages/shared`, or `@hivorr/server` from an app, fails a
  command that CI runs.
- The root web app still renders the prototype through the Figma Make configuration, unchanged.
- The four privileged/app bundles build into `dist/` without touching the prototype source.
- Any deviation from the recorded tool selections is visible in the phase overview, not hidden.

## 11. Testing and validation

| Test | Method | Result |
|---|---|---|
| T-01 | `pnpm check:toolchain` | **Pass** — node 22.23.4, pnpm 10.34.9 |
| T-02 | `pnpm install --frozen-lockfile` | **Pass** — 36.3 s, lockfile respected |
| T-03 | `pnpm typecheck` | **Pass** — exit 0 after install |
| T-04 | `pnpm lint:boundaries` | **Pass** — 35 files |
| T-05 | `pnpm build:all` | **Pass** — main + control + staff + partner |
| T-06 | `pnpm build:server` | **Pass** — API/worker build |
| T-07 | Seeded boundary violation | **Pass (fails as intended)** — see execution record |
| T-08 | Prototype diff against `v0.0.1-bootstrap` | **Pass** — empty for `App.tsx` and `theme.css` |
| T-09 | `pnpm test` | **Partial** — 8 files/55 tests pass; 4 suites cannot load on Windows because the Linux-only optional dependency set omits the argon2 native binding. CI on Linux is the reference (`F-10`) |

## 12. Risks and considerations

| Risk | Impact | Handling |
|---|---|---|
| Tool-selection drift (`graphile-worker`, `dependency-cruiser`, Supabase CLI) | The architecture record and the code disagree | Recorded as `F-03`; architect must ratify or direct rework before `004`, `013`, `014` close. Not silently accepted. |
| Single root TS program instead of composite project references | Plan wording says "tsconfig references" | Recorded interpretation: package resolution is enforced by `exports` + `paths` in one program. Adding `composite` references would change build output for no requirement. Architect may direct otherwise. |
| Linux-only `supportedArchitectures` | Windows workstations cannot run argon2 suites | Keep the EP-00 control; CI is the reference; documented as `F-10`. Do not change the policy to make a local run pass. |
| Adding packages without consumers (`design`, `api-client`) | Dead boundaries could drift | They are intentional seams with explicit ownership in `051`/`013`; no UI was added early. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Execution date** | 2026-11-09 |
| **Execution record** | `execution-records/EP-01-002.md` |
| **Findings raised** | `F-03` (tool-selection deviations), `F-10` (workstation/platform limitation) |
| **Follow-ups** | Architect ruling on `F-03` before `004`/`013`/`014` close; `003` may start |
