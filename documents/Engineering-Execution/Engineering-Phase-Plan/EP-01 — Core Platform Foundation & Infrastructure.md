# EP-01 — Core Platform Foundation & Infrastructure
## Engineering Phase Plan

**Planning basis:** `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` (approved 4 Nov 2026), `documents/Context/AGENTS.md`, `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`, `VISUAL-IDENTITY.md`, and `Business-Development-Roadmap.md`.

> **Phase status verdict: `Not started`.** This plan does not open EP-01 for build. The repository currently has **zero commits, no CI, no test runner, no server, no schema and no authentication**; EP-00 has not exited. EP-01 also depends on three open founder decisions (managed Postgres provider, hosting/DNS/TLS, sign-in identifier). Until those are evidenced, EP-01 cannot become `Ready` and no roadmap item below may start.

---

## 1. Phase definition

| Field | Detail |
| --- | --- |
| **Phase ID** | EP-01 |
| **Phase name** | Core Platform Foundation & Infrastructure |
| **Roadmap phase served** | Phase 0 → Phase 1 |
| **Phase priority** | Critical — blocks every product phase |
| **Phase status** | `Not started` |
| **Entry gate** | EP-00 exit evidenced; managed Postgres provider decided (`ARCHITECTURE.md` §16.4 #1); hosting, DNS and TLS decided (#17); sign-in identifier decided (#14). |
| **Exit gate** | One vertical slice works end to end on staging: sign in → session issued for the correct audience → a capability check denies and allows correctly → the action writes an audit record. Typecheck, lint and tests green in CI. Visual regression baseline approved by the founder. Staging runs the same artifact digest as the candidate release. |
| **Closure authority** | Founder, on the architect's recommendation, through G5. |
| **Duration** | Not estimated. A phase is a gate, not a date (ED-01). |

### 1.1 Phase objective

Establish the architecture, module boundaries, server-side enforcement path and core platform services that every later phase depends on: one repository, one API, one worker, one PostgreSQL database per environment, one identity service, one capability engine, one audit trail and one visual-regression-protected frontend foundation.

### 1.2 Business capability being enabled

**No user-facing business capability is delivered by EP-01.** It is the engineering bedrock that makes every later capability buildable, testable, deployable and auditable. What becomes true is narrower and deliberately so:

- An account can exist and sign in.
- A session is issued for the correct surface (`app`, `control`, `staff`, `partner`) and rejected elsewhere.
- An activity can be activated and its state is real.
- The server can allow or deny an action from computed capabilities, not from the client.
- Every privileged or state-changing action leaves an append-only audit record.
- The platform can be built once, deployed to staging as one artifact, and verified by CI.

This enables the roadmap's Phase 0 foundation work and the Phase 1 entry condition that a transaction can be taken on a system with identity, enforcement and evidence already in place.

---

## 2. Engineering objectives

1. **One build graph.** Extend the pnpm workspace to include `server/`, `packages/*` and `apps/*` without moving the root web app or breaking the Figma Make preview.
2. **One backend shape.** NestJS + Fastify modular monolith with ten module boundaries, schema ownership and enforced acyclic dependencies.
3. **One enforcement path.** Route guard → service-layer capability decision inside the transaction → RLS as defence in depth. The service layer is authoritative.
4. **One identity foundation.** Accounts, users, credentials, sessions, devices, memberships, grants, session audiences and MFA-ready schema.
5. **One activity model.** The six activities as registry entries and rows, not account types; activation is a separate, explicit act.
6. **One capability computation.** Pure, deterministic, default-deny, table-driven, with stable deny reasons.
7. **One audit trail.** Append-only, written by the service layer, separated from application logs.
8. **One design system.** The prototype's tokens and only the primitives the EP-01 screens need, extracted without visual change.
9. **One delivery posture.** Staging mirrors production topology; artifacts are built once, digested and promoted; migrations are reviewed and applied in order.
10. **One evidence rule.** No status above `Not started` without a linked artifact.

---

## 3. Technical goals

| ID | Technical goal | Measure |
| --- | --- | --- |
| **TG-01** | Clean clone is reproducible | Frozen lockfile install, typecheck, lint, test and build all green in CI on a clean checkout. |
| **TG-02** | Contract is generated, not hand-written | OpenAPI 3.1 emitted from the API; `@hivorr/api-client` generated; a breaking diff fails CI. |
| **TG-03** | Schema is reproducible | `db reset` from empty creates all ten module schemas, `private`, roles, grants and migration history; `db diff` clean. |
| **TG-04** | Database least privilege | `hivorr_api` cannot DDL, truncate or bypass RLS; migrator is CI-only; per-environment credentials. |
| **TG-05** | RLS fails closed | Every EP-01 table has RLS enabled, one policy per operation, and an allow **and** deny test. |
| **TG-06** | Session isolation | Sign-in issues a host-only `__Host-` cookie for the correct audience; a wrong-audience session is rejected; rotation, reuse detection and revocation are tested. |
| **TG-07** | Capability authority | Computation is pure and deterministic; unknown capability denies; every implemented capability has allow and deny tests; the check runs inside the transaction. |
| **TG-08** | Audit is immutable | Sign-in and activity activation write audit rows; no update or delete path exists; reads are scoped and audited. |
| **TG-09** | Visual identity survives | Baseline captured at 375 / 768 / 1280 before extraction; extracted screens are pixel-identical; no new hex or font family. |
| **TG-10** | Staging is provable | Staging runs the same artifact digest as the candidate; migrations applied in order; smoke and E2E green. |
| **TG-11** | Operability baseline | Structured logs with correlation IDs, PII redaction, health/readiness, queue health, error-tracking adapter with no vendor lock-in. |
| **TG-12** | Budgets captured | Initial route JS ≤ 200 KB gzipped per bundle; API read p95 ≤ 300 ms and write p95 ≤ 800 ms excluding third parties, measured on the built artifact. |

---

## 4. Scope guard

### 4.1 In scope

- Monorepo and workspace topology; `server/`, `packages/design`, `packages/shared`, `packages/api-client`, `apps/control`, `apps/staff`, `apps/partner`.
- NestJS + Fastify API, worker process, PostgreSQL-backed queue and transactional outbox contract.
- PostgreSQL 16 schema-per-module, migration runner, five-role model, RLS scaffolding.
- Identity and authentication foundation: accounts, users, credentials, sessions, devices, memberships, grants, session audiences, MFA-ready schema.
- Activity registry, activation/deactivation state machine, capability computation and the guarded vertical slice.
- Append-only `audit_log` skeleton and structured logging.
- Frontend design tokens and slice primitives; route manifest and router; four bundles; visual regression baseline.
- Three-environment separation; staging topology; build-once artifact; migration application; smoke and E2E.
- CI gates for typecheck, lint, test, build, OpenAPI diff, migration lint/`db diff`, visual regression, dependency and secret scanning.

### 4.2 Out of scope — EP-01 must not build these

- Any verification lane, KYC case, document upload, private bucket or review queue.
- Any financial ledger, escrow, payout, provider adapter, deposit webhook or reconciliation job.
- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Any `control.` review feature, staff job function or partner programme feature. The bundles exist; the features do not.
- Taxonomy registry, messaging/notification features, AI, public API, multi-region, offline sync or native apps.
- Production deployment. EP-01 exits on staging; G4 is not part of this phase.
- Full extraction of all 82 prototype screens. Only the vertical-slice screens are extracted.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.

### 4.3 Scope interpretations to confirm at G0

Two statements in the approved phase scope need an explicit architect ruling before work starts. They are recorded here rather than resolved silently:

1. **"Five frontend bundles."** Resolved 2026-11-07 by architecture revision 3 and `EP-01-ENTRY-RECORD.md` §6.3: Hivorr has **four bundles** (`web`, `control`, `staff`, `partner`) and **eight deployments**, one per bundle in staging and production. The partner host is `partner.hivorr.com` / `partner.staging.hivorr.com`. The earlier “four bundles, five deployments” reading and the `partners.` spelling are superseded.
2. **"Screens extracted from `App.tsx` without visual change."** Extracting all 82 screens would be a rewrite and would violate bounded scope. This plan establishes the design package and extracts **only the screens and primitives the vertical slice uses**. Later phases extract on touch, as the architecture requires. The architect must confirm this reading at G0.

---

## 5. Required systems, modules and components

### 5.1 Systems

| System | Responsibility in EP-01 |
| --- | --- |
| **Root web app** | Stays at the repository root so the Figma Make preview keeps working (§14.2). Consumes `packages/design`, `packages/shared`, `packages/api-client`. |
| **API** | NestJS + Fastify, `/v1`, OpenAPI, audience guards, capability checks, transactions, audit writes. |
| **Worker** | PostgreSQL-backed queue, outbox consumer contract, idempotent jobs, health. |
| **PostgreSQL** | One instance per environment; ten module schemas; roles; migrations; RLS. |
| **Edge/CDN** | Per-host static bundles; same-origin `/api/*` rewrite; TLS/HSTS; noindex for privileged hosts. |
| **Secret store** | Per-environment secrets injected at runtime; no secret in a bundle, repo or log. |
| **CI** | Install, lint, typecheck, test, build, OpenAPI diff, migration lint, visual regression, dependency and secret scan. |
| **Observability** | Structured logs, correlation IDs, health/readiness, queue metrics, error-tracking adapter. |
| **Object storage** | Interface and configuration only; no product uploads in EP-01. |
| **Staging** | `staging.hivorr.com`, same topology as production, isolated data and credentials, candidate artifact digest. |

### 5.2 Backend modules — disposition in EP-01

| # | Module | Schema | EP-01 disposition |
| --- | --- | --- | --- |
| 1 | Identity & Authentication | `identity` | **Implemented**: accounts, users, credentials, sessions, devices, memberships, grants, MFA-ready columns, reset/verification tokens. |
| 2 | Profiles & Verification | `profile` | **Partially implemented**: profile record and activity activation only. No verification lane, evidence or KYC. |
| 3 | Local Market | `market` | **Boundary only**: schema exists; no tables, endpoints or capabilities. |
| 4 | Professional Services | `services` | **Boundary only**. |
| 5 | Errands | `errands` | **Boundary only**. |
| 6 | Logistics | `logistics` | **Boundary only**. |
| 7 | Wallet & Financial Operations | `finance` | **Boundary only**. |
| 8 | Messaging & Notifications | `messaging` | **Boundary only**. No messaging tables or delivery features. |
| 9 | Administration & Governance | `admin` | **Minimal**: audit-read contract and the capability-guarded deny probe. No review queues, moderation or configuration. |
| 10 | Shared Platform Services | `platform` | **Implemented**: audit log, outbox, idempotency keys, feature flags, reference numbers. No taxonomy registry, media, search or geo. |

### 5.3 Frontend components

| Component | Role |
| --- | --- |
| `packages/design` | Tokens from `theme.css` plus the prototype primitives required by the slice. |
| `packages/shared` | Framework-free types, zod schemas, capability constants, activity registry types, error codes, route IDs. |
| `packages/api-client` | Generated OpenAPI client; never hand-edited. |
| Route manifest | Every approved URL family declared; only slice routes reachable in EP-01. |
| Session/capability context | Account, active activities, capability list for presentation only, audience. |
| Auth screens | Sign-in, registration, reset/verification capture state. |
| Activity switcher/activation | Lists only activated activities and the activation affordance. |
| Four bundles | `web`, `control`, `staff`, `partner`, each with its own entry and deployment target. |

### 5.4 Test and quality stack

Vitest (unit), Vitest + Testing Library (component), Vitest + Testcontainers Postgres (integration and RLS), OpenAPI schema diff (contract), Playwright (E2E and visual regression), dependency and secret scanning, lint and typecheck. All of these are additions; none is installed today.

---

## 6. Recommended engineering development order

No dates. Order is by dependency and by what produces evidence earliest.

| Stage | Work | Why this order |
| --- | --- | --- |
| **0 — Gate closure** | EP-01-001 | Nothing starts until EP-00 is exited and the three entry decisions are recorded. |
| **1 — Workspace and contracts** | EP-01-002 → 003 → 004 | The build graph and shared vocabulary must exist before any module is written. |
| **2 — Platform and data, in parallel** | API: 010 → 011 → 012 → 013 → 014. Data: 020 → 021 → 022 → 023/024 → 025 → 026. | API and database touch different concerns; both depend on Stage 1. The contract (013) and outbox (014) follow the module skeleton. |
| **3 — Identity, activity, capability** | 030 → 031 → 032 → 033 → 034 → 036 → 035 | Each step supplies the next one's inputs. Audit (036) can land alongside enforcement. |
| **4 — Security and observability hardening** | 040, 042, 043 in parallel; 041 after 032 and 060 | Hardening must be in place before staging, but need not block the domain work. |
| **5 — Frontend foundation** | 050 can start in Stage 1; 051 after 050; 052 after 013/032; 053 after 035; 054 after 002/052. | The visual baseline must exist before extraction. Wiring waits for the API contract. |
| **6 — Environments and delivery** | 060 → 061 → 062 → 063 | Staging topology precedes deployment; local parity can run in parallel once schemas and sessions exist. |
| **7 — Exit evidence** | 070 → 071 → 072 | Evidence is produced by a running system, not assembled from intentions. |

### 6.1 Parallelism rules

Within the phase, work packages may run in parallel only when they touch different modules and neither depends on the other's schema or public contract. Frontend baseline and extraction run independently of backend data work. Staging provisioning may start once hosting is decided, but no deployment happens until the API and migrations exist. Hardening packages may overlap domain work but must land before G3. Exactly one phase may be `In build`; EP-01 does not run alongside EP-02.

### 6.2 Critical path

`001 → 002 → 003 → 020 → 021 → 022 → 023/024 → 025 → 026 → 030 → 031 → 032 → 033 → 034 → 036 → 035 → 060 → 061 → 063 → 070 → 071 → 072`

The visual baseline (`050`) is off the backend critical path but on the **phase exit** path, because the founder must approve it.

---

## 7. Dependencies

### 7.1 Internal dependencies

| Dependency | Effect |
| --- | --- |
| **EP-00 exit** | Hard blocker. A clean clone must install, typecheck, lint and test green in CI; `main` protected; first commit tagged `v0.0.1-bootstrap`. |
| **Founder decisions** | #1 managed Postgres, #17 hosting/DNS/TLS, #14 sign-in identifier. |
| **Architect decisions** | Validation library (standards §16 #1), session lifetimes (#3), secret manager (#8), error-tracking vendor (#9), CSP posture (#6), API versioning (#2), test toolchain approval, second-reviewer arrangement (EES §11.2 #2). |
| **Reviewer capacity** | G2 on authentication, capability and migration changes requires a second reviewer who did not author the change (AUT-39, QUA-31). |
| **Founder approval** | Visual regression baseline; G5 phase closure. |
| **EP-00 CI provider** | Extended, not replaced. |

### 7.2 External dependencies

| Dependency | Needed by | Status |
| --- | --- | --- |
| Managed PostgreSQL 16-compatible provider | Data foundation, staging | **Open** (#1) |
| Hosting platform, DNS, TLS issuance | Staging, all bundles | **Open** (#17) |
| Edge rewrite capability for same-origin `/api` | Staging, cookie isolation | Follows #17 |
| Secret manager | Staging, config contract | **Open** (standards #8) |
| Error tracking / APM vendor | Observability adapter | **Open** (standards #9) |
| Transactional email / SMS delivery | Registration reset/verification | **Open**; EP-01 uses a capture-only adapter |
| CI provider and repository hosting | Every G2 | Decided at EP-00 |
| Figma Make preview | Must keep working | Existing constraint |

**Not dependencies of EP-01:** VFD, payment providers, KYC vendors, map/geo providers, AI model providers, mobile tooling. No contract or credential for any of them is created in this phase.

---

## 8. Risks

| # | Risk | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| R1 | **EP-00 is not complete.** Zero commits, no CI, no tests, stale lockfile. | EP-01 cannot start; any work would be unverifiable. | Do not open EP-01. Close EP-00 first and link its evidence in EP-01-001. | Founder / architect |
| R2 | **Three entry decisions remain open.** | Database, staging and auth work are blocked or built on assumptions. | EP-01-001 records each decision; work packages stay `Not started` until the decision is linked. | Founder |
| R3 | **No second reviewer for critical changes.** | G2 cannot be passed honestly for auth, capability and migrations. | Appoint an external reviewer or record a time-boxed deviation with compensating controls (founder review + agent-assisted checklist) before auth work. No silent waiver. | Founder / architect |
| R4 | **Frontend extraction scope explodes.** `App.tsx` is 3,814 lines with 82 screens. | The phase turns into a rewrite; visual drift enters. | Baseline first; extract only the slice screens and primitives; no cosmetic refactor; every extraction has a visual diff. | Architect |
| R5 | **Capability engine overreaches into later-phase semantics.** | EP-01 invents verification or KYC defaults it has no authority to decide. | Register capabilities with metadata; implement only inputs EP-01 owns; capabilities requiring lanes/KYC deny until their phase supplies the input; unknown capability denies. | Architect |
| R6 | **Pre-auth RLS breaks sign-in.** A deny-all policy blocks credential lookup. | Auth cannot function; teams weaken RLS to compensate. | Define a transaction-scoped identity context and narrow pre-auth selectors; test both the allowed lookup and the denied cross-account read; never use `auth.uid()`. | Architect |
| R7 | **Provider-specific RLS behaviour.** Supabase, Neon and RDS differ in role and policy mechanics. | The data layer works on one provider and not the other. | Keep repositories provider-agnostic; Position A applies only if Supabase is chosen; run the policy suite on the chosen provider. | Architect |
| R8 | **Sign-in identifier decision expands scope.** Phone-first pulls OTP and SMS delivery into EP-01. | Auth work grows materially; delivery vendor becomes a phase dependency. | Confirm #14 at G0. If phone-first, re-plan the OTP and SMS adapter explicitly before starting EP-01-031. | Founder / architect |
| R9 | **Hosting and cookie misconfiguration.** A cross-origin API forces `SameSite=None`. | The host-only session isolation collapses. | Same-origin `/api` rewrite; host-only cookies; no parent-domain cookie; staging header tests. | Architect |
| R10 | **Secrets leak or environments share credentials.** | Security incident; staging reaches production. | Decide the secret manager before staging; per-environment namespaces; startup validation; secret scanning in CI. | Architect |
| R11 | **Audit immutability conflicts with operations.** Someone asks for an update or delete path. | The audit trail loses evidentiary value. | No update/delete grants; append-only; corrections are new records; retention decision remains open and no purge is built. | Architect |
| R12 | **Bundle/build complexity.** Four bundles plus staging and edge rewrites. | Slow pipeline; accidental cross-bundle code. | Shared packages; per-app entry; import-boundary lint; build all bundles on every PR. | Architect |
| R13 | **Visual regression is flaky.** Remote images, fonts and timing cause false diffs. | The gate is disabled, which defeats its purpose. | Deterministic fixtures, self-hosted fonts, fixed viewports, pinned browser, approved image strategy. | Developer |
| R14 | **Local parity drifts from CI.** Windows workstation, containers, Node versions. | "Works on my machine" defects. | One-command dev environment; CI is the reference; pinned toolchain from `.mise.toml`. | Developer |
| R15 | **Pressure to declare the phase done without evidence.** | Repeats the v1 failure mode. | Evidence index; no status above `Not started` without an artifact; G5 is a founder signature. | Founder / architect |

---

## 9. Assumptions

1. EP-00 exits before EP-01 starts, with a protected `main`, a green pipeline and a tagged first commit.
2. The managed provider is PostgreSQL 16-compatible and supports schemas, roles, RLS and `FORCE ROW LEVEL SECURITY`.
3. Hosting supports per-host static bundles, an edge rewrite of `/api/*` to an internal origin, and TLS/HSTS on every host.
4. Sign-in is email + password at minimum; no social login and no mobile client at MVP. If #14 chooses phone-first, the OTP path is added to the auth work package rather than assumed.
5. No production release occurs in EP-01. Staging is the highest environment.
6. The prototype is not edited. Extraction copies code into new packages and features.
7. A second reviewer is available, or a recorded deviation with compensating controls exists before authentication work.
8. No real personal data enters development or staging; seeds are synthetic.
9. Currency, fees, escrow and custody are not exercised; no money code exists in EP-01.
10. The approved documents remain the authority; where two disagree, the owning document wins and the conflict is recorded, not resolved in code.

---

## 10. Engineering considerations

- **Default deny.** Every new endpoint, capability, table and bucket starts closed and is opened deliberately.
- **Service layer is authoritative.** Route guards and RLS are additional layers; neither is the model.
- **No client authority.** Capabilities are computed server-side and returned for presentation only. The client never stores a capability as authority.
- **No shared tables.** A module reads only its own schema; cross-module reads go through a public interface or a read model.
- **No business logic in controllers, React components or triggers.** Domain rules live in pure TypeScript; triggers enforce invariants, not authorisation.
- **Migrations are self-contained.** A table migration creates columns, keys, constraints, indexes, RLS, policies, grants and comments together.
- **Forward-only and expand/contract.** No production `down` script; rollback is a previous artifact digest.
- **RLS needs a deny test.** A policy tested only with a permitted caller is untested.
- **Audit is written by the service layer**, so the reason and correlation ID are captured with the change.
- **Secrets never enter a client bundle, a log, a migration, a seed or a screenshot.**
- **The palette is closed.** New UI consumes tokens; no new hex, font family, type size or radius.
- **Extraction is not redesign.** A screen is extracted only because it is being wired or extended; untouched screens stay untouched.
- **Bounded scope limits edits, not understanding.** Every work package records what it inspected for reuse.
- **Evidence is an artifact a third party can inspect.** A status sentence is not evidence.
- **No AI agent approves a gate, deploys, widens a permission or decides an open question.**
- **Performance is measured on the built artifact**, not the dev server.

---

## 11. Roadmap items

Each item is a candidate work package under the EES §8 protocol. Before it reaches G0 it must be elaborated with class, scope-in/out, reuse check, test plan, evidence, rollback and approver. IDs are stable and are never reused. Three-digit references in this plan, such as `020`, mean `EP-01-020`; the shorthand is valid only inside this document.

**Reasoning levels:** *Planning* = reasoning needed to define the package at G0. *Coding* = reasoning needed to implement and verify it. Use the higher level when a security or architectural property is involved.

---

### Stage A — Entry and workspace

#### EP-01-001 — Entry gate closure and decision register
- **Objective:** Verify EP-00's exit evidence and record every decision EP-01 depends on before any work package is marked `Ready`.
- **Engineering purpose:** Satisfies G0, prevents work on an open decision, and establishes the phase's true starting position.
- **Dependencies:** EP-00 exit; founder for #1, #17, #14; architect for standards-level decisions.
- **Expected outcome:** A signed entry record linking EP-00 evidence, the three entry decisions, and the work-package blockers (session lifetimes, validation library, secret manager, error-tracking vendor, second reviewer, CSP posture). EP-01 becomes `Ready`, or `Blocked` with named owners.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Low

#### EP-01-002 — Workspace topology and package boundaries
- **Objective:** Extend the pnpm workspace so the root web app, `server/`, shared packages and privileged apps build together without breaking Figma Make.
- **Engineering purpose:** Establishes the architectural structure and makes import boundaries enforceable from the first commit.
- **Dependencies:** EP-01-001; technical selections recorded (DB driver, migration runner, queue, OpenAPI generator, test stack, boundary lint).
- **Expected outcome:** `server/`, `packages/design|shared|api-client`, `apps/control|staff|partner` exist with package names, tsconfig references and boundary lint; root build and typecheck are green; the Figma preview is unchanged.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

#### EP-01-003 — Shared contracts package
- **Objective:** Publish `@hivorr/shared` with framework-free types, zod schemas, capability constants, activity registry types, error codes and route IDs.
- **Engineering purpose:** One vocabulary across API and clients; no hand-duplicated types and no divergent validation.
- **Dependencies:** EP-01-002; validation library decision.
- **Expected outcome:** Package consumed by the API and web app; no React, database or provider imports; contract tests pass.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-004 — CI pipeline extension
- **Objective:** Extend the EP-00 pipeline to cover the multi-package build, OpenAPI diff, migration lint and `db diff`, visual regression, dependency and secret scanning.
- **Engineering purpose:** Produces G2 evidence and ensures each gate can actually fail.
- **Dependencies:** EP-01-002, EP-01-003, EP-00 CI.
- **Expected outcome:** A green pipeline on a throwaway PR; seeded failing fixtures prove that typecheck, contract, migration, visual and secret gates block.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage B — API platform

#### EP-01-010 — API bootstrap and runtime configuration
- **Objective:** Stand up the NestJS + Fastify API with `/v1`, validated configuration, health/readiness, request timeouts, body limits, graceful shutdown and correlation IDs.
- **Engineering purpose:** Creates the single ingress for all five clients and makes configuration failures fail fast.
- **Dependencies:** EP-01-002, EP-01-004.
- **Expected outcome:** API starts locally and in CI; health endpoints respond; missing configuration stops startup; no secret appears in logs.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-011 — Common request pipeline and error contract
- **Objective:** Implement request validation, audience declaration, exception mapping, stable error codes, pagination and idempotency primitives.
- **Engineering purpose:** Consistent denial semantics and distinguishable failures; prevents per-route ad-hoc handling.
- **Dependencies:** EP-01-010; validation library decision.
- **Expected outcome:** Every endpoint declares an audience; unknown fields are rejected; errors distinguish unauthenticated, unauthorised, activity-inactive, validation and not-found; contract tests cover each.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-012 — Ten-module boundary skeleton
- **Objective:** Create the ten module folders with controller → service → domain → repository layering, one public `index.ts` each, and an enforced acyclic dependency rule.
- **Engineering purpose:** Makes module ownership structural rather than conventional, so a module can be extracted later without redesign.
- **Dependencies:** EP-01-010, EP-01-011.
- **Expected outcome:** Boundary lint fails on a cross-module repository or table import; only identity, profile, platform and admin contain code; the other six are boundaries with no tables or endpoints.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

#### EP-01-013 — OpenAPI 3.1 contract and generated client
- **Objective:** Generate OpenAPI 3.1 from the implemented endpoints, publish `@hivorr/api-client`, and fail CI on a breaking contract diff.
- **Engineering purpose:** The contract is the integration point; hand-written client types are a defect.
- **Dependencies:** EP-01-010, EP-01-011, EP-01-012.
- **Expected outcome:** Generated client consumed by the web app; OpenAPI diff stage active; a deliberate breaking-change fixture fails the build.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-014 — Worker, PostgreSQL queue and outbox
- **Objective:** Add the worker process, a PostgreSQL-backed job runner, and the transactional outbox consumer contract.
- **Engineering purpose:** Side effects must not block requests; establishes the event seam without building messaging features.
- **Dependencies:** EP-01-012, EP-01-024.
- **Expected outcome:** Worker starts; claims and replays a test job idempotently; dead-letters a failing job; queue health is observable.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

---

### Stage C — Data foundation

#### EP-01-020 — Managed PostgreSQL and environment configuration
- **Objective:** Provision the chosen managed PostgreSQL provider for local and staging, and define the per-environment connection and secret contract.
- **Engineering purpose:** Establishes the system of record and environment isolation before any table exists.
- **Dependencies:** EP-01-001 (#1 provider); secret manager decision.
- **Expected outcome:** Separate databases, roles and credentials per environment; connection validation; no shared credentials; local container parity.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Medium

#### EP-01-021 — Migration runner and baseline schemas
- **Objective:** Install the migration runner and create the ten module schemas, the `private` schema and migration history from an empty database.
- **Engineering purpose:** Reproducible schema, schema ownership and a forward-only workflow from day one.
- **Dependencies:** EP-01-020; migration-runner selection from EP-01-001.
- **Expected outcome:** `db reset` from empty yields all schemas; `db diff` is clean; naming and self-containment rules are enforced by lint.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

#### EP-01-022 — Database roles, grants and default privileges
- **Objective:** Create the migrator, API, worker, readonly and break-glass roles; apply least-privilege grants and default privileges.
- **Engineering purpose:** The API role cannot change schema, truncate or bypass RLS; every object starts closed.
- **Dependencies:** EP-01-021.
- **Expected outcome:** Role tests prove the API cannot DDL or bypass RLS; the migrator is CI-only; each environment has distinct credentials; no application role is superuser.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — High

#### EP-01-023 — Identity schema
- **Objective:** Create `identity` tables for accounts, users, credentials, sessions, devices, memberships, grants, MFA factors and reset/verification tokens.
- **Engineering purpose:** Establishes the identity spine from which every capability is derived.
- **Dependencies:** EP-01-021, EP-01-022.
- **Expected outcome:** Tables, foreign keys, state constraints, indexes, RLS enabled, grants and comments; UUIDv7 and `timestamptz` conventions applied.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-024 — Profile, activity and platform schema
- **Objective:** Create `profile` (profiles, activity activations) and `platform` (audit log, outbox, idempotency keys, feature flags, reference numbers) tables.
- **Engineering purpose:** Establishes activity state and the audit/event backbone without building later-phase domains.
- **Dependencies:** EP-01-021, EP-01-022.
- **Expected outcome:** The six activity IDs are constrained; activation states are constrained; audit and outbox shapes are append-only; policy-filter columns are indexed.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-025 — RLS pattern, identity context and policy tests
- **Objective:** Implement the transaction-scoped identity context, private policy helpers, `FORCE ROW LEVEL SECURITY`, and allow/deny tests for every EP-01 policy.
- **Engineering purpose:** Delivers the defence-in-depth layer that fails closed, including a pre-auth lookup path that does not break sign-in.
- **Dependencies:** EP-01-022, EP-01-023, EP-01-024.
- **Expected outcome:** Every EP-01 table has RLS and one policy per operation; unset identity denies; pre-auth lookups are narrowly scoped; cross-account reads deny; no `auth.uid()` appears.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-026 — Repository and transaction foundation
- **Objective:** Provide the unit-of-work, connection pool, parameterised query helpers and transaction-local context setter.
- **Engineering purpose:** Every mutating service opens one explicit transaction, and the RLS context is always set.
- **Dependencies:** EP-01-021 through EP-01-025.
- **Expected outcome:** Transaction tests prove rollback, context isolation and no cross-request leakage; repositories are scoped to their module schema.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

---

### Stage D — Identity and capability

#### EP-01-030 — Identity domain and repositories
- **Objective:** Implement account, user, membership, grant and device domain models with identity-scoped repositories.
- **Engineering purpose:** Keeps identity invariants pure and independent of HTTP, ORM and provider SDKs.
- **Dependencies:** EP-01-023, EP-01-026.
- **Expected outcome:** Domain unit tests cover identity invariants; registration and activation cannot create a grant; repositories cannot read another module's schema.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-031 — Registration, credentials and account recovery
- **Objective:** Implement registration (user + account + profile, zero activities), Argon2id credentials, verification/reset token issuance, and a capture-only delivery adapter.
- **Engineering purpose:** A real account can exist and recover without receiving any capability it did not earn.
- **Dependencies:** EP-01-030; sign-in identifier decision (#14); delivery adapter.
- **Expected outcome:** Registration creates no activity or grant; hashes meet OWASP parameters; reset invalidates sessions; tokens are single-use, expiring, hashed and never logged.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-032 — Session lifecycle, audiences and session endpoint
- **Objective:** Implement sign-in, host-only audience cookies, access/refresh rotation, reuse detection, device sessions, revocation and `GET /v1/session`.
- **Engineering purpose:** Provides the transport of identity and the audience isolation the whole platform depends on.
- **Dependencies:** EP-01-031; session-lifetime decision (standards #3).
- **Expected outcome:** Sign-in issues a `__Host-` cookie for the correct audience; a wrong audience is rejected; reuse revokes the family; sign-out and suspension revoke server-side; the session response returns account, activities and presentation-only capabilities.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-033 — Activity registry and activation state machine
- **Objective:** Implement the six-activity registry, activation/deactivation, and the `ACTIVE` / `RESTRICTED` / `SUSPENDED` transitions.
- **Engineering purpose:** Activities are rows, not account types; dashboard visibility follows activity state, not verification status.
- **Dependencies:** EP-01-024, EP-01-030.
- **Expected outcome:** Any of the six activities activates in any order; deactivation retains history; invalid transitions are rejected in domain and by constraint; activation is not gated by verification.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-01-034 — Capability computation engine
- **Objective:** Build a pure, deterministic capability function over a typed context, with a capability registry and stable deny reasons.
- **Engineering purpose:** Implements the authoritative authorisation model without encoding later-phase defaults.
- **Dependencies:** EP-01-033.
- **Expected outcome:** Table-driven tests cover every implemented capability's allow and deny branch; unknown capability denies; capabilities requiring lanes or KYC that EP-01 does not own are registered and deny until their phase supplies the input; no request input widens the set.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-035 — Service-layer enforcement and vertical-slice endpoints
- **Objective:** Enforce capabilities inside the transaction for the EP-01 endpoints, including session read, activity activation and the guarded audit-read probe.
- **Engineering purpose:** Proves the enforcement path, not just the computation.
- **Dependencies:** EP-01-032, EP-01-034, EP-01-036.
- **Expected outcome:** `activity.activate` allows; `admin.audit.read` denies without a grant; denials use stable codes; the check runs inside the same transaction as the write; integration tests prove both branches.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Very High

#### EP-01-036 — Audit logging service and immutability
- **Objective:** Implement append-only audit writes from the service layer for authentication, activity and privileged actions, with actor, audience, correlation, before/after and target fields.
- **Engineering purpose:** Creates the evidence trail every later governance action depends on.
- **Dependencies:** EP-01-024, EP-01-026.
- **Expected outcome:** Sign-in and activity activation write audit rows; no update or delete path exists; the read model returns entries; audit failure handling is explicit and tested.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

---

### Stage E — Security and observability

#### EP-01-040 — Structured logging, correlation and error-tracking seam
- **Objective:** Add structured logs, correlation IDs, PII redaction and an error-tracking adapter with no vendor lock-in.
- **Engineering purpose:** Makes the platform operable without leaking personal data and keeps the vendor decision open.
- **Dependencies:** EP-01-010, EP-01-011.
- **Expected outcome:** Every request has a correlation ID; credentials, tokens and PII are redacted; errors carry the ID; the adapter has a no-op/capture implementation until the vendor is chosen.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

#### EP-01-041 — Edge and origin security posture
- **Objective:** Apply TLS/HSTS, host-only cookie policy, CORS and edge rewrite rules, CSP, `noindex` for privileged hosts and `no-store` on session responses.
- **Engineering purpose:** Establishes the first enforcement layer and prevents cookie-scope collapse.
- **Dependencies:** EP-01-032, EP-01-060.
- **Expected outcome:** Header tests pass on every host; `/api` is same-origin; no parent-domain cookie; no wildcard CORS; any CSP inline-style exception is recorded.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-042 — Authentication abuse controls
- **Objective:** Rate-limit sign-in, reset and OTP endpoints per identifier and IP; add lockout/backoff and suspicious sign-in audit events.
- **Engineering purpose:** Provides account-takeover resistance from the first sign-in endpoint.
- **Dependencies:** EP-01-032.
- **Expected outcome:** `429` with `Retry-After`; lockout after the configured threshold; new-location privileged sign-in writes an audit record; limits are configurable per environment.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Medium

#### EP-01-043 — Secret management and configuration contract
- **Objective:** Put every environment's secrets in the managed store, inject at runtime, validate the configuration shape, and keep secrets out of bundles.
- **Engineering purpose:** Environment isolation and rotation are prerequisites for staging and for any later provider integration.
- **Dependencies:** EP-01-020; secret-manager decision (standards #8).
- **Expected outcome:** The same configuration keys exist in every environment with different values; startup fails on a missing secret; no secret is in the repository, bundle or log; rotation procedure is documented.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Medium

---

### Stage F — Frontend foundation

#### EP-01-050 — Visual regression baseline and harness
- **Objective:** Capture the prototype's current output at 375 / 768 / 1280 as the approved baseline before any extraction, and wire comparison into CI.
- **Engineering purpose:** Provides the mechanism that prevents visual drift during extraction.
- **Dependencies:** EP-01-004; founder approval of the baseline.
- **Expected outcome:** Deterministic screenshot suite; baseline stored; a deliberate 1 px change fails; the founder approves the baseline.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

#### EP-01-051 — Design tokens and primitive extraction for the slice
- **Objective:** Establish `packages/design` with the theme tokens and extract only the primitives the EP-01 screens use, without visual change.
- **Engineering purpose:** Creates one design system and prevents a second component language.
- **Dependencies:** EP-01-050, EP-01-002.
- **Expected outcome:** Extracted primitives render pixel-identically at three widths; no raw hex is added; the shadcn kit stays dormant; untouched screens are untouched.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-052 — Route manifest, router and providers
- **Objective:** Replace the prototype's 82-value `Screen` union approach with a typed route manifest and introduce the router, session/capability context and server-state provider.
- **Engineering purpose:** Gives every entry point real URLs, makes the approved URL families declarative, and keeps client state in the three approved tiers (server state, session state, ephemeral UI state).
- **Dependencies:** EP-01-003, EP-01-013, EP-01-050, EP-01-051.
- **Expected outcome:** Route manifest declares every approved URL family; only slice routes are reachable; unknown routes render a real 404; session and capability context are provided from `GET /v1/session` and are presentation-only; no capability is cached as authority.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-053 — Vertical-slice screens
- **Objective:** Wire the EP-01 screens — sign-in, registration, reset/verification capture, session bootstrap, activity switcher/activation, and the guarded deny probe — against the generated client.
- **Engineering purpose:** Proves the API, the contract and the frontend foundation work together, and produces the first real end-to-end path.
- **Dependencies:** EP-01-032, EP-01-034, EP-01-035, EP-01-052, EP-01-051.
- **Expected outcome:** Slice screens render pixel-identically to the prototype at three widths; every call uses `@hivorr/api-client`; denial states are labelled and not colour-only; no dead controls; keyboard focus visible; no unreachable screen added.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — High

#### EP-01-054 — Four-bundle build and deployment targets
- **Objective:** Produce four independent bundles (`web`, `control`, `staff`, `partner`) with per-app entries, shared packages and enforced import boundaries.
- **Engineering purpose:** Makes the four portal bundles real deployment units without creating a second backend or a second user population.
- **Dependencies:** EP-01-002, EP-01-052.
- **Expected outcome:** All four bundles build in CI on every PR; no bundle imports another app; privileged bundles carry `noindex` metadata; the root web bundle stays within the route-JS budget; the Figma Make preview is unaffected.
- **Priority:** High · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Medium

---

### Stage G — Environments and delivery

#### EP-01-060 — Environment topology and staging provisioning
- **Objective:** Provision `local`, `staging` (and the reserved `production` definition) with isolated databases, credentials, secrets and hostnames, matching the architecture's **eight deployments** (four portals in each hosted environment).
- **Engineering purpose:** Establishes environment isolation and the integrated staging ecosystem that EP-01 exits on.
- **Dependencies:** EP-01-001 (#17 hosting/DNS/TLS), EP-01-020, EP-01-043.
- **Expected outcome:** `staging.hivorr.com`, `control-staging.hivorr.com`, `staff-staging.hivorr.com` and `partner-staging.hivorr.com` resolve with valid TLS; staging has its own database, roles, secrets and session issuer; no credential is shared with local or production; Cloudflare Access protects the control and staff staging hosts; the topology is recorded as code or as a reproducible runbook.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Extremely High · Coding — Medium

#### EP-01-061 — Build-once artifact and promotion
- **Objective:** Build each bundle and the API once per commit, record the artifact digest, and promote the same digest from staging to the release candidate.
- **Engineering purpose:** Guarantees that what is verified is what is promoted, and makes rollback a digest change rather than a rebuild.
- **Dependencies:** EP-01-004, EP-01-054, EP-01-060.
- **Expected outcome:** CI emits a digest per artifact; staging deploys by digest, never by branch; the deployed digest is retrievable from the running system; promotion requires no rebuild.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-062 — Migration application pipeline
- **Objective:** Apply forward-only migrations to staging as a discrete, reviewable pipeline step with the CI-only migrator role and a pre-application check.
- **Engineering purpose:** Prevents ad-hoc schema changes and keeps the deployed schema reproducible from the repository.
- **Dependencies:** EP-01-021, EP-01-022, EP-01-060, EP-01-061.
- **Expected outcome:** A staging reset applies all migrations in order; `db diff` is clean after application; a failed migration aborts the deploy; the migrator credential exists only in that step.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

#### EP-01-063 — Staging smoke, E2E and gate wiring
- **Objective:** Run post-deploy smoke checks and the Playwright E2E suite against the deployed digest, and make them blocking.
- **Engineering purpose:** Proves the deployed artifact, not the local build, satisfies the phase exit gate.
- **Dependencies:** EP-01-061, EP-01-062, EP-01-053.
- **Expected outcome:** Smoke covers health/readiness, sign-in, session, activation and the deny probe on every host; E2E reproduces the exit-gate slice; a failing smoke blocks promotion; results are attached as evidence.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — High

---

### Stage H — Exit evidence and closure

#### EP-01-070 — Phase evidence pack and traceability index
- **Objective:** Assemble the evidence index that maps every EP-01 objective, technical goal and completion criterion to an inspectable artifact.
- **Engineering purpose:** Makes the exit gate auditable by a third party instead of asserted by the team.
- **Dependencies:** Every item from EP-01-001 through EP-01-063.
- **Expected outcome:** One index linking CI runs, digests, migration output, policy test reports, contract diff results, visual baseline approval, header tests, coverage and the staging E2E run; every criterion has an artifact or is explicitly marked unmet.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Low

#### EP-01-071 — Phase-level security and quality review
- **Objective:** Conduct the end-of-phase review of authentication, authorisation, RLS, audit immutability, secret handling and test adequacy against the approved standards.
- **Engineering purpose:** Catches systemic gaps that per-package reviews cannot see, before the phase is declared closed.
- **Dependencies:** EP-01-070; second reviewer (R3 resolved or deviation recorded).
- **Expected outcome:** A review record listing each checked standard rule, findings, and either remediation or an approved, recorded deviation; no unmitigated critical or high finding remains.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — Very High · Coding — Low

#### EP-01-072 — G5 phase closure record
- **Objective:** Present the evidence pack and review outcome to the founder for phase closure.
- **Engineering purpose:** Makes closure an explicit, signed decision rather than an inference from finished tasks.
- **Dependencies:** EP-01-070, EP-01-071.
- **Expected outcome:** A signed closure record stating the phase outcome, the artifact digest that satisfied it, accepted residual risks and the entry conditions EP-02 inherits; or a documented decision to hold.
- **Priority:** Critical · **Status:** `Not started`
- **Reasoning:** Planning — High · Coding — Low

---

## 12. Expected phase outcome

EP-01 succeeds when the following are true, demonstrated on staging, not described:

1. **An account exists.** A real user is created through registration, with no role, activity or grant attached at creation.
2. **A session is real and scoped.** Sign-in issues a host-only `__Host-` cookie for the correct audience; the same cookie is rejected on another host; rotation, reuse detection and revocation are exercised.
3. **An activity is activated.** Any of the six activities activates as an explicit, separate act, and the state is persisted and readable.
4. **A capability denies and allows.** The server computes capabilities; `activity.activate` succeeds for an authenticated account and `admin.audit.read` is denied without a grant; denials carry stable codes.
5. **Enforcement is inside the transaction.** The capability decision and the write share one transaction, and RLS denies a cross-account read.
6. **Evidence is written.** Sign-in and activation produce append-only audit records with actor, audience, correlation ID and target.
7. **The platform is deployable.** CI is green on a clean clone, builds once, produces a digest, applies migrations in order and deploys that digest to staging.
8. **The UI is unaltered.** The extracted slice is pixel-identical to the prototype at 375 / 768 / 1280, and the founder has approved the baseline.
9. **The foundation is portable.** Boundaries, schema ownership, roles and grants mean later modules can be added without redesign.

## 13. Phase completion criteria

EP-01 is complete only when all of the following hold, each with a linked artifact in EP-01-070.

| # | Criterion | Evidence |
| --- | --- | --- |
| C1 | Entry gate satisfied | Signed EP-01-001 record; EP-00 exit evidence linked |
| C2 | Build graph works | Clean-checkout install, typecheck, lint, test and build green in CI |
| C3 | Contract is generated | OpenAPI 3.1 emitted; generated client consumed; breaking-diff fixture fails CI |
| C4 | Schema is reproducible | `db reset` from empty produces all schemas, roles, grants and history; `db diff` clean |
| C5 | Least privilege proven | Tests show `hivorr_api` cannot DDL, truncate or bypass RLS; migrator is CI-only |
| C6 | RLS fails closed | Every EP-01 table has RLS and one policy per operation, with allow **and** deny tests |
| C7 | Session isolation proven | `__Host-` cookie per audience; wrong-audience rejection, rotation and reuse tests pass |
| C8 | Capability authority proven | Table-driven allow/deny tests for every implemented capability; unknown capability denies |
| C9 | Enforcement proven in transaction | Integration tests show the check and the write share a transaction |
| C10 | Audit is immutable | Append-only writes; no update/delete path; read is scoped and audited |
| C11 | Visual identity preserved | Baseline approved by founder; slice pixel-identical at three widths; no new hex or font |
| C12 | Staging is provable | Staging runs the candidate digest; migrations applied in order; smoke and E2E green |
| C13 | Operability baseline | Correlation IDs, PII redaction, health/readiness, queue health, error-tracking seam |
| C14 | Budgets captured | Route JS, API read and write latency measured on the built artifact |
| C15 | Quality gates honest | Typecheck, lint, tests, contract, migration, visual, dependency and secret scans all blocking and proven to fail when seeded |
| C16 | Review complete | EP-01-071 record with no unmitigated critical or high finding |
| C17 | Closure signed | EP-01-072 founder signature, with artifacts and accepted residual risks |

**A criterion without an artifact is unmet.** A phase is not `Completed` because its tasks are `Completed`.

## 14. What EP-01 deliberately does not prove

Recorded so the exit gate is not overread:

- That verification, KYC or document handling works — none exists yet.
- That money can move, be held, split or reconciled — no finance code exists.
- That any of the six activity experiences is usable — only activation state exists.
- That `control`, `staff` or `partner` perform their functions - only their bundles and hosts exist.
- That the system is production-ready — EP-01 exits on staging, and G4 is a later phase.

## 15. Transition handed to EP-02

EP-02 inherits, and must not need to rebuild: the workspace, the four bundles, the generated client, the migration runner, the role model, the RLS pattern and identity context, the identity and activity schema, the capability engine and its registry contract, the audit trail, the outbox seam, the observability seam, the visual baseline and the CI gates.

EP-02 does **not** inherit any verification lane, KYC tier enforcement, finance primitive or activity feature — those must be built and gated in their own phases.

---

**Plan status:** complete for EP-01 only. No future phase has been analysed, expanded or planned, no implementation documentation has been produced, and no production code has been written.

Before any of this becomes actionable, three things are needed: EP-00 must actually exit, the three entry decisions (#1 provider, #17 hosting, #14 sign-in identifier) must be recorded, and the G0 scope readings in §4.3 must be confirmed.
