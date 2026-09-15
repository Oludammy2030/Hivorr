-- EP-02-19: Professional Profile & Credential Display System
--
-- Single additive migration adding:
--   1. portfolio_items table (owner self-CRUD, anon zero grants, realtime-excluded)
--   2. portfolio_public_profile_get(uuid) SECURITY DEFINER RPC — the sole public
--      read path for professional profile data
--
-- SECURITY POSTURE
--   * anon/authenticated retain zero table-level SELECT on portfolio_items
--     (default-deny). Public reads traverse only the SECURITY DEFINER RPC.
--   * Owner self-CRUD (insert/update/delete) via RLS (auth.uid() = entity_id).
--   * Column whitelist enforced by explicit SELECT projections inside the RPC:
--     legal_name, document_path, reviewed_by, rejection_reason, KYC limits
--     never leave the server.
--   * Approved-gate: PLT004 (identical message) for nonexistent, inactive, or
--     zero-approved-profession entities — no enumeration oracle.
--
-- IDEMPOTENCY
--   This is a new migration; no prior file is modified. Safe to re-apply in dev.
--
-- Ordered after 20260911090002_demo_identity_seed.sql.

-- ─── 1. portfolio_items table ────────────────────────────────────────────────
create table public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  item_type text,
  title text,
  description text,
  media_path text,
  sort_order integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint portfolio_items_item_type_allowed check (
    item_type is null or item_type in ('image', 'video', 'document', 'link')
  ),
  constraint portfolio_items_title_length check (
    title is null or char_length(btrim(title)) between 1 and 255
  ),
  constraint portfolio_items_description_length check (
    description is null or char_length(description) <= 5000
  ),
  constraint portfolio_items_media_path_format check (
    media_path is null
    or media_path like 'portfolio-items/' || entity_id::text || '/%'
  )
);

create index portfolio_items_entity_sort_idx
  on public.portfolio_items (entity_id, sort_order);

comment on table public.portfolio_items is
  'Owner-managed work samples / project showcase for the public professional profile. Default-deny anon: public reads go through portfolio_public_profile_get (SECURITY DEFINER) only.';
comment on column public.portfolio_items.media_path is
  'Storage object reference under portfolio-items/{entity_id}/{item_id}/{file}. CHECK enforces path-RLS parity with the storage bucket policy.';
comment on column public.portfolio_items.entity_id is
  'Owner entity. RLS enforces auth.uid() = entity_id for all writes.';

-- ─── 2. platform_set_updated_at trigger ─────────────────────────────────────
create trigger portfolio_items_set_updated_at
  before update on public.portfolio_items
  for each row
  execute function public.platform_set_updated_at();

-- ─── 3. RLS enablement ──────────────────────────────────────────────────────
alter table public.portfolio_items enable row level security;

-- ─── 4. RLS policies (owner self-CRUD; no anon policy) ──────────────────────
create policy portfolio_items_authenticated_insert
  on public.portfolio_items for insert to authenticated
  with check (entity_id = auth.uid());

create policy portfolio_items_authenticated_update
  on public.portfolio_items for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

create policy portfolio_items_authenticated_delete
  on public.portfolio_items for delete to authenticated
  using (entity_id = auth.uid());

comment on policy portfolio_items_authenticated_insert on public.portfolio_items is
  'Owner-scoped insert: entity_id must match the authenticated caller.';
comment on policy portfolio_items_authenticated_update on public.portfolio_items is
  'Owner-scoped update: entity_id must match the authenticated caller.';
comment on policy portfolio_items_authenticated_delete on public.portfolio_items is
  'Owner-scoped delete: entity_id must match the authenticated caller.';

-- ─── 5. Default-deny revokes (belt & suspenders) ────────────────────────────
revoke all on table public.portfolio_items from anon, authenticated;

-- ─── 6. Table-level grants ──────────────────────────────────────────────────
grant select, insert, update, delete on table public.portfolio_items to authenticated;
grant select on table public.portfolio_items to service_role;

-- ─── 7. Realtime exclusion ──────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'portfolio_items'
  ) then
    alter publication supabase_realtime
      drop table public.portfolio_items;
  end if;
end;
$$;

-- ─── 8. RPC: portfolio_public_profile_get ────────────────────────────────────
-- SECURITY DEFINER: executes as migration owner; bypasses RLS inside the
-- function body. anon holds zero table grants outside this function.
-- STABLE: eligible for PostgREST response caching.
-- Column whitelist enforced by explicit SELECT projections (never SELECT *).
-- Approved-gate: entity must be active AND have ≥1 approved trade profession.
-- Identical PLT004 for unknown/inactive/unapproved — no enumeration oracle.
create or replace function public.portfolio_public_profile_get(
  p_entity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_entity public.entities;
  v_profile public.entity_profiles;
  v_approved_count int;
  v_kyc jsonb;
  v_professions jsonb;
  v_credentials jsonb;
  v_portfolio_items jsonb;
  v_profession_slug text;
  v_profession_name text;
  v_industry_slug text;
  v_industry_name text;
  v_data jsonb;
begin
  -- PLT003: null entity id
  if p_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Entity id is required.');
  end if;

  -- Entity must exist and be active
  select * into v_entity
    from public.entities
   where id = p_entity_id;

  if not found or v_entity.status <> 'active' then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- Approved-gate: at least one approved trade profession (AGENT.md Rule 2)
  select count(*) into v_approved_count
    from public.entity_professions ep
   where ep.entity_id = p_entity_id
     and ep.trade_verification_status = 'approved';

  if v_approved_count = 0 then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- Profile (whitelisted columns only — never legal_name)
  select display_name, avatar_path, bio, country_code
    into v_profile
    from public.entity_profiles
   where entity_id = p_entity_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Professional profile not found.');
  end if;

  -- Approved professions (whitelisted: id, profession_id, is_primary; never verified_at/verified_by)
  -- joined with profession + industry for slug/name badges and SEO route
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', ep.id,
    'profession_id', ep.profession_id,
    'is_primary', ep.is_primary,
    'profession_slug', p.slug,
    'profession_name', p.name,
    'industry_slug', ind.slug,
    'industry_name', ind.name
  ) order by ep.is_primary desc, ep.created_at), '[]'::jsonb)
    into v_professions
    from public.entity_professions ep
    join public.professions p on p.id = ep.profession_id
    join public.industries ind on ind.id = p.industry_id
   where ep.entity_id = p_entity_id
     and ep.trade_verification_status = 'approved';

  -- Derive primary profession slug/name and industry slug/name for SEO route
  select p.slug, p.name, ind.slug, ind.name
    into v_profession_slug, v_profession_name, v_industry_slug, v_industry_name
    from public.entity_professions ep
    join public.professions p on p.id = ep.profession_id
    join public.industries ind on ind.id = p.industry_id
   where ep.entity_id = p_entity_id
     and ep.trade_verification_status = 'approved'
     and ep.is_primary = true
   limit 1;

  -- If no primary flag, fall back to first approved profession
  if v_profession_slug is null then
    select p.slug, p.name, ind.slug, ind.name
      into v_profession_slug, v_profession_name, v_industry_slug, v_industry_name
      from public.entity_professions ep
      join public.professions p on p.id = ep.profession_id
      join public.industries ind on ind.id = p.industry_id
     where ep.entity_id = p_entity_id
       and ep.trade_verification_status = 'approved'
     order by ep.created_at
     limit 1;
  end if;

  -- Approved credentials (whitelisted: kind, title, verification_status; never document_path/reviewed_by/rejection_reason)
  select coalesce(jsonb_agg(jsonb_build_object(
    'kind', ec.kind,
    'title', ec.title,
    'verification_status', ec.verification_status
  )), '[]'::jsonb)
    into v_credentials
    from public.entity_credentials ec
   where ec.entity_id = p_entity_id
     and ec.verification_status = 'approved';

  -- KYC level indicator (read-only tier code + status; never limits)
  select coalesce(jsonb_build_object(
    'tier_code', kt.tier_code,
    'status', ekl.status
  ), '{}'::jsonb)
    into v_kyc
    from public.entity_kyc_levels ekl
    left join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = p_entity_id;

  -- Portfolio items (whitelisted: id, item_type, title, description, media_path, sort_order; never entity_id, created_by)
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', pi.id,
    'item_type', pi.item_type,
    'title', pi.title,
    'description', pi.description,
    'media_path', pi.media_path,
    'sort_order', pi.sort_order
  ) order by pi.sort_order nulls last, pi.created_at), '[]'::jsonb)
    into v_portfolio_items
    from public.portfolio_items pi
   where pi.entity_id = p_entity_id;

  -- Assembly
  v_data := jsonb_build_object(
    'entity_id',       v_entity.id,
    'display_name',    v_profile.display_name,
    'avatar_path',     v_profile.avatar_path,
    'bio',             v_profile.bio,
    'country_code',    v_profile.country_code,
    'professions',     v_professions,
    'credentials',     v_credentials,
    'kyc',             v_kyc,
    'portfolio_items', v_portfolio_items,
    'profession_slug', v_profession_slug,
    'profession_name', v_profession_name,
    'industry_slug',   v_industry_slug,
    'industry_name',   v_industry_name
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Professional profile retrieved.',
    'data', v_data
  );
end;
$$;

comment on function public.portfolio_public_profile_get(uuid) is
  'Public professional profile read. SECURITY DEFINER with whitelisted column projection (never legal_name, document_path, or KYC limits). Approved-gate: entity active + ≥1 approved trade profession. PLT004 for unknown/inactive/unapproved. STABLE. EXECUTE granted to anon, authenticated, service_role.';

-- ─── 9. EXECUTE grants: anon receives only this RPC ─────────────────────────
revoke execute on all functions in schema public from public;

grant execute on function public.portfolio_public_profile_get(uuid) to anon, authenticated, service_role;
