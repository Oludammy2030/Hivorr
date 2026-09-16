-- EP-02-11: Manage User (Admin User Console)
--
-- Admin-gated user directory + lifecycle actions built on the Super Admin
-- system (20260916090001). Admins can search the entity directory, inspect a
-- single user's full posture (entity core, profile, roles, KYC, admin flag,
-- verification summary), suspend/reactivate an account, and reopen onboarding
-- (reset capability + completion stamp for re-onboarding).
--
-- ARCHITECTURE
--   1. manage_user_list            — paginated directory with search + status filters
--   2. manage_user_get             — single-user posture (nested canonical shape)
--   3. manage_user_set_status      — active / suspended / deactivated lifecycle
--   4. manage_user_reset_onboarding— admin re-onboarding (mirrors service-role reset)
--   5. Admin RLS policies          — entity_roles SELECT + entities UPDATE
--
-- DESIGN PRINCIPLES (EP-01-05, AGENT.md, inherited from 20260916090001)
--   - SECURITY INVOKER for all four functions; RLS applies inside every body
--   - Admin check is is_platform_admin() in the body — the EXECUTE grant is
--     NOT the access control gate (the body guard is)
--   - Guards never create a lockout: no self-suspension, no suspension of a
--     platform admin, and the Reviewer keeps at least one active admin
--   - D5 guard triggers still protect privileged columns: capability /
--     onboarding_completed_at changes flow only through the reset RPC which
--     sets platform.rpc_invocation (direct PostgREST PATCH stays blocked)
--   - audits: both mutating RPCs use platform_audit_log_add (auth.uid() is
--     present for authenticated admins, so the dedicated trail stays limited to
--     the service-role reset path — 019 posture test unchanged)
--   - Envelope: {success, code, message, data}; codes PLT000..PLT999
--
-- MIGRATION POSTURE
--   - No DDL on existing migration files (Rule 3 write discipline); only new
--     policies/grants/functions
--   - Canonical shapes below are locked by supabase/tests/database/022_manage_user.sql
--     and consumed verbatim by the Flutter DTOs (lib/data/models/manage_user_dto.dart)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Admin RLS policy additions
-- ═══════════════════════════════════════════════════════════════════════════════

-- entity_roles: admin cross-entity read (directory + detail role summaries).
-- Base table SELECT grant to authenticated already exists (20260821090003).
create policy entity_roles_admin_select
  on public.entity_roles for select to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entity_roles_admin_select on public.entity_roles is
  'Admin cross-entity read: platform admins can view role assignments for the user directory.';

-- entities: admin UPDATE for lifecycle status + onboarding reset. Column-level
-- ACLs (update id, status, capability, onboarding_completed_at) plus the
-- entities_guard_onboarding_state trigger keep privileged writes RPC-gated.
create policy entities_admin_update
  on public.entities for update to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entities_admin_update on public.entities is
  'Admin cross-entity update: platform admins may set lifecycle status and (via the reset RPC, which sets platform.rpc_invocation) clear onboarding state. The guard trigger still blocks direct capability/completion PATCH.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. RPC: manage_user_list (paginated directory)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Canonical user row (data.users[]):
--   id, display_name, legal_name, avatar_path, status, roles[], kyc_tier,
--   is_admin, onboarding_completed, created_at

create or replace function public.manage_user_list(
  p_search text default null,
  p_status text default null,
  p_offset int default 0,
  p_limit int default 20
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

  if p_offset < 0 or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Invalid pagination bounds.');
  end if;

  v_term := nullif(btrim(coalesce(p_search, '')), '');

  select count(*) into v_total_count
    from public.entities e
    left join public.entity_profiles ep on ep.entity_id = e.id
   where (p_status is null or e.status = p_status)
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

comment on function public.manage_user_list(text, text, int, int) is
  'Paginated admin user directory. Supports case-insensitive search on display/legal name and entity status filter. Returns the canonical user row shape (id, display_name, legal_name, avatar_path, status, roles, kyc_tier, is_admin, onboarding_completed, created_at). Admin-gated.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. RPC: manage_user_get (single-user posture)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Canonical detail shape (data.user):
--   entity  {id, status, capability, onboarding_completed_at, created_at}
--   profile {display_name, legal_name, bio, avatar_path, country_code}
--   roles   [{role, is_active, activated_at}]
--   kyc     {tier_code, status, assigned_at}
--   is_admin
--   summary {credential_count, approved_credentials, pending_submissions, total_submissions}

create or replace function public.manage_user_get(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_entity jsonb;
  v_profile jsonb;
  v_roles jsonb;
  v_kyc jsonb;
  v_summary jsonb;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_user_id is null then
    perform public.platform_raise_error('PLT003', 'User id is required.');
  end if;

  select jsonb_build_object(
           'id', e.id,
           'status', e.status,
           'capability', e.capability,
           'onboarding_completed_at', e.onboarding_completed_at,
           'created_at', e.created_at)
    into v_entity
    from public.entities e
   where e.id = p_user_id;

  if v_entity is null then
    perform public.platform_raise_error('PLT004', 'User not found.');
  end if;

  select jsonb_build_object(
           'display_name', ep.display_name,
           'legal_name', ep.legal_name,
           'bio', ep.bio,
           'avatar_path', ep.avatar_path,
           'country_code', ep.country_code)
    into v_profile
    from public.entity_profiles ep
   where ep.entity_id = p_user_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'role', er.role,
           'is_active', er.is_active,
           'activated_at', er.activated_at)
         order by er.role), '[]'::jsonb)
    into v_roles
    from public.entity_roles er
   where er.entity_id = p_user_id;

  select jsonb_build_object(
           'tier_code', k.tier_code,
           'status', k.status,
           'assigned_at', k.assigned_at)
    into v_kyc
    from public.entity_kyc_levels k
   where k.entity_id = p_user_id
   order by k.assigned_at desc
   limit 1;

  select jsonb_build_object(
           'credential_count', (select count(*) from public.entity_credentials ec where ec.entity_id = p_user_id),
           'approved_credentials', (select count(*) from public.entity_credentials ec where ec.entity_id = p_user_id and ec.verification_status = 'approved'),
           'pending_submissions', (select count(*) from public.verification_submissions vs where vs.entity_id = p_user_id and vs.status in ('pending', 'in_review')),
           'total_submissions', (select count(*) from public.verification_submissions vs where vs.entity_id = p_user_id))
    into v_summary;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'User posture retrieved.',
    'data', jsonb_build_object(
      'user', jsonb_build_object(
        'entity', v_entity,
        'profile', v_profile,
        'roles', v_roles,
        'kyc', v_kyc,
        'is_admin', public.is_platform_admin(p_user_id),
        'summary', v_summary
      )
    )
  );
end;
$$;

comment on function public.manage_user_get(uuid) is
  'Single-user admin posture: entity core, profile, role assignments, current KYC tier, admin flag, and verification summary counts. Admin-gated. PLT004 when the target does not exist.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. RPC: manage_user_set_status (lifecycle) and lockout guards
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.manage_user_set_status(
  p_user_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_status text;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_user_id is null then
    perform public.platform_raise_error('PLT003', 'User id is required.');
  end if;

  v_status := btrim(coalesce(p_status, ''));
  if v_status not in ('active', 'suspended', 'deactivated') then
    perform public.platform_raise_error('PLT003', 'Invalid status value.');
  end if;

  if p_user_id = v_actor then
    perform public.platform_raise_error('PLT005', 'Cannot change your own account status.');
  end if;

  if v_status <> 'active' and public.is_platform_admin(p_user_id) then
    perform public.platform_raise_error('PLT005', 'Cannot suspend a platform admin.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  -- updated_at is stamped by the entities_set_updated_at trigger; the
  -- authenticated column-level ACL has no updated_at grant (20260915090001).
  update public.entities
     set status = v_status
   where id = p_user_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'User not found.');
  end if;

  perform public.platform_audit_log_add(
    'manage_user_set_status',
    'entities',
    jsonb_build_object('user_id', p_user_id, 'status', v_status)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'User status updated.',
    'data', jsonb_build_object('user_id', p_user_id, 'status', v_status)
  );
end;
$$;

comment on function public.manage_user_set_status(uuid, text) is
  'Sets an entity lifecycle status (active | suspended | deactivated) as a platform admin. Lockout guards: cannot change your own status and cannot pull a platform admin out of active. `deleted` is intentionally excluded (hard lifecycle operator action). Audit-logged.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. RPC: manage_user_reset_onboarding (admin re-onboarding)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Mirrors entity_onboarding_reset (service-role) for the authenticated admin
-- path. Clears capability + completion stamp and appends to the existing
-- entity_onboarding_audit_trail with the same 'onboarding_reset' action.

create or replace function public.manage_user_reset_onboarding(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.entities;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_user_id is null then
    perform public.platform_raise_error('PLT003', 'User id is required.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  -- updated_at is stamped by the entities_set_updated_at trigger.
  update public.entities
     set capability = null,
         onboarding_completed_at = null
   where id = p_user_id
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'User not found.');
  end if;

  -- Authenticated admins carry auth.uid(), so platform_audit_log_add is
  -- usable here (unlike the service-role reset which needs the dedicated
  -- entity_onboarding_audit_trail); the trail keeps its zero-grant posture.
  perform public.platform_audit_log_add(
    'manage_user_reset_onboarding',
    'entities',
    jsonb_build_object('user_id', p_user_id)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Onboarding reset.',
    'data', jsonb_build_object(
      'user_id', p_user_id,
      'capability', v_row.capability,
      'onboarding_completed_at', v_row.onboarding_completed_at
    )
  );
end;
$$;

comment on function public.manage_user_reset_onboarding(uuid) is
  'Admin re-onboarding: clears capability and onboarding_completed_at for any entity (platform admins included, for support re-runs). Sets platform.rpc_invocation to pass the entities_guard_onboarding_state trigger. Audit-logged via platform_audit_log_add.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. EXECUTE grants
-- ═══════════════════════════════════════════════════════════════════════════════

-- Reset all function grants (belt & suspenders — mirrors 20260916090001 §16)
revoke execute on all functions in schema public from public;

-- Platform helpers
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

-- Entity model RPCs
grant execute on function public.entity_profile_update(text, text, text) to authenticated, service_role;
grant execute on function public.entity_roles_activate(text) to authenticated, service_role;
grant execute on function public.entity_roles_deactivate(text) to authenticated, service_role;
grant execute on function public.entity_profession_bind(uuid) to authenticated, service_role;
grant execute on function public.entity_credentials_submit(text, text, uuid, text, timestamptz) to authenticated, service_role;

-- Onboarding RPCs
grant execute on function public.entity_onboarding_status_update(text, boolean) to authenticated, service_role;
grant execute on function public.entity_onboarding_status_get() to authenticated, service_role;
grant execute on function public.entity_onboarding_reset(uuid) to service_role;

-- Verification entity-facing RPCs
grant execute on function public.verification_submit(uuid, text) to authenticated, service_role;
grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
grant execute on function public.verification_kyc_level_get() to authenticated, service_role;
grant execute on function public.verification_limits_get() to authenticated, service_role;

-- Verification review RPCs
grant execute on function public.verification_review_approve(uuid, text) to authenticated, service_role;
grant execute on function public.verification_review_reject(uuid, text, boolean) to authenticated, service_role;

-- Admin system RPCs
grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_check() to authenticated, service_role;
grant execute on function public.platform_admin_provision(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_revoke(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_list() to authenticated, service_role;
grant execute on function public.verification_review_queue_get(text, int, int, text) to authenticated, service_role;
grant execute on function public.verification_review_start(uuid) to authenticated, service_role;
grant execute on function public.verification_review_audit_get(uuid) to authenticated, service_role;

-- Manage User RPCs (NEW)
grant execute on function public.manage_user_list(text, text, int, int) to authenticated, service_role;
grant execute on function public.manage_user_get(uuid) to authenticated, service_role;
grant execute on function public.manage_user_set_status(uuid, text) to authenticated, service_role;
grant execute on function public.manage_user_reset_onboarding(uuid) to authenticated, service_role;