-- Applicant identity snapshot (20261010090001).
--
-- Validates that application_submit snapshots whitelisted identity columns
-- from the applicant's OWN profile rows (RLS-legal self-read) and that
-- application_list_for_job / job_get project them, so the client inbox
-- renders names with zero follow-up profile RPCs:
--   - submit response carries applicant_display_name/avatar/profession_*.
--   - list_for_job carries the same snapshot per item.
--   - job_get applications[] carries it (whole-row to_jsonb).
--   - missing profile row yields NULLs (client falls back, never crashes).
--   - no legal_name/phone keys leak into any application payload.

begin;
set search_path to extensions, public;
select plan(15);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'b1b1b1b1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2b2b2b2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'b3b3b3b3-3333-4333-8333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'snap-a@example.com'),
       (current_setting('test.b')::uuid, 'snap-b@example.com'),
       (current_setting('test.c')::uuid, 'snap-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id = current_setting('test.a')::uuid;
update public.entities set capability = 'offer'
 where id in (current_setting('test.b')::uuid, current_setting('test.c')::uuid);
select set_config('platform.rpc_invocation', '', true);

-- B has a profile + one approved primary profession; C has no profile row.
insert into public.entity_profiles (entity_id, legal_name, display_name, avatar_path)
values (current_setting('test.b')::uuid, 'Chidi Eze Legal', 'Chidi Eze', 'profile-avatars/b2/avatar.png')
on conflict (entity_id) do update
  set display_name = 'Chidi Eze', avatar_path = 'profile-avatars/b2/avatar.png';

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000071', 'snap-trade', 'Snapshot Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000072', 'ffffffff-0000-0000-0000-000000000071', 'snap-fixer', 'Snapshot Fixer', true)
on conflict (id) do nothing;

insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values (current_setting('test.b')::uuid, 'ffffffff-0000-0000-0000-000000000072', true, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- A posts + publishes J1.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.j1', (select (public.job_create(
  'Fix My Kitchen Sink Quickly',
  'Kitchen sink drainage is blocked and the faucet leaks continuously. Need a certified plumber with own tools this week.',
  null, null, 5000, 20000, 'NGN', 'Lagos'
 )->'data'->>'id')), true);
select lives_ok($$ select public.job_publish(current_setting('test.j1')::uuid) $$,
  'owner can publish snapshot job');

-- ─── 1. Submit snapshots identity (B) ────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
-- set_config takes text: explicit jsonb→text cast (no implicit cast exists).
select set_config('test.sub_b', (select public.application_submit(
  current_setting('test.j1')::uuid,
  'Certified snapshot plumber with own tools, available this week.',
  15000, 'NGN', 3))::text, true);
select is(
  (select current_setting('test.sub_b')::jsonb->'data'->>'applicant_display_name'),
  'Chidi Eze', 'submit response snapshots display name');
select is(
  (select current_setting('test.sub_b')::jsonb->'data'->>'applicant_avatar_path'),
  'profile-avatars/b2/avatar.png', 'submit response snapshots avatar path');
select is(
  (select current_setting('test.sub_b')::jsonb->'data'->>'applicant_profession_name'),
  'Snapshot Fixer', 'submit response snapshots approved profession name');
select is(
  (select current_setting('test.sub_b')::jsonb->'data'->>'applicant_profession_slug'),
  'snap-fixer', 'submit response snapshots profession slug');

-- ─── 2. Missing profile row yields NULLs, not errors (C) ────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select set_config('test.sub_c', (select public.application_submit(
  current_setting('test.j1')::uuid,
  'Eager newcomer without a profile row yet, ready to start now.',
  12000))::text, true);
select is(
  (select current_setting('test.sub_c')::jsonb->'data'->>'applicant_display_name'),
  null, 'submit without profile row snapshots NULL display name');
select is(
  (select current_setting('test.sub_c')::jsonb->'data'->>'applicant_profession_name'),
  null, 'submit without profession snapshots NULL profession');

-- ─── 3. Owner list projects the snapshot ─────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select (a->>'applicant_display_name') from
    (select jsonb_array_elements(
       public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
    where a->>'professional_entity_id' = current_setting('test.b')),
  'Chidi Eze', 'list_for_job projects B display name');
select is(
  (select (a->>'applicant_profession_slug') from
    (select jsonb_array_elements(
       public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
    where a->>'professional_entity_id' = current_setting('test.b')),
  'snap-fixer', 'list_for_job projects B profession slug');
select is(
  (select (a->>'applicant_display_name') from
    (select jsonb_array_elements(
       public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
    where a->>'professional_entity_id' = current_setting('test.c')),
  null, 'list_for_job carries NULL snapshot for C');

-- ─── 4. No private-field leakage ─────────────────────────────────────────────
select ok(
  (select not (a ? 'legal_name') from
    (select jsonb_array_elements(
       public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
    where a->>'professional_entity_id' = current_setting('test.b')),
  'application payload has no legal_name key');
select ok(
  (select not (a ? 'phone_number') from
    (select jsonb_array_elements(
       public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
    where a->>'professional_entity_id' = current_setting('test.b')),
  'application payload has no phone_number key');

-- ─── 5. job_get applications[] carries the snapshot ──────────────────────────
select is(
  (select (a->>'applicant_display_name') from
    (select jsonb_array_elements(
       public.job_get(current_setting('test.j1')::uuid)->'data'->'applications') as a) s
    where a->>'professional_entity_id' = current_setting('test.b')),
  'Chidi Eze', 'job_get applications carry the snapshot');

select * from finish();
rollback;
