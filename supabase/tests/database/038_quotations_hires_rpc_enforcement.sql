-- EP-04-02: Quotations & Hires RPC Enforcement
--
-- Validates the 8 hiring RPCs end to end:
--   - Authorization: anon cannot call any (42501); applicant-only propose/
--     withdraw (PLT002); owner-only accept/shortlist/hire (PLT002);
--     participant-only hire reads with identical PLT004 (no oracle).
--   - Validation: PLT003/PLT004/PLT005 paths for amount/currency/duration/
--     revision chain/quotation state/hire funnel (shortlisted only, one hire
--     per job, quotation ownership).
--   - Full funnel: propose -> revise (supersede) -> accept -> shortlist ->
--     hire_accept (contract + milestone + event + award + reject rest) ->
--     professional accepts contract -> milestone complete/verify/close ->
--     hire_complete (job completed); hire_cancel reopens a pending hire.
--   - service_role can call the read RPCs.

begin;
set search_path to extensions, public;
select plan(50);

-- ─── 0. Fixtures ───────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'a1a1a1a1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2b2b2b2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'c3c3c3c3-3333-4333-8333-333333333333', true);
select set_config('test.d', 'd4d4d4d4-4444-4444-8444-444444444444', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'hire-a@example.com'),
       (current_setting('test.b')::uuid, 'hire-b@example.com'),
       (current_setting('test.c')::uuid, 'hire-c@example.com'),
       (current_setting('test.d')::uuid, 'hire-d@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active'),
       (current_setting('test.d')::uuid, 'active')
on conflict (id) do nothing;

select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id = current_setting('test.a')::uuid;
update public.entities set capability = 'offer'
 where id = current_setting('test.b')::uuid;
update public.entities set capability = 'offer'
 where id = current_setting('test.c')::uuid;
select set_config('platform.rpc_invocation', '', true);

-- A posts + publishes J1; B and C apply; A shortlists B.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.j1', (select (public.job_create(
  'Install Three Phase Prepaid Meter',
  'Licensed electrician needed to install a three phase prepaid meter with certification documentation in Surulere.',
  null, null, 25000, 50000)->'data'->>'id')), true);
select public.job_publish(current_setting('test.j1')::uuid);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select public.application_submit(
  current_setting('test.j1')::uuid,
  'Licensed electrician with twelve years experience and valid certification papers.',
  40000, 'NGN', 5);

select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select public.application_submit(
  current_setting('test.j1')::uuid,
  'Certified electrical contractor, weekend availability and warranty included.',
  45000);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.app_b', (select (a->>'id') from
  (select jsonb_array_elements(
     public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
   where a->>'professional_entity_id' = current_setting('test.b')), true);
select public.application_shortlist(current_setting('test.app_b')::uuid);

-- ─── 1. Authorization: anon ────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.quotation_propose('00000000-0000-0000-0000-000000000000'::uuid, 100) $$,
  '42501', null, 'anon cannot call quotation_propose');
select throws_ok($$ select public.quotation_withdraw('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call quotation_withdraw');
select throws_ok($$ select public.quotation_accept('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call quotation_accept');
select throws_ok($$ select public.hire_accept('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call hire_accept');
select throws_ok($$ select public.hire_get('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call hire_get');
select throws_ok($$ select public.hire_list_mine() $$,
  '42501', null, 'anon cannot call hire_list_mine');
select throws_ok($$ select public.hire_cancel('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call hire_cancel');
select throws_ok($$ select public.hire_complete('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call hire_complete');

-- ─── 2. Quotation validation (B is the applicant) ──────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.quotation_propose(current_setting('test.app_b')::uuid, 0) $$,
  'P0001', null, 'quotation with zero amount rejected (PLT003)');
select throws_ok($$ select public.quotation_propose(current_setting('test.app_b')::uuid, 100, 'XYZ') $$,
  'P0001', null, 'quotation with bad currency rejected (PLT003)');
select throws_ok($$ select public.quotation_propose('99999999-9999-9999-9999-999999999999'::uuid, 100) $$,
  'P0001', null, 'quotation on unknown application rejected (PLT004)');

-- A (owner, not applicant) cannot propose.
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.quotation_propose(current_setting('test.app_b')::uuid, 100) $$,
  'P0001', null, 'non-applicant propose rejected (PLT002)');

-- ─── 3. Revise chain + accept ──────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.quotation_propose(
  current_setting('test.app_b')::uuid, 38000, 'NGN', 4, 'Revised after site visit.') $$,
  'applicant can propose first quotation');
select lives_ok($$ select public.quotation_propose(
  current_setting('test.app_b')::uuid, 36000, 'NGN', 4, 'Final best price.') $$,
  'applicant can revise quotation');
select set_config('test.q2', (select q.id::text from public.job_quotations q
  where q.application_id = current_setting('test.app_b')::uuid and q.status = 'proposed'), true);
select is(
  (select revision_number::int from public.job_quotations
    where id = current_setting('test.q2')::uuid),
  2, 'revision chain increments to 2');
select is(
  (select count(*)::int from public.job_quotations
    where application_id = current_setting('test.app_b')::uuid and status = 'superseded'),
  1, 'first quotation superseded');

-- C proposes; A accepts C's quotation (pre-select, no hire yet).
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.app_c', (select (a->>'id') from
  (select jsonb_array_elements(
     public.application_list_for_job(current_setting('test.j1')::uuid)->'data'->'items') as a) s
   where a->>'professional_entity_id' = current_setting('test.c')), true);

select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select lives_ok($$ select public.quotation_propose(
  current_setting('test.app_c')::uuid, 44000, 'NGN', 6, 'All-inclusive with warranty.') $$,
  'applicant C can propose quotation');
select set_config('test.qc', (select id::text from public.job_quotations
  where application_id = current_setting('test.app_c')::uuid and status = 'proposed'), true);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.quotation_accept(current_setting('test.qc')::uuid) $$,
  'owner can accept live quotation');
select throws_ok($$ select public.quotation_accept(current_setting('test.qc')::uuid) $$,
  'P0001', null, 're-accept of quotation rejected (PLT005)');

-- B withdraws live quotation, then is hired on the application quote.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.quotation_withdraw(current_setting('test.q2')::uuid) $$,
  'applicant can withdraw live quotation');
select throws_ok($$ select public.quotation_withdraw(current_setting('test.q2')::uuid) $$,
  'P0001', null, 're-withdraw of quotation rejected (PLT005)');

-- ─── 4. hire_accept: full award ────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.hire_accept(current_setting('test.app_b')::uuid) $$,
  'owner can hire shortlisted application on application quote');
select set_config('test.hire1', (select (public.hire_list_mine('client')->'data'->'items'->0->>'id')), true);
select set_config('test.contract1', (select contract_id::text from public.hires
  where id = current_setting('test.hire1')::uuid), true);

select is(
  (select (public.job_get(current_setting('test.j1')::uuid)->'data'->'job'->>'status')),
  'awarded', 'J1 awarded after hire_accept');
select is(
  (select (public.hire_get(current_setting('test.hire1')::uuid)->'data'->>'effective_status')),
  'pending', 'hire effective status pending on offered contract');
select is(
  (select status from public.job_applications
    where id = current_setting('test.app_c')::uuid),
  'rejected', 'losing applications rejected on award');
select is(
  (select job_id::text from public.service_contracts
    where id = current_setting('test.contract1')::uuid),
  current_setting('test.j1'), 'linked contract is job-sourced');
select is(
  (select count(*)::int from public.service_contracts
    where id = current_setting('test.contract1')::uuid
      and service_listing_id is null),
  1, 'linked contract has no listing source');

select throws_ok($$ select public.hire_accept(current_setting('test.app_b')::uuid) $$,
  'P0001', null, 're-hire of awarded job rejected (PLT005)');

-- J2: non-shortlisted funnel + non-owner gates.
select set_config('test.j2', (select (public.job_create(
  'Service My Car Air Conditioner',
  'Car AC blows warm air and needs regassing plus leak check by a mobile technician in Lekki.',
  null, null, 15000, 30000)->'data'->>'id')), true);
select public.job_publish(current_setting('test.j2')::uuid);
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select public.application_submit(
  current_setting('test.j2')::uuid,
  'Mobile auto AC specialist with recovery machine and five years experience.',
  25000);
select set_config('test.app_c2', (select id::text from public.job_applications
  where job_id = current_setting('test.j2')::uuid
    and professional_entity_id = current_setting('test.c')::uuid), true);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.hire_accept(current_setting('test.app_c2')::uuid) $$,
  'P0001', null, 'hire of non-shortlisted application rejected (PLT005)');
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.hire_accept(current_setting('test.app_c2')::uuid) $$,
  'P0001', null, 'non-owner hire_accept rejected (PLT002)');

-- ─── 5. Hire reads: oracle + scopes ────────────────────────────────────────
select throws_ok($$ select public.hire_get('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'hire_get unknown id rejected (PLT004)');
select set_config('request.jwt.claim.sub', current_setting('test.d'), true);
select throws_ok($$ select public.hire_get(current_setting('test.hire1')::uuid) $$,
  'P0001', null, 'outsider hire_get rejected (PLT004)');

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.hire_list_mine('admin') $$,
  'P0001', null, 'hire_list_mine with bad role rejected (PLT003)');
select throws_ok($$ select public.hire_list_mine(null, 'bogus') $$,
  'P0001', null, 'hire_list_mine with bad status rejected (PLT003)');
select lives_ok($$ select public.hire_list_mine('client') $$,
  'client can list own hires');
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.hire_list_mine('professional') $$,
  'professional can list own hires');

-- ─── 6. hire_cancel reopens the funnel ─────────────────────────────────────
select lives_ok($$ select public.hire_cancel(current_setting('test.hire1')::uuid, 'Client rescheduling.') $$,
  'professional can cancel pending hire');
select is(
  (select (public.hire_get(current_setting('test.hire1')::uuid)->'data'->>'effective_status')),
  'cancelled', 'hire effective status cancelled after hire_cancel');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select (public.job_get(current_setting('test.j1')::uuid)->'data'->'job'->>'status')),
  'open', 'job reopened to open after hire_cancel');
select throws_ok($$ select public.hire_cancel(current_setting('test.hire1')::uuid) $$,
  'P0001', null, 're-cancel of hire rejected (PLT005)');

-- ─── 7. Re-hire -> contract accept -> milestone flow -> hire_complete ──────
select lives_ok($$ select public.hire_accept(current_setting('test.app_b')::uuid) $$,
  'owner can re-hire after cancel');
select set_config('test.hire2', (select h.id::text from public.hires h
  where h.job_id = current_setting('test.j1')::uuid and h.status <> 'cancelled'), true);
select set_config('test.contract2', (select contract_id::text from public.hires
  where id = current_setting('test.hire2')::uuid), true);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.contract2')::uuid) $$,
  'professional accepts linked offered contract');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.hire_complete(current_setting('test.hire2')::uuid) $$,
  'P0001', null, 'hire_complete with active contract rejected (PLT005)');

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.m1', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.contract2')::uuid), true);
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid) $$,
  'professional completes hire milestone');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid) $$,
  'client verifies hire milestone');
select lives_ok($$ select public.service_contract_close(current_setting('test.contract2')::uuid) $$,
  'client closes verified contract');
select lives_ok($$ select public.hire_complete(current_setting('test.hire2')::uuid) $$,
  'client completes hire on closed contract');
select is(
  (select (public.job_get(current_setting('test.j1')::uuid)->'data'->'job'->>'status')),
  'completed', 'job completed after hire_complete');

-- ─── 8. service_role reads ─────────────────────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.hire_get(current_setting('test.hire1')::uuid) $$, 'service_role hire_get');
select lives_ok($$ select public.hire_list_mine() $$, 'service_role hire_list_mine');

select * from finish();
rollback;
