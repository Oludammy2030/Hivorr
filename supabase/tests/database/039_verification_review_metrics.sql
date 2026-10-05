-- Professional Verification Queue: metrics RPC contract (Phase 2).
--
-- Locks the `verification_review_metrics_get` wire contract shared with the
-- Flutter client (migration 20261003090001):
--
--   verification_review_metrics_get ->
--     data { pending_total, in_review_total, avg_verification_seconds,
--            approved_today, decided_total, rejected_total, rejection_rate,
--            period_days }
--
-- Definitions: avg over approved/rejected rows decided in the trailing
-- window; approved_today counts immutable decision records since the UTC day
-- boundary; rejection_rate = rejected / decided with `requires_resubmission`
-- excluded from both sides.

begin;
set search_path to extensions, public;
select plan(17);

-- ─── 0. Fixtures ────────────────────────────────────────────────────────────
set role postgres;

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'nonadmin-metrics@test.local'),
       ('33333333-3333-3333-3333-333333333333', 'admin-metrics@test.local')
on conflict (id) do nothing;

insert into public.entities (id, status)
values ('33333333-3333-3333-3333-333333333333', 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, display_name, legal_name)
values ('33333333-3333-3333-3333-333333333333', 'Metrics Co', 'Metrics Sdn Bhd')
on conflict (entity_id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000170', 'fx-metrics-ind', 'Metrics Ind', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000171', 'ffffffff-0000-0000-0000-000000000170', 'fx-metrics-prof', 'Metrics Prof', true)
on conflict (id) do nothing;

insert into public.platform_admins (user_id, granted_by, notes)
values ('33333333-3333-3333-3333-333333333333', null, 'Metrics contract test admin')
on conflict (user_id) do nothing;

-- Five credentials: four trade_proof, one identity_document.
insert into public.entity_credentials (id, entity_id, profession_id, kind, title)
values ('ffffffff-0000-0000-0000-000000000172', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000171', 'trade_proof', 'Metrics Trade A'),
       ('ffffffff-0000-0000-0000-000000000173', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000171', 'trade_proof', 'Metrics Trade B'),
       ('ffffffff-0000-0000-0000-000000000174', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000171', 'trade_proof', 'Metrics Trade C'),
       ('ffffffff-0000-0000-0000-000000000175', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000171', 'trade_proof', 'Metrics Trade D'),
       ('ffffffff-0000-0000-0000-000000000176', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000171', 'identity_document', 'Metrics ID E')
on conflict (id) do nothing;

-- A: approved 2-day turnaround (submitted 3d ago, reviewed 1d ago).
insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status, submitted_at, reviewed_at, reviewed_by)
values ('ffffffff-0000-0000-0000-000000000177', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000172', 'trade_proof', 'approved', now() - interval '3 days', now() - interval '1 day', '33333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;

-- B: rejected 1-day turnaround (submitted 10d ago, reviewed 9d ago).
insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status, submitted_at, reviewed_at, reviewed_by)
values ('ffffffff-0000-0000-0000-000000000178', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000173', 'trade_proof', 'rejected', now() - interval '10 days', now() - interval '9 days', '33333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;

-- C: requires_resubmission (excluded from avg + decided by definition).
insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status, submitted_at, reviewed_at, reviewed_by)
values ('ffffffff-0000-0000-0000-000000000179', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000174', 'trade_proof', 'requires_resubmission', now() - interval '2 days', now() - interval '1 day', '33333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;

-- D: trade pending. E: identity pending.
insert into public.verification_submissions (id, entity_id, credential_id, submission_type, status)
values ('ffffffff-0000-0000-0000-000000000180', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000175', 'trade_proof', 'pending'),
       ('ffffffff-0000-0000-0000-000000000181', '33333333-3333-3333-3333-333333333333', 'ffffffff-0000-0000-0000-000000000176', 'identity_document', 'pending')
on conflict (id) do nothing;

-- Immutable decision records: A approved today, B rejected 5d ago,
-- C resubmission today (excluded from decided).
insert into public.verification_reviews (submission_id, entity_id, reviewer_id, decision, created_at)
values ('ffffffff-0000-0000-0000-000000000177', '33333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 'approved', now()),
       ('ffffffff-0000-0000-0000-000000000178', '33333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 'rejected', now() - interval '5 days'),
       ('ffffffff-0000-0000-0000-000000000179', '33333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 'requires_resubmission', now())
on conflict do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Function surface + live counts ──────────────────────────────────────
select has_function('public', 'verification_review_metrics_get', 'metrics_get exists');

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'pending_total',
  '2',
  'metrics pending_total reflects the two seeded pending rows'
);

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'in_review_total',
  '0',
  'metrics in_review_total is zero with no claimed rows'
);

-- ─── 2. Trailing-window aggregates ──────────────────────────────────────────
select ok(
  abs(((public.verification_review_metrics_get() -> 'data' ->> 'avg_verification_seconds')::double precision) - 129600.0) < 1.0,
  'metrics avg_verification_seconds means the 2-day and 1-day turnarounds'
);

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'approved_today',
  '1',
  'metrics approved_today counts the decision recorded today'
);

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'decided_total',
  '2',
  'metrics decided_total excludes the resubmission row'
);

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'rejected_total',
  '1',
  'metrics rejected_total counts the single rejection'
);

select ok(
  abs(((public.verification_review_metrics_get() -> 'data' ->> 'rejection_rate')::double precision) - 0.5) < 0.0001,
  'metrics rejection_rate is 1 rejected of 2 decided'
);

select is(
  public.verification_review_metrics_get() -> 'data' ->> 'period_days',
  '30',
  'metrics period_days echoes the default window'
);

-- ─── 3. Canonical data key set ──────────────────────────────────────────────
select set_eq(
  $$ select k from jsonb_object_keys(public.verification_review_metrics_get() -> 'data') k $$,
  $$ select unnest(array[
       'pending_total', 'in_review_total', 'avg_verification_seconds',
       'approved_today', 'decided_total', 'rejected_total',
       'rejection_rate', 'period_days'
     ]) $$,
  'metrics data carries exactly the canonical key set'
);

-- ─── 4. Envelope + type filter ─────────────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.verification_review_metrics_get())),
  4,
  'metrics envelope has exactly 4 top-level keys'
);

select is(
  (public.verification_review_metrics_get())->>'code',
  'PLT000',
  'metrics envelope code is PLT000'
);

select is(
  public.verification_review_metrics_get(30, 'trade_proof') -> 'data' ->> 'pending_total',
  '1',
  'metrics pending_total respects the submission_type filter'
);

select is(
  public.verification_review_metrics_get(30, 'identity_document') -> 'data' ->> 'pending_total',
  '1',
  'metrics pending_total counts the identity pending row when filtered'
);

-- ─── 5. Validation + gating ─────────────────────────────────────────────────
select throws_ok(
  $$ select public.verification_review_metrics_get(0) $$,
  'P0001', 'PLT003: Invalid period (1-365 days).',
  'metrics rejects an out-of-range period'
);

select throws_ok(
  $$ select public.verification_review_metrics_get(30, 'bogus_type') $$,
  'P0001', 'PLT003: Invalid submission type filter.',
  'metrics rejects an unknown submission_type filter'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$ select public.verification_review_metrics_get() $$,
  'P0001', 'PLT002: Admin access required.',
  'metrics raises PLT002 for non-admin'
);

-- Cleanup: transaction rollback discards all fixtures and mutations
select * from finish();
rollback;
