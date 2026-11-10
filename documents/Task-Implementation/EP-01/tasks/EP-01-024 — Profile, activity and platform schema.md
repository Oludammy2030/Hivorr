# EP-01-024 — Profile, activity and platform schema

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-024` |
| **Task title** | Profile, activity and platform schema |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — activity state model |
| **Execution order** | 14 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-021`, `EP-01-022` |

## 2. Objective

Create one shared profile per account and one activation row per account and activity, with exactly
the six approved activity IDs and the four activation states. Constrain, index, enable RLS, grant
and comment both tables. Confirm the platform audit/outbox/idempotency/flag/reference tables already
carry the required shapes.

## 3. Scope

### 3.1 Included

- `profile.profiles` — one row per account, shared by every activity.
- `profile.activity_activations` — unique `(account_id, activity_id)`, `INACTIVE`/`ACTIVE`/`RESTRICTED`/`SUSPENDED`.
- RLS select/insert/update policies using `platform.current_account_id()`.
- Indexes on the policy and switcher filters.
- Explicit API and readonly grants; readonly may evaluate the account policy.
- A local schema-policy test and fresh-database assertions for constraints, idempotency, RLS and
  cross-account denial.

### 3.2 Excluded

- Transition rules and endpoints — `EP-01-033`.
- `FORCE ROW LEVEL SECURITY` and the full allow/deny matrix — `EP-01-025`.
- Verification cases, documents and KYC tiers. They are in the profile module's long-term ownership
  but are not part of the two tables this task names.
- Platform tables. Migration `002` already created audit, outbox, idempotency, feature flags and
  reference counters; no second set is created.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Exactly the six shared activity IDs are allowed. | Matrix §5, shared `ACTIVITY_IDS` |
| R-02 | The four activation states are allowed. | Matrix §5.3 |
| R-03 | One activation per account and activity; activating twice cannot duplicate. | Matrix §5.2 |
| R-04 | One shared profile per account. | Matrix §6 |
| R-05 | Activation and profile rows use UUIDv7 and `timestamptz`. | Conventions §9.4 |
| R-06 | RLS restricts rows to the current account. | Matrix §11 |
| R-07 | The account/state and activity/state filters are indexed. | Plan `024` outcome |
| R-08 | `hivorr_api` writes; `hivorr_readonly` reads and may evaluate the policy. | `022` |
| R-09 | Both tables are commented. | Plan `023` convention |
| R-10 | Platform tables remain append-only where required. | `002` |
| R-11 | No new dependency or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-021` runner | **REQUIRES_REVIEW** — applies the new migration |
| `EP-01-022` roles/defaults | **REQUIRES_REVIEW** — default-closed posture |
| `EP-01-023` identity | **REQUIRES_REVIEW** — supplies accounts and `current_account_id()` |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the matrix activation model, architecture module 2 and the platform tables.
2. Add `20261109000300_profile_create_profile_tables.sql`.
3. Add `tests/profile-schema.test.ts` for the declarations and the shared lists.
4. Extend `test-db-migrations.mjs` with constraints, idempotency, RLS, grants and cross-account denial.
5. Run the migration lint and local gates; record the DB evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `ACTIVITY_IDS`, `ACTIVITY_ACTIVATION_STATES` | **Reuse** | The shared list is the source; the check constraint restates it and a test compares them |
| `platform.current_account_id()` | **Reuse** | The identity context from `006` |
| `platform.uuidv7()` | **Reuse** | Id convention |
| `hivorr_api` / `hivorr_readonly` | **Reuse** | Existing least-privilege roles |
| Platform tables in `002` | **Reuse** | No duplicate audit/outbox/idempotency set |
| `test-db-migrations.mjs` | **Extend** | One fresh-database suite |

**Must not be duplicated:** a second activity list, a second profile per activity, a second platform
table set, or a second RLS policy family.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `supabase/migrations/20261109000300_profile_create_profile_tables.sql` | **New** |
| `tests/profile-schema.test.ts` | **New** |
| `scripts/test-db-migrations.mjs` | Extended DB assertions |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No identity, platform, role, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `profile.profiles` and `profile.activity_activations` exist. |
| DoD-02 | The check constraint lists exactly the six shared activity IDs. |
| DoD-03 | The check constraint lists exactly the four states. |
| DoD-04 | `unique (account_id, activity_id)` makes activation idempotent. |
| DoD-05 | UUIDv7 and `timestamptz` conventions hold. |
| DoD-06 | RLS is enabled with select/insert/update policies on both tables. |
| DoD-07 | The account/state and activity/state indexes exist. |
| DoD-08 | API write and readonly read grants exist; readonly may evaluate the policy. |
| DoD-09 | Both tables are commented. |
| DoD-10 | An unknown activity ID, unknown state and duplicate activation are refused by the database. |
| DoD-11 | RLS shows only the current account's rows and blocks a cross-account write. |
| DoD-12 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-13 | No new dependency, secret or permission. |
| DoD-14 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The static test compares the database lists with `ACTIVITY_IDS` and the shared states, so they
  cannot drift.
- The fresh-database suite refuses `market.discover`, state `ON` and a second activation for the same
  account/activity.
- The API sees one profile and six activations for its account, not the second account's rows.
- The API cannot insert a profile for another account.
- `lint:migrations` accepts the new profile migration as strict-named and self-contained.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/profile-schema.test.ts` |
| T-02 | `pnpm lint:migrations` |
| T-03 | `pnpm test:db` — CI database job |
| T-04 | `pnpm test:gates` |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The DB check duplicates the shared activity list. | The static test extracts the SQL list and compares it with `ACTIVITY_IDS`; drift fails locally. |
| `hivorr_readonly` cannot run the RLS function without EXECUTE. | The migration grants EXECUTE on `current_account_id()`; the DB test asserts it. |
| State transitions are not enforced yet. | `033` owns the transition graph; this migration constrains only the state set. |
| A profile is created before a display name exists. | `display_name` is nullable until the profile is edited or activation fills it. |
| No Postgres locally. | The constraint and RLS assertions run in CI. |
| A future activity needs a new ID. | It requires a migration and a shared-list change together, deliberately. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI applies the profile migration and passes the constraint/RLS assertions |
| **Execution record** | `execution-records/EP-01-024.md` |
