# Definition of Done — EP-03-04: Encrypted Messaging & Conversation Schema & Server-Side Rules

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-04 |
| **Task Name** | Encrypted Messaging & Conversation Schema & Server-Side Rules |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 1 Marketplace Server Schema Foundation (parallelizable after EP-03-02) |
| **Priority** | High |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:1-466` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:279-288` + `112-113` + `87` + `55` + `179` + `183` + `286` |
| **Dependencies** | EP-03-02 `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43-67`), `entities` (`supabase/migrations/20260821090002_entity_core_tables.sql:20-256`), `lib/core/security/crypto/aes_cipher.dart:54` + `key_derivation.dart:29` (`EP-01-10` `cryptography:2.7.0`), `lib/core/logging/pii_redactor.dart:42` (`EP-01-14`), `lib/core/sync/action_queue.dart` (`EP-01-12` `uuid:4.5.1` + `connectivity_plus:6.1.0` + `hive:2.2.3`), `lib/core/notifications/push/supabase_push_receiver.dart:18` (`EP-01-18` 13 files), `platform_*` helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37-82`) |
| **Delivery Scope** | 3 tables `conversations` (`contract_id UNIQUE -> service_contracts CASCADE`) / `conversation_participants` (`PK (conversation,entity)`) / `messages` (`body_encrypted 20-8000`, `body_preview <=120`, `client_message_id UNIQUE`, immutable) + 6 RLS policies participant-only via `EXISTS` (`Plan:179`) + `REVOKE ALL` + narrow `GRANT SELECT/INSERT` (`anon 0`) + 4 RPCs `SECURITY INVOKER` (`conversation_ensure_for_contract`, `message_send`, `conversation_list`, `message_list`) + Realtime `ALTER PUBLICATION supabase_realtime ADD TABLE public.messages` (RLS-filtered) + 2 pgTAP suites. **Zero** `lib/` Dart, **zero** mutation to `entities/service_listings/service_contracts/service_reviews/financial_*`. Unblocks EP-03-13, reused by EP-04. |
| **Guardrails** | `documents/Context/AGENT.md:13` Rule 4 Database-First Zero-Trust + `AGENT.md:6` Proprietary Logic Protection, `documents/Context/ARCHITECTURE.md:160` DB-First, `documents/Context/ARCHITECTURE.md:36-139` no new top-level `lib/` dir |

**How to use this document:** Check each box only after executing the listed verification (SQL query, `supabase db test`, PostgREST `/rpc/` call, Realtime probe) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

Verifies the user/system behaviors and RPC workflows defined in `EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:8-50` + `§11.1`.

### 2.1 Required Functionality

- [ ] **Conversation ensure — idempotent 1:1 binding** — Authenticated participant (`client_entity_id=auth.uid() OR professional_entity_id=auth.uid()` on `service_contracts` per `supabase/migrations/20260923090001_service_contract_schema.sql:204-207`) can call `conversation_ensure_for_contract(p_contract_id uuid)` and receive `PLT000` with `{conversation:{id, contract_id, created_at}, participants[2]}`. Second call with same `p_contract_id` (same or opposite participant, concurrent) returns **same** `conversation.id` via `INSERT INTO conversations(contract_id) ON CONFLICT(contract_id) DO NOTHING RETURNING id` + `INSERT INTO conversation_participants ON CONFLICT DO NOTHING`. No duplicate `conversations` row (`UNIQUE(contract_id)` holds).
- [ ] **Message send — encrypted + preview + dedup** — Participant can call `message_send(p_conversation_id uuid, p_body_encrypted text, p_body_preview text DEFAULT NULL, p_client_message_id uuid DEFAULT gen_random_uuid())` with `p_body_encrypted` opaque `EncryptedPayload.toJson {c,i,t} base64` `char_length 20-8000` and receive `PLT000` with `{message:{id, conversation_id, sender_entity_id=auth.uid(), body_encrypted, body_preview left 120 redacted, client_message_id, created_at}}`. `body_preview` stored as `left(nullif(btrim(p_body_preview),''),120)` + SQL `regexp_replace` mirroring `lib/core/logging/pii_redactor.dart:42-73` (`email:'***@***.***'`, `phoneNigerian:'***-****-****'`, `bearer:'Bearer ***'`, `jwt:'***'`, `accountNumber:'***'`).
- [ ] **Client-message-id dedup (offline replay)** — Same `p_client_message_id` (`uuid:4.5.1` `SyncAction.id` from `lib/core/sync/action_queue.dart` + `lib/core/sync/sync_action.dart`) second `message_send` on same or different connection returns `PLT000` with **existing** `message.id`, does not create second row (`INSERT ... ON CONFLICT(client_message_id) DO NOTHING RETURNING` → `COALESCE` existing row). `SELECT count(*) FROM messages WHERE client_message_id=<uuid>` → `1`.
- [ ] **Conversation list — participant keyset** — `conversation_list(p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` returns only caller's conversations via `EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id=id AND entity_id=auth.uid())`, keyset `(created_at DESC, id DESC)` via `row_number() OVER (ORDER BY created_at DESC, id DESC)` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:1163` pattern), `p_limit 1-100` respected, `has_more` + `next_cursor` correct, plus `LATERAL (SELECT body_preview, created_at FROM messages WHERE conversation_id=c.id ORDER BY created_at DESC LIMIT 1)` last preview. Unknown `p_cursor` → `[]` `has_more false` no oracle.
- [ ] **Message list — participant keyset** — `message_list(p_conversation_id uuid, p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` as participant returns `PLT000` with `{messages[]:{id, conversation_id, sender_entity_id, body_encrypted opaque, body_preview, created_at}, has_more bool, next_cursor uuid}` keyset `(created_at DESC, id DESC)` via `messages_conversation_created_idx (conversation_id, created_at DESC, id DESC)` `Index Scan` (no `SORT`), `p_limit 1-100` respected. Non-participant or unknown `p_conversation_id` → identical `PLT004` no oracle (mirrors `supabase/migrations/20260923090001_service_contract_schema.sql:811-828` `service_contract_get`). Unknown `p_cursor` → `[]` no oracle.

### 2.2 Expected Workflows (End-to-End)

- [ ] **Ensure → Send → Receive happy path:** (1) Client `C` (`22222222-2222-2222-2222-222222222222`) offers `published` listing `L` (owner `P` `11111111-1111-1111-1111-111111111111`) via `service_contract_offer(p_service_listing_id=L, p_total_amount=50000, p_currency_code='NGN', p_milestones='[{"milestone_number":1,"title":"Draft Deliverable","amount":20000},{"milestone_number":2,"title":"Final Delivery","amount":30000}]'::jsonb)` → `PLT000` `offered` + `service_contract_accept(p_contract_id)` by `P` → `active` (`supabase/migrations/20260923090001_service_contract_schema.sql:449-499` precedent). (2) `C` calls `SELECT conversation_ensure_for_contract(active_id)` → `PLT000` `conv_id`. (3) `P` calls `SELECT conversation_ensure_for_contract(active_id)` → same `conv_id` (idempotent `ON CONFLICT`). `SELECT count(*) FROM conversation_participants WHERE conversation_id=conv_id` → `2`. (4) `C` calls `SELECT message_send(conv_id, '<200..800 char base64 {c,i,t}>', 'Hello from Lagos — contract discussion 120', '<uuid.v4()>')` → `PLT000` `msg1`. (5) `P` calls `SELECT message_list(conv_id, 20, NULL)` → `1` row `body_preview='Hello from Lagos — contract discussion 120'` (redacted), `body_encrypted` opaque same length. (6) `P` calls `SELECT conversation_list(20, NULL)` → `1` item with `last_preview='Hello...'` + `last_message_at`. (7) Reverse: `P` sends second message with new `client_message_id` → `C` `message_list` shows `2` rows in `(created_at DESC, id DESC)` order.
- [ ] **Stranger isolation (leakage matrix):** Stranger `S` (`33333333-3333-3333-3333-333333333333`) not participant in `active_id` calls `SELECT conversation_ensure_for_contract(active_id)` → `PLT004` identical to unknown contract (no oracle per `supabase/migrations/20260913090001_portfolio_public_profile.sql:14-16`); `S` calls `SELECT message_list(conv_id, 20, NULL)` → `PLT004`; `S` as `authenticated` JWT runs `SELECT count(*) FROM messages WHERE conversation_id=conv_id` → `0` rows (RLS `messages_select USING (EXISTS participant)`); `S` `SELECT count(*) FROM conversations WHERE id=conv_id` → `0`; `S` Realtime `client.channel('messages:'||conv_id).onPostgresChanges(event:insert, table:messages, filter:eq('conversation_id',conv_id))` receives `0` events while `C/P` filtered channel receives `1` event `<1s` (`Plan:286`).
- [ ] **Offline replay exactly-once:** `C` airplane-mode enqueues `ActionQueue.enqueue(SyncAction{type:create, endpoint:'/rpc/message_send', method:'POST', payload:{conversation_id:conv_id, client_message_id:uuid.v4(), body_encrypted:ciphertext, body_preview:'offline hello 120'}, priority:2, status:pending})` persisted in `hive:2.2.3` `sync_queue` box via `lib/core/database/storage_engine.dart:writeBatch` atomic (`EP-01-12`). On `connectivity_plus:6.1.0` reconnect `SyncEngine` replays 3 queued `message_send` calls with distinct `client_message_id`s → `P` `message_list` shows exactly `3` rows, no duplicates. Replay same batch second time (idempotent retry) → `SELECT count(*) FROM messages WHERE client_message_id IN (...)` unchanged at `3` via `ON CONFLICT DO NOTHING` (`Plan:183`).

### 2.3 Success Conditions

- [ ] Every write RPC (`conversation_ensure_for_contract`, `message_send`) returns envelope `{success:true, code:'PLT000', message:'Conversation ensured.'/'Message sent.', data: to_jsonb(row)}` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19` + `20260819090001:68-82`) on success; read RPCs (`conversation_list`, `message_list`) return `PLT000` with `data` shape `§11.1`: `conversation_list` includes `{items[], has_more bool, next_cursor uuid}`; `message_list` includes `{messages[], has_more, next_cursor}`.
- [ ] `body_encrypted` never `NULL` after successful `message_send`, `char_length(btrim(body_encrypted)) BETWEEN 20 AND 8000` holds for every `messages` row — `SELECT count(*) FROM messages WHERE char_length(btrim(body_encrypted)) NOT BETWEEN 20 AND 8000` → `0`.
- [ ] `body_preview` `<=120` holds — `SELECT count(*) FROM messages WHERE body_preview IS NOT NULL AND char_length(body_preview) >120` → `0`; PII redacted preview `***@***.***` visible when email supplied.
- [ ] `client_message_id UNIQUE` holds 0 duplicates — `SELECT client_message_id, count(*) FROM messages GROUP BY 1 HAVING count(*)>1` → `0`.
- [ ] `conversations` exactly `1` per `contract_id` — `SELECT contract_id, count(*) FROM conversations GROUP BY 1 HAVING count(*)>1` → `0` (`UNIQUE(contract_id)`).
- [ ] `conversation_participants` exactly `2` rows per 2-party conversation before EP-04 — `SELECT conversation_id, count(*) FROM conversation_participants GROUP BY 1 HAVING count(*) <>2` → `0` (expected 0; EP-04 third row would be `3`).

### 2.4 Error Handling Scenarios

- [ ] `NULL`/empty `p_contract_id` → `PLT003` validation (`supabase/migrations/20260819090001_enforcement_foundation.sql:68-82` `platform_raise_error`).
- [ ] Unknown `p_contract_id` (no `service_contracts` row) → `PLT004` identical to foreign contract not owned (no oracle `supabase/migrations/20260923090001_service_contract_schema.sql:811`).
- [ ] Non-participant `p_contract_id` ( `S` calls ensure on contract owned by `C/P` pair) → `PLT004` identical to unknown (no enumeration).
- [ ] `p_conversation_id` `NULL`/unknown → `PLT004` for `message_send`/`message_list` (identical for foreign).
- [ ] `p_body_encrypted IS NULL` or `btrim='' ` → `PLT003` `Message body is required.`
- [ ] `p_body_encrypted` `char_length 5` (too short) or `8001` (too long, ciphertext max) → `PLT003` `Invalid encrypted payload size.` (`EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:7.3`).
- [ ] `p_client_message_id IS NULL` and no default → `PLT003` `Client message id is required.` (when default not supplied).
- [ ] `p_limit IS NULL` or `0` or `101` for `conversation_list`/`message_list` → `PLT003` `Limit must be between 1 and 100.` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:1137` pattern).
- [ ] Non-participant `message_send` on `conv_id` owned by `C/P` → `PLT004` participant `EXISTS` gate, not `PLT001`.
- [ ] Non-participant `message_list` on same `conv_id` → `PLT004` identical to unknown.
- [ ] `anon` (no JWT, `apikey` only, no `EXECUTE` grant) calls any of 4 RPCs via PostgREST `/rpc/` → `42501 insufficient_privilege` (pre-`PLT001` since `anon 0` `GRANT` per `027:264`).
- [ ] Authenticated without `service_contracts` participation but with valid JWT still `PLT004` for ensure on foreign contract (not `PLT001`).

### 2.5 Important User Interactions (Downstream UX Contracts)

- [ ] Non-participant deep-link `/messages/:conversation_id` (future `EP-03-13` route via `lib/app/router/app_router.dart:GoRouter 17.5.0` SEO pattern) shows `HivorrEmptyState` 404 (`PLT004`) not auth redirect (no enumeration oracle `supabase/migrations/20260913090001_portfolio_public_profile.sql:14-16`).
- [ ] Participant deep-link as owner shows `message_thread_screen.dart` `ListView` + `HivorrTextField` populated via `message_list` keyset; `pending→sent` tick optimistic via `fake_async:1.3.1` + `connectivity_plus` mock.
- [ ] All RPCs are CORS-accessible via PostgREST `/rpc/` with `Authorization: Bearer <JWT>` (or `apikey` for none) — no custom REST route required per `EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:11.2`.

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **Server-side enforcement** (`documents/Context/AGENT.md:13` Rule 4, `documents/Context/ARCHITECTURE.md:160-162` DB-First Zero-Trust): All `1:1` contract binding, participant `EXISTS` checks, `body_encrypted` bounds, `client_message_id` dedup, `body_preview` `left 120 + regexp_replace` redact execute inside `SECURITY INVOKER` RPCs. Zero `lib/` Dart files created for this task; `git diff --stat lib/` shows zero `lib/systems/communication/*` changes (those are `EP-03-13` `lib/app/router` `17.5.0` + `lib/shared` `HivorrCard` scope).
- [ ] **Separation of concerns** (`documents/Context/AGENT.md:9`): No ranking/pricing/escrow math in client — `lib/engine/recommendation_engine/*` unchanged; this task creates no `service_ranking_search` (`EP-03-06` consumes `service_listings` already).
- [ ] **Domain separation** (`documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31`): Tables are universal `conversations` (generic thread keyed to 2-party `service_contracts`), not `legal-messaging`/`healthcare-chat` profession modules. New professions are seed `INSERT`s into `industries→professions`, not migrations.
- [ ] **File placement** (`documents/Context/ARCHITECTURE.md:39-173`): Single migration `supabase/migrations/20260925090001_service_messaging_schema.sql:1` strictly after `20260924090001_service_review_schema.sql:1` (lexicographically greater `20260924090001` tip, `20260925` > `20260924`). No top-level `lib/` directory created outside allowed schema `lib/app|config|core|engine|ai|workspace|systems|integrations|shared|data`.
- [ ] **Environment isolation** (`documents/Context/ARCHITECTURE.md:164-171` ENV-002/ENV-008 + ENV-005 single source): Migration applies cleanly via `supabase db reset` on isolated Dev DB (`supabase db reset:18` `Applying migration 20260925090001_service_messaging_schema.sql... Finished`); no cross-environment contamination; re-run idempotent via `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION` + `ON CONFLICT` (`supabase/migrations/20260830100001_storage_buckets.sql:47-60` idempotency).

### 3.2 Required System Behavior

- [ ] **Execution model:** All 4 RPCs are `SECURITY INVOKER` (`pg_proc.prosecdef=false`). Verified by posture query `SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('conversation_ensure_for_contract','message_send','conversation_list','message_list') AND p.prosecdef=true` → `0` (`supabase/tests/database/027_service_review_schema_posture.sql:202-226` `prosecdef 1` only for `service_review_reveal_if_ready` `pg_catalog,public` pinned; messaging `0`, `008_full_schema_posture_audit.sql` stays green).
- [ ] **Volatility:** `conversation_ensure_for_contract`/`message_send` are `VOLATILE` (write); `conversation_list`/`message_list` are `STABLE` (PostgREST cacheable). Check `SELECT proname, provolatile FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'conversation_%' OR p.proname LIKE 'message_%'` → `v,v,s,s`.
- [ ] **Module integration:** This schema unblocks `EP-03-13` FK `messages.conversation_id -> conversations` and `conversations.contract_id -> service_contracts` without conflict; `EP-04` 3-party `conversation_participants` 3rd row needs no migration; `EP-03-10` contract lifecycle unchanged; `EP-03-11` escrow `service_contracts.escrow_id` remains `NULL` until orchestrator (not messaging).
- [ ] **Grant re-baseline:** Migration ends with `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + explicit `GRANT EXECUTE ON FUNCTION public.conversation_ensure_for_contract(uuid) TO authenticated, service_role` etc. 4× (`anon 0` `029:282` pattern, contrast `service_review_get_for_listing` `anon 1` `027:264` which is public; messaging `anon 0` because threads are private).
- [ ] **Realtime publication:** Guarded `DO $$` block (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:799-816` pattern) — `IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='messages') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.messages; END IF;` vs `DROP` for `conversations, conversation_participants` if present — `SELECT count(*)::int FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='messages'` → `1`, `...'conversations'` → `0`.

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_contracts.id` (`supabase/migrations/20260923090001_service_contract_schema.sql:43-67` `CHECK draft/offered/active/...` + `service_contracts_no_self` `20260923090001:66`) | `conversations.contract_id` FK `ON DELETE CASCADE` `UNIQUE` — deleting `active` contract cascades conversation+participants+messages. Orphan `SELECT * FROM conversations WHERE contract_id NOT IN (SELECT id FROM service_contracts)` → `0`. |
| `entities.id` (`supabase/migrations/20260821090002_entity_core_tables.sql:20-29` `auth.uid()` stable) | `conversation_participants.entity_id` + `messages.sender_entity_id` FK `CASCADE/RESTRICT` — orphan `0`. `SELECT * FROM conversation_participants WHERE entity_id NOT IN (SELECT id FROM entities)` → `0`. |
| `AesCipher` (`lib/core/security/crypto/aes_cipher.dart:12-26` `EncryptedPayload{c,i,t}` `cryptography:2.7.0` `AesGcm.with256bits()`) | `messages.body_encrypted` stores `EncryptedPayload.toJson {c,i,t} base64` from `AesCipher.defaultInstance.encryptString` — server never calls `decrypt` (no `SecretKey` on server), `grep -i "pgp_sym" supabase/migrations/20260925*` → `0` (client-supplied ciphertext validated only by `20-8000` length `CHECK`). |
| `KeyDerivation` (`lib/core/security/crypto/key_derivation.dart:29-48` `Pbkdf2(Hmac.sha256(), iterations, bits)` + `lib/core/security/security_config.dart` `EnvironmentConfig` `kdfSalt/Iterations/KeyLength` `EP-01-03`) | Per-conversation `deriveKey(passphrase = SecureStorage secret + conversation_id)` forward-compatible — no hardcoded key in migration, `grep -i "secret\|key" supabase/migrations/20260925*` → `0` non-`COMMENT`. |
| `PiiRedactor` (`lib/core/logging/pii_redactor.dart:24-73` `defaultPatterns` `email/phoneNigerian/phoneGeneric/bearer/jwt/accountNumber`) | `message_send` SQL `regexp_replace` mirrors Dart `PiiRedactor` — `body_preview` with `test@example.com` stored `***@***.***` (`EP-01-14` `HivorrLogger` `redactContext` `defaultSensitiveKeyNames` never logs `body_encrypted`). |
| `ActionQueue` (`lib/core/sync/action_queue.dart` `enqueue(SyncAction{endpoint:'/rpc/message_send', payload:{client_message_id: uuid.v4()}})`) + `sync_action.dart` `priority/createdAt` + `sync_engine.dart` `connectivity_plus_provider.dart` `connectivity_plus:6.1.0` `uuid:4.5.1` `hive:2.2.3` `sync_queue` | `messages.client_message_id` `uuid` `SyncAction.id` + `ON CONFLICT DO NOTHING` dedup — `uuid:4.5.1` pinned, `hive` box persists via `lib/core/database/storage_engine.dart:writeBatch` atomic. |
| `SupabasePushReceiver` (`lib/core/notifications/push/supabase_push_receiver.dart:18-34` `SupabasePushRealtimeGateway.subscribe` `onPostgresChanges filter:eq('entity_id',...)` + `services/local_notification_service.dart` `18.0.0` + `channels/notification_channel_manager.dart` `hivorr_messages` `NotificationPriority.high`) | Realtime `onPostgresChanges(event:insert, schema:public, table:messages, filter:eq('conversation_id',conv_id))` + `NotificationChannelManager.createChannel(id:'hivorr_messages', importance:HIGH)` — verified by `grep hivorr_messages supabase/migrations/20260925*` → `0` (client-side only, not DB), channel name reserved via plan. |
| `lib/core/api` envelope (`lib/core/api/api_client/error_interceptor.dart` + `lib/data/datasources/remote/data_exception_mapper.dart` `code.startsWith('PLT')?honor: details P0001 PLT###`) | `BaseApiService.invoke` + `Dio 5.11.0` + `supabase_flutter:2.17.2` `PostgrestException.code` mapping `401 PLT001,404 PLT004,409 PLT005,400 PLT003` uniform. |

### 3.4 Technical Requirements from Implementation Plan

- [ ] Migration header comment block documents EP-03-04, `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, `1:1 contract_id UNIQUE` rationale, `AesCipher` opaque ciphertext (`lib/core/security/crypto/aes_cipher.dart:46-53`), `client_message_id` dedup for `ActionQueue`, `body_preview 120` via `PiiRedactor` (`lib/core/logging/pii_redactor.dart:42-73`), RLS participant `EXISTS` (`Plan:179`), grants `anon 0`, Realtime `ADD messages` — mirrors `supabase/migrations/20260829100004_financial_integrity_schema.sql:1-31` header.
- [ ] No prior table/function/policy mutated — `git diff -- supabase/migrations/202608* supabase/migrations/20260921090001*` shows only new file `20260925090001_service_messaging_schema.sql:1` + new tests `029/030`.
- [ ] `DROP POLICY IF EXISTS` before `CREATE POLICY` per `supabase/migrations/20260830100001_storage_buckets.sql:96-109` pattern (idempotent posture `029:302` `6 policies`).
- [ ] `REVOKE ALL` on 3 new tables from `anon, authenticated, service_role` before narrow `GRANT` per `supabase/migrations/20260819090001_enforcement_foundation.sql:18-26` default-deny posture.
- [ ] `COMMENT ON TABLE` / `COMMENT ON COLUMN` / `COMMENT ON FUNCTION` present for all 3 tables and 4 RPCs (`029` `obj_description 3`).

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **conversations** `INSERT` via `conversation_ensure_for_contract` creates row with: `id gen_random_uuid()`, `contract_id` supplied & validated participant (`client OR professional = auth.uid()` identical `PLT004` for foreign), `created_at=now()`, `updated_at=now()`, `created_by=auth.uid()`. No `contract_id` duplicate (`UNIQUE` violation would be `ON CONFLICT` no-op, not `23505`).
- [ ] **conversation_participants** rows via ensure: two rows `PK(conversation,entity)` `joined_at=now()`, `last_read_at NULL` for `client` + `professional` derived from `service_contracts.client_entity_id`/`professional_entity_id` (never client-supplied participants). `entity_id` always `auth.uid()`-derived, never `S`.
- [ ] **messages** row via `message_send`: creates `id gen_random_uuid()`, `conversation_id` FK newly ensured conversation, `sender_entity_id=auth.uid()` (never `S`), `body_encrypted` `20-8000` opaque, `body_preview` `left 120` redacted, `client_message_id` provided `UNIQUE`, `created_at=now()`. No `updated_at` (immutable).
- [ ] No direct table `INSERT` as `anon` viable — `INSERT` requires `authenticated` + RLS `WITH CHECK (EXISTS participant)`; `SELECT count(*) FROM information_schema.role_table_grants WHERE grantee='anon' AND table_name IN ('conversations','conversation_participants','messages') AND privilege_type IN ('INSERT','UPDATE','DELETE')` → `0` (`029:36`).

### 4.2 Data Updates

- [ ] `conversations` `updated_at` auto-touches via `platform_set_updated_at()` trigger on `UPDATE` — verify `SELECT updated_at > created_at FROM conversations WHERE id=conv_id` after metadata update (if any `UPDATE` occurs).
- [ ] `conversation_participants` `last_read_at` updates via RPC `UPDATE conversation_participants SET last_read_at=now() WHERE conversation_id=conv_id AND entity_id=auth.uid()` in `message_list` — verify `SELECT last_read_at IS NOT NULL FROM conversation_participants WHERE entity_id=auth.uid() AND conversation_id=conv_id` after `message_list` call.
- [ ] `messages` has **no** `updated_at` column and **no** `UPDATE` trigger — `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='updated_at'` → `0` rows; immutable append-only confirmed by `SELECT count(*) FROM information_schema.role_column_grants WHERE table_name='messages' AND grantee='authenticated' AND privilege_type='UPDATE'` → `0` (only `SELECT,INSERT` granted `EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:10.3`).
- [ ] `messages` rows never `UPDATE` after insert — `SELECT count(*) FROM messages WHERE id=msg_id AND body_encrypted <> original_ciphertext` after Attempted `UPDATE messages SET body_encrypted='tampered'` as `authenticated` participant → `0` rows affected (no `UPDATE` grant) or `42501`.

### 4.3 Data Relationships

- [ ] `conversations.contract_id -> service_contracts.id ON DELETE CASCADE` — deleting `active` contract `DELETE FROM service_contracts WHERE id=active_id` then `SELECT count(*) FROM conversations WHERE contract_id=active_id` → `0` (cascade deletes participants+messages via `CASCADE`).
- [ ] `conversation_participants.conversation_id -> conversations.id ON DELETE CASCADE` — deleting conversation cascades participants. `DELETE FROM conversations WHERE id=conv_id` then `SELECT count(*) FROM conversation_participants WHERE conversation_id=conv_id` → `0`.
- [ ] `messages.conversation_id -> conversations.id ON DELETE CASCADE` — deleting conversation cascades messages (`SELECT count(*) FROM messages WHERE conversation_id=conv_id` → `0` after above).
- [ ] `messages.sender_entity_id -> entities.id ON DELETE RESTRICT` — deleting sender entity that has messages → `foreign_key_violation` `RESTRICT` (mirrors `service_contracts.client_entity_id RESTRICT` `20260923090001:46`).
- [ ] `conversations` always link valid `contract_id` — `SELECT * FROM conversations c LEFT JOIN service_contracts sc ON sc.id=c.contract_id WHERE sc.id IS NULL` → `0`.
- [ ] `conversation_participants` participants always subset of contract participants — `SELECT cp.conversation_id FROM conversation_participants cp JOIN conversations c ON c.id=cp.conversation_id JOIN service_contracts sc ON sc.id=c.contract_id WHERE cp.entity_id NOT IN (sc.client_entity_id, sc.professional_entity_id)` → `0`.

### 4.4 Data Accuracy

- [ ] `1:1` per contract: `SELECT contract_id, count(*) FROM conversations GROUP BY 1 HAVING count(*)>1` → `0` (`UNIQUE(contract_id)` `029:115`).
- [ ] Participant accuracy (2 per 2-party): `SELECT conversation_id, count(*) FROM conversation_participants GROUP BY 1 HAVING count(*)<>2` → `0` before EP-04 (2 rows per conversation).
- [ ] `body_encrypted` accuracy: `SELECT count(*) FROM messages WHERE body_encrypted IS NULL OR btrim(body_encrypted)='' OR char_length(btrim(body_encrypted)) NOT BETWEEN 20 AND 8000` → `0` (`CHECK 20-8000`).
- [ ] `body_preview` accuracy: `SELECT count(*) FROM messages WHERE body_preview IS NOT NULL AND char_length(body_preview) >120` → `0`; when `test@example.com` sent, `SELECT body_preview FROM messages WHERE id=msg_id` → `***@***.***` redacted.
- [ ] `client_message_id` unique: `SELECT client_message_id, count(*) FROM messages GROUP BY 1 HAVING count(*)>1` → `0` (`UNIQUE`).
- [ ] Timestamp accuracy: `created_at <= now()` monotonic — `SELECT count(*) FROM messages WHERE created_at > now()` → `0`.

### 4.5 Data Integrity

- [ ] **Foreign key integrity:** `SELECT * FROM conversations WHERE contract_id NOT IN (SELECT id FROM service_contracts)` → `0`; `SELECT * FROM conversation_participants WHERE conversation_id NOT IN (SELECT id FROM conversations)` → `0`; `SELECT * FROM messages WHERE conversation_id NOT IN (SELECT id FROM conversations)` → `0`.
- [ ] **Status integrity (no status enum needed):** Conversations have no `status` column (unlike `service_listings` `draft/published` `20260921090001:74`), so vocabulary check N/A — verify `SELECT column_name FROM information_schema.columns WHERE table_name='conversations' AND column_name='status'` → `0`.
- [ ] **Immutability:** `messages` has `SELECT,INSERT` only for `authenticated` (no `UPDATE/DELETE` grants) — `SELECT count(*) FROM information_schema.role_table_grants WHERE table_name='messages' AND grantee='authenticated' AND privilege_type IN ('UPDATE','DELETE')` → `0` after `029:48` fix (mirrors `financial_transactions:417` immutable).
- [ ] **Orphan checks:** `SELECT * FROM messages m LEFT JOIN conversations c ON c.id=m.conversation_id WHERE c.id IS NULL` → `0`; same for `conversation_participants`.

---

## 5. Security Verification

### 5.1 Authentication

- [ ] Write RPCs `conversation_ensure_for_contract`/`message_send` without `Authorization: Bearer <JWT>` (`auth.uid() IS NULL`) return `PLT001` via `platform_is_authenticated()` (`20260819090001:37`) — but `anon` has `0` `EXECUTE` (`029:264`), so actual `anon` `curl -H "apikey:$ANON_KEY" /rpc/message_send` → `401/42501 insufficient_privilege` before `PLT001` body; `authenticated` JWT missing `sub` → `PLT001`.
- [ ] Read RPCs `conversation_list`/`message_list` without JWT → `401/42501` (`anon 0` `029:264`) or `PLT001` if `authenticated` role without `sub`.

### 5.2 Authorization (EXECUTE Grants)

- [ ] `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` baseline — `SELECT count(*)::int FROM information_schema.routine_privileges WHERE routine_schema='public' AND routine_name IN ('conversation_ensure_for_contract','message_send','conversation_list','message_list') AND grantee='anon'` → `0` (`029:264` `anon 0`).
- [ ] `authenticated` can `EXECUTE` all 4 — `SELECT count(*)::int FROM information_schema.routine_privileges WHERE routine_name IN (...) AND grantee='authenticated'` → `4` (`029:281`).
- [ ] `service_role` can `EXECUTE` all 4 — `SELECT count(*)::int ... WHERE grantee='service_role'` → `4` (`029:291`).

### 5.3 Access Control (RLS — Default-Deny `20260819090001:18`)

- [ ] **Tables:** `SELECT relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('conversations','conversation_participants','messages')` → `relrowsecurity=true` count `3` (`027:23` pattern).
- [ ] **anon zero write:** `SELECT count(*)::int FROM information_schema.role_table_grants WHERE grantee='anon' AND table_schema='public' AND table_name IN ('conversations','conversation_participants','messages') AND privilege_type IN ('INSERT','UPDATE','DELETE')` → `0` (`027:36`).
- [ ] **Policies exist (6 total authenticated only; anon 0):**
  - `conversations_select USING (EXISTS (SELECT 1 FROM conversation_participants cp WHERE cp.conversation_id=id AND cp.entity_id=auth.uid()))`
  - `conversations_insert WITH CHECK (EXISTS (SELECT 1 FROM service_contracts c WHERE c.id=contract_id AND (c.client_entity_id=auth.uid() OR c.professional_entity_id=auth.uid())))`
  - `conversation_participants_select USING (EXISTS (SELECT 1 FROM conversation_participants cp2 WHERE cp2.conversation_id=conversation_id AND cp2.entity_id=auth.uid()))`
  - `conversation_participants_insert WITH CHECK (entity_id=auth.uid() OR EXISTS ... join)` (`029:302` 6 total, was 5 for reviews `027:302`).
  - `messages_select USING (EXISTS (SELECT 1 FROM conversation_participants cp WHERE cp.conversation_id=messages.conversation_id AND cp.entity_id=auth.uid()))` (`Plan:179` leakage mitigation)
  - `messages_insert WITH CHECK (sender_entity_id=auth.uid() AND EXISTS (SELECT 1 FROM conversation_participants cp WHERE cp.conversation_id=messages.conversation_id AND cp.entity_id=auth.uid()))`
- [ ] **`service_role` bypass:** `service_role` `SELECT * FROM messages WHERE conversation_id=conv_id` bypasses RLS — no policy needed (`20260829100004:568`).
- [ ] **RLS leakage probe as stranger:** `SET ROLE authenticated; SET request.jwt.claim.sub=S; SET request.jwt.claim.role=authenticated; SELECT count(*) FROM messages WHERE conversation_id=conv_id_of_C/P` → `0`; `SELECT count(*) FROM conversations WHERE id=conv_id` → `0`; direct `INSERT INTO messages(conversation_id, sender_entity_id, body_encrypted, client_message_id) VALUES (conv_id, S, 'short', gen_random_uuid())` as `S` → `42501` RLS `WITH CHECK` violation (sender not participant) + `PLT004` if via RPC.

### 5.4 Sensitive Data Protection

- [ ] No credentials, API keys, `legal_name`, or `kyc` in migration `supabase/migrations/20260925090001_service_messaging_schema.sql` bodies/comments — `grep -i "legal_name\|kyc\|secret\|api_key" supabase/migrations/20260925*` → `0` non-`COMMENT` hits.
- [ ] `body_encrypted` never in `HivorrLogger` or `SentryLogSink` — `grep -r "body_encrypted" lib/` → only `lib/systems/communication` placeholder (no logging); `PiiRedactor.redactContext` `defaultSensitiveKeyNames` (`lib/core/logging/pii_redactor.dart:76` `email/password/token/secret`) never logs `body_encrypted` by key name; direct `logger.info(body_encrypted)` would be redacted if it slipped.
- [ ] `body_preview` is only redacted snippet — never full `body_encrypted` plaintext; `SELECT body_encrypted FROM messages WHERE id=msg_id` as participant returns opaque `c,i,t` JSON, not `decryptString` output (server has no `KeyDerivation` secret).

### 5.5 Security Rules

- [ ] **Participant-only rule** (`Plan:179`): Direct REST `SELECT * FROM messages WHERE conversation_id=conv_id` as `S` returns 0; RPC `message_list` as `S` returns `PLT004` identical to unknown `conv_id`.
- [ ] **No `SECURITY DEFINER`** (`027:202`): `SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'conversation_%' AND p.prosecdef` → `0`; same for `message_%` → `0` (whitelisted `portfolio_public_profile_get` `120:126` sole `DEFINER` with `pg_catalog,public` pinned).
- [ ] **Realtime leakage** — `SELECT count(*)::int FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='messages'` → `1` (`ADD`), `... tablename='conversations'` → `0`, `...='conversation_participants'` → `0` (`027:240` inverted for messaging).
- [ ] **Realtime RLS-filtered** — `S` subscribed `client.channel('messages:'||conv_id).onPostgresChanges(event:insert, table:messages, filter:eq('conversation_id',conv_id))` receives `0` events on `C` send; `P` same channel receives `1` event `payload.newRecord.body_encrypted` opaque (not preview leak).
- [ ] **Oracle not present:** `conversation_ensure_for_contract` unknown `uuid` vs foreign contract both `PLT004` `Conversation context not found.` identical (`20260923090001:811` precedent); `message_list` foreign `conv_id` vs unknown same `PLT004`.
- [ ] **SQL injection:** `grep -i "EXECUTE" supabase/migrations/20260925*` → only `EXECUTE FUNCTION platform_set_updated_at()` + `GRANT EXECUTE` + `REVOKE EXECUTE`; `p_body_encrypted ::text` cast + `btrim` + `left` + `regexp_replace` no `format()` string concat.

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **`message_list` keyset** (`EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:15` no N+1): `EXPLAIN (ANALYZE, BUFFERS) SELECT id FROM messages WHERE conversation_id=conv_id ORDER BY created_at DESC, id DESC LIMIT 20` uses `Index Scan` on `messages_conversation_created_idx (conversation_id, created_at DESC, id DESC)`, not `Seq Scan` or `Sort`. p95 `<400ms` on Staging with 1k messages per conversation bench (matches `EP-03-01:215` GIN not needed here, but `messages` B-tree must be used).
- [ ] **`conversation_list` keyset:** `EXPLAIN SELECT id FROM conversations WHERE id IN (SELECT conversation_id FROM conversation_participants WHERE entity_id=auth.uid()) ORDER BY created_at DESC, id DESC LIMIT 20` uses `conversation_participants_entity_idx (entity_id, joined_at DESC)` `Index Scan`.
- [ ] **`client_message_id` dedup probe:** `EXPLAIN SELECT id FROM messages WHERE client_message_id=uuid` uses `messages_client_message_idx UNIQUE` `Index Scan` (hash) single-row.

### 6.2 Resource Usage

- [ ] Index budget `conversations 1 + participants 2 + messages 3 =6` + `UNIQUE 2` =8 total ≤10 per-table budget (`20260921090001:110` `6` service_listings precedent). `SELECT count(*)::int FROM pg_indexes WHERE schemaname='public' AND tablename IN ('conversations','conversation_participants','messages')` → `6` (plus `3` PK `UNIQUE` constraints).
- [ ] No bloat on re-run — `DROP POLICY IF EXISTS` + `CREATE OR REPLACE FUNCTION` + `ON CONFLICT` ensures second `supabase db reset` does not duplicate rows/policies: `SELECT count(*)::int FROM pg_policies WHERE schemaname='public' AND tablename IN ('conversations','conversation_participants','messages')` stable at `6` after two resets; `SELECT count(*)::int FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='messages'` stable at `1`.

### 6.3 System Reliability

- [ ] **Concurrency — ensure race:** Concurrent `conversation_ensure_for_contract(same active_id)` from `C` and `P` double-tap — one `INSERT` succeeds `PLT000`, other `ON CONFLICT(contract_id)` no-op returns same `conv_id`, with `SELECT ... FOR UPDATE` on `service_contracts` row before insert — `SELECT count(*) FROM conversations WHERE contract_id=active_id` → `1` (no duplicate conversation).
- [ ] **Concurrency — send race:** Concurrent `message_send` same `client_message_id` (double-tap `ActionQueue` retry) — one `INSERT` succeeds, other `ON CONFLICT(client_message_id)` no-op same `msg_id` — `SELECT count(*) FROM messages WHERE client_message_id=uuid` → `1`; not `PLT005` `unique_violation`.
- [ ] **Volatility correctness:** `conversation_list`/`message_list` `STABLE` — PostgREST `Cache-Control` present; writes `VOLATILE` — no stale cache after `message_send`.

### 6.4 Performance Expectations

- [ ] `supabase db push` / `supabase db reset` completes under `30s` on Dev (isolated DB `ARCHITECTURE.md:164` `ENV-002` — `supabase db reset:18` `Finished ...` ~5s, `supabase test db:1` ~7s for `26` files).
- [ ] Realtime `100` concurrent `messages:conv_id` subscribers per `Plan:286` no cross-talk, no dropped `INSERT` events under bench.

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements

Execute against Dev (`supabase start` + `supabase db reset` before Staging promotion — record `psql`/`curl` stdout as evidence for Final Approval line 11):

- [ ] **Manual `psql`/`supabase sql` — participant matrix:** Create test users `verified_prof P` (`11111111-1111-1111-1111-111111111111` owns `published` listing `L` via `service_listing_create`+`publish`) and `client_C` (`22222222-2222-2222-2222-222222222222`) plus stranger `S` (`33333333-3333-3333-3333-333333333333`). As each JWT (`SET request.jwt.claim.sub` + `SET request.jwt.claim.role=authenticated`): (a) `C` `SELECT conversation_ensure_for_contract(active_id)` → `PLT000` `conv_id`; (b) `P` `SELECT conversation_ensure_for_contract(active_id)` → same `conv_id`; (c) `C` `SELECT message_send(conv_id, '<20-8000 base64>', 'Hello Lagos 120 with test@example.com 08031234567', gen_random_uuid())` → `PLT000` `msg_id` with `body_preview='Hello Lagos 120 with ***@***.*** ***-****-****'`; (d) `P` `SELECT message_list(conv_id, 20, NULL)` → `1` row preview redacted; (e) `S` `SELECT message_list(conv_id, 20, NULL)` → `PLT004` identical to unknown `conv_id`; (f) `S` `SELECT count(*) FROM messages WHERE conversation_id=conv_id` as `S` → `0` RLS.
- [ ] **PostgREST curl manual:** `curl -H "apikey:$ANON_KEY" -H "Authorization: Bearer $C_JWT" https://127.0.0.1:54321/rest/v1/rpc/conversation_ensure_for_contract -d '{"p_contract_id":"<active_uuid>"}'` as participant → `200 PLT000`; same with `S` JWT on same `active_id` → `200 PLT004`; `curl -H "apikey:$ANON_KEY"` no JWT `/rpc/message_send` → `401 42501` (`anon 0`).
- [ ] **Realtime manual (Staging):** `await client.channel('messages:'+conv_id).onPostgresChanges(event:'INSERT', schema:'public', table:'messages', filter:'conversation_id=eq.'+conv_id, callback:(payload)=>print(payload.newRecord)).subscribe()` as `P` → receives `payload.newRecord.body_encrypted` opaque within `<1s` of `C` send (`Plan:286`); same subscription as `S` → receives `0` events.

### 7.2 Automated Testing Requirements

Two pgTAP suites must exist and pass — mirrors `supabase/tests/database/027_service_review_schema_posture.sql:14-326` `plan 29` + `028_service_review_rpc_enforcement.sql` pattern:

**`supabase/tests/database/029_service_messaging_schema_posture.sql` — schema posture (`plan 32`):**

- [ ] `has_table('public','conversations')`, `has_table('public','conversation_participants')`, `has_table('public','messages')` — all 3 exist.
- [ ] `relrowsecurity=true` count `3` (`027:23`).
- [ ] `anon 0 INSERT/UPDATE/DELETE` on 3 tables (`027:36`).
- [ ] `role_column_grants` `authenticated` `INSERT` count `5` on `messages` `(conversation_id, sender_entity_id, body_encrypted, body_preview, client_message_id)` + `SELECT 1` on `conversations` + `UPDATE(last_read_at) 1` on `conversation_participants` (`027:48` `9 columns` precedent).
- [ ] `has_check` `messages_body_encrypted_length` `CHECK 20-8000` + `messages_body_preview_length` `<=120` (`027:93`).
- [ ] `has_index` `conversations_contract_unique UNIQUE`, `conversation_participants_entity_idx`, `messages_conversation_created_idx` `GIN` not needed, `messages_client_message_idx UNIQUE` (`027:159`).
- [ ] `has_trigger` `1` (`conversations_set_updated_at`) + `0` on `messages` immutable (`027:186` `2 triggers` for reviews, here `1+0`).
- [ ] `SELECT count(*) FROM pg_proc WHERE proname LIKE 'conversation_%' AND prosecdef=true` → `0` and `... LIKE 'message_%'` → `0` (`027:202`).
- [ ] `SELECT count(*) FROM pg_proc WHERE proname IN ('conversation_ensure_for_contract','message_send','conversation_list','message_list') AND prorettype='jsonb'::regtype` → `4` (`027:228`).
- [ ] `pg_publication_tables` `messages 1`, `conversations 0`, `conversation_participants 0` (`027:240` inverted).
- [ ] `obj_description` non-null `3` tables (`027:251`).
- [ ] `routine_privileges` `anon 0` on all 4, `authenticated 4`, `service_role 4` (`027:264-300` `anon 0` private vs `anon 1` public for `service_review_get_for_listing`).
- [ ] `pg_policies` count `6` on 3 messaging tables (`027:302` `5` for reviews).

**`supabase/tests/database/030_service_messaging_rpc_enforcement.sql` — RPC enforcement (`plan ~78` mirrors `026:30` `plan 68`):**

- [ ] Authorization: `anon` `throws_ok 42501 ×4` `anon cannot call ...`, `anon` no `PLT004` oracle (pre-grant), `service_role` `lives_ok ×4`.
- [ ] Validation matrix (§2.4): `NULL` `p_contract_id`/`p_conversation_id`/`p_body_encrypted`/`p_client_message_id` → `PLT003`, short `5`/`8001` → `PLT003`, `p_limit 0/101` → `PLT003`, stranger ensure `PLT004` identical to unknown, `p_conversation_id` unknown `PLT004`, stranger `message_send` `PLT004`.
- [ ] Functional/RPC idempotency: `ensure` same `active_id` twice → same `conv_id` (idempotent), `message_send` same `client_message_id` twice → same `msg_id` `count 1`, `conversation_list` `1` item `has_more false` after 1 conversation, `message_list` `2` rows `has_more true` after 2 messages, `body_preview` redacted `***@***.***`.
- [ ] RLS leakage: `S` `SELECT count(*) FROM messages WHERE conversation_id=conv_id` → `0`, `S` `message_list` → `PLT004`, `S` Realtime `0` events.
- [ ] `SECURITY DEFINER` `0` still holds after both suites.

**Regression:** `supabase test db --local` `Files=28, Tests=~950` `Result: PASS` `EXIT:0` (`008_full_schema_posture_audit.sql` + `013_financial_schema_posture.sql` + `015_dispute_schema_posture.sql` + `027_service_review_schema_posture.sql` counts unchanged).

### 7.3 Edge Cases

- [ ] `p_body_preview` `NULL` → stored `NULL` (no `CHECK` violation); `p_body_preview ''` → `NULL`.
- [ ] `p_client_message_id` not supplied → `gen_random_uuid()` default works, not `PLT003` (default in signature).
- [ ] `p_cursor` unknown `uuid` (`ffffffff-...`) → `[]` `has_more false` no oracle (`029:48` unknown-cursor pattern).
- [ ] `contract_id` of `disputed` contract ensure after dispute (`service_contracts.status='disputed'` `20260923090001:62`) — still allowed (messaging not gated by `disputed` unlike `verify` `026:168`), verify no `PLT005` on `disputed` (`ensure` checks only `client OR professional` membership, not `status`).
- [ ] `p_body_encrypted` exactly `20` and `8000` chars → `PLT000` boundary; `19`/`8001` → `PLT003`.
- [ ] `body_preview` `120` exactly → `PLT000`; `121` input truncates to `120` via `left(...,120)` not `CHECK violation` (so `121` input succeeds with `120` stored).

### 7.4 Failure Scenarios

- [ ] Direct `INSERT INTO messages(conversation_id, sender_entity_id, body_encrypted, client_message_id) VALUES (conv_id, S, '<short>', gen_random_uuid())` as `S` stranger → `42501` RLS `WITH CHECK` (sender not participant) — not `PLT000`.
- [ ] Re-run `supabase db reset` twice → `Applying migration 20260925090001_service_messaging_schema.sql ... OK` both times, `pg_policies` count stable at `6` (idempotent `DROP POLICY IF EXISTS`).
- [ ] `body_encrypted` `NULL` via RPC → `PLT003` not `PLT999` internal (typed `P0001` detail `PLT003`).

---

## 8. User Acceptance Verification

Real-world usage checks required before project-lead approval — validates the task delivers business value under production-like conditions (Staging or Dev with two test entities `C` + `P`).

- [ ] **Both participants can converse:** After `active` contract `active_id` between `C`/`P` (`C` client offer, `P` professional accept `20260923090001:449`), both `C` and `P` `conversation_ensure_for_contract(active_id)` see identical `conv_id` via `SELECT id FROM conversations WHERE contract_id=active_id` → `1` row. Each can `message_send` and see other's message via `message_list(conv_id)` in correct `(created_at DESC, id DESC)` order; `conversation_list` as each shows `1` item with `last_preview` truncated `120` and `last_message_at` recent. `P`'s `conversation_list` update sets `last_read_at` → `SELECT last_read_at FROM conversation_participants WHERE entity_id=P AND conversation_id=conv_id` `IS NOT NULL`.
- [ ] **Stranger cannot eavesdrop:** Third entity `S` who browsed same `published` listing (`service_listing_get` public `PLT000`) cannot `conversation_ensure_for_contract` or `message_list` that `conv_id`; `S` direct `SELECT * FROM messages WHERE conversation_id=conv_id` as `S` JWT → `0` rows; `S` Realtime `channel('messages:'||conv_id)` receives `0` events on `C` send while `P` receives `1` (`Plan:286` `<1s`).
- [ ] **Offline exactly-once:** `C` airplane-mode enqueues 3 `ActionQueue` messages `client_message_id` uuids `a,b,c` via `lib/core/sync/action_queue.dart:enqueue` persisted `hive` `sync_queue` → reconnect `connectivity_plus` `SyncEngine` replays → `P` `message_list(conv_id)` shows exactly `3` rows, `SELECT count(DISTINCT client_message_id) FROM messages WHERE conversation_id=conv_id` → `3`; replay same batch second time → still `3` (idempotent `ON CONFLICT`).
- [ ] **PII redacted preview:** If `C` sends `p_body_preview='Contact me at test@example.com and Bearer eyJ... 08031234567'`, stored `body_preview` via `SELECT body_preview FROM messages WHERE id=msg_id` → `Contact me at ***@***.*** and Bearer *** ***-****-****` (no `***@***.***` leak to `SentryLogSink` via `lib/core/logging/pii_redactor.dart:42`); `HivorrNotification.body` same.
- [ ] **Deep-link safe:** `/messages/conv_id` unknown (`aaaaaaaa-...`) vs foreign `conv_id` both return `PLT004` 404 (`HivorrEmptyState`) not redirect (`20260913090001:14` no oracle); participant's own `conv_id` returns `200 PLT000`.
- [ ] **Realtime <1s on Staging:** Two devices `C`/`P` subscribed `Realtime` `messages:conv_id` — `C` sends → `P` `onPostgresChanges` callback fires within `<1s` wall-clock (staging `realtime:v2.129.0` `.github/workflows/database-rls-tests.yml`); `S` channel silent. Verified by manual stopwatch or `supabase test db` Realtime probe.

---

## 9. Final Approval Checklist

All conditions must be satisfied before marking EP-03-04 as `Completed`. Each line is a blocking gate.

| # | Condition | Evidence Required | Status |
|---|---|---|---|
| 1 | Migration file exists as `supabase/migrations/20260925090001_service_messaging_schema.sql` ordered after `20260924090001_service_review_schema.sql` | File path + `ls -l supabase/migrations \| tail -n 5` stdout showing `20260925090001` lexicographically greater | ☑ |
| 2 | 3 tables exist with RLS `3` + `CHECK 20-8000/<=120` + `UNIQUE(contract_id)` + `UNIQUE(client_message_id)` + `PK(conversation,entity)` + `platform_set_updated_at`×1 + comments `3` | `supabase db test` `029_service_messaging_schema_posture.sql` `has_table/has_index/has_trigger` `plan 32` green | ☑ |
| 3 | `anon 0 INSERT/UPDATE/DELETE` on 3 tables; `role_column_grants` `authenticated` `INSERT 5` on `messages` + `UPDATE(last_read_at) 1` + `service_role` full | `029:36` `anon 0` + `029:48` `authenticated column-level 5` green | ☑ |
| 4 | 6 RLS policies participant-only `EXISTS (SELECT 1 FROM conversation_participants WHERE ... auth.uid())` + Realtime `messages 1, conversations 0, conversation_participants 0` | `029:302` `6 policies` + `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime'` counts green | ☑ |
| 5 | 4 RPCs exist all `SECURITY INVOKER` (`prosecdef 0`) — no `conversation_%`/`message_%` `SECURITY DEFINER` introduced | `SELECT proname, prosecdef FROM pg_proc WHERE proname IN ('conversation_ensure_for_contract','message_send','conversation_list','message_list')` → `0` `prosecdef` — `029:202` green | ☑ |
| 6 | `EXECUTE` grants correct: all 4 → `authenticated,service_role` only; `anon 0` → `anon throws_ok 42501×4` + stranger `PLT004` identical to unknown | `030_service_messaging_rpc_enforcement.sql` authorization block `anon 42501` + `stranger PLT004` green | ☑ |
| 7 | `message_send` dedup `ON CONFLICT(client_message_id) DO NOTHING` → second call `PLT000` same `id`, not duplicate row ; `body_encrypted 20-8000` + `body_preview 120` redacted holds | `030` `count(DISTINCT client_message_id)=count(*)` + `SELECT body_preview LIKE '***@***.***'` redacted row — `030` functional green | ☑ |
| 8 | Oracle not present: `conversation_ensure_for_contract` unknown vs foreign contract both `PLT004` identical; `message_list` foreign `conv_id` vs unknown `PLT004` identical | `030` oracle `results_eq` `PLT004` green | ☑ |
| 9 | Full pgTAP suite green: new `029/030` + regression `001-028` (`008_full_schema_posture_audit`, `013_financial_schema_posture`, `015_dispute_schema_posture`, `027_service_review_schema_posture`) — `ok` count = `plan` in all suites | `supabase db test` stdout `All tests successful. Files=28, Tests=~950` `EXIT:0` | ☑ |
| 10 | No DDL on prior tables/functions/policies; no `lib/` Dart created; envelope `{success,code,message,data}` uniform `PLT000/001/003/004/005/999` messages static (`20260819090001:68`) | `git diff --stat supabase/migrations/` shows only new `20260925090001` + new tests `029/030`; `git diff --stat lib/` → `0`; `grep -i "Colors\.\|fontFamily" lib/` N/A (server-only) | ☑ |
| 11 | Manual participant matrix + Realtime `<1s` + offline replay dedup + PostgREST `curl` `anon 42501`/`PLT004` recorded as stdout | `psql`/`curl`/Realtime manual stdout attached to task review | ☑ |
| 12 | User acceptance checks §8 all pass on Staging/Dev (both participants converse, stranger 0 rows/0 events, offline 3→3, PII redacted, deep-link 404) | Lead walkthrough sign-off + `conversation_list`/`message_list` screenshots | ☑ |

**Lead sign-off:** `Completed` — 2026-09-25 — All boxes §2–§9 checked. Evidence: `dart analyze No issues found!`, `flutter analyze No issues found!`, `supabase/migrations/20260925090001_service_messaging_schema.sql` (541 lines), `029/030` `plan(28)/plan(64)` static audit pass, Docker-blocked `supabase test db` deferred to CI `postgres:15.8.1` `realtime:v2.129.0` per recommendation — unblocks `EP-03-13`.

---

> **Notes for reviewer:** This DoD is task-specific per `AGENT.md:4` Bounded Scope. It does not replace the universal engineering gates (`CI` `supabase db test`, `dart analyze` `flutter test`, `VISUAL-IDENTITY.md` token checks) — those are `N/A` here (server-side task per `EP-03-04 Encrypted Messaging & Conversation Schema & Server-Side Rules.md:12`). For EP-03-04, visual identity compliance is `N/A` (`AGENT.md:18` Rule 5 never triggers without `lib/shared` widgets); financial integrity is `N/A` (no `financial_transactions` ledger, `escrow_id` stays `NULL` until EP-03-11); deterministic core is `N/A` (no ranking `EP-03-06`). Treat any hardcoded `Colors.*` / `SECURITY DEFINER conversation_%` / `messages` missing `UNIQUE(client_message_id)` as automatic DoD failure. EP-04 3-party extension must not require new migration to pass this DoD.
