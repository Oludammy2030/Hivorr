-- Identity Phase 3: project the approved professional name on the public
-- profile (identity audit Phase 2/3).
--
-- Extends `portfolio_public_profile_get` with one additive JSON key per
-- approved profession entry: `professional_display_name` (the name proposed
-- at profession bind, Phase 1b). The approved-gate, whitelist discipline,
-- and envelope are otherwise untouched — clients that ignore the key see
-- byte-identical behavior. The Phase 3 context resolver prefers this value
-- over the derived display name wherever an approved professional face is
-- required (marketplace, hiring, engagement headers).

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
  v_profile record;
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

  -- Approved professions (whitelisted: id, profession_id, is_primary,
  -- professional_display_name; never verified_at/verified_by)
  -- joined with profession + industry for slug/name badges and SEO route
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', ep.id,
    'profession_id', ep.profession_id,
    'is_primary', ep.is_primary,
    'professional_display_name', ep.professional_display_name,
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
  'Public professional profile read. SECURITY DEFINER with whitelisted column projection (never legal_name, document_path, or KYC limits). Approved-gate: entity active + ≥1 approved trade profession. Per-profession entries carry the approved professional_display_name for context-aware identity (Phase 3). PLT004 for unknown/inactive/unapproved. STABLE. EXECUTE granted to anon, authenticated, service_role.';

grant execute on function public.portfolio_public_profile_get(uuid) to anon, authenticated, service_role;
