# EP-01-012 — Ten-module boundary skeleton

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-012` |
| **Task title** | Ten-module boundary skeleton |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — structural boundary enforcement |
| **Execution order** | 7 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage B |
| **Dependencies** | `EP-01-010`, `EP-01-011` |

## 2. Objective

Make module ownership structural. The server exposes exactly the ten modules in `ARCHITECTURE.md`
§9.2, each with one public `index.ts`; a module may not import another's internals, repository or
tables; the dependency graph is acyclic; the six activity modules stay empty boundaries until their
owning phase. A linter, not a convention, enforces all of it.

## 3. Scope

### 3.1 Included

- Create the ten module folders: `identity`, `profile`, `market`, `services`, `errands`, `logistics`,
  `finance`, `messaging`, `admin`, `platform`.
- Give each a public `index.ts` as its only cross-module interface.
- Move `grants` under `identity` (the architecture assigns grants to identity).
- Move `health` out of `modules/` to `server/src/health/`; it is infrastructure, not a module.
- Add a platform public interface (`appendAudit`) and route identity/grant audit writes through it,
  removing direct `platform.audit_log` access.
- Extend `scripts/lint-boundaries.mjs` with module rules: missing/unknown module, missing index,
  activity-module code, cross-module internal and repository imports, controller SQL, direct
  cross-schema table access, and dependency cycles.
- Add six seeded-failure proofs for those rules.
- Clean `server/dist` before compiling so a module move cannot leave stale output.
- Add a filesystem test for the ten-module skeleton and empty activity schemas.

### 3.2 Excluded

- Adding tables, endpoints or domain rules to the six activity modules. Their owning phases do so
  and must add the module to the linter's reviewed code list.
- A full audit service, read model, retention or integrity checks — `036`.
- A repository abstraction for identity. The skeleton enforces the rule when repositories appear; it
  does not invent a repository layer now.
- Capability declaration or enforcement — `035`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Exactly ten module folders exist, matching the architecture. | Architecture §9.2 |
| R-02 | Each module has one public `index.ts`. | Plan `012` |
| R-03 | A module may import another module only through its `index.ts`. | Architecture §9.3 |
| R-04 | A module may not import another module's repository. | Architecture §9.3 |
| R-05 | A module may not read or write another module's tables. | Architecture §9.2, §9.3 |
| R-06 | The module dependency graph is acyclic. | Architecture §9.3 |
| R-07 | A controller does not execute SQL or import a repository. | Architecture §14.3 |
| R-08 | Only identity, profile, platform and admin may contain code in EP-01. | Plan `012` outcome |
| R-09 | The six activity modules contain no code, tables or endpoints. | Plan `012` outcome |
| R-10 | Each rule has a failing fixture, not just a passing repository. | Plan `004` evidence rule |
| R-11 | The build output reflects the current module set. | Deterministic build |
| R-12 | No new runtime dependency or secret. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-010` bootstrap | **REQUIRES_REVIEW** — supplies the module registration |
| `EP-01-011` pipeline | **REQUIRES_REVIEW** — supplies the shared common layer |
| `EP-01-004` CI | **REQUIRES_REVIEW** — runs `lint:boundaries` and `test:gates` |
| Node `fs`/`path` | Standard library; no new package |

## 6. Implementation plan

1. Read the architecture module table, import rules and directory responsibilities.
2. Move `grants` under `identity`; move `health` to `server/src/health`; update imports.
3. Add `index.ts` to all ten modules; keep six of them export-only.
4. Add `modules/platform/audit.ts` and route identity/grant audit writes through it.
5. Extend the boundary linter with the module rules and a `--root` fixture switch.
6. Add six seeded proofs to `test-ci-gates.mjs`.
7. Add `tests/module-boundaries.test.ts` for the filesystem invariants.
8. Add a clean step to `build:server`; rebuild and inspect `server/dist/modules`.
9. Run typecheck, lint, boundaries, formatting, tests and builds; record results.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `scripts/lint-boundaries.mjs` | **Extend** | It already owns workspace boundaries; module rules belong in the same gate |
| `scripts/test-ci-gates.mjs` | **Extend** | The seeded-proof harness already exists |
| `modules/identity/*` | **Keep in place** | Moving every file into layer folders would churn imports and tests without changing the boundary |
| `modules/grants/*` | **Move under identity** | Grants are identity-owned; a separate folder would be an eleventh module |
| `modules/health/*` | **Move out** | Health is infrastructure, not a domain module |
| `platform.audit_log` | **Reuse; expose one function** | Platform owns the table; modules call `appendAudit` |
| `DatabaseService`, `PoolClient` | **Reuse** | The audit write accepts the caller's transaction client |
| `audience-declaration.test.ts` | **Update paths** | The controllers moved |
| `server/src/index.ts` | **Leave** | It is the package entry, not a module, so the cross-module index rule does not apply |
| `build:server` | **Extend with a clean step** | `tsc` cannot remove stale output |

**Must not be duplicated:** a second module list, a second boundary linter, a second audit insert,
or a second health route.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/modules/{profile,market,services,errands,logistics,finance,messaging,admin}/index.ts` | **New** — boundary only |
| `server/src/modules/identity/index.ts` | **New** — public identity and grants surface |
| `server/src/modules/platform/audit.ts` | **New** — the one platform write EP-01 needs |
| `server/src/modules/platform/index.ts` | **New** — public platform surface |
| `server/src/modules/identity/grants/*` | **Moved** from `modules/grants` |
| `server/src/health/health.controller.ts` | **Moved** from `modules/health` |
| `server/src/modules/identity/identity.service.ts` | Audit write via `appendAudit` |
| `server/src/modules/identity/grants/grants.service.ts` | Audit write via `appendAudit`; imports updated |
| `server/src/app.module.ts` | Registration paths updated |
| `scripts/lint-boundaries.mjs` | Module rules and `--root` |
| `scripts/test-ci-gates.mjs` | Six seeded boundary proofs |
| `scripts/clean-server-build.mjs` | **New** |
| `package.json` | `build:server` cleans first |
| `tests/module-boundaries.test.ts` | **New** |
| `tests/audience-declaration.test.ts` | Import paths updated |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Exactly ten module directories exist; no unknown module directory. |
| DoD-02 | Every module has an `index.ts`; no index exports a controller. |
| DoD-03 | The six activity modules contain `index.ts` and nothing else. |
| DoD-04 | A cross-module internal import fails the boundary lint. |
| DoD-05 | A cross-module repository import fails. |
| DoD-06 | A direct cross-schema table access fails. |
| DoD-07 | A module dependency cycle fails. |
| DoD-08 | A controller that executes SQL fails. |
| DoD-09 | Identity and grants no longer insert into `platform.audit_log`; they call the platform interface. |
| DoD-10 | `pnpm lint:boundaries` passes the repository and `pnpm test:gates` passes 17/17. |
| DoD-11 | `pnpm typecheck`, `lint`, `format:check`, `build:all`, `build:server` pass. |
| DoD-12 | `server/dist/modules` contains exactly the ten modules; `health` is at the server root. |
| DoD-13 | No new runtime dependency, secret or CI permission. |
| DoD-14 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- Deleting a module folder, adding an eleventh, or removing an `index.ts` fails the boundary gate.
- Importing `../market/service` from identity fails; importing `../market` succeeds.
- A cycle between two module indexes fails with the cycle path in the output.
- Adding a file to `market/` fails until the reviewed code list is changed.
- A direct `select ... from market.orders` inside identity fails.
- The real repository passes with no grandfather list.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm lint:boundaries` |
| T-02 | `pnpm test:gates` — 17 seeded proofs, six of them boundary rules |
| T-03 | `pnpm test -- tests/module-boundaries.test.ts` |
| T-04 | `pnpm typecheck`, `lint`, `format:check` |
| T-05 | `pnpm build:all`, `build:server`; inspect `server/dist/modules` |
| T-06 | `node -e "require('./server/dist/modules/platform').appendAudit"` |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The activity code list is phase-scoped. | Adding code to an activity module requires editing `CODE_MODULES` in the reviewed linter, which makes the change visible. |
| The filesystem test asserts no activity tables. | It is a statement about EP-01; the owning phase updates the test when it adds its table. |
| The linter parses imports and SQL with regular expressions. | It targets the repository's import style and schema-qualified SQL; the seeded proofs cover both false directions. |
| A public index could re-export an entire internal module. | The rule allows the index to choose the surface; review still owns what it exports. |
| `platform.set_identity_context` remains a direct platform function call. | It is a function call, not table access; moving it behind the platform interface is a follow-up for `035`/`036`. |
| `tsc` leaves stale outputs. | `build:server` removes `server/dist` first; verified by inspection. |
| Windows cannot load argon2. | Unrelated suites still fail locally (`F-10`); this task's evidence is filesystem- and lint-based. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Started** | 2026-11-09 |
| **Completed** | 2026-11-09 |
| **Execution record** | `execution-records/EP-01-012.md` |
