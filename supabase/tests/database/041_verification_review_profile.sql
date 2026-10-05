-- Professional Verification Queue: profile RPC contract (Phase 3).
--
-- Locks the `verification_review_profile_get` wire contract shared with the
-- Flutter client (migration 20261005090002):
--
--   verification_review_profile_get ->
--     data.experiences[] (9 canonical keys, current-first ordering)
--     data.educations[]  (5 canonical keys, graduation-year ordering)
--     data.skills[]      (3 canonical keys, name ordering)

begin;
set search_path to extensions, public;
select plan(14);

-- ─── 0. Fixtures ────────────────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'nonadmin-profile@test.local'),
       ('77777777-7777-7777-7777-777777777777', 'admin-profile@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('77777777-7777-7777-7777-777777777777', 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name)
values ('77777777-7777-7777-7777-777777777777', 'Profile Pro', 'Profile Legal')
on conflict (entity_id) do nothing;

insert into public.platform_admins (user_id, granted_by, notes)
values ('77777777-7777-7777-7777-777777777777', null, 'Profile contract test admin')
on conflict (user_id) do nothing;

insert into public.entity_credentials (id, entity_id, kind, title)
values ('ffffffff-0000-0000-0000-000000000371', '77777777-7777-7777-7777-777777777777', 'trade_proof', 'Profile Trade Cert')
on conflict (id) do nothing;

insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status)
values ('ffffffff-0000-0000-0000-000000000372', '77777777-7777-7777-7777-777777777777', 'ffffffff-0000-0000-0000-000000000371', 'trade_proof', 'pending')
on conflict (id) do nothing;

-- Past role first (insertion order must not win over ordering rules).
insert into public.entity_work_experiences (id, entity_id, title, organization, start_year, start_month, end_year, end_month, is_current, description)
values ('ffffffff-0000-0000-0000-000000000373', '77777777-7777-7777-7777-777777777777', 'Junior Plumber', 'Old Pipes Co', 2019, 6, 2021, 3, false, 'Assisted installs.'),
       ('ffffffff-0000-0000-0000-000000000374', '77777777-7777-7777-7777-777777777777', 'Senior Plumber', 'Flow Masters', 2021, 4, null, null, true, 'Leads installs.')
on conflict (id) do nothing;

insert into public.entity_educations (id, entity_id, school, degree, field_of_study, graduation_year)
values ('ffffffff-0000-0000-0000-000000000375', '77777777-7777-7777-7777-777777777777', 'Trade Institute', 'Diploma', 'Plumbing', 2019)
on conflict (id) do nothing;

insert into public.entity_skills (id, entity_id, name, years_experience)
values ('ffffffff-0000-0000-0000-000000000376', '77777777-7777-7777-7777-777777777777', 'Welding', 4),
       ('ffffffff-0000-0000-0000-000000000377', '77777777-7777-7777-7777-777777777777', 'Pipefitting', 6)
on conflict (id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '77777777-7777-7777-7777-777777777777', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Surface + experience ordering ───────────────────────────────────────
select has_function('public', 'verification_review_profile_get', 'profile_get exists');

select is(
  jsonb_array_length(
    public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'experiences'
  ),
  2,
  'profile_get returns both experience rows'
);

select is(
  (public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'experiences' -> 0 ->> 'title'),
  'Senior Plumber',
  'profile_get orders the current role first'
);

select is(
  (public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'experiences' -> 0 ->> 'is_current'),
  'true',
  'profile_get exposes is_current'
);

-- ─── 2. Education + skills ──────────────────────────────────────────────────
select is(
  (public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'educations' -> 0 ->> 'school'),
  'Trade Institute',
  'profile_get exposes the school'
);

select is(
  (public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'skills' -> 0 ->> 'name'),
  'Pipefitting',
  'profile_get orders skills by name ascending'
);

select is(
  (public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'skills' -> 0 ->> 'years_experience'),
  '6',
  'profile_get exposes years of experience'
);

-- ─── 3. Canonical key sets ──────────────────────────────────────────────────
select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'experiences'
       ) limit 1)
     ) k $$,
  $$ select unnest(array[
       'id', 'title', 'organization', 'start_year', 'start_month',
       'end_year', 'end_month', 'is_current', 'description'
     ]) $$,
  'profile_get experience rows carry exactly the canonical key set'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'educations'
       ) limit 1)
     ) k $$,
  $$ select unnest(array[
       'id', 'school', 'degree', 'field_of_study', 'graduation_year'
     ]) $$,
  'profile_get education rows carry exactly the canonical key set'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') -> 'data' -> 'skills'
       ) limit 1)
     ) k $$,
  $$ select unnest(array['id', 'name', 'years_experience']) $$,
  'profile_get skill rows carry exactly the canonical key set'
);

-- ─── 4. Envelope + validation + gating ─────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372'))),
  4,
  'profile_get envelope has exactly 4 top-level keys'
);

select throws_ok(
  $$ select public.verification_review_profile_get(null) $$,
  'P0001', 'PLT003: Submission id is required.',
  'profile_get rejects a null submission id'
);

select throws_ok(
  $$ select public.verification_review_profile_get('00000000-0000-0000-0000-000000000000') $$,
  'P0001', 'PLT004: Submission not found.',
  'profile_get reports an unknown submission'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_profile_get('ffffffff-0000-0000-0000-000000000372') $$,
  'P0001', 'PLT002: Admin access required.',
  'profile_get raises PLT002 for non-admin'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;
