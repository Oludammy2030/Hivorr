-- EP-03-15: Portfolio & Proof-of-Work Service Integration
--
-- Validates the service_listing_portfolio_links junction DDL + RLS and the
-- three proof RPCs: service_listing_link_portfolio_items(uuid, uuid[]),
-- service_listing_unlink_portfolio_item(uuid, uuid),
-- service_listing_portfolio_list(uuid) (EP-03-15 TIP §16).
-- Style mirrors 018_portfolio_public_profile.sql / 024_service_marketplace_rpc_enforcement.sql.
--
-- Covers:
--   - Junction table exists, NOT NULL columns, updated_at trigger, RLS,
--     UNIQUE(listing_id, portfolio_item_id), (listing_id, sort_order) index.
--   - Default-deny: anon zero grants; owner self-CRUD present; no anon policy.
--   - portfolio_items gains exactly one additive owner SELECT policy (the
--     pre-existing grant, activated for the link-RPC ownership guard; anon
--     posture unchanged).
--   - RPC identity: writes SECURITY INVOKER + VOLATILE; public read SECURITY
--     DEFINER (portfolio_public_profile_get precedent) + STABLE; jsonb
--     returns; EXECUTE grants (list anon-capable; writes
--     authenticated+service_role; no PUBLIC grant anywhere).
--   - Behavior: PLT003/PLT004/PLT001/PLT005 matrices, full-replace
--     idempotency, unlink idempotency, published-vs-draft visibility with the
--     identical PLT004 (no oracle), whitelist negatives, raw anon SELECT
--     denial, realtime exclusion.

begin;
set search_path to extensions, public;
select plan(60);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);
select set_config('test.prof', 'ffffffff-0000-0000-0000-000000000040', true);
select set_config('test.ind', 'ffffffff-0000-0000-0000-000000000041', true);
select set_config('test.item_a1', 'aaaaaaaa-0000-4000-8000-0000000000a1', true);
select set_config('test.item_a2', 'aaaaaaaa-0000-4000-8000-0000000000a2', true);
select set_config('test.item_a3', 'aaaaaaaa-0000-4000-8000-0000000000a3', true);
select set_config('test.item_b1', 'bbbbbbbb-0000-4000-8000-0000000000b1', true);
select set_config('test.listing_pub', 'c0000000-0000-4000-8000-000000000001', true);
select set_config('test.listing_draft', 'c0000000-0000-4000-8000-000000000002', true);
select set_config('test.listing_arch', 'c0000000-0000-4000-8000-000000000003', true);
select set_config('test.listing_b', 'c0000000-0000-4000-8000-000000000004', true);

insert into auth.users (id, email)
values
  (current_setting('test.a')::uuid, 'entity-a-proof@example.com'),
  (current_setting('test.b')::uuid, 'entity-b-proof@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values
  (current_setting('test.a')::uuid, 'active'),
  (current_setting('test.b')::uuid, 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name, bio, country_code)
values
  (current_setting('test.a')::uuid, 'Proof Owner Alpha', 'Alpha', 'Proves work', 'NG'),
  (current_setting('test.b')::uuid, 'Proof Stranger Beta', 'Beta', 'Stranger', 'NG')
on conflict (entity_id) do nothing;

insert into public.industries (id, slug, name, is_active)
values (current_setting('test.ind')::uuid, 'proof-trade', 'Proof Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values (current_setting('test.prof')::uuid, current_setting('test.ind')::uuid, 'proof-pro', 'Proof Professional', true)
on conflict (id) do nothing;

insert into public.portfolio_items (id, entity_id, item_type, title, description, media_path, sort_order)
values
  (current_setting('test.item_a1')::uuid, current_setting('test.a')::uuid, 'image', 'Alpha piece one', 'A proof piece', 'portfolio-items/11111111-1111-1111-1111-111111111111/a1.jpg', 1),
  (current_setting('test.item_a2')::uuid, current_setting('test.a')::uuid, 'image', 'Alpha piece two', 'Another proof piece', 'portfolio-items/11111111-1111-1111-1111-111111111111/a2.jpg', 2),
  (current_setting('test.item_a3')::uuid, current_setting('test.a')::uuid, 'document', 'Alpha case study', 'A written case study', 'portfolio-items/11111111-1111-1111-1111-111111111111/a3.pdf', 3),
  (current_setting('test.item_b1')::uuid, current_setting('test.b')::uuid, 'image', 'Beta piece', 'Stranger piece', 'portfolio-items/22222222-2222-2222-2222-222222222222/b1.jpg', 1)
on conflict (id) do nothing;

-- Fixture listings are seeded as postgres (the D5 publish-state guard only
-- fires for current_user = 'authenticated'; CHECK semantics still hold, so
-- the published rows carry published_at).
insert into public.service_listings
  (id, entity_id, profession_id, industry_id, slug, title, description, status, pricing_type, price_min, currency_code, published_at)
values
  (current_setting('test.listing_pub')::uuid, current_setting('test.a')::uuid, current_setting('test.prof')::uuid, current_setting('test.ind')::uuid,
   'proof-listing-pub', 'Proof listing published title', 'A published service listing with enough description length to satisfy the check constraint here.', 'published', 'fixed', 5000, 'NGN', now()),
  (current_setting('test.listing_draft')::uuid, current_setting('test.a')::uuid, current_setting('test.prof')::uuid, current_setting('test.ind')::uuid,
   'proof-listing-draft', 'Proof listing draft title here', 'A draft service listing with enough description length to satisfy the check constraint here.', 'draft', 'fixed', 5000, 'NGN', null),
  (current_setting('test.listing_arch')::uuid, current_setting('test.a')::uuid, current_setting('test.prof')::uuid, current_setting('test.ind')::uuid,
   'proof-listing-arch', 'Proof listing archived title', 'An archived service listing with enough description length to satisfy the check constraint here.', 'archived', 'fixed', 5000, 'NGN', null),
  (current_setting('test.listing_b')::uuid, current_setting('test.b')::uuid, current_setting('test.prof')::uuid, current_setting('test.ind')::uuid,
   'proof-listing-b', 'Stranger published listing title', 'A stranger published listing with enough description length to satisfy the check here.', 'published', 'fixed', 5000, 'NGN', now())
on conflict (id) do nothing;

-- ─── 1. Junction table exists ────────────────────────────────────────────────
select has_table('public', 'service_listing_portfolio_links', 'junction table exists');

-- ─── 2-5. NOT NULL columns ───────────────────────────────────────────────────
select col_not_null('public', 'service_listing_portfolio_links', 'listing_id', 'listing_id is not null');
select col_not_null('public', 'service_listing_portfolio_links', 'portfolio_item_id', 'portfolio_item_id is not null');
select col_not_null('public', 'service_listing_portfolio_links', 'entity_id', 'entity_id is not null');
select col_not_null('public', 'service_listing_portfolio_links', 'created_at', 'created_at is not null');

-- ─── 6. updated_at trigger ───────────────────────────────────────────────────
select has_trigger('public', 'service_listing_portfolio_links', 'service_listing_portfolio_links_set_updated_at', 'platform_set_updated_at trigger exists');

-- ─── 7. RLS enabled ──────────────────────────────────────────────────────────
select is(
  (select c.relrowsecurity
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'service_listing_portfolio_links'),
  true,
  'junction RLS is enabled'
);

-- ─── 8. Anon zero grants ─────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'service_listing_portfolio_links'
      and grantee = 'anon'),
  0,
  'anon has zero grants on the junction table'
);

-- ─── 9. Authenticated self-CRUD ──────────────────────────────────────────────
select ok(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'service_listing_portfolio_links'
      and grantee = 'authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')) = 4,
  'authenticated has SELECT/INSERT/UPDATE/DELETE on the junction table'
);

-- ─── 10. service_role SELECT ─────────────────────────────────────────────────
select ok(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'service_listing_portfolio_links'
      and grantee = 'service_role'
      and privilege_type = 'SELECT') >= 1,
  'service_role has SELECT on the junction table'
);

-- ─── 11. UNIQUE(listing_id, portfolio_item_id) ───────────────────────────────
select ok(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listing_portfolio_links'::regclass
      and contype = 'u') >= 1,
  'unique constraint on (listing_id, portfolio_item_id) exists'
);

-- ─── 12. (listing_id, sort_order) index ──────────────────────────────────────
select ok(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_listing_portfolio_links'
      and indexname = 'service_listing_portfolio_links_listing_sort_idx') = 1,
  '(listing_id, sort_order) index exists'
);

-- ─── 13. No anon policy ──────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'service_listing_portfolio_links'
      and roles @> array['anon']::name[]),
  0,
  'no anon policy on the junction table'
);

-- ─── 14. Four owner policies ─────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'service_listing_portfolio_links'
      and policyname like 'service_listing_portfolio_links\_%\_own'),
  4,
  'four owner policies exist (select/insert/update/delete)'
);

-- ─── 15. portfolio_items gains exactly one additive owner SELECT policy ─────
-- (activates the pre-existing SELECT grant for the link-RPC ownership guard;
-- anon posture unchanged, EP-02-19 pgTAP 018 unaffected).
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public' and tablename = 'portfolio_items'
      and policyname = 'portfolio_items_authenticated_select_own'),
  1,
  'portfolio_items owner select policy exists'
);

-- ─── 16-18. RPCs exist ─────────────────────────────────────────────────────
select has_function('public', 'service_listing_link_portfolio_items', array['uuid', 'uuid[]'],
  'service_listing_link_portfolio_items function exists');
select has_function('public', 'service_listing_unlink_portfolio_item', array['uuid', 'uuid'],
  'service_listing_unlink_portfolio_item function exists');
select has_function('public', 'service_listing_portfolio_list', array['uuid'],
  'service_listing_portfolio_list function exists');

-- ─── 19-21. Volatility: writes VOLATILE, read STABLE ────────────────────────
select is(
  (select provolatile from pg_proc where proname = 'service_listing_link_portfolio_items'),
  'v',
  'link RPC is VOLATILE'
);
select is(
  (select provolatile from pg_proc where proname = 'service_listing_unlink_portfolio_item'),
  'v',
  'unlink RPC is VOLATILE'
);
select is(
  (select provolatile from pg_proc where proname = 'service_listing_portfolio_list'),
  's',
  'list RPC is STABLE'
);

-- ─── 22-24. Writes INVOKER, public read DEFINER ─────────────────────────────
select is(
  (select prosecdef from pg_proc where proname = 'service_listing_link_portfolio_items'),
  false,
  'link RPC is SECURITY INVOKER'
);
select is(
  (select prosecdef from pg_proc where proname = 'service_listing_unlink_portfolio_item'),
  false,
  'unlink RPC is SECURITY INVOKER'
);
select is(
  (select prosecdef from pg_proc where proname = 'service_listing_portfolio_list'),
  true,
  'list RPC is SECURITY DEFINER (portfolio_public_profile_get precedent)'
);

-- ─── 25-26. jsonb returns ────────────────────────────────────────────────────
select is(
  (select prorettype::regtype from pg_proc where proname = 'service_listing_link_portfolio_items'),
  'jsonb'::regtype,
  'link RPC returns jsonb'
);
select is(
  (select prorettype::regtype from pg_proc where proname = 'service_listing_portfolio_list'),
  'jsonb'::regtype,
  'list RPC returns jsonb'
);

-- ─── 27-32. EXECUTE grants ──────────────────────────────────────────────────
select ok(
  has_function_privilege('anon', 'public.service_listing_portfolio_list(uuid)', 'execute'),
  'anon has EXECUTE on the list RPC (published-only read)'
);
select ok(
  not has_function_privilege('anon', 'public.service_listing_link_portfolio_items(uuid, uuid[])', 'execute'),
  'anon has no EXECUTE on the link RPC'
);
select ok(
  has_function_privilege('authenticated', 'public.service_listing_link_portfolio_items(uuid, uuid[])', 'execute'),
  'authenticated has EXECUTE on the link RPC'
);
select ok(
  has_function_privilege('authenticated', 'public.service_listing_unlink_portfolio_item(uuid, uuid)', 'execute'),
  'authenticated has EXECUTE on the unlink RPC'
);
select ok(
  not has_function_privilege('public', 'public.service_listing_link_portfolio_items(uuid, uuid[])', 'execute'),
  'no PUBLIC execute grant on the link RPC'
);
select ok(
  not has_function_privilege('public', 'public.service_listing_portfolio_list(uuid)', 'execute'),
  'no PUBLIC execute grant on the list RPC'
);

-- ─── Link RPC behavior as owner A ────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── 33. PLT003 null listing ─────────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(null, ARRAY[%L]::uuid[])', current_setting('test.item_a1')),
  'P0001', 'PLT003: Listing id is required.',
  'PLT003 raised for null listing id'
);

-- ─── 34. PLT003 empty array ──────────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[]::uuid[])', current_setting('test.listing_pub')),
  'P0001', 'PLT003: Select at least one portfolio item.',
  'PLT003 raised for empty portfolio array'
);

-- ─── 35. PLT003 over cap (9 ids) ─────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L,%L,%L,%L,%L,%L,%L,%L,%L]::uuid[])',
    current_setting('test.listing_pub'), current_setting('test.item_a1'), current_setting('test.item_a2'),
    current_setting('test.item_a3'), current_setting('test.item_a1'), current_setting('test.item_a2'),
    current_setting('test.item_a3'), current_setting('test.item_a1'), current_setting('test.item_a2'),
    current_setting('test.item_a3')),
  'P0001', 'PLT003: Link at most 8 portfolio items per service.',
  'PLT003 raised for 9 portfolio ids'
);

-- ─── 36. PLT003 duplicates ───────────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L,%L]::uuid[])',
    current_setting('test.listing_pub'), current_setting('test.item_a1'), current_setting('test.item_a1')),
  'P0001', 'PLT003: Duplicate portfolio items are not allowed.',
  'PLT003 raised for duplicate portfolio ids'
);

-- ─── 37. PLT004 unknown listing ──────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L]::uuid[])',
    '00000000-0000-4000-8000-000000000099', current_setting('test.item_a1')),
  'P0001', 'PLT004: Listing not found.',
  'PLT004 raised for unknown listing'
);

-- ─── 38. PLT001 stranger listing ─────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L]::uuid[])',
    current_setting('test.listing_b'), current_setting('test.item_a1')),
  'P0001', 'PLT001: You can only link proof to your own listings.',
  'PLT001 raised when linking to a stranger listing'
);

-- ─── 39. PLT004 identical for stranger item (no oracle) ─────────────────────
-- Under RLS the caller cannot distinguish an unknown id from an unowned one;
-- both surface the identical PLT004 (returning PLT001 here would leak item
-- existence). The PLT001 ownership branch remains as defense-in-depth for
-- service_role callers, who bypass RLS.
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L,%L]::uuid[])',
    current_setting('test.listing_pub'), current_setting('test.item_a1'), current_setting('test.item_b1')),
  'P0001', 'PLT004: Portfolio item not found.',
  'PLT004 raised when a stranger item is mixed in (no existence oracle)'
);

-- ─── 40. PLT005 archived listing ─────────────────────────────────────────────
select throws_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L]::uuid[])',
    current_setting('test.listing_arch'), current_setting('test.item_a1')),
  'P0001', 'PLT005: Proof can only be linked to draft, published, or paused listings.',
  'PLT005 raised when linking to an archived listing'
);

-- ─── 41-43. PLT000 happy path: link 2, count + order ────────────────────────
select lives_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L,%L]::uuid[])',
    current_setting('test.listing_pub'), current_setting('test.item_a1'), current_setting('test.item_a2')),
  'PLT000 success linking two owned items to an owned published listing'
);

select is(
  (select (public.service_listing_link_portfolio_items(
    current_setting('test.listing_pub')::uuid,
    ARRAY[current_setting('test.item_a1')::uuid, current_setting('test.item_a2')::uuid]
  ) -> 'data' ->> 'count')),
  '2',
  'link result count is 2'
);

select is(
  (select (public.service_listing_link_portfolio_items(
    current_setting('test.listing_pub')::uuid,
    ARRAY[current_setting('test.item_a1')::uuid, current_setting('test.item_a2')::uuid]
  ) -> 'data' -> 'linked_ids' ->> 0)),
  current_setting('test.item_a1'),
  'link result preserves array order (first id)'
);

-- ─── 44. Full-replace: new set supersedes ────────────────────────────────────
select is(
  (select (public.service_listing_link_portfolio_items(
    current_setting('test.listing_pub')::uuid,
    ARRAY[current_setting('test.item_a3')::uuid]
  ) -> 'data' ->> 'count')),
  '1',
  'full-replace save supersedes the previous link set'
);

-- ─── 45-46. Unlink idempotency ───────────────────────────────────────────────
select is(
  (select (public.service_listing_unlink_portfolio_item(
    current_setting('test.listing_pub')::uuid,
    current_setting('test.item_a3')::uuid
  ) -> 'data' ->> 'removed')),
  'true',
  'unlink of a linked item returns removed=true'
);

select is(
  (select (public.service_listing_unlink_portfolio_item(
    current_setting('test.listing_pub')::uuid,
    current_setting('test.item_a3')::uuid
  ) -> 'data' ->> 'removed')),
  'false',
  'unlink of an absent link returns removed=false (idempotent)'
);

-- Re-link two items for the visibility matrix below.
select public.service_listing_link_portfolio_items(
  current_setting('test.listing_pub')::uuid,
  ARRAY[current_setting('test.item_a1')::uuid, current_setting('test.item_a2')::uuid]
);

-- ─── 47-48. Anon reads published links ───────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000099', true);
select set_config('request.jwt.claim.role', 'anon', true);

select is(
  (select (public.service_listing_portfolio_list(current_setting('test.listing_pub')::uuid) ->> 'code')),
  'PLT000',
  'anon list of a published listing returns PLT000'
);

select is(
  (select (public.service_listing_portfolio_list(current_setting('test.listing_pub')::uuid) -> 'data' ->> 'count')),
  '2',
  'anon list of a published listing returns 2 items'
);

-- ─── 49. Anon reads draft → PLT004 (no oracle) ───────────────────────────────
select throws_ok(
  format('select public.service_listing_portfolio_list(%L::uuid)', current_setting('test.listing_draft')),
  'P0001', 'PLT004: Listing not found.',
  'PLT004 raised for anon list of a draft listing'
);

-- ─── 50. Stranger B reads owner A draft → PLT004 ─────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  format('select public.service_listing_portfolio_list(%L::uuid)', current_setting('test.listing_draft')),
  'P0001', 'PLT004: Listing not found.',
  'PLT004 raised for stranger list of a draft listing'
);

-- ─── 51. Owner A reads own draft → PLT000 ────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select is(
  (select (public.service_listing_portfolio_list(current_setting('test.listing_draft')::uuid) ->> 'code')),
  'PLT000',
  'owner list of own draft returns PLT000 (staging preview)'
);

-- ─── 52. Unknown listing → identical PLT004 ──────────────────────────────────
select throws_ok(
  $$ select public.service_listing_portfolio_list('00000000-0000-4000-8000-000000000099') $$,
  'P0001', 'PLT004: Listing not found.',
  'PLT004 raised for unknown listing (identical message)'
);

-- ─── 53. Whitelist negative: entity_id never in item payload ─────────────────
select is(
  (select (public.service_listing_portfolio_list(current_setting('test.listing_pub')::uuid) -> 'data' -> 'items' -> 0) ? 'entity_id'),
  false,
  'entity_id is NOT in the linked item payload'
);

-- ─── 54. Anon raw table SELECT still fails (default-deny preserved) ─────────
set role anon;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000099', true);
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok(
  $$ select count(*) from public.service_listing_portfolio_links $$,
  '42501', null,
  'anon raw SELECT on the junction table fails (default-deny RLS)'
);

-- ─── 55. Junction excluded from supabase_realtime ────────────────────────────
set role service_role;
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'service_listing_portfolio_links'),
  0,
  'junction table excluded from supabase_realtime'
);

-- ─── 56. Exactly the 3 new proof RPCs exist ──────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname in ('service_listing_link_portfolio_items',
                      'service_listing_unlink_portfolio_item',
                      'service_listing_portfolio_list')),
  3,
  'exactly the 3 new proof RPCs exist (link/unlink/list)'
);

-- ─── 57-59. Reuse, cascade, direct-insert guard ──────────────────────────────
-- One portfolio piece may prove many listings (junction, not FK-on-item).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  format('select public.service_listing_link_portfolio_items(%L::uuid, ARRAY[%L]::uuid[])',
    current_setting('test.listing_draft'), current_setting('test.item_a1')),
  'owner links an already-linked item to a second listing'
);

select is(
  (select count(*)::int
     from public.service_listing_portfolio_links
    where portfolio_item_id = current_setting('test.item_a1')::uuid),
  2,
  'the same item is linked to two listings (reuse)'
);

-- Deleting a listing cascades its links only; sibling listings keep theirs.
-- (Cleanup as service_role: owner DELETE on service_listings is not part of
-- the client contract.)
set role service_role;
delete from public.service_listings
 where id = current_setting('test.listing_draft')::uuid;

select is(
  (select count(*)::int from public.service_listing_portfolio_links),
  2,
  'deleting a listing removes only its own links (cascade)'
);

-- A stranger cannot attach rows to another professional's listing outside
-- the RPCs, even with a self-owned row (owned-listing conjunct).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select throws_ok(
  format(
    'insert into public.service_listing_portfolio_links (listing_id, portfolio_item_id, entity_id) values (%L::uuid, %L::uuid, %L::uuid)',
    current_setting('test.listing_pub'), current_setting('test.item_b1'), current_setting('test.b')),
  '42501', null,
  'stranger direct insert on another listing fails (owned-listing conjunct)'
);

select * from finish();
rollback;
