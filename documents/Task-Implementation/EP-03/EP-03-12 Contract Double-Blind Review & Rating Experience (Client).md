# Task Implementation Plan — EP-03-12: Contract Double-Blind Review & Rating Experience (Client)

**Task ID:** EP-03-12 | **Priority:** High | **Phase:** EP-03 Stage 5 — Trust & Coordination
**Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:367-376` (Objective, Dependencies `EP-03-03, EP-03-10`, Expected Outcome) + `§5` (review system row), `§7` (dep row), `§8` (timing-oracle risk)
**Planning Reasoning:** High | **Status:** Not Started — planning artifact only, no production code

> Respects `documents/Context/AGENT.md:1-19` (Separation of Concerns, Rule 4 Server-Side Enforcement, Rule 5 Visual Identity tokens, Rule 6 Unified Account no-Both, Rules 2/3 verification/KYC gates) and `documents/Context/ARCHITECTURE.md:39-178` (`lib/` schema, `lib/systems/reviews` trust engine slot, `lib/data/*` vertical slice, `lib/shared/*` design system, `lib/app/router` SEO routes).

---

## 1. Task Objective

Build the **client-side double-blind review experience** on top of the already-shipped server invariant (`supabase/migrations/20260924090001_service_review_schema.sql`, EP-03-03). Neither party's `rating`/`comment` is disclosed until both submit or the 14-day deadline expires; reveal is atomic server-side.

Client deliverables (mirroring EP-03-10 contract slice conventions):

- Full vertical slice: `ServiceReview` / `ReviewAggregate` entities → DTOs → mappers → `ServiceReviewRemoteDataSource` (+ Supabase impl) → `ServiceReviewRepository` (+ impl) → `ServiceReviewProvider` → `ServiceReviewService` facade → DI registration
- Screens: `review_submit_screen.dart` (1–5 stars + optional 10–2000 comment), `review_reveal_screen.dart` / contract-embedded reveal section
- Widgets: `double_blind_status_card.dart` (states `awaiting_yours` / `awaiting_counterparty` / `revealed`), `star_rating_input.dart`, `star_rating_display.dart`, `rating_distribution_bar.dart`
- Integration points: review entry CTA in `contract_detail_screen.dart`, post-reveal stars + distribution extension in `service_detail_screen.dart`, `review_submitted` / `revealed` notification via `lib/core/notifications/*`, routes `/contracts/:id/review` + `/contracts/:id/reviews`
- Zero new tables, zero new RPCs, zero ranking/financial logic in client.

## 2. Business Problem Being Solved

EP-03-03 proved the server primitive (`service_reviews` + `service_review_aggregates` + 4 RPCs + pgTAP `027/028`), and EP-03-10 proved `service_contracts` lifecycle (`active/completed/closed` reviewable). But there is **no client path to use it**:

- `lib/systems/reviews/` contains only `.gitkeep` (verified empty). No entity, DTO, repository, provider, service, screen, or widget for `service_reviews` exists.
- `service_detail_screen.dart:448-481` (`_RatingLine`) and `discovery_service_card.dart` (`_RatingRow`) render only the read-only `avgRating/reviewCount` cache from `ServiceListing`; users cannot submit, cannot see blind status, cannot see revealed comments or distribution.
- Without an honest blind UX (explicit `awaiting_*` states, no counterparty leakage, `you_have_submitted` only), users will either not trust ratings or will infer the other party's submission (timing oracle) — reintroducing retaliatory rating that EP-03-03 was built to eliminate (`Business-Roadmap` Trust layer #3).
- Without this, `EP-03-06` ranking (`w_rating * bayesian_avg`) has no growing data source and `EP-03-09` detail cannot show reputation depth.

## 3. Scope

| In Scope | Detail |
|---|---|
| Data vertical | `lib/data/entities/service_review.dart` (`ServiceReview`, `ReviewAggregate`, `ReviewStatus` / `MyReviewStatus`), `lib/data/models/service_review_dto.dart` (+ envelopes), `lib/data/mappers/review_mapper.dart`, `lib/data/datasources/remote/service_review_remote_data_source.dart` + `supabase_service_review_remote_data_source.dart` (+ `service_review_envelope_parser.dart`), `lib/data/repositories/service_review_repository.dart` + `_impl.dart`, `lib/data/providers/service_review_provider.dart`, wiring in `lib/data/data_layer.dart` (`registerServiceReviewLayer`) |
| Domain facade | `lib/systems/reviews/services/service_review_service.dart` — thin facade over repository: vocab (`minRating=1, maxRating=5, minComment=10, maxComment=2000`), fail-fast validators (`validateRating/validateComment`), delegation (`submitReview/getMyStatus/getForListing`), PII-safe logging, `reviews.*` perf spans. Mirrors `ContractService` (`lib/systems/documents/services/contract_service.dart:35-100`) |
| Screens | `lib/systems/reviews/screens/review_submit_screen.dart` (contract-scoped form), `review_reveal_screen.dart` (or reveal section; shows `revealed_reviews[]` only when `is_revealed=true`), contract-detail review section embed |
| Widgets | `lib/systems/reviews/widgets/double_blind_status_card.dart`, `star_rating_input.dart`, `star_rating_display.dart`, `rating_distribution_bar.dart`, `review_list_tile.dart` (revealed comment row) |
| Contract integration | Review CTA + status card slot in `contract_detail_screen.dart` (gated on `status in (active,completed,closed)` + participant check; affordance only), post-submit refresh of `ServiceContractProvider.selected` context |
| Listing integration | Extend `service_detail_screen.dart` `_RatingLine` / add revealed-reviews carousel section consuming `service_review_get_for_listing` (revealed only) + `ReviewAggregate` header; empty state via `HivorrEmptyState` |
| Routing | `RoutePaths.contractReview = '/contracts/:id/review'`, `RoutePaths.contractReviews = '/contracts/:id/reviews'` + `RouteNames.contractReview/contractReviews` + `app_router.dart` protected entries with `route_guard.dart`; deep-link payload for notification tap |
| Notifications | `review_submitted` (local confirm) + `revealed` notification via existing `NotificationService.show()` + `HivorrNotification`; tap deep-links to reveal route. No new channel; reuse per-category channel manager |
| Validation | Client-side rating/comment length parity with server CHECKs (fail-fast only; server remains authoritative per Rule 4) |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| New tables / columns / RLS / RPCs | EP-03-03 already shipped `service_reviews`, `service_review_aggregates`, 4 RPCs, RLS, indexes. Any change here belongs to a schema follow-up, not EP-03-12 |
| Ranking formula changes | `EP-03-06` consumes `service_review_aggregates`; this task only writes/reads via existing RPCs |
| Messaging / scheduling / escrow release / dispute / portfolio link | EP-03-13 / 14 / 11 / 17 / 15 respectively; review screens must not embed those flows |
| Admin moderation of reviews | Reuses `EP-02-11` Admin shell tooling; no marketplace-embedded admin |
| AI ranking override / sentiment analysis | Banned by `AGENT.md:7` Deterministic Core Supremacy; `lib/ai/*` excluded from EP-03 |
| Offline review queue | Reviews are low-frequency, contract-gated writes; offline replay is an EP-03-13 messaging pattern (`action_queue.dart`), not required here. Failed submit surfaces retry via `HivorrErrorState` |
| Media / photo reviews | Server `comment text 10-2000` only, no bucket; evidence uploads stay in contract milestone flow |

## 5. Existing Asset and Dependency Analysis

Inspected live codebase (read + subagent exploration). All paths verified to exist unless marked MISSING.

**Server primitive — EXISTS, reuse as-is:**
- `supabase/migrations/20260924090001_service_review_schema.sql:52-76` — `service_reviews` (FKs `contract_id CASCADE`, `service_listing_id/profession_id/entities RESTRICT`, `rating 1-5`, `comment NULL|10-2000`, `is_revealed default false`, `UNIQUE(contract_id, reviewer)`, `CHECK no_self`, `CHECK revealed_at semantics`)
- Same file `:108-120` — `service_review_aggregates` (PK `(professional_entity_id, profession_id)`, `avg_rating 0-5`, `review_count`, `distribution jsonb`, `last_revealed_at`)
- Same file `:220-344` — `service_review_submit(p_contract_id uuid, p_rating integer, p_comment text)` (`SECURITY INVOKER, VOLATILE`): participant gate, `status IN (active,completed,closed)` else `PLT005`, `reviewee` derived as opposite participant, single-review `PLT005`, lazy `reveal_if_ready` call, envelope `{success,code,message,data.review}`
- Same file `:350-414` — `service_review_get_mine(p_contract_id uuid)` (`STABLE`): returns `you_have_submitted bool + your_review (even unrevealed) + revealed_reviews[] (only is_revealed=true) + review_count`. No oracle by design
- Same file `:420-536` — `service_review_get_for_listing(p_service_listing_id uuid, p_limit int 1-100, p_cursor uuid)` (`STABLE`, `anon` allowed): only `is_revealed=true`, keyset `(revealed_at DESC, id DESC)`, returns `reviews[] + avg_rating/review_count/distribution` from aggregates; identical `PLT004` for draft/unknown (no oracle)
- Same file `:548-` — `service_review_reveal_if_ready(p_contract_id uuid)` (`SECURITY DEFINER`, sole DEFINER — counts RLS-hidden counterparty row, `FOR UPDATE`, `ON CONFLICT DO UPDATE` aggregates + `service_listings` cache)
- Grants `:725-728` — `submit/get_mine/reveal` to `authenticated,service_role`; `get_for_listing` also to `anon`
- Tests `supabase/tests/database/027_service_review_schema_posture.sql` + `028_service_review_rpc_enforcement.sql` — solo→not-revealed, both→revealed+aggregates+listing cache, 14d expiry, idempotency, immutability

**Client reviews slice — MISSING (genuine new capability):**
- `lib/systems/reviews/.gitkeep` — only file; no `services/screens/widgets` (confirmed via glob `**/*rating*`, `**/*star*`, `**/*double_blind*` → no files; grep `ServiceReview|double.?blind|submit_review` in `lib/` → only `AdminReview*` hits which are EP-02-11 verification queue, different domain)
- `lib/data/entities/` (43 files) — has `service_contract.dart:17-146` (`ServiceContract` + `canAccept/canComplete/canVerify/canClose` affordance hints), `service_listing.dart:10-33` (`avgRating/reviewCount` cache fields), `contract_milestone.dart`, `contract_event.dart`; NO `service_review.dart` / `review_aggregate.dart`
- `lib/data/models/` (50 files) — has `service_contract_dto.dart`, `service_listing_dto.dart` (`avg_rating/review_count` parse), `admin_review_dto.dart`; NO `service_review_dto.dart`
- `lib/data/repositories/`, `lib/data/providers/`, `lib/data/datasources/remote/` — have `service_contract_*`, `service_listing_*`, `admin_review_*`, `supabase_service_contract_remote_data_source.dart:16-80` (canonical `_guard(mapDataException)` + `supabase.rpc` + envelope-unwrap pattern to copy); NO `service_review_*`
- `lib/data/mappers/` — has `contract_mapper.dart`, `service_listing_mapper.dart`; NO `review_mapper.dart`
- `lib/data/data_layer.dart:1-80` (969 lines) — has `registerServiceContractLayer`, `registerServiceListingLayer`, `registerContractEscrowLayer`, etc.; NO `registerServiceReviewLayer` / `registerReviewLayer`

**Contract dependency — EXISTS, extend by composition (no modification of contract logic):**
- `lib/systems/documents/services/contract_service.dart:35-100` — `ContractService` facade pattern to mirror (vocab consts, `validate*`, repository delegation, `HivorrLogger` + `PerformanceTracer` + `PiiRedactor`, storage-before-RPC for evidence — review needs no storage)
- `lib/data/providers/service_contract_provider.dart:29-80` — `ServiceContractProvider` (`idle/loading/loaded/error`, `contracts/selected`, `loadMine/loadMore/select/refresh/offer/accept/...`, `WidgetsBindingObserver` pause gate) — review provider mirrors this shape
- `lib/systems/documents/screens/contract_detail_screen.dart:34-120` — header + `MilestoneListCard` via `contract_milestone_adapter.dart` + `contract_timeline` + `ContractWriteCtaPanel` + `escrow_dispute_banner`; this is the host screen where the review CTA/status-card slot is added
- `lib/systems/documents/widgets/contract_status_badge.dart`, `contract_milestone_adapter.dart` (`reviewCountdownLabel`, `reviewPeriodExpiresAt`) — status-badge composition pattern to follow

**Listing/discovery display — EXISTS, extend read-only:**
- `lib/systems/marketplace/screens/service_detail_screen.dart:330-481` — `_DetailBody` + `_RatingLine` (`Icons.star` + `avgRating.toStringAsFixed(1)` + `(N reviews)`, `Semantics` label), `_ProofSlot`, `_BookingCta` (affordance-only + `?next=` login resume). Review section appends below rating line; must not alter booking CTA logic
- `lib/systems/marketplace/widgets/discovery_service_card.dart` (`_RatingRow`), `lib/systems/marketplace/services/service_listing_service.dart` (listing facade + validators) — no changes needed; review reads `avg_rating` cache already present

**Shared design system — EXISTS, mandatory reuse:**
- `lib/shared/widgets/hivorr_card.dart` (`HivorrCard`), `hivorr_button.dart` (`HivorrButton` variants `primary/secondary/outline/text`, sizes, `>=48dp` CTA), `hivorr_empty_state.dart` (`HivorrEmptyState` + `compact`), `hivorr_error_state.dart`, `hivorr_loading_state.dart`, `hivorr_success_state.dart:10-75` (`HivorrSuccessState` + `celebrate` opt-in), `hivorr_snackbar.dart`, `hivorr_text_field.dart` (`HivorrTextField`), `hivorr_badge.dart` (`HivorrBadge` variants), `hivorr_chip.dart`
- `lib/shared/components/hivorr_stat_card.dart` (`HivorrStatCard` + `HivorrStatGrid` — aggregate metric pattern), `hivorr_section_header.dart`, `hivorr_dialog.dart`, `hivorr_bottom_sheet.dart`, `hivorr_skeleton.dart`
- `lib/shared/layouts/hivorr_screen_scaffold.dart`, `hivorr_responsive_scaffold.dart`, `hivorr_content_pane.dart` (≈720dp max, 16/24dp gutters), `breakpoints.dart` (tablet 600, desktop 1024)
- `lib/shared/validators/hivorr_validators.dart` (`required/minLength/maxLength/compose` returning `String?`), `lib/shared/extensions/build_context_extensions.dart` (`context.colorScheme/textTheme/appExtension`), `lib/shared/helpers/hivorr_spacing.dart`, `hivorr_formatters.dart`
- `lib/app/theme/app_colors.dart` (`brandPrimary 0xFF2D3FE7` etc.), `app_theme.dart` (`AppThemeExtension` success/warning/info, radius, `HivorrMotion`, `HivorrElevation`), `app_text_theme.dart` (Plus Jakarta Sans) — Rule 5: no `Colors.*`/hex/`fontFamily` per-widget

**Cross-cutting — EXISTS, reuse:**
- `lib/core/api/services/base_api_service.dart` (`BaseApiService.invoke` normalizes `DioException→ApiException`), `lib/core/api/exceptions/api_exception.dart` (`ApiExceptionKind` + `code PLT000/001/003/004/005/999`), `data_exception_mapper.dart` + `service_contract_envelope_parser.dart` (envelope `{success,code,message,data}` unwrap — copy pattern)
- `lib/core/authentication/providers/auth_provider.dart` (`currentSession?.entityId` for viewer-vs-participant affordance)
- `lib/core/notifications/services/notification_service.dart:11-32` (abstract `initialize/show/cancel/onNotificationTapped/dispose`), `models/hivorr_notification.dart`, `channels/notification_channel_manager.dart`, `providers/notification_provider.dart`, `push/supabase_push_receiver.dart` — generic engine only, no review type yet
- `lib/core/logging/hivorr_logger.dart` + `pii_redactor.dart` (never log comment bodies), `lib/core/monitoring/performance_tracer.dart`, `sentry_flutter:9.27.0`
- `lib/app/router/route_paths.dart:192-209` (contracts `/contracts`, `/contracts/new?listingId=`, `/contracts/:id`, `/contracts/:id/milestones/edit` + builders), `route_names.dart:106-110`, `app_router.dart` (66 routes), `route_guard.dart` — new review routes follow this exact shape
- `lib/systems/portfolio/services/professional_profile_service.dart` (aggregate/facade delegation pattern: derived `verifiedIdentity/tradeVerified/seoMeta`), `widgets/verification_badges_row.dart` (pure display row receiving derived booleans) — model for aggregate header widget
- `lib/systems/finance/widgets/milestone_list_card.dart` + `escrow_status_badge.dart` (tone→`AppThemeExtension` chip) — model for status-card tone mapping

## 6. Reuse / Extension / Refactoring Assessment

| Proposed Asset | Verdict | Justification & Integration |
|---|---|---|
| Server tables + RPCs + RLS | **Reuse as-is** | `service_reviews`, `service_review_aggregates`, all 4 RPCs already live with pgTAP cover. No migration in EP-03-12. Client calls RPCs only; never direct table writes (Rule 4) |
| `ServiceReview` / `ReviewAggregate` entities + DTOs + mapper | **Create new** (genuine gap) | Inspected `lib/data/entities/` + `models/` + `mappers/` — no review types exist; `AdminReview` is a different domain (verification queue) and must not be repurposed. Design as reusable platform capability: generic `rating 1-5 + comment + is_revealed` shape that EP-04 product reviews can extend, not a contract-only one-off. Pure Dart, no Flutter/Supabase imports (mirrors `ServiceContract` doc pattern) |
| `ServiceReviewRemoteDataSource` + Supabase impl + envelope parser | **Create new by copying pattern** | No review datasource exists. Copy `SupabaseServiceContractRemoteDataSource._guard + supabase.rpc(p_contract_id/p_rating/p_comment) + EnvelopeParser.unwrap` verbatim; do not refactor contract datasource (stable, covered by tests) |
| `ServiceReviewRepository` + impl | **Create new** | No review repository exists. Interface (`submitReview/getMyStatus/getForListing`) + impl over remote (+ optional in-memory page cache for `get_for_listing` window, mirroring `LruCache` search pattern — never authoritative) |
| `ServiceReviewProvider` | **Create new** | No review provider exists. Mirror `ServiceContractProvider` shape (`ReviewLoadState idle/loading/loaded/error`, `myStatus/selectedContractId/listingReviews/aggregate`, `loadMyStatus/submit/submitAndReload/loadForListing/loadMore/refresh`, `_disposed` guard, lifecycle pause). Never decides reveal — renders server `is_revealed` verbatim |
| `ServiceReviewService` | **Create new** | `lib/systems/reviews/services/` empty. Mirror `ContractService` (vocab consts, `validateRating/validateComment/validateContractId`, delegation, redacted logging, `reviews.*` tracer spans). Single seam for screens + provider, matching `registerMarketplaceLayer`/`registerDocumentsLayer` DI shape |
| `review_submit_screen`, `review_reveal_screen`/section | **Create new** | No review screens exist. Compose only from `Hivorr*` shared widgets + new star input/display widgets. Screens consume `ServiceReviewService`/`ServiceReviewProvider` only, never `SupabaseClient` directly (Separation of Concerns) |
| `double_blind_status_card`, `star_rating_input/display`, `rating_distribution_bar`, `review_list_tile` | **Create new (reusable)** | Glob confirms no star/rating/double-blind widgets exist; existing `_RatingRow`/`_RatingLine` are private read-only one-liners, not reusable inputs. Build as platform-grade reusable components (forward-compatible with EP-04 product ratings): `StarRatingInput(value/onChanged/size/semantics)`, `StarRatingDisplay(avg/count/size)`, `RatingDistributionBar(distribution)` over `HivorrCard` + theme tokens |
| Contract-detail review slot | **Extend existing screen** (composition, no logic change) | `contract_detail_screen.dart` is the correct host (contract is the review atom). Add CTA + `DoubleBlindStatusCard` section; do not alter milestone/escrow/timeline logic. CTA visibility uses `canReview`-style affordance hint (participant + `status in active/completed/closed` + `you_have_submitted==false`); enforcement stays server-side (`PLT005` otherwise) |
| Listing-detail aggregate section | **Extend existing screen** (read-only append) | `service_detail_screen.dart` already renders `avgRating/reviewCount`; append revealed-reviews section (`aggregate header + distribution + paginated revealed list`) fed by `get_for_listing`. No change to booking CTA, media, or proof slot |
| Routes `/contracts/:id/review`, `/contracts/:id/reviews` | **Extend router** (additive only) | No review routes exist (`route_paths.dart`, `route_names.dart` verified). Add path constants + builders + `app_router.dart` protected entries reusing `route_guard.dart` contract-ownership guard pattern. No change to existing 66 routes |
| Notifications on submit/reveal | **Reuse + thin extension** | `NotificationService` + `HivorrNotification` + channel manager exist and are transport-agnostic. Add `review_submitted`/`review_revealed` notification construction (PII-redacted: rating only, never comment body in push preview — mirrors `body_preview` redaction rationale in EP-03-04) with deep-link to reveal route. No new channel; no change to push receiver |
| Validators, spacing, formatters, theme, error/loading/success states | **Reuse as-is** | `HivorrValidators.compose`, `HivorrSpacing`, `HivorrFormatters`, `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme`, `HivorrLoadingState/ErrorState/SuccessState/EmptyState/Snackbar` cover all states including VISUAL-IDENTITY §9 calm states |

No parallel systems are introduced. The only new domain is the genuinely missing client review slice, designed for EP-04 reuse.

## 7. Recommended Technical Approach

**Layered vertical slice, server-authoritative, presentation-only client** (Rule 4). All state transitions via the 4 existing RPCs; client never evaluates `both_submitted`, never computes averages, never re-sorts revealed lists.

**7.1 Data layer (`lib/data/`)** — pure Dart entities, envelope DTOs, mapper, remote seam:
- `ServiceReview(id, contractId, serviceListingId, reviewerEntityId, revieweeEntityId, professionId, rating 1-5, comment?, isRevealed, revealedAt, createdAt)`; `ReviewAggregate(professionalEntityId, professionId, avgRating, reviewCount, distribution{1..5}, lastRevealedAt)`; `MyReviewStatus(contractId, youHaveSubmitted, yourReview?, revealedReviews[], reviewCount)` — mirrors `ServiceSearchPage`/`ServiceContract` purity (no DTO leakage)
- `ServiceReviewDto.fromJson` (handles `rating` int-or-numeric, `comment` nullable, `is_revealed` bool, `revealed_at` nullable) + `ReviewAggregateDto` + `MyReviewStatusEnvelopeDto` / `ListingReviewsEnvelopeDto` (`reviews/has_more/next_cursor/avg_rating/review_count/distribution`)
- `ReviewMapper.toEntity/toAggregate/toMyStatus/toListingPage` (verbatim server order preserved — `AGENT.md:7` analog: never client re-sort)
- `ServiceReviewRemoteDataSource` interface (`submitReview({contractId, rating, comment?})`, `getMyStatus(contractId)`, `getForListing({listingId, limit, cursor})`) + `SupabaseServiceReviewRemoteDataSource extends BaseApiService` (`supabase.rpc('service_review_submit'/'service_review_get_mine'/'service_review_get_for_listing')`, `_guard(mapDataException)`, `ServiceReviewEnvelopeParser.unwrap`) — exact copy of contract datasource idiom
- `ServiceReviewRepository` + `ServiceReviewRepositoryImpl` (remote-only; optional transient page-window memo, never settlement truth)
- `ServiceReviewProvider extends ChangeNotifier with WidgetsBindingObserver` (mirror contract provider: `ReviewLoadState`, `myStatusByContract`, `listingReviews/listingAggregate/hasMore/nextCursor`, `submit/loadMyStatus/loadForListing/loadMore/refresh`, `pausePolling/resumePolling`, single `ApiException` surface)
- `registerServiceReviewLayer()` in `data_layer.dart` returning `({dataSource, repository, provider, service})` following `registerServiceContractLayer` shape

**7.2 Domain service (`lib/systems/reviews/services/service_review_service.dart`)** — thin facade:
- Vocab: `minRating=1, maxRating=5, minCommentLength=10, maxCommentLength=2000, reviewableStatuses=['active','completed','closed']`, `currencies` not needed (no money here)
- Validators: `validateRating(int?)`, `validateComment(String?)` (null/empty → valid star-only; else 10–2000 trimmed), `validateContractId(String?)` — fail-fast parity with server CHECKs; server remains enforcer
- Delegation: `submitReview/getMyStatus/getForListing` → repository; redacted logs (contract-id suffix + `is_revealed` delta only, never comment text); `reviews.submit/get_mine/get_for_listing` tracer spans; `canReview(ServiceContract?, MyReviewStatus?)` affordance hint (participant + reviewable status + not-yet-submitted) — documented as CTA-visibility only

**7.3 Presentation (`lib/systems/reviews/screens + widgets/`)** — token-only UI:
- `review_submit_screen.dart` (`/contracts/:id/review`): loads `ServiceContractProvider.selected` (for counterparty role label + reviewable gate hint) + `ServiceReviewProvider.loadMyStatus`; if `you_have_submitted` → redirect to reveal route (no double-submit UI). Form: `StarRatingInput` (1–5, `Semantics` per star, keyboard-accessible, `>=48dp` touch) + `HivorrTextField` multiline comment (counter 10–2000, empty = star-only) + `HivorrButton` submit with `isLoading`. Errors: `PLT005 Already reviewed` → info guidance + link to reveal; `PLT005 Not reviewable` → `HivorrErrorState` with back-to-contract action; `PLT004` → same not-found state as contract detail (no oracle). Success → `HivorrSuccessState(celebrate:false, title:'Review submitted', subtitle: blind-aware copy)` + auto-navigate to reveal route
- `DoubleBlindStatusCard` states: `awaiting_yours` (CTA to submit, `HivorrBadge info`), `awaiting_counterparty` (neutral copy `Waiting for the other party — your review stays hidden until both submit or the 14-day window ends`, no rating shown, no countdown leaking exact deadline), `revealed` (both `StarRatingDisplay` rows + comments, `HivorrBadge success`). Tone mapping reuses `EscrowStatusBadge._StatusChip` idiom via `AppThemeExtension`
- `review_reveal_screen.dart` (`/contracts/:id/reviews`): `HivorrScreenScaffold` + `HivorrContentPane`; `loadMyStatus` → status card + `revealed_reviews[]` list (`ReviewListTile`: stars + comment + `revealed_at` via `HivorrFormatters.date`); pre-reveal shows only status card + `HivorrEmptyState` (`Others hidden until reveal`). Pull-to-refresh re-calls `get_mine` (which lazy-triggers server reveal on expiry)
- `StarRatingInput/StarRatingDisplay/RatingDistributionBar`: `Icons.star/star_border` (or `star_half` for display rounding) tinted `colorScheme.secondary` / `appExtension.warning` (matching existing `_RatingLine`); distribution bars from `aggregate.distribution` with `LinearProgressIndicator` per row; all text via `TextTheme`, all spacing via `HivorrSpacing`
- Contract-detail embed: review section after `contract_timeline`, before `ContractWriteCtaPanel`; listing-detail embed: revealed-reviews section after `_RatingLine`, before proof slot; both guarded by provider `isLoading/isLoaded` + `HivorrLoadingState/Skeleton` and `HivorrErrorState` retry

**7.4 Routing + notifications:**
- `RoutePaths.contractReview='/contracts/:id/review'`, `contractReviews='/contracts/:id/reviews'` + builders `contractReviewFor(id)`, `contractReviewsFor(id)`; `RouteNames.contractReview/contractReviews`; `app_router.dart` entries with authenticated + contract-participant guard (reuse `route_guard.dart` pattern; `PLT004`-identical denial for foreign ids)
- On `submit` success: `NotificationService.show(HivorrNotification(review_submitted, deepLink: contractReviewsFor))`; on `get_mine` transition to `revealed` (client observes `revealed_reviews.length 0→2` or `review_count` change): show `review_revealed` notification. Comment body never in push payload (PII redaction). Full fan-out matrix (push content, expiry-cron path) ships in EP-03-18; here only local confirm + reveal-deep-link

## 8. Required Systems, Modules, and Components

| Layer | Files (new `+`, extend `~`) | Purpose |
|---|---|---|
| Entities | `+ lib/data/entities/service_review.dart` | `ServiceReview`, `ReviewAggregate`, `MyReviewStatus`, `ListingReviewsPage` |
| DTOs | `+ lib/data/models/service_review_dto.dart` | Request/response + envelope DTOs |
| Mappers | `+ lib/data/mappers/review_mapper.dart` | DTO→entity, verbatim order |
| Datasources | `+ lib/data/datasources/remote/service_review_remote_data_source.dart`, `+ supabase_service_review_remote_data_source.dart`, `+ service_review_envelope_parser.dart` | Single RPC seam (3 calls; `reveal_if_ready` never called directly — server lazy-triggers it) |
| Repositories | `+ lib/data/repositories/service_review_repository.dart`, `+ service_review_repository_impl.dart` | Domain contract + impl |
| Providers | `+ lib/data/providers/service_review_provider.dart` | `ReviewLoadState`, my-status + listing-page state |
| Services | `+ lib/systems/reviews/services/service_review_service.dart`, `+ lib/systems/reviews/reviews.dart` (barrel), `+ lib/systems/reviews/reviews_dependency_injection.dart` (`registerReviewsLayer`) | Facade + DI mirroring marketplace/documents layers |
| Screens | `+ lib/systems/reviews/screens/review_submit_screen.dart`, `+ review_reveal_screen.dart` | Submit + reveal flows |
| Widgets | `+ lib/systems/reviews/widgets/double_blind_status_card.dart`, `+ star_rating_input.dart`, `+ star_rating_display.dart`, `+ rating_distribution_bar.dart`, `+ review_list_tile.dart` | Blind-status + reusable star/distribution kit |
| Host screens | `~ lib/systems/documents/screens/contract_detail_screen.dart` (review section slot), `~ lib/systems/marketplace/screens/service_detail_screen.dart` (revealed-reviews section) | Composition-only embeds |
| Router | `~ lib/app/router/route_paths.dart`, `~ route_names.dart`, `~ app_router.dart` | 2 protected routes + builders |
| Data wiring | `~ lib/data/data_layer.dart` | `registerServiceReviewLayer` export |
| Notifications | `~ notification construction call-sites only` (`lib/systems/reviews/*` → `NotificationService.show`) | Submit/reveal confirms with deep links |

No changes to `supabase/*`, `lib/engine/*`, `lib/ai/*`, `lib/systems/finance/*`, `lib/systems/communication/*`, `lib/systems/scheduling/*`.

## 9. Data Requirements

- `ServiceReview`: `id, contractId, serviceListingId, reviewerEntityId, revieweeEntityId, professionId uuids (opaque strings client-side); rating int 1-5; comment String? (null = star-only, else trimmed 10-2000); isRevealed bool; revealedAt/createdAt/updatedAt DateTime?`
- `ReviewAggregate`: `professionalEntityId, professionId; avgRating double 0-5; reviewCount int >=0; distribution Map<int,int> {1..5}; lastRevealedAt DateTime?`
- `MyReviewStatus`: `contractId; youHaveSubmitted bool; yourReview ServiceReview? (visible even when unrevealed — owner only); revealedReviews List<ServiceReview> (only is_revealed=true, server-filtered); reviewCount int`
- `ListingReviewsPage`: `reviews List<ServiceReview> (revealed only, server order `(revealed_at DESC, id DESC)` verbatim); aggregate ReviewAggregate?; hasMore bool; nextCursor String? (opaque uuid)`
- Client validation mirrors server exactly: rating null/out-of-range → local `PLT003`-copy message before RPC; comment non-empty but <10 or >2000 → local message; contract id empty → local message. All are fail-fast conveniences; RPC errors remain authoritative
- No local persistence of reviews (no `Hive` cache for review bodies — blind data must always re-read server; only transient provider memo within session). No PII logging of comments

## 10. Database Considerations

**None — reuse verified, no migration.** EP-03-03 schema already satisfies this task:

- `service_reviews` UNIQUE + CHECKs enforce single-review, no-self, rating/comment ranges, reveal semantics
- `service_review_aggregates` PK + `ON CONFLICT DO UPDATE` supports atomic recompute
- Partial index `service_reviews_listing_revealed_idx WHERE is_revealed` serves `get_for_listing` pagination; `contract_idx`/`reviewer_idx` serve `get_mine`
- RLS default-deny + narrow `UPDATE(is_revealed,revealed_at,updated_at)` + `service_listings(avg_rating,review_count)` column grant already in place
- Client must not issue direct `SELECT/INSERT` on tables — all access via the 4 RPCs (RLS would block bypass anyway; pgTAP `027/028` already proves it)

If implementation discovers a missing index or grant, it must be raised as an EP-03-03 defect, not silently migrated here.

## 11. API Requirements

**No new endpoints — reuse 3 client-facing RPCs** (4th is server-internal lazy trigger):

| RPC | Call | Params | Response consumed |
|---|---|---|---|
| `service_review_submit` | `supabase.rpc('service_review_submit', {p_contract_id, p_rating, p_comment})` | `rating int`, `comment String?` (null → star-only) | `data.review` → `ServiceReview`; errors `PLT001/003/004/005/999` mapped via `mapDataException` |
| `service_review_get_mine` | `supabase.rpc('service_review_get_mine', {p_contract_id})` | — | `data.{you_have_submitted, your_review, revealed_reviews[], review_count}` → `MyReviewStatus` |
| `service_review_get_for_listing` | `supabase.rpc('service_review_get_for_listing', {p_service_listing_id, p_limit (default 20, max 100), p_cursor})` | keyset cursor opaque uuid | `data.{reviews[], avg_rating, review_count, distribution, has_more, next_cursor}` → `ListingReviewsPage` |
| `service_review_reveal_if_ready` | **Never called directly from client** | — | Lazy-invoked server-side by `submit`/`get_mine`; client observes reveal via `get_mine` polling/refresh |

Envelope handling reuses `ServiceContractEnvelopeParser.unwrap` idiom (`{success,code,message,data}` → throw `ApiException(code)` on `!success`). Error-copy mapping: `PLT003` → form field errors; `PLT004` → not-found empty state (identical for foreign/unknown — no oracle); `PLT005 Already reviewed` → reveal redirect; `PLT005 Not reviewable` → guidance state; `PLT001` → login resume `?next=`.

## 12. User Interface Requirements

- **Submit screen** (`/contracts/:id/review`): `HivorrScreenScaffold` + `HivorrContentPane`; header `ContractStatusBadge` context + counterparty role line (`You are rating: Professional/Client` — names never exposed beyond contract row); `StarRatingInput` (5 tappable stars, `>=48dp`, keyboard focus traversal, `Semantics(label:'Rate X out of 5')`); comment `HivorrTextField` (multiline 4–6 lines, live counter `0/2000`, helper `Optional — 10 character minimum if provided`); disclaimers (`Your review stays hidden until both parties submit or 14 days pass`); submit `HivorrButton(primary, isExpanded, isLoading)`; states: loading → `HivorrLoadingState`; error → `HivorrErrorState(retry)`; success → `HivorrSuccessState(title:'Review submitted', subtitle blind copy)` then push-replace to reveal route
- **Reveal screen** (`/contracts/:id/reviews`): `DoubleBlindStatusCard` top; revealed list `ReviewListTile` cards (`StarRatingDisplay` + comment + `revealed_at`); pre-reveal → card + `HivorrEmptyState(title:'Waiting for the other party', subtitle blind copy, compact)`; post-reveal → `HivorrBadge(success,'Revealed')` + both reviews; pull-to-refresh
- **Contract-detail embed**: new `ReviewSection` (status card compact + CTA button `Write a review` / `View reviews`) placed after timeline; hidden entirely for non-participants (affordance, not enforcement)
- **Listing-detail embed**: aggregate header (`StarRatingDisplay` + count + `RatingDistributionBar`) + first page of revealed reviews + `View all` affordance (full pagination lives on reveal/listing-reviews view); `HivorrEmptyState(compact, 'No reviews yet')` when `review_count==0`
- **Responsive**: `HivorrResponsiveScaffold`/`HivorrContentPane` constraints; mobile single-column, tablet/desktop centered max-width; no custom breakpoints
- **Visual identity**: 100% `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme`; stars use `colorScheme.secondary`/`extension.warning` (existing `_RatingLine` precedent); any hardcoded `Colors.*`/hex/`fontFamily` fails DoD

## 13. User Experience Considerations

- **Blind honesty is the core UX**: copy must explicitly state hidden-until-both-or-14-days on submit, waiting, and success states; never show counters like `1/2 submitted`, never show `updated_at` hints, never differentiate `awaiting_counterparty` timing (single static copy regardless of actual counterparty state — mitigates timing oracle per Phase Plan `§8`)
- **Symmetric flows**: client and professional see identical submit/reveal UI (only the `You are rating:` role label differs); both receive the same reveal notification
- **Self-contract / non-participant**: CTA hidden; deep-link to review route for foreign id renders identical `PLT004` not-found (no existence oracle, mirroring `ContractDetailScreen` behavior)
- **Double-submit prevention**: submit button disables while in-flight + on `you_have_submitted==true` immediate redirect; `UNIQUE` violation surfaces as friendly already-submitted guidance, not a crash
- **Star-only allowed**: empty comment is valid (server `comment NULL`); UI must not force comment entry — placeholder `Share what went well (optional, min 10 characters)`
- **Accessibility**: star input operable via keyboard/dpad + screen reader (`Semantics` on input, display, and status card); distribution bars expose `Semantics(label:'N out of M are 5 stars')`; touch targets `>=48dp`; calm §9 empty/success/error states, no celebratory confetti on submit (genuine milestone celebration reserved — `celebrate:false`)
- **Lagos-connectivity resilience**: submit is synchronous RPC with retry affordance; no optimistic reveal; refresh-driven reveal check keeps UX correct on slow networks

## 14. Security Considerations

- **Rule 4 zero-trust**: no rating math, no reveal decision, no average computation in client; `is_revealed` rendered verbatim; `get_for_listing` never requested with a bypass (server filters `is_revealed=true` regardless)
- **No oracle**: `get_mine` exposes only `you_have_submitted` (never counterparty-submitted boolean); UI copy is state-identical for all pre-reveal viewers; `PLT004` identical for foreign/unknown/draft (verified server behavior — client must preserve it, not "improve" messages per-id)
- **Participant binding**: `reviewer=auth.uid()` server-derived; client never sends `reviewer/reviewee/profession/listing` ids (only `contract_id + rating + comment`); viewer-vs-participant checks are CTA-visibility only
- **PII**: comment bodies never logged (`PiiRedactor` + logger allowlist: ids + ratings + booleans only), never in push payloads, never in Sentry breadcrumbs; `created_by` audit stays server-side
- **Immutability**: no edit/delete RPC exists — UI offers no edit affordance; resubmit attempt correctly yields `PLT005`
- **Transport**: all calls via authenticated `supabase.rpc` with `auth_interceptor` JWT refresh; `anon` path only for `get_for_listing` on `published` listings (public stars, same as listing read)
- **Static gates**: `dart analyze` + grep CI for banned patterns (`service_reviews` direct table access, client-side `avg(` reduce for settlement display, `Colors.*`/hex in new files)

## 15. Performance Considerations

- **Pagination**: `get_for_listing` keyset (`(revealed_at DESC, id DESC)`, `limit<=100`, default 20); provider `loadMore` appends verbatim; no unbounded fetch; `ListView.builder` (never `Column` for review lists)
- **Read minimization**: `get_mine` single call per screen entry + pull-to-refresh; no polling loop (lifecycle `pausePolling/resumePolling` inherited shape but no timer — reveal is user-driven refresh + notification-driven entry, avoiding Realtime cost; Realtime for reviews is explicitly out — EP-03-18 notification fan-out covers it)
- **No N+1**: contract-detail embed makes at most 1 `get_mine` call (not per-milestone); listing section makes at most 1 `get_for_listing` page + uses cached `avg_rating` from listing row for header (no separate aggregate fetch)
- **Build cost**: `const` constructors, `Selector`/scoped `read` (never whole-tree `watch` on provider), star widgets `StatelessWidget` with `RepaintBoundary` where lists scroll; media-free screens (no image pipeline)
- **Target**: submit round-trip p95 < 800ms on staging; listing reviews page p95 < 400ms (indexed revealed path); verified in EP-03-20 harness, not load-tested here

## 16. Testing Strategy

| Level | Location | Cases |
|---|---|---|
| Unit (provider/service/mapper) | `test/unit/reviews/*` | `ReviewMapper` null/comment/rating coercions; `ServiceReviewService.validateRating` (0/6/null → error, 1-5 → null), `validateComment` (empty→null-valid, 9 chars→error, 10/2000→valid, 2001→error); `ServiceReviewProvider` state transitions (`idle→loading→loaded/error`), `loadMore` cursor append, `_disposed` guard |
| Widget | `test/widget/reviews/*` | Submit form validation (0 stars blocks, 9-char comment blocks, star-only submits); pre-reveal shows `Waiting for the other party`, never counterparty rating (assert `find.text(counterpartyRating)` finds nothing); post-both shows both reviews + `Revealed` badge; `DoubleBlindStatusCard` 3 states golden; theme-token assertion (no `Colors.*` — scan + `ColorScheme.primary == #2D3FE7` analog); a11y semantics labels present |
| Integration (mocked datasource) | `test/integration/reviews/*` | Submit→`get_mine(you_have_submitted=true, revealed=[])`; both-submit→`revealed.length==2` + aggregate `avg == mean(ratings)` + `distribution` sums; `get_for_listing` pagination (page1 `has_more`, page2 no overlap, cursor-exhausted returns empty without oracle); `PLT005 Already reviewed` resubmit; `PLT005 Not reviewable` on `offered` contract; `PLT004` foreign contract identical to unknown |
| Contract-host regression | Existing `contract_detail` + `service_detail` suites | Review section renders without breaking milestone/escrow/timeline/booking CTA; non-participant sees no review CTA; owner-cannot-hire-self CTA unaffected |
| Router | `test/widget/router/*` | `/contracts/:id/review` + `/contracts/:id/reviews` require auth (redirect `?next=`), foreign id → not-found state; notification deep-link lands on reveal route |
| Static | CI | `dart analyze`, `flutter test`, `grep -rn 'Colors\.\|Color(0x' lib/systems/reviews`, `grep -rn 'service_reviews.*\.\(insert\|update\|select\)' lib/` (must be zero — RPC only), `grep -rn '\.reduce\|fold.*rating' lib/systems/reviews` (must be zero — no client aggregation) |
| Manual (staging) | — | Two-account E2E: A submits → A sees waiting; B submits → both receive reveal notification + both see ratings; expiry path verified via server clock (no client clock logic); Lagos-network throttle sanity (submit retry) |

Server pgTAP (`027/028`) is already green and is **not** re-run here; client tests assert blind-state non-disclosure at the widget layer (the timing-oracle mitigation).

## 17. Recommended Implementation Sequence

1. **Entities → DTOs → mapper** (`service_review.dart`, `service_review_dto.dart`, `review_mapper.dart`) + unit tests — unblocks everything, no dependencies beyond EP-03-03 column names
2. **Datasource + envelope parser + repository + impl** (`service_review_remote_data_source.dart`, `supabase_*`, `service_review_repository*.dart`) + unit tests with mocked `SupabaseClient` — mirrors contract datasource; verify `p_*` param names against migration (`p_contract_id/p_rating/p_comment/p_service_listing_id/p_limit/p_cursor`)
3. **Service facade + validators** (`service_review_service.dart`) + unit tests — vocab + `validate*` + redacted-logging assertions
4. **Provider + DI** (`service_review_provider.dart`, `reviews_dependency_injection.dart`, `data_layer.dart registerServiceReviewLayer`, barrel `reviews.dart`) + unit tests — provider shape review against `ServiceContractProvider`
5. **Reusable widgets** (`star_rating_input/display`, `rating_distribution_bar`, `review_list_tile`, `double_blind_status_card`) + widget goldens — theme-token + a11y assertions first, before screens consume them
6. **Submit screen + contract-detail embed** + widget/integration tests (blind-state non-disclosure, `PLT005/004` branches, `you_have_submitted` redirect)
7. **Reveal screen + listing-detail aggregate section** + pagination tests (`has_more/next_cursor`, empty states)
8. **Routes + guards + notification hooks** (`route_paths/names/app_router`, `NotificationService.show` call-sites with deep links) + router tests
9. **Cross-suite regression** (`flutter test` full, `dart analyze`, static grep gates) + staging two-account walkthrough evidence for EP-03-20 input

Steps 1–4 are strictly sequential (type dependency); 5–8 parallelizable after provider lands, but 6 must precede 7 (submit state drives reveal UI).

## 18. Expected Outcome

- A verified professional and their client can each submit a 1–5 star + optional comment review on an `active/completed/closed` contract exactly once; each sees `Waiting for the other party` (never the other's rating) until both submit or 14 days pass; then both see both reviews + updated stars/distribution on the listing — with zero client-side reveal logic and zero oracle leakage
- `service_detail_screen` shows server-truth stars + revealed distribution; `contract_detail_screen` offers a discoverable, role-correct review entry point; notifications confirm submit and reveal with deep links
- Full `test/unit + widget + integration` cover per §16; `dart analyze` clean; zero hardcoded colors/fonts; zero direct table access; reusable star/blind-status kit ready for EP-04 product ratings
- Unblocks `EP-03-09` reputation depth display, feeds `EP-03-06` ranking data, and provides the review-event source for `EP-03-18` notification matrix

## 19. Definition of Done (DoD)

- [ ] `lib/systems/reviews/{services,screens,widgets}` + `lib/data/{entities,models,mappers,datasources/remote/service_review_*,repositories/service_review_*,providers/service_review_provider.dart}` implemented per §7–8; `registerServiceReviewLayer` wired; no other `lib/` production file modified except additive slots (`contract_detail_screen`, `service_detail_screen`, router trio, `data_layer.dart`)
- [ ] All reads/writes via the 3 existing RPCs with envelope unwrap; `service_review_reveal_if_ready` never invoked directly; no `supabase.from('service_reviews')` anywhere (`grep` gate passes)
- [ ] Blind invariant holds in UI: pre-reveal never renders counterparty `rating/comment` (widget test asserts absence); only `you_have_submitted` drives copy; `PLT004` copy identical for foreign/unknown/draft
- [ ] `rating 1-5` enforced + `comment` null-or-10–2000 parity client-side with server-authoritative errors mapped per §11; duplicate submit yields friendly already-reviewed guidance
- [ ] `service_detail` aggregate (`avg/review_count/distribution`) renders verbatim from `get_for_listing`; no client average computation (`grep` gate passes); list order verbatim server order
- [ ] Routes `/contracts/:id/review` + `/contracts/:id/reviews` live, guarded, deep-linkable; notification tap lands correctly; signed-out preserves `?next=`
- [ ] All UI consumes `ColorScheme`/`AppThemeExtension`/`TextTheme` only; `HivorrCard/Button/EmptyState/ErrorState/LoadingState/SuccessState/Snackbar` used throughout; responsive via `HivorrScreenScaffold`/`HivorrContentPane`; `>=48dp` CTAs; `Semantics` on stars/status
- [ ] `flutter test` (unit + widget + integration per §16) green; `dart analyze` clean; static grep gates (no `Colors.*`/hex/`fontFamily`, no direct table I/O, no client rating reduce) pass
- [ ] No `supabase/migrations/*` added or altered; no `lib/engine`, `lib/ai`, finance/escrow, messaging, scheduling, or dispute logic touched
- [ ] Staging two-account walkthrough recorded (submit → waiting → both-submit → revealed + notification) as input evidence for EP-03-20

---

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High**
- **Reasoning Level Justification:** Technical complexity is **moderate-high** (blind-state UX with 3 states, keyset pagination, envelope-mapped error branches, provider lifecycle — but no new SQL, no financial ledger, no crypto). Business impact is **high** (trust compounding; a leak reintroduces retaliation). Security risk is **medium-high** (timing-oracle non-disclosure must hold at widget/copy level even though server enforces it — requires disciplined copy and `PLT004`-identical handling). Data/integration complexity is **moderate** (3 RPCs, 2 host-screen embeds, router + notification hooks, all patterns already proven by EP-03-10). This matches the Phase Plan's own calibration (`EP-03-12: Planning High / Coding High`, `§13` — High tier, not Extremely/Very High reserved for schema/ranking/escrow). **High** provides sufficient rigor for oracle-safe UX and reusable widget design without the exhaustive formal-verification overhead required for escrow or ranking SQL.

---

*Planning artifact only. No production code written. Awaiting approval before implementation.*
