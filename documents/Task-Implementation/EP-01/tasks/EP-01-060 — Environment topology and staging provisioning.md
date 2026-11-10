# EP-01-060 — Environment topology and staging provisioning

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-060` |
| **Task title** | Environment topology and staging provisioning |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — infrastructure evidence |
| **Execution order** | 32 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage G |
| **Dependencies** | `EP-01-001` (#17), `EP-01-020`, `EP-01-043` |

## 2. Objective

Provision and record `local`, staging and the reserved production definition with isolated databases,
credentials, secrets and hostnames across the eight deployments; verify that the four staging hosts
resolve with valid TLS, that `/api/*` reaches only the staging API, and that Cloudflare Access protects
the control, staff and partner hosts.

## 3. Scope

### 3.1 Included

- Read-only live probe `scripts/verify-staging-hosts.mjs` and `pnpm verify:staging-hosts`.
- Reconcile the topology record with observed reality: staging `planned` → `verified`, with
  `verifiedAt` and an evidence path.
- Evidence file `documents/Engineering-Execution/evidence/staging-topology/2026-11-10.md`.
- Topology test update: staging is verified with recorded evidence; the premature-production fixture
  now resets staging explicitly.
- Runbook corrections: live status, evidence command, `/v1` health paths, API-image freshness note.
- `F-27` closed: the three-way status record now agrees on live staging.

### 3.2 Excluded

- Provider-side changes: no DNS record, Access policy, Pages project, Fly app, bucket, role or database
  was created or modified.
- Reading a credential or calling a provider API with one.
- Database certificate verification (`F-08`); it needs `DATABASE_SSL_CA`.
- Automated Pages deployment from the release manifest; that is `061`.
- Deploying a fresh API image; the stale staging image is recorded as `F-49` and belongs to `061`.
- Production changes; production stays `reserved`.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The four staging hosts resolve and serve valid TLS for their own names. | Plan `060` |
| R-02 | `/api/*` reaches the staging API, not production. | Plan `060` |
| R-03 | Access challenges control, staff and partner before the bundle loads. | Plan `060` |
| R-04 | The topology record reflects observed status. | `F-27` |
| R-05 | Production remains `reserved`. | Topology policy |
| R-06 | Evidence contains no secret, token or connection string. | `API-35`, `API-34` |
| R-07 | The probe is reproducible. | Plan `060` runbook rule |
| R-08 | No provider resource is modified by this task. | Bounded scope |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-001` hosting/DNS/TLS | **COMPLETED** |
| `EP-01-020` managed PostgreSQL | **REQUIRES_REVIEW** — live project recorded |
| `EP-01-043` secret contract | **REQUIRES_REVIEW** — provider ruling `F-04` open |
| Staging runbook | Live and now evidence-linked |

## 6. Implementation plan

1. Read the topology record, policy and runbook.
2. Probe the four hosts read-only: DNS/TLS, status, Access, edge API health.
3. Record the evidence without tokens.
4. Update the topology status and evidence pointer.
5. Update the topology tests and the runbook.
6. Run the topology, contract and repository gates.
7. Report the remaining provider-side gaps.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `config/environments.json` | **Update status** | The single topology record |
| `environment-topology-policy.mjs` | **Reuse** | Already validates the eight deployments |
| `test-environment-topology.mjs` | **Update fixtures** | Staging is no longer "not verified" |
| `STAGING_PROVISIONING.md` | **Correct** | Status, evidence and health paths |
| `verify-backend-target.mjs` | **Reuse** | Deployment preflight |
| `verify-staging-hosts.mjs` | **New** | Reproducible live check |

**Must not be duplicated:** a second host list, a second topology policy, or a second secret store.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/verify-staging-hosts.mjs` | **New** |
| `config/environments.json` | staging `verified`, evidence pointer |
| `scripts/test-environment-topology.mjs` | Verified-staging assertions |
| `STAGING_PROVISIONING.md` | Status, evidence, health paths, `F-49` note |
| `documents/Engineering-Execution/evidence/staging-topology/2026-11-10.md` | **New** |
| `package.json` | `verify:staging-hosts` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No provider resource, credential or production record changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `pnpm verify:staging-hosts` passes against live staging. |
| DoD-02 | Four hosts resolve with a certificate covering each name. |
| DoD-03 | Main returns 200; privileged hosts return an Access challenge. |
| DoD-04 | `/api/v1/health/live` returns `environment=staging`. |
| DoD-05 | The topology record says staging `verified` with evidence; production `reserved`. |
| DoD-06 | `pnpm topology:verify` and `pnpm test:topology` pass. |
| DoD-07 | The evidence file contains no secret or Access token. |
| DoD-08 | The runbook health paths match the API (`/v1/...`). |
| DoD-09 | Local gates pass. |

## 10. Acceptance criteria

- Probe output: main 200, control/staff/partner 302 to `*.cloudflareaccess.com`, API health 200
  `environment=staging`.
- `topology:verify` prints four staging and four production hosts with staging `verified`.
- Production remains `reserved`.
- `F-49` records that `GET /api/v1/session` and `/activities` return 404 on the deployed image.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm verify:staging-hosts` |
| T-02 | `pnpm topology:verify` |
| T-03 | `pnpm test:topology` |
| T-04 | `pnpm test` (full) |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `config:check` |
| T-06 | `pnpm verify:backend-target` remains the deployment preflight |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A probe could leak an Access token. | The script prints only the redirect hostname; the evidence omits the URL. |
| "Verified" could overstate database isolation. | The evidence states what was observed; database/secret isolation remains a recorded control (`F-08`, `F-04`). |
| Live DNS changes between runs. | The probe is reproducible; CI does not run it, so it cannot flake PRs. |
| The deployed API is stale. | Recorded as `F-49`; `061` deploys the current digest. |
| Production could be touched. | The probe only reads the four staging hosts. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | `F-08`/`F-49` are closed and the CI run is green; the topology itself is observed |
| **Execution record** | `execution-records/EP-01-060.md` |
