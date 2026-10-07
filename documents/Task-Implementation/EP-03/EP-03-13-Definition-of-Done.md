# Task Definition of Done — EP-03-13: Encrypted Messaging & Real-Time Communication System (Client)

**Task ID:** EP-03-13 | **Priority:** High | **Phase:** EP-03 Stage 5 — Trust & Coordination
**Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-13 Encrypted Messaging & Real-Time Communication System (Client).md` (§1–20)
**Dependencies:** EP-03-04 server primitive (`supabase/migrations/20260925090001_service_messaging_schema.sql` + pgTAP 029/030), EP-03-02/10 contract slice, EP-01-12 sync/offline queue, EP-01-18 notifications, EP-01-10 crypto, EP-01-16 design system

> Practical verification checklist for the project lead. No migration is included in this task — server reuse only. Mark the task completed only when every box below is checked with evidence.

---

## 1. Task Identification

- [ ] Task ID confirmed: EP-03-13
- [ ] Task Name confirmed: Encrypted Messaging & Real-Time Communication System (Client)
- [ ] Related Phase confirmed: EP-03 Stage 5 — Trust & Coordination
- [ ] Reference Implementation Plan reviewed: `EP-03-13 Encrypted Messaging & Real-Time Communication System (Client).md`
- [ ] Dependencies verified present (EP-03-04 RPCs + pgTAP 029/030 green, `ActionQueue`/`SyncEngine`/`connectivity_plus`, `SupabasePushReceiver`/`LocalNotificationService`, `AesCipher`/`MessageCrypto`, shared design system)
- [ ] No new tables / columns / RLS / RPCs / Realtime publication introduced by this task confirmed

## 2. Functional Verification

- [ ] Contract participant can ensure exactly one thread per contract via `ensureForContract(contractId)` — second call (same or opposite participant) returns same `conversation.id` (`contract_id UNIQUE 1:1`)
- [ ] Conversation list renders participant-only threads newest-first with server-redacted 120-char `lastMessagePreview` + `lastMessageAt`, keyset paging (default 20, cap 100), pull-to-refresh
- [ ] Thread renders messages oldest-first with cursor `loadEarlier` prepend (default 30, cap 100), no overlap, exhausted/unknown cursor returns empty without oracle
- [ ] Participant can send text 1–4000 chars: composer (`HivorrTextField` multiline + counter + `HivorrButton` send) → `MessageCrypto.encryptText(contractId)` → `message_send` with fresh `client_message_id uuid.v4` → decrypted echo appended
- [ ] Blank and >4000-char sends blocked client-side with inline validation; submit disabled while `isSending`
- [ ] Realtime delivery verified: `subscribe(conversationId)` on `select`, `unsubscribe` on dispose/switch; incoming `insert` coalesced into single `refresh()` (backpressure, no full-list rebuild storm); poll-on-resume fallback works when Realtime unavailable
- [ ] Offline send verified: airplane-mode / offline `send` enqueues `SyncAction{endpoint:'/rpc/message_send', payload:{conversation_id, body_encrypted, body_preview, client_message_id}}` persisted via `writeBatch` in Hive `sync_queue`; UI shows `pending` → `sent` after `SyncEngine.drain` on reconnect
- [ ] Exactly-once verified: double-tap / replay with same `client_message_id` returns same `message.id` (no double bubble, never `PLT005`)
- [ ] Hive thread persistence verified: last window + composer drafts warm UI before RPC resolves; drafts survive rotate/reconnect; cache evicted on logout; cache never treated as settlement truth
- [ ] Undecryptable rows render italic placeholder via `HivorrChatBubble(text:null)` — never renders `body_encrypted`
- [ ] Contract entry verified: `contract_detail` CTA → `ensureForContract` → `goNamed(dashboardMessageThread)`; existing routes `/dashboard/messages` + `/dashboard/messages/:id` preserved with `?next=` resume
- [ ] Notifications verified: growth while open shows local `HivorrNotification(title:'New message', body:redacted preview only, channelId:'hivorr_default', actionRoute:'/dashboard/messages/:id')`; background `message_received` push carries preview only; tap deep-links to thread
- [ ] Error handling verified:
  - [ ] `PLT003` validation (blank text, limit 0/101, empty ids) → inline error / `HivorrErrorState` with guidance, no RPC round-trip for preventable cases
  - [ ] `PLT004` foreign / unknown conversation / contract → identical `HivorrEmptyState` 404 (no existence oracle, no auth redirect)
  - [ ] `PLT001` signed-out → login resume with `?next=` preserved
  - [ ] Transport / 5xx → `pending` queued + `HivorrErrorState` retry; `4xx except 401/409` → dead-letter + `Retry` (no silent loss)
  - [ ] `anon` RPC call → `42501` (pre-grant, `anon 0 EXECUTE`)
- [ ] Important interactions verified: search filters list locally without reordering server order; date separators present; `time()` locale formatting; optimistic ticks (`pending/sent/failed`); `HivorrSnackbar` on send failure; no attachments affordance in v1

## 3. Technical Verification

- [ ] Architecture compliance: new code only as `MessagingRealtimeDataSource` interface + `SupabaseMessagingRealtimeDataSource` impl under `lib/data/datasources/remote/`, `messaging_local_data_source.dart` + `AppBoxes.messages` extension under `lib/data/datasources/local/` + `AppBoxes`, extensions to `lib/systems/communication/services/messaging_service.dart` + `lib/data/providers/messaging_provider.dart` + DI (`registerMessagingLayer`, `app.dart`); single thread UI implementation only (canonical `lib/systems/communication/screens/` + `widgets/` OR dashboard in-place — loser deleted/redirected, never two implementations)
- [ ] No other `lib/` production files modified except additive slots (dashboard hosts if retained, contract-detail CTA, router trio, `data_layer.dart`); no new top-level `lib/` dir per `ARCHITECTURE.md:39`
- [ ] All reads/writes go through `conversation_ensure_for_contract` / `conversation_list` / `message_list` / `message_send` with `MessagingEnvelopeParser.unwrap`; no `supabase.from('conversations'|'conversation_participants'|'messages')` anywhere (grep gate passes); zero `supabase/` diff (`git diff supabase/ = 0`)
- [ ] Separation of Concerns: screens consume Service/Provider only, never `SupabaseClient`/channel directly; no financial math, no ranking logic, no reveal/ordering decision in client; `lib/ai/*` untouched and never reorders messages
- [ ] Thread order rendered verbatim (server `(created_at DESC, id DESC)` reversed once for display); no client re-sort; no client-side aggregation treated as truth
- [ ] Module integration: contract offer/accept/milestone/escrow/timeline/booking CTA unbroken; dispute freeze path untouched (thread is evidence context only); 2 dashboard message routes still guarded via `route_guard.dart` (shared, no hire/offer gate)
- [ ] Visual Identity compliance: 100% `Theme.of(context).colorScheme` / `AppThemeExtension` / `TextTheme`; `HivorrButton` / `HivorrTextField` / `HivorrCard` / `HivorrListTile` / `HivorrAvatar` / `HivorrChatBubble` / `HivorrLoadingState(HivorrLoader)` / `HivorrEmptyState` / `HivorrErrorState` / `HivorrSnackbar` / `HivorrSkeleton` used; responsive via `HivorrResponsiveScaffold` / `HivorrScreenScaffold` / `HivorrContentPane` + `breakpoints.dart` (single-column mobile, ≥900 two-pane); send target ≥48dp; `Semantics` on bubbles/composer; no `Colors.*` / raw hex / per-widget `fontFamily` (grep gate passes)
- [ ] Logging / tracing: redacted logs only (ids + counts, never bodies/previews/ciphertext); `communication.*` performance spans present; `PiiRedactor` on notification bodies

## 4. Data Verification

- [ ] `Conversation` fields map 1:1 to RPC shape (`id`, `contractId`, `createdAt`, `updatedAt`, `lastMessagePreview`, `lastMessageAt`, `unreadCount=0`, `peerOnline=false`); `unreadCount`/`peerOnline` remain 0/false with TODOs intact (no faked presence/counts)
- [ ] `ConversationMessage` fields map 1:1 (`id`, `conversationId`, `senderEntityId`, `bodyEncrypted` opaque `{c,i,t}`, `bodyPreview` ≤120 redacted, `clientMessageId` uuid.v4, `createdAt`, `decryptedBody?` memory-only)
- [ ] Envelopes verified (`ConversationEnsure/List`, `MessageList{hasMore, nextCursor}`); keyset `(created_at DESC, id DESC)` with opaque cursor; limits 1–100 enforced fail-fast (`PLT003`) before RPC
- [ ] Client validation parity confirmed (non-empty ids, limit 1–100, text 1–4000 trimmed, non-empty ciphertext, non-empty `clientMessageId`) as fail-fast only; server remains authoritative
- [ ] Hive window/drafts verified per-conversation keyed, warm-then-refresh, logout eviction; no review/financial bodies persisted here; transient provider memo only besides Hive window
- [ ] No direct table `INSERT`/`UPDATE`/`DELETE` from client; `messages` treated immutable (no edit/delete affordance); resend uses same `client_message_id` dedup, not edit

## 5. Security Verification

- [ ] Authentication: `ensure/list/send` require authenticated caller with JWT refresh (`auth_interceptor`); anon path blocked (`anon 0 EXECUTE` → `42501`)
- [ ] Authorization: `sender == auth.uid()` server-derived; client sends only `conversation_id + body_encrypted + body_preview + client_message_id` (never `sender` / participant list); viewer-vs-participant checks are CTA-visibility only
- [ ] Access control (RLS reuse): non-participant direct `SELECT` returns 0 rows; `message_list` as stranger returns `PLT004` identical to unknown; Realtime channel as stranger receives 0 events while participant receives 1
- [ ] No oracle: identical `PLT004` copy for foreign / unknown contract and conversation; no `1/2` counters or `updated_at` hints in UI
- [ ] Sensitive data protection: `body_encrypted` never logged, never in push payloads, never in Sentry breadcrumbs; plaintext exists only in composer + `decryptedBody` memory; `body_preview` is 120-char redacted snippet only (`MessageCrypto.previewOf` + server `regexp_replace`); v1 key `SHA-256("hivorr-msg-v1"+contractId)` retained with no plaintext key persisted and no key in logs (future `KeyDerivation` migration documented, not executed)
- [ ] Tamper hard-reject: `decryptText` null on tamper/wrong-key/malformed → placeholder; `grep -rn body_encrypted lib/core/logging` shows no logging; `grep -rn "supabase.from('messages'\|supabase.from(\"messages\"\|from('conversations'\|from('conversation_participants'" lib/` returns zero hits
- [ ] Static security gates pass: no direct messaging table I/O, no client-side settlement/ranking logic, `SECURITY INVOKER/DEFINER` posture unchanged (029/030 green)

## 6. Performance Verification

- [ ] `conversation_list` issued at most once per list entry + pull-to-refresh; `message_list` paged (no unbounded fetch); Realtime bursts coalesced to one `refresh()`; no polling loop besides resume-refresh; lifecycle pause stops background RPCs (`WidgetsBindingObserver`)
- [ ] Thread decrypts off build then single `notifyListeners`; `ListView.builder` (never unbounded `Column`); `const` constructors and scoped `read`/`Selector` (no whole-tree `watch`); LRU preview cache for list snippets
- [ ] Index usage confirmed on Staging: `EXPLAIN` shows `Index Scan` on `messages_conversation_created_idx`, `conversation_participants_entity_idx`, `messages_client_message_idx`; `LATERAL` last-preview (no N+1)
- [ ] Staging targets observed: Realtime insert → peer callback p95 <1s; `message_list` page p95 <400ms; 100 concurrent `messages:conv_id` subscribers with no cross-talk and no dropped events (EP-03-04 bench reused)

## 7. Testing Verification

- [ ] Manual testing: two-account staging E2E completed (C ensures → P ensures same id → C sends → P receives Realtime <1s → P replies → C sees oldest-first order); stranger isolation probe (0 rows + `PLT004` + 0 Realtime events); airplane-mode 3-message queue → reconnect exactly 3 rows → replay again still 3; throttled-network send retry sanity; deep-link foreign vs unknown both 404
- [ ] Automated unit tests (`test/unit/communication/*`) green: crypto round-trip / wrong-key-null / malformed-null / blank+oversize / nonce-randomness; `validateText` (blank → false; 1/4000 → true; 4001 → false); `previewOf` 120 truncation; mapper null/preview/ciphertext coercions; envelope `PLT000` unwrap vs `PLT003/004` throw; Realtime fake channel mapping + unsubscribe
- [ ] Automated widget tests (`test/widget/communication/*`) green: list loading/empty/error + retry; thread paging prepend with no overlap; composer gates (blank blocks, 4001 blocks, valid submits); undecryptable placeholder asserted (ciphertext absent); `pending→sent` tick + failed retry; theme-token assertion; mobile + ≥900 split goldens; semantics labels present
- [ ] Automated integration tests (`test/integration/*messaging*`) green: 3-message exchange via real RPCs with GCM verify; stranger `SELECT 0` + `PLT004` + Realtime 0; offline `ActionQueue` enqueue 3 (`fake_async` + `connectivity_plus` mock) → reconnect exactly 3 → idempotent replay still 3; Realtime event <1s; `PLT004` deep-link → `EmptyState`
- [ ] Host regression green: existing `contract_detail` (CTA unbroken) + dashboard suites + notification deep-link suites; `supabase test db --local` 029/030 remain green (not re-run here beyond guard; client introduces no DDL)
- [ ] Router tests green: both message routes require auth (redirect `?next=`); foreign id → not-found; notification tap lands on `/dashboard/messages/:id`
- [ ] Static checks green: `dart analyze`, `flutter test`, `grep -rn 'Colors\.\|Color(0x' lib/systems/communication lib/data/datasources/{remote/messaging*,local/messaging*}` (zero hits), direct messaging table I/O grep (zero hits), `dart:io` in messaging/storage path grep (zero hits for web-safety)
- [ ] Edge cases covered: `body_preview` NULL vs 120 truncation; `p_cursor` unknown → empty no-oracle; `disputed` contract thread still readable (no `PLT005` gate on messaging); concurrent ensure same id; concurrent same `client_message_id` single row; lifecycle backgrounded pauses refresh; logout evicts Hive window/drafts
- [ ] Failure scenarios covered: transport failure queued then replayed; dead-letter shows retry (no crash); duplicate tap returns same id; tampered row shows placeholder (no plaintext fallback)

## 8. User Acceptance Verification

- [ ] Client and professional each complete ensure → list → thread → send → Realtime-receive → offline-replay flows on real devices (mobile + web) with calm loading / empty / error / `pending` states
- [ ] Composer operable by touch, keyboard, and screen reader with ≥48dp send target and visible counter
- [ ] List shows truthful redacted previews only; full text only post-GCM-verify in thread; `No conversations yet` otherwise
- [ ] Honest privacy copy verified: participant-only stated; no presence/read-receipt claims observable (badges/dots hidden per TODOs)
- [ ] Unreliable-network acceptance (Nigeria profile): airplane-mode compose preserved, reconnect auto-replays in FIFO+priority order with `offline/syncing` status visible
- [ ] Server pgTAP suites 029/030 remain green (this task's proof is client non-bypass + stranger isolation, not DDL)

## 9. Final Approval Checklist

- [ ] All Functional (§2), Technical (§3), Data (§4), Security (§5), Performance (§6), Testing (§7), and UAT (§8) boxes checked with evidence (test runs, screenshots, staging walkthrough for EP-03-20 input)
- [ ] `flutter test` green; `dart analyze` clean; all static grep gates pass
- [ ] No `supabase/migrations/*` added or altered; no new bucket/RPC/table; single thread implementation confirmed
- [ ] No hardcoded colors / fonts; no direct table access; no client-side settlement/ranking/message-order logic
- [ ] Project lead sign-off recorded; task may be marked completed
