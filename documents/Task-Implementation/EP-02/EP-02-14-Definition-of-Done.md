# Definition of Done — EP-02-14: Escrow & Milestone Payment Management

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-14 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-14-Escrow & Milestone Payment Management.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-14 |
| **Task Name** | Escrow & Milestone Payment Management |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 5 — Financial Integrity Systems |
| **Priority** | Critical |
| **Dependencies** | EP-02-04 (Financial Schema — `financial_escrow` `financial_escrow_milestones` `financial_escrow_transactions` + write RPCs `financial_escrow_create/fund/release/refund/milestone_complete` + read RPC `financial_escrow_get` `supabase/migrations/20260829100004_financial_integrity_schema.sql:191-257,758-1147,1683-1694`), EP-02-09 (Payment Gateway Abstraction — `lib/integrations/payment_gateways/payment_gateway_factory.dart` read-only hint) |
| **Blocks** | EP-02-15 (Currency Conversion — escrow `released` receivable handoff), EP-02-16 (Payouts & Deposit Verification — release-to-receivable), EP-02-18 (Edge Function proxy `financial-escrow-proxy` — this task hands the call-site + flag + exception contract) |
| **Read seam** | EP-02-05 (Dispute Resolution — `financial_escrow.dispute_id` + `disputed` status; this task renders the frozen UI + `financial_escrow_get` self-scope) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-14-Escrow & Milestone Payment Management.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829100004_financial_integrity_schema.sql:191-227` (`financial_escrow` — 7-status check `204-207`), `232-257` (`financial_escrow_milestones` — 3-status check `240-241`), `758-838` (`financial_escrow_create` service_role-only), `841-904` (`financial_escrow_fund` service_role-only), `905-968` (`financial_escrow_release` — guards `status in ('funded','partially_released')` line `923`, service_role-only), `969-1025` (`financial_escrow_refund` service_role-only, refundable from `created/funded/partially_released/disputed` line `988`), `1028-1108` (`financial_escrow_milestone_complete` service_role-only), `1111-1147` (`financial_escrow_get` authenticated self-scope `1132`, `PLT001` `1122-1124`, returns `{escrow, milestones}` — no transaction array in this migration version), `593-596` (`financial_escrow_select` RLS), `597-604` (`financial_escrow_milestones_select` RLS), `1683` (`financial_escrow_get` granted `authenticated, service_role`), `1690-1694` (write RPCs granted `service_role` only) — task is `lib/` + `test/` only; `git diff --stat supabase/` must be `0`, `.supabase/functions` untouched (proxy deploy deferred to EP-02-18).

---

## 2. Functional Verification

This task delivers the **escrow & milestone payment management system**: lifecycle tracking of `financial_escrow` (7 states) and `financial_escrow_milestones` (3 states), escrow detail/list viewing with frozen-disputed handling, the milestone-progress trust UX, and the **server-authoritative write seam** behind `EscrowRemoteDataSource` with the Edge Function proxy as the documented swap point (`escrowWriteViaProxyEnabled` flag off until EP-02-18). The client **reads** escrow via the live `financial_escrow_get` RPC and **never** invokes a `service_role`-only write RPC. Functional verification confirms the domain vocabulary, data layer, repository, service facade, provider, screens, widgets, routing, and write-seam behave correctly and never bypass server invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `lib/systems/finance/models/escrow_status.dart` defines `EscrowStatus` with exactly 7 entries matching `financial_escrow.status` check `204-207`: `created` ("Awaiting funding", tone `warning`), `funded` ("Funded & held", `info`), `partially_released` ("Milestones releasing", `info`), `released` ("Released to provider", `success`), `refunded` ("Refunded to payer", `neutral`), `cancelled` ("Cancelled", `neutral`), `disputed` ("In dispute — frozen", `danger`) — each with `code`, `label`, `tone`
- [ ] **FV-02:** `EscrowStatus` is data-driven vocab only (no business logic) — `code` strings match server check constraint exactly; no drift from `financial_escrow` `204-207`; `values.length==7` asserted in unit test
- [ ] **FV-03:** `MilestoneStatus` (or inline vocabulary) defines exactly 3 labels matching `financial_escrow_milestones.status` check `240-241`: `pending` → "Pending", `completed` → "Completed — awaiting release", `released` → "Released" — no invented 4th state
- [ ] **FV-04:** `EscrowService.escrowWriteAvailable` surfaces the proxy feature flag — `bool get escrowWriteAvailable => remote.writeViaProxy` — read once at construction, not per frame

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [ ] **FV-05:** `Escrow` entity exists at `lib/data/entities/escrow.dart` — `id, projectId, escrowInternalId, clientReference, creatorEntityId, providerEntityId, totalAmount, currencyCode, status (7-state), disputeId?, createdAt, fundedAt?, releasedAt?` — pure Dart, no Flutter/Supabase imports (field names are the client contract; map from server `payer_entity_id`/`payee_entity_id`/`financial_profile_id`/`released_amount`/`refunded_amount`)
- [ ] **FV-06:** `EscrowMilestone` entity at `lib/data/entities/escrow_milestone.dart` — `id, escrowId, title, amount, status (3-state), completedAt?, releasedAt?` (map from server `milestone_number`/`sort_order`/`description` as available)
- [ ] **FV-07:** `EscrowTransaction` entity at `lib/data/entities/escrow_transaction.dart` — `id, escrowId, type (fund|release|refund|fee|chargeback), amount, direction (in|out), entityId, reference, createdAt` — derived from server envelope when present; null-safe when migration returns only `{escrow, milestones}`
- [ ] **FV-08:** `EscrowMilestoneInput` value object at `lib/data/models/escrow_milestone_input.dart` — create-payload shape `{title, amount}` with `amount > 0` validation; used by `createEscrow` write seam
- [ ] **FV-09:** DTOs exist at `lib/data/models/escrow_dto.dart`, `escrow_milestone_dto.dart`, `escrow_transaction_dto.dart` — `fromJson` maps `financial_escrow_get` `{escrow:{...}, milestones:[{...}]}` (and `transactions:[...]` when present); null `dispute_id`/`released_at`/`funded_at` → `null`, not throw
- [ ] **FV-10:** `EscrowMapper` at `lib/data/mappers/escrow_mapper.dart` defines `escrowToEntity`, `milestoneToEntity`, `transactionToEntity`, `entityToInput` — maps DTO→Entity without leaking RPC JSON shape; empty `milestones` array → `[]` (never null); missing transaction array handled gracefully
- [ ] **FV-11:** Numeric correctness — `total_amount numeric` / `amount numeric` parsed to `double` without precision catastrophe; `EscrowService` sum logic uses tolerance `0.01` (see §2.5)

### 2.3 Required Functionality — Remote Data Source (Read live / Write seam)

- [ ] **FV-12:** `EscrowRemoteDataSource` abstract exists at `lib/data/datasources/remote/escrow_remote_data_source.dart` — read methods `getById(String id)`, `getByProject(String projectId)` + write seam methods `createEscrow(...)`, `fundEscrow({escrowId})`, `releaseMilestone({escrowId, milestoneId})`, `releaseFinal({escrowId})`, `refundEscrow({escrowId, reason})`, `completeMilestone({escrowId, milestoneId})`
- [ ] **FV-13:** `SupabaseEscrowRemoteDataSource` exists at `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), constructor `({required super.dio, required super.supabase, required super.exceptionMapper, bool writeViaProxy = false})`
- [ ] **FV-14:** Read mapping exact — `financial_escrow_get(p_escrow_id)` `1111-1147` self-scoped payer/payee `1132`; implementation confirms exact signature/filter at build time from migration (plan §5.2: single RPC takes optional filter args); envelope unwrap via `FinancialEnvelopeParser` validates `success==true && code=='PLT000'` before mapping
- [ ] **FV-15:** **Write seam never breaks:** each of the 6 write methods starts with `if (!writeViaProxy) throw const EscrowWriteUnavailableException();` — never a silent no-op, never a direct `supabase.rpc` on `financial_escrow_create/fund/release/refund/milestone_complete` (all `service_role`-only `1690-1694`)
- [ ] **FV-16:** Proxy branch (when flag `true`) is the documented swap point — calls the Edge Function proxy `financial-escrow-proxy` semantically; concrete `supabase.functions.invoke` path NOT implemented in this task (EP-02-18 owns deploy); the branch is stubbed to throw `UnimplementedError('Edge Function proxy deployment pending EP-02-18')` only after the flag guard passes
- [ ] **FV-17:** `EscrowWriteUnavailableException extends ApiException` (`kind: forbidden`, message includes "Escrow actions are not available yet — releases are handled by our support team.") — deliberately distinct from `PLT002` so UI renders the "actions via support" panel, not a generic forbidden error (§5.3)
- [ ] **FV-18:** Error mapping via `DataExceptionMapper` — `PLT001→auth`, `PLT002→forbidden`, `PLT003→validation`, `PLT004→notFound`, `PLT005→conflict`, `PLT999→server`; raw `DioException`/`SupabaseException` never propagates (`BaseApiService.invoke` normalizes)

### 2.4 Required Functionality — Repository

- [ ] **FV-19:** `EscrowRepository` abstract + `EscrowRepositoryImpl` exist at `lib/data/repositories/escrow_repository.dart` + `escrow_repository_impl.dart` — methods `getById`, `getByProject`, `createEscrow`, `completeMilestone`, `releaseMilestone`, `releaseFinal`, `refundEscrow`
- [ ] **FV-20:** `getById(id)` / `getByProject(projectId)` delegate to `remote` → `EscrowMapper.escrowToEntity` — read-only, live, never throws on empty milestone list
- [ ] **FV-21:** `createEscrow(...)` — **client pre-validates milestone sum invariant** `sum(milestones.amount) == totalAmount` (tolerance `0.01`) **before** the write-seam call; mismatch throws `ApiException(kind: validation, code: PLT003, message: 'Milestone amounts must sum to the escrow total')` — no write attempt for known-invalid input; on success (future) re-reads `getById` to confirm server state, never optimistic
- [ ] **FV-22:** `completeMilestone` / `releaseMilestone` / `releaseFinal` / `refundEscrow` — flag-gated `remote` calls; when `writeViaProxy == false` the `EscrowWriteUnavailableException` propagates to UI; when `true` (future) awaits proxy response then re-reads `getById` for optical re-sync
- [ ] **FV-23:** Repository **never writes** `financial_escrow`/`financial_escrow_milestones` directly — no REST `POST /rest/v1/financial_escrow`, no direct `supabase.rpc` on write RPCs (`1690-1694` are `service_role`-only)
- [ ] **FV-24:** Repository never imports `lib/systems/` widgets — unidirectional `data → systems`; no `SupabaseClientProvider` singleton inside repository (client held via datasource only)

### 2.5 Required Functionality — Systems Facade

- [ ] **FV-25:** `EscrowService` exists at `lib/systems/finance/services/escrow_service.dart` — thin facade over `EscrowRepository` + `remote.writeViaProxy`, consumed by `EscrowProvider` and future `EP-02-15/16` without modification
- [ ] **FV-26:** `bool validateMilestoneSums({required double totalAmount, required List<double> milestoneAmounts})` — pure `abs(sum - total) <= 0.01`; `[50000,50000]` for `total 100000` → `true`; `[40000,40000]` for `total 100000` → `false`; used by create UI before submit
- [ ] **FV-27:** `double releasedMilestoneTotal(List<EscrowMilestone>)` — sums only `status == 'released'`; `double completedMilestoneTotal(...)` — sums `completed` + `released` — pure fold, no I/O
- [ ] **FV-28:** `HivorrLogger` + `PiiRedactor` redacted logging (`escrowId`, `entityId: ***last4`, `amount`, `currencyCode`, milestone index) — never logs `client_reference` full, never dispute evidence, never milestone `title` if it embeds contract terms
- [ ] **FV-29:** `PerformanceTracer` spans `finance.escrow.get.duration`, `finance.escrow.list.duration`, `finance.escrow.milestone.sum.duration` tagged `finance.escrow.status`/`finance.escrow.milestone.count`, no PII, sampled via `MonitoringConfig`

### 2.6 Required Functionality — Provider (ChangeNotifier)

- [ ] **FV-30:** `EscrowProvider` exists at `lib/data/providers/escrow_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`), mirrors `FinancialProvider` pattern (`lib/data/providers/financial_provider.dart:49`)
- [ ] **FV-31:** State fields: `List<Escrow> escrows`, `Escrow? selected`, `List<EscrowMilestone> milestones`, `Map<String,List<EscrowTransaction>> transactionsByEscrowId`, `AsyncState loadState`, `ApiException? lastError`, `bool isRefreshing`, `bool writeAvailable`
- [ ] **FV-32:** `loadForProject(String projectId)` fetches escrows + milestones via `financial_escrow_get`; `select(String escrowId)` loads detail + milestones + transactions; `refresh()` re-reads current selection then `notifyListeners()` — 1–2 RPCs per screen visit, memoized per escrow id
- [ ] **FV-33:** `writeAvailable` initialized from `remote.writeViaProxy` at construction — UI reads once, not per-frame; no config lookup in build methods
- [ ] **FV-34:** Lifecycle: `pausePolling()`/`resumePolling()` exposed, `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses, `dispose()` cancels; no `Timer.periodic` leak while a screen is backgrounded
- [ ] **FV-35:** Constructor injection `({required EscrowRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability; no `SupabaseClientProvider` singleton inside provider; optional `NotificationProvider` on milestone-release/release-final success (only when flag on, one-shot, local-only)

### 2.7 Required Functionality — UI Screens

- [ ] **FV-36:** `EscrowListScreen` exists at `lib/systems/finance/screens/escrow_list_screen.dart` (`GET /finance/escrow`): `AppBar(title: Text('Escrows', style: textTheme.titleLarge))`, per-escrow cards (status badge + `BalanceFormatter` amount + entity initials `***last4` — never full legal name), pull-to-refresh, `HivorrEmptyState` ("No active escrows — create one from a project contract page")
- [ ] **FV-37:** `EscrowDetailScreen` exists at `lib/systems/finance/screens/escrow_detail_screen.dart` (`GET /finance/escrow/:id`): header (status badge + amount + currency code + `clientReference` truncated `***ref` via `PiiRedactor`)

### 2.8 Required Functionality — UI Widgets

- [ ] **FV-38:** `EscrowStatusBadge` at `lib/systems/finance/widgets/escrow_status_badge.dart` — 7-status color map using `colorScheme.*` only: `created` `warningContainer`, `funded` `primaryContainer`, `partially_released` `primaryContainer`, `released` `successContainer`, `refunded` `surfaceVariant`, `cancelled` `surfaceVariant`, `disputed` `errorContainer`; label from `EscrowStatus` vocab; no hex, `Container(decoration: BoxDecoration(color: ..., borderRadius: BorderRadius.circular(ext.radiusSm)))` soft not hard shadow (`VISUAL-IDENTITY.md:226`)
- [ ] **FV-39:** `MilestoneListCard` at `lib/systems/finance/widgets/milestone_list_card.dart` — per-milestone row: title (`textTheme.bodyMedium`) + amount (`BalanceFormatter`) + status chip (`pending` `surfaceContainerHighest`, `completed` `primaryContainer`, `released` `successContainer`); `LinearProgressIndicator(value: releasedTotal/total, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest)` — value clamped `0..1`, `0` when no released
- [ ] **FV-40:** `EscrowWriteCtaPanel` at `lib/systems/finance/widgets/escrow_write_cta_panel.dart` — when `writeAvailable==true` (future): provider-visible `HivorrButton`s (Complete milestone / Release / Release final / Refund) as `HivorrButton(variant:..., isLoading, isExpanded:true)`; when `false`: `Card` guidance "Escrow actions are handled by our support team" + `Icons.help_outline` + "Contact support" action; **never** renders an enabled button that would dead-end
- [ ] **FV-41:** `EscrowDisputeBanner` at `lib/systems/finance/widgets/escrow_dispute_banner.dart` — `Container` `colorScheme.errorContainer`, `Icons.gavel`/`Icons.help`, "In dispute — all actions frozen until resolved" + "View dispute" action routing to EP-02-05 dispute screen; renders **only** when `escrow.status == 'disputed'`
- [ ] **FV-42:** All widgets consume `AppTheme` tokens **only** — `Theme.of(context).colorScheme`, `textTheme`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:176-190,219-235`); cards 16dp (`VISUAL-IDENTITY.md:221`); no `Colors.*`, no `Color(0xFF...)` inline (hex lives only in `lib/app/theme/app_colors.dart:16`), no `fontFamily` literal; responsive via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`) 16dp mobile / 24dp web; amounts via `BalanceFormatter` only (never `double.toString()`)

### 2.9 Required Functionality — Routing & DI

- [ ] **FV-43:** `RoutePaths.escrow = '/finance/escrow'` and `RoutePaths.escrowDetail = '/finance/escrow/:id'` added to `lib/app/router/route_paths.dart`; `RouteNames.escrow`/`escrowDetail` added; `app_router.dart:17` registers both — guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) authenticated only, no taxonomy gate; detail reads `:id` param → `EscrowProvider.select(id)`; private flow (not SEO `/p/:slug/:id` `ARCHITECTURE.md:150`)
- [ ] **FV-44:** Barrels re-export all new symbols: `lib/systems/finance/finance.dart:1`, `lib/data/data_layer.dart:1`
- [ ] **FV-45:** Feature flag `escrowWriteViaProxyEnabled` exists in config (per repo convention), **default `false`** in Development, Staging, and Production — no new `ENV` secrets; factory `EscrowProvider.create(supabase: SupabaseClientProvider.client, writeViaProxy: config.escrowWriteViaProxyEnabled)` wired in bootstrap; screens consume `EscrowProvider`/`EscrowService` without importing `supabase.rpc` literals (`ARCHITECTURE.md:101-110`)

### 2.10 Expected Workflows

- [ ] **FV-46:** List→detail happy path: `loadForProject('project-x')` → `financial_escrow_get` → `escrows.length == 1` → user taps card → `select(escrowId)` → detail shows header badge (e.g. `funded` `primaryContainer`), `MilestoneListCard` with statuses `pending/completed/released`, transaction summary — all read-only
- [ ] **FV-47:** Disputed frozen workflow: `escrow.status == 'disputed'` → detail renders `EscrowDisputeBanner` + "View dispute" (→ EP-02-05) + **all** milestone action buttons disabled `onPressed: null` — even if `writeAvailable` were true, a disputed escrow never shows an actionable release button
- [ ] **FV-48:** Write-unavailable workflow: `escrowWriteViaProxyEnabled == false` → `EscrowWriteCtaPanel` shows support-team guidance card + "Contact support"; no enabled primary button; user is not surprised by a disabled CTA or a generic error
- [ ] **FV-49:** Write-available (future) workflow: flag `true` → user taps Complete milestone → modal confirm → proxy path invoked (EP-02-18) → post-success `getById` re-sync → milestone chip updates `completed` `primaryContainer` — never optimistic local mutation
- [ ] **FV-50:** Milestone-sum validation workflow: create form total `100000`, milestones `[40000, 40000]` → inline field error naming the offending milestone (`PLT003` equivalent client-side) — no proxy round-trip for known-invalid input

### 2.11 Success Conditions

- [ ] **FV-51:** `financial_escrow_get(p_escrow_id)` returns `{success:true, code:PLT000, data:{escrow:{...}, milestones:[{...}]}}` `1142-1145` when actor is payer (`payer_entity_id`) or payee (`payee_entity_id`) of the escrow `1132`
- [ ] **FV-52:** Escrow consultation is live and read-only — client maps `financial_escrow_get` to `Escrow` + `EscrowMilestone` entities; `active_escrow_count` optionally surfaced via `financial_status_get` (EP-02-13) for an "N active escrows" summary — no write required to view
- [ ] **FV-53:** Write seam is provably inert in production — `escrowWriteViaProxyEnabled` defaults `false`; all write UI renders guidance, never an enabled dead-end; no `service_role` RPC string in any client file (grep-lens §7.4)

### 2.12 Error Handling Scenarios

- [ ] **FV-54:** `401 PLT001 auth` (unauthenticated actor `financial_escrow_get` `1122-1124`) → `ApiExceptionKind.auth` → redirect `/login` via `RouteGuard`
- [ ] **FV-55:** `403 PLT002 forbidden` (actor is neither payer nor payee — e.g. third party attempts escrow read) → `ApiExceptionKind.forbidden`; no SQL leaked; surfaced in `HivorrErrorState`
- [ ] **FV-56:** `404 PLT004 notFound` (`financial_escrow_get` `1133-1135` — escrow id absent or not party to it) → `ApiExceptionKind.notFound` — surfaced as "Escrow not found", never raw
- [ ] **FV-57:** `400/422 PLT003 validation` (create-milestone sum mismatch, malformed envelope `success:false`) → `ApiExceptionKind.validation` — inline field error, never toast; milestone pre-validation catches before write-seam
- [ ] **FV-58:** `409 PLT005 conflict` (server status-transition violation — e.g. attempting to release an escrow not in `funded/partially_released` `923`, double-release race) → `ApiExceptionKind.conflict` — surfaced inline; no optimistic UI state
- [ ] **FV-59:** `5xx PLT999 server` → `ApiExceptionKind.server` — retry 3x prod / 4x dev with `500ms→8s` backoff (`lib/core/api/api_config.dart:40-49`); no unbounded retry storm
- [ ] **FV-60:** `EscrowWriteUnavailableException` (flag off write attempt) → `kind: forbidden` + support-team message — distinct from `PLT002`, surfaces the "via support team" panel (not a generic forbidden error); no silent no-op
- [ ] **FV-61:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; backoff applied; raw `DioException` never propagates — `BaseApiService.invoke` normalizes

### 2.13 Important User Interactions

- [ ] **FV-62:** Fail-fast milestone validation: create flow validates `sum(milestones)==total` (tolerance 0.01) client-side before any write attempt — no round-trip for a known `PLT003` violation; field-level error names the offending milestone
- [ ] **FV-63:** Trust-through-progress UX: milestone status chips + `LinearProgressIndicator` (`releasedTotal/total`) are the primary visibility; payer and provider both see `pending/completed/released` — action buttons are secondary
- [ ] **FV-64:** PII truncation everywhere: `clientReference` rendered `***ref`, entity display `***last4` initials or "Payer"/"Provider" labels — never full legal names, per `AGENT.md` privacy rules
- [ ] **FV-65:** Currency clarity: every amount rendered `BalanceFormatter` symbol + code (`₦50,000.00 NGN`) to prevent cross-currency confusion; never raw `double.toString()`
- [ ] **FV-66:** Progressive disclosure: list shows cards not transaction walls; detail reveals transaction envelope summary in a secondary section; empty state `HivorrEmptyState`, loading `HivorrLoadingState` wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), error `HivorrErrorState` — never bare `CircularProgressIndicator`

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files added ONLY under `lib/data/entities/escrow*.dart` (3), `lib/data/models/escrow*.dart` (3 DTOs + `escrow_milestone_input.dart`), `lib/data/mappers/escrow_mapper.dart`, `lib/data/datasources/remote/escrow_remote_data_source.dart` + `supabase_escrow_remote_data_source.dart`, `lib/data/repositories/escrow_repository*.dart` (2), `lib/data/providers/escrow_provider.dart`, `lib/systems/finance/models/escrow_status.dart`, `lib/systems/finance/services/escrow_service.dart`, `lib/systems/finance/screens/escrow_*.dart` (2), `lib/systems/finance/widgets/escrow_*.dart` (4), `lib/systems/finance/finance.dart`, `lib/data/data_layer.dart` (barrel), `lib/config/` (flag), `lib/app/router/*` (2 routes), `test/**` — no files in `lib/core/storage/`, `lib/engine/`, `lib/integrations/payment_gateways/`, `lib/systems/verification/`, reserved for EP-02-18
- [ ] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; no `lib/core/storage/*` modification
- [ ] **TV-03:** Module placement conforms to `ARCHITECTURE.md:56,101-138` — `lib/data/` owns RPC + DTOs + write-seam (reusable `EP-02-15/16`), `lib/systems/finance/` owns escrow vocabulary + milestone progress + UX, `lib/integrations/` untouched (within `112-120` surface); Edge Function seam is **client-side only** — no `.supabase/functions/` directory created
- [ ] **TV-04:** Interface-first — abstract `EscrowRemoteDataSource` separate from `SupabaseEscrowRemoteDataSource`; abstract `EscrowRepository` separate from `EscrowRepositoryImpl`; repository never imports `lib/systems/` widgets (unidirectional `data → systems`); service consumes interface only
- [ ] **TV-05:** No `public.*` SECURITY DEFINER/GRANT/CREATE POLICY — `supabase/migrations/` untouched; no `.supabase/functions/financial-escrow-proxy/index.ts` created (EP-02-18 owns deploy)
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `currentAccessToken` `:29`; no direct `Supabase.instance.client` leakage beyond datasource

### 3.2 Required System Behavior

- [ ] **TV-07:** `SupabaseEscrowRemoteDataSource` reuses `FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart`) — validates `success==true && code=='PLT000'`; same envelope contract as `SupabaseFinancialRemoteDataSource`; no third parser created
- [ ] **TV-08:** Every public method throws only `ApiException` (`lib/core/api/exceptions/api_exception.dart:6-66`) or `DataException` — never raw `Supabase`/`DioException`; `ApiExceptionMapper` preserves `kind/code/statusCode` with safe message (no SQL/stack); `EscrowWriteUnavailableException` is an `ApiException` subclass `kind: forbidden`
- [ ] **TV-09:** Write seam is the only write path — `createEscrow/fundEscrow/releaseMilestone/releaseFinal/refundEscrow/completeMilestone` all pass through `if (!writeViaProxy) throw EscrowWriteUnavailableException`; no method reaches a `service_role` RPC directly; unit test proves write RPC spy never called from client
- [ ] **TV-10:** Client never writes `financial_escrow.status`/`released_amount`/`refunded_amount` or `financial_escrow_milestones.status` — no REST `POST`/`PATCH` on these tables; all transitions server-authoritative (`AGENT.md:16` Rule 4); `grep` proves no write-RPC string in `lib/`
- [ ] **TV-11:** `EscrowProvider.loadForProject`/`select` uses memoized state + 1–2 RPCs; `refresh()` re-reads current selection; no polling while backgrounded (`WidgetsBindingObserver`); no `Timer.periodic` storm
- [ ] **TV-12:** `EscrowRemoteDataSource` does NOT inject `StorageService`/`NotificationProvider`; `EscrowProvider` does not hold `SupabaseClientProvider` singleton — repository holds client
- [ ] **TV-13:** `EscrowService` math is pure Dart (no I/O/globals/Flutter imports) — `validateMilestoneSums` tolerance 0.01, `releasedMilestoneTotal`/`completedMilestoneTotal` folds; `O(n)` ≤20 milestones, safe per render
- [ ] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) log `escrowId`, `entityId ***last4`, `amount`, `currencyCode`, milestone index — never `client_reference` full, never dispute evidence, never milestone `title` full; `MonitoringService` spans `finance.escrow.*` sampled via `MonitoringConfig`

### 3.3 Module Integration

- [ ] **TV-15:** No conflict with `FinancialRemoteDataSource` (`lib/data/datasources/remote/financial_remote_data_source.dart`) — dediciated `EscrowRemoteDataSource` reuses `FinancialEnvelopeParser` + `BalanceFormatter` without importing `financial_remote_data_source` internals; independent evolution (future proxy activation without touching EP-02-13)
- [ ] **TV-16:** Envelope parser + `DataExceptionMapper` shared (not re-implemented) — single parsing path
- [ ] **TV-17:** `EscrowProvider` mirrors `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) read/memoization pattern — no third timer, no notification duplication
- [ ] **TV-18:** `lib/systems/finance/` imports `lib/data/entities/escrow*.dart` + `BalanceFormatter` + `PaymentGatewayFactory` interface only — never imports `lib/systems/verification/widgets/`, Supabase SDK in formatter/math
- [ ] **TV-19:** Consumable by `EP-02-15` (currency conversion reads released escrow) and `EP-02-16` (release→receivable handoff) without modification; `EscrowStatus`/`MilestoneStatus` + `BalanceFormatter` reusable
- [ ] **TV-20:** No `lib/integrations/payment_gateways/*` mutation; no `financial_balances`/`financial_transactions` ledger read beyond the escrow envelope; no `supabase_realtime` payload (escrow events surface on next `financial_escrow_get`)

### 3.4 Technical Requirements from Plan

- [ ] **TV-21:** `flutter analyze` + `dart analyze` clean
- [ ] **TV-22:** `EscrowRemoteDataSource`/`SupabaseEscrowRemoteDataSource` dartdoc documents RPC envelope contract, `FinancialEnvelopeParser` reuse, `BaseApiService.invoke` pattern, the **write-seam flag + `EscrowWriteUnavailableException` + proxy swap point** (EP-02-18 contract)
- [ ] **TV-23:** `EscrowRepository` dartdoc documents milestone-sum pre-validation (tolerance 0.01), never-writes-escrow-tables rule (`AGENT.md:16` Rule 4), `EscrowWriteUnavailableException` propagation; `EscrowService` dartdoc documents `validateMilestoneSums`/`releasedMilestoneTotal`/`completedMilestoneTotal`/`escrowWriteAvailable`
- [ ] **TV-24:** `EscrowProvider` (ChangeNotifier) dartdoc documents `loadForProject`/`select`/`refresh` lifecycle + `pausePolling`/`resumePolling`; `EscrowStatus` dartdoc documents 7/3-state vocab matching server check constraints `204-207`/`240-241`

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** No client creates escrow rows — `financial_escrow`/`financial_escrow_milestones` rows are created **server-side only** by `financial_escrow_create` `758-838` (service_role-only `1690`); this task's `createEscrow` is a flag-gated write **seam**, never a table insert; `git diff --stat supabase/` = 0
- [ ] **DV-02:** `financial_escrow` server shape verified at read time — `total_amount > 0` `201`, status 7-state `204-207`, `released_amount`/`refunded_amount` `>= 0` `202-203`, constraint `released_amount + refunded_amount <= total_amount` `216` — client reflects these, never invents amounts
- [ ] **DV-03:** `financial_escrow_milestones` server shape — `milestone_number >= 1` `236`, `unique(escrow_id, milestone_number)` `248`, `title` 1–255 chars `237`, `amount > 0` `239`, status 3-state `240-241` — client maps/dereives these, never creates rows

### 4.2 Data Updates

- [ ] **DV-04:** Client **never** updates escrow/milestone rows — all `released_amount`/`refunded_amount`/`status`/`released_at`/`refunded_at` transitions happen inside `financial_escrow_release` `905-968` and `financial_escrow_refund` `969-1025` (service_role-only); `grep -r "financial_escrow.*status.*=" lib/` = 0 for update
- [ ] **DV-05:** Status transition is server-authoritative — `financial_escrow_release` only allows `status in ('funded','partially_released')` `923` (a `disputed` escrow is therefore **blocked** from release); `financial_escrow_refund` allows `created/funded/partially_released/disputed` `988`; client post-write (future) always re-reads `getById` — never optimistic
- [ ] **DV-06:** Dispute hold is defense-in-depth — server release blocks `disputed` `923`; client additionally renders `EscrowDisputeBanner` with all actions disabled (`onPressed: null`); the client layer is UX, the server layer is enforcement

### 4.3 Data Relationships

- [ ] **DV-07:** `financial_escrow_get` `1111-1147` returns escrow + `milestones` array via `select jsonb_agg(... where t.escrow_id = v_escrow.id order by t.sort_order, t.milestone_number)` `1137-1140` — display of milestone state, read-only
- [ ] **DV-08:** Self-scope enforced server-side — `financial_escrow_get` filters `where id = p_escrow_id and (payer_entity_id = v_actor or payee_entity_id = v_actor)` `1131-1132`; non-party → `PLT004` `1134`; client cannot read another entity's escrow
- [ ] **DV-09:** Escrow→milestone FK chain `financial_escrow_milestones.escrow_id → financial_escrow.id` `234-235` cascade — client renders the aggregation from the RPC response, never joins tables directly
- [ ] **DV-10:** `dispute_id` link to `financial_disputes` (EP-02-05) is nullable on the server escrow record — client maps `disputeId?` → `null` when absent, never fabricates a dispute link; disputed status driven by server `status` field

### 4.4 Data Accuracy

- [ ] **DV-11:** Status vocab exact — client `EscrowStatus`/`MilestoneStatus` codes match server check constraints `204-207`/`240-241` verbatim; mapper/stub test asserts `values.length==7`/`3` and code strings; no invented state
- [ ] **DV-12:** Amount precision — `total_amount`/`amount` `numeric` (arbitrary precision server-side) parsed to `double` client-side without precision catastrophe; `EscrowService` sum math uses tolerance `0.01`; `BalancerFormatter` renders locale thousands + 2dp (`₦50,000.00`)
- [ ] **DV-13:** Currency correctness — `currency_code char(3)` from `financial_supported_currencies` mapped to `SupportedCurrency` vocab (EP-02-13); amount displays always `symbol + code` (`₦50,000.00 NGN`); no cross-currency confusion
- [ ] **DV-14:** Timestamps — `funded_at`/`released_at`/`refunded_at`/`created_at` mapped to nullable `DateTime`; `completed_at`/`released_at` on milestones nullable; null rendered as "—" not crash

### 4.5 Data Integrity

- [ ] **DV-15:** Zero DDL — no `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger on escrow tables; `git diff --stat supabase/` = 0; full pgTAP `001-017` + financial `013-014` suites must remain green
- [ ] **DV-16:** Audit is server-written — `financial_audit_trail` rows (`escrow_released` `959-960`, `escrow_refunded` `1017-1018`) inserted by the write RPCs; client never inserts audit rows
- [ ] **DV-17:** No disk persistence of escrow state (no Hive local data source) — `EscrowProvider` memoizes in memory only; invalidation via `refresh()` on pull-to-refresh/lifecycle-resume/post-write re-sync; escrow is live financial state, not offline-cacheable
- [ ] **DV-18:** Milestone sum invariant not bypassable — server `financial_escrow_create` enforces `sum(milestones)==total` (`PLT003`); client pre-validation is UX fast-fail; a client bug can never create a mis-summed escrow because the create path is flag-gated and, when on, the proxy maps to the server RPC

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative escrow (`AGENT.md:16` Rule 4) — client never writes `financial_escrow.*`/`financial_escrow_milestones.*` via REST or `supabase.rpc`; all write paths are the proxy-flagged seam; `grep` proves no write-RPC string in `lib/`; all critical state changes execute server-side via `service_role`-only RPCs under RLS
- [ ] **SV-02:** RLS default-deny inherited — escrow tables RLS-enabled, `financial_escrow_select` `593-596` + `financial_escrow_milestones_select` `597-604` self-scoped to payer/payee; write grants `service_role` only `1690-1694`; `financial_escrow_get` authenticated `1683`; `RouteGuard` redirects `/login`
- [ ] **SV-03:** Client write attempt to `/rest/v1/financial_escrow` (REST `POST`) fails — no `authenticated INSERT/UPDATE` grant on escrow tables (grants are `service_role` write `1690-1694`); `403 PLT002`/RLS violation; unit test proves repository never issues a table write
- [ ] **SV-04:** No `service_role` leak — `grep -r "service_role" lib/` = 0; `EscrowProvider`/`EscrowService`/`SupabaseEscrowRemoteDataSource` never hold `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` RLS scope; the proxy key (EP-02-18) lives in Supabase Edge Function env **server-side only**
- [ ] **SV-05:** Write RPCs not invocable by client — `financial_escrow_create/fund/release/refund/milestone_complete` granted `service_role` only `1690-1694`; authenticated `supabase.rpc` attempt → `42501`/`403 PLT002`; static grep proves no such call in `lib/`
- [ ] **SV-06:** Execution model respected — read `financial_escrow_get` `security invoker` `1114` + self-scope `1132`; write RPCs `security invoker`, RLS applies inside body
- [ ] **SV-07:** Auth token protection — `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId ***last4`; never logs `client_reference` full, dispute evidence, or milestone `title` full
- [ ] **SV-08:** PII scope minimal on screen — `clientReference` truncated `***ref`, party display `***last4` initials or "Payer"/"Provider", never legal names; no bank account numbers pass through this task (`EP-02-16` owns payout binding)
- [ ] **SV-09:** Dispute freeze is defense-in-depth — server `financial_escrow_release` blocks `disputed` (`status in ('funded','partially_released')` `923`); client also renders frozen UI; both layers must agree; grep lens proves no client path releases a disputed milestone
- [ ] **SV-10:** Time-of-check/race — server `financial_escrow_release` uses `select ... for update` `919` (row lock) + status guard `923`, refund `for update` `984`; `released_amount + refunded_amount <= total_amount` `216` prevents over-release; client `releaseMilestone`/`refundEscrow` re-read `getById` after write to show post-action truth, never optimistic
- [ ] **SV-11:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); escrow reads/writes per environment via migration + proxy env (future), no cross-env read
- [ ] **SV-12:** No SQL injection / no REST write — RPC calls use parameterized `supabase.rpc('financial_escrow_get', params: {...})`; no raw SQL, no dynamic query interpolation; no `POST /rest/v1/financial_escrow`; write seam uses only the documented flag path

---

## 6. Performance Verification

- [ ] **PV-01:** RPC cost — `financial_escrow_get` `stable` `1115` + indexed `financial_escrow_payer_idx` `222-223`, `financial_escrow_payee_idx` `224-225`, `financial_escrow_status_idx` `226-227`, `financial_escrow_milestones_escrow_idx` `254-255`, `financial_escrow_milestones_escrow_number_key` `256-257` — sub-10ms typical; `EscrowProvider.select` = 1 RPC for detail + milestones
- [ ] **PV-02:** Caching — `EscrowProvider` memoizes `escrows` + per-escrow `milestones` + `transactionsByEscrowId` in memory; `refresh()` re-reads only current selection; no disk persistence
- [ ] **PV-03:** Milestone progress math — `EscrowService.releasedMilestoneTotal`/`completedMilestoneTotal` = single fold over ≤20 milestones — microseconds, safe per-frame
- [ ] **PV-04:** Feature flag read cost — `escrowWriteAvailable` read once at provider construction, not per frame — no config lookups in build methods
- [ ] **PV-05:** Lifecycle pause/resume — `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses `EscrowProvider` polling; resumes on foreground — no wasted RPCs while app is backgrounded (Nigerian 3G)
- [ ] **PV-06:** No polling storm — no `Timer.periodic` while a screen is backgrounded; `refresh()` only on pull-to-refresh / resume / post-write re-sync
- [ ] **PV-07:** `PerformanceTracer` spans (`finance.escrow.get.duration`, `finance.escrow.list.duration`, `finance.escrow.milestone.sum.duration`) sampled via `MonitoringConfig`, tags `finance.escrow.status`/`finance.escrow.milestone.count`, no PII — lightweight
- [ ] **PV-08:** Notification one-shot — one `HivorrNotification` per milestone-release/release-final success (flag on only), local-only, no `supabase_realtime`; escrow events surface on next `financial_escrow_get` fetch

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + fakes (`test/support/fakes/fake_supabase.dart`, `fake_escrow_remote_data_source.dart`) — no live Supabase.

- [ ] **TT-01:** `escrow_remote_data_source_test.dart` ≥12 cases green — mock `SupabaseClient.rpc`: `financial_escrow_get → {success:true, code:PLT000, data:{escrow:{...}, milestones:[...]}}` success; `p_escrow_id` read; `404 PLT004 notFound` → `notFound`; `403 PLT002 forbidden` → `forbidden`; envelope `success:false → PLT003` → `validation`; `401 PLT001 auth`, `500 PLT999`; **write seam**: `writeViaProxy=false` → `createEscrow/fundEscrow/releaseMilestone/releaseFinal/refundEscrow/completeMilestone` each throw `EscrowWriteUnavailableException`; `writeViaProxy=true` → proxy branch invoked (stub `UnimplementedError` confirms **no direct `supabase.rpc` write call**)
- [ ] **TT-02:** `escrow_repository_test.dart` ≥14 cases green — fake `SupabaseEscrowRemoteDataSource` + real `EscrowRepositoryImpl`: `getById` maps escrow + milestones; `getByProject` maps list; `createEscrow` pre-validates milestone sum (`[50000,50000]` for `total 100000` passes; `[40000,40000]` for `total 100000` throws `PLT003 validation` before remote); `createEscrow` with `writeViaProxy=false` propagates `EscrowWriteUnavailableException`; `completeMilestone/releaseMilestone/releaseFinal/refundEscrow` re-read after proxy success (flag on); PLT004 surfaces notFound
- [ ] **TT-03:** `escrow_mapper_test.dart` ≥10 cases green — `EscrowDto.fromJson → Escrow` mapping status/currency/amount/dispute_id; `EscrowMilestoneDto.fromJson → EscrowMilestone` mapping title/amount/status/timestamps; transaction mapping; null `dispute_id`/`released_at` → null; empty milestones → `[]` — **100%**
- [ ] **TT-04:** `escrow_service_test.dart` ≥10 cases green — `validateMilestoneSums(100000,[50000,50000])==true`; `(100000,[40000,40000])==false`; tolerance `0.01`; `releasedMilestoneTotal` sums only `released`; `completedMilestoneTotal` sums `completed`+`released`; `escrowStatuses.length==7`; status vocab labels match server check `204-207`; disputed tone `danger` — **100%**
- [ ] **TT-05:** `escrow_write_unavailable_test.dart` ≥4 cases green — exception is `ApiException kind:forbidden`; message contains support guidance; no silent no-op; surfaces distinct from `PLT002`
- [ ] **TT-06:** `escrow_provider_test.dart` ≥12 cases green — `ChangeNotifier` with mocked repository: `loadForProject` sets `loadState=loading` then `success` with escrows+milestones; `select(id)` loads detail; `refresh` re-reads + `notifyListeners`; `writeAvailable` from repo/config at construction; lifecycle `pausePolling`/`resumePolling`; error state surfaces `lastError.message` (≥90%)
- [ ] **TT-07:** Total **≥62 unit assertions** green; repository/provider ≥90%, mappers/service 100%

### 7.2 Automated Widget Suite — `test/widget/systems/finance/`

- [ ] **TT-08:** `escrow_status_badge_test.dart` ≥9 cases green — pump `MaterialApp AppTheme.light` (`lib/app/theme/app_theme.dart:1`): each of 7 statuses renders label + expected `colorScheme` container (created `warningContainer`, funded `primaryContainer`, partially_released `primaryContainer`, released `successContainer`, refunded `surfaceVariant`, cancelled `surfaceVariant`, disputed `errorContainer`); no hardcoded hex; `grep Colors.` assert = 0
- [ ] **TT-09:** `milestone_list_card_test.dart` ≥8 cases green — `pending` chip `surfaceContainerHighest`, `completed` `primaryContainer`, `released` `successContainer`; `LinearProgressIndicator` value == `releasedTotal/total` (clamped 0..1); amount formatted via `BalanceFormatter` (`₦50,000.00`); title `textTheme.bodyMedium`
- [ ] **TT-10:** `escrow_detail_screen_test.dart` ≥12 cases green — pump with `Provider<EscrowProvider>` fake + `MaterialApp`: header shows badge + truncated `***ref`; disputed escrow shows `EscrowDisputeBanner` + all action buttons `onPressed == null`; `writeAvailable=false` shows `EscrowWriteCtaPanel` guidance + "Contact support", no enabled primary button; `writeAvailable=true` (injected mock) shows milestone action buttons; transactions list renders direction arrows; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily`), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:221`); `grep Colors.` assert = 0
- [ ] **TT-11:** `escrow_list_screen_test.dart` ≥8 cases green — cards render per escrow with badge + amount; empty → `HivorrEmptyState` ("No active escrows"); pull-to-refresh invokes provider `refresh`; error → `HivorrErrorState`
- [ ] **TT-12:** `escrow_write_cta_panel_test.dart` ≥6 cases green — `!writeAvailable`: guidance card visible, "Contact support" action, no `HivorrButton` enabled; `writeAvailable` (mock): complete/release buttons visible; disputed flag disables regardless
- [ ] **TT-13:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)` — AppTheme harness pattern

### 7.3 Integration (Fake-E2E) — `test/integration/finance/`

- [ ] **TT-14:** `test/integration/finance/escrow_proxy_seam_test.dart` green — fake `SupabaseClient.rpc` map + real `EscrowRepositoryImpl` + `writeViaProxy=false`: `getByProject('project-x')` → mock `financial_escrow_get → {escrow:{status:'funded'}, milestones:[{status:'pending'},...], transactions:[...]}` → `escrows.length==1` → `select(escrow.id)` → milestones rendered → `completeMilestone(...)` → **throws `EscrowWriteUnavailableException`** (proves guard) → assert `lastError.message` contains "support team" → same flow with `writeViaProxy=true` mock proxy → `completeMilestone` invokes proxy path (fake response) → re-read `getById` → milestone now `completed`; no `supabase start` container needed (live `supabase db test` is RLS truth)

### 7.4 Regression Guard

- [ ] **TT-15:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-16:** `flutter test --coverage` — domain ≥80% line coverage; mappers/service 100%, provider ≥90%;
- [ ] **TT-17:** `supabase db test` full suite `001-017` + financial `013-014` green — zero RLS/role regression
- [ ] **TT-18:** Lens greps — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data` = 0 (except `lib/app/theme/app_colors.dart:16`); `grep -r "fontFamily" lib/systems/finance` = 0; `grep -r "service_role" lib/systems/finance lib/data/finance` = 0; `grep -rn "supabase.rpc.*financial_escrow_\|financial_escrow_create\|financial_escrow_fund\|financial_escrow_release\|financial_escrow_refund\|financial_escrow_milestone_complete" lib/` = 0 (no direct write-RPC invocation)
- [ ] **TT-19:** `git diff --stat supabase/` = 0; `git status --porcelain .supabase/functions` empty (proxy deploy deferred); `git diff --stat lib/integrations/payment_gateways` = 0

### 7.5 Edge Cases

- [ ] **TT-20:** `escrow.status == 'disputed'` → banner + all actions `onPressed:null` even when `writeAvailable==true`
- [ ] **TT-21:** Empty escrow list → `HivorrEmptyState` "No active escrows — create one from a project contract page", no throw
- [ ] **TT-22:** Milestone sum boundary — `[50000,50000]` for `total 100000` passes at tolerance; `[50000.01, 49999.99]` passes; `[50000, 49999]` fails (tolerance 0.01)
- [ ] **TT-23:** Escrow lifecycle progression — `created → funded → partially_released → released` reflects server `status` exactly; terminal `refunded`/`cancelled` render `surfaceVariant` neutral
- [ ] **TT-24:** Null `dispute_id`/`funded_at`/`released_at`/`completed_at`/`released_at` → null-safe mapping, never throw; `released/0` progress → `LinearProgressIndicator` value `0` (no divide-by-zero)
- [ ] **TT-25:** Transaction array absent from `financial_escrow_get` response (migration returns `{escrow, milestones}` only `1142-1145`) → `transactionsByEscrowId` empty gracefully, no crash
- [ ] **TT-26:** `writeViaProxy=false` + any write action → guidance panel, never an enabled dead-end button

### 7.6 Failure Scenarios

- [ ] **TT-27:** `createEscrow` with mis-summed milestones → `PLT003 validation` inline, write seam not reached (proxy/remote spy not called)
- [ ] **TT-28:** `401 → PLT001` unauth → redirect `/login` via `RouteGuard`; `loadForProject` surfaces `ApiExceptionKind.auth`, not raw
- [ ] **TT-29:** Client attempt to invoke a write RPC → `42501`/`403 PLT002` mapped to `ApiExceptionKind.forbidden` (unit test); grep proves no such call exists in `lib/`
- [ ] **TT-30:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced — no raw JSON to UI
- [ ] **TT-31:** Network timeout → `ApiExceptionKind.timeout` + backoff `500ms→8s`; visible pull-to-refresh/error state
- [ ] **TT-32:** `5xx PLT999` retry 3x prod / 4x dev bounded; no infinite retry loop
- [ ] **TT-33:** Post-write (future, flag on) proxy failure → re-read fails → UI shows `HivorrErrorState` with retry; no optimistic stale state

### 7.7 Manual Testing

- [ ] **TT-34:** Manual spot-check (optional, `supabase start` or against local service-role seeded escrow): project contract page → `/finance/escrow` list shows cards → open funded escrow → `MilestoneListCard` progress + status chips → `writeAvailable=false` shows support guidance card (no dead button) → disputed escrow (seeded) shows frozen banner + disabled actions → amounts rendered `₦50,000.00 NGN` → `***ref`/initials truncated, no legal names

---

## 8. User Acceptance Verification

This task delivers the **Stage 5 escrow seam** — the marketplace trust anchor that lets buyers/payers and providers see milestone progress, escrow status, and dispute freeze, while staging the write path behind the EP-02-18 proxy. UAT verifies trust-visibility UX, graceful write-unavailable behavior, frozen-dispute handling, and downstream readiness.

- [ ] **UA-01:** The project lead can open `/finance/escrow` and see per-escrow cards with correct 7-state `EscrowStatusBadge` colors (`funded` `primaryContainer`, `released` `successContainer`, `disputed` `errorContainer`), `BalanceFormatter` amounts always with `symbol + code` (`₦50,000.00 NGN`), and entity `***last4` initials (never full legal names) — all AppTheme-token driven, no raw colors
- [ ] **UA-02:** Opening an escrow shows `MilestoneListCard` with the correct 3-state chips (`pending` `surfaceContainerHighest`, `completed` `primaryContainer`, `released` `successContainer`), a `LinearProgressIndicator` reflecting `releasedTotal/total`, and a read-only transaction envelope summary — no enabled dead-end controls
- [ ] **UA-03:** Disputed escrow freezes correctly — `EscrowDisputeBanner` (`errorContainer`, `Icons.gavel`) + "View dispute" routing to EP-02-05, and **every** milestone action button is disabled `onPressed:null` — the client reflects the server hold and never claims to be the enforcement
- [ ] **UA-04:** While `escrowWriteViaProxyEnabled == false` (production default), the write surface is the `EscrowWriteCtaPanel` guidance card "Escrow actions are handled by our support team" + "Contact support" — reads fully functional, no generic error, no silent no-op
- [ ] **UA-05:** Fail-fast milestone validation — create-form total/`sum` mismatch shows inline field error naming the offending milestone (`PLT003`-equivalent) before any write attempt; no round-trip for known-invalid input
- [ ] **UA-06:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), soft elevation not hard shadow, 8pt grid `AppThemeExtension`, ≥48dp touch targets, 16dp mobile / 24dp web responsive panes, light/dark WCAG AA `#0B6E99`/`#10B981` — no raw `Colors.*`/hex/`fontFamily` per `AGENT.md:17` Rule 5
- [ ] **UA-07:** Security transparent — `grep -r "service_role" lib/` = 0; no direct write-RPC string in `lib/` (`financial_escrow_create/fund/release/refund/milestone_complete` absent); all escrow state server-authoritative per `AGENT.md:16` Rule 4; anonymous/unauthenticated access redirects to `/login`
- [ ] **UA-08:** No PII leakage — `clientReference` truncated `***ref`, entity `***last4` initials, no dispute evidence on screen, no legal names anywhere in escrow UI or logs
- [ ] **UA-09:** Downstream unblocked — `EP-02-15` (conversion) and `EP-02-16` (payouts) can import `Escrow`/`EscrowMilestone`/`EscrowService` without `supabase.rpc` literals; `EP-02-18` receives the exact proxy call-site shapes, flag semantics, and `EscrowWriteUnavailableException` contract — flipping `escrowWriteViaProxyEnabled` to `true` is a config change, not a code change

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-14 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/entities/escrow.dart` exists — `Escrow{id, projectId, escrowInternalId, clientReference, creatorEntityId, providerEntityId, totalAmount, currencyCode, status, disputeId?, createdAt, fundedAt?, releasedAt?}` | File inspection | ☑ |
| 2 | `lib/data/entities/escrow_milestone.dart` exists — `EscrowMilestone{id, escrowId, title, amount, status, completedAt?, releasedAt?}` | File inspection | ☑ |
| 3 | `lib/data/entities/escrow_transaction.dart` exists — `EscrowTransaction{id, escrowId, type, amount, direction, entityId, reference, createdAt}` | File inspection | ☑ |
| 4 | `lib/data/datasources/remote/escrow_remote_data_source.dart` abstract — `getById`/`getByProject` + write seam `createEscrow/fundEscrow/completeMilestone/releaseMilestone/releaseFinal/refundEscrow` | File inspection | ☑ |
| 5 | `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` `extends BaseApiService` — read `financial_escrow_get` + `FinancialEnvelopeParser`; write branch `escrowWriteViaProxyEnabled` guard → `EscrowWriteUnavailableException`, proxy stub on; **never** calls write RPCs directly | Code review + unit test | ☑ |
| 6 | `lib/data/mappers/escrow_mapper.dart` defines `escrowToEntity`/`milestoneToEntity`/`transactionToEntity`/`entityToInput` — null → defaults, empty milestones → `[]` | Unit test | ☑ |
| 7 | `lib/data/repositories/escrow_repository.dart + _impl.dart` — `getById/getByProject/createEscrow/completeMilestone/releaseMilestone/releaseFinal/refundEscrow`; milestone-sum pre-validation (tolerance 0.01); propagates `EscrowWriteUnavailableException`; never writes escrow tables directly | Unit test | ☑ |
| 8 | `lib/systems/finance/models/escrow_status.dart` — 7 `EscrowStatus` matching `financial_escrow` check `204-207` + 3 `MilestoneStatus` matching `240-241` (no invented states) | File + unit test | ☑ |
| 9 | `lib/systems/finance/services/escrow_service.dart` exposes `validateMilestoneSums`/`releasedMilestoneTotal`/`completedMilestoneTotal`/`escrowWriteAvailable` (pure Dart) | File + unit test (100%) | ☑ |
| 10 | `escrowWriteViaProxyEnabled` flag in config, **default `false`** in Dev/Staging/Prod; no new `ENV` secrets | File inspection | ☑ |
| 11 | `lib/data/providers/escrow_provider.dart` — `ChangeNotifier` `escrows/selected/milestones/transactionsByEscrowId/loadState/writeAvailable` + `loadForProject/select/refresh/pausePolling/resumePolling/dispose`; mirrors `FinancialProvider:49` | Unit test (≥90%) | ☑ |
| 12 | `lib/systems/finance/screens/escrow_list_screen.dart` — `GET /finance/escrow`, escrow cards + `HivorrEmptyState` + pull-to-refresh, `AppTheme` tokens, responsive | Widget test | ☑ |
| 13 | `lib/systems/finance/screens/escrow_detail_screen.dart` — `GET /finance/escrow/:id`, header + dispute banner + `MilestoneListCard` + `EscrowWriteCtaPanel` + transaction summary | Widget test | ☑ |
| 14 | `lib/systems/finance/widgets/escrow_status_badge.dart` / `milestone_list_card.dart` / `escrow_write_cta_panel.dart` / `escrow_dispute_banner.dart` — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp; disputed banner disables all actions | Widget test | ☑ |
| 15 | Barrels `lib/systems/finance/finance.dart` + `lib/data/data_layer.dart` re-export new symbols | File inspection | ☑ |
| 16 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `escrow='/finance/escrow'` + `escrowDetail='/finance/escrow/:id'` guarded by `RouteGuard` | File + `go_router` smoke | ☑ |
| 17 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` | ☑ |
| 18 | No `.supabase/functions/*` files created — proxy deploy deferred to EP-02-18 | `git status --porcelain .supabase/functions` empty | ☑ |
| 19 | No `service_role`/secret leakage — `grep -r "service_role" lib/systems/finance lib/data/finance` = 0 | grep | ☑ |
| 20 | No direct escrow write-RPC invocation from client — `grep -rn "supabase.rpc.*financial_escrow_\|financial_escrow_create\|financial_escrow_fund\|financial_escrow_release\|financial_escrow_refund\|financial_escrow_milestone_complete" lib/` = 0 | grep | ☑ |
| 21 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0 | grep | ☑ |
| 22 | `test/unit/data/finance/escrow_remote_data_source_test.dart` ≥12 cases green (RPC envelope `PLT001/002/003/004/999`, write-seam guard both flag states) | `flutter test` | ☑ |
| 23 | `test/unit/data/finance/escrow_repository_test.dart` ≥14 + `escrow_mapper_test.dart` ≥10 + `escrow_write_unavailable_test.dart` ≥4 green | `flutter test` | ☑ |
| 24 | `test/unit/data/providers/escrow_provider_test.dart` ≥12 + `test/unit/systems/finance/escrow_service_test.dart` ≥10 green (sum invariant, status vocab, lifecycle) | `flutter test` | ☑ |
| 25 | `test/widget/systems/finance/escrow_status_badge_test.dart` ≥9 + `milestone_list_card_test.dart` ≥8 + `escrow_detail_screen_test.dart` ≥12 + `escrow_list_screen_test.dart` ≥8 + `escrow_write_cta_panel_test.dart` ≥6 green, token + layout asserts | `flutter test` | ☑ |
| 26 | `test/integration/finance/escrow_proxy_seam_test.dart` fake-E2E green: `getByProject → select → completeMilestone(flag off → guidance) → (flag on → proxy → re-read)` | `flutter test` | ☑ |
| 27 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI | ☑ |
| 28 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS/role regression | `supabase db test` | ☑ |
| 29 | `flutter test` total ≥62 unit assertions green; `EscrowService` 100%, `EscrowProvider` ≥90%, mappers 100% | `flutter test` | ☑ |
| 30 | Documentation: dartdoc on `Escrow`, `EscrowMilestone`, `EscrowTransaction`, `EscrowStatus`, `EscrowService`, `EscrowRepository` contract + `EscrowRemoteDataSource` write-seam/flags/EP-02-18 proxy swap-point doc | File inspection | ☑ |

---

> **Sign-off:** Task EP-02-14 marked **Completed** (Stage 5 — Financial Integrity Systems) — all 30 Final Approval Checklist conditions verified and signed off by the project lead: read seam `financial_escrow_get` live, write seam flag-guarded (`escrowWriteViaProxyEnabled=false`), full suite green, coverage targets met, `supabase db test` 17 files / 500 tests PASS, EP-02-18 handed the proxy call-site contract.
