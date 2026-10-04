-- Professional Verification Queue: server filter contract (Phase 3).
--
-- Asserts the filter params added in migration 20261004090001 on top of the
-- unchanged 16-key row shape (locked by test 021):
-- free-text search (display/legal/credential), profession restriction, and
-- newest/oldest/name sort, including total_count honoring the filters.

begin;
set search_path to extensions, public;
select plan(12);

-- ─── 0. Fixtures ────────────────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'nonadmin-filter@test.local'),
       ('44444444-4444-4444-4444-444444444444', 'admin-filter@test.local'),
       ('55555555-5555-5555-5555-555555555555', 'entity-filter-b@test.local'),
       ('66666666-6666-6666-6666-666666666666', 'entity-filter-c@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('44444444-4444-4444-4444-444444444444', 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name)
values ('44444444-4444-4444-4444-444444444444', 'placeholder', 'Zulu Holdings')
on conflict (entity_id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000270', 'fx-filter-ind', 'Filter Ind', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000271', 'ffffffff-0000-0000-0000-000000000270', 'fx-filter-alpha', 'Filter Alpha Prof', true),
       ('ffffffff-0000-0000-0000-000000000272', 'ffffffff-0000-0000-0000-000000000270', 'fx-filter-beta', 'Filter Beta Prof', true)
on conflict (id) do nothing;

insert into public.platform_admins (user_id, granted_by, notes)
values ('44444444-4444-4444-4444-444444444444', null, 'Filter contract test admin')
on conflict (user_id) do nothing;

-- Three credentials with distinct titles.
insert into public.entity_credentials (id, entity_id, profession_id, kind, title)
values ('ffffffff-0000-0000-0000-000000000273', '44444444-4444-4444-4444-444444444444', 'ffffffff-0000-0000-0000-000000000271', 'trade_proof', 'Zulu Cert'),
       ('ffffffff-0000-0000-0000-000000000274', '44444444-4444-4444-4444-444444444444', 'ffffffff-0000-0000-0000-000000000272', 'trade_proof', 'Mango Cert'),
       ('ffffffff-0000-0000-0000-000000000275', '44444444-4444-4444-4444-444444444444', 'ffffffff-0000-0000-0000-000000000271', 'trade_proof', 'Gamma Cert')
on conflict (id) do nothing;

-- One display name per entity: distinct searchable names need three entities.
insert into public.entities (id, status)
values ('55555555-5555-5555-5555-555555555555', 'active'),
       ('66666666-6666-6666-6666-666666666666', 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name)
values ('55555555-5555-5555-5555-555555555555', 'Mango Beta', 'Zulu Holdings'),
       ('66666666-6666-6666-6666-666666666666', 'Apple Gamma', 'Zulu Holdings')
on conflict (entity_id) do nothing;

-- Re-point credentials B/C at their entities (A keeps the first entity).
update public.entity_credentials set entity_id = '55555555-5555-5555-5555-555555555555'
 where id = 'ffffffff-0000-0000-0000-000000000274';
update public.entity_credentials set entity_id = '66666666-6666-6666-6666-666666666666'
 where id = 'ffffffff-0000-0000-0000-000000000275';
update public.entity_profiles set display_name = 'Zulu Alpha'
 where entity_id = '44444444-4444-4444-4444-444444444444';

-- S1 Zulu/Alpha 3d ago, S2 Mango/Beta 1d ago, S3 Apple/Alpha 2d ago.
insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status, submitted_at)
values ('ffffffff-0000-0000-0000-000000000277', '44444444-4444-4444-4444-444444444444', 'ffffffff-0000-0000-0000-000000000273', 'trade_proof', 'pending', now() - interval '3 days'),
       ('ffffffff-0000-0000-0000-000000000278', '55555555-5555-5555-5555-555555555555', 'ffffffff-0000-0000-0000-000000000274', 'trade_proof', 'pending', now() - interval '1 day'),
       ('ffffffff-0000-0000-0000-000000000279', '66666666-6666-6666-6666-666666666666', 'ffffffff-0000-0000-0000-000000000275', 'trade_proof', 'pending', now() - interval '2 days')
on conflict (id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Surface + default order ─────────────────────────────────────────────
select has_function('public', 'verification_review_queue_get', 'queue_get exists');

select is(
  (public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions' -> 0 ->> 'entity_display_name'),
  'Mango Beta',
  'queue_get defaults to newest first'
);

-- ─── 2. Free-text search ────────────────────────────────────────────────────
select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, null, 'mango') -> 'data' -> 'submissions'
  ),
  1,
  'queue_get search matches the display name'
);

select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, null, 'zulu hold') -> 'data' -> 'submissions'
  ),
  3,
  'queue_get search matches the shared legal name'
);

select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, null, 'gamma cert') -> 'data' -> 'submissions'
  ),
  1,
  'queue_get search matches the credential title'
);

select is(
  public.verification_review_queue_get(null, 0, 20, null, 'zzz-no-match') -> 'data' ->> 'total_count',
  '0',
  'queue_get total_count honors a search with no matches'
);

-- ─── 3. Profession filter ───────────────────────────────────────────────────
select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, null, null, 'ffffffff-0000-0000-0000-000000000271') -> 'data' -> 'submissions'
  ),
  2,
  'queue_get profession filter returns the two Alpha rows'
);

-- ─── 4. Sort modes ──────────────────────────────────────────────────────────
select is(
  (public.verification_review_queue_get(null, 0, 20, null, null, null, 'oldest') -> 'data' -> 'submissions' -> 0 ->> 'entity_display_name'),
  'Zulu Alpha',
  'queue_get oldest sorts submitted_at ascending'
);

select is(
  (public.verification_review_queue_get(null, 0, 20, null, null, null, 'name') -> 'data' -> 'submissions' -> 0 ->> 'entity_display_name'),
  'Apple Gamma',
  'queue_get name sorts display name ascending'
);

select throws_ok(
  $$ select public.verification_review_queue_get(null, 0, 20, null, null, null, 'bogus') $$,
  'P0001', 'PLT003: Invalid sort (newest/oldest/name).',
  'queue_get rejects an unknown sort'
);

-- ─── 5. Envelope + gating ───────────────────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.verification_review_queue_get(null, 0, 20, null, 'mango'))),
  4,
  'queue_get envelope keeps 4 top-level keys with filters'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_queue_get(null, 0, 20, null, 'mango') $$,
  'P0001', 'PLT002: Admin access required.',
  'queue_get raises PLT002 for non-admin with filters'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;
