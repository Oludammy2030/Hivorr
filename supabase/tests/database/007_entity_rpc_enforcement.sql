-- EP-01-06: Entity RPC Enforcement
--
-- Verifies the five enforcement RPCs (EP-01-06 Plan §14.3): anon has no execute
-- grant, unauthenticated calls return PLT001, vocabulary validation, profession
-- existence/activity, duplicate binding, pending-only credential creation, and
-- audit-log writes. RPC failures RAISE (P0001), matching EP-01-05 error contract.

begin;
set search_path to extensions, public;
select plan(24);

-- Seed caller + taxonomy
insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'a@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values ('11111111-1111-1111-1111-111111111111', 'active');
insert into public.entity_profiles (entity_id, legal_name, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Legal A', 'Display A');

insert into auth.users (id, email) values ('22222222-2222-2222-2222-222222222222', 'b@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values ('22222222-2222-2222-2222-222222222222', 'active');
insert into public.entity_profiles (entity_id, legal_name, display_name)
values ('22222222-2222-2222-2222-222222222222', 'Legal B', 'Display B');

insert into public.industries (id, slug, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'fx-tech', 'Technology');
insert into public.professions (id, industry_id, slug, name, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'fx-chef', 'Chef', true);
insert into public.professions (id, industry_id, slug, name, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'fx-plumber', 'Plumber', false);

-- ─── A. Anon has NO execute grant on entity RPCs (42501) ────────────────────
set role anon;
select throws_ok(
  $$ select public.entity_profile_update('X','Y','Z') $$,
  '42501', null, 'anon cannot execute entity_profile_update (no grant)');
select throws_ok(
  $$ select public.entity_roles_activate('rider') $$,
  '42501', null, 'anon cannot execute entity_roles_activate (no grant)');
select throws_ok(
  $$ select public.entity_roles_deactivate('rider') $$,
  '42501', null, 'anon cannot execute entity_roles_deactivate (no grant)');
select throws_ok(
  $$ select public.entity_profession_bind('bbbbbbbb-0000-0000-0000-000000000001') $$,
  '42501', null, 'anon cannot execute entity_profession_bind (no grant)');
select throws_ok(
  $$ select public.entity_credentials_submit('trade_proof','Title') $$,
  '42501', null, 'anon cannot execute entity_credentials_submit (no grant)');

-- ─── B. Authenticated but empty JWT sub → PLT001 (P0001) ───────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok(
  $$ select public.entity_roles_activate('rider') $$,
  'P0001', 'PLT001: Authentication required.', 'empty-sub RPC call returns PLT001');

-- ─── C. As authenticated user A ─────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Invalid role vocabulary (PLT003)
select throws_ok(
  $$ select public.entity_roles_activate('wizard') $$,
  'P0001', 'PLT003: Invalid role value.', 'unknown role rejected (PLT003)');

-- Valid role activation
select is(
  (select (public.entity_roles_activate('rider'))->>'code'),
  'PLT000', 'valid role activated (PLT000)');
select is(
  (select is_active from public.entity_roles where entity_id = '11111111-1111-1111-1111-111111111111' and role = 'rider'),
  true, 'role activation persisted active');

-- Deactivate
select is(
  (select (public.entity_roles_deactivate('rider'))->>'code'),
  'PLT000', 'role deactivated (PLT000)');
select is(
  (select is_active from public.entity_roles where entity_id = '11111111-1111-1111-1111-111111111111' and role = 'rider'),
  false, 'role deactivation persisted');

-- Profession binding: unknown (PLT004)
select throws_ok(
  $$ select public.entity_profession_bind('cccccccc-0000-0000-0000-000000000001') $$,
  'P0001', 'PLT004: Profession not found.', 'unknown profession rejected (PLT004)');

-- Profession binding: inactive (PLT004)
select throws_ok(
  $$ select public.entity_profession_bind('bbbbbbbb-0000-0000-0000-000000000002') $$,
  'P0001', 'PLT004: Profession is not active.', 'inactive profession rejected (PLT004)');

-- Profession binding: valid → unverified
select is(
  (select (public.entity_profession_bind('bbbbbbbb-0000-0000-0000-000000000001'))->>'code'),
  'PLT000', 'valid profession bound (PLT000)');
select is(
  (select trade_verification_status from public.entity_professions
    where entity_id = '11111111-1111-1111-1111-111111111111' and profession_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'unverified', 'new binding lands unverified (Rule 2 gate)');

-- Duplicate binding (PLT005)
select throws_ok(
  $$ select public.entity_profession_bind('bbbbbbbb-0000-0000-0000-000000000001') $$,
  'P0001', 'PLT005: Entity already bound to this profession.', 'duplicate binding rejected (PLT005)');

-- Credential submission: invalid kind (PLT003)
select throws_ok(
  $$ select public.entity_credentials_submit('bogus','Title') $$,
  'P0001', 'PLT003: Invalid credential kind.', 'invalid credential kind rejected (PLT003)');

-- Credential submission: valid → pending
select is(
  (select (public.entity_credentials_submit('trade_proof','My Cert','bbbbbbbb-0000-0000-0000-000000000001',null))->>'code'),
  'PLT000', 'credential submitted (PLT000)');
select is(
  (select verification_status from public.entity_credentials
    where entity_id = '11111111-1111-1111-1111-111111111111' and title = 'My Cert'),
  'pending', 'credential lands pending (no approval path)');

-- Profile update: invalid legal name (PLT003)
select throws_ok(
  $$ select public.entity_profile_update('   ','New Display',null) $$,
  'P0001', 'PLT003: Legal name cannot be empty.', 'empty legal name rejected (PLT003)');
select is(
  (select (public.entity_profile_update('New Legal','New Display',null))->>'code'),
  'PLT000', 'profile updated (PLT000)');
select is(
  (select legal_name from public.entity_profiles where entity_id = '11111111-1111-1111-1111-111111111111'),
  'New Legal', 'profile anchor update persisted via RPC');

-- Audit log written for mutating calls (authenticated has no SELECT on audit log)
set role postgres;
select is(
  (select count(*)::int from public.platform_audit_log
    where actor_id = '11111111-1111-1111-1111-111111111111'
      and entity in ('entity_profiles','entity_roles','entity_professions','entity_credentials')),
  5, 'audit log captured RPC mutations');

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Envelope shape sanity (success path)
select is(
  (select (public.entity_profile_update('A','B',null))->>'success'),
  'true', 'envelope success flag true on success');

select * from finish();
rollback;
