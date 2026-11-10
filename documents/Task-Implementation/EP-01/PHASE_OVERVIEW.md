# EP-01 — Phase Overview
## Core Platform Foundation & Infrastructure

| Field | Value |
|---|---|
| **Phase ID** | `EP-01` |
| **Phase name** | Core Platform Foundation & Infrastructure |
| **Roadmap phase served** | Phase 0 → Phase 1 |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` |
| **Phase record root** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/` |
| **Task documentation root** | `documents/Task-Implementation/EP-01/` |
| **Entry record** | `EP-01-ENTRY-RECORD.md` — `Verified`, 2026-11-07; phase opened |
| **Phase status at this overview** | **`In build`** — opened 2026-11-07; reconciled against the as-built repository on 2026-11-09 |
| **Total tasks** | **39** (`001`–`072`, per the approved plan §11) |
| **Completed** | 3 (`001`, `002`, `003`) |
| **Implemented but not verified** | 17 work packages (see §5) |
| **Not implemented or materially incomplete** | 19 work packages (see §5) |
| **Closure authority** | Founder, on the architect's recommendation, through G5 (`072`) |

> **Why this file exists.** The approved phase plan defines *what* EP-01 must achieve. It does not
> carry the per-task implementation plans, DoDs, tracker and execution records that the development
> protocol requires. This overview and its sibling tracker are those records. They describe the
> repository as it actually is on 2026-11-09, not the planning snapshot of 2026-11-06.

---

## 1. Phase objectives

EP-01 establishes the architecture, module boundaries, server-side enforcement path and core
platform services every later phase depends on:

1. One build graph across the root web app, `server/`, `packages/*` and `apps/*`.
2. One backend shape: NestJS + Fastify modular monolith with bounded modules.
3. One enforcement path: route guard → service-layer capability decision inside the transaction →
   RLS as defence in depth.
4. One identity foundation: accounts, users, credentials, sessions, devices, memberships, grants,
   session audiences and MFA-ready schema.
5. One activity model: six activities as registry rows and state, never account types.
6. One capability computation: pure, deterministic, default-deny, with stable deny reasons.
7. One audit trail: append-only, written by the service layer.
8. One design system, extracted from the prototype without visual change.
9. One delivery posture: build once, digest, promote; staging mirrors production topology.
10. One evidence rule: no status above `Not started` without a linked artifact.

**No user-facing business capability is delivered by EP-01.** It is engineering bedrock.

---

## 2. Scope

### 2.1 In scope

- Workspace topology, package boundaries and import enforcement.
- `@hivorr/shared`, `@hivorr/design`, `@hivorr/api-client`; four portal bundles
  (`web`, `control`, `staff`, `partner`).
- NestJS + Fastify API, worker, PostgreSQL-backed queue and transactional outbox.
- PostgreSQL 16-compatible schema-per-module, migration runner, five-role model, RLS scaffolding.
- Identity and authentication foundation, including audience-scoped sessions and MFA-ready schema.
- Activity registry, activation state machine, capability computation and the guarded vertical slice.
- Append-only `platform.audit_log` skeleton and structured logging.
- Design tokens, slice primitives, route manifest, router, four bundles and visual regression.
- Three-environment separation; staging topology; build-once artifact; migration application.
- CI gates for typecheck, lint, test, build, OpenAPI diff, migration lint/`db diff`, visual
  regression, dependency and secret scanning.

### 2.2 Out of scope — must not be built in EP-01

- Verification lanes, KYC cases, document upload, private buckets, review queues.
- Financial ledger, escrow, payout, provider adapter, deposit webhook, reconciliation.
- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- `control.` review features, staff job functions, partner programme features. Bundles exist;
  features do not.
- Taxonomy registry, messaging/notification features, AI, public API, multi-region, offline sync,
  native apps.
- Production deployment. EP-01 exits on staging; G4 is later.
- Full extraction of all 82 prototype screens. Slice-only extraction (ruling R2, §6.2 of the entry
  record; superseded bundle reading in §6.3).
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or
  `ARCHITECTURE.md` by an agent.

---

## 3. Dependencies and prerequisites

### 3.1 Entry gate — closed 2026-11-07

| Condition | State | Evidence |
|---|---|---|
| EP-00 exit evidenced | **Met** — G5 signed 2026-11-07 | `EP-00-011` §6 |
| Managed Postgres provider (`#1`) | **Decided** — Supabase, managed Postgres only | `ARCHITECTURE.md` §16.4 `#1` |
| Hosting, DNS, TLS (`#17`) | **Decided** — Cloudflare edge/Pages, Fly.io API and worker | `ARCHITECTURE.md` §16.4 `#17` |
| Sign-in identifier (`#14`) | **Decided** — email-first | `ARCHITECTURE.md` §16.4 `#14` |

### 3.2 Standing conditions

| Condition | State | Effect |
|---|---|---|
| `DEV-002` — host protection gap | **In force**; ends at EP-01 `G5` or earlier | `main` is not protected; compensating controls only |
| `DEV-003` — second reviewer | **In force**; ends at reviewer appointment or EP-01 `G5` | Sensitive changes need the recorded compensating controls |
| `TEC-12` — vendor data processing | **Approved for staging**; open items must close before production | Blocks production use of Supabase, Cloudflare, Fly.io, R2, Sentry |
| `EX-10` — test toolchain residual | **Approved in full** (Playwright, Testcontainers, Testing Library) | Row closes when all three are installed and gated in CI |
| Architect review | Founder holds both roles | G2 on auth/capability/migration changes needs the `DEV-003` controls |

### 3.3 Recorded technical selections — status and deviations

The entry record §5 records five architect selections. The as-built code does not match three of them.
This is recorded here as a finding, not resolved by an agent.

| Selection | Recorded | As built | State |
|---|---|---|---|
| DB driver | `pg` | `pg` 8.16.3 | **Matches** |
| Migration runner | Supabase CLI migrations | Versioned SQL + `scripts/apply-migrations.mjs` | **Deviation — needs ratification** |
| Queue | `graphile-worker` | Custom lease-based `platform.outbox` consumer | **Deviation — needs ratification** |
| OpenAPI generator | `@nestjs/swagger` | Not installed; `packages/api-client` is a boundary stub | **Pending — task `013`** |
| Boundary lint | `dependency-cruiser` | `scripts/lint-boundaries.mjs` | **Deviation — needs ratification** |

---

## 4. As-built reality check — 2026-11-09

The approved plan's opening statement — *"zero commits, no CI, no test runner, no server, no schema
and no authentication"* — is stale. The repository has advanced well past it. The plan is **not**
edited; the drift is recorded here.

| Area | Verified state on 2026-11-09 | Evidence |
|---|---|---|
| Git | `main`/`staging` flow, merged PRs through #42; clean working tree at `8d461d2` | `git log`, `git status` |
| Workspace | `pnpm-workspace.yaml` covers `.`, `apps/*`, `server`, `packages/*` | file |
| Packages | `@hivorr/shared`, `@hivorr/design`, `@hivorr/api-client`, `@hivorr/server`, `@hivorr/app-control`, `@hivorr/app-staff`, `@hivorr/app-partner` | package manifests |
| Boundary lint | 35 workspace source files checked, green | `pnpm lint:boundaries` |
| API | NestJS 12 + Fastify 5, `/v1`, validated config, health/live/ready, correlation IDs, error filter | `server/src/**` |
| Identity | Accounts, users, credentials (Argon2id), sessions, refresh rotation, devices, memberships, grants, TOTP MFA, recovery codes | migrations + `identity.service.ts` |
| Capabilities | Pure default-deny function over authenticated/audience/grants | `server/src/domain/capabilities.ts` |
| Database | 11 migrations: 10 module schemas + `private`, platform tables, roles/grants, UUIDv7, identity tables, RLS + FORCE, session lookup, MFA, refresh tokens, grants, outbox | `supabase/migrations` |
| Worker | Lease-based outbox consumer, retry/backoff, dead-letter, health | `server/src/worker/**` |
| Frontend foundation | Four bundles build; `@hivorr/design` and `@hivorr/api-client` are **empty boundaries**; root app is still the prototype | `packages/*/src/index.ts`, `src/main.tsx` |
| Visual regression / E2E | **Not installed** — no Playwright, no baseline | dependency list |
| OpenAPI | **Not generated** — no `@nestjs/swagger`, no contract diff stage | dependency list, CI |
| Audit | `platform.audit_log` exists; writes exist only for grants; **no sign-in or activity audit, no audit read API** | `grants.service.ts`, `capabilities.ts` |
| Profile / activities | Schema absent; no registry, no activation endpoint | migrations, server modules |
| Staging | Four hosts live with TLS, `/api/*` same-origin proxy, Cloudflare Access, Fly API/worker | `STAGING_PROVISIONING.md` |
| CI | Six jobs (install, lint, typecheck, test, database, build, security), no OpenAPI/visual/migration-diff gates | `.github/workflows/ci.yml` |
| Local gates | `pnpm verify` — see §4.1 | command output |

### 4.1 Local gate result

- `pnpm check:toolchain` — OK (node 22.23.4, pnpm 10.34.9).
- `pnpm lint` — OK, 20 known baseline violations, 0 new.
- `pnpm lint:boundaries` — OK, 35 files.
- `pnpm topology:verify` — OK, 8 hosts.
- `pnpm typecheck` — **failed on first run** because the workstation had never installed the new
  `server` workspace dependencies (`Cannot find module '@nestjs/common'` and similar). After
  `pnpm install --frozen-lockfile`, typecheck exits 0. This was workstation state, not a repository
  defect; the frozen install is the correct first step and is recorded as finding `F-10`.
- `pnpm test` — **8 files / 55 tests pass, 4 files fail to load** on this Windows workstation because
  `@node-rs/argon2` cannot resolve its native binding. The cause is the deliberate
  `supportedArchitectures: os: [linux]` policy in `pnpm-workspace.yaml`, which installs only the
  Linux optional dependency set. The 4 failing suites import the identity service. This is an
  environment limitation, not a test failure; the readiness contract that pins the Linux reference
  architecture is left unchanged. CI on Linux remains the reference environment (`F-10`).
- `pnpm build:all` — OK: main bundle plus `control`, `staff`, `partner`.
- `pnpm build:server` — OK: shared declarations, API/worker build, CommonJS finalisation.
- `pnpm test:push-protection`, `pnpm test:release`, `pnpm test:topology` — all pass.

### 4.2 Findings — recorded, not resolved

| ID | Finding | Owner | Disposition |
|---|---|---|---|
| **F-01** | The phase plan's "not started" snapshot is stale. | Architect | Recorded here; plan not edited. |
| **F-02** | 37 of 39 work packages (`002`–`072`) had no task plan, DoD or execution record. | Architect | This documentation set. |
| **F-03** | Three recorded technical selections were replaced without a recorded ruling (§3.3). | Architect | **Closed 2026-11-09 by founder ruling** — the as-built custom boundary linter, migration runner and lease-based outbox are ratified. CI may encode them. |
| **F-04** | Secret management was GitHub environment secrets + `fly secrets`, not Doppler (`standards` §16 `#8`). `043` implements a provider-agnostic contract; the review left the provider ruling open. | Founder / architect | **Closed 2026-11-10 by founder ruling** — Doppler is not adopted. GitHub environment secrets + `fly secrets` are the provider for staging and production, with the recorded compensating controls. Standards §16 #8 needs a formal revision; residual: manual rotation and GitHub Free reviewer limits. |
| **F-05** | `profile` schema, activity registry and activation state machine are absent. Blocks `033`, `035` and exit criterion 3. | Architect | Scheduled as `024`, `033`, `035`. |
| **F-06** | Audit writes exist for grants only. Sign-in and activity activation are not audited; no read API. | Architect | Scheduled as `035`, `036`. |
| **F-07** | Frontend foundation is not started: design tokens, router, slice screens and visual baseline are absent. | Architect | Scheduled as `050`–`053`. |
| **F-08** | Staging is live but `/health/ready` returns 503 by design, `DATABASE_SSL_CA` is unset and Pages deployment is not automated from the release manifest. | Architect | Remaining scope of `060`. |
| **F-09** | `RELEASE_PIPELINE.md` says no hosted staging exists; `STAGING_PROVISIONING.md` says it is live. | Architect | Document contradiction; do not resolve silently. |
| **F-10** | A fresh workstation fails `pnpm typecheck` until `pnpm install` runs, and cannot execute the four argon2-dependent suites on Windows because `supportedArchitectures` is pinned to Linux. | Developer | Documented; CI on Linux is the reference. No control weakened. |
| **F-11** | `packages/shared` carried only environment/portal contracts; capability constants, error codes, route IDs and zod schemas lived in `server/src`. | Architect | **Closed 2026-11-09 by `003`** — vocabulary moved to shared, duplicated in server; computation stays server-side. |
| **F-12** | Eleven applied migrations predate §9.3 naming and §9.4 self-containment. Applied migrations cannot be renamed (§9.3). | Architect | `004` grandfathers them in `lint:migrations`; new files are strict. Permanent exception unless the set is rebaselined. |
| **F-13** | CI's OpenAPI and visual gates had no real artefact: `013` publishes the contract and `050` the visual baseline, and `050` depends on `004`. | Architect | **OpenAPI half closed 2026-11-09 by `013`** — `openapi/openapi.json` exists and the diff gate is active. The visual half remains owned by `050`. |
| **F-14** | `@hivorr/shared` exported `src/index.ts` and its compiled ESM used extensionless specifiers, so the compiled API could not load it; the runtime image also omitted the package. | Architect | **Closed 2026-11-09 by `010`** — compiled ESM exports, server dependency declared, Docker runtime copy, `test:api` enforces it. |
| **F-15** | `STAGING_PROVISIONING.md` lines 29 and 131-132 describe `/health/live` and `/health/ready`; the API serves `/v1/health/...`, and `fly.staging.api.toml` already uses `/v1/health/live`. | Architect | Documentation correction; reported, not edited. |
| **F-16** | The shared error contract had no activity-inactive code, so five distinguishable outcomes could not be expressed. | Architect | **Closed 2026-11-09 by `011`** — `ACTIVITY_INACTIVE` plus a factory. |
| **F-17** | Zod object schemas stripped unknown request fields instead of rejecting them, contrary to SEC-23/API-06. | Architect | **Closed 2026-11-09 by `011`** — strict schemas and one validation helper. |
| **F-18** | `GET /v1/grants` and `GET /v1/control/grants` return unbounded arrays; the pagination primitive exists but is not applied. | Architect / grant module | Adopt before `013` fixes the API contract. |
| **F-19** | `tests/grants-integration.test.ts` never runs against Postgres in CI; the database job runs identity only. | Architect | Add a `test:grants` step before the grant module closes. |
| **F-20** | No handler execution deadline (API-07); only Fastify request receipt is bounded. | Architect | Decision required: a global interceptor affects future SSE. |
| **F-21** | `grants` and `health` sat outside the ten-module structure: grants is identity-owned and health is infrastructure. | Architect | **Closed 2026-11-09 by `012`** — grants under `identity`, health under `server/src/health`. |
| **F-22** | Identity and grants inserted into `platform.audit_log` across the module boundary. | Architect | **Closed 2026-11-09 by `012`** — `appendAudit` is the platform public interface. |
| **F-23** | No OpenAPI document or generated client existed; the diff gate had no artefact. | Architect | **Closed 2026-11-09 by `013`** — 3.1 document, typed client, drift checks. |
| **F-24** | The contract and client could drift from the implemented endpoints. | Architect | **Closed 2026-11-09 by `013`** — in-process equality and `openapi:check` regeneration. |
| **F-25** | The worker had no process, health-endpoint or loop evidence. | Architect | **Closed 2026-11-09 by `014`** — loop and health tests, process smoke, CI wiring. |
| **F-26** | The plan lists `024` as a dependency of `014`, but `024` is pending while the worker is implemented; the required platform tables already exist from `002`/`011`. | Architect | Re-sequence the plan or record the dependency exception. |
| **F-27** | Environment status is recorded three ways: `config/environments.json` said staging `planned`, `config/backend-projects.json` says `active`, and `STAGING_PROVISIONING.md` describes it as live. | Architect | **Closed 2026-11-10 by `060`** — live probe passed, topology says staging `verified` with dated evidence; production stays `reserved`. |
| **F-28** | No committed `supabase/schema-baseline.txt`; the schema diff publishes a head snapshot but cannot report a clean comparison against a base. | Architect / implementer | Generate the baseline from a migrated database in CI and commit it. |
| **F-29** | The runbook says migrations are applied as `hivorr_migrator`, but the role is `nologin` and the runner connects with the provider admin; default privileges are scoped to the applying role. | Architect | **Accepted 2026-11-10** — the migration job uses a distinct CI-only `MIGRATOR_DATABASE_URL`, never set on Fly; `hivorr_migrator` stays `nologin`; a login migrator role is a pre-production follow-up. |
| **F-30** | Four identity tables (`memberships`, `devices`, `recovery_codes`, `tokens`) had no table comment. | Architect | **Closed 2026-11-09 by `023`** — forward-only comment migration and a catalog assertion. |
| **F-31** | The profile module had no tables and activity state had no schema. | Architect | **Closed 2026-11-09 by `024`** — shared profile, four-state activations, RLS, grants and tests. |
| **F-32** | Platform system tables (`audit_log`, `outbox`, `idempotency_keys`, `feature_flags`, `reference_counters`) have no RLS and no account column. | Architect | Ruling needed on whether the "every EP-01 table" RLS rule covers service-internal system tables. |
| **F-33** | The unit-of-work helper is adopted in grants and registration; session, MFA and grant flows still use manual transaction blocks. | Architect / `031`/`032` | Adopt when those flows are extracted. |
| **F-34** | Account recovery delivers through a capture-only adapter; no email or SMS provider is selected. | Architect | When the delivery vendor is approved; the service contract is provider-independent. |
| **F-35** | Suspension revocation happens on the next session read/refresh, not at the moment of suspension. | Architect / `036` | Add an admin suspension action that revokes sessions immediately. |
| **F-36** | The permission matrix defines the four activation states but not the transition table; `033` adopted a minimal table. | Architect | Ratify or amend the transition table. |
| **F-37** | The KYC ladder beyond `tier_1` is OPEN; the capability engine models `tier_0` versus `tier_1` and above. | Architect | When the financial ladder is decided. |
| **F-38** | `035` depends on `036`, which is still pending; the guarded audit probe uses the existing append-only table as a stopgap. | Architect / `036` | **Closed 2026-11-09 by `036`** — audit service and read model are implemented. |
| **F-39** | Audit retention, legal hold and export are not decided. | Architect | Before an independent audit or a retention commitment. |
| **F-40** | Redaction is key-based; a free-text provider error could carry PII into a worker log. | Architect | When a vendor adapter or log drain is selected. |
| **F-41** | Authentication rate limits are per process; a multi-instance deployment needs a shared store. | Architect | Before horizontal scaling. |
| **F-42** | New-location detection is approximated by auditing every privileged sign-in with the row IP; no location history exists. | Architect | When geo/device history is introduced. |
| **F-43** | The visual baseline covers the entry screens only; dashboard screens load hero images from Unsplash, so their baselines are deferred to `053`. | Architect | Before `053` claims full-screen coverage. |
| **F-44** | Visual determinism is pinned to Windows + Playwright Chromium and depends on Google Fonts; the first CI run must confirm the baseline matches. | Architect | Next CI run; regenerate and re-approve if it differs. |
| **F-45** | The prototype's `C.gray` (`#6B7280`) has no `--hivorr-gray` token; the design package uses `var(--muted-foreground)`, which holds the same value. Adding the token requires editing the protected `theme.css`. | Architect | When `theme.css` is next opened. |
| **F-46** | The approved URL table has no password-reset or email-verification routes, yet `053` needs token-capture URLs. The app shell does not invent paths. | Architect / founder | **Closed 2026-11-10** — founder approved `/forgot-password`, `/reset-password`, `/verify-email`; token in the query. |
| **F-47** | The auth gradient stops (`#1A2AD4`, `#4F5FEF`) are approved values but have no `theme.css` tokens, and the file is protected. Pixel-identical auth screens need a token addition or permission for the prototype's literals. | Founder / architect | **Closed 2026-11-10** — founder approved additive `--hivorr-gradient-auth` and the deep-blue anchors. |
| **F-48** | The prototype's signup collects Full name, Email, Phone and Country; the register API accepts email, password and displayName only. Pixel identity would require dead fields; wiring the API diverges. | Founder / architect | **Closed 2026-11-10** — founder accepted the name/email/password divergence; phone/country follow the profile contract. |
| **F-49** | The deployed staging API predates `/v1/session` and `/v1/activities`; both return 404 while auth routes exist. | Founder | `061` deploys the current digest. |
| **F-50** | The frontend Pages rollout is manual; CI produces and verifies a digest-stamped artifact but does not deploy it to Pages. | Architect / founder | Before `063` can rely on automatic staging. |
| **F-51** | The API image is addressed by the immutable `staging-<sha>` tag; the registry digest is not captured, so `RELEASE_DIGEST` has no injector. | Architect | When flyctl digest capture is verified. |

---

## 5. Task inventory, statuses and execution sequence

**Status vocabulary** (protocol): `PENDING`, `IN_PROGRESS`, `COMPLETED`, `BLOCKED`,
`REQUIRES_REVIEW`.

- `COMPLETED` — DoD satisfied and validated, with an execution record.
- `REQUIRES_REVIEW` — code exists and basic gates pass, but the task's DoD has not been verified
  against an artifact, or a recorded deviation needs an architect ruling.
- `PENDING` — the task's outcome does not yet exist, or a material part of its scope does not.

| Order | Task | Title | Dependencies | Status |
|---:|---|---|---|---|
| 1 | `EP-01-001` | Entry gate closure and decision register | EP-00 exit | **COMPLETED** (2026-11-07) |
| 2 | `EP-01-002` | Workspace topology and package boundaries | `001` | **COMPLETED** (2026-11-09) |
| 3 | `EP-01-003` | Shared contracts package | `002` | **COMPLETED** (2026-11-09) |
| 4 | `EP-01-004` | CI pipeline extension | `002`, `003` | **REQUIRES_REVIEW** — gate code and seeded proofs pass; live pipeline run not yet observed |
| 5 | `EP-01-010` | API bootstrap and runtime configuration | `002`, `004` | **REQUIRES_REVIEW** — HTTP suite and process smoke wired; Linux run not yet observed (`F-14` fixed) |
| 6 | `EP-01-011` | Common request pipeline and error contract | `010` | **REQUIRES_REVIEW** — primitives and guard pass locally; controller metadata and HTTP deny paths are Linux-only |
| 7 | `EP-01-012` | Ten-module boundary skeleton | `010`, `011` | **COMPLETED** (2026-11-09) |
| 8 | `EP-01-013` | OpenAPI 3.1 contract and generated client | `010`–`012` | **REQUIRES_REVIEW** — document and client generated; route coverage and committed-tree check need Linux CI; `052` consumes it |
| 9 | `EP-01-014` | Worker, PostgreSQL queue and outbox | `012`, `024` | **REQUIRES_REVIEW** — loop, health and process smoke pass locally; the Postgres suite is CI-only |
| 10 | `EP-01-020` | Managed PostgreSQL and environment configuration | `001` | **REQUIRES_REVIEW** — topology, TLS, roles and `db:check` pass locally; live run and `F-27` remain |
| 11 | `EP-01-021` | Migration runner and baseline schemas | `020` | **REQUIRES_REVIEW** — runner/lint verified and history check added; live run and baseline (`F-28`) remain |
| 12 | `EP-01-022` | Database roles, grants and default privileges | `021` | **REQUIRES_REVIEW** — default-privilege migration and policy tests pass locally; DB denials run in CI (`F-29`) |
| 13 | `EP-01-023` | Identity schema | `021`, `022` | **REQUIRES_REVIEW** — schema policy passes locally; catalog and integration suites run in CI |
| 14 | `EP-01-024` | Profile, activity and platform schema | `021`, `022` | **REQUIRES_REVIEW** — profile/activation schema and policy pass locally; constraint and RLS assertions run in CI |
| 15 | `EP-01-025` | RLS pattern, identity context and policy tests | `022`-`024` | **REQUIRES_REVIEW** — private helpers, FORCE RLS and policy map pass locally; catalog and pre-auth assertions run in CI (`F-32`) |
| 16 | `EP-01-026` | Repository and transaction foundation | `021`-`025` | **REQUIRES_REVIEW** — unit-of-work tests pass locally; grants adopted; identity adoption is `030` (`F-33`) |
| 17 | `EP-01-030` | Identity domain and repositories | `023`, `026` | **REQUIRES_REVIEW** — domain/repository tests pass; registration uses the unit of work; remaining flows are `031`/`032` |
| 18 | `EP-01-031` | Registration, credentials and account recovery | `030` | **REQUIRES_REVIEW** — policy/contract pass locally; recovery integration runs in CI; delivery is capture-only (`F-34`) |
| 19 | `EP-01-032` | Session lifecycle, audiences and session endpoint | `031` | **REQUIRES_REVIEW** — `/v1/session` view and suspension revocation implemented; integration runs in CI (`F-35`) |
| 20 | `EP-01-033` | Activity registry and activation state machine | `024`, `030` | **REQUIRES_REVIEW** — domain state machine and endpoints pass locally; trigger/lifecycle run in CI (`F-36`) |
| 21 | `EP-01-034` | Capability computation engine | `033` | **COMPLETED** (2026-11-09) |
| 22 | `EP-01-036` | Audit logging service and immutability | `024`, `026` | **REQUIRES_REVIEW** — summaries, read model and failure tests pass locally; immutability runs in CI (`F-39`) |
| 23 | `EP-01-035` | Service-layer enforcement and vertical-slice endpoints | `032`, `034`, `036` | **REQUIRES_REVIEW** — enforcement and audit probe pass locally; deny/allow run in CI; `036` completes the audit service (`F-38`) |
| 24 | `EP-01-040` | Structured logging, correlation and error-tracking seam | `010`, `011` | **REQUIRES_REVIEW** — logger/redaction/filter tests pass locally; live wiring is CI smoke (`F-40`) |
| 25 | `EP-01-042` | Authentication abuse controls | `032` | **REQUIRES_REVIEW** — limiter/config/header tests pass; lockout and privileged audit run in CI (`F-41`, `F-42`) |
| 26 | `EP-01-043` | Secret management and configuration contract | `020` | **REQUIRES_REVIEW** — contract/template/topology/startup tests pass; provider ruling `F-04` and CI remain |
| 27 | `EP-01-041` | Edge and origin security posture | `032`, `060` | **REQUIRES_REVIEW** |
| 28 | `EP-01-050` | Visual regression baseline and harness | `004` | **REQUIRES_REVIEW** — baseline approved 2026-11-10; nine-image determinism and one-pixel gate proven locally; first CI run remains (`F-43`, `F-44`) |
| 29 | `EP-01-051` | Design tokens and primitive extraction for the slice | `050`, `002` | **REQUIRES_REVIEW** — tokens + 3 primitives; 9 exact parity checks at 3 widths; approved baseline unchanged; CI parity run remains (`F-45`) |
| 30 | `EP-01-052` | Route manifest, router and providers | `003`, `013`, `050`, `051` | **REQUIRES_REVIEW** — five slice routes + real 404 + TanStack Query/session context; 15 checks; CI and the `053` mount remain (`F-46`) |
| 31 | `EP-01-053` | Vertical-slice screens | `032`, `034`, `035`, `051`, `052` | **REQUIRES_REVIEW** — slice live; sign-in exact at 3 widths; MFA/reset/verify/activity wired; live E2E in `063` |
| 32 | `EP-01-054` | Four-bundle build and deployment targets | `002`, `052` | **REQUIRES_REVIEW** — four bundles, noindex and 200 KB gzip gate; release manifest verified; CI remains |
| 33 | `EP-01-060` | Environment topology and staging provisioning | `001`, `020`, `043` | **REQUIRES_REVIEW** — four live hosts, valid TLS and Access challenges observed; staging `verified`; `F-49` stale API image and `F-08` remain |
| 34 | `EP-01-061` | Build-once artifact and promotion | `004`, `054`, `060` | **REQUIRES_REVIEW** — release identity in health; digest artifact + promotion guards; deployed SHA unobserved (`F-49`/`F-50`/`F-51`) |
| 35 | `EP-01-062` | Migration application pipeline | `021`, `022`, `060`, `061` | **REQUIRES_REVIEW** — plan/apply/verify + 8 unit checks; no DB/workflow run; `F-29` credential and `F-28` baseline remain |
| 36 | `EP-01-063` | Staging smoke, E2E and gate wiring | `061`, `062`, `053` | **REQUIRES_REVIEW** — blocking promotion gates; both correctly fail on `F-49`/`F-50` |
| 37 | `EP-01-070` | Phase evidence pack and traceability index | all prior | **REQUIRES_REVIEW** — pack complete; C1 met, 11 partial, 2 unmet (`C4`/`C12`), 2 open |
| 38 | `EP-01-071` | Phase-level security and quality review | `070` | **REQUIRES_REVIEW** — review complete; 0 critical, **2 high** (`F-49`, `F-50`); CI green |
| 39 | `EP-01-072` | G5 phase closure record | `070`, `071` | **PENDING** |

**Next eligible task:** **none.** `EP-01-072` cannot be signed while two high findings remain: `F-49`
(stale staging API) and `F-50` (slice/Pages rollout). CI run `42835621656` is green, closing the
no-CI finding; H-01 (`F-29`) is an accepted residual and H-05 (`F-04`) is resolved by the no-Doppler
ruling. `DEV-003` ends at `G5` or on a second reviewer's appointment.

### 5.1 Critical path for the remaining work

`003 → 004 → 011 → 012 → 024 → 025 → 033 → 036 → 035 → 053 → 063 → 070 → 071 → 072`

`050`–`052` run beside the backend path but must land before `053`. `040`, `042`, `043` and `041`
must land before `063`. `013` must land before `052` because the router consumes the generated client.

---

## 6. Architectural considerations

1. **The prototype remains the only visual authority.** No slice screen may introduce a hex value,
   font family, type size or radius that is not in `theme.css` / `App.tsx`.
2. **The service layer is authoritative.** Route guards and RLS are additional layers. Capability
   computation is pure and lives server-side.
3. **No shared tables.** A module reads only its own schema. `platform.audit_log` and
   `platform.outbox` are the only cross-cutting platform tables.
4. **Default deny.** Every new endpoint, capability, table and bucket starts closed.
5. **Migrations are self-contained and forward-only.** A table migration creates columns, keys,
   constraints, indexes, RLS, policies, grants and comments together.
6. **Audit is written by the service layer**, so reason and correlation ID are captured with the
   change.
7. **Secrets never enter a client bundle, a log, a migration, a seed or a screenshot.**
8. **Extraction is not redesign.** A screen is extracted only because it is being wired or extended.
9. **Evidence is an artifact a third party can inspect.** A status sentence is not evidence.
10. **No AI agent approves a gate, deploys, widens a permission or decides an open question.**

### 6.1 Recorded architectural deviations

- **Backend framework.** Approved architecture says NestJS + Fastify; the as-built uses NestJS 12 +
  Fastify 5. **Matches.**
- **Queue.** Recorded selection was `graphile-worker`; the as-built uses a custom lease-based outbox
  consumer. **Ratified 2026-11-09 — `F-03` closed.**
- **Boundary lint.** Recorded selection was `dependency-cruiser`; the as-built uses
  `scripts/lint-boundaries.mjs`. **Ratified 2026-11-09 — `F-03` closed.**
- **Migration runner.** Recorded selection was Supabase CLI; the as-built uses versioned SQL plus a
  custom runner. **Ratified 2026-11-09 — `F-03` closed.**
- **Secrets.** Recorded selection was Doppler; the founder ruled on 2026-11-10 that Doppler is **not**
  adopted. GitHub environment secrets and Fly secrets are the provider. **Closed — `F-04`.**
- **Activity model.** Not yet built; `activity.activate` is computed but no endpoint or table exists.
  **Gap — `F-05`.**

---

## 7. Completion criteria (from the approved plan §13)

| # | Criterion | State on 2026-11-09 |
|---|---|---|
| C1 | Entry gate satisfied | **Met** — `EP-01-001` signed |
| C2 | Build graph works | **Met in CI**; local clean-clone install verified 2026-11-09 |
| C3 | Contract is generated | **Unmet** — `013` |
| C4 | Schema is reproducible | **Partially met** — 11 migrations, custom runner; profile/activity absent |
| C5 | Least privilege proven | **Partially met** — roles and grants exist; deny tests not per-role |
| C6 | RLS fails closed | **Partially met** — identity RLS + FORCE; per-policy allow/deny suite incomplete |
| C7 | Session isolation proven | **Partially met** — audience rejection and rotation tests exist |
| C8 | Capability authority proven | **Partially met** — pure tests exist; unknown-capability and deny-reason tests incomplete |
| C9 | Enforcement proven in transaction | **Unmet** — `035` |
| C10 | Audit is immutable | **Unmet** — grants only; no sign-in/activation audit, no read API |
| C11 | Visual identity preserved | **Unmet** — `050`–`053` |
| C12 | Staging is provable | **Partially met** — live hosts; smoke/E2E and readiness pending |
| C13 | Operability baseline | **Partially met** — correlation IDs; no structured log/PII redaction/error tracker |
| C14 | Budgets captured | **Unmet** |
| C15 | Quality gates honest | **Partially met** — six gates; OpenAPI, visual, migration diff absent |
| C16 | Review complete | **Unmet** — `071` |
| C17 | Closure signed | **Unmet** — `072` |

**A criterion without an artifact is unmet. A phase is not `Completed` because its tasks are
`Completed`.**

---

## 8. Documentation method for this phase

The phase is being reconciled against an as-built repository that already contains most of the
foundation. Issuing 37 speculative task plans at once would describe a repository that does not exist
and would contradict the rule that documentation must reflect the codebase.

Therefore:

- `PHASE_OVERVIEW.md` and `PHASE_EXECUTION_TRACKER.md` are complete for **all 39 tasks**.
- Each task's implementation plan and DoD are issued in `tasks/` **when the task becomes eligible**,
  immediately before execution, using the standard 13-section format.
- Every executed task gets an execution record in `execution-records/`.
- Implemented-but-unverified work is `REQUIRES_REVIEW`; it is never marked `COMPLETED` on the
  strength of existing code alone.

This is a deliberate adaptation, recorded here for founder/architect approval. It changes no scope
and skips no task.

### 8.1 Reuse discipline — binding for every task

`AGENTS.md` §3 ("reuse before creating") and phase plan §10 ("bounded scope limits edits, not
understanding") apply to every task in this phase. The rolling method makes the check concrete
because the plan is written against the tree that exists on that day.

Every task document must contain an **Existing Components and Reusability** section that names:

1. The files, modules, services, utilities, types, tokens, tests and configuration inspected.
2. For each: `reuse as-is`, `extend`, `move`, or `replace` — with the reason.
3. What is genuinely new, and why nothing existing serves the need.
4. What must **not** be duplicated: a second capability list, error enum, portal definition, colour
   value, session helper, migration runner, queue or boundary linter.

The task DoD must include a check that no parallel implementation was introduced. The existing
controls that make this enforceable are reused rather than supplemented: `scripts/lint-boundaries.mjs`,
`tests/workspace-contracts.test.ts`, `tests/capabilities.test.ts`, `.lint-baseline.json` and the
`theme.css` token layer.

Worked examples for the next tasks:

- `003` extends `packages/shared/src/index.ts`, moves vocabulary out of
  `server/src/domain/capabilities.ts` and `server/src/common/errors.ts`, and reuses `zod` — it does not
  create a second capability list or validator.
- `051`/`052` copy the prototype's primitives and token values into `packages/design`; they never
  rewrite `App.tsx` and never re-invent a colour, radius or type size.
- `014` keeps the working lease-based outbox unless the architect ratifies the recorded
  `graphile-worker` selection; a working control is not replaced to match a stale line.


---

## 9. Related documentation

- `documents/Context/AGENTS.md` — AI working rules, visual preservation, vocabulary.
- `documents/Context/VISION.md` — product direction.
- `documents/Context/ARCHITECTURE.md` — system design and §16.4 open-decision register.
- `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` — account and permission model.
- `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` — database governance.
- `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` — engineering gates and §19
  audit readiness.
- `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md` — mandatory application security baseline.
- `documents/Context/VISUAL-IDENTITY.md` — written visual reference (prototype wins on conflict).
- `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md`
  — gates, work-package protocol and status vocabulary.
- `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` — entry gate,
  decisions and blocker matrix.
- `documents/Engineering-Execution/STAGING_PROVISIONING.md` — live staging topology.
- `documents/Engineering-Execution/RELEASE_PIPELINE.md` — build-once and promotion.
- `documents/Engineering-Execution/WORKER_AND_OUTBOX.md` — outbox contract.
- `documents/Engineering-Execution/BACKEND_ENVIRONMENT_SETUP.md` — environment variables and secrets.
- `documents/Engineering-Execution/TEC-12-VENDOR-DATA-PROCESSING.md` — vendor processing record.

---

**Overview status:** current to 2026-11-09. Task statuses change only through the tracker and an
execution record.
