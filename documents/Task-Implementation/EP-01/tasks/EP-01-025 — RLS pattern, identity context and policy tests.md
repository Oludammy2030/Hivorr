# EP-01-025 — RLS pattern, identity context and policy tests

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-025` |
| **Task title** | RLS pattern, identity context and policy tests |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — database authorisation |
| **Execution order** | 15 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-022`, `EP-01-023`, `EP-01-024` |

## 2. Objective

Make the RLS layer explicit and defensible: transaction-scoped identity helpers in the `private`
schema, `FORCE ROW LEVEL SECURITY` on every identity and profile table, one policy per intended
operation, fail-closed behaviour with no context, cross-account denial, and a narrow pre-auth lookup
that still works for sign-in.

## 3. Scope

### 3.1 Included

- Add `private.current_account_id()`, `private.current_user_id()` and
  `private.set_identity_context()`; revoke them from PUBLIC.
- Keep `platform.current_*` and `platform.set_identity_context` as security-definer wrappers.
- Force RLS on `profile.profiles` and `profile.activity_activations`.
- Recreate the profile policies with explicit roles: select for API and readonly; insert/update for
  API.
- Add owner-read policies for the tables the existing security-definer functions query.
- Extend the fresh-database tests: FORCE flags, one policy per operation, no-context denial,
  cross-account session read, private helper, wrapper `prosecdef`, definer policies, unknown and
  closed pre-auth lookups.
- Add a static RLS-policy test.

### 3.2 Excluded

- RLS on `platform.audit_log`, `outbox`, `idempotency_keys`, `feature_flags` and
  `reference_counters`. They are service-internal and have no account column; see `F-32`.
- The unit-of-work and transaction-context setter — `026`.
- Activation transitions — `033`.
- A Data API surface. Position A keeps it disabled; the `private` schema is not exposed either way.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Identity helpers live in the `private` schema. | Plan `025` |
| R-02 | `platform` names remain stable wrappers. | Reuse rule |
| R-03 | Every identity and profile table has RLS and FORCE RLS. | Plan `025` |
| R-04 | Each intended operation has a policy; no operation is implicitly open. | Plan `025` outcome |
| R-05 | An unset identity context returns no rows. | Plan `025` outcome |
| R-06 | Cross-account reads and writes are denied. | Plan `025` outcome |
| R-07 | The pre-auth lookup is narrow and works without a session. | Plan `025` engineering purpose |
| R-08 | No `auth.uid()` appears. | Plan `025` outcome |
| R-09 | Security-definer functions work under FORCE RLS. | PostgreSQL ownership |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-022` roles/defaults | **REQUIRES_REVIEW** — default-closed and role setup |
| `EP-01-023` identity | **REQUIRES_REVIEW** — 12 tables and policies |
| `EP-01-024` profile | **REQUIRES_REVIEW** — 2 tables and policies |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the identity RLS migration, the profile policies and the security-definer functions.
2. Add `20261109000400_identity_alter_rls_hardening.sql`.
3. Add `tests/rls-policy.test.ts`.
4. Extend `test-db-migrations.mjs` with FORCE, policy, no-context and pre-auth assertions.
5. Run the migration lint and local gates; record the DB evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `platform.current_*`, `platform.set_identity_context` | **Keep as wrappers** | Existing policies and service calls depend on the names |
| `private` schema | **Use** | It already exists and is closed to application roles |
| Identity policies in `006`/`008`/`009` | **Reuse** | Already scoped `TO hivorr_api` |
| Profile policies in `024` | **Replace** | Add explicit roles and FORCE |
| Security-definer functions | **Reuse** | Add only the owner-read policies they need |
| `test-db-migrations.mjs` | **Extend** | Owns the fresh-database evidence |

**Must not be duplicated:** a second helper implementation, a second policy family, or a second RLS
test suite.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `supabase/migrations/20261109000400_identity_alter_rls_hardening.sql` | **New** |
| `tests/rls-policy.test.ts` | **New** |
| `scripts/test-db-migrations.mjs` | Extended DB assertions |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No table, grant, role, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Private helpers exist and are revoked from PUBLIC. |
| DoD-02 | Platform wrappers are security definer and preserve the contract. |
| DoD-03 | FORCE RLS is on all 12 identity and 2 profile tables. |
| DoD-04 | Policy operations match the intended map. |
| DoD-05 | Profile policies are explicitly scoped to API/readonly. |
| DoD-06 | Definer owner policies cover the tables the current functions query. |
| DoD-07 | No `auth.uid()` appears. |
| DoD-08 | Unset context denies users, profiles, activations and sessions. |
| DoD-09 | Cross-account session/profile reads deny. |
| DoD-10 | Unknown and closed pre-auth lookups return nothing; the valid lookup returns one row. |
| DoD-11 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-12 | No new dependency, secret or permission. |
| DoD-13 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The static test finds a policy for every intended operation and no `auth.uid()`.
- The fresh-database suite sees FORCE RLS on all 14 user-data tables.
- With no context, the API sees zero users, profiles, activations and sessions.
- With a context, it sees only its own account's rows.
- The pre-auth lookup returns one credential for a valid email and nothing for an unknown or closed
  account.
- The definer owner has exactly seven narrow read policies.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/rls-policy.test.ts` |
| T-02 | `pnpm lint:migrations` |
| T-03 | `pnpm test:db` — CI database job |
| T-04 | `pnpm test:identity` — CI database job |
| T-05 | `pnpm test:gates` |
| T-06 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| FORCE RLS also applies to the table owner, which can break security-definer functions. | Seven narrow owner-read policies cover exactly the tables the current functions query; a future definer on another table must add its policy. |
| The owner may be `postgres` or `hivorr_migrator`. | The policies name both; a superuser owner bypasses regardless. |
| Platform tables do not have RLS. | They are service-internal with no account column; recorded as `F-32` for an architect ruling. |
| A custom GUC can be set by any role. | Only `hivorr_api` has the table grants and a policy; a direct caller with the API role must already be trusted. The database credentials are not client-issued. |
| `private` helpers are revoked from PUBLIC. | The platform wrapper is security definer, so callers do not need private execute. |
| No Postgres locally. | The FORCE, policy and pre-auth assertions run in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the RLS catalog and pre-auth assertions; `F-32` is ruled on |
| **Execution record** | `execution-records/EP-01-025.md` |
