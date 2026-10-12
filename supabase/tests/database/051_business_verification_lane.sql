-- Identity Phase 2a: business verification lane.
--
-- Validates business creation + membership, the business_document credential
-- kind, verification_submit coherence, approve propagation (business-only,
-- no KYC/trade cross-grant), representative authorization, the D5 guard,
-- and stranger isolation:
--   - 3 create+join + 1 stranger-isolation + 3 credential + 2 submit +
--   - 4 approve-propagation + 1 D5-guard + 3 reject-path + 4 diagnostics = 21.

begin;
set search_path to extensions, public;
select plan(21);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'b1b1b1b1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2b2b2b2-2222-4222-8222-222222222222', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'biz-creator@example.com'),
       (current_setting('test.b')::uuid, 'biz-stranger@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active')
on conflict (id) do nothing;

-- ─── 1. Create + join (A) ────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Deployment + identity diagnostics (regression tripwires for the RLS lane).
select is(
  auth.uid()::text,
  current_setting('test.a'),
  'jwt identity visible to policy evaluation'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'businesses'),
  5,
  'businesses RLS policies deployed'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'business_memberships'),
  5,
  'memberships RLS policies deployed'
);

select is(
  (select with_check from pg_policies
    where schemaname = 'public'
      and tablename = 'businesses'
      and policyname = 'businesses_authenticated_insert'),
  '((created_by IS NULL) OR (created_by = auth.uid()))',
  'deployed insert policy matches the migration text'
);
-- Data-modifying statements cannot nest in a scalar subquery: insert first
-- (with explicit created_by so the RLS WITH CHECK never depends on NULL
-- semantics), then capture the id with a select-back on the unique CAC.
-- No ON CONFLICT: every CI run migrates a fresh database, and the arbiter
-- interacts poorly with RLS speculative insertion.
insert into public.businesses
  (trading_name, registered_legal_name, cac_number, created_by)
values ('Amara Foods', 'Amara Foods Ltd', 'CAC-BIZ-001',
  current_setting('test.a')::uuid);
select set_config('test.biz', (select id::text from public.businesses
  where cac_number = 'CAC-BIZ-001'), true);
select ok(
  current_setting('test.biz') is not null,
  'creator inserts a business row (PLT000 path)'
);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'pending',
  'new business starts pending'
);
select lives_ok(
  $$ insert into public.business_memberships (business_id, entity_id, role)
     values (current_setting('test.biz')::uuid, auth.uid(), 'representative') $$,
  'creator joins own business as representative'
);

-- ─── 2. Stranger isolation (B) ───────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select is(
  (select count(*)::int from public.businesses),
  0,
  'stranger selects zero businesses (member-scoped RLS)'
);

-- ─── 3. CAC credential (A) ───────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select set_config('test.cred', (select (public.entity_credentials_submit(
  'business_document', 'CAC certificate Amara Foods',
  null, null, null,
  current_setting('test.biz')::uuid
)->'data'->>'id')), true);
select ok(
  current_setting('test.cred') is not null,
  'member submits a CAC business_document credential (PLT000)'
);
select throws_ok(
  $$ select public.entity_credentials_submit('business_document', 'Orphan CAC doc') $$,
  'P0001', 'PLT003: Business id is required for business documents.',
  'business document without a business rejected (PLT003)'
);
select throws_ok(
  $$ select public.entity_credentials_submit(
    'identity_document', 'National ID', null, null, null,
    current_setting('test.biz')::uuid) $$,
  'P0001', 'PLT003: Business link applies to business documents only.',
  'business link on a non-business kind rejected (PLT003)'
);

-- ─── 4. Submit to the business lane (A) ──────────────────────────────────────
select lives_ok(
  $$ select public.verification_submit(current_setting('test.cred')::uuid) $$,
  'business document queues to business_verification by kind default (PLT000)'
);
select is(
  (select submission_type from public.verification_submissions
    where credential_id = current_setting('test.cred')::uuid),
  'business_verification',
  'submission resolves to the business lane'
);

-- ─── 5. Approve flips business only (service_role) ───────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

select lives_ok(
  $$ select public.verification_review_approve(
    (select id from public.verification_submissions
      where credential_id = current_setting('test.cred')::uuid),
    'CAC verified against registry extract') $$,
  'service_role approves the business submission (PLT000)'
);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'approved',
  'business flips to approved'
);
select is(
  (select is_authorized from public.business_memberships
    where business_id = current_setting('test.biz')::uuid
      and entity_id = current_setting('test.a')::uuid),
  true,
  'submitting representative authorized on approval'
);
select is(
  (select count(*)::int from public.entity_kyc_levels
    where entity_id = current_setting('test.a')::uuid),
  0,
  'business approval assigns no personal KYC tier (no cross-grant)'
);

-- ─── 6. D5 guard blocks direct status writes (A) ─────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ update public.businesses set verification_status = 'rejected'
     where id = current_setting('test.biz')::uuid $$,
  'P0001', 'PLT002: Business verification state may only be changed through the verification review RPCs.',
  'D5 guard blocks direct verification_status update'
);

-- ─── 7. Reject path propagates nothing ───────────────────────────────────────
select set_config('test.cred2', (select (public.entity_credentials_submit(
  'business_document', 'Tax clearance Amara Foods',
  null, null, null,
  current_setting('test.biz')::uuid
)->'data'->>'id')), true);
select lives_ok(
  $$ select public.verification_submit(
    current_setting('test.cred2')::uuid, 'business_verification') $$,
  'second business document queues with explicit lane type (PLT000)'
);
set role service_role;
select lives_ok(
  $$ select public.verification_review_reject(
    (select id from public.verification_submissions
      where credential_id = current_setting('test.cred2')::uuid),
    'Unverifiable scan', false) $$,
  'service_role rejects the second submission (PLT000)'
);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'approved',
  'rejection leaves the approved business untouched'
);

select * from finish();
rollback;
