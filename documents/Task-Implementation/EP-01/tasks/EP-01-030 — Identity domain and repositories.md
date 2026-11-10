# EP-01-030 — Identity domain and repositories

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-030` |
| **Task title** | Identity domain and repositories |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — domain model and data access |
| **Execution order** | 17 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-023`, `EP-01-026` |

## 2. Objective

Keep identity invariants pure and independent of HTTP, ORM and provider SDKs. Provide identity-scoped
repositories over the unit of work, and make registration use them so an account, user, credential
and owner membership are created together — never a grant or an activity activation.

## 3. Scope

### 3.1 Included

- `server/src/modules/identity/domain/identity.ts`: statuses, membership roles, grant types and
  scopes, email normalisation, grant validity, single-owner invariant, registration side-effect
  flags.
- `IdentityRepository`: registration write plus account, user, membership, grant and device reads.
- A runtime schema guard: the repository rejects SQL that names another module's schema.
- Move `GRANT_SCOPES`/`GRANT_TYPES` from the grant service into the domain and re-export them.
- Move `normalizeEmail` into the domain; keep the identity-service export for compatibility.
- Refactor `register` to use `DatabaseService.withTransaction` and the repository.
- Domain and repository unit tests.

### 3.2 Excluded

- Rewriting every identity transaction in the service. Sign-in, sessions, MFA and grant flows remain
  in the service for `031`/`032`; `register` is the first adopted path.
- Activity activation writes — `033`. The activation table exists; it does not create grants.
- A generic repository base class or ORM. The repository is explicit SQL over the unit of work.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Domain modules import no Nest, pg, HTTP or provider SDK. | Plan `030` |
| R-02 | Email is normalised before comparison and storage. | SEC-26 |
| R-03 | A grant scope must belong to its grant type. | Matrix §9 |
| R-04 | An expired or revoked grant is inactive. | Grant model |
| R-05 | An account has at most one owner membership. | Matrix §9.2 |
| R-06 | Registration creates no grant and no activity. | Plan `030` outcome |
| R-07 | The registration write uses one unit of work and the RLS context. | `026` |
| R-08 | Repositories read and write only the identity schema. | Plan `030` outcome |
| R-09 | Repository reads map snake_case to domain fields. | SEC-30, API-03 |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-023` identity schema | **REQUIRES_REVIEW** — tables, constraints and RLS |
| `EP-01-026` unit of work | **REQUIRES_REVIEW** — `withTransaction`, `setIdentity` |
| `EP-01-025` RLS helpers | **REQUIRES_REVIEW** — context function and policies |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the identity service, grant service and transaction helper.
2. Add the pure domain module.
3. Move the grant constants and email helper; keep re-exports.
4. Add the identity repository and schema guard.
5. Refactor `register` to the unit of work and repository.
6. Add domain and repository tests.
7. Run local gates; record the integration evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| Identity tables and RLS | **Reuse** | No schema change |
| `withTransaction`, `TransactionContext` | **Reuse** | The repository accepts a transaction, never a pool |
| Grant scope map | **Move to domain** | It is an invariant, not HTTP behaviour |
| `normalizeEmail` | **Move to domain** | Pure and used by the service and repository |
| Registration SQL | **Move into the repository** | First real repository path |
| Session/MFA/grant SQL | **Leave for `031`/`032`** | Too broad for this task |

**Must not be duplicated:** a second grant scope map, a second email normaliser, or a second
registration insert path.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/modules/identity/domain/identity.ts` | **New** — pure invariants |
| `server/src/modules/identity/repositories/identity.repository.ts` | **New** — identity-scoped repository |
| `server/src/modules/identity/identity.service.ts` | `register` uses the unit of work and repository; `normalizeEmail` re-exported |
| `server/src/modules/identity/grants/grants.service.ts` | Grant constants imported from the domain |
| `tests/identity-domain.test.ts` | **New** |
| `tests/identity-repository.test.ts` | **New** |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No schema, migration, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Domain functions are pure and import no Nest, pg or provider SDK. |
| DoD-02 | Email normalisation, grant scope validity, grant activity, single owner and status guards are tested. |
| DoD-03 | Registration creates account, user, credential and owner membership only. |
| DoD-04 | The repository rejects another module's schema at runtime. |
| DoD-05 | Repository reads map account, user, membership, grant and device rows. |
| DoD-06 | `register` uses one transaction and sets the identity context. |
| DoD-07 | The grant service still exports the same constants. |
| DoD-08 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-09 | `pnpm test:identity` passes against Postgres in CI after the registration refactor. |
| DoD-10 | No new dependency, secret or permission. |
| DoD-11 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The domain test proves a staff grant cannot hold an admin scope, and an expired/revoked grant is
  inactive.
- The repository test captures four inserts and no `identity.grants` or profile table.
- `assertIdentitySchemaSql` rejects `market.orders` and `profile.profiles`, accepts `identity.users`
  and `platform.uuidv7()`.
- Registration integration still returns an account and creates no grant.
- The unit of work test still proves rollback and context isolation.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/identity-domain.test.ts tests/identity-repository.test.ts` |
| T-02 | `pnpm test:identity` — CI database job |
| T-03 | `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The registration refactor changes transaction or error behaviour. | The unit of work preserves begin/commit/rollback/release; unique violations are still mapped to `CONFLICT`; integration runs in CI. |
| Moving `normalizeEmail` breaks an importer. | The identity service re-exports it; the session test still imports the same name. |
| Moving grant constants breaks an importer. | The grant service re-exports `GRANT_SCOPES`, `GRANT_TYPES` and `GrantType`. |
| The repository read methods are not yet used by the service. | They are the foundation for `031`/`032`; the registration write is already used. |
| A regex schema guard can miss dynamic SQL. | All repository SQL is static; the guard is defence in depth behind `lint-boundaries`. |
| No Postgres locally. | Domain/repository tests use a fake transaction; integration runs in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes registration/session integration after the refactor; remaining identity flows adopt the repository in `031`/`032` |
| **Execution record** | `execution-records/EP-01-030.md` |
