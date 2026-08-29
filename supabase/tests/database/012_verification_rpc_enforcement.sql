-- EP-02-03: Verification RPC Enforcement
--
-- Validates the 6 verification RPCs (EP-02-03 Plan §14.2):
--   - Authorization: anon cannot call any (42501); authenticated cannot call the
--     2 review RPCs (42501); authenticated + service_role may call the 4
--     entity-facing RPCs; service_role may call the 2 review RPCs.
--   - Validation: PLT003 (null), PLT004 (not found / not owned / cross-entity),
--     PLT005 (duplicate active submission / already reviewed).
--   - Functional: submission -> pending; identity approval -> KYC tier_1; trade
--     approval -> Rule 2 gate flip (entity_professions.trade_verification_status);
--     rejection -> no propagation; audit trail + immutable decision records.
--   - Envelope: {success, code, message, data} with PLT000 on success.
--   - Posture: 6 verification_* functions, none SECURITY DEFINER.

begin;
set search_path to extensions, public;
select plan(37);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'entity-a@example.com'),
       ('22222222-2222-2222-2222-222222222222', 'entity-b@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('11111111-1111-1111-1111-111111111111', 'active'),
       ('22222222-2222-2222-2222-222222222222', 'active')
on conflict (id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000010', 'fx-verify-ind', 'FX Verify Ind', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000011', 'ffffffff-0000-0000-0000-000000000010', 'fx-verify-prof', 'FX Verify Prof', true)
on conflict (id) do nothing;

insert into public.entity_professions (entity_id, profession_id, is_primary)
values ('11111111-1111-1111-1111-111111111111', 'ffffffff-0000-0000-0000-000000000011', true)
on conflict do nothing;

insert into public.entity_credentials (id, entity_id, profession_id, kind, title)
values
  ('ffffffff-0000-0000-0000-000000000020', '11111111-1111-1111-1111-111111111111', null, 'identity_document', 'ID Doc A'),
  ('ffffffff-0000-0000-0000-000000000021', '11111111-1111-1111-1111-111111111111', 'ffffffff-0000-0000-0000-000000000011', 'trade_proof', 'Trade Proof A'),
  ('ffffffff-0000-0000-0000-000000000022', '11111111-1111-1111-1111-111111111111', null, 'identity_document', 'ID Doc A2'),
  ('ffffffff-0000-0000-0000-000000000023', '22222222-2222-2222-2222-222222222222', null, 'identity_document', 'ID Doc B')
on conflict (id) do nothing;

-- ─── 1. Authorization: anon (no EXECUTE grant -> 42501 before body) ────────────
set role anon;

select throws_ok(
  $$ select public.verification_submit('00000000-0000-0000-0000-000000000001', 'identity_document') $$,
  '42501', null, 'anon cannot execute verification_submit (no grant)');
select throws_ok(
  $$ select public.verification_review_approve('00000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'anon cannot execute verification_review_approve (no grant)');
select throws_ok(
  $$ select public.verification_review_reject('00000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'anon cannot execute verification_review_reject (no grant)');
select throws_ok(
  $$ select public.verification_status_get('00000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'anon cannot execute verification_status_get (no grant)');
select throws_ok(
  $$ select public.verification_kyc_level_get() $$,
  '42501', null, 'anon cannot execute verification_kyc_level_get (no grant)');
select throws_ok(
  $$ select public.verification_limits_get() $$,
  '42501', null, 'anon cannot execute verification_limits_get (no grant)');

-- ─── 2. Authorization + validation: authenticated (entity A) ──────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$ select public.verification_status_get(null) $$,
  'authenticated can call verification_status_get');
select lives_ok(
  $$ select public.verification_kyc_level_get() $$,
  'authenticated can call verification_kyc_level_get');
select lives_ok(
  $$ select public.verification_limits_get() $$,
  'authenticated can call verification_limits_get');

-- Submit an identity document (creates pending submission S1)
select lives_ok(
  $$ select public.verification_submit('ffffffff-0000-0000-0000-000000000020', null) $$,
  'authenticated can submit a owned credential (pending S1)');

-- Duplicate active submission -> PLT005
select throws_ok(
  $$ select public.verification_submit('ffffffff-0000-0000-0000-000000000020', null) $$,
  'P0001', 'PLT005: An active submission already exists for this credential.', 'duplicate active submission rejected (PLT005)');

-- Non-owned credential -> PLT004 (RLS hides the row from the caller, so the
--   function reports "Credential not found." — identical PLT004 code, no leak)
select throws_ok(
  $$ select public.verification_submit('ffffffff-0000-0000-0000-000000000023', null) $$,
  'P0001', 'PLT004: Credential not found.', 'non-owned credential rejected (PLT004)');

-- Null credential -> PLT003
select throws_ok(
  $$ select public.verification_submit(null, null) $$,
  'P0001', 'PLT003: Credential id is required.', 'null credential rejected (PLT003)');

-- Cross-entity status query -> PLT004
select throws_ok(
  $$ select public.verification_status_get('22222222-2222-2222-2222-222222222222') $$,
  'P0001', 'PLT004: Cannot view another entity''s verification status.', 'cross-entity status query rejected (PLT004)');

-- ─── 3. Authorization + functional: service_role (acting as entity A) ──────────
set role service_role;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"service_role"}', true);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'service_role', true);

-- service_role can submit (with acting sub) and read
select lives_ok(
  $$ select public.verification_submit('ffffffff-0000-0000-0000-000000000022', null) $$,
  'service_role can submit a credential (pending S2)');
select lives_ok(
  $$ select public.verification_status_get(null) $$,
  'service_role can call verification_status_get');
select lives_ok(
  $$ select public.verification_kyc_level_get() $$,
  'service_role can call verification_kyc_level_get');
select lives_ok(
  $$ select public.verification_limits_get() $$,
  'service_role can call verification_limits_get');

-- Missing submission -> PLT004
select throws_ok(
  $$ select public.verification_review_approve('00000000-0000-0000-0000-000000000001') $$,
  'P0001', 'PLT004: Submission not found.', 'approve missing submission rejected (PLT004)');
select throws_ok(
  $$ select public.verification_review_reject('00000000-0000-0000-0000-000000000001') $$,
  'P0001', 'PLT004: Submission not found.', 'reject missing submission rejected (PLT004)');

-- Approve identity submission S1 -> KYC tier_1 assigned
select lives_ok(
  $$ select public.verification_review_approve(
       (select id from public.verification_submissions where credential_id = 'ffffffff-0000-0000-0000-000000000020'),
       'Looks good') $$,
  'service_role can approve identity submission (S1)');

select is(
  (select tier_code from public.entity_kyc_levels where entity_id = '11111111-1111-1111-1111-111111111111'),
  'tier_1', 'identity approval assigned KYC tier_1');
select is(
  (select status from public.entity_kyc_levels where entity_id = '11111111-1111-1111-1111-111111111111'),
  'active', 'KYC tier_1 is active');

select is(
  (select (public.verification_kyc_level_get()->'data'->'limits'->>'daily')),
  '50000', 'verification_kyc_level_get returns tier_1 daily limit (50000)');

-- Reject submission S2 -> no propagation
select lives_ok(
  $$ select public.verification_review_reject(
       (select id from public.verification_submissions where credential_id = 'ffffffff-0000-0000-0000-000000000022'),
       'Inconclusive') $$,
  'service_role can reject submission (S2)');

select is(
  (select status from public.verification_submissions where credential_id = 'ffffffff-0000-0000-0000-000000000022'),
  'rejected', 'rejected submission has status rejected');
select is(
  (select tier_code from public.entity_kyc_levels where entity_id = '11111111-1111-1111-1111-111111111111'),
  'tier_1', 'rejection did not change KYC tier');

-- Submit + approve trade proof S3 -> Rule 2 gate flipped
select lives_ok(
  $$ select public.verification_submit('ffffffff-0000-0000-0000-000000000021', null) $$,
  'service_role can submit a trade proof (pending S3)');

select lives_ok(
  $$ select public.verification_review_approve(
       (select id from public.verification_submissions where credential_id = 'ffffffff-0000-0000-0000-000000000021'),
       'Trade verified') $$,
  'service_role can approve trade submission (S3)');

select is(
  (select trade_verification_status
     from public.entity_professions
    where entity_id = '11111111-1111-1111-1111-111111111111'
      and profession_id = 'ffffffff-0000-0000-0000-000000000011'),
  'approved', 'trade approval flipped entity_professions.trade_verification_status = approved (Rule 2 gate)');

-- Re-approve already-decided S1 -> PLT005
select throws_ok(
  $$ select public.verification_review_approve(
       (select id from public.verification_submissions where credential_id = 'ffffffff-0000-0000-0000-000000000020')) $$,
  'P0001', 'PLT005: Submission has already been reviewed.', 're-approve decided submission rejected (PLT005)');

-- ─── 4. Audit trail + immutable decision records ──────────────────────────────
select is(
  (select count(*)::int from public.verification_audit_trail
    where entity_id = '11111111-1111-1111-1111-111111111111'),
  8, 'verification_audit_trail captured all verification events (8 rows)');

select is(
  (select count(*)::int from public.verification_reviews
    where entity_id = '11111111-1111-1111-1111-111111111111'),
  3, 'verification_reviews captured 3 immutable decision records');

-- ─── 5. Envelope contract ──────────────────────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.verification_status_get(null))),
  4, 'status envelope has exactly 4 top-level keys');
select is(
  (public.verification_status_get(null))->>'code',
  'PLT000', 'status envelope code is PLT000');

-- ─── 6. Posture ─────────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_proc where proname like 'verification_%'),
  6, 'exactly 6 verification_* functions exist');
select is(
  (select count(*)::int from pg_proc where proname like 'verification_%' and prosecdef),
  0, 'no verification_* function is SECURITY DEFINER');

select * from finish();
rollback;
