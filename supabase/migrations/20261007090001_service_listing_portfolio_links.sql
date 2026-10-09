-- EP-03-15: Portfolio & Proof-of-Work Service Integration
--
-- Links existing `portfolio_items` rows to `service_listings` rows as
-- per-listing proof-of-work. One additive junction table plus two
-- SECURITY INVOKER write RPCs and one SECURITY DEFINER public-read RPC;
-- zero edits to existing tables, RPCs, or policies.
--
-- Design (EP-03-15 TIP §7.1):
--   - `service_listing_portfolio_links` — one row per (listing, item),
--     entity-scoped via denormalized `entity_id`, per-listing curation order
--     via `sort_order` (array position on every full-replace save).
--   - `service_listing_link_portfolio_items(p_listing_id, p_portfolio_ids)` —
--     VOLATILE full-replace (idempotent, single round-trip reorder), owner-only.
--   - `service_listing_unlink_portfolio_item(p_listing_id, p_portfolio_item_id)` —
--     VOLATILE single-remove convenience, idempotent on absent links.
--   - `service_listing_portfolio_list(p_listing_id)` — STABLE SECURITY
--     DEFINER public read; `published` listings visible to anon, drafts
--     visible to the owner only. DEFINER is required (not optional): the
--     `portfolio_items` table intentionally carries no anon SELECT policy
--     (public reads flow through whitelisted RPC projections, per EP-02-19),
--     so an INVOKER read could never serve anon viewers. This mirrors
--     `portfolio_public_profile_get` (DEFINER + STABLE + anon EXECUTE +
--     identical PLT004, whitelisted projection). Visibility stays
--     function-enforced; `auth.uid()` still resolves the caller under
--     DEFINER, so owner-vs-anon gating is unchanged.
--   - Linking is staging: allowed on `draft`/`published`/`paused` so owners can
--     prepare proof before publishing. Publish/offer gates stay in EP-03-01
--     (`trade_verification_status == APPROVED`); this migration adds no trade
--     or KYC check. `archived`/`reported` listings reject links (PLT005).
--   - Envelope `{success, code, message, data}` with PLT000/001/003/004/005;
--     identical PLT004 for unknown vs non-visible listings/items (no oracle).
--     Write RPCs use `platform_raise_error`; the anon-capable read raises
--     inline (anon holds no EXECUTE on `platform_raise_error`).

-- =============================================================================
-- SECTION 1: Junction table
-- =============================================================================
create table if not exists public.service_listing_portfolio_links (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.service_listings(id) on delete cascade,
  portfolio_item_id uuid not null references public.portfolio_items(id) on delete cascade,
  entity_id uuid not null references public.entities(id) on delete cascade,
  sort_order integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint service_listing_portfolio_links_unique unique (listing_id, portfolio_item_id)
);

comment on table public.service_listing_portfolio_links is
  'EP-03-15 proof-of-work links: one row per (service_listing, portfolio_item). Ordering authority is sort_order (per-listing curation, set from the link array position), not portfolio_items.sort_order. UNIQUE doubles as the idempotency guard for full-replace retry/replay.';

create index if not exists service_listing_portfolio_links_listing_sort_idx
  on public.service_listing_portfolio_links (listing_id, sort_order);

create index if not exists service_listing_portfolio_links_item_idx
  on public.service_listing_portfolio_links (portfolio_item_id);

drop trigger if exists service_listing_portfolio_links_set_updated_at
  on public.service_listing_portfolio_links;
create trigger service_listing_portfolio_links_set_updated_at
  before update on public.service_listing_portfolio_links
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: RLS (default-deny; no anon policy — public visibility is gated
-- inside service_listing_portfolio_list, mirroring portfolio_public_profile_get)
-- =============================================================================
alter table public.service_listing_portfolio_links enable row level security;
revoke all on public.service_listing_portfolio_links
  from anon, authenticated, service_role;
grant select, insert, update, delete on public.service_listing_portfolio_links
  to authenticated;
grant select on public.service_listing_portfolio_links
  to service_role;

drop policy if exists service_listing_portfolio_links_select_own
  on public.service_listing_portfolio_links;
create policy service_listing_portfolio_links_select_own
  on public.service_listing_portfolio_links
  for select
  to authenticated
  using (entity_id = auth.uid());

drop policy if exists service_listing_portfolio_links_insert_own
  on public.service_listing_portfolio_links;
create policy service_listing_portfolio_links_insert_own
  on public.service_listing_portfolio_links
  for insert
  to authenticated
  -- Mirrors service_listing_media_insert_own: the row must be caller-owned
  -- AND the listing must be caller-owned, so no stranger can attach rows to
  -- another professional's listing outside the ownership-guarded RPCs.
  with check (
    entity_id = auth.uid()
    and exists (
      select 1
        from public.service_listings sl
       where sl.id = service_listing_portfolio_links.listing_id
         and sl.entity_id = auth.uid()
    )
  );

drop policy if exists service_listing_portfolio_links_update_own
  on public.service_listing_portfolio_links;
create policy service_listing_portfolio_links_update_own
  on public.service_listing_portfolio_links
  for update
  to authenticated
  using (entity_id = auth.uid())
  with check (
    entity_id = auth.uid()
    and exists (
      select 1
        from public.service_listings sl
       where sl.id = service_listing_portfolio_links.listing_id
         and sl.entity_id = auth.uid()
    )
  );

drop policy if exists service_listing_portfolio_links_delete_own
  on public.service_listing_portfolio_links;
create policy service_listing_portfolio_links_delete_own
  on public.service_listing_portfolio_links
  for delete
  to authenticated
  using (entity_id = auth.uid());

-- =============================================================================
-- SECTION 2b: portfolio_items owner SELECT (additive; required by the link
-- RPC ownership guard)
-- =============================================================================
-- The `portfolio_items` table ships owner INSERT/UPDATE/DELETE policies plus
-- a SELECT *grant* but no SELECT *policy* (public reads flow exclusively
-- through `portfolio_public_profile_get`). Without an owner SELECT policy,
-- no SECURITY INVOKER function — including the link RPC below — can verify
-- item ownership server-side. This additive owner-only policy activates the
-- existing grant for owners; anon access stays at zero policies and the
-- `portfolio_public_profile_get` posture is unchanged (EP-02-19 pgTAP 018
-- asserts name-specific policies plus no-anon, all preserved).
drop policy if exists portfolio_items_authenticated_select_own
  on public.portfolio_items;
create policy portfolio_items_authenticated_select_own
  on public.portfolio_items
  for select
  to authenticated
  using (entity_id = auth.uid());

-- =============================================================================
-- SECTION 3: service_listing_link_portfolio_items (full-replace, owner-only)
-- =============================================================================
create or replace function public.service_listing_link_portfolio_items(
  p_listing_id uuid,
  p_portfolio_ids uuid[]
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_listing_entity uuid;
  v_listing_status text;
  v_ids uuid[];
  v_found integer;
  v_owned integer;
  v_linked_ids jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  if p_portfolio_ids is null or cardinality(p_portfolio_ids) = 0 then
    perform public.platform_raise_error('PLT003', 'Select at least one portfolio item.');
  end if;

  if cardinality(p_portfolio_ids) > 8 then
    perform public.platform_raise_error('PLT003', 'Link at most 8 portfolio items per service.');
  end if;

  -- Deduplicate defensively; a duplicate set is a client shape error.
  -- NOTE: the unnest output column must be aliased (`as x(id)`); without it
  -- the column is named `unnest` and `distinct x` would aggregate whole
  -- records, silently matching zero rows below.
  select coalesce(array_agg(distinct x.id order by x.id), '{}'::uuid[])
    into v_ids
    from unnest(p_portfolio_ids) as x(id);
  if cardinality(v_ids) <> cardinality(p_portfolio_ids) then
    perform public.platform_raise_error('PLT003', 'Duplicate portfolio items are not allowed.');
  end if;

  -- Serialize concurrent full-replace saves per listing with a
  -- transaction-scoped advisory lock (released at commit/rollback). This
  -- avoids relying on row-lock privileges under the RLS-restricted grants;
  -- the UNIQUE constraint remains the idempotency backstop.
  perform pg_advisory_xact_lock(
    hashtext('service_listing_proof:' || p_listing_id::text)
  );

  -- Lock-free parent read (ownership + status gate below).
  select l.entity_id, l.status
    into v_listing_entity, v_listing_status
    from public.service_listings l
   where l.id = p_listing_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_listing_entity is distinct from v_actor then
    perform public.platform_raise_error('PLT001', 'You can only link proof to your own listings.');
  end if;

  if v_listing_status not in ('draft', 'published', 'paused') then
    perform public.platform_raise_error('PLT005', 'Proof can only be linked to draft, published, or paused listings.');
  end if;

  -- Unknown ids (count mismatch) share one identical PLT004 (no oracle).
  select count(*)::int
    into v_found
    from public.portfolio_items pi
   where pi.id = any (v_ids);
  if v_found <> cardinality(v_ids) then
    perform public.platform_raise_error('PLT004', 'Portfolio item not found.');
  end if;

  -- Ownership guard (defense-in-depth for service_role callers, who bypass
  -- RLS): every item must belong to the caller and to the listing's entity.
  -- Authenticated callers can only *see* owned rows through RLS, so for them
  -- an unowned id already failed the existence check above with the identical
  -- PLT004 (no existence oracle); this branch never identifies the id.
  select count(*)::int
    into v_owned
    from public.portfolio_items pi
   where pi.id = any (v_ids)
     and pi.entity_id = v_actor
     and pi.entity_id = v_listing_entity;
  if v_owned <> cardinality(v_ids) then
    perform public.platform_raise_error('PLT001', 'You can only link your own portfolio items.');
  end if;

  delete from public.service_listing_portfolio_links l
   where l.listing_id = p_listing_id;

  insert into public.service_listing_portfolio_links
    (listing_id, portfolio_item_id, entity_id, sort_order)
  select p_listing_id, id_with_ord.id, v_actor, id_with_ord.ord
    from unnest(v_ids) with ordinality as id_with_ord(id, ord)
  on conflict (listing_id, portfolio_item_id) do nothing;

  select coalesce(jsonb_agg(l.portfolio_item_id order by l.sort_order, l.created_at), '[]'::jsonb)
    into v_linked_ids
    from public.service_listing_portfolio_links l
   where l.listing_id = p_listing_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Portfolio proof linked.',
    'data', jsonb_build_object(
      'listing_id', p_listing_id,
      'linked_ids', v_linked_ids,
      'count', jsonb_array_length(v_linked_ids)
    )
  );
end;
$$;

comment on function public.service_listing_link_portfolio_items(uuid, uuid[]) is
  'Security invoker, VOLATILE. Full-replace proof linkage (EP-03-15): caller must own the listing and every item under the same entity_id. Cap 8, dedup enforced, archived/reported rejected (PLT005). UNIQUE + per-listing advisory lock make retry/replay idempotent. Linking is staging — publish gates stay in EP-03-01.';

-- =============================================================================
-- SECTION 4: service_listing_unlink_portfolio_item (single-remove, idempotent)
-- =============================================================================
create or replace function public.service_listing_unlink_portfolio_item(
  p_listing_id uuid,
  p_portfolio_item_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_listing_entity uuid;
  v_removed boolean := false;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  if p_portfolio_item_id is null then
    perform public.platform_raise_error('PLT003', 'Portfolio item id is required.');
  end if;

  select l.entity_id
    into v_listing_entity
    from public.service_listings l
   where l.id = p_listing_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_listing_entity is distinct from v_actor then
    perform public.platform_raise_error('PLT001', 'You can only unlink proof from your own listings.');
  end if;

  delete from public.service_listing_portfolio_links l
   where l.listing_id = p_listing_id
     and l.portfolio_item_id = p_portfolio_item_id
     and l.entity_id = v_actor;

  if found then
    v_removed := true;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Portfolio proof unlinked.',
    'data', jsonb_build_object(
      'listing_id', p_listing_id,
      'portfolio_item_id', p_portfolio_item_id,
      'removed', v_removed
    )
  );
end;
$$;

comment on function public.service_listing_unlink_portfolio_item(uuid, uuid) is
  'Security invoker, VOLATILE. Owner-only single proof removal (EP-03-15). Idempotent: absent links return PLT000 with removed=false.';

-- =============================================================================
-- SECTION 5: service_listing_portfolio_list (public read, published-only)
-- =============================================================================
create or replace function public.service_listing_portfolio_list(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_entity uuid;
  v_status text;
  v_items jsonb;
begin
  if p_listing_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PLT003: Listing id is required.',
      detail  = 'PLT003';
  end if;

  select l.entity_id, l.status
    into v_entity, v_status
    from public.service_listings l
   where l.id = p_listing_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'PLT004: Listing not found.',
      detail  = 'PLT004';
  end if;

  -- Drafts and other private states are visible to the owner only; everyone
  -- else receives the identical PLT004 (no existence oracle).
  if v_status <> 'published'
     and (v_actor is null or v_actor is distinct from v_entity) then
    raise exception using
      errcode = 'P0001',
      message = 'PLT004: Listing not found.',
      detail  = 'PLT004';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
            'id', pi.id,
            'item_type', pi.item_type,
            'title', pi.title,
            'description', pi.description,
            'media_path', pi.media_path,
            'sort_order', pi.sort_order,
            'link_sort_order', l.sort_order
          ) order by l.sort_order nulls last, pi.created_at), '[]'::jsonb)
    into v_items
    from public.service_listing_portfolio_links l
    join public.portfolio_items pi on pi.id = l.portfolio_item_id
   where l.listing_id = p_listing_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing proof retrieved.',
    'data', jsonb_build_object(
      'listing_id', p_listing_id,
      'items', v_items,
      'count', jsonb_array_length(v_items)
    )
  );
end;
$$;

comment on function public.service_listing_portfolio_list(uuid) is
  'Security definer, STABLE. Public read of linked proof for published listings (anon capable); owner read of private states. DEFINER mirrors portfolio_public_profile_get: the underlying tables carry no anon SELECT policy, so public reads flow through this whitelisted projection only. Identical PLT004 for unknown or non-visible listings (no enumeration oracle). Server order (link sort_order, then created_at) is authoritative — clients render it verbatim.';

-- =============================================================================
-- SECTION 6: EXECUTE grants (list is anon-capable; writes are owner-gated)
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_listing_link_portfolio_items(uuid, uuid[])
  to authenticated, service_role;
grant execute on function public.service_listing_unlink_portfolio_item(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.service_listing_portfolio_list(uuid)
  to anon, authenticated, service_role;

-- =============================================================================
-- SECTION 7: Realtime exclusion (proof links never stream; detail refetches)
-- =============================================================================
do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'service_listing_portfolio_links'
  ) then
    alter publication supabase_realtime
      drop table public.service_listing_portfolio_links;
  end if;
end;
$$;
