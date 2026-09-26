-- EP-03-05: Scheduling Schema Posture
--
-- Validates the 3 new scheduling tables:
--   - All 3 tables exist; RLS enabled on all 3.
--   - anon has zero INSERT/UPDATE/DELETE on all 3.
--   - authenticated grants narrow per plan (owner RLS / participant).
--   - CHECKs (weekday 0-6, start<end, duration 15-480, timezone, status, event_type, starts<ends), UNIQUEs, indexes, btree_gist, EXCLUDE, triggers, comments.
--   - No scheduling_% SECURITY DEFINER; exactly 5 RPCs.
--   - Realtime excludes all 3; EXECUTE posture: anon 0, authenticated 5, service_role 5.
--   - Policies 7.

begin;
set search_path to extensions, public;
select plan(37);

-- ─── 0. All 3 tables exist ────────────────────────────────────────────────────
select has_table('public', 'availability_slots', 'availability_slots exists');
select has_table('public', 'appointments', 'appointments exists');
select has_table('public', 'appointment_events', 'appointment_events exists');

-- ─── 1. RLS enabled on all 3 ─────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('availability_slots', 'appointments', 'appointment_events')
      and c.relrowsecurity),
  3,
  'RLS enabled on all 3 scheduling tables'
);

-- ─── 2. anon has zero write grants on all 3 ─────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('availability_slots', 'appointments', 'appointment_events')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on scheduling tables'
);

-- ─── 3. authenticated has SELECT on availability_slots (owner RLS) ───────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'availability_slots'
      and privilege_type = 'SELECT'),
  1,
  'authenticated has SELECT on availability_slots'
);

-- ─── 4. authenticated has INSERT/UPDATE/DELETE on availability_slots via RLS ─
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'availability_slots'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  3,
  'authenticated has INSERT, UPDATE, DELETE on availability_slots for owner RPC'
);

-- ─── 5. authenticated has SELECT,INSERT on appointments + column UPDATE(status) ─
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'appointments'
      and privilege_type = 'SELECT'),
  1,
  'authenticated has SELECT on appointments'
);
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'appointments'
      and privilege_type = 'INSERT'),
  1,
  'authenticated has INSERT on appointments'
);
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'appointments'
      and privilege_type = 'UPDATE'
      and column_name in ('status', 'reschedule_of', 'updated_at')),
  3,
  'authenticated has column-level UPDATE(status,reschedule_of,updated_at) on appointments'
);

-- ─── 6. appointment_events has no UPDATE/DELETE (append-only) ───────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee in ('anon', 'authenticated', 'service_role')
      and table_schema = 'public'
      and table_name = 'appointment_events'
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'appointment_events has no UPDATE/DELETE grants (append-only)'
);

-- ─── 7. appointment_events authenticated SELECT + INSERT ─────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'appointment_events'
      and privilege_type = 'SELECT'),
  1,
  'authenticated has SELECT on appointment_events'
);

-- ─── 8. CHECK weekday 0-6 ─────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.availability_slots'::regclass
      and contype = 'c'
      and conname = 'availability_slots_weekday_range'),
  1,
  'availability_slots_weekday_range CHECK exists'
);

-- ─── 9. CHECK start<end ──────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.availability_slots'::regclass
      and contype = 'c'
      and conname = 'availability_slots_start_before_end'),
  1,
  'availability_slots_start_before_end CHECK exists'
);

-- ─── 10. CHECK duration 15-480 ───────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.availability_slots'::regclass
      and contype = 'c'
      and conname = 'availability_slots_duration_range'),
  1,
  'availability_slots_duration_range CHECK exists'
);

-- ─── 11. CHECK timezone format ───────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.availability_slots'::regclass
      and contype = 'c'
      and conname = 'availability_slots_timezone_format'),
  1,
  'availability_slots_timezone_format CHECK exists'
);

-- ─── 12. UNIQUE(entity_id, profession_id, weekday, start_time) ───────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.availability_slots'::regclass
      and contype = 'u'
      and conname = 'availability_slots_entity_prof_weekday_start_key'),
  1,
  'UNIQUE(entity_id, profession_id, weekday, start_time) exists'
);

-- ─── 13. CHECK starts<ends on appointments ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.appointments'::regclass
      and contype = 'c'
      and conname = 'appointments_starts_before_ends'),
  1,
  'appointments_starts_before_ends CHECK exists'
);

-- ─── 14. CHECK status vocab on appointments ──────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.appointments'::regclass
      and contype = 'c'
      and conname = 'appointments_status_allowed'),
  1,
  'appointments_status_allowed CHECK exists'
);

-- ─── 15. UNIQUE(idempotency_key) ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.appointments'::regclass
      and contype = 'u'
      and conname = 'appointments_idempotency_key_unique'),
  1,
  'UNIQUE(idempotency_key) exists'
);

-- ─── 16. CHECK event_type on appointment_events ──────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.appointment_events'::regclass
      and contype = 'c'
      and conname = 'appointment_events_event_type_allowed'),
  1,
  'appointment_events_event_type_allowed CHECK exists'
);

-- ─── 17. has_extension btree_gist ────────────────────────────────────────────
select is(
  (select count(*)::int from pg_extension where extname = 'btree_gist'),
  1,
  'btree_gist extension exists'
);

-- ─── 18. has_constraint EXCLUDE appointments_no_overlap ──────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.appointments'::regclass
      and contype = 'x'
      and conname = 'appointments_no_overlap'),
  1,
  'appointments_no_overlap EXCLUDE constraint exists'
);

-- ─── 19. Indexes on availability_slots (3) ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'availability_slots'
      and indexname in (
        'availability_slots_entity_idx',
        'availability_slots_entity_prof_idx',
        'availability_slots_profession_idx'
      )),
  3,
  'the 3 availability_slots indexes exist'
);

-- ─── 20. Indexes on appointments (4) ─────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'appointments'
      and indexname in (
        'appointments_contract_idx',
        'appointments_professional_starts_idx',
        'appointments_client_starts_idx',
        'appointments_idempotency_idx'
      )),
  4,
  'the 4 appointments btree indexes exist'
);

-- ─── 21. Indexes on appointment_events (3) ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'appointment_events'
      and indexname in (
        'appointment_events_appointment_idx',
        'appointment_events_contract_idx',
        'appointment_events_type_idx'
      )),
  3,
  'the 3 appointment_events indexes exist'
);

-- ─── 22. Triggers: 2 updated_at (slots + appointments, zero on events) ──────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in (
        'availability_slots_set_updated_at', 'appointments_set_updated_at'
      )),
  2,
  'the 2 updated_at triggers exist (slots + appointments)'
);
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
    where c.oid = 'public.appointment_events'::regclass
      and not t.tgisinternal
      and t.tgname like '%updated_at%'),
  0,
  'appointment_events has no updated_at trigger (append-only)'
);

-- ─── 23. No scheduling_% SECURITY DEFINER ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname = 'availability_upsert' or p.proname = 'availability_list' or p.proname like 'appointment\_%')
      and p.prosecdef),
  0,
  'no scheduling RPC is SECURITY DEFINER'
);

-- ─── 24. Exactly 5 scheduling RPCs ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('availability_upsert','availability_list','appointment_book','appointment_reschedule','appointment_cancel')
      and p.prorettype = 'jsonb'::regtype),
  5,
  'exactly 5 scheduling RPCs exist'
);

-- ─── 25. Realtime excludes all 3 ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('availability_slots', 'appointments', 'appointment_events')),
  0,
  'Realtime excludes all 3 scheduling tables'
);

-- ─── 26. All 3 tables have comments ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('availability_slots', 'appointments', 'appointment_events')
      and obj_description(c.oid, 'pg_class') is not null),
  3,
  'all 3 scheduling tables have comments'
);

-- ─── 27. anon EXECUTE zero on scheduling RPCs ────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('availability_upsert','availability_list','appointment_book','appointment_reschedule','appointment_cancel')
      and grantee = 'anon'),
  0,
  'anon can execute zero scheduling RPCs'
);

-- ─── 28. authenticated EXECUTE on all 5 ─────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('availability_upsert','availability_list','appointment_book','appointment_reschedule','appointment_cancel')
      and grantee = 'authenticated'),
  5,
  'authenticated can execute all 5 scheduling RPCs'
);

-- ─── 29. service_role EXECUTE on all 5 ──────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('availability_upsert','availability_list','appointment_book','appointment_reschedule','appointment_cancel')
      and grantee = 'service_role'),
  5,
  'service_role can execute all 5 scheduling RPCs'
);

-- ─── 30. RLS policies: 9 total (4 on slots, 3 on appointments, 2 on events) ──
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('availability_slots', 'appointments', 'appointment_events')),
  9,
  '9 RLS policies on scheduling tables (4 slots +3 appointments +2 events)'
);

-- ─── 31. availability_slots has published gate policy ────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'availability_slots'
      and policyname = 'availability_slots_select'),
  1,
  'availability_slots_select policy exists'
);

select * from finish();
rollback;
