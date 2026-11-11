# ARCHITECTURE.md — Hivorr Technical Architecture

> **STATUS: REVISED — 7 November 2026 (revision 3).**
> This revision replaces revision 2 **in place**. It records the founder-approved environment
> architecture: **four applications across two hosted environments, eight deployments**, a
> staging-first, build-once release process, and a funded, founder-approved production gate. It also
> records the staged retirement of the legacy Flutter applications that served
> `hivorr.com` and `staging.hivorr.com`.
>
> Revision 2 replaced the 1 November 2026 revision in place. The pre-1-November original (the
> Flutter-era document, 178 lines) is preserved unchanged at
> `C:\Users\user\Downloads\ARCHITECTURE.md` and is described in Appendix A.
>
> This document is derived from four sources, in this order of authority:
>
> 1. `documents/Context/VISION.md` — approved product direction.
> 2. `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` — approved account and
>    permission model.
> 3. `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` — approved database,
>    migration, grant, RLS, and Supabase Data API governance.
> 4. `src/app/App.tsx` — the prototype, which is the visual and user-experience authority.
>
> Where this document and any of the above disagree, the higher source wins and this document has a
> defect. Report it; do not quietly pick a side.
>
> **Label key**
>
> | Label | Meaning | Effect |
> | --- | --- | --- |
> | **[DECIDED]** | Fixed by an approved document, by the prototype, or by an explicit founder instruction. | Binding. Changing it requires a recorded revision. |
> | **[RECOMMENDED]** | Proposed by this revision. A safe default, not yet signed off. | Takes effect when the founder accepts this revision. §16.3 lists every one. |
> | **[OPEN]** | Not settled by any source. | Nothing may be built on it. §16.4 lists every one. |
>
> **Supabase mechanics are not restated here.** Where a rule concerns grants, RLS, policies,
> migration tooling, migration history, exposure of the Data API, API keys, or backups, the authority
> is `Database-Migration-and-Supabase-Data-API-Rules.md` (the "database rules"). This document states
> the Hivorr-level decision and points at the section that governs the mechanism.

---

## 1. Architectural Overview

### 1.1 The shape, in one paragraph

**[DECIDED]** Hivorr is **one product with four applications across two hosted environments and one
backend per environment**: a modular-monolith TypeScript API, one worker process, and one PostgreSQL
database per environment. The main product — all six user activities — lives at `hivorr.com`. Three
narrow, separately deployed surfaces sit beside it (`control`, `staff`, `partner`). Staging carries
the same four applications at `staging.hivorr.com`, `control-staging.hivorr.com`,
`staff-staging.hivorr.com`, and `partner-staging.hivorr.com`. That is **four applications and eight
deployments**. All eight are clients of the same API and identity service *within their environment*.
None is a second backend, a second database, a second user population, or a route into the other
environment.

```
        PRODUCTION                                  STAGING
 hivorr.com        control.hivorr.com        staging.hivorr.com      control-staging.hivorr.com
 staff.hivorr.com  partner.hivorr.com       staff.staging...        partner.staging...
        │                  │                          │                        │
        └────────┬─────────┘                          └───────────┬────────────┘
                 │ same-origin /api/*                            │ same-origin /api/*
     ┌───────────▼────────────┐                     ┌─────────────▼────────────┐
     │ Production API + worker│                     │ Staging API + worker      │
     │ Production PostgreSQL  │                     │ Staging PostgreSQL        │
     │ Production R2          │                     │ Staging R2                │
     │ VFD live · live email  │                     │ VFD test · capture email  │
     └────────────────────────┘                     └───────────────────────────┘
```

The frontend is a React single-page application in the prototype's stack (§2.1, §8). It is built as
**one shared component library and one shared design system, consumed by four separate application
bundles** (§8.12). Each bundle is deployed independently to its production and staging hosts. The
bundles are separate so that `control` code can never ship to `partner`, and `partner` code can
never ship to `hivorr.com`.

### 1.2 Why a modular monolith

**[DECIDED]** The MVP must support six activities, a shared wallet, verification lanes, an admin
environment, a staff portal, and a partner portal over **one** identity. That is a wide domain with
tightly coupled financial invariants — exactly the case where distributed transactions and network
boundaries cost more than they return.

A modular monolith keeps one transactional boundary around money, one deploy pipeline, and one
database, while module boundaries are enforced in code so that any module can be extracted later
without redesign (§9.3, §13.2).

### 1.3 What is explicitly excluded at MVP

**[DECIDED]** Microservices · event streaming · GraphQL · a separate backend per entry point · a
second database · offline sync · micro-frontends · a generic workflow engine · a plugin runtime.

### 1.4 The four applications and their environments

The four applications are not equivalent, and the architecture says so explicitly rather than
relying on a subdomain to imply it. Each has a production deployment and a staging deployment.

| Tier | Production | Staging | Who | Trust |
| --- | --- | --- | --- | --- |
| **Public product** | `hivorr.com` | `staging.hivorr.com` | Any registered account | Standard session; all six activities; never admin |
| **Internal operations** | `staff.hivorr.com` | `staff-staging.hivorr.com` | Appointed Hivorr staff | Standard session + staff grant + MFA; job-scoped |
| **Privileged governance** | `control.hivorr.com` | `control-staging.hivorr.com` | Founder, authorised developer | Strictest session + mandatory MFA; narrow scopes |
| **External partnership** | `partner.hivorr.com` | `partner-staging.hivorr.com` | Approved affiliates and partners | Partner session; no activity capabilities, no wallet |

The staging column is non-production and must never share data, credentials, signing keys, payment
accounts, buckets, or queues with the production column (§11). A subdomain is an **organisational
and deployment** boundary. It is not, by itself, a security control (§10.12).

### 1.5 How to read the rest of this document

§2 fixes the technology. §3 draws the system boundaries. §4 defines the four portals and their
environments. §5–§7 define the account, the six activities, and the three privileged surfaces. §8–§9
define the frontend and the backend. §10 defines security. §11–§12 define environments and release
governance. §13 defines how the system grows. §14–§15 define the repository and its dependencies.
§16 records every decision, every open question, and every conflict this revision found. §17 records
the implementation roadmap.

---

## 2. Technology Decisions

### 2.1 The stack, verified against the repository

**[DECIDED]** The following is read from `package.json`, `tsconfig.json`, `vite.config.ts`,
`.mise.toml`, and `pnpm-workspace.yaml` on 3 November 2026. It is the prototype's stack and is
adopted as the project stack (`AGENTS.md` §1).

| Layer | Technology | Version | Evidence |
| --- | --- | --- | --- |
| UI runtime | React + React DOM | 18.3.1 | `package.json` |
| Language | TypeScript | ^5.7, `strict: true` | `package.json`, `tsconfig.json` |
| Build | Vite | 6.3.5 (pinned via pnpm override) | `package.json`, `vite.config.ts` |
| Styling engine | Tailwind CSS | 4.1.12 with `@tailwindcss/vite` | `package.json` |
| Design tokens | CSS custom properties | `src/styles/theme.css` | verified |
| Icons | `lucide-react` | 0.487.0 | sole icon source in `App.tsx` |
| Routing | `react-router` | 7.13.0 | installed, **not yet used** |
| Forms | `react-hook-form` | 7.55.0 | installed, **not yet used** |
| Primitives | Radix UI | 26 packages | installed, reachable only through the unused shadcn kit |
| Runtime | Node.js | 22 | `.mise.toml` |
| Package manager | pnpm | 10.34.3 | `.mise.toml` |
| Formatter | `oxfmt` | ^0.2.0 | `package.json` |
| Host wrapper | Figma Make | `vite.figma.config.ts` | wraps `vite.config.ts` |
| Path alias | `@/*` → `./src/*` | — | `tsconfig.json`, `vite.config.ts` |

**[DECIDED]** `src/styles/theme.css` is the single CSS token layer. `src/styles/index.css` imports
`fonts.css` → `tailwind.css` → `theme.css` in that order. `src/styles/fonts.css` loads Plus Jakarta
Sans and Inter. No second palette may be introduced (`AGENTS.md` §2.12).

### 2.2 Backend framework

**[DECIDED]** Node 22 + TypeScript, sharing types and validation schemas with the frontend.

| Option | Advantages | Disadvantages | Verdict |
| --- | --- | --- | --- |
| **NestJS** (Fastify adapter) | First-class modules, DI, guards/interceptors, OpenAPI generation, testable layering | More structure and boilerplate; larger learning surface | **Decided** |
| Fastify + manual structure | Minimal, fast, few abstractions | Module boundaries become convention only; authorisation is hand-rolled per route | Rejected |
| Next.js full-stack | One deployment, fast start | Couples the product to a framework that would replace the prototype's Vite build; server components add no value here | Rejected |
| Laravel / Django | Mature, batteries included | Second language; loses shared TypeScript types with the frontend | Rejected |

The decisive factor is not performance but **enforceable boundaries**: a governance-heavy domain
(verification gates, KYC tiers, admin scopes, escrow, staff scopes) benefits from a framework where
authorisation is a declarative guard rather than a per-route convention.

### 2.3 Database engine

**[DECIDED]** PostgreSQL 16 — relational integrity, `numeric` arithmetic, row-level security, and
advisory locks are all load-bearing here.

**[DECIDED 7 November 2026]** The managed provider is **Supabase**, used as managed PostgreSQL only
(`§16.4 #1`). The Data API and GraphQL are disabled, Supabase Auth is not used, and no Supabase key
ships in any client (database rules §2.4, Position A). Staging and production use separate Supabase
projects with separate credentials.

### 2.4 What is present but not adopted

**[DECIDED]** These packages are installed and **must not become the basis of new code** without a
recorded decision:

| Package | State | Ruling |
| --- | --- | --- |
| `@mui/material`, `@mui/icons-material`, `@emotion/react`, `@emotion/styled` | Removed from `package.json` on 3 November 2026. `pnpm-lock.yaml` still resolves them until `pnpm install` runs (EX-19) | Do not re-add. |
| `@popperjs/core`, `react-popper` | Installed, imported nowhere | Dead weight. Do not use. Candidate for removal when the prototype is retired. |
| `motion`, `date-fns`, `react-dnd`, `react-slick`, `react-responsive-masonry`, `canvas-confetti` | Installed, imported nowhere | Not part of the design language. Do not introduce. |
| `src/app/components/ui/*` (50 shadcn files) | Installed and self-consistent, imported by **nothing** | A second, unused component system. The prototype does not use it. See §8.3. |
| `next-themes` | Reachable only through the unused shadcn `sonner` wrapper | Hivorr is light-only (`theme.css`); no dark mode exists. |
| `src/app/components/ui/sidebar.tsx` | 21 KB shadcn sidebar, unused | **Must never replace** the prototype's own `Sidebar` / `ActivitySidebar`. |
| `src/app/components/figma/ImageWithFallback.tsx` | Exported, never imported | Harmless; do not treat as part of the design system. |

The reason this matters: two component systems in one repository is how visual drift starts. The
prototype's primitives are the design system (§8.4). The shadcn kit is scaffolding that came with
the Figma Make file.

### 2.5 Dependency policy

- **[RECOMMENDED]** A new runtime dependency requires a one-line justification against the
  prototype: what it does that existing code cannot, and why it cannot be written in 50 lines.
- **[RECOMMENDED]** Every dependency is pinned exactly (the repository does this, including the
  dev-only entries since 3 November 2026) and `pnpm-lock.yaml` is committed. `@types/react` and
  `@types/react-dom` track the React 18 line, not the latest types release.
- **[RECOMMENDED]** `pnpm-workspace.yaml` sets `minimumReleaseAge: 10080` (7 days). Keep it. It is a
  supply-chain control, not a preference.
- **[DECIDED]** No CSS-in-JS library. No second UI kit. No second icon set.

---

## 3. System Boundaries

### 3.1 Components

| # | Component | Responsibility | Status |
| --- | --- | --- | --- |
| 1 | **Web app** (`hivorr.com`, `staging.hivorr.com`) | The six user activities, shared wallet, messaging, profile, activity switcher. | Exists as prototype; no deployment from this repository yet |
| 2 | **Control app** (`control.hivorr.com`, `control-staging.hivorr.com`) | Founder governance, developer operations, review queues, configuration, audit. | New — §7.2 |
| 3 | **Staff app** (`staff.hivorr.com`, `staff-staging.hivorr.com`) | Job-scoped operational work: support, verification, operations, marketing. | New — §7.3 |
| 4 | **Partner app** (`partner.hivorr.com`, `partner-staging.hivorr.com`) | Affiliate and partner applications, referral and commission tracking. | New — §7.4 |
| 5 | **API** | Authentication, authorisation, domain logic, financial operations, admin/staff/partner operations. | New |
| 6 | **Worker** | Webhooks, notifications, escrow release, payouts, reconciliation, media scanning, referral accrual. | New |
| 7 | **PostgreSQL** | One system of record per environment. Module-scoped schemas, ledger, audit log. | New |
| 8 | **Object storage** | Product media, avatars, contracts, KYC documents, proof of delivery. Private by default. | New |
| 9 | **CDN / edge** | Static bundles for all eight deployments, public media, TLS, HSTS, `noindex` for privileged hosts. | Cloudflare — decided 7 November 2026 |
| 10 | **Payment providers** | **VFD** — single payment and custody partner: collections, escrow balances, payouts. Founder decision, 3 November 2026. Replaces the previous Paystack/Flutterwave arrangement. Conditions in `documents/Business-Roadmap/Business-Development-Roadmap.md` BD-D11. | New |
| 11 | **Messaging providers** | SMS OTP (Termii), transactional email. | New |
| 12 | **Maps / geo** | Geocoding and radius dispatch. | Deferred — not in the prototype |
| 13 | **Observability** | Error tracking, structured logs, metrics, traces, uptime. | New |

**[DECIDED 3 November 2026]** The founder selected **VFD as the single payment and custody partner**,
replacing the previous Paystack-primary / Flutterwave-secondary arrangement. This is a deliberate
concentration: one provider for collection, escrow balances and payout. The decision is conditional on
VFD confirming, in writing, that marketplace escrow, nationwide operation and third-party release are
within its licence. Until that confirmation and production certification exist, no integration is
built against it. The accepted risk and its mitigations are recorded in the business roadmap
(BD-D11, BD-R14).

### 3.2 What each entry point may reach

| Capability | `hivorr.com` | `staff.*` | `control.*` | `partner.*` |
| --- | --- | --- | --- | --- |
| Six activity capabilities | Yes (activated) | No | No (unless separately activated as a user) | No |
| Own wallet | Yes | No | No | No |
| Verification review queue | No | Scoped | Yes | No |
| Payment review | No | Scoped, read + flag | Yes, with dual control | No |
| Platform configuration | No | No | Yes, scoped | No |
| Audit log | No | Own actions | Read | No |
| User PII | Own only | Minimum needed for the task | Scoped | Own partner organisation only |
| Referral / commission records | Own referral code only | Scoped | Yes | Own programme only |
| Infrastructure / deployment | No | No | Developer scope only | No |

Each staging application has the same capability boundary as its production counterpart, but its
sessions, credentials, data, and signing keys are environment-local (§11). Staging never grants a
capability that the production seed does not grant, and never reaches a production resource.

### 3.3 Boundaries that are not negotiable

**[DECIDED]**

1. **One database per environment.** Six activities, three privileged surfaces, and one identity
   share one database per environment. No per-activity database, no per-activity auth system, and no
   database shared between staging and production.
2. **One identity service per environment.** Every application authenticates against the same
   identity module in its environment. A second credential store is forbidden.
3. **One API per environment.** The privileged surfaces are not a second backend. They call the same
   API with different scopes.
4. **No client is trusted.** Every boundary in §3.2 is enforced server-side. The client's route,
   bundle, or subdomain proves nothing.
5. **No cross-module table access.** A module reads only its own schema (§9.2).
6. **No cross-environment access.** A staging credential, session, signing key, bucket, queue, or
   provider key cannot reach production, and the reverse is also forbidden (§11.2).

---

## 4. Domain and Subdomain Structure

### 4.0 One ecosystem, four portals

**[DECIDED 7 November 2026]** Hivorr is **one integrated AI-powered professional services
ecosystem**, not four products, four businesses, or four independent applications. It has four
functional portals. Each portal is an access surface over the same environment's shared identity,
API, database, audit log, and business services.

| Portal | Purpose | Primary users | Production | Staging |
| --- | --- | --- | --- | --- |
| **Main** | Marketplace and service activities | Clients, professionals, sellers, logistics providers | `hivorr.com` | `staging.hivorr.com` |
| **Control** | Governance and system control | Founder, explicitly authorised administrators and technical personnel | `control.hivorr.com` | `control-staging.hivorr.com` |
| **Staff** | Internal daily operations | Appointed Hivorr staff, by job function | `staff.hivorr.com` | `staff-staging.hivorr.com` |
| **Partner** | Affiliation and external partnerships | Approved partners, affiliates, partner organisations | `partner.hivorr.com` | `partner-staging.hivorr.com` |

**Main portal.** Registration, sign-in, profiles, account management, the six activities (Buy,
Hire, Errand, Sell, Offer Services, Provide Logistics), job posting and applications, product
listings and purchases, errands, logistics, messaging, notifications, wallet and payment
experiences, quotations and transaction documents, verification interfaces, and the activity
switcher. It is the primary user-facing business platform.

**Control portal.** Business and platform oversight, administrative governance, account
administration, verification approval and oversight, platform configuration and business rules,
system-wide permissions, financial and transaction oversight, marketplace and service governance,
operational performance, authorised administrative privileges, security and audit oversight,
integrations, and critical system configuration. It is **not** the staff workspace and **not** a
customer-facing marketplace. Access is limited to the founder and explicitly authorised
administrators/technical personnel, enforced by backend authentication, scoped capabilities, MFA,
and an edge access layer.

**Staff portal.** Customer support, user enquiries and complaints, transaction and payment support,
verification case processing, marketplace support, professional/client assistance, order and
delivery support, operational monitoring, escalation, internal task management, operational
reporting, and service coordination. Staff receive job-specific permissions. A support officer does
not automatically receive financial-configuration or platform-wide authority, and staff never
receive `admin.*` or control-portal access by default.

**Partner portal.** Partner registration and applications, affiliate onboarding, partner profiles
and account management, referral activities and tracking, partnership performance, commission
tracking, partner earnings and payment information, partnership reports, communication, and
approved partnership arrangements. Partners see only their own organisation's records. They never
access internal staff operations, administrative controls, or another partner's confidential data,
and a partner session carries no activity capability or wallet.

**What is shared, and what is not.**

| Shared across the portals | Portal-specific |
| --- | --- |
| Identity, credentials, sessions, devices, memberships, grants | Application shell, navigation, and visual emphasis |
| API, domain services, capability engine, audit log, outbox | Capability scope and job/admin/partner grants |
| Database per environment, ledger, verification cases, notifications | Read models and queue views |
| Design system, status language, security controls | Portal routes and permitted actions |

The rule is: if two portals need the same business concept, it is shared once in the API and
database. It is never copied into a portal "to keep them independent". Independence is an access and
permission boundary, not a data-duplication licence.

### 4.1 The eight deployments

**[DECIDED]** by founder instruction, 7 November 2026. Four applications, each deployed to a
production host and a staging host.

| Environment | Domain | Application | Access | Trust tier |
| --- | --- | --- | --- | --- |
| Production | `hivorr.com` | Main Hivorr platform | All six core activities | Public product |
| Production | `control.hivorr.com` | Administrative platform | Founder and explicitly authorised developer | Privileged governance |
| Production | `staff.hivorr.com` | Internal staff portal | Officially appointed Hivorr staff | Internal operations |
| Production | `partner.hivorr.com` | External partnership portal | Approved affiliates and partners | External partnership |
| Staging | `staging.hivorr.com` | Main Hivorr platform | Authorised testers and founder | Non-production |
| Staging | `control-staging.hivorr.com` | Administrative platform | Authorised testers and founder | Non-production |
| Staging | `staff-staging.hivorr.com` | Internal staff portal | Authorised testers and founder | Non-production |
| Staging | `partner-staging.hivorr.com` | External partnership portal | Authorised testers and founder | Non-production |

These are **eight deployments of four applications, not eight user populations** (§5). A person may
hold an ordinary Hivorr account and a staff grant at the same time; the grants are separate, and
neither implies the other. The staging applications are one integrated ecosystem: they share the
staging API, staging identity service, and staging database, and they are tested together.

### 4.2 `hivorr.com` — the main application

**[DECIDED]** All six core activities remain reachable through `hivorr.com`:

| # | Activity | Dashboard | Route family |
| --- | --- | --- | --- |
| 1 | I Want to Buy | Local Market | `/explore/market` |
| 2 | I Want to Hire | Client Dashboard | `/explore/hire` |
| 3 | Send an Errand | Errand Requester Dashboard | `/explore/errands` |
| 4 | I Want to Sell | Seller Dashboard | `/earn/sell` |
| 5 | I Want to Offer My Services | Professional Dashboard | `/earn/services` |
| 6 | I Want to Provide Logistics | Logistics Provider Dashboard | `/earn/logistics` |

**No separate domain may be introduced for an ordinary user activity.** "Sell at sell.hivorr.com" is
forbidden: it would fragment one account into six, which is the single thing the account model exists
to prevent (`matrix` §2, §5.4).

### 4.3 The staging ecosystem

**[DECIDED]** `staging.hivorr.com` is the **staging deployment of the main application**, not the
name of the whole environment. The staging environment comprises all four staging hosts in §4.1.

- It runs the same build pipeline as production, against staging services and a staging database.
- It is never linked from the production product and never shares credentials, buckets, signing
  keys, queues, or payment accounts with it.
- The four staging applications are deployed as one release and tested as one ecosystem. A change
  that touches verification, disputes, referrals, accounts, or permissions must be tested across the
  affected staging hosts before it can be considered for production.
- It is `noindex` and crawler-disallowed on every host, including `staging.hivorr.com`.

### 4.4 `control.hivorr.com` — the administrative platform

**[DECIDED]** The restricted administrative environment, deployed at `control.hivorr.com` and
`control-staging.hivorr.com`.

Access is limited to:

- **Founder** — ultimate business authority, including financial and business decisions.
- **Explicitly authorised developer** — technical permissions only.

**Developer access is governed by explicitly assigned technical permissions.** Technical privilege
must never automatically grant access to financial operations, sensitive user information, or
business decisions. Concretely:

| Developer capability | Granted | Notes |
| --- | --- | --- |
| Deployment, rollback, environment configuration | Yes | §12 |
| Feature flags and non-financial configuration | Yes | Audited |
| Read application logs and traces | Yes | PII redacted |
| Read aggregate metrics and queue health | Yes | No per-user detail |
| Run or review migrations | Yes | Review gate, not unilateral execution (§12.4) |
| Read user PII | **No** by default | Time-boxed, dual-controlled exception only |
| Read or move money | **Never** | Not a developer capability at any scope |
| Approve verification, disputes, or payouts | **Never** | Founder or delegated staff only |
| Change business rules, fees, or limits | **Never** | Founder only |

**[RECOMMENDED]** Developer privilege is a distinct grant named `platform.engineering`, held by an
individual account, time-boxed, MFA-protected, and audited on every use. It is not a superuser role
and it is not "admin".

**[RECOMMENDED]** Cloudflare Access protects both control hosts at the edge, in addition to the
application's own authentication, MFA, and server-side capability checks. The edge layer reduces
exposure; it never replaces authorisation.

### 4.5 `staff.hivorr.com` — the staff portal

**[DECIDED]** Reserved for officially appointed Hivorr personnel: marketing, operations, customer
support, verification officers, and other authorised staff. Deployed at `staff.hivorr.com` and
`staff-staging.hivorr.com`.

- **Staff access is controlled through job-specific permissions** (§10.6).
- **A staff member does not automatically receive administrator privileges.** Staff and admin are
  different grants; holding one never implies the other.
- Staff never reach `control.hivorr.com` unless they separately hold a control grant.
- Staff never gain activity capabilities from a staff grant.
- **[RECOMMENDED]** Cloudflare Access protects both staff hosts at the edge, in addition to the
  application's own authentication and MFA.

### 4.6 `partner.hivorr.com` — the partnership portal

**[DECIDED]** Reserved for external partnership programmes: affiliates, referral programmes,
business partnerships, partnership applications, and commission and referral tracking. Deployed at
`partner.hivorr.com` and `partner-staging.hivorr.com`.

- It **must not become an alternative entry point for the six core activities.** A partner session
  cannot place an order, publish a listing, accept an errand, or touch a wallet.
- A partner sees only its own organisation's applications, referrals, and commission records.
- **[RECOMMENDED]** Partner identity is a **partner membership** on the same identity service, not a
  second account system. An individual who is also an ordinary Hivorr user keeps one account and two
  separate grants.
- The partner hosts are application-authenticated; edge access is optional because external partner
  onboarding must remain usable.

### 4.7 Rules that apply to all eight deployments

**[DECIDED]**

1. **One API, one identity service, and one database per environment.** No application gets its own
   backend, and no environment reaches another environment's backend.
2. **Each application has its own session audience** (§10.3). A session issued for one application is
   rejected by the others. Every session is also bound to its environment; a staging session is
   rejected by production even if the hostname were somehow reached.
3. **No host is a security boundary by virtue of its hostname.** Authorisation is enforced
   server-side, per request (§10.12).
4. **Cross-origin is explicit.** Each host has an exact CORS allowlist entry; no wildcard and no
   `*.hivorr.com`. In the browser path there is no cross-origin call at all — see §4.9 — so the
   allowlist governs the edge-to-origin hop and any future public surface.
5. **Staging is a separate environment, not a prefix added to production.** Staging has its own
   database, credentials, signing keys, buckets, queues, and payment test account. A staging session
   can never be replayed against production.
6. **TLS everywhere, HSTS on every host**, including the privileged and staging hosts.
7. **No index for privileged or staging hosts.** `control.`, `staff.`, `partner.`,
   `control.staging.`, `staff.staging.`, `partner.staging.`, and `staging.` are `noindex`,
   serve `Disallow: /`, and are not linked from the public product.
8. **No additional subdomain is introduced without founder approval.** The eight hosts in §4.1 are
   the complete set.
9. **The legacy Flutter deployments are not the architecture.** Until the staged cutover in §12.10
   completes, `hivorr.com` and `staging.hivorr.com` may still be served by the legacy applications.
   That is a recorded transitional state, not a second supported architecture.

### 4.8 DNS, TLS and hosting

**[DECIDED 7 November 2026]** Cloudflare provides DNS, TLS, and the edge. Cloudflare Pages serves the
four static application bundles in each environment. Fly.io runs the API and worker. Supabase
provides managed PostgreSQL only (Position A); the Data API, Supabase Auth, and Supabase Storage are
not used. Cloudflare R2 provides object storage.

**Verified state on 7 November 2026 — not the target state:**

- `hivorr.com` and `staging.hivorr.com` resolve through Cloudflare.
- Both served the **legacy Flutter application** until 7 November 2026, not this repository's React build.
  The two web CNAME records and the two Flutter Pages custom domains were removed on 7 November 2026;
  both hostnames are now unavailable.
- `www.hivorr.com`, `control.hivorr.com`, `staff.hivorr.com`, `partner.hivorr.com`, and all three
  privileged staging hosts have no DNS record yet.
- The legacy hosts do not send HSTS, CSP, frame protection, or a permissions policy.
  `staging.hivorr.com` is currently indexable. Both conditions are corrected before cutover.

**No DNS, certificate, hosting, or deployment configuration was changed in producing this revision.**
The cutover is a separate, approved operation with a rollback position (§12.10).

**TLS.** The three privileged staging hosts are **flattened to first-level names**:
`control-staging.hivorr.com`, `staff-staging.hivorr.com`, and `partner-staging.hivorr.com`. They are
covered by Cloudflare's Universal SSL wildcard for `*.hivorr.com`. The earlier second-level
`*.staging.hivorr.com` scheme is superseded, and no Advanced Certificate Manager subscription is
required for staging. This resolves §16.4 #26.

**[RECOMMENDED]** Each application has its own Cloudflare Pages project per environment, with an
explicit custom domain. `staging.` is a separate deployment target, not a rewrite rule.

### 4.9 API host and canonical hostnames

**[DECIDED]** — the API has no public hostname in either environment.

| Rule | Detail |
| --- | --- |
| Browser path | Each of the eight hosts serves `/api/*` **same-origin**, rewritten at the Cloudflare edge to that environment's Fly.io API origin. |
| Origin hostname | The API has an internal origin hostname reachable only from the edge — not resolvable by a browser and not present in any bundle. |
| Consequence | No CORS in the browser path at all; §4.7 #4 remains as a defence-in-depth allowlist for the edge hop. |
| Cookies | Stay **host-only on the application host**, `SameSite=Lax`, `__Host-` prefix — exactly §5.4. |
| Environment binding | Each environment has its own API origin, signing keys, and session issuer. A staging `/api` rewrite never points at production. |
| If a public API is ever required | It is a **separate, scoped surface** with its own credentials (§9.9), not this API opened to the internet. |

**Canonical hostnames.**

| Rule | Detail |
| --- | --- |
| Apex canonical | `hivorr.com` is canonical. `www.hivorr.com` issues a single **301 to the apex**, at the edge, before any application logic runs. |
| Privileged and staging hosts | `control.`, `staff.`, `partner.`, `staging.`, and the three `*.staging.` hosts are canonical on the bare subdomain. No `www.` variant exists for any of them. |
| One host per environment | An environment is never a path on a production host. `hivorr.com/staging` is forbidden. |
| No wildcard DNS | Each hostname is an explicit record. No `*.hivorr.com` and no `*.staging.hivorr.com`, so a new subdomain cannot appear by accident. Certificate coverage is explicit. |
| Redirects | Only `GET`/`HEAD` are redirected across hosts. A `POST` is never redirected — it would drop the body — and API requests are never redirected. |
| HSTS | `max-age=31536000; includeSubDomains` on every host. **`preload` is a later, deliberate step**: it is effectively irreversible and commits every future subdomain to HTTPS. |
| `robots` | Every privileged and staging host serves `Disallow: /` and `noindex` (§4.7 #7). Only `hivorr.com` is indexable. |

---

## 5. Unified Account Architecture

### 5.1 Five concepts, deliberately separated

**[DECIDED]** (`matrix` §3, `database rules` §12.3)

| Concept | Meaning |
| --- | --- |
| **Account** | The legal/billing party — a person, or a business represented as a verified profile on that person (`matrix` §3.4). Owns the wallet. |
| **User** | A credential holder that can sign in. One account has one owner user at MVP. |
| **Membership** | Links a user to an account with a role. Enables future teams and, now, partner organisations. |
| **Profile** | Activity-specific presentation — buyer, client, errand requester, seller, professional, logistics provider. |
| **Activity activation** | A record that an account has activated an activity, with its own state. |

The previous revision said "four concepts" above a five-row table. Corrected here.

### 5.2 The identity chain

```
user ──(membership)──► account ──(activation)──► activity ──(computed)──► capability
                          │
                          ├── profile (per activity)
                          ├── verification lanes (identity, trade, seller, logistics, business)
                          ├── kyc tier
                          ├── wallet (one, shared)
                          └── grants (staff, partner, admin, engineering)  ← orthogonal
```

**Grants are orthogonal to activities.** An admin may hold zero activities; a user may hold six and
zero grants. Neither implies the other (`matrix` §14.4).

### 5.3 Registration, activation, switching

**[DECIDED]**

1. **Registration creates** a user, an account, and a profile. It creates **no** activity, role,
   verification, or dashboard (`matrix` §5.1).
2. **Activation is a separate, explicit act**, any of the six, in any order (`matrix` §5.2).
3. **Switching requires no re-authentication.** The switcher lists only activated activities and is
   reachable from every dashboard (`matrix` §10.3). The prototype's Activities hub exists but is
   unreachable from the shells; wiring it is an MVP requirement, not a new feature.
4. **"Both" is permanently removed.** There is nothing to choose, so the value cannot exist
   (`AGENTS.md` Rule 6).
5. **No activity is an account type.** An activity is a row.

### 5.4 Sessions and session audiences

**[DECIDED]** — four session audiences, each bound to an application and an environment.

| Rule | Detail |
| --- | --- |
| Cookie scope | **Host-only**, `Secure`, `httpOnly`, `SameSite=Lax`, `Path=/`, `__Host-` prefix. No `Domain=.hivorr.com`. |
| Audience | Every session record carries an audience: `app`, `control`, `staff`, `partner`. |
| Environment | Every session record also carries `staging` or `production`, a distinct issuer, and a key signed with that environment's key. A staging session is invalid in production. |
| Validation | The API rejects a session whose audience, environment, or issuer does not match the endpoint. |
| Cookie names | Distinct per host (for example `__Host-hivorr_app_sid` and `__Host-hivorr_control_sid`) so accidental reuse is visible in logs and impossible in the browser. |
| Rotation | Short-lived access token (10–15 min) plus a rotating refresh token; reuse detection revokes the family. |
| Devices | One server-side session record per device, revocable, with a "signed-in devices" screen in the main app. |
| Bearer | Bearer-token support is designed in from the start for a future mobile client. |

**Why host-only and not a shared parent-domain cookie.** A shared `.hivorr.com` cookie means an XSS
or a compromised dependency on `partner.` — the lowest-trust, externally facing surface — yields a
valid main-product session. It would also cross the environment boundary if the cookie were ever set
on a parent domain. Host-only cookies cost one extra sign-in on the privileged hosts, which is
desirable there anyway because they require MFA. The trade is deliberate.

### 5.5 What is never an account

**[DECIDED]** An activity · a dashboard · a verification lane · a KYC tier · a staff role · a partner
organisation · an admin scope. All of these are grants, records, or computed states on one account.

---

## 6. Six-Activity Architecture

### 6.1 The six activities

**[DECIDED]** Six initial activities in one ecosystem, grouped by user intent exactly as the
prototype's activity chooser presents them (`App.tsx` lines 879–898).

**Explore with Hivorr**

| # | Activity | Dashboard | Activity ID | Core workflow |
| --- | --- | --- | --- | --- |
| 1 | I Want to Buy | Local Market | `market.buy` | browse → product → cart → checkout → order → track |
| 2 | I Want to Hire | Client | `services.hire` | discover → post job → review applications → hire → pay via escrow |
| 3 | Send an Errand | Errand Requester | `errands.request` | create → review → submit → match provider → track |

**Earn with Hivorr**

| # | Activity | Dashboard | Activity ID | Core workflow |
| --- | --- | --- | --- | --- |
| 4 | I Want to Sell | Seller | `market.sell` | listing → publish → stock → fulfil → invoice → analyse |
| 5 | I Want to Offer My Services | Professional | `services.offer` | find work → apply → deliver → earn → analyse |
| 6 | I Want to Provide Logistics | Logistics Provider | `logistics.provide` | browse requests → accept → progress delivery → earn |

The namespaced activity IDs follow the matrix (`matrix` §19 #4) and are the wire format. The
user-facing names are the prototype's.

### 6.2 Shared versus activity-specific

**[DECIDED]** (`matrix` §6, `VISION.md` §7)

| Shared across the account | Activity-specific |
| --- | --- |
| Identity, credentials, sessions, devices | Dashboard shell and navigation set |
| Wallet: total, available, pending, withdrawable; withdrawals and statements | Accent colour and signature gradient |
| Messaging inbox (scoped by context) | Transaction, order, and engagement records |
| Notifications | Earnings and analytics views |
| Profile record and personal details | Eligibility and verification lane state |
| Design system, dialogs, status language | Activity onboarding requirements |
| Activity switcher | — |

**The reuse rule** (`matrix` §6.3): if two activities need the same concept, it is shared and lives
once. It is never copied into a second activity "to keep them independent". The six activities are
one platform; independence is a boundary, not a duplication licence.

### 6.3 Dashboard shells, verified from the prototype

**[DECIDED]** The prototype uses **two shell families**, not one. This is a fact about the reference
implementation and it shapes the frontend architecture (§8.6).

| Shell family | Used by | Structure |
| --- | --- | --- |
| `MarketShell` | Buy, Errand, Sell, Logistics | `ActivitySidebar` (accent-tinted) + header with activity switcher, notifications, cart (commerce only), avatar + `ActivityMobileBottomNav` |
| `Sidebar` + `TopBar` | Hire (Client), Professional, Admin | Collapsible global sidebar with role badge + `TopBar` + `MobileBottomNav` |

Navigation sets are authoritative (`matrix` §10.2):

| Shell | Navigation |
| --- | --- |
| Local Market | Market Home · Browse Products · Saved Products · Cart · My Orders · Payments · Profile |
| Client | Dashboard · Find Services · Post a Job · My Jobs · Applications · Messages · Payments · Profile |
| Errand requester | Errand Home · Create Errand · My Errands · Active Tracking · Payments · Profile |
| Seller | Overview · Products · Add Product · Orders · Inventory · Invoices · Sales Analysis · Earnings · Profile |
| Professional | Dashboard · Find Work · My Jobs · Messages · Earnings · Earnings Analysis · Profile |
| Logistics provider | Overview · Available Requests · Active Assignments · Delivery History · Earnings · Analysis · Profile · Provider Details |

Mobile reduces each set to five destinations, exactly as the prototype does.

**Do not unify the navigation sets.** The difference between shells is product identity
(`matrix` §10.2).

### 6.4 Activity accents, verified from the prototype

**[DECIDED]** Read from `App.tsx` (`MarketShell` line 2763, `getRoleColor` line 989):

| Activity | Shell accent | Signature gradient |
| --- | --- | --- |
| Local Market | `#2D3FE7` blue | none (solid surfaces) |
| Client (Hire) | `#2D3FE7` blue | `#1727BE → #2D3FE7 → #5263F4` |
| Errand requester | `#F97316` orange | `#B9380A → #EA580C → #FB7B32` |
| Seller | `#8B5CF6` purple | `#5B21B6 → #7C3AED → #9B66F3` |
| Professional | `#16A34A` green | `#116530 → #16A34A → #32B965` |
| Logistics provider | `#16A34A` green | `#0F5F5A → #0F766E → #16A34A` |

Professional and logistics share green but keep **different** gradients and different navigation. Do
not merge them.

**Observed prototype detail, not a defect:** the activity *chooser* cards use different tint pairs
from the shells — "I Want to Hire" renders purple and "I Want to Provide Logistics" renders orange on
that one screen (`App.tsx` lines 885, 895). The shell accent is the authoritative per-activity
identity; the chooser is a selection surface. When the chooser is rebuilt, it must be rebuilt to the
prototype, not "corrected".

### 6.5 Activity state machine

**[DECIDED]** (`matrix` §5.3, §12)

```
(not activated) ──activate──► ACTIVE ──restrict──► RESTRICTED ──restore──► ACTIVE
                                 │                    │
                                 │                    └──suspend──► SUSPENDED ──restore──► ACTIVE
                                 └──deactivate──► (not activated)   [history retained]
```

- Dashboard visibility is determined by activity state, **never** by verification status
  (`matrix` §10.1).
- Deactivation never deletes history.
- **[OPEN]** whether deactivation is blocked while obligations are open (`§16.4 #4`).

### 6.6 Gated writes, not gated dashboards

**[DECIDED]** The most frequently violated rule in this domain:

> An account with `market.sell` active but no seller approval **can open the Seller dashboard,
> browse, create drafts, and see why publishing is blocked**. It cannot publish.

| Action | Requires |
| --- | --- |
| Publish a product | `market.sell` active + seller lane `APPROVED` |
| Apply to or accept work | `services.offer` active + identity + trade lane `APPROVED` |
| Accept a dispatch | `logistics.provide` active + identity + logistics lane `APPROVED` |
| Receive earnings | applicable lane **and** KYC `tier_1` or above |
| Withdraw, pay out, convert | KYC `tier_1` or above + bound verified payout account |
| `tier_0` | zero limits on every financial action |

The full capability matrix is `matrix` §9.3 and is not duplicated here.

### 6.7 Cross-activity boundaries

**[DECIDED]** (`matrix` §9.4) — hard boundaries, not conventions:

| Boundary | Rule |
| --- | --- |
| Buy ↔ Sell | Buying from your own store is blocked. |
| Hire ↔ Offer | Both may be held; an account cannot apply to its own job or be both parties to one engagement. |
| Errand ↔ Logistics | Both may be held; an account cannot accept its own errand request. |
| Any activity ↔ Admin/Staff | A grant never confers an activity capability; an activity never confers a grant. |
| Any activity ↔ another account | No capability reaches another account's records. There is no "view all" endpoint outside scoped admin. |

### 6.8 Data ownership per activity

**[DECIDED]** Each activity's records live in its module's schema (§9.2) and carry explicit party
columns (`matrix` §11.4). Money does not: one wallet, one ledger, one statement, with each entry
attributed to an activity so the statement stays legible without fragmenting the balance
(`matrix` §9.5).

---

## 7. Administrative, Staff and Partner Separation

### 7.1 Three non-user surfaces, one identity service

**[DECIDED]** `control`, `staff`, and `partner` are **not** activities, not dashboards, and not
account types. They are separate applications that call the same API with different scopes. Each is
deployed to production and staging (§4.1); the staging copies exist so cross-application workflows can
be tested before production.

The reason they are separate applications rather than routes inside `hivorr.com`:

| Reason | Consequence |
| --- | --- |
| Blast radius | `partner` is externally facing and lower-trust; it must not ship admin code or share a session cookie (§5.4). |
| Bundle size | `control` ships review queues and audit tooling no ordinary user ever downloads. |
| Independent deployment target | A privileged surface has its own build and host, while releases remain coordinated (§12.9). |
| Auditability | Every request from a privileged host is tagged with its audience, making privileged activity trivially separable in logs. |
| Least privilege by default | A bundle that cannot contain a capability is a weaker target than one that merely hides it. |

### 7.2 Control platform — `control.hivorr.com`

**[DECIDED]** Founder and explicitly authorised developer. Capabilities are scoped, never binary
(`matrix` §14.2). The control surface carries:

| Area | Capabilities | Notes |
| --- | --- | --- |
| Verification review | `admin.verification.review` | Evidence access is audited; documents served via short-lived signed URLs |
| Payment review | `admin.payment.review` | High-risk actions require dual control |
| Dispute resolution | `admin.dispute.resolve` | Refunds require dual control |
| Account management | `admin.account.manage` | No self-suspension |
| Platform configuration | `admin.configuration.write` | Audited; fee/limit changes are founder-only |
| Audit access | `admin.audit.read` | Read-only, immutable source |
| Engineering | `platform.engineering` | Technical only; never money, never PII by default (§4.4) |

**[DECIDED]** The founder retains ultimate business authority. Any capability that changes money,
fees, limits, verification outcomes, or business rules terminates at the founder or an explicitly
delegated staff member — never at a developer grant.

### 7.3 Staff platform — `staff.hivorr.com`

**[DECIDED]** Job-specific permissions, not a role hierarchy.

| Job function | Default capability scope | Explicitly not included |
| --- | --- | --- |
| Verification officer | Review queue, evidence view, decision within policy | Payments, configuration, user deletion |
| Customer support | Ticket handling, read-only account context, message threads they are party to | Verification decisions, refunds above threshold, PII export |
| Operations | Assignment oversight, dispatch exceptions, SLA monitoring | Financial configuration, admin grants |
| Marketing | Campaign and content tools, aggregate analytics | Individual user PII, financial records |
| Other authorised staff | As assigned, per job | Anything not assigned |

**[RECOMMENDED]** Staff capabilities live in their own namespace — `support.*`, `operations.*`,
`marketing.*` — rather than reusing `admin.*`. This keeps the audit trail honest: a support action
should never read as an administrator action.

**[DECIDED]** Staff grants are: assigned by the founder or a delegated administrator; scoped to a job
function; time-bound where the role is temporary; MFA-protected; and revoked on role change. **A
staff member does not automatically receive administrator privileges.**

### 7.4 Partner platform — `partner.hivorr.com`

**[DECIDED]** External partnership programmes only.

| Surface | Included | Excluded |
| --- | --- | --- |
| Applications | Partnership application, status, documents | Any activity onboarding |
| Referrals | Referral codes, attributed sign-ups, conversion status | Access to referred users' data beyond aggregate status |
| Commission | Accrual, statement, payout status | Wallet, escrow, or any money movement outside commission payout |
| Business partnerships | Agreement records, contacts | Platform configuration, user management |

**It must not become an alternative entry point for the six core activities.** A partner session
cannot place an order, publish a listing, accept an errand, or call any activity capability. If a
partner organisation also trades on Hivorr, its people use `hivorr.com` with their ordinary account.

### 7.5 The permission ladder

**[DECIDED]** One table, so the boundaries are visible in one place:

| Grant | Held by | Scope | MFA | Dual control | Visible in activity switcher |
| --- | --- | --- | --- | --- | --- |
| Activity | Any account | That activity's own records | No | No | **Yes** |
| Partner membership | Approved partner org | That organisation's programme | No | No | No |
| Staff grant | Appointed staff | One job function | **Yes** | For high-risk actions | No |
| `platform.engineering` | Authorised developer | Technical operations | **Yes** | For production changes (§12) | No |
| `admin.*` | Founder / delegated admin | Scoped administrative area | **Yes** | For refunds, payouts, overrides, suspension | No |
| Founder | Founder | Everything, including business decisions | **Yes** | — | No |

### 7.6 Rules that prevent drift

**[DECIDED]**

1. A grant is never granted by registration, onboarding, or activity activation.
2. A grant is never inferred from a subdomain, a bundle, or a route.
3. Revoking a grant never touches activities, records, wallet, or verification (`matrix` §14.4).
4. Granting a grant never activates an activity.
5. Every grant change is audited with actor, target, before/after, and reason.
6. The prototype's public "Open admin prototype" entry point is removed in every production build
   (`matrix` §10.5).

### 7.7 Administrative governance domain

**[DECIDED 11 November 2026]** The Control Portal is **one governance architecture with two
operational shells**, not a merged portal. The `admin` module (module 9, §9.2) owns the governance
domain: roles, permissions, assignments, staff, departments, partner organisations, cases, evidence,
approvals, configuration and reporting read models. `control.hivorr.com` presents privileged
governance; `staff.hivorr.com` presents job-scoped operations; `partner.hivorr.com` remains an
external organisation surface. All three call the same API, authorization engine, audit trail,
identity service and design system.

The authoritative definition is `documents/Context/Administrative-Governance-Architecture.md`.
It extends this document and the permission matrix for the governance domain; it does not replace
them. Decisions D-01…D-08 and D-13 in
`documents/Engineering-Execution/Control-Portal/DECISION-RECORD.md` record the founder approval.

**Boundaries that remain unchanged:**

- `control` is still limited to the founder and explicitly authorised administrators/developers
  (§4.4, §7.2). Widen `staff` access to `control` only through a separately recorded decision.
- Staff still receive job-scoped permissions and never default to `admin.*` (§7.3, §10.6).
- Partners still receive no activity capability and no wallet (§7.4, §10.7).
- No second identity, role, capability, audit, ledger, file store, notification system or design
  system is introduced.

---

## 8. Frontend Architecture

### 8.1 Confirmed foundation — do not replace

**[DECIDED]** The frontend stack is the prototype's stack (§2.1). It is not reopened here.

**[DECIDED]** The prototype is the **only** source of truth for UI: colour, typography, spacing,
shape, layout, navigation, and copy. Where a written instruction disagrees with it, the prototype
wins (`AGENTS.md` §1, conflict rule).

### 8.2 The measured state of the prototype

These are measurements taken on 3 November 2026, not estimates. They justify the migration strategy
in §8.3.

| Measurement | Value |
| --- | --- |
| `src/app/App.tsx` | 3,814 lines, one file |
| Screens (`Screen` union) | 82 |
| Top-level components and data blocks | ~110 |
| Inline `style={{…}}` objects | **1,065** |
| Inline `fontFamily` declarations | 151 |
| Hex colour literals | 228 |
| `className` usages | 3 (all `hide-scrollbar`) |
| Images | Remote Unsplash URLs (see §8.4) |

The previous revision said "~1,882 inline style objects". That figure was wrong; the measured value
is 1,065. It does not change the conclusion — the file is still a single-component application — but
the number should be right.

### 8.3 Component organisation and reuse

**[DECIDED]** Three tiers, in this order of preference. Reuse before creating (`AGENTS.md` §3).

| Tier | What | Where | Rule |
| --- | --- | --- | --- |
| 1 | **Prototype primitives** — the design system | extracted from `App.tsx` to `packages/design` (§14) | Every screen uses these. They are the visual authority. |
| 2 | **Feature components** — one per module | `src/features/<module>/components` | Composed from tier 1. Never restyle tier 1. |
| 3 | **shadcn kit** | `src/app/components/ui/*` | **Dormant.** Not imported by the prototype. Not a design source. Not to be used for new UI. |

The prototype's primitives are:

`Av` · `Pill` · `Btn` · `Input` · `SelectField` · `Card` · `StatCard` · `Section` · `Stars` ·
`JobRow` · `PrototypeDialog` · `FinancialActionDialog` · `ActivityHero` · `WalletInfo` · `ChatUI` ·
`MarketShell` · `ActivitySidebar` · `Sidebar` · `TopBar` · `MobileNavBar` · `MobileBottomNav` ·
`ActivityMobileBottomNav` · `ProductCard` · `MarketFilterPanel` · `ProductTaxonomyFields` ·
`AnalysisPeriodTabs` · `UnifiedPayments` · `UnifiedEarnings` · `UnifiedProfile` · `ActivitiesHub` ·
`ActivitySelectScreen`

**[DECIDED]** Extraction is **incremental, by extraction**, never a rewrite, under three hard rules:

1. **No visual drift.** Every extraction is guarded by screenshot comparison at 375 / 768 / 1280 px
   before it is accepted (§8.10).
2. **Extraction order follows the domain**, not the file order: shared primitives first, then one
   activity shell at a time.
3. **No extraction without a reason.** A screen is refactored only when it is being wired to the API
   or extended. There is no cosmetic refactor of untouched screens (`AGENTS.md` §3, bounded scope).

**Reuse, do not rebuild.** `UnifiedPayments`, `UnifiedEarnings`, and `UnifiedProfile` are already
shared across activities in the prototype. They stay shared. `MarketShell` already parameterises
accent, label, navigation, and mobile destinations; it is the model for the activity shell contract.

### 8.4 Shared design system

**[DECIDED]** The design system is the prototype's tokens plus the prototype's primitives. It is
published as one package consumed by all four applications (§14.3), so `control`, `staff`, and `partner`
look like Hivorr without re-implementing it.

- **Tokens**: `theme.css` custom properties (`--hivorr-*`) plus Tailwind utilities exposed through
  `@theme inline` (`bg-brand`, `text-success`, `bg-attention-tint`, `text-seller`, `text-danger-tint`,
  `text-info`, `text-rating`, `text-ink`, `text-body`, `bg-surface-subtle`, `border-strong`,
  `font-display`, `font-body`, `shadow-rest`, `shadow-hover`, `shadow-overlay`).
- **Primitives**: the list in §8.3, extracted as-is.
- **Imagery**: photography only, rounded 10–20 px, hero images with a 4 px white border and a drop
  shadow. **The prototype's images are remote Unsplash URLs.** They are licensed for the prototype
  (`ATTRIBUTIONS.md`) but must not be hotlinked from production — that leaks referrers, depends on a
  third party, and cannot be optimised. **[RECOMMENDED]** production serves equivalent photography
  from R2 behind the CDN, with the prototype's crops preserved.
- **Icons**: `lucide-react` only. Sizes 12–24 px in UI, 48–56 px in onboarding art.

### 8.5 Styling and design tokens

**[DECIDED]** (`AGENTS.md` §2.12, `VISUAL-IDENTITY.md`)

- `src/styles/theme.css` is the only place that may define colour values in CSS.
- Every colour resolves to a named token. New colours require founder approval.
- New work must not add raw hex outside the token layer. Existing literals migrate as files are
  touched — never in a sweeping, unrelated refactor.
- The palette is closed. Accessibility gaps in the prototype are recorded in `VISUAL-IDENTITY.md`
  §24 and §31 and are **not** corrected by substituting a colour or raising a type size.
- Dark mode does not exist. Do not invent one.

**Current-state note:** the prototype's 228 hex literals and 151 inline `fontFamily` declarations are
debt, not a pattern. New components use tokens. Extracted primitives keep their exact rendering while
their literals are replaced one token at a time, guarded by visual regression.

### 8.6 Routing and navigation

**[DECIDED]** Routing is introduced with `react-router` 7 — already a dependency, currently unused.
The prototype's `Screen` union (82 values) is replaced by real URLs.

| Area | URL pattern | Purpose |
| --- | --- | --- |
| Public | `/`, `/login`, `/signup`, `/onboarding` | auth and onboarding |
| Activity switch | `/activities` | the switcher; must be reachable (`matrix` §10.3) |
| Explore | `/explore/market`, `/explore/hire`, `/explore/errands` | buying, hiring, errands |
| Earn | `/earn/sell`, `/earn/services`, `/earn/logistics` | selling, services, logistics |
| Shared | `/wallet`, `/messages`, `/profile` | one identity across activities |
| Public entities | `/p/:slug`, `/store/:slug` | SEO-discoverable listings and stores |
| Admin | `/admin/*` on `control.hivorr.com` | privileged environment, guarded |

Deep-linkable public URLs are required for the Local Market and storefronts.

**[RECOMMENDED]** Navigation is **per shell**, not global. `MarketShell` keeps its activity
navigation; the Client, Professional, and Admin shells keep theirs. A single shared navigation set is
forbidden because the difference is product identity (`matrix` §10.2). What is global is the
switcher, notifications, and the account menu — exactly as the prototype already renders them.

### 8.7 State management

**[DECIDED]** Three tiers only:

| Tier | Tool | Status | Use |
| --- | --- | --- | --- |
| Server state | TanStack Query | **Not installed — add it** | all API reads and mutations, caching, invalidation |
| Session / capabilities | React context | — | current account, active activities, capability set, audience |
| Local UI state | `useState` / `useReducer` | in use | dialogs, wizard steps, tabs |

- No global Redux-style store at MVP.
- Server state is not duplicated into a client store.
- Form state uses `react-hook-form` (installed) + `zod` (**not installed — add it**) with schemas
  shared with the API.

The previous revision described `zod` as "already a dependency". It is not in `package.json`.
Corrected here: it must be added before form work begins.

### 8.8 API integration

**[DECIDED]**

- A generated TypeScript client from the API's OpenAPI document replaces ad-hoc `fetch`. Types are
  never hand-duplicated.
- The session endpoint returns the account, its activated activities with states, and a flat
  capability list **for presentation only**.
- The UI hides or disables what the account cannot do and shows the reason. Hiding is a courtesy,
  never a control: the API re-checks every capability inside the transaction (`matrix` §11.3).
- One API base URL per environment, injected at build time. No environment branching in source.
- The client sends the audience-appropriate credentials only (§5.4). It never reads a token from
  `localStorage` as authority.

### 8.9 Responsive behaviour

**[DECIDED]** The prototype's breakpoints are fixed (`AGENTS.md` §2.9):

| Range | Behaviour |
| --- | --- |
| `< 768 px` | single column; 260 px drawer; bottom navigation (max 5 destinations); dialogs become bottom sheets; 16 px gutters; ~90 px bottom padding to clear the nav |
| `768–1023 px` | collapsed sidebar (66 px), except admin; two-column grids |
| `≥ 1024 px` | full sidebar (224 px); three- and four-column grids; content max-width 880–1200 px |

`useBreakpoint()` in the prototype (`App.tsx` line 16) is the reference implementation. Extracted
into a shared hook, it keeps identical thresholds. Do not introduce a second grid or spacing system.

### 8.10 Testing strategy

**[DECIDED]** Visual regression is mandatory, not optional — it is the mechanism that guarantees the
prototype's identity survives extraction (`AGENTS.md` §2, §6).

| Level | Tool | Status | Scope |
| --- | --- | --- | --- |
| Unit | Vitest | **Not installed** | domain rules, pricing, state machines, capability computation |
| Component | Vitest + Testing Library | **Not installed** | primitives, permission-aware UI states |
| Integration | Vitest + Testcontainers Postgres | **Not installed** | repositories, transactions, RLS, migrations |
| Contract | OpenAPI schema diff | **Not installed** | breaking-change detection |
| E2E | Playwright | **Not installed** | onboarding → activity → order/errand → wallet → review |
| Visual regression | Playwright screenshots | **Not installed** | 375 / 768 / 1280 px on every extracted screen |

None of this tooling is in `package.json` today. The previous revision presented it as approved
strategy without saying so. It is approved strategy **and** unbuilt work.

**The visual gate**: a pull request that changes rendering without an approved diff is rejected. The
baseline is the prototype's current output, captured before the first extraction.

### 8.11 Build and deployment configuration

**[DECIDED]** The build must not break the Figma Make preview.

- `vite.config.ts` remains the real config: React plugin, Tailwind plugin, `@` alias, asset types.
- `vite.figma.config.ts` wraps it and must keep working. It reads `.figma/make/site.json` and the
  asset/source alias maps.
- The root package stays the Figma Make app (§14.2).
- Build output is static assets. No server-side rendering at MVP.
- **[RECOMMENDED]** Route-level code splitting per activity replaces the previous document's
  "15–20 MB installer with lazily fetched modules". Same intent — keep the initial payload small —
  met by splitting per activity route, not by a custom module loader.
- **[RECOMMENDED]** A content security policy is applied at the CDN/edge, not only in meta tags.

### 8.12 Four application bundles, eight deployments

**[DECIDED 7 November 2026]** — four application bundles, each deployed to a production host and a
staging host.

| App | Production host | Staging host | Ships | Does not ship |
| --- | --- | --- | --- | --- |
| `web` | `hivorr.com` | `staging.hivorr.com` | six activity shells, wallet, messaging, profile, switcher | review queues, audit tooling, engineering tools |
| `control` | `control.hivorr.com` | `control-staging.hivorr.com` | review queues, configuration, audit, engineering views | product checkout, seller tools |
| `staff` | `staff.hivorr.com` | `staff-staging.hivorr.com` | support, verification, operations, marketing tools | financial configuration, engineering tools |
| `partner` | `partner.hivorr.com` | `partner-staging.hivorr.com` | applications, referrals, commission | any activity capability, any wallet |

All four consume `packages/design`, `packages/shared`, and `packages/api-client`. Each has its own
Vite entry, its own `index.html`, and its own deployment target in each environment. They share a
repository and a pipeline, not a bundle.

**Why not one app with host-based routing.** A single bundle means `partner.` downloads admin code
and `control.` downloads checkout code. Host-based routing also makes it easy to reach a privileged
route by mistake, because the route exists in the build. Separate bundles make the privileged
surfaces smaller targets and independent build units.

**Why not micro-frontends.** No runtime composition, no module federation, no remote entry points.
Shared source, separate builds. That is enough.

**Cost, stated honestly.** Four build targets and eight deployment configurations are more work than
one. The cost is accepted because `partner` is externally facing and `control` is the highest-value
target in the system. Releases are still coordinated (§12.9): a bundle is a separate build unit, not
an independently released product.

---

## 9. Backend and Database Architecture

### 9.1 Layering

**[DECIDED]** Every module is layered identically:

```
HTTP controller        parse, validate, map to a command/query — no business logic
  ↓
Application service    authorisation, orchestration, transaction boundary
  ↓
Domain                 invariants, state transitions, pricing/rules — pure TypeScript
  ↓
Repository             SQL only, scoped to the module's schema
```

Rules:

- Controllers never touch a repository directly.
- Domain code never imports HTTP, ORM, or provider SDKs.
- Every mutating service method opens an explicit database transaction.
- Provider SDKs (VFD, Termii, R2) are reached only through adapters in `integrations/`.

### 9.2 Modules

**[DECIDED]** Ten modules. Each owns its schema, its tables, its domain rules, and its public
interface. A module never reads another module's tables directly.

| # | Module | Schema | Owns | Depends on |
| --- | --- | --- | --- | --- |
| 1 | **Identity & Authentication** | `identity` | accounts, users, credentials, sessions, devices, memberships, grants, MFA | — |
| 2 | **Profiles & Verification** | `profile` | profile records, activity activation, verification cases, documents, KYC tiers | Identity, Files |
| 3 | **Local Market** | `market` | stores, products, taxonomy bindings, carts, orders, fulfilments | Identity, Profiles, Finance, Files |
| 4 | **Professional Services** | `services` | jobs, applications, engagements, milestones, deliverables | Identity, Profiles, Finance, Messaging |
| 5 | **Errands** | `errands` | errand requests, offers, assignment, task status | Identity, Profiles, Finance, Geo |
| 6 | **Logistics** | `logistics` | dispatch pool, assignments, delivery legs, tracking events, proof of delivery | Identity, Profiles, Finance, Errands, Geo |
| 7 | **Wallet & Financial Operations** | `finance` | ledger accounts, journal entries, escrow, payouts, limits, reconciliation, commission | Identity, Profiles |
| 8 | **Messaging & Notifications** | `messaging` | threads, messages, attachments, notifications, delivery attempts | Identity, Files |
| 9 | **Administration & Governance** | `admin` | admin roles, review queues, moderation, configuration, audit access, disputes, staff scopes, partner programme | all (read models only) |
| 10 | **Shared Platform Services** | `platform` | taxonomy registry, feature flags, media, search, audit log, reference numbers, geo | — |

**Two additions to the previous list**, both consequences of §4: staff scopes and partner programme
records live in module 9 (governance), and **geo** is named explicitly in module 10 rather than
being an undeclared dependency of Errands and Logistics.

### 9.3 How modules communicate

**[DECIDED]** Three mechanisms, in order of preference:

1. **Synchronous in-process call** to another module's public interface (a TypeScript service
   contract), inside the caller's transaction when consistency is required.
2. **Domain events through a transactional outbox** for side effects that must not block the caller —
   notifications, analytics, search indexing, media processing, referral accrual. Events are written
   in the same transaction as the state change and delivered at-least-once by the worker, with
   idempotent consumers.
3. **Explicit read models** for cross-module reporting. Views or dedicated query services, not joins
   scattered through feature code.

**Anti-coupling rules:**

- No shared tables between modules. Shared *identifiers* only (`account_id`, `activity_id`,
  `order_id`).
- No distributed transactions. One transaction touches one module's writes plus its outbox row.
- A module may not import another module's repository or ORM model.
- Cross-module dependencies must be acyclic; where a cycle appears, an event replaces the call.

### 9.4 Database strategy

**[DECIDED]** (`database rules` §12.2)

| Concern | Decision |
| --- | --- |
| Engine | PostgreSQL 16, one instance per environment, PITR |
| Ownership | One schema per module (`identity`, `profile`, `market`, `services`, `errands`, `logistics`, `finance`, `messaging`, `admin`, `platform`) |
| Money | `numeric(20, 4)` plus an explicit `currency` code. Never floating point. |
| Identifiers | UUIDv7, generated server-side |
| Timestamps | `timestamptz`, stored UTC |
| Common columns | `created_at`, `updated_at`, and — where user data — `owner_account_id` |
| State machines | Explicit status enum and legal transitions, enforced in the domain layer **and** by a check constraint |
| Soft delete | The exception, used only where retention requires it. Financial and audit records are never deleted. |
| Roles | Dedicated least-privilege roles; the API role owns nothing (`database rules` §6.9) |

### 9.5 Migrations

**[DECIDED]** Forward-only SQL migrations, versioned in the repository, reviewed like code, applied
by CI. Expand/contract for breaking changes so a rollback never requires data loss.

**All migration mechanics are governed by `Database-Migration-and-Supabase-Data-API-Rules.md` §9–§10**
— tooling, naming, self-containment, destructive-change gates, backfills, seeds, migration history,
`migration repair`, declarative schemas, and review. They are not restated here.

Hivorr-level additions from §12.4 of this document: a migration is reviewed before execution, applied
to staging first, and never executed against production by hand.

### 9.6 Row-level security

**[DECIDED]** RLS is enabled on account-scoped tables as **defence in depth**, never as the primary
authorisation mechanism. Authorisation is decided in the service layer; RLS exists so that a missed
filter fails closed rather than leaking rows.

The identity mechanism — a transaction-scoped session variable set by the repository layer — is
`database rules` §6.4 (Position A, adopted 3 November 2026). The role matrix is `database rules` §6.9.
Policy style, `force row level security`, index requirements, and recursive-policy traps are
`database rules` §6.3–§6.8.

**[DECIDED]** `auth.uid()` must never appear in a Hivorr policy: Supabase Auth is not used, so it
would return `NULL` and every policy would fail closed for every user.

### 9.7 Identity and authentication

**[DECIDED]** (§5)

- Email + password, hashed with **Argon2id**.
- Phone OTP for Nigerian numbers via Termii, plus email verification.
- Password reset by single-use, expiring token.
- No social login at MVP.
- **DECIDED 7 November 2026:** sign-in is **email-first** — email and password at registration, phone
  optional until a phone-dependent action (§16.4 #14).
- Sessions and audiences per §5.4.
- Privileged grants require TOTP MFA (§10.8).

### 9.8 Authorisation

**[DECIDED]** Capability-based, computed server-side from explicit inputs:

```
capabilities = f(
    account,
    activated activities and their states,
    verification lane states,
    KYC tier,
    grants: admin scope | staff function | partner | platform.engineering
)
```

- Computation is pure and deterministic. The same inputs always produce the same set.
- Capabilities are never stored as authority on the client, never encoded in a token claim the client
  can forge, and never trusted from a request body.
- Every mutating request re-checks the capability server-side, inside the transaction.
- Roles are **derived**, never selected or stored (`matrix` §9.2). This includes the Errand requester
  role, which the previous revision's derived-role table omitted.

### 9.9 API architecture

**[DECIDED]**

| Aspect | Decision |
| --- | --- |
| Style | REST/JSON, resource-oriented, versioned at `/v1` |
| Contract | OpenAPI 3.1 generated from code; TypeScript client generated for each app |
| Audience | Every endpoint declares its audience (`app` · `control` · `staff` · `partner`) |
| Pagination | Cursor-based, stable ordering |
| Errors | Stable machine codes plus a human message; never a bare 500 |
| Money mutations | `Idempotency-Key` required; replay returns the original result |
| Concurrency | `ETag` / `If-Match` on records with competing editors (listings, jobs) |
| Auth | Host-only cookie session per audience; bearer token supported for future mobile |
| Rate limits | Per account, per IP, and per audience; tighter on auth, money, and privileged routes |
| Webhooks (inbound) | Signature-verified, idempotent, stored before processing |
| Realtime | Server-Sent Events for notifications and delivery status; WebSocket for chat when needed |
| GraphQL | Not at MVP |

**Deliberate omission:** no public partner API at MVP. `partner.hivorr.com` is a partner *portal*,
not a partner *API*. If an API is added later it becomes a separate, scoped surface, not the internal
API opened up.

### 9.10 Financial architecture

**[DECIDED]**

A double-entry ledger is the source of truth.

```
journal_entry  (id, kind, reference, currency, created_at, idempotency_key)
postings       (entry_id, ledger_account_id, direction, amount, currency)
ledger_account (id, owner_type, owner_id, kind)
                 kind ∈ user_wallet | escrow | platform_clearing | fee_revenue
                      | payout_payable | commission_payable | adjustment
```

- Every entry balances to zero per currency.
- `postings` and `journal_entry` are append-only; correction is a reversing entry.
- Displayed wallet figures (total, available, pending, withdrawable) are **derived views**, matching
  the prototype's wallet semantics.
- Every posting carries its originating activity, so the statement is legible per activity without
  fragmenting the balance.
- Escrow lifecycle: `held → released` or `held → refunded`, plus dispute states. Release is a
  scheduled worker job after the approved holding period.
- VFD is the single payment and custody provider behind one `PaymentProvider` interface. NIBSS name
  enquiry for payout-account verification.
- Deposit webhooks enforce `Payer Name == Entity Profile Name` (`AGENTS.md` Rule 3).
- Payouts only to bound, pre-verified bank accounts.
- Every provider callback is stored raw, verified, then processed idempotently.
- A daily reconciliation job compares provider settlements against the ledger and alerts on mismatch.

**[OPEN]** The holding period, platform fee, dispute rules, currency model, and the funds-custody
question are all unresolved (`§16.4 #6, #8, #11, #12`). The custody question is the highest legal risk
in this document: holding user funds, escrow, and payouts may constitute a regulated payment service
in Nigeria. Two paths — a licensed provider holds and splits funds, or Hivorr holds balances and
pursues the licence. It must be settled with counsel before wallet code is written.

### 9.11 Messaging and notifications

**[DECIDED]**

- **Messaging:** threads scoped to a context (job, order, errand, delivery) with participants, text,
  attachments, read state. One inbox across activities, matching the prototype's shared surface.
- **Notifications:** one record per recipient, plus delivery attempts per channel. In-app at MVP;
  email and SMS for transactional events.
- **Delivery path:** state change → outbox event → worker → provider adapter → delivery attempt
  record, with retries and exponential backoff.
- **Templates** are versioned and rendered server-side; no PII in logs or analytics payloads.
- **Realtime:** SSE stream per account; the client reconnects and resumes from a cursor.
- **[OPEN]** Push notifications are deferred until mobile.
- **Staff and partner surfaces reuse the same notification infrastructure**, with their own
  templates. They do not get a second notification system.

### 9.12 Storage

**[DECIDED]**

| Concern | Decision |
| --- | --- |
| Storage | Cloudflare R2 (no egress fees), S3-compatible |
| Upload | Pre-signed `PUT`; the API issues the URL after validating type, size, and ownership |
| Buckets | `public-media` (product images, avatars, hero art) and `private-documents` (KYC, contracts, proof of delivery) |
| Public media | Served through the CDN; no direct bucket access |
| Private documents | No public URL; short-lived signed `GET`; every access logged |
| Scanning | Asynchronous virus/malware scan before a document is usable |
| Images | CDN-side resize and format negotiation |
| Retention | Defined per class; KYC follows regulatory retention; deletion is logged |

Large files never stream through the API process. Supabase Storage is **not** used
(`database rules` §8.1).

### 9.13 Administrative services

**[DECIDED]** Module 9 provides the read models and commands behind `control.` and `staff.`. It owns
review queues, moderation, configuration, disputes, staff scopes, partner programme records, and
audit access. It reads other modules' data through read models, never through their tables (§9.3).

### 9.14 Location and logistics

**[DECIDED]** Geo is a platform capability (module 10): geocoding, distance, and radius queries.
Errands and Logistics depend on it; they do not each implement their own.

**[OPEN]** Map provider and routing engine are not chosen. The prototype shows route placeholders and
staged delivery progression but no map, so the architecture must not assume one.

### 9.15 Future integrations

**[DECIDED]** Every external service sits behind an adapter in `integrations/` with a narrow
interface. Payment, SMS, email, storage, KYC, and (later) airtime, utilities, and subscriptions all
follow the same rule. A new provider replaces an adapter, never a caller.

---

## 10. Security and Permission Boundaries

### 10.1 The trust model, stated plainly

**[DECIDED]** The client is hostile. The network is hostile. A hostname proves nothing. Every
decision is made server-side, inside a transaction, from data the server owns.

### 10.2 Enforcement layers

**[DECIDED]** Four layers, all required (`matrix` §11.1):

| Layer | Responsibility | Failure mode if missing |
| --- | --- | --- |
| **Edge** | TLS, HSTS, CSP, CORS allowlist, coarse rate limits | Noise, not a breach |
| **Route guard** | Reject unauthenticated, wrong-audience, or out-of-scope requests early | Noise, not a breach |
| **Service-layer policy** | The authoritative capability decision, inside the transaction | **The breach** |
| **Database tenancy** | RLS and owner/party constraints | Cross-account leakage |

### 10.3 Centralised identity, isolated sessions

**[DECIDED]** One identity service per environment; four session audiences (§5.4).

| Rule | Reason |
| --- | --- |
| Host-only cookies, no parent-domain cookie | A compromise on `partner.` must not yield a product session, and a cookie must never cross environments |
| Session audience checked on every request | A stolen `app` session must not open `control.` |
| Session environment/issuer checked on every request | A staging session must not open production, even through a misconfigured edge |
| Distinct cookie names per host | Prevents accidental reuse and makes logs unambiguous |
| Refresh-token reuse detection revokes the family | Limits the value of a stolen token |
| Privileged sessions are shorter-lived | §10.8 |
| Sign-out revokes server-side | A cleared cookie is not a logout |

### 10.4 Role-based access control and activity permissions

**[DECIDED]** Two orthogonal axes, never conflated (`matrix` §9.1):

- **Activity** — one of six, granted by the user, visible in the switcher.
- **Grant** — admin scope, staff function, partner membership, or engineering; granted by the
  founder or a delegate, never visible in the switcher.

A capability is the intersection of the account's activities, verification lanes, KYC tier, and
grants. There is no "Seller permission", only `market.sell` plus the seller lane.

### 10.5 Administrative privilege restrictions

**[DECIDED]**

- Admin scopes are enumerated, never binary (`matrix` §14.2).
- High-risk actions require dual control and an immutable audit record: refunds, manual payouts,
  verification overrides, account suspension (`matrix` §14.3).
- No admin may suspend or modify their own account.
- **A developer grant never includes money, PII by default, or business decisions** (§4.4).
- The founder retains ultimate business authority.

### 10.6 Staff permission boundaries

**[DECIDED]**

- Staff capabilities are job-specific and drawn from a small, enumerated set (§7.3).
- Staff never receive `admin.*` by default.
- Staff never gain activity capabilities.
- Staff PII access is limited to what the task requires; evidence and documents are served through
  signed URLs and every access is logged.
- Staff grants are revoked on role change, not left dormant.

### 10.7 Partner access restrictions

**[DECIDED]**

- A partner session cannot call any activity capability, wallet endpoint, or admin endpoint.
- Partner data scope is the organisation, not the referred user.
- Partner users see aggregate referral status, not the referred account's records.
- Partner access is revoked when the programme relationship ends; historical commission records are
  retained.

### 10.8 Multi-factor authentication

**[DECIDED]**

| Surface | MFA |
| --- | --- |
| `hivorr.com` / `staging.hivorr.com` | Optional at MVP; available to every account |
| `staff.hivorr.com` / `staff-staging.hivorr.com` | **Mandatory** TOTP |
| `control.hivorr.com` / `control-staging.hivorr.com` | **Mandatory** TOTP; optional IP allowlist for the founder; Cloudflare Access at the edge |
| `partner.hivorr.com` / `partner-staging.hivorr.com` | **Mandatory** TOTP for commission payout access |

Staging privileged accounts are separate accounts with separate grants; a production staff or admin
grant does not exist in staging unless it is seeded there under a synthetic identity.

**[RECOMMENDED]** TOTP at MVP, WebAuthn when a second factor is added. Recovery codes are single-use
and stored hashed.

### 10.9 Audit logging

**[DECIDED]** An append-only `audit_log`: actor, actor type, actor audience, action, target type,
target id, before/after summary, IP, user agent, correlation id, timestamp.

- Admin, staff, engineering, and partner actions **all** write to it.
- Verification decisions, financial mutations, and grant changes write to it.
- It is separate from application logs and is retained longer.
- **[RECOMMENDED]** It is written by the service layer, not by a database trigger alone, so that the
  reason and correlation id are captured with it.

### 10.10 Rate limiting and suspicious-login monitoring

**[DECIDED]**

- Rate limits on sign-in, OTP issuance, password reset, and privileged endpoints; exponential
  backoff and lockout.
- OTP single-use with a short TTL.
- Alerts on credential-stuffing patterns, impossible travel, and repeated MFA failures.
- Privileged sign-in from a new location raises an alert and writes an audit record.
- **[RECOMMENDED]** Every privileged session shows its recent sign-ins in the UI.

### 10.11 Sensitive financial and identity information

**[DECIDED]**

- TLS 1.2+ everywhere; HSTS on all eight hosts.
- Encryption at rest for the database and buckets; field-level encryption for bank details.
- Secrets in a managed secret store with rotation; no secret in any client bundle.
- Strict CORS allowlist per entry point; CSP; no third-party scripts on authenticated pages.
- Dependency scanning and lockfile pinning in CI; SAST on pull requests.
- Least-privilege database roles: the API role cannot alter schema; migrations run as a separate role
  (`database rules` §6.9).
- PII is minimised, classified, and redacted from logs. Data-subject access and deletion are
  supported where law permits, with financial and audit records exempted by retention obligations.

### 10.12 Subdomain separation is not a security control

**[DECIDED]** This is stated explicitly because it is the most likely misreading of §4.

A subdomain changes **what is deployed where**, and that is genuinely useful: `partner.` ships no
admin code, and `control.` can be network-restricted. But a hostname is a DNS record, not an
authorisation check. Everything that actually protects the system is server-side:

| Control | Enforced by |
| --- | --- |
| Who may call an endpoint | Session audience + environment/issuer + capability check in the service layer |
| Which rows are visible | Ownership/party scope + RLS |
| Which money may move | KYC tier + verification lane + ledger invariants + idempotency |
| Which grant exists | Grant records, audited, revocable |
| What a compromised app can do | The API's scope for that audience — nothing more |

If `control.hivorr.com` were served from `hivorr.com/control` tomorrow, the security posture would be
unchanged. The reverse is also true: a separate hostname would not save a system that trusted it.
Cloudflare Access on the control and staff hosts is an additional exposure-reduction layer, not a
substitute for any row in this table.

### 10.13 Threat model

| Threat | Primary control |
| --- | --- |
| Account takeover | Argon2id, OTP limits, session revocation, MFA on privileged surfaces |
| Horizontal privilege escalation (IDOR) | Capability checks + `owner_account_id` + RLS |
| Cross-activity leakage | Activity-scoped queries; no "all data" endpoints |
| Cross-audience leakage | Session audience + separate bundles + CORS allowlist |
| Cross-environment leakage | Separate API/DB/keys/buckets + environment-bound session issuer + network egress controls |
| Legacy origin remains authoritative | Controlled cutover with DNS/domain detachment, verification, and a preserved rollback position (§12.10) |
| Staff overreach | Job-scoped grants, no default admin, audited actions |
| Developer overreach | `platform.engineering` excludes money and PII; dual control on production changes |
| Partner pivot into the product | Partner sessions carry no activity capability |
| Payment fraud | Name-match rule, verified webhooks, ledger reconciliation, idempotency |
| Fake verification documents | Review queue, document scanning, dual control on override |
| Insider admin abuse | Scoped roles, dual control, immutable audit log |
| Webhook spoofing | Signature verification, replay window, stored raw payload |
| Malicious uploads | Type/size validation, scanning, private bucket, no inline rendering of untrusted SVG |
| Data exfiltration via API | Rate limits, pagination caps, per-account query budgets |
| Supply-chain compromise | Pinned versions, `minimumReleaseAge`, lockfile, dependency scanning |

---

## 11. Development, Staging and Production Environments

### 11.1 Two hosted environments plus local development

**[DECIDED]** There are two hosted environments, staging and production, plus local development.
Each hosted environment runs four applications, one API, one worker, and one database.

| | Development | Staging | Production |
| --- | --- | --- | --- |
| Purpose | Local implementation and testing; controlled source changes | Integrated testing, QA, founder review | Live product |
| Applications | `localhost:8443` (Vite) | `staging.hivorr.com`, `control-staging.hivorr.com`, `staff-staging.hivorr.com`, `partner-staging.hivorr.com` | `hivorr.com`, `control.hivorr.com`, `staff.hivorr.com`, `partner.hivorr.com` |
| API | local process | staging Fly.io app | production Fly.io app |
| Database | local Postgres container | **staging Supabase project only** | **production Supabase project only** |
| Storage | local or a dev bucket | staging R2 buckets | production R2 buckets |
| Payments | provider test mode | VFD test/sandbox only | VFD live only |
| SMS / email | captured, never sent | captured or approved test recipients | live |
| Data | synthetic seeds | synthetic or anonymised | real |
| Access | the developer | authorised testers + founder | the public, with founder-gated release |
| Edge protection | none | Cloudflare Access on control/staff | Cloudflare Access on control/staff |

### 11.2 Isolation rules

**[DECIDED]** — these are not guidelines.

1. **No production data in development or staging**, ever. Not a dump, not a sample, not "just one
   table". Staging seeds are synthetic.
2. **No shared credentials** across environments. Separate database users, separate API keys,
   separate payment accounts, separate buckets, separate signing keys, separate queue namespaces.
3. **No shared secrets file or secret namespace.** Each environment has its own secret store
   namespace and its own runtime identity.
4. **Separate session issuers and signing keys.** A staging session is cryptographically invalid in
   production, independent of the hostname.
5. **Staging never calls a production service.** If a provider cannot be sandboxed, the call is
   intercepted and recorded. Staging egress to production resources is blocked at the infrastructure
   level, not by convention.
6. **Separate databases.** A staging migration never touches the production database, and a
   production connection string never exists in a staging secret store.
7. **Separate object storage and queues.** Staging buckets and queues are distinct from production;
   no shared bucket prefix or queue name.
8. **Staging is not publicly linked** and is `noindex` on every host, including
   `staging.hivorr.com`.
9. **Staging accounts and grants are separate.** A production staff or admin grant does not exist in
   staging except as a synthetic seeded identity with its own credentials.

#### 11.2.1 Supabase project separation

**[DECIDED]** Staging and production use **two independent Supabase projects**. There is no shared
project, no shared database, no shared API key, and no fallback from one to the other.

| Environment | Supabase project reference | Status |
| --- | --- | --- |
| Production | `ahyizcwidkwyowroeqfp` | **Verified 7 November 2026** — DNS resolves; REST endpoint returned `401` without a key |
| Staging | `hkswhaltyqfqkgswukfs` | **Verified 7 November 2026** — DNS resolves; REST endpoint returned `401` without a key |
| Production (retired) | `fxpcgtetvzlexbptqiwp` | Deleted by the founder; the live Flutter bundle still embeds it |
| Staging (retired) | `cgxkiczmwzydhoroclvf` | Deleted by the founder; the live Flutter bundle still embeds it |

The active references are also recorded in `config/backend-projects.json`, which the deployment
preflight reads. The two retired references are recorded only as historical evidence. They must not
be used or recreated.

**Enforced configuration contract.**

- `HIVORR_ENV` is `staging` or `production`.
- `BACKEND_ENVIRONMENT` is required and must equal `HIVORR_ENV`.
- `SUPABASE_PROJECT_REF` is required and must match the environment's project reference.
- `DATABASE_URL` must belong to `SUPABASE_PROJECT_REF`: a direct Supabase host
  `db.<ref>.supabase.co`, or a pooler username containing the project reference.
- `EXPECTED_SUPABASE_PROJECT_REF` is supplied by the deployment environment and must equal
  `SUPABASE_PROJECT_REF`.
- `scripts/verify-backend-target.mjs` refuses a deployment when any of the above fails, when staging
  and production references are identical, or when the deployment points at the other environment's
  project.
- The API configuration refuses to start in staging or production if the environment, project
  reference, or database URL is missing or inconsistent.

**Production credentials are never placed in a staging build, workflow, secret namespace, or
developer workstation.** A production connection string is stored only in the production secret
store. The database password is never committed, logged, or pasted into an issue.

### 11.3 What staging must mirror

**[DECIDED]** Staging is only useful if it can catch production failures:

- the same release artifacts (§12.7), not a rebuild;
- the same migration set, applied in the same order;
- the same configuration *shape* (every key present, values different);
- the same infrastructure topology: four applications, one API, one worker, one database, one bucket
  set per environment;
- the same feature-flag defaults unless a flag is explicitly under test;
- the same cross-application workflows, tested as one ecosystem.

**[RECOMMENDED]** A migration that has not run on staging has not been tested. Production applies
only migrations that staging has already applied successfully.

### 11.4 What staging must not have

**[DECIDED]** Live payment credentials · real customer data · production signing keys · a public
route from the production product · the ability to send real SMS or email to real users · any grant
that exists in production but not in staging's seed · a shared database, bucket, queue, or secret
with production.

### 11.5 Production protection

**[DECIDED]**

- Production is reachable only through the release pipeline (§12). No direct deploys, no manual file
  uploads, no console writes to the database.
- The production environment requires an explicit, recorded founder approval for every deployment
  (§12.5). Approval of one release does not authorise the next.
- Production secrets are readable only by the production runtime identity and the production
  deployment workflow.
- Production database access for humans is break-glass, time-boxed, dual-controlled, and audited.
- Cloudflare Access protects `control.hivorr.com` and `staff.hivorr.com` at the edge. The application
  still authenticates and authorises every request.

### 11.6 Local development

**[RECOMMENDED]** One command starts Postgres, the API, the worker, and the Vite dev server. Seed
data covers each activity and each verification state so permission behaviour is testable without
manual setup. The Figma Make preview must keep working throughout (§8.11). Local development never
connects to staging or production.

### 11.7 Staging verification gate

**[DECIDED]** A release is staging-verified only when all of the following are recorded against the
same commit and artifact set:

1. All CI gates pass on the commit.
2. All four staging applications and the staging API/worker are deployed from the same release
   artifacts.
3. The migration set applies cleanly to staging from the previous state and from empty.
4. Smoke tests pass on all four staging hosts, including headers, `noindex`, and session-audience
   rejection.
5. Cross-application E2E scenarios pass for every affected workflow.
6. Visual regression passes at 375 / 768 / 1280 px.
7. No staging credential, bucket, or queue can reach production.

A release request cannot be prepared until this gate is recorded (§12.5).

### 11.8 Cross-portal workflows that staging must test

**[DECIDED]** These workflows are the reason the four portals exist in the same environment. Each is
an end-to-end staging scenario using synthetic accounts, never production data.

| # | Workflow | Cross-portal path |
| --- | --- | --- |
| 1 | **User verification** | Main submits identity/trade evidence → API case → staff processes within policy → control approves where required → main reflects the new lane state and unlocks gated writes. |
| 2 | **Customer complaint** | Main raises a complaint → staff receives and investigates → escalation to control where authority is required → client receives updates on main. |
| 3 | **Affiliate referral** | Approved partner uses a referral mechanism → referred user registers on main → backend attributes eligible activity → commission appears in the partner portal → control oversees the programme. |
| 4 | **Account suspension** | Control suspends an account → all sessions in every portal are revoked → main, staff, and partner access is denied → audit record is written. |
| 5 | **Dispute and refund** | Main opens a dispute → staff triages → control decides with dual control where required → ledger entry and notification → main reflects the outcome. |
| 6 | **Listing moderation** | Seller publishes on main → staff/control review → publish or deny → main shows the correct status and reason. |
| 7 | **KYC/tier change** | Main submits evidence → staff/control decision → financial capability changes → main and staff read models update. |
| 8 | **Partner payout review** | Partner requests commission payout → staff/control reviews → finance executes through the provider adapter → partner sees updated status, not another partner's data. |

Every scenario must prove:

- the correct portal receives the task and the others do not;
- a user without the required grant receives a stable deny response;
- a session from one portal or environment cannot perform the action;
- the state change is visible in every portal that should see it;
- the audit record names the actor, audience, environment, target, and correlation id;
- no live payment, SMS, or email leaves staging.

---

## 12. CI/CD and Deployment Governance

### 12.1 Branching model

**[DECIDED]** Two protected branches and short-lived working branches. The flow is
`feature → staging → main`; `staging` is the integration branch and `main` is the production
release branch.

| Branch | Purpose | Lifetime |
| --- | --- | --- |
| `main` | Production release branch; always deployable | permanent |
| `staging` | Integration and staging deployment branch | permanent |
| `feat/<slug>`, `fix/<slug>`, `chore/<slug>`, `docs/<slug>`, `test/<slug>` | One change | hours to days |
| `release/<date>` | **Not used** — production is a promotion, not a branch | — |

Rules:

- No direct commits or pushes to `main` or `staging`. Pull request required.
- A working branch merges into `staging` first. Only a verified `staging` commit is promoted to
  `main` by pull request.
- Linear history; squash merge; no merge commits.
- Force-push and branch deletion on `main` and `staging` are disabled where the GitHub plan allows
  it, and detected by CI where it does not (§12.3).
- A branch that cannot merge within a few days is split.

### 12.2 Pipeline stages

**[DECIDED]**

```
pull request
  1 install (frozen lockfile)
  2 lint + format check (oxfmt)
  3 typecheck (tsc --noEmit)
  4 unit + component tests
  5 build all four application bundles
  6 visual regression against the baseline
  7 OpenAPI diff (breaking change = failure)
  8 dependency + secret scan
  9 migration lint + `db diff` review artefact
        │
        ▼
merge to staging
 10 repeat gates on the merged commit; deployment depends on their success
 11 build once → one release manifest and immutable artifacts per component
 12 verify the staging backend target (environment, project ref, database URL)
 13 deploy the four staging applications + staging API + worker
 14 apply migrations to staging
 15 smoke test every staging host + cross-application E2E
 16 record the staging-verified release
        │
        ▼
release request (GitHub Issue)
 17 issue contains SHA, manifest, digests, migrations, changes, test evidence, rollback target
        │
        ▼
founder approval (issue comment)
 18 `/approve-release <sha>` from the authorised founder account
 19 approval workflow verifies identity, SHA, issue state, and successful staging verification
        │
        ▼
production promotion (gated)
 20 download the same staging artifacts; verify digests
 21 verify the production backend target (environment, project ref, database URL)
 22 apply the reviewed migration set to production (expand/contract only)
 23 deploy the same artifacts to the four production hosts + production API/worker
 24 post-deploy smoke test on all eight hosts
 25 monitor error rate and queue depth for 30 minutes
```

A normal push, PR merge, or staging deployment never triggers production. Production is reachable
only through the approval in §12.5.

### 12.3 Environment protection

**[DECIDED]** Staging and production are GitHub Environments. Deployment credentials exist only in
the environment that uses them.

| Environment | Trigger | Approval |
| --- | --- | --- |
| Preview (per PR) | automatic | none |
| Staging | successful CI on `staging` | none, but all gates must be green |
| Production | approved release request | **founder, per deployment** |

**GitHub Free constraint (verified 6 November 2026).** This private repository is on GitHub Free.
Server-side branch protection, rulesets, required status checks, and environment required reviewers
are unavailable. The controls in this repository are therefore:

1. the local pre-push hook, which blocks accidental direct pushes;
2. the CI `verify-pr-merge` guard, which fails a protected-branch push that is not linked to a merged
   PR;
3. deployment workflows that depend on successful CI and on the founder approval workflow;
4. artifact promotion, which refuses to build a different artifact for production.

These are **compensating controls, not server-side enforcement**. A repository administrator can
alter a workflow, a variable, or a protected branch. The alternatives are recorded in §16.4 #27:
remain on Free with compensating controls, upgrade to GitHub Pro/Team for enforceable branch and
environment protection, or move hosting. No upgrade is required by this revision.

### 12.4 Migration review gate

**[DECIDED]** Production database migrations undergo review before execution.

| Step | Requirement |
| --- | --- |
| Authoring | Migration is written as SQL, forward-only, self-contained |
| Review | A second person reviews the SQL and the `db diff` output — not just the PR title |
| Dry run | Applied to staging first, with timing recorded for large tables |
| Destructive change | Requires an explicit founder sign-off and an expand/contract plan |
| Execution | CI job, as the migrator role, before the application deploy |
| Verification | Post-migration smoke test; schema drift check |
| Emergency | Same review, compressed; never "just run it on production" |

Migration mechanics — naming, self-containment, `migration repair`, declarative schemas — are
`Database-Migration-and-Supabase-Data-API-Rules.md` §9.

### 12.5 Release approval

**[DECIDED]** **Every production release requires explicit founder approval. Approval of one release
does not authorise future releases.**

The release request is a GitHub Issue created only after the staging verification gate passes
(§11.7). It contains:

- the release tag/version and commit SHA;
- the staging CI run and staging deployment record;
- the release manifest and the digest of every application, API, and worker artifact;
- the migration set and its hash;
- the affected applications and the cross-application workflows tested;
- the change summary since the previous release;
- the test evidence: CI, smoke, E2E, visual regression, security scans;
- the rollback target: the previous release manifest and digests.

The approval is an issue comment from the authorised founder account using the agreed command:

```
/approve-release <release-sha>
```

The approval workflow verifies, before it dispatches anything:

1. the comment is newly created and the issue carries the release-candidate label;
2. the comment author is the configured founder GitHub account;
3. the SHA in the comment matches the issue's release SHA;
4. the same SHA has a successful staging verification record;
5. the artifact manifest still exists and its digests match the staging artifacts.

It records the approval comment ID, the approver, the timestamp, the SHA, and the digests. Only then
does it dispatch the production promotion. The production workflow re-verifies the approval record
and refuses to build a new artifact. A normal push, PR merge, staging deployment, or manual dispatch
without a matching approved issue never deploys to production.

**Sole-operator note.** The founder may be both the approver and the repository administrator. The
separation preserved here is between **approval** and **execution**: the approval is a recorded
comment, and the deployment is performed by the workflow from the approved artifacts, not from a
workstation. Under GitHub Free the founder's admin access remains a residual risk (§12.3).

### 12.6 Rollback and recovery

**[DECIDED]**

- Application rollback is a redeploy of the previous release manifest's artifacts. No rebuild.
- Database changes follow expand/contract, so a rollback never requires a destructive migration.
- A migration that cannot be rolled back forward is not merged.
- Every release records its rollback target and the previous manifest.
- Restore drills are quarterly, with a documented RTO (§13.6).
- **[OPEN]** Backup tier, PITR retention length, and logical-dump destination (`§16.4 #13`).

### 12.7 Artifact provenance

**[DECIDED]**

- Build once, promote the same artifacts. Staging and production run identical bytes.
- The release manifest records the commit SHA, release tag, build time, and the digest of each
  application bundle, the API image, the worker image, and the migration set.
- The manifest is stored with the artifacts and referenced by the release issue.
- The artifact digest is recorded in the deployment, the audit record, and the release note.
- Dependencies are installed from the frozen lockfile only.
- Builds are reproducible from a tagged commit.
- If the staging artifacts have expired or their digests do not match, promotion fails and the
  release must be re-staged. Production never rebuilds.

### 12.8 What is prohibited

**[DECIDED]**

- Deploying to production from a laptop.
- Applying a migration by hand to production.
- Editing production configuration outside the pipeline.
- Sharing a production secret with a developer workstation.
- A production deployment that does not originate from an approved staging release.
- Rebuilding an artifact for production instead of promoting the staged one.
- Approving a release whose staging verification is missing, failed, or belongs to a different SHA.
- Shipping a release whose migration has not run on staging.
- Deploying a backend without passing `scripts/verify-backend-target.mjs`, or with a database URL
  that belongs to another environment's Supabase project.
- Leaving the legacy Flutter origin serving after a completed cutover without a recorded rollback
  position.

### 12.9 Coordinated releases

**[DECIDED]** Releases are **lockstep** at MVP. One commit produces one release manifest covering:

- `web`, `control`, `staff`, and `partner`, in both environments;
- the API and worker;
- the migration set;
- the configuration shape and feature-flag defaults.

All eight hosts and the API report the same release SHA. A staging verification that covers only one
application is not sufficient for a change that affects shared identity, permissions, API contracts,
or another application's workflow.

Independent application releases are not permitted at MVP. They may be introduced later only when
the API contract declares a compatibility range, the manifest records it, and staging verifies every
consuming application. That is a recorded architecture change, not an operational shortcut.

### 12.10 Legacy Flutter cutover

**[DECIDED]** The legacy Flutter applications formerly serving `hivorr.com` and
`staging.hivorr.com` were retired by **immediate detach** on 7 November 2026. The operational record is
`documents/Engineering-Execution/LEGACY_FLUTTER_CUTOVER.md`.

What happened:

1. The two web CNAME records were deleted.
2. The two Flutter Pages custom domains were removed.
3. The two Flutter Pages projects were deleted.
4. No Flutter rollback target remains.
5. The domain registration, Cloudflare zone, MX, and TXT records are intact.
6. Both hostnames remain dark until the React production deployment exists.
7. The operation was performed with founder approval and scoped Cloudflare access; the tokens were
   revoked afterwards.

---

## 13. Future Expansion Strategy

### 13.1 Three tiers

**[DECIDED]** Every future capability belongs to exactly one tier, and the tier determines what is
built now.

| Tier | Meaning | What is built now |
| --- | --- | --- |
| **MVP** | Required for launch | Fully implemented and tested |
| **Architecturally ready** | Not built, but the seam exists and building it later needs no redesign | The boundary, the naming, and the registry entry — **no feature code** |
| **Reserved** | Possible, but no seam is worth building yet | Nothing. Documented so it is not accidentally blocked |

### 13.2 The extension seams

**[DECIDED]** Five seams, no more. Each already exists for MVP reasons; none was invented for the
future.

| Seam | What it is | Why it already exists |
| --- | --- | --- |
| **Activity registry** | Activities are definitions (id, name, dashboards, navigation, accent, lanes), not hard-coded switches | The six activities already need a switcher and per-activity navigation |
| **Module boundary** | A module owns a schema and exposes a service contract | Six activities already require isolation (§9.2) |
| **Capability namespace** | `<domain>.<resource>.<action>` strings, computed not stored | The permission matrix already works this way (`matrix` §9.3) |
| **Provider adapter** | One interface per external service | Payments already need a provider boundary for VFD and any future provider |
| **Outbox events** | Side effects published transactionally | Notifications already need them (§9.11) |

A sixth seam is not needed. If a future feature appears to need one, that is a signal to re-read this
section rather than to add a framework.

### 13.3 Future service categories

**[DECIDED]** — how each named future service is expected to land. This is a classification, not a
commitment.

| Future service | Expected tier | Expected shape |
| --- | --- | --- |
| Airtime and data purchases | Architecturally ready | A **service vertical** inside the Buy activity, not a new activity. Provider adapter + a `digital` sub-domain in the market module. |
| Electricity and utility bill payments | Architecturally ready | Same as airtime: a service vertical with a biller adapter and a stored customer reference. |
| Television subscriptions | Reserved | Same shape as utilities, but the biller integrations are distinct enough that no seam is worth building until utilities ship. |
| Additional marketplace services | Architecturally ready | New verticals in the **taxonomy registry** (module 10). Taxonomy is already admin-configurable, so this needs data, not code. |
| Financial and digital services | Reserved | Depends on the custody decision (§9.10). Do not design a wallet extension before that is settled. |
| Third-party integrations | Architecturally ready | Provider adapters (§9.15) plus scoped API credentials. |
| Other future service categories | Reserved | Assessed against §13.4. |

### 13.4 Activity or service vertical? The four-part test

**[DECIDED]** This is the rule that prevents both activity explosion and premature architecture.

A new offering becomes a **new activity** only when **all four** are true:

1. It needs its **own dashboard and navigation set** that would be incoherent inside an existing one.
2. It has **different permissions and verification requirements** from every existing activity.
3. It produces **different transaction records** that an existing activity cannot own.
4. A user would reasonably expect to **switch to it** as a distinct way of using Hivorr.

If any answer is no, it is a **service vertical** inside an existing activity — new taxonomy data, a
new provider adapter, new capabilities in an existing namespace. Airtime is a vertical. Selling is an
activity.

### 13.5 What "architecturally ready" means — and does not mean

**[DECIDED]**

| It means | It does not mean |
| --- | --- |
| The activity registry accepts a new entry without a schema change | A plugin runtime, a dynamic module loader, or remote module federation |
| A new module can be added without touching existing modules | A generic workflow engine, a rules engine, or a BPMN layer |
| A new provider implements an existing adapter interface | An integration marketplace or self-service connector builder |
| A capability namespace has room for a new prefix | A permission DSL or a policy language |
| The taxonomy registry can hold a new vertical | A generic entity-attribute-value model for everything |

**No feature code is written for a tier-2 item.** Readiness is a property of the boundaries, not of
extra code.

### 13.6 Revisit triggers

**[DECIDED]**

| Trigger | Reconsider |
| --- | --- |
| Sustained > 70% database CPU | read replicas, caching layer |
| Queue latency above target | move from the Postgres queue to Redis |
| A module's deploy cadence diverges sharply | extract that module |
| Second market or second currency | multi-currency ledger design |
| Mobile app funded | sync engine, push, offline model |
| Regulated licence obtained | custody and settlement design |
| A second full product line appears | microservice extraction for that line only |

---

## 14. Proposed Project Structure

### 14.1 The layout

**[RECOMMENDED]** — the repository structure this document proposes for implementation. No folder in
this section was created by this revision.

```
/                          # repository root
├── src/                   # current Figma Make web app (the prototype)
│   ├── app/
│   │   ├── App.tsx        # shrinks as screens are extracted
│   │   ├── shells/        # MarketShell, ClientShell, AdminShell (extracted)
│   │   └── routes.tsx     # route table (new)
│   ├── features/          # one folder per module boundary (§9.2)
│   │   ├── identity/
│   │   ├── profile/
│   │   ├── market/
│   │   ├── services/
│   │   ├── errands/
│   │   ├── logistics/
│   │   ├── finance/
│   │   ├── messaging/
│   │   └── admin/
│   ├── styles/            # theme.css, fonts.css, tailwind.css, index.css
│   ├── components/        # app-level composition (thin)
│   └── main.tsx
│
├── apps/                  # additional entry points (new)
│   ├── control/           # control.hivorr.com
│   ├── staff/             # staff.hivorr.com
│   └── partner/          # partner.hivorr.com
│
├── server/                # API + worker (new package)
│   ├── src/
│   │   ├── modules/       # identity, profile, market, services, errands,
│   │   │                  # logistics, finance, messaging, admin, platform
│   │   ├── integrations/  # payment, sms, email, storage, kyc, geo adapters
│   │   ├── common/        # guards, interceptors, errors, correlation id
│   │   ├── main.ts        # API entry point
│   │   └── worker.ts      # worker entry point
│   ├── migrations/        # forward-only SQL
│   └── test/
│
├── packages/
│   ├── design/            # tokens + prototype primitives (§8.4)
│   ├── shared/            # types, zod schemas, capability constants, activity registry
│   └── api-client/        # generated OpenAPI client
│
├── documents/Context/     # governance documents (this file lives here)
├── guidelines/
├── .figma/                # Figma Make configuration — do not disturb
├── package.json           # root web app (Figma Make)
├── pnpm-workspace.yaml    # extended to include apps/, server/, packages/
└── vite.figma.config.ts   # Figma Make wrapper — must keep working
```

### 14.2 Why the root package does not move

**[DECIDED]** `vite.figma.config.ts` imports `./vite.config.ts` and reads `.figma/make/*`. Moving the
web app into `apps/web` would break the Figma Make wrapper and therefore the prototype preview.

Therefore:

- The web app stays at the repository root while Figma Make is in use.
- New apps start under `apps/` because Figma Make does not build them.
- If Figma Make is retired, moving `src/` to `apps/web/` becomes a **mechanical move with visual
  regression proof** — not a redesign. It is not done now.

### 14.3 Directory responsibilities

| Path | Responsibility | Rule |
| --- | --- | --- |
| `src/app/` | Composition: shells, route table, providers | No business logic, no raw SQL, no capability decisions |
| `src/features/<module>/` | Screens and feature components for one module | May import `packages/design` and `packages/api-client`; never another feature's internals |
| `packages/design/` | Tokens + primitives | **The only place a primitive is defined.** Never restyled by a feature |
| `packages/shared/` | Types, schemas, capability constants, activity registry | Pure. No React, no database access |
| `packages/api-client/` | Generated client | Generated, never hand-edited |
| `server/src/modules/<module>/` | Controller → service → domain → repository | One schema per module (§9.2) |
| `server/src/integrations/` | Provider adapters | The only place a provider SDK is imported |
| `server/migrations/` | Forward-only SQL | Reviewed, never hand-applied (§12.4) |
| `apps/<app>/` | One privileged entry point | Consumes shared packages; contains no domain logic |
| `documents/Context/` | Governance | Source of truth for rules, not code |

### 14.4 Naming and import rules

**[RECOMMENDED]**

- Workspace package names: `@hivorr/design`, `@hivorr/shared`, `@hivorr/api-client`, `@hivorr/server`.
- Cross-package imports go through the package name, never a relative path across a boundary.
- `src/features/market` may not import `src/features/finance`. Shared behaviour moves to
  `packages/shared` or a server module.
- A module's public surface is a single `index.ts`. Everything else is internal.
- No barrel files that re-export an entire module; they hide cycles.

### 14.5 What not to create

**[DECIDED]** Explicitly, so the structure does not grow by imitation:

- No `utils/` dumping ground. A helper lives next to its only caller until a second caller exists.
- No `hooks/` folder for one hook.
- No `types/` folder that duplicates `packages/shared`.
- No `services/` folder in the frontend that is not the API client.
- No per-activity frontend package. Activities are features in one app, not six apps.
- No per-activity backend. Activities are modules in one API, not six services.
- No `common/` in the frontend. Shared code is a package.

---

## 15. Technical Dependencies

### 15.1 Frontend — present and in use

**[DECIDED]**

| Package | Version | Used for |
| --- | --- | --- |
| `react`, `react-dom` | 18.3.1 | UI runtime |
| `lucide-react` | 0.487.0 | the only icon source |
| `vite` | 6.3.5 | build and dev server |
| `@vitejs/plugin-react` | 4.7.0 | React transform |
| `tailwindcss`, `@tailwindcss/vite` | 4.1.12 | utility layer over the tokens |
| `tw-animate-css` | 1.3.8 | the prototype's animation utilities |
| `typescript` | ^5.7 | types |
| `oxfmt` | ^0.2.0 | formatting |

### 15.2 Frontend — present, unused, or dormant

**[DECIDED]** See §2.4 for the ruling on each.

| Package | State | Ruling |
| --- | --- | --- |
| `react-router` | installed, unused | **Adopt** for routing (§8.6) |
| `react-hook-form` | installed, unused | **Adopt** for forms (§8.7) |
| `class-variance-authority`, `clsx`, `tailwind-merge` | used only by the unused shadcn kit | Adopt only if the design system needs variants; otherwise dormant |
| 26 × `@radix-ui/react-*` | used only by the unused shadcn kit | Dormant. The prototype implements its own primitives. Adopt a Radix primitive only when building an accessible widget the prototype does not have (for example a combobox) |
| `recharts`, `sonner`, `cmdk`, `vaul`, `embla-carousel-react`, `react-day-picker`, `input-otp`, `next-themes`, `react-resizable-panels` | reachable only through the unused shadcn kit | Dormant. The prototype uses inline SVG charts and its own dialogs |
| `@popperjs/core`, `react-popper` | imported nowhere | **Do not use.** Remove when the prototype is retired |
| `@mui/material`, `@mui/icons-material`, `@emotion/react`, `@emotion/styled` | imported nowhere; **removed from `package.json` 3 November 2026** | **Do not re-add.** The lockfile still resolves them until `pnpm install` runs (EX-19) |
| `motion`, `date-fns`, `react-dnd`, `react-slick`, `react-responsive-masonry`, `canvas-confetti` | imported nowhere | **Do not use.** Not part of the design language |

### 15.3 Frontend — to be added

**[RECOMMENDED]**

| Package | Purpose | Needed by |
| --- | --- | --- |
| `@tanstack/react-query` | server state, caching, invalidation | §8.7 |
| `zod` | shared validation schemas | §8.7 |
| `vitest`, `@testing-library/react` | unit and component tests | §8.10 |
| `@playwright/test` | E2E and visual regression | §8.10 |
| `openapi-typescript` (or equivalent) | generated client | §8.8 |

### 15.4 Backend

**[RECOMMENDED]**

| Package | Purpose |
| --- | --- |
| `@nestjs/core`, `@nestjs/common`, `@nestjs/platform-fastify` | API framework |
| `@nestjs/swagger` | OpenAPI 3.1 generation |
| `fastify` | HTTP server |
| `pg` or `postgres` | driver (choice deferred to first repository) |
| `@node-rs/argon2` or `argon2` | Argon2id hashing |
| `zod` | request validation, shared with the frontend |
| `graphile-worker` or `pg-boss` | PostgreSQL-backed job queue |
| `pino` | structured logging |
| `@sentry/node` | error tracking |
| `vitest`, `testcontainers` | integration tests |

### 15.5 Infrastructure and services

**[DECIDED 7 November 2026]**

| Layer | Provider | Status |
| --- | --- | --- |
| DNS, TLS, edge | Cloudflare | decided (`§16.4 #17`) |
| Web hosting | Cloudflare Pages | decided (`§16.4 #17`) |
| API + worker runtime | Fly.io | decided (`§16.4 #17`) |
| Database | Supabase, managed PostgreSQL only (Position A) | decided (`§16.4 #1`) |
| Object storage | Cloudflare R2 | decided (§9.12) |
| CI/CD | GitHub Actions | decided (`§16.4 #25`) |
| Payments | VFD, with NIBSS name enquiry | decided (§9.10) |
| SMS | Termii | decided (§9.7) |
| Error tracking | Sentry | recommended |
| Logs / metrics / traces | OpenTelemetry → Grafana Cloud, or equivalent | recommended |

### 15.6 Dependency rules

**[DECIDED]**

1. One package manager, one lockfile. No npm/yarn mix.
2. Exact versions for runtime dependencies; ranges only for dev tooling.
3. A dependency that duplicates an existing one is rejected.
4. A dependency that ships its own design system is rejected (§2.4).
5. A dependency that cannot be removed without a rewrite is a commitment, not a convenience — record
   it in §16.
6. No dependency in the client that can be computed on the server.

---

## 16. Architectural Decisions and Changelog

### 16.1 Decision register

**[DECIDED]**

| # | Decision | Status |
| --- | --- | --- |
| 1 | Modular monolith, not microservices | Decided |
| 2 | React 18 + Vite 6 + TypeScript + Tailwind 4 frontend | Decided |
| 3 | NestJS + Fastify API in TypeScript | Decided |
| 4 | PostgreSQL 16, schema per module | Decided |
| 5 | Double-entry append-only ledger | Decided |
| 6 | Capability-based authorisation derived from activities + grants | Decided |
| 7 | REST + OpenAPI, generated client | Decided |
| 8 | Cloudflare R2, private-first object storage | Decided |
| 9 | PostgreSQL-backed job queue at MVP | Decided |
| 10 | Managed PaaS + managed Postgres | Decided — Cloudflare Pages/Fly.io + Supabase (`§16.4 #1`, #17) |
| 11 | Visual regression gate on frontend extraction | Decided |
| 12 | One account, six activities, no per-activity database or auth | Decided |
| 13 | Four applications, eight deployments: `web`, `control`, `staff`, `partner` in production and staging | Decided (7 Nov 2026) |
| 14 | RLS as defence in depth; service layer is authoritative | Decided |
| 15 | Supabase as managed Postgres only (Position A) | Decided (7 Nov 2026) |
| 16 | Staging is an integrated ecosystem of all four applications | Decided (7 Nov 2026) |
| 17 | Lockstep releases with one manifest per commit | Decided (7 Nov 2026) |
| 18 | Founder approval by GitHub Issue comment, promoting the staging artifacts | Decided (7 Nov 2026) |
| 19 | Staged retirement of the legacy Flutter deployments | Decided (7 Nov 2026) |
| 20 | One administrative governance domain with separate control/staff/partner shells; `admin` owns roles, staff, departments, partners, cases, evidence, approvals and configuration | Decided (11 Nov 2026) — see §7.7 |

### 16.2 Decisions added by this revision

**[DECIDED]** by founder instruction, 7 November 2026:

1. **Eight deployments** — four applications, each in production and staging, with the hosts in
   §4.1.
2. **Integrated staging ecosystem** — all four staging applications share the staging API, identity,
   and database, and are tested together.
3. **Lockstep releases** — one commit, one manifest, all four applications plus API, worker, and
   migrations (§12.9).
4. **Issue-based founder approval** — a GitHub Issue and `/approve-release <sha>` comment, verified
   by the approval workflow (§12.5).
5. **Build-once promotion** — production consumes the staging artifacts; it never rebuilds (§12.7).
6. **Staged Flutter cutover** — the legacy Flutter deployments are retired only after the React
   replacement is deployed and verified (§12.10).
7. **Migration review before production execution** — §12.4.
8. **Future expansion must not be over-built** — §13.1 and §13.5.

Decisions retained from 3 November 2026: control scope (founder + authorised developer),
staff job-specific permissions, partner scope, staging/production separation, per-release founder
approval, and the six-activity model.

### 16.3 Recommendations that need sign-off

**[RECOMMENDED]** — if this revision is accepted, these are accepted with it. Each is reversible
without redesign.

| # | Recommendation | Section |
| --- | --- | --- |
| 1 | Four application bundles sharing one design system | §8.12 |
| 2 | Host-only session cookies with four audiences and environment binding | §5.4, §10.3 |
| 3 | Partner identity as a membership on the one identity service | §4.6 |
| 4 | `platform.engineering` as a distinct, time-boxed developer grant | §4.4 |
| 5 | Staff capabilities in `support.*` / `operations.*` / `marketing.*` namespaces | §7.3 |
| 6 | `feature → staging → main` branching with protected `staging` and `main` | §12.1 |
| 7 | Build once, promote the same release manifest and artifact digests | §12.7 |
| 8 | `staging` and `production` as GitHub Environments, with the issue-comment founder gate | §12.3, §12.5 |
| 9 | Geo as a platform capability, not per-module | §9.14 |
| 10 | Production photography served from R2 instead of hotlinked Unsplash | §8.4 |
| 11 | Adopt `react-router`, `react-hook-form`, TanStack Query, `zod`; add the test toolchain | §8.7, §8.10, §15.3 |
| 12 | The repository layout in §14.1 | §14 |
| 13 | `minimumReleaseAge` retained as a supply-chain control | §2.5 |
| 14 | No public API host: each of the eight hosts serves `/api/*` same-origin from the edge | §4.9 |
| 15 | Apex canonical with `www` → apex 301; no `www.` on privileged/staging hosts; no wildcard DNS; HSTS without `preload` | §4.9 |
| 16 | Cloudflare Access on the control and staff hosts, in both environments | §4.4, §4.5, §10.12 |
| 17 | Cross-application E2E suite as a blocking staging gate | §11.7 |
| 18 | A release manifest stored with the artifacts and referenced by the release issue | §12.7 |

### 16.4 Open founder decisions

**[OPEN]** - nothing here may be implemented as though it were decided, except where a row is
explicitly marked **DECIDED**. This register consolidates the matrix §18 and the database rules §13
so there is one list, not three.

| # | Decision | Blocks | Owner | Source |
| --- | --- | --- | --- | --- |
| 1 | **Managed Postgres provider** — **DECIDED 7 November 2026:** Supabase, managed Postgres only (Position A). The Data API, Supabase Auth and Supabase Storage are not used; identity is built in the NestJS API and storage is Cloudflare R2 (§9.12). | §4–§8 applicability of the database rules; hosting | Founder + architect | db rules #1; EP-01 entry record §5 |
| 2 | **Funds custody** — licensed provider holds funds, or Hivorr pursues a licence | Wallet design; legal structure; launch timeline | Founder + counsel | §9.10 |
| 3 | **MVP activity scope** — all six at launch, or Explore-first | Which modules ship first | Founder | matrix #3 |
| 4 | **Deactivation with open obligations** — blocked, or allowed | Activity state machine | Founder | matrix #4 |
| 5 | **Business as account or profile** | `identity.account` cardinality; team features | Founder | matrix #5 |
| 6 | **KYC tier ladder and limits** | Financial gating; `finance` constraints | Founder | matrix #6 |
| 7 | **Retention periods** — identity, KYC, chat, disputes | Deletion design; no purge may be built | Founder + counsel | matrix #7 |
| 8 | **Currency model** — single currency or multi-currency ledger | `finance` schema; wallet presentation | Founder | db rules #9 |
| 9 | **Switcher form** — hub screen, sidebar section, or account menu | §5.3, §8.6 | Founder | matrix #9 |
| 10 | **Role language** — keep "Client"/"Professional" as dashboard names, or replace them | UI copy; the prototype uses them | Founder | matrix #10 |
| 11 | **Platform fee, escrow holding period, dispute rules** | Escrow lifecycle; ledger design | Founder | matrix #13, §9.10 |
| 12 | **`discover`** - **DECIDED 3 November 2026:** a capability inside Hire, not an activity (§16.5 #3). Kept in the register so cross-references stay valid. | Nothing - settled | Founder | matrix #1 |
| 13 | **Backup tier** — PITR retention and dump destination | Production readiness | Founder + architect | db rules #13 |
| 14 | **Sign-in identifier** — **DECIDED 7 November 2026:** email-first. Email and password are required at registration; a phone number is optional and becomes mandatory only before an action that sends an OTP or a dispatch message | Auth screens; identity schema | Founder | §9.7; EP-01 entry record §5 |
| 15 | **Verification vendor** — review queue only, or an identity provider | Lane implementation | Founder | matrix #12 |
| 16 | **Data residency and primary region** | Provider and region; latency; compliance | Founder | db rules #10 |
| 17 | **Hosting platform, DNS provider, TLS issuance** — **DECIDED 7 November 2026:** Cloudflare for DNS, TLS and the edge (Pages for the static bundles), and Fly.io for the API and worker runtime. All eight hostnames sit behind the Cloudflare edge; `/api/*` is proxied same-origin from the edge to the Fly.io origin. TLS is provider-managed at the edge; HSTS without `preload`. The three privileged staging hosts are flattened to first-level names (§16.4 #26). | §4.8, §4.9 | Founder + architect | new; EP-01 entry record §5 |
| 18 | **Map / geo provider** | Errand and logistics dispatch | Founder | §9.14 |
| 19 | **Mobile** — PWA first, or React Native | §19 (removed — see changelog) | Founder | old #8 |
| 20 | **AI scope** — out of launch scope, or a specific surface | Any AI module | Founder | old #9 |
| 21 | **Admin access path** — how Admin and Super Admin are granted; is the prototype entry point removed in all builds | §7.2 | Founder | matrix #11 |
| 22 | **Team size and ops capacity** | How much managed infrastructure to buy | Founder | old #11 |
| 23 | **Self-dealing exceptions** | §6.7 | Founder | matrix #14 |
| 24 | **Grandfathering** — grace period if a verification rule tightens | Rollout policy | Founder | matrix #13 |
| 25 | **CI provider and repository hosting** — **DECIDED 4 November 2026:** GitHub and GitHub Actions; private repository; protected `main`; native secret and dependency scanning; `staging`/`production` as definitions only; no deployment in EP-00. Kept in the register so cross-references stay valid. | Nothing — settled | Founder | `standards` §16 #18; EP-00-000 |
| 26 | **TLS for the three privileged staging hosts** — **RESOLVED 8 November 2026:** the hosts are flattened to `control-staging.hivorr.com`, `staff-staging.hivorr.com`, and `partner-staging.hivorr.com`. They are first-level names covered by Cloudflare's Universal SSL `*.hivorr.com` wildcard. No Advanced Certificate Manager subscription is required. | Nothing — settled | Founder | Revision 3 §4.8; 8 November 2026 amendment |
| 27 | **GitHub enforcement tier** — remain on GitHub Free with the compensating controls in §12.3, or upgrade to Pro/Team for server-side branch protection and environment required reviewers. | Strength of the production approval guarantee; §12.3 | Founder | Revision 3 §12.3 |

**Resolved by this revision and therefore removed from the list:** the errand-vs-logistics question.
The founder's instruction defines six activities, with "Send an Errand" and "I Want to Provide
Logistics" as separate activities (§6.1). The matrix §18 #2 and §19 #2 should be updated to record
that; this revision does not edit the matrix.

### 16.5 Conflicts discovered

**[DECIDED]** — recorded, not silently resolved.

| # | Conflict | Detail | Resolution in this revision |
| --- | --- | --- | --- |
| 1 | **Supabase vs "provider open"** | Revision 2 left the managed provider open and treated Supabase as conditional. | Resolved 7 November 2026: Supabase is the managed PostgreSQL provider, used under Position A only. The Data API, Supabase Auth, and Supabase Storage are not used. |
| 2 | **Errand as an activity** | The matrix marks errand-vs-logistics open; `VISION.md` §6 marks errand `[OPEN]`; `AGENTS.md` Rule 6 omits it. | The founder's instruction for this revision settles it: six activities, errand and logistics separate. Matrix §18 #2 and §19 #2 record the settlement as of 3 November 2026. |
| 3 | **`discover`** | `VISION.md` §3 listed it as an approved Explore activity; the prototype offers errand; `AGENTS.md` Rule 6 said "buy, hire, discover". | Settled 3 November 2026: `errand` is the third Explore activity and `discover` is the browse step inside Hire, which the prototype already implements as `emp-discover` and `pro-discover`. `VISION.md`, `AGENTS.md` and the matrix were corrected to match. |
| 4 | **Developer as an actor** | No approved document defines a developer role. The matrix's admin scopes are verification, payment, dispute, account, configuration, audit. | This revision adds `platform.engineering` as a **separate, non-admin grant** (§4.4, §16.3 #4). It does not widen any existing admin scope. |
| 5 | **Staff as an actor** | The matrix has no staff model; it has admin scopes only. | This revision adds job-scoped staff grants in their own namespaces (§7.3, §16.3 #5) and states that staff never default to admin. |
| 6 | **`zod` "already a dependency"** | The previous revision said forms use `react-hook-form` + `zod` as existing dependencies. `zod` is not in `package.json`. | Corrected: `react-hook-form` is installed and unused; `zod` must be added (§8.7, §15.3). |
| 7 | **Testing stack presented as settled** | The previous revision listed Vitest, Testcontainers, Playwright, and OpenAPI diff as approved strategy without noting that none is installed. | Corrected: strategy approved, tooling absent (§8.10). |
| 8 | **"Four distinct concepts" above a five-row table** | §8.1 of the previous revision. | Corrected to five (§5.1). |
| 9 | **Missing Errand requester role** | The previous revision's derived-role table omitted it, though the matrix §9.2 includes it. | Corrected (§9.8). |
| 10 | **Inline style count** | The previous revision said "~1,882 inline style objects"; the measured value is 1,065. | Corrected (§8.2). |
| 11 | **Two component systems** | The repository contains a 50-file shadcn kit that nothing imports, plus the prototype's own primitives. | Recorded and ruled on (§2.4, §8.3): the prototype's primitives are the design system; the kit is dormant. |
| 12 | **Unsplash hotlinks** | The prototype references remote Unsplash URLs for all photography. | Recorded (§8.4): licensed for the prototype, not for production hotlinking. |
| 13 | **`index.html` declares `light dark`** | `<meta name="color-scheme" content="light dark">` contradicts `theme.css`'s `color-scheme: light` and the no-dark-mode rule. | Recorded. **Not changed** — the prototype must not be modified by a documentation task. Flagged for the implementation phase. |
| 14 | **Activities hub is unreachable** | `ActivitiesHub` exists but no route reaches it; `VISION.md` §8 records this. | Recorded as an MVP requirement, not a new feature (§5.3). |
| 15 | **Architecture modelled five entry points** | Revision 2 defined `hivorr.com`, `staging.hivorr.com`, `control.`, `staff.`, `partner.` and four bundles as "five deployments". That is inconsistent with four applications in two environments. | Corrected in revision 3: four applications, eight deployments (§4.1, §8.12). The EP-01 entry record's four-bundles/five-deployments ruling is superseded by an amendment. |
| 16 | **Live hosts serve legacy Flutter** | Verified 7 November 2026: `hivorr.com` and `staging.hivorr.com` served the legacy Flutter build. The founder approved immediate detach; the CNAME records and Pages custom domains were removed and both Flutter Pages projects were deleted. | Both hostnames are unavailable; React is not deployed. No Flutter rollback target remains. |
| 17 | **VFD vs Paystack/Flutterwave** | §3.1 recorded VFD as the single provider, while §9.10 and §15.5 still said Paystack primary and Flutterwave secondary. | Corrected in revision 3: VFD is the single payment/custody provider throughout. |
| 18 | **TLS for second-level staging hosts** | The original `*.staging.hivorr.com` names were not covered by standard Cloudflare Universal SSL. | **Resolved 8 November 2026** by flattening the three privileged staging hosts to first-level names. No ACM subscription is required (§16.4 #26). |

### 16.6 Changelog

#### 11 November 2026 — administrative governance domain

**Decided by founder approval**

- The Control Portal is one governance architecture with two operational shells: `control` for
  privileged governance, `staff` for job-scoped operations, and `partner` for external
  organisations. They share the `admin` governance domain, authorization engine, audit trail and
  design system.
- `admin` owns roles, permissions, assignments, staff, departments, partner organisations, cases,
  evidence, approvals, configuration and reporting read models.
- The authoritative governance definition is
  `documents/Context/Administrative-Governance-Architecture.md`.
- The cross-phase Control Portal workstream is recorded in
  `documents/Engineering-Execution/Control-Portal/`.

**Not changed**

- No portal was merged. No session audience changed. No `[OPEN]` financial, verification, retention
  or legal decision was settled. No production deployment or infrastructure change was made.

### 8 November 2026 — flattened staging hostnames

**Decided by founder instruction**

- The three privileged staging hosts become `control-staging.hivorr.com`,
  `staff-staging.hivorr.com`, and `partner-staging.hivorr.com`.
- The second-level `*.staging.hivorr.com` scheme is superseded.
- §16.4 #26 is resolved. Cloudflare Universal SSL covers the flattened names; no Advanced
  Certificate Manager subscription is required.
- No DNS, certificate, hosting, database, or credential change was made by this amendment.

#### 7 November 2026 — revision 3: four portals, two environments

**Decided by founder instruction**

- Hivorr is one ecosystem with four functional portals: main, control, staff, and partner.
- Each portal exists in staging and production: eight deployments in total.
- The partner portal host is `partner.hivorr.com` in production and
  `partner-staging.hivorr.com` in staging. The earlier `partners.` spelling is superseded.
- Releases are lockstep: one commit, one manifest, all four applications plus API, worker, and
  migrations.
- Production is promoted from the staging artifacts after an explicit founder approval comment on a
  release issue.
- The legacy Flutter deployments are retired by a staged, reversible cutover.

**Added**

- §4.0 one ecosystem, four portals, with responsibilities and shared versus portal-specific services.
- §4.1 the eight deployments and the `partner` hostnames.
- §11.7 staging verification gate and §11.8 cross-portal workflows.
- §12.5 issue-based founder approval, §12.9 coordinated releases, §12.10 legacy Flutter cutover.
- §16.4 #26 staging TLS coverage and #27 GitHub enforcement tier.
- §16.5 #15–#18: five-versus-eight topology, live Flutter, VFD consistency, second-level TLS.

**Corrected**

- Revision 2's “five entry points” and “four bundles, five deployments” are replaced by four
  applications, eight deployments.
- Session records now carry an environment/issuer binding in addition to the four audiences.
- §9.10 and §15.5 no longer name Paystack or Flutterwave; VFD is the single payment/custody provider.
- §11.2 isolation now names separate database projects, signing keys, buckets, queues, and provider
  accounts, and blocks staging egress to production.
- §12.1 branching now matches the repository: `feature → staging → main`.

**Verified, not changed**

- `hivorr.com` and `staging.hivorr.com` served the legacy Flutter application until the web CNAME
  records and Pages custom domains were removed on 7 November 2026. Both hostnames are now
  unavailable.
- No DNS, certificate, Cloudflare, Fly.io, Supabase, or credential change was made by this revision.
- `control.`, `staff.`, `partner.`, and their staging hosts have no DNS record yet.

#### 7 November 2026 — EP-01 entry decisions folded in

**Recorded** — the separate fold-in act required by `R-P5` and `EP-01-ENTRY-RECORD.md` §10.4.

- §16.4 #1 decided: **Supabase**, managed Postgres only (Position A); Data API, Auth and Storage not used.
- §16.4 #17 decided: **Cloudflare** for DNS, TLS and the edge (Pages), **Fly.io** for the API and worker; `/api/*` proxied same-origin at the edge.
- §16.4 #14 decided: **email-first** sign-in; phone optional until a phone-dependent action. §9.7 updated to match.
- No other row changed. No rule changed meaning. The remaining **[OPEN]** rows are untouched.

#### 4 November 2026 — CI provider and repository hosting decided

**Recorded**

- §16.4 #25: the founder decided repository hosting and CI — GitHub and GitHub Actions, private repository, protected `main`, native secret and dependency scanning, `staging`/`production` as definitions only, and no deployment in EP-00. The row is marked **DECIDED** and kept for cross-reference.
- `standards` §16 #18 is marked decided and points here. No other **[OPEN]** row changed.

#### 3 November 2026 — revision 2

**Process note**

- This revision was applied **in place**, as instructed. The 1 November 2026 revision was overwritten
  and no separate copy of it exists. The pre-1-November Flutter-era document is the only older
  version preserved, at `C:\Users\user\Downloads\ARCHITECTURE.md`, and is summarised in Appendix A.
  If the 1 November text is needed for comparison later, it must be reconstructed from the summary
  in §16.6 and Appendix A — it cannot be retrieved from disk.

**Added**

- §1.4 trust tiers; §3.2 entry-point capability matrix; §3.3 non-negotiable boundaries.
- §4 domain and subdomain architecture: `hivorr.com`, `staging.`, `control.`, `staff.`, `partner.`,
  with access rules, developer restrictions, and staff/partner boundaries.
- §4.9 API host and canonical hostnames: same-origin `/api` at the edge instead of a public
  `api.hivorr.com`, apex canonical with a `www` redirect, no wildcard DNS, HSTS without `preload`.
- §5.4 session audiences and the host-only cookie rule.
- §7 the three privileged surfaces, the permission ladder, and the anti-drift rules.
- §8.12 five application bundles, with the cost stated.
- §8.2 measured prototype figures; §8.3 three-tier component organisation and the full primitive list.
- §9.2 staff scopes, partner programme records, and geo as explicit module responsibilities.
- §10.3 centralised identity with isolated sessions; §10.8 MFA matrix; §10.12 why subdomain
  separation is not a security control.
- §11.2–§11.4 data isolation, what staging must mirror, what staging must not have.
- §12 branching, pipeline stages, environment protection, migration gate, per-release approval,
  rollback, artifact provenance, prohibited actions.
- §13 three expansion tiers, five extension seams, the activity-versus-vertical test, and what
  "architecturally ready" does not mean.
- §14 repository layout, root-package constraint, directory responsibilities, naming rules, and what
  not to create.
- §15 dependency inventory split into in-use, dormant, to-be-added, backend, and infrastructure.
- §16.3 recommendations, §16.4 consolidated open decisions, §16.5 conflicts.

**Corrected**

- §5.1 "four concepts" → five.
- §9.8 derived roles now include the Errand requester.
- §8.2 inline style count corrected from ~1,882 to the measured 1,065.
- §8.7 `zod` is not installed; it must be added.
- §8.10 the test toolchain is not installed; the strategy is approved, the tooling is not.
- §2.4 two component systems in the repository are now ruled on explicitly.

**Restructured**

- 20 sections + 3 appendices → 16 sections + 1 appendix, matching the required document shape.
- Supabase mechanics removed from this document and pointed at
  `Database-Migration-and-Supabase-Data-API-Rules.md`.
- The three separate open-question lists (this document, the matrix, the database rules) consolidated
  into §16.4 with source references.

**Retained unchanged in substance**

- Modular monolith, NestJS + Fastify, schema per module, double-entry ledger, capability-based
  authorisation, REST + OpenAPI, R2, PostgreSQL queue, visual regression gate, three-layer
  enforcement, financial guardrails, messaging and notifications design, observability, scalability.
- Every frontend constraint: prototype is the visual authority, incremental extraction, no visual
  drift, closed palette, fixed breakpoints, no second palette.

**Removed**

- §19 "Future Mobile Integration" as a numbered section. Mobile is now a decision (§16.4 #19) and a
  revisit trigger (§13.6), not an architecture section — the previous text was entirely deferred work.
- Appendix B "Gaps in the previous document", which described the superseded Flutter-era document and
  no longer helps anyone.
- Appendix C, replaced by §16.4.

---

## 17. Implementation Roadmap

**[DECIDED]** Stages are ordered by dependency. No stage starts before its predecessor's exit evidence
exists. Only stages marked "external" touch DNS, hosting, databases, or credentials, and each of
those requires explicit founder approval.

| Stage | Work | Depends on | External change | Exit evidence |
| --- | --- | --- | --- | --- |
| **0** | Hostname and scope decisions recorded | — | No | This revision; `partner` confirmed |
| **1** | Documentation rework: architecture, standards, EP-01 amendment, cutover runbook | Stage 0 | No | Updated documents; no external change |
| **2** | Monorepo foundation: `apps/control`, `apps/staff`, `apps/partner`, `server/`, `packages/`; four bundle entries | Stage 1 | No | All bundles build; Figma preview intact |
| **3** | API, worker, identity, capability engine, audit, database foundation, migrations | Stage 2 | No | Local gates; allow/deny tests; migration reset |
| **4** | CI and release pipeline: all-bundle build, release manifest, digests, staging gate | Stage 3 | No | Seeded failing gates; manifest artifact |
| **5** | Staging ecosystem: four hosts, API, worker, staging Supabase, R2, secrets, Access | Stage 4 | **Yes** | All four staging hosts serve; headers; isolation |
| **6** | Cross-portal E2E, smoke, visual regression, staging verification record | Stage 5 | Yes | §11.7 and §11.8 evidence |
| **7** | Release governance: issue creation, founder comment approval, artifact promotion, rollback | Stage 4, 6 | GitHub configuration | Approval workflow tested; rollback drill |
| **8** | Production ecosystem: four hosts, API, worker, separate Supabase, R2, secrets, Access | Stage 6, 7 | **Yes** | Production smoke; isolation proof |
| **9** | Legacy Flutter cutover with rollback window | Stage 8 | **Yes** | `LEGACY_FLUTTER_CUTOVER.md` evidence |
| **10** | First production release through the approved gate | Stage 9 | **Yes** | Release issue, approval, deployment record |

**Current position (7 November 2026):** Stage 0 is complete for the portal/hostname decision;
Stage 1 is complete; Stage 2 is complete; Stage 3 has started with the API bootstrap, configuration
contract, health endpoints, capability engine, database baseline (module schemas, platform tables,
identity spine, UUIDv7, roles, grants, append-only audit), RLS policies and transaction-scoped
identity context, and their tests. Identity now uses a short-lived opaque access token plus a rotating
refresh token bound to one portal and one environment; the refresh chain detects reuse and revokes the
session, privileged portals require a confirmed TOTP factor and exchange a short-lived, single-use
challenge for a session, recovery codes are single-use, TOTP secrets are encrypted at the application
layer, and sessions can be listed and revoked. Grant management now exists for the control portal:
`admin`, `staff`, `partner`, and `platform_engineering` grants are listed, created, and revoked by
callers holding an active `admin.grant.manage` grant in the same environment. Every function
re-verifies the actor inside the database, grants are filtered by environment, the last active
grant-manager cannot be revoked, and each API change is audited. The first grant is bootstrapped
out of band, never by a migration. The privileged grant surface is not built yet. The transaction
outbox now has a worker: lease-based claiming with `for update skip locked`, at-least-once delivery,
deterministic exponential backoff, dead-lettering, and queue-health endpoints. No production event
handlers are registered yet, so real event types dead-letter until a handler exists. The release
pipeline now builds once, records a manifest of the four bundle digests, the backend source, and the
migration set, and promotes the staging artifact to production without rebuilding. Production
requires a founder `/approve-release <sha>` comment on a `release-candidate` Issue and re-verifies
every digest after download. No hosted environment exists, so rollout remains unconfigured. Stages
4–10 are not started. Provider adapters, portal screens, and a working staging/production deployment
are not built. The live main and staging hostnames were detached from the legacy Flutter origin on
7 November 2026 and are currently unavailable; the React production deployment does not exist yet.

---

## Appendix A — Previous architecture: what happened to each part

| Previous element | Verdict | Reason |
| --- | --- | --- |
| ENV-001 … ENV-010 | **Retain** | Sound; now expressed as §11 and §12 |
| Deterministic core vs AI assistance | **Retain** | Matches `AGENTS.md` Rule 1 |
| Payment gateway abstraction | **Retain** | Correct; prevents provider lock-in |
| Unified account rule | **Retain** | Matches the approved vision |
| Dual taxonomy (profession + product) | **Retain with modification** | Registry is database-driven and admin-configurable, not a client lookup |
| Database-first zero-trust | **Retain with modification** | Rules move to the service layer; RLS becomes defence in depth |
| Flutter `lib/` directory schema | **Replace** | Wrong stack; replaced by §14.1 |
| `android/`, `ios/`, `linux/`, `macos/`, `windows/` | **Replace** | No native shells at MVP |
| `engine/` inside the client | **Redesign** | Ranking, matching, and dispatch are server-side; client copies would violate Rule 4 |
| `ai/` agents in the client | **Redesign** | Deferred and server-side when introduced |
| `core/sync` offline engine | **Defer** | Not applicable to an online-first web MVP |
| Dynamic module delivery (15–20 MB installer) | **Redesign** | Becomes route-level code splitting |
| `workspace/` blueprints and registries | **Retain with modification** | Concept survives as server-side configuration and taxonomy data |
| `shared/` widget design system | **Retain with modification** | Becomes `packages/design` over `theme.css` |
| `data/` repositories and datasources | **Retain with modification** | Pattern survives as TanStack Query + typed API client |
| Admin as a separate privileged shell | **Retain** | Matches the vision and the prototype; extended to `control.` and `staff.` |
| Reference to `Unified-Account-and-Activity-Permission-Matrix.md` | **Retain** | The document exists at `documents/Context/`, approved 1 November 2026 |
| Reference to `AGENT.md` Rules 2/3 | **Replace** | Superseded by `documents/Context/AGENTS.md` Rules 2/3 |
