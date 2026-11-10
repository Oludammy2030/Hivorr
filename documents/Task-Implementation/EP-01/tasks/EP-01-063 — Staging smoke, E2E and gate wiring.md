# EP-01-063 — Staging smoke, E2E and gate wiring

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-063` |
| **Task title** | Staging smoke, E2E and gate wiring |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — deployed-artifact evidence |
| **Execution order** | 35 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage G |
| **Dependencies** | `EP-01-061`, `EP-01-062`, `EP-01-053` |

## 2. Objective

Run post-deploy smoke checks and the Playwright E2E suite against the deployed digest, make them
blocking, and attach the results as evidence that the deployed artifact — not the local build —
satisfies the exit gate.

## 3. Scope

### 3.1 Included

- `scripts/smoke-staging.mjs` / `pnpm smoke:staging`:
  - health/live and the expected release SHA;
  - health/ready (503 is the current honest state);
  - session and activity routes deny anonymously;
  - sign-in validates without a 5xx;
  - all four hosts serve, with Cloudflare Access on the privileged three;
  - transient network retry, no credential, no token printed.
- `scripts/e2e-slice.mjs` / `pnpm e2e:slice`:
  - the deployed slice bundle is served;
  - the login screen renders;
  - an invalid sign-in shows a labelled error;
  - an unknown route renders the real 404;
  - an anonymous visit to `/` redirects to `/login`;
  - with `E2E_EMAIL`/`E2E_PASSWORD`, sign-in, the activity switcher and activation;
  - a failure screenshot.
- `deploy-production.yml`: blocking `smoke-staging` and `e2e-staging` jobs; `promote-release` needs
  both. A failed smoke or E2E stops promotion.

### 3.2 Observed result at this commit

Both scripts were run against live staging. They correctly **fail** on the known deployment state:

| Check | Result |
|---|---|
| health/live 200, staging | Pass |
| health/ready 503 `not_ready` | Pass |
| session denies anonymously | **Fail — 404** (`F-49`: stale image) |
| activities deny anonymously | **Fail — 404** (`F-49`) |
| sign-in validates | Pass |
| four hosts / Access | Pass |
| slice bundle deployed | **Fail — host serves a fallback** (`F-50`: manual Pages rollout) |

This is the gate doing its job: it refuses to promote the current staging deployment.

### 3.3 Excluded / remaining

- Deploying the current API digest (`F-49`) and the slice bundle (`F-50`). No push or provider
  credential is available here.
- Authenticated E2E without a test identity. CI reads `E2E_EMAIL`/`E2E_PASSWORD`; when absent, the
  authenticated branch is explicitly noted as skipped.
- A load/performance suite; `063` is functional smoke and E2E.
- Attaching results to a CI run — the workflow has not executed.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Smoke covers health and readiness. | Plan `063` |
| R-02 | Smoke covers sign-in, session and activity denials. | Plan `063` |
| R-03 | Every host is checked, with Access on the privileged three. | Plan `063` |
| R-04 | E2E reproduces the slice. | Plan `063` |
| R-05 | A failed smoke blocks promotion. | Plan `063` outcome |
| R-06 | Results are evidence, not an assertion. | Plan `063` outcome |
| R-07 | No credential is printed or committed. | `API-34` |
| R-08 | The deployed release identity is checked when supplied. | `EP-01-061` |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-061` release identity | **REQUIRES_REVIEW** — deployed SHA unobserved |
| `EP-01-062` migrations | **REQUIRES_REVIEW** — `F-29`/`F-28` |
| `EP-01-053` slice | **REQUIRES_REVIEW** — sign-in exact; E2E pending |
| `F-49` stale API image | Open |
| `F-50` manual Pages rollout | Open |

## 6. Implementation plan

1. Read the deployment workflows and the slice routes.
2. Write the smoke script with release identity and Access checks.
3. Write the E2E script for the unauthenticated path plus optional authenticated checks.
4. Wire both into production promotion as blocking jobs.
5. Run both against live staging and record the real result.
6. Run the local gates and update the records.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `verify-staging-hosts.mjs` | **Reuse pattern** | Host/TLS/Access checks |
| `smoke-api.mjs` | **Reuse pattern** | Process smoke and pass/fail style |
| Playwright 1.64.1 | **Reuse** | Already pinned |
| `slice.html` | **Target** | The deployed slice |
| Promotion workflow | **Extend** | Add blocking jobs |
| Release identity (`RELEASE_SHA`) | **Reuse** | Smoke asserts it |

**Must not be duplicated:** a second host list, a second health contract, a second Playwright install,
or a second promotion path.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/smoke-staging.mjs` | **New** |
| `scripts/e2e-slice.mjs` | **New** |
| `package.json` | `smoke:staging`, `e2e:slice` |
| `.github/workflows/deploy-production.yml` | Blocking smoke and E2E jobs |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No application, API, migration or secret changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Smoke checks health, readiness, session, activities and sign-in. |
| DoD-02 | Smoke checks all four hosts and Access. |
| DoD-03 | Smoke asserts `RELEASE_SHA` when supplied. |
| DoD-04 | E2E checks the entry, login, invalid sign-in, 404 and bootstrap redirect. |
| DoD-05 | Optional authenticated E2E signs in and activates. |
| DoD-06 | A failed smoke blocks promotion. |
| DoD-07 | Results are captured as evidence. |
| DoD-08 | No credential is printed. |
| DoD-09 | Local gates pass. |
| DoD-10 | The deployed run passes — **blocked** on `F-49`/`F-50`. |

## 10. Acceptance criteria

- `pnpm smoke:staging` returns non-zero on the current staging because session/activities are 404.
- After the current digest and slice are deployed, the same command returns zero.
- `pnpm e2e:slice` fails clearly when `/slice.html` is not the deployed bundle.
- `promote-release` cannot run when `smoke-staging` or `e2e-staging` fails.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm smoke:staging` against live staging — observed failure |
| T-02 | `pnpm e2e:slice --base https://staging.hivorr.com` — observed failure |
| T-03 | `pnpm test:gates`, typecheck, lint, boundaries, format |
| T-04 | CI promotion run after the deployments close `F-49`/`F-50` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The gate fails until the deployment is current. | That is its purpose; `F-49`/`F-50` are recorded. |
| Authenticated E2E has no identity. | Optional env credentials; the skip is printed and recorded. |
| Smoke hits a sleeping Fly machine. | GET retries three times, 1.5 s apart. |
| Secrets could leak. | No credential is sent by smoke; E2E never prints the values. |
| Access blocks a privileged host. | The smoke asserts the challenge, not the app behind it. |
| Promotion depends on staging uptime. | It already required a successful staging run. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | `F-49` and `F-50` are deployed, the smoke and E2E pass against staging, and the CI run is green |
| **Execution record** | `execution-records/EP-01-063.md` |
