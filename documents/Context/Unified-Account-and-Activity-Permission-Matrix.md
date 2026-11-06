# Unified Account and Activity Permission Matrix

> **STATUS: APPROVED — 1 November 2026.**
> This revision supersedes the previous version at
> `C:\Users\user\Downloads\Unified-Account-and-Activity-Permission-Matrix.md`, which is preserved
> unchanged. It is the same document, corrected and extended — not a replacement product model.
>
> Approval covers the **account model and the permission model**: one account, six activities,
> independent verification lanes, server-computed capabilities, and the enforcement rules in §11.
> Approval does **not** settle the fourteen items listed in §18. Those remain undecided and are
> not approved requirements. Nothing marked `[OPEN]` may be implemented as though it were decided.
>
> **Sources of truth, in order of authority**
>
> 1. `documents/Context/VISION.md` — approved product direction.
> 2. `src/app/App.tsx` — the prototype, which is the current product experience and the visual
>    authority.
> 3. `documents/Context/AGENTS.md` and `documents/Context/ARCHITECTURE.md` — approved engineering,
>    security, and system rules.
> 4. The previous version of this document — retained where it does not conflict with 1–3.
>
> **Label key**
>
> - **[RETAINED]** — carried forward from the previous version, unchanged in substance.
> - **[REVISED]** — carried forward but corrected to match the current direction.
> - **[NEW]** — introduced by this revision.
> - **[OPEN]** — unresolved; requires a founder decision. Not a requirement.
>
> **The one rule that governs everything below:** one account, six activities, and permissions that
> are enforced by the server. Activities are capabilities on an account, never account types.

---

## 1. Purpose and scope

This document defines the account model and the permission model for Hivorr. It answers five
questions precisely:

1. What is created when a person registers?
2. How does one account use six activities without becoming six accounts?
3. What must be true before each action is allowed?
4. What does an activity activation grant, and what does it never grant?
5. How are these rules enforced, audited, and tested?

It is a **model and contract** document. It does not define UI layout (see
`VISUAL-IDENTITY.md`), product strategy (see `VISION.md`), or system architecture (see
`ARCHITECTURE.md`). Where those documents disagree with this one, they win and this document has a
defect.

**Scope boundaries.** This document does not decide commercial rules (platform fee, escrow period,
dispute outcomes), pricing, currency, or MVP activity scope. Those are separate founder decisions.

---

## 2. Core account principle

**[RETAINED]**

- Hivorr operates on **one unified account per user**.
- A user registers **once** and activates or uses **multiple activities** under that same account.
- Activities never require separate accounts and never create duplicate personal identities.
- Registration collects identity credentials only. It does **not** ask the user to choose a role,
  a mode, or an account type.
- Activity activation and its additional requirements happen **after** registration, separately,
  and at the user's discretion.

The six activities are six **experiences within one ecosystem** — not six applications, not six
profiles, and not six account types.

```
                          ┌─────────────────────────────┐
                          │        ONE ACCOUNT          │
                          │  identity · wallet · inbox  │
                          └──────────────┬──────────────┘
                                         │
        ┌────────────────────────────────┼────────────────────────────────┐
        │                                                                │
   EXPLORE                                                             EARN
   ├─ Buy      → Local Market                                          ├─ Sell      → Seller
   ├─ Hire     → Client                                                ├─ Offer     → Professional
   └─ Errand   → Errand requester                                      └─ Logistics → Logistics provider

                          ADMIN is not on this axis.
              It is a separately granted platform role, never an activity.
```

---

## 3. The account model

**[RETAINED, REVISED]** Seven concepts are deliberately separated. Conflating any two of them is
the most common way this model is broken.

| Concept | Definition | Owned by | Example |
| --- | --- | --- | --- |
| **User** | A credential holder who can sign in. | Identity module | `user_01H…` |
| **Account** | The legal/billing party. Owns the wallet, the profile, and all records. | Identity module | `account_01H…` |
| **Membership** | Links a user to an account with a role. Enables future teams. | Identity module | owner, representative |
| **Profile** | The account's shared presentation: name, avatar, contact, locale. | Profiles module | "Amara Diallo" |
| **Activity activation** | A record that this account has turned on one of the six activities, with its own status. | Profiles module | `market.sell` → `ACTIVE` |
| **Verification record** | Evidence and decision for one verification lane, scoped to the account or to an activity. | Verification module | trade, seller, logistics, business |
| **Capability** | A fine-grained permission string, computed server-side. Never stored on the client. | Authorisation service | `market.product.publish` |

### 3.1 What each concept is *not*

| Concept | Is not |
| --- | --- |
| Account | An activity, a role, or a dashboard |
| Activity activation | An account type, a login, or a permission |
| Verification | A subscription, a payment, or a permanent status |
| Capability | A UI flag, a route, or a client-side claim |
| Admin role | An activity, an account type, or something a user can select |

### 3.2 Permanently removed account types

The following must never exist as account types, registration choices, or mutually exclusive
classifications:

`Client` · `Professional` · `Both` · `Buyer` · `Seller` · `Rider` · `Requester` · `Merchant` ·
`Vendor` · `Freelancer` · `Admin` · `Super Admin`

"Client", "Professional", "Seller", "Logistics Provider", and "Errand Requester" are **dashboard
names and derived roles**, not stored account classifications. `Admin` and `Super Admin` are
**granted platform roles** (§14). `Both` is permanently removed and has no replacement.

### 3.3 The identity chain

```
User ──owns──▶ Account ──has──▶ Profile (shared)
                  │
                  ├──▶ Activity activation × N        (which experiences are on)
                  ├──▶ Verification record × N        (what has been proven, and for what)
                  ├──▶ KYC tier                       (how much money may move)
                  ├──▶ Wallet                         (shared, one balance)
                  └──▶ Records                        (orders, jobs, errands, deliveries)
```

**[NEW]** One personal account per user. At MVP, one account has exactly one owner user. Additional
memberships exist in the model so that teams and business representatives can be added later
without a migration.

### 3.4 Business representation

**[REVISED]** A business is a **verified business profile on the account**, not a second account and
not a second login. It carries a trading name, a registered legal name, a registration number, and
business documents. It is optional; an individual can hire, sell, and offer services without one.

- Business verification is its own lane (§7.5) and is independent of personal identity and trade
  approval.
- A business-backed hiring flow requires an approved business **and** an authorised representative
  membership.
- The legal name and the public display name are separate fields and are never merged.

**[OPEN]** Whether a business should eventually become its own account, with its own wallet,
activities, and multiple sign-in users. This revision keeps businesses inside the account because
the core principle is one account per user, and because the prototype models the store and business
as profile surfaces rather than separate logins.

> **Conflict to reconcile:** `ARCHITECTURE.md` §8.1 defines the Account as "the legal/billing entity
> — a person or a business". This document reads that as *the account is the legal party*, with a
> business represented through a business profile until multi-user accounts are introduced. See §17.

---

## 4. The six activities

**[REVISED]** The previous version listed `buy`, `hire`, `discover`, `sell`, `offer`, `logistics`.
The current product direction and the prototype define **errand** as the third Explore activity and
do not present `discover` as an activity of its own.

| Activity | Stable ID | Umbrella | User intent | Dashboard | Shell accent |
| --- | --- | --- | --- | --- | --- |
| **Buy** | `market.buy` | Explore | I want to buy | Local Market | blue `#2D3FE7` |
| **Hire** | `services.hire` | Explore | I want to hire | Client | blue `#2D3FE7` |
| **Errand** | `errands.request` | Explore | I want help with a task | Errand requester | orange `#F97316` |
| **Sell** | `market.sell` | Earn | I want to sell products | Seller | purple `#8B5CF6` |
| **Offer services** | `services.offer` | Earn | I want to offer my services | Professional | green `#16A34A` |
| **Provide logistics** | `logistics.provide` | Earn | I want to provide logistics | Logistics provider | green `#16A34A` |

Activity IDs are stable API and database identifiers. Dashboard names are display strings and may
change without a migration.

### 4.1 What each activity represents

| Activity | Represents | Core workflow |
| --- | --- | --- |
| Buy | Demand for products from local stores | browse → product → cart → checkout → order → track |
| Hire | Demand for professional services | discover professionals → post job → review applications → hire → pay via escrow |
| Errand | Demand for a physical task | create → review → submit → match provider → track |
| Sell | Supply of products | create listing → publish → manage stock → fulfil orders → invoice → analyse |
| Offer services | Supply of professional work | find work → apply → deliver → earn → analyse earnings |
| Provide logistics | Supply of physical movement | browse requests → accept → progress delivery → earn |

### 4.2 Open activity-model questions

**[DECIDED] `discover`** - settled by the founder on 3 November 2026 as **(a) a capability inside
Hire**: a requester browses professionals before posting a job, and a professional browses open work.
`VISION.md` §3, §9 D1 and §10 Q2 were corrected to match. The prototype already implements it as
`emp-discover` ("Find Services") and `pro-discover` ("Find Work"). `discover` is **not** an
activation and must not be modelled as one.

**[OPEN] Errand vs logistics** — `VISION.md` §10 Q2/Q3 asks whether errand is an approved activity,
and whether errand and logistics are one activity with demand and supply views or two activities.
This revision treats them as **two activities on one shared request pool**, which is what the
prototype shows. If they are later merged, the `errands.request` and `logistics.provide` activations
merge into one with two capabilities — the capability strings survive the change.

**[OPEN] MVP activity scope** — all six at launch, or an Explore-first release
(`ARCHITECTURE.md` Appendix C, item 2). The model supports either; the launch set is a product
decision.

---

## 5. Activation model

### 5.1 Registration

**[RETAINED]** Registration creates the unified account and nothing else:

| Collected at registration | Never collected at registration |
| --- | --- |
| Name | Account type |
| Email | Role or mode |
| Phone | Activity selection |
| Country / locale | Business details |
| Password (Argon2id) | Verification documents |

Email and phone verification follow `ARCHITECTURE.md` §8.2. The account exists, can sign in, can
edit its profile, and has no activities.

### 5.2 Activation is a separate, explicit act

**[NEW]** An **activity activation** is a row with its own lifecycle. Activating an activity:

- creates no user, no account, and no second identity;
- adds the activity's shell to the account's switcher;
- creates the activity's derived role (§9.1);
- does **not** grant any write capability that depends on verification;
- is idempotent — activating twice is a no-op, not an error and not a duplicate row.

### 5.3 Activation states

| State | Meaning | Dashboard | Writes |
| --- | --- | --- | --- |
| `INACTIVE` | Never activated, or deactivated by the user | Not shown in switcher | None |
| `ACTIVE` | On, but verification may still be outstanding | Full access | Only capabilities whose requirements are met |
| `RESTRICTED` | On, but a specific capability is blocked (for example a failed payment review) | Full access, read-only where blocked | Blocked capability only |
| `SUSPENDED` | On, but suspended by platform action | Visible, read-only | None for that activity |

`ACTIVE` is not the same as "verified". An account can be fully active in Sell and still be unable
to publish a product. This distinction is the heart of the model.

### 5.4 Multiple activities at once

**[RETAINED]** An account may hold any combination of the six activities simultaneously, in any
order, with no limit and no exclusivity. There is no "primary" activity, no "switch" that disables
another, and no ordering requirement.

- Every activity reads and writes only its own records.
- All activities share one wallet, one profile, one inbox, and one set of identity documents.
- Activating a fourth activity does not alter the state of the first three.

### 5.5 Switching

**[NEW]** Switching activity is a **navigation** act, not an account act:

- No re-authentication, no session change, no token exchange.
- No loss of state, draft, cart, or unsaved work in the activity being left.
- The active activity is a client-side routing concern; the server never needs to be told which
  dashboard is open.
- A deep link into any active activity works directly, without visiting a switcher first.

---

## 6. Shared vs activity-specific

**[RETAINED, REVISED]** The previous boundary was correct. This revision makes it exhaustive.

### 6.1 Shared across the account

| Shared | Notes |
| --- | --- |
| User credentials and sessions | One sign-in for everything |
| Personal identity and verification | One identity submission, reused across activities |
| Core profile: legal name, display name, avatar, contact, locale, timezone | Edited in one place |
| KYC tier | Account-level, not per activity |
| Wallet | One balance, one statement, one payout account list |
| Messaging inbox | One inbox; threads are scoped to their context |
| Notifications | One feed |
| Security settings, devices, MFA | Account-level |
| Activity switcher and global navigation | One model across shells |

### 6.2 Activity-specific

| Activity-specific | Buy | Hire | Errand | Sell | Offer | Logistics |
| --- | --- | --- | --- | --- | --- | --- |
| Dashboard and navigation set | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Accent colour | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Transaction records | orders | jobs, applications, contracts | errand requests | listings, orders, invoices | engagements, milestones | assignments, deliveries |
| Earnings and analytics view | purchases | spend | spend | sales, margin | earnings | earnings |
| Eligibility and verification | — | business (optional) | — | seller lane | trade lane | logistics lane |
| Additional profile surface | — | — | — | store profile | professional profile | provider details |

### 6.3 The reuse rule

**[NEW]** Reuse is mandatory for **identity** and forbidden for **eligibility**.

| Reused across activities | Never reused across activities |
| --- | --- |
| Legal name, date of birth, government ID, liveness result | Trade approval |
| Address, phone, email, country | Seller approval |
| KYC tier and its evidence | Logistics / vehicle approval |
| Avatar and display name | Business approval |
| Bank accounts and payout destinations | Store identity, professional profile, provider details |
| Wallet balance and history | Activity-specific records and analytics |

**Completing verification for one activity must never automatically approve another.** Identity is
the only lane that is genuinely shared, because it proves *who the person is*, not *what they are
allowed to do*.

---

## 7. Verification model

### 7.1 Lanes

**[RETAINED, REVISED]** Six lanes. Each has its own state machine, its own evidence, and its own
decision. They never collapse into one status.

| Lane | Scope | Required evidence | Unlocks | Does not unlock |
| --- | --- | --- | --- | --- |
| **Identity** (personal) | Account | Government ID document. Whether liveness/selfie capture and date-of-birth matching are also required depends on the verification vendor **[OPEN]** | Being a verified person; prerequisite for every earning lane | Any activity write by itself |
| **KYC tier** | Account | Identity plus address, and any tier-specific evidence — the ladder is **[OPEN]** (§7.4) | Financial limits at `tier_1` and above | Activity eligibility |
| **Trade / professional** | `services.offer` | Identity + proof of trade (licence, certification, qualification, portfolio as applicable) | Publish a service, bid, apply for work | Hiring, selling, logistics |
| **Seller** | `market.sell` | Store profile + identity + proof of trade (supplier invoice, registration, tax document, or equivalent) | Publish products, receive orders | Professional work, logistics |
| **Logistics** | `logistics.provide` | Identity + KYC + vehicle/logistics proof | Accept a dispatch, deliver | Selling, professional work |
| **Business** | `services.hire` (business-backed), `market.sell` (business store) | Trading name, registered legal name, registration number, business documents | Business-backed hiring and invoicing | Personal identity, trade, or logistics |

### 7.2 Independence

**[RETAINED]** These statements are binding:

1. Identity approval does not approve trade, seller, logistics, or business.
2. Trade approval does not approve identity, seller, logistics, or business.
3. Seller approval does not approve trade, logistics, or business.
4. Logistics approval does not approve seller, trade, or business.
5. KYC tier is independent of every activity lane. A fully verified professional at `tier_0` may
   apply for work but may not withdraw.
6. Approving one activity never marks the account "verified" in another.

### 7.3 Verification states

| State | Meaning |
| --- | --- |
| `NOT_STARTED` | No submission exists |
| `DRAFT` | The user is preparing evidence; nothing is under review |
| `SUBMITTED` | Submitted; queued for review |
| `UNDER_REVIEW` | Claimed by a reviewer |
| `APPROVED` | Decision recorded; the lane is open |
| `REJECTED` | Decision recorded with a reason; the lane is closed and may be resubmitted |
| `EXPIRED` | Evidence or the decision has lapsed and must be renewed |

Rules:

- A lane may have **at most one active submission** at a time. Duplicate submissions on the same
  credential are rejected.
- An `APPROVED` lane is never silently reopened by a new submission; a re-verification is an
  explicit act.
- A `REJECTED` decision must carry a machine-readable reason and a human explanation.
- Decisions are made only through admin review. No user action and no automated job may approve a
  lane. KYC status is server-assigned only.
- Identity fields are frozen while a submission is `UNDER_REVIEW` and reopen after `REJECTED`.

### 7.4 KYC tiers

**[RETAINED]** Tiers gate money, not activities.

| Tier | Meaning | Financial effect |
| --- | --- | --- |
| `tier_0` | Unverified | Zero limits on all financial actions: no withdrawal, no payout, no conversion, no receiving earnings |
| `tier_1` and above | Verified | Transactions, withdrawals, payouts, conversions, and earnings subject to the tier's configured limits |

- Tier thresholds and limits are configuration, not code. They are **not** defined by any approved
  source and must not be invented here. **[OPEN]** the exact tier ladder and per-tier limits.
- Tier state is account-level. It does not vary by activity.
- Dashboard access is never removed because of a low tier; only financial writes are blocked.

### 7.5 Business verification

**[RETAINED]** Business verification is its own lane with its own rules:

- Collected only when the user chooses to create a business.
- Creation atomically creates the business record and the owner's representative membership.
- A new business starts `PENDING`, never `APPROVED`.
- One business may have many members, but only one active submission at a time, enforced across
  members.
- Distinct businesses never collapse into one review lane.
- Rejection cascades to the business's gated operations without touching the account's personal
  identity or other activities.
- Legal name and public display name are separate fields; the legal name is never projected
  publicly.

### 7.6 Dashboard access is not a verification gate

**[RETAINED]** This is the most important UX and security rule in the document:

> An unverified account gets **full dashboard access immediately**. Verification gates **writes**,
> never **access**.

A user who activates Sell can open the Seller dashboard, see the catalogue, prepare a draft, and
understand exactly what is missing. They cannot publish. The server enforces the write; the UI
explains the reason. Hiding a dashboard until verification completes would be a product failure and
is not permitted.

---

## 8. Activity onboarding requirements

**[NEW]** Registration is identical for everyone. Everything below happens **after** registration,
**only** when the user activates that activity, and **only** to the extent the activity needs it.

| Activity | Additional information | Additional verification | Optional |
| --- | --- | --- | --- |
| Buy | Delivery addresses, preferred payment method | None | — |
| Hire | None. Each job post carries its own category, budget, and location. | None to post a personal job | Business profile + business verification, for business-backed jobs |
| Errand | Pickup and drop-off details, and a contact number for the provider | None | — |
| Sell | Store name, store description, category selection, payout account | Seller lane; identity; KYC for earnings | Business profile for a business store |
| Offer services | Professional headline, profession, skills, rate, portfolio | Identity; trade lane; KYC for earnings | Business profile |
| Provide logistics | Service area, transport type, availability | Identity; KYC; logistics lane | — |

Rules:

- No activity asks for information another activity already holds. Shared fields are pre-filled and
  read-only unless the user edits them in the shared profile.
- Onboarding is resumable. Abandoning it leaves the activity `ACTIVE` with the relevant write
  capabilities locked, never half-created.
- Skipping verification is always allowed. It defers the write capability, not the activation.

---

## 9. Permission matrix

### 9.1 Two levels

**[NEW]** The model has two distinct levels, and they must not be conflated:

| Level | What it is | Example | How it is granted |
| --- | --- | --- | --- |
| **Activity** | One of the six experiences | `market.sell` | User activation |
| **Capability** | A single allowed action | `market.product.publish` | Computed from activity + verification + KYC + admin role |

A user never "has the Seller permission". They have the `market.sell` activity, and the server
computes which seller capabilities are currently true.

### 9.2 Derived roles

**[RETAINED]** Roles are derived, never selected or stored:

| Derived role | Condition |
| --- | --- |
| Buyer | `market.buy` is `ACTIVE` |
| Client | `services.hire` is `ACTIVE` |
| Errand requester | `errands.request` is `ACTIVE` |
| Seller | `market.sell` is `ACTIVE` **and** seller lane `APPROVED` |
| Professional | `services.offer` is `ACTIVE` **and** trade lane `APPROVED` |
| Logistics provider | `logistics.provide` is `ACTIVE` **and** logistics lane `APPROVED` |
| Verified person | identity lane `APPROVED` |
| Financially enabled | KYC `tier_1` or above |
| Support / Admin / Super Admin | granted by Super Admin only |

### 9.3 The matrix

Legend: **A** = activity active · **I** = identity approved · **T** = trade approved ·
**S** = seller approved · **L** = logistics approved · **B** = business approved ·
**K** = KYC tier requirement

| Capability | Activity | Requires | Notes |
| --- | --- | --- | --- |
| `profile.read.self` | — | authenticated | Always available |
| `profile.update.self` | — | authenticated | Identity fields frozen during review |
| `activity.activate` | — | authenticated | Any of the six, any order |
| `activity.deactivate` | — | authenticated | Never deletes history |
| `market.catalog.browse` | — | authenticated | Public listings are also readable without an account |
| `market.cart.manage` | `market.buy` | A | Cart is per account, not per activity |
| `market.order.place` | `market.buy` | A + K above threshold | Financial limit applies |
| `market.order.cancel` | `market.buy` | A | Only before fulfilment starts |
| `market.order.dispute` | `market.buy` | A | Window defined by dispute rules **[OPEN]** |
| `services.job.post` | `services.hire` | A | Personal job; no business required |
| `services.job.post.business` | `services.hire` | A + B | Requires an authorised representative |
| `services.application.review` | `services.hire` | A | Only on jobs the account owns |
| `services.engagement.fund` | `services.hire` | A + K above threshold | Escrow funding |
| `services.job.apply` | `services.offer` | A + I + T | Drafting is allowed before approval |
| `services.service.publish` | `services.offer` | A + I + T | Drafts allowed before approval |
| `services.engagement.deliver` | `services.offer` | A + I + T | Only on engagements the account holds |
| `services.earnings.receive` | `services.offer` | A + I + T + K | `tier_0` receives nothing |
| `errands.request.create` | `errands.request` | A | Draft and submit |
| `errands.request.cancel` | `errands.request` | A | Before a provider is assigned |
| `errands.request.track` | `errands.request` | A | Own requests only |
| `market.product.draft` | `market.sell` | A | Drafting is allowed before approval |
| `market.product.publish` | `market.sell` | A + S | The core seller gate |
| `market.inventory.manage` | `market.sell` | A + S | |
| `market.order.fulfil` | `market.sell` | A + S | Orders on the account's own store |
| `market.invoice.issue` | `market.sell` | A + S | |
| `market.earnings.receive` | `market.sell` | A + S + K | `tier_0` receives nothing |
| `logistics.pool.browse` | `logistics.provide` | A | Available requests |
| `logistics.assignment.accept` | `logistics.provide` | A + I + L + K | The core logistics gate |
| `logistics.delivery.progress` | `logistics.provide` | A + I + L | Own assignment only |
| `logistics.delivery.complete` | `logistics.provide` | A + I + L | Proof of delivery required |
| `logistics.earnings.receive` | `logistics.provide` | A + I + L + K | `tier_0` receives nothing |
| `business.create` | — | authenticated | Starts `PENDING` |
| `business.verification.submit` | — | authenticated + member | One active submission per business |
| `business.update` | — | authenticated + member + not approved | Frozen during review |
| `wallet.read` | — | authenticated | Shared across activities |
| `wallet.withdraw` | — | K + bound verified payout account | `tier_0` blocked |
| `wallet.payout_account.bind` | — | K | Name match enforced |
| `wallet.convert` | — | K | Currency model **[OPEN]** |
| `messaging.thread.read` | — | authenticated + participant | Scoped to the context |
| `messaging.message.send` | — | authenticated + participant | Scoped to the context |
| `notification.read` | — | authenticated | Own notifications only |
| `admin.verification.review` | — | admin role `verification.review` | Not an activity |
| `admin.payment.review` | — | admin role `payment.review` | Dual control on high risk |
| `admin.dispute.resolve` | — | admin role `dispute.resolve` | Dual control on refunds |
| `admin.account.suspend` | — | admin role `account.manage` | Never self-suspend |
| `admin.configuration.write` | — | admin role `configuration.write` | Audited |
| `admin.audit.read` | — | admin role `audit.read` | Read-only |

### 9.4 Cross-activity boundaries

**[NEW]** These are hard boundaries, not conventions:

| Boundary | Rule |
| --- | --- |
| Buy ↔ Sell | A seller's own store is never implicitly a purchase; buying from yourself is blocked. |
| Hire ↔ Offer | The same account may hold both. An account cannot apply to its own job, and cannot be both parties to one engagement. |
| Errand ↔ Logistics | The same account may request an errand and provide logistics. It cannot accept its own request. |
| Any activity ↔ Admin | Admin status never grants an activity capability, and an activity never grants admin. |
| Any activity ↔ another account | No capability ever reaches another account's records. There is no "view all" endpoint outside admin. |

### 9.5 Financial capabilities

**[RETAINED]** Money is account-level, not activity-level:

- One wallet, one balance, one statement, one payout-account list.
- Earning capabilities require the activity lane **and** the KYC tier (§9.3).
- `tier_0` receives no earnings and performs no financial writes.
- Activity records still attribute money to their activity, so the statement is legible per
  activity without fragmenting the balance.
- A restriction on one activity's earning capability does not freeze the wallet or block unrelated
  activities.

---

## 10. Dashboard access and navigation

### 10.1 What determines access

| Question | Determined by |
| --- | --- |
| Is the shell visible in the switcher? | Activity state `ACTIVE`, `RESTRICTED`, or `SUSPENDED` |
| Can the user open it? | Same as above — **never** by verification status |
| Which actions are enabled inside it? | Computed capabilities |
| Which records are visible inside it? | Ownership and party scope |

### 10.2 Navigation sets

**[REVISED]** Each activity owns its own navigation. These are the prototype's sets and are
authoritative for the shell structure:

| Shell | Navigation |
| --- | --- |
| Local Market | Market Home · Browse Products · Saved Products · Cart · My Orders · Payments · Profile |
| Client | Dashboard · Find Services · Post a Job · My Jobs · Applications · Messages · Payments · Profile |
| Errand requester | Errand Home · Create Errand · My Errands · Active Tracking · Payments · Profile |
| Seller | Overview · Products · Add Product · Orders · Inventory · Invoices · Sales Analysis · Earnings · Profile |
| Professional | Dashboard · Find Work · My Jobs · Messages · Earnings · Earnings Analysis · Profile |
| Logistics provider | Overview · Available Requests · Active Assignments · Delivery History · Earnings · Analysis · Profile · Provider Details |

Mobile reduces each to five destinations. Do not invent a single shared navigation set — the
difference between shells is product identity.

### 10.3 The switcher

**[REVISED]** The prototype contains an Activities hub that no route reaches
(`VISION.md` §3, §8). The model requires it:

- Reachable from every dashboard and from the global navigation.
- Lists only activated activities, plus an "Explore more" affordance to activate another.
- Shows each activity's state: active, action required (verification outstanding), restricted,
  suspended.
- Never requires re-authentication.
- **[OPEN]** whether the switcher is a hub screen, a sidebar section, or an account menu
  (`VISION.md` §10 Q6).

### 10.4 Gated writes, not gated dashboards

Repeated here because it is the most frequently violated rule:

> An account with `market.sell` active but no seller approval **can open the Seller dashboard,
> browse, create drafts, and see why publishing is blocked**. It cannot publish.

The UI hides or disables the blocked action and shows the reason. The server rejects the action
regardless of what the UI showed.

### 10.5 Admin environment

**[RETAINED]** Admin is a separate shell, reached only through a privileged route:

- Never listed in the activity switcher.
- Never granted by activation, registration, or onboarding.
- The prototype's public "Open admin prototype" link is removed in production builds.
- An admin who opens a user dashboard sees it as an admin view, not as an activity the admin
  activated, and gains no activity capabilities from doing so.

---

## 11. Enforcement

### 11.1 Three layers, all required

**[RETAINED, REVISED]** From `ARCHITECTURE.md` §9.2:

| Layer | Responsibility | Failure mode if missing |
| --- | --- | --- |
| **Route guard** | Reject unauthenticated or out-of-scope requests early | Noise, but not a breach |
| **Service-layer policy** | The authoritative capability decision, inside the transaction | **The breach** |
| **Database tenancy** | Row-level security and owner/party constraints | Cross-account leakage |

The previous version treated database RPC and RLS as *the* enforcement mechanism. That is retained
in spirit but relocated: **business rules live in the service layer**, where they are testable, and
the database enforces tenancy so a missed filter fails closed.

### 11.2 Capability computation

**[NEW]** The server computes capabilities from explicit inputs and returns the result with the
session:

```
capabilities = f(
    account,
    activated activities and their states,
    verification lane states,
    KYC tier,
    admin role grants
)
```

Rules:

- Computation is pure and deterministic. The same inputs always produce the same set.
- Capabilities are never stored on the client, never encoded in a token claim that the client can
  forge, and never trusted from a request body.
- The session response may include a flat capability list **for presentation only**.
- Every mutating request re-checks the capability server-side, inside the transaction.

### 11.3 What the frontend may and may not do

| May | May not |
| --- | --- |
| Hide or disable an action the account cannot perform | Be the only thing preventing the action |
| Show the reason a write is blocked | Infer a capability from a route or a URL |
| Cache the capability list for the session | Persist a capability in local storage as authority |
| Link directly to a verification step | Assume a link implies permission |

### 11.4 Identity and tenancy

- Every user-owned row carries `owner_account_id`.
- Every transaction row carries its parties (`buyer_account_id`, `seller_account_id`,
  `client_account_id`, `professional_account_id`, `requester_account_id`, `provider_account_id`)
  and is readable only by those parties and by scoped admin.
- No endpoint returns "all" of anything outside admin.
- Object identifiers are UUIDv7, never sequential; but access control never depends on
  unguessability.
- File access is signed, short-lived, and logged; private documents are never on a public bucket.

### 11.5 Error contract

**[RETAINED]** Failures return a stable machine code plus a human message — never a bare error:

```json
{ "success": false, "code": "AUTHZ_ACTIVITY_INACTIVE", "message": "This activity is not active." }
```

The previous `PLTxxx` code family is the precedent. Codes must distinguish at least:

| Condition | Distinguishable from |
| --- | --- |
| Not authenticated | Not authorised |
| Activity not active | Activity active but verification missing |
| Verification missing | Verification rejected |
| KYC tier too low | Financial limit reached |
| Record not owned | Record does not exist |

Conflating these leaks information or destroys usability. A "not found" response for a record the
account does not own is acceptable and preferred over a "forbidden" that confirms existence.

### 11.6 Audit

**[RETAINED]** Every privileged or state-changing action writes an append-only audit record:
actor, actor type, action, target type, target id, before/after summary, IP, user agent, correlation
id, timestamp.

Audited without exception: verification decisions, activity suspension, account suspension, admin
role grants, financial mutations, business approval, and every admin read of private documents.

---

## 12. Account lifecycle

### 12.1 States

| Level | States | Effect |
| --- | --- | --- |
| Account | `ACTIVE`, `RESTRICTED`, `SUSPENDED`, `CLOSED` | Umbrella state |
| Activity | `INACTIVE`, `ACTIVE`, `RESTRICTED`, `SUSPENDED` | Per-activity state |
| Verification lane | §7.3 | Per-lane state |
| KYC tier | `tier_0` … `tier_n` | Financial limits |

### 12.2 Account-level states

| State | Sign-in | Dashboards | Writes | Money |
| --- | --- | --- | --- | --- |
| `ACTIVE` | Yes | All activated | Per capabilities | Per KYC |
| `RESTRICTED` | Yes | All activated, read-only where restricted | Blocked capabilities only | Withdrawals may be held |
| `SUSPENDED` | Yes, limited session | Read-only | None | Frozen pending review |
| `CLOSED` | No | None | None | Settled, then closed |

### 12.3 Restriction propagation

**[NEW]** This is the rule that prevents a small problem from becoming a platform-wide one:

| Trigger | Scope of effect |
| --- | --- |
| A verification rejection | That lane only |
| A failed payment review | The financial capability only |
| A dispute on one order | That order and, if escalated, that activity |
| Fraud or security hold | Account-level, may reach all financial capabilities |
| Policy violation in one activity | That activity, unless escalated to an account-level review |
| Admin role revocation | Admin capabilities only; user activities unaffected |

> **Rule:** an activity-specific restriction must not block unrelated activities unless an
> account-level restriction or an explicit security rule requires it. Suspending Sell must not stop
> the account from requesting an errand.

### 12.4 Adding an activity

**[NEW]**

1. User selects the activity in the switcher.
2. Activation row created; state `ACTIVE`.
3. Shell appears; dashboard is fully browsable.
4. Shared profile and identity are reused, not re-collected.
5. Any verification lane already approved for this account is reused.
6. Gated writes stay locked until the remaining requirements are met.
7. No other activity changes state.

### 12.5 Removing an activity

**[RETAINED, REVISED]** Deactivation suspends future writes; it never deletes history.

- The activation becomes `INACTIVE`; the shell leaves the switcher.
- Existing records remain stored, readable through history and statements, and visible to the other
  party.
- Open obligations — an unfilled order, an active delivery, an open engagement — remain valid and
  must be completable. Deactivation does not cancel them.
- The wallet, earnings, and statements remain accessible.
- Reactivation restores the activity with its verification and history intact.
- **[OPEN]** whether deactivation should be **blocked** while obligations are open, or allowed with
  obligations still actionable. This revision permits deactivation and keeps obligations
  actionable, because blocking traps users. Founder decision required.

### 12.6 Account closure

**[NEW]**

- Closure requires all obligations settled and the wallet emptied or paid out.
- Identity and financial records are retained for the regulatory period; the profile is
  de-identified where law permits.
- Closure is reversible only within a defined window. **[OPEN]** the window and the retention
  period.

---

## 13. Data ownership, privacy, and reuse

### 13.1 Ownership

**[NEW]**

- The account owns its data. The platform is a custodian, not an owner.
- Activity records are owned by the account that created them and are shared with the counterparty
  only to the extent the transaction requires.
- Verification documents are owned by the account and are never reused for a purpose the user did
  not consent to.

### 13.2 Reuse of verified information

**[RETAINED]**

- Identity is collected **once** and reused across every activity. A verified user is never asked to
  resubmit identity.
- Trade, seller, logistics, and business evidence is collected per lane and is never inferred from
  another lane.
- Reuse means *the server reads an existing approved record*. It never means *the platform shows one
  activity's documents to another activity's counterparty*.

### 13.3 Public vs private

| Public (projection) | Private (never public) |
| --- | --- |
| Display name, avatar, rating, completed count | Legal name, date of birth, ID number |
| Store name, store description, categories | ID document images, liveness captures |
| Professional headline, skills, portfolio, rate | Address, phone, email (unless the user publishes them) |
| Verification badge (a boolean, not the evidence) | Business registration documents |
| Service area, vehicle type | Bank details, payout accounts |
| Activity-specific public listings | Chat contents, dispute records |

- Public profiles are **projections**, never joins onto private tables.
- A verification badge communicates *that* a lane is approved, never *what was submitted*.
- Admin reads of private documents are logged individually.

### 13.4 Retention

**[OPEN]** Retention periods for identity documents, KYC evidence, chat history, and dispute records
are not defined by any approved source. They must be set with counsel. Until then: retain, do not
delete, and do not build automatic purge behaviour.

---

## 14. Administrative access

### 14.1 The distinction

**[RETAINED]** Administrative access is categorically different from activity access:

| | Activity | Admin |
| --- | --- | --- |
| Granted by | The user, by activating | Super Admin only |
| Visible in switcher | Yes | Never |
| Can be self-selected | Yes | Never |
| Scope | The account's own records | Platform-wide, within an admin role |
| Authentication | Standard | Mandatory TOTP MFA, shorter session |
| Audited | Standard | Every action |

### 14.2 Scoped admin roles

**[RETAINED]** Admin permissions are scoped, never binary:

`verification.review` · `payment.review` · `dispute.resolve` · `account.manage` ·
`configuration.write` · `audit.read`

A Support admin and a Super Admin are not the same thing, and neither is an activity.

### 14.3 Dual control

**[RETAINED]** High-risk actions require a second admin's confirmation and an immutable audit
record: refunds, manual payouts, verification overrides, and account suspension. No admin may
suspend or modify their own account.

### 14.4 Admin and activities are orthogonal

- An admin may hold no activities at all and still perform every admin action in scope.
- An admin may hold all six activities and gain nothing extra from admin status inside them.
- Revoking an admin role never touches the user's activities, records, wallet, or verification.
- Granting an admin role never activates an activity.

---

## 15. Migration and backward compatibility

### 15.1 This is a greenfield build

**[REVISED]** The previous version described migrating live `both` rows and dual-writing
`entities.capability`. That assumed the previous Flutter/Supabase system was the production
database. It is not: `ARCHITECTURE.md` records that implementation has not begun and no backend
exists. There is **no production data to migrate**.

What remains relevant is **vocabulary compatibility** — legacy documents and legacy UI strings that
still say "Client", "Professional", "Both", or "mode".

### 15.2 Legacy vocabulary mapping

**[RETAINED]** If the previous database is ever imported, or if legacy strings are encountered:

| Legacy | Forward |
| --- | --- |
| `both` | `services.hire` + `services.offer` (two activations, not one) |
| `client` / `employer` | `services.hire` |
| `professional` | `services.offer` |
| `merchant` / `vendor` | `market.sell` |
| `rider` | `logistics.provide` |
| `buyer` | `market.buy` |
| `discover` | Not an activity — see §4.2 |

Legacy `both` maps to **two activations**, because the account is not a mode. Nothing is deleted on
conversion; history stays attached to the account.

### 15.3 Forward compatibility rules

- New activities are added by inserting an activation type, not by altering the account table.
- New verification lanes are added as rows, not columns.
- Capability strings are namespaced by module (`market.*`, `services.*`, `errands.*`,
  `logistics.*`, `wallet.*`, `admin.*`) so a new activity can add a namespace without touching
  existing ones.
- Removing an activity must be possible without dropping tables: deactivate, retain, and hide.
- API responses must not assume the account has exactly one activity.

### 15.4 Documentation consistency

**[REVISED]** The previous acceptance check grepped for `Both-account`, `DashboardCapability`, and
`(Client)`. The forward check is:

| Must be zero in forward documents | Exceptions |
| --- | --- |
| `Both` as an account type | Historical changelogs |
| `account_type` | Migration tables |
| "Choose your role" at registration | — |
| Admin reachable from the activity selection screen | Prototype-only builds |

---

## 16. Testing requirements

### 16.1 Levels

| Level | What it proves |
| --- | --- |
| **Unit — capability computation** | For every activity × activation state × lane state × KYC tier × admin role, the capability set is exactly as specified in §9.3 |
| **Unit — derived roles** | A role exists only when its full condition holds |
| **Integration — isolation** | Account A can never read or write account B's records in any activity |
| **Integration — independence** | Approving lane X never changes lane Y's state |
| **Integration — lifecycle** | Activate, deactivate, reactivate, suspend, restrict, close |
| **Contract** | The session capability list matches what the service layer enforces |
| **E2E** | The acceptance scenarios below |
| **Security** | IDOR sweep across every endpoint; privilege escalation from activity to admin |

The capability matrix is a **table-driven test**, not a set of examples. Every cell in §9.3 must be
covered by a case that asserts both the allowed and the denied outcome.

### 16.2 Acceptance scenarios

**[REVISED]** Stack-neutral. Each must pass for the account model to be considered correct.

| # | Scenario | Must demonstrate |
| --- | --- | --- |
| A | New individual registers | Registration collects credentials only; no role, mode, or activity choice; account exists with zero activities |
| B | Client activates Hire and posts a job | Personal job created with no business and no identity verification; dashboard was accessible before verification |
| C | Same account activates Offer | Identity already approved is reused; trade lane is separate and still `NOT_STARTED`; applying is blocked until trade approval |
| D | Trade is rejected | Identity and KYC unchanged; lane reopens for resubmission; no other activity is affected |
| E | Admin approves trade | Apply and publish unlock; identity and KYC are not re-evaluated; audit record written |
| F | Account activates Sell | Seller dashboard opens immediately; publish blocked; drafts allowed; identity not re-collected |
| G | Account activates Logistics | Dispatch acceptance blocked until logistics lane approved; earnings blocked at `tier_0` |
| H | Account activates all six | Six shells, one wallet, one inbox, one identity; no duplicate account; no duplicate identity row |
| I | Account deactivates Sell | Shell leaves the switcher; orders and invoices remain; open orders still completable; other activities unchanged |
| J | Account reactivates Sell | Seller approval and history restored; no re-verification; no data loss |
| K | Activity restricted | Only that activity's writes are blocked; unrelated activities still function |
| L | Account suspended | All activities read-only; sign-in limited; financial actions frozen; audit recorded |
| M | Admin role granted | No activity is activated; no activity capability is gained; admin capabilities only |
| N | Cross-account access attempt | Every endpoint returns not-found or forbidden without leaking existence or content |

### 16.3 Regression obligations

- Any change to §9.3 requires the table-driven test to be updated in the same change.
- Any new activity requires: an activation type, a capability namespace, a dashboard, a
  verification lane (or an explicit statement that it needs none), and rows in §6, §8, §9, §10.
- Any new verification lane requires: a state machine, an admin review surface, and an audit record.

---

## 17. Changelog — what changed from the previous version

### 17.1 Retained unchanged in substance

- One unified account; no account-type selection at registration.
- Activities as capabilities, not account types; `Both` permanently removed.
- Identity verified once, reused everywhere; trade approval independent of identity.
- Dashboard-immediate, gate-locked writes.
- One active submission per credential; no duplicate identity requests.
- Business verification as its own lane, atomic creation, freeze during review, one active
  submission across members.
- KYC tiers: `tier_0` zero limits, `tier_1+` unlocks financial actions.
- Default-deny, party-scoped access; admin as a separate shell; no self-suspend.
- Deactivation suspends writes and never deletes history.
- Stable machine-readable error codes.

### 17.2 Changed, and why

| Previous | Now | Why |
| --- | --- | --- |
| Six activities: `buy`, `hire`, `discover`, `sell`, `offer`, `logistics` | Six activities: Buy, Hire, **Errand**, Sell, Offer services, Provide logistics | The prototype defines errand as the third Explore activity; `discover` is not presented. `discover` is now an open question, not an activity. |
| Supabase RPC, RLS, `SECURITY INVOKER`, `PLTxxx` | Service-layer policy plus database tenancy | `ARCHITECTURE.md` §9.2 relocates business rules to the service layer; RLS becomes defence in depth. |
| `entity_kyc_levels`, `entity_activities`, `entities.capability` | Account, activity activation, verification record, KYC tier | The schema is greenfield; Supabase table names are not carried forward. |
| `HivorrActivity.isLive`, `dashboardVisibility()`, `visibleFor()` | Activity state plus computed capabilities | Flutter-era client helpers are replaced by a server-computed capability set. |
| `/activities` launcher and "Explore more" | Switcher specification (§10.3) | The prototype's hub is unreachable; the model requires it and defines its states. |
| Flutter and SQL test file names in the scenario table | Stack-neutral acceptance scenarios A–N | Those files belong to the previous implementation and do not exist here. |
| Migration of live `both` rows | Vocabulary migration only; greenfield build | No production data exists. |
| Admin identity as `is_platform_admin()` | Scoped admin roles plus dual control | `ARCHITECTURE.md` §9.4 requires scoped permissions and dual control. |

### 17.3 Added

- Explicit separation of user, account, membership, profile, activation, verification, and
  capability (§3).
- Activation lifecycle and states (§5.3).
- Activity switching as a navigation act, not an account act (§5.5).
- An exhaustive shared vs activity-specific boundary (§6).
- Per-activity onboarding requirements (§8).
- The capability matrix with explicit prerequisites (§9.3).
- Cross-activity boundary rules, including self-dealing prohibitions (§9.4).
- Dashboard-access rules and the switcher (§10).
- Restriction propagation rules (§12.3).
- Add, remove, and close flows (§12.4–12.6).
- Data ownership, public/private projections, and reuse rules (§13).
- Forward-compatibility rules (§15.3).
- Table-driven capability testing and the A–N acceptance scenarios (§16).

### 17.4 Removed

- `discover` as an activity. It is the browse step inside Hire (§4.2), not an activation.
- All Flutter, Dart, Supabase, and SQL-test references.
- The `both → offer` single-activity remap. `both` now maps to two activations.
- The assumption that RLS/RPC is the primary authorisation mechanism.
- Any implication that an activity is a mode that can be switched on at the expense of another.

---

## 18. Unresolved founder decisions

These are not requirements. Nothing below may be implemented as though it were decided, except
where a row is explicitly marked **DECIDED**.

This table is not the consolidated register. `ARCHITECTURE.md` §16.4 is the single list that
combines this section, the database rules §13 and the engineering standards §16. Record a decision
there first, then here.

| # | Decision | Blocks |
| --- | --- | --- |
| 1 | **`discover`** - **DECIDED 3 November 2026:** a capability inside Hire, not an activity (§4.2). Kept in place so existing cross-references stay valid. | Nothing - settled |
| 2 | **Errand vs logistics** - **DECIDED 3 November 2026:** two separate activities that share a request pool but not a capability namespace (`ARCHITECTURE.md` §16.5 #2). Kept in place so existing cross-references stay valid. | Nothing - settled |
| 3 | **MVP activity scope** — all six at launch, or Explore-first? | Release scope |
| 4 | **Deactivation with open obligations** — blocked, or allowed with obligations still actionable? | §12.5 |
| 5 | **Business as account** — stay a profile on the account, or become its own account with its own wallet and multiple sign-in users? | §3.4; team features |
| 6 | **KYC tier ladder and limits** — how many tiers, what limits, what evidence per tier? | §7.4; financial gating |
| 7 | **Retention periods** — identity documents, KYC evidence, chat, disputes | §13.4; deletion design |
| 8 | **Account closure window** — how long is closure reversible? | §12.6 |
| 9 | **Switcher form** — hub screen, sidebar section, or account menu? | §10.3 |
| 10 | **Role language** — remove "Client"/"Professional" from UI copy, or keep them as dashboard names? | §3.2; copy |
| 11 | **Admin access path** — how are Admin and Super Admin granted, and is the prototype entry point removed in all builds? | §14 |
| 12 | **Verification vendor** — build the review queue only, or integrate an identity provider? | Lane implementation |
| 13 | **Grandfathering** — if any verification rule tightens after launch, is there a grace period? | Rollout policy |
| 14 | **Self-dealing exceptions** — are there legitimate cases where one account is both parties to a transaction (for example a business buying from its own store)? | §9.4 |

---

## 19. Conflicts with the other project documents

Recorded here, not resolved here - except rows 1 and 2, which the founder settled on 3 November 2026.
The rest remain open or are recorded so that the disagreement is visible.

| # | Conflict | Detail | Resolution |
| --- | --- | --- | --- |
| 1 | **`discover`** | `VISION.md` §3 listed it as an approved Explore activity while §6 already treated "discover professionals" as the first step of Hire; `AGENTS.md` Rule 6 said "Explore (buy, hire, discover)". | Settled 3 November 2026 - `errand` is the third Explore activity and `discover` is the browse step inside Hire. `VISION.md` §3, §9 D1, §10 Q2 and `AGENTS.md` Rule 6 now say so. |
| 2 | **Errand as an activity** | `VISION.md` §6 marks it `[OPEN]`; `AGENTS.md` Rule 6 omits it. | Settled 3 November 2026 - six activities, with errand and logistics separate (`ARCHITECTURE.md` §16.5 #2). §18 #2 records the settlement. |
| 3 | **Account vs business** | `ARCHITECTURE.md` §8.1 defines the Account as "a person or a business". This document keeps one personal account per user and treats a business as a verified profile on it. | Read §8.1 as "the account is the legal party". If businesses become separate accounts, §3.4 changes but the capability model does not. |
| 4 | **Activity IDs** | The previous document used bare `buy`, `hire`, `sell`, `offer`, `logistics`. `ARCHITECTURE.md` §9.1 uses `market.buy`, `market.sell`, `services.hire`, `services.offer`, `logistics.provide`. | This document adopts the namespaced form and adds `errands.request`. |
| 5 | **Matrix file location** | `ARCHITECTURE.md` Appendix A lists this file as non-existent. | This revision resolves it: the file now exists at `documents/Context/`. |
| 6 | **Admin reachability** | The prototype exposes "Open admin prototype" on the activity screen; `VISION.md` §4.4 and `ARCHITECTURE.md` §8.4 require its removal. | Removal stands; the prototype is a prototype. |

---

## 20. Summary — the model in one page

```
REGISTRATION
  creates: user + account + profile
  does not create: activity, role, verification, dashboard

ACTIVATION (per activity, any order, any combination)
  creates: an activation row
  grants:   the dashboard, the shell, the derived role
  does not grant: any verification-gated write

VERIFICATION (per lane, independent, server-decided)
  identity   → proves the person          (shared, reused)
  KYC tier   → how much money may move    (shared, account-level)
  trade      → may offer services         (activity-specific)
  seller     → may sell products          (activity-specific)
  logistics  → may deliver                (activity-specific)
  business   → may act as a business      (profile-specific)

CAPABILITY = activity state
           + verification lane states
           + KYC tier
           + admin role
           computed server-side, re-checked on every write

DASHBOARD  = visible when activated
             never gated by verification
             gated writes explained in place

ADMIN      = a separate, granted, audited environment
             never an activity, never self-selectable,
             never a source of activity power
```

**One account. Six activities. One identity. Independent verification. Server-enforced
permissions. No exceptions.**

---

*This document models permissions; it does not implement them. No code, schema, authentication
service, or frontend component is changed by this revision. Items marked `[OPEN]` require a founder
decision before implementation.*
