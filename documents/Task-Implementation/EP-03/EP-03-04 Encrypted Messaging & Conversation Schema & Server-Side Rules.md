# Task Implementation Plan — EP-03-04: Encrypted Messaging & Conversation Schema & Server-Side Rules

**Task ID:** EP-03-04 | **Priority:** High | **Status:** Completed | **Phase:** EP-03 Stage 1 — Marketplace Server Schema Foundation (parallelizable after EP-03-02)
**Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:279-288` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173` + `documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31`

---

## 1. Task Objective

Deliver the **contract-scoped encrypted messaging fabric** that EP-03-13 and all future EP-04 multi-party threads reuse. This is a **server-only** migration:

*   **3 tables:** `conversations` (`contract_id uuid UNIQUE -> service_contracts.id CASCADE`), `conversation_participants` (`conversation_id -> conversations CASCADE`, `entity_id -> entities CASCADE`, `PK (conversation_id, entity_id)`), `messages` (`conversation_id -> conversations CASCADE`, `sender_entity_id -> entities RESTRICT`, `body_encrypted text NOT NULL`, `body_preview text CHECK <=120`, `client_message_id uuid UNIQUE`, `created_at`)
*   **4 RPCs `SECURITY INVOKER` envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999` per `supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19`):** `conversation_ensure_for_contract(p_contract_id uuid)`, `message_send(p_conversation_id uuid, p_body_encrypted text, p_body_preview text, p_client_message_id uuid)`, `conversation_list(p_limit int, p_cursor uuid)`, `message_list(p_conversation_id uuid, p_limit int, p_cursor uuid)` — all `VOLATILE` (write) / `STABLE` (read), `REVOKE EXECUTE FROM public` + narrow `GRANT EXECUTE` (`anon 0`, `authenticated/service_role`), `COMMENT ON FUNCTION`×4
*   **Full RLS default-deny** (`supabase/migrations/20260819090001_enforcement_foundation.sql:18-26`) — participant-only `SELECT/INSERT` via `EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = id AND entity_id = auth.uid())` pattern; `messages SELECT` joins participant check; `service_role` bypass
*   **Realtime publication on `messages`** — `ALTER PUBLICATION supabase_realtime ADD TABLE public.messages` (RLS-filtered), guarded `DO $$` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:799-816` / `20260921090001_service_marketplace_schema.sql:741-754` precedent). `conversations`/`conversation_participants` remain excluded. Leverages `lib/core/notifications/push/supabase_push_receiver.dart:18-34` `onPostgresChanges(filter: eq('conversation_id', ...))` seam
*   **At-rest encryption:** `body_encrypted` stores opaque ciphertext `EncryptedPayload.toJson() {c,i,t} bas64` produced by `lib/core/security/crypto/aes_cipher.dart:54-62` `AesCipher.defaultInstance.encryptString` with per-conversation `SecretKey` derived via `lib/core/security/crypto/key_derivation.dart:29-48` `KeyDerivation.fromConfiguration`. Server validates `body_encrypted IS NOT NULL` + length; `body_preview` truncated 120 + redacted via `lib/core/logging/pii_redactor.dart:92-102` `PiiRedactor.redact` server-side mirror
*   **2 pgTAP suites:** `029_service_messaging_schema_posture.sql` + `030_service_messaging_rpc_enforcement.sql` (`supabase/tests/database/027_service_review_schema_posture.sql:14-326` pattern)
*   **Zero mutation** of `entities`/`service_listings`/`service_contracts`/`service_reviews`/`financial_*`

Unblocks `EP-03-13` (`lib/systems/communication/services/messaging_service.dart` + `lib/data/datasources/remote/supabase_messaging_remote_data_source.dart` + `ActionQueue` offline replay) and is reused by EP-04 3-party threads without schema change (new `conversation_type` seed, not migration).

## 2. Business Problem Being Solved

EP-03-02 proved `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43-67` `offered->active->closed`) and EP-03-01 proved `service_listings` + `financial_escrow` linkage, but **no private negotiation channel exists**:

*   No `conversations` 1:1 per `service_contracts.id` — `EP-03 Plan:138` `conversations.scoped to contract/service participants` has no FK target; `EP-03-13` `conversation_ensure_for_contract` has no table
*   No participant-scoped `messages` — direct `SELECT * FROM messages` would leak PII to non-participants (`Plan:179` high risk: `Message RLS leakage`)
*   No encrypted-at-rest `body_encrypted text` — plaintext `body text` would violate `AGENT.md:6` Rule 4 (`DB-First Logic & Zero-Trust Client`) and `lib/core/security/crypto/aes_cipher.dart:46-53` defense-in-depth where `flutter_secure_storage` is not OS-encrypted on Web
*   No `client_message_id uuid UNIQUE` — `lib/core/sync/action_queue.dart` `ActionQueue.enqueue(SyncAction{endpoint:'/rpc/message_send', payload:{client_message_id: uuid.v4()}})` (`uuid:4.5.1` + `connectivity_plus:6.1.0` `EP-01-12`) has no dedup key; Nigeria unreliable connectivity would produce duplicate messages on reconnect (`Plan:183`)
*   No `body_preview 120` — `lib/core/notifications/services/notification_service.dart` + `lib/core/notifications/channels/notification_channel_manager.dart` `hivorr_messages` channel (`EP-01-18`) has no redacted preview for push; logging would leak PII to `SentryLogSink` via `lib/core/logging/pii_redactor.dart` breach
*   No Realtime RLS-filtered subscription — polling would miss the `<1s` staging delivery target (`Plan:286`)

Without this, trust negotiation (contract offer/accept, milestone evidence discussion, dispute context) leaks or loses messages.

## 3. Scope

| In Scope | Detail |
|---|---|
| `conversations` | `id uuid PK gen_random_uuid()`, `contract_id uuid NOT NULL UNIQUE -> service_contracts(id) ON DELETE CASCADE`, `created_at timestamptz DEFAULT now()`, `updated_at timestamptz DEFAULT now()` + `platform_set_updated_at()` trigger, `created_by uuid DEFAULT auth.uid()`, `CHECK contract_id IS NOT NULL`, comment, indexes `contract_id UNIQUE`, `created_at` |
| `conversation_participants` | `conversation_id uuid -> conversations CASCADE`, `entity_id uuid -> entities CASCADE`, `joined_at timestamptz DEFAULT now()`, `last_read_at timestamptz`, `PK (conversation_id, entity_id)`, `CHECK conversation_id IS NOT NULL`, comment, indexes `(entity_id, joined_at)`, `(conversation_id)` |
| `messages` | `id uuid PK`, `conversation_id uuid -> conversations CASCADE`, `sender_entity_id uuid -> entities RESTRICT`, `body_encrypted text NOT NULL CHECK (char_length(btrim(body_encrypted)) BETWEEN 20 AND 8000)`, `body_preview text CHECK (body_preview IS NULL OR char_length(body_preview) <= 120)`, `client_message_id uuid UNIQUE NOT NULL DEFAULT gen_random_uuid()`, `created_at timestamptz DEFAULT now()`, `CHECK client_message_id IS NOT NULL` — **no `updated_at`** (immutable), no `platform_set_updated_at` (mirrors `financial_transactions:417` / `contract_events:150`, `service_favorites:265`) |
| RLS + grants | `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL FROM anon, authenticated, service_role` (`20260819090001:18-26` posture) then narrow `GRANT SELECT` on `conversations` to `authenticated`, `SELECT, INSERT` on `conversation_participants`/`messages` to `authenticated`, full to `service_role`, `anon 0`; 6 policies (2+2+2) participant-scoped via `EXISTS` join |
| Realtime | Guarded `DO $$ ALTER PUBLICATION supabase_realtime ADD TABLE public.messages` (idempotent, `IF NOT EXISTS` via `pg_publication_tables`), `DO $$ DROP TABLE` guards for `conversations`/`conversation_participants` (`20260924090001:741-754` pattern inverted for `messages`) |
| RPC `conversation_ensure_for_contract` | `p_contract_id uuid` -> `VOLATILE` `SECURITY INVOKER` — validates `service_contracts` participant (`client OR professional = auth.uid()` identical `PLT004` for foreign/unknown per `20260923090001:811-828` `service_contract_get`), `INSERT INTO conversations(contract_id) ON CONFLICT (contract_id) DO NOTHING RETURNING id` + `INSERT INTO conversation_participants(conversation_id, entity_id) VALUES (v_conversation_id, v_client), (v_conversation_id, v_professional) ON CONFLICT DO NOTHING`, returns `{conversation, participants[]}` envelope |
| RPC `message_send` | `p_conversation_id uuid, p_body_encrypted text, p_body_preview text DEFAULT NULL, p_client_message_id uuid DEFAULT gen_random_uuid()` -> `VOLATILE` — `platform_is_authenticated() PLT001`, `EXISTS participation PLT004`, `body_encrypted NOT NULL 20-8000 PLT003`, `client_message_id NOT NULL PLT003`, foreign prefix not needed (ciphertext opaque), computes `v_preview := left(nullif(btrim(p_body_preview),''),120)` + SQL `regexp_replace` PII redaction mirroring `lib/core/logging/pii_redactor.dart:42-73` (email `***@***.***`, phone `***`, bearer `Bearer ***`), `INSERT ... ON CONFLICT (client_message_id) DO NOTHING RETURNING ...` dedup, returns `{message, conversation_id}`; audit log `platform_audit_log_add` |
| RPC `conversation_list` | `(p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` -> `STABLE` — participant-scoped keyset `(created_at DESC, id DESC)` via `conversation_participants` join + `LATERAL` last message `body_preview`, `has_more/next_cursor`, unknown cursor `[]` no oracle (`20260921090001:1141-1159` `service_listing_list_mine` pattern) |
| RPC `message_list` | `(p_conversation_id uuid, p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` -> `STABLE` — `EXISTS participation PLT004`, keyset `(created_at DESC, id DESC)` (`messages` index `conversation_id, created_at DESC, id DESC`), `has_more/next_cursor`, returns `body_encrypted` opaque + `body_preview` + `sender_entity_id` |
| pgTAP `029` posture | `has_table 3`, `relrowsecurity 3`, `anon 0 INSERT/UPDATE/DELETE`, `authenticated SELECT 1 / INSERT 2`, `UNIQUE(contract_id)`, `PK(conversation,entity)`, `UNIQUE(client_message_id)`, `CHECK 20-8000 / <=120`, `GIN` not needed, `4 RPCs jsonb`, `prosecdef 0`, `Realtime 1 for messages 0 for others`, `comments 3`, `EXECUTE anon 0 authenticated 4 service_role 4`, `5?6 policies` |
| pgTAP `030` enforcement | `anon 42501` on 4 RPCs, `authenticated PLT001/003/004/005`, `stranger PLT004` identical for foreign/unknown `conversation_id`, `body_encrypted NULL PLT003`, `client_message_id duplicate idempotent PLT000 not PLT005`, `offline replay second call returns same id`, `RLS leakage matrix` non-participant `SELECT 0 rows` |
| Helper reuse | `platform_is_authenticated() 20260819090001:37`, `platform_raise_error 20260819090001:68`, `platform_set_updated_at 20260819090001:54`, `platform_audit_log_add 20260819090003:388` |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| `availability_slots/appointments` | `EP-03-05` (`Plan:138`) — separate `gist EXCLUDE` race, not messaging |
| `service_reviews/aggregates` | `EP-03-03` (`20260924090001:52-136`) — already delivered; messaging has no rating dependency |
| Deterministic ranking `service_ranking_search` / `service_search` FTS | `EP-03-06/07` (`Plan:138-140`) — consumes `service_listings.search_vector`, not conversations |
| Any `lib/systems/communication/*` Dart (`messaging_service.dart`, `screens/conversation_*.dart`, `supabase_messaging_remote_data_source.dart`) | `EP-03-13` (`Plan:144`); this task is server-only, client slice needs `ActionQueue`/`Realtime` seam |
| `service-listing-media` new bucket / `message_attachments` bucket | No attachment in EP-03-04; if later needed reuse `storage.objects foldername[1]=auth.uid()` + `lib/core/storage/storage_paths.dart` `sanitize()` (`EP-02-06 20260830100001:51-55`) — not in this migration |
| `notification_events` table / Edge Function `escrow_milestone_auto_release` | `EP-03-11/18` scope; messaging notification is `messages` Realtime + `NotificationChannelManager.createChannel(id:'hivorr_messages')` client-side; no new `notification_events` DDL here |
| `lib/ai/*` intelligence | Excluded from EP-03 (`Plan:106`, `AGENT.md:7`) — AI may never reorder messages |
| Mutation of `service_contracts`/`service_listings`/`entities`/`professions`/`industries`/`financial_*` | Finalized EP-01/02/03-01-03; referenced, not altered |

## 5. Existing Asset and Dependency Analysis

| Asset | Location | State | Reuse Verdict for EP-03-04 |
|---|---|---|---|
| `service_contracts(id, client_entity_id, professional_entity_id)` | `supabase/migrations/20260923090001_service_contract_schema.sql:43-67` (`20260923090001:43`) | Implemented (`025/026` pgTAP 29/88 pass) | **Reuse** `FK conversations.contract_id UNIQUE -> service_contracts ON DELETE CASCADE` — messaging derives participants without storing role |
| `entities(id)` / `entity_profiles` / `entity_professions` | `supabase/migrations/20260821090002_entity_core_tables.sql:20-256` | Implemented (`EP-01-06`) | **Reuse** `conversation_participants.entity_id -> entities` + `messages.sender_entity_id -> entities` + `auth.uid()` participant check |
| `lib/core/security/crypto/aes_cipher.dart:54-102` `AesCipher` + `EncryptedPayload{c,i,t}` `cryptography:2.7.0` | `lib/core/security/crypto/aes_cipher.dart:12-26` | Implemented (`EP-01-10`) | **Reuse** client encrypts `body_encrypted text` before `message_send`; server stores opaque JSON, validates length `20-8000`, never attempts `decrypt` (no key on server) |
| `lib/core/security/crypto/key_derivation.dart:15-48` `KeyDerivation.fromConfiguration(SecurityConfiguration)` + `generateRandomSecret()` | `lib/core/security/crypto/key_derivation.dart:29-48` | Implemented (`EP-01-10`, `lib/core/security/security_config.dart` reads `EnvironmentConfig` `kdfSalt/Iterations/KeyLength` `EP-01-03`) | **Reuse** per-conversation `deriveKey(passphrase = persisted SecureStorage secret + conversation_id)` — forward-compatible, no hardcoded keys, no plaintext persisted via `lib/core/security/crypto/aes_cipher.dart:46-53` defense |
| `lib/core/logging/pii_redactor.dart:42-150` `PiiRedactor.defaultPatterns` `redact()` + `redactContext()` | `lib/core/logging/pii_redactor.dart:24-73` | Implemented (`EP-01-14`) | **Reuse** client `PiiRedactor.redact` on `body_preview` before `message_send`; server mirrors with SQL `regexp_replace(email:'***@***.***', phone:'***', bearer:'Bearer ***', jwt:'***', account:'***')` for `messages.body_preview` stored 120-char, and before `HivorrLogger`/`SentryLogSink` never logs `body_encrypted` |
| `lib/core/sync/action_queue.dart` `ActionQueue.enqueue(SyncAction{type:create, endpoint:'/rpc/message_send', method:'POST', payload:{client_message_id: uuid.v4()}, priority:0-10})` + `sync_action.dart` `priority/createdAt` FIFO + `sync_engine.dart` `connectivity_plus_provider.dart` `connectivity_plus:6.1.0` | `lib/core/sync/action_queue.dart` (`EP-01-12`) | Implemented (`fake_async:1.3.1` tests) | **Reuse** offline send queue — `messages.client_message_id uuid UNIQUE` + `INSERT ... ON CONFLICT (client_message_id) DO NOTHING` deduplicates `SyncEngine` replay after `connectivity_plus` reconnect; `uuid:4.5.1` already pinned, `hive:2.2.3` `sync_queue` box persists via `lib/core/database/storage_engine.dart` `writeBatch` atomic |
| `lib/core/notifications/*` (`services/notification_service.dart`, `push/supabase_push_receiver.dart:18-34` `SupabasePushRealtimeGateway.subscribe(entityId, onPostgresChanges filter: eq('entity_id',...))`, `channels/notification_channel_manager.dart`, `models/hivorr_notification.dart` `channelId:'hivorr_messages'` `NotificationPriority.high`) | `lib/core/notifications/` 13 files (`EP-01-18`, `flutter test 42 passed` `flutter_local_notifications:18.0.0`) | Implemented | **Reuse** `message_send` post-commit triggers `SupabasePushReceiver.onMessage` -> `LocalNotificationService.show(HivorrNotification(channelId:'hivorr_messages', title:'New message', body:body_preview redacted, payload:{conversation_id, client_message_id}, actionRoute:'/messages/:id'))`; `NotificationChannelManager.createChannel` Android `IMPORTANCE_HIGH` |
| `lib/core/api/api_client/error_interceptor.dart` + `exceptions/api_exception.dart` `ApiExceptionKind` + `data/datasources/remote/data_exception_mapper.dart` `code.startsWith('PLT')?honor: details P0001 PLT###` | `lib/core/api/` `lib/data/datasources/remote/` | Implemented (`EP-01-07`, `EP-01-08`) | **Reuse** envelope `{success,code,message,data}` (`20260829100004:17` + `20260819090001:68`) via `BaseApiService.invoke` + `Dio 5.11.0` + `supabase_flutter:2.17.2` `PostgrestException.code` mapping `401 PLT001,404 PLT004,409 PLT005,400 PLT003,5xx PLT999` |
| `lib/core/storage/storage_service.dart` `StorageService.upload/download` + `supabase_storage_service.dart` + `storage_paths.dart sanitize()` + `storage_validators.dart` | `lib/core/storage/` (`EP-02-06/08`) | Implemented | **Not needed** for EP-03-04 (text-only); reserve for future `message_attachments` bucket with `storage.foldername(name)[1]=auth.uid()::text` (`20260830100001:112-204` pattern) |
| `lib/app/router/app_router.dart` / `route_paths.dart` `/p/:profession_slug/:entity_id` + `lib/shared/widgets/hivorr_*` + `HivorrContentPane` `VISUAL-IDENTITY.md:44-80` | `lib/app/router:EP-01-15` `lib/shared:EP-01-16` | Implemented | **Not in scope** (server-only); EP-03-13 messaging screens will reuse `HivorrCard/Button/EmptyState/ErrorState/LoadingState(HivorrLoader)` + `ThemeExtension` tokens — no hardcoded `Colors.*` |
| `supabase/migrations/*` ordering 33 files ending `20260924090001_service_review_schema.sql:1-754` | `supabase/migrations/` | Implemented (current tip `20260924090001`) | **Extend** ordering: EP-03-04 migration `20260925090001_service_messaging_schema.sql` immediately after `20260924090001`; `IF NOT EXISTS`/`DROP IF EXISTS`/`CREATE OR REPLACE` idempotent, no prior DDL |
| `supabase/tests/database/*` 26 files `001`→`028` pgTAP `plan 29/88` `supabase test db` `postgres:15.8.1` `realtime:v2.129.0` | `supabase/tests/database/` `.github/workflows/database-rls-tests.yml` | Implemented | **Extend** with `029_service_messaging_schema_posture.sql` + `030_service_messaging_rpc_enforcement.sql` replicating `027/028` assertions |

**Existing messaging assets inspected:** `grep -rn "conversation|message" supabase/migrations/*.sql lib/**/*` ⇒ **0 tables** — `lib/systems/communication/.gitkeep` empty, `supabase/migrations` creates only `industries, professions, entities×7, verification_*, financial_*, dispute_cases, portfolio_items, service_listings/media/favorites, service_contracts/milestones/events, service_reviews/aggregates`. Conclusion: no collision, green-field.

## 6. Reuse / Extension / Refactoring Assessment

| Proposed Asset | Assess: Reuse / Extend / Refactor / New | Why Not Reuse/Extend Existing + Why New Is Necessary | Future Reuse Design |
|---|---|---|---|
| `conversations` table (`contract_id UNIQUE -> service_contracts`) | **New** | No existing conversation/table satisfies 1:1 contract binding. `service_contracts` (`20260923090001:43`) is the engagement atom but has no thread; `contract_events` (`20260923090001:150`) is append-only audit, not chat. `entities`/`service_listings` cannot host chat. Creating `conversations` as standalone would duplicate participant derivation; binding to `service_contracts` reuses the universal 2-party primitive per `Engineering-Execution-Generation-Principle.md:57-58` (taxonomy universal, no schema change for new industry). | Designed as reusable platform primitive: `conversations(contract_id UNIQUE)` is generic 2-party thread. EP-04 3-party needs only `conversation_type` enum seed or `conversation_participants` 3rd row, not new table. `FK ON DELETE CASCADE` preserves engagement atom lifecycle |
| `conversation_participants` `(conversation_id, entity_id) PK` | **New** | No existing participant set. `entity_professions`/`entity_roles` map professions, not thread membership. `service_contracts.client/professional` are source but not RLS-filterable for `messages`. A new join table is mandatory for `messages SELECT USING (EXISTS SELECT 1 FROM conversation_participants WHERE ... auth.uid())` (`Plan:179` leakage mitigation). | EP-04 adds third participant row (`merchant`/`rider`) via same PK, no migration. Supports `last_read_at` for unread counts reused by future read-receipts |
| `messages` `body_encrypted text` + `body_preview 120` + `client_message_id uuid UNIQUE` | **New** | No existing message store. `contract_events.details jsonb` is audit, not encrypted chat. `service_reviews.comment` (`20260924090001:67`) is blind-until-reveal, not realtime. `financial_audit_trail` ledger is immutable financial, not conversational. Must store opaque ciphertext via `lib/core/security/crypto/aes_cipher.dart:12-26` `EncryptedPayload{c,i,t}` (non-deterministic IV per `20260924090001` does not apply). `client_message_id` dedup mirrors `lib/core/sync/action_queue.dart` `SyncAction.id uuid.v4()` — no prior table has this. | `body_encrypted text 20-8000` + `body_preview 120` + `client_message_id UNIQUE` pattern is reusable for any future `lib/systems/communication` voice transcript, EP-04 order chat, or support tickets. `INSERT ... ON CONFLICT DO NOTHING` guarantees idempotent `ActionQueue` replay. |
| `conversation_ensure_for_contract` / `message_send` / `conversation_list` / `message_list` RPCs | **New** | No existing RPC creates participant-scoped threads. `service_contract_get` (`20260923090001:788-850`) is `STABLE` participant read but not thread; `service_review_submit` (`20260924090001:219-344`) is `VOLATILE` with `FOR UPDATE` double-credit guard but different domain. Reusing them would conflate review audit with chat RLS. New RPCs are `SECURITY INVOKER` (`prosecdef=0` per `027:202-226`) with `platform_is_authenticated()` + `platform_raise_error` envelope (`027:242` `PLT000` success). | 4 RPCs follow the `lib/data/datasources/remote/*_envelope_parser.dart` seam (`EP-01-08`) — `supabase_messaging_remote_data_source.dart` will be the single client seam,mirroring `supabase_taxonomy_remote_data_source.dart`. Signatures include `p_client_message_id uuid` for `uuid:4.5.1` idempotency, paginated `p_limit 1-100` + `p_cursor uuid` keyset `(created_at DESC, id DESC)` (`Plan:55` no N+1, `p95 <400ms`). |
| `AesCipher`/`KeyDerivation`/`PiiRedactor`/`ActionQueue`/`SupabasePushReceiver` | **Reuse** (no new crypto/sync/notification code) | Existing `lib/core/security/crypto/aes_cipher.dart:54` `AesGcm.with256bits()` + `key_derivation.dart:29` `Pbkdf2(Hmac.sha256(), iterations, bits)` + `lib/core/security/security_config.dart` `EnvironmentConfig` are sufficient; creating new crypto would duplicate `EP-01-10` `cryptography:2.7.0` + `crypto:3.0.3` and risk hardcoded keys (`AGENT.md:6` Proprietary Logic). `PiiRedactor` already covers `email/phone/bearer/jwt/accountNumber` (`20260924090001` does not need new patterns). | Keep crypto abstraction provider-agnostic per `ARCHITECTURE.md:112-113` (`lib/integrations/payment_gateways/` precedent). Messaging imports only `lib/core/security/crypto/*` + `lib/core/logging/*`, never `lib/ai/*` (`Plan:106`). |
| Realtime publication `supabase_realtime` | **Extend** (add `messages`) | All prior migrations (`20260829090003:799`, `20260921090001:741`, `20260923090001:953`, `20260924090001:741`) **drop** tables from `supabase_realtime` (count 0 assertion in `027:240`). Messaging is the first to require Realtime-in (`Plan:179` `Realtime subscription is RLS-filtered`). Extending publication with `ADD TABLE public.messages` (guarded `IF NOT EXISTS` via `pg_publication_tables`) is additive and idempotent; no refactor of existing `DROP` guards. | Future EP-04 logistics `real-time delivery tracking` reuses same `supabase_realtime` + RLS-filtered `ON UPDATE` via `supabase_flutter` `channel.onPostgresChanges(event: update)` |

## 7. Recommended Technical Approach

### 7.1 Single SQL Migration — `supabase/migrations/20260925090001_service_messaging_schema.sql` (immediately after `20260924090001_service_review_schema.sql:1`)

Strict order (mirrors `20260924090001:49-754` + `20260923090001:40-965`):

1. Header block — EP-03-04 execution model `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, 1:1 `contract_id UNIQUE` rationale, `body_encrypted` opaque ciphertext via `AesCipher` (`lib/core/security/crypto/aes_cipher.dart:46-53`), `client_message_id` dedup for `ActionQueue`, `body_preview 120` via `PiiRedactor` (`lib/core/logging/pii_redactor.dart:42-73`), RLS participant `EXISTS` (`Plan:179`), grants, Realtime `ADD messages`
2. DDL `conversations` (`UNIQUE(contract_id)`, FK `CASCADE`, indexes, `platform_set_updated_at()` trigger, `COMMENT ON TABLE/COLUMN`)
3. DDL `conversation_participants` (`PK (conversation_id, entity_id)`, FKs `CASCADE`, indexes, no `updated_at` trigger — `last_read_at` is `updated_at` itself, but `platform_set_updated_at()` not needed since row is not updated except `last_read_at`; add trigger on `last_read_at`? Keep simple: no trigger, update via RPC)
4. DDL `messages` (`CHECK body_encrypted 20-8000`, `CHECK body_preview <=120`, `UNIQUE(client_message_id)`, FKs `CASCADE/RESTRICT`, indexes `conversation_id, created_at DESC`, `sender_entity_id`, `client_message_id`, comments — **no `updated_at` trigger** (immutable)
5. `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL FROM anon, authenticated, service_role` + narrow `GRANT SELECT` / `SELECT,INSERT` + `SELECT,INSERT,UPDATE,DELETE` to `service_role` + `UPDATE(last_read_at)` on `conversation_participants` to `authenticated`
6. 6 RLS policies (2 per table: `select` + `insert`/`update`) participant-scoped via `EXISTS` join (see §8.3)
7. 4 RPCs `SECURITY INVOKER` (`VOLATILE` `ensure/send`, `STABLE` `list/message_list`) `set search_path=public`
8. `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + 4× `GRANT EXECUTE authenticated,service_role` (`anon 0`) + `COMMENT ON FUNCTION`×4
9. Realtime `DO $$` — `ADD TABLE public.messages` if not in `pg_publication_tables`, `DROP TABLE public.conversations, conversation_participants` if present (mirrors `20260829090003:799` guard)
10. Posture comment block

**No DDL on prior tables** — only additive `GRANT UPDATE(last_read_at)` none, additive `GRANT INSERT` on new tables.

### 7.2 Execution Model: `SECURITY INVOKER` (No New `SECURITY DEFINER`)

All 4 RPCs `SECURITY INVOKER` — RLS applies inside body. Complies with `supabase/tests/database/027_service_review_schema_posture.sql:202-226` posture (`prosecdef 1` only for `service_review_reveal_if_ready` `pg_catalog,public` pinned; messaging has `0`, `008_full_schema_posture_audit.sql` stays green). `AGENT.md:6` Rule 4: client is unprivileged; `authenticated` caller rolls back on `PLT` violation.

| RPC | `anon` | `authenticated` | `service_role` | Gate |
|---|---|---|---|---|
| `conversation_ensure_for_contract(p_contract_id uuid)` | — (42501) | `EXECUTE` (participant) | `EXECUTE` | `platform_is_authenticated() PLT001`, `service_contracts` participant `client OR professional = auth.uid()` identical `PLT004` for foreign/unknown (no oracle `20260923090001:811`), idempotent `ON CONFLICT (contract_id) DO NOTHING` |
| `message_send(p_conversation_id uuid, p_body_encrypted text, p_body_preview text, p_client_message_id uuid)` | — | `EXECUTE` (participant sender) | `EXECUTE` | `authenticated`, `EXISTS conversation_participants PLT004`, `body_encrypted NOT NULL 20-8000 PLT003`, `client_message_id NOT NULL PLT003`, `sender_entity_id=auth.uid()` `INSERT`, `ON CONFLICT (client_message_id) DO NOTHING` idempotent `PLT000` second replay, `body_preview left 120 + regexp_replace` PII (`lib/core/logging/pii_redactor.dart:42-73`) |
| `conversation_list(p_limit int, p_cursor uuid)` | — | `EXECUTE` (own) | `EXECUTE` | `authenticated`, `p_limit 1-100 PLT003`, `p_cursor` participant `EXISTS` else `[]` no oracle (`20260921090001:1141`), keyset `(created_at DESC, id DESC)` via `conversation_participants` join + `LATERAL` last `messages` |
| `message_list(p_conversation_id uuid, p_limit int, p_cursor uuid)` | — | `EXECUTE` (participant) | `EXECUTE` | `authenticated`, `EXISTS participation PLT004`, `p_limit 1-100 PLT003`, keyset `(created_at DESC, id DESC)` via `messages_conversation_created_idx` `Index Scan`, unknown `p_cursor` `[]` |

`anon` EXECUTE `0/4` (no public messaging, mirrors `service_contracts` `20260923090001:924-931` `anon 0`; contrast `service_listing_get` `20260921090001` anon 1 and `service_review_get_for_listing` `20260924090001:727` anon 1 which are public).

### 7.3 Encryption-at-Rest Validation

```sql
-- messages body_encrypted is opaque ciphertext JSON {c,i,t} base64 from AesCipher
-- Server never decrypts; validates presence and bounds only
IF p_body_encrypted IS NULL OR btrim(p_body_encrypted)='' THEN
  PERFORM public.platform_raise_error('PLT003','Message body is required.');
END IF;
IF char_length(p_body_encrypted) NOT BETWEEN 20 AND 8000 THEN
  PERFORM public.platform_raise_error('PLT003','Invalid encrypted payload size.');
END IF;
-- client_message_id RFC4122 uuid v4 from uuid:4.5.1
IF p_client_message_id IS NULL THEN
  PERFORM public.platform_raise_error('PLT003','Client message id is required.');
END IF;
-- body_preview: left 120 + PII redaction mirroring Dart PiiRedactor
v_preview := left(nullif(btrim(p_body_preview),''), 120);
IF v_preview IS NOT NULL THEN
  v_preview := regexp_replace(v_preview, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '***@***.***','g');
  v_preview := regexp_replace(v_preview, '\+?234[\s-]?\d{3}[\s-]?\d{3}[\s-]?\d{4}', '***-****-****','g');
  v_preview := regexp_replace(v_preview, 'Bearer\s+\S+', 'Bearer ***','g');
  v_preview := regexp_replace(v_preview, 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '***','g');
  v_preview := regexp_replace(v_preview, '\b\d{10}\b', '***','g');
END IF;
```

`messages.body_encrypted` column excluded from `PiiRedactor` logging via `HivorrLogger` `redactContext` — `lib/core/logging/pii_redactor.dart:106-120` `sensitiveKeyNames` never logs `body_encrypted`.

### 7.4 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001_enforcement_foundation.sql:37-43` | Auth gate on 4 RPCs |
| `platform_current_user_id()` | `20260819090001:45-51` | `auth.uid()` alias |
| `platform_set_updated_at()` | `20260819090001:54-62` | `updated_at` trigger on `conversations` only (mutable); `conversation_participants` `last_read_at` updated via RPC `UPDATE ... SET last_read_at=now()` no trigger; `messages` no trigger (immutable) |
| `platform_raise_error(code,message)` | `20260819090001:68-82` | Typed `P0001` `PLT001/003/004/005` envelope (`20260819090001:65-68`) |
| `platform_audit_log_add(action,entity,details)` | `20260819090003:388-398` precedent | Audit `conversation_ensure` + `message_send` with `contract_id/conversation_id/client_message_id` |
| `supabase_push_receiver.dart:18` `SupabasePushRealtimeGateway` | `lib/core/notifications/push/supabase_push_receiver.dart` | Realtime seam for `messages` `onPostgresChanges(event:insert, schema:public, table:messages, filter:eq('conversation_id', id))` + `NotificationChannelManager` `hivorr_messages` |

## 8. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Messaging schema + RPCs migration | `supabase/migrations/20260925090001_service_messaging_schema.sql` (after `20260924090001_service_review_schema.sql:1`) | **Create** — new SQL migration (~750 lines) |
| pgTAP posture | `supabase/tests/database/029_service_messaging_schema_posture.sql` (`plan 29-32`) | **Create** — mirrors `027_service_review_schema_posture.sql:14-326` |
| pgTAP enforcement | `supabase/tests/database/030_service_messaging_rpc_enforcement.sql` (`plan ~78`) | **Create** — mirrors `028_service_review_rpc_enforcement.sql` / `026_service_contract_rpc_enforcement.sql` |
| `service_contracts` FK target | `20260923090001:43` | **Reuse** `RESTRICT` client/professional + participant derivation |
| `entities` FK target | `20260821090002:20-29` | **Reuse** `CASCADE` |
| `AesCipher` + `KeyDerivation` + `PiiRedactor` | `lib/core/security/crypto/aes_cipher.dart:54` `key_derivation.dart:29` `lib/core/logging/pii_redactor.dart:42` | **Reuse** client-side encryption + redaction (no new crypto) |
| `ActionQueue` + `SyncEngine` + `connectivity_plus` | `lib/core/sync/action_queue.dart` `sync_action.dart` `sync_engine.dart` `connectivity_plus_provider.dart` | **Reuse** offline `client_message_id` replay (no new queue) |
| `SupabasePushReceiver` + `NotificationService` + `NotificationChannelManager` | `lib/core/notifications/push/supabase_push_receiver.dart` `services/local_notification_service.dart` `channels/notification_channel_manager.dart` | **Reuse** `hivorr_messages` channel for `body_preview` push (no new `notification_events` table) |
| `lib/systems/communication` Dart | `lib/systems/communication/.gitkeep` | **Not created** — `EP-03-13` (`Plan:144`) will create `services/messaging_service.dart` + `datasources/remote/supabase_messaging_remote_data_source.dart` + `providers/messaging_provider.dart` |

**No `lib/` files created in this task** — server-only, matching `EP-03-01/02/03` pattern (client `lib/systems/communication` + `lib/data/*` is `EP-03-13` scope).

## 9. Data Requirements

### 9.1 `conversations`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `contract_id` | `uuid NOT NULL UNIQUE -> service_contracts(id) ON DELETE CASCADE` | 1:1 per engagement (`Plan:279`); `UNIQUE` prevents second conversation for same contract; `CASCADE` preserves atom if contract archived |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | `platform_set_updated_at()` |
| `created_by` | `uuid DEFAULT auth.uid()` | |

Indexes: `conversations_contract_unique UNIQUE(contract_id)`, `conversations_created_at_idx (created_at DESC)`.

### 9.2 `conversation_participants`

| Column | Type | Notes |
|---|---|---|
| `conversation_id` | `uuid -> conversations(id) ON DELETE CASCADE` | PK part 1 |
| `entity_id` | `uuid -> entities(id) ON DELETE CASCADE` | PK part 2 = participant (`auth.uid()`), derived from `service_contracts.client/professional`, no role column |
| `joined_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `last_read_at` | `timestamptz` | RPC `UPDATE ... SET last_read_at=now()` after `message_list` (future read-receipts reuse) |

PK `(conversation_id, entity_id)` — exactly 2 rows per conversation (client+professional). No check limits to 2 (EP-04 third row needs 3). Indexes: `conversation_participants_entity_idx (entity_id, joined_at DESC)` for `conversation_list` `WHERE entity_id=auth.uid()`, `conversation_participants_conversation_idx (conversation_id)`.

### 9.3 `messages`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `conversation_id` | `uuid -> conversations(id) ON DELETE CASCADE` | |
| `sender_entity_id` | `uuid -> entities(id) ON DELETE RESTRICT` | `auth.uid()` at send, `CHECK sender = participant` via RLS `WITH CHECK` + RPC `sender=auth.uid()` |
| `body_encrypted` | `text NOT NULL` `CHECK char_length(btrim(body_encrypted)) BETWEEN 20 AND 8000` | Opaque `EncryptedPayload{c,i,t} base64` (`lib/core/security/crypto/aes_cipher.dart:28-34`); never `SELECT pgp_sym_decrypt` server-side |
| `body_preview` | `text` `CHECK (body_preview IS NULL OR char_length(body_preview) <= 120)` | Redacted 120-char for `NotificationService` + `conversation_list` `LATERAL` preview; truncated + `regexp_replace` mirroring `lib/core/logging/pii_redactor.dart:42-73`, `PiiRedactor.enabled=true` |
| `client_message_id` | `uuid NOT NULL UNIQUE DEFAULT gen_random_uuid()` | `uuid:4.5.1` `v4` from `lib/core/sync/sync_action.dart:id`; `ON CONFLICT DO NOTHING` idempotent replay |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | Keyset cursor `(created_at DESC, id DESC)` |

No `updated_at` — immutable (mirrors `contract_events:150` `no updated_at`). Indexes: `messages_conversation_created_idx (conversation_id, created_at DESC, id DESC)` for `message_list` `Index Scan` (no `SORT`), `messages_sender_idx (sender_entity_id)`, `messages_client_message_idx UNIQUE (client_message_id)`.

Constraints summary: `conversations_contract_unique`, `conversation_participants_pkey`, `messages_client_message_unique`, `messages_body_encrypted_length`, `messages_body_preview_length`, `messages_sender_not_null`.

## 10. Database Considerations

### 10.1 Existing Schema (References Only — No Modification)

*   `entities(id, status)` — `20260821090002:20-29` (`auth.uid()` stable `lib/core/authentication/services/supabase_auth_service.dart` + `lib/core/api/api_client/auth_interceptor.dart`)
*   `service_contracts(id, client_entity_id, professional_entity_id, status, escrow_id)` — `20260923090001:43-67` `CHECK draft/offered/active/...` + `service_contracts_no_self` + `currency_format`
*   `service_listings` is **not** directly referenced by messaging (via contract `service_listing_id` only for `conversation_ensure` `PLT004` derivation)
*   `financial_*` / `dispute_cases` / `service_reviews` not mutated; `service_listings.avg_rating` narrow grant unchanged

### 10.2 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| `contract_id UNIQUE 1:1` | `UNIQUE(contract_id)` + `FK CASCADE` + RPC `ON CONFLICT DO NOTHING` idempotent `ensure` |
| No self participant (2 rows, not 1) | RPC `INSERT` 2 rows `client, professional` where `client <> professional` guaranteed by `service_contracts_no_self` (`20260923090001:66`) |
| Exactly 2 participants per conversation | RPC inserts exactly 2; no `CHECK` limits to 2 to allow EP-04 third row without migration |
| `body_encrypted 20-8000` | `CHECK char_length(btrim(body_encrypted)) BETWEEN 20 AND 8000` + RPC `PLT003` |
| `body_preview <=120` | `CHECK char_length(body_preview) <=120` + RPC `left 120 + regexp_replace` |
| `client_message_id unique` | `UNIQUE(client_message_id)` + `ON CONFLICT DO NOTHING` dedup (`PLT000` second replay) |
| `sender is participant` | RPC `EXISTS participation` `PLT004` + RLS `WITH CHECK (sender_entity_id=auth.uid() AND EXISTS participant)` |

### 10.3 RLS & Grants (Default-Deny `20260819090001:18`)

```sql
REVOKE ALL ON TABLE public.conversations, public.conversation_participants, public.messages FROM anon, authenticated, service_role;

-- conversations: authenticated participant read; insert via RPC only
GRANT SELECT ON public.conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversations TO service_role;
-- No UPDATE grant to authenticated except via RPC (ensure is the only writer)

-- conversation_participants: authenticated read+insert+update(last_read_at)
GRANT SELECT, INSERT ON public.conversation_participants TO authenticated;
GRANT UPDATE (last_read_at) ON public.conversation_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversation_participants TO service_role;

-- messages: authenticated read+insert (immutable, no UPDATE/DELETE)
GRANT SELECT, INSERT (conversation_id, sender_entity_id, body_encrypted, body_preview, client_message_id) ON public.messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO service_role;

-- Policies (6 total, authenticated only; anon 0)
-- conversations SELECT participant-only
CREATE POLICY conversations_select ON public.conversations FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id=id AND cp.entity_id=auth.uid()));
CREATE POLICY conversations_insert ON public.conversations FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())));
-- conversation_participants SELECT/INSERT participant-only
CREATE POLICY conversation_participants_select ON public.conversation_participants FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversation_participants cp2 WHERE cp2.conversation_id=conversation_id AND cp2.entity_id=auth.uid()));
CREATE POLICY conversation_participants_insert ON public.conversation_participants FOR INSERT TO authenticated
  WITH CHECK (entity_id=auth.uid() OR EXISTS (SELECT 1 FROM public.service_contracts c JOIN public.conversations conv ON conv.id=conversation_id WHERE conv.contract_id=c.id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())));
-- messages SELECT/INSERT participant-only (Plan:179 leakage mitigation)
CREATE POLICY messages_select ON public.messages FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id=messages.conversation_id AND cp.entity_id=auth.uid()));
CREATE POLICY messages_insert ON public.messages FOR INSERT TO authenticated
  WITH CHECK (sender_entity_id=auth.uid() AND EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id=messages.conversation_id AND cp.entity_id=auth.uid()));
```

`service_role` bypasses RLS (`20260829100004:568`). `anon` `0` grants (`027:36` pattern).

### 10.4 Triggers & Idempotency

*   `platform_set_updated_at()` on `conversations` only (mutable `updated_at`), `DROP TRIGGER IF EXISTS` before `CREATE` (`20260921090001:214-220` pattern)
*   `conversation_participants` `last_read_at` updated via `UPDATE ... SET last_read_at=now()` in `message_list` RPC (no trigger needed)
*   `messages` no `updated_at` trigger (immutable) — matches `service_favorites:265` + `contract_events:150`
*   Realtime `DO $$` guarded `ADD/DROP` idempotent (`20260829090003:799`), `ON CONFLICT` idempotent (`20260830100001:56-60`, `20260921090001:284`)

### 10.5 Concurrency & Locking

*   `conversation_ensure_for_contract` — `SELECT ... FOR UPDATE` on `service_contracts` row (requires `SELECT` grant, already `authenticated` via `service_contracts` RLS) + `INSERT INTO conversations ON CONFLICT (contract_id) DO NOTHING RETURNING id` + `SELECT ... FOR UPDATE` on `conversations` row before inserting participants `ON CONFLICT DO NOTHING`; second concurrent `ensure` sees `ON CONFLICT` no-op, returns same `id`
*   `message_send` — `SELECT ... FOR UPDATE` on `conversations` + `EXISTS participation` before `INSERT ... ON CONFLICT (client_message_id) DO NOTHING`; duplicate `client_message_id` from `ActionQueue` replay returns `PLT000` with existing `id` (no `unique_violation` `PLT005`)
*   `message_list`/`conversation_list` — `STABLE`, no locks, `row_number() OVER (ORDER BY created_at DESC, id DESC)` keyset (`20260921090001:1163-1179` pattern)

### 10.6 Realtime Publication

```sql
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename IN ('conversations','conversation_participants')) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.conversations, public.conversation_participants;
  END IF;
END $$;
```

Posture asserts `messages 1, others 0` (invert `027:240` `0` for reviews). RLS-filtered subscription: `client.channel('messages:'||conversation_id).onPostgresChanges(event:insert, schema:public, table:messages, filter:eq('conversation_id', conversationId), callback: payload.newRecord)` — `lib/core/notifications/push/supabase_push_receiver.dart:22-28` `eq('entity_id',...)` precedent replaced by `eq('conversation_id',...)` + participant RLS (`Plan:179`).

## 11. API Requirements

### 11.1 RPC Surface (`PostgREST /rpc/`, `PLT000` `20260829100004:17`)

| RPC | Signature | Volatility | Access | Purpose (code `PLT...`) |
|---|---|---|---|---|
| `conversation_ensure_for_contract` | `(p_contract_id uuid)` | `VOLATILE` | `authenticated, service_role` (`anon 0`) | Validates `service_contracts` participant `PLT004` (identical for foreign/unknown), idempotent `ON CONFLICT` 1:1, inserts 2 `conversation_participants`, audit, returns `{conversation, participants[2]}` |
| `message_send` | `(p_conversation_id uuid, p_body_encrypted text, p_body_preview text DEFAULT NULL, p_client_message_id uuid DEFAULT gen_random_uuid())` | `VOLATILE` | `authenticated, service_role` | `platform_is_authenticated PLT001`, `EXISTS participation PLT004`, `body_encrypted 20-8000 PLT003`, `client_message_id PLT003`, `sender_entity_id=auth.uid()` `INSERT`, `ON CONFLICT DO NOTHING` dedup `PLT000` second replay, `body_preview left 120 + PiiRedactor regexp` `PLT003` if >8000, returns `{message, conversation_id}` |
| `conversation_list` | `(p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` | `STABLE` | `authenticated, service_role` | `p_limit 1-100 PLT003`, unknown `p_cursor` `[]` no oracle, keyset `(created_at DESC, id DESC)` via `conversation_participants` join + `LATERAL` last `messages`, `has_more/next_cursor` (`20260921090001:1163` pattern) |
| `message_list` | `(p_conversation_id uuid, p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` | `STABLE` | `authenticated, service_role` | `PLT004` for non-participant/unknown `p_conversation_id` no oracle, `p_limit 1-100 PLT003`, keyset `(created_at DESC, id DESC)` `messages_conversation_created_idx` `Index Scan`, `has_more/next_cursor`, returns `body_encrypted` opaque + `body_preview` |

`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + 4× `GRANT EXECUTE authenticated,service_role` (`027:281-300` pattern `anon 1` for public `get_for_listing` contrast `anon 0` here).

### 11.2 No REST / No Edge Functions

No `supabase/functions/*`; `storage.objects` not used (text-only). Future attachment evidence would use `service-listing-media` `storage.foldername(name)[1]=auth.uid()::text` (`20260921090001:306`), but not in this migration.

## 12. User Interface Requirements

**None** — server-only (`Plan:87` `Messaging & conversation schema` is `supabase/migrations/*_service_messaging_schema.sql` only). Client is `EP-03-13` (`Plan:145`):

*   Service `lib/systems/communication/services/messaging_service.dart` wrapping `conversation_ensure_for_contract`, `message_send/list`, `SupabaseRealtime` via `lib/data/datasources/remote/supabase_messaging_remote_data_source.dart` abstraction + `ActionQueue` `Hive` offline replay deduped by `client_message_id`
*   Screens `conversation_list_screen.dart` / `message_thread_screen.dart` (`ListView` + `HivorrTextField` + `HivorrButton`) via `lib/shared/widgets/hivorr_*` + `lib/shared/layouts/hivorr_content_pane.dart:720dp` (`EP-01-16`)
*   Encryption via `lib/core/security/crypto/aes_cipher.dart:79` `encryptString/decryptString` with `KeyDerivation.generateRandomSecret()` per-conversation key persisted in `lib/core/storage/secure_storage.dart` `flutter_secure_storage:11.0.0` (never logged)
*   All EP-03 UI complies with `AGENT.md:18` Rule 5 (`VISUAL-IDENTITY.md:44-80` `ColorScheme` + `AppThemeExtension` + `TextTheme`, never `Colors.*`/hex/`fontFamily`) — verified in EP-03-13, not here (`dart analyze:1` `No issues found!`)

## 13. User Experience Considerations (Server-Shaped)

*   `PLT004` identical for `conversation_ensure_for_contract` unknown vs foreign contract (`20260923090001:811` precedent) → `HivorrEmptyState` 404, not auth redirect, so `/messages/:id` deep-link safe (no enumeration oracle `20260913090001_portfolio_public_profile.sql:14-16`)
*   `PLT003` `body_encrypted 20-8000` → `HivorrErrorState` “Message failed to send — retry” with `ActionQueue` retry `SyncActionStatus.failed` → `deadLettered` after `maxRetries` (`lib/core/sync/sync_action.dart` + `EP-01-12` `defaultMaxRetries`)
*   `ON CONFLICT (client_message_id) DO NOTHING` → second tap after offline replay shows `PLT000` with same `id`, not `PLT005` conflict — `Lib/systems/communication` can show optimistic `pending → sent` tick (`fake_async:1.3.1` + `connectivity_plus` mock)
*   `body_preview 120` truncated preview enables `conversation_list` last-message snippet + `HivorrNotification.body` without exposing `body_encrypted` plaintext to non-participants; `lib/core/logging/pii_redactor.dart:42-73` guarantees no `***@***.***` leaks to `SentryLogSink`
*   `conversation_list` `has_more/next_cursor` keyset prevents `OFFSET` duplicate on concurrent send (no missing tail)
*   Envelope `{success,code,message,data}` uniform with `20260829100004:17` + `20260921090001:12` → `lib/core/api/api_client/error_interceptor.dart` retry only on `PLT999` network, not `PLT004`

## 14. Security Considerations

| Consideration | Approach | Verification (`supabase test db --local`) |
|---|---|---|
| Zero client logic | All `contract_id 1:1`, participant `EXISTS`, `body_encrypted` bounds, `client_message_id` dedup, `body_preview` redact via `SECURITY INVOKER` (`AGENT.md:6` Rule 4, `ARCHITECTURE.md:160`) | `prosecdef 0` (`027:202` pattern) |
| RLS leakage (non-participant `SELECT 0 rows`) | `conversations SELECT USING (EXISTS participant)` + `messages SELECT USING (EXISTS participant)` + `Realtime` publication `ADD messages` RLS-filtered (`Plan:179`) | `029` `pg_publication_tables messages 1` + `030` non-participant `SELECT count 0` + Realtime subscription test `0 events` for non-participant vs `1 event` for participant |
| Participant forgery (`sender != auth.uid()`) | `messages_insert WITH CHECK (sender_entity_id=auth.uid() AND EXISTS participation)` + `GRANT INSERT (..., sender_entity_id, ...)` column-level | `030` `INSERT with sender != auth.uid() → 42501 RLS violation` |
| `client_message_id` replay injection | `UNIQUE(client_message_id)` + `INSERT ON CONFLICT DO NOTHING` → `PLT000` not `PLT005` | `030` second `message_send` with same `client_message_id` `PLT000` same `id`, not duplicate row |
| `body_encrypted` injection (plaintext instead of `EncryptedPayload{c,i,t}`) | `CHECK 20-8000` + server does not `decrypt`, client `AesCipher.encryptString` with `KeyDerivation` (`lib/core/security/crypto/key_derivation.dart:29`) non-deterministic IV ensures same plaintext ≠ same ciphertext; `PiiRedactor` never logs `body_encrypted` | `030` `body_encrypted short 5 → PLT003`, `NULL → PLT003` |
| No `SECURITY DEFINER` expansion | `0` `service_messaging_%` `prosecdef` (except `portfolio_public_profile_get:120` whitelisted) | `029` `pg_proc prosecdef 0` |
| Oracle `PLT004` | `conversation_ensure/message_list` foreign/unknown identical `PLT004` (`20260923090001:811`) | `030` stranger `ensure PLT004` vs `anon 42501` |
| Realtime cross-talk (100 concurrent subscribers per conversation) | `Realtime` filtered `eq(conversation_id, ...)` + RLS participant; `ALTER PUBLICATION ... ADD messages` not `conversations` | Load test `100 subscribers` `Plan:286` no cross-talk |
| SQL injection | `::uuid`/`::text` casts, `btrim`, no `EXECUTE` string (`grep EXECUTE` only `platform_set_updated_at`) | `dart analyze` + `pgBadger` |
| PII in logs/notifications | `PiiRedactor.redact` + `redactContext` (`lib/core/logging/pii_redactor.dart:92-120` `defaultSensitiveKeyNames` `email/password/token/secret`) on `body_preview` before `HivorrNotification` + `SentryLogSink` | `030` preview with `test@example.com` stored as `***@***.***` |

## 15. Performance Considerations

| Consideration | Approach | Verification |
|---|---|---|
| `message_list` keyset | `(conversation_id, created_at DESC, id DESC)` `messages_conversation_created_idx` `Index Scan` no `SORT`/`OFFSET` (`20260923090001:953` `contract_events_contract_idx` precedent) | `029` `6 indexes` + `EXPLAIN Index Scan` |
| `conversation_list` keyset | `(entity_id, joined_at DESC)` `conversation_participants_entity_idx` + `LATERAL` last `messages` `Index Scan`, not `JOIN` full scan | `029` `4 indexes` |
| `client_message_id` dedup | `UNIQUE` `Hash Index` `ON CONFLICT` single-row probe, no table lock (mirrors `service_favorites:270` `UNIQUE(entity_id,listing_id)`) | `030` concurrent `message_send` same `client_message_id` second `ON CONFLICT` no `unique_violation` |
| Volatility | `STABLE` reads `conversation_list/message_list` (PostgREST cacheable), `VOLATILE` writes `ensure/send` | `prosecdef 0` + `provotile` (`027:202`) |
| Realtime backpressure | `messages` `Realtime` `INSERT` events only, not `UPDATE/DELETE`; `SupabasePushReceiver` `onMessage` buffered `StreamController` with `realtime_client` transitive `supabase_flutter:2.17.2` | Staging `100 concurrent` no drop |
| Index budget | `conversations 1 + participants 2 + messages 3 =6` + `UNIQUE 2` =8 total ≤10 per-table budget (`20260921090001:110-123` `6 indexes` service_listings) | `029` `All tests successful. Files=1, Tests=32` |

## 16. Testing Strategy

### 16.1 `029_service_messaging_schema_posture.sql` (`plan 32` mirrors `027_service_review_schema_posture.sql:14-326` `plan 29`)

| Test | Assertion (`027:18-323` pattern) |
|---|---|
| `has_table` 3 | `conversations`, `conversation_participants`, `messages` |
| `relrowsecurity` 3 | `pg_class relrowsecurity` count `3` |
| `anon 0 INSERT/UPDATE/DELETE` | `role_table_grants grantee='anon' privilege_type IN ('INSERT','UPDATE','DELETE')` `0` (`027:36`) |
| `authenticated SELECT 1` on `conversations` | `role_table_grants grantee='authenticated' SELECT` `1` (participant RLS) |
| `authenticated INSERT` column-level on `messages` `(conversation_id, sender_entity_id, body_encrypted, body_preview, client_message_id)` | `role_column_grants` count `5` (`027:48` `9 columns` precedent for reviews) |
| `authenticated UPDATE(last_read_at)` | `role_column_grants update last_read_at` `1` (`027:58` `3 columns` for reveal) |
| `UNIQUE(contract_id)` | `pg_constraint contype='u' conname='conversations_contract_id_key'` `1` (`027:115` `service_reviews_contract_reviewer_key`) |
| `PK (conversation,entity)` | `pg_constraint contype='p' conname='conversation_participants_pkey'` `1` |
| `UNIQUE(client_message_id)` | `pg_constraint contype='u' conname='messages_client_message_id_key'` `1` |
| `CHECK body_encrypted 20-8000` / `body_preview <=120` | `pg_constraint contype='c' conname='messages_body_encrypted_length'` + `messages_body_preview_length` `1` (`027:93` `service_reviews_rating_range`) |
| `Indexes 6` | `pg_indexes` `conversations_contract_unique, conversation_participants_entity_idx, ... messages_conversation_created_idx, messages_client_message_idx` `6` (`027:159` `4 indexes`) |
| `Triggers 1 updated_at` + `0` on `messages` | `pg_trigger tgname='conversations_set_updated_at'` `1` + `messages` `0` (`027:186` `2 triggers`) |
| `prosecdef 0` | `pg_proc proname LIKE 'conversation_%'/'message_%' prosecdef` `0` (`027:202`) |
| `4 RPCs jsonb` | `pg_proc proname LIKE ... prorettype='jsonb'` `4` (`027:228` `4 RPCs`) |
| `Realtime 1 for messages, 0 for others` | `pg_publication_tables pubname='supabase_realtime' tablename='messages'` `1` + `conversations/participants` `0` (`027:240` `0` for reviews inverted) |
| `comments 3` | `obj_description pg_class` `3` (`027:251`) |
| `anon EXECUTE 0, authenticated 4, service_role 4` | `routine_privileges grantee='anon' routine_name LIKE 'conversation_%/message_%'` `0` + `authenticated` `4` + `service_role` `4` (`027:264-300`) |
| `6 RLS policies` | `pg_policies tablename IN (...)` `6` (`027:302` `5 policies` for reviews) |
| Regression | `001-028` `008_full_schema_posture_audit.sql`, `013_financial_schema_posture.sql`, `015_dispute_schema_posture.sql`, `027` still pass — no prior DDL |

### 16.2 `030_service_messaging_rpc_enforcement.sql` (`plan ~78` mirrors `026_service_contract_rpc_enforcement.sql` `plan 88` + `028`)

| Group | Tests |
|---|---|
| Authz `anon 42501×4` + `service_role 4× lives_ok` + participant `PLT004` oracle | `throws_ok('SELECT conversation_ensure_for_contract...','42501')` anon `4`; `service_role` `4` `lives_ok`; `set_config('request.jwt.claim.sub','333...')` stranger `conversation_ensure stranger PLT004` vs `service_role PLT000` (`026:30` `stranger get returns PLT004`) |
| Validation `PLT003/004/005` | `NULL contract_id PLT003`, unknown contract `PLT004`, `draft` contract still `offered`? actually `service_contracts` any status `offered/active/closed` allowed for chat; `body_encrypted NULL PLT003`, `body_encrypted short 5 PLT003`, `client_message_id NULL PLT003`, `p_limit 0 PLT003`, `p_limit 101 PLT003`, `p_conversation_id NULL PLT003` |
| Functional `PLT000` | `client A offer service_listing → professional B accept → A ensure PLT000 conversation_id returned`; `B ensure same contract → same id (ON CONFLICT)`; `A message_send ciphertext 200 chars + preview 'Hello 120' + uuid.v4() → PLT000 message id`; `B message_list PLT000 1 row body_preview 'Hello 120'`; `A message_list PLT000 same`; `C stranger message_list PLT004`; `C SELECT * FROM messages WHERE conversation_id=... → 0 rows` RLS leakage; `A conversation_list 1 item last_preview='Hello 120'`; `B conversation_list same`; `C conversation_list 0 items`; `A second message_send same client_message_id → PLT000 same id not duplicate row count 1` |
| Invariants | `client_message_id duplicate idempotent` `count 1`, `body_preview redacted` `test@example.com` stored `***@***.***`, `body_encrypted NOT NULL` |
| Realtime | `messages` `pg_publication_tables` `1` + manual `supabase.test` `Realtime` subscription `authenticated participant` receives `1 event` `<1s`, `non-participant` receives `0` (Plan:286 load 100 concurrent) |
| Regression | `001-029` `relrowsecurity` unchanged `All tests successful.` |

Post-repair `supabase db reset --local` `Applying migration 20260925090001_service_messaging_schema.sql... OK` + `supabase test db --local 029/030` `pass` + `dart analyze:1` `No issues found!` (no `lib/` Dart).

## 17. Recommended Implementation Sequence

| Step | Action | Output | Verification |
|---|---|---|---|
| 1 | Create migration `supabase/migrations/20260925090001_service_messaging_schema.sql` after `20260924090001_service_review_schema.sql:1` (tip) | Scaffold | `ls -l supabase/migrations \| tail -n 5` |
| 2 | Header block (EP-03-04, `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, 1:1 contract binding, `AesCipher` opaque ciphertext, `PiiRedactor` preview, `ActionQueue` dedup, RLS `EXISTS`, Realtime `ADD messages`) | Docs | `grep -n "EP-03-04" supabase/migrations/20260925090001*` |
| 3 | DDL `conversations` (`UNIQUE(contract_id) -> service_contracts CASCADE`, `CHECK`, `UNIQUE` index, `platform_set_updated_at()` trigger, `COMMENT ON`) | Table | `029:18` `has_table conversations` + `029:240` `relrowsecurity 3` |
| 4 | DDL `conversation_participants` (`PK (conversation,entity) -> entities CASCADE`, indexes, comments — no `updated_at` trigger) | Table | `029:48` `role_column_grants` + `029:115` `PK` |
| 5 | DDL `messages` (`CHECK 20-8000/<=120`, `UNIQUE(client_message_id)`, FKs `CASCADE/RESTRICT`, 3 indexes, comments — no `updated_at`) | Table | `029:93` `CHECK` + `029:159` `6 indexes` |
| 6 | `REVOKE ALL` + `GRANT SELECT/INSERT/UPDATE(last_read_at)` to `authenticated`, `SELECT,INSERT,UPDATE,DELETE` to `service_role`, `anon 0` + 6 `CREATE POLICY` participant-scoped `EXISTS` (`029:240` `pg_publication_tables` after) | Security | `029:36` `anon 0` + `029:48` `authenticated column-level` + `029:302` `6 policies` |
| 7 | Implement `conversation_ensure_for_contract` (`authenticated PLT001`, `service_contracts` participant `PLT004`, `ON CONFLICT (contract_id) DO NOTHING`) `VOLATILE` | RPC | `030:30` `anon 42501` + `ensure PLT000` |
| 8 | Implement `message_send` (`authenticated`, `EXISTS participation PLT004`, `body_encrypted 20-8000 PLT003`, `client_message_id PLT003`, `left 120 + regexp_replace` PII, `ON CONFLICT DO NOTHING`) `VOLATILE` | RPC | `030:30` `body_encrypted NULL PLT003` + `stranger PLT004` |
| 9 | Implement `conversation_list` + `message_list` (`authenticated`, `p_limit 1-100 PLT003`, keyset `(created_at DESC, id DESC)` `Index Scan`, unknown cursor `[]`) `STABLE` | RPC | `030` `conversation_list 1 item` + `message_list 1 row` |
| 10 | `REVOKE EXECUTE ON ALL FUNCTIONS FROM public` + `GRANT EXECUTE authenticated,service_role 4×` (`anon 0`) + `COMMENT ON FUNCTION`×4 | Grants | `029:264` `anon 0` `authenticated 4` |
| 11 | Realtime `DO $$ ADD messages / DROP conversations,participants` guarded (`20260829090003:799` pattern inverted) | Realtime | `029:240` `messages 1 others 0` |
| 12 | `029_service_messaging_schema_posture.sql:14` `plan 32` | pgTAP | `supabase test db --local 029` `All tests successful. Files=1, Tests=32` |
| 13 | `030_service_messaging_rpc_enforcement.sql:14` `plan ~78` | pgTAP | `supabase test db --local 030` `anon 42501 PLT004 stranger` pass |
| 14 | `supabase db reset --local` (`ARCHITECTURE.md:164` `ENV-002` isolated Dev `ENV-008`) | Integration | `supabase db reset:18` `Applying migration ... OK` `Finished ...` |
| 15 | `dart analyze` (`ARCHITECTURE.md:9` `AGENT.md:6`) no `lib/` Dart change | Quality | `dart analyze:1` `No issues found!` |

## 18. Expected Outcome

*   3 conversation tables `relrowsecurity 3` (`029:23` `3`), `UNIQUE(contract_id)` `1` (`029:115`), `PK (conversation,entity)` `1`, `UNIQUE(client_message_id)` `1`, `CHECK 20-8000` `1` + `<=120` `1` (`029:93`), 6 indexes `Index Scan` (`029:159`), 1 `updated_at` trigger (`029:186`), `prosecdef 0` (`029:202`), `4 RPCs jsonb` (`029:228`), `Realtime messages 1 others 0` (`029:240`), `comments 3` (`029:251`), `anon 0 authenticated 4 service_role 4` (`029:264`), `6 RLS policies` (`029:302`), `dart analyze No issues found!`, `EP-03-13` `conversations.id` FK ready (`Plan:138`), no prior DDL (`grep alter table public.(service_contracts|service_listings) 0` `CHECK_DONE`).
*   Messaging is atomic with `ActionQueue` dedup: `SyncAction{endpoint:'/rpc/message_send', payload:{client_message_id: uuid.v4()}, priority:high}` `INSERT ON CONFLICT DO NOTHING` guarantees exactly-once after `connectivity_plus` reconnect (Nigeria market).
*   Platform integration: `conversations.contract_id UNIQUE` reuses `service_contracts` (`20260923090001:43`) 2-party primitive; `conversation_participants` reuses `entities` (`20260821090002:20`); crypto reuses `lib/core/security/crypto/*` (`cryptography:2.7.0`) + `PiiRedactor`; sync reuses `lib/core/sync/*`; push reuses `lib/core/notifications` `hivorr_messages` high-priority channel; routing reuses `lib/app/router` `GoRouter 17.5.0` `/messages/:id` (future EP-03-19 SEO pattern `/s/:profession_slug/:service_id` untouched); no new top-level `lib/` dir per `ARCHITECTURE.md:36-139`.

## 19. Definition of Done (DoD)

| # | Criterion | Verification (`supabase test db --local`) |
|---|---|---|
| 1 | `20260925090001_service_messaging_schema.sql` after `20260924090001` | `ls -l supabase/migrations \| tail -n 5` |
| 2 | `has_table` 3 | `029:18` `has_table` `conversations, conversation_participants, messages` `3` |
| 3 | `relrowsecurity 3` | `029:23` `3` |
| 4 | `anon 0 INSERT/UPDATE/DELETE` | `029:36` `0` |
| 5 | `authenticated SELECT` `1` on `conversations`, `INSERT` column-level `5` on `messages` | `029:48` `have:5` |
| 6 | `authenticated UPDATE(last_read_at)` `1` | `029:58` `1` |
| 7 | `UNIQUE(contract_id)` + `PK (conversation,entity)` + `UNIQUE(client_message_id)` | `029:115` `1` + `PK` `1` + `UNIQUE` `1` |
| 8 | `CHECK body_encrypted 20-8000` + `CHECK body_preview <=120` | `029:93` `1` + `body_preview` `1` |
| 9 | Indexes `messages_conversation_created_idx` + `client_message_idx` `6` | `029:159` `6` |
| 10 | `platform_set_updated_at` `1` on `conversations` + `0` on `messages` | `029:186` `1` + `0` |
| 11 | `prosecdef 0` | `029:202` `0` |
| 12 | `4 RPCs jsonb` | `029:228` `4` |
| 13 | `Realtime messages 1, conversations/participants 0` | `029:240` `1` + `0` |
| 14 | `comments 3` | `029:251` `3` |
| 15 | `anon 0, authenticated 4, service_role 4` | `029:264,281,291` `0,4,4` |
| 16 | `6 RLS policies` | `029:302` `6` (2+2+2) |
| 17 | `030` `anon 42501×4` `PLT004` oracle stranger `ensure/message_list` | `030:30` `anon 42501` + `stranger PLT004` |
| 18 | `message_send` `body_encrypted NULL PLT003` + short `PLT003` + `client_message_id PLT003` | `030:30` |
| 19 | `ensure` idempotent `ON CONFLICT` same `id` + second `message_send` same `client_message_id` `PLT000` not duplicate | `030` `count 1` |
| 20 | `conversation_list 1 item` `has_more` + `message_list 1 row` preview `***@***.***` redacted | `030` |
| 21 | `RLS leakage` non-participant `SELECT * FROM messages WHERE conversation_id=... 0 rows` + `Realtime` non-participant `0 events` | `030` |
| 22 | `REVOKE EXECUTE FROM public` + `GRANT EXECUTE` 4× | `029:264` |
| 23 | No prior DDL `CHECK_DONE 0`, no `lib/` Dart `dart analyze:1 No issues found!` | `grep alter table public.(service_contracts\|service_listings) 0` |
| 24 | `EP-03-13` FK ready `conversations.id` + `messages.client_message_id` dedup for `ActionQueue` | `Plan:138,183` |

## 20. Implementation AI Execution Profile

**Recommended Coding Reasoning Level: Very High**

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Very High** — 3 tables `FK CASCADE/RESTRICT`, `UNIQUE(contract_id) + UNIQUE(client_message_id) + PK(conversation,entity)`, `CHECK 20-8000/<=120`, `CREATE OR REPLACE` `AesCipher` opaque validation, `regexp_replace` PII mirroring `PiiRedactor:42-73`, `FOR UPDATE` + `ON CONFLICT DO NOTHING` idempotency, 4 RPCs `VOLATILE/STABLE` |
| **Business impact** | **Very High** — contract-scoped negotiation fabric; leakage destroys `Plan:179` privacy + trust for EP-03→EP-08 |
| **Security risk** | **Extremely High** — `EXISTS participation` RLS (`Plan:179` high risk), `anon 0` vs `authenticated 4` (`027:264`), `body_encrypted` server never decrypts, `PiiRedactor` preview `120` (`lib/core/logging/pii_redactor.dart:92`), `client_message_id` replay `ON CONFLICT` prevents duplicate `ActionQueue` funds-discussion spoof |
| **Performance sensitivity** | **High** — keyset `(created_at DESC, id DESC)` `Index Scan` (`Plan:55` `p95 <400ms`), `Realtime` `ADD messages` backpressure `100 concurrent` (`Plan:286`), `hive` `sync_queue` persistence |
| **Data complexity** | **High** — `client_message_id uuid UNIQUE` dedup, `body_encrypted 20-8000` ciphertext bounds, `body_preview 120` redacted, `1:1 contract_id UNIQUE` derivation from `service_contracts.client/professional` |
| **Integration complexity** | **Very High** — blocks `EP-03-13` (`Plan:138,144` `ActionQueue` + `SupabasePushReceiver` + `hivorr_messages` `NotificationChannelManager`), reused by EP-04 3-party threads without migration |

**Rationale:** `Plan:475` `EP-03-04 Planning/Coding Very High / Very High` (6 `Very High` items `Plan:503`). Financial/verification `Extremely High` items are `EP-03-01/02/03/06/11` (`Plan:499`); messaging is not ledger but carries `Extremely High` privacy risk via RLS `EXISTS` + `prosecdef 0` + `anon 0` posture, hence `Very High` (not `Extremely High`) — one level below `EP-03-02` `Extremely High` `service_contracts_no_self` + `escrow_id NULL` until `EP-03-11` ledger atomicity.

---

**File Write Target (gated on build-mode approval):** `documents/Task-Implementation/EP-03/EP-03-04-Encrypted Messaging & Conversation Schema & Server-Side Rules.md` (content above) + no `supabase/migrations`/`lib` writes until approval. Wait for approval before proceeding to implementation.
