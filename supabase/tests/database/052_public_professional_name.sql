-- Identity Phase 3: approved professional name on the public profile.
--
-- Validates that portfolio_public_profile_get projects
-- `professional_display_name` per approved profession entry, yields null
-- when the binding carries no name, and keeps the approved-gate intact:
--   - 2 named-projection + 1 null-name + 1 gate-intact = 4.

begin;
set search_path to extensions, public;
select plan(4);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'c1c1c1c1-1111-4111-8111-111111111111', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'pro-name-public@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name)
values (current_setting('test.a')::uuid, 'Adaeze Okafor', 'Adaeze Okafor')
on conflict (entity_id) do update
  set display_name = 'Adaeze Okafor';

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000095', 'pro-name-pub', 'Pro Name Pub', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000096', 'ffffffff-0000-0000-0000-000000000095', 'pro-name-star', 'Pro Name Star', true),
       ('ffffffff-0000-0000-0000-000000000097', 'ffffffff-0000-0000-0000-000000000095', 'pro-name-extra', 'Pro Name Extra', true)
on conflict (id) do nothing;

-- Named approved binding + unnamed approved binding.
insert into public.entity_professions
  (entity_id, profession_id, is_primary, trade_verification_status, professional_display_name)
values (current_setting('test.a')::uuid, 'ffffffff-0000-0000-0000-000000000096', true, 'approved', 'Adaeze Fixes It')
on conflict (entity_id, profession_id) do update
  set trade_verification_status = 'approved',
      professional_display_name = 'Adaeze Fixes It';

insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values (current_setting('test.a')::uuid, 'ffffffff-0000-0000-0000-000000000097', false, 'approved')
on conflict (entity_id, profession_id) do update
  set trade_verification_status = 'approved';

-- ─── 1. Named projection ─────────────────────────────────────────────────────
set role service_role;

select is(
  (select t->>'professional_display_name'
     from jsonb_array_elements(
       public.portfolio_public_profile_get(current_setting('test.a')::uuid)
         ->'data'->'professions') as t
    where t->>'profession_id' = 'ffffffff-0000-0000-0000-000000000096'),
  'Adaeze Fixes It',
  'approved binding projects its professional name'
);

-- ─── 2. Unnamed binding yields null (client falls back) ──────────────────────
select is(
  (select t->>'professional_display_name'
     from jsonb_array_elements(
       public.portfolio_public_profile_get(current_setting('test.a')::uuid)
         ->'data'->'professions') as t
    where t->>'profession_id' = 'ffffffff-0000-0000-0000-000000000097'),
  null,
  'binding without a name projects null (no invented identity)'
);

-- ─── 3. Approved-gate intact ─────────────────────────────────────────────────
select is(
  (select public.portfolio_public_profile_get(current_setting('test.a')::uuid)->>'code'),
  'PLT000',
  'profile still resolves with named + unnamed approved bindings'
);
select throws_ok(
  format('select public.portfolio_public_profile_get(%L)', '00000000-0000-4000-8000-000000000099'),
  'P0001', null,
  'unknown entity still PLT004 (gate intact)'
);

select * from finish();
rollback;
