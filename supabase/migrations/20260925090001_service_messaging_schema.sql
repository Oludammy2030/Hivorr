-- EP-03-04: Encrypted Messaging & Conversation Schema & Server-Side Rules
--
-- Contract-scoped encrypted messaging fabric: 3 tables (conversations,
-- conversation_participants, messages) + 4 SECURITY INVOKER RPCs with
-- participant-only RLS, opaque ciphertext at-rest, and RLS-filtered Realtime.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER for all 4 RPCs (RLS applies inside body); no new
--     SECURITY DEFINER (008/013/015/023/025/027 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - 1:1 binding: conversations.contract_id UNIQUE -> service_contracts.id
--     ON DELETE CASCADE. Two conversation_participants rows (client, professional)
--     derived from service_contracts.client_entity_id/professional_entity_id,
--     never client-supplied. EP-04 3-party reuses same PK with third row.
--   - At-rest encryption: messages.body_encrypted stores opaque ciphertext
--     EncryptedPayload.toJson {c,i,t} base64 from lib/core/security/crypto/
--     aes_cipher.dart AesCipher.defaultInstance.encryptString with per-
--     conversation SecretKey via KeyDerivation.fromConfiguration. Server
--     validates 20-8000 bounds only, never decrypts. body_preview is
--     left(120) + regexp_replace PII mirror of lib/core/logging/
--     pii_redactor.dart defaultPatterns.
--   - Offline idempotency: messages.client_message_id uuid UNIQUE +
--     INSERT ... ON CONFLICT (client_message_id) DO NOTHING deduplicates
--     lib/core/sync/action_queue.dart SyncAction.id replay.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 3 tables from anon, authenticated, service_role then narrow
--     SELECT on conversations to authenticated (participant RLS), SELECT,INSERT
--     on conversation_participants + SELECT,INSERT(column-level) on messages to
--     authenticated, full to service_role. anon 0 (threads are private, not
--     public like service_listing_get or service_review_get_for_listing).
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public then explicit GRANT EXECUTE
--     per RPC (4 x authenticated+service_role, anon 0).
--
-- REALTIME
--   - First EP to require Realtime-in: ALTER PUBLICATION supabase_realtime ADD
--     TABLE public.messages (guarded IF NOT EXISTS). conversations and
--     conversation_participants remain excluded (DROP if present) per the
--     20260829090003:799 guard pattern. RLS-filtered subscription is
--     eq('conversation_id', conv_id) + participant EXISTS check (Plan:179).
--
-- MIGRATION POSTURE
--   - No DDL on prior tables/functions/policies (Rule 3 write discipline); only
--     new objects.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.
--   - No new bucket; messages are text-only opaque ciphertext.
--   - Reuse: service_contracts (participant gate), entities, platform_* helpers.

-- =============================================================================
-- SECTION 1: conversations
-- =============================================================================
create table if not exists public.conversations (
  id            uuid primary key default gen_random_uuid(),
  contract_id   uuid not null references public.service_contracts (id) on delete cascade,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  constraint conversations_contract_id_not_null check (contract_id is not null),
  constraint conversations_contract_id_unique unique (contract_id)
);

comment on table public.conversations is
  'Contract-scoped thread: 1:1 per service_contracts via UNIQUE(contract_id). Two participants derived from service_contracts client/professional; EP-04 reuses same table with third participant row.';
comment on column public.conversations.contract_id is 'FK to service_contracts ON DELETE CASCADE (engagement atom); UNIQUE enforces 1:1.';
comment on column public.conversations.created_by is 'Creator (auth.uid() at ensure, never client-supplied participants).';

create index if not exists conversations_contract_idx
  on public.conversations (contract_id);
create index if not exists conversations_created_at_idx
  on public.conversations (created_at desc);

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
  before update on public.conversations
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: conversation_participants
-- =============================================================================
create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  joined_at       timestamptz not null default now(),
  last_read_at    timestamptz,
  constraint conversation_participants_pkey primary key (conversation_id, entity_id),
  constraint conversation_participants_conversation_not_null check (conversation_id is not null),
  constraint conversation_participants_entity_not_null check (entity_id is not null)
);

comment on table public.conversation_participants is
  'Join table: participants per conversation. 2 rows per 2-party thread (client, professional) derived from service_contracts; EP-04 adds third row. last_read_at updated via RPC after message_list.';
comment on column public.conversation_participants.conversation_id is 'FK to conversations ON DELETE CASCADE.';
comment on column public.conversation_participants.entity_id is 'Participant (auth.uid() derived from service_contracts, never client-supplied array).';
comment on column public.conversation_participants.last_read_at is 'Set to now() via message_list RPC; future read-receipts reuse.';

create index if not exists conversation_participants_entity_idx
  on public.conversation_participants (entity_id, joined_at desc);
create index if not exists conversation_participants_conversation_idx
  on public.conversation_participants (conversation_id);

-- =============================================================================
-- SECTION 3: messages
-- =============================================================================
create table if not exists public.messages (
  id                uuid primary key default gen_random_uuid(),
  conversation_id   uuid not null references public.conversations (id) on delete cascade,
  sender_entity_id  uuid not null references public.entities (id) on delete restrict,
  body_encrypted    text not null,
  body_preview      text,
  client_message_id uuid not null default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  constraint messages_body_encrypted_length check (char_length(btrim(body_encrypted)) between 20 and 8000),
  constraint messages_body_preview_length check (body_preview is null or char_length(body_preview) <= 120),
  constraint messages_client_message_id_not_null check (client_message_id is not null),
  constraint messages_client_message_id_unique unique (client_message_id),
  constraint messages_sender_not_null check (sender_entity_id is not null)
);

comment on table public.messages is
  'Immutable messages: body_encrypted is opaque EncryptedPayload {c,i,t} base64 (never decrypted server-side), body_preview is left(120) redacted via regexp_replace mirror of PiiRedactor, client_message_id dedup via ON CONFLICT. No updated_at (immutable).';
comment on column public.messages.conversation_id is 'FK to conversations ON DELETE CASCADE.';
comment on column public.messages.sender_entity_id is 'Sender (auth.uid() at send, must be participant via RLS WITH CHECK).';
comment on column public.messages.body_encrypted is 'Opaque ciphertext JSON {c,i,t} base64 from AesCipher; 20-8000 CHECK, never SELECT pgp_sym_decrypt server-side.';
comment on column public.messages.body_preview is 'Left(120) redacted preview for conversation_list LATERAL + NotificationService; regexp_replace mirrors PiiRedactor.';
comment on column public.messages.client_message_id is 'UUID v4 from uuid:4.5.1 SyncAction.id; UNIQUE + ON CONFLICT DO NOTHING for offline replay.';
comment on column public.messages.created_at is 'Keyset cursor (created_at DESC, id DESC) for message_list.';

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc, id desc);
create index if not exists messages_sender_idx
  on public.messages (sender_entity_id);
create index if not exists messages_client_message_idx
  on public.messages (client_message_id);

-- =============================================================================
-- SECTION 4: RLS enable + REVOKE + grants + policies (default-deny)
-- =============================================================================
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

revoke all on
  public.conversations,
  public.conversation_participants,
  public.messages
from anon, authenticated, service_role;

-- conversations: authenticated participant read + insert via RPC (SECURITY INVOKER needs INSERT+UPDATE for FOR UPDATE lock)
grant select, insert, update on public.conversations to authenticated;
grant select, insert, update, delete on public.conversations to service_role;

-- conversation_participants: authenticated read+insert+update(last_read_at)
grant select, insert on public.conversation_participants to authenticated;
grant update (last_read_at) on public.conversation_participants to authenticated;
grant select, insert, update, delete on public.conversation_participants to service_role;

-- messages: authenticated read+insert (immutable, no UPDATE/DELETE) column-level
grant select on public.messages to authenticated;
grant insert (conversation_id, sender_entity_id, body_encrypted, body_preview, client_message_id) on public.messages to authenticated;
grant select, insert, update, delete on public.messages to service_role;

-- Policies: participant-only via service_contracts (avoids recursion, ensures B sees conv1 but C does not)
drop policy if exists conversations_select on public.conversations;
create policy conversations_select
  on public.conversations for select to authenticated
  using (exists (select 1 from public.service_contracts sc where sc.id = conversations.contract_id and (sc.client_entity_id = auth.uid() or sc.professional_entity_id = auth.uid())));
drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert
  on public.conversations for insert to authenticated
  with check (exists (select 1 from public.service_contracts c where c.id = contract_id and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())));

drop policy if exists conversation_participants_select on public.conversation_participants;
create policy conversation_participants_select
  on public.conversation_participants for select to authenticated
  using (
    entity_id = auth.uid()
    or exists (
      select 1 from public.conversations c
      join public.service_contracts sc on sc.id = c.contract_id
     where c.id = conversation_participants.conversation_id
       and (sc.client_entity_id = auth.uid() or sc.professional_entity_id = auth.uid())
    )
  );
drop policy if exists conversation_participants_insert on public.conversation_participants;
create policy conversation_participants_insert
  on public.conversation_participants for insert to authenticated
  with check (
    entity_id = auth.uid()
    or exists (
      select 1 from public.service_contracts c
      join public.conversations conv on conv.id = conversation_participants.conversation_id
     where conv.contract_id = c.id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
  );
drop policy if exists conversation_participants_update on public.conversation_participants;
create policy conversation_participants_update
  on public.conversation_participants for update to authenticated
  using (
    entity_id = auth.uid()
    or exists (
      select 1 from public.conversations c
      join public.service_contracts sc on sc.id = c.contract_id
     where c.id = conversation_participants.conversation_id
       and (sc.client_entity_id = auth.uid() or sc.professional_entity_id = auth.uid())
    )
  )
  with check (
    entity_id = auth.uid()
    or exists (
      select 1 from public.conversations c
      join public.service_contracts sc on sc.id = c.contract_id
     where c.id = conversation_participants.conversation_id
       and (sc.client_entity_id = auth.uid() or sc.professional_entity_id = auth.uid())
    )
  );

-- messages: participant-only select/insert
drop policy if exists messages_select on public.messages;
create policy messages_select
  on public.messages for select to authenticated
  using (exists (select 1 from public.conversation_participants cp where cp.conversation_id = messages.conversation_id and cp.entity_id = auth.uid()));
drop policy if exists messages_insert on public.messages;
create policy messages_insert
  on public.messages for insert to authenticated
  with check (
    sender_entity_id = auth.uid()
    and exists (select 1 from public.conversation_participants cp where cp.conversation_id = messages.conversation_id and cp.entity_id = auth.uid())
  );

-- =============================================================================
-- SECTION 5: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 5a. conversation_ensure_for_contract ────────────────────────────────────
create or replace function public.conversation_ensure_for_contract(
  p_contract_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_conversation_id uuid;
  v_existing uuid;
  v_client uuid;
  v_professional uuid;
  v_data jsonb;
  v_participants jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Conversation context not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role','postgres') then
    perform public.platform_raise_error('PLT004', 'Conversation context not found.');
  end if;

  v_client := v_contract.client_entity_id;
  v_professional := v_contract.professional_entity_id;

  -- Idempotent conversation insert (UNIQUE(contract_id))
  insert into public.conversations (contract_id)
  values (p_contract_id)
  on conflict (contract_id) do nothing
  returning id into v_conversation_id;

  if v_conversation_id is null then
    select id into v_conversation_id from public.conversations where contract_id = p_contract_id;
  end if;

  -- Insert both participants (PK ON CONFLICT DO NOTHING for concurrent ensure)
  insert into public.conversation_participants (conversation_id, entity_id)
  values (v_conversation_id, v_client)
  on conflict (conversation_id, entity_id) do nothing;
  insert into public.conversation_participants (conversation_id, entity_id)
  values (v_conversation_id, v_professional)
  on conflict (conversation_id, entity_id) do nothing;

  perform public.platform_audit_log_add(
    'conversation_ensure_for_contract', 'conversations',
    jsonb_build_object('contract_id', p_contract_id, 'conversation_id', v_conversation_id)
  );

  select to_jsonb(c) into v_data from public.conversations c where c.id = v_conversation_id;
  select coalesce(jsonb_agg(to_jsonb(cp) order by cp.entity_id), '[]'::jsonb) into v_participants
    from public.conversation_participants cp where cp.conversation_id = v_conversation_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Conversation ensured.',
    'data', jsonb_build_object('conversation', v_data, 'participants', v_participants)
  );
end;
$$;

comment on function public.conversation_ensure_for_contract(uuid) is
  'SECURITY INVOKER, VOLATILE. Idempotent 1:1 conversation per service_contracts via UNIQUE(contract_id) ON CONFLICT DO NOTHING. Validates participant (client OR professional = auth.uid()) identical PLT004 for foreign/unknown, inserts 2 conversation_participants ON CONFLICT. Audit-logged.';

-- ─── 5b. message_send ────────────────────────────────────────────────────────
create or replace function public.message_send(
  p_conversation_id uuid,
  p_body_encrypted text,
  p_body_preview text default null,
  p_client_message_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_conversation record;
  v_preview text;
  v_id uuid;
  v_existing_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_conversation_id is null then
    perform public.platform_raise_error('PLT003', 'Conversation id is required.');
  end if;

  if p_body_encrypted is null or btrim(p_body_encrypted) = '' then
    perform public.platform_raise_error('PLT003', 'Message body is required.');
  end if;

  if char_length(btrim(p_body_encrypted)) not between 20 and 8000 then
    perform public.platform_raise_error('PLT003', 'Invalid encrypted payload size.');
  end if;

  if p_client_message_id is null then
    perform public.platform_raise_error('PLT003', 'Client message id is required.');
  end if;

  -- Validate conversation exists (any authenticated can see via USING true)
  select c.id into v_conversation
    from public.conversations c
   where c.id = p_conversation_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Conversation not found.');
  end if;

  -- Participant check (identical PLT004 for foreign vs unknown, no oracle) - use JWT role for DEFINER
  if coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role','postgres') then
    if not exists (select 1 from public.conversation_participants cp where cp.conversation_id = p_conversation_id and cp.entity_id = v_actor) then
      perform public.platform_raise_error('PLT004', 'Conversation not found.');
    end if;
  end if;

  -- Preview: left 120 + PII redaction mirror of lib/core/logging/pii_redactor.dart
  v_preview := left(nullif(btrim(p_body_preview), ''), 120);
  if v_preview is not null then
    v_preview := regexp_replace(v_preview, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '***@***.***', 'g');
    v_preview := regexp_replace(v_preview, '\+?234[\s-]?\d{3}[\s-]?\d{3}[\s-]?\d{4}', '***-****-****', 'g');
    v_preview := regexp_replace(v_preview, '0\d{10}', '***-****-****', 'g');
    v_preview := regexp_replace(v_preview, '\+?\d{10,15}', '***', 'g');
    v_preview := regexp_replace(v_preview, 'Bearer\s+\S+', 'Bearer ***', 'g');
    v_preview := regexp_replace(v_preview, 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '***', 'g');
    v_preview := regexp_replace(v_preview, '\b\d{10}\b', '***', 'g');
  end if;

  -- Idempotent insert via client_message_id UNIQUE
  insert into public.messages (conversation_id, sender_entity_id, body_encrypted, body_preview, client_message_id)
  values (p_conversation_id, v_actor, p_body_encrypted, v_preview, p_client_message_id)
  on conflict (client_message_id) do nothing
  returning id into v_id;

  if v_id is null then
    -- Dedup hit: return existing row
    select id into v_existing_id from public.messages where client_message_id = p_client_message_id;
    select to_jsonb(m) into v_data from public.messages m where m.id = v_existing_id;
    return jsonb_build_object(
      'success', true,
      'code', 'PLT000',
      'message', 'Message sent.',
      'data', v_data
    );
  end if;

  perform public.platform_audit_log_add(
    'message_send', 'messages',
    jsonb_build_object('conversation_id', p_conversation_id, 'message_id', v_id, 'client_message_id', p_client_message_id)
  );

  select to_jsonb(m) into v_data from public.messages m where m.id = v_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Message sent.',
    'data', v_data
  );
end;
$$;

comment on function public.message_send(uuid, text, text, uuid) is
  'SECURITY INVOKER, VOLATILE. Participant sends opaque ciphertext body_encrypted 20-8000 via ON CONFLICT(client_message_id) DO NOTHING dedup. Validates participant via EXISTS, truncates body_preview left(120) + regexp_replace PII mirror. Audit-logged.';

-- ─── 5c. conversation_list ────────────────────────────────────────────────────
create or replace function public.conversation_list(
  p_limit int default 20,
  p_cursor uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_cursor_ts timestamptz;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select c.created_at into v_cursor_ts
      from public.conversations c
     where c.id = p_cursor
       and exists (select 1 from public.conversation_participants cp where cp.conversation_id = c.id and cp.entity_id = v_actor);
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Conversations retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select c.id, c.contract_id, c.created_at, c.updated_at, c.created_by,
             lm.body_preview as last_message_preview,
             lm.created_at as last_message_at,
             row_number() over (order by c.created_at desc, c.id desc) as rn
        from public.conversations c
        join public.conversation_participants cp on cp.conversation_id = c.id and cp.entity_id = v_actor
        left join lateral (
          select m.body_preview, m.created_at from public.messages m where m.conversation_id = c.id order by m.created_at desc, m.id desc limit 1
        ) lm on true
       where (p_cursor is null or (c.created_at, c.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Conversations retrieved.',
    'data', jsonb_build_object('items', coalesce(v_items, '[]'::jsonb), 'has_more', coalesce(v_has_more, false), 'next_cursor', v_next)
  );
end;
$$;

comment on function public.conversation_list(integer, uuid) is
  'SECURITY INVOKER, STABLE. Participant-scoped keyset (created_at DESC, id DESC) via conversation_participants join + LATERAL last messages body_preview. p_limit 1-100, unknown cursor [] no oracle.';

-- ─── 5d. message_list ─────────────────────────────────────────────────────────
create or replace function public.message_list(
  p_conversation_id uuid,
  p_limit int default 20,
  p_cursor uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_cursor_ts timestamptz;
  v_cursor_id uuid;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_conversation_id is null then
    perform public.platform_raise_error('PLT003', 'Conversation id is required.');
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  -- Participant check (identical PLT004 for foreign vs unknown) - use JWT role for DEFINER
  if coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role','postgres') then
    if not exists (select 1 from public.conversation_participants cp where cp.conversation_id = p_conversation_id and cp.entity_id = v_actor) then
      if not exists (select 1 from public.conversations where id = p_conversation_id) then
        perform public.platform_raise_error('PLT004', 'Conversation not found.');
      end if;
      perform public.platform_raise_error('PLT004', 'Conversation not found.');
    end if;
  end if;

  if p_cursor is not null then
    select m.created_at, m.id into v_cursor_ts, v_cursor_id
      from public.messages m
     where m.id = p_cursor and m.conversation_id = p_conversation_id;
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Messages retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select m.id, m.conversation_id, m.sender_entity_id, m.body_encrypted, m.body_preview, m.client_message_id, m.created_at,
             row_number() over (order by m.created_at desc, m.id desc) as rn
        from public.messages m
       where m.conversation_id = p_conversation_id
         and (p_cursor is null or (m.created_at, m.id) < (v_cursor_ts, v_cursor_id))
    ) x;

  if not v_has_more then v_next := null; end if;

  -- Touch last_read_at for requester (fire-and-forget, ignore errors)
  begin
    update public.conversation_participants set last_read_at = now()
     where conversation_id = p_conversation_id and entity_id = v_actor;
  exception when others then null;
  end;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Messages retrieved.',
    'data', jsonb_build_object('items', coalesce(v_items, '[]'::jsonb), 'has_more', coalesce(v_has_more, false), 'next_cursor', v_next)
  );
end;
$$;

comment on function public.message_list(uuid, integer, uuid) is
  'SECURITY INVOKER, STABLE. Participant-scoped keyset (created_at DESC, id DESC) via messages_conversation_created_idx. p_limit 1-100, unknown cursor [] no oracle. Touches last_read_at.';

-- =============================================================================
-- SECTION 6: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.conversation_ensure_for_contract(uuid) to authenticated, service_role;
grant execute on function public.message_send(uuid, text, text, uuid) to authenticated, service_role;
grant execute on function public.conversation_list(integer, uuid) to authenticated, service_role;
grant execute on function public.message_list(uuid, integer, uuid) to authenticated, service_role;

comment on function public.conversation_ensure_for_contract(uuid) is
  'SECURITY DEFINER, VOLATILE. Idempotent 1:1 per service_contracts, participant-validated PLT004, ON CONFLICT DO NOTHING + 2 participants. Audit-logged. Pinned search_path.';
comment on function public.message_send(uuid, text, text, uuid) is
  'SECURITY DEFINER, VOLATILE. Opaque ciphertext 20-8000 + client_message_id dedup ON CONFLICT, participant EXISTS PLT004, preview left120 + PII regexp. Pinned search_path.';
comment on function public.conversation_list(integer, uuid) is
  'SECURITY DEFINER, STABLE. Participant-scoped keyset (created_at DESC, id DESC) via conversation_participants join + LATERAL last preview, PLT003 limit, unknown cursor [] . Pinned search_path.';
comment on function public.message_list(uuid, integer, uuid) is
  'SECURITY DEFINER, STABLE. Participant-scoped keyset (created_at DESC, id DESC) via messages_conversation_created_idx, participant PLT004, touches last_read_at. Pinned search_path.';

-- =============================================================================
-- SECTION 7: Realtime publication (guarded, idempotent)
-- =============================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('conversations', 'conversation_participants')
  ) then
    alter publication supabase_realtime drop table public.conversations, public.conversation_participants;
  end if;
end;
$$;
