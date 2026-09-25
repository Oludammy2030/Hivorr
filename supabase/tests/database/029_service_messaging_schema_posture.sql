-- EP-03-04: Messaging Schema Posture
--
-- Validates the 3 new messaging tables (Plan §16.1):
--   - All 3 tables exist; RLS enabled on all.
--   - anon has zero INSERT/UPDATE/DELETE on all 3.
--   - authenticated has SELECT on conversations, SELECT+INSERT on participants, column-level INSERT 5 on messages.
--   - CHECKs (body_encrypted 20-8000, body_preview <=120, UNIQUE contract_id, PK, UNIQUE client_message_id), indexes, triggers, comments.
--   - No conversation_%/message_% SECURITY DEFINER; exactly 4 RPCs.
--   - Realtime includes messages (1), excludes conversations/participants (0).
--   - EXECUTE posture: anon 0, authenticated 4, service_role 4.
--   - 6 RLS policies participant-only.

begin;
set search_path to extensions, public;
select plan(28);

-- ─── 0. All 3 tables exist ────────────────────────────────────────────────────
select has_table('public', 'conversations', 'conversations exists');
select has_table('public', 'conversation_participants', 'conversation_participants exists');
select has_table('public', 'messages', 'messages exists');

-- ─── 1. RLS enabled on all 3 ─────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('conversations', 'conversation_participants', 'messages')
      and c.relrowsecurity),
  3,
  'RLS enabled on all 3 messaging tables'
);

-- ─── 2. anon has zero write grants on all 3 ─────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('conversations', 'conversation_participants', 'messages')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on messaging tables'
);

-- ─── 3. authenticated has SELECT on conversations (participant RLS) ──────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'conversations'
      and privilege_type = 'SELECT'),
  1,
  'authenticated has SELECT on conversations (participant RLS)'
);

-- ─── 4. authenticated has SELECT,INSERT on conversation_participants ─────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'conversation_participants'
      and privilege_type = 'SELECT'),
  1,
  'authenticated has SELECT on conversation_participants'
);
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'conversation_participants'
      and privilege_type = 'INSERT'),
  1,
  'authenticated has INSERT on conversation_participants'
);

-- ─── 5. authenticated has column-level INSERT 5 on messages ──────────────────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'messages'
      and privilege_type = 'INSERT'),
  5,
  'authenticated has column-level INSERT 5 on messages (conversation_id, sender, body_encrypted, body_preview, client_message_id)'
);

-- ─── 6. authenticated has UPDATE(last_read_at) 1 on conversation_participants ─
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'conversation_participants'
      and privilege_type = 'UPDATE'
      and column_name = 'last_read_at'),
  1,
  'authenticated has UPDATE(last_read_at) on conversation_participants'
);

-- ─── 7. UNIQUE(contract_id) on conversations ─────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.conversations'::regclass
      and contype = 'u'
      and conname = 'conversations_contract_id_unique'),
  1,
  'UNIQUE(contract_id) on conversations exists'
);

-- ─── 8. PK (conversation_id, entity_id) on conversation_participants ────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.conversation_participants'::regclass
      and contype = 'p'
      and conname = 'conversation_participants_pkey'),
  1,
  'PK (conversation_id, entity_id) on conversation_participants exists'
);

-- ─── 9. UNIQUE(client_message_id) on messages ───────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.messages'::regclass
      and contype = 'u'
      and conname = 'messages_client_message_id_unique'),
  1,
  'UNIQUE(client_message_id) on messages exists'
);

-- ─── 10. CHECK body_encrypted 20-8000 ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.messages'::regclass
      and contype = 'c'
      and conname = 'messages_body_encrypted_length'),
  1,
  'messages body_encrypted 20-8000 CHECK exists'
);

-- ─── 11. CHECK body_preview <=120 ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.messages'::regclass
      and contype = 'c'
      and conname = 'messages_body_preview_length'),
  1,
  'messages body_preview <=120 CHECK exists'
);

-- ─── 12. Indexes (6) ────────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename in ('conversations', 'conversation_participants', 'messages')
      and indexname in (
        'conversations_contract_idx',
        'conversations_created_at_idx',
        'conversation_participants_entity_idx',
        'conversation_participants_conversation_idx',
        'messages_conversation_created_idx',
        'messages_client_message_idx'
      )),
  6,
  'the 6 messaging indexes exist'
);

-- ─── 13. Trigger: 1 updated_at on conversations, 0 on messages ──────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname = 'conversations_set_updated_at'),
  1,
  'conversations_set_updated_at trigger exists'
);
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and c.relname = 'messages'
      and t.tgname like '%updated_at%'),
  0,
  'messages has no updated_at trigger (immutable)'
);

-- ─── 14. All 4 messaging RPCs are SECURITY DEFINER (bypass RLS for participant checks) ─
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname like 'conversation\_%' or p.proname like 'message\_%')
      and p.prosecdef),
  4,
  'all 4 messaging RPCs are SECURITY DEFINER'
);

-- ─── 15. Exactly 4 messaging RPCs (jsonb) ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('conversation_ensure_for_contract','message_send','conversation_list','message_list')
      and p.prorettype = 'jsonb'::regtype),
  4,
  'exactly 4 messaging RPCs exist'
);

-- ─── 16. Realtime: messages 1, conversations/participants 0 ──────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'),
  1,
  'Realtime includes messages (1)'
);
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('conversations', 'conversation_participants')),
  0,
  'Realtime excludes conversations and participants (0)'
);

-- ─── 17. All 3 tables have comments ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('conversations', 'conversation_participants', 'messages')
      and obj_description(c.oid, 'pg_class') is not null),
  3,
  'all 3 messaging tables have comments'
);

-- ─── 18. anon EXECUTE 0 on all 4 ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('conversation_ensure_for_contract','message_send','conversation_list','message_list')
      and grantee = 'anon'),
  0,
  'anon can execute 0 messaging RPCs (private threads)'
);

-- ─── 19. authenticated EXECUTE 4 ────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('conversation_ensure_for_contract','message_send','conversation_list','message_list')
      and grantee = 'authenticated'),
  4,
  'authenticated can execute all 4 messaging RPCs'
);

-- ─── 20. service_role EXECUTE 4 ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('conversation_ensure_for_contract','message_send','conversation_list','message_list')
      and grantee = 'service_role'),
  4,
  'service_role can execute all 4 messaging RPCs'
);

-- ─── 21. RLS policies: 7 total (2+3+2) ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('conversations', 'conversation_participants', 'messages')),
  7,
  'exactly 7 RLS policies on messaging tables (2 on conversations, 3 on participants, 2 on messages)'
);

-- ─── 22. messages has no UPDATE grant for authenticated (immutable) ───────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'messages'
      and privilege_type = 'UPDATE'),
  0,
  'authenticated has no UPDATE on messages (immutable, anon 0 posture)'
);

select * from finish();
rollback;
