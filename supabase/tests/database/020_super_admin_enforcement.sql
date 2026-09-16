-- EP-02-11: Super Admin enforcement
--
-- Validates the super-admin platform (EP-02-11 §):
--   - platform_admins registry + is_platform_admin() helper
--   - D5 guard triggers block direct PostgREST writes to verification columns
--   - Admin RLS policies gate cross-entity reads/writes
--   - RPC authorization: only active admins can review/audit/provision
--   - Envelope contract: {success, code, message, data} with PLT000 on success.
--
-- NOTE on error assertions: platform_raise_error raises with SQLSTATE P0001 and
-- message format "PLT002: <message>". throws_ok is called with the SQLSTATE in
-- arg 2 and a message regex in arg 3 (matching the technique in test 007/012).

begin;
set search_path to extensions, public;
select plan(49);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'nonadmin@test.local'),
       ('22222222-2222-2222-2222-222222222222', 'admin@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('11111111-1111-1111-1111-111111111111', 'active'),
       ('22222222-2222-2222-2222-222222222222', 'active')
on conflict (id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000040', 'fx-super-admin-ind', 'FX Super Admin Ind', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000041', 'ffffffff-0000-0000-0000-000000000040', 'fx-super-admin-prof', 'FX Super Admin Prof', true)
on conflict (id) do nothing;

-- Admin identity (2222...) with a profession binding used by the guard tests
insert into public.platform_admins (user_id, granted_by, notes)
values ('22222222-2222-2222-2222-222222222222', null, 'Test admin')
on conflict (user_id) do nothing;

insert into public.entity_professions (entity_id, profession_id, is_primary)
values ('22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000041', true)
on conflict do nothing;

insert into public.entity_credentials (id, entity_id, profession_id, kind, title)
values
  ('ffffffff-0000-0000-0000-000000000050', '22222222-2222-2222-2222-222222222222', null, 'identity_document', 'Admin ID Doc'),
  ('ffffffff-0000-0000-0000-000000000051', '22222222-2222-2222-2222-222222222222', null, 'identity_document', 'Admin ID Doc 2'),
  ('ffffffff-0000-0000-0000-000000000052', '22222222-2222-2222-2222-222222222222', null, 'certification',  'Admin Cert'),
  ('ffffffff-0000-0000-0000-000000000053', '11111111-1111-1111-1111-111111111111', null, 'identity_document', 'Non-Admin ID Doc')
on conflict (id) do nothing;

insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status)
values
  ('ffffffff-0000-0000-0000-000000000060', '22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000050', 'identity_document', 'pending'),
  ('ffffffff-0000-0000-0000-000000000061', '22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000051', 'identity_document', 'pending'),
  ('ffffffff-0000-0000-0000-000000000062', '22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000052', 'certification',  'pending'),
  ('ffffffff-0000-0000-0000-000000000063', '11111111-1111-1111-1111-111111111111', 'ffffffff-0000-0000-0000-000000000053', 'identity_document', 'pending')
on conflict (id) do nothing;

-- ─── 1. platform_admins table exists and has expected columns ────────────────
select has_table('public', 'platform_admins', 'platform_admins table exists');

select has_column('public', 'platform_admins', 'id', 'platform_admins has id column');
select has_column('public', 'platform_admins', 'user_id', 'platform_admins has user_id column');
select has_column('public', 'platform_admins', 'granted_by', 'platform_admins has granted_by column');
select has_column('public', 'platform_admins', 'notes', 'platform_admins has notes column');
select has_column('public', 'platform_admins', 'granted_at', 'platform_admins has granted_at column');

-- Unique constraint on user_id
select results_eq(
  $$ select count(*)::bigint from pg_constraint where conrelid = 'public.platform_admins'::regclass and contype = 'u' $$,
  $$ values (1::bigint) $$,
  'platform_admins has unique constraint on user_id'
);

-- ─── 2. is_platform_admin() function ─────────────────────────────────────────
select has_function('public', 'is_platform_admin', 'is_platform_admin function exists');

select is(
  public.is_platform_admin('22222222-2222-2222-2222-222222222222'),
  true,
  'is_platform_admin returns true for admin user'
);

select is(
  public.is_platform_admin('11111111-1111-1111-1111-111111111111'),
  false,
  'is_platform_admin returns false for non-admin user'
);

select is(
  public.is_platform_admin(null),
  false,
  'is_platform_admin returns false for null input'
);

-- ─── 3. D5 guard triggers exist ──────────────────────────────────────────────
select ok(
  exists(select 1 from pg_trigger where tgname = 'entity_professions_guard_verification_state_update'),
  'entity_professions D5 guard trigger exists'
);

select ok(
  exists(select 1 from pg_trigger where tgname = 'verification_submissions_guard_review_state_update'),
  'verification_submissions D5 guard trigger exists'
);

select ok(
  exists(
    select 1 from pg_trigger
     where tgname in ('entity_kyc_levels_guard_state_insert', 'entity_kyc_levels_guard_state_update')
  ),
  'entity_kyc_levels D5 guard trigger exists'
);

-- ─── 4. D5 guard trigger enforcement: blocks direct PostgREST writes ─────────
-- Even an admin cannot mutate the guarded columns directly: the guard fires
-- unless platform.rpc_invocation = 'on' (set only by the review RPCs).
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ update public.entity_professions
       set trade_verification_status = 'approved',
           verified_at = now(),
           verified_by = '22222222-2222-2222-2222-222222222222'
     where entity_id = '22222222-2222-2222-2222-222222222222'
       and profession_id = 'ffffffff-0000-0000-0000-000000000041' $$,
  'P0001', 'PLT002: Trade verification state may only be changed through the verification review RPCs.',
  'D5 guard blocks direct trade_verification_status update'
);

select throws_ok(
  $$ update public.verification_submissions
       set status = 'approved',
           reviewed_at = now(),
           reviewed_by = '22222222-2222-2222-2222-222222222222'
     where id = 'ffffffff-0000-0000-0000-000000000060' $$,
  'P0001', 'PLT002: Submission review state may only be changed through the verification review RPCs.',
  'D5 guard blocks direct verification_submissions status update'
);

-- ─── 5. RPC authorization: platform_admin_check ──────────────────────────────
select has_function('public', 'platform_admin_check', 'platform_admin_check function exists');

-- Admin user: success with is_admin true
select is(
  (public.platform_admin_check() ->> 'success')::boolean,
  true,
  'platform_admin_check returns success for admin'
);

select is(
  public.platform_admin_check() -> 'data' ->> 'is_admin',
  'true',
  'platform_admin_check reports is_admin true for admin'
);

-- Non-admin user: success with is_admin false (not an exception)
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is(
  public.platform_admin_check() -> 'data' ->> 'is_admin',
  'false',
  'platform_admin_check reports is_admin false for non-admin'
);

-- Anon: no EXECUTE grant -> 42501 before the body runs
set role anon;
select throws_ok(
  $$ select public.platform_admin_check() $$,
  '42501', null, 'anon cannot execute platform_admin_check (no grant)'
);

-- ─── 6. RPC authorization: verification_review_approve ───────────────────────
select has_function('public', 'verification_review_approve', 'verification_review_approve function exists');

-- Non-admin cannot approve
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ select public.verification_review_approve('ffffffff-0000-0000-0000-000000000063', 'Should fail') $$,
  'P0001', 'PLT002: Admin access required.',
  'verification_review_approve raises PLT002 for non-admin'
);

-- Admin can approve a pending identity submission -> KYC tier_1 assigned
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is(
  (public.verification_review_approve(
    'ffffffff-0000-0000-0000-000000000060',
    'Approved by test'
  ) ->> 'success')::boolean,
  true,
  'verification_review_approve succeeds for admin'
);

select is(
  (select tier_code from public.entity_kyc_levels
    where entity_id = '22222222-2222-2222-2222-222222222222'),
  'tier_1',
  'identity approval assigned KYC tier_1'
);

-- ─── 7. RPC authorization: verification_review_reject ────────────────────────
select has_function('public', 'verification_review_reject', 'verification_review_reject function exists');

select is(
  (public.verification_review_reject(
    'ffffffff-0000-0000-0000-000000000061',
    'Rejected by test',
    true
  ) ->> 'success')::boolean,
  true,
  'verification_review_reject succeeds for admin'
);

select is(
  (select status from public.verification_submissions
    where id = 'ffffffff-0000-0000-0000-000000000061'),
  'requires_resubmission',
  'reject with resubmission flag yields requires_resubmission'
);

select is(
  (public.verification_review_reject(
    'ffffffff-0000-0000-0000-000000000063',
    'Rejected by test',
    false
  ) ->> 'success')::boolean,
  true,
  'verification_review_reject (hard reject) succeeds for admin'
);

select is(
  (select status from public.verification_submissions
    where id = 'ffffffff-0000-0000-0000-000000000063'),
  'rejected',
  'reject without resubmission flag yields rejected'
);

-- ─── 8. verification_review_queue_get ────────────────────────────────────────
select has_function('public', 'verification_review_queue_get', 'verification_review_queue_get function exists');

select ok(
  (public.verification_review_queue_get(null, 10, 0) ->> 'success')::boolean,
  'verification_review_queue_get returns success for admin'
);

-- Non-admin denied
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_queue_get(null, 10, 0) $$,
  'P0001', 'PLT002: Admin access required.',
  'verification_review_queue_get raises PLT002 for non-admin'
);

-- ─── 9. verification_review_start ────────────────────────────────────────────
select has_function('public', 'verification_review_start', 'verification_review_start function exists');

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select ok(
  (public.verification_review_start('ffffffff-0000-0000-0000-000000000062') ->> 'success')::boolean,
  'verification_review_start succeeds for admin'
);

select is(
  (select status from public.verification_submissions
    where id = 'ffffffff-0000-0000-0000-000000000062'),
  'in_review',
  'verification_review_start claimed the submission (status in_review)'
);

-- ─── 10. verification_review_audit_get ───────────────────────────────────────
select has_function('public', 'verification_review_audit_get', 'verification_review_audit_get function exists');

select ok(
  (public.verification_review_audit_get('ffffffff-0000-0000-0000-000000000060') ->> 'success')::boolean,
  'verification_review_audit_get returns success for admin'
);

-- Non-admin denied
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_audit_get('ffffffff-0000-0000-0000-000000000060') $$,
  'P0001', 'PLT002: Admin access required.',
  'verification_review_audit_get raises PLT002 for non-admin'
);

-- ─── 11. platform_admin_provision / revoke / list ────────────────────────────
select has_function('public', 'platform_admin_provision', 'platform_admin_provision function exists');
select has_function('public', 'platform_admin_revoke', 'platform_admin_revoke function exists');
select has_function('public', 'platform_admin_list', 'platform_admin_list function exists');

-- Non-admin cannot provision / revoke / list
select throws_ok(
  $$ select public.platform_admin_provision('00000000-0000-4000-8000-000000000001') $$,
  'P0001', 'PLT002: Admin access required.',
  'platform_admin_provision raises PLT002 for non-admin'
);

select throws_ok(
  $$ select public.platform_admin_revoke('22222222-2222-2222-2222-222222222222') $$,
  'P0001', 'PLT002: Admin access required.',
  'platform_admin_revoke raises PLT002 for non-admin'
);

select throws_ok(
  $$ select public.platform_admin_list() $$,
  'P0001', 'PLT002: Admin access required.',
  'platform_admin_list raises PLT002 for non-admin'
);

-- Admin can provision (the seeded demo identity) and list
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is(
  (public.platform_admin_provision('00000000-0000-4000-8000-000000000001') ->> 'success')::boolean,
  true,
  'platform_admin_provision succeeds for admin'
);

select ok(
  jsonb_array_length(public.platform_admin_list() -> 'data' -> 'admins') >= 1,
  'platform_admin_list returns the admin roster for admin'
);

-- ─── 12. Envelope contract ───────────────────────────────────────────────────
select is(
  (public.verification_review_queue_get(null, 10, 0))->>'code',
  'PLT000',
  'envelope code is PLT000'
);

select is(
  (select count(*)::int from jsonb_object_keys(public.verification_review_queue_get(null, 10, 0))),
  4,
  'envelope has exactly 4 top-level keys'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;