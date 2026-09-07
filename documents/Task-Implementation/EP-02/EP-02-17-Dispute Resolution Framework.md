# Task Implementation Plan — EP-02-17: Dispute Resolution Framework

**Task ID:** EP-02-17 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Ready for Implementation | **Priority:** High | **Dependencies:** EP-02-05, EP-02-14, EP-02-08 | **Stage:** 5 — Financial Integrity Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:423-432` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:4-8,15-17` | Server Schema: `supabase/migrations/20260829120005_dispute_resolution_schema.sql` + `supabase/migrations/20260829120006_dispute_withdraw_definer.sql` (frozen) | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`, `go_router`) | Storage: `lib/core/storage/storage_service.dart`, `lib/core/storage/storage_paths.dart`, `lib/core/storage/storage_config.dart`

---

## 1. Objective

Build the client-side dispute resolution framework in `lib/systems/support/` that connects to the frozen server-side dispute infrastructure (EP-02-05): dispute filing linked to an escrow/transaction, evidence submission (documents, descriptions, screenshots), case status tracking, resolution display, and integration with escrow holds (disputed escrow is frozen — all actions disabled — until resolved). Build the complete data layer for `DisputeCase`, `DisputeEvidence`, and `DisputeResolution` entities, DTOs, repositories, and providers behind `SupabaseDisputeRemoteDataSource` — the client wrapper over the five client-callable RPCs (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`, `dispute_list`). Evidence uploads use the existing `credential-documents` private bucket via the EP-02-08 `StorageService` with a new `StoragePaths.disputeEvidence()` helper. The `service_role`-only `dispute_resolve` RPC is **never** invoked from client code.

Deliverables:
- Data layer: `DisputeCase`, `DisputeEvidence`, `DisputeResolution` entities + DTOs + mappers, `SupabaseDisputeRemoteDataSource` (5 RPC wrappers), `DisputeRepository`, `DisputeProvider` in `lib/data/`
- Orchestration: `DisputeService` facade in `lib/systems/support/`
- Storage: `StoragePaths.disputeEvidence()` addition for private-bucket evidence upload via existing `StorageService`
- UI: `DisputeListScreen`, `DisputeDetailScreen`, `DisputeFilingScreen`, `DisputeEvidenceFormScreen`, `DisputeStatusBadge`, `EvidenceAttachmentCard`, `EscrowFrozenBanner` in `lib/systems/support/screens/` + `lib/systems/support/widgets/`
- Routes: `/support/disputes` + `/support/disputes/new` + `/support/disputes/:id` (`lib/app/router/app_router.dart:17`)
- Barrel + DI: `lib/systems/support/support.dart` + `lib/data/data_layer.dart` re-exports
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `DisputeRepository`)

## 2. Business Problem Being Solved

`EP-02:423-432` mandates the **dispute resolution framework** as the safety net for marketplace trust. The server infrastructure exists and is frozen (`supabase/migrations/20260829120005_dispute_resolution_schema.sql`): 4 tables (`dispute_cases`, `dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail`), 6 RPCs, 2 SECURITY DEFINER escrow-hold helpers, party-scoped RLS, and pgTAP tests `015`/`016`. However **no client surface exists** — users cannot file or track disputes:

- No dispute filing flow — entities have no structured way to raise a formal dispute against a transaction/escrow from the app (`dispute_file` exists but is uncalled).
- No evidence submission — there is no UI or storage pipeline for documents, descriptions, or screenshots (`dispute_submit_evidence` exists but is uncalled; the `credential-documents` bucket from EP-02-08 exists and is unused for disputes).
- No case tracking — users cannot see dispute status (`open`/`under_review`/`resolved`/`closed`/`withdrawn`) or resolution outcome (`dispute_get`/`dispute_list` exist but are uncalled).
- No escrow-hold visibility — filing a dispute places an automatic escrow hold (`dispute_place_escrow_hold` transitions escrow to `disputed`); the client renders a disputed escrow as **frozen** (all milestone/refund actions disabled) — a client that lets the payer interact with a disputed milestone breaks the dispute freeze contract (EP-02-14 already renders the frozen banner; this task provides the dispute detail that banner routes to).
- No withdrawal path — a filer who resolves the matter informally cannot withdraw the dispute and release the hold (`dispute_withdraw` exists but is uncalled).

Without EP-02-17:

- Every dispute screen would call `supabase.rpc('dispute_file')`/`dispute_get` inline, duplicating envelope parsing and `ApiException` mapping — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:4-6` Separation of Concerns.
- No typed `DisputeCase`/`DisputeEvidence`/`DisputeResolution` entities — reason-length validation (10–2000), evidence-type vocabulary, and status vocabulary could not be pre-checked client-side, causing avoidable `PLT003` round-trips.
- No storage integration — evidence attachments could not reach the private `credential-documents` bucket via the existing validated `StorageService`.
- No `service_role` boundary — without a dedicated `SupabaseDisputeRemoteDataSource`, a future screen could accidentally invoke `dispute_resolve` (forbidden, `403 PLT002`) or leak the resolution path into client logic; the static grep lens would be unenforceable.

This task is the **Stage 5 client seam** that makes the dispute safety net actionable while keeping `dispute_resolve` strictly `service_role`-only.

## 3. Scope

| In Scope | Detail |
|---|---|
| `SupabaseDisputeRemoteDataSource` + abstract | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Wraps the **5 client-callable RPCs** via `supabase.rpc()`: `dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`, `dispute_list`. Envelope unwrap via `DisputeEnvelopeParser` (same `{success, code, message, data}` contract as `FinancialEnvelopeParser`). **Never** calls `dispute_resolve` (`service_role`-only) |
| Domain models | `DisputeCase` entity (`id, escrowId, filerEntityId, counterpartyEntityId, disputeType, status, reason, desiredOutcome?, priority, filedAt, resolvedAt?, closedAt?, withdrawnAt?, metadata`), `DisputeEvidence` entity (`id, caseId, submittedBy, evidenceType, title, description?, fileUrl?, fileMetadata, createdAt`), `DisputeResolution` entity (`id, caseId, resolvedBy?, resolutionType, reasoning, payerRefundAmount, payeeReleaseAmount, notes?, resolvedAt, createdAt`) — pure Dart, no DTO leakage |
| DTOs + mappers | `DisputeCaseDto`, `DisputeEvidenceDto`, `DisputeResolutionDto`, `DisputeListEnvelopeDto` — DTO layer in `lib/data/models/`; mapper extensions in `lib/data/mappers/dispute_mapper.dart` mapping DTOs → entities |
| `DisputeRepository` | `listDisputes({status})`, `getCase(id)`, `fileDispute(...)`, `submitEvidence(...)`, `withdrawDispute(id)` — orchestrates `SupabaseDisputeRemoteDataSource`, pre-validates client-side constraints (reason length, evidence type, title length), maps DTOs to entities |
| `DisputeService` facade (`lib/systems/support/`) | Thin wrapper over `DisputeRepository`. Exposes dispute status vocabulary (5 statuses + display labels/colors), dispute type vocabulary (5 types matching CHECK constraint), desired-outcome vocabulary (4 options + `other`), required-outcome labels, evidence-type vocabulary (4 types). Adds `HivorrLogger` redacted log (`caseId`, `entityId: ***last4`, `escrowId`) via `pii_redactor.dart` — never logs full reason/description/evidence title. Wraps `PerformanceTracer` span `support.dispute.get.duration` |
| `DisputeProvider` (`ChangeNotifier`) `lib/data/providers/dispute_provider.dart` | `List<DisputeCase> disputes`, `DisputeCase? selected`, `List<DisputeEvidence> evidence`, `DisputeResolution? resolution`, `AsyncState loadState`, `ApiException? lastError`. `loadList({status})`, `select(id)`, `file(...)`, `submitEvidence(...)`, `withdraw(id)`, `refresh()`. Mirrors `EscrowProvider` pattern (`lib/data/providers/escrow_provider.dart`) with `WidgetsBindingObserver` lifecycle |
| Storage integration | `StoragePaths.disputeEvidence(caseId, fileName)` helper added to `lib/core/storage/storage_paths.dart` — routes evidence attachments to the existing `credential-documents` private bucket (max 10 MiB, `jpeg/png/webp/pdf` per `storage_config.dart`) via the existing `StorageService.upload()`; signed-URL preview via `StorageService.createSignedUrl()` (private bucket — no public-URL path) |
| UI screens + widgets | `DisputeListScreen` (`GET /support/disputes`), `DisputeDetailScreen` (`GET /support/disputes/:id`) with resolution display + evidence list + withdraw action (filer, open status only), `DisputeFilingScreen` (`GET /support/disputes/new`) with escrow context + reason/type/priority/desired-outcome fields, `DisputeEvidenceFormScreen` with attachment upload — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Barrel + DI | `lib/systems/support/support.dart` (new barrel) + `lib/data/data_layer.dart` re-exports; factory `DisputeProvider.create(supabase: SupabaseClientProvider.client)`; `EscrowFrozenBanner` receives dispute routing from EP-02-14 `EscrowDetailScreen` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation or modification | EP-02-05 frozen (`20260829120005` + `20260829120006`); this task is `lib/` only. `git diff --stat supabase/` must be `0` |
| Calling or wrapping `dispute_resolve` from the client | `service_role`-only (EXECUTE granted to `service_role` only, `20260829120005:874`). Resolution is an admin decision executed server-side. No `service_role` string anywhere in `lib/` |
| Admin dispute review interface / resolution decision UI | `service_role`-only RPC; the client only **displays** resolution outcomes returned by `dispute_get`. Future admin tooling |
| Edge Function for dispute notifications or `service_role` proxy | Future task |
| Modifying `dispute_withdraw` execution model | Server-side already approved as SECURITY DEFINER (`20260829120006_dispute_withdraw_definer.sql`); the client just calls it via `supabase.rpc('dispute_withdraw')` |
| Creating a new storage bucket | Evidence uploads reuse the existing `credential-documents` private bucket (`storage_config.dart:16`); zero bucket config changes |
| Modifying `StorageService`, `StorageConfig`, or `StorageValidators` | Reused as-is from EP-02-08; only `StoragePaths.disputeEvidence()` is added |
| Dispute escrow hold / release logic | Fully server-side in the SECURITY DEFINER helpers `dispute_place_escrow_hold`/`dispute_release_escrow_hold`; the client only renders frozen state via `EscrowFrozenBanner` |
| Payment/balance movements on resolution | Inline in `dispute_resolve` (double-entry `financial_transactions` + `financial_balances`); client displays outcome amounts read-only |
| Appeal or escalation workflow, SLA timers, auto-escalation | Future task |
| Any hardcoded business logic in UI components | All vocabulary/validation via `DisputeService`/`DisputeRepository` |
| Creating any files outside `lib/` and `documents/Task-Implementation/EP-02/` | Scope boundary |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/support/` vs `lib/data/`

`ARCHITECTURE.md:55-60,101-110,131-138` assigns `lib/core/` = platform, `lib/data/` = DTO/entity/repository/provider, `lib/systems/support/` = support business system. The dispute framework follows the exact pattern of EP-02-14 (`lib/systems/finance/`): the **data layer** owns RPC transport + DTOs + mappers + repositories + providers (reusable), the **systems layer** owns dispute vocabulary, status logic, and UX orchestration. `lib/systems/support/` is currently empty (`.gitkeep` only) — this task populates it as a new first-class system barrel. Data-layer files go in `lib/data/` alongside the existing escrow/financial modules.

No new top-level `lib/` directory. No `.supabase/functions/` directory created. No `supabase/migrations/*` change.

### 5.2 Server-Side Contract (Frozen — Read-Only Reference)

The server contract is **inherited from EP-02-05 and must be referenced, never modified**:

**Tables** (`supabase/migrations/20260829120005_dispute_resolution_schema.sql`):
- `dispute_cases` (`54-101`) — `escrow_id` FK, `filer_entity_id`, `counterparty_entity_id`, `dispute_type` CHECK (`service_quality|non_delivery|milestone_disagreement|fraud|other`) `62-65`, `status` CHECK (`open|under_review|resolved|closed|withdrawn`) `66-68`, `reason` CHECK (10–2000 chars) `69-70`, `desired_outcome` CHECK (`release_to_payee|refund_to_payer|split|other`, nullable) `71-73`, `priority` CHECK (`low|medium|high|critical`) `74-75`, timestamps, `metadata jsonb`.
- `dispute_evidence` (`106-122`) — immutable. `case_id` FK CASCADE, `submitted_by` FK, `evidence_type` CHECK (`document|screenshot|description|photo`) `112-113`, `title` CHECK (1–255) `114-115`, `description` ≤2000 `116-117`, `file_url`, `file_metadata jsonb`.
- `dispute_resolutions` (`135-152`) — immutable. `case_id` unique FK RESTRICT, `resolved_by` FK SET NULL, `resolution_type` CHECK (`release_to_payee|refund_to_payer|split|dismissed`) `141-143`, `reasoning` CHECK (10–5000) `144-145`, `payer_refund_amount`/`payee_release_amount` ≥0 `146-147`.
- `dispute_audit_trail` (`163-184`) — append-only. `event_type` CHECK (11 vocabulary values) `169-174`, `subject_type` CHECK `175-177`.

**Client-callable RPCs** (`authenticated` + `service_role` EXECUTE grants `867-871`):
| RPC | Params | Returns (envelope) |
|---|---|---|
| `dispute_file` (`382-473`, INVOKER) | `p_escrow_id uuid, p_dispute_type text, p_reason text, p_desired_outcome text default null, p_priority text default 'medium'` | `{success, code, message, data: dispute_case}` — places escrow hold via DEFINER helper |
| `dispute_submit_evidence` (`476-545`, INVOKER) | `p_case_id uuid, p_evidence_type text, p_title text, p_description text default null, p_file_url text default null, p_file_metadata jsonb default '{}'` | `{success, code, message, data: dispute_evidence}` |
| `dispute_withdraw` (`20260829120006`, **SECURITY DEFINER**) | `p_case_id uuid` | `{success, code, message, data: dispute_case}` — releases escrow hold |
| `dispute_get` (`786-827`, INVOKER, STABLE) | `p_case_id uuid` | `{success, code, message, data: {case, evidence: [...], resolution: {...}\|null}}` |
| `dispute_list` (`830-859`, INVOKER, STABLE) | `p_status text default null` | `{success, code, message, data: {disputes: [...]}}` |

**Prohibited from client** (`service_role`-only, `874`):
- `dispute_resolve(uuid, text, text, numeric, numeric, text)` — never called, never wrapped, never referenced as a client path.

**Envelope contract:** all RPCs return `{success, code, message, data}`; `PLT000` success, `PLT001` auth, `PLT003` validation, `PLT004` not found, `PLT005` conflict, `PLT999` internal. Client unwraps via `DisputeEnvelopeParser`.

### 5.3 Data Layer Contract

```dart
// lib/data/datasources/remote/dispute_remote_data_source.dart
abstract class DisputeRemoteDataSource {
  Future<DisputeListEnvelopeDto> listDisputes({String? status});
  Future<DisputeCaseDetailEnvelopeDto> getCase(String caseId);
  Future<DisputeCaseDto> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });
  Future<DisputeEvidenceDto> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const {},
  });
  Future<DisputeCaseDto> withdrawDispute(String caseId);
}
```

```dart
// lib/data/entities/dispute_case.dart
class DisputeCase {
  final String id;
  final String escrowId;
  final String filerEntityId;
  final String counterpartyEntityId;
  final String disputeType;   // service_quality|non_delivery|milestone_disagreement|fraud|other
  final String status;        // open|under_review|resolved|closed|withdrawn
  final String reason;
  final String? desiredOutcome;
  final String priority;      // low|medium|high|critical
  final DateTime filedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime? withdrawnAt;
  final Map<String, dynamic> metadata;
}
```

```dart
// lib/data/entities/dispute_evidence.dart
class DisputeEvidence {
  final String id;
  final String caseId;
  final String submittedBy;
  final String evidenceType;  // document|screenshot|description|photo
  final String title;
  final String? description;
  final String? fileUrl;
  final Map<String, dynamic> fileMetadata;
  final DateTime createdAt;
}
```

```dart
// lib/data/entities/dispute_resolution.dart
class DisputeResolution {
  final String id;
  final String caseId;
  final String? resolvedBy;
  final String resolutionType; // release_to_payee|refund_to_payer|split|dismissed
  final String reasoning;
  final double payerRefundAmount;
  final double payeeReleaseAmount;
  final String? notes;
  final DateTime resolvedAt;
  final DateTime createdAt;
}
```

- Implementation `SupabaseDisputeRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`.
- All RPC methods invoke `supabase.rpc<Map<String,dynamic>>('dispute_<fn>', params: {...})`, then unwrap the envelope via `DisputeEnvelopeParser` (checks `data['success']==true && data['code']=='PLT000'`, else throws `ApiException` with extracted `code/message`).
- `dispute_withdraw` is `SECURITY DEFINER` server-side — the client calls it exactly like the other entity-facing RPCs via `supabase.rpc('dispute_withdraw', params: {p_case_id: ...})`; no special handling required, filer-scoping is enforced inside the function body.
- `DisputeRemoteDataSource` **declares no `dispute_resolve` method** — the `service_role`-only RPC is absent from the entire client contract. Static grep lens proves it.

### 5.4 Repository — `DisputeRepository` (the unit-tested business contract)

```dart
// lib/data/repositories/dispute_repository.dart
abstract class DisputeRepository {
  Future<List<DisputeCase>> listDisputes({String? status});
  Future<DisputeCaseDetail> getCase(String caseId); // case + evidence + resolution?
  Future<DisputeCase> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });
  Future<DisputeEvidence> submitEvidence({required String caseId,
    required String evidenceType, required String title,
    String? description, String? fileUrl, Map<String, dynamic> fileMetadata});
  Future<DisputeCase> withdrawDispute(String caseId);
}
```

`DisputeRepositoryImpl` (`lib/data/repositories/dispute_repository_impl.dart`):

1. `listDisputes({status})` → `remote.listDisputes` → map each DTO via `DisputeMapper.disputeListToEntities` → validate status fixture client-side before RPC (only if a non-null status provided, else no filter passed).
2. `getCase(id)` → `remote.getCase` → `DisputeMapper.caseDetailToEntity` (case + ordered evidence list + optional resolution) → `DisputeCaseDetail` value object.
3. `fileDispute(...)` — **client pre-validates** reason length (10–2000 after trim), dispute type + desired outcome + priority against the frozen CHECK vocabularies, escrow id non-null — before the RPC round-trip (prevents known `PLT003` violations). On success re-reads `getCase` for the authoritative envelope.
4. `submitEvidence(...)` — pre-validates evidence type (4-value vocab), title length (1–255), description ≤2000, optional `file_url` (already uploaded to `credential-documents` before this call). Evidence row is immutable server-side — no edit/delete pathways.
5. `withdrawDispute(id)` → `remote.withdrawDispute` → maps updated case. UI only offers withdrawal when `status == 'open'` and caller is filer.

Repository **never imports** `lib/systems/` widgets — unidirectional `data → systems`.

### 5.5 Systems Facade — `DisputeService` (`lib/systems/support/services/`)

Thin wrapper used by `DisputeProvider` (ChangeNotifier) and consumers:

- Exposes dispute status vocabulary (data-driven, matches `dispute_cases` CHECK `66-68`):
  ```dart
  const disputeStatuses = [
    DisputeStatus(code: 'open', label: 'Open', tone: 'warning'),
    DisputeStatus(code: 'under_review', label: 'Under review', tone: 'info'),
    DisputeStatus(code: 'resolved', label: 'Resolved', tone: 'success'),
    DisputeStatus(code: 'closed', label: 'Closed', tone: 'neutral'),
    DisputeStatus(code: 'withdrawn', label: 'Withdrawn', tone: 'neutral'),
  ];
  ```
- Exposes dispute type vocabulary (matches CHECK `62-65`): `service_quality` → "Service quality", `non_delivery` → "Non-delivery", `milestone_disagreement` → "Milestone disagreement", `fraud` → "Fraud", `other` → "Other".
- Exposes desired-outcome vocabulary (matches CHECK `71-73`): `release_to_payee` → "Release to provider", `refund_to_payer` → "Refund to me", `split` → "Split the amount", `other` → "Other".
- Exposes priority vocabulary (matches CHECK `74-75`): `low`, `medium`, `high`, `critical`.
- Exposes evidence-type vocabulary (matches CHECK `112-113`): `document`, `screenshot`, `description`, `photo`.
- Exposes resolution-type vocabulary (matches CHECK `141-143`): `release_to_payee`, `refund_to_payer`, `split`, `dismissed` with outcome labels.
- `bool validateReason(String reason)` — 10–2000 chars after trim (matches server `69-70`); `bool validateTitle(String title)` — 1–255; `bool validateDescription(String description)` — ≤2000.
- Delegates to `DisputeRepository`; adds `HivorrLogger` + `PiiRedactor` redacted log (`caseId`, `escrowId`, `entityId: ***last4`, dispute type, status deltas) — never full `reason`, `description`, or evidence `title`.
- `PerformanceTracer` spans `support.dispute.get.duration`, `support.dispute.list.duration`, `support.dispute.file.duration` (`lib/core/monitoring/performance_tracer.dart`).

### 5.6 State — `DisputeProvider` (`lib/data/providers/`)

```dart
class DisputeProvider extends ChangeNotifier {
  List<DisputeCase> disputes;
  DisputeCase? selected;
  List<DisputeEvidence> evidence;
  DisputeResolution? resolution;
  AsyncState loadState;
  ApiException? lastError;
  bool isRefreshing;

  Future<void> loadList({String? status});
  Future<void> select(String caseId); // case + evidence + resolution via dispute_get
  Future<DisputeCase> file({required String escrowId, required String disputeType,
    required String reason, String? desiredOutcome, String priority = 'medium'});
  Future<DisputeEvidence> submitEvidence({...});
  Future<DisputeCase> withdraw(String caseId);
  Future<void> refresh();
}
```

- Constructor injection `({required DisputeRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability.
- Mirrors `EscrowProvider` pattern (`lib/data/providers/escrow_provider.dart`) — `WidgetsBindingObserver` lifecycle, `pausePolling`/`resumePolling` via `didChangeAppLifecycleState`, `NotificationProvider` on file/withdraw success.
- `loadList` maps dispute list; `select` loads case + evidence + resolution in one `dispute_get` RPC. 1 RPC per screen visit, memoized per case id.
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.7 UI — `lib/systems/support/screens/` + `widgets/`

- `DisputeListScreen` (`GET /support/disputes`):
  1. Dispute cards per case — `DisputeStatusBadge` + dispute type label + counterparty initials (never full name) + filed date (`BalanceFormatter`-style date formatting, not amount).
  2. Status filter chips (All / Open / Under review / Resolved / Withdrawn).
  3. Empty state `HivorrEmptyState` — "No disputes yet — raise one from an escrow's dispute action."
  4. FAB / primary action → `DisputeFilingScreen` (`GET /support/disputes/new`).
  5. Pull-to-refresh (`HivorrLoader` breathing pulse), not bare `CircularProgressIndicator` (`VISUAL-IDENTITY.md:148`).
- `DisputeDetailScreen` (`GET /support/disputes/:id`):
  1. Header — `DisputeStatusBadge` + dispute type + priority chip + filed date.
  2. Case context — linked escrow summary (escrow id suffix `***`, amount via `BalanceFormatter`, `EscrowStatus` from EP-02-14 vocabulary) with "View escrow" action routing to EP-02-14 `/finance/escrow/:id`; `EscrowFrozenBanner` variant when escrow is `disputed`.
  3. Dispute details — reason (full text, read-only), desired outcome, priority, `metadata` summary.
  4. Evidence section — `EvidenceAttachmentCard` per evidence item (type icon, title, description, attachment thumb/preview + download via signed URL); "Add evidence" action when `status in ('open','under_review')` → `DisputeEvidenceFormScreen`.
  5. Resolution section — only when resolution present: `DisputeStatusBadge` (resolved) + `resolution_type` label + reasoning (full text) + outcome amounts (`₦/₵/$/£` via `BalanceFormatter`): payer refund / payee release.
  6. Withdraw action — only enabled when `status == 'open'` AND caller is filer; confirmation dialog; on success navigates to list with refreshed state.
  7. Audit awareness — note that evidence and resolutions are immutable.
- `DisputeFilingScreen` (`GET /support/disputes/new`):
  1. Escrow context — pre-selected escrow (from EP-02-14 `EscrowProvider.select` or a picked escrow from the list), read-only escrow header (status, total, currency via `BalanceFormatter`), "raise dispute against this escrow" framing.
  2. Fields exactly matching `dispute_file` params: dispute type selector (5-value vocab), reason text area (10–2000, live counter + `DisputeService.validateReason`), desired outcome selector (4 options + other / optional, matching nullable `desired_outcome`), priority selector (default medium).
  3. Submit → `DisputeProvider.file(...)` → success routes to `DisputeDetailScreen` (escrow now `disputed` — server hold).
  4. Mirror-client warning when escrow already `disputed`: server blocks with `PLT005` (partial unique index on active dispute per escrow); UI surfaces "An active dispute already exists for this escrow."
- `DisputeEvidenceFormScreen`:
  1. Evidence type selector (4-value vocab), title (1–255), description (≤2000, optional).
  2. Attachment picker for `document`/`screenshot`/`photo` — validates against `StorageConfig` (10 MiB, `jpeg/png/webp/pdf`), uploads to `credential-documents` via `StorageService.upload(StoragePaths.disputeEvidence(caseId, fileName))` BEFORE calling `dispute_submit_evidence`; `description` type uses no attachment.
  3. On upload success → `DisputeProvider.submitEvidence(...)` with `fileUrl` from upload result + `fileMetadata {mimeType, sizeBytes, originalName}`.
- `DisputeStatusBadge` — pure widget: color map per 5 statuses using `colorScheme.*` (open `warningContainer`, under_review `primaryContainer`, resolved `successContainer`, closed `surfaceVariant`, withdrawn `surfaceVariant`). No hardcoded hex.
- `EvidenceAttachmentCard` — pure widget: type icon + title + description + attachment preview. Optional signed-URL preview for `document`/`screenshot`/`photo` via `StorageService.createSignedUrl` (private bucket).
- `EscrowFrozenBanner` — pure widget: `Container` `colorScheme.errorContainer`, `Icons.gavel`, "This escrow is in dispute — all actions are frozen until resolved", "View dispute" action routing to `/support/disputes/:id`. Reused by EP-02-14 `EscrowDetailScreen` (which already renders its frozen-dispute state; this task provides the dispute detail route target).

Responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

### 5.8 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.disputes = '/support/disputes'`, `disputesNew = '/support/disputes/new'`, `disputeDetail = '/support/disputes/:id'` and matching `RouteNames`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required; no taxonomy gate. Detail route reads `:id` param → `DisputeProvider.select(id)`. Filing route may receive `escrowId` query param for pre-selection from EP-02-14. No SEO public URL (private support flow).

### 5.9 Config & Logging

- No new feature flags required (all 5 RPCs are `authenticated`-callable and live; no write-seam staging — unlike EP-02-14 escrow writes).
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server`. `SupabaseDisputeRemoteDataSource` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `caseId`, `escrowId`, `entityId suffix`, dispute type, status delta; never full `reason`, `description`, evidence `title`, or counterparty full identity.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `DisputeRemoteDataSource` abstract | `lib/data/datasources/remote/dispute_remote_data_source.dart` | **Create** — §5.3 |
| `SupabaseDisputeRemoteDataSource` | `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.3 (5 RPC wrappers; no `dispute_resolve`) |
| `DisputeEnvelopeParser` | `lib/data/datasources/remote/dispute_envelope_parser.dart` | **Create** — `{success, code, message, data}` unwrap (same shape as `FinancialEnvelopeParser`) |
| `DisputeCase` entity | `lib/data/entities/dispute_case.dart` | **Create** — §5.3 |
| `DisputeEvidence` entity | `lib/data/entities/dispute_evidence.dart` | **Create** — §5.3 |
| `DisputeResolution` entity | `lib/data/entities/dispute_resolution.dart` | **Create** — §5.3 |
| `DisputeCaseDetail` value object | `lib/data/models/dispute_case_detail.dart` | **Create** — §5.4 compound |
| DTOs | `lib/data/models/dispute_case_dto.dart`, `dispute_evidence_dto.dart`, `dispute_resolution_dto.dart`, `dispute_list_envelope_dto.dart`, `dispute_case_detail_envelope_dto.dart` | **Create** — §5.3 |
| Mappers | `lib/data/mappers/dispute_mapper.dart` | **Create** — `caseToEntity`, `evidenceToEntity`, `resolutionToEntity`, `listEnvelopeToEntities`, `caseDetailToEntity` |
| `DisputeRepository` abstract + impl | `lib/data/repositories/dispute_repository.dart` + `dispute_repository_impl.dart` | **Create** — §5.4 |
| `DisputeProvider` (ChangeNotifier) | `lib/data/providers/dispute_provider.dart` | **Create** — §5.6 |
| `DisputeService` facade | `lib/systems/support/services/dispute_service.dart` | **Create** — §5.5 |
| `DisputeStatus` / vocab models | `lib/systems/support/models/dispute_status.dart` | **Create** — §5.5 statuses + types + priorities + outcomes + evidence types |
| Screens | `lib/systems/support/screens/dispute_list_screen.dart`, `dispute_detail_screen.dart`, `dispute_filing_screen.dart`, `dispute_evidence_form_screen.dart` | **Create** — §5.7 |
| Widgets | `lib/systems/support/widgets/dispute_status_badge.dart`, `evidence_attachment_card.dart`, `escrow_frozen_banner.dart` | **Create** — §5.7 |
| Barrel | `lib/systems/support/support.dart` (new) + `lib/data/data_layer.dart` | **Create/Update** — re-exports |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 3 routes, guard via `RouteGuard` |
| `StoragePaths.disputeEvidence` | `lib/core/storage/storage_paths.dart` | **Update** — add helper (§5.7) |
| `StorageService` reuse | `lib/core/storage/supabase_storage_service.dart` | **Reuse** — upload + createSignedUrl private bucket, `StorageConfig` limits |
| `BalanceFormatter` reuse | `lib/systems/finance/helpers/balance_formatter.dart` (EP-02-13/14) | **Reuse** — format escrow amounts on detail/filing screens |
| `EscrowProvider` reuse | `lib/data/providers/escrow_provider.dart` (EP-02-14) | **Reuse** — escrow context for filing screen + "View escrow" routing |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `.supabase/functions/*` | `.supabase/functions/` | **No change** |
| Tests + fakes | `test/unit/data/dispute_*`, `test/unit/systems/support/dispute_*`, `test/widget/systems/support/dispute_*`, `test/support/fakes/fake_dispute_remote_data_source.dart` | **Create** — §14 |

No new tables, no RPCs, no Edge Function files, no storage buckets.

## 7. Data Requirements

### 7.1 Dispute Case (via `dispute_file`, `dispute_get`, `dispute_list`, `dispute_withdraw`)

`dispute_cases` (`54-101`): `id`, `escrow_id`, `filer_entity_id`, `counterparty_entity_id`, `dispute_type` (5-value CHECK), `status` (5-value CHECK), `reason` (10–2000), `desired_outcome` (nullable 4-value CHECK), `priority` (4-value CHECK), `filed_at/resolved_at/closed_at/withdrawn_at`, `metadata jsonb`, `created_by auth.uid()`. Client reads via `dispute_get`/`dispute_list` (party-scoped RLS) and writes via `dispute_file`/`dispute_withdraw` (RPCs are the only write path; `authenticated` has no UPDATE on status columns — `status`/`resolved_at`/`closed_at`/`withdrawn_at` are server-controlled).

### 7.2 Dispute Evidence (via `dispute_submit_evidence`, `dispute_get`)

`dispute_evidence` (`106-122`): `id`, `case_id` FK CASCADE, `submitted_by`, `evidence_type` (4-value CHECK), `title` (1–255), `description` (≤2000, nullable), `file_url` (nullable — Supabase Storage URL in `credential-documents`), `file_metadata jsonb`, `created_at`. **Immutable** — no UPDATE/DELETE grants to any client role; client never edits or deletes evidence.

### 7.3 Dispute Resolution (via `dispute_get` only)

`dispute_resolutions` (`135-152`): `id`, `case_id` unique, `resolved_by` (nullable), `resolution_type` (4-value CHECK), `reasoning` (10–5000), `payer_refund_amount`/`payee_release_amount` (≥0), `notes`, `resolved_at`, `created_at`. **Immutable**; INSERT only by `service_role` via `dispute_resolve`. Client renders read-only.

### 7.4 Audit Trail (read-only awareness)

`dispute_audit_trail` (`163-184`) — append-only, party-scoped SELECT. The client does not surface the audit trail in MVP screens (scope boundary); it is fully server-written.

### 7.5 Evidence Storage (existing bucket, new path helper)

| Element | Detail |
|---|---|
| Bucket | `credential-documents` (existing, private — `storage_config.dart:16`) |
| Path helper | `StoragePaths.disputeEvidence(String caseId, String fileName)` → `<caseId>/<sanitized fileName>` within the credential-documents namespace (exact prefix determined at build time from `storage_paths.dart:11` conventions) |
| Limits | 10 MiB; `jpeg`, `png`, `webp`, `pdf` (`storage_config.dart:36,58`) |
| Upload | `StorageService.upload` (existing) |
| Preview | `StorageService.createSignedUrl` (private bucket only — public-URL path throws, `storage_service.dart:53`) |
| Flow | pick & validate → upload → `dispute_submit_evidence(p_file_url: <path>, p_file_metadata: {mimeType, sizeBytes, originalName})` |

## 8. Database Considerations

- **Zero DDL in this task.** All 4 tables, RLS, grants, triggers, indexes, and functions exist and are frozen (`20260829120005` + `20260829120006`). No `ALTER`, `CREATE POLICY`, `GRANT`, index, trigger, or function added. `git diff --stat supabase/` = 0.
- **RLS posture inherited:** all 4 tables default-deny (`205-216`); party-scoped SELECT policies (`241-276`); `authenticated` INSERT limited to allowed columns; `dispute_cases.status/resolved_at/closed_at/withdrawn_at` NOT writable by `authenticated` (server-controlled); evidence/resolutions/audit **immutable** (no UPDATE/DELETE to any client role).
- **Write paths are RPC-only by construction:** `dispute_file`/`dispute_submit_evidence`/`dispute_withdraw` are the only client write RPCs (EXECUTE granted `authenticated`, `867-871`). The client never issues REST/table DML on the 4 tables. `grep -rn "supabase.rpc.*dispute_resolve\|dispute_resolve" lib/` must be `0`.
- **`dispute_resolve` boundary is absolute:** granted `service_role` only (`874`). The client contract `DisputeRemoteDataSource` declares no resolve method; no `service_role` string anywhere in `lib/`.
- **Escrow hold is server-authoritative:** `dispute_file` → `dispute_place_escrow_hold` (SECURITY DEFINER) transitions escrow `funded/partially_released → disputed`; `dispute_withdraw`/`dismissed` → `dispute_release_escrow_hold` transitions `disputed → funded`. The client renders frozen state (`EscrowFrozenBanner`), never performs or claims the state change — defense-in-depth, not enforcement.
- **One active dispute per escrow** enforced by partial unique index `dispute_cases_one_open_per_escrow_idx` (`99-101`); client surfaces `PLT005` conflict message as "An active dispute already exists for this escrow."
- **Reason/type/priority vocab fidelity:** client vocabulary and validators must match the frozen CHECK constraints exactly (`62-75`, `112-117`, `141-147`) to avoid avoidable `PLT003` round-trips; the server remains the single authority.
- **Full pgTAP suite stays green:** `015` dispute posture + `016` dispute RPC enforcement + full `001-017` regression (EP-02-14 ran through `017`); no client change can affect server tests — verified via `supabase db test` as regression gate.

## 9. API Requirements

### 9.1 Supabase RPC — Client-Callable (all live)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| File dispute | `dispute_file` (`382`) | `p_escrow_id, p_dispute_type, p_reason, p_desired_outcome, p_priority` | `authenticated` self-scoped (party) | `200 {success:true, code:PLT000, data:{...dispute_case}}`; escrow → `disputed` | `401 PLT001`, `403 PLT002`, `400/422 PLT003` (validation), `404 PLT004`, `409 PLT005` (duplicate active) |
| Submit evidence | `dispute_submit_evidence` (`476`) | `p_case_id, p_evidence_type, p_title, p_description, p_file_url, p_file_metadata` | `authenticated` (party, case `open`/`under_review`) | `200 {success:true, code:PLT000, data:{...dispute_evidence}}` | `401`, `403`, `400/422 PLT003`, `404 PLT004`, `409 PLT005` (evidence on closed case) |
| Withdraw dispute | `dispute_withdraw` (`20260829120006`) | `p_case_id` | `authenticated` (filer only, `open` only); runs SECURITY DEFINER | `200 {success:true, code:PLT000, data:{...dispute_case}}`; escrow → `funded` | `401`, `400/422 PLT003` (non-filer), `409 PLT005` (not open) |
| Get case detail | `dispute_get` (`786`) | `p_case_id` | `authenticated` (party), STABLE | `200 {success:true, code:PLT000, data:{case:{...}, evidence:[...], resolution:{...}\|null}}` | `401`, `404 PLT004` (non-party or missing) |
| List disputes | `dispute_list` (`830`) | `p_status<optional>` | `authenticated` (party), STABLE | `200 {success:true, code:PLT000, data:{disputes:[...]}}` | `401`, `400/422 PLT003` (invalid filter) |

### 9.2 Prohibited RPC — Never Called From Client

| RPC | Grant | Client rule |
|---|---|---|
| `dispute_resolve(uuid, text, text, numeric, numeric, text)` | `service_role` only (`874`) | Absent from `DisputeRemoteDataSource`/`DisputeRepository`/`DisputeService`; no `supabase.rpc('dispute_resolve')` anywhere; grep lens `grep -rn "dispute_resolve" lib/` = 0 |

### 9.3 Storage API (existing)

`StorageService.upload(bucket: 'credential-documents', path: StoragePaths.disputeEvidence(caseId, file), file: ...)` + `StorageService.createSignedUrl(bucket, path)` for preview. No new bucket; no public-URL path for evidence.

### 9.4 Error Contract

Every public method throws only `ApiException` (`api_exception.dart` kinds) or `DataException` — never raw `Supabase`/`DioException`. `BaseApiService.invoke` normalizes `DioException` via `ApiExceptionMapper.map`. Distinct UX per kind: `PLT003` → inline field errors; `PLT004` → not-found state with back navigation; `PLT005` → conflict banner ("An active dispute already exists for this escrow." / "This dispute cannot be modified in its current state."); network → retry state.

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies.** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`, `lib/app/theme/app_theme_extension.dart`) — never `Colors.*` or `Color(0xFF...)` inline.
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')` (delegated to `lib/app/theme/app_text_theme.dart`).
- Source spacing/radius/elevation/motion via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation`/`duration` (`VISUAL-IDENTITY.md:219-235`) — 8pt grid, cards 16dp.
- Handle 4 states via branded primitives (`lib/shared/widgets/hivorr_empty_state.dart`, `hivorr_loading_state.dart`, `hivorr_error_state.dart`, `hivorr_success_state.dart`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `DisputeListScreen` | `GET /support/disputes` | Dispute list with status filter | `AppBar(title: Text('Disputes', style: textTheme.titleLarge))`, status filter chips, dispute cards (status badge + type + counterparty initials + date), `FilledButton.icon` FAB "File dispute", pull-to-refresh, `HivorrEmptyState` ("No disputes yet") |
| `DisputeDetailScreen` | `GET /support/disputes/:id` | Case detail + evidence + resolution | Header (status badge + type + priority + date), escrow context card (+ "View escrow" → EP-02-14 route, `EscrowFrozenBanner` when disputed), reason block, evidence list (`EvidenceAttachmentCard`), "Add evidence" when `open`/`under_review`, resolution panel when present (type + reasoning + outcome amounts via `BalanceFormatter`), withdraw action (open + filer) |
| `DisputeFilingScreen` | `GET /support/disputes/new` | File dispute against escrow | Escrow context header (read-only), type selector, reason `TextField(maxLines: 6)` + live counter (10–2000), desired-outcome selector (optional), priority selector (default medium), submit `FilledButton` with loading state |
| `DisputeEvidenceFormScreen` | (modal/subroute) | Submit evidence + attachment | Evidence-type selector, title field (1–255 counter), description field (≤2000, optional), attachment picker (MIME/size validated, preview before submit), submit disabled until title valid |
| `DisputeStatusBadge` | — | 5-status chip | `Container(decoration: BoxDecoration(color: <status tone color>, borderRadius: BorderRadius.circular(ext.radiusSm)))`, label from `DisputeStatus` vocab, no hex |
| `EvidenceAttachmentCard` | — | Evidence display | Type icon (`Icons.description`/`Icons.screenshot_monitor`/`Icons.text_snippet`/`Icons.photo_camera`), title (`textTheme.bodyMedium`), description, attachment chip (name/size) + signed-URL preview action |
| `EscrowFrozenBanner` | — | Frozen disputed state | `Container` `colorScheme.errorContainer`, `Icons.gavel`, "This escrow is in dispute — all actions are frozen until resolved", "View dispute" → `/support/disputes/:id` |

Amounts always rendered with `BalanceFormatter` (`₦/₵/$/£`, EP-02-13/14) — never raw `double.toString()`. Party identity always entity-id suffix initials (`***1234`) or "Filer"/"Counterparty" labels — no full legal names on screen.

## 11. User Experience Considerations

- **Escrow-first filing:** A dispute is always filed against a specific escrow (server requires `escrow_id`). The filing flow is entered from the escrow context (EP-02-14 detail screen "Raise dispute" or the dispute list FAB with escrow picker) so the user never types an escrow id manually.
- **Immediate hold confirmation:** After successful filing, the detail screen explicitly confirms the escrow hold — "This escrow is now frozen pending resolution" — and the linked escrow renders `disputed` accordingly.
- **Frozen UX is absolute:** `disputed` escrows disallow all dispute-evidence-eligible state changes only where the server blocks them (evidence only on `open`/`under_review`, withdraw only on `open` + filer). Buttons are hidden, not disabled-without-explanation; the banner explains why.
- **Progressive disclosure:** List shows cards, not walls; detail reveals evidence then resolution in sections; resolution reasoning is shown in full (read-only, transparent).
- **Fail-fast validation:** Reason (10–2000), title (1–255), description (≤2000), evidence MIME/size validated client-side with live counters before any RPC — no round-trip for known `PLT003` violations.
- **Evidence upload is staged and non-blocking:** attachment uploads happen before the evidence RPC; a failed upload surfaces a retry without losing the typed title/description.
- **Withdrawal is a deliberate act:** confirmation dialog with explicit copy — "Withdrawing releases the escrow hold and closes this dispute. This cannot be undone."
- **Transparency of immutability:** submission surfaces read-only copy/state clearly; the user understands evidence and resolutions cannot be edited or deleted.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative dispute state** `AGENT.md:16` Rule 4 | Client never writes the 4 dispute tables via REST or direct SQL; all writes flow through the 3 client RPCs (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`). Status columns (`status`, `resolved_at`, `closed_at`, `withdrawn_at`) are server-controlled; withdrawal flips status server-side via SECURITY DEFINER `dispute_withdraw` with filer-scoping in the body. |
| **`service_role` boundary absolute** | `dispute_resolve` is absent from the client contract. No `service_role` string anywhere in `lib/`: `grep -r "service_role" lib/` = 0. No `supabase.rpc('dispute_resolve')`: `grep -rn "dispute_resolve" lib/` = 0. Static grep lenses in CI. |
| **PII / evidence sensitivity** | `DisputeCase.reason`, evidence `description`, and evidence `title` are user-authored dispute content — rendered read-only, logged only via `HivorrLogger` + `PiiRedactor` as truncated/redacted (never full). Party identity displayed as entity-id suffix (`***1234`), never full names. Escrow amounts via `BalanceFormatter`; currency always shown. |
| **Evidence storage privacy** | Evidence attachments live only in the private `credential-documents` bucket; preview via signed URL (`StorageService.createSignedUrl`, validated TTL), never a public-URL path (`storage_service.dart:53` throws for private buckets on public URL). MIME/size validated against `StorageConfig` before upload. |
| **Immutable evidence & resolutions** | Server has no UPDATE/DELETE grants on `dispute_evidence`/`dispute_resolutions`; client offers no edit/delete affordances — the UI truthfully reflects immutability. |
| **Escrow freeze defense-in-depth** | Server `dispute_place_escrow_hold`/`dispute_release_escrow_hold` (SECURITY DEFINER, `FOR UPDATE`) are the enforcement; client `EscrowFrozenBanner` + disabled actions are the UX layer. Both must agree; no client code path releases a disputed milestone (EP-02-14 already guards, confirmed by grep lens). |
| **Duplicate-active-dispute race** | Partial unique index `dispute_cases_one_open_per_escrow_idx` (`99-101`) prevents concurrent active disputes; `dispute_file` maps `unique_violation` → `PLT005`. Client surfaces the conflict message and disables "File" when the linked escrow already shows `disputed`. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per env; dispute reads/writes per environment, no cross-env. |
| **Validation fidelity** | Client validators must mirror the frozen CHECK constraints exactly (reason 10–2000, title 1–255, description ≤2000, vocabularies) — the server remains the single authority; client pre-validation is UX fast-fail only. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **RPC cost** | `dispute_get` STABLE + PK lookup + indexed evidence join (`157`); `dispute_list` filer/counterparty indexes + status index (`91-98`). `DisputeProvider.select` = 1 RPC for case + evidence + resolution envelope. |
| **Caching** | `DisputeProvider` memoizes `disputes` + per-case `evidence`/`resolution` in memory. `refresh()` re-reads only the current selection. No disk persistence (dispute is live case state, not offline-cacheable). Invalidate on pull-to-refresh, lifecycle resume, or post-action re-read. |
| **Vocabulary/math** | All status/type/priority/outcome vocabularies are compile-time const lists in `DisputeService` — no lookups in build methods, no per-frame allocation. |
| **Evidence upload** | Single upload per attachment with `StorageService` progress callback; file validated (MIME/size) before transfer; signed-URL preview lazily created on demand, never eagerly for list items. |
| **Lifecycle pause/resume** | `WidgetsBindingObserver` `didChangeAppLifecycleState` pauses `DisputeProvider` polling (none in MVP — state loads on demand) and cancels in-flight state changes on background; resumes on foreground. |
| **Tracer overhead** | `PerformanceTracer` spans (`support.dispute.get/list/file/submit_evidence`) sampled via `MonitoringConfig`, tags `support.dispute.status`, `support.dispute.evidence.count`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/` + `test/unit/systems/support/`

Pattern mirrors the EP-02-14/EP-02-16 suites + `test/support/fakes/fake_supabase.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `supabase_dispute_remote_data_source_test.dart` | 14 | Mock `SupabaseClient.rpc` via fake `SupabaseClient`: `dispute_file → {success:true, code:PLT000, data:{...}}` success; `dispute_submit_evidence` success; `dispute_withdraw` (SECURITY DEFINER, plain rpc call) success; `dispute_get → {case, evidence:[...], resolution}` success; `dispute_get → resolution:null`; `dispute_list → {disputes:[...]}` success; `dispute_list(p_status)` passes filter param; envelope `success:false → PLT003` → `validation`; `404 PLT004` → `notFound`; `409 PLT005` → `conflict`; `401 PLT001` → `auth`; `403 PLT002` → `forbidden`; `500 PLT999` → `server`; **no `dispute_resolve` method exists** (contract assertion via reflection/grep) |
| `dispute_repository_test.dart` | 14 | Fake `SupabaseDisputeRemoteDataSource` + real `DisputeRepositoryImpl`. `listDisputes` maps list; `listDisputes(status:'open')` passes filter + maps; `getCase` maps case+evidence+resolution; resolution null safe; `fileDispute` pre-validates reason (<10 throws `PLT003` before remote; >2000 throws; valid passes); invalid dispute type throws before remote; invalid priority throws; valid file → mapped case; `submitEvidence` pre-validates title (empty throws), description (>2000 throws), invalid evidence type throws; valid submit mapped; `withdrawDispute` mapped; PLT005 propagated |
| `dispute_provider_test.dart` | 12 | `ChangeNotifier` with mocked repository: `loadList` sets `loadState=loading` then `success` with disputes; status filter variant; `select(id)` loads case+evidence+resolution; `file` updates state + notifies; `submitEvidence` appends evidence + notifies; `withdraw` updates selected status + notifies; `refresh` re-reads; error state surfaces `lastError.message`; `pausePolling`/`resumePolling`; `dispose` |
| `dispute_mapper_test.dart` | 12 | `DisputeCaseDto.fromJson → DisputeCase` mapping all snake_case fields (`escrow_id`, `filer_entity_id`, `counterparty_entity_id`, `dispute_type`, `desired_outcome`, `filed_at`, `resolved_at`...); null timestamps → null; `DisputeEvidenceDto.fromJson → DisputeEvidence` (evidence_type, file_url, file_metadata); `DisputeResolutionDto.fromJson → DisputeResolution` (resolution_type, payer_refund_amount numeric→double, reasoning); `dispute_get` envelope → `DisputeCaseDetail`; `dispute_list` envelope → `List<DisputeCase>`; empty evidence array → `[]`; null resolution → null; metadata passthrough |
| `dispute_service_test.dart` | 12 | `disputeStatuses.length == 5`; status vocab labels match CHECK `66-68`; `disputeTypes.length == 5` matching `62-65`; desired-outcome vocab length/content matching `71-73`; priority vocab length matching `74-75`; evidence types matching `112-113`; resolution types matching `141-143`; `validateReason('1234567890') == true`; `validateReason('short') == false`; 2001-char reason false; `validateTitle('') == false`; `validateDescription(2001) == false` |
| `dispute_envelope_parser_test.dart` | 6 | `PLT000` success unwraps data; `success:false` throws `ApiException` with code/message; PLT003/004/005/999 code parity |

Target **≥70 unit assertions**; repository/provider ≥90%, mappers/service/parser 100%.

### 14.2 Widget Suite — `test/widget/systems/support/`

| File | Cases (min) | Method |
|---|---|---|
| `dispute_status_badge_test.dart` | 7 | Pump with `MaterialApp` `AppTheme.light`: each of 5 statuses renders label + expected `colorScheme` container (open `warningContainer`, under_review `primaryContainer`, resolved `successContainer`, closed `surfaceVariant`, withdrawn `surfaceVariant`); no hardcoded hex; `grep Colors.` assert `0` |
| `dispute_list_screen_test.dart` | 8 | Cards render per dispute (badge + type + counterparty initials + date); empty → `HivorrEmptyState`; status filter chips toggle provider.filter; FAB navigates to filing; pull-to-refresh invokes provider `loadList`; error → `HivorrErrorState` |
| `dispute_detail_screen_test.dart` | 14 | Header badge + type + priority; escrow context card + "View escrow" route; `EscrowFrozenBanner` on disputed escrow presence; reason rendered full; evidence cards render (type icon, title, description); "Add evidence" visible when `open`/`under_review`, hidden when `resolved`/`withdrawn`/`closed`; resolution panel visible when resolution present (type + reasoning + `BalanceFormatter` amounts), hidden otherwise; withdraw button visible only open + filer (mock current user); withdrawal confirm dialog; state asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge`, spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp; `grep Colors.` assert `0` |
| `dispute_filing_screen_test.dart` | 10 | Escrow context header renders picked escrow (amount via `BalanceFormatter`); type selector 5 options; reason field live counter; invalid reason disables submit; priority defaults medium; desired outcome optional; submit calls `DisputeProvider.file` with exact params; success routes to detail; `PLT005` conflict surfaces banner; existing-disputed escrow disables submit |
| `dispute_evidence_form_screen_test.dart` | 8 | Evidence type selector 4 options; title counter; invalid title disables submit; attachment picker validates MIME/size (over-10MiB rejected, wrong type rejected); upload progress state; successful upload passes `fileUrl` to `submitEvidence`; server error surfaces inline |
| `evidence_attachment_card_test.dart` | 5 | Renders type icon per evidence type; title/description; attachment chip shows name/size; signed-URL preview action; no preview for `description` type |
| `escrow_frozen_banner_test.dart` | 4 | Renders `colorScheme.errorContainer`; copy "all actions are frozen"; "View dispute" action routes to `/support/disputes/:id`; no hex |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`/`find.byType(FilledButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/support/dispute_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseClient.rpc` map + real `SupabaseDisputeRemoteDataSource` + real `DisputeRepositoryImpl` + real `DisputeProvider`. Flow: `file(escrowId: 'escrow-x', type: service_quality, reason: 'Work did not match the milestone agreement...')` → mock `dispute_file → {data:{status:'open'}}` (escrow → `disputed` asserted in server domain mock) → `submitEvidence(title: 'Screenshot mismatch', description: 'See attachment', fileUrl: '<credential-documents path>')` → mock `dispute_submit_evidence` → `select(caseId)` → mock `dispute_get → {case:{status:'under_review'}, evidence:[...], resolution:null}` → assert evidence rendered → (mock admin resolution) re-`select` → mock `dispute_get → resolution:{resolution_type:'release_to_payee', ...}` → assert resolution displayed → `withdraw` only when open/filer (else assert button absent). No `supabase start` container needed; live `supabase db test` is source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001-017` + financial `013-014` + dispute `015-016` green. Lens: `grep -r "Colors\.\|Color(0x" lib/systems/support lib/data/dispute*` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/support` = 0, `grep -r "service_role" lib/` = 0, `grep -rn "dispute_resolve\|supabase.rpc.*dispute_resolve" lib/` = 0 (no client resolve path), `git diff --stat supabase/` = 0, `git status --porcelain .supabase/functions` empty.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_dispute_remote_data_source.dart` export. Static grep lens proves the client never calls `dispute_resolve` and holds no `service_role` key.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/migrations/20260829120005_dispute_resolution_schema.sql` + `20260829120006_dispute_withdraw_definer.sql`, `lib/data/datasources/remote/financial_envelope_parser.dart`, `lib/core/api/services/base_api_service.dart:15`, `lib/data/providers/escrow_provider.dart`, `lib/core/storage/storage_paths.dart`, `lib/core/storage/storage_config.dart`, `lib/app/router/app_router.dart:17`, `lib/systems/support/` (empty) | Baseline |
| 2 | Create `lib/data/entities/dispute_case.dart` — `DisputeCase{id, escrowId, filerEntityId, counterpartyEntityId, disputeType, status, reason, desiredOutcome?, priority, filedAt, resolvedAt?, closedAt?, withdrawnAt?, metadata}` entity | Entity |
| 3 | Create `lib/data/entities/dispute_evidence.dart` — `DisputeEvidence{id, caseId, submittedBy, evidenceType, title, description?, fileUrl?, fileMetadata, createdAt}` entity | Entity |
| 4 | Create `lib/data/entities/dispute_resolution.dart` — `DisputeResolution{id, caseId, resolvedBy?, resolutionType, reasoning, payerRefundAmount, payeeReleaseAmount, notes?, resolvedAt, createdAt}` entity | Entity |
| 5 | Create DTOs `lib/data/models/dispute_case_dto.dart`, `dispute_evidence_dto.dart`, `dispute_resolution_dto.dart`, `dispute_list_envelope_dto.dart`, `dispute_case_detail_envelope_dto.dart` + `dispute_case_detail.dart` value object — JSON matching `dispute_get`/`dispute_list` shapes | DTOs |
| 6 | Create `lib/data/mappers/dispute_mapper.dart` — `caseToEntity`, `evidenceToEntity`, `resolutionToEntity`, `listEnvelopeToEntities`, `caseDetailToEntity` extension methods | Mappers |
| 7 | Create `lib/data/datasources/remote/dispute_remote_data_source.dart` — abstract `DisputeRemoteDataSource` §5.3 (5 methods; **no resolve**) | Contract |
| 8 | Create `lib/data/datasources/remote/dispute_envelope_parser.dart` — `{success, code, message, data}` unwrap | Parser |
| 9 | Create `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart` — `BaseApiService` impl: 5 RPC wrappers via `supabase.rpc()` + `DisputeEnvelopeParser` | Remote |
| 10 | Create `lib/data/repositories/dispute_repository.dart` abstract + `lib/data/repositories/dispute_repository_impl.dart` — §5.4 `listDisputes/getCase/fileDispute/submitEvidence/withdrawDispute`; client-side pre-validation; never writes tables directly | Repository |
| 11 | Create `lib/systems/support/models/dispute_status.dart` — `DisputeStatus` + type/priority/outcome/evidence-type vocab §5.5 | Vocabulary |
| 12 | Create `lib/systems/support/services/dispute_service.dart` — facade §5.5: vocabularies, `validateReason/validateTitle/validateDescription`, delegation | Service |
| 13 | Create `lib/data/providers/dispute_provider.dart` — `ChangeNotifier` §5.6 (mirrors `EscrowProvider` pattern, `pausePolling`/`resumePolling`) | Provider |
| 14 | Update `lib/core/storage/storage_paths.dart` — add `StoragePaths.disputeEvidence(caseId, fileName)` | Storage path |
| 15 | Create widgets `lib/systems/support/widgets/dispute_status_badge.dart`, `evidence_attachment_card.dart`, `escrow_frozen_banner.dart` — `AppTheme` tokens only | Widgets |
| 16 | Create screens `lib/systems/support/screens/dispute_list_screen.dart`, `dispute_detail_screen.dart`, `dispute_filing_screen.dart`, `dispute_evidence_form_screen.dart` — §5.7 responsive, branded states, frozen-aware | Screens |
| 17 | Create barrel `lib/systems/support/support.dart` + update `lib/data/data_layer.dart` | Barrels |
| 18 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `disputes/disputesNew/disputeDetail` routes guarded by `RouteGuard` (+ optional `escrowId` query for filing pre-selection) | Routes |
| 19 | Create `test/support/fakes/fake_dispute_remote_data_source.dart` + `fake_dispute_repository.dart` | Test infra |
| 20 | Create `test/unit/data/dispute_mapper_test.dart` (12) + `dispute_envelope_parser_test.dart` (6) | Tests 1 |
| 21 | Create `test/unit/data/dispute_repository_test.dart` (14) + `test/unit/data/dispute_provider_test.dart` (12) | Tests 2 |
| 22 | Create `test/unit/data/supabase_dispute_remote_data_source_test.dart` (14) + `test/unit/systems/support/dispute_service_test.dart` (12) | Tests 3 |
| 23 | Create `test/widget/systems/support/dispute_status_badge_test.dart` (7) + `evidence_attachment_card_test.dart` (5) + `escrow_frozen_banner_test.dart` (4) | Tests 4 |
| 24 | Create `test/widget/systems/support/dispute_list_screen_test.dart` (8) + `dispute_detail_screen_test.dart` (14) + `dispute_filing_screen_test.dart` (10) + `dispute_evidence_form_screen_test.dart` (8) | Tests 5 |
| 25 | Create `test/integration/support/dispute_flow_test.dart` — fake-E2E `file → submitEvidence → select → resolution display → withdraw` | Integration |
| 26 | `flutter analyze` + `flutter test --coverage` (≥70 assertions green, repository ≥90%, mapper/service/parser 100%) | Verify |
| 27 | `supabase db test` full suite `001-017` + dispute `015-016` + financial `013-014` green + grep lenses: `Colors.\|Color(0x` = 0, `service_role` in `lib/` = 0, no `dispute_resolve` in `lib/` = 0, `git diff --stat supabase/` = 0, `.supabase/functions` untouched | Regression |
| 28 | Doc pass: dartdoc on `DisputeCase`, `DisputeEvidence`, `DisputeResolution`, `DisputeStatus`, `DisputeService`, `DisputeRepository` contract + `SupabaseDisputeRemoteDataSource` RPC-surface doc | Docs |
| 29 | Tag `EP-02-18/19/20` unblocked; phase plan `EP-02-17` → `Completed` candidate pending review; hand `EscrowFrozenBanner`/dispute routes to EP-02-14 consumers + EP-02-18 onboarding integration | Handoff |

## 16. Expected Outcome

- `lib/data/` exposes a single seam for dispute state: `DisputeRepository` lists and reads cases via the live `dispute_list`/`dispute_get` RPCs, files and withdraws via `dispute_file`/`dispute_withdraw`, submits evidence via `dispute_submit_evidence` (with pre-uploaded `credential-documents` URLs), maps via `DisputeMapper` to pure `DisputeCase`/`DisputeEvidence`/`DisputeResolution`, and pre-validates against the frozen CHECK vocabularies — **never** calling the `service_role`-only `dispute_resolve`.
- The **`service_role` boundary is absolute and grep-provable**: `DisputeRemoteDataSource` declares no resolve method; `grep -rn "dispute_resolve" lib/` = 0; no `service_role` string anywhere in `lib/`.
- `lib/systems/support/` is established as a first-class system: status/type/priority/outcome/evidence vocabularies matching the frozen CHECK constraints, `validateReason/validateTitle/validateDescription` fail-fast helpers, and the `EscrowFrozenBanner` that makes the escrow-dispute freeze visible across the app.
- Filing a dispute from an escrow places the automatic server hold (escrow → `disputed`) and the UI immediately renders the frozen state with a "View dispute" path; withdrawal releases the hold server-side (`disputed → funded`).
- `DisputeProvider` (`ChangeNotifier`) owns memoized list/detail/evidence/resolution state, `WidgetsBindingObserver` lifecycle, and post-action re-reads — mirroring the proven `EscrowProvider` pattern with no `supabase_realtime`.
- `DisputeListScreen`, `DisputeDetailScreen`, `DisputeFilingScreen`, `DisputeEvidenceFormScreen` render status badges, evidence attachments, resolution outcomes, and frozen banners with **zero hardcoded `Colors.*`/hex/`fontFamily`** — all `Theme.of(context).colorScheme.*`/`textTheme.*`/`AppThemeExtension` tokens (`VISUAL-IDENTITY.md:176-190,219-235`), responsive via `shared/layouts/` (16dp mobile / 24dp web), branded states via `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrLoader`.
- Evidence attachments securely reach the existing private `credential-documents` bucket (10 MiB, `jpeg/png/webp/pdf`) via `StoragePaths.disputeEvidence()` and preview via signed URLs only.
- Unit suite ≥70 assertions green with mocked `SupabaseClient`/`Dio`; `flutter analyze` clean; full pgTAP `001-017` + dispute `015-016` + financial `013-014` green; grep lenses prove no `service_role`, no hardcoded color/font leakage, and **no client invocation of `dispute_resolve`**; `git diff --stat supabase/` = 0; `.supabase/functions` untouched.
- `EP-02-18` (onboarding), `EP-02-19` (professional profile), and `EP-02-20` (client verification display) unblocked — dispute routes, vocabulary, and frozen-banner integration are ready for cross-system wiring.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/entities/dispute_case.dart` exists — `DisputeCase{id, escrowId, filerEntityId, counterpartyEntityId, disputeType, status, reason, desiredOutcome?, priority, filedAt, resolvedAt?, closedAt?, withdrawnAt?, metadata}` | File inspection |
| 2 | `lib/data/entities/dispute_evidence.dart` exists — `DisputeEvidence{id, caseId, submittedBy, evidenceType, title, description?, fileUrl?, fileMetadata, createdAt}` | File inspection |
| 3 | `lib/data/entities/dispute_resolution.dart` exists — `DisputeResolution{id, caseId, resolvedBy?, resolutionType, reasoning, payerRefundAmount, payeeReleaseAmount, notes?, resolvedAt, createdAt}` | File inspection |
| 4 | All 5 DTOs + `DisputeCaseDetail` value object exist in `lib/data/models/` matching `dispute_get`/`dispute_list` envelope shapes | File inspection |
| 5 | `lib/data/mappers/dispute_mapper.dart` defines `caseToEntity`, `evidenceToEntity`, `resolutionToEntity`, `listEnvelopeToEntities`, `caseDetailToEntity` — null → nullable defaults | Unit test |
| 6 | `lib/data/datasources/remote/dispute_remote_data_source.dart` exists — abstract `DisputeRemoteDataSource` with exactly 5 methods (`listDisputes`/`getCase`/`fileDispute`/`submitEvidence`/`withdrawDispute`); **no resolve method declared** | File inspection |
| 7 | `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart` implements `DisputeRemoteDataSource` — 5 RPC wrappers via `supabase.rpc()` + `DisputeEnvelopeParser`; never calls `dispute_resolve` | File + unit test |
| 8 | `lib/data/datasources/remote/dispute_envelope_parser.dart` unwraps `{success, code, message, data}`; `success:false` → `ApiException` with server code/message | Unit test |
| 9 | `lib/data/repositories/dispute_repository.dart` + `_impl.dart` define `DisputeRepository{listDisputes, getCase, fileDispute, submitEvidence, withdrawDispute}` — client pre-validates reason/title/description/vocabs before RPC; never writes dispute tables directly | Unit test |
| 10 | `lib/systems/support/services/dispute_service.dart` facade exposes status (5), type (5), desired-outcome (4+other), priority (4), evidence-type (4), resolution-type (4) vocabularies matching frozen CHECK constraints + `validateReason` (10–2000) / `validateTitle` (1–255) / `validateDescription` (≤2000) | File + unit test |
| 11 | `lib/data/providers/dispute_provider.dart` exists — `ChangeNotifier` with `disputes/selected/evidence/resolution/loadState/lastError`, `loadList({status})`/`select(id)`/`file(...)`/`submitEvidence(...)`/`withdraw(id)`/`refresh()`, `pausePolling`/`resumePolling` — mirrors `lib/data/providers/escrow_provider.dart` | Unit test |
| 12 | `lib/core/storage/storage_paths.dart` gains `disputeEvidence(caseId, fileName)` routing to `credential-documents` (no bucket/create changes) | File + grep |
| 13 | `lib/systems/support/screens/dispute_list_screen.dart` exists — `GET /support/disputes`, status filter chips, dispute cards, FAB → filing, pull-to-refresh, `AppTheme` tokens only, responsive | Widget test |
| 14 | `lib/systems/support/screens/dispute_detail_screen.dart` exists — `GET /support/disputes/:id`, header + escrow context (+ "View escrow" + `EscrowFrozenBanner` when disputed) + reason + evidence cards + resolution panel + open/filer-only withdraw | Widget test |
| 15 | `lib/systems/support/screens/dispute_filing_screen.dart` exists — `GET /support/disputes/new`, escrow context header, type/reason/desired-outcome/priority fields matching `dispute_file` params, pre-validated submit, `PLT005` conflict banner | Widget test |
| 16 | `lib/systems/support/screens/dispute_evidence_form_screen.dart` exists — type/title/description fields + validated attachment upload to `credential-documents` before RPC | Widget test |
| 17 | `lib/systems/support/widgets/dispute_status_badge.dart` / `evidence_attachment_card.dart` / `escrow_frozen_banner.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp; frozen banner routes to `/support/disputes/:id` | Widget test |
| 18 | `lib/systems/support/support.dart` barrel + `lib/data/data_layer.dart` re-export new symbols | File inspection |
| 19 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `disputes='/support/disputes'` + `disputesNew='/support/disputes/new'` + `disputeDetail='/support/disputes/:id'` guarded by `RouteGuard` (+ optional `escrowId` query) | File + `go_router` smoke |
| 20 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` |
| 21 | No `.supabase/functions/*` files created | `git status --porcelain .supabase/functions` empty |
| 22 | No `service_role` or secret leakage — `grep -r "service_role" lib/` = 0 | `grep` |
| 23 | No client `dispute_resolve` path — `grep -rn "dispute_resolve\|supabase.rpc.*dispute_resolve" lib/` = 0 | `grep` |
| 24 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/support lib/data/dispute*` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/support` = 0 | `grep` |
| 25 | `test/unit/data/supabase_dispute_remote_data_source_test.dart` ≥14 cases green (5 RPC success paths, envelope, `PLT001/002/003/004/005/999`, no-resolve contract) | `flutter test` |
| 26 | `test/unit/data/dispute_repository_test.dart` ≥14 + `dispute_provider_test.dart` ≥12 + `dispute_mapper_test.dart` ≥12 green | `flutter test` |
| 27 | `test/unit/data/dispute_envelope_parser_test.dart` ≥6 + `test/unit/systems/support/dispute_service_test.dart` ≥12 green (vocab fidelity + validators) | `flutter test` |
| 28 | `test/widget/systems/support/dispute_status_badge_test.dart` ≥7 + `dispute_list_screen_test.dart` ≥8 + `dispute_detail_screen_test.dart` ≥14 green, token + layout asserts | `flutter test` |
| 29 | `test/widget/systems/support/dispute_filing_screen_test.dart` ≥10 + `dispute_evidence_form_screen_test.dart` ≥8 + `evidence_attachment_card_test.dart` ≥5 + `escrow_frozen_banner_test.dart` ≥4 green | `flutter test` |
| 30 | `test/integration/support/dispute_flow_test.dart` fake-E2E green: `file → submitEvidence → select → resolution display → withdraw (open/filer only)` | `flutter test` |
| 31 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI |
| 32 | `supabase db test` full suite `001-017` + dispute `015-016` + financial `013-014` green — no RLS/role regression | `supabase db test` |
| 33 | `flutter test` total ≥70 unit assertions green; `DisputeService` 100%, `DisputeRepository` ≥90%, mappers/parser 100% | `flutter test` |
| 34 | `EP-02-18/19/20` unblocked; phase plan status updated; `EscrowFrozenBanner` route handoff documented | Dependency check + docs |

---

## Recommended Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Very High**

**Reasoning Level Justification:**

| Dimension | Assessment | Rationale |
|---|---|---|
| Technical complexity | High | 3 entities + 5 DTOs + mapper chain + `DisputeEnvelopeParser` + `ChangeNotifier` provider mirroring the proven `EscrowProvider` (EP-02-14) pattern — all against known RPC shapes from the frozen migration. Elevated by the **5-RPC surface** with a mix of SECURITY INVOKER and one SECURITY DEFINER (`dispute_withdraw`), the staged evidence-upload-then-RPC flow over the private storage bucket, and client pre-validation fidelity to four CHECK vocabularies. |
| Business impact | Extremely High | Dispute resolution IS the marketplace safety net (`EP-02:423-432`) — when a transaction goes wrong, this is the only recourse for both parties. A client that cannot file a dispute, let a user submit evidence, or display a resolution outcome erodes the trust narrative that escrow (EP-02-14) established. Filing must produce the escrow hold reliably; the frozen-dispute UX must never present an actionable control on a disputed escrow. |
| Security risk | Extremely High | The `service_role` boundary for `dispute_resolve` is absolute — any client code path that invokes it (or leaks `service_role`/a resolver grant into `lib/`) is a design violation caught by grep lens but catastrophic architecturally if it slips through. Evidence content (reason, descriptions, screenshots) is sensitive PII-level data — full-text logging, public-URL leaks, or unmasked party identity would violate `AGENT.md` privacy rules. The immutable evidence/resolution contract must not be undermined by an edit/delete affordance in the UI. |
| Performance sensitivity | Medium | 1 RPC per select (`dispute_get` STABLE, PK + indexed joins), memoized provider state, compile-time const vocabularies — trivial. Notable only for evidence upload (validated MIME/size before transfer, lazy signed-URL previews) and lifecycle pause/resume. |
| Data complexity | High | Dispute aggregates three relational shapes (case + ordered evidence array + optional resolution) from one `dispute_get` envelope; evidence `file_url` points at private storage paths that must round-trip through `StorageService.createSignedUrl`. Frozen schema: 5 dispute statuses `66-68`, 5 types `62-65`, 4 priorities `74-75`, 4 evidence types `112-113`, 4 resolution types `141-143`, reason 10–2000 `69-70`, title 1–255 `114-115` — vocab and validation must match exactly to avoid drift on the frozen migration. |
| Integration complexity | High | Couples with EP-02-14 escrow (filing computes escrow context, detail routes to escrow, `EscrowFrozenBanner` shared) and EP-02-08 storage (evidence pipeline). Reads depend on the frozen EP-02-05 RPCs + the standard `{success, code, message, data}` envelope; the client must be defensively correct across all 5 RPCs plus the prohibited `dispute_resolve`. Blocks EP-02-18/19/20, which consume dispute routes and vocabulary. |

Overall the task anchors the marketplace dispute safety net with a **provably safe client seam** (`AGENT.md:16` Rule 4 server-authoritative, zero client `service_role`, zero `dispute_resolve` references, static grep-lens enforcement), strict vocabulary fidelity to the frozen migration, secure private-bucket evidence handling, and truthful frozen/immutable UX — **Very High** reasoning ensures every RPC is wrapped correctly, every CHECK vocabulary matches byte-for-byte, no resolution path leaks client-side, and the frozen-dispute display can never present an actionable control.

---

## 18. Appendix

### A. Glossary

| Term | Definition |
|------|-----------|
| **Dispute** | A formal complaint raised by either party to an escrow against the other, freezing the escrow funds until resolution |
| **Escrow Hold** | Server-side transition of `financial_escrow.status → 'disputed'` performed atomically by the SECURITY DEFINER helper `dispute_place_escrow_hold` |
| **Evidence** | Immutable submissions (`document`, `screenshot`, `description`, `photo`) attached to a dispute case; stored in the private `credential-documents` bucket |
| **Resolution** | Binding admin decision (`release_to_payee`, `refund_to_payer`, `split`, `dismissed`) recorded in `dispute_resolutions` via the `service_role`-only `dispute_resolve` |
| **SECURITY DEFINER** | PostgreSQL function attribute — the function body executes with the owner's privileges (used for `dispute_withdraw` and the escrow-hold helpers; pinned `search_path`) |
| **Service Role** | Supabase role with elevated privileges — only callable from server-side; `dispute_resolve` is granted exclusively to it |
| **Authenticated** | Supabase role for logged-in users — callable from client with valid JWT; the 5 client RPCs are granted to it |

### B. Related Documents

- `AGENT.md` — Rules 1-5 (security guardrails), Rule 4 server-authoritative, Rule 5 visual identity
- `ARCHITECTURE.md` — Directory structure, separation of concerns, layer responsibilities
- `EP-02 Trust, Identity & Financial Integrity Engine.md` — Phase plan source of truth (`423-432`)
- `EP-02-05-Dispute Resolution Schema & Server-Side Rules.md` — Server schema + RPC reference (this task's server dependency)
- `EP-02-14-Escrow & Milestone Payment Management.md` — Escrow client implementation reference + `EscrowFrozenBanner` consumer
- `EP-02-08-Storage Service & File Upload Infrastructure.md` — `StorageService`/`StorageConfig`/path conventions reference
- `EP-02-16-Bound Payout Account System & Deposit Name Verification.md` — Plan template reference
- `supabase/migrations/20260829120005_dispute_resolution_schema.sql` — Frozen dispute schema (4 tables + 8 functions + RLS)
- `supabase/migrations/20260829120006_dispute_withdraw_definer.sql` — Approved DEFINER deviation for `dispute_withdraw`
- `documents/Context/VISUAL-IDENTITY.md` — Design tokens (all UI must source from `AppTheme`)