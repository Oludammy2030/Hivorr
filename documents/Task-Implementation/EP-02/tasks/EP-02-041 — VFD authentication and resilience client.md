# EP-02-041 — VFD authentication and resilience client

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-041` |
| **Task title** | VFD authentication and resilience client |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | Critical |
| **GOV-09 class** | [FOUNDER] (provisional; confirm at G0) |
| **Execution order** | 21 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage E |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Implement VFD token acquisition, caching, refresh, timeout, retry and error mapping without a non-expiring token.

## 3. Scope

### 3.1 Included

- Implement VFD token acquisition, caching, refresh, timeout, retry and error mapping without a non-expiring token.
- Bounded VFD token acquisition, caching and refresh.
- Timeout, retry and failure mapping.
- No non-expiring token and no secret in logs.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- A second provider.
- Production credentials or production money movement.
- Card acceptance, card issuing, bills, loans or POS.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: Tokens are short-lived and refreshed safely; timeouts and retries are bounded; errors map to Hivorr codes; secrets never appear in logs; a failed token request fails closed. | EP-02-041 |

## 5. Dependencies

- **Task dependencies:** EP-02-040; VFD sandbox credentials.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect the VFD documentation and the approved adapter boundary.
3. Define or extend the port and its contract tests against a fake.
4. Implement authentication with bounded lifetime and failure handling.
5. Implement collections and payouts behind the port.
6. Add webhook intake, raw storage, dedupe and status verification.
7. Run sandbox certification and record the evidence.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `server/src/integrations` for adapter boundaries.
- `server/src/modules/platform/outbox` for asynchronous processing.
- `server/src/modules/finance` for provider references and idempotency.
- `documents/integrations/vfd` for vendor facts and gaps.
- EP-01 secret and configuration contract.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `server/src/integrations/vfd/auth.ts`, `index.ts`
- `server/src/config.ts` — VFD mode, credentials and bounds
- `server/src/app.module.ts` — `VFD_AUTH` provider
- `config/configuration-contract.json`, `.env.example`
- `tests/vfd-auth.test.ts`, `tests/vfd-auth.integration.test.ts`, `tests/server-config.test.ts`
- No migration, schema change or API contract change

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: Tokens are short-lived and refreshed safely; timeouts and retries are bounded; errors map to Hivorr codes; secrets never appear in logs; a failed token request fails closed. | Linked artefact in the execution record |
| DoD-02 | Every dependency is satisfied or explicitly recorded as a blocker | Dependency table |
| DoD-03 | `pnpm typecheck`, `pnpm lint`, `pnpm test` and the relevant database/contract gates pass | Command output |
| DoD-04 | Every new allow path has a deny test where the task touches verification, finance, evidence or admin authority | Test names and results |
| DoD-05 | The audit-readiness impact note is recorded where the task touches identity, money, personal data or a trust boundary | Impact note |
| DoD-06 | No parallel implementation, duplicate vocabulary or unapproved dependency is introduced | Reuse check |
| DoD-07 | Task document, tracker and execution record are current | Links |
| DoD-08 | No production code or feature outside EP-02 scope is added | Diff review |

## 10. Acceptance criteria

- The behaviour described in the objective is observable on staging or in an automated test.
- A reviewer who did not write the change can inspect the evidence and reach the same conclusion.
- The deny path is proven, not asserted.
- No marketplace transaction flow is added.
- The change remains inside the approved phase scope.

## 11. Testing and validation

Planned tests; no run is claimed until the execution record records the result.

- Provider port contract tests against a fake adapter.
- VFD authentication expiry and failure tests.
- Webhook replay and duplicate tests.
- Sandbox collection and payout tests.
- Error mapping tests for documented VFD failures.

## 12. Risks and considerations

- VFD webhooks have no documented signature.
- VFD documentation has no OpenAPI, idempotency contract or rate limits.
- Sandbox behaviour may not match production.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Execution date** | 2026-11-21 |
| **Execution record** | `execution-records/EP-02-041.md` |
| **Blocked by** | — (control-portal mode toggle and sandbox certification remain follow-ups; the written pooled-account confirmation is an accepted risk under the founder's direction) |
| **Notes** | Bounded token client with cache, single-flight refresh, timeout, retries, error mapping, redaction and test/live URL selection. Live mode is refused outside production. No secret handled. |

