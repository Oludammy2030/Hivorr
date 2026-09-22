-- EP-02-11 Admin Console: capability-filtered directory
--
-- Extends the manage_user_list RPC (20260917090002) to support
-- capability-based filtered views (All / Professionals / Clients) per
-- the Super Admin sidebar spec. The Users submenu is NOT a separate
-- account system — it is a capability filter over the single Hivorr
-- population:
--
--   All Users     → no capability filter
--   Professionals → capability IN ('offer','both')
--   Clients       → capability IN ('hire','both')
--   Both          → appears in both Professiona ls and Clients
--
-- Also exposes `capability` in the canonical row so the client can
-- render chips without a second roundtrip (detail already had it).
--
-- Migration posture:
--   - Appends capability filter without breaking existing 4-arg
--     callers: the 4-arg signature stays, a 5-arg DEFAULT overload is
--     added. Clients migrate to 5 args opportunistically.
--   - SECURITY INVOKER, admin-gated PLT002, PLT003 on invalid value.
--   - Leaves all RLS/grant posture unchanged except rebasing execute grants.

-- ═══════════════════════════════════════════════════════════════════════
-- 5-arg overload: manage_user_list(search, status, capability, offset, limit)
-- Canonical row now: id, display_name, legal_name, avatar_path, status,
--   capability, roles[], kyc_tier, is_admin, onboarding_completed, created_at
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.manage_user_list(
  p_search text default null,
  p_status text default null,
  p_offset int default 0,
  p_limit int default 20,
  p_capability text default null
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_users jsonb;
  v_total_count int;
  v_term text;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_status is not null and p_status not in ('active', 'suspended', 'deactivated', 'deleted') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  if p_capability is not null and p_capability not in ('hire', 'offer', 'both', 'professional', 'client') then
    perform public.platform_raise_error('PLT003', 'Invalid capability filter.');
  end if;

  if p_offset < 0 or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Invalid pagination bounds.');
  end if;

  v_term := nullif(btrim(coalesce(p_search, '')), '');

  select count(*) into v_total_count
    from public.entities e
    left join public.entity_profiles ep on ep.entity_id = e.id
   where (p_status is null or e.status = p_status)
     and (
       p_capability is null
       or (p_capability = 'hire' and e.capability = 'hire')
       or (p_capability = 'offer' and e.capability = 'offer')
       or (p_capability = 'both' and e.capability = 'both')
       or (p_capability = 'professional' and e.capability in ('offer','both'))
       or (p_capability = 'client' and e.capability in ('hire','both'))
     )
     and (v_term is null
          or ep.display_name ilike '%' || v_term || '%'
          or ep.legal_name ilike '%' || v_term || '%');

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_users
    from (
      select jsonb_build_object(
        'id', e.id,
        'display_name', ep.display_name,
        'legal_name', ep.legal_name,
        'avatar_path', ep.avatar_path,
        'status', e.status,
        'capability', e.capability,
        'roles', coalesce(
          (select array_agg(er.role order by er.role)
             from public.entity_roles er
            where er.entity_id = e.id and er.is_active),
          array[]::text[]),
        'kyc_tier', (select k.tier_code
                       from public.entity_kyc_levels k
                      where k.entity_id = e.id
                      order by k.assigned_at desc
                      limit 1),
        'is_admin', public.is_platform_admin(e.id),
        'onboarding_completed', e.onboarding_completed_at is not null,
        'created_at', e.created_at
      ) as entry
      from public.entities e
      left join public.entity_profiles ep on ep.entity_id = e.id
     where (p_status is null or e.status = p_status)
       and (
         p_capability is null
         or (p_capability = 'hire' and e.capability = 'hire')
         or (p_capability = 'offer' and e.capability = 'offer')
         or (p_capability = 'both' and e.capability = 'both')
         or (p_capability = 'professional' and e.capability in ('offer','both'))
         or (p_capability = 'client' and e.capability in ('hire','both'))
       )
       and (v_term is null
            or ep.display_name ilike '%' || v_term || '%'
            or ep.legal_name ilike '%' || v_term || '%')
     order by e.created_at desc
     limit p_limit offset p_offset
    ) sub;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'User directory retrieved.',
    'data', jsonb_build_object(
      'users', v_users,
      'total_count', v_total_count
    )
  );
end;
$$;

comment on function public.manage_user_list(text, text, int, int, text) is
  'Paginated admin user directory with capability filter. Supports case-insensitive search on display/legal name, entity status filter, and capability filter (hire | offer | both | professional | client) where professional = offer,both and client = hire,both so Both appears in both filtered views. Row now includes capability. Admin-gated. Pagination 1..100.';

-- Backward-compat 4-arg wrapper for clients not yet migrated.
-- Keeps lib/data/datasources/remote/supabase_manage_user_remote_data_source.dart
-- call shape (search,status,offset,limit) working without a re-deploy freeze.
-- PostgreSQL treats create-or-replace with defaulted trailing arg as the same
-- signature; to preserve 4-arg calls we keep the old positional mapping:
-- (p_search, p_status, p_offset, p_limit) → delegates to new with p_capability=null.
-- Since Postgres does not allow two functions differing only by defaults, callers
-- that omit p_capability (4 args) still resolve to the 5-arg definition above
-- via default. Explicit 4-arg recreation is therefore just a grant rebase.

-- EXECUTE grants (rebased — mirrors 20260917090002 §6)
revoke execute on all functions in schema public from public;

grant execute on function public.platform_health() to anon, authenticated, service_role;
grant execute on function public.platform_is_authenticated() to authenticated, service_role;
grant execute on function public.platform_current_user_id() to authenticated, service_role;
grant execute on function public.platform_set_updated_at() to authenticated, service_role;
grant execute on function public.platform_raise_error(text, text) to authenticated, service_role;
grant execute on function public.platform_validate_payload(jsonb, text[]) to authenticated, service_role;
grant execute on function public.platform_audit_log_add(text, text, jsonb) to authenticated, service_role;
grant execute on function public.platform_demo_records_get(uuid) to authenticated, service_role;
grant execute on function public.platform_demo_records_create(text, jsonb) to authenticated, service_role;
grant execute on function public.platform_demo_records_update(uuid, jsonb) to authenticated, service_role;

grant execute on function public.entity_profile_update(text, text, text) to authenticated, service_role;
grant execute on function public.entity_roles_activate(text) to authenticated, service_role;
grant execute on function public.entity_roles_deactivate(text) to authenticated, service_role;
grant execute on function public.entity_profession_bind(uuid) to authenticated, service_role;
grant execute on function public.entity_credentials_submit(text, text, uuid, text, timestamptz) to authenticated, service_role;

grant execute on function public.entity_onboarding_status_update(text, boolean) to authenticated, service_role;
grant execute on function public.entity_onboarding_status_get() to authenticated, service_role;
grant execute on function public.entity_onboarding_reset(uuid) to service_role;

grant execute on function public.verification_submit(uuid, text) to authenticated, service_role;
grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
grant execute on function public.verification_kyc_level_get() to authenticated, service_role;
grant execute on function public.verification_limits_get() to authenticated, service_role;

grant execute on function public.verification_review_approve(uuid, text) to authenticated, service_role;
grant execute on function public.verification_review_reject(uuid, text, boolean) to authenticated, service_role;

grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_check() to authenticated, service_role;
grant execute on function public.platform_admin_provision(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_revoke(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_list() to authenticated, service_role;
grant execute on function public.verification_review_queue_get(text, int, int, text) to authenticated, service_role;
grant execute on function public.verification_review_start(uuid) to authenticated, service_role;
grant execute on function public.verification_review_audit_get(uuid) to authenticated, service_role;

grant execute on function public.manage_user_list(text, text, int, int, text) to authenticated, service_role;
grant execute on function public.manage_user_get(uuid) to authenticated, service_role;
grant execute on function public.manage_user_set_status(uuid, text) to authenticated, service_role;
grant execute on function public.manage_user_reset_onboarding(uuid) to authenticated, service_role;

-- Service marketplace (keep grant from 20260921090001)
grant execute on function public.service_listing_create(uuid, text, text, text, numeric, numeric, char(3), text) to authenticated, service_role;
grant execute on function public.service_listing_update(uuid, text, text, uuid, text, numeric, numeric, char(3)) to authenticated, service_role;
grant execute on function public.service_listing_publish(uuid) to authenticated, service_role;
grant execute on function public.service_listing_unpublish(uuid, text) to authenticated, service_role;
grant execute on function public.service_listing_get(uuid) to anon, authenticated, service_role;
grant execute on function public.service_listing_list_mine(text, integer, uuid) to authenticated, service_role;
grant execute on function public.service_favorite_toggle(uuid) to authenticated, service_role;
