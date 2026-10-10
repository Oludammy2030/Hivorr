# Task Implementation Plan — EP-03-16: Financial Reporting & Earnings Visibility System

> **Mode:** Planning artifact only. No production code written. No Phase document modified. Awaiting approval before implementation.

---

## 1. Task Objective

Build a **read-only, server-truth earnings visibility layer** for Earn-side professionals (`offer` activity) that surfaces:

1. **Earnings summary** — available / held / pending / lifetime-earned per currency, derived server-side from `financial_balances` + immutable `financial_transactions` + `service_contracts` linkage.
2. **Transaction history** — paginated, filterable ledger view over `financial_transactions` scoped to the caller's `entity_id`.
3. **Contract earnings drill-down** — per-contract earned / held / disputed breakdown linking to existing `contract_detail` and `escrow_detail` screens.

Per the approved Phase Plan (§11 EP-03-16): two new read-only RPCs — `service_earnings_summary(p_currency)` and `service_transaction_history(p_filters, p_cursor)` — plus `lib/systems/finance/services/service_earnings_service.dart` + `lib/systems/analytics/services/service_analytics_service.dart`, and screens `earnings_dashboard_screen.dart`, `transaction_history_screen.dart`, `contract_earnings_detail_screen.dart`. **Zero write RPCs. Zero client-computed settlement.**

---

## 2. Business Problem Being Solved

Professionals cannot currently see trustworthy earnings:

- The only live finance UI is balance-scoped (`FinancialProfileScreen` + `BalanceOverviewCard`, per-escrow `EscrowDetailScreen`, conversion history). There is **no global ledger history, no lifetime-earned, no monthly trend, no per-contract earnings attribution**.
- The current `EarningsScreen` in `lib/systems/dashboard/screens/finance_hubs_screen.dart` is **mock-driven** (`_earningsEntries()`, `_EarningsHistoryEntry`, hardcoded chart bars mirroring `pro earning.png`, counts derived from `HireProvider.loadList` with no amounts). It cannot support retention, tax preparation, or payout decisions.
- Without server-derived earnings, professionals will either distrust payouts or perform client-side summation — a settlement-divergence risk explicitly called out in the Phase Plan risk register.

EP-03-16 converts the existing immutable ledger into a retention-driving, auditable earnings surface while preserving the invariant: **earnings truth lives in Postgres; the client only renders it.**

---

## 3. Scope

### In scope

1. **Server layer (migration-first):**
   - `service_earnings_summary(p_currency CHAR(3))` — SECURITY INVOKER, envelope `{success,code,message,data}`, self-scoped to `auth.uid()`.
   - `service_transaction_history(p_filters JSONB, p_currency CHAR(3), p_limit INT, p_cursor JSONB)` — keyset-paginated ledger read with contract join.
   - Explicit `GRANT EXECUTE ... TO authenticated`; `REVOKE` for `anon`; no new tables; no writes to ledger/balances.
   - pgTAP posture + enforcement tests.
2. **Data layer (vertical slice):**
   - Entities, DTOs, mappers, remote data sources, repositories, providers for earnings summary + transaction history, following existing finance seams.
3. **Service layer:**
   - `ServiceEarningsService` (finance facade, thin, traced) + `ServiceAnalyticsService` (analytics aggregation/formatting seam — monthly buckets, per-contract grouping of already-aggregated server rows only).
4. **Presentation layer:**
   - Live `earnings_dashboard`, `transaction_history`, `contract_earnings_detail` — reusing existing cards/chips/badges/scaffolds; replacing mock seams in `EarningsScreen` / `_ProEarningsChartCard` (extend, not duplicate).
   - Filters (type, currency, date range, contract), cursor pagination, empty/loading/error states, disputed-freeze banner, deep-links to `/contracts/:id` and `/finance/escrow/:id`.
   - `CacheManager` window caching, `PerformanceTracer` spans, PII-safe logging, `earnings_released` notification hook (consumer of EP-03-18 event, not a new fan-out).
5. **Quality gates:**
   - `trust_financial_logic_scan_verification` compliance (no client ledger arithmetic), visual-identity token compliance, responsive matrix, RLS leakage matrix.

### Dependencies required before build

| Dependency | Status | Why |
|---|---|---|
| EP-02-04 financial integrity schema (`20260829100004`) | Complete (assumed per Phase Plan §8) | Ledger + balances source of truth |
| EP-03-02 contract schema (`20260923090001`) + EP-03-11 linkage (`20261006090001`) | Inspected; linkage RPC + `review_period_expires_at` + release gate exist | Contract attribution join |
| EP-03-11 orchestrator + escrow release RPCs | Inspected | Earnings rows only materialize after verified release |
| EP-01-16 design system, EP-01-07 API layer, EP-01-18 notifications | Complete | UI/API/notify seams |

---

## 4. Out of Scope

Explicitly **excluded** — no silent expansion:

- ❌ Any write RPC (fund/release/refund/withdraw/convert/dispute). All writes remain with EP-02-04 / EP-03-11 / payout / conversion services.
- ❌ New ledger tables, balance recomputation, fee/pricing formulas, FX conversion logic, or cross-currency normalization (per-currency reporting only; `NGN/GHS/USD/GBP` scope preserved).
- ❌ New currencies, new payment rails, payout binding, KYC tier mutation (read-only display of existing `verification_limits_get` / `financial_status_get` only).
- ❌ New charting package — reuse `HivorrMonthBars` / `HivorrMiniBars`.
- ❌ Admin earnings console, platform-wide revenue analytics, CSV/PDF export engine (may leave a disabled seam button only if trivial; no export implementation).
- ❌ AI ranking/suggestion on earnings (`AGENT.md` Rule 1/Deterministic Core — AI never decides financial presentation order beyond RPC order).
- ❌ Local Market (`sell`), logistics, 3-party split (EP-04); EP-03-16 is services-`offer` lane only but designed so EP-04 can reuse the RPC pattern with an added `source` discriminator.
- ❌ Realtime ledger streaming — polling + cache invalidation suffices; Realtime stays with messaging/contracts.

---

## 5. Existing Asset and Dependency Analysis

Inspected via codebase exploration (subagent sweeps + grep for `service_earnings_summary|service_transaction_history` → **0 hits: confirmed genuine gap**).

### 5.1 Server / database (reuse — no new tables)

| Asset | Path | Reuse role |
|---|---|---|
| Financial integrity schema | `supabase/migrations/20260829100004_financial_integrity_schema.sql` — `financial_transactions` (immutable double-entry ledger), `financial_balances` (available/held/pending), `financial_escrow` + `financial_escrow_milestones`, `financial_audit_trail`, 17 RPCs, envelope `PLTxxx` | **Sole aggregation source.** New RPCs `SELECT` only from these; no schema change |
| Dispute freeze | `20260829120005_dispute_resolution_schema.sql` + `20260829120006_dispute_withdraw_definer.sql` | `disputed` escrow status must surface as frozen earnings |
| Contract schema + linkage | `20260923090001_service_contract_schema.sql` (`service_contracts.escrow_id` nullable) + `20261006090001_contract_escrow_linkage.sql` (`service_contract_link_escrow`, `service_contract_release_gate`) | Contract→escrow join key for per-contract earnings |
| Auto-release cron | `supabase/functions/escrow_milestone_auto_release/` | Only automated release path producing earnings rows — no change needed |
| pgTAP tests | `supabase/tests/database/013_financial_schema_posture.sql`, `014_financial_rpc_enforcement.sql`, `025/026_service_contract_*`, `042/043_contract_escrow_*` | Patterns to clone for new RPC tests |

### 5.2 Data layer (reuse / extend)

| Asset | Path | Reuse role |
|---|---|---|
| `Balance`, `FinancialStatus`, `Escrow`, `EscrowTransaction`, `ServiceContract` entities + DTOs + mappers | `lib/data/entities/balance.dart`, `financial_status.dart`, `escrow_transaction.dart`, `service_contract.dart`; `lib/data/models/balance_dto.dart`, `financial_status_dto.dart`, `escrow_transaction_dto.dart`; `lib/data/mappers/financial_mapper.dart`, `escrow_mapper.dart`, `contract_mapper.dart` | Clone patterns for `EarningsSummary` / `EarningsTransaction` entity+DTO+mapper; reuse `Balance` for balance chips |
| Remote seam | `supabase_financial_remote_data_source.dart` (`financial_balance_get`, `financial_status_get`), `financial_envelope_parser.dart` (`unwrap` PLT000), `base_api_service.dart` (`invoke()`), `ApiException` | Extend with `getEarningsSummary` / `listTransactions` via same envelope + error mapping |
| Repositories | `financial_repository(_impl).dart`, `escrow_repository(_impl).dart`, `service_contract_repository.dart` | New `EarningsRepository` mirrors interface style; delegates joins server-side |
| Providers | `financial_provider.dart`, `escrow_provider.dart`, `service_contract_provider.dart` (keyset `(created_at DESC, id DESC)` cursor + status filter + `hasMore/nextCursor`) | New `EarningsProvider` / `TransactionHistoryProvider` clone lifecycle: `LoadState`, `_disposed` guard, polling pause/resume, one-shot local notification hook |

### 5.3 Service layer (reuse)

| Asset | Path | Reuse role |
|---|---|---|
| `FinancialService`, `EscrowService` (pure progress math only), `ContractEscrowOrchestrator` + `ContractEscrowReleaseState` | `lib/systems/finance/services/` | **Reuse as-is.** Earnings service never duplicates their logic; reads their outputs. `EscrowService.releasedMilestoneTotal / milestoneProgress` informs pending-vs-released display vocabulary |
| `BalanceFormatter.formatBalance`, `SupportedCurrency`, `EscrowStatus`/`MilestoneStatus` vocab | `lib/systems/finance/helpers/`, `lib/systems/finance/models/` | Direct reuse for amounts, currency symbols, status tones |
| `ContractService`, `DisputeService` | `lib/systems/documents/services/contract_service.dart`, `lib/systems/support/services/dispute_service.dart` | Deep-link targets + frozen-state vocabulary; no logic copied |
| `lib/systems/analytics/` | Currently only `.gitkeep` — **empty** | Justifies placing aggregation-formatting seam here without colliding with existing code |

### 5.4 Presentation (reuse — extend, don't duplicate)

| Asset | Path | Reuse role |
|---|---|---|
| Mock earnings to replace | `lib/systems/dashboard/screens/finance_hubs_screen.dart` (`EarningsScreen`, `_earningsEntries`, `_EarningsFilter`, `_ProEarningsChartCard`) + `dashboard_overview_screen.dart` (`TODO(pro-dashboard-backend): monthly-earnings seam`) | **Primary integration seam.** Swap mock rows/bars for live provider data; keep layout/order/routes |
| Finance widgets | `balance_overview_card.dart` (`BalanceOverviewCard`), `balance_chip.dart` (`BalanceChipKind{available,held,pending}`), `milestone_list_card.dart`, `escrow_status_badge.dart`, `escrow_dispute_banner.dart` (+ support variant `escrow_frozen_banner.dart`), `finance_history_badge.dart` (to extend with real counts), `conversion_history_list.dart` (history-list pattern) | Direct reuse; new `earnings_summary_card`, `earnings_transaction_tile`, `monthly_earnings_chart` compose these |
| Shared design system | `HivorrCard`, `HivorrButton`, `HivorrChip`, `HivorrBadge`, `HivorrStatCard`/`HivorrStatGrid`, `HivorrMonthBars`, `HivorrMiniBars`, `HivorrDataTable` (≥600dp), `HivorrListTile`, `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`, `HivorrSkeletonList`, `HivorrSectionHeader`, `HivorrScreenScaffold`, `HivorrResponsiveScaffold`, `breakpoints.dart`, `MobileCompact`, `HivorrSpacing`, `HivorrFormatters` (dates), theme tokens (`AppColors`, `AppThemeExtension`, `RoleThemeExtension` — Earn green `#16A34A`) | All earnings UI composes these; **no new atoms** |
| Router | `route_paths.dart` (`dashboardEarnings=/dashboard/earnings`, `finance`, `escrowDetailFor(id)`, `contractDetail(id)`), `app_router.dart`, `route_guard.dart` | Reuse routes; add `contractEarningsDetail` + optional filtered history route following `escrowDetailFor` builder pattern |
| Infra | `CacheManager` (`finance:earnings:*` keys), `PerformanceTracer` (`finance.*` spans), `PiiRedactor`, `NotificationProvider` + `EscrowNotificationChannel`/`FinanceNotificationChannel` patterns, `SyncStatusProvider` (offline banner) | Reuse; no new infra |

### 5.5 Test assets (reuse)

`FakeFinancialRepository`, `FakeEscrowRepository`, `FakeServiceContract` fakes; `entity_builders`/`dto_builders`; `widget_harness` (`pumpScreen`), `responsive_harness` (`expectNoOverflowAtMobileWidths`); `trust_financial_logic_scan_verification.dart` (must-pass zero-client-arithmetic gate); `finance_history_badge_test.dart`, `dashboard_responsive_matrix_test.dart`, `contract_escrow_section_test.dart`, `escrow_proxy_seam_test.dart`, `financial_profile_flow_test.dart` as templates.

---

## 6. Reuse / Extension / Refactoring Assessment

| Proposed need | Verdict | Rationale |
|---|---|---|
| Ledger / balances / escrow tables | **Reuse** | `20260829100004` already immutable + RLS-hardened; new table would duplicate source of truth |
| `service_earnings_summary` + `service_transaction_history` RPCs | **Create (genuine gap)** | Grep confirms 0 existing RPCs aggregate earnings by contract/currency/month. `financial_balance_get`/`financial_status_get` return point balances only, no lifetime-earned, no monthly buckets, no ledger pagination with contract join. Extension of `financial_status_get` rejected: changing its envelope would break existing consumers (`FinancialProfileScreen`, admin screens); additive read-only RPCs preserve backward compatibility |
| `EarningsSummary` / `EarningsTransaction` entity+DTO+mapper+repository+provider | **Create (genuine gap)** | No earnings aggregate model exists. Designed as reusable platform capability: `source` discriminator (`service_contract` today, `order`/`dispatch` in EP-04) and per-currency shape so EP-04 reuses without rework |
| `ServiceEarningsService` + `ServiceAnalyticsService` | **Create (genuine gap)** | `FinancialService`/`EscrowService` are balance/escrow facades; neither aggregates earnings. Analytics dir is empty. New services are thin facades + display-formatting only (month bucketing of server rows, currency grouping) — **no settlement math** |
| Dashboard / history / detail screens | **Extend + refactor** | `EarningsScreen` + `_ProEarningsChartCard` + `TODO(pro-dashboard-backend)` seam already define layout/routes. Refactor: inject live providers behind the same widgets; delete mock entry builders; keep `HivorrStatCard`/`HivorrMonthBars` composition. No parallel earnings route tree |
| Widgets (summary card, ledger tile, chart, badges) | **Extend** | Compose `BalanceOverviewCard`, `BalanceChip`, `HivorrStatCard`, `HivorrMonthBars`, `HivorrDataTable`, `EscrowFrozenBanner`, `ContractStatusBadge`; add only `earnings_summary_header`, `earnings_transaction_tile`, `monthly_earnings_section` as thin composites in `lib/systems/finance/widgets/` |
| Cache / tracing / notifications / formatting | **Reuse** | `CacheManager`, `PerformanceTracer`, `BalanceFormatter`, `PiiRedactor`, existing notification channels cover needs |
| `FinanceHistoryBadge` | **Extend** | Currently counts payout accounts + deposits; extend to accept real ledger counts without breaking existing call sites |

**No parallel systems proposed.** Every new asset integrates with the existing finance→contract→support graph and is designed for EP-04 reuse.

---

## 7. Recommended Technical Approach

**Principle: server aggregates, client renders. Per-currency. Cursor-paginated. Cached window. Frozen-aware.**

### 7.1 Server (one self-contained migration + two pgTAP files)

New migration `supabase/migrations/<ts>_service_earnings_visibility.sql`:

- `service_earnings_summary(p_currency CHAR(3)) RETURNS JSONB envelope`:
  - Validates `p_currency ∈ (NGN,GHS,USD,GBP)` (`PLT003` otherwise), `auth.uid()` required (`PLT001`).
  - Resolves caller `entity_id` from `auth.uid()`; reads `financial_balances` (available/held/pending for currency), `SUM(amount) WHERE destination=entity AND reference_type IN ('escrow_release','milestone_release') AND currency` → `lifetime_earned`, `COUNT(DISTINCT reference_id)` → `completed_contracts`, month buckets (last 6 months, `date_trunc('month', created_at)`) from `financial_transactions`, `COUNT(*) WHERE status='disputed'` via escrow join → `frozen_count`.
  - `SECURITY INVOKER`, `GRANT EXECUTE TO authenticated`, `REVOKE ... FROM anon`.
- `service_transaction_history(p_currency CHAR(3), p_filters JSONB, p_limit INT, p_cursor JSONB) RETURNS JSONB envelope`:
  - Filters: `{type: earned|withdrawn|fund_locked|all, contract_id?, date_from?, date_to?}`; cursor `{created_at, id}` keyset `(created_at DESC, id DESC)`, `p_limit ∈ [1,50]`.
  - `SELECT t.*, c.id AS contract_id, c.status AS contract_status, e.status AS escrow_status FROM financial_transactions t LEFT JOIN service_contracts c ON ... LEFT JOIN financial_escrow e ON ... WHERE (t.entity_id = caller OR t.source_entity = caller ...) AND currency ORDER BY created_at DESC, id DESC LIMIT n+1` (hasMore probe). `disputed` rows flagged, never hidden.
  - Same security posture. Supporting index: `CREATE INDEX IF NOT EXISTS ... ON financial_transactions(entity_id, currency_code, created_at DESC, id DESC)` + contract-join index if missing (verify in migration with `IF NOT EXISTS`; no table rewrite).
- No triggers, no views requiring grants, no DEFINER, no cron, no storage changes.

### 7.2 Data layer (new files, existing patterns)

```
lib/data/entities/earnings_summary.dart      (per-currency totals + monthly buckets + frozen count)
lib/data/entities/earnings_transaction.dart  (ledger row + contract_id/status + escrow_status + direction)
lib/data/models/earnings_summary_dto.dart    (fromEnvelope)
lib/data/models/earnings_transaction_dto.dart (+ page envelope: items/hasMore/nextCursor)
lib/data/mappers/earnings_mapper.dart
lib/data/datasources/remote/earnings_remote_data_source.dart (abstract)
lib/data/datasources/remote/supabase_earnings_remote_data_source.dart (via BaseApiService.invoke + FinancialEnvelopeParser.unwrap)
lib/data/repositories/earnings_repository.dart (abstract: getSummary(currency), listTransactions(...))
lib/data/repositories/earnings_repository_impl.dart
lib/data/providers/earnings_provider.dart (summary state + polling pause/resume)
lib/data/providers/transaction_history_provider.dart (cursor list state: items/hasMore/nextCursor/filter setters)
```

Rules: repositories extend `BaseApiService`; single surfaced error `ApiException`; PII-safe logs (counts + currency only, never amounts in logs beyond debug-redacted); `SupportedCurrency` validation client-side before RPC (fail fast, server still authoritative).

### 7.3 Service layer (two thin facades)

- `lib/systems/finance/services/service_earnings_service.dart` — `getSummary`, `listHistory`, `summaryForAllCurrencies` (sequential per-currency calls, default-currency-first per `BalanceOverviewCard` convention), currency-support guard via `FinancialService.isCurrencySupported`.
- `lib/systems/analytics/services/service_analytics_service.dart` — formats server buckets into `HivorrMonthDatum` / `HivorrBarDatum` lists, per-contract grouping of the already-paginated rows, `relative` date labels via `HivorrFormatters`. **Explicitly forbidden: summing `amount` to derive balances or settlement; only grouping/counting for display.**

### 7.4 Presentation (extend existing screens)

- Refactor `EarningsScreen` (`finance_hubs_screen.dart`): replace `_earningsEntries()` with `TransactionHistoryProvider` items; replace mock chart with `monthly_earnings_section` fed by `EarningsProvider.summary.monthlyBuckets` via `HivorrMonthBars` (honest `No activity yet` empty); summary row via `HivorrStatGrid` + `BalanceOverviewCard`; filter chips (`HivorrChip`: All/Earned/Withdrawn/Frozen) → provider filter; currency selector (`HivorrSelectField`) → provider currency.
- `transaction_history_screen.dart`: `HivorrScreenScaffold` + `RefreshIndicator` + `ListView` of `earnings_transaction_tile` (<600dp) / `HivorrDataTable` (≥600dp) + infinite-scroll cursor load + `EscrowFrozenBanner` inline on disputed rows.
- `contract_earnings_detail_screen.dart`: contract header (`ContractStatusBadge`), milestone rows (`MilestoneListCard` via `ContractMilestoneAdapter`), ledger rows for contract, actions `View contract` → `contractDetail(id)`, `View escrow` → `escrowDetailFor(escrowId)`, `Get help` → `disputesFile(escrowId)` (deep-link only, per EP-03-10 boundary).
- States: `HivorrLoadingState` / `HivorrSkeletonList` first paint, `HivorrEmptyState` (`No earnings yet` + `Create a listing` CTA for owner), `HivorrErrorState` + Retry, offline banner via `SyncStatusProvider`.
- Caching: `CacheManager` `finance:earnings:{entity}:{currency}` summary (TTL ~60s) + history window; `invalidatePrefix('finance:earnings:')` on `earnings_released` notification / escrow provider `notifyContractMilestoneEvent`.
- Notifications: consume `milestone_released` event (EP-03-18 producer) → one-shot local `Payment received` deep-linking `/dashboard/earnings`; no new channel (reuse `EscrowNotificationChannel.system`).

---

## 8. Required Systems, Modules, and Components

| # | Component | Location | New / Reuse / Extend |
|---|---|---|---|
| 1 | `service_earnings_summary` + `service_transaction_history` RPCs | `supabase/migrations/<ts>_service_earnings_visibility.sql` | **New** |
| 2 | pgTAP posture + enforcement | `supabase/tests/database/<nn>_service_earnings_*.sql` | **New** (clone 013/014) |
| 3 | Entities/DTOs/mappers | `lib/data/entities/earnings_*.dart`, `lib/data/models/earnings_*_dto.dart`, `lib/data/mappers/earnings_mapper.dart` | **New** |
| 4 | Remote data sources | `lib/data/datasources/remote/*earnings*` | **New** |
| 5 | `EarningsRepository(+Impl)` | `lib/data/repositories/earnings_repository*.dart` | **New** |
| 6 | `EarningsProvider`, `TransactionHistoryProvider` | `lib/data/providers/` | **New** |
| 7 | `ServiceEarningsService` | `lib/systems/finance/services/service_earnings_service.dart` | **New** |
| 8 | `ServiceAnalyticsService` | `lib/systems/analytics/services/service_analytics_service.dart` | **New** (first real analytics file) |
| 9 | Earnings dashboard / history / contract-detail screens | `lib/systems/finance/screens/` + refactor `lib/systems/dashboard/screens/finance_hubs_screen.dart` | **Extend** |
| 10 | `earnings_summary_header`, `earnings_transaction_tile`, `monthly_earnings_section` widgets | `lib/systems/finance/widgets/` | **New (thin composites)** |
| 11 | `FinanceHistoryBadge` real counts | `lib/systems/finance/widgets/finance_history_badge.dart` | **Extend** |
| 12 | Routes (`contractEarningsDetail`, history filters) | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart` | **Extend** |
| 13 | DI wiring | `lib/app/app_bootstrap.dart`, `lib/systems/finance/finance.dart` (+ analytics barrel) | **Extend** |
| 14 | Balances, escrow, contracts, disputes, shared UI, cache, tracing, notifications | Existing paths (§5) | **Reuse** |

---

## 9. Data Requirements

- **Read sources:** `financial_transactions` (all amount truth), `financial_balances` (available/held/pending chips), `financial_escrow`/`financial_escrow_milestones` (pending + disputed flags), `service_contracts` + `contract_milestones` (attribution), `financial_payouts` (withdrawn leg), `entity_profiles.legal_name` (display anchor only, never recomputed).
- **No new persisted data.** Monthly buckets and per-contract groupings are computed at query time in the RPC (server) and formatted in `ServiceAnalyticsService` (client display only).
- **Multi-currency:** all aggregates partitioned by `currency_code`; UI shows per-currency sections default-first; **no FX normalization** in v1 (avoids rate-trust liability; `ConversionService` untouched).
- **Pagination:** keyset `(created_at DESC, id DESC)`, limit 20 default / 50 max, `hasMore/nextCursor` envelope.
- **Retention:** history reads full ledger (no TTL truncation); cache is transient-only (`CacheManager`, never persisted, no PII at rest).

---

## 10. Database Considerations

- **No new tables, columns, triggers, or RLS policies on existing tables.** The migration adds two `SECURITY INVOKER` functions + least-privilege `GRANT EXECUTE TO authenticated` + supporting indexes (`IF NOT EXISTS`).
- **RLS posture preserved:** functions resolve caller via `auth.uid()` → `entity_id` mapping already used by `financial_balance_get`; `anon` gets `PLT001`; cross-entity reads impossible (all predicates bind caller entity; leakage-matrix test asserts User A ⊘ User B rows).
- **Immutability preserved:** functions are `STABLE`, `SELECT`-only; `financial_transactions` no-update/no-delete invariant untouched (posture test re-asserts).
- **Migration compliance:** self-contained per DB-Migration Rules §§11/21 (function + grants + indexes in one file), `supabase db reset` compatible, Staging-first promotion per ENV-007, no DEFINER (extra review avoided).
- **Performance:** keyset pagination + composite index avoids `OFFSET` degradation; month-bucket aggregation bounded to 6 buckets; `EXPLAIN` evidence in validation report.

---

## 11. API Requirements

| RPC | Signature | Auth | Envelope codes |
|---|---|---|---|
| `service_earnings_summary` | `(p_currency CHAR(3))` | `authenticated` EXECUTE; `anon` denied | `PLT000` ok; `PLT001` unauth; `PLT003` bad currency; `PLT999` internal |
| `service_transaction_history` | `(p_currency CHAR(3), p_filters JSONB, p_limit INT, p_cursor JSONB)` | Same | Same + `PLT005` invalid cursor/limit |

- Client access exclusively through `SupabaseEarningsRemoteDataSource` (extends `BaseApiService`, `Dio` + interceptors preserved); **no direct PostgREST `SELECT` on `financial_transactions`** from the client (blocked by lack of grants + CI lint).
- Static guard: extend `trust_financial_logic_scan_verification` to forbid `.reduce(`/`.fold(` over `EarningsTransaction.amount` / `FinancialTransaction.amount` outside `earnings_mapper` display grouping (settlement use fails CI).
- Idempotency/offline-write machinery not needed (read-only); offline behavior = serve last cached window + `SyncStatus.offline` banner, replay nothing.

---

## 12. User Interface Requirements

- **Screens (3):** earnings dashboard (summary + monthly chart + recent ledger preview), transaction history (full filterable ledger), contract earnings detail (per-contract breakdown + milestone + ledger + deep-links).
- **Composition (no new atoms):** `HivorrScreenScaffold` + `HivorrResponsiveScaffold`, `HivorrStatGrid`/`HivorrStatCard` (Available / In escrow / Lifetime earned), `BalanceOverviewCard` + `BalanceChip`, `HivorrMonthBars` (monthly), `HivorrMiniBars` (per-contract split), `HivorrChip` filters, `HivorrSelectField` currency, `HivorrDataTable` (wide) / `HivorrListTile` rows (narrow), `EscrowStatusBadge`/`ContractStatusBadge`/`DisputeStatusBadge` tones, `EscrowFrozenBanner` on disputed, `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrSkeletonList`.
- **Formatting:** amounts via `BalanceFormatter.formatBalance` (intl-aware `₦/₵/$/£`); dates via `HivorrFormatters`; ledger refs via `idRefSuffix` (`***last4`).
- **Token compliance:** `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` only; Earn green `#16A34A` accents; zero `Colors.*`/hex/`fontFamily` per-widget (DoD gate). Touch targets ≥48dp; 320–600dp overflow matrix.

---

## 13. User Experience Considerations

- **Honest empty states:** `No earnings yet — publish a listing to get hired` (owner CTA) vs `No earnings match this filter` (filter reset CTA); chart shows `No activity yet`, never zero-fabricated bars.
- **Trust signaling:** every figure labeled `Server-verified`; disputed amounts visually quarantined with freeze explanation + `Get help` deep-link; pending (held) vs available vs lifetime clearly separated to prevent "where is my money" confusion.
- **Progressive disclosure:** dashboard → history → contract detail drill path; amounts never require horizontal scroll on 320dp.
- **Feedback:** pull-to-refresh, cursor infinite scroll with `HivorrLoader`, Retry on error, `HivorrSnackbar` on filter/copy actions, reduced-motion-safe skeletons (no shimmer).
- **Accessibility:** semantic labels on figures, badge tones never color-only (icon + text), locale-aware amounts.
- **KYC awareness:** if `tier_0`, show `HivorrCtaBand` upsell (`Verify identity to withdraw`) without blocking read access (reads are not withdrawals; gate messaging only).

---

## 14. Security Considerations

1. **Zero-trust client:** no ledger/balance arithmetic determines settlement; RPCs are the sole aggregators (`AGENT.md` Rule 4). CI scan enforces.
2. **Least privilege:** `authenticated` EXECUTE only on the two new RPCs; `anon` zero; no new table grants; no DEFINER; self-scoped predicates (`auth.uid()` → entity).
3. **IDOR resistance:** `contract_id` filter validated as participant-or-empty; non-participant contract history returns empty with `PLT001`, never other users' rows (leakage matrix test).
4. **PII:** amounts/refs never in logs beyond redacted form (`PiiRedactor`); ledger refs truncated (`***last4`); no export of full account numbers.
5. **Dispute safety:** `disputed` rows flagged frozen; no release/withdraw CTA rendered from earnings screens (writes live only in escrow/payout systems behind their gates).
6. **Audit reuse:** every figure traceable to `financial_transactions` + `financial_audit_trail` rows; validation report includes SQL evidence per figure.

---

## 15. Performance Considerations

- Keyset pagination (no `OFFSET`), 20-row windows, `hasMore` probe via `LIMIT n+1`; composite index on `(entity_id, currency_code, created_at DESC, id DESC)`.
- Summary RPC single round-trip per currency; multi-currency dashboard loads default currency first, others lazily.
- `CacheManager` 60s summary TTL + history-window cache; `invalidatePrefix` on release events only (no blind polling storm; reuse `FinancialProvider` 15s polling discipline — earnings polls only when visible).
- `EXPLAIN` index-usage evidence; target p95 < 400ms for summary + first history page on Staging (Phase Plan §10 gate); no N+1 (contract join in-RPC, not per-row client fetch).

---

## 16. Testing Strategy

| Layer | Tests (new, cloning existing patterns) |
|---|---|
| **pgTAP** | `service_earnings_posture.sql`: functions exist, `authenticated` EXECUTE granted, `anon` denied, no DEFINER. `service_earnings_enforcement.sql`: unauth → `PLT001`; bad currency → `PLT003`; User A ⊘ User B rows; fund-2-contracts → release-1-milestone-each → summary matches `SELECT SUM()` ground truth; history pagination no-overlap + cursor integrity; disputed contract flagged frozen; limit bounds enforced |
| **Unit** | DTO↔entity mappers, `ServiceAnalyticsService` bucket formatting, filter→`p_filters` composition, currency guard |
| **Widget** | Dashboard renders RPC order (no client re-sort), filter chips → provider calls, disputed banner visible, empty/loading/error states, `HivorrMonthBars` honest-empty, 320–600dp `expectNoOverflowAtMobileWidths`, token assertions (no `Colors.*`) |
| **Integration** | Fund NGN 50k + USD 100 contracts → release 1 milestone each → dashboard per-currency `available` correct; history shows 4 ledger rows (fund+release × 2); deep-links land on `/contracts/:id` + `/finance/escrow/:id`; offline → cached window + banner; `earnings_released` → cache invalidate + refresh |
| **Static/security** | `dart analyze`, `flutter test`, extended `trust_financial_logic_scan_verification` (zero settlement reduce), RLS leak matrix 0 leaks, `design_system_integration_test` token gate |
| **Fakes** | `FakeEarningsRepository` + `FakeEarningsRemoteDataSource` in `test/support/fakes/finance/` mirroring existing fakes; builders in `entity_builders`/`dto_builders` |

---

## 17. Recommended Implementation Sequence

1. **Migration + pgTAP** — write `<ts>_service_earnings_visibility.sql` (both RPCs + indexes + grants); pgTAP posture + enforcement; `supabase db reset` green; Staging promotion.
2. **Data layer** — entities → DTOs → mapper → remote → repository → providers; unit tests per file; fakes + builders.
3. **Services** — `ServiceEarningsService` → `ServiceAnalyticsService`; unit tests; wire into `finance.dart` barrel + `app_bootstrap.dart` DI.
4. **Widgets (composites)** — `earnings_summary_header`, `earnings_transaction_tile`, `monthly_earnings_section`; widget tests with fakes.
5. **Screens + router** — dashboard refactor (mock swap) → history → contract detail; route additions; responsive + token tests.
6. **Cache/notify polish** — `CacheManager` keys + invalidation on `notifyContractMilestoneEvent`; `earnings_released` local notification hookup (consume EP-03-18 event contract).
7. **Gates** — financial-logic scan, design-system gate, RLS matrix, Staging E2E (Phase Plan §10 earnings criterion), validation evidence for EP-03-20 handoff.

Each step independently reviewable; steps 1–2 unblock EP-03-17/18 consumers without rework (additive interfaces).

---

## 18. Expected Outcome

A professional opens `/dashboard/earnings` and sees **server-verified** available / held / lifetime-earned per currency, a 6-month earnings chart, and a filterable ledger whose every row drills into its contract and escrow — with disputed funds clearly quarantined. All figures reconcile 1:1 with `SELECT` ground truth over `financial_transactions`. The mock earnings seam is eliminated; no client summation influences settlement; EP-04 can extend the same RPC/entity pattern with a `source` discriminator.

---

## 19. Definition of Done

- [ ] Migration `*_service_earnings_visibility.sql` applied via version control; `supabase db reset` green; Staging verified; no new tables; no DEFINER.
- [ ] `service_earnings_summary` + `service_transaction_history` live: SECURITY INVOKER, envelope `PLTxxx`, `authenticated`-only EXECUTE, `anon` denied, keyset pagination, per-currency correctness proven against ledger ground truth.
- [ ] pgTAP posture + enforcement suites green (auth matrix, cross-entity leakage 0 rows, disputed flag, pagination integrity, limit bounds).
- [ ] Data slice (entities/DTOs/mappers/remote/repo/providers) + fakes/builders complete; unit tests green.
- [ ] `ServiceEarningsService` + `ServiceAnalyticsService` complete; **no settlement arithmetic** (financial-logic scan green).
- [ ] Three screens live with reused tokens/widgets; mock seam removed; empty/loading/error/offline/disputed states verified; 320–600dp overflow matrix green.
- [ ] Deep-links (`contractDetail`, `escrowDetailFor`, `disputesFile`) verified; `earnings_released` notification + cache invalidation verified.
- [ ] `dart analyze` + `flutter test` + design-system token gate + RLS leak matrix all green.
- [ ] Validation evidence recorded for EP-03-20 criterion: *"earnings summary/transaction history screens read server-aggregated RPCs — no client math determines settlement"* + grep proof of zero settlement reduce.
- [ ] Interface sign-off: EP-03-17/18/20 can consume summary/history shapes without modification.

---

## 20. Implementation AI Execution Profile

**Recommended Coding Reasoning Level: High**

**Justification:** The Phase Plan (§11/§13) rates EP-03-16 **High** for both planning and coding — and the evidence supports it. The task is read-only (no fund-movement state machine, hence below the `Extremely High` escrow-mutation tier of EP-03-01/02/11), but carries **high business impact** (retention driver; incorrect figures erode payout trust), **high data complexity** (multi-currency double-entry aggregation with contract joins, month bucketing, cursor pagination), **high integration complexity** (touches ledger + balances + contracts + escrow + disputes + dashboard + notifications + cache), and **meaningful security sensitivity** (cross-entity ledger leakage would be a privacy breach; client-side summation would be a settlement-divergence risk). `High` provides the rigor for RLS/auth-matrix reasoning, pagination correctness, and token/test compliance without the exhaustive state-machine formalism reserved for fund-mutating tasks. No escalation to `Very High`/`Extremely High` is warranted since no new financial invariant is created — existing ledger invariants are only read.

---

*Plan complete. No code written. Awaiting your approval to proceed to implementation.*
