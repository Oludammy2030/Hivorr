-- EP-01-05: RLS Leakage Matrix
--
-- Verifies zero data leakage for unauthenticated, cross-user, and elevated
-- (service_role) access patterns (EP-01-05 Plan §14.1).
--
-- Impersonation strategy: the test session runs as a superuser. Actor roles
-- are switched with SET ROLE, and the JWT identity is injected through the
-- request.jwt.claim.* configuration variables that auth.uid() consumes.
--
-- Actor ids:
--   A = 11111111-1111-1111-1111-111111111111
--   B = 22222222-2222-2222-2222-222222222222
-- Fixture records use deterministic ids so cross-user assertions do not
-- depend on visibility of the owning user's rows.

begin;
set search_path to extensions, public;
select plan(17);

-- ─── Fixtures: user A inserts two records ──────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.platform_demo_records (id, owner_id, title, payload)
values (
  'aaaaaaaa-0000-0000-0000-000000000000',
  auth.uid(),
  'alpha',
  '{"k":1}'::jsonb
);

select is(
  (select count(*) from public.platform_demo_records where title = 'alpha'),
  1::bigint,
  'user A inserts fixture record alpha'
);

insert into public.platform_demo_records (id, owner_id, title, payload)
values (
  'bbbbbbbb-0000-0000-0000-000000000000',
  auth.uid(),
  'beta',
  '{"k":2}'::jsonb
);

select is(
  (select count(*) from public.platform_demo_records where title = 'beta'),
  1::bigint,
  'user A inserts fixture record beta'
);

-- ─── anon: zero visibility ──────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  'select * from public.platform_demo_records',
  '42501',
  NULL,
  'anon direct select on platform_demo_records is denied'
);

select throws_ok(
  'select public.platform_demo_records_create(''stolen'', ''{}''::jsonb)',
  '42501',
  NULL,
  'anon RPC write is denied (no execute grant)'
);

select throws_ok(
  'select public.platform_demo_records_update(''aaaaaaaa-0000-0000-0000-000000000000''::uuid, ''{}''::jsonb)',
  '42501',
  NULL,
  'anon RPC update is denied (no execute grant)'
);

select throws_ok(
  'select * from public.platform_audit_log',
  '42501',
  NULL,
  'anon direct select on platform_audit_log is denied'
);

select is(
  (select (public.platform_health())->>'code'),
  'PLT000',
  'anon can call public platform_health'
);

-- ─── user B: cannot see or mutate user A data ───────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*) from public.platform_demo_records),
  0::bigint,
  'user B sees zero rows (RLS isolation)'
);

select is(
  (select (public.platform_demo_records_get(
     'aaaaaaaa-0000-0000-0000-000000000000'::uuid
   ))->>'code'),
  'PLT004',
  'user B cannot read user A record (PLT004)'
);

update public.platform_demo_records
   set payload = '{"tampered": true}'::jsonb
 where title = 'alpha';

select throws_ok(
  'insert into public.platform_demo_records (owner_id, title) values (''11111111-1111-1111-1111-111111111111'', ''sneak'')',
  '42501',
  NULL,
  'user B cannot insert a row owned by user A (WITH CHECK)'
);

select is(
  (select (public.platform_demo_records_create('gamma', '{"k":3}'::jsonb))->>'code'),
  'PLT000',
  'user B creates own record gamma via RPC'
);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'gamma')
   ))->>'code'),
  'PLT000',
  'user B reads own record gamma via RPC'
);

-- ─── service_role: bypasses RLS (server-side only) ─────────────────────────
set role service_role;

select is(
  (select count(*) from public.platform_demo_records),
  3::bigint,
  'service_role sees all three records (RLS bypass, server-side only)'
);

-- ─── Audit path: RPC-only writes ───────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select public.platform_audit_log_add('created', 'platform_demo_records', '{"k":1}'::jsonb);

select throws_ok(
  'insert into public.platform_audit_log (action, entity) values (''x'', ''y'')',
  '42501',
  NULL,
  'authenticated direct insert on platform_audit_log is denied (RPC-only path)'
);

set role service_role;

select is(
  (select count(*) from public.platform_audit_log),
  1::bigint,
  'audit trail contains exactly the RPC-written row'
);

-- ─── user A still reads own data ────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select (public.platform_demo_records_get(
     (select id from public.platform_demo_records where title = 'beta')
   ))->>'code'),
  'PLT000',
  'user A reads own record beta via RPC'
);

select is(
  (select payload from public.platform_demo_records where title = 'alpha'),
  '{"k":1}'::jsonb,
  'user A payload unchanged after user B update attempt'
);

select * from finish();
rollback;