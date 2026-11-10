# EP-01-026 — Repository and transaction foundation

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-026` |
| **Task title** | Repository and transaction foundation |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — data-access foundation |
| **Execution order** | 16 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-021`–`EP-01-025` |

## 2. Objective

Provide one unit of work for every mutating service: acquire one connection, open one explicit
transaction, set the RLS identity context, run parameterised queries, commit or roll back, and
release the connection. A failing transaction must never leak a connection or a context into another
request.

## 3. Scope

### 3.1 Included

- `withTransaction(pool, options, work)` in `server/src/db/transaction.ts`.
- `TransactionContext` with `client`, parameterised `query`, and `setIdentity`.
- `DatabaseService.withTransaction` as the injected entry point.
- Adopt the helper in the grant create/revoke transactions.
- Unit tests for commit, rollback, context, re-setting context, commit failure, parameterisation and
  connection isolation.
- Document that module repositories arrive in `030` and must use this unit of work; schema scoping
  remains enforced by `lint-boundaries`.

### 3.2 Excluded

- Migrating every identity-service transaction to the helper. The service already opens explicit
  transactions and sets context; the mechanical migration belongs to `030` when repositories are
  extracted.
- A repository base class. There is no repository yet; inventing one before `030` would be
  speculative.
- Retry/circuit-breaker policy. `ENG-14` timeouts are already on the pool; retry classification is a
  later concern.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | One connection per unit of work. | Plan `026` |
| R-02 | One explicit transaction; commit on success, rollback on failure. | Plan `026` |
| R-03 | The RLS context is set before work when supplied. | Plan `026` |
| R-04 | A caller can set the context again inside the work. | Registration flow |
| R-05 | Queries are parameterised; values are never interpolated. | `AFS-IO`, SEC-22 |
| R-06 | The connection is released on every path. | Pool safety |
| R-07 | No context or connection leaks between requests. | Plan `026` outcome |
| R-08 | A service uses the helper for its mutations. | Plan `026` engineering purpose |
| R-09 | Module repositories are schema-scoped. | Plan `026` outcome |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-021`–`025` | **REQUIRES_REVIEW** — schema, roles, RLS and context helpers |
| `pg` 8.16.3 | Existing |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the pool factory and every manual transaction block.
2. Add `withTransaction` and `TransactionContext`.
3. Add `DatabaseService.withTransaction`.
4. Adopt it in grant create/revoke.
5. Add `tests/transaction.test.ts`.
6. Run local gates; record the integration evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `createDatabasePool` | **Reuse** | Timeouts and TLS are already correct |
| `DatabaseService` | **Extend** | One injected entry point |
| `platform.set_identity_context` | **Reuse** | The context setter is already a database function |
| Grant create/revoke transactions | **Migrate** | Straightforward blocks prove the helper in a real service |
| Identity service transactions | **Leave for `030`** | Many flows; extracting repositories is the right change |
| `lint-boundaries` | **Reuse** | Cross-schema table access is already rejected |

**Must not be duplicated:** a second pool factory, a second context setter, or a second transaction
wrapper.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/db/transaction.ts` | **New** — unit of work |
| `server/src/db/database.service.ts` | **Extend** — `withTransaction` |
| `server/src/modules/identity/grants/grants.service.ts` | Create/revoke use the helper |
| `tests/transaction.test.ts` | **New** — seven transaction rules |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No schema, migration, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The helper acquires one connection and begins one transaction. |
| DoD-02 | It sets the context when supplied and skips it otherwise. |
| DoD-03 | Work errors roll back, rethrow the original error and release. |
| DoD-04 | Commit errors roll back and release. |
| DoD-05 | A caller can set a new context inside the work. |
| DoD-06 | Query values are passed as parameters, never interpolated. |
| DoD-07 | Two transactions never share a connection. |
| DoD-08 | Grant create/revoke use the helper. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | `pnpm test:identity` still passes against Postgres. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The unit test observes `begin → set context → query → commit → release`.
- A thrown work error observes `begin → rollback → release` and the same error instance.
- A failed commit observes `begin → commit → rollback → release`.
- The parameter test proves a SQL-injection-shaped value stays in the values array.
- The isolation test uses two connections and two distinct contexts.
- Grant integration tests still pass in CI after the refactor.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/transaction.test.ts` |
| T-02 | `pnpm test:identity` — CI database job (grant paths) |
| T-03 | `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The grant refactor changes transaction semantics. | The helper mirrors the old begin/commit/rollback/release order; integration tests run in CI. |
| Identity service still uses manual transactions. | It already sets context and releases; `030` migrates it when extracting repositories. |
| A commit failure can leave the client in an unknown state. | The helper rolls back and releases; pg destroys a broken client. |
| Repository schema scoping is not a runtime guard. | `lint-boundaries` rejects cross-schema table access at build time; repositories arrive in `030`. |
| No Postgres locally. | The unit test proves orchestration; the integration suite proves the real client. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the grant integration suite after the refactor; `030` adopts the helper in identity repositories |
| **Execution record** | `execution-records/EP-01-026.md` |
