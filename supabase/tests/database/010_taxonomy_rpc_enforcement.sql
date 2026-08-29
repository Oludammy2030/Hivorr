-- EP-02-02: Taxonomy RPC Enforcement
--
-- Validates the 7 taxonomy management RPCs (EP-02-02 Plan §14.1):
--   - Authorization: anon/authenticated can read, cannot write (42501)
--   - service_role can invoke all writes (with admin identity in JWT context)
--   - Input validation: PLT003 (format/required), PLT004 (not found), PLT005 (conflict)
--   - Envelope contract: {success, code, message, data}
--   - Functional reads/writes, partial updates, re-parenting
--   - Audit trail, SECURITY INVOKER posture, function existence

begin;
set search_path to extensions, public;
select plan(48);

-- ─── 0. Seed fixture: an inactive industry (for PLT004-inactive test) ───────
set role postgres;
insert into public.industries (id, slug, name, is_active)
values ('dddddddd-0000-0000-0000-000000000001', 'inactive-ind', 'Inactive Industry', false)
on conflict (id) do nothing;

-- ─── 1. Authorization: anon ─────────────────────────────────────────────────
set role anon;

select lives_ok(
  $$ select public.taxonomy_industries_list() $$,
  'anon can call taxonomy_industries_list');
select lives_ok(
  $$ select public.taxonomy_professions_list() $$,
  'anon can call taxonomy_professions_list');

select throws_ok(
  $$ select public.taxonomy_industry_create('x','y') $$,
  '42501', null, 'anon cannot execute taxonomy_industry_create (no grant)');
select throws_ok(
  $$ select public.taxonomy_industry_update('00000000-0000-0000-0000-000000000001','y') $$,
  '42501', null, 'anon cannot execute taxonomy_industry_update (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_create('00000000-0000-0000-0000-000000000001','x','y') $$,
  '42501', null, 'anon cannot execute taxonomy_profession_create (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_update('00000000-0000-0000-0000-000000000001','y') $$,
  '42501', null, 'anon cannot execute taxonomy_profession_update (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_move('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'anon cannot execute taxonomy_profession_move (no grant)');

-- ─── 1. Authorization: authenticated ─────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$ select public.taxonomy_industries_list() $$,
  'authenticated can call taxonomy_industries_list');
select lives_ok(
  $$ select public.taxonomy_professions_list() $$,
  'authenticated can call taxonomy_professions_list');

select throws_ok(
  $$ select public.taxonomy_industry_create('x','y') $$,
  '42501', null, 'authenticated cannot execute taxonomy_industry_create (no grant)');
select throws_ok(
  $$ select public.taxonomy_industry_update('00000000-0000-0000-0000-000000000001','y') $$,
  '42501', null, 'authenticated cannot execute taxonomy_industry_update (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_create('00000000-0000-0000-0000-000000000001','x','y') $$,
  '42501', null, 'authenticated cannot execute taxonomy_profession_create (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_update('00000000-0000-0000-0000-000000000001','y') $$,
  '42501', null, 'authenticated cannot execute taxonomy_profession_update (no grant)');
select throws_ok(
  $$ select public.taxonomy_profession_move('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'authenticated cannot execute taxonomy_profession_move (no grant)');

-- ─── 2. Functional reads (run BEFORE any write creates data) ─────────────────
select is(
  jsonb_array_length((public.taxonomy_industries_list())->'data'),
  8, 'industries list returns 8 seeded industries (active-only)');

select is(
  jsonb_array_length((public.taxonomy_professions_list())->'data'),
  46, 'professions list returns 46 seeded professions (active-only)');

select is(
  jsonb_array_length(
    (public.taxonomy_professions_list((select id from public.industries where slug='technology'), false))->'data'
  ),
  8, 'professions list filtered by technology returns 8');

-- ─── 3. service_role can invoke all write RPCs (admin context) ───────────────
set role service_role;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"service_role"}', true);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'service_role', true);

select lives_ok(
  $$ select public.taxonomy_industry_create('test-ind-a','Test Industry A',null,100) $$,
  'service_role can call taxonomy_industry_create');
select lives_ok(
  $$ select public.taxonomy_industry_update((select id from public.industries where slug='test-ind-a'),'Renamed A') $$,
  'service_role can call taxonomy_industry_update');
select lives_ok(
  $$ select public.taxonomy_profession_create((select id from public.industries where slug='test-ind-a'),'test-prof-a','Test Profession A',null,10) $$,
  'service_role can call taxonomy_profession_create');
select lives_ok(
  $$ select public.taxonomy_profession_update((select id from public.professions where slug='test-prof-a'),'Renamed Prof A') $$,
  'service_role can call taxonomy_profession_update');
select lives_ok(
  $$ select public.taxonomy_profession_move((select id from public.professions where slug='test-prof-a'),(select id from public.industries where slug='legal')) $$,
  'service_role can call taxonomy_profession_move');

-- ─── 4. Posture & existence ──────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_proc where proname like 'taxonomy_%' and prosecdef),
  0, 'no taxonomy_ function is SECURITY DEFINER');

select is(
  (select count(*)::int from pg_proc where proname like 'taxonomy_%'),
  7, 'exactly 7 taxonomy_ functions exist');

-- ─── 5. Envelope contract ────────────────────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.taxonomy_industries_list())),
  4, 'envelope has exactly 4 top-level keys');

select is(
  (public.taxonomy_industries_list())->>'code',
  'PLT000', 'success envelope code is PLT000');

-- ─── 6. Validation (service_role context) ───────────────────────────────────
select throws_ok(
  $$ select public.taxonomy_industry_create(null, 'Name') $$,
  'P0001', 'PLT003: Industry slug is required.', 'null slug rejected (PLT003)');
select throws_ok(
  $$ select public.taxonomy_industry_create('Legal','Name') $$,
  'P0001', 'PLT003: Industry slug must be lowercase.', 'uppercase slug rejected (PLT003)');
select throws_ok(
  $$ select public.taxonomy_industry_create('legal services','Name') $$,
  'P0001', 'PLT003: Industry slug format is invalid. Use lowercase letters, numbers, and single hyphens only.', 'space slug rejected (PLT003)');
select throws_ok(
  $$ select public.taxonomy_industry_create('valid-slug','   ') $$,
  'P0001', 'PLT003: Industry name is required.', 'empty name rejected (PLT003)');
select throws_ok(
  $$ select public.taxonomy_industry_create('legal','Legal Dup') $$,
  'P0001', 'PLT005: An industry with this slug already exists.', 'duplicate industry slug rejected (PLT005)');
select throws_ok(
  $$ select public.taxonomy_industry_update('00000000-0000-0000-0000-000000000001','Name') $$,
  'P0001', 'PLT004: Industry not found.', 'unknown industry update rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_create('cccccccc-0000-0000-0000-000000000001','slug','Name') $$,
  'P0001', 'PLT004: Industry not found.', 'profession create with unknown industry rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_create('dddddddd-0000-0000-0000-000000000001','slug','Name') $$,
  'P0001', 'PLT004: Industry is not active.', 'profession create with inactive industry rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_create((select id from public.industries where slug='legal'),'corporate-lawyer','Name') $$,
  'P0001', 'PLT005: A profession with this slug already exists.', 'duplicate profession slug rejected (PLT005)');
select throws_ok(
  $$ select public.taxonomy_profession_update('00000000-0000-0000-0000-000000000001','Name') $$,
  'P0001', 'PLT004: Profession not found.', 'unknown profession update rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_move('00000000-0000-0000-0000-000000000001',(select id from public.industries where slug='legal')) $$,
  'P0001', 'PLT004: Profession not found.', 'move unknown profession rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_move((select id from public.professions where slug='corporate-lawyer'),'cccccccc-0000-0000-0000-000000000001') $$,
  'P0001', 'PLT004: Industry not found.', 'move to unknown industry rejected (PLT004)');
select throws_ok(
  $$ select public.taxonomy_profession_move((select id from public.professions where slug='corporate-lawyer'),(select id from public.industries where slug='legal')) $$,
  'P0001', 'PLT003: Profession is already in the target industry.', 'move to same industry rejected (PLT003)');

-- ─── 7. Functional writes (state verification) ───────────────────────────────
select is(
  (public.taxonomy_industry_create('test-ind-func','Test Industry Func',null,100))->>'code',
  'PLT000', 'industry create returns PLT000');
select is(
  (select count(*)::int from public.industries
    where slug='test-ind-func' and is_active=true and created_by is null),
  1, 'industry persisted with is_active=true and created_by=null');

select is(
  (public.taxonomy_industry_update(
     (select id from public.industries where slug='test-ind-func'),
     'Renamed Industry', null, null, null))->'data'->>'name',
  'Renamed Industry', 'industry update changes name');
select is(
  (public.taxonomy_industry_update(
     (select id from public.industries where slug='test-ind-func'),
     null, null, null, false))->'data'->>'is_active',
  'false', 'industry deactivates via is_active=false');

select is(
  (public.taxonomy_profession_create(
     (select id from public.industries where slug='legal'),
     'test-prof-func','Test Profession Func',null,10))->>'code',
  'PLT000', 'profession create returns PLT000');
select is(
  (select count(*)::int from public.professions p
     join public.industries i on i.id = p.industry_id
    where p.slug='test-prof-func'),
  1, 'profession FK valid (linked to legal industry)');
select is(
  (public.taxonomy_profession_update(
     (select id from public.professions where slug='test-prof-func'),
     'Renamed Profession', null, null, null))->'data'->>'name',
  'Renamed Profession', 'profession update changes name');
select is(
  (public.taxonomy_profession_move(
     (select id from public.professions where slug='test-prof-func'),
     (select id from public.industries where slug='technology')))->'data'->>'industry_id',
  (select id::text from public.industries where slug='technology'),
  'profession re-parented to technology industry');

-- ─── 8. Audit trail ──────────────────────────────────────────────────────────
set role postgres;
select is(
  (select count(*)::int from public.platform_audit_log
    where action='taxonomy_industry_create' and details->>'slug'='test-ind-func'),
  1, 'audit log captured taxonomy_industry_create with slug');

select * from finish();
rollback;
