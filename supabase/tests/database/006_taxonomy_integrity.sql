-- EP-01-06: Taxonomy Integrity
--
-- Validates the two-tier Industry → Profession model (EP-01-06 Plan §14.2):
-- public readability, no client writes, slug uniqueness, RESTRICT FK, referential
-- integrity, and cascade behavior.

begin;
set search_path to extensions, public;
select plan(15);

-- ─── Anon + authenticated can read taxonomy ─────────────────────────────────
set role anon;
select is(
  (select count(*)::int from public.industries), 0, 'anon can read industries (empty now)');
select is(
  (select count(*)::int from public.professions), 0, 'anon can read professions (empty now)');

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*)::int from public.industries), 0, 'authenticated can read industries');
select is(
  (select count(*)::int from public.professions), 0, 'authenticated can read professions');

-- ─── No client write path to taxonomy ───────────────────────────────────────
select throws_ok(
  $$ insert into public.industries (slug, name) values ('tech', 'Technology') $$,
  '42501', null, 'anon/authenticated cannot insert into industries');
select throws_ok(
  $$ insert into public.professions (industry_id, slug, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'chef', 'Chef') $$,
  '42501', null, 'anon/authenticated cannot insert into professions');

set role postgres;

-- ─── Service role can populate (simulating EP-02 admin tooling) ─────────────
insert into public.industries (id, slug, name)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'tech', 'Technology');
insert into public.industries (id, slug, name)
values ('aaaaaaaa-0000-0000-0000-000000000002', 'food', 'Food');

insert into public.professions (id, industry_id, slug, name)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'chef', 'Chef');
insert into public.professions (id, industry_id, slug, name)
values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'electrician', 'Electrician');

-- ─── Slug uniqueness ─────────────────────────────────────────────────────────
select throws_ok(
  $$ insert into public.industries (slug, name) values ('tech', 'Duplicate Tech') $$,
  '23505', null, 'duplicate industry slug rejected');
select throws_ok(
  $$ insert into public.professions (industry_id, slug, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'chef', 'Dup Chef') $$,
  '23505', null, 'duplicate profession slug rejected');

-- ─── Slug format enforcement ─────────────────────────────────────────────────
select throws_ok(
  $$ insert into public.industries (slug, name) values ('Bad Slug', 'Bad') $$,
  '23514', null);
select throws_ok(
  $$ insert into public.industries (slug, name) values ('_bad', 'Bad') $$,
  '23514', null);

-- ─── Industry RESTRICT prevents orphaning ───────────────────────────────────
select throws_ok(
  $$ delete from public.industries where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '23503', null, 'cannot delete industry with linked professions (RESTRICT)');

-- ─── Referential integrity holds ─────────────────────────────────────────────
select is(
  (select count(*)::int from public.professions p join public.industries i on i.id = p.industry_id),
  2, 'every profession references an existing industry');

-- ─── Cascade behavior from entity deletion ──────────────────────────────────
insert into auth.users (id, email) values ('cccccccc-0000-0000-0000-000000000001', 'c@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values ('cccccccc-0000-0000-0000-000000000001', 'active');
insert into public.entity_professions (entity_id, profession_id)
values ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.entity_professions where entity_id = 'cccccccc-0000-0000-0000-000000000001'),
  1, 'entity profession binding present before cascade');

set role postgres;
delete from public.entities where id = 'cccccccc-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.entity_professions where entity_id = 'cccccccc-0000-0000-0000-000000000001'),
  0, 'entity deletion cascades to profession bindings');

-- ─── Vocabulary constraints ─────────────────────────────────────────────────
select throws_ok(
  $$ insert into public.entities (id, status) values ('dddddddd-0000-0000-0000-000000000001', 'bogus') $$,
  '23514', null, 'invalid entity status rejected');

select * from finish();
rollback;
