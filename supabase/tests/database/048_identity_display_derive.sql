-- Identity Phase 1a: display_name derivation on profile creation.
--
-- Validates that entity_profile_update derives `first + last` when the
-- caller omits p_display_name on insert, keeps explicit values verbatim,
-- still rejects missing first/last/phone, and never rewrites a stored
-- display on display-less updates:
--   - 3 derive-default + 2 explicit-verbatim + 2 still-required +
--   - 2 update-keeps + 1 explicit-empty-rejected = 10.

begin;
set search_path to extensions, public;
select plan(10);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'd1d1d1d1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'd2d2d2d2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'd3d3d3d3-3333-4333-8333-333333333333', true);
select set_config('test.d', 'd4d4d4d4-4444-8444-9444-444444444444', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'derive-a@example.com'),
       (current_setting('test.b')::uuid, 'derive-b@example.com'),
       (current_setting('test.c')::uuid, 'derive-c@example.com'),
       (current_setting('test.d')::uuid, 'derive-d@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active'),
       (current_setting('test.d')::uuid, 'active')
on conflict (id) do nothing;

-- ─── 1. Omitted display derives `first + last` (A) ───────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$ select public.entity_profile_update(null, null, null, 'Adaeze', null, 'Okafor', '+15550001111') $$,
  'insert without display succeeds (PLT000)'
);
select is(
  (select display_name from public.entity_profiles where entity_id = current_setting('test.a')::uuid),
  'Adaeze Okafor',
  'omitted display derives first + last'
);
select is(
  (select legal_name from public.entity_profiles where entity_id = current_setting('test.a')::uuid),
  'Adaeze Okafor',
  'legal anchor derives alongside'
);

-- ─── 2. Explicit display stays verbatim (B) ──────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select lives_ok(
  $$ select public.entity_profile_update(null, 'Chidi the Fixer', null, 'Chidi', null, 'Eze', '+15550002222') $$,
  'insert with explicit display succeeds (PLT000)'
);
select is(
  (select display_name from public.entity_profiles where entity_id = current_setting('test.b')::uuid),
  'Chidi the Fixer',
  'explicit display stored verbatim, never overwritten by derivation'
);

-- ─── 3. First/last/phone still required (C) ──────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);

select throws_ok(
  $$ select public.entity_profile_update(null, null, null, null, null, 'Okafor', '+15550003333') $$,
  'P0001', 'PLT003: First name, last name, and phone number are required to create your profile.',
  'missing first still rejected without display in the message'
);
select is(
  (select count(*)::int from public.entity_profiles where entity_id = current_setting('test.c')::uuid),
  0,
  'rejected insert leaves no profile row'
);

-- ─── 4. Display-less update keeps stored value (A again) ─────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select lives_ok(
  $$ select public.entity_profile_update(null, null, null, null, null, null, '+15550009999') $$,
  'phone-only update succeeds (PLT000)'
);
select is(
  (select display_name from public.entity_profiles where entity_id = current_setting('test.a')::uuid),
  'Adaeze Okafor',
  'derived display survives display-less updates'
);

-- ─── 5. Explicit empty display still rejected (D) ────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.d'), true);

select throws_ok(
  $$ select public.entity_profile_update(null, '   ', null, 'Dayo', null, 'Ade', '+15550004444') $$,
  'P0001', 'PLT003: Display name cannot be empty.',
  'whitespace-only display rejected even with derivation available'
);

select * from finish();
rollback;
