# EP-01-036 — Audit logging service and immutability

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-036` |
| **Task title** | Audit logging service and immutability |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — evidence trail |
| **Execution order** | 23 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-024`, `EP-01-026` |

## 2. Objective

Write append-only audit records from the service layer for authentication, activity and privileged
actions, with actor, audience, correlation, target and before/after summaries. There must be no update
or delete path. A read model returns the entries to an authorised control caller. An audit failure is
propagated into the caller's transaction.

## 3. Scope

### 3.1 Included

- Extend `platform.appendAudit` with optional `before_summary` and `after_summary`.
- Add summaries to registration, sign-in, sign-out, refresh, activity activation/deactivation and
  grant create/revoke.
- Extend `platform.listAuditEntries` with the summaries.
- Keep the append-only trigger and prove update and delete are both refused.
- Prove the API role has no update/delete privilege.
- Unit-test audit write failure propagation and the read mapping.
- Integration-test summaries for activity activation/deactivation and the audit read model.

### 3.2 Excluded

- Retention, legal hold and export policy — not yet decided (`F-39`).
- A vendor error-tracking adapter — `040`.
- Audit screens in the control portal — `053`/later.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Audit writes include actor, audience, environment, action and target. | Plan `036` |
| R-02 | Before/after summaries are nullable and stored as JSON. | Plan `036` |
| R-03 | The write shares the caller's transaction. | `026` |
| R-04 | An audit failure aborts the transaction. | Plan `036` outcome |
| R-05 | No update or delete path exists, in grants or triggers. | Plan `036` outcome |
| R-06 | The read model returns entries and summaries. | Plan `036` outcome |
| R-07 | Sign-in and activity activation produce rows. | Plan `036` outcome |
| R-08 | Summaries never contain secrets, tokens or full credentials. | `AFS-LOG-01` |
| R-09 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-024` profile schema | **REQUIRES_REVIEW** — activity state |
| `EP-01-026` unit of work | **REQUIRES_REVIEW** — shared transaction |
| `EP-01-035` audit probe | **REQUIRES_REVIEW** — read endpoint |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the audit table, trigger and current writes.
2. Add summary fields to the write and read model.
3. Add summaries to the key service actions.
4. Add update/delete grant and trigger tests.
5. Add unit tests for failure propagation and mapping.
6. Add integration assertions for summaries and the read model.
7. Run local gates; record the CI-only evidence.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `platform.audit_log` | **Reuse** | Columns already include before/after |
| Append-only trigger | **Reuse** | Rejects update and delete |
| `appendAudit` | **Extend** | Optional summaries |
| `listAuditEntries` | **Extend** | Return summaries |
| Service audit calls | **Extend** | Add summaries where state changes |
| Migration `002` | **Do not edit** | Applied; no schema change needed |

**Must not be duplicated:** a second audit table, a second append function, a second read model or a
second immutability trigger.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/modules/platform/audit.ts` | Summaries in write and read |
| `server/src/modules/identity/identity.service.ts` | Registration, sign-in, sign-out, refresh summaries |
| `server/src/modules/identity/grants/grants.service.ts` | Grant create/revoke summaries |
| `server/src/modules/profile/profile.service.ts` | Activation/deactivation summaries |
| `server/src/contracts/schemas.ts` | Audit entry summaries |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `tests/audit.test.ts` | **New** |
| `scripts/test-db-migrations.mjs` | Delete refusal and privilege checks |
| `tests/identity-integration.test.ts` | Summary and read-model assertions |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No schema, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Audit writes include actor, audience, environment, action and target. |
| DoD-02 | Before/after summaries are stored and returned. |
| DoD-03 | Sign-in and activity activation rows exist with summaries where relevant. |
| DoD-04 | An audit insert failure rejects the caller's transaction. |
| DoD-05 | Update and delete are refused by the trigger. |
| DoD-06 | The API role cannot update or delete audit rows. |
| DoD-07 | The read model returns entries and summaries. |
| DoD-08 | No token or credential appears in a summary. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | `pnpm test:db` and `pnpm test:identity` pass the audit assertions in CI. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- A registration/sign-in row carries the session/account identifiers in `after_summary`.
- An activation row has `before_summary.state = INACTIVE` and `after_summary.state = ACTIVE`.
- A deactivation row has the reverse.
- `UPDATE` and `DELETE` on `platform.audit_log` both raise.
- `hivorr_api` has no update/delete privilege.
- The control audit probe returns `beforeSummary`/`afterSummary` fields.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/audit.test.ts` |
| T-02 | `pnpm test:db` — CI database job |
| T-03 | `pnpm test:identity` — CI database job |
| T-04 | `pnpm openapi:generate`; contract test |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Summaries could leak sensitive data. | Only identifiers and state; never a token, hash or password. |
| The append trigger could be dropped by a later migration. | The DB test fails if update/delete succeeds. |
| An audit failure could be swallowed. | `appendAudit` awaits the insert; the unit test proves rejection. |
| Retention is undecided. | Recorded as `F-39`; no deletion path is added. |
| No Postgres locally. | Trigger and integration tests run in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the delete/privilege and summary integration tests; retention is decided |
| **Execution record** | `execution-records/EP-01-036.md` |
