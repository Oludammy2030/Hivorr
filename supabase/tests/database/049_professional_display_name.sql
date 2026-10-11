-- Identity Phase 1b: professional display name on profession bindings.
--
-- Validates the extended entity_profession_bind (optional professional name),
-- the length CHECK, duplicate handling, the legacy 1-arg call shape, and the
-- verification_status_get projection:
--   - 3 bind-with-name + 2 bind-without-name + 2 name-validation +
--   - 1 duplicate + 1 valid-bind + 1 stored-name + 1 status-projection = 11.

begin;
set search_path to extensions, public;
select plan(11);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'e1e1e1e1-1111-4111-8111-111111111111', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'profilename-a@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active')
on conflict (id) do nothing;

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000081', 'pro-name-trade', 'Pro Name Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000082', 'ffffffff-0000-0000-0000-000000000081', 'pro-name-fixer', 'Pro Name Fixer', true),
       ('ffffffff-0000-0000-0000-000000000083', 'ffffffff-0000-0000-0000-000000000081', 'pro-name-other', 'Pro Name Other', true),
       ('ffffffff-0000-0000-0000-000000000084', 'ffffffff-0000-0000-0000-000000000081', 'pro-name-third', 'Pro Name Third', true)
on conflict (id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 1. Bind with professional name (082) ────────────────────────────────────
select lives_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000082', 'Adaeze Fixes It') $$,
  'bind with professional name succeeds (PLT000)'
);
select is(
  (select professional_display_name from public.entity_professions
    where entity_id = current_setting('test.a')::uuid
      and profession_id = 'ffffffff-0000-0000-0000-000000000082'),
  'Adaeze Fixes It',
  'professional name stored on the binding'
);
select is(
  (select trade_verification_status from public.entity_professions
    where entity_id = current_setting('test.a')::uuid
      and profession_id = 'ffffffff-0000-0000-0000-000000000082'),
  'unverified',
  'name carries no privilege: status stays unverified'
);

-- ─── 2. Bind without name stays null (083, legacy 1-arg shape) ───────────────
select lives_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000083') $$,
  'legacy 1-arg bind still resolves via the default (PLT000)'
);
select is(
  (select professional_display_name from public.entity_professions
    where entity_id = current_setting('test.a')::uuid
      and profession_id = 'ffffffff-0000-0000-0000-000000000083'),
  null,
  'omitted name stores null'
);

-- ─── 3. Name validation (084, still unbound) ─────────────────────────────────
select throws_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000084', '   ') $$,
  'P0001', 'PLT003: Professional name cannot be empty.',
  'whitespace-only professional name rejected'
);
select throws_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000084', rpad('x', 121, 'x')) $$,
  'P0001', 'PLT003: Professional name must be 120 characters or fewer.',
  'overlong professional name rejected'
);

-- ─── 4. Duplicate still rejected (082) ───────────────────────────────────────
select throws_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000082', 'Another Name') $$,
  'P0001', 'PLT005: Entity already bound to this profession.',
  'duplicate bind rejected (PLT005)'
);

-- ─── 5. Valid bind + projection (084) ────────────────────────────────────────
select lives_ok(
  $$ select public.entity_profession_bind('ffffffff-0000-0000-0000-000000000084', 'Dayo Delivers') $$,
  'bind with valid name succeeds after rejections (PLT000)'
);
select is(
  (select professional_display_name from public.entity_professions
    where entity_id = current_setting('test.a')::uuid
      and profession_id = 'ffffffff-0000-0000-0000-000000000084'),
  'Dayo Delivers',
  'rejected attempts left no partial row'
);
select is(
  (select t->>'professional_display_name'
     from jsonb_array_elements((public.verification_status_get()->'data'->'trade_verifications')) as t
    where t->>'profession_id' = 'ffffffff-0000-0000-0000-000000000082'),
  'Adaeze Fixes It',
  'status_get projects the professional name per profession'
);

select * from finish();
rollback;
