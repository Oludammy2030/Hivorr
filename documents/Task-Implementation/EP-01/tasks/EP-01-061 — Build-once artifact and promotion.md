# EP-01-061 — Build-once artifact and promotion

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-061` |
| **Task title** | Build-once artifact and promotion |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — release identity and promotion |
| **Execution order** | 33 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage G |
| **Dependencies** | `EP-01-004`, `EP-01-054`, `EP-01-060` |

## 2. Objective

Build each bundle and the API once per commit, record the artifact digest, deploy staging by that
identity rather than by branch, expose the deployed identity from the running system, and promote the
same artifact with no rebuild.

## 3. Scope

### 3.1 Included

- Config: `RELEASE_SHA` (40-hex) and optional `RELEASE_DIGEST` (`sha256:<64-hex>`), injected by the
  deployment; startup rejects a malformed value.
- `GET /v1/health/live` now reports `releaseSha` and `releaseDigest` (nullable), so the running system
  answers “what is deployed?”.
- Contract: `healthResponse` extended; OpenAPI and the generated client regenerated.
- `deploy-staging.yml`: computes `sha256` of the release manifest, writes `release-digest.txt`, and
  uploads it as a third artifact alongside the manifest and bundles.
- `deploy-production.yml`: downloads the digest, verifies it against the manifest bytes, and refuses
  promotion if the live staging health does not report the same `releaseSha`.
- `deploy-fly-staging.yml`: injects `RELEASE_SHA` into the API and worker, and the smoke test fails
  unless `/v1/health/live` reports the deployed commit.
- Tests for the release config and the health response.

### 3.2 Excluded / recorded limits

- Automated Cloudflare Pages deployment from the manifest. The frontend artifact is digest-verified
  and uploaded, but hosting rollout remains manual (`F-50`).
- Capturing the Fly.io **image** digest from the remote builder. Staging deploys the immutable
  `staging-<sha>` image tag; the commit SHA is the deployed identity and is verifiable (`F-51`).
- A production rollout. Production remains reserved; the promotion job verifies and records.
- Pushing or running the workflows; no workflow run is claimed.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | One build per commit; artifacts carry digests. | Plan `061` |
| R-02 | Staging deploys by an immutable identity, never a branch. | Plan `061` outcome |
| R-03 | The deployed identity is retrievable from the running system. | Plan `061` outcome |
| R-04 | Promotion downloads and verifies, never rebuilds. | Plan `061` outcome |
| R-05 | The digest travels with the artifact and is checked. | Release manifest |
| R-06 | A malformed release identity fails startup. | Config contract |
| R-07 | The deployed staging identity must match before promotion. | Promotion guard |
| R-08 | No secret is exposed in health output. | `API-34` |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-004` CI/release workflow | **REQUIRES_REVIEW** |
| `EP-01-054` four bundles | **REQUIRES_REVIEW** — gate passes locally |
| `EP-01-060` staging topology | **REQUIRES_REVIEW** — verified live; `F-49` stale API |

## 6. Implementation plan

1. Read the release workflows, manifest and health contract.
2. Add the optional release identity to config and the health response.
3. Regenerate OpenAPI and the client.
4. Emit and upload the manifest digest from the staging build.
5. Verify the digest and the live staging identity during promotion.
6. Inject `RELEASE_SHA` into the Fly deployment and assert it in smoke.
7. Add tests and run the local gates.
8. Record the remaining Pages automation and image-digest limits.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| Release manifest | **Reuse** | Already records per-bundle digests |
| `verify-release-manifest.mjs` | **Reuse** | Promotion already verifies bytes |
| `deploy-staging.yml` artifacts | **Extend** | Add the manifest digest file |
| `deploy-production.yml` | **Extend** | Add digest and live-identity checks |
| `deploy-fly-staging.yml` | **Extend** | Inject and assert `RELEASE_SHA` |
| Health endpoint | **Extend** | The running system now answers the identity question |
| `parseConfig` | **Extend** | Validated, optional, no secret |

**Must not be duplicated:** a second digest calculation, a second release manifest, or a second
version endpoint.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/config.ts` | `RELEASE_SHA`, `RELEASE_DIGEST` |
| `server/src/health/health.controller.ts` | Reports the release identity |
| `server/src/contracts/schemas.ts` | Health schema |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `.env.example`, `config/configuration-contract.json` | Two public keys |
| `.github/workflows/deploy-staging.yml` | Digest artifact |
| `.github/workflows/deploy-production.yml` | Digest and live-identity checks |
| `.github/workflows/deploy-fly-staging.yml` | `RELEASE_SHA` injection and smoke assert |
| `tests/server-config.test.ts`, `tests/server-app.test.ts` | Release identity checks |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration or secret value changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `RELEASE_SHA` and `RELEASE_DIGEST` are validated and optional. |
| DoD-02 | Health reports both fields, null when unset. |
| DoD-03 | OpenAPI and the generated client include the fields. |
| DoD-04 | Staging build emits and uploads the manifest digest. |
| DoD-05 | Promotion verifies the digest against the manifest bytes. |
| DoD-06 | Promotion refuses when staging reports a different `releaseSha`. |
| DoD-07 | Fly deploy injects `RELEASE_SHA`; smoke fails on a mismatch. |
| DoD-08 | Local gates pass. |
| DoD-09 | No rebuild appears in the promotion job. |

## 10. Acceptance criteria

- `parseConfig` maps a valid SHA/digest and rejects a malformed one.
- `/v1/health/live` includes `releaseSha` and `releaseDigest`.
- The generated `HealthResponse` type includes both.
- The staging workflow writes `sha256:<manifest-digest>`.
- Promotion verifies the digest and the live staging SHA before proceeding.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/server-config.test.ts tests/server-app.test.ts` |
| T-02 | `pnpm test -- tests/openapi-contract.test.ts tests/api-client.test.ts` |
| T-03 | `pnpm test:release`, `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `config:check` |
| T-05 | Full suite |
| T-06 | Workflow execution on staging — not run here |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Health could leak a secret. | The fields are public identifiers; no token, key or URL is added. |
| A stale staging image passes promotion. | The live `/v1/health/live` SHA must match; currently this closes `F-49` on the next deploy. |
| The manifest digest could be computed over different bytes. | The same downloaded file is hashed; any difference refuses. |
| The Fly image is addressed by tag, not digest. | The tag is the commit SHA and immutable per commit; the limit is recorded as `F-51`. |
| Pages rollout is manual. | Recorded as `F-50`; the digest-verified artifact is ready. |
| Workflows are unrun. | Status remains `REQUIRES_REVIEW`; no run is claimed. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | A staging run deploys the current SHA, `/v1/health/live` reports it, and promotion verifies the digest with no rebuild; `F-50`/`F-51` are accepted or closed |
| **Execution record** | `execution-records/EP-01-061.md` |
