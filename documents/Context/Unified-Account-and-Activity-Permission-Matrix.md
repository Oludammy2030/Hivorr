# Unified Account and Activity Permission Matrix

> **Status:** Approved scope — authorizes the hire/offer → multi-activity evolution.
> **Sources:** `documents/Context/VISION.md`, `documents/Context/AGENT.md` Rule 6, `documents/Context/ARCHITECTURE.md`, EP-01/EP-02 phase plans.
> **Account rule:** One Hivorr account activates multiple activities over time. Both is permanently removed. Admin / Super Admin are system-granted, never selectable.

## 1. Activities (capabilities, not account types)

| Activity | Shelf | Meaning | Gate for writes |
|---|---|---|---|
| `buy` | Explore | I want to buy (order products) | `buy` active; order RPCs. Payment above tier limits requires KYC upgrade. |
| `hire` | Explore | I want to hire (post jobs, hire) | `hire` active (existing `job_create` gate preserved). Funding escrow above tier limits requires KYC upgrade. |
| `discover` | Explore | Browse services/products (no gate) | None (public-capable discovery) |
| `sell` | Earn | I want to sell products (store + listings) | `sell` active + seller verification `APPROVED` + required KYC tier for receiving earnings/withdrawals |
| `offer` | Earn | I want to offer services | `offer` active + trade verification `APPROVED` (existing Rule 2) + required KYC tier for receiving earnings/withdrawals |
| `logistics` | Earn | I want to provide logistics | `logistics` active + rider verification `APPROVED` + required KYC tier for receiving earnings/withdrawals |

`HivorrActivity.isLive` is UX-only. Server RPC + RLS remain authoritative (AGENT.md Rule 4). Access to some areas is subject to KYC: `tier_0` (Unverified) carries zero limits; financial areas (withdrawals, payouts, conversions, higher daily/weekly/monthly/cashout limits) and earning payouts require a verified tier (`tier_1` and above).

## 2. Verification lanes

* Services (`offer`): identity document plus mandatory proof of trade → `trade_verification_status = APPROVED` to publish/bid. No professional-service publishing or paid work without an approved trade proof. Unverified gets dashboard immediately, gated writes blocked `PLT002`.
* Sellers (`sell`): store profile + identity document plus mandatory proof-of-trade/store document (e.g. trade proof, supplier invoice, business registration, or tax document as applicable) → `seller_verification_status = APPROVED` to publish products. No product publishing without an approved seller document. Same dashboard-immediate, gate-locked pattern.
* Riders (`logistics`): mandatory logistics verification — identity + KYC + vehicle/logistics proof → rider verification `APPROVED` to accept dispatches. No dispatch acceptance without approval. Same dashboard-immediate, gate-locked pattern.
* KYC tier (subject-to-KYC areas): `tier_0` Unverified = zero limits; `tier_1` Basic and above unlock transactions, withdrawals, payouts, conversions, and earning payouts per `kyc_tiers` limits. KYC status is server-assigned via verification review RPCs only (`entity_kyc_levels` RPC-only, `verification_kyc_level_get` / `verification_limits_get` self-scoped reads).
* Admin review queue gains seller/rider lanes; existing service lane unchanged.

## 3. Authorization matrix

| Write | Required activity + verification | Server enforcement |
|---|---|---|
| `job_create` | `hire` active | Existing RPC gate preserved |
| `application_submit` | `offer` active + trade approved | Existing RPC gate preserved |
| `service_listing publish` / bid | `offer` active + trade approved | Existing publish guard preserved |
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
