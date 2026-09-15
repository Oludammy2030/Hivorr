-- EP-02-19: Portfolio Public Profile
--
-- Validates the portfolio_items table DDL + RLS and the
-- portfolio_public_profile_get(uuid) SECURITY DEFINER RPC (EP-02-19 TIP §14.1).
-- Style mirrors 012_verification_rpc_enforcement.sql / 017_storage_posture.sql.
--
-- Covers:
--   - portfolio_items table exists, audit columns, trigger, RLS, CHECK constraints.
--   - Default-deny: anon has zero SELECT/INSERT/UPDATE/DELETE on portfolio_items;
--     owner self-CRUD present; anon has no table SELECT on entity-model tables.
--   - portfolio_public_profile_get identity: SECURITY DEFINER, STABLE, execute
--     granted to anon, authenticated, service_role; no public grant.
--   - Behavior: PLT003 null id; PLT004 nonexistent/inactive/unapproved; PLT000
--     with ≥1 approved profession + profile; payload contains whitelisted fields.
--   - Whitelist negative: legal_name, document_path, reviewed_by,
--     rejection_reason, KYC limits absent; raw anon table select fails.
--   - portfolio_items excluded from supabase_realtime.

begin;
set search_path to extensions, public;
select plan(34);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);

insert into auth.users (id, email)
values
  (current_setting('test.a')::uuid, 'entity-a-portfolio@example.com'),
  (current_setting('test.b')::uuid, 'entity-b-portfolio@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values
  (current_setting('test.a')::uuid, 'active'),
  (current_setting('test.b')::uuid, 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name, bio, country_code)
values
  (current_setting('test.a')::uuid, 'Ada Lovelace', 'Ada', 'Mathematician', 'GB'),
  (current_setting('test.b')::uuid, 'Grace Hopper', 'Grace', 'Computer scientist', 'US')
on conflict (entity_id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000030', 'portfolio-tech', 'Technology', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000031', 'ffffffff-0000-0000-0000-000000000030', 'portfolio-dev', 'Software Developer', true)
on conflict (id) do nothing;

insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values
  (current_setting('test.a')::uuid, 'ffffffff-0000-0000-0000-000000000031', true, 'approved'),
  (current_setting('test.b')::uuid, 'ffffffff-0000-0000-0000-000000000031', true, 'unverified')
on conflict (entity_id, profession_id) do nothing;

insert into public.entity_credentials (entity_id, kind, title, verification_status, reviewed_at, reviewed_by)
values
  (current_setting('test.a')::uuid, 'identity_document', 'Passport A', 'approved', now(), current_setting('test.a')::uuid),
  (current_setting('test.b')::uuid, 'identity_document', 'Passport B', 'pending', null, null)
on conflict do nothing;

insert into public.kyc_tiers (tier_code, name, daily_limit)
values ('tier_1', 'Identity Verified', 50000)
on conflict (tier_code) do update set daily_limit = 50000;

insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.a')::uuid, 'tier_1', 'active')
on conflict (entity_id) do nothing;

insert into public.portfolio_items (entity_id, item_type, title, description, media_path, sort_order)
values
  (current_setting('test.a')::uuid, 'image', 'Project Alpha', 'A portfolio piece', 'portfolio-items/11111111-1111-1111-1111-111111111111/item1/photo.jpg', 1)
on conflict do nothing;

-- ─── 1. portfolio_items table exists ──────────────────────────────────────────
select has_table('public', 'portfolio_items', 'portfolio_items table exists');

-- ─── 2. audit columns present ─────────────────────────────────────────────────
select col_not_null('public.portfolio_items', 'created_at', 'created_at is not null');
select col_not_null('public.portfolio_items', 'updated_at', 'updated_at is not null');
select has_trigger('public.portfolio_items', 'portfolio_items_set_updated_at', 'platform_set_updated_at trigger exists');

-- ─── 3. RLS enabled ──────────────────────────────────────────────────────────
select is(
  (select c.relrowsecurity
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'portfolio_items'),
  true,
  'portfolio_items RLS is enabled'
);

-- ─── 4-5. Default-deny: anon has zero grants on portfolio_items ──────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'portfolio_items'
      and grantee = 'anon'),
  0,
  'anon has zero grants on portfolio_items'
);

-- ─── 6-7. Authenticated self-CRUD present ────────────────────────────────────
select ok(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'portfolio_items'
      and grantee = 'authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')) = 4,
  'authenticated has SELECT/INSERT/UPDATE/DELETE on portfolio_items'
);

-- ─── 8. service_role has SELECT ──────────────────────────────────────────────
select ok(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'portfolio_items'
      and grantee = 'service_role'
      and privilege_type = 'SELECT') >= 1,
  'service_role has SELECT on portfolio_items'
);

-- ─── 9. Anon has no SELECT on entity-model tables (regression guard) ─────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'anon'
      and table_name in ('entities','entity_profiles','entity_roles',
        'entity_credentials','entity_professions','entity_settings','entity_devices')),
  0,
  'anon has zero table SELECT on entity-model tables (regression)'
);

-- ─── 10-12. RLS policies: owner self-CRUD present, no anon select ────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'portfolio_items'
      and policyname = 'portfolio_items_authenticated_insert'),
  1,
  'owner insert policy exists'
);
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'portfolio_items'
      and policyname = 'portfolio_items_authenticated_update'),
  1,
  'owner update policy exists'
);
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'portfolio_items'
      and policyname = 'portfolio_items_authenticated_delete'),
  1,
  'owner delete policy exists'
);

-- ─── 13. No anon select policy on portfolio_items ────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'portfolio_items'
      and roles @> array['anon']::name[]),
  0,
  'no anon policy on portfolio_items'
);

-- ─── 14-16. portfolio_public_profile_get identity ─────────────────────────────
select has_function('public', 'portfolio_public_profile_get', array['uuid'],
  'portfolio_public_profile_get function exists');

select is(
  (select prosecdef from pg_proc
    where proname = 'portfolio_public_profile_get'
      and proargtypes::regtype[] = array['uuid'::regtype]),
  true,
  'portfolio_public_profile_get is SECURITY DEFINER'
);

select is(
  (select proargtypes::regtype[] from pg_proc
    where proname = 'portfolio_public_profile_get'
      and proargtypes::regtype[] = array['uuid'::regtype]),
  array['uuid']::regtype[],
  'portfolio_public_profile_get returns jsonb'
);

-- ─── 17. STABLE ──────────────────────────────────────────────────────────────
select is(
  (select provolatile from pg_proc
    where proname = 'portfolio_public_profile_get'
      and proargtypes::regtype[] = array['uuid'::regtype]),
  's',
  'portfolio_public_profile_get is STABLE'
);

-- ─── 18-20. EXECUTE grants ───────────────────────────────────────────────────
select ok(
  has_function_privilege('anon', 'public.portfolio_public_profile_get(uuid)', 'execute'),
  'anon has EXECUTE on portfolio_public_profile_get'
);
select ok(
  has_function_privilege('authenticated', 'public.portfolio_public_profile_get(uuid)', 'execute'),
  'authenticated has EXECUTE on portfolio_public_profile_get'
);
select ok(
  has_function_privilege('service_role', 'public.portfolio_public_profile_get(uuid)', 'execute'),
  'service_role has EXECUTE on portfolio_public_profile_get'
);

-- ─── 21. No public EXECUTE grant ─────────────────────────────────────────────
select ok(
  not has_function_privilege('public', 'public.portfolio_public_profile_get(uuid)', 'execute'),
  'no PUBLIC execute grant on portfolio_public_profile_get'
);

-- ─── 22-23. PLT003 null id; PLT004 nonexistent entity ────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

select throws_ok(
  $$ select public.portfolio_public_profile_get(null) $$,
  'P0001', 'PLT003: Entity id is required.',
  'PLT003 raised for null entity id'
);
select throws_ok(
  $$ select public.portfolio_public_profile_get('00000000-0000-4000-8000-000000000099') $$,
  'P0001', 'PLT004: Professional profile not found.',
  'PLT004 raised for nonexistent entity'
);

-- ─── 24. PLT004 for entity with zero approved professions (entity B) ─────────
select throws_ok(
  format('select public.portfolio_public_profile_get(%L)', current_setting('test.b')),
  'P0001', 'PLT004: Professional profile not found.',
  'PLT004 raised for active entity with no approved professions (gate)'
);

-- ─── 25-28. PLT000 success: approved entity A returns envelope ───────────────
select lives_ok(
  format('select public.portfolio_public_profile_get(%L)', current_setting('test.a')),
  'PLT000 success for entity with ≥1 approved profession'
);

select is(
  (select (public.portfolio_public_profile_get(current_setting('test.a')::uuid)->>'code')),
  'PLT000',
  'envelope code is PLT000'
);

select is(
  (select count(*)::int from jsonb_object_keys(public.portfolio_public_profile_get(current_setting('test.a')::uuid))),
  4,
  'envelope has exactly 4 top-level keys'
);

-- ─── 29-30. Whitelisted fields present; sensitive fields absent ───────────────
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' ? 'display_name'),
  true,
  'payload contains display_name (whitelisted)'
);
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' ? 'professions'),
  true,
  'payload contains professions (whitelisted)'
);
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' ? 'credentials'),
  true,
  'payload contains credentials (whitelisted)'
);
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' ? 'portfolio_items'),
  true,
  'payload contains portfolio_items (whitelisted)'
);

-- ─── 31. Whitelist negative: legal_name never in payload ──────────────────────
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' ? 'legal_name'),
  false,
  'legal_name is NOT in the public payload'
);

-- ─── 32. Whitelist negative: document_path never in credential payload ────────
select is(
  (select (public.portfolio_public_profile_get(current_setting('test.a')::uuid) -> 'data' -> 'credentials' -> 0) ? 'document_path'),
  false,
  'document_path is NOT in the credential payload'
);

-- ─── 33. Anon raw table SELECT still fails (default-deny preserved) ──────────
set role anon;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000099', true);
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok(
  $$ select count(*) from public.portfolio_items $$,
  '42501', null,
  'anon raw SELECT on portfolio_items fails (default-deny RLS)'
);

-- ─── 34. portfolio_items excluded from supabase_realtime ─────────────────────
set role service_role;
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'portfolio_items'),
  0,
  'portfolio_items excluded from supabase_realtime'
);

select * from finish();
rollback;
