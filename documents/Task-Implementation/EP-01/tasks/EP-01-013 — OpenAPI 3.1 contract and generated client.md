# EP-01-013 — OpenAPI 3.1 contract and generated client

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-013` |
| **Task title** | OpenAPI 3.1 contract and generated client |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — public API contract |
| **Execution order** | 8 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage B |
| **Dependencies** | `EP-01-010`, `EP-01-011`, `EP-01-012` |

## 2. Objective

Make the HTTP contract a generated artifact. Every implemented endpoint is described once, the
OpenAPI 3.1 document is produced from that source, `@hivorr/api-client` is generated from the
document, and CI fails when the committed contract or client drifts from the code or a breaking
change is introduced.

## 3. Scope

### 3.1 Included

- `server/src/contracts/schemas.ts` — the request and response schemas used by the controllers and
  the generator; requests are strict.
- `server/src/openapi/operations.ts` — the twenty implemented operations, their audience and their
  responses.
- `server/src/openapi/build.ts` — deterministic OpenAPI 3.1 document, using zod's
  `toJSONSchema` (no new dependency).
- `server/src/openapi/client.ts` — deterministic typed client generator.
- `server/src/openapi/scan.ts` — Nest route metadata reader for the coverage test.
- `openapi/openapi.json` and `packages/api-client/src/index.ts` — committed generated outputs.
- `pnpm openapi:generate`, `openapi:check`, and a CI regeneration step before the base diff.
- Contract tests: document shape, request strictness, committed-output equality, generated-client
  equality; client behaviour tests with a mock fetch; route coverage against controllers.

### 3.2 Excluded

- Wiring the client into the prototype. `src/app/App.tsx` is the visual authority and must not be
  edited; the router/providers task `052` consumes the client.
- Authentication flows beyond the existing endpoints.
- Pagination adoption (recorded as `F-18`).
- A generated client for a public partner API (not at MVP).
- Any new runtime dependency. The generator uses `zod`, `tsc`, Nest metadata and Node built-ins.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The document declares OpenAPI `3.1.0`. | Plan `013` |
| R-02 | Every implemented endpoint is documented once, with audience and responses. | Architecture §9.9 |
| R-03 | Request schemas reject unknown fields. | SEC-23, API-06 |
| R-04 | Every client error uses the stable error envelope. | `011` |
| R-05 | Each portal has a host-only cookie security scheme. | AUT-11, Architecture §5.4 |
| R-06 | The client is generated from the document, never hand-written. | Plan `013` |
| R-07 | The client sends cookie credentials and encodes path parameters. | Architecture §9.9 |
| R-08 | A non-2xx outside the declared expectations becomes `ApiClientError`. | `011` |
| R-09 | The committed document and client must match a fresh generation. | Drift control |
| R-10 | The OpenAPI diff stage is active against the real document and a breaking fixture fails. | Plan `004`, `013` |
| R-11 | No new runtime dependency or secret. | Standards §3.4, §4A |
| R-12 | The generated client is not hand-formatted; `openapi:check` owns its integrity. | Determinism |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-010` bootstrap | **REQUIRES_REVIEW** — supplies the server |
| `EP-01-011` pipeline | **REQUIRES_REVIEW** — supplies validation and error contracts |
| `EP-01-012` modules | **COMPLETED** — supplies the controller surface |
| `zod` 4.6.7 | Existing; `z.toJSONSchema` converts the schemas |
| `typescript` 5.9.3 | Existing; compiles the generator |
| `scripts/openapi-diff.mjs` | Existing from `004`; now receives a real document |

## 6. Implementation plan

1. Read the controllers, service response types and the existing diff gate.
2. Extract request schemas into `contracts/schemas.ts`; add response schemas.
3. Update the controllers to validate with the shared request schemas.
4. Define the twenty operations in `openapi/operations.ts`.
5. Build the 3.1 document with zod JSON Schema conversion and four cookie schemes.
6. Generate the typed client with a small JSON-Schema-to-TypeScript emitter.
7. Add `openapi:build`, `openapi:generate` and `openapi:check`; wire CI and `verify`.
8. Add the contract, client and route-coverage tests.
9. Run every local gate; record what requires Linux.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `scripts/openapi-diff.mjs` | **Reuse** | It already detects removed paths, operations, responses and narrowed schemas |
| `scripts/test-ci-gates.mjs` | **Reuse** | The breaking-change fixture already exists; no new proof needed |
| `packages/shared` error schema | **Reuse** | One error envelope for the document and client |
| `packages/shared` capability/portal/environment tuples | **Reuse** | Response enums cannot drift from the contract |
| `packages/api-client` | **Fill the placeholder** | The package already existed as a boundary |
| `zod` | **Reuse** | `toJSONSchema` is built in |
| Nest metadata constants | **Reuse** | Route scanning needs no app boot |
| Controller request schemas | **Move to contracts** | One source for validation and documentation |
| `004` CI openapi job | **Extend** | Add regeneration, keep the base diff |

**Must not be duplicated:** a second request schema, a second error envelope, a second client, or a
second contract document.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/contracts/schemas.ts` | **New** — request and response schemas |
| `server/src/openapi/{types,operations,build,client,scan,generate}.ts` | **New** |
| `server/tsconfig.openapi.json` | **New** — generator build |
| `scripts/{clean-openapi-build,finalize-openapi-build}.mjs` | **New** |
| `scripts/format-check.mjs` | Exclude the generated client |
| `openapi/openapi.json` | **New** — generated contract |
| `packages/api-client/src/index.ts` | Replaced by the generated client |
| `server/src/modules/identity/identity.controller.ts` | Imports the contract schemas |
| `server/src/modules/identity/grants/grants.controller.ts` | Imports the contract schema |
| `server/tsconfig.build.json` | Excludes the generator from the runtime build |
| `package.json` | `openapi:build`, `openapi:generate`, `openapi:check`; `verify` |
| `.github/workflows/ci.yml` | Regenerate before the base diff |
| `tests/{openapi-contract,api-client,openapi-route-coverage}.test.ts` | **New** |
| `tests/ci-pipeline.test.ts` | Requires `pnpm openapi:check` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The document declares OpenAPI 3.1.0 and all twenty operations. |
| DoD-02 | Every operation declares its audience, responses and security. |
| DoD-03 | Every request schema rejects unknown fields. |
| DoD-04 | Client errors use the stable error envelope. |
| DoD-05 | Four cookie security schemes exist with the real cookie names. |
| DoD-06 | `packages/api-client` is generated, typechecks and is not hand-written. |
| DoD-07 | Client tests cover credentials, JSON bodies, path encoding, errors and expected 503. |
| DoD-08 | The committed document and client match a fresh generation. |
| DoD-09 | `pnpm openapi:check` regenerates and fails on a diff in CI. |
| DoD-10 | The route-coverage test proves controllers and document agree. |
| DoD-11 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `build:all`, `build:server` pass. |
| DoD-12 | No new runtime dependency, secret or CI permission. |
| DoD-13 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- A fresh `pnpm openapi:generate` rewrites the committed files byte-for-byte (after whitespace
  normalization for the client).
- Removing an operation from the registry removes it from the document; the diff gate reports a
  breaking change.
- A controller route without an operation, or an operation without a route, fails the coverage test.
- A request body with an unknown field is still a 400 in the API.
- `createHivorrClient` sends cookies, JSON and encoded path parameters, and throws the stable error.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm openapi:generate`; inspect the document and client |
| T-02 | `pnpm test -- tests/openapi-contract.test.ts tests/api-client.test.ts` |
| T-03 | `tests/openapi-route-coverage.test.ts` — Linux CI (controller import) |
| T-04 | `pnpm openapi:check` — CI on a committed tree |
| T-05 | `pnpm test:gates` — the breaking-change fixture |
| T-06 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-07 | `pnpm build:all`, `build:server`; confirm the generator is not in the runtime output |
| T-08 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A hand-written spec would drift. | The document is built from zod schemas and an operation registry; a test compares the committed file. |
| A generated client could drift. | `openapi:check` regenerates and diffs both outputs; the contract test compares them in-process. |
| The client is not wired into the web app. | The prototype is protected and has no API calls; `052` consumes the package. Recorded as an open item. |
| `openapi:check` uses `git diff`, which cannot validate an uncommitted working tree. | The contract test is the local proof; CI proves the committed tree. |
| The custom generator is a technical selection. | It adds no dependency and produces a deterministic, testable artifact; the alternative (`@nestjs/swagger`) would add a dependency and generates 3.0 by default. |
| The route-coverage test cannot load argon2 on Windows. | It runs in Linux CI; the contract test and client tests are local. |
| Response schemas could diverge from service output. | They are explicit DTOs; the HTTP integration suite exercises the real responses in CI. |
| Generated code is not hand-formatted. | `format-check` excludes it; `openapi:check` owns it. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | Linux CI runs the route-coverage test and `openapi:check` on a committed tree; `052` consumes the client in the web app |
| **Execution record** | `execution-records/EP-01-013.md` |
