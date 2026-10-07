# Task Definition of Done — EP-03-12: Contract Double-Blind Review & Rating Experience (Client)

**Task ID:** EP-03-12 | **Priority:** High | **Phase:** EP-03 Stage 5 — Trust & Coordination
**Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-12 Contract Double-Blind Review & Rating Experience (Client).md` (§1–20)
**Dependencies:** EP-03-03 server primitive (`supabase/migrations/20260924090001_service_review_schema.sql` + pgTAP 027/028), EP-03-10 contract slice, EP-02-19 portfolio pattern

> Practical verification checklist for the project lead. No migration is included in this task — server reuse only. Mark the task completed only when every box below is checked with evidence.

---

## 1. Task Identification

- [ ] Task ID confirmed: EP-03-12
- [ ] Task Name confirmed: Contract Double-Blind Review & Rating Experience (Client)
- [ ] Related Phase confirmed: EP-03 Stage 5 — Trust & Coordination
- [ ] Reference Implementation Plan reviewed: `EP-03-12 Contract Double-Blind Review & Rating Experience (Client).md`
- [ ] Dependencies verified present (EP-03-03 RPCs + pgTAP green, EP-03-10 contract lifecycle, shared design system)
- [ ] No new tables / columns / RLS / RPCs introduced by this task confirmed

## 2. Functional Verification

- [ ] Participant on an `active` / `completed` / `closed` contract can submit exactly one review: 1–5 stars + optional comment (empty comment = valid star-only)
- [ ] `review_submit_screen` (`/contracts/:id/review`) presents star input + comment field with live counter + blind disclaimer + submit CTA; `you_have_submitted == true` redirects to the reveal route (no double-submit UI)
- [ ] `review_reveal_screen` (`/contracts/:id/reviews`) renders `DoubleBlindStatusCard` in the correct state:
  - [ ] `awaiting_yours` shows submit CTA (`HivorrBadge info`)
  - [ ] `awaiting_counterparty` shows `Waiting for the other party` copy with no rating shown
  - [ ] `revealed` shows both reviews with `Revealed` badge (`HivorrBadge success`)
- [ ] Pre-reveal viewer sees only own `your_review` + `you_have_submitted`; counterparty `rating` / `comment` is never rendered pre-reveal
- [ ] Post-both-submit (or 14-day expiry) both parties see both `revealed_reviews[]`
- [ ] Contract-detail `ReviewSection` (after timeline, before CTA panel) shows `Write a review` / `View reviews`; hidden entirely for non-participants
- [ ] Listing-detail section shows aggregate header (stars + count + distribution) + first revealed page; shows `No reviews yet` (`HivorrEmptyState compact`) when `review_count == 0`
- [ ] Submit success shows `HivorrSuccessState (celebrate: false, title: Review submitted, blind-aware subtitle)` then push-replaces to the reveal route
- [ ] Error handling verified:
  - [ ] `PLT003` validation → inline field error
  - [ ] `PLT005 Already reviewed` → friendly already-submitted guidance + link to reveal
  - [ ] `PLT005 Not reviewable` (e.g. `offered` contract) → `HivorrErrorState` with back-to-contract action
  - [ ] `PLT004` foreign / unknown / draft → identical not-found state (no existence oracle)
  - [ ] `PLT001` signed-out → login resume with `?next=` preserved
  - [ ] Transport failure → `HivorrErrorState` retry; no optimistic reveal
- [ ] Star-only submit accepted; 0-star and 6-star blocked; 9-character comment blocked; submit disabled while in-flight
- [ ] Notifications verified: `review_submitted` confirm on submit; `review_revealed` on `revealed.length 0 → 2` transition; tap deep-links to `/contracts/:id/reviews`; comment body never in payload

## 3. Technical Verification

- [ ] Architecture compliance: new code only under `lib/systems/reviews/{services,screens,widgets}` and `lib/data/{entities/service_review.dart, models/service_review_dto.dart, mappers/review_mapper.dart, datasources/remote/service_review_*, repositories/service_review_*, providers/service_review_provider.dart}`; `reviews.dart` barrel + `reviews_dependency_injection.dart (registerReviewsLayer)` present; `data_layer.dart registerServiceReviewLayer` wired
- [ ] No other `lib/` production files modified except additive slots (`contract_detail_screen`, `service_detail_screen`, router trio `route_paths.dart` / `route_names.dart` / `app_router.dart`, `data_layer.dart`)
- [ ] All reads/writes go through `service_review_submit` / `service_review_get_mine` / `service_review_get_for_listing` with envelope unwrap; `service_review_reveal_if_ready` never invoked directly; no `supabase.from('service_reviews')` anywhere (grep gate passes)
- [ ] Separation of Concerns: screens consume Service / Provider only, never `SupabaseClient` directly; no financial math, no ranking logic, no reveal decision in client
- [ ] Revealed list order rendered verbatim (server `(revealed_at DESC, id DESC)`); no client re-sort; no client average computation (grep gate passes)
- [ ] Module integration: contract milestone / escrow / timeline / booking CTA behavior unbroken; 2 new protected routes live and guarded via `route_guard.dart` pattern; no changes to `supabase/*`, `lib/engine/*`, `lib/ai/*`, `lib/systems/finance/*`, `lib/systems/communication/*`, `lib/systems/scheduling/*`
- [ ] Visual Identity compliance: 100% `Theme.of(context).colorScheme` / `AppThemeExtension` / `TextTheme`; `HivorrCard` / `HivorrButton` / `HivorrEmptyState` / `HivorrErrorState` / `HivorrLoadingState` / `HivorrSuccessState` / `HivorrSnackbar` used; responsive via `HivorrScreenScaffold` / `HivorrContentPane`; CTAs `>= 48dp`; `Semantics` on stars and status card; no `Colors.*` / raw hex / per-widget `fontFamily` (grep gate passes)
- [ ] Logging / tracing: redacted logs only (ids + ratings + booleans, never comment text); `reviews.*` performance spans present

## 4. Data Verification

- [ ] `ServiceReview` fields map 1:1 to RPC shape (`rating` int-or-numeric, nullable `comment`, `is_revealed`, nullable `revealed_at` / timestamps); uuids treated as opaque strings
- [ ] `ReviewAggregate` verified (`avg_rating 0–5`, `review_count >= 0`, `distribution {1..5}`, `last_revealed_at`)
- [ ] `MyReviewStatus` verified (`you_have_submitted`, `your_review` owner-visible even unrevealed, `revealed_reviews[]` server-filtered only, `review_count`)
- [ ] `ListingReviewsPage` verified (revealed-only, verbatim server order, `has_more`, opaque `next_cursor`)
- [ ] Pagination verified: page 1 `has_more`, page 2 no overlap, exhausted/unknown cursor returns empty without oracle
- [ ] No `Hive` persistence of review bodies; transient provider memo only; fresh server re-read on entry + pull-to-refresh (server lazy reveal on expiry)
- [ ] Client validation parity confirmed (rating 1–5, comment null-or-10–2000 trimmed, non-empty contract id) as fail-fast only; server remains authoritative

## 5. Security Verification

- [ ] Authentication: `submit` / `get_mine` require authenticated caller; `get_for_listing` anon path allowed only for `published` listings (public stars)
- [ ] Authorization: `reviewer == auth.uid()` server-derived; client sends only `contract_id + rating + comment` (never `reviewer` / `reviewee` / `profession` / `listing` ids); viewer-vs-participant checks are CTA-visibility only
- [ ] No timing oracle: no `1/2 submitted` counter, no `updated_at` hint, single static pre-reveal copy, identical `PLT004` copy for foreign / unknown / draft
- [ ] Sensitive data protection: comment bodies never logged, never in push payloads, never in Sentry breadcrumbs; `created_by` audit stays server-side
- [ ] Immutability: no edit / delete affordance exists; resubmit correctly yields `PLT005`
- [ ] Transport: all calls via authenticated `supabase.rpc` with JWT refresh (`auth_interceptor`)
- [ ] Static security gates pass: no direct `service_reviews` table I/O, no client-side rating aggregation for display truth

## 6. Performance Verification

- [ ] `get_mine` issued at most once per screen entry + explicit pull-to-refresh; no polling loop; no Realtime subscription for reviews
- [ ] Contract-detail embed issues at most 1 `get_mine` (not per milestone); listing section issues at most 1 `get_for_listing` page + cached header (no separate aggregate fetch); no N+1
- [ ] Review lists use `ListView.builder` (never unbounded `Column`); `const` constructors and scoped `read` / `Selector` (no whole-tree `watch`); media-free screens
- [ ] Staging targets observed: submit round-trip p95 < 800ms; listing reviews page p95 < 400ms (indexed revealed path; EP-03-20 harness reference)

## 7. Testing Verification

- [ ] Manual testing: two-account staging E2E completed (A submits → A sees waiting; B submits → both receive reveal notification + both see ratings); expiry path verified via server clock (no client clock logic); throttled-network submit retry sanity
- [ ] Automated unit tests (`test/unit/reviews/*`) green: mapper null / comment / rating coercions; `validateRating` (0 / 6 / null → error; 1–5 → valid); `validateComment` (empty → valid star-only; 9 chars → error; 10 / 2000 → valid; 2001 → error); provider `idle → loading → loaded / error`, `loadMore` cursor append, `_disposed` guard
- [ ] Automated widget tests (`test/widget/reviews/*`) green: form gates (0 stars blocks, 9-char comment blocks, star-only submits); pre-reveal shows waiting text and counterparty rating is absent (asserted); post-both shows both reviews + `Revealed` badge; `DoubleBlindStatusCard` 3-state goldens; theme-token assertion; accessibility semantics labels present
- [ ] Automated integration tests (`test/integration/reviews/*`) green: submit → `you_have_submitted == true` with empty revealed list; both-submit → `revealed.length == 2` + `avg == mean(ratings)` + distribution sums; `get_for_listing` pagination no-overlap; `PLT005` resubmit; `PLT005` not-reviewable on `offered`; `PLT004` foreign identical to unknown
- [ ] Host regression green: existing `contract_detail` + `service_detail` suites (milestone / escrow / timeline / booking CTA unbroken; non-participant sees no review CTA; owner self-hire guard unaffected)
- [ ] Router tests green (`test/widget/router/*`): both review routes require auth (redirect `?next=`); foreign id → not-found; notification deep-link lands on reveal route
- [ ] Static checks green: `dart analyze`, `flutter test`, `grep -rn 'Colors\.\|Color(0x' lib/systems/reviews` (zero hits), direct `service_reviews` table I/O grep (zero hits), client rating-reduce grep (zero hits)
- [ ] Edge cases covered: 14-day expiry reveal via refresh; concurrent both-submit single atomic reveal; `offered` / `cancelled` / `disputed` submit blocked; empty comment valid; over-long comment blocked
- [ ] Failure scenarios covered: transport failure retry; duplicate submit guidance (no crash); foreign-contract identical not-found

## 8. User Acceptance Verification

- [ ] Client and professional each complete submit → waiting → revealed flows on real devices (mobile + web) with calm empty / success / error states
- [ ] Star input operable by touch, keyboard / dpad, and screen reader with `>= 48dp` targets
- [ ] Listing shows truthful stars + distribution only post-reveal; `No reviews yet` otherwise
- [ ] Blind-honest copy verified on submit, waiting, and success states: hidden-until-both-or-14-days stated; no `1/2` counters or deadline leaks observable
- [ ] Role label `You are rating: Professional / Client` correct on both sides; symmetric flows confirmed
- [ ] Server pgTAP suites 027 / 028 remain green (not re-run here; widget-layer non-disclosure is this task's proof)

## 9. Final Approval Checklist

- [ ] All Functional (§2), Technical (§3), Data (§4), Security (§5), Performance (§6), Testing (§7), and UAT (§8) boxes checked with evidence (test runs, screenshots, staging walkthrough for EP-03-20 input)
- [ ] `flutter test` green; `dart analyze` clean; all static grep gates pass
- [ ] No `supabase/migrations/*` added or altered; no out-of-scope modules touched
- [ ] No hardcoded colors / fonts; no direct table access; no client-side rating aggregation
- [ ] Project lead sign-off recorded; task may be marked completed
