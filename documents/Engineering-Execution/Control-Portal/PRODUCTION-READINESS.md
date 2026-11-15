# Control Portal — Production Readiness Plan

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/PRODUCTION-READINESS.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Date** | 15 November 2026 |
| **Status** | **PLAN — nothing provisioned, nothing deployed.** |
| **Scope** | Portal implementation → first production release |

> This plan states what production requires, what already exists, and what is missing. It is not an
> approval to deploy, and it provisions nothing. Every gate named here is a rule from
> `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` or `ARCHITECTURE.md §12`.

---

## 1. Where the codebase actually is

The application side is in good shape: twenty packages implemented, independently reviewed and signed
(§4.1 of the execution tracker), eleven database suites running in CI, and every merge commit on
`staging` with a green CI, Fly and staging-gate run.

What is absent is everything *around* the application: a production environment, production
configuration, and the release evidence `AR-4` requires.

| Area | State |
|---|---|
| Application code | Complete for CP-001 → CP-020 |
| CI gates | Green; database suites execute since #103 |
| Staging deployment | `staging.hivorr.com` family live, Fly `v61`+, Pages bundles deployed |
| Production environment | **Not provisioned** — no Fly app, no Postgres, no R2 bucket, no Pages project |
| Production configuration | **Incomplete** — `DATABASE_SSL_CA` unset; see §3 |
| Release evidence | Partial — no restore drill, no vulnerability triage, no DEP-23 record |
| Second reviewer | **Absent** — `DEV-002` deviation in force; `DEP-14` cannot be met as written |

## 2. The gate chain

A production release is not a deploy; it is a sequence of recorded gates. Each one is a rule, not a
suggestion.

| Gate | Rule | What it requires |
|---|---|---|
| Evidence review | `AR-4` | Traceability register, deployment record, restore drill, vulnerability status and open findings, complete enough that a reviewer who was not involved reaches the same conclusion |
| Named reviewer | `DEP-14` | A reviewer who is not the deployer, with no ability to affect the release |
| Founder approval per release | `DEP-15`, `DEP-23` | Approval of one release never authorises the next; each records who approved, when, the artifact digest and the outcome |
| Configuration through the pipeline | `DEP-16` | No host is edited by hand; configuration changes are versioned |
| Build-once promotion | `ARCHITECTURE §12.3` | The artifact verified on staging is the artifact promoted, by digest |
| Rollback rehearsal | `DEP-24` | Redeploy of the previous digest is rehearsed, not improvised |
| Migration discipline | `DEP-18`, `DEP-20` | Migrations reviewed as SQL, forward-only in production |

`deploy-production.yml` already enforces the mechanical half: founder-only dispatch, the
`DEPLOY_PRODUCTION` confirmation, a 40-hex release SHA, a release-candidate issue check, main-branch
ancestry, and the build-once manifest. It cannot enforce the human half — the named reviewer and the
evidence.

## 3. Production configuration

`server/src/config.ts` validates configuration at boot and refuses to run when a required value is
missing in `staging` or `production`. The table is the checklist; **status reflects today**.

| Variable | Required | Purpose | Status |
|---|---|---|---|
| `HIVORR_ENV=production` | yes | Environment identity; switches issuer and cache names | unset |
| `BACKEND_ENVIRONMENT` | yes | Which data plane this process talks to | unset |
| `SUPABASE_PROJECT_REF` | yes | Managed Postgres project | unset |
| `DATABASE_URL` | yes | API database role connection | unset |
| `DATABASE_SSL_CA` | **yes in production** | Verifies TLS to the managed database | unset — the API now **refuses to boot** in production without it |
| `SESSION_ISSUER` | yes | Session token issuer | unset |
| `MFA_ENCRYPTION_KEY` | yes | Encrypts TOTP secrets at rest | unset |
| `EDGE_SHARED_SECRET` | no, but required for forwarded-host trust | Lets the edge prove the original host | unset |
| `WORKER_DATABASE_URL`, `WORKER_*` | worker only | Outbox consumer | unset |
| `ZEPTOMAIL_TOKEN`, `MAIL_FROM_ADDRESS`, `PUBLIC_APP_ORIGIN` | email only | Invitations, reset, verification | unset |
| `CORS_ALLOWED_ORIGINS` | no | Browser origin allowlist | unset |
| `FOUNDER_GITHUB_LOGIN` (repo variable) | yes for deploy | Restricts production dispatch | **check** |

`DATABASE_SSL_CA` was a configuration trap: the variable was optional, so a production boot would
succeed while connecting to the managed database without certificate verification. It is now required
when `HIVORR_ENV=production`, and the API refuses to boot without it (#121).

## 4. What is missing, in the order it blocks

| # | Gap | Blocks | Nature |
|---|---|---|---|
| 1 | **Reviewer not named — founder is the only reviewer** (`DEP-14`) | `DEP-14` | `D-P0-1`: the deployer and the only reviewer are the same person, so the gate is unmet. Appointment terms in `D-P0-1A`; an agent cannot hold the seat |
| 2 | Production environment not provisioned | Everything | Fly API + worker, Postgres, R2, Pages project, DNS for the four production hosts |
| 3 | Production configuration incomplete | Boot | §3, including the TLS CA |
| 4 | No restore drill | `AR-4` | Restore a production-shaped database from backup and record the time and result |
| 5 | No vulnerability triage record | `AR-4` | The dependency scan runs; no one has triaged its output into a decision |
| 6 | No visual baseline or staging E2E | Release confidence | The control portal's UI evidence is a local browser pass with a mocked API (#116) |
| 7 | Errors are captured, not shipped | Operations | `CaptureErrorTracker` holds errors in memory and makes no network call; a production sink has to be chosen |
| 8 | No branch protection on `staging`/`main` | `QUA-29` | Compensating controls only: pre-push hook, branch guard, founder review |
| 9 | Legal hold and retention **decided** (`D-P0-4`), not implemented | Data governance | Seven-year retention with legal hold overriding; the mechanism belongs to CP-035/CP-038 |

## 5. Sequenced plan

### Phase 0 — Decisions only (no infrastructure)

**Decided 15 November 2026 — see `PRODUCTION-DECISIONS.md`.** A named reviewer will be appointed
(`D-P0-1`, with the appointment terms in `D-P0-1A`), the data plane is EU (`D-P0-2`), errors ship to
Sentry EU with scrubbing (`D-P0-3`), and retention is seven years with legal hold overriding
(`D-P0-4`).

The decision that still blocks is `D-P0-1`: the founder is currently the **only reviewer available**,
and the founder also dispatches the release, so `DEP-14` is unmet by definition. An agent cannot hold
the seat. Phase 1 provisioning should wait for a named reviewer.

### Phase 1 — Provision, least privilege first

1. Create the production Postgres project and roles (`hivorr_api`, `hivorr_worker`, `hivorr_readonly`,
   `hivorr_migrator`, `hivorr_breakglass`) exactly as migrations expect.
2. Create the R2 bucket (evidence, private) and the Pages project.
3. Create the Fly apps for API and worker; separate from staging, separate secrets.
4. DNS and TLS for `hivorr.com`, `control.hivorr.com`, `staff.hivorr.com`, `partner.hivorr.com`,
   with Cloudflare Access on the privileged three.
5. Confirm no staging credential can reach a production resource (`ARCHITECTURE §11.2`).

### Phase 2 — Configuration, through the pipeline

1. Set every variable in §3 with production values; set `DATABASE_SSL_CA` first.
2. Run `pnpm config:check` against the production configuration.
3. Boot the API against production Postgres and confirm `/v1/health/ready` answers honestly.

### Phase 3 — Evidence

1. **Migrations**: apply to production with the deployment runner, then `migrations:verify`.
2. **Restore drill**: restore from backup into an isolated database, record wall-clock time and
   verification query results.
3. **Vulnerability triage**: adjudicate `security:deps` output into fixed / accepted / not-applicable,
   with reasons.
4. **Smoke**: `scripts/smoke-staging.mjs --base <production host> --expect-sha <sha>` proves the
   deployed artifact, not the build.
5. **UI evidence**: one real pass per portal against production, recorded as screenshots and a
   timestamped note.

### Phase 4 — Release rehearsal

1. Promote a staging-verified digest through `deploy-production.yml` in a rehearsal window.
2. Execute the `DEP-23` record: who approved, when, digest, outcome.
3. Rehearse rollback by redeploying the previous digest (`DEP-24`) and recording the time.
4. Confirm audit rows, health, worker outbox and mail delivery in production.

### Phase 5 — First real release

Only after Phases 0–4 are recorded. `DEP-15` applies: this approval covers this release, not the
next one.

## 6. Exit criteria

A production release is approvable when all of these are true and recorded:

- [ ] Second reviewer appointed, or a production deviation signed with compensating controls
- [ ] Production environment provisioned with separate credentials and no staging path
- [ ] Every §3 variable set; `DATABASE_SSL_CA` set and verified
- [ ] Migrations applied and the history verified
- [ ] Restore drill completed with a recorded duration
- [ ] Vulnerability scan triaged with reasons
- [ ] Smoke passed against the production host with the promoted SHA
- [ ] A real browser pass per portal, recorded
- [ ] Rollback rehearsed
- [ ] `DEP-23` record written for this release

## 7. What "ready" does not mean

Following this plan does not make the portal complete. CP-021 → CP-024 are unbuilt, `D-11` (who may
recommend, approve and execute sanctions) and `D-12` (retention and legal hold) are undecided, and the
partner and staff portals are foundation shells. Production readiness here means the governance
surface that exists can be run safely and audited — not that the platform is finished.
