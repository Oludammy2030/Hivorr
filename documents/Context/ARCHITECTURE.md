# ARCHITECTURE.md — Hivorr Technical Architecture

> **STATUS: REVISED — 3 November 2026 (revision 2).**
> This revision replaces the 1 November 2026 revision **in place**. That revision was not archived
> separately and no copy of it is retained; its substance is carried forward in §16.6 and Appendix A,
> which record what was retained, corrected, restructured, and removed. The pre-1-November original
> (the Flutter-era document, 178 lines) is preserved unchanged at
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

**[DECIDED]** Hivorr is **one product with five application entry points and one backend**: a
modular-monolith TypeScript API, one worker process, and one PostgreSQL database per environment.
The main product — all six user activities — lives at `hivorr.com`. Three narrow, separately
deployed surfaces sit beside it (`control`, `staff`, `partners`), and staging sits at
`staging.hivorr.com`. All five are clients of the same API and the same identity service. None of
them is a second backend, a second database, or a second user population.

```
        hivorr.com            control.*        staff.*         partners.*
        (6 activities)        (governance)     (operations)    (affiliates)
              │                   │               │               │
              └───────────────────┴───────┬───────┴───────────────┘
                                          │ HTTPS / JSON (OpenAPI)
                              ┌───────────▼────────────┐
                              │  API (NestJS + Fastify)│  stateless, one deployable
                              │  modules · service     │
                              │  layer · capability    │
                              │  checks · transactions │
                              └──┬────────┬────────┬───┘
                                 │        │        │
                    ┌────────────▼──┐ ┌───▼────┐ ┌─▼──────────────────┐
                    │ PostgreSQL    │ │ Worker │ │ Object storage     │
                    │ (system of    │ │ jobs,  │ │ Cloudflare R2      │
                    │  record)      │ │hooks   │ │ public + private   │
                    └───────────────┘ └───┬────┘ └────────────────────┘
                                          │
                    ┌─────────────────────▼──────────────────────────┐
                    │ External: Paystack · Flutterwave · Termii SMS   │
                    │ · transactional email · maps/geo (later)        │
                    └────────────────────────────────────────────────┘
```

The frontend is a React single-page application in the prototype's stack (§2.1, §8). It is built as
**one shared component library and one shared design system, consumed by five separate application
bundles** (§8.12). The bundles are separate so that `control` code can never ship to `partners`, and
`partners` code can never ship to `hivorr.com`.

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

### 1.4 The three trust tiers

The five entry points are not equivalent, and the architecture says so explicitly rather than
relying on a subdomain to imply it.

| Tier | Entry points | Who | Trust |
| --- | --- | --- | --- |
| **Public product** | `hivorr.com` | Any registered account | Standard session; all six activities; never admin |
| **Internal operations** | `staff.hivorr.com` | Appointed Hivorr staff | Standard session + staff grant + MFA; job-scoped |
| **Privileged governance** | `control.hivorr.com` | Founder, authorised developer | Strictest session + mandatory MFA; narrow scopes |
| **External partnership** | `partners.hivorr.com` | Approved affiliates and partners | Partner session; no activity capabilities, no wallet |
| **Non-production** | `staging.hivorr.com` | Authorised testers | Isolated credentials; never reaches production data |

Subdomain separation is an **organisational and deployment** boundary. It is not, by itself, a
security control (§10.12).

### 1.5 How to read the rest of this document

§2 fixes the technology. §3 draws the system boundaries. §4 defines the entry points. §5–§7 define
the account, the six activities, and the three privileged surfaces. §8–§9 define the frontend and
the backend. §10 defines security. §11–§12 define environments and release governance. §13 defines
how the system grows. §14–§15 define the repository and its dependencies. §16 records every decision,
every open question, and every conflict this revision found.

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

**[OPEN]** The **managed provider** is not chosen: Neon, Supabase, or RDS (`§16.4 #1`). If Supabase
is chosen, it is used as managed Postgres only — Data API and GraphQL disabled, Supabase Auth not
used, no Supabase key in any client (database rules §2.4, Position A, adopted 3 November 2026).
Nothing in this document depends on which provider is selected.

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
| 1 | **Web app** (`hivorr.com`) | The six user activities, shared wallet, messaging, profile, activity switcher. | Exists as prototype |
| 2 | **Control app** (`control.hivorr.com`) | Founder governance, developer operations, review queues, configuration, audit. | New — §7.2 |
| 3 | **Staff app** (`staff.hivorr.com`) | Job-scoped operational work: support, verification, operations, marketing. | New — §7.3 |
| 4 | **Partner app** (`partners.hivorr.com`) | Affiliate and partner applications, referral and commission tracking. | New — §7.4 |
| 5 | **API** | Authentication, authorisation, domain logic, financial operations, admin/staff/partner operations. | New |
| 6 | **Worker** | Webhooks, notifications, escrow release, payouts, reconciliation, media scanning, referral accrual. | New |
| 7 | **PostgreSQL** | Single system of record. Module-scoped schemas, ledger, audit log. | New |
| 8 | **Object storage** | Product media, avatars, contracts, KYC documents, proof of delivery. Private by default. | New |
| 9 | **CDN** | Static bundles for all five entry points, public media. | New |
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

| Capability | `hivorr.com` | `staff.*` | `control.*` | `partners.*` |
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

### 3.3 Boundaries that are not negotiable

**[DECIDED]**

1. **One database.** Six activities, three privileged surfaces, and one identity share one database
   per environment. No per-activity database, no per-activity auth system.
2. **One identity service.** Every entry point authenticates against the same identity module. A
   second credential store is forbidden.
3. **One API.** The privileged surfaces are not a second backend. They call the same API with
   different scopes.
4. **No client is trusted.** Every boundary in §3.2 is enforced server-side. The client's route,
   bundle, or subdomain proves nothing.
5. **No cross-module table access.** A module reads only its own schema (§9.2).

---

## 4. Domain and Subdomain Structure

### 4.1 The five entry points

**[DECIDED]** by founder instruction, 3 November 2026.

| Domain | Purpose | Access | Trust tier |
| --- | --- | --- | --- |
| `hivorr.com` | Main Hivorr ecosystem | All six core activities | Public product |
| `staging.hivorr.com` | Staging environment | Authorised testing and review | Non-production |
| `control.hivorr.com` | Administrative platform | Founder and explicitly authorised developer | Privileged governance |
| `staff.hivorr.com` | Internal staff portal | Officially appointed Hivorr staff | Internal operations |
| `partners.hivorr.com` | External partnership portal | Approved affiliates and partners | External partnership |

These are **distinct application entry points, not distinct user identities** (§5). A person may hold
an ordinary Hivorr account and a staff grant at the same time; the grants are separate, and neither
implies the other.

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

### 4.3 `staging.hivorr.com` — staging

**[DECIDED]** The only hosted non-production environment (§11). It runs the same build pipeline as
production, against staging services and a staging database. It is never linked from the production
product and never shares credentials, buckets, keys, or payment accounts with it.

### 4.4 `control.hivorr.com` — the administrative platform

**[DECIDED]** The restricted administrative environment.

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

### 4.5 `staff.hivorr.com` — the staff portal

**[DECIDED]** Reserved for officially appointed Hivorr personnel: marketing, operations, customer
support, verification officers, and other authorised staff.

- **Staff access is controlled through job-specific permissions** (§10.6).
- **A staff member does not automatically receive administrator privileges.** Staff and admin are
  different grants; holding one never implies the other.
- Staff never reach `control.hivorr.com` unless they separately hold a control grant.
- Staff never gain activity capabilities from a staff grant.

### 4.6 `partners.hivorr.com` — the partnership portal

**[DECIDED]** Reserved for external partnership programmes: affiliates, referral programmes,
business partnerships, partnership applications, and commission and referral tracking.

- It **must not become an alternative entry point for the six core activities.** A partner session
  cannot place an order, publish a listing, accept an errand, or touch a wallet.
- A partner sees only its own organisation's applications, referrals, and commission records.
- **[RECOMMENDED]** Partner identity is a **partner membership** on the same identity service, not a
  second account system. An individual who is also an ordinary Hivorr user keeps one account and two
  separate grants.

### 4.7 Rules that apply to all five

**[DECIDED]**

1. **One API, one identity service, one database per environment.** No entry point gets its own
   backend.
2. **Each entry point has its own session audience** (§10.3). A session issued for one entry point is
   rejected by the others.
3. **No entry point is a security boundary by virtue of its hostname.** Authorisation is enforced
   server-side, per request (§10.12).
4. **Cross-origin is explicit.** Each entry point has an exact CORS allowlist entry; no wildcard, no
   `*.hivorr.com`. In the browser path there is no cross-origin call at all — see §4.9 — so the
   allowlist governs the edge-to-origin hop and any future public surface.
5. **`staging.` is not a prefix on production.** Staging has its own credentials and its own session
   audience; a staging session can never be replayed against production.
6. **TLS everywhere, HSTS on every host**, including `control.` and `staff.`.
7. **No directory listing, no `robots` index for privileged hosts.** `control.`, `staff.`, and
   `partners.` are `noindex` and are not linked from the public product.

### 4.8 DNS, TLS and hosting

**[OPEN]** The DNS provider, TLS issuance method, and hosting platform for each entry point are not
chosen. This document defines the required topology, not the vendor. **No DNS, certificate, or
hosting configuration was changed in producing this revision.**

**[RECOMMENDED]** All five hostnames resolve to the same CDN/edge provider, with each app's static
bundle served from its own path prefix or its own project. `staging.` is a separate deployment
target, not a rewrite rule.

### 4.9 API host and canonical hostnames

**[RECOMMENDED]** — the two hostname questions §4.7 leaves implicit. They are recorded here because
both get decided by accident during DNS setup otherwise, and one of them would quietly break §5.4.

**The API does not get a public hostname.** §4.7 #4 requires a CORS allowlist per entry point, which
implies the API is cross-origin — and a cross-origin API on `api.hivorr.com` would force every
session cookie to `SameSite=None` and to be scoped to the API host instead of the app host. That
collapses the isolation §5.4 depends on: the browser would send *every* audience's cookie to
`api.hivorr.com` on *every* request, from any origin, and audience separation would survive only in
the server-side check.

| Rule | Detail |
| --- | --- |
| Browser path | Each entry point serves `/api/*` **same-origin**, rewritten at the edge to the API origin. |
| Origin hostname | The API has an internal origin hostname reachable only from the edge — not resolvable by a browser, not in any bundle. |
| Consequence | No CORS in the browser path at all; §4.7 #4 remains as a defence-in-depth allowlist for the edge hop. |
| Cookies | Stay **host-only on the app host**, `SameSite=Lax`, `__Host-` prefix — exactly §5.4, unchanged. |
| If a public API is ever required | It is a **separate, scoped surface** with its own credentials (§9.9), not this API opened to the internet. |

**Canonical hostnames.**

| Rule | Detail |
| --- | --- |
| Apex canonical | `hivorr.com` is canonical. `www.hivorr.com` issues a single **301 to the apex**, at the edge, before any application logic runs. |
| Privileged hosts | `control.`, `staff.`, `partners.`, and `staging.` are canonical on the bare subdomain. No `www.` variant exists for any of them. |
| One host per environment | An environment is never a path on a production host. `hivorr.com/staging` is forbidden. |
| No wildcard DNS | Each hostname is an explicit record. No `*.hivorr.com`, so a new subdomain cannot appear by accident and no wildcard certificate is needed. |
| Redirects | Only `GET`/`HEAD` are redirected across hosts. A `POST` is never redirected — it would drop the body — and API requests are never redirected. |
| HSTS | `max-age=31536000; includeSubDomains` on every host. **`preload` is a later, deliberate step**: it is effectively irreversible and commits every future subdomain to HTTPS. |
| `robots` | `control.`, `staff.`, `partners.`, and `staging.` serve `Disallow: /` and `noindex` (§4.7 #7). `hivorr.com` is indexable. |

**[OPEN]** Which hostname the edge rewrites `/api` to, and whether the API origin is public at all,
follow from the hosting decision (§16.4 #17) and are not settled here.

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

**[RECOMMENDED]** — this extends the previous revision's session design to five entry points.

| Rule | Detail |
| --- | --- |
| Cookie scope | **Host-only**, `Secure`, `httpOnly`, `SameSite=Lax`, `Path=/`, `__Host-` prefix. No `Domain=.hivorr.com`. |
| Audience | Every session record carries an audience: `app`, `control`, `staff`, `partners`. |
| Validation | The API rejects a session whose audience does not match the endpoint's audience. |
| Rotation | Short-lived access token (10–15 min) plus a rotating refresh token; reuse detection revokes the family. |
| Devices | One server-side session record per device, revocable, with a "signed-in devices" screen in the main app. |
| Bearer | Bearer-token support is designed in from the start for a future mobile client. |

**Why host-only and not a shared parent-domain cookie.** A shared `.hivorr.com` cookie means an XSS
or a compromised dependency on `partners.` — the lowest-trust, externally facing surface — yields a
valid main-product session. Host-only cookies cost one extra sign-in on the privileged hosts, which
is desirable there anyway because they require MFA. The trade is deliberate.

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

**[DECIDED]** `control`, `staff`, and `partners` are **not** activities, not dashboards, and not
account types. They are separate applications that call the same API with different scopes.

The reason they are separate applications rather than routes inside `hivorr.com`:

| Reason | Consequence |
| --- | --- |
| Blast radius | `partners` is externally facing and lower-trust; it must not ship admin code or share a session cookie (§5.4). |
| Bundle size | `control` ships review queues and audit tooling no ordinary user ever downloads. |
| Independent release cadence | A support-portal fix must not require a product release. |
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

### 7.4 Partner platform — `partners.hivorr.com`

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
published as one package consumed by all five apps (§14.3), so `control`, `staff`, and `partners`
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

### 8.12 Five application bundles

**[RECOMMENDED]** — the main frontend decision this revision adds, and the one that needs founder
sign-off.

| App | Host | Ships | Does not ship |
| --- | --- | --- | --- |
| `web` | `hivorr.com` | six activity shells, wallet, messaging, profile, switcher | review queues, audit tooling, engineering tools |
| `control` | `control.hivorr.com` | review queues, configuration, audit, engineering views | product checkout, seller tools |
| `staff` | `staff.hivorr.com` | support, verification, operations, marketing tools | financial configuration, engineering tools |
| `partners` | `partners.hivorr.com` | applications, referrals, commission | any activity capability, any wallet |

All four consume `packages/design`, `packages/shared`, and `packages/api-client`. Each has its own
Vite entry, its own `index.html`, and its own deployment target. They share a repository and a
pipeline, not a bundle.

**Why not one app with host-based routing.** A single bundle means `partners.` downloads admin code
and `control.` downloads checkout code. Host-based routing also makes it easy to reach a privileged
route by mistake, because the route exists in the build. Separate bundles make the privileged
surfaces smaller targets and independent release units.

**Why not micro-frontends.** No runtime composition, no module federation, no remote entry points.
Shared source, separate builds. That is enough.

**Cost, stated honestly.** Four build targets and four deployment configurations are more work than
one. The cost is accepted because `partners` is externally facing and `control` is the highest-value
target in the system.

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
- Provider SDKs (Paystack, Termii, R2) are reached only through adapters in `integrations/`.

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
- **[OPEN]** whether sign-in is email-first, phone-first, or either (`§16.4 #14`).
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
| Audience | Every endpoint declares its audience (`app` · `control` · `staff` · `partners`) |
| Pagination | Cursor-based, stable ordering |
| Errors | Stable machine codes plus a human message; never a bare 500 |
| Money mutations | `Idempotency-Key` required; replay returns the original result |
| Concurrency | `ETag` / `If-Match` on records with competing editors (listings, jobs) |
| Auth | Host-only cookie session per audience; bearer token supported for future mobile |
| Rate limits | Per account, per IP, and per audience; tighter on auth, money, and privileged routes |
| Webhooks (inbound) | Signature-verified, idempotent, stored before processing |
| Realtime | Server-Sent Events for notifications and delivery status; WebSocket for chat when needed |
| GraphQL | Not at MVP |

**Deliberate omission:** no public partner API at MVP. `partners.hivorr.com` is a partner *portal*,
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
- Paystack primary, Flutterwave secondary, both behind one `PaymentProvider` interface. NIBSS name
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

**[DECIDED]** One identity service; four session audiences (§5.4).

| Rule | Reason |
| --- | --- |
| Host-only cookies, no parent-domain cookie | A compromise on `partners.` must not yield a product session |
| Session audience checked on every request | A stolen `app` session must not open `control.` |
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
| `hivorr.com` | Optional at MVP; available to every account |
| `staff.hivorr.com` | **Mandatory** TOTP |
| `control.hivorr.com` | **Mandatory** TOTP; optional IP allowlist for the founder |
| `partners.hivorr.com` | **Mandatory** TOTP for commission payout access |

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

- TLS 1.2+ everywhere; HSTS on all five hosts.
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

A subdomain changes **what is deployed where**, and that is genuinely useful: `partners.` ships no
admin code, and `control.` can be network-restricted. But a hostname is a DNS record, not an
authorisation check. Everything that actually protects the system is server-side:

| Control | Enforced by |
| --- | --- |
| Who may call an endpoint | Session audience + capability check in the service layer |
| Which rows are visible | Ownership/party scope + RLS |
| Which money may move | KYC tier + verification lane + ledger invariants + idempotency |
| Which grant exists | Grant records, audited, revocable |
| What a compromised app can do | The API's scope for that audience — nothing more |

If `control.hivorr.com` were served from `hivorr.com/control` tomorrow, the security posture would be
unchanged. The reverse is also true: a separate hostname would not save a system that trusted it.

### 10.13 Threat model

| Threat | Primary control |
| --- | --- |
| Account takeover | Argon2id, OTP limits, session revocation, MFA on privileged surfaces |
| Horizontal privilege escalation (IDOR) | Capability checks + `owner_account_id` + RLS |
| Cross-activity leakage | Activity-scoped queries; no "all data" endpoints |
| Cross-audience leakage | Session audience + separate bundles + CORS allowlist |
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

### 11.1 The three environments

**[DECIDED]**

| | Development | Staging | Production |
| --- | --- | --- | --- |
| Purpose | Local implementation and testing; controlled source changes | Hosted testing, QA, founder review | Live product |
| Web | `localhost:8443` (Vite) | `staging.hivorr.com` | `hivorr.com` + `control.` `staff.` `partners.` |
| API | local process | staging deployment | production deployment |
| Database | local Postgres container | **staging database only** | **production database only** |
| Storage | local or a dev bucket | staging buckets | production buckets |
| Payments | provider test mode | provider test mode | provider live mode |
| SMS / email | captured, never sent | captured or test recipients | live |
| Data | synthetic seeds | synthetic or anonymised | real |
| Access | the developer | authorised testers + founder | the public, with founder-gated release |

### 11.2 Data isolation rules

**[DECIDED]** — these are not guidelines.

1. **No production data in development or staging**, ever. Not a dump, not a sample, not "just one
   table".
2. **No shared credentials** across environments. Separate database users, separate API keys,
   separate payment accounts, separate buckets, separate signing keys.
3. **No shared secrets file.** Each environment has its own secret store namespace.
4. **Staging never calls a production service.** If a provider cannot be sandboxed, the call is
   intercepted and recorded.
5. **Staging is not publicly linked** and is `noindex`.

### 11.3 What staging must mirror

**[DECIDED]** Staging is only useful if it can catch production failures:

- the same build artifact (§12.7), not a rebuild;
- the same migration set, applied in the same order;
- the same configuration *shape* (every key present, values different);
- the same infrastructure topology (one API, one worker, one database, one bucket set);
- the same feature-flag defaults unless a flag is explicitly under test.

**[RECOMMENDED]** A migration that has not run on staging has not been tested. Production applies
only migrations that staging has already applied successfully.

### 11.4 What staging must not have

**[DECIDED]** Live payment credentials · real customer data · production signing keys · a public
route from the production product · the ability to send real SMS or email to real users · any grant
that exists in production but not in staging's seed.

### 11.5 Production protection

**[DECIDED]**

- Production is reachable only through the release pipeline (§12). No direct deploys, no manual file
  uploads, no console writes to the database.
- The production environment is a **protected deployment environment**: it requires an explicit
  approval by the founder for every deployment (§12.5).
- Production secrets are readable only by the production runtime identity.
- Production database access for humans is break-glass, time-boxed, dual-controlled, and audited.

### 11.6 Local development

**[RECOMMENDED]** One command starts Postgres, the API, the worker, and the Vite dev server. Seed
data covers each activity and each verification state so permission behaviour is testable without
manual setup. The Figma Make preview must keep working throughout (§8.11).

---

## 12. CI/CD and Deployment Governance

### 12.1 Branching model

**[RECOMMENDED]** Trunk-based development with short-lived branches. The reason is governance, not
fashion: a long-lived branch is a release that has not been reviewed, and this project requires every
production change to be reviewed and approved.

| Branch | Purpose | Lifetime |
| --- | --- | --- |
| `main` | Always deployable; protected | permanent |
| `feat/<slug>` | One change | hours to days; squash-merged |
| `fix/<slug>` | One defect | hours to days |
| `release/<date>` | **Not used** — production is a promotion, not a branch | — |

Rules:

- No direct commits to `main`. Pull request required.
- Linear history; squash merge; no merge commits.
- Force-push and branch deletion on `main` are disabled.
- A branch that cannot merge within a few days is split.

### 12.2 Pipeline stages

**[RECOMMENDED]**

```
pull request
  1 install (frozen lockfile)
  2 lint + format check (oxfmt)
  3 typecheck (tsc --noEmit)
  4 unit + component tests
  5 build all app bundles
  6 visual regression against the baseline
  7 OpenAPI diff (breaking change = failure)
  8 dependency + secret scan
  9 migration lint + `db diff` review artefact
        │
        ▼
merge to main
 10 build once → immutable artifact (digest recorded)
 11 deploy artifact to staging
 12 apply migrations to staging
 13 smoke test + E2E on staging
        │
        ▼
production (gated)
 14 founder approval
 15 apply migrations to production (reviewed, expand/contract only)
 16 deploy the same artifact digest
 17 post-deploy smoke test
 18 monitor error rate and queue depth for 30 minutes
```

### 12.3 Environment protection

**[RECOMMENDED]**

| Environment | Trigger | Approval |
| --- | --- | --- |
| Preview (per PR) | automatic | none |
| Staging | merge to `main` | none, but it must be green |
| Production | manual promotion of a staging artifact | **founder, per deployment** |

GitHub Environments with required reviewers is the concrete mechanism. The production environment
has: required reviewer (founder), no self-review, wait timer, and a deployment branch rule that only
accepts the artifact promoted from staging.

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

Concretely:

- The approval is per deployment, attached to a specific artifact digest and a specific migration
  set.
- There is no standing "auto-deploy to production" toggle.
- A previously approved artifact that is re-promoted still requires approval for that promotion.
- Approval is recorded with who, when, what digest, and what changed since the last release.

### 12.6 Rollback and recovery

**[DECIDED]**

- Application rollback is instant: redeploy the previous artifact digest.
- Database changes follow expand/contract, so a rollback never requires a destructive migration.
- A migration that cannot be rolled back forward is not merged.
- Restore drills are quarterly, with a documented RTO (§13.6).
- **[OPEN]** Backup tier, PITR retention length, and logical-dump destination (`§16.4 #13`).

### 12.7 Artifact provenance

**[RECOMMENDED]**

- Build once, promote the same artifact. Staging and production run identical bytes.
- The artifact digest is recorded in the deployment, the audit log, and the release note.
- Dependencies are installed from the frozen lockfile only.
- Builds are reproducible from a tagged commit.

### 12.8 What is prohibited

**[DECIDED]**

- Deploying to production from a laptop.
- Applying a migration by hand to production.
- Editing production configuration outside the pipeline.
- Sharing a production secret with a developer workstation.
- Approving your own production deployment.
- Shipping a release whose migration has not run on staging.

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
| **Provider adapter** | One interface per external service | Payments already need Paystack *and* Flutterwave (§9.10) |
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
│   └── partners/          # partners.hivorr.com
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

**[OPEN]** — provider selection is not part of this revision.

| Layer | Candidate | Status |
| --- | --- | --- |
| Web hosting | Cloudflare Pages, Vercel | open |
| API + worker runtime | Fly.io, Render, Railway | open |
| Database | Neon, Supabase, RDS | **open** (`§16.4 #1`) |
| Object storage | Cloudflare R2 | decided (§9.12) |
| CI/CD | GitHub Actions | recommended (§12) |
| Payments | Paystack, Flutterwave, NIBSS | decided (§9.10) |
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
| 10 | Managed PaaS + managed Postgres | Decided (provider open) |
| 11 | Visual regression gate on frontend extraction | Decided |
| 12 | One account, six activities, no per-activity database or auth | Decided |
| 13 | Five entry points: `hivorr.com`, `staging.`, `control.`, `staff.`, `partners.` | Decided (3 Nov 2026) |
| 14 | RLS as defence in depth; service layer is authoritative | Decided |
| 15 | Supabase, if chosen, is managed Postgres only (Position A) | Decided (3 Nov 2026) |

### 16.2 Decisions added by this revision

**[DECIDED]** by founder instruction, 3 November 2026:

1. **Domain structure** — the five entry points in §4.1, with the access rules in §4.4–§4.7.
2. **Control platform scope** — founder + authorised developer; developer is technical-only and never
   touches money, PII by default, or business decisions.
3. **Staff platform scope** — job-specific permissions; staff never automatically receive admin.
4. **Partner platform scope** — partnerships only; never an entry point for the six activities.
5. **Staging and production separation** — staging at `staging.hivorr.com`, production at
   `hivorr.com`, no shared data or credentials, production protected by founder approval.
6. **Per-release founder approval** — every production release, not a standing authorisation.
7. **Migration review before production execution** — §12.4.
8. **Future expansion must not be over-built** — §13.1 and §13.5.

### 16.3 Recommendations that need sign-off

**[RECOMMENDED]** — if this revision is accepted, these are accepted with it. Each is reversible
without redesign.

| # | Recommendation | Section |
| --- | --- | --- |
| 1 | Four separate frontend bundles sharing one design system | §8.12 |
| 2 | Host-only session cookies with four audiences | §5.4, §10.3 |
| 3 | Partner identity as a membership on the one identity service | §4.6 |
| 4 | `platform.engineering` as a distinct, time-boxed developer grant | §4.4 |
| 5 | Staff capabilities in `support.*` / `operations.*` / `marketing.*` namespaces | §7.3 |
| 6 | Trunk-based branching with protected `main` | §12.1 |
| 7 | Build once, promote the same artifact digest | §12.7 |
| 8 | Production as a protected GitHub Environment with per-deployment founder approval | §12.3 |
| 9 | Geo as a platform capability, not per-module | §9.14 |
| 10 | Production photography served from R2 instead of hotlinked Unsplash | §8.4 |
| 11 | Adopt `react-router`, `react-hook-form`, TanStack Query, `zod`; add the test toolchain | §8.7, §8.10, §15.3 |
| 12 | The repository layout in §14.1 | §14 |
| 13 | `minimumReleaseAge` retained as a supply-chain control | §2.5 |
| 14 | No public API host: each entry point serves `/api/*` same-origin from the edge | §4.9 |
| 15 | Apex canonical with `www` → apex 301; no `www.` on privileged hosts; no wildcard DNS; HSTS without `preload` | §4.9 |

### 16.4 Open founder decisions

**[OPEN]** - nothing here may be implemented as though it were decided, except where a row is
explicitly marked **DECIDED**. This register consolidates the matrix §18 and the database rules §13
so there is one list, not three.

| # | Decision | Blocks | Owner | Source |
| --- | --- | --- | --- | --- |
| 1 | **Managed Postgres provider** — Neon, Supabase, or RDS | §4–§8 applicability of the database rules; hosting | Founder + architect | db rules #1 |
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
| 14 | **Sign-in identifier** — email-first, phone-first, or either | Auth screens; identity schema | Founder | §9.7 |
| 15 | **Verification vendor** — review queue only, or an identity provider | Lane implementation | Founder | matrix #12 |
| 16 | **Data residency and primary region** | Provider and region; latency; compliance | Founder | db rules #10 |
| 17 | **Hosting platform, DNS provider, TLS issuance** | §4.8 | Founder + architect | new |
| 18 | **Map / geo provider** | Errand and logistics dispatch | Founder | §9.14 |
| 19 | **Mobile** — PWA first, or React Native | §19 (removed — see changelog) | Founder | old #8 |
| 20 | **AI scope** — out of launch scope, or a specific surface | Any AI module | Founder | old #9 |
| 21 | **Admin access path** — how Admin and Super Admin are granted; is the prototype entry point removed in all builds | §7.2 | Founder | matrix #11 |
| 22 | **Team size and ops capacity** | How much managed infrastructure to buy | Founder | old #11 |
| 23 | **Self-dealing exceptions** | §6.7 | Founder | matrix #14 |
| 24 | **Grandfathering** — grace period if a verification rule tightens | Rollout policy | Founder | matrix #13 |
| 25 | **CI provider and repository hosting** — **DECIDED 4 November 2026:** GitHub and GitHub Actions; private repository; protected `main`; native secret and dependency scanning; `staging`/`production` as definitions only; no deployment in EP-00. Kept in the register so cross-references stay valid. | Nothing — settled | Founder | `standards` §16 #18; EP-00-000 |

**Resolved by this revision and therefore removed from the list:** the errand-vs-logistics question.
The founder's instruction defines six activities, with "Send an Errand" and "I Want to Provide
Logistics" as separate activities (§6.1). The matrix §18 #2 and §19 #2 should be updated to record
that; this revision does not edit the matrix.

### 16.5 Conflicts discovered

**[DECIDED]** — recorded, not silently resolved.

| # | Conflict | Detail | Resolution in this revision |
| --- | --- | --- | --- |
| 1 | **Supabase vs "provider open"** | The instruction for this revision names "staging Supabase" and "production Supabase". `ARCHITECTURE.md` §2.3 and `database rules` §1.4 leave the managed provider open, and Position A is explicitly conditional ("if Supabase is chosen"). | This revision writes the environment rules provider-agnostically and treats "staging Supabase project" as the concrete form *if* Supabase is selected. The provider stays open (§16.4 #1). **This needs a founder decision.** |
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

### 16.6 Changelog

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
- §4 domain and subdomain architecture: `hivorr.com`, `staging.`, `control.`, `staff.`, `partners.`,
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
