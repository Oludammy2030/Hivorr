-- EP-01-06 / EP-02: Onboarding Authoritative State Enforcement
--
-- Verifies the onboarding-authority migration (20260915090001): anon has no
-- execute grants, unauthenticated calls return PLT001, capability vocabulary is
-- validated, completion is gated on server-side step verification (hire = profile
-- only; offer/both = professional role + profession + identity + trade proof),
-- direct PostgREST writes to capability / onboarding_completed_at are blocked by
-- the D5 guard trigger (PLT002), reset is service_role-only and trails to the
-- append-only audit table with zero client grants, and platform_audit_log
-- captures the authenticated-path mutations.

begin;
set search_path to extensions, public;
select plan(31);

-- ─── Seed callers + taxonomy + profiles ─────────────────────────────────────
insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'a@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values ('11111111-1111-1111-1111-111111111111', 'active');
insert into public.entity_profiles (entity_id, legal_name, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Legal A', 'Display A');

insert into auth.users (id, email) values ('22222222-2222-2222-2222-222222222222', 'b@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values ('22222222-2222-2222-2222-222222222222', 'active');
insert into public.entity_profiles (entity_id, legal_name, display_name)
values ('22222222-2222-2222-2222-222222222222', 'Legal B', 'Display B');

insert into public.industries (id, slug, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'fx-tech', 'Technology');
insert into public.professions (id, industry_id, slug, name, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'fx-chef', 'Chef', true);

-- ─── A. Anon has NO execute grant on onboarding RPCs (42501) ────────────────
set role anon;
select throws_ok(
  $$ select public.entity_onboarding_status_update('hire', null) $$,
  '42501', null, 'anon cannot execute entity_onboarding_status_update (no grant)');
select throws_ok(
  $$ select public.entity_onboarding_status_get() $$,
  '42501', null, 'anon cannot execute entity_onboarding_status_get (no grant)');
select throws_ok(
  $$ select public.entity_onboarding_reset('11111111-1111-1111-1111-111111111111') $$,
  '42501', null, 'anon cannot execute entity_onboarding_reset (no grant)');

-- ─── B. Authenticated but empty JWT sub → PLT001 (P0001) ───────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok(
  $$ select public.entity_onboarding_status_get() $$,
  'P0001', 'PLT001: Authentication required.', 'empty-sub status_get returns PLT001');

-- ─── C. As authenticated user A (hire path) ─────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('platform.rpc_invocation', '', true);
select throws_ok(
  $$ update public.entities set capability = 'both' where id = '11111111-1111-1111-1111-111111111111' $$,
  'P0001', 'PLT002: Onboarding state may only be changed through the entity_onboarding_status_update RPC.',
  'direct PATCH of capability blocked by D5 guard (PLT002)');

select set_config('platform.rpc_invocation', '', true);
select throws_ok(
  $$ update public.entities set onboarding_completed_at = now() where id = '11111111-1111-1111-1111-111111111111' $$,
  'P0001', 'PLT002: Onboarding state may only be changed through the entity_onboarding_status_update RPC.',
  'direct PATCH of onboarding_completed_at blocked by D5 guard (PLT002)');

select throws_ok(
  $$ select public.entity_onboarding_reset('22222222-2222-2222-2222-222222222222') $$,
  '42501', null, 'authenticated cannot execute entity_onboarding_reset (service_role only)');

select throws_ok(
  $$ select public.entity_onboarding_status_update('wizard', null) $$,
  'P0001', 'PLT003: Invalid capability value.', 'unknown capability rejected (PLT003)');

select is(
  (select (public.entity_onboarding_status_update('hire', null))->>'code'),
  'PLT000', 'hire capability persisted (PLT000)');
select is(
  (select capability from public.entities where id = '11111111-1111-1111-1111-111111111111'),
  'hire', 'capability persisted on entities row');

select is(
  (select (public.entity_onboarding_status_update(null, true))->>'code'),
  'PLT000', 'hire completes with profile only (PLT000)');
select is(
  (select onboarding_completed_at is not null from public.entities where id = '11111111-1111-1111-1111-111111111111'),
  true, 'completion stamp persisted for hire path');
select is(
  (select (public.entity_onboarding_status_get())->>'data')
    ::jsonb ->> 'completed',
  'true', 'status_get reports completed = true');

-- ─── D. As authenticated user B (offer/both path) ───────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select (public.entity_onboarding_status_update('both', null))->>'code'),
  'PLT000', 'both capability persisted (PLT000)');
select is(
  (select (public.entity_roles_activate('professional'))->>'code'),
  'PLT000', 'professional role activated (PLT000)');

select throws_ok(
  $$ select public.entity_onboarding_status_update(null, true) $$,
  'P0001', 'PLT003: Bind at least one profession before finishing onboarding.',
  'completion blocked without profession binding (PLT003)');

select is(
  (select (public.entity_profession_bind('bbbbbbbb-0000-0000-0000-000000000001'))->>'code'),
  'PLT000', 'profession bound (PLT000)');

select throws_ok(
  $$ select public.entity_onboarding_status_update(null, true) $$,
  'P0001', 'PLT003: Submit an identity document before finishing onboarding.',
  'completion blocked without identity document (PLT003)');

select is(
  (select (public.entity_credentials_submit('identity_document','National ID','bbbbbbbb-0000-0000-0000-000000000001',null))->>'code'),
  'PLT000', 'identity document submitted (PLT000)');

select throws_ok(
  $$ select public.entity_onboarding_status_update(null, true) $$,
  'P0001', 'PLT003: Submit trade proof before finishing onboarding.',
  'completion blocked without trade proof (PLT003)');

select is(
  (select (public.entity_credentials_submit('trade_proof','Trade Cert','bbbbbbbb-0000-0000-0000-000000000001',null))->>'code'),
  'PLT000', 'trade proof submitted (PLT000)');

select is(
  (select (public.entity_onboarding_status_update(null, true))->>'code'),
  'PLT000', 'offer/both completes once all steps present (PLT000)');
select is(
  (select onboarding_completed_at is not null from public.entities where id = '22222222-2222-2222-2222-222222222222'),
  true, 'completion stamp persisted for offer path');

-- ─── E. Service-role reset (admin re-onboarding) ────────────────────────────
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select (public.entity_onboarding_reset('11111111-1111-1111-1111-111111111111'))->>'code'),
  'PLT000', 'service_role reset succeeds (PLT000)');
select is(
  (select capability from public.entities where id = '11111111-1111-1111-1111-111111111111'),
  null, 'reset clears capability');
select is(
  (select onboarding_completed_at from public.entities where id = '11111111-1111-1111-1111-111111111111'),
  null, 'reset clears completion stamp');
select is(
  (select count(*)::int from public.entity_onboarding_audit_trail
    where entity_id = '11111111-1111-1111-1111-111111111111' and action = 'onboarding_reset'),
  1, 'reset writes append-only audit trail');

-- ─── F. Audit + posture (postgres) ──────────────────────────────────────────
set role postgres;
select is(
  (select count(*)::int from public.platform_audit_log
    where actor_id = '11111111-1111-1111-1111-111111111111'
      and entity = 'entities' and action = 'entity_onboarding_status_update'),
  2, 'authenticated onboarding mutations audit-logged (hire: capability + completion)');

select is(
  (select count(*)::int from public.platform_audit_log
    where actor_id = '22222222-2222-2222-2222-222222222222'
      and entity = 'entities' and action = 'entity_onboarding_status_update'),
  2, 'authenticated onboarding mutations audit-logged (both: capability + completion)');

select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'entity_onboarding_audit_trail'
      and grantee = 'anon'),
  0, 'anon has zero grants on the onboarding audit trail');
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'entity_onboarding_audit_trail'
      and grantee = 'authenticated'),
  0, 'authenticated has zero grants on the onboarding audit trail');

select * from finish();
rollback;