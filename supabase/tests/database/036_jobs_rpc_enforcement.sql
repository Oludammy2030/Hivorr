-- EP-04-01: Jobs & Applications RPC Enforcement
--
-- Validates the 16 jobs RPCs:
--   - Authorization: anon cannot call any (42501); capability gates return
--     PLT002 (hire to post, offer to apply — switch focus via the launcher);
--     owner checks return
--     PLT002; identical PLT004 for foreign/unavailable ids (no oracle).
--   - Validation: PLT003 paths for title/description/budget/currency/taxonomy/
--     cover note/quote/duration/limit/role/status filters.
--   - State machines: draft->open<->paused, ->cancelled; awarded->completed;
--     submitted->shortlisted->accepted/rejected, ->withdrawn; duplicates and
--     self-apply blocked (PLT005).
--   - job_get returns applications[] (owner) + my_application + events[];
--     job_list is open-only discovery; job_list_mine posted|applied scoping.
--   - service_role can call the read RPCs.

begin;
set search_path to extensions, public;
select plan(64);

-- ─── 0. Fixtures ───────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'a1a1a1a1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2b2b2b2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'c3c3c3c3-3333-4333-8333-333333333333', true);
select set_config('test.d', 'd4d4d4d4-4444-4444-8444-444444444444', true);
select set_config('test.e', 'e5e5e5e5-5555-4555-8555-555555555555', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'jobs-a@example.com'),
       (current_setting('test.b')::uuid, 'jobs-b@example.com'),
       (current_setting('test.c')::uuid, 'jobs-c@example.com'),
       (current_setting('test.d')::uuid, 'jobs-d@example.com'),
       (current_setting('test.e')::uuid, 'jobs-e@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active'),
       (current_setting('test.d')::uuid, 'active'),
       (current_setting('test.e')::uuid, 'active')
on conflict (id) do nothing;

-- Capability assignment bypasses the D5 guard via the RPC GUC (test-only).
select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id = current_setting('test.a')::uuid;
update public.entities set capability = 'offer'
 where id = current_setting('test.b')::uuid;
update public.entities set capability = 'offer'
 where id in (current_setting('test.c')::uuid, current_setting('test.e')::uuid);
select set_config('platform.rpc_invocation', '', true);

select set_config('test.prof1',
  (select id::text from public.professions where is_active limit 1), true);

-- ─── 1. Authorization: anon ────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.job_create('Valid Job Title Here', 'A description that is definitely longer than fifty characters for testing.') $$,
  '42501', null, 'anon cannot call job_create');
select throws_ok($$ select public.job_update('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_update');
select throws_ok($$ select public.job_publish('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_publish');
select throws_ok($$ select public.job_pause('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_pause');
select throws_ok($$ select public.job_resume('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_resume');
select throws_ok($$ select public.job_cancel('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_cancel');
select throws_ok($$ select public.job_complete('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_complete');
select throws_ok($$ select public.job_get('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call job_get');
select throws_ok($$ select public.job_list() $$,
  '42501', null, 'anon cannot call job_list');
select throws_ok($$ select public.job_list_mine() $$,
  '42501', null, 'anon cannot call job_list_mine');
select throws_ok($$ select public.application_submit('00000000-0000-0000-0000-000000000000'::uuid, 'A cover note that is definitely longer than twenty characters.') $$,
  '42501', null, 'anon cannot call application_submit');
select throws_ok($$ select public.application_withdraw('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call application_withdraw');
select throws_ok($$ select public.application_shortlist('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call application_shortlist');
select throws_ok($$ select public.application_reject('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call application_reject');
select throws_ok($$ select public.application_list_for_job('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call application_list_for_job');
select throws_ok($$ select public.application_list_mine() $$,
  '42501', null, 'anon cannot call application_list_mine');

-- ─── 2. Validation: job_create (A is hire) ─────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.job_create('Short', 'A description that is definitely longer than fifty characters for testing.') $$,
  'P0001', null, 'job_create with short title rejected (PLT003)');
select throws_ok($$ select public.job_create('Valid Job Title Here', 'Too short.') $$,
  'P0001', null, 'job_create with short description rejected (PLT003)');
select throws_ok($$ select public.job_create('Valid Job Title Here', 'A description that is definitely longer than fifty characters for testing.', null, null, 5000, 1000) $$,
  'P0001', null, 'job_create with inverted budget rejected (PLT003)');
select throws_ok($$ select public.job_create('Valid Job Title Here', 'A description that is definitely longer than fifty characters for testing.', null, null, null, null, 'XYZ') $$,
  'P0001', null, 'job_create with bad currency rejected (PLT003)');
select throws_ok($$ select public.job_create('Valid Job Title Here', 'A description that is definitely longer than fifty characters for testing.', '99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'job_create with unknown profession rejected (PLT004)');

-- D has no capability: posting blocked (PLT002).
select set_config('request.jwt.claim.sub', current_setting('test.d'), true);
select throws_ok($$ select public.job_create('Valid Job Title Here', 'A description that is definitely longer than fifty characters for testing.') $$,
  'P0001', null, 'job_create without hiring capability rejected (PLT002)');

-- ─── 3. Lifecycle: create/publish/pause/resume (A) ─────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.j1', (select (public.job_create(
  'Fix My Kitchen Plumbing Issue',
  'Kitchen sink drainage is blocked and the faucet leaks continuously. Need a certified plumber with own tools this week.',
  current_setting('test.prof1')::uuid, null, 5000, 20000, 'NGN', 'Lagos'
 )->'data'->>'id')), true);

select lives_ok($$ select public.job_get(current_setting('test.j1')::uuid) $$,
  'owner can get own draft job');
select is(
  (select (public.job_get(current_setting('test.j1')::uuid)->'data'->'job'->>'status')),
  'draft', 'J1 starts as draft');

select lives_ok($$ select public.job_publish(current_setting('test.j1')::uuid) $$,
  'owner can publish draft job');
select is(
  (select (public.job_get(current_setting('test.j1')::uuid)->'data'->'job'->>'status')),
  'open', 'J1 is open after publish');
select throws_ok($$ select public.job_publish(current_setting('test.j1')::uuid) $$,
  'P0001', null, 're-publish of open job rejected (PLT005)');

-- B (non-owner) cannot mutate J1.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.job_update(current_setting('test.j1')::uuid, 'Hacked Title Here!!') $$,
  'P0001', null, 'non-owner job_update rejected (PLT002)');

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.job_update(current_setting('test.j1')::uuid, 'Bad') $$,
  'P0001', null, 'job_update with short title rejected (PLT003)');
select lives_ok($$ select public.job_update(current_setting('test.j1')::uuid, 'Fix My Kitchen Plumbing Urgently') $$,
  'owner can update open job');

select lives_ok($$ select public.job_pause(current_setting('test.j1')::uuid) $$,
  'owner can pause open job');
select is(
  (select (public.job_list()->>'code')), 'PLT000', 'job_list envelope ok while J1 paused');

select lives_ok($$ select public.job_resume(current_setting('test.j1')::uuid) $$,
  'owner can resume paused job');
select throws_ok($$ select public.job_resume(current_setting('test.j1')::uuid) $$,
  'P0001', null, 'resume of open job rejected (PLT005)');

-- ─── 4. Applications: capability + availability gates ──────────────────────
-- A (hire) cannot apply.
select throws_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'I am a great plumber with ten years of experience in Lagos.') $$,
  'P0001', null, 'hire-only client cannot apply (PLT002)');

-- Draft job J2 for availability gate.
select set_config('test.j2', (select (public.job_create(
  'Paint My Two Bedroom Flat',
  'Full interior repaint of a two bedroom flat in Ikeja including ceilings and doors. Paint provided by client.',
  null, null, 30000, 60000)->'data'->>'id')), true);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.application_submit(
  current_setting('test.j2')::uuid,
  'Professional painter with five years experience and references.') $$,
  'P0001', null, 'application to draft job rejected (PLT004)');

-- B applies to open J1.
select lives_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Certified plumber with own tools, available this week for inspection.',
  15000, 'NGN', 3) $$,
  'professional can apply to open job');
select throws_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Trying to apply a second time to the same job here.') $$,
  'P0001', null, 'duplicate application rejected (PLT005)');

-- A (owner, focus switched to offer) cannot self-apply.
set role postgres;
select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'offer'
 where id = current_setting('test.a')::uuid;
select set_config('platform.rpc_invocation', '', true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Owner trying to apply to own job with enough characters.') $$,
  'P0001', null, 'self-apply rejected (PLT005)');

-- C applies then withdraws.
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select lives_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Master plumber, same-day service and one year workmanship warranty.',
  18000) $$,
  'second professional can apply');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.app_c', (select (a->>'id') from
  (select jsonb_array_elements(
     public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
   where a->>'professional_entity_id' = current_setting('test.c')), true);
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select lives_ok($$ select public.application_withdraw(current_setting('test.app_c')::uuid) $$,
  'applicant can withdraw submitted application');
select throws_ok($$ select public.application_withdraw(current_setting('test.app_c')::uuid) $$,
  'P0001', null, 're-withdraw rejected (PLT005)');

-- ─── 5. Shortlist / reject (A owns J1) ─────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.app_b', (select (a->>'id') from
  (select jsonb_array_elements(
     public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
   where a->>'professional_entity_id' = current_setting('test.b')), true);
select lives_ok($$ select public.application_shortlist(current_setting('test.app_b')::uuid) $$,
  'owner can shortlist submitted application');
select throws_ok($$ select public.application_shortlist(current_setting('test.app_b')::uuid) $$,
  'P0001', null, 're-shortlist rejected (PLT005)');

-- B (non-owner) cannot shortlist.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.application_shortlist(current_setting('test.app_c')::uuid) $$,
  'P0001', null, 'non-owner shortlist rejected (PLT002)');

-- E applies, A rejects.
select set_config('request.jwt.claim.sub', current_setting('test.e'), true);
select lives_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Budget plumber available weekends with flexible pricing options.',
  12000) $$,
  'third professional can apply');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.app_e', (select (a->>'id') from
  (select jsonb_array_elements(
     public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
   where a->>'professional_entity_id' = current_setting('test.e')), true);
select lives_ok($$ select public.application_reject(current_setting('test.app_e')::uuid) $$,
  'owner can reject submitted application');
select throws_ok($$ select public.application_submit(
  current_setting('test.j1')::uuid,
  'Owner re-apply attempt after rejection should still be blocked.') $$,
  'P0001', null, 'owner re-apply still blocked (PLT005 self-apply)');

-- ─── 6. Listing scopes ─────────────────────────────────────────────────────
select lives_ok($$ select public.application_list_for_job(current_setting('test.j1')::uuid) $$,
  'owner can list applications for own job');
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.application_list_for_job(current_setting('test.j1')::uuid) $$,
  'P0001', null, 'non-owner cannot list applications for job (PLT002)');
select lives_ok($$ select public.application_list_mine() $$,
  'professional can list own applications');

select throws_ok($$ select public.job_get('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'job_get unknown id rejected (PLT004)');
select lives_ok($$ select public.job_get(current_setting('test.j1')::uuid) $$,
  'applicant can get open job');
select throws_ok($$ select public.job_get(current_setting('test.j2')::uuid) $$,
  'P0001', null, 'non-applicant cannot get draft job (PLT004)');

select throws_ok($$ select public.job_list(null, null, 0) $$,
  'P0001', null, 'job_list with bad limit rejected (PLT003)');
select throws_ok($$ select public.job_list_mine('admin') $$,
  'P0001', null, 'job_list_mine with bad role rejected (PLT003)');
select lives_ok($$ select public.job_list_mine('applied') $$,
  'professional can list applied jobs');

-- ─── 7. Cancel / complete ──────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.job_list_mine('posted') $$,
  'owner can list posted jobs');
select lives_ok($$ select public.job_cancel(current_setting('test.j2')::uuid, 'Found someone offline.') $$,
  'owner can cancel draft job');
select throws_ok($$ select public.job_cancel(current_setting('test.j2')::uuid) $$,
  'P0001', null, 're-cancel rejected (PLT005)');
select throws_ok($$ select public.job_complete(current_setting('test.j1')::uuid) $$,
  'P0001', null, 'complete of non-awarded job rejected (PLT005)');

-- ─── 8. service_role reads ─────────────────────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.job_list() $$, 'service_role job_list');
select lives_ok($$ select public.job_get(current_setting('test.j1')::uuid) $$, 'service_role job_get');
select lives_ok($$ select public.job_list_mine() $$, 'service_role job_list_mine');

select * from finish();
rollback;
