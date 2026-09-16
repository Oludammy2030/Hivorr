-- EP-02-11: Manage User wire contract (canonical shape + guards)
--
-- Locks the MANAGE USER WIRE CONTRACT shared with the Flutter client
-- (migration 20260917090002). The client DTOs adopt this shape; this test is
-- the server-side guarantee that the shape cannot drift without a failing
-- fixture:
--
--   manage_user_list            -> data.users[] (10 canonical keys) + total_count
--   manage_user_get             -> data.user { entity, profile, roles, kyc,
--                                              is_admin, summary }
--   manage_user_set_status      -> data.{user_id, status} with lockout guards
--   manage_user_reset_onboarding-> clears capability/completion + audit row
--
-- Assertions are key-set based (jsonb_object_keys) so key RENAMES surface as
-- failures while natural JSON key ordering stays irrelevant.

begin;
set search_path to extensions, public;
select plan(40);

-- ─── 0. Fixtures (mirrors 020/021) ─────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('33333333-3333-4333-8333-333333333333', 'manage-nonadmin@test.local'),
       ('44444444-4444-4444-8444-444444444444', 'manage-admin@test.local'),
       ('55555555-5555-4555-8555-555555555555', 'manage-gamma@test.local'),
       ('66666666-6666-4666-8666-666666666666', 'manage-admin2@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status, capability, onboarding_completed_at)
values ('33333333-3333-4333-8333-333333333333', 'active', null, null),
       ('44444444-4444-4444-8444-444444444444', 'active', 'hire', now()),
       ('55555555-5555-4555-8555-555555555555', 'suspended', 'hire', now()),
       ('66666666-6666-4666-8666-666666666666', 'active', null, null)
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name, country_code)
values ('33333333-3333-4333-8333-333333333333', 'Manage Alpha Co', 'Manage Alpha Sdn Bhd', 'MY'),
       ('44444444-4444-4444-8444-444444444444', 'Manage Beta Co', 'Manage Beta Sdn Bhd', 'MY'),
       ('55555555-5555-4555-8555-555555555555', 'Suspended Gamma Co', 'Suspended Gamma Sdn Bhd', 'MY'),
       ('66666666-6666-4666-8666-666666666666', 'Admin Six Co', 'Admin Six Sdn Bhd', 'MY')
on conflict (entity_id) do nothing;

insert into public.entity_roles (entity_id, role, is_active)
values ('33333333-3333-4333-8333-333333333333', 'consumer', true),
       ('33333333-3333-4333-8333-333333333333', 'professional', true),
       ('33333333-3333-4333-8333-333333333333', 'merchant', false)
on conflict (entity_id, role) do nothing;

insert into public.platform_admins (user_id, granted_by, notes)
values ('44444444-4444-4444-8444-444444444444', null, 'Manage test admin'),
       ('66666666-6666-4666-8666-666666666666', null, 'Manage test admin 2')
on conflict (user_id) do nothing;

insert into public.entity_kyc_levels (entity_id, tier_code, status, assigned_at, assigned_by)
values ('33333333-3333-4333-8333-333333333333', 'tier_1', 'active', now(),
        '44444444-4444-4444-8444-444444444444')
on conflict (entity_id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Function surface ─────────────────────────────────────────────────────
select has_function('public', 'manage_user_list', 'manage_user_list exists');
select has_function('public', 'manage_user_get', 'manage_user_get exists');
select has_function('public', 'manage_user_set_status', 'manage_user_set_status exists');
select has_function('public', 'manage_user_reset_onboarding', 'manage_user_reset_onboarding exists');

-- ─── 2. Admin gating (non-admin is rejected on every RPC) ────────────────────
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select throws_ok(
  $$ select public.manage_user_list(null, null, 0, 20) $$,
  'P0001', 'PLT002: Admin access required.',
  'list raises PLT002 for non-admin'
);
select throws_ok(
  $$ select public.manage_user_get('33333333-3333-4333-8333-333333333333') $$,
  'P0001', 'PLT002: Admin access required.',
  'get raises PLT002 for non-admin'
);
select throws_ok(
  $$ select public.manage_user_set_status('55555555-5555-4555-8555-555555555555', 'suspended') $$,
  'P0001', 'PLT002: Admin access required.',
  'set_status raises PLT002 for non-admin'
);
select throws_ok(
  $$ select public.manage_user_reset_onboarding('55555555-5555-4555-8555-555555555555') $$,
  'P0001', 'PLT002: Admin access required.',
  'reset raises PLT002 for non-admin'
);
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);

-- ─── 3. manage_user_list: canonical shape ───────────────────────────────────
select is(
  public.manage_user_list(null, null, 0, 50) -> 'data' ->> 'total_count',
  '4',
  'list total_count reflects the four seeded users'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.manage_user_list(null, null, 0, 50) -> 'data' -> 'users'
       ) limit 1)
     ) k $$,
  $$ select unnest(array[
       'id', 'display_name', 'legal_name', 'avatar_path', 'status',
       'roles', 'kyc_tier', 'is_admin', 'onboarding_completed', 'created_at'
     ]) $$,
  'list rows carry exactly the canonical key set'
);

select is(
  jsonb_array_length(
    public.manage_user_list(null, 'suspended', 0, 50) -> 'data' -> 'users'
  ),
  1,
  'list filters by entity status'
);

select is(
  jsonb_array_length(
    public.manage_user_list('Alpha', null, 0, 50) -> 'data' -> 'users'
  ),
  1,
  'list filters by display/legal name search'
);

select is(
  jsonb_array_length(
    public.manage_user_list('Alpha', null, 0, 50) -> 'data' -> 'users' -> 0 -> 'roles'
  ),
  2,
  'list returns only active roles (merchant is inactive)'
);

select is(
  public.manage_user_list('Alpha', null, 0, 50) -> 'data' -> 'users' -> 0 ->> 'kyc_tier',
  'tier_1',
  'list joins kyc_tier'
);

select is(
  public.manage_user_list('Alpha', null, 0, 50) -> 'data' -> 'users' -> 0 ->> 'is_admin',
  'false',
  'list marks non-admin false'
);

select throws_ok(
  $$ select public.manage_user_list(null, 'bogus', 0, 20) $$,
  'P0001', 'PLT003: Invalid status filter.',
  'list rejects an unknown status filter'
);

select throws_ok(
  $$ select public.manage_user_list(null, null, -1, 20) $$,
  'P0001', 'PLT003: Invalid pagination bounds.',
  'list rejects negative offset'
);

select is(
  (select count(*)::int from jsonb_object_keys(public.manage_user_list(null, null, 0, 20))),
  4,
  'list envelope has exactly 4 top-level keys'
);

select is(
  public.manage_user_list(null, null, 0, 20) ->> 'code',
  'PLT000',
  'list envelope code is PLT000'
);

-- ─── 4. manage_user_get: canonical shape ─────────────────────────────────────
select set_eq(
  $$ select k from jsonb_object_keys(
       public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user'
     ) k $$,
  $$ select unnest(array['entity', 'profile', 'roles', 'kyc', 'is_admin', 'summary']) $$,
  'get user object carries exactly the canonical key set'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'entity'
     ) k $$,
  $$ select unnest(array['id', 'status', 'capability', 'onboarding_completed_at', 'created_at']) $$,
  'get entity block carries exactly the canonical key set'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'profile'
     ) k $$,
  $$ select unnest(array['display_name', 'legal_name', 'bio', 'avatar_path', 'country_code']) $$,
  'get profile block carries exactly the canonical key set'
);

select is(
  jsonb_array_length(
    public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'roles'
  ),
  3,
  'get roles include all assignments (active and inactive)'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'roles'
       ) limit 1)
     ) k $$,
  $$ select unnest(array['role', 'is_active', 'activated_at']) $$,
  'get role entries carry exactly the canonical key set'
);

select is(
  public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'kyc' ->> 'tier_code',
  'tier_1',
  'get joins kyc tier'
);

select is(
  public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' ->> 'is_admin',
  'false',
  'get reports is_admin false for non-admin'
);

select is(
  public.manage_user_get('44444444-4444-4444-8444-444444444444') -> 'data' -> 'user' ->> 'is_admin',
  'true',
  'get reports is_admin true for admin'
);

select ok(
  public.manage_user_get('55555555-5555-4555-8555-555555555555') -> 'data' -> 'user' ->> 'kyc' is null,
  'get returns null kyc block when the user has no KYC assignment'
);

select throws_ok(
  $$ select public.manage_user_get('99999999-9999-4999-8999-999999999999') $$,
  'P0001', 'PLT004: User not found.',
  'get rejects an unknown user'
);

-- ─── 5. manage_user_set_status: lifecycle + lockout guards ───────────────────
select is(
  public.manage_user_set_status('33333333-3333-4333-8333-333333333333', 'suspended')
    -> 'data' ->> 'status',
  'suspended',
  'set_status suspends a non-admin'
);

select is(
  public.manage_user_get('33333333-3333-4333-8333-333333333333') -> 'data' -> 'user' -> 'entity' ->> 'status',
  'suspended',
  'get reflects the suspended status'
);

select is(
  public.manage_user_set_status('33333333-3333-4333-8333-333333333333', 'active')
    -> 'data' ->> 'status',
  'active',
  'set_status reactivates a suspended user'
);

select throws_ok(
  $$ select public.manage_user_set_status('33333333-3333-4333-8333-333333333333', 'bogus') $$,
  'P0001', 'PLT003: Invalid status value.',
  'set_status rejects an unknown status value'
);

select throws_ok(
  $$ select public.manage_user_set_status('44444444-4444-4444-8444-444444444444', 'suspended') $$,
  'P0001', 'PLT005: Cannot change your own account status.',
  'set_status blocks self-suspension'
);

select throws_ok(
  $$ select public.manage_user_set_status('66666666-6666-4666-8666-666666666666', 'suspended') $$,
  'P0001', 'PLT005: Cannot suspend a platform admin.',
  'set_status blocks suspending another platform admin'
);

select throws_ok(
  $$ select public.manage_user_set_status('99999999-9999-4999-8999-999999999999', 'suspended') $$,
  'P0001', 'PLT004: User not found.',
  'set_status rejects an unknown user'
);

-- ─── 6. manage_user_reset_onboarding: re-onboarding flow ────────────────────
select ok(
  public.manage_user_reset_onboarding('55555555-5555-4555-8555-555555555555')
    -> 'data' ->> 'capability' is null,
  'reset clears capability'
);

select ok(
  public.manage_user_get('55555555-5555-4555-8555-555555555555') -> 'data' -> 'user' -> 'entity' ->> 'capability' is null,
  'get reflects cleared capability after reset'
);

-- Audit row assertion needs RLS bypass (platform_audit_log grants SELECT to
-- service_role only).
set role postgres;
select is(
  (select count(*)::int from public.platform_audit_log
    where action = 'manage_user_reset_onboarding'
      and entity = 'entities'
      and actor_id = '44444444-4444-4444-8444-444444444444'
      and details ->> 'user_id' = '55555555-5555-4555-8555-555555555555'),
  1,
  'reset appends a platform_audit_log row for the admin actor'
);
set role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);

select throws_ok(
  $$ select public.manage_user_reset_onboarding('99999999-9999-4999-8999-999999999999') $$,
  'P0001', 'PLT004: User not found.',
  'reset rejects an unknown user'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;