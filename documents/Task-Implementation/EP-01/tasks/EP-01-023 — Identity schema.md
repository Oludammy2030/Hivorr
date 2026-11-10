# EP-01-023 — Identity schema

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-023` |
| **Task title** | Identity schema |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — identity data model |
| **Execution order** | 13 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-021`, `EP-01-022` |

## 2. Objective

Create the identity spine: accounts, users, credentials, memberships, grants, devices, sessions, MFA
factors, recovery codes, one-time tokens, MFA challenges and refresh tokens. Every table needs
foreign keys, state constraints, indexes, RLS, explicit grants, a comment, UUIDv7 identifiers where an
`id` applies, and `timestamptz` timestamps.

## 3. Scope

### 3.1 Included

- Verify the twelve identity tables in migrations `005`, `008` and `009`.
- Verify RLS in `006`, `008` and `009`.
- Add a forward-only migration that comments the four tables missing a comment.
- Add a local schema-policy test for tables, identifiers, timestamps, constraints, FKs, RLS, grants
  and comments.
- Extend the fresh-database test: the full table list, RLS on every table, comments on every table,
  foreign-key presence and UUIDv7 defaults.

### 3.2 Excluded

- Editing applied migrations `005`–`010`. Applied files are immutable; the missing comments are a new
  migration.
- Profile, activity, platform tables — `024`.
- Session lifecycle endpoints — `030`/`032`.
- Capability computation changes.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Twelve identity tables exist. | Plan `023` |
| R-02 | Each table with an `id` uses `platform.uuidv7()`; credentials uses `user_id`. | Conventions §9.4 |
| R-03 | Timestamps are `timestamptz`. | Conventions §9.4 |
| R-04 | Foreign keys link the spine with delete behaviour chosen per relationship. | Plan `023` |
| R-05 | State columns have `check` constraints. | Plan `023` |
| R-06 | Lookup indexes exist for account/user/session queries. | Plan `023` |
| R-07 | RLS is enabled on every table. | Plan `023`, `022` |
| R-08 | `hivorr_api` has explicit grants; nothing is default-open. | `022` |
| R-09 | Every table has a comment. | Plan `023` |
| R-10 | No new dependency or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-021` runner | **REQUIRES_REVIEW** — applies the new comment migration |
| `EP-01-022` roles/defaults | **REQUIRES_REVIEW** — default-closed posture and RLS |
| Identity integration suite | Existing; runs against Postgres in CI |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the identity table, RLS, MFA and refresh-token migrations and the fresh-database test.
2. Add `20261109000200_identity_alter_table_comments.sql` for the four missing comments.
3. Add `tests/identity-schema.test.ts`.
4. Extend `test-db-migrations.mjs` with the full table list, RLS, comments, FKs and UUIDv7 defaults.
5. Run the migration lint and local gates; record the DB evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| Migrations `005`–`010` | **Reuse, do not edit** | Applied and checksum-protected |
| `platform.uuidv7()` | **Reuse** | All identity ids default to it |
| RLS policies in `006`/`008`/`009` | **Reuse** | Already cover all twelve tables |
| `test-db-migrations.mjs` | **Extend** | Owns the fresh-database assertions |
| Identity integration suite | **Reuse** | Exercises registration, sessions, MFA and grants |
| `hivorr_api` grants | **Reuse** | Explicit per table |

**Must not be duplicated:** a second identity table set, a second RLS policy set, or a second UUIDv7
function.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `supabase/migrations/20261109000200_identity_alter_table_comments.sql` | **New** — four table comments |
| `tests/identity-schema.test.ts` | **New** — schema policy |
| `scripts/test-db-migrations.mjs` | Extended DB assertions |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No existing table, policy, grant, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Twelve identity tables exist. |
| DoD-02 | Every UUID `id` defaults to `platform.uuidv7()`; credentials uses `user_id`. |
| DoD-03 | Every timestamp is `timestamptz`. |
| DoD-04 | State constraints exist for status, role, grant type, audience, environment, factor type and token purpose. |
| DoD-05 | Foreign keys link the spine. |
| DoD-06 | RLS is enabled on every table. |
| DoD-07 | `hivorr_api` has explicit grants on every table. |
| DoD-08 | Every table has a comment. |
| DoD-09 | `pnpm lint:migrations` passes with two strict files and eleven legacy files. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The fresh-database suite sees twelve `identity` tables, all with RLS and a comment.
- At least ten identity foreign keys exist.
- Eleven identity `id` columns default to UUIDv7.
- The schema-policy test names every table, constraint family and grant it expects.
- `lint:migrations` accepts the new comment migration as strict-named and forward-only.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/identity-schema.test.ts` |
| T-02 | `pnpm lint:migrations` |
| T-03 | `pnpm test:db` — CI database job |
| T-04 | `pnpm test:identity` — CI database job |
| T-05 | `pnpm test:gates` |
| T-06 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Four tables had no comment. | New forward-only comment migration; the DB test now requires a comment on every table. |
| Regex-based schema test can miss a structural defect. | The fresh-database suite asserts the live catalog; the static test pins the declarations. |
| `credentials` has no `id` column. | The test treats it as the one exception with `user_id` as primary key. |
| RLS policies could silently disappear. | The DB test asserts `rowsecurity` on every table; integration tests exercise the policies. |
| No Postgres locally. | The catalog and integration suites run in CI. |
| Default privileges could hide a missing grant. | `022` made objects default-closed; the static test requires an explicit grant per table. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI applies the comment migration and passes the extended catalog and identity suites |
| **Execution record** | `execution-records/EP-01-023.md` |
