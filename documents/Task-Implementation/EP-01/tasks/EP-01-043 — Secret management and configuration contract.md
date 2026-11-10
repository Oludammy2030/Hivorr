# EP-01-043 — Secret management and configuration contract

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-043` |
| **Task title** | Secret management and configuration contract |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — environment isolation and secrets |
| **Execution order** | 26 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage E |
| **Dependencies** | `EP-01-020`; secret-manager decision (`standards` §16 `#8`) |

## 2. Objective

Give every environment one declared configuration contract: the same key names, different values;
startup fails when a required secret is missing; no secret is committed, bundled or logged; and the
rotation procedure is documented. The provider choice recorded in the standards is Doppler, while the
as-built runtime uses GitHub environment secrets and Fly.io secrets. On 2026-11-10 the founder ruled that
Doppler is not adopted, so GitHub + Fly are the provider (`F-04` closed). This task implements the
provider-agnostic contract and does **not** choose a provider.

## 3. Scope

### 3.1 Included

- `config/configuration-contract.json` — every key with `source` (`config` / `tooling` /
  `deployment`), `classification` (`public` / `secret`), `requiredIn`, and a short description. No
  values, no defaults.
- `scripts/lib/configuration-contract.mjs` — pure validation rules.
- `scripts/check-configuration-contract.mjs` and `pnpm config:check` — drift gate over the contract,
  `.env.example`, `config/environments.json` and client source.
- `.env.example` completed so every config and tooling key appears exactly once, and every secret
  placeholder is empty.
- `CONFIG_ENV_KEYS` exported from `server/src/config.ts` as the single schema-key source of truth.
- `tests/configuration-contract.test.ts` — schema parity, committed-contract pass, empty secret
  placeholders, startup failure on a missing staging secret without echoing the value, seeded drift.
- Two seeded-failure proofs in `scripts/test-ci-gates.mjs`.
- `documents/Engineering-Execution/SECRET_MANAGEMENT.md` — inventory, injection points, rotation per
  secret, break-glass, evidence, and what is not covered.

### 3.2 Excluded

- Provisioning Doppler or moving existing values. Doppler was ruled out on 2026-11-10; GitHub + Fly remain (`F-04` closed).
- Reading, printing or validating any real secret value. The gate never contacts a provider.
- Automated rotation.
- A key-versioned re-encryption path for `MFA_ENCRYPTION_KEY`.
- Provider-side secret scanning.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every configuration key is declared once, with a classification and a source. | Plan `043` |
| R-02 | Every API schema key appears in the contract, and the contract declares no non-schema config key. | Plan `043` |
| R-03 | `.env.example` lists every config and tooling key; a secret placeholder is empty. | `API-36` |
| R-04 | Deployment-only secrets never appear in the application template. | `DAT-23` |
| R-05 | Startup fails when a required staging/production secret is missing, naming the key only. | Plan `043` outcome |
| R-06 | No secret name is referenced by client source. | Plan `043` outcome |
| R-07 | The topology manifest may only name secrets the contract knows. | `DAT-23` |
| R-08 | Rotation is documented per secret, including the MFA key's re-enrolment constraint. | Plan `043` outcome |
| R-09 | The contract gate runs in CI and has a seeded proof that it can fail. | `EP-01-004` |
| R-10 | No dependency, secret or CI permission is added. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-020` environment configuration | **REQUIRES_REVIEW** — `config.ts` and the topology manifest exist |
| `EP-01-004` CI pipeline | **REQUIRES_REVIEW** — lint job and seeded-gate harness |
| `standards` §16 `#8` | **SUPERSEDED 2026-11-10** — founder ruled no Doppler; GitHub + Fly are the provider (`F-04` closed); the standards entry needs a revision |
| `TEC-12` vendor processing | Approved for staging; covers Supabase, Cloudflare and Fly.io, not Doppler |

## 6. Implementation plan

1. Re-read the plan, `config.ts`, `.env.example`, the environment manifest and the provisioning docs.
2. Confirm the provider ruling status before changing any injection point (`F-04`).
3. Export the schema keys as `CONFIG_ENV_KEYS`.
4. Write the contract inventory from the schema, the tooling scripts and the deploy workflow.
5. Write the pure policy and the CLI gate.
6. Complete `.env.example`.
7. Add schema parity, startup-failure and drift tests; add seeded proofs.
8. Document injection and rotation.
9. Run the local gates; update the tracker, overview and execution record.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `config.ts` zod schema and `superRefine` | **Reuse** | Startup validation already exists; expose its keys instead of restating them |
| `ConfigurationError` | **Reuse** | Names fields, never values |
| `.env.example` | **Extend** | It is the template `API-36` requires |
| `config/environments.json` `requiredSecrets` | **Reuse** | Cross-checked against the contract |
| `scripts/secret-scan.mjs` | **Reuse** | Credential-pattern scan stays the value-level guard |
| `scripts/verify-backend-target.mjs` | **Reuse** | Deployment-target preflight; its keys become tooling keys |
| `scripts/test-ci-gates.mjs` | **Extend** | New gate gets a seeded failure |
| `BACKEND_ENVIRONMENT_SETUP.md` | **Reference only** | Existing provisioning instructions stay authoritative for commands |
| `STAGING_PROVISIONING.md` | **Reference only** | Same |

**Must not be duplicated:** a second environment schema, a second key list inside the checker, or a
second rotation document. The contract names keys; `config.ts` owns parsing; the rotation doc owns
procedure.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `config/configuration-contract.json` | **New** — 31-key inventory |
| `scripts/lib/configuration-contract.mjs` | **New** — pure rules |
| `scripts/check-configuration-contract.mjs` | **New** — CLI gate |
| `server/src/config.ts` | Export `CONFIG_ENV_KEYS`; no parsing change |
| `.env.example` | Complete key coverage; empty secret placeholders |
| `tests/configuration-contract.test.ts` | **New** |
| `scripts/test-ci-gates.mjs` | Two seeded proofs |
| `package.json` | `config:check`; added to `verify` |
| `.github/workflows/ci.yml` | Run `config:check` in the lint job |
| `documents/Engineering-Execution/SECRET_MANAGEMENT.md` | **New** — rotation and evidence |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The contract declares every schema key exactly once and no phantom config key. |
| DoD-02 | Every config and tooling key appears in `.env.example` exactly once. |
| DoD-03 | Every secret placeholder in `.env.example` is empty. |
| DoD-04 | Deployment-only secrets are absent from `.env.example`. |
| DoD-05 | No secret name appears in client source. |
| DoD-06 | The topology manifest names only known secrets. |
| DoD-07 | `parseConfig` fails on a missing staging `DATABASE_URL` or `MFA_ENCRYPTION_KEY` and does not echo a value. |
| DoD-08 | `pnpm config:check` passes on the committed tree. |
| DoD-09 | `pnpm test:gates` proves the contract gate can fail (clean passes, secret-value fixture is blocked). |
| DoD-10 | Rotation is documented per secret, including the MFA re-enrolment constraint. |
| DoD-11 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-12 | No new dependency, secret or permission; prototype and theme unchanged. |

## 10. Acceptance criteria

- `pnpm config:check` reports `OK — 31 key(s), 5 secret(s), startup-required: MFA_ENCRYPTION_KEY,
  DATABASE_URL`.
- Removing `API_PORT` from `.env.example` fails the gate with `API_PORT: missing from .env.example`.
- Putting a value on `MFA_ENCRYPTION_KEY` in `.env.example` fails the gate.
- Referencing `DATABASE_URL` from `src/` fails the gate.
- Naming an unknown secret in `config/environments.json` fails the gate.
- A staging environment missing `DATABASE_URL` or `MFA_ENCRYPTION_KEY` throws `ConfigurationError`
  whose message contains the key and not the connection string.
- A complete staging configuration parses.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm config:check` |
| T-02 | `pnpm test -- tests/configuration-contract.test.ts tests/server-config.test.ts` |
| T-03 | `pnpm test:gates` — 19/19 |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | CI lint job runs `config:check` |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The provider was undecided (`F-04`); it is now resolved: GitHub + Fly, no Doppler. | The contract is provider-agnostic; the rotation doc records the ruling. A future provider change touches injection, not key names. |
| A JSON contract can drift from the schema. | The test asserts set equality with `CONFIG_ENV_KEYS`; the CLI checks the template and topology. |
| The template may hide a real value. | Every secret placeholder must be empty; `secret-scan` still scans tracked content. |
| Client source can reference a secret name. | The gate scans `src/` for every secret name. It cannot detect a value injected at build time, which remains a review control. |
| MFA key rotation locks users out. | The procedure requires re-enrolment; a key-versioned migration is explicitly out of scope. |
| `EDGE_SHARED_SECRET` is optional. | It is only needed when the edge forwards a host; absence falls back to the `Host` header and fails closed. |
| CI cannot validate real provider values. | CI validates the contract and startup behaviour; the values stay in the secret store. |
| No local Postgres or argon2. | Unrelated to this task; the contract tests are pure. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | The CI lint job runs `config:check` and the rotation procedure is accepted (`F-04` closed 2026-11-10) |
| **Execution record** | `execution-records/EP-01-043.md` |
