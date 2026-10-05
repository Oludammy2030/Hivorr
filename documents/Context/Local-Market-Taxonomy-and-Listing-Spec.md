# Local Market Taxonomy and Listing Spec

> **Status:** Approved scope — Local Market (3-party operations streams).
> **Sources:** `documents/Context/VISION.md`, `documents/Context/ARCHITECTURE.md`, `documents/Business-Roadmap/Business-Development-Roadmap.md` Phase 3, `documents/Engineering-Execution/Engineering-Execution-Structure/Engineering-Execution-Structure.md` EP-04.
> **Account rule:** One unified account. Explore (buy, hire, discover) + Earn (sell, offer services, provide logistics). No Client / Professional / Both account types. Both is permanently removed. Admin / Super Admin are separate privileged roles.

## 1. Purpose

Define the Local Market classification, listing, discovery, and management architecture so sellers classify listings once, listings appear in the correct marketplace area, and buyers discover them through relevant filters — without hardcoding taxonomy or duplicating platform capabilities.

## 2. Taxonomy (admin-configurable, never hardcoded)

Parallel to the Profession taxonomy (`Industry → Profession`):

* `market_vertical` → `market_category` → `market_subcategory` → `product_type` → `product_attribute_defs` → `product_attribute_values`
* `service_categories` reuse existing `industries / professions / skills`; `logistics_service_types` cover parcel, food, grocery, multi-stop, scheduled delivery.
* Flags per type: `is_physical / is_digital`, `requires_fulfilment`, `requires_logistics`.
* Multi-category via `listing_categories(listing_id, category_id, is_primary)`; one primary for canonical URL/SEO.
* Management mirrors `taxonomy_industry_create/update`, `taxonomy_profession_create/move`: service-role-only writes, public reads, slug-based seeds with `ON CONFLICT DO NOTHING`.

Illustrative starter set (not final; expandable by authorized admins without code changes):

* Food & Groceries
* Home & Living
* Fashion & Beauty
* Electronics
* Health & Personal Care
* Other (catch-all pending formal vertical)

Nigeria-first seed; new verticals/markets added via admin config, never via app release.

## 3. Listing model

* `stores(store profile, seller entity, verification status, location, policies)` → `product_listings(title, description, price, currency, stock/availability, variations jsonb, media, location, status, primary category, physical/digital, fulfilment type)` → `product_listing_media`, `product_favorites`, `digital_product_assets` (private bucket, entitlement-gated download).
* Listing statuses: `draft → pending_review → published | paused | archived | reported → under_review → published | removed`. Editing material fields re-queues review. Removals are soft deletes; transactional rows are never hard-deleted.
* Creation UX reuses `profession_registry` picker patterns (`taxonomy_engine`, industry/profession pickers) for vertical → category → product-type selection with per-type attributes.
* Media reuses `service-listing-media` bucket pattern: new `product-media` (public) + `digital-assets` (private) + `logistics-proof` (private) buckets with owner-write, entitlement-read policies.

## 4. Discovery and ranking

* Full-text `search_vector + GIN`, cursor/keyset pagination, filters: category, price range, location radius, rating, availability.
* Deterministic ranking mirroring `service_ranking_search`: verify > rating > completion > recency > relevance, weights in `platform_config`. Future `product_ranking_search` and `logistics_ranking_search` RPCs.
* Routes: `/market`, `/market/search`, `/market/:id`, `/store/:storeId` (live once backend lands; placeholder until then, never echoing `:storeId` on 404).

## 5. Orders, fulfilment, trust

* Staged: `carts/cart_items` → `orders/order_items/order_events` → `order_fulfilments/shipments/tracking_events` → `returns/refunds` (linked to financial ledger), 3-party split (buyer → merchant + rider + platform fee) in EP-04.
* Trust reuses the 8-layer model: seller verification lane (store profile + identity document + mandatory proof-of-trade/store document → `seller_verification_status`; no product publishing without an approved seller document), `seller_aggregates / product_aggregates`, reporting, moderation queue, dispute linkage (`non_delivery` reason exists), messaging per order, notifications, double-blind-vs-visible review decision deferred to founder approval.
* Access to some areas is subject to KYC: receiving seller earnings, withdrawals, payouts, conversions, and transacting above tier limits require a verified KYC tier (`tier_1` and above; `tier_0` carries zero limits) with bound pre-verified payout accounts.
* Digital delivery: entitlement check before download, licence/expiry policy, no public URLs.

## 6. Non-goals for MVP

Variations v2, carts v2, COD, multi-category v2 UI, advanced logistics optimization (EP-05). Sell + buy physical first; digital + 3-party fulfilment next.
