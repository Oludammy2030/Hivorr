# Unified Account and Activity Permission Matrix

> **Status:** Approved scope — authorizes the hire/offer → multi-activity evolution.
> **Sources:** `documents/Context/VISION.md`, `documents/Context/AGENT.md` Rule 6, `documents/Context/ARCHITECTURE.md`, EP-01/EP-02 phase plans.
> **Account rule:** One Hivorr account activates multiple activities over time. Both is permanently removed. Admin / Super Admin are system-granted, never selectable.

## 1. Activities (capabilities, not account types)

| Activity | Shelf | Meaning | Gate for writes |
|---|---|---|---|
| `buy` | Explore | I want to buy (order products) | `buy` active; order RPCs. Payment above tier limits requires KYC upgrade. |
| `hire` | Explore | I want to hire (post jobs, hire) | `hire` active (existing `job_create` gate preserved). Business-backed jobs additionally require an approved business and an authorized representative. Funding escrow above tier limits requires KYC upgrade. |
| `discover` | Explore | Browse services/products (no gate) | None (public-capable discovery) |
| `sell` | Earn | I want to sell products (store + listings) | `sell` active + seller verification `APPROVED` + required KYC tier for receiving earnings/withdrawals |
| `offer` | Earn | I want to offer services | `offer` active + identity verified (`tier_1+`) + trade verification `APPROVED` (existing Rule 2) + required KYC tier for receiving earnings/withdrawals |
| `logistics` | Earn | I want to provide logistics | `logistics` active + rider verification `APPROVED` + required KYC tier for receiving earnings/withdrawals |

`HivorrActivity.isLive` is UX-only. Server RPC + RLS remain authoritative (AGENT.md Rule 4). Access to some areas is subject to KYC: `tier_0` (Unverified) carries zero limits; financial areas (withdrawals, payouts, conversions, higher daily/weekly/monthly/cashout limits) and earning payouts require a verified tier (`tier_1` and above).

## 2. Verification lanes

* One personal identity per account: the same `entity_kyc_levels` record gates every mode. Switching `hire`/`offer` never asks for a second identity submission. Trade approval and identity approval stay independent.
* Services (`offer`): identity verified (`entity_kyc_levels` active at `tier_1+`) plus mandatory proof of trade → `trade_verification_status = APPROVED` to apply or publish/bid. No professional-service publishing or paid work without both. Unverified gets dashboard immediately; gated writes are blocked server-side (`PLT005` identity, `PLT002` trade). Creating a draft listing remains allowed so evidence can be prepared before approval.
* Sellers (`sell`): store profile + identity document plus mandatory proof-of-trade/store document (e.g. trade proof, supplier invoice, business registration, or tax document as applicable) → `seller_verification_status = APPROVED` to publish products. No product publishing without an approved seller document. Same dashboard-immediate, gate-locked pattern.
* Riders (`logistics`): mandatory logistics verification — identity + KYC + vehicle/logistics proof → rider verification `APPROVED` to accept dispatches. No dispatch acceptance without approval. Same dashboard-immediate, gate-locked pattern.
* KYC tier (subject-to-KYC areas): `tier_0` Unverified = zero limits; `tier_1` Basic and above unlock transactions, withdrawals, payouts, conversions, and earning payouts per `kyc_tiers` limits. KYC status is server-assigned via verification review RPCs only (`entity_kyc_levels` RPC-only, `verification_kyc_level_get` / `verification_limits_get` self-scoped reads).
* Businesses (`hire` as a business): business identity (trading name, registered legal name, CAC number) is collected only when the user creates a business. `business_create` atomically creates the business and the representative membership; the business starts `pending`. Evidence uses the existing `business_document` credential and `business_verification` review lane. Identity fields freeze while a submission is under review or the business is approved, and reopen after rejection. Distinct business submissions never collapse into one lane.
* Admin review queue gains business, seller and rider lanes. Business rows carry business id/name/CAC/status and support a `business_verification` filter; non-business rows keep the canonical 16-key shape.

## 3. Authorization matrix

| Write | Required activity + verification | Server enforcement |
|---|---|---|
| `job_create` | `hire` active; business-backed jobs require approved business + authorized representative | Existing RPC gate preserved, business gate enforced in `job_create` |
| `application_submit` | `offer` active + identity verified + trade approved | Identity gate (`PLT005`) then existing trade/capability gates |
| `service_listing publish` / bid | `offer` active + identity verified + trade approved | Identity gate (`PLT005`) in `service_listing_create`/`service_listing_publish`, then existing trade guard |
| `business_create` | Authenticated entity | Atomic business + representative membership RPC; starts `pending` |
| `business verification submit` | Business member, business not approved, no pending/in-review business submission | `verification_submit` lifecycle guard (`PLT005`); identity fields frozen by trigger |
| `product_create/update/publish` | `sell` active + seller approved + required KYC tier | Proposed RPC + RLS, party-scoped seller |
| `order_create` | `buy` active (payment above tier limits requires KYC upgrade) | Proposed RPC + RLS, party-scoped buyer |
| `dispatch_accept` | `logistics` active + rider approved + required KYC tier | Proposed RPC + RLS, party-scoped rider |
| Withdrawals / payouts / conversions / higher limits | Required KYC tier (`tier_1`+) + bound pre-verified payout account | Existing financial RPC gates (`verification_limits_get`, `financial_withdraw`); `tier_0` blocked/zero limits |
| Admin writes | `is_platform_admin()` | Existing `platform_admins` gates; no self-suspend |

RLS: default-deny, self/party-scoped (`seller/buyer/rider`, `client/professional`), `SECURITY INVOKER`, envelope `{success, code, message, data}` `PLTxxx`. `SECURITY DEFINER` requires extra review.

## 4. Dashboard and navigation

* Existing `dashboardVisibility()` + `visibleFor(hire, offer)` extended to workspaces: Purchases / Sales / My Hiring / My Work / Logistics, filtered by active activities.
* `/activities` launcher + dashboard "Explore more" remain reachable post-onboarding so users add/deactivate activities without a new account. Deactivation suspends future writes, never deletes history.
* `/admin/*` stays a separate shell (`SuperAdminShell`); admin can visit dashboards manually but gains no activity powers from admin status.

## 5. Migration note (Both removal)

* Legacy `both` rows already remapped to `offer` (hiring one tap away). Forward vocabulary is `hire | offer` plus `buy | sell | logistics` as they land.
* `entities.capability hire|offer` retained during dual-write transition; new `entity_activities` entitlements added additively. No `entity_type` column. No history deletion on switch.
* Docs grep acceptance: `Both-account | DashboardCapability(hire/offer/both) | (Client)` → 0 in forward docs (history `Task-Implementation` exempt).

## 6. Scenario coverage (A–L)

These are the executable anchors for the required end-to-end scenarios. SQL tests
run under `supabase test db --local`; Flutter tests run under `flutter test`.

| Scenario | Primary coverage |
|---|---|
| A — New individual client | `auth_screens_test.dart` → *renders credentials-only registration form* (name/email/phone/password only, no mode or role); `profile_screen_verify_test.dart` → *unverified identity row links to verification status*; `057_unified_account_eligibility.sql` → hire-only client creates and publishes a personal job while identity stays unverified. |
| B — Client identity already verified | `verification_status_screen_test.dart` → *verified shows the identity badge and no upload CTA*; `profile_screen_verify_test.dart` → *professional identity row reflects verified status*; `onboarding_identity_step_screen_test.dart` → *verified identity renders the approved state*; `012_verification_rpc_enforcement.sql` → identity approval assigns `tier_1`. |
| C — Client identity pending or rejected | `onboarding_identity_step_screen_test.dart` → *pending-verification conflict offers skip + view-status* and *persisted rejected identity offers resubmission*; `verification_status_screen_test.dart` → *does not render the action-required block while pending*; `012_verification_rpc_enforcement.sql` → an active submission cannot be duplicated on the same credential. |
| D — Client switches to Professional; identity reused, trade separate | `professional_requirements_test.dart` → *verified identity counts as done even with pending trade*; `onboarding_trade_step_screen_test.dart` → *pending gate shows the locked copy* and *approved gate shows the unlocked copy*; `057_unified_account_eligibility.sql` → identity verification unlocks apply/publish while trade approval remains a separate prerequisite. |
| E — No identity; route to existing identity flow | `professional_requirements_test.dart` → *fresh account routes every item to its fix*; `professional_requirements_screen_test.dart` → *actionable rows open the wizard step with a return marker*; `onboarding_identity_step_screen_test.dart` → *renders intro copy and all five document-type chips*. |
| F — Identity/trade pending; stay Under Review, no dashboard jump | `onboarding_identity_step_screen_test.dart` → *submit delegates, shows reviewed copy, advances to trade*; `onboarding_trade_step_screen_test.dart` → *submit binds the profession id and stays under review* and *under-review state survives re-entry from persisted status*; `057_unified_account_eligibility.sql`/`012_verification_rpc_enforcement.sql` → submissions remain pending until an admin decision. |
| G — Admin approves trade proof | `admin_review_queue_screen_test.dart` → *renders the submissions table with review actions*; `admin_review_detail_screen_test.dart` → *opening claims the submission for review*; `012_verification_rpc_enforcement.sql` → trade approval flips the profession gate. |
| H — Admin rejects trade proof | `admin_review_detail_screen_test.dart` → *reject forwards the resubmission choice* and *reject without the choice stays final*; `trade_verification_status_screen_test.dart` → *rejected detail guides a resubmission*; `012_verification_rpc_enforcement.sql` → rejection leaves identity/KYC state unchanged and reopens the lane. |
| I — Individual client, no business | `057_unified_account_eligibility.sql` → hire-only client creates/publishes a personal job with `business_id = null`; `business_screens_test.dart` → *empty state offers creation* (business setup is optional); `053_job_business_link.sql` → personal job snapshots. |
| J — Business client or professional | `business_screens_test.dart` → under-review/rejected/approved projections, notes, and upload locking; `admin_review_detail_screen_test.dart` → *business submissions lead with registered identity*; `057_unified_account_eligibility.sql` → atomic creation, duplicate-lane blocking across members, freeze, rejection cascade, approval, and business-linked hiring; `051_business_verification_lane.sql` and `053_job_business_link.sql` → business review and hiring lanes. |
| K — Business-name consistency and display-name separation | `professional_profile_settings_test.dart` → *profile tab separates legal and display names*; `professional_profile_screen_test.dart` → *route title stays generic; the display name renders in the …*; `057_unified_account_eligibility.sql` → trading name and registered legal name are distinct business fields; `052_public_professional_name.sql` → public-name projection. |
| L — Existing-user regressions | Full `flutter test` suite; all 61 SQL files under `supabase test db --local` (1,928 assertions), including the identity-verified KYC fixtures updated for the new gates. |

## 7. Known boundaries and follow-ups

* Identity and trade submissions are de-duplicated per credential; the UI never
  asks a verified user to resubmit identity and never creates a second active
  request from the same flow. A cross-credential active-lane guard (one active
  identity lane per account, one active trade lane per profession) is a
  follow-up, mirroring the cross-member business guard already shipped.
* Existing users are enforced immediately by the server gates. A grandfathering
  or grace-period policy for already-active professionals remains a product
  decision.
* Representative identity for business hiring, first-release
  business-management scope, and cross-surface display-name consistency remain
  deferred product decisions.
