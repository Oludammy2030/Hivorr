-- Identity Phase 1b: professional display name per profession binding.
--
-- Adds `entity_professions.professional_display_name` (nullable, 1-120 chars
-- when present): the proposed public professional name collected during
-- professional onboarding. It rides the binding row and becomes effective
-- only when the binding's trade_verification_status flips to `approved`
-- (the Phase 2 context resolver reads it exclusively under approval).
--
-- `entity_profession_bind` gains optional `p_professional_display_name`
-- (old 1-arg overload dropped to avoid PostgREST ambiguity; all callers use
-- named params). RLS column grants extended for the new column only —
-- `trade_verification_status / verified_at / verified_by` stay excluded
-- (D5). `verification_status_get` projects the name per profession.

-- ─── 1. Column + CHECK ─────────────────────────────────────────────────────
alter table public.entity_professions
  add column if not exists professional_display_name text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'entity_professions_professional_name_length'
  ) then
    alter table public.entity_professions
      add constraint entity_professions_professional_name_length
      check (professional_display_name is null or char_length(btrim(professional_display_name)) between 1 and 120);
  end if;
end
$$;

comment on column public.entity_professions.professional_display_name is
  'Proposed public professional name for this binding (identity audit Phase 1b). Nullable until the professional supplies one; effective for display only when trade_verification_status = approved (enforced by readers, not here). Never a legal identity.';

-- ─── 2. RLS column grants (new column only; gate columns untouched) ─────────
grant select, insert (entity_id, profession_id, is_primary, professional_display_name),
  update (entity_id, profession_id, is_primary, professional_display_name)
  on table public.entity_professions to authenticated;

-- ─── 3. Bind RPC with optional professional name ─────────────────────────────
drop function if exists public.entity_profession_bind(uuid);

create or replace function public.entity_profession_bind(
  p_profession_id uuid,
  p_professional_display_name text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_professions;
  v_profession public.professions;
  v_name text;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;

  -- Verify profession exists and is active
  select * into v_profession
    from public.professions
   where id = p_profession_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if not v_profession.is_active then
    perform public.platform_raise_error('PLT004', 'Profession is not active.');
  end if;

  -- Optional professional name: validated when supplied, stored on the
  -- binding. It carries no privilege; approval still flips status alone.
  v_name := nullif(btrim(coalesce(p_professional_display_name, '')), '');
  if p_professional_display_name is not null then
    if v_name is null then
      perform public.platform_raise_error('PLT003', 'Professional name cannot be empty.');
    end if;
    if char_length(v_name) > 120 then
      perform public.platform_raise_error('PLT003', 'Professional name must be 120 characters or fewer.');
    end if;
  end if;

  -- Insert binding; trade_verification_status defaults to 'unverified'
  -- (kept out of invoker grants so it can only move via EP-02 admin paths)
  begin
    insert into public.entity_professions (entity_id, profession_id, is_primary, professional_display_name)
    values (auth.uid(), p_profession_id, false, v_name)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'Entity already bound to this profession.');
  end;

  perform public.platform_audit_log_add(
    'entity_profession_bind',
    'entity_professions',
    jsonb_build_object('profession_id', p_profession_id, 'has_professional_name', v_name is not null)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profession bound (unverified).',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_profession_bind(uuid, text) is
  'Binds a profession to the calling entity after validating existence and activity (PLT004 if missing/inactive). Duplicate bindings rejected (PLT005). Optional professional display name stored on the binding (validated 1-120 when supplied); effective for display only after trade approval (readers enforce). New bindings land as trade_verification_status = unverified — no client path to pending/approved (EP-02 admin gate). Audit-logged.';

grant execute on function public.entity_profession_bind(uuid, text) to authenticated, service_role;

-- ─── 4. verification_status_get projects the professional name ───────────────
create or replace function public.verification_status_get(
  p_entity_id uuid default null
)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
  v_tier_code text;
  v_tier_status text;
  v_daily numeric;
  v_weekly numeric;
  v_monthly numeric;
  v_cashout numeric;
  v_identity_verified boolean;
  v_trade jsonb;
  v_pending integer;
  v_total integer;
begin
  if v_actor is null then
    if p_entity_id is null then
      perform public.platform_raise_error('PLT003', 'Entity id is required for admin query.');
    end if;
    v_target := p_entity_id;
  else
    if p_entity_id is not null and p_entity_id <> v_actor then
      perform public.platform_raise_error('PLT004', 'Cannot view another entity''s verification status.');
    end if;
    v_target := v_actor;
  end if;

  select kt.tier_code, ekl.status, kt.daily_limit, kt.weekly_limit, kt.monthly_limit, kt.cashout_limit
    into v_tier_code, v_tier_status, v_daily, v_weekly, v_monthly, v_cashout
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_target;

  if not found then
    v_tier_code := 'tier_0';
    v_tier_status := 'unassigned';
    v_daily := 0; v_weekly := 0; v_monthly := 0; v_cashout := 0;
  end if;

  v_identity_verified := (v_tier_status = 'active' and v_tier_code >= 'tier_1');

  select jsonb_agg(
    jsonb_build_object(
      'profession_id', ep.profession_id,
      'trade_verification_status', ep.trade_verification_status,
      'professional_display_name', ep.professional_display_name
    )
  )
    into v_trade
    from public.entity_professions ep
   where ep.entity_id = v_target;

  select count(*) into v_pending
    from public.verification_submissions vs
   where vs.entity_id = v_target and vs.status in ('pending', 'in_review');

  select count(*) into v_total
    from public.verification_submissions vs
   where vs.entity_id = v_target;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Verification status retrieved.',
    'data', jsonb_build_object(
      'entity_id', v_target,
      'kyc', jsonb_build_object(
        'tier_code', v_tier_code,
        'status', v_tier_status,
        'limits', jsonb_build_object(
          'daily', v_daily,
          'weekly', v_weekly,
          'monthly', v_monthly,
          'cashout', v_cashout
        )
      ),
      'identity_verified', v_identity_verified,
      'trade_verifications', coalesce(v_trade, '[]'::jsonb),
      'pending_submissions', v_pending,
      'total_submissions', v_total
    )
  );
end;
$$;

comment on function public.verification_status_get(uuid) is
  'Aggregated verification status for an entity. Self-scoped for authenticated (cross-entity id raises PLT004); service_role may pass any p_entity_id. Returns KYC tier + limits, identity_verified flag, per-profession trade statuses (each with the proposed professional_display_name), and submission counts. SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
