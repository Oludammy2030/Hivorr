-- EP-02-01: Taxonomy Seed Verification
--
-- Validates the seed data produced by migration 20260829090001_taxonomy_seed_data.sql:
-- counts, active flags, descriptions, FK integrity, slug uniqueness / format,
-- profession distribution, sort order, public readability, and absence of a
-- client write path. Runs in a rolled-back transaction (read-only verification),
-- operating against the committed (migration-applied) database state.

begin;
set search_path to extensions, public;
select plan(20);

-- ─── Counts ──────────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.industries), 8,
  'exactly 8 industries seeded');
select is(
  (select count(*)::int from public.professions), 46,
  'exactly 46 professions seeded');

-- ─── Active flags ──────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.industries where is_active), 8,
  'all industries active');
select is(
  (select count(*)::int from public.professions where is_active), 46,
  'all professions active');

-- ─── Descriptions present ───────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.industries where description is null), 0,
  'no null industry descriptions');
select is(
  (select count(*)::int from public.professions where description is null), 0,
  'no null profession descriptions');

-- ─── FK integrity ───────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.professions p
   where not exists (select 1 from public.industries i where i.id = p.industry_id)),
  0, 'every profession references an existing industry');

-- ─── Slug uniqueness ────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from (
    select slug from public.industries group by slug having count(*) > 1) t),
  0, 'industry slugs globally unique');
select is(
  (select count(*)::int from (
    select slug from public.professions group by slug having count(*) > 1) t),
  0, 'profession slugs globally unique');

-- ─── Slug format compliance ─────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.industries
   where slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  0, 'all industry slugs match kebab-case format');
select is(
  (select count(*)::int from public.professions
   where slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  0, 'all profession slugs match kebab-case format');

-- ─── Profession distribution per industry (3–8) ─────────────────────────────────
select is(
  (select count(*)::int from (
    select i.id
    from public.industries i
    join public.professions p on p.industry_id = i.id
    group by i.id
    having count(p.id) < 3 or count(p.id) > 8) t),
  0, 'every industry has between 3 and 8 professions');

-- ─── Sort order populated ───────────────────────────────────────────────────────
select is(
  (select count(*)::int from public.industries
   where sort_order is null or sort_order = 0),
  0, 'industry sort_order populated');
select is(
  (select count(*)::int from public.professions
   where sort_order is null or sort_order = 0),
  0, 'profession sort_order populated');

-- ─── Public readability (anon) ───────────────────────────────────────────────────
set role anon;
select is(
  (select count(*)::int from public.industries), 8,
  'anon can read 8 industries');
select is(
  (select count(*)::int from public.professions), 46,
  'anon can read 46 professions');

-- ─── No client write path (authenticated) ───────────────────────────────────────
set role postgres;
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ insert into public.industries (slug, name) values ('should-fail', 'Should Fail') $$,
  '42501', null, 'authenticated cannot insert into industries');
select throws_ok(
  $$ insert into public.professions (industry_id, slug, name)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'should-fail', 'Should Fail') $$,
  '42501', null, 'authenticated cannot insert into professions');
select throws_ok(
  $$ update public.professions set name = 'x' where slug = 'electrician' $$,
  '42501', null, 'authenticated cannot update professions');
select throws_ok(
  $$ delete from public.industries where slug = 'legal' $$,
  '42501', null, 'authenticated cannot delete industries');

select * from finish();
rollback;
