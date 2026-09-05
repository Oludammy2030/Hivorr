# Task Implementation Plan — EP-02-14: Escrow & Milestone Payment Management

**Task ID:** EP-02-14 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** Critical | **Dependencies:** EP-02-04, EP-02-09 | **Stage:** 5 — Financial Integrity Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:390-399` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:4-8,15-17` | Dependencies: `EP-02:143-145` (`EP-02-14 → 04, 09`), `EP-02:373` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `supabase/migrations/20260829100004_financial_integrity_schema.sql:191-257,762-1102,1566-1618`, `lib/integrations/payment_gateways/payment_gateway_factory.dart`, `lib/core/api/services/base_api_service.dart:15`

---

## 1. Task Objective

Build the escrow & milestone payment management system in `lib/systems/finance/` — escrow creation draft (payer pays into escrow, funds held until milestone release), milestone lifecycle tracking, escrow detail viewing with frozen/disputed handling, and release-to-provider handoff. Build the complete data layer for escrow records and milestones, including the server-authoritative write seam behind `EscrowRemoteDataSource` with the Edge Function proxy as the documented swap point (feature flag off until available).

Deliverables:
- Data layer: `Escrow`, `EscrowMilestone`, `EscrowTransaction` entities + DTOs + mapper extensions, `EscrowRemoteDataSource` (read via `financial_escrow_get`; write seam abstracted behind Edge Function proxy flag), `EscrowRepository`, `EscrowProvider` in `lib/data/`
- Orchestration: `EscrowService` facade in `lib/systems/finance/`
- UI: `EscrowDetailScreen`, `EscrowListScreen`, `MilestoneListCard`, `EscrowStatusBadge` (`lib/systems/finance/widgets/` + `screens/`)
- Routes: `/finance/escrow` + `/finance/escrow/:id` (`lib/app/router/app_router.dart:17`)
- Barrel + DI: `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `EscrowRepository`)

## 2. Business Problem Being Solved

`EP-02:390-399` mandates **escrow & milestone payment management** as the trust anchor of the marketplace — buyers hold funds in escrow, providers are paid per milestone release. Server infrastructure exists and is frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql`):

- `financial_escrow` `191-227` — internal_id, `project_id uuid FK public.projects`, `client_reference` unique, `creator_entity_id`, `provider_entity_id` (buyer+provider from `public.entities`), `total_amount numeric(18,2)`, `currency_code`, `status in ('created','funded','partially_released','released','refunded','cancelled','disputed')` `205-209`, `dispute_id FK financial_disputes` `213-214`, `timestamps`, all nonzero amount guards server-side (`PLT021`).
- `financial_escrow_milestones` `232-257` — `escrow_id FK`, `title`, `amount numeric(18,2)`, `status in ('pending','completed','released')` `245-247`, `created_by_entity_id` (provider authorizes), `completed_at`, `released_at`. `sum(milestone amounts) == escrow total` enforced server-side (`PLT003`).
- RPCs: `financial_escrow_create` `762-838` (validates milestone sums, inserts escrow + milestones atomically), `financial_escrow_fund` `841-904`, `financial_escrow_release` `905-968` (per-milestone + final release), `financial_escrow_refund` `969-1026` (full refund to payer, one-time), `financial_escrow_milestone_complete` `1027-1087`, `financial_escrow_get` (read by payer/payee self-scoped).

**Critical write-seam constraint:** the five escrow write RPCs `financial_escrow_create/fund/release/refund/milestone_complete` are granted **`service_role`-only** in EP-02-04 — the authenticated client **cannot** call them directly (`403 PLT002 forbidden`). The authenticated read RPC `financial_escrow_get` is payer/payee-scoped with RLS. Therefore this task:

1. Instantiates all write pathways **client-side as an abstraction seam** — `EscrowRemoteDataSource` declares create/fund/release/refund/milestoneComplete, and the `SupabaseEscrowRemoteDataSource` implementation routes them to the **Edge Function proxy** (`financial-escrow-proxy`) which is the documented swap point that will enforce `auth.uid()` claims server-side. The feature flag `escrowWriteViaProxyEnabled` is **off by default** — until the Edge Function ships, calls surface a clear "Escrow actions not yet available — provider releases are handled by our support team" guidance, never a silent no-op or a direct `supabase.rpc` call.
2. Reads are fully live — the client renders escrow records, milestone lists, and status via `financial_escrow_get` today; write actions are staged behind the flag with full DI wiring so flipping the flag to `true` is a config change, not a code change.

Without EP-02-14:

- Every escrow screen would call `supabase.rpc('financial_escrow_get')` inline, duplicate envelope parsing and `ApiException` mapping — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:4-6` Separation of Concerns.
- No typed `Escrow`/`EscrowMilestone` entities — milestone sum validation (`sum(milestone amounts) == total_amount`) cannot be pre-checked client-side, causing avoidable `PLT003` round-trips on the server.
- No frozen rendering for `disputed` escrows — `EP-02-05` holds are a real business state; a client that lets a payer interact with a disputed milestone breaks the dispute freeze contract.
- No write-seam — when the Edge Function proxy ships (EP-02-18), escrow writes would require a rewrite of every screen; this task pre-wires the seam.
- No milestone progress display — providers cannot see which milestones are `completed` vs `pending` vs `released`, blocking trust-building milestone UX.

This task is the **Stage 5 escrow seam** that makes marketplace trust visible and, once the proxy flag flips, actionable.

## 3. Scope

| In Scope | Detail |
|---|---|
| `EscrowRemoteDataSource` abstract + `SupabaseEscrowRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). **Read** methods: `getByProject(projectId)`, `getById(id)` — via `supabase.rpc('financial_escrow_get')` envelope → `FinancialEnvelopeParser` + `DataExceptionMapper`. **Write** methods: `createEscrow`, `fundEscrow`, `releaseMilestone`, `releaseFinal`, `refundEscrow`, `completeMilestone` — routed via `escrowWriteViaProxyEnabled` feature flag; when `false` throws `EscrowWriteUnavailableException` with guidance; when `true` (future) invokes Edge Function proxy `financial-escrow-proxy`. **Never** calls write RPCs directly |
| Domain models | `Escrow` entity (`id, projectId, escrowInternalId, clientReference, creatorEntityId, providerEntityId, totalAmount, currencyCode, status, disputeId?, createdAt, fundedAt?, releasedAt?`), `EscrowMilestone` entity (`id, escrowId, title, amount, status, completedAt?, releasedAt?`), `EscrowTransaction` entity (`id, escrowId, type, amount, direction, entityId, reference, createdAt`) — pure Dart, no DTO leakage |
| DTOs + mappers | `EscrowDto`, `EscrowMilestoneDto`, `EscrowTransactionDto` — DTO layer in `lib/data/models/`; mapper extensions in `lib/data/mappers/escrow_mapper.dart` mapping DTOs → entities |
| `EscrowRepository` | `getByProject(projectId)`, `getById(id)`, `createEscrow(...)`, `fundEscrow(...)`, `releaseMilestone(...)`, `releaseFinal(...)`, `refundEscrow(...)`, `completeMilestone(...)` — orchestrates `EscrowRemoteDataSource` write-seam flags + maps DTOs. Validates milestone sum invariant client-side before write-seam call |
| `EscrowService` facade (`lib/systems/finance/`) | Thin wrapper over `EscrowRepository`. Exposes `escrrowWriteAvailable` (proxy flag), milestone sum validator, escrow status vocabulary (7 statuses + display labels/colors) and milestone status vocabulary (3 statuses). Adds `HivorrLogger` redacted log (`entityId: ***last4`, `escrowId`, amounts) via `pii_redactor.dart` — never logs `clientReference` full. Wraps `PerformanceTracer` span `finance.escrow.get.duration` |
| `EscrowProvider` (`ChangeNotifier`) `lib/data/providers/escrow_provider.dart` | `List<Escrow> escrows`, `Escrow? selected`, `List<EscrowMilestone> milestones`, `Map<String,List<EscrowTransaction>> transactionsByEscrowId`, `AsyncState loadState`, `bool writeAvailable`. Invalidates via `notifyListeners()`; `loadForProject()` fetches `financial_escrow_get`; `select(id)` loads detail + milestones + transactions. Mirrors `FinancialProvider` pattern (`lib/data/providers/financial_provider.dart:49`) with `WidgetsBindingObserver` lifecycle |
| UI screens + widgets | `EscrowDetailScreen` (`GET /finance/escrow/:id`), `EscrowListScreen` (`GET /finance/escrow`), `MilestoneListCard` (per-milestone status chips + progress bar), `EscrowStatusBadge` (7-status color mapping), `EscrowWriteCtaPanel` (disabled CTA + "via support" guidance when `!writeAvailable`) — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Barrel + DI | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports; factory `EscrowProvider.create(supabase: SupabaseClientProvider.client)` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, milestone sum trigger change, `supabase/config.toml` edit | `EP-02-04` frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1-1764`); this task is `lib/` only. `git diff --stat supabase/` must be `0` |
| Deploying the Escrow Edge Function proxy (`financial-escrow-proxy`) | EP-02-18 owns Edge Function deployment; this task pre-wires the client seam + flag. No `.supabase/functions/` files created here |
| Writing `financial_escrow` / `financial_escrow_milestones` directly from client via REST or `supabase.rpc` | `service_role`-only write RPCs (`762,841,905,969,1027`); the client write seam is the proxy flag, never direct RPC. RLS on escrow tables is default-deny `authenticated` — read via `financial_escrow_get` only |
| Dispute lifecycle (raise, evidence, resolution) | `EP-02-05` owns `financial_escrow.dispute_id` + `disputed` status transitions; this task only **renders** `disputed` frozen state and routes dispute info to `EP-02-05` screens |
| Payment gateway live charging (Paystack/Flutterwave card charge for funding) | `EP-02-09` owns provider abstractions; `fundEscrow` write action is staged behind the proxy flag — no live gateway call in this task |
| Escrow refund payout execution (paystack transfer, bank transfer) | `EP-02-16` owns payout binding + execution; refund is a one-time all-or-nothing server action `969-1026`, client only renders status |
| Provider payout settlement after release | `EP-02-16` — milestones `released` here surface provider receivable, not payout execution |
| Currency conversion of escrow amounts | `EP-02-15` — escrow displays `currency_code` + amount, does not convert |
| Audit trail / transaction history rendering beyond escrow-scoped `EscrowTransaction` | `financial_transactions` double-entry ledger is `EP-02-04` server-owned; client shows escrow envelope summary only |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/finance/` vs `lib/data/` vs edge seam

`ARCHITECTURE.md:55-60,101-110,131-138` assigns `lib/core/` = platform, `lib/data/` = DTO/entity/repository/provider, `lib/systems/finance/` = financial business system, `lib/integrations/` = external adapters. Escrow straddles data and systems like `EP-02-13` financial profiles: the **data layer** owns RPC transport + DTOs (reusable across `EP-02-15/16`), the **systems layer** owns escrow vocabulary, milestone progress logic, and UX orchestration. New here: the **Edge Function seam** is expressed **client-side only** — a feature-flagged method on `EscrowRemoteDataSource`, not a deployed function in this task.

No new top-level `lib/` directory. No `.supabase/functions/` directory created.

### 5.2 Data Layer Contract

```dart
// lib/data/datasources/remote/escrow_remote_data_source.dart
abstract class EscrowRemoteDataSource {
  // Read — live now, via financial_escrow_get
  Future<EscrowDto> getById(String id);
  Future<List<EscrowDto>> getByProject(String projectId);

  // Write — seam, behind escrowWriteViaProxyEnabled flag
  Future<EscrowDto> createEscrow(..., {required String currencyCode, required double totalAmount, required List<EscrowMilestoneInput> milestones});
  Future<void> fundEscrow({required String escrowId});
  Future<void> releaseMilestone({required String escrowId, required String milestoneId});
  Future<void> releaseFinal({required String escrowId});
  Future<void> refundEscrow({required String escrowId, required String reason});
  Future<void> completeMilestone({required String escrowId, required String milestoneId});
}

// lib/data/entities/escrow.dart
class Escrow {
  final String id;                  // financial_escrow.id
  final String projectId;
  final String escrowInternalId;    // financial_escrow.internal_id
  final String clientReference;
  final String creatorEntityId;
  final String providerEntityId;
  final double totalAmount;
  final String currencyCode;        // 'NGN', 'GHS', 'USD', 'GBP'
  final String status;              // 'created','funded','partially_released','released','refunded','cancelled','disputed'
  final String? disputeId;
  final DateTime createdAt;
  final DateTime? fundedAt;
  final DateTime? releasedAt;
}

// lib/data/entities/escrow_milestone.dart
class EscrowMilestone {
  final String id;
  final String escrowId;
  final String title;
  final double amount;
  final String status;              // 'pending','completed','released'
  final DateTime? completedAt;
  final DateTime? releasedAt;
}

// lib/data/entities/escrow_transaction.dart
class EscrowTransaction {
  final String id;
  final String escrowId;
  final String type;                // 'fund','release','refund','fee','chargeback'
  final double amount;
  final String direction;           // 'in'|'out'
  final String entityId;
  final String reference;
  final DateTime createdAt;
}
```

- Implementation `SupabaseEscrowRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper, bool writeViaProxy = false})`.
- Read methods invoke `supabase.rpc<Map<String,dynamic>>('financial_escrow_get', params: {p_escrow_id | p_project_id: ...})` — note the single RPC takes optional filter args (implementation confirms exact signature from `financial_escrow_get` `1027+` at build time from the migration), then envelope unwind (validates `{success:true, code:PLT000, data:{escrow:{}, milestones:[...], transactions:[...]}}`) via `FinancialEnvelopeParser` — same envelope as `SupabaseFinancialRemoteDataSource`.
- Write methods: `if (!writeViaProxy) throw const EscrowWriteUnavailableException();` else `Future` seam invoking Edge Function proxy — this is the **documented swap point**. The concrete proxy HTTP path (`supabase.functions.invoke('financial-escrow-proxy', body: {...})`) is NOT implemented in this task (EP-02-18 owns deploy); the branch is stubbed to throw `UnimplementedError('Edge Function proxy deployment pending EP-02-18')` only after the flag guard passes.
- `EscrowWriteUnavailableException extends ApiException` (`kind: forbidden`, message: "Escrow actions are not available yet — releases are handled by our support team.") — never a silent no-op.
- `DataExceptionMapper` maps `ApiException(PLT000/003/004/999)` to `DataException`.

### 5.3 Repository — `EscrowRepository` (the unit-tested business contract)

```dart
abstract class EscrowRepository {
  Future<Escrow> getById(String id);
  Future<List<Escrow>> getByProject(String projectId);
  Future<EscrowMilestone> completeMilestone({required String escrowId, required String milestoneId});
  Future<EscrowMilestone> releaseMilestone({required String escrowId, required String milestoneId});
  Future<void> releaseFinal({required String escrowId});
  Future<void> refundEscrow({required String escrowId, required String reason});
  Future<Escrow> createEscrow({required String projectId, required String currencyCode, required double totalAmount, required List<EscrowMilestoneInput> milestones, String? clientReference});
}
```

`EscrowRepositoryImpl` (`lib/data/repositories/escrow_repository_impl.dart`):

1. `getById(id)` / `getByProject(projectId)` → `remote.getById/getByProject` → `EscrowMapper.escrowToEntity(milestones: ..., transactions: ...)`. Read-only, live.
2. `createEscrow(...)` — **client pre-validates milestone sum invariant** (`sum(milestones.amount) == totalAmount`, tolerance `0.01`) before the write-seam call; on mismatch throws `ApiException(kind: validation, code: PLT003, message: 'Milestone amounts must sum to the escrow total')` — prevents a known server round-trip. Then `remote.createEscrow(...)` (flag-gated). On success re-reads `getById` to confirm server state.
3. `completeMilestone` / `releaseMilestone` / `releaseFinal` / `refundEscrow` → flag-gated `remote` calls. When `writeViaProxy == false`, the `EscrowWriteUnavailableException` propagates to UI, which renders the "via support team" panel. When true (future), awaits proxy response then re-reads `getById` for re-sync.
4. Repository **never writes** `financial_escrow`/`financial_escrow_milestones` directly — no REST `POST`, no direct `supabase.rpc` on write RPCs.

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.4 Systems Facade — `EscrowService` (`lib/systems/finance/`)

Thin wrapper used by `EscrowProvider` (ChangeNotifier) and future `EP-02-15/16` consumers:

- Exposes escrow status vocabulary (data-driven, matches `financial_escrow` check constraint `205-209`):
  ```dart
  const escrowStatuses = [
    EscrowStatus(code: 'created', label: 'Awaiting funding', tone: 'warning'),
    EscrowStatus(code: 'funded', label: 'Funded & held', tone: 'info'),
    EscrowStatus(code: 'partially_released', label: 'Milestones releasing', tone: 'info'),
    EscrowStatus(code: 'released', label: 'Released to provider', tone: 'success'),
    EscrowStatus(code: 'refunded', label: 'Refunded to payer', tone: 'neutral'),
    EscrowStatus(code: 'cancelled', label: 'Cancelled', tone: 'neutral'),
    EscrowStatus(code: 'disputed', label: 'In dispute — frozen', tone: 'danger'),
  ];
  ```
- Exposes milestone status vocabulary: `pending` → "Pending", `completed` → "Completed — awaiting release", `released` → "Released".
- `bool get escrowWriteAvailable => remote.writeViaProxy;` — surfaces proxy flag to UI.
- `bool validateMilestoneSums({required double totalAmount, required List<double> milestoneAmounts})` — pure `sum == total` (tolerance 0.01), used by create UI before submit.
- `double get releasedMilestoneTotal(List<EscrowMilestone> milestones)` — sum of `released` amounts (trust progress), `double get completedMilestoneTotal(...)` — sum of `completed` + `released`.
- Delegates to `EscrowRepository`; adds `HivorrLogger` + `PiiRedactor` redacted log (`escrowId`, `entityId: ***last4`, `amount`, `currencyCode`) — never `client_reference` full, never dispute evidence.
- `PerformanceTracer` spans `finance.escrow.get.duration`, `finance.escrow.list.duration`, `finance.escrow.milestone.sum.duration` (`lib/core/monitoring/performance_tracer.dart`).

### 5.5 State — `EscrowProvider` (`lib/data/providers/`)

```dart
class EscrowProvider extends ChangeNotifier {
  List<Escrow> escrows;
  Escrow? selected;
  List<EscrowMilestone> milestones;
  Map<String, List<EscrowTransaction>> transactionsByEscrowId;
  AsyncState loadState;
  ApiException? lastError;
  bool isRefreshing;
  bool writeAvailable;

  Future<void> loadForProject(String projectId); // escrows + milestones via financial_escrow_get
  Future<void> select(String escrowId);          // detail + milestones + transactions
  Future<void> refresh();                        // re-read current selection, maybeNotify
  void pausePolling();
  void resumePolling();
}
```

- Constructor injection `({required EscrowRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability (`provider:6.1.5`).
- Mirrors `FinancialProvider` pattern (`lib/data/providers/financial_provider.dart:49`) — `WidgetsBindingObserver` lifecycle, `NotificationProvider` on milestone release/release-final success (when flag on), `pausePolling`/`resumePolling` via `didChangeAppLifecycleState`.
- `loadForProject` maps escrow list + per-escrow milestones; `select` loads detail row + its milestones + transactions. 1–2 RPCs per screen visit, memoized per escrow id.
- `writeAvailable` initialized from `remote.writeViaProxy` at construction — UI reads once, not per-frame.
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.6 UI — `lib/systems/finance/screens/` + `widgets/`

- `EscrowListScreen` (`GET /finance/escrow`):
  1. Escrow cards per project — `EscrowStatusBadge` + total amount (`₦`, `₵`, `$`, `£` via `BalanceFormatter`), provider/creator entity initials (never full legal name), created date.
  2. Empty state `HivorrEmptyState` — "No active escrows — create one from a project contract page."
  3. Refresh via pull-to-refresh (`HivorrLoader` breathing pulse), not bare `CircularProgressIndicator` (`VISUAL-IDENTITY.md:148`).
- `EscrowDetailScreen` (`GET /finance/escrow/:id`):
  1. Header — `EscrowStatusBadge` + amount + currency code + client reference truncated (`***ref` via PiiRedactor).
  2. **Frozen-dispute banner** — when `escrow.status == 'disputed'`, amber/red banner "This escrow is in dispute — all actions are frozen until resolved" with "View dispute" action routing to `EP-02-05` dispute screen. All milestone action buttons disabled (`onPressed: null`).
  3. Milestone progress — `MilestoneListCard` per milestone: title, amount, status chip (`pending` grey, `completed` primary, `released` success), progress bar = `releasedMilestoneTotal / totalAmount` (`LinearProgressIndicator` value from `EscrowService`).
  4. Write action panel — `EscrowWriteCtaPanel`: when `writeAvailable == true` (future proxy on), shows provider-visible actions (complete/release milestone, release final, refund) as `HivorrButton` variants; when `false`, shows guidance card "Escrow actions are handled by our support team" with `Icons.help_outline` + "Contact support" action. **Never** renders an enabled button that would dead-end.
  5. Transaction summary — `EscrowTransaction` list (fund/release/refund entries) with direction arrows + `BalanceFormatter`, read-only.
- `EscrowStatusBadge` — pure widget: color map per 7 statuses using `colorScheme.*` (created `warningContainer`, funded `primaryContainer`, partially_released `primaryContainer`, released `successContainer`, refunded `surfaceVariant`, cancelled `surfaceVariant`, disputed `errorContainer`). No hardcoded hex.
- `MilestoneListCard` — pure widget: milestone rows + `LinearProgressIndicator(value: releasedTotal/total, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest)`.

Responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

### 5.7 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.escrow = '/finance/escrow'`, `escrowDetail = '/finance/escrow/:id'` and `RouteNames.escrow/escrowDetail`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required; no taxonomy gate. Detail route reads `:id` param → `EscrowProvider.select(id)`. No SEO public URL (private financial flow).

### 5.8 Config & Logging

- Feature flag `escrowWriteViaProxyEnabled` — `lib/config/app_config.dart` (or `environment_config.dart` where the repo places such flags) — **default `false`** in all environments (Dev/Staging/Prod) until the EP-02-18 Edge Function is deployed. No new `ENV` secrets.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server`. `SupabaseEscrowRemoteDataSource` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `escrowId`, `entityId suffix`, `amount`, `currencyCode`, milestone index (not title full); never `client_reference` full, never dispute evidence text, never milestone `title` if it embeds contract terms. `MonitoringService` span `finance.escrow.get` sampled.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `EscrowRemoteDataSource` abstract | `lib/data/datasources/remote/escrow_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseEscrowRemoteDataSource` | `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 (read live, write seam flag) |
| `Escrow` entity | `lib/data/entities/escrow.dart` | **Create** — §5.2 |
| `EscrowMilestone` entity | `lib/data/entities/escrow_milestone.dart` | **Create** — §5.2 |
| `EscrowTransaction` entity | `lib/data/entities/escrow_transaction.dart` | **Create** — §5.2 |
| `EscrowMilestoneInput` value object | `lib/data/models/escrow_milestone_input.dart` | **Create** — §5.3 create payload |
| DTOs | `lib/data/models/escrow_dto.dart`, `escrow_milestone_dto.dart`, `escrow_transaction_dto.dart` | **Create** — §5.2 |
| Mappers | `lib/data/mappers/escrow_mapper.dart` | **Create** — `escrowToEntity`, `milestoneToEntity`, `transactionToEntity`, `entityToInput` |
| `EscrowRepository` abstract + impl | `lib/data/repositories/escrow_repository.dart` + `escrow_repository_impl.dart` | **Create** — §5.3 |
| `EscrowProvider` (ChangeNotifier) | `lib/data/providers/escrow_provider.dart` | **Create** — §5.5 (mirrors `FinancialProvider` `lib/data/providers/financial_provider.dart:49`) |
| `EscrowService` facade | `lib/systems/finance/services/escrow_service.dart` | **Create** — §5.4 |
| `EscrowStatus` / `MilestoneStatus` vocab | `lib/systems/finance/models/escrow_status.dart` | **Create** — §5.4 |
| Screens | `lib/systems/finance/screens/escrow_list_screen.dart`, `escrow_detail_screen.dart` | **Create** — §5.6 |
| Widgets | `lib/systems/finance/widgets/escrow_status_badge.dart`, `milestone_list_card.dart`, `escrow_write_cta_panel.dart`, `escrow_dispute_banner.dart` | **Create** — §5.6 |
| Barrel | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` | **Update** — re-exports |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 2 routes, guard via `RouteGuard` |
| `FinancialEnvelopeParser` reuse | `lib/data/datasources/remote/financial_envelope_parser.dart` | **Reuse** — envelope unwrap for `financial_escrow_get` |
| `BalanceFormatter` reuse | `lib/systems/finance/helpers/balance_formatter.dart` (EP-02-13) | **Reuse** — format escrow amounts |
| Feature flag | `lib/config/` (config location per repo convention) | **Add** — `escrowWriteViaProxyEnabled` default `false` |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `.supabase/functions/*` | `.supabase/functions/` | **No change** — proxy deploy is EP-02-18 |
| Tests + fakes | `test/unit/data/finance/escrow_*`, `test/widget/systems/finance/escrow_*`, `test/support/fakes/fake_escrow_remote_data_source.dart` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Function files, no storage buckets.

## 7. Data Requirements

### 7.1 Escrow Headers (read-only via `financial_escrow_get`)

`financial_escrow` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:191-227`): `internal_id` text unique `194`, `project_id uuid FK public.projects` `195`, `client_reference` text unique `196`, `creator_entity_id uuid FK public.entities` `200`, `provider_entity_id uuid FK public.entities` `201`, `total_amount numeric(18,2)` `203`, `currency_code FK financial_supported_currencies` `204`, `status in ('created','funded','partially_released','released','refunded','cancelled','disputed')` `205-209`, `dispute_id uuid FK financial_disputes` (nullable) `213-214`, `created_at/funded_at/released_at` timestamps. One row per marketplace escrow. Client reads via `financial_escrow_get` (payer/payee self-scoped through creator/provider entity membership).

### 7.2 Escrow Milestones (read-only via `financial_escrow_get`)

`financial_escrow_milestones` (`232-257`): `escrow_id FK financial_escrow` `236`, `title` `238`, `amount numeric(18,2)` `239`, `status in ('pending','completed','released')` `245-247`, `created_by_entity_id` (provider marker) `248`, `completed_at`/`released_at` `250-252`. Invariant `sum(milestone amounts) == escrow total_amount` enforced by `financial_escrow_create` `762-838` (`PLT003` violation otherwise) and milestone amount updates `239` are server-guarded — client pre-validates the invariant before create to avoid the round-trip.

### 7.3 Escrow Transactions (read-only envelope)

`financial_escrow_get` returns a transactions array (fund/release/refund envelope events) derived from `financial_escrow_transactions` — type (`fund|release|refund|fee|chargeback`), amount, direction, reference. Client renders the summary; full double-entry ledger stays server-side (`financial_transactions` `EP-02-04`).

### 7.4 Write Payloads (seam, not live RPC)

| Action | Payload (via proxy when flag on) | Server RPC (service_role-only) |
|---|---|---|
| Create escrow | `{project_id, currency_code, total_amount, milestones:[{title, amount}], client_reference?}` | `financial_escrow_create` (`762`) |
| Fund escrow | `{escrow_id, payment method}` | `financial_escrow_fund` (`841`) |
| Complete milestone | `{escrow_id, milestone_id}` | `financial_escrow_milestone_complete` (`1027`) |
| Release milestone | `{escrow_id, milestone_id}` | `financial_escrow_release` (`905`) |
| Release final | `{escrow_id}` | `financial_escrow_release` final path |
| Refund | `{escrow_id, reason}` | `financial_escrow_refund` (`969`) |

Client sends these shapes through the Edge Function proxy **only when `escrowWriteViaProxyEnabled == true`**; today (`false`) the UI surfaces the support-team guidance instead. No `supabase.rpc` invocation of any `financial_escrow_*` write RPC from client code — static `grep` guard proves it.

### 7.5 Notification Payload (derived, not persisted)

`HivorrNotification{id: escrow.id.hashCode, title: status == 'released' ? 'Milestone released' : 'Escrow updated', body: '₦50,000.00 released to provider — milestone 2 of 3', channel: system, priority: medium, actionRoute: '/finance/escrow/:id'}` — local notification only; no `supabase_realtime` payload (escrow events surface on next `financial_escrow_get` fetch).

## 8. Database Considerations

- **Zero DDL in this task.** `public.financial_escrow`, `public.financial_escrow_milestones`, `public.financial_escrow_transactions`, `public.financial_disputes` all exist (`supabase/migrations/20260829100004_financial_integrity_schema.sql:191-257,258-320`). No `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger added. Full pgTAP `001-017` + financial `013-014` suites must remain green.
- **RLS posture inherited:** RLS enabled on all 12 financial tables (`479-490`) + default-deny `revoke all from anon, authenticated, service_role` (`492-506`) + escrow-specific: `financial_escrow: authenticated SELECT where auth is creator or provider` `536`, `financial_escrow_milestones: authenticated SELECT (via escrow role)` `539`, `financial_escrow_transactions: authenticated SELECT (via escrow role)` — client reads escrow via `financial_escrow_get` only.
- **Write bypass is impossible by construction:** the five escrow write RPCs are granted `service_role` only (`financial_escrow_create` `762+`, `fund` `841+`, `release` `905+`, `refund` `969+`, `milestone_complete` `1027+`). An authenticated client calling any of them via `supabase.rpc` receives `403 PLT002 forbidden`. The Edge Function proxy (EP-02-18) will carry the `service_role` key **server-side only**, authenticated via `auth.uid()` claims — this client task never holds it. `grep -r "service_role" lib/systems/finance lib/data/finance` must be `0`.
- **Execution model respected:** `financial_escrow_get` is `authenticated`, self-scoped `732/737` (creator or provider). All write RPCs `SECURITY INVOKER` `767`, RLS applies inside function body.
- **Dispute hold is server-authoritative:** `financial_escrow_release` independently blocks `disputed` status (`905-968` — guards `status IN ('funded','partially_released')`). The client also renders `disputed` as frozen UI — defense-in-depth, not the enforcement.
- **Milestone sum invariant:** enforced in `financial_escrow_create` (`762-838`, `PLT003` when `sum(milestones.amount) <> total_amount`). Client pre-validates same invariant (tolerance `0.01`) so the create form fails fast before the proxy round-trip.
- **No service-role bypass in client.** Adapters never hold `service_role` key; `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) uses `anon`/`authenticated` role with RLS.
- **Audit:** `financial_audit_trail` writes (`escrow_created`, `escrow_funded`, `escrow_milestone_released`, `escrow_refunded`) are written server-side inside the write RPCs; client never inserts audit rows directly.

## 9. API Requirements

### 9.1 Supabase RPC — Read (live)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Get single escrow | `financial_escrow_get` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1027+`) | `p_escrow_id` (or `p_project_id`) | `authenticated` self-scoped (creator or provider) | `200 {success:true, code:PLT000, data:{escrow:{...}, milestones:[{...}], transactions:[...]}}` | `404 PLT004 notFound`, `403 PLT002 forbidden` (not party to escrow), `401 PLT001 auth` |
| List escrows for project | `financial_escrow_get` | `p_project_id` | `authenticated` self-scoped | `200 {success:true, code:PLT000, data:{escrows:[...], milestones:[...]}}` | `404 PLT004 notFound`, `401 PLT001 auth` |

All `supabase.rpc<Map<String,dynamic>>('financial_escrow_get', params: {...})` unwrapped via `FinancialEnvelopeParser` `lib/data/datasources/remote/financial_envelope_parser.dart` — checks `data['success']==true && data['code']=='PLT000'` else throws `ApiException` with extracted `code/message`.

### 9.2 Edge Function Proxy Seam (write — staged, flag off)

| Operation | Transport | Status | Notes |
|---|---|---|---|
| `createEscrow` / `fundEscrow` / `completeMilestone` / `releaseMilestone` / `releaseFinal` / `refundEscrow` | `supabase.functions.invoke('financial-escrow-proxy', body: <action payload>)` | **Staged** (`escrowWriteViaProxyEnabled == false` → `EscrowWriteUnavailableException`) | EP-02-18 deploys the function; this task wires the call site + flag + exception surface. Proxy authenticates via `auth.uid()` and calls the `service_role`-only RPCs server-side with entity claims |
| Reading `financial_escrow_get` | `supabase.rpc` | **Live today** | Unchanged RLS self-scoped |
| `financial_status_get` active escrow count | `supabase.rpc('financial_status_get')` | **Live today** (EP-02-13 surface) | `active_escrow_count` drives "N active escrows" summary if desired |

No Supabase REST `POST /rest/v1/financial_escrow` — table RLS is default-deny; client never writes escrow tables via REST. No `lib/integrations/payment_gateways/` mutation.

### 9.3 No Storage / No Edge Function Deploy

No `Supabase Storage` REST (escrow is RPC-driven, no upload). No Edge Function **deploy** in this task — the seam is client-side only (EP-02-18 owns `.supabase/functions/financial-escrow-proxy/index.ts`). No live payment provider SDK calls until flag on.

### 9.4 Error Contract

Every public method throws only `ApiException` (`api_exception.dart:6-66` kinds) or `DataException` — never raw `Supabase`/`DioException`. `BaseApiService.invoke` normalizes `DioException` via `ApiExceptionMapper.map`. `EscrowWriteUnavailableException` is an `ApiException` subclass `kind: forbidden` with the support-team guidance message — deliberately distinct from `PLT002` so UI can render the "actions via support" panel rather than a generic forbidden error.

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies (all `AppTheme` tokens `documents/Context/VISUAL-IDENTITY.md:176-190`).** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`, `lib/app/theme/app_theme_extension.dart`) — never `Colors.*` or `Color(0xFF...)` inline (that hex lives only in `AppColors`).
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')` (delegated to `lib/app/theme/app_text_theme.dart`).
- Source spacing/radius/elevation/motion via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation`/`duration` (`VISUAL-IDENTITY.md:219-235`) — 8pt grid, cards 16dp, sheets 24dp top.
- Handle 4 states via branded primitives (`lib/shared/widgets/hivorr_empty_state.dart`, `hivorr_loading_state.dart`, `hivorr_error_state.dart`, `hivorr_success_state.dart`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `EscrowListScreen` | `GET /finance/escrow` | Escrow list for project / across escrows | `AppBar(title: Text('Escrows', style: textTheme.titleLarge))`, escrow cards (status badge + total + entity initials), pull-to-refresh, `HivorrEmptyState` ("No active escrows") |
| `EscrowDetailScreen` | `GET /finance/escrow/:id` | Single escrow detail + milestones + actions | Header (badge + amount + `***ref`), `EscrowDisputeBanner` when `disputed` (frozen, actions disabled, "View dispute"), `MilestoneListCard` (status chips + `LinearProgressIndicator`), `EscrowWriteCtaPanel` (guidance when flag off; actions when on), transaction summary |
| `EscrowStatusBadge` | — | 7-status chip | `Container(decoration: BoxDecoration(color: <status tone color>, borderRadius: BorderRadius.circular(ext.radiusSm)))`, label from `EscrowStatus` vocab, no hex |
| `MilestoneListCard` | — | Milestone progress | Per-milestone row: title (`textTheme.bodyMedium`) + amount (`BalanceFormatter`) + status chip (`pending` `surfaceContainerHighest`, `completed` `primaryContainer`, `released` `successContainer`); `LinearProgressIndicator(value: releasedTotal/total, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest)` |
| `EscrowWriteCtaPanel` | — | Action surface | When `writeAvailable`: provider-visible `HivorrButton`s (Complete milestone / Release / Release final / Refund). When `!writeAvailable`: `Card` guidance "Escrow actions are handled by our support team" + `Icons.help_outline` + "Contact support"; **no enabled dead-end buttons** |
| `EscrowDisputeBanner` | — | Frozen state | `Container` `colorScheme.errorContainer`, `Icons.gavel` or `Icons.help`, "In dispute — all actions frozen", "View dispute" → EP-02-05 route |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Amounts always rendered with `BalanceFormatter` (`₦/₵/$/£`, `EP-02-13`) — never raw `double.toString()`.

## 11. User Experience Considerations

- **Trust through progress, not through buttons:** The primary UX is visibility — payer and provider both see milestone status (`pending/completed/released`), released total, and dispute freeze. Action buttons take a back seat to status clarity; when write is on (future), the release flow is milestone-by-milestone, never one-shot for funded escrows.
- **Graceful write-unavailable state:** While `escrowWriteViaProxyEnabled == false`, escrow screens show reads fully (list, detail, milestones, transactions) with a clear non-blocking guidance card for writes — the user is never surprised by a disabled button or a generic error. Support-team contact is a first-class action.
- **Frozen dispute UX:** `disputed` escrows render the banner + fully disabled actions (`onPressed: null`) + microcopy "resolved via the dispute team" — the client reflects the server hold (`financial_escrow_release` blocks `disputed`), but never claims to be the enforcement.
- **Fail-fast milestone validation:** The create form validates `sum(milestones.amount) == total_amount` client-side before any write attempt — no round-trip for a known `PLT003` violation, and the field-level error names the offending milestone.
- **Progressive disclosure:** List screen shows cards, not transaction walls; detail screen reveals transaction envelope summary on a secondary tab/section. Numeric amounts formatted locale-aware; currency always shown (₦50,000.00 NGN) to prevent cross-currency confusion.
- **Entity initials, never names:** Escrow party display uses `creatorEntityId/providerEntityId` suffix initials (`***1234`) or "Payer"/"Provider" labels — no full legal names on screen, matching the PII-redaction posture (`AGENT.md` privacy rules).

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative escrow** `AGENT.md:16` Rule 4 | Client never writes `financial_escrow.*` or `financial_escrow_milestones.*` directly via REST or `supabase.rpc`. All write paths are an absttaskractioned seam; today the seam throws guidance, tomorrow it calls the Edge Function proxy which authenticates `auth.uid()` claims server-side and invokes the `service_role`-only RPCs. RLS on escrow tables is default-deny `authenticated` for writes — any direct `POST` returns RLS violation or `403 PLT002`. |
| **No `service_role` leak** | No `service_role` import anywhere in client data/systems; `EscrowProvider` never holds `service_role` key; the proxy key lives in Supabase Edge Function env only (EP-02-18). `grep lib/systems/finance lib/data "service_role"` = 0. |
| **PII exposure** | Escrow detail renders `client_reference` truncated (`***ref`), party entity **IDs** suffix only; `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) masks `entityId` to `***last4`, never logs milestone `title` full, never dispute evidence text, never full `client_reference`. |
| **Dispute freeze defense-in-depth** | Server `financial_escrow_release` independently blocks `disputed` (`905-968`); client renders frozen UI. Both layers must agree; the client layer is UX, the server layer is enforcement. `grep` lens proves no client code path releases a disputed milestone. |
| **Milestone sum server check** | `financial_escrow_create` `762-838` enforces `sum(milestones.amount) == total_amount` (`PLT003`). Client pre-validation is UX fast-fail; the server remains the single authority — a client bug can never create a mis-summed escrow. |
| **Time-of-check / race** | `financial_escrow.client_reference` unique `196` + server conditional guards on status transitions prevent double-fund/double-release; client `releaseMilestone` re-reads `getById` after modal confirm to show post-release truth, never optimistically updating UI state. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); escrow reads/writes per environment via migration + proxy env, no cross-env read. |
| **Amount formatting safety** | Numeric amounts always rendered via `BalanceFormatter` (locale-aware thousands + 2dp) — never raw `double` string concat that could leak precision or collide with direction arrows. `total_amount numeric(18,2)` handled as double in client, authoritative decimal on server. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **RPC cost** | `financial_escrow_get` `STABLE` + indexed `financial_escrow_client_reference_key` `196`, `financial_escrow_milestones_escrow_id_idx` `255` — negligible. `EscrowProvider.select` = 1 RPC for detail + milestones + transactions envelope. |
| **Caching** | `EscrowProvider` memoizes `escrows` + per-escrow `milestones` + `transactionsByEscrowId` in memory. `refresh()` re-reads only the current selection. No disk persistence (escrow is live financial state, not offline-cacheable). Invalidate on pull-to-refresh, lifecycle resume, or post-write re-sync. |
| **Milestone progress math** | `EscrowService.releasedMilestoneTotal` = single `fold` over ≤20 milestones — microseconds, safe per-frame per milestone row count. |
| **Feature flag read cost** | `escrowWriteAvailable` read once at provider construction, not per frame — no config lookups in build methods. |
| **Lifecycle pause/resume** | `WidgetsBindingObserver` `didChangeAppLifecycleState` pauses `EscrowProvider` polling on background, resumes on foreground — no wasted RPCs while app is backgrounded. |
| **Tracer overhead** | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart:1`) around `getById`/`getByProject`/`select`, sampled via `MonitoringConfig`, tags `finance.escrow.status`, `finance.escrow.milestone.count`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors the EP-02-13 suite + `test/support/fakes/fake_supabase.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `escrow_remote_data_source_test.dart` | 12 | Mock `SupabaseClient.rpc` via fake `SupabaseClient`: `financial_escrow_get → {success:true, data:{escrow:{...}, milestones:[...], transactions:[...]}}` success; `p_project_id` list success; `404 PLT004 notFound` → `notFound`; `403 PLT002 forbidden` → `forbidden`; envelope `success:false → PLT003` → `validation`; `401 PLT001 auth`, `500 PLT999`; **write seam**: `writeViaProxy=false` → `createEscrow/fundEscrow/releaseMilestone/releaseFinal/refundEscrow/completeMilestone` each throw `EscrowWriteUnavailableException`; `writeViaProxy=true` → proxy branch invoked (stub `UnimplementedError` confirms no direct RPC call) |
| `escrow_repository_test.dart` | 14 | Fake `SupabaseEscrowRemoteDataSource` + real `EscrowRepositoryImpl`. `getById` maps escrow + milestones + transactions; `getByProject` maps list; `createEscrow` pre-validates milestone sum (`[50000, 50000]` for `total 100000` passes; `[40000, 40000]` for `total 100000` throws `PLT003 validation` before remote); `createEscrow` with `writeViaProxy=false` propagates `EscrowWriteUnavailableException`; `completeMilestone/releaseMilestone/releaseFinal/refundEscrow` re-read after proxy success (when flag on); PLT004 surfaces notFound |
| `escrow_provider_test.dart` | 12 | `ChangeNotifier` with mocked repository: `loadForProject` sets `loadState=loading` then `success` with escrows+milestones; `select(id)` loads detail; `refresh` re-reads and `notifyListeners`; `writeAvailable` from repo/config at construction; lifecycle `pausePolling`/`resumePolling`; error state surfaces `lastError.message` |
| `escrow_mapper_test.dart` | 10 | `EscrowDto.fromJson → Escrow` mapping `internal_id, client_reference, creator_entity_id, provider_entity_id, total_amount, currency_code, status, dispute_id`; `EscrowMilestoneDto.fromJson → EscrowMilestone` mapping `title, amount, status, completed_at, released_at`; `EscrowTransactionDto.fromJson` mapping `type, direction, reference`; null `dispute_id` → null; status string passthrough |
| `escrow_service_test.dart` | 10 | `validateMilestoneSums(100000, [50000,50000]) == true`; `(100000, [40000,40000]) == false`; tolerance `0.01`; `releasedMilestoneTotal` sums only `released`; `completedMilestoneTotal` sums `completed`+`released`; `escrowStatuses.length == 7`; status vocab labels match server check constraint `205-209`; disputed tone `danger` |
| `escrow_write_unavailable_test.dart` | 4 | Exception is `ApiException kind: forbidden`; message contains support guidance; no silent no-op; surfaces distinct from `PLT002` |

Target **≥62 unit assertions**; repository/provider ≥90%, mappers/service 100%.

### 14.2 Widget Suite — `test/widget/systems/finance/`

| File | Cases (min) | Method |
|---|---|---|
| `escrow_status_badge_test.dart` | 9 | Pump with `MaterialApp` `AppTheme.light` (`lib/app/theme/app_theme.dart:1`): each of 7 statuses renders label + expected `colorScheme` container (created `warningContainer`, funded `primaryContainer`, partially_released `primaryContainer`, released `successContainer`, refunded `surfaceVariant`, cancelled `surfaceVariant`, disputed `errorContainer`); no hardcoded hex; `grep Colors.` assert `0` |
| `milestone_list_card_test.dart` | 8 | `pending` chip `surfaceContainerHighest`, `completed` `primaryContainer`, `released` `successContainer`; `LinearProgressIndicator` value == `releasedTotal/total`; amount formatted via `BalanceFormatter` (`₦50,000.00`); title rendered `textTheme.bodyMedium` |
| `escrow_detail_screen_test.dart` | 12 | Pump with `Provider<EscrowProvider>` fake + `MaterialApp`: header shows badge + truncated `***ref`; disputed escrow shows `EscrowDisputeBanner` + all action buttons `onPressed == null`; `writeAvailable=false` shows `EscrowWriteCtaPanel` guidance + "Contact support", no enabled primary button; `writeAvailable=true` (injected mock) shows milestone action buttons; transactions list renders direction arrows; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge`, spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`); `grep Colors.` assert `0` |
| `escrow_list_screen_test.dart` | 8 | Cards render per escrow with badge + amount; empty → `HivorrEmptyState` ("No active escrows"); pull-to-refresh invokes provider `refresh`; error → `HivorrErrorState` |
| `escrow_write_cta_panel_test.dart` | 6 | `!writeAvailable`: guidance card visible, "Contact support" action, no `HivorrButton` enabled; `writeAvailable` (mock): complete/release buttons visible; disputed flag disables regardless |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/finance/escrow_proxy_seam_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseClient.rpc` map + real `EscrowRepositoryImpl` + `writeViaProxy=false`. Flow: `getByProject('project-x')` → mock `financial_escrow_get → {escrow:{status:'funded'}, milestones:[{status:'pending'},...], transactions:[...]}` → `escrows.length == 1` → `select(escrow.id)` → milestones rendered statuses → `completeMilestone(...)` → **throws `EscrowWriteUnavailableException`** (proves the guard) → assert `lastError.message` contains "support team" → same flow with `writeViaProxy=true` mock proxy → `completeMilestone` invokes proxy path (fake response) → re-read `getById` → milestone now `completed`. No `supabase start` container needed; live `supabase db test` is source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + financial `013-014` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (private finance seam) except `lib/app/theme/app_colors.dart:16`, `grep -r "fontFamily" lib/systems/finance` = 0, `grep -r "service_role" lib/` = 0, `grep -rn "supabase.rpc.*financial_escrow_\|financial_escrow_create\|financial_escrow_fund\|financial_escrow_release\|financial_escrow_refund\|financial_escrow_milestone_complete" lib/` = 0 (no direct write-RPC invocation), `git diff --stat supabase/` = 0, `git status --porcelain .supabase/functions` empty.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_escrow_remote_data_source.dart` export. Static grep lens proves the client never calls a `service_role` write RPC directly and holds no `service_role` key.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/migrations/20260829100004_financial_integrity_schema.sql:191-257,762-1102,1566-1618`, `lib/data/providers/financial_provider.dart:49`, `lib/data/datasources/remote/financial_envelope_parser.dart`, `lib/core/api/services/base_api_service.dart:15`, `lib/core/api/exceptions/api_exception_mapper.dart:15`, config-file convention for feature flags | Baseline |
| 2 | Create `lib/data/entities/escrow.dart` — `Escrow{id, projectId, escrowInternalId, clientReference, creatorEntityId, providerEntityId, totalAmount, currencyCode, status, disputeId?, createdAt, fundedAt?, releasedAt?}` entity | Entity |
| 3 | Create `lib/data/entities/escrow_milestone.dart` — `EscrowMilestone{id, escrowId, title, amount, status, completedAt?, releasedAt?}` entity | Entity |
| 4 | Create `lib/data/entities/escrow_transaction.dart` — `EscrowTransaction{id, escrowId, type, amount, direction, entityId, reference, createdAt}` entity | Entity |
| 5 | Create `lib/data/models/escrow_dto.dart`, `escrow_milestone_dto.dart`, `escrow_transaction_dto.dart`, `escrow_milestone_input.dart` — JSON serialization DTOs matching `financial_escrow_get` response shape + create payload shape | DTOs |
| 6 | Create `lib/data/mappers/escrow_mapper.dart` — `escrowToEntity`, `milestoneToEntity`, `transactionToEntity`, `entityToInput` extension methods | Mappers |
| 7 | Create `lib/data/datasources/remote/escrow_remote_data_source.dart` — abstract `EscrowRemoteDataSource` §5.2 (3 read, 6 write seam methods) | Contract |
| 8 | Create `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` — `BaseApiService` impl: `financial_escrow_get` read live; write branch `escrowWriteViaProxyEnabled` guard → `EscrowWriteUnavailableException` or proxy stub | Remote |
| 9 | Create `lib/data/repositories/escrow_repository.dart` abstract + `lib/data/repositories/escrow_repository_impl.dart` — §5.3 `getById/getByProject/createEscrow/completeMilestone/releaseMilestone/releaseFinal/refundEscrow`; milestone-sum pre-validation; never writes escrow tables directly | Repository |
| 10 | Create `lib/systems/finance/models/escrow_status.dart` — `EscrowStatus` + `MilestoneStatus` vocab §5.4 | Status vocab |
| 11 | Create `lib/systems/finance/services/escrow_service.dart` — facade §5.4: `validateMilestoneSums`, `releasedMilestoneTotal`, `completedMilestoneTotal`, `escrowWriteAvailable` | Service |
| 12 | Add feature flag `escrowWriteViaProxyEnabled` (default `false`) to config (per repo convention) | Config |
| 13 | Create `lib/data/providers/escrow_provider.dart` — `ChangeNotifier` §5.5 (mirrors `FinancialProvider` `lib/data/providers/financial_provider.dart:49` lifecycle, `pausePolling`/`resumePolling`) | Provider |
| 14 | Create widgets `lib/systems/finance/widgets/escrow_status_badge.dart`, `milestone_list_card.dart`, `escrow_write_cta_panel.dart`, `escrow_dispute_banner.dart` — `AppTheme` tokens only | Widgets |
| 15 | Create screens `lib/systems/finance/screens/escrow_list_screen.dart`, `escrow_detail_screen.dart` — §5.6 responsive, branded states, frozen-dispute handling | Screens |
| 16 | Update barrels `lib/systems/finance/finance.dart:1`, `lib/data/data_layer.dart:1` | Barrels |
| 17 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `escrow/escrowDetail` routes guarded by `RouteGuard` | Routes |
| 18 | Create `test/support/fakes/fake_escrow_remote_data_source.dart` + `test/support/fakes/fake_escrow_repository.dart` | Test infra |
| 19 | Create `test/unit/data/finance/escrow_remote_data_source_test.dart` (12) + `escrow_repository_test.dart` (14) + `escrow_mapper_test.dart` (10) + `escrow_write_unavailable_test.dart` (4) | Tests 1 |
| 20 | Create `test/unit/data/providers/escrow_provider_test.dart` (12) + `test/unit/systems/finance/escrow_service_test.dart` (10) | Tests 2 |
| 21 | Create `test/widget/systems/finance/escrow_status_badge_test.dart` (9) + `milestone_list_card_test.dart` (8) + `escrow_detail_screen_test.dart` (12) + `escrow_list_screen_test.dart` (8) + `escrow_write_cta_panel_test.dart` (6) | Tests 3 |
| 22 | Create `test/integration/finance/escrow_proxy_seam_test.dart` — fake-E2E `getByProject → select → completeMilestone(flag off → guidance) → (flag on → proxy → re-read)` | Integration |
| 23 | `flutter analyze` + `flutter test --coverage` (≥62 assertions green, repository ≥90%, mapper 100%) | Verify |
| 24 | `supabase db test` full suite `001..017` + `013-014` green + grep lenses: `Colors.\|Color(0x` = 0, `service_role` in `lib/systems/finance lib/data` = 0, no direct write-RPC `supabase.rpc` call, `git diff --stat supabase/` = 0, `.supabase/functions` untouched | Regression |
| 25 | Doc pass: dartdoc on `Escrow`, `EscrowMilestone`, `EscrowTransaction`, `EscrowStatus`, `EscrowService`, `EscrowRepository` contract + `EscrowRemoteDataSource` seam doc | Docs |
| 26 | Tag `EP-02-15/16` unblocked; phase plan `EP-02-14` → `Completed` candidate pending review; hand EP-02-18 the proxy call-site contract | Handoff |

## 16. Expected Outcome

- `lib/data/` exposes a single seam for escrow state: `EscrowRepository` reads `financial_escrow`, `financial_escrow_milestones`, and escrow transactions via the live `financial_escrow_get` RPC, maps via `EscrowMapper` to pure `Escrow`/`EscrowMilestone`/`EscrowTransaction`, and stages all six write pathways (`createEscrow/fundEscrow/completeMilestone/releaseMilestone/releaseFinal/refundEscrow`) behind the `escrowWriteViaProxyEnabled` feature flag — never calling a `service_role`-only RPC from the client.
- The **Edge Function proxy is the documented swap point**: segment flipping `escrowWriteViaProxyEnabled` from `false` to `true` (post EP-02-18 deploy) activates the write seam with no other code change; until then the UI renders the support-team guidance panel, never a dead-end or disabled-without-explanation control.
- `lib/systems/finance/` provides the escrow vocabulary (`EscrowStatus` 7-state, `MilestoneStatus` 3-state) and pure milestone-progress math (`validateMilestoneSums`, `releasedMilestoneTotal`, `completedMilestoneTotal`) — matching the frozen server check constraint `205-209`/`245-247` and enforcing the `sum(milestones) == total` invariant pre-flight.
- `EscrowProvider` (`ChangeNotifier`) owns memoized list/detail/transactions state, `WidgetsBindingObserver` lifecycle, and optical re-sync after (future) writes — mirroring the proven `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) pattern with no `supabase_realtime`.
- `EscrowListScreen` + `EscrowDetailScreen` render status badges, milestone progress, frozen-dispute banner, and transactions with **zero hardcoded `Colors.*`/hex/`fontFamily`** — all `Theme.of(context).colorScheme.*`/`textTheme.*`/`AppThemeExtension` tokens (`VISUAL-IDENTITY.md:176-190,219-235`), responsive via `shared/layouts/` (16dp mobile / 24dp web), branded states via `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrLoader`.
- Unit suite ≥62 assertions green with mocked `SupabaseClient`/`Dio`; `flutter analyze` clean; full pgTAP `001-017` + financial `013-014` green; grep lenses prove no `service_role`, no hardcoded color/font leakage, and **no direct client invocation of escrow write RPCs**; `git diff --stat supabase/` = 0; `.supabase/functions` untouched.
- `EP-02-15` (currency conversion) and `EP-02-16` (payouts, deposit verification) unblocked — escrow seam provides typed entities, milestone progress, and the release-to-receivable handoff for payout execution; EP-02-18 receives the exact proxy call-site contract.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/entities/escrow.dart` exists — `Escrow{id, projectId, escrowInternalId, clientReference, creatorEntityId, providerEntityId, totalAmount, currencyCode, status, disputeId?, createdAt, fundedAt?, releasedAt?}` | File inspection |
| 2 | `lib/data/entities/escrow_milestone.dart` exists — `EscrowMilestone{id, escrowId, title, amount, status, completedAt?, releasedAt?}` | File inspection |
| 3 | `lib/data/entities/escrow_transaction.dart` exists — `EscrowTransaction{id, escrowId, type, amount, direction, entityId, reference, createdAt}` | File inspection |
| 4 | `lib/data/datasources/remote/escrow_remote_data_source.dart` exists — abstract `EscrowRemoteDataSource` with read `getById`/`getByProject` and write seam `createEscrow`/`fundEscrow`/`completeMilestone`/`releaseMilestone`/`releaseFinal`/`refundEscrow` | File inspection |
| 5 | `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart` implements `EscrowRemoteDataSource` — read via `supabase.rpc('financial_escrow_get')` + `FinancialEnvelopeParser`; write branch guarded by `escrowWriteViaProxyEnabled`, throws `EscrowWriteUnavailableException` when off, proxy stub when on; **never** calls write RPCs directly | File + unit test |
| 6 | `lib/data/mappers/escrow_mapper.dart` defines `escrowToEntity`, `milestoneToEntity`, `transactionToEntity`, `entityToInput` — maps DTOs to entities, null → defaults | Unit test |
| 7 | `lib/data/repositories/escrow_repository.dart` + `escrow_repository_impl.dart` define `EscrowRepository{getById,getByProject,createEscrow,completeMilestone,releaseMilestone,releaseFinal,refundEscrow}` — validates milestone-sum invariant before create, propagates `EscrowWriteUnavailableException`, never writes escrow tables directly | Unit test |
| 8 | `lib/systems/finance/models/escrow_status.dart` defines 7 `EscrowStatus` entries matching `financial_escrow` check constraint `205-209` + 3 `MilestoneStatus` entries matching `245-247` | File + unit test |
| 9 | `lib/systems/finance/services/escrow_service.dart` facade exposes `validateMilestoneSums` (tolerance 0.01), `releasedMilestoneTotal`, `completedMilestoneTotal`, `escrowWriteAvailable` | File + unit test |
| 10 | `escrowWriteViaProxyEnabled` flag exists in config, default `false` in all environments | File inspection |
| 11 | `lib/data/providers/escrow_provider.dart` exists — `ChangeNotifier` with `escrows/selected/milestones/transactionsByEscrowId/loadState/writeAvailable`, `loadForProject()`/`select()`/`refresh()`, `pausePolling`/`resumePolling`, `dispose` — mirrors `lib/data/providers/financial_provider.dart:49` | Unit test |
| 12 | `lib/systems/finance/screens/escrow_list_screen.dart` exists — `GET /finance/escrow`, escrow cards + empty state + pull-to-refresh, `AppTheme` tokens only, responsive | Widget test |
| 13 | `lib/systems/finance/screens/escrow_detail_screen.dart` exists — `GET /finance/escrow/:id`, header + dispute banner + `MilestoneListCard` + `EscrowWriteCtaPanel` + transaction summary | Widget test |
| 14 | `lib/systems/finance/widgets/escrow_status_badge.dart` / `milestone_list_card.dart` / `escrow_write_cta_panel.dart` / `escrow_dispute_banner.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`); disputed banner disables all actions | Widget test |
| 15 | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` barrels re-export new symbols | File inspection |
| 16 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `escrow='/finance/escrow'` + `escrowDetail='/finance/escrow/:id'` guarded by `RouteGuard` | File + `go_router` smoke |
| 17 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` |
| 18 | No `.supabase/functions/*` files created — proxy deploy deferred to EP-02-18 | `git status --porcelain .supabase/functions` empty |
| 19 | No `service_role` or secret leakage — `grep -r "service_role" lib/systems/finance lib/data/finance` = 0 | `grep` |
| 20 | No direct escrow write-RPC invocation from client — `grep -rn "supabase.rpc.*financial_escrow_\|financial_escrow_create\|financial_escrow_fund\|financial_escrow_release\|financial_escrow_refund\|financial_escrow_milestone_complete" lib/` = 0 | `grep` |
| 21 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0 | `grep` |
| 22 | `test/unit/data/finance/escrow_remote_data_source_test.dart` ≥12 cases green (RPC envelope, `PLT001/002/003/004/999`, write-seam guard both flag states) | `flutter test` |
| 23 | `test/unit/data/finance/escrow_repository_test.dart` ≥14 + `escrow_mapper_test.dart` ≥10 + `escrow_write_unavailable_test.dart` ≥4 green | `flutter test` |
| 24 | `test/unit/data/providers/escrow_provider_test.dart` ≥12 + `test/unit/systems/finance/escrow_service_test.dart` ≥10 green (sum invariant, status vocab, lifecycle) | `flutter test` |
| 25 | `test/widget/systems/finance/escrow_status_badge_test.dart` ≥9 + `milestone_list_card_test.dart` ≥8 + `escrow_detail_screen_test.dart` ≥12 + `escrow_list_screen_test.dart` ≥8 + `escrow_write_cta_panel_test.dart` ≥6 green, token + layout asserts | `flutter test` |
| 26 | `test/integration/finance/escrow_proxy_seam_test.dart` fake-E2E green: `getByProject → select → completeMilestone(flag off → guidance) → (flag on → proxy → re-read)` | `flutter test` |
| 27 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI |
| 28 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS/role regression | `supabase db test` |
| 29 | `flutter test` total ≥62 unit assertions green; `EscrowService` 100%, `EscrowProvider` ≥90%, mappers 100% | `flutter test` |

---

## Recommended Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Extremely High**

**Reasoning Level Justification:**

| Dimension | Assessment | Rationale |
|---|---|---|
| Technical complexity | High | Read-only `financial_escrow_get` wrapper + 3 entities/DTOs + mapper chain + `ChangeNotifier` provider mirror `FinancialProvider` — follows proven EP-02-13 patterns. Elevated by the **write-seam abstraction**: six write pathways behind a feature flag, `EscrowWriteUnavailableException` surface, and a stub proxy branch that must never silently route to a `service_role` RPC. The create-form milestone-sum invariant (`sum == total`, tolerance 0.01) adds client-side pre-validation correctness work beyond EP-02-13. |
| Business impact | Extremely High | Escrow IS the marketplace trust anchor (`EP-02:390-399`) — buyers hold all funds in escrow until milestone release. A client that renders a disputed escrow as actionable, or leaks `client_reference`/party identity, or pre-validates milestone sums wrong, breaks the entire buyer-provider payment trust model. Even a cosmetic status mislabel erodes the trust narrative. No money moves client-side, but escrow is where the marketplace's money credibility is earned. |
| Security risk | Extremely High | The five escrow write RPCs are `service_role`-only — any client code path that invokes them directly (or bypasses the proxy flag) is a design violation with `403 PLT002` catches in tests but catastrophic architectural trust if it slips through. `disputed` hold must render frozen (edge case: a released-milestone button on a frozen escrow would be a visible product-level breach of the dispute freeze). PII exposure via `client_reference`/party IDs requires disciplined redaction. Server is authoritative; client must be defensively correct. |
| Performance sensitivity | Medium | 1 RPC per select (`financial_escrow_get` STABLE + indexed), memoized list/detail state, `O(1)` flag reads at construction, fold-based milestone math — trivial. Notable only for lifecycle pause/resume (avoid polling on Nigerian 3G) and optical re-sync discipline (never optimistic UI after write). |
| Data complexity | High | Escrow aggregates three relational shapes (header, milestones with sum invariant, transaction envelope) from one RPC; milestone invariants must be upheld client-side for fast-fail UX while the server remains authority. Frozen schema: 7 escrow statuses `205-209`, 3 milestone statuses `245-247`, `numeric(18,2)` amounts — vocab must match exactly to avoid drift on the frozen migration. |
| Integration complexity | Extremely High | The **Edge Function proxy seam** (`financial-escrow-proxy`, EP-02-18) is a cross-task contract: this task defines the exact call-site shapes, flag semantics, and exception surface that EP-02-18 must satisfy. Read path depends on EP-02-04 frozen RPC + `FinancialEnvelopeParser`; write path depends on a function that does not exist yet — the flag-gated seam must be provably safe (grep lens) while remaining a pure config flip to activate. Couples with EP-02-05 dispute screen (banner routing) and EP-02-16 payout handoff (released milestone → receivable). |

Overall the task anchors marketplace trust with a **provably safe write seam** (`AGENT.md:16` Rule 4 server-authoritative, zero client `service_role`, static grep-lens enforcement) plus frozen-dispute render stability and exact status-vocab fidelity to the frozen migration — **Extremely High** reasoning ensures every write path is flag-guarded and grep-provable, the milestone-sum invariant is correct to the cent, the disputed display can never present an actionable release button, and the proxy seam contract handed to EP-02-18 is unambiguous.