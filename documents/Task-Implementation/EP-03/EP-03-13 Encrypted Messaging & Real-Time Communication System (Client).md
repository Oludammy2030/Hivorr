# Task Implementation Plan — EP-03-13: Encrypted Messaging & Real-Time Communication System (Client)

**Task ID:** EP-03-13 | **Priority:** High | **Status:** Not Started | **Phase:** EP-03 Stage 5 — Trust & Coordination
**Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:378-387` + `§5/§7` + `AGENT.md` + `ARCHITECTURE.md:39-178`
**Plan Mode:** Planning artifact only. No production code. No Phase doc mutation. Awaiting approval before implementation.

---

## 1. Task Objective

Deliver the **client-side contract-scoped encrypted messaging system** on top of the completed EP-03-04 server fabric:

> Service `lib/systems/communication/services/messaging_service.dart` wrapping `conversation_ensure_for_contract`, `message_send/list`, `SupabaseRealtime` subscription behind `lib/data/datasources/remote/supabase_messaging_remote_data_source.dart` abstraction. Local queue `lib/core/sync/action_queue.dart` for offline send with `Hive` persistence; send deduplicated by `client_message_id`. Screens: `conversation_list_screen.dart`, `message_thread_screen.dart` (`ListView` + `HivorrTextField` + send `HivorrButton`). Encryption: `AES-GCM` via `lib/core/security/crypto/aes_cipher.dart` for `body_encrypted` (keys per conversation derived via `lib/core/security/crypto/key_derivation.dart` from session + conversation_id — forward-compatible, not persisted plaintext). Push on `new_message` via `lib/core/notifications/push/supabase_push_receiver.dart`.

Success is: two contract participants exchange AES-GCM-authenticated messages with Realtime delivery (<1s on Staging), offline-sent messages replay exactly-once via `client_message_id`, non-participants read zero rows, undecryptable rows render placeholders (never plaintext), and all UI consumes `AppTheme` tokens.

## 2. Business Problem Being Solved

EP-03-02 proved contracts + EP-03-04 proved `conversations (contract_id UNIQUE)`, `conversation_participants`, `messages (body_encrypted 20-8000, body_preview <=120, client_message_id UNIQUE)` + 4 RPCs + RLS + `supabase_realtime ADD TABLE messages` + pgTAP `029/030`. But **no usable client coordination exists**:

- No Realtime Dart subscription for `messages` — current `MessagingProvider.refresh()/select()` is poll-on-resume only.
- No offline queue wiring — `ActionQueue` exists but `MessagingService.sendText` calls RPC directly; airplane-mode send fails instead of `pending → sent`.
- No Hive persistence for drafts/thread window — reconnect loses composer state.
- `unreadCount` always `0`, `peerOnline` always `false` (explicit `TODO(messaging-backend)` in `lib/data/entities/conversation.dart:40-50`) — badges/presence hidden.
- Notification is generic local hook only (`MessagingProvider._maybeNotify`), no `body_preview`-driven push with deep-link `/dashboard/messages/:id`.
- Text-only; Nigeria unreliable-connectivity market (`Business-Roadmap:29`) will lose messages without hybrid Realtime + queue.

Without this, offer/accept negotiation, milestone evidence discussion, and dispute context have no private, lossless channel.

## 3. Scope

| In Scope | Detail |
|---|---|
| Realtime delivery seam | `MessagingRealtimeDataSource` interface + Supabase implementation: `channel('messages:<id>').onPostgresChanges(event:insert, schema:public, table:messages, filter:eq('conversation_id',…))`, RLS-filtered, lifecycle-aware subscribe/unsubscribe, backpressure (latest-page refresh, not per-event list rebuild) |
| Offline send queue | `ActionQueue.enqueue(SyncAction{endpoint:'/rpc/message_send', payload:{client_message_id uuid.v4}})` + Hive `sync_queue` persistence + `connectivity_plus` replay + `ON CONFLICT(client_message_id) DO NOTHING` dedup; optimistic `pending → sent/failed` UI |
| Thread persistence | Hive box for thread window + composer drafts via `lib/core/database/local_store.dart`; `AppBoxes` extension (one new box, no new engine) |
| Conversation list + thread UI | Canonical thread experience bound to contract: list (keyset, preview, pull-refresh), thread (oldest-first, cursor `loadEarlier`, composer 1–4000, undecryptable placeholder, retry) |
| Encryption boundary | Keep `MessageCrypto.encryptText/decryptText/previewOf` + `AesCipher.defaultInstance` + `validateText`; PII-safe logging via `PiiRedactor` |
| Contract entry + routing | `ensureForContract(contractId)` from `contract_detail` CTA + existing `/dashboard/messages`, `/dashboard/messages/:id` deep-links with `PLT004 → HivorrEmptyState` (no oracle) |
| Notifications | `hivorr_default` channel local notification on growth while open + push receiver wiring for background `message_received` with redacted `body_preview` only |
| Visual identity + responsive | `HivorrButton/TextField/Card/Loading/Empty/ErrorState/Avatar/Badge/ChatBubble`, `HivorrResponsiveScaffold`, `HivorrContentPane`, `breakpoints.dart`, no `Colors.*`/hex/`fontFamily` |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| New tables / RPCs / RLS / Realtime publication | EP-03-04 `20260925090001_service_messaging_schema.sql` is complete and tested; client is unprivileged presentation per `AGENT.md:13` Rule 4 |
| New crypto primitive / key-exchange protocol | `AesCipher (AesGcm.with256bits)` + `MessageCrypto v1 SHA-256("hivorr-msg-v1"+contractId)` stays; migration to `KeyDerivation.fromConfiguration` per-conversation keys is a future EP (boundary preserved) |
| `message_attachments` bucket / voice / images | No EP-03-04 bucket; reuse `service-listing-media` only for milestone evidence (EP-03-10/11). Attachments deferred; do not create bucket here |
| Presence / read-receipts / typing indicators | No server seam (`peerOnline=false`, `unreadCount=0` TODOs). Keep hidden; do not fake presence. Optional follow-up only if `conversation_list` exposes counts |
| `lib/ai/*` reordering / summarization | Excluded from EP-03 per Phase Plan `§5:106` + `AGENT.md:7`. AI may never reorder RPC order |
| Admin moderation console | Reuses EP-02-11 Admin shell if needed; no marketplace-embedded admin |
| EP-04 3-party threads / logistics chat | `conversation_participants` 3rd row needs no migration; not built here |

## 5. Existing Asset and Dependency Analysis

Inspected via codebase search + direct reads (reuse-first mandate):

| Asset | Location | State | Verdict for EP-03-13 |
|---|---|---|---|
| Server schema + RPCs + RLS + Realtime pub | `supabase/migrations/20260925090001_service_messaging_schema.sql` (623 lines) + `supabase/tests/database/029_*`, `030_*` (92 assertions) | **Implemented, Completed** | **Reuse as-is.** No DDL. Client calls 4 RPCs only |
| `MessageCrypto` | `lib/systems/communication/services/message_crypto.dart:26-107` (`keyForContract`, `encryptText`, `decryptText→null`, `previewOf`, `maxPlaintextLength=4000`) | **Implemented** | **Reuse.** Do not duplicate cipher |
| `MessagingService` | `lib/systems/communication/services/messaging_service.dart:20-157` (validate/ensure/list/decrypt/send + logger/tracer) | **Implemented** | **Reuse + Extend** (add queue/Realtime delegation, keep plaintext boundary) |
| Remote seam | `lib/data/datasources/remote/supabase_messaging_remote_data_source.dart:15-97` + `messaging_remote_data_source.dart` + `messaging_envelope_parser.dart` | **Implemented** | **Reuse.** Single RPC seam; add Realtime interface alongside, don't replace |
| Repository | `lib/data/repositories/messaging_repository.dart` + `messaging_repository_impl.dart:19-104` (fail-fast `PLT003`, mapper delegation, never direct writes) | **Implemented** | **Reuse** |
| Provider | `lib/data/providers/messaging_provider.dart:49-340` (list/select/refresh/loadEarlier/send, lifecycle pause, `_maybeNotify`) | **Implemented** | **Extend.** Add `subscribe/unsubscribe`, queue-aware `send`, Hive hydration; preserve public getters |
| Entities/DTOs/Mappers | `lib/data/entities/conversation.dart:10-118`, `lib/data/models/conversation_dto.dart`, `messaging_envelopes_dto.dart`, `lib/data/mappers/messaging_mapper.dart` | **Implemented** | **Reuse.** `unreadCount/peerOnline` stay 0/false until backend exposes |
| `AesCipher` + `EncryptedPayload{c,i,t}` | `lib/core/security/crypto/aes_cipher.dart:11-102` | **Implemented (EP-01-10)** | **Reuse** |
| `KeyDerivation` + `sha256` | `lib/core/security/crypto/key_derivation.dart`, `sha256.dart`, `security_config.dart` | **Implemented** | **Reuse docs only.** Note divergence: `MessageCrypto` uses raw `sha256` digest, not `KeyDerivation` — do not silently migrate keys in this task |
| `ActionQueue` + `SyncEngine` + `SyncAction` | `lib/core/sync/action_queue.dart:17-184`, `sync_engine.dart:40-305`, `sync_action.dart`, `connectivity_plus_provider.dart` | **Implemented (EP-01-12)** | **Reuse + wire.** First messaging caller of generic queue |
| Notifications | `lib/core/notifications/push/supabase_push_receiver.dart`, `services/local_notification_service.dart`, `channels/notification_channel_manager.dart`, `providers/notification_provider.dart`, `models/hivorr_notification.dart` | **Implemented (EP-01-18)** | **Reuse + extend** payload to `body_preview` + `actionRoute:/dashboard/messages/:id` |
| Storage/Secure/Cache/DB/Network/API/Logging | `lib/core/storage/secure_storage.dart`, `supabase_storage_service.dart`, `storage_paths.dart`, `lib/core/database/* (hive_storage_engine, local_store, AppBoxes)`, `lib/core/cache/lru_cache.dart`, `lib/core/network/*`, `lib/core/api/* (base_api_service, api_client_factory, interceptors)`, `lib/core/logging/pii_redactor.dart`, `hivorr_logger.dart` | **Implemented** | **Reuse.** One new Hive box + thread-preview LRU only |
| Screens (dashboard hosts) | `lib/systems/dashboard/screens/messages_screen.dart` (997 lines, split-view), `conversation_screen.dart` (375 lines, composer), `widgets/messaging_thread_meta.dart` | **Implemented** | **Extend/Refactor, don't duplicate.** Extract canonical `lib/systems/communication/screens + widgets` and keep dashboard as shell hosts OR keep dashboard files and add missing behaviors — decision at build start (see §7.1). Never maintain two thread implementations |
| Shared DS | `lib/shared/widgets/hivorr_{button,card,text_field,loading_state,empty_state,error_state,success_state,snackbar,avatar,badge,chip}.dart`, `lib/shared/components/hivorr_chat_bubble.dart` (`text:null→placeholder`), `hivorr_skeleton/list_tile/dialog/bottom_sheet`, `helpers/hivorr_formatters.dart`, `mixins/*`, `validators/*` | **Implemented (EP-01-16)** | **Reuse** |
| Layouts/Theme/Router | `lib/shared/layouts/hivorr_responsive_scaffold.dart`, `hivorr_screen_scaffold.dart`, `hivorr_content_pane.dart`, `breakpoints.dart`, `mobile_compact.dart`; `lib/app/theme/* (#2D3FE7, AppThemeExtension, Plus Jakarta)`; `lib/app/router/route_paths.dart:264-275` (`dashboardMessages`, `dashboardMessageThreadRoute`), `route_names.dart`, `route_guard.dart`, `app_router.dart` | **Implemented** | **Reuse.** No new top-level `lib/` dir per `ARCHITECTURE.md:39` |
| DI/bootstrap | `lib/app/app_bootstrap.dart:360-361,433-434 (registerMessagingLayer)`, `lib/app/app.dart:219-222,398-399,497-501` | **Implemented** | **Extend** registrations for Realtime + queue adapters |
| Tests | `test/unit/communication/message_crypto_test.dart`, `messaging_models_test.dart`, `test/widget/communication/messaging_screens_test.dart`, `test/support/harnesses/*`, `fakes/*`, `pubspec.yaml (supabase_flutter 2.17.2, connectivity_plus 6.1.0, uuid 4.5.1, hive 2.2.3, fake_async)` | **Implemented** | **Reuse + extend** (Realtime fake, offline replay, leakage tests) |
| Missing | `lib/data/datasources/local/*messaging*`, `lib/integrations/*realtime*`, `supabase/functions/*messaging*`, messaging `messages` Realtime Dart subscription | **Missing (genuine gaps)** | **New (small, reusable):** Realtime interface + Hive thread cache only |

**Dependencies (from Phase Plan §7):** EP-03-04 (server), EP-01-12 (sync/offline queue), EP-01-18 (notifications), EP-01-13 implied storage/crypto. Contract context from EP-03-02/10 for `ensureForContract` entry.

## 6. Reuse / Extension / Refactoring Assessment

| Proposed Asset | Assess | Why + Future Reuse |
|---|---|---|
| `conversations/participants/messages` tables, 4 RPCs, RLS, Realtime pub | **Reuse** | EP-03-04 complete + pgTAP green. Any new table/RPC would duplicate the engagement atom and violate Rule 4. No DDL in EP-03-13 |
| `MessageCrypto`, `AesCipher`, `PiiRedactor` | **Reuse** | `cryptography:2.7.0` + `AesGcm.with256bits` sufficient. New cipher would risk hardcoded keys and break stored `{c,i,t}` rows. Keep v1 derivation; document `KeyDerivation` migration as future EP |
| `SupabaseMessagingRemoteDataSource`, `MessagingRepositoryImpl`, DTOs, mappers | **Reuse** | Single RPC seam already mirrors `supabase_taxonomy_*` pattern. New parallel service would create divergent truth |
| `MessagingService` + `MessagingProvider` | **Extend** | Add Realtime subscribe + queue-aware send + Hive hydration behind existing method names (`loadConversations/select/refresh/loadEarlier/send`). Preserve `validateText 1-4000`, `decrypted echo`, `PLT003` fail-fast, PII-safe logs |
| Dashboard `messages_screen` / `conversation_screen` | **Refactor/Extend, not duplicate** | Two thread UIs must not coexist. Either (A) promote canonical `lib/systems/communication/screens/conversation_list_screen.dart` + `message_thread_screen.dart` + `widgets/message_bubble.dart (wrapping HivorrChatBubble)` and re-export from dashboard, or (B) keep dashboard paths and implement gaps in place. Decide at build kickoff; delete/redirect the loser |
| `ActionQueue/SyncEngine` + `connectivity_plus` | **Extend (wire, don't fork)** | Generic queue has zero messaging callers today. EP-03-13 becomes first `endpoint:'/rpc/message_send'` producer with `client_message_id` as idempotency key. No new queue class |
| Hive thread cache + drafts | **New (minimal)** | No `messaging` local datasource exists (`grep message\|conversation in lib/data/datasources/local = 0`). One box via `AppBoxes` + `LocalStore.read/write` for window + drafts; evict on logout. Designed as reusable `ThreadCache` for EP-04 order chat |
| `MessagingRealtimeDataSource` interface | **New (minimal, abstracted)** | No `lib/integrations/*realtime*` and no `messages` channel code exist (`grep channel( / onPostgresChanges` only hits push infra + TODOs). Interface + `SupabaseMessagingRealtimeDataSource` keeps `supabase_flutter` channel behind a testable seam, mirroring `SupabasePushRealtimeGateway`. Reusable for EP-04 presence/delivery tracking |
| Push on `new_message` | **Extend** | `SupabasePushReceiver` is generic (`filter:eq entity_id`). Add conversation-scoped subscription + redacted `HivorrNotification(body:body_preview)` with deep-link; never include ciphertext/plaintext |
| `unreadCount`, `peerOnline`, attachments, E2E key-exchange | **Defer (no new asset)** | Backend returns neither count nor presence; inventing client-side counts would lie. Keep badges/dots hidden with existing TODOs; do not create bucket or protocol here |

## 7. Recommended Technical Approach

### 7.1 Screen placement decision (first build step, no duplication)

Audit `messages_screen.dart` vs Phase Plan `conversation_list_screen.dart` / `message_thread_screen.dart`. Preferred: create canonical `lib/systems/communication/screens/` + `widgets/` (list, thread, composer, status ticks) built from `Hivorr*` DS, then thin dashboard hosts delegate to them (preserves `/dashboard/messages*` routes). If audit shows dashboard screens already satisfy 80%+, invert: keep dashboard files, extract shared widgets only. Either way, **one thread implementation survives**.

### 7.2 Data flow (online)

`Composer (HivorrTextField, maxLength 4000) → MessagingProvider.send → MessagingService.validateText → MessageCrypto.encryptText(contractId) → Repository.sendMessage(clientMessageId: uuid.v4) → SupabaseMessagingRemoteDataSource.rpc('message_send') → MessagingEnvelopeParser.unwrap → echo decrypted → append → Realtime fan-out`.

Reads: `ensureForContract → listConversations (limit 20, keyset) → select → listDecryptedMessages (limit 30, cursor) → MessageCrypto.decryptText per row (null→placeholder) → oldest-first display → loadEarlier prepend`.

### 7.3 Realtime (new seam, RLS-filtered)

```dart
abstract class MessagingRealtimeDataSource {
  Stream<MessageDto> subscribe(String conversationId);
  Future<void> unsubscribe(String conversationId);
}
```

Supabase impl: `client.channel('messages:$id').onPostgresChanges(event:insert, schema:public, table:messages, filter:'conversation_id=eq.$id', callback)`. Provider subscribes on `select`, unsubscribes on dispose/switch, debounces bursts into single `refresh()` (backpressure). Poll-on-resume (`refresh`) remains fallback per Phase assumption 3 (polling with `fake_async` if Realtime unavailable). Non-participant channel receives 0 events (server RLS).

### 7.4 Offline (wire generic queue)

On `send` with `NetworkStatusProvider.isConnected==false` or RPC network/5xx throw: `ActionQueue.enqueue(SyncAction{type:create, endpoint:'/rpc/message_send', method:'POST', payload:{conversation_id, body_encrypted, body_preview, client_message_id}, priority:2})` persisted via `writeBatch`; UI shows `pending`. `SyncEngine.drain` on `ConnectivityProvider.online` replays sequentially; `ON CONFLICT DO NOTHING` makes retry idempotent (`pending→sent`, duplicate tap returns same `id`, never `PLT005`). `4xx except 401/409 → deadLetter → HivorrErrorState + Retry`. `Idempotency-Key: uuid.v4` header parity with `SyncAction.id`.

### 7.5 Cache

`ThreadCacheDataSource` over `LocalStore` (new `AppBoxes.messages` box): last window per conversation + unsent drafts keyed by `conversationId`. Warm UI from Hive before RPC resolves; never treat cache as settlement truth. LRU preview cache via `lib/core/cache/lru_cache.dart` for list snippets.

### 7.6 Encryption & logging discipline

Plaintext exists only in composer + `decryptedBody` memory. `body_encrypted` opaque through repo/remote; `HivorrLogger` + `PiiRedactor` log ids/counts only. `body_preview = MessageCrypto.previewOf → server left(120)+regexp_replace`. Server never decrypts; client never logs ciphertext.

### 7.7 Platform integration

- Contracts: `contract_detail` CTA `ensureForContract → goNamed(dashboardMessageThread)`.
- Disputes/support: thread is evidence context only; freeze stays in EP-03-17.
- Finance: no balance math; escrow UI untouched.
- Router: reuse `RoutePaths.dashboardMessages/MessageThread`, `route_guard.dart` (messages shared, no hire/offer gate), `?next=` preserve.
- Theme: `Theme.of(context).colorScheme / AppThemeExtension / TextTheme` only; `HivorrChatBubble(mine:primary vs surface+border)`, `time()` formatter.

## 8. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Realtime seam | `lib/data/datasources/remote/messaging_realtime_data_source.dart` (new interface) + `supabase_messaging_realtime_data_source.dart` (new impl) | **Create** (small, behind interface) |
| Thread cache | `lib/data/datasources/local/messaging_local_data_source.dart` + `AppBoxes.messages` extension | **Create** (Hive via `LocalStore`) |
| Service extension | `lib/systems/communication/services/messaging_service.dart` | **Extend** (queue + Realtime delegation) |
| Provider extension | `lib/data/providers/messaging_provider.dart` | **Extend** (subscribe, queue-aware send, hydration) |
| Screens/widgets | `lib/systems/communication/screens/` + `widgets/` canonical OR dashboard in-place (see §7.1) | **Refactor/Extend** (one implementation) |
| DI | `lib/app/app_bootstrap.dart (registerMessagingLayer)`, `lib/app/app.dart` | **Extend** (inject Realtime + cache + queue) |
| Notifications payload | `lib/core/notifications/*` wiring | **Extend** (preview + deep-link) |
| Server schema/RPCs/RLS | `supabase/*` | **Reuse, zero change** |

No new top-level `lib/` directory. No `lib/ai/*`. No new payment/storage infra.

## 9. Data Requirements

Reuse EP-03-04 rows; no new columns. Client shapes (existing, unchanged):

- `Conversation{id, contractId, createdAt, updatedAt, lastMessagePreview, lastMessageAt, unreadCount=0, peerOnline=false}`.
- `ConversationMessage{id, conversationId, senderEntityId, bodyEncrypted, bodyPreview, clientMessageId, createdAt, decryptedBody?}`.
- Envelopes: `ConversationEnsure/List, MessageList{hasMore, nextCursor}` with cursor keyset `(created_at DESC, id DESC)`, limits 1–100 (list default 20, thread default 30).
- Validation mirrors server: non-empty ids, `limit 1-100`, text `1-4000` → `PLT003` fail-fast before RPC.

## 10. Database Considerations

**None — no migration.** Constraints enforced server-side already: `contract_id UNIQUE 1:1`, `PK(conversation,entity)`, `body_encrypted 20-8000`, `body_preview <=120`, `client_message_id UNIQUE`, immutable `messages` (no `UPDATE`), participant-only RLS, `messages` in `supabase_realtime`. Client must not `INSERT` tables directly (`REVOKE`d); all writes via 4 RPCs (`SECURITY INVOKER/DEFINER` posture per `029/030`). Verify at build: `supabase db test` still green; `EXPLAIN` uses `messages_conversation_created_idx` + `conversation_participants_entity_idx`; no N+1 (LATERAL preview + paged `message_list`).

## 11. API Requirements

**No new endpoints.** Reuse PostgREST `/rpc/`:

- `conversation_ensure_for_contract(p_contract_id)` — idempotent 1:1.
- `message_send(p_conversation_id, p_body_encrypted, p_body_preview, p_client_message_id)` — dedup via `ON CONFLICT DO NOTHING`.
- `conversation_list(p_limit, p_cursor)` + `message_list(p_conversation_id, p_limit, p_cursor)` — keyset, `PLT004` identical for foreign/unknown (no oracle).
- Envelope `{success,code,message,data}` via `MessagingEnvelopeParser.unwrap` → `ApiException` (`PLT001/003/004/005/999`); `BaseApiService.invoke` + Dio interceptors (auth→logging→retry→error). `anon 0 EXECUTE`.
- Realtime is Supabase channel (`supabase_flutter:2.17.2`), not REST; abstracted behind new interface for testability + polling fallback.

## 12. User Interface Requirements

Reuse DS; no hardcoded style:

- List: `HivorrResponsiveScaffold` + `HivorrScreenScaffold`, search (`HivorrTextField`), rows (`HivorrListTile` + `HivorrAvatar` + preview + `time()`), states (`HivorrLoadingState(HivorrLoader)` / `Empty` / `Error` + Retry), skeleton shimmer, entrance motion.
- Thread: `HivorrContentPane` (~720dp), `ListView` oldest-first + `loadEarlier`, date separators (`HivorrDivider`), bubbles (`HivorrChatBubble`: mine=`primary`, theirs=`surface`+border, `null→italic undecryptable`), composer (`HivorrTextField` multiline + counter + `HivorrButton` send ≥48dp + `isSending` loader), optimistic ticks (`pending/sent/failed`), `HivorrSnackbar` on failure, `HivorrDialog/BottomSheet` only if delete/attach confirmed (no attachments v1).
- Breakpoints: single-column mobile, `≥900` two-pane (list + thread) mirroring existing `MessagesScreen.splitStart=900`; `MobileCompact.bubbleMaxWidth`.
- Routes: existing `/dashboard/messages`, `/dashboard/messages/:id`; contract CTA deep-links; `PLT004 → HivorrEmptyState` 404.

## 13. User Experience Considerations

- `pending→sent` optimistic append; duplicate tap after replay returns same `id` (no double bubble).
- Offline composer preserved in Hive drafts; reconnect auto-replays in FIFO+priority order; `SyncStatusProvider` surfaces `offline/syncing`.
- Pull-refresh + resume-refresh; lifecycle pause (no background RPCs via `WidgetsBindingObserver`).
- Identical `PLT004` for foreign/unknown → 404 empty state, not auth redirect (no enumeration).
- Redacted 120-char preview in list + notification; full plaintext only after GCM verify.
- Conflict chip pattern from scheduling (`Slot taken`) reused for `PLT005`/dead-letter: `HivorrErrorState` + `Retry` / `Pick another` equivalent (`Try again`).
- Locale-aware `time()` via `lib/core/localization`; accessibility: 48dp send target, semantic labels on bubbles.

## 14. Security Considerations

| Risk | Mitigation | Verify |
|---|---|---|
| RLS leakage | Participant-only `EXISTS` + Realtime RLS-filtered; client never bypasses RPC | Non-participant `SELECT 0 rows`, `message_list PLT004`, Realtime 0 events |
| Plaintext exposure | GCM auth; `decryptText→null` hard reject → placeholder; never render `body_encrypted`; `PiiRedactor` on logs/notifications | Tamper/wrong-key unit tests; `grep body_encrypted` never in logger |
| Key handling | Keep v1 `SHA-256(prefix+contractId)`; no plaintext key persisted; no key in logs/migration | No `SecureStorage` key write in this task; document future `KeyDerivation` path |
| Replay injection | `client_message_id uuid.v4 UNIQUE` + `ON CONFLICT DO NOTHING` | Double-send → same `id`, count 1 |
| Forgery (`sender!=auth.uid()`) | `WITH CHECK (sender=auth.uid() AND EXISTS participant)` + column grants | Stranger `INSERT 42501` |
| Zero-trust client | No financial/ranking logic; no direct table writes; `SECURITY INVOKER` posture | `dart analyze` + static scan; `git diff supabase/ = 0` |

## 15. Performance Considerations

- Keyset pagination (`(score N/A, created_at DESC, id DESC)`), defaults 20/30, cap 100; cursor, not offset.
- `Index Scan` on `messages_conversation_created_idx`, `conversation_participants_entity_idx`, `messages_client_message_idx`; `LATERAL` last-preview (no N+1).
- Realtime backpressure: coalesce bursts → single page refresh; no per-event full decrypt storm; decrypt off build (async, then setState once).
- LRU thread-preview cache; Hive window avoids refetch on rotate; `const` widgets, lazy lists/slivers per `FLUTTER-UI-IMPLEMENTATION-RULES`.
- Targets: Realtime `<1s` Staging; p95 `message_list` `<400ms`; 100 concurrent subscribers no cross-talk (EP-03-04 bench reused).

## 16. Testing Strategy

- **pgTAP (reuse, no new):** `029/030` must stay green (`supabase test db --local`).
- **Unit:** `MessageCrypto` round-trip/wrong-key-null/malformed-null/blank+oversize/nonce-randomness (exists — extend); `MessagingMapper`/envelope parser/`validateText`; `previewOf` 120; `RealtimeDataSource` fake channel mapping.
- **Widget (with `widget_harness`, `FakeMessagingRepository` + real crypto):** ranked-order preserved (no client re-sort), filter state → RPC filters, empty/loading/error states, composer validation, undecryptable placeholder, `pending→sent` tick, retry on `PLT003/PLT999`, theme-token assertions (no `Colors.*`), golden mobile+web.
- **Integration:** (1) two participants exchange 3 messages via real RPCs; (2) third entity `SELECT 0` + `PLT004` + Realtime 0; (3) offline `ActionQueue` enqueue 3 → reconnect → exactly 3 rows, replay again → still 3 (`fake_async` + `connectivity_plus` mock); (4) Realtime event `<1s`; (5) deep-link `PLT004 → EmptyState`.
- **Static:** `dart analyze`, `flutter test`, `ColorScheme.primary==#2D3FE7` assertion, forbidden `financial_transactions.amount reduce` lint (earnings guard, sanity), no `dart:io` in storage path (web-safe).

## 17. Recommended Implementation Sequence

1. **Screen audit + placement decision (§7.1)** — diff dashboard screens vs Phase spec; lock single implementation path.
2. **Realtime seam** — interface + Supabase impl + DI + fake for tests; provider `subscribe/unsubscribe` + lifecycle; polling fallback preserved.
3. **Offline queue wiring** — `send` → queue on offline/transient, `drain` replay, `pending/sent/failed` UI + dead-letter `Retry`.
4. **Hive cache + drafts** — `AppBoxes.messages` + `LocalStore` window/drafts; warm-then-refresh; logout eviction.
5. **Thread/list UX completion** — cursor paging, pull-refresh, placeholders, notifications deep-link, contract CTA entry, responsive split, visual-identity pass.
6. **Test matrix + Staging validation** — unit/widget/integration/leakage/Realtime bench; `supabase test db`, `dart analyze`, `flutter test`; EP-03-20 input report.

## 18. Expected Outcome

Contract-scoped threads where verified participants converse with at-rest AES-GCM ciphertext, RLS-scoped reads, Realtime delivery, exactly-once offline replay, redacted previews, and deep-linked notifications — reusing EP-03-04 + EP-01 platform primitives with no parallel messaging system, unblocking EP-03-20 validation and EP-04 multi-party reuse.

Integration test: two participants exchange 3 messages; third cannot `SELECT` thread; offline-sent appears `pending` then `sent` after reconnect; Realtime delivers `<1s` on Staging (Phase Plan `§7: Expected Outcome`).

## 19. Definition of Done (DoD)

- [ ] Single thread implementation (no duplicate list/thread screens); dashboard routes preserved.
- [ ] `ensureForContract/listConversations/listMessages/sendText` via existing RPC seam; zero direct table writes; zero `supabase/` diff.
- [ ] AES-GCM encrypt/decrypt boundary intact; tamper → placeholder; no ciphertext/plaintext in logs/notifications (only ids + redacted 120-char preview).
- [ ] Realtime subscribe/unsubscribe lifecycle-correct; burst-safe; non-participant 0 events; polling fallback works.
- [ ] Offline queue: Hive-persisted, FIFO+priority replay, `client_message_id` dedup (double-tap = same `id`), `pending/sent/failed` + Retry UI.
- [ ] Keyset pagination, no N+1, index scans; p95 thread page `<400ms`; Realtime `<1s` Staging.
- [ ] `PLT004` foreign/unknown identical → `HivorrEmptyState` 404; `PLT003` validation → `HivorrErrorState` + guidance.
- [ ] Visual identity: `ColorScheme`/`AppThemeExtension`/`TextTheme` only; `Hivorr*` states throughout; responsive mobile + ≥900 split + web path URLs.
- [ ] Tests: unit (crypto/mapper) + widget (screens/fakes/goldens) + integration (2-party exchange, stranger blocked, offline replay, Realtime) green; `029/030` pgTAP green; `dart analyze` + `flutter test` green.
- [ ] No `lib/ai/*` ranking/message override; no financial logic in client; no new bucket/table/RPC.

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: Very High**
- **Reasoning Level Justification:** Matches approved Phase Plan `§11 EP-03-13: Planning Very High / Coding Very High`. High security risk (E2E auth, RLS leakage, PII redaction), realtime + offline divergence risk (exactly-once, dedup, backpressure), and integration complexity (4 RPCs + Realtime + queue + Hive + notifications + contract entry) with zero tolerance for plaintext/replay/duplication faults. Below `Extremely High` (reserved for escrow settlement/ranking determinism) but above `High` CRUD — Realtime/offline hybrid + cryptographic boundary demands it.

---

*Planning artifact only. Awaiting approval before implementation.*
