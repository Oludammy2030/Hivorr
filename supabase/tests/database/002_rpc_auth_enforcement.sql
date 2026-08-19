-- EP-01-05: RPC Auth Enforcement
--
-- Verifies that every non-health RPC requires authentication, that the
-- returned envelope follows the {success, code, message, data} contract,
-- and that owner-guarding holds through both RLS and function guards
-- (EP-01-05 Plan §14.2).
--
-- Actors:
--   A = 11111111-1111-1111-1111-111111111111
--   B = 22222222-2222-2222-2222-222222222222

begin;
set search_path to extensions, public;
select plan(18);

-- ─── anon: only the public health probe ────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select (public.platform_health())->>'code'),
  'PLT000',
  'anon platform_health succeeds'
);

select throws_ok(
  'select public.platform_demo_records_get(''00000000-0000-0000-0000-000000000000''::uuid)',
  '42501',
  NULL,
  'anon platform_demo_records_get denied (no execute grant)'
);

-- ─── authenticated without JWT identity: in-function PLT001 ─────────────────
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  'select public.platform_demo_records_create(''x'', ''{}''::jsonb)',
  'P0001',
  'PLT001: Authentication required\.',
  'authenticated without identity: create raises PLT001'
);

select throws_ok(
  'select public.platform_demo_records_get(''00000000-0000-0000-0000-000000000000''::uuid)',
  'P0001',
  'PLT001: Authentication required\.',
  'authenticated without identity: get raises PLT001'
);

select throws_ok(
  'select public.platform_demo_records_update(''00000000-0000-0000-0000-000000000000''::uuid, ''{}''::jsonb)',
  'P0001',
  'PLT001: Authentication required\.',
  'authenticated without identity: update raises PLT001'
);

select throws_ok(
  'select public.platform_audit_log_add(''a'', ''b'')',
  'P0001',
  'PLT001: Authentication required\.',
  'authenticated without identity: audit add raises PLT001'
);

-- ─── service_role without identity: still subject to auth check ─────────────
set role service_role;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  'select public.platform_demo_records_get(''00000000-0000-0000-0000-000000000000''::uuid)',
  'P0001',
  'PLT001: Authentication required\.',
  'service_role without identity: get raises PLT001 (auth gate applies)'
);

-- ─── authenticated user A: full happy path + envelope contract ──────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select (public.platform_demo_records_create('zeta', '{"k":9}'::jsonb))->>'code'),
  'PLT000',
  'user A creates record zeta via RPC'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'zeta')
   ))->>'success'),
  'true',
  'success envelope field is true'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'zeta')
   )) ? 'success'),
  true,
  'envelope contains success'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'zeta')
   )) ? 'code'),
  true,
  'envelope contains code'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'zeta')
   )) ? 'message'),
  true,
  'envelope contains message'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'zeta')
   )) ? 'data'),
  true,
  'envelope contains data'
);

-- ─── cross-user enforcement on the write path ───────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  'select public.platform_demo_records_get((select id from public.platform_demo_records where title = ''zeta''))',
  'P0001',
  'PLT003: Record id is required\.',
  'user B cannot read user A record zeta (RLS hides it, PLT003)'
);

select throws_ok(
  'select public.platform_demo_records_update((select id from public.platform_demo_records where title = ''zeta''), ''{"owned": false}''::jsonb)',
  'P0001',
  'PLT003: Record id is required\.',
  'user B cannot update user A record zeta (RLS hides it, PLT003)'
);

-- ─── owner update + trigger verification ────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select (public.platform_demo_records_update(
     (select id from public.platform_demo_records where title = 'zeta'),
     '{"owned": true}'::jsonb
   ))->>'code'),
  'PLT000',
  'user A updates own record zeta (PLT000)'
);

select is(
  (select
     (updated_at > created_at)
     from public.platform_demo_records
    where title = 'zeta'),
  true,
  'updated_at trigger fired on owner update'
);

-- ─── service_role sees exactly one record ───────────────────────────────────
set role service_role;

select is(
  (select count(*) from public.platform_demo_records),
  1::bigint,
  'service_role sees exactly the single record created in this file'
);

select * from finish();
rollback;