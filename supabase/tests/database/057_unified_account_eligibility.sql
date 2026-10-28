-- Unified account eligibility + business lifecycle.
--
-- Covers the end-to-end gates introduced for the single account:
--   - an unverified professional cannot apply or publish (identity gate);
--   - identity verification unlocks apply/publish when trade approval exists;
--   - business creation is atomic and starts pending;
--   - business evidence stays under review (no duplicate queueing, including
--     across members of the same business);
--   - business identity freezes while under review/approved and reopens after
--     rejection;
--   - an admin rejection cascades, resubmission works, and approval authorizes
--     the representative;
--   - the unified projection exposes business status and eligibility.

begin;
set search_path to extensions, public;
select plan(35);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'd1d1d1d1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'd2d2d2d2-2222-4222-8222-222222222222', true);
select set_config('test.admin', 'd3d3d3d3-3333-4333-8333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'unified-client@example.com'),
       (current_setting('test.b')::uuid, 'unified-pro@example.com'),
       (current_setting('test.admin')::uuid, 'unified-admin@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.admin')::uuid, 'active')
on conflict (id) do nothing;

select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id = current_setting('test.a')::uuid;
update public.entities set capability = 'offer'
 where id = current_setting('test.b')::uuid;
select set_config('platform.rpc_invocation', '', true);

insert into public.platform_admins (user_id, granted_by, notes)
values (current_setting('test.admin')::uuid, null, 'unified account test admin')
on conflict (user_id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name)
values (current_setting('test.a')::uuid, 'Amara Diallo', 'Amara Diallo'),
       (current_setting('test.b')::uuid, 'Bola Professional', 'Bola Professional')
on conflict (entity_id) do update set display_name = excluded.display_name;

insert into public.kyc_tiers (tier_code, name, cashout_limit)
values ('tier_1', 'Tier 1', 100000)
on conflict (tier_code) do update
  set name = excluded.name, cashout_limit = excluded.cashout_limit;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-4000-8000-0000000000b1', 'unified-trade', 'Unified Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values (
  'ffffffff-0000-4000-8000-0000000000b2',
  'ffffffff-0000-4000-8000-0000000000b1',
  'unified-fixer', 'Unified Fixer', true
) on conflict (id) do nothing;

-- B is trade-approved but still identity-unverified until section 2.
insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values (
  current_setting('test.b')::uuid,
  'ffffffff-0000-4000-8000-0000000000b2',
  true,
  'approved'
) on conflict (entity_id, profession_id) do update
  set is_primary = true, trade_verification_status = 'approved';

-- A publishes an untyped personal job; B will attempt to apply.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.job', (select public.job_create(
  'Unified account untyped job',
  'A sufficiently detailed job description for the unified account test fixture.',
  null, null, 1000, 2000, 'NGN', 'Lagos', null
)->'data'->>'id'), true);
select public.job_publish(current_setting('test.job')::uuid);

-- B creates a draft service before identity verification.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.listing', (select public.service_listing_create(
  'ffffffff-0000-4000-8000-0000000000b2',
  'Unified account draft service',
  'A sufficiently detailed service description for the unified account test fixture.',
  'fixed', 5000, null, 'NGN', 'draft'
)->'data'->>'id'), true);

-- ─── 1. Unverified identity is denied across restricted actions ──────────────
select is(
  public.verification_status_get()->'data'->>'identity_verified',
  'false',
  'unverified professional reports identity_verified=false'
);
select throws_ok(
  $$ select public.application_submit(
    current_setting('test.job')::uuid,
    'I can complete this job professionally and on time.',
    null, 'NGN', null) $$,
  'P0001', 'PLT005: Identity verification required before applying.',
  'unverified identity cannot apply to an open job'
);
select throws_ok(
  $$ select public.service_listing_publish(current_setting('test.listing')::uuid) $$,
  'P0001', 'PLT005: Identity verification required to publish services.',
  'unverified identity cannot publish a draft listing'
);
select throws_ok(
  $$ select public.service_listing_create(
    'ffffffff-0000-4000-8000-0000000000b2',
    'Unified account published service',
    'A sufficiently detailed service description for the unified account test fixture.',
    'fixed', 5000, null, 'NGN', 'published') $$,
  'P0001', 'PLT005: Identity verification required to publish services.',
  'unverified identity cannot create a published listing'
);

-- ─── 2. Identity verification unlocks the same actions ───────────────────────
set role postgres;
insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.b')::uuid, 'tier_1', 'active')
on conflict (entity_id) do update
  set tier_code = excluded.tier_code, status = excluded.status;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  public.verification_status_get()->'data'->>'identity_verified',
  'true',
  'admin-verified identity projects identity_verified=true'
);
select lives_ok(
  $$ select public.application_submit(
    current_setting('test.job')::uuid,
    'I can complete this job professionally and on time.',
    null, 'NGN', null) $$,
  'verified identity applies to an untyped job'
);
select lives_ok(
  $$ select public.service_listing_publish(current_setting('test.listing')::uuid) $$,
  'verified identity publishes the draft listing'
);
select lives_ok(
  $$ select public.service_listing_create(
    'ffffffff-0000-4000-8000-0000000000b2',
    'Unified account published service',
    'A sufficiently detailed service description for the unified account test fixture.',
    'fixed', 5000, null, 'NGN', 'published') $$,
  'verified identity creates an initially published listing'
);

-- ─── 3. Atomic business creation + pending review lifecycle ──────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select set_config('test.biz', (select public.business_create(
  'Amara Foods', 'Amara Foods Ltd', 'CAC-UNIFIED-001'
)->'data'->>'business_id'), true);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'pending',
  'business_create starts the business pending'
);
select is(
  (select role from public.business_memberships
    where business_id = current_setting('test.biz')::uuid
      and entity_id = current_setting('test.a')::uuid),
  'representative',
  'business_create atomically inserts the representative membership'
);

select set_config('test.cred1', (select (public.entity_credentials_submit(
  'business_document', 'CAC certificate Amara Foods',
  null, null, null,
  current_setting('test.biz')::uuid
)->'data'->>'id')), true);
select lives_ok(
  $$ select public.verification_submit(
    current_setting('test.cred1')::uuid, 'business_verification') $$,
  'pending business queues its first business submission'
);
select throws_ok(
  $$ select public.verification_submit(
    current_setting('test.cred1')::uuid, 'business_verification') $$,
  'P0001', 'PLT005: A business verification submission is already under review.',
  'duplicate business submission is blocked while under review'
);

-- A second member cannot queue another lane for the same business, even with
-- a different credential. The check must see rows the caller cannot SELECT.
set role postgres;
insert into public.business_memberships (business_id, entity_id, role)
values (
  current_setting('test.biz')::uuid,
  current_setting('test.b')::uuid,
  'representative'
) on conflict (business_id, entity_id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.cred_b', (select (public.entity_credentials_submit(
  'business_document', 'CAC certificate second member',
  null, null, null,
  current_setting('test.biz')::uuid
)->'data'->>'id')), true);
select throws_ok(
  $$ select public.verification_submit(
    current_setting('test.cred_b')::uuid, 'business_verification') $$,
  'P0001', 'PLT005: A business verification submission is already under review.',
  'another business member cannot duplicate the active business lane'
);

set role postgres;
delete from public.entity_credentials
 where id = current_setting('test.cred_b')::uuid;
delete from public.business_memberships
 where business_id = current_setting('test.biz')::uuid
   and entity_id = current_setting('test.b')::uuid;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  public.business_has_active_verification(current_setting('test.biz')::uuid),
  false,
  'non-members cannot probe the active business lane'
);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok(
  $$ update public.businesses set trading_name = 'Amara Foods Changed'
     where id = current_setting('test.biz')::uuid $$,
  'P0001',
  'PLT002: Business identity fields cannot be changed after submission. Contact support if the registered details are wrong.',
  'business identity is frozen while under review'
);

-- ─── 4. Rejection, resubmission, approval ────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.admin'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.verification_review_reject(
    (select id from public.verification_submissions
      where credential_id = current_setting('test.cred1')::uuid),
    'Registry name mismatch', false) $$,
  'admin rejects the pending business submission'
);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'rejected',
  'business rejection cascades to a pending business'
);
select lives_ok(
  $$ update public.businesses
       set trading_name = 'Amara Foods & Co',
           registered_legal_name = 'Amara Foods and Company Ltd'
     where id = current_setting('test.biz')::uuid $$,
  'business identity is editable after rejection'
);

select set_config('test.cred2', (select (public.entity_credentials_submit(
  'business_document', 'CAC certificate Amara Foods corrected',
  null, null, null,
  current_setting('test.biz')::uuid
)->'data'->>'id')), true);
select lives_ok(
  $$ select public.verification_submit(
    current_setting('test.cred2')::uuid, 'business_verification') $$,
  'rejected business can resubmit corrected evidence'
);
select throws_ok(
  $$ update public.businesses set trading_name = 'Blocked While Pending'
     where id = current_setting('test.biz')::uuid $$,
  'P0001',
  'PLT002: Business identity fields cannot be changed after submission. Contact support if the registered details are wrong.',
  'resubmitted business identity is frozen again'
);
select is(
  public.verification_status_get()->'data'->'businesses'->0->'latest_submission'->>'status',
  'pending',
  'projection prefers the fresh pending lane over the prior rejection'
);

select set_config('request.jwt.claim.sub', current_setting('test.admin'), true);
select lives_ok(
  $$ select public.verification_review_approve(
    (select id from public.verification_submissions
      where credential_id = current_setting('test.cred2')::uuid),
    'Registry extract verified') $$,
  'admin approves the corrected business submission'
);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select verification_status from public.businesses
    where id = current_setting('test.biz')::uuid),
  'approved',
  'business approval cascades'
);
select is(
  (select is_authorized from public.business_memberships
    where business_id = current_setting('test.biz')::uuid
      and entity_id = current_setting('test.a')::uuid),
  true,
  'approval authorizes the representative through the admin RPC grant'
);
select is(
  (select count(*)::int from public.entity_kyc_levels
    where entity_id = current_setting('test.a')::uuid),
  0,
  'business approval does not cross-grant personal KYC'
);
select throws_ok(
  $$ update public.businesses set trading_name = 'Blocked After Approval'
     where id = current_setting('test.biz')::uuid $$,
  'P0001',
  'PLT002: Business identity fields cannot be changed after submission. Contact support if the registered details are wrong.',
  'approved business identity stays frozen'
);

-- ─── 5. Unified projection + business hiring ─────────────────────────────────
select is(
  public.verification_status_get()->'data'->'businesses'->0->>'verification_status',
  'approved',
  'projection exposes the approved business lane'
);
select is(
  public.verification_status_get()->'data'->'eligibility'->'business_eligibility'->0->>'can_hire',
  'true',
  'projection reports business hiring eligibility'
);
select is(
  public.verification_status_get()->'data'->'businesses'->0->'latest_submission'->>'decision_notes',
  'Registry extract verified',
  'projection carries the latest business decision notes'
);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  jsonb_array_length(public.verification_status_get()->'data'->'businesses'),
  0,
  'non-members see no business lane (RLS)'
);

-- ─── 6. Admin queue: business filter + additive metadata ─────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.admin'), true);
select is(
  public.verification_review_queue_get(
    'approved', 0, 20, 'business_verification'
  )->'data'->>'total_count',
  '1',
  'admin queue filters by business_verification'
);
select is(
  public.verification_review_queue_get(
    'approved', 0, 20, 'business_verification'
  )->'data'->'submissions'->0->>'business_trading_name',
  'Amara Foods & Co',
  'admin queue carries the business trading name'
);
select is(
  public.verification_review_queue_get(
    'approved', 0, 20, 'business_verification'
  )->'data'->'submissions'->0->>'business_cac_number',
  'CAC-UNIFIED-001',
  'admin queue carries the CAC number'
);
select is(
  public.verification_review_queue_get(
    'approved', 0, 20, 'business_verification'
  )->'data'->'submissions'->0->>'business_verification_status',
  'approved',
  'admin queue carries the business verification status'
);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.bizjob', (select public.job_create(
  'Business-linked job after approval',
  'A sufficiently detailed job description for the approved business hiring fixture.',
  'ffffffff-0000-4000-8000-0000000000b2', null, 5000, 20000, 'NGN', 'Lagos',
  current_setting('test.biz')::uuid
)->'data'->>'id'), true);
select is(
  (select business_id::text from public.jobs
    where id = current_setting('test.bizjob')::uuid),
  current_setting('test.biz'),
  'approved business can create a business-linked job'
);

select * from finish();
rollback;
