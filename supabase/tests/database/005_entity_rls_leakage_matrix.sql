-- EP-01-06: Entity RLS Leakage Matrix
--
-- Proves zero cross-entity data leakage across all seven private entity tables
-- (EP-01-06 Plan §14.1). Actor roles switched with SET ROLE + JWT claim injection
-- following the EP-01-05 impersonation strategy.

begin;
set search_path to extensions, public;
select plan(20);

-- ─── Seed taxonomy (postgres, bypasses RLS) ────────────────────────────────
insert into public.industries (id, slug, name)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'tech', 'Technology');
insert into public.professions (id, industry_id, slug, name, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'chef', 'Chef', true);

-- Test callers (auth.users rows so entity.id FK holds for the default auth.uid() inserts)
insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'a@example.com') on conflict (id) do nothing;
insert into auth.users (id, email) values ('22222222-2222-2222-2222-222222222222', 'b@example.com') on conflict (id) do nothing;

-- ─── A. Anon denied on every private table ──────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);

select throws_ok('select * from public.entities', '42501', null, 'anon denied select on entities');
select throws_ok('select * from public.entity_profiles', '42501', null, 'anon denied select on profiles');
select throws_ok('select * from public.entity_roles', '42501', null, 'anon denied select on roles');
select throws_ok('select * from public.entity_credentials', '42501', null, 'anon denied select on credentials');
select throws_ok('select * from public.entity_professions', '42501', null, 'anon denied select on profession bindings');
select throws_ok('select * from public.entity_settings', '42501', null, 'anon denied select on settings');
select throws_ok('select * from public.entity_devices', '42501', null, 'anon denied select on devices');

select throws_ok(
  'insert into public.entities (status) values (''active'')',
  '42501', null, 'anon cannot insert into entities');

-- ─── B. User A creates data under own identity ──────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.entities (status) values ('active');
insert into public.entity_profiles (legal_name, display_name, bio)
values ('Legal A', 'Display A', 'bio a');
insert into public.entity_roles (role) values ('consumer');
insert into public.entity_settings (setting_key, value)
values ('theme', '{"mode":"dark"}'::jsonb);
insert into public.entity_devices (device_token, platform)
values ('tok-aaa', 'android');

select is((select count(*)::int from public.entities), 1, 'user A sees own entity');
select is((select count(*)::int from public.entity_profiles), 1, 'user A sees own profile');
select is((select count(*)::int from public.entity_settings), 1, 'user A sees own settings');

-- ─── C. User B cannot read or mutate user A data ────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is((select count(*)::int from public.entities), 0, 'user B sees zero entities (isolation)');
select is((select count(*)::int from public.entity_profiles), 0, 'user B sees zero profiles (isolation)');

select throws_ok(
  'insert into public.entity_profiles (entity_id, legal_name, display_name) values (''11111111-1111-1111-1111-111111111111'', ''Hacker'', ''Hacker'')',
  '42501', null, 'user B cannot insert profile owned by A (no entity_id INSERT grant)');

select lives_ok(
  'update public.entity_profiles set display_name = ''evil'' where entity_id = ''11111111-1111-1111-1111-111111111111''',
  'user B update of A profile is silently blocked by RLS (0 rows)');

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select display_name from public.entity_profiles where entity_id = '11111111-1111-1111-1111-111111111111'),
  'Display A', 'user B update did not alter A profile');

-- ─── D. Verification-column write denial (column-level grants) ──────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.entity_professions (profession_id) values ('bbbbbbbb-0000-0000-0000-000000000001');

select throws_ok(
  'update public.entity_professions set trade_verification_status = ''approved'' where entity_id = ''11111111-1111-1111-1111-111111111111''',
  '42501', null, 'client cannot write trade_verification_status (column-level grant)');
select throws_ok(
  'update public.entity_professions set verified_by = ''22222222-2222-2222-2222-222222222222'' where entity_id = ''11111111-1111-1111-1111-111111111111''',
  '42501', null, 'client cannot write verified_by (column-level grant)');

-- ─── E. Credential immutability (no UPDATE grant to owner) ──────────────────
insert into public.entity_credentials (kind, title)
values ('trade_proof', 'My Certificate');

select throws_ok(
  'update public.entity_credentials set title = ''Tampered'' where entity_id = ''11111111-1111-1111-1111-111111111111''',
  '42501', null, 'owner cannot UPDATE credentials (immutable submissions)');

-- ─── F. Service role bypass (server-side only) ──────────────────────────────
set role service_role;
select is((select count(*)::int from public.entities), 1, 'service_role sees all entities (server-side tooling)');

select * from finish();
rollback;
