-- Identity Phase 4: job-business linkage + client identity snapshots.
--
-- Validates hiring as a verified business (membership + approval gates),
-- personal-job snapshots, application carry-through of both snapshots, and
-- the owner list projection:
--   - 4 business-linked create + 2 business gates + 2 personal create +
--   - 1 approved apply + 2 application-row snapshots + 2 list projection = 13.

begin;
set search_path to extensions, public;
select plan(13);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'a1a1a1a1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2b2b2b2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'c3c3c3c3-3333-4333-8333-333333333333', true);
select set_config('test.d', 'd4d4d4d4-4444-8444-9444-444444444444', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'bizlink-client@example.com'),
       (current_setting('test.b')::uuid, 'bizlink-pro@example.com'),
       (current_setting('test.c')::uuid, 'bizlink-pending@example.com'),
       (current_setting('test.d')::uuid, 'bizlink-other@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active'),
       (current_setting('test.d')::uuid, 'active')
on conflict (id) do nothing;

select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id in (current_setting('test.a')::uuid, current_setting('test.d')::uuid);
update public.entities set capability = 'offer'
 where id in (current_setting('test.b')::uuid, current_setting('test.c')::uuid);
select set_config('platform.rpc_invocation', '', true);

insert into public.entity_profiles (entity_id, legal_name, display_name)
values (current_setting('test.a')::uuid, 'Amara Diallo', 'Amara Diallo')
on conflict (entity_id) do update set display_name = 'Amara Diallo';

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-0000000000a1', 'bizlink-trade', 'Bizlink Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-0000000000a2', 'ffffffff-0000-0000-0000-0000000000a1', 'bizlink-fixer', 'Bizlink Fixer', true)
on conflict (id) do nothing;

-- B approved for the typed profession; C unbound.
insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values (current_setting('test.b')::uuid, 'ffffffff-0000-0000-0000-0000000000a2', true, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Biz1 verified (+A authorized rep); Biz2 pending (A, unauthorized);
-- BizD belongs to stranger D.
insert into public.businesses (id, trading_name, registered_legal_name, cac_number, verification_status, created_by)
values ('aaaaaaaa-0000-4000-8000-000000000001', 'Amara Foods', 'Amara Foods Ltd', 'CAC-LINK-001', 'approved', current_setting('test.a')::uuid),
       ('aaaaaaaa-0000-4000-8000-000000000002', 'Pending Co', 'Pending Co Ltd', 'CAC-LINK-002', 'pending', current_setting('test.a')::uuid),
       ('aaaaaaaa-0000-4000-8000-000000000003', 'Stranger Co', 'Stranger Co Ltd', 'CAC-LINK-003', 'approved', current_setting('test.d')::uuid)
on conflict (id) do nothing;

insert into public.business_memberships (business_id, entity_id, role, is_authorized)
values ('aaaaaaaa-0000-4000-8000-000000000001', current_setting('test.a')::uuid, 'representative', true),
       ('aaaaaaaa-0000-4000-8000-000000000002', current_setting('test.a')::uuid, 'representative', false),
       ('aaaaaaaa-0000-4000-8000-000000000003', current_setting('test.d')::uuid, 'representative', true)
on conflict (business_id, entity_id) do update set is_authorized = excluded.is_authorized;

-- ─── 1. Create hiring as the verified business (A) ───────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.j1', (select (public.job_create(
  'Fix the kitchen sink urgently today',
  'Kitchen sink drainage is blocked and the faucet leaks continuously. Need a certified plumber with own tools this week.',
  'ffffffff-0000-0000-0000-0000000000a2', null, 5000, 20000, 'NGN', 'Lagos',
  'aaaaaaaa-0000-4000-8000-000000000001'
)->'data'->>'id')), true);
select lives_ok(
  $$ select public.job_publish(current_setting('test.j1')::uuid) $$,
  'business-linked job publishes (PLT000)'
);
select is(
  (select business_id::text from public.jobs where id = current_setting('test.j1')::uuid),
  'aaaaaaaa-0000-4000-8000-000000000001',
  'job row links the hiring business'
);
select is(
  (select client_business_name from public.jobs where id = current_setting('test.j1')::uuid),
  'Amara Foods',
  'job snapshots the business trading name at creation'
);
select is(
  (select client_display_name from public.jobs where id = current_setting('test.j1')::uuid),
  'Amara Diallo',
  'job snapshots the poster display name at creation'
);

-- ─── 2. Business gates ───────────────────────────────────────────────────────
select throws_ok(
  $$ select public.job_create(
    'Paint the flat urgently this week',
    'Full interior repaint of a two bedroom flat including ceilings and doors over the weekend.',
    null, null, 30000, 60000, 'NGN', 'Lagos',
    'aaaaaaaa-0000-4000-8000-000000000002') $$,
  'P0001', 'PLT005: Business verification required to hire for this business.',
  'unverified business rejected with guidance (PLT005)'
);
select throws_ok(
  $$ select public.job_create(
    'Paint the flat urgently this week',
    'Full interior repaint of a two bedroom flat including ceilings and doors over the weekend.',
    null, null, 30000, 60000, 'NGN', 'Lagos',
    'aaaaaaaa-0000-4000-8000-000000000003') $$,
  'P0001', 'PLT004: Business not found.',
  'stranger business identical to unknown (PLT004, no oracle)'
);

-- ─── 3. Personal job snapshots display, null business (A) ────────────────────
select set_config('test.j2', (select (public.job_create(
  'Help moving boxes this weekend',
  'Need an extra pair of hands moving packed boxes from the apartment to a van on Saturday morning.',
  null, null, 5000, 20000, 'NGN', 'Lagos'
)->'data'->>'id')), true);
select lives_ok(
  $$ select public.job_publish(current_setting('test.j2')::uuid) $$,
  'personal job publishes (PLT000)'
);
select is(
  (select client_business_name from public.jobs where id = current_setting('test.j2')::uuid),
  null,
  'personal job snapshots null business name'
);

-- ─── 4. Application copies both snapshots (B on J1) ──────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select lives_ok(
  $$ select public.application_submit(
    current_setting('test.j1')::uuid,
    'Certified bizlink plumber with own tools, available this week for the job.'
  ) $$,
  'approved professional applies to the business-linked job (PLT000)'
);

-- ─── 5. Owner list projects the client snapshots (A) ─────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select is(
  (select client_business_name from public.job_applications
    where job_id = current_setting('test.j1')::uuid
      and professional_entity_id = current_setting('test.b')::uuid),
  'Amara Foods',
  'application row freezes the business name at submit'
);
select is(
  (select client_display_name from public.job_applications
    where job_id = current_setting('test.j1')::uuid
      and professional_entity_id = current_setting('test.b')::uuid),
  'Amara Diallo',
  'application row freezes the client display name at submit'
);
select is(
  (select (a->>'client_business_name') from
    (select jsonb_array_elements(
      public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s),
  'Amara Foods',
  'owner list projects the frozen business name'
);
select is(
  (select (a->>'client_display_name') from
    (select jsonb_array_elements(
      public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s),
  'Amara Diallo',
  'owner list projects the frozen client display name'
);

select * from finish();
rollback;
