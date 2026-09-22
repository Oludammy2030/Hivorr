# ENGINEERING PHASE PLAN — EP-03: Two-Party Transaction Engine & Professional Services Platform

> **Document Type:** Engineering Phase Plan | **Source:** `documents/Engineering-Execution/Engineering-Execution-Structure/Engineering-Execution-Structure.md` EP-03 + `documents/Business-Roadmap/Business-Development-Roadmap.md` Phase 2 | **Status:** Ready for Review | **Priority:** High — First Revenue-Generating Capability
> **Plan Mode Note:** Read-only generation. File write to `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md` gated on plan approval / build mode activation.

---

## 1. Phase Overview

| Attribute | Detail |
|---|---|
| **Phase ID** | EP-03 |
| **Phase Name** | Two-Party Transaction Engine & Professional Services Platform |
| **Phase Objective** | Build the universal 2-party transaction engine and launch the professional services marketplace — the simplest transaction model with no logistics dependency. |
| **Business Capability Enabled** | Business Phase 2 — Professional Services Marketplace Activation. Enables direct expert-to-client connections with contract management, escrow-backed payments, and trust signals. |
| **Priority** | High — first revenue-generating capability; validates trust infrastructure under real transaction conditions |
| **Status** | Not Started |
| **Dependencies** | EP-01 (Universal Entity data model, auth framework, server-side RPC+RLS architecture, core platform services, design system) ; EP-02 (verified entities, two-tier taxonomy, trade verification gate, KYC framework, unified multi-currency financial profile, escrow & milestone infrastructure, bound payouts, dispute framework, portfolio display) |

Conforms to `documents/Context/AGENT.md:1-18` (Bounded Scope, Separation of Concerns, Server-Side Enforcement Rule 4, Deterministic Core Supremacy, Rule 2 Trade Verification Gate, Rule 3 Financial Guardrails, Rule 5 Visual Identity), `documents/Context/ARCHITECTURE.md:39-173`, and `documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md` Domain Separation.

---

## 2. Engineering Objectives

1. **Establish the Professional Services Marketplace Database Foundation** — Create server-side tables and RPC+RLS for service listings, service engagements, and marketplace metadata bound to `industries→professions` taxonomy and `trade_verification_status`.
2. **Build the Contract & Milestone Engagement Engine** — Implement the universal 2-party contract lifecycle (draft → offer → active → milestone tracking → completion → closure) with escrow linkage modeled on `financial_escrow:191-228` + `financial_escrow_milestones:232-257`.
3. **Implement Deterministic Ranking & Matching** — Deliver the server-side ranking/matching algorithm in `lib/engine/recommendation_engine` / `lib/engine/matching_engine` that orders discovery results by verifiable signals (verification tier, rating, completion rate, recency, profession relevance) — never AI-overridden per `AGENT.md:7`.
4. **Deliver Search & Discovery Infrastructure** — Build full-text search, filtering, pagination, and client-side `lib/engine/search_engine` indexing for profession-aware discovery.
5. **Build Escrow Release on Verified Milestone Completion** — Orchestrate escrow state transitions (`funded → partially_released → released`) via milestone verification (client acceptance, evidence, review-period expiry) through existing `financial_escrow_*` RPCs — zero client-side financial math per `AGENT.md:13`.
6. **Deliver Double-Blind Review & Rating System** — Enforce server-side rule: neither party's review disclosed until both submit or timeout, then aggregated atomically.
7. **Build Encrypted Messaging & Communication** — Provide conversation-scoped, RLS-protected messaging with Realtime delivery and at-rest encryption via `lib/core/security/crypto/aes_cipher.dart`.
8. **Build Scheduling & Appointment Management** — Provide availability, booking, rescheduling, and cancellation workflows linked to contracts.
9. **Integrate Portfolio & Proof-of-Work with Service Context** — Extend `EP-02-19` portfolio (`lib/systems/portfolio`) so service listings surface linked portfolio evidence.
10. **Deliver Financial Reporting & Earnings Visibility** — Surface server-computed earnings, held/available balances, and transaction history via read-only RPCs over `financial_transactions:149-186`.
11. **Extend Structured Dispute Resolution to Service Engagements** — Bind `dispute_cases` to `service_contracts`/`escrow` with automatic escrow freeze on filing.
12. **Orchestrate Lifecycle Notifications & Validate Phase** — Fire reliable events for contract, escrow, review, message, and scheduling transitions via `lib/core/notifications` and validate EP-04 readiness.

---

## 3. Technical Goals

| Goal | Target |
|---|---|
| Server-side transaction enforcement | All service, contract, milestone, escrow-release, review aggregation, and earnings calculations execute via PostgreSQL RPC+RLS (`security invoker`, `AGENT.md:13`) — client is unprivileged presentation |
| Trade verification gate | `trade_verification_status != APPROVED` → `service_listing.create`, `contract.offer/accept` blocked server-side; verified enforcement test covers bypass attempt |
| Deterministic ranking | Ranking formula is auditable SQL/plpgsql in `lib/engine/recommendation_engine`, deterministic, explainable, covers 100% of discovery ordering — AI may *enhance display* only, never override order per `AGENT.md:7` |
| Double-blind integrity | Reviews stored with `is_revealed=false` until condition met; reveal is single atomic transaction; disclosure-before-condition is impossible per RLS+RPC |
| Messaging security | Conversation membership RLS, message RLS self-scoped, encryption-at-rest for body, no plaintext exposure to non-participants; Realtime subscription is RLS-filtered |
| Escrow lifecycle integrity | Milestone release debits `held_balance` → credits payee `available_balance` + writes `financial_transactions` + `financial_audit_trail` atomically; no held-fund release without verified milestone completion |
| Search correctness | Full-text ranking + taxonomy + rating + availability filters return paginated, RLS-scoped results; client never bypasses server filter |
| Earnings truth | Earnings dashboards read from server-aggregated RPCs over immutable ledger; no client-side summation determines settlement |
| Visual identity compliance | All EP-03 UI consumes `Theme.of(context).colorScheme` / `AppThemeExtension` + `TextTheme` per `documents/Context/VISUAL-IDENTITY.md:3-250`; hardcoded `Colors.*`/hex/fontFamily fails DoD per `AGENT.md:18` |
| Test coverage | pgTAP enforcement tests for every new RPC/RLS + unit/widget/integration tests for every new system; financial and review paths require exhaustive edge-case matrices |
| Performance | Discovery lists paginated (cursor/keyset), search indexed with GIN; Realtime messaging with backpressure; no N+1 over contracts/milestones |

---

## 4. Technology Stack (Confirmed — Carried from EP-01/EP-02)

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart SDK `^3.12.2`) |
| Backend-as-a-Service | Supabase (PostgreSQL + Auth + RPC + RLS + Realtime + Storage + Edge Functions) |
| HTTP Client | `dio:5.11.0` with `auth_interceptor:lib/core/api/api_client/auth_interceptor.dart`, `error_interceptor`, `retry_interceptor` |
| Routing | `go_router:17.5.0` with SEO-clean URLs (`/s/:profession_slug/:service_id`, `/contracts/:id`) per `ARCHITECTURE.md:148-152` |
| State Management | `provider:6.1.5` + `lib/data/providers/*` |
| Local Storage | `hive:2.2.3` + `lib/core/database/*` (`EP-01-11`) ; `lib/core/cache/lru_cache.dart` for taxonomy/search caches |
| Secure Storage | `flutter_secure_storage:11.0.0` + `lib/core/storage/secure_storage.dart` |
| Monitoring | `sentry_flutter:9.27.0` + `lib/core/monitoring/*` |
| CI/CD | GitHub Actions (`EP-01-04`) |
| Code Quality | `flutter_lints:6.0.0`, `dart analyze`, `flutter test` |
| Storage | Supabase Storage (buckets: `credential-documents`, `profile-avatars`, `portfolio-items` from `EP-02-06` + new `service-listing-media` bucket) |
| Financial Rails | Existing `lib/integrations/payment_gateways/*` abstraction (Paystack/Flutterwave + NIBSS) — EP-03 reuses, not replaces |
| Realtime | Supabase Realtime (for messaging + contract lifecycle events) |
| Security Crypto | `cryptography:2.7.0` + `crypto:3.0.3` (`lib/core/security/crypto/aes_cipher.dart`) |

---

## 5. Required Systems, Modules & Components

| System / Module | Location | Purpose |
|---|---|---|
| Service marketplace schema & RPCs | `supabase/migrations/*_service_marketplace_schema.sql` + pgTAP `supabase/tests/database/*_service_marketplace_*.sql` | Tables `service_listings`, `service_listing_media`, `service_favorites`; RLS + RPC for CRUD, publish/unpublish, trade-gate enforcement |
| Contract & engagement schema & RPCs | `supabase/migrations/*_service_contract_schema.sql` | Tables `service_contracts`, `contract_milestones` (linking `financial_escrow_milestones`), `contract_events`; lifecycle state machine + escrow linkage |
| Review & rating schema & RPCs | `supabase/migrations/*_service_review_schema.sql` | Tables `service_reviews`, `service_review_aggregates`; double-blind reveal RPC + aggregate recomputation |
| Messaging & conversation schema | `supabase/migrations/*_service_messaging_schema.sql` | Tables `conversations`, `conversation_participants`, `messages`; RLS + Realtime policies, encrypted body column |
| Scheduling & availability schema | `supabase/migrations/*_service_scheduling_schema.sql` | Tables `availability_slots`, `appointments`, `appointment_events`; slot generation + conflict detection RPCs |
| Storage bucket for service media | Supabase Storage + RLS (`service-listing-media`) | Service cover images, milestone evidence attachments; owner-write, participant-read policies |
| Deterministic ranking & matching engine | `lib/engine/recommendation_engine/*` + `lib/engine/matching_engine/*` | Server RPC `service_ranking_search` implementing verifiable ranking formula; client sequencing helpers (no order override) |
| Search infrastructure | `lib/engine/search_engine/*` + server FTS (`tsvector`/`tsquery`) | Server FTS + GIN indexes, filter composition, pagination; client offline index hydrator for taxonomy/search cache |
| Marketplace data layer | `lib/data/entities/service_listing.dart`, `lib/data/models/service_listing_dto.dart`, `lib/data/mappers/*`, `lib/data/datasources/remote/supabase_service_*`, `lib/data/repositories/*`, `lib/data/providers/marketplace_*` | Full vertical slice for services, contracts, reviews, messages, appointments |
| Service listing management | `lib/systems/marketplace/services/service_listing_service.dart`, `screens/*`, `widgets/*` | Create/edit/publish/unpublish/listings with media upload via `lib/core/storage/supabase_storage_service.dart` |
| Discovery & search experience | `lib/systems/marketplace/*` + `lib/workspace/profession_registry/*` | Browse by industry→profession, filtered search, ranked results feeding `HivorrCard`, `HivorrChip`, responsive scaffolds |
| Contract & milestone system | `lib/systems/documents/*` + `lib/systems/marketplace/*` | Offer/accept/complete milestone UI, contract timeline, evidence submission; drives `financial_escrow_*` RPCs |
| Review & rating system | `lib/systems/reviews/*` (`services/review_service.dart`, `widgets/double_blind_review_*`) | Submit review, blind-until-reveal, aggregate display, rating distribution |
| Encrypted messaging system | `lib/systems/communication/*` (`services/messaging_service.dart`, `screens/conversation_*`) | Conversation list, message thread, Realtime subscription, encryption hooks |
| Scheduling system | `lib/systems/scheduling/*` | Availability editor, booking flow, appointment calendar, reschedule/cancel |
| Portfolio service integration | `lib/systems/portfolio/*` (`services/professional_profile_service.dart` extension) | Link `portfolio_items` to `service_listings`; proof-of-work carousel on listing detail |
| Financial reporting | `lib/systems/finance/*` + `lib/systems/analytics/*` | Earnings visibility screens aggregating server RPCs over `financial_transactions`/`financial_balances` |
| Dispute integration | `lib/systems/support/*` (`services/dispute_service.dart` extension) | File dispute bound to contract/escrow, evidence via `lib/core/storage/*`, escrow-freeze integration |
| Notifications orchestration | `lib/core/notifications/*` + `supabase/templates/*` extensions | Contract/milestone/message/booking/review/dispute events → local + push |
| Public routes & SEO | `lib/app/router/app_router.dart`, `lib/app/router/route_paths.dart`, `lib/app/router/route_names.dart` + `lib/systems/portfolio/seo/*` | Clean URLs `/s/:slug/:id`, `/contracts/:id`, `/messages/:id`; web-manifest + meta for discoverability |
| Shared UI compliance | `lib/shared/widgets/*`, `lib/shared/layouts/*`, `lib/app/theme/*` per `VISUAL-IDENTITY.md` | `HivorrButton`/`HivorrCard`/`HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState` throughout |

Not expanding beyond EP-03: no `lib/systems/local_commerce`, `lib/systems/logistics_dispatch`, `lib/ai/*` intelligence, `lib/systems/business_management` B2B, or EP-04 3-party orchestration.

---

## 6. Recommended Engineering Development Order

**Stage 1 — Marketplace Server Schema Foundation (unblocks all EP-03 work):** `EP-03-01`, `EP-03-02`, `EP-03-03`, `EP-03-04`, `EP-03-05` — four parallelizable schema tracks plus media bucket config; `03-02` depends on `03-01` for `service_listing` FK; `03-03/04/05` depend on `03-02` contract context but schema creation can be parallelized.

**Stage 2 — Deterministic & Search Engines (must precede discovery UI):** `EP-03-06`, `EP-03-07` — server ranking RPC + FTS indexes before any client discovery consumes them (`AGENT.md:7` determinism).

**Stage 3 — Service Listing & Discovery (first user-visible marketplace):** `EP-03-08`, `EP-03-09`, `EP-03-15`, `EP-03-19` — listing CRUD → ranked discovery → portfolio linkage → SEO routes. Depends on Stage 1+2 (`EP-01` router + `EP-02` taxonomy engine).

**Stage 4 — Transaction Core (contract + escrow):** `EP-03-10`, `EP-03-11` — contract creation linked to discovery, then milestone-verified escrow release (reuses `EP-02-04` escrow). Most financially sensitive stage per `AGENT.md:13`.

**Stage 5 — Trust & Coordination (reviews, messaging, scheduling, disputes):** `EP-03-12`, `EP-03-13`, `EP-03-14`, `EP-03-17` — double-blind reviews (post-contract), Realtime messaging (contract-scoped), scheduling (contract-bound), and dispute freeze — parallelizable after contracts exist.

**Stage 6 — Financial & Event Layer:** `EP-03-16`, `EP-03-18` — earnings visibility reads ledger; notifications fan out from all prior lifecycle events.

**Stage 7 — Validation:** `EP-03-20` — end-to-end marketplace validation; EP-04 readiness check.

---

## 7. Internal and External Dependencies

### Internal Dependencies

| Item | Depends On | Rationale |
|---|---|---|
| EP-03-01 | EP-01-06 (Universal Entity), EP-02-02 (taxonomy RPCs), EP-02-03 (verification status) | Service listings must validate profession taxonomy + trade gate |
| EP-03-02 | EP-03-01, EP-02-04 (financial_escrow schema) | Contracts reference service_listing + create/link escrow rows |
| EP-03-03 | EP-03-02 | Reviews bound to completed service_contracts; double-blind state references contract participants |
| EP-03-04 | EP-03-02 | Conversations scoped to contract/service participants via `conversation_participants` |
| EP-03-05 | EP-03-02 | Appointments linked to `service_contracts.id` |
| EP-03-06 | EP-03-01, EP-02-11 (trade verification) | Ranking inputs: verification tier, aggregates, taxonomy relevance |
| EP-03-07 | EP-03-01, EP-03-06 | Search uses FTS indexes on listings + consumes ranking RPC ordering |
| EP-03-08 | EP-03-01, EP-02-06 (storage buckets), EP-02-07 (taxonomy engine), EP-01-16 (design system) | Client listing CRUD + media upload + profession picker |
| EP-03-09 | EP-03-07, EP-03-08, EP-03-15 | Discovery reads ranked search; listing creation must exist for searchable data |
| EP-03-10 | EP-03-02, EP-03-08, EP-03-11, EP-01-07 (API layer) | Contract offer/accept flow + milestone definition linked to escrow |
| EP-03-11 | EP-03-02, EP-02-04 (escrow fund/release RPCs), EP-03-10 | Milestone completion → `financial_escrow_milestone_complete` + `financial_escrow_release` |
| EP-03-12 | EP-03-03, EP-03-10 | Client review submission/reveal after contract reaches reviewable state |
| EP-03-13 | EP-03-04, EP-01-12 (sync engine for offline queue), EP-01-18 (notifications) | Realtime messaging with offline queue + push on new message |
| EP-03-14 | EP-03-05, EP-03-10 | Booking UI consumes availability slots, creates appointments under contract |
| EP-03-15 | EP-02-06, EP-02-19, EP-03-01, EP-03-08 | Listing detail embeds portfolio items via existing portfolio service |
| EP-03-16 | EP-02-04, EP-03-02, EP-03-11 | Earnings aggregation reads immutable `financial_transactions` linked to contracts |
| EP-03-17 | EP-02-05 (dispute schema), EP-03-02, EP-03-11 | Dispute filing freezes escrow via `dispute_file` → escrow hold trigger |
| EP-03-18 | EP-03-10, EP-03-11, EP-03-13, EP-03-14, EP-01-18 | Event fan-out for every lifecycle transition |
| EP-03-19 | EP-03-08, EP-01-15 (router), EP-02-19 (SEO pattern) | Public listing URLs reuse `go_router` SEO pattern from portfolio (`/p/:slug/:id`) |
| EP-03-20 | All EP-03 items | Phase gate |

### External Dependencies

| Dependency | Type | Impact | Required For |
|---|---|---|---|
| Supabase projects (Dev/Staging/Prod) with Realtime enabled + RLS on Realtime | Infrastructure | Messaging & contract-status Realtime subscriptions fail without it | EP-03-04, EP-03-13 |
| Supabase Storage bucket provisioning (`service-listing-media`) with RLS | Infrastructure | Blocks `EP-03-08` media upload & `EP-03-15` proof evidence | EP-03-01 (schema), EP-03-08 |
| Supabase Edge Functions (optional — webhook/escrow-state side-effects) | Infrastructure | If milestone evidence requires async verification, functions carry it | EP-03-11 (if deferred verification needed) |
| Admin moderation tooling (existing `EP-02-11` review gate extended) | Tooling | Disputed contracts / reported listings need admin visibility | EP-03-17 |
| `file_picker:12.3.0` + `file_picker_web:3.1.0` | Package | Media/evidence picking on web + mobile | EP-03-08, EP-03-10 |
| Connectivity telemetry `connectivity_plus:6.1.0` | Library | Offline message queue replay gating | EP-03-13 |
| No new payment provider credentials — EP-02 `Paystack`/`Flutterwave` abstraction reused | Integration | Escrow funding path already provisioned | EP-03-11 |

---

## 8. Risks, Assumptions & Engineering Considerations

### Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Ranking formula perceived as opaque or biased | Catastrophic — trust erosion per `VISION.md`; regulatory scrutiny | **Extremely High** reasoning. Formula in versioned SQL + documented weights (verification tier > rating > completion rate > recency > relevance); auditable `EXPLAIN`; no hidden coefficients; pgTAP asserts deterministic ordering; `AGENT.md:7` AI ban enforced by code review |
| Escrow release on unverified milestone → fund loss | Catastrophic — direct financial loss | Server-side state machine only (`financial_escrow.status` enum + `disputed` guard); milestone `released` transition requires `completed` + payer or system confirmation; client cannot call release without RPC; double-entry ledger + `financial_audit_trail:386-412` for every mutation; edge-case matrix (partial, refund, disputed hold) reviewed per `EP-02-04` |
| Double-blind timing oracle (infer other party's submission) | High — retaliatory behavior reintroduced | Polling/count endpoint returns only `you_have_submitted` boolean, not counterparty state; reveal RPC checks `both_submitted OR expiry` atomically; no leaked `updated_at` on aggregate until reveal; widget tests assert blind state |
| Trade-gate bypass via direct `service_listings` insert | High — unverified supply | `BEFORE INSERT` trigger + RPC guard: `trade_verification_status == APPROVED` required; direct table INSERT blocked by RLS + column grants (authenticated cannot set `verification_override`); pgTAP bypass attempt test |
| Message RLS leakage (non-participant reads conversation) | High — privacy breach | `conversations` RLS checks `exists (select 1 from conversation_participants where conversation_id=id and entity_id=auth.uid())`; `messages` RLS joins participant check; Realtime publication RLS-filtered; `supabase/tests/database/*_rls_leakage_matrix.sql` pattern replicated |
| Scheduling timezone/double-booking race | Medium — operational failure | All timestamps `timestamptz`; slot generation server-side; booking RPC uses `FOR UPDATE` + exclusion constraint on `appointments(slot_id, status)`; idempotency key per booking attempt |
| Search relevance degradation at scale | Medium — discoverability loss | GIN indexes on `service_listings.search_vector`; ranking RPC uses keyset pagination; client never fetches unbounded result sets; performance benchmark in `EP-03-20` (p95 < 400ms for filtered search) |
| Financial earnings computed client-side | High — settlement divergence | Earnings screen calls read-only aggregation RPC (`service_earnings_summary`) over `financial_transactions`; client summation is display-only and CI-linted for forbidden `financial_transactions.amount` reduce patterns |
| Realtime + offline queue divergence | Medium — message loss | Offline queue (`lib/core/sync/action_queue.dart`) persists unsent messages in `Hive`; replay on `connectivity_plus` reconnect; deduplication by `client_message_id` UUID (`uuid:4.5.1`) |

### Assumptions

1. EP-01 is `Completed` per `EP-01-20` foundation verification and EP-02 is `Completed` per `EP-02-20` trust verification — `industries/professions` seeded (`20260829090001_taxonomy_seed_data.sql`), financial schema at `20260829100004_financial_integrity_schema.sql`, storage buckets at `20260830100001_storage_buckets.sql`, portfolio at `20260913090001_portfolio_public_profile.sql` all promoted through Staging.
2. Auth framework (`lib/core/authentication/*` + `supabase_flutter:2.17.2`) provides `auth.uid()` stable for all RLS; JWT refresh via `lib/core/api/api_client/auth_interceptor.dart` is operational.
3. Supabase Realtime is available on the provisioned projects (if not, `EP-03-13` degrades to polling with `fake_async:1.3.1` tests but plan still valid — seam is abstracted behind `MessagingRealtimeDataSource` interface).
4. Currency scope remains `NGN/GHS/USD/GBP` from `financial_supported_currencies:55-62`; EP-03 does not add currency.
5. Initial marketplace operates on 2-party escrow already proven in EP-02 (`financial_escrow` states `created/funded/partially_released/released/refunded/disputed` at `EP-02-04:203-207`); no 3-party split (EP-04) enters EP-03.
6. Admin review for listings/disputes reuses `EP-02-11` tooling; a full admin console is not an EP-03 deliverable — a filtered queue screen suffices.
7. `provider:6.1.5` remains sufficient for `lib/data/providers/*` marketplace state; no new state framework introduced.

### Engineering Considerations

1. **Server-Side Enforcement is Non-Negotiable** (`AGENT.md:6,13`). Every marketplace state transition (listing publish, contract offer/accept, milestone release, review reveal) is `SECURITY INVOKER` RPC with RLS. REST `INSERT` on `service_listings`/`service_contracts` is `REVOKE`d for `authenticated` except via RPC-limited column grants (mirrors `financial_balances:521-524` pattern).
2. **Deterministic Core Supremacy** (`AGENT.md:7` + `ARCHITECTURE.md:157-159`). Ranking resides in `lib/engine/recommendation_engine` SQL, versioned. `lib/ai/*` is excluded from EP-03 — AI suggestion may reorder *presentation grouping* but never RPC result order; code review checks for banned ranking override.
3. **Taxonomy Is Universal.** `service_listings.profession_id → professions.id → industries.id` FK chain ensures any future industry (per `Engineering-Execution-Generation-Principle.md:57-58`) adds listings without schema change — new industry = seed insert, not migration.
4. **Legal Name Is Financial Anchor.** Escrow / payout identity still anchors to `entity_profiles.legal_name` guarded at `20260821090006_entity_profile_legal_name_guard.sql` — EP-03 contracts reuse, not replace, this anchor.
5. **Escrow Is Provider-Agnostic.** `financial_escrow` state lives in Hivorr DB; `lib/integrations/payment_gateways/payment_gateway.dart` abstraction handles fund movement only (`ARCHITECTURE.md:149-153`).
6. **Double-Entry & Audit.** Contract-linked financial mutations produce paired `financial_transactions` rows + `financial_audit_trail` entry in one transaction — no client-held balance.
7. **Visual Identity Binding** (`VISUAL-IDENTITY.md:1-250` + `AGENT.md:18`). Every EP-03 screen uses `HivorrTheme`, `HivorrCard` (`lib/shared/widgets/hivorr_card.dart`), `HivorrContentPane` (`lib/shared/layouts/hivorr_content_pane.dart` ≈720dp max, 16dp/24dp gutters), `HivorrEmptyState`/`HivorrErrorState`/`HivorrLoadingState`, and token spacing/elevation/motion — any `Colors.*`/raw hex/`fontFamily` per-widget fails DoD.
8. **Domain Separation.** EP-03 builds universal platform primitives (listings, contracts, reviews, messaging, scheduling). No Building & Construction / Legal / Healthcare workflow specialization is introduced — industries remain independent modules per `Engineering-Execution-Generation-Principle.md:20-31`.
9. **Idempotency & Offline.** Contract/milestone/message mutations carry `Idempotency-Key: uuid v4` via `lib/core/sync/sync_action.dart`; duplicate replay is no-op server-side.

---

## 9. Expected Phase Outcome

A functioning 2-party marketplace where verified professionals (via `EP-02` trade gate) can publish service listings bound to the two-tier taxonomy, be discovered through deterministic, auditable ranking and full-text search, form milestone-backed contracts whose funds are protected in provider-agnostic escrow and released only on verified completion, exchange encrypted, RLS-scoped messages, schedule appointments, accrue double-blind reputation, resolve service disputes with escrow freeze, and view server-derived earnings — validating the core marketplace model under real transaction conditions and unblocking EP-04 without exposing proprietary logic, financial calculations, or ranking coefficients to the client.

---

## 10. Phase Completion Criteria

| Criterion | Verification |
|---|---|
| Service marketplace schema live: `service_listings`, `service_listing_media`, `service_favorites` + RLS +  `service_listing_create/update/publish/unpublish` RPCs enforce trade gate | `supabase/tests/database` pgTAP + RPC integration tests; bypass attempt test fails as expected |
| Contract & milestone schema live: `service_contracts`, `contract_milestones`, `contract_events` with state machine (`draft→offered→active→completed→closed/disputed`) + escrow linkage | Migration verify + pgTAP state-transition matrix |
| Review schema live: `service_reviews`, `service_review_aggregates` with `review_submit` / `review_reveal` atomicity; `is_revealed` invariant verified | pgTAP double-blind tests |
| Messaging schema live: `conversations`, `conversation_participants`, `messages` + Realtime publication policies; encryption-at-rest applied | pgTAP RLS + leakage matrix; Realtime subscription test for participant vs non-participant |
| Scheduling schema live: `availability_slots`, `appointments` with exclusion constraint + booking RPCs | pgTAP booking race + timezone test |
| `service-listing-media` Storage bucket provisioned with RLS (owner-write, participant-read for contract evidence) | Storage policy test per `20260830100001_storage_buckets.sql` pattern |
| Deterministic ranking RPC `service_ranking_search` returns auditable, deterministic ordering; AI does not override result order | Unit test with fixed fixtures; code-review gate asserts no ranking override |
| FTS discovery: `search_vector` + GIN + `service_search` RPC returns filtered, paginated, ranked results scoped by RLS | Integration test: seed listings → query → ranked page |
| Service listing management: create/edit/publish with profession selection via `lib/workspace/profession_registry/taxonomy_engine.dart`, media upload with progress | Widget + integration test; trade-gate blocked client path test |
| Service discovery screens: browse industry→profession, filter, search, ranked list, listing detail with portfolio carousel | Widget tests + golden visual on mobile + web; theme-token assertions |
| Contract lifecycle: offer → accept → milestone tracking → evidence → client acceptance → milestone-verified escrow release via `financial_escrow_milestone_complete`/`financial_escrow_release` | E2E integration test: contract → milestone complete → balances atomically moved + ledger row + audit row |
| Double-blind review: both parties submit → auto-reveal; timeout reveal; pre-reveal disclosure impossible | E2E review test + RLS probe |
| Messaging: conversation per contract, send/receive via Realtime, offline queue replay, encrypted body | Integration test: send online → receive Realtime; send offline → replay on reconnect; non-participant read blocked |
| Scheduling: availability CRUD, booking, reschedule, cancel with conflict detection | Integration test: overlapping booking rejected (`PLT005`) |
| Portfolio linkage: listing detail renders linked `portfolio_items` proof; empty state uses `HivorrEmptyState` branded slot | Widget test |
| Financial reporting: earnings summary/transaction history screens read server-aggregated RPCs over `financial_transactions` — no client math determines settlement | Integration test + static lint forbidding client-side ledger reduce for settlement |
| Service-engagement dispute: `dispute_file` on contract auto-freezes escrow (`disputed`); `dispute_resolve` triggers release/refund | E2E dispute test: file → escrow `disputed` → resolve → ledger reflects outcome |
| Lifecycle notifications: push+local for contract, milestone, review, message, appointment events | Notification integration test (foreground + background) |
| Public routes: `/s/:profession_slug/:service_id` + `/contracts/:id` deep-linkable, SEO-friendly; responsive via `HivorrResponsiveScaffold` | Router integration test + SEO meta check |
| All new tables RLS default-deny; no `authenticated` direct `INSERT` bypass where RPC is canonical | `supabase/tests/database/00*_security_posture_audit.sql` style pgTAP audit |
| Zero financial/matching logic in client code; no hardcoded colors/fonts | `dart analyze` + static scan + `ColorScheme.primary == #0B6E99` assertion (per `VISUAL-IDENTITY.md:84`) |
| All EP-03 items at `Completed` | Phase plan audit |

---

## 11. Engineering Roadmap Items

### EP-03-01: Professional Service Marketplace Schema & Server-Side Enforcement

| Attribute | Detail |
|---|---|
| **Objective** | Create `service_listings` (FK `entity_id→entities`, `profession_id→professions`, `status` enum `draft/published/paused/archived/reported`, `pricing_type`, `price_min/max`, `currency_code`, `search_vector`, `avg_rating` cache, `is_trade_verified_cache`), `service_listing_media` (bucket path, sort), `service_favorites` + `supabase/storage/service-listing-media` bucket RLS. RPCs: `service_listing_create/draft`, `service_listing_update`, `service_listing_publish`, `service_listing_unpublish`, `service_listing_get`, `service_listing_list_mine`, `service_favorite_toggle`. All `SECURITY INVOKER`, envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999` per `20260829100004`), trade gate enforced (`entity_professions.trade_verification_status == APPROVED` via `20260915090001_onboarding_authoritative_state.sql` source). |
| **Engineering Purpose** | The listing is the atomic marketplace unit. Without server-enforced taxonomy binding, trade-gate, and FTS vector, discovery, ranking, and contract linkage have no trustworthy foundation. |
| **Dependencies** | EP-01-06, EP-02-02, EP-02-03, EP-01-07, EP-02-06 |
| **Expected Outcome** | Migrations + RLS (anon no read, authenticated self-covers own listings + public read for `published` only, service_role full). pgTAP: trade-gate bypass fails `PLT005`, anon leakage fails, `published` listings publicly readable, drafts owner-only. Bucket RLS: owner write, public read for `published` listing media. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-03-02: Service Contract & Milestone Engine Schema & Lifecycle RPCs

| Attribute | Detail |
|---|---|
| **Objective** | Tables `service_contracts` (`service_listing_id`, `client_entity_id`, `professional_entity_id`, `status` state machine `draft/offered/active/completed/disputed/closed/cancelled`, `escrow_id→financial_escrow.id` nullable until funded, `total_amount`, `currency_code`), `contract_milestones` (FK `contract_id`, links `escrow_milestone_id` where funded via escrow), `contract_events` (append-only state log). RPCs: `service_contract_offer`, `service_contract_accept`, `service_contract_cancel`, `service_contract_complete_milestone` (submit evidence), `service_contract_verify_milestone` (client acceptance / expiry), `service_contract_close`. All state transitions emit `contract_events` + `financial_audit_trail` when escrow-linked. |
| **Engineering Purpose** | Universal 2-party engagement primitive reused by EP-04 logistics only as supervision. Milestone verification is the escrow-release precondition — correctness here prevents fund misrelease. |
| **Dependencies** | EP-03-01, EP-02-04 |
| **Expected Outcome** | Full lifecycle pgTAP matrix (offer→accept, accept without offer fails, double-accept fails, milestone verify before complete fails, disputed contract cannot release). Escrow linkage constraint: `active` contracts requiring funding have non-null `escrow_id` after `financial_escrow_create` (service_role-only). |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-03-03: Double-Blind Review & Rating Schema & Server-Side Rules

| Attribute | Detail |
|---|---|
| **Objective** | Tables `service_reviews` (`contract_id` unique per `(contract_id, reviewer_entity_id)`, `reviewee_entity_id`, `rating 1-5`, `comment`, `is_revealed boolean default false`, `revealed_at`), `service_review_aggregates` (materialized per professional+profession: `avg_rating`, `count`, `distribution`). RPCs: `service_review_submit`, `service_review_get_mine`, `service_review_get_for_listing` (returns only `is_revealed=true`), `service_review_reveal_if_ready` (internal). Trigger/RPC rule: `is_revealed` flips to `true` atomically only when `count(review is not null)=2` for the contract or `review_deadline < now()` via scheduled check. Aggregate recomputation in same transaction as reveal. |
| **Engineering Purpose** | Eliminates retaliatory rating per `Business-Roadmap:64-73` Trust layer #3. Blind-until-both is a security invariant, not UX polish — must be RLS+RPC enforced, never client-evaluated. |
| **Dependencies** | EP-03-02 |
| **Expected Outcome** | pgTAP: submitter alone sees `you_submitted=true` but not counterparty `revealed`; pre-reveal `GET` returns empty body/rating; post-both `GET` returns both; aggregate `avg_rating` matches `SELECT avg(rating)` over revealed rows; race-submit concurrent test passes via `FOR UPDATE`. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-03-04: Encrypted Messaging & Conversation Schema & Server-Side Rules

| Attribute | Detail |
|---|---|
| **Objective** | Tables `conversations` (`contract_id unique` per 1:1 service engagement), `conversation_participants` (`conversation_id`, `entity_id`, `joined_at`, `last_read_at`), `messages` (`conversation_id`, `sender_entity_id`, `body_encrypted text`, `body_preview text` 120-char redacted preview for notifications maybe, `client_message_id uuid unique`, `created_at`). RLS: participant-only read/write; `messages` `SELECT` checks `exists (select 1 from conversation_participants where ...)`. Realtime publication on `messages` filtered by participant. RPCs: `conversation_ensure_for_contract`, `message_send` (encrypts via `pgp_sym_encrypt` or client-supplied ciphertext validated), `conversation_list`, `message_list` (cursor pagination). PII redaction uses `lib/core/logging/pii_redactor.dart`. |
| **Engineering Purpose** | Marketplace trust requires private negotiation with auditability. Participant-scoped RLS + Realtime is the secure real-time fabric for EP-03 contracts and is reused by EP-04 multi-party threads. |
| **Dependencies** | EP-03-02, EP-01-10 (security), EP-01-18 (notifications) |
| **Expected Outcome** | pgTAP leakage matrix (non-participant `SELECT` returns 0 rows; Realtime subscription for non-participant receives 0 events). `client_message_id` deduplicates offline replay. Load test: 100 concurrent Realtime subscribers per conversation with no cross-talk. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-05: Scheduling & Availability Schema & Server-Side Rules

| Attribute | Detail |
|---|---|
| **Objective** | Tables `availability_slots` (`entity_id`, `profession_id`, `weekday`, `start_time`, `end_time`, `slot_duration_min`, `timezone`), `appointments` (`contract_id`, `slot_id`, `starts_at timestamptz`, `ends_at timestamptz`, `status` enum `pending/confirmed/completed/cancelled/rescheduled`, `reschedule_of uuid`), `appointment_events`. Exclusion constraint `EXCLUDE USING gist (professional_entity_id WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status in ('pending','confirmed'))` prevents double-booking. RPCs: `availability_upsert`, `availability_list`, `appointment_book`, `appointment_reschedule`, `appointment_cancel`. All writes `FOR UPDATE` on slot. |
| **Engineering Purpose** | 2-party services depend on calendar coordination (legal consultation, artisan visit). Availability is contract-bound and must be globally consistent despite concurrent booking — server exclusion guarantees no double-book. |
| **Dependencies** | EP-03-02 |
| **Expected Outcome** | pgTAP: overlapping `appointment_book` second call returns `PLT005` conflict; timezone conversion preserves wall-clock; `cancelled` slots release for rebooking. Repo tests assert `timestamptz` round-trip. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-06: Deterministic Ranking & Matching Engine

| Attribute | Detail |
|---|---|
| **Objective** | Server RPC `service_ranking_search(p_profession_id uuid, p_query text, p_filters jsonb, p_cursor jsonb)` implementing documented formula: `score = w_verify * kyc_tier_weight + w_rating * bayesian_avg + w_completion * completion_rate + w_recency * decay(now() - published_at) + w_relevance * ts_rank + w_activity * login_recency`. Weights stored in `public.platform_config` table (service-role writable), not hardcoded. Code in `lib/engine/recommendation_engine/ranking_formula.dart` mirrors SQL for offline explainability but never decides order client-side. `lib/engine/matching_engine` reserved for EP-04 spatial routing (left as seam). |
| **Engineering Purpose** | **Core platform intelligence** per `AGENT.md:6` — marketplace fairness, auditability, and defensibility. Deterministic ordering must be provable, explainable, and invulnerable to client manipulation. |
| **Dependencies** | EP-03-01, EP-02-11 (trade verification), EP-03-03 (aggregates) |
| **Expected Outcome** | Versioned SQL in migration, `platform_config` row (`service_ranking_weights`) editable by service_role only. pgTAP: fixed 10-listing fixture yields deterministic rank array; weight-tweak shifts order as documented; `EXPLAIN` shows index usage. Widget test asserts results render in RPC order (no client resort). |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-03-07: Search & Discovery Infrastructure (Full-Text + Filtering + Caching)

| Attribute | Detail |
|---|---|
| **Objective** | Add `search_vector tsvector` trigger on `service_listings(title || description || profession name)` with `GIN` index; server `service_search` RPC composing `to_tsquery` + `ts_rank`, filters `{profession_id, price_range, rating_min, is_verified_only, availability_date}`, cursor pagination (`(score, id)`). Client `lib/engine/search_engine/service_search_index.dart` hydrates `Hive` cache of taxonomy + recent listings for offline browse; `lib/core/cache/lru_cache.dart` for result window. `lib/data/datasources/remote/supabase_service_search_remote_data_source.dart` is the single search seam. |
| **Engineering Purpose** | Discovery is frequency driver per `Business-Roadmap:219-226`. Search must be ranking-aware, filterable, paginated, and offline-resilient without duplicating ranking logic to the client. |
| **Dependencies** | EP-03-01, EP-03-06 |
| **Expected Outcome** | `GIN` index live; integration test: `query='legal drafting'` returns ranked hits with `ts_rank` tie-break; filter `rating_min=4.5` excludes `<4.5`; cursor pagination returns no overlap; cache hydrates from `Hive` when offline. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-08: Service Listing Management System (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Build `lib/systems/marketplace/services/service_listing_service.dart` + `lib/data/repositories/service_listing_repository*` + `lib/data/providers/marketplace_providers` covering draft/create/update/publish/unpublish, media upload via `lib/core/storage/supabase_storage_service.dart` with `lib/core/platform/platform_file_picker.dart` progress + `lib/core/storage/storage_validators.dart` (size/type). Screens: `service_listing_form_screen.dart`, `service_listing_media_screen.dart`, `my_listings_screen.dart`. Profession selection reuses `lib/workspace/profession_registry/widgets/profession_picker.dart` + `lib/workspace/profession_registry/taxonomy_engine.dart`. Applies `HivorrContentPane`, `HivorrCard`, `HivorrButton` (>=48dp), `HivorrEmptyState` for no-listings. |
| **Engineering Purpose** | Supply-side creation flow. Must enforce client-side validation (price >0, profession selected) while trade-gate remains server-authoritative. |
| **Dependencies** | EP-03-01, EP-03-06, EP-02-07, EP-02-08, EP-01-16, EP-02-06 |
| **Expected Outcome** | Unit tests for repository mapper (`service_listing ↔ dto`); widget tests for form validation, trade-gate blocked publish shows `HivorrErrorState` with guidance; media upload progress indicator tested with mock `supabase_storage_service`. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-09: Service Discovery & Search Experience (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Screens `marketplace_discovery_screen.dart` (industry→profession browser), `marketplace_search_screen.dart` (query + chips for `profession`, `price_range`, `rating`, `verified_only`), `service_detail_screen.dart` (header, pricing, verification badges `TradeVerifiedBadge`, portfolio carousel, `Book/Request Proposal` CTA). Consumes ranked `service_ranking_search` — no client re-sort. Uses `lib/shared/layouts/hivorr_responsive_scaffold.dart` + `hivorr_screen_scaffold.dart`, `HivorrChip` filters, `HivorrLoadingState(HivorrLoader)` pulse. Caches taxonomy search via `lib/data/datasources/local/taxonomy_local_data_source.dart`. |
| **Engineering Purpose** | Consumer-facing discovery that proves `AGENT.md:7` marketplace model. Frequency and cross-role engagement (`Business-Roadmap:247-248`) depend on frictionless discovery. |
| **Dependencies** | EP-03-07, EP-03-08, EP-03-15, EP-01-16, EP-02-07 |
| **Expected Outcome** | Widget tests assert ranked order matches RPC payload; filter-chip state reflected in RPC `p_filters`; empty query shows recently-published ranked defaults; detail screen CTA disabled when viewer `trade_verification_status != APPROVED` and viewer==professional (cannot hire self). |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-10: Contract Creation & Milestone Management System (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Service `lib/systems/documents/services/contract_service.dart` + screens `contract_offer_screen.dart`, `contract_detail_screen.dart`, `milestone_editor_screen.dart`, widgets `milestone_list_card` (reuse `lib/systems/finance/widgets/milestone_list_card.dart`), `contract_timeline`. Flows: consumer `Request Service` → `contract_offer` (milestones array + total), professional accept → `service_contract_accept` → auto `financial_escrow_create` (service_role via Edge Function or RPC wrapper) if amount>0. Milestone evidence upload to `service-listing-media` with `EscrowWrite CTA panel` pattern (`lib/systems/finance/widgets/escrow_write_cta_panel.dart`). |
| **Engineering Purpose** | Converts discovery into financially-protected engagement. Milestone structure must mirror `financial_escrow_milestones` 1:1 so EP-02 escrow lifecycle is reused without new financial ledger. |
| **Dependencies** | EP-03-02, EP-03-08, EP-02-04, EP-01-07 |
| **Expected Outcome** | Integration test: `offer (3 milestones sum==total)` → `accept` → `escrow_id` non-null → `milestone_list_card` reflects 3 milestones; malformed `milestones sum != total` returns `PLT003`; . |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-11: Escrow-Backed Milestone Release & Verification Orchestration

| Attribute | Detail |
|---|---|
| **Objective** | Orchestrator `lib/systems/finance/services/contract_escrow_orchestrator.dart` bridging `contract_service` milestones to `lib/systems/finance/services/escrow_service.dart` (`financial_escrow_milestone_complete`, `financial_escrow_release` at `20260829100004:1027-1077`). Rules: professional marks `milestone completed` → uploads evidence → client `verify` (accept / request revision) or `review_period` (`7d`) expires → RPC releases held→available atomically; `disputed` blocks release. Widgets: `escrow_status_badge`, `escrow_dispute_banner` reuse. Edge Function `escrow_milestone_auto_release` (cron) for expiry. |
| **Engineering Purpose** | **Most financially sensitive client item** — the only path where held funds become available. Must be atomic against `financial_transactions:149` + `financial_audit_trail:386` and gated by milestone verification (`Business-Roadmap:230`). |
| **Dependencies** | EP-03-02, EP-02-04, EP-03-10 |
| **Expected Outcome** | E2E ledger test: `escrow_funded 30000` → `milestone_completed 10000` + client `verify` → payee `available_balance +10000`, payer `held -10000`, `financial_transactions` row `escrow_release` + `conversion?` no; `disputed` contract milestone verify returns `PLT005` blocked; expiry auto-release via Edge Function test. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-03-12: Double-Blind Review & Rating Experience (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Service `lib/systems/reviews/services/service_review_service.dart` + screens `review_submit_screen.dart` (1-5 + comment), `review_reveal_screen.dart`, widget `double_blind_status_card` (states: `awaiting_yours`, `awaiting_counterparty`, `revealed`). Uses `service_review_submit/get_mine/reveal` RPCs. Aggregate `service_review_aggregates` rendered as stars + distribution on `service_detail_screen` only post-reveal. Communicates via `lib/core/notifications` on reveal. Conforms to `VISUAL-IDENTITY §9` calm empty/success/error states (`HivorrSuccessState` on submitted). |
| **Engineering Purpose** | Trust signal that compounds across transactions (`Business-Roadmap:57` sunk reputation). Blind-until-both must be UX-obvious and cryptographically honest. |
| **Dependencies** | EP-03-03, EP-03-10, EP-02-19 |
| **Expected Outcome** | Widget tests: pre-reveal viewer sees `Awaiting other party` not rating; submitter-only query returns `is_revealed=false`; after both submit, both devices receive `revealed` notification + rating now visible; average recomputes correctly. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-13: Encrypted Messaging & Real-Time Communication System (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Service `lib/systems/communication/services/messaging_service.dart` wrapping `conversation_ensure_for_contract`, `message_send/list`, `SupabaseRealtime` subscription behind `lib/data/datasources/remote/supabase_messaging_remote_data_source.dart` abstraction. Local queue `lib/core/sync/action_queue.dart` for offline send with `Hive` persistence; send deduplicated by `client_message_id`. Screens: `conversation_list_screen.dart`, `message_thread_screen.dart` (`ListView` + `HivorrTextField` + send `HivorrButton`). Encryption: `AES-GCM` via `lib/core/security/crypto/aes_cipher.dart` for `body_encrypted` (keys per conversation derived via `lib/core/security/crypto/key_derivation.dart` from session + conversation_id — forward-compatible, not persisted plaintext). Push on `new_message` via `lib/core/notifications/push/supabase_push_receiver.dart`. |
| **Engineering Purpose** | Contract-scoped coordination. Offline + Realtime hybrid ensures usability in `Business-Roadmap:29` Nigeria market unreliable connectivity without message loss. |
| **Dependencies** | EP-03-04, EP-01-12, EP-01-18, EP-01-13 |
| **Expected Outcome** | Integration test: two participants exchange 3 messages; third entity cannot `SELECT` thread; offline-sent message appears as `pending` then `sent` after reconnect (via `fake_async` + `connectivity_plus` mock); Realtime event delivers within <1s on staging. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-14: Scheduling & Appointment Management System (Client)

| Attribute | Detail |
|---|---|
| **Objective** | Service `lib/systems/scheduling/services/scheduling_service.dart` + screens `availability_editor_screen.dart` (weekday slots editor via `HivorrChip` days + `HivorrFormField` time pickers), `appointment_book_screen.dart` (calendar + slot picker), `appointment_detail_screen.dart` (reschedule/cancel). Validates `starts_at/ends_at` in local TZ but stores `timestamptz`; conflict chip shows `Slot taken`. Uses `lib/shared/helpers/hivorr_formatters.dart` for time display and `lib/core/localization` for locale. |
| **Engineering Purpose** | Service delivery requires calendar certainty. Client must surface server-conflict errors gracefully and prevent double-book optimism. |
| **Dependencies** | EP-03-05, EP-03-10 |
| **Expected Outcome** | Widget tests: availability editor saves → `availability_list` reflects slots; two concurrent booking attempts second returns `PLT005` error displayed as `HivorrErrorState` with `Pick another time` action; timezone round-trip test for Lagos vs UTC. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-15: Portfolio & Proof-of-Work Service Integration

| Attribute | Detail |
|---|---|
| **Objective** | Extend `EP-02-19` `lib/systems/portfolio/services/professional_profile_service.dart` (`supabase_portfolio_remote_data_source.dart`) so `service_listing_detail` and `professional_profile_screen.dart` carousel link/selection of `portfolio_items` as listing proof. Adds RPC `service_listing_link_portfolio_items(p_listing_id, p_portfolio_ids uuid[])` with ownership guard (entity owns both). Widget `portfolio_grid` reuse inside `service_detail_screen` with `verification_badges_row` still authoritative per `EP-02-11/12`. |
| **Engineering Purpose** | Proof-of-work converts discovery into trust (`Business-Roadmap:225`). Reusing portfolio avoids duplicating media/RLS and deepens `Universal Entity` entanglement. |
| **Dependencies** | EP-02-19, EP-02-06, EP-03-01, EP-03-08 |
| **Expected Outcome** | Integration test: create `portfolio_item` → link to `published` listing → unauth viewer sees carousel with linked items; non-owner link attempt fails `PLT001`; unlinked listing shows `HivorrEmptyState` proof placeholder with `Add portfolio` CTA (when owner). |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-16: Financial Reporting & Earnings Visibility System

| Attribute | Detail |
|---|---|
| **Objective** | Read-only RPCs `service_earnings_summary(p_currency char(3))`, `service_transaction_history(p_filters jsonb, p_cursor)` aggregating over `financial_transactions` + `financial_balances` + `service_contracts` join. Service `lib/systems/finance/services/service_earnings_service.dart` + `lib/systems/analytics/services/service_analytics_service.dart`. Screens: `earnings_dashboard_screen.dart` (available/held/pending chips via `BalanceChip`, `BalanceOverviewCard` reuse), `transaction_history_screen.dart` (ledger rows with `finance_history_badge`), `contract_earnings_detail_screen.dart`. No write RPC; no client-computed settlement. |
| **Engineering Purpose** | Professional retention driver (`Business-Roadmap:227-228`). Earnings truth must be server-derived and auditable, not self-reported. |
| **Dependencies** | EP-02-04, EP-03-02, EP-03-11, EP-01-16 |
| **Expected Outcome** | Integration test: fund 2 contracts (NGN 50k, USD 100) → release 1 milestone each → dashboard reads correct `available` per currency; transaction history paginated list shows 4 ledger rows (fund+release each); static grep finds zero `FinancialTransaction.amount` reduce used for earnings settlement. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-17: Structured Dispute Resolution for Service Engagements

| Attribute | Detail |
|---|---|
| **Objective** | Extend `EP-02-05` `dispute_cases:supabase/migrations/20260829120005_dispute_resolution_schema.sql` with FK `contract_id→service_contracts.id` (alternative to existing `escrow_id` link) and RPC `service_dispute_file(p_contract_id, p_reason, p_evidence_paths)`. Filing triggers same escrow freeze: `UPDATE financial_escrow SET status='disputed'` via trigger already at `20260829120006_dispute_withdraw_definer.sql`. Screens `dispute_filing_screen.dart` (contract-scoped), `dispute_evidence_form_screen.dart` (file_picker证据), `dispute_detail_screen` (reuse `lib/systems/support/*` + `escrow_frozen_banner.dart`). Evidence upload to `service-listing-media/dispute/<id>/`. |
| **Engineering Purpose** | Safety net for service trust (`Business-Roadmap:245`). Contract-dispute path must freeze the same provider-agnostic escrow as financial disputes — single enforcement point. |
| **Dependencies** | EP-02-05, EP-03-02, EP-03-11, EP-02-06 |
| **Expected Outcome** | E2E test: active funded contract → `service_dispute_file` → `financial_escrow.status='disputed'` → milestone verify blocked; `dispute_submit_evidence` then `dispute_resolve` (admin service_role) → escrow `refunded` or `released` per resolution; ledger + audit rows appended. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-03-18: Lifecycle Notifications & Event Orchestration

| Attribute | Detail |
|---|---|
| **Objective** | Event matrix: `listing_published`, `contract_offered/accepted/cancelled`, `milestone_completed/verified/rejected`, `milestone_released`, `review_submitted/revealed`, `message_received`, `appointment_booked/rescheduled/cancelled`, `dispute_filed/resolved`, `earnings_released`. Wiring: RPC post-commit inserts `notification_outbox` (or Supabase `realtime` → Edge Function → `lib/core/notifications/services/notification_service.dart`) → `local_notification_service` + `push_notification_receiver` (`EP-01-18`) with deep-link payloads (`/contracts/:id`, `/messages/:id`). Uses `lib/core/notifications/channels/notification_channel_manager.dart` channels per category. |
| **Engineering Purpose** | Cross-cutting coordination (`Business-Roadmap:242-246` SLA). Notifications must be reliable, deep-linked, and PII-redacted per `lib/core/logging/pii_redactor.dart`. |
| **Dependencies** | EP-03-10, EP-03-11, EP-03-13, EP-03-14, EP-01-18 |
| **Expected Outcome** | Integration test matrix: each lifecycle event fires exactly one notification (local foreground) + one push payload; deep-link tap lands on correct protected route per `lib/app/router/route_guard.dart`; disabled-permission path shows `HivorrErrorState` with `Enable notifications`. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-19: Public Listing Routes & SEO Discoverability

| Attribute | Detail |
|---|---|
| **Objective** | Routes `/s/:profession_slug/:service_id` (public listing detail), `/s/:industry_slug` (profession-filtered browse), `/c/:profession_slug/:entity_id` alias compatibility for profile → listing cross-link. Extend `lib/app/router/app_router.dart` + `route_paths.dart` with public (unauth) read guard, deep-link `go_router` redirect, web `pathUrlStrategy` clean URLs, `lib/systems/portfolio/seo/portfolio_seo_meta.dart` extension for listing meta (title, description, `og:image` via `logo_icon.png` fallback). Responsive via `lib/shared/layouts/breakpoints.dart` + `HivorrContentPane`. |
| **Engineering Purpose** | SEO discoverability (`Business-Roadmap:44-50` word-of-mouth + cross-role discovery). Marketplace must be indexable on web without auth while drafts remain private. |
| **Dependencies** | EP-03-08, EP-01-15, EP-02-19 |
| **Expected Outcome** | Router test: unauth `GET /s/legal/draft-id` redirects to login-or-preview? Actually `published` listing unauth renders detail, `draft` unauth returns 404/not-found state (`HivorrEmptyState`). Web build check confirms path URLs, not hash. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-03-20: Phase Integration Validation & Marketplace Verification

| Attribute | Detail |
|---|---|
| **Objective** | 12-point E2E validation across full stack on Staging (mirrors `EP-02-20` pattern): (1) Verified pro creates listing → `published` searchable, (2) Unverified pro blocked `PLT005`, (3) Deterministic ranking fixtures deterministic, (4) Consumer search → ranked paginated results, (5) Contract offer→accept→escrow funded, (6) Milestone evidence → client verify → escrow milestone release ledger correct, (7) Double-blind review submit→reveal, (8) Encrypted messaging Realtime + offline replay, (9) Scheduling availability→booking→conflict rejection, (10) Portfolio proof linkage renders, (11) Earnings/transaction history matches ledger, (12) Dispute freeze+resolve moves escrow. Perf & security gates: p95 search <400ms, RLS leak matrix 0 leaks, `dart analyze` + `flutter test` + `VISUAL-IDENTITY` token asserts pass. EP-04 readiness sign-off. |
| **Engineering Purpose** | Final gate before EP-03 marked `Completed` and EP-04 unblocked. Proves marketplace model under real transaction conditions per `Business-Roadmap:248-251`. |
| **Dependencies** | All EP-03 items |
| **Expected Outcome** | Validation report (markdown, like `EP-01-20-20-Foundation-Verification-Report.md`) with per-point pass/fail + SQL evidence, CI workflow run artifacts, Staging demo walkthrough. Criteria at `§10` all green. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

---

## 12. Roadmap Summary Matrix

| Task ID | Task Name | Priority | Plan Reasoning | Code Reasoning | Dependencies | Status |
|---|---|---|---|---|---|---|
| EP-03-01 | Professional Service Marketplace Schema & Enforcement | Critical | **Extremely High** | **Extremely High** | EP-01-06, EP-02 | Not Started |
| EP-03-02 | Service Contract & Milestone Engine Schema | Critical | **Extremely High** | **Extremely High** | 03-01, EP-02-04 | Not Started |
| EP-03-03 | Double-Blind Review & Rating Schema | High | **Extremely High** | **Extremely High** | 03-02 | Not Started |
| EP-03-04 | Encrypted Messaging Schema & Rules | High | Very High | Very High | 03-02 | Not Started |
| EP-03-05 | Scheduling & Availability Schema | High | Very High | Very High | 03-02 | Not Started |
| EP-03-06 | Deterministic Ranking & Matching Engine | Critical | **Extremely High** | **Extremely High** | 03-01, EP-02-11, 03-03 | Not Started |
| EP-03-07 | Search & Discovery Infrastructure | High | Very High | Very High | 03-01, 03-06 | Not Started |
| EP-03-08 | Service Listing Management (Client) | High | High | High | 03-01, EP-02 | Not Started |
| EP-03-09 | Service Discovery & Search Experience | High | High | High | 03-07, 03-08 | Not Started |
| EP-03-10 | Contract Creation & Milestone Management | High | Very High | Very High | 03-02, 03-08 | Not Started |
| EP-03-11 | Escrow-Backed Milestone Release Orchestration | Critical | **Extremely High** | **Extremely High** | 03-02, EP-02-04, 03-10 | Not Started |
| EP-03-12 | Double-Blind Review Experience | High | High | High | 03-03, 03-10 | Not Started |
| EP-03-13 | Encrypted Messaging & Realtime (Client) | High | Very High | Very High | 03-04, EP-01 | Not Started |
| EP-03-14 | Scheduling & Appointment Management | High | High | High | 03-05, 03-10 | Not Started |
| EP-03-15 | Portfolio & Proof-of-Work Integration | High | High | High | EP-02-19, 03-01 | Not Started |
| EP-03-16 | Financial Reporting & Earnings Visibility | High | High | High | EP-02-04, 03-02 | Not Started |
| EP-03-17 | Service-Engagement Dispute Resolution | High | Very High | Very High | EP-02-05, 03-02 | Not Started |
| EP-03-18 | Lifecycle Notifications & Events | High | High | High | 03-10/11/13/14 | Not Started |
| EP-03-19 | Public Listing Routes & SEO | High | High | High | 03-08, EP-01-15 | Not Started |
| EP-03-20 | Phase Integration Validation | Critical | High | High | All | Not Started |

---

## 13. Reasoning Level Distribution

| Level | Items | Count |
|---|---|---|
| **Extremely High** | EP-03-01, EP-03-02, EP-03-03, EP-03-06, EP-03-11 | 5 |
| **Very High** | EP-03-04, EP-03-05, EP-03-07, EP-03-10, EP-03-13, EP-03-17 | 6 |
| **High** | EP-03-08, EP-03-09, EP-03-12, EP-03-14, EP-03-15, EP-03-16, EP-03-18, EP-03-19, EP-03-20 | 9 |
| **Medium** | — | 0 |
| **Low** | — | 0 |

Concentration of `Extremely High` (5/20) reflects marketplace-critical database architecture, contract state machine, double-blind trust invariant, deterministic ranking auditability, and held-fund release atomicity — the five failure points that would create irreversible financial or trust loss if designed incorrectly. `Very High` (6/20) captures complex backend/RPC seams (messaging, scheduling, search, contract orchestration, dispute freeze). No item falls below `High` because even CRUD surfaces in EP-03 carry marketplace-level business impact and visual-identity compliance gating.

---

> **Next Step (upon plan approval & exit from read-only mode):** Write `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md` with the content above; then schedule `EP-03-01` (Marketplace Schema) and `EP-03-04/05` (Messaging/Scheduling schemas) as the first unblocked parallel track alongside `EP-03-06` ranking formula design review. Do not proceed to EP-04 commerce orchestration until `EP-03-20` validation report is `GO`.

