-- EP-02-11: Admin review wire contract (canonical shape)
--
-- Locks the ADMIN REVIEW WIRE CONTRACT shared with the Flutter client
-- (EP-02-11 §5.2, migration 20260917090001). The client DTOs adopt this
-- shape; this test is the server-side guarantee that the shape cannot drift
-- without a failing fixture:
--
--   verification_review_queue_get ->
--     data.submissions[]  (exactly the 16 canonical keys, order-independent)
--     data.total_count
--   verification_review_audit_get ->
--     data.audit_entries[] (exactly the 9 canonical keys)
--   platform_admin_check ->
--     data.is_admin (boolean)
--
-- Assertions are key-set based (jsonb_object_keys) so key RENAMES surface as
-- failures while natural JSON key ordering stays irrelevant.

begin;
set search_path to extensions, public;
select plan(21);

-- ─── 0. Fixtures (mirrors 020) ────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'nonadmin-contract@test.local'),
       ('22222222-2222-2222-2222-222222222222', 'admin-contract@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('11111111-1111-1111-1111-111111111111', 'active'),
       ('22222222-2222-2222-2222-222222222222', 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name)
values ('22222222-2222-2222-2222-222222222222', 'Contract Admin Co', 'Contract Admin Sdn Bhd')
on conflict (entity_id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000070', 'fx-contract-ind', 'Contract Ind', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000071', 'ffffffff-0000-0000-0000-000000000070', 'fx-contract-prof', 'Contract Prof', true)
on conflict (id) do nothing;

insert into public.platform_admins (user_id, granted_by, notes)
values ('22222222-2222-2222-2222-222222222222', null, 'Contract test admin')
on conflict (user_id) do nothing;

insert into public.entity_credentials (id, entity_id, profession_id, kind, title)
values ('ffffffff-0000-0000-0000-000000000072', '22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000071', 'trade_proof', 'Contract Trade Cert')
on conflict (id) do nothing;

insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status)
values ('ffffffff-0000-0000-0000-000000000073', '22222222-2222-2222-2222-222222222222', 'ffffffff-0000-0000-0000-000000000072', 'trade_proof', 'pending')
on conflict (id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Function surface ─────────────────────────────────────────────────────
select has_function('public', 'verification_review_queue_get', 'queue_get exists');
select has_function('public', 'verification_review_audit_get', 'audit_get exists');
select has_function('public', 'platform_admin_check', 'admin_check exists');

select is(
  public.verification_review_queue_get(null, 0, 20) -> 'data' ->> 'total_count',
  '1',
  'queue_get total_count reflects a single seeded submission'
);

-- ─── 2. queue_get: canonical submission key set ───────────────────────────────
-- Every canonical key must be present.
select ok(
  (select jsonb_object_keys(s) is not null from jsonb_array_elements(
    public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions'
  ) s(s) limit 1),
  'queue_get submissions array is non-empty'
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions'
       ) limit 1)
     ) k $$,
  $$ select unnest(array[
       'id', 'entity_id', 'entity_display_name', 'entity_legal_name',
       'entity_avatar_path', 'credential_id', 'credential_title',
       'credential_kind', 'document_path', 'profession_id',
       'profession_name', 'submission_type', 'status', 'submitted_at',
       'assigned_reviewer', 'decision_notes'
     ]) $$,
  'queue_get submission rows carry exactly the canonical key set'
);

-- Spot-check the joined metadata the client renders.
select is(
  (public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions' -> 0 ->> 'entity_display_name'),
  'Contract Admin Co',
  'queue_get joins entity_display_name'
);

select is(
  (public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions' -> 0 ->> 'credential_kind'),
  'trade_proof',
  'queue_get joins credential_kind'
);

select is(
  (public.verification_review_queue_get(null, 0, 20) -> 'data' -> 'submissions' -> 0 ->> 'submission_type'),
  'trade_proof',
  'queue_get exposes submission_type'
);

-- ─── 3. queue_get: p_submission_type filter (the new contract param) ─────────
select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, 'identity_document') -> 'data' -> 'submissions'
  ),
  0,
  'queue_get filters by submission_type (no identity_document rows)'
);

select is(
  jsonb_array_length(
    public.verification_review_queue_get(null, 0, 20, 'trade_proof') -> 'data' -> 'submissions'
  ),
  1,
  'queue_get includes the trade_proof row when filtered by type'
);

select throws_ok(
  $$ select public.verification_review_queue_get(null, 0, 20, 'bogus_type') $$,
  'P0001', 'PLT003: Invalid submission type filter.',
  'queue_get rejects an unknown submission_type filter'
);

-- ─── 4. audit_get: canonical audit entry key set ──────────────────────────────
insert into public.verification_audit_trail (
  entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
) values (
  '22222222-2222-2222-2222-222222222222', 'submission_created', 'submission',
  'ffffffff-0000-0000-0000-000000000073', null, 'pending',
  '22222222-2222-2222-2222-222222222222',
  jsonb_build_object('submission_type', 'trade_proof')
);

select set_eq(
  $$ select k from jsonb_object_keys(
       (select value from jsonb_array_elements(
         public.verification_review_audit_get('ffffffff-0000-0000-0000-000000000073') -> 'data' -> 'audit_entries'
       ) limit 1)
     ) k $$,
  $$ select unnest(array[
       'id', 'event_type', 'subject_type', 'subject_id', 'from_state',
       'to_state', 'actor_id', 'details', 'created_at'
     ]) $$,
  'audit_get rows carry exactly the canonical key set'
);

select is(
  jsonb_array_length(
    public.verification_review_audit_get('ffffffff-0000-0000-0000-000000000073') -> 'data' -> 'audit_entries'
  ),
  1,
  'audit_get returns the seeded audit entry'
);

select is(
  (public.verification_review_audit_get('ffffffff-0000-0000-0000-000000000073') -> 'data' -> 'audit_entries' -> 0 ->> 'event_type'),
  'submission_created',
  'audit_get entry exposes event_type'
);

-- ─── 5. platform_admin_check: canonical shape ──────────────────────────────────
select is(
  public.platform_admin_check() -> 'data' ->> 'is_admin',
  'true',
  'admin_check returns data.is_admin true for admin'
);

select is(
  (select jsonb_object_keys(
    (public.platform_admin_check() -> 'data')
  ) order by 1 desc nulls last limit 1),
  'is_admin',
  'admin_check data carries exactly one key: is_admin'
);

-- Non-admin: is_admin false (not an exception)
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is(
  public.platform_admin_check() -> 'data' ->> 'is_admin',
  'false',
  'admin_check reports is_admin false for non-admin'
);

-- ─── 6. Envelope contract: exactly 4 top-level keys ───────────────────────────
-- The envelope assertions need admin context; restore it (non-admin was
-- asserted above in section 5).
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is(
  (select count(*)::int from jsonb_object_keys(public.verification_review_queue_get(null, 0, 20))),
  4,
  'queue_get envelope has exactly 4 top-level keys'
);

select is(
  (public.verification_review_queue_get(null, 0, 20))->>'code',
  'PLT000',
  'queue_get envelope code is PLT000'
);

-- ─── 7. Admin gating on the new signature ─────────────────────────────────────
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_queue_get(null, 0, 20, 'trade_proof') $$,
  'P0001', 'PLT002: Admin access required.',
  'queue_get raises PLT002 for non-admin on the 4-arg signature'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;