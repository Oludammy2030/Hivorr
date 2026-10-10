# Definition of Done — EP-03-16: Financial Reporting & Earnings Visibility System

> **Document type:** Task Definition of Done (verification checklist) | **Status:** Proposed — pending project-lead approval
> **Reference implementation plan:** `documents/Task-Implementation/EP-03/EP-03-16 Financial Reporting & Earnings Visibility System.md`
> **Phase plan source:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md` §11 (EP-03-16), §10 earnings criterion
> **No production code. No plan modification. Verification artifact only.**

---

## 1. Task Identification

- [ ] **Task ID:** EP-03-16
- [ ] **Task Name:** Financial Reporting & Earnings Visibility System
- [ ] **Related Phase:** EP-03 Stage 6 — Financial & Event Layer (Two-Party Transaction Engine & Professional Services Platform)
- [ ] **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-16 Financial Reporting & Earnings Visibility System.md` (single source of truth; this DoD does not reinterpret it)
- [ ] **Dependencies confirmed present:** EP-02-04 financial integrity schema, EP-03-02 contract schema, EP-03-11 escrow linkage + orchestrator, EP-01-07 API layer, EP-01-16 design system, EP-01-18 notifications
- [ ] **Out-of-scope guard acknowledged:** no write RPCs, no new ledger tables, no FX normalization, no new currencies/rails, no admin console, no export engine, no AI ordering, no EP-04 lanes, no Realtime ledger streaming

---

## 2. Functional Verification

### 2.1 Earnings summary (`service_earnings_summary`)

- [ ] Dashboard shows per-currency **available / held / pending / lifetime-earned** matching RPC `data` 1:1 (NGN, GHS, USD, GBP partitioned; default currency first)
- [ ] `lifetime_earned` reconciles with `SELECT SUM(amount)` ground truth over `financial_transactions` for released/milestone-release references in that currency
- [ ] `completed_contracts` count matches `COUNT(DISTINCT reference_id)` ground truth
- [ ] 6-month buckets render via `HivorrMonthBars`; months with no activity show honest `No activity yet` (no fabricated zero bars)
- [ ] `frozen_count` reflects disputed-escrow join; disputed amounts quarantined, never merged into available
- [ ] Every figure labeled `Server-verified`; no client-side summation determines any displayed total
- [ ] Invalid currency input returns `PLT003` envelope; UI currency guard fails fast before RPC

### 2.2 Transaction history (`service_transaction_history`)

- [ ] History lists ledger rows newest-first in RPC order (no client re-sort) with keyset cursor `(created_at DESC, id DESC)`
- [ ] Filters work: type (`all` / `earned` / `withdrawn` / `fund_locked` / frozen), currency selector, date range (`date_from`/`date_to`), `contract_id` scoping
- [ ] Pagination: 20-row default window, `hasMore`/`nextCursor` envelope, infinite scroll loads next page with zero overlap / zero gaps (verified over >40 seeded rows)
- [ ] Each row shows amount via `BalanceFormatter`, date via `HivorrFormatters`, truncated ref `***last4`, `contract_status` + `escrow_status` badges
- [ ] `p_limit` outside `[1,50]` returns `PLT005`; invalid cursor returns `PLT005` with `HivorrErrorState` + Retry (no crash)

### 2.3 Contract earnings drill-down

- [ ] Per-contract screen shows header (`ContractStatusBadge`), milestone rows (`MilestoneListCard` via `ContractMilestoneAdapter`), and contract-scoped ledger rows
- [ ] Actions deep-link correctly: `View contract` → `contractDetail(id)` (`/contracts/:id`); `View escrow` → `escrowDetailFor(escrowId)` (`/finance/escrow/:id`); `Get help` → `disputesFile(escrowId)` (deep-link only)
- [ ] Disputed contract shows `EscrowFrozenBanner`/`escrow_frozen_banner` with freeze explanation; no release/withdraw CTA rendered from any earnings screen

### 2.4 Mock-removal workflows

- [ ] `EarningsScreen` mock builders (`_earningsEntries`, `_EarningsHistoryEntry`, hardcoded chart bars) removed; screen renders live `EarningsProvider` + `TransactionHistoryProvider` data
- [ ] `TODO(pro-dashboard-backend): monthly-earnings seam` in `dashboard_overview_screen.dart` resolved to live buckets
- [ ] Existing `/dashboard/earnings` route preserved (no parallel earnings route tree); new `contractEarningsDetail` route follows `escrowDetailFor` builder pattern

### 2.5 Error handling & interactions

- [ ] Unauthenticated call → `PLT001` envelope; UI shows `HivorrErrorState` with login guidance (no ledger leak)
- [ ] Empty ledger → `HivorrEmptyState` (`No earnings yet` + owner `Create a listing` CTA); filtered-empty → `No earnings match this filter` + reset action
- [ ] Loading first paint → `HivorrLoadingState` / `HivorrSkeletonList` (reduced-motion safe, no shimmer)
- [ ] RPC failure → `HivorrErrorState` + Retry; retry re-invokes provider without duplicating rows
- [ ] Offline → serves last cached window + `SyncStatus.offline` banner; no write queue created (read-only, nothing to replay)
- [ ] Pull-to-refresh refreshes summary + current history window; filter change resets cursor to first page
- [ ] `tier_0` user: read access preserved; `HivorrCtaBand` upsell (`Verify identity to withdraw`) shown without blocking reads

---

## 3. Technical Verification

- [ ] **Architecture compliance:** vertical slice respects `lib/` schema — entities → DTOs → mappers → remote (`BaseApiService.invoke` + `FinancialEnvelopeParser.unwrap`) → repositories → providers → `finance`/`analytics` services → screens/widgets; theme via `AppTheme` tokens only
- [ ] **Server-first invariant:** all aggregation in the two RPCs; `ServiceAnalyticsService` performs display formatting/grouping only (month-bucket mapping to `HivorrMonthDatum`/`HivorrBarDatum`, per-contract grouping of paginated rows) — zero settlement arithmetic
- [ ] **Required files exist:** `earnings_summary.dart`, `earnings_transaction.dart`, `earnings_summary_dto.dart`, `earnings_transaction_dto.dart`, `earnings_mapper.dart`, `earnings_remote_data_source.dart`, `supabase_earnings_remote_data_source.dart`, `earnings_repository.dart`, `earnings_repository_impl.dart`, `earnings_provider.dart`, `transaction_history_provider.dart`, `service_earnings_service.dart`, `service_analytics_service.dart` (first real file in `lib/systems/analytics/`), `earnings_summary_header`, `earnings_transaction_tile`, `monthly_earnings_section`, dashboard/history/detail screens
- [ ] **Module integration:** `ServiceEarningsService.summaryForAllCurrencies` sequential per-currency, default-first; currency guard via `FinancialService.isCurrencySupported`; `EscrowService`/`ContractService`/`DisputeService` reused as-is (no duplicated logic); `FinanceHistoryBadge` extended without breaking existing call sites; DI wired in `app_bootstrap.dart` + `finance.dart` barrel (+ analytics barrel)
- [ ] **Reuse checklist:** `Balance`/`BalanceOverviewCard`/`BalanceChip{available,held,pending}`, `MilestoneListCard`, `EscrowStatusBadge`/`ContractStatusBadge`/`DisputeStatusBadge`, `HivorrCard`/`HivorrStatCard`/`HivorrStatGrid`/`HivorrMonthBars`/`HivorrMiniBars`/`HivorrDataTable`/`HivorrListTile`/`HivorrChip`/`HivorrSelectField`, `CacheManager` (`finance:earnings:*`, ~60s TTL, `invalidatePrefix` on `notifyContractMilestoneEvent`), `PerformanceTracer` (`finance.*` spans), `PiiRedactor`, existing notification channels (consume `milestone_released` → one-shot `Payment received` → `/dashboard/earnings`; no new channel)
- [ ] **No forbidden additions:** no new charting package, no new state framework, no new API client, no new cache infra, no new notification channel, no new tables/triggers/views/cron/buckets
- [ ] **Visual identity:** zero `Colors.*`/raw-hex/`fontFamily` per-widget (static assertion); Earn green `#16A34A` accents; `titleLarge/headlineSmall w700` values; ≥48dp targets; `HivorrScreenScaffold` + responsive scaffold + `breakpoints.dart` + `MobileCompact` compliance
- [ ] **`dart analyze` clean; `flutter test` green**

---

## 4. Data Verification

- [ ] **No new persisted data:** migration adds two `STABLE SELECT`-only functions + `IF NOT EXISTS` indexes + grants; zero new tables/columns/triggers/policies (verified by migration diff + `supabase db reset` green)
- [ ] **Relationships:** history join `financial_transactions` → `service_contracts` (via `escrow_id` linkage from `20260923090001` + `20261006090001`) → `financial_escrow` verified; `contract_id` filter rejects non-participant contracts with `PLT001` (no cross-user rows)
- [ ] **Accuracy:** per-currency summary and all history pages reconcile 1:1 with direct `SELECT` ground-truth queries (evidence recorded: fund 2 contracts NGN 50k + USD 100 → release 1 milestone each → dashboard `available` per currency correct; history shows exactly 4 ledger rows fund+release × 2)
- [ ] **Integrity:** `financial_transactions` no-update/no-delete invariant re-asserted (posture test); functions `SECURITY INVOKER`, no `DEFINER`; month buckets bounded to 6; pagination `LIMIT n+1` probe correct
- [ ] **Multi-currency isolation:** amounts never mixed across currencies; no FX conversion applied (`ConversionService` untouched)
- [ ] **Cache safety:** cache transient-only via `CacheManager` (never persisted, no PII at rest); `earnings_released` event invalidates prefix and refreshes; no stale-settlement risk (cache displays only, RPC remains truth)

---

## 5. Security Verification

- [ ] **Authentication:** both RPCs require `auth.uid()`; unauthenticated → `PLT001`; `anon` has zero `EXECUTE` (posture test asserts)
- [ ] **Authorization / least privilege:** `GRANT EXECUTE ... TO authenticated` only on the two new functions; no new table grants; no direct PostgREST `SELECT` on `financial_transactions` from client (grant absence + lint); `REVOKE ... FROM anon` explicit
- [ ] **Access control / IDOR:** all predicates bind caller `entity_id`; leakage matrix green — User A ⊘ User B rows, User B ⊘ User A rows, unauthenticated zero rows, admin path unchanged
- [ ] **Sensitive data protection:** logs contain counts/currency only (amounts debug-redacted via `PiiRedactor`); ledger refs truncated `***last4` (`idRefSuffix`); no full account numbers exported; no export engine introduced
- [ ] **Dispute safety:** `disputed` rows flagged frozen and never actionable from earnings UI; writes remain behind escrow/payout gates
- [ ] **Auditability:** every displayed figure traceable to `financial_transactions` + `financial_audit_trail` rows; validation report includes SQL evidence per figure
- [ ] **Static security gate:** extended `trust_financial_logic_scan_verification` green — zero `.reduce(` / `.fold(` over `EarningsTransaction.amount` / `FinancialTransaction.amount` for settlement (display grouping in `earnings_mapper` only)

---

## 6. Performance Verification

- [ ] Summary + first history page **p95 < 400ms** on Staging (Phase Plan §10 gate; evidence with `EXPLAIN` index usage)
- [ ] Keyset pagination (no `OFFSET`); composite index `(entity_id, currency_code, created_at DESC, id DESC)` present and used; no N+1 (contract/escrow join inside RPC, not per-row client fetch)
- [ ] Multi-currency dashboard loads default currency first, others lazily (single round-trip per currency; no fan-out storm)
- [ ] Polling discipline: earnings polls only when visible (mirrors `FinancialProvider` pause/resume); invalidation event-driven, not blind polling
- [ ] 100-row scroll and filter-switch interactions remain jank-free on reference mobile profile; skeleton → content cross-fade without layout jump

---

## 7. Testing Verification

### 7.1 Automated (all green, evidence attached)

- [ ] pgTAP `service_earnings_posture.sql`: functions exist, `authenticated` EXECUTE granted, `anon` denied, no DEFINER, supporting indexes exist
- [ ] pgTAP `service_earnings_enforcement.sql`: `PLT001` unauth; `PLT003` bad currency; cross-entity zero rows; fund→release ground-truth match; pagination no-overlap + cursor integrity; disputed-flagged; limit bounds `PLT005`
- [ ] Unit: DTO↔entity mappers, analytics bucket formatting, filter→`p_filters` composition, currency guard
- [ ] Widget: RPC-order rendering (no client re-sort), filter chips → provider calls, disputed banner, all states, `HivorrMonthBars` honest-empty, 320/360/375/390/414/480/599/600+ `expectNoOverflowAtMobileWidths`, token assertions
- [ ] Integration: NGN 50k + USD 100 E2E (summary + 4-row history), deep-links land correctly, offline cached-window + banner, `earnings_released` → invalidate + refresh
- [ ] Static: `dart analyze`, `flutter test`, financial-logic scan, RLS leak matrix (0 leaks), `design_system_integration_test` token gate

### 7.2 Manual (project-lead walkthrough on Staging)

- [ ] Professional with released milestones sees correct per-currency figures; professional with zero earnings sees honest empty states (not zeros-as-data)
- [ ] Filter/currency/date/contract combinations exercised; cursor walk across ≥3 pages shows no duplicates/gaps
- [ ] Disputed contract verified frozen with help path; withdraw/release CTAs absent from earnings surfaces
- [ ] Drill path dashboard → history → contract detail → contract/escrow traversed without dead ends
- [ ] 320dp device check: no horizontal scroll on amounts; badges icon+text (never color-only)

### 7.3 Edge & failure cases

- [ ] `p_currency` lowercase/unsupported → `PLT003`; `p_limit` 0/51/negative → `PLT005`; malformed cursor → `PLT005`; unknown `contract_id` → empty page (not error leak)
- [ ] Concurrent release during history scroll → next-page cursor remains consistent; refresh reconciles
- [ ] Non-participant `contract_id` filter → `PLT001` empty (no oracle on other users' activity)
- [ ] `tier_0` read flow; notification-permission-denied path shows inline state (no crash)

---

## 8. User Acceptance Verification

- [ ] Real professional confirms figures match their payout expectations and bank-credit experience (trust check: available vs held vs lifetime clearly distinguishable)
- [ ] Professional can answer "which contract earned what" from the drill-down without support help
- [ ] Disputed-funds messaging understood without support escalation in UAT script
- [ ] No participant mistakes pending (held) for withdrawable; KYC upsell copy clear that reads are free but withdrawals require verification
- [ ] Accessibility pass: semantic figure labels, locale-aware amounts, badge meaning not color-dependent

---

## 9. Final Approval Checklist

- [ ] All §2–§8 boxes checked with evidence links (test runs, SQL ground-truth outputs, Staging walkthrough notes)
- [ ] Migration version-controlled, `supabase db reset` green, Staging promoted per ENV-007; production deployment approved through standard process (no direct-prod application)
- [ ] Zero client-settlement proof: grep for forbidden ledger reduce patterns clean + financial-logic scan report attached
- [ ] EP-03-20 evidence recorded: *"earnings summary/transaction history screens read server-aggregated RPCs — no client math determines settlement"*
- [ ] Interface sign-off recorded: EP-03-17/18/20 can consume summary/history shapes without modification
- [ ] No out-of-scope items introduced (verified by diff review: no write RPCs, no new tables, no FX, no export, no new packages)
- [ ] **Project-lead mark:** `Completed` only when every item above is satisfied; otherwise task remains `In Progress` with follow-up todos filed
