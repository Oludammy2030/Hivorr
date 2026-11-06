# VISION.md — Hivorr Product Vision & Ecosystem Blueprint

> **STATUS: APPROVED — 1 November 2026.**
> This is the consolidated vision for Hivorr. It was prepared from the previous `VISION.md`
> (preserved unchanged at `C:\Users\user\Downloads\VISION.md`) and the frontend prototype in this
> repository, and approved by the founder on 1 November 2026.
>
> It supersedes the previous vision as the reference for product direction. Items marked `[OPEN]`
> remain undecided and are not approved requirements.
>
> **Revised 3 November 2026** - the founder ruled that `discover` is the browse step inside Hire,
> not an activity, and that errand and logistics are two separate activities. §3, §6, §9 D1 and
> §10 Q2/Q3 record the rulings.
>
> **Label key**
> - **[APPROVED]** — carried forward from the existing vision, unchanged in substance.
> - **[PROTOTYPE]** — observed in the prototype; adopted as product direction on approval.
> - **[OPEN]** — not established by either source; requires a founder decision.

---

## 1. Core Identity

**[APPROVED]** **Hivorr**, developed by **AfriNova Digital Limited**, is an **AI-assisted Universal
Business & Daily Lifestyle Operational Infrastructure**. It is intended to become an all-encompassing
operating layer for modern work and daily life — a single digital environment in which a person or
business can run enterprise workflows, professional services, local commerce, and everyday needs.

**[APPROVED]** Hivorr is deliberately built to absorb future innovation: new utilities, services, and
digital capabilities should be addable to the ecosystem without structural reinvention.

**[PROTOTYPE]** The prototype presents Hivorr more narrowly, as *"Africa's Workforce Marketplace"*
(and *"Africa's #1 Workforce Marketplace"*). It is regionally anchored, workforce-led, and
service/commerce oriented.

**[OPEN]** Which positioning is canonical? See §10, Q1.

---

## 2. The Universal Entity Principle

**[APPROVED]** At the heart of Hivorr is the Universal Entity Principle:

- Every account is a fluid, fully capable operational node.
- Users operate without rigid mode toggles, siloed profiles, or app switching.
- A single entity can move between hiring a lawyer, drafting a contract, booking a private chef,
  running a storefront, orchestrating team workflows, and dispatching a delivery rider — inside the
  same unified interface.
- **Capabilities are activities, not account types.**

**[APPROVED]** There are no Client, Professional, or "Both" account types. The "Both" value is
permanently removed. A user registers once, then activates activities.

**[PROTOTYPE]** Registration collects only name, email, phone, and country — no account type. This
matches the approved model. However, the prototype's internal role model still distinguishes
`employer`, `professional`, and `admin`, and surfaces the labels "Client Dashboard" and
"Professional Dashboard". See §9, D3.

---

## 3. The Unified Account Model

**[APPROVED]** One unified account per person or business. After registration, users activate
activities under two umbrellas:

| Umbrella | Activities (approved) |
| --- | --- |
| **Explore with Hivorr** | buy, hire, errand |
| **Earn with Hivorr** | sell, offer services, provide logistics |

**[APPROVED]** Additional activities can be activated later without creating another account.

**[APPROVED]** Admin and Super Admin are privileged platform roles. They are **never** selectable
through registration or activity selection.

**[PROTOTYPE]** The prototype's activity selection screen offers:

- **Explore with Hivorr** — *I Want to Buy*, *I Want to Hire*, *Send an Errand*
- **Earn with Hivorr** — *I Want to Sell*, *I Want to Offer My Services*, *I Want to Provide Logistics*

This confirms **errand** as the third Explore activity. **`discover` is not an activity** — it is the
browse step inside Hire, where a requester browses professionals before posting a job, and a
professional browses open work. The founder settled this on 3 November 2026 (§9 D1, §10 Q2).

**[PROTOTYPE]** The prototype contains an "Activities" hub screen intended to let a user move between
activities, but no route currently reaches it, so switching activities mid-session is not possible in
the prototype. See §8.

---

## 4. The Ecosystem

### 4.1 Professional & Expert Services — two-party direct streams

**[APPROVED]** Instant access to verified domain experts and skilled practitioners: legal drafting,
consulting, artisans, home-service specialists, and similar. Transactions are governed by transparent
contracts and milestone-backed security.

**[PROTOTYPE]** Represented as the **Hire** (client) and **Offer Services** (professional) dashboards:
job posting, discovery of professionals, applications, hiring, messaging, and escrow-based payments.
Contract and milestone artefacts are referenced but not yet represented as screens.

### 4.2 Local Market — three-party operations streams

**[APPROVED]** Complete local store fulfilment, market/grocery sourcing, and restaurant dining
coordination, powered by an expandable product taxonomy:
**vertical → category → subcategory → product type → attributes**.
Sellers choose the classification when listing; published listings appear in the correct marketplace
area and are discoverable through relevant filters. The flow is
**Buyer ↔ Merchant/Vendor ↔ Nearby Delivery Rider**.

**[PROTOTYPE]** Represented as the **Local Market** buyer shell (home, browse, saved, cart, checkout,
orders) and the **Seller** workspace (listing wizard, products, inventory, orders, invoices, sales
analysis, earnings). Taxonomy is currently **two levels only** (category → subcategory), administered
by platform admin. Restaurant dining coordination is not represented.

### 4.3 Errands & Hyper-local Logistics — the physical movement layer

**[APPROVED]** High-speed, geo-radius broadcast dispatch and multi-stop delivery management, anchoring
physical movement across cities. Logistics participation (delivery, pickup, transport) is an **earning
activity** activated on the same unified account.

**[PROTOTYPE]** Split across two dashboards that share one request pool:

- **Errand requester** — create request, review, submit, track (pending match → provider assigned →
  pickup and delivery), history, payments.
- **Logistics provider** — available requests, active assignment with staged progression
  (accepted → heading to pickup → arrived → item collected → in transit → delivered), delivery history,
  earnings, provider eligibility details.

Geo-radius broadcast, map-based dispatch, and multi-stop routing are **not** represented.

### 4.4 Administration — separate privileged environment

**[APPROVED]** Admin and Super Admin operate in a distinct environment for review queues, user
management, moderation, configuration, and audit. Administration is never an Explore/Earn activity.

**[PROTOTYPE]** Represented as an admin environment with two layers:

- **Dashboard Management** — an admin view of each user-facing workspace (buyer, client, errand,
  seller, professional, logistics).
- **Platform Admin** — support and security logs.
- Plus record modules: clients, jobs, hiring, applications, verification, payments, requests,
  monitoring, access, notifications, reports, disputes, support, security.

The prototype reaches admin through a public "Open admin prototype" link on the activity selection
screen — a prototype convenience that conflicts with the approved rule. See §9, D4.

### 4.5 Endless future-proof expandability

**[APPROVED]** The ecosystem is designed to welcome new verticals without structural reinvention.
**[PROTOTYPE]** No mechanism for adding new verticals is represented.

---

## 5. Experience Principles

**[APPROVED]** *Frictionless daily utility*: enterprise-grade capability with consumer-grade
simplicity. Power, speed, and versatility should feel immediate.

**[APPROVED]** Explore, Earn, and Admin share one account, one design system, and one navigation model,
per the visual identity specification.

**[PROTOTYPE]** Observed experience principles:

- **One identity, many dashboards.** The same person appears as a buyer, client, seller, professional,
  errand requester, and logistics provider.
- **Activity-specific shells.** Each activity gets its own navigation set and accent colour:
  Local Market (indigo), Seller (purple), Errand (orange), Logistics/Professional (green).
- **Shared surfaces.** One wallet across activities, one profile with per-activity identities, shared
  messaging, shared dialogs and design tokens.
- **Trust is explicit.** Verification badges, escrow language, provider eligibility, dispute and
  support modules, and clear status wording ("pending", "held", "awaiting acceptance").
- **Honest status language.** The prototype repeatedly states what has *not* happened ("No money was
  moved", "Illustrative prototype order", "Submission does not automatically assign or complete the
  errand"). This restraint should be preserved as a product principle.
- **Responsive by default.** Desktop sidebar, tablet collapse, mobile drawer and bottom navigation.

**[OPEN]** "One navigation model" is not yet demonstrated: the prototype uses four distinct shells.
See §9, D5.

---

## 6. The Activity Model

Six activities, one account. Each activity provides its own dashboard and permissions; not every
activity must share every feature or transaction view.

| Activity | User intent | Dashboard | Core represented workflow |
| --- | --- | --- | --- |
| **Buy** | I want to buy | Local Market | browse → product → cart → checkout → order → track |
| **Hire** | I want to hire | Client | discover professionals → post job → review applications → hire → pay via escrow |
| **Errand** | I want help with a task | Errand requester | create → review → submit → match provider → track |
| **Sell** | I want to sell products | Seller | create listing → publish → manage stock → fulfil orders → invoice → analyse sales |
| **Offer services** | I want to offer my services | Professional | find work → apply → deliver → earn → analyse earnings |
| **Provide logistics** | I want to provide logistics | Logistics provider | browse requests → accept → progress delivery → earn |

**[DECIDED]** "Errand" is an approved Explore activity, separate from logistics. Settled by the
founder on 3 November 2026. See §9 D1 and §10 Q2/Q3.

---

## 7. Shared vs Activity-Specific

**[PROTOTYPE]** Proposed boundary, subject to approval:

**Shared across the account**
- Personal identity and profile
- Wallet: total, available, pending, withdrawable; withdrawals and statements
- Messaging
- Design system, navigation conventions, dialogs, status language

**Activity-specific**
- Dashboard, navigation set, and accent identity
- Transaction and earnings views relevant to that activity
- Permissions and eligibility (e.g. provider eligibility, store identity, professional profile)
- Analytics appropriate to the activity (sales vs earnings)

**[APPROVED]** Activity-specific dashboards must not become separate accounts.

---

## 8. What the Prototype Establishes

The prototype is a **simulated front-end**, not working production functionality. All data is
hardcoded, all state is local, and nothing persists. It should be read as a statement of intended
experience and workflow.

Established:

1. Registration and onboarding with no account-type choice, followed by activity selection.
2. A six-activity selection screen split into Explore and Earn.
3. Separate dashboards for each activity, sharing one identity.
4. A unified wallet and unified profile with per-activity identities.
5. A complete errand lifecycle from requester and provider perspectives.
6. A seller workspace with listing, inventory, invoicing, and profitability analysis.
7. An admin environment organised as dashboard management plus platform administration, with record
   modules, status transitions, and an audit trail.
8. Consistent visual language, responsive layout, and mobile navigation.
9. Deliberate, repeated signalling that interactions are prototypes rather than completed actions.

Not established (prototype gaps, not necessarily product decisions):

- No in-product way to switch activities after onboarding (the Activities hub is unreachable).
- No AI assistance of any kind.
- No contract or milestone artefacts.
- No geo-radius dispatch, map, or multi-stop routing.
- No user-facing verification/KYC submission flow.
- No notifications surface for end users.
- No persistence, no backend, no real payments.

---

## 9. Reconciliation Notes

### A. Confirmed alignment

- One unified account; no account-type selection at registration.
- Explore/Earn framing and the six activity names.
- Activity-specific dashboards on one identity.
- Admin as a separate privileged environment with review, moderation, and audit.
- Verification and escrow as the trust model for services.
- Local Market as buyer ↔ seller, with delivery performed by logistics providers.
- Seller classification of listings against an admin-managed taxonomy.
- Logistics as an earning activity on the same account.
- "Both" account type absent.

### B. Vision requirements not yet represented

- AI assistance.
- Full taxonomy depth (vertical, product type, attributes).
- Restaurant dining coordination.
- Transparent contracts and milestone-backed security as product surfaces.
- Geo-radius broadcast dispatch and multi-stop delivery.
- In-product activation of additional activities after registration.
- User-facing verification submission.
- Distinct Admin vs Super Admin experience.
- Gating of the admin environment.
- A single navigation model across shells.
- Future-vertical expansion mechanism.

### C. New detail revealed by the prototype

- Errand as a first-class Explore activity with its own requester dashboard.
- Logistics provider dashboard with request marketplace and staged delivery progression.
- Unified multi-activity wallet with total/available/pending/withdrawable.
- Unified profile with per-activity identities.
- Seller profitability analysis (cost, selling price, unit gross profit).
- Earnings semantics: recognised earnings exclude quotations, applications, and pending escrow.
- Admin "dashboard management" model mirroring each user workspace.
- Activity-specific accent colours and shells.
- Reference formats: `#HV-` orders, `INV-` invoices, `ER-` errands, `DL-` deliveries.

### D. Apparent conflicts

1. **Third Explore activity.** *Resolved 3 November 2026.* The vision's umbrella table said
   *discover*; the prototype offers *errand*. The vision's own capability list in §6 already
   treated "discover professionals" as the first step of Hire, so the umbrella row was the defect.
   **`errand` is the third Explore activity; `discover` is the browse step inside Hire.**
2. **Positioning.** Vision: universal operating infrastructure for modern existence. Prototype:
   Africa's workforce marketplace. Different scope and audience.
3. **Account types.** Vision permanently removes Client/Professional account types; the prototype
   retains them as internal roles and dashboard labels.
4. **Admin access.** Vision: never selectable. Prototype: publicly reachable entry point.
5. **Navigation model.** Vision: one navigation model. Prototype: four distinct shells.
6. **Currency.** Hire and professional flows use USD; market, errand, and logistics flows use NGN,
   including inside the shared wallet.
7. **Marketing claims.** The prototype asserts "50,000+ professionals", "1.2K companies", and
   "$12M+ earned" as if factual.

### E. Unresolved decisions

See §10.

---

## 10. Open Decisions

These cannot be settled from either source. Each needs a founder decision, except where an item is
marked as decided.

1. **Positioning** — is Hivorr "Africa's workforce marketplace", or the broader universal operational
   infrastructure described in the vision, with Africa as the initial market?
2. **Discover vs errand** — **Decided 3 November 2026.** `errand` is approved as the third Explore
   activity. `discover` is the browse step inside Hire — browsing professionals before posting a job,
   and browsing open work — not an activity and not an activation. Kept in this list so the numbering
   below does not shift.
3. **Errand vs logistics** — **Decided 3 November 2026.** Two separate activities that share a
   request pool but not a capability namespace (`ARCHITECTURE.md` §16.5 #2). Kept in this list so the
   numbering below does not shift.
4. **Role language** — should "Client" and "Professional" be removed from all UI copy, or retained as
   dashboard names without implying account types?
5. **Admin access** — how are Admin and Super Admin granted, and should the prototype entry point be
   removed from the activity screen?
6. **Activity switching** — is the Activities hub the intended switcher, and should it be reachable
   from every dashboard?
7. **Currency and market scope** — single currency per market, or multi-currency accounts? Which
   launch markets?
8. **AI** — is AI assistance in launch scope? If so, which surfaces (matching, pricing, drafting,
   support)?
9. **Contracts and milestones** — required at launch, or a later phase?
10. **Taxonomy depth** — two levels at launch, or the full five-level model?
11. **Commercial rules** — platform fee, escrow release period, cancellation and dispute rules.
12. **MVP boundary** — the vision defines no MVP; what is in the first release?

---

## 11. Changes From the Original

Preserved unchanged: core identity, Universal Entity Principle, unified-account rules, removal of
"Both", Explore/Earn framing, admin privilege rules, the five ecosystem dimensions, taxonomy ambition,
trust model, and experience philosophy.

Added: an explicit activity model, shared vs activity-specific boundaries, a prototype evidence
section, reconciliation notes, and open decisions.

Softened or deferred: no approved statement has been deleted. Where the prototype differs from the
vision, the difference is recorded rather than resolved.

Not included: target-user segmentation, problem statements, business rules, MVP scope, and success
metrics — the original vision does not define these, and they must not be invented here.
