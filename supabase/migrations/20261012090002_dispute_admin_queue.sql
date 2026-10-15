-- =============================================================================
-- R3 (EP-03-17 follow-up): service-engagement dispute admin visibility
-- -----------------------------------------------------------------------------
-- Migration: 20261012090002_dispute_admin_queue.sql
-- Depends on: 20261011090001_service_dispute_contract_link.sql (contract_id,
--             service_dispute_get join shape)
--             20260916090001_super_admin_system.sql (is_platform_admin helper)
--
-- PURPOSE
--   Give platform admins a read-only, filterable view over ALL dispute cases
--   (frozen party-scoped RLS deliberately does not cover admins, so these
--   helpers are the only admin read path). Powers the filtered queue inside
--   the Admin shell; resolution stays service_role SQL/manual — no resolve
--   affordance is exposed here.
--
-- EXECUTION MODEL
--   - service_dispute_admin_list / service_dispute_admin_get are SECURITY
--     DEFINER with pinned search_path = pg_catalog, public (mirrors the
--     dispute hold helpers): they must read rows across all parties, which
--     party-scoped RLS forbids to `authenticated`. Narrowly scoped to SELECTs
--     only; both gate on is_platform_admin(auth.uid()) FIRST (PLT002
--     otherwise) and never write.
--   - Names are service_dispute_*-prefixed so the frozen EP-02-05 posture
--     audits (015/016 `dispute_%` object counts) stay green.
--   - Envelope: {success, code, message, data}; STABLE; idempotent DDL.
-- =============================================================================

-- =============================================================================
-- SECTION 1: service_dispute_admin_list (DEFINER, STABLE)
-- =============================================================================
create or replace function public.service_dispute_admin_list(
  p_status text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_items jsonb;
  v_total int;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Platform admin access required.');
  end if;
  if p_status is not null and p_status not in
     ('open', 'under_review', 'resolved', 'closed', 'withdrawn') then
    perform public.platform_raise_error('PLT003', 'Status filter is invalid.');
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;
  if p_offset is null or p_offset < 0 then
    perform public.platform_raise_error('PLT003', 'Offset must be zero or greater.');
  end if;

  select count(*)::int into v_total
    from public.dispute_cases d
   where (p_status is null or d.status = p_status);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.filed_at desc, x.id desc), '[]'::jsonb)
    into v_items
    from (
      select d.*,
             c.status as contract_status,
             c.escrow_id as contract_escrow_id,
             c.total_amount as contract_total,
             c.currency_code as contract_currency,
             s.title as listing_title,
             e.status as escrow_status
        from public.dispute_cases d
        left join public.service_contracts c on c.id = d.contract_id
        left join public.service_listings s on s.id = c.service_listing_id
        left join public.financial_escrow e on e.id = d.escrow_id
       where (p_status is null or d.status = p_status)
       order by d.filed_at desc, d.id desc
       limit p_limit offset p_offset
    ) x;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Admin disputes listed.',
    'data', jsonb_build_object('disputes', v_items, 'total_count', v_total)
  );
end;
$$;

-- =============================================================================
-- SECTION 2: service_dispute_admin_get (DEFINER, STABLE)
-- =============================================================================
create or replace function public.service_dispute_admin_get(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.dispute_cases%rowtype;
  v_evidence jsonb;
  v_resolution jsonb;
  v_contract jsonb;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Platform admin access required.');
  end if;
  if p_case_id is null then
    perform public.platform_raise_error('PLT003', 'Case id is required.');
  end if;

  select * into v_case
    from public.dispute_cases
   where id = p_case_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Dispute case not found.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
    into v_evidence
    from public.dispute_evidence e
   where e.case_id = v_case.id;

  select to_jsonb(r) into v_resolution
    from public.dispute_resolutions r
   where r.case_id = v_case.id;

  if v_case.contract_id is not null then
    select jsonb_build_object(
             'id', c.id,
             'status', c.status,
             'escrow_id', c.escrow_id,
             'total_amount', c.total_amount,
             'currency_code', c.currency_code,
             'service_listing_id', c.service_listing_id,
             'listing_title', s.title)
      into v_contract
      from public.service_contracts c
      left join public.service_listings s on s.id = c.service_listing_id
     where c.id = v_case.contract_id;
  else
    v_contract := null;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Admin dispute retrieved.',
    'data', jsonb_build_object(
      'case', to_jsonb(v_case),
      'evidence', coalesce(v_evidence, '[]'::jsonb),
      'resolution', v_resolution,
      'contract', v_contract)
  );
end;
$$;

-- =============================================================================
-- SECTION 3: GRANTs + COMMENTs
-- =============================================================================
revoke execute on function public.service_dispute_admin_list(text, int, int) from public, anon;
grant execute on function public.service_dispute_admin_list(text, int, int) to authenticated, service_role;

revoke execute on function public.service_dispute_admin_get(uuid) from public, anon;
grant execute on function public.service_dispute_admin_get(uuid) to authenticated, service_role;

comment on function public.service_dispute_admin_list(text, int, int) is
  'SECURITY DEFINER (pinned search_path), STABLE. Admin-gated (is_platform_admin, PLT002 otherwise) read-only queue over all dispute_cases with contract/escrow join + total_count. Never writes; resolution stays out of scope.';

comment on function public.service_dispute_admin_get(uuid) is
  'SECURITY DEFINER (pinned search_path), STABLE. Admin-gated single-case read (case + evidence + resolution + contract join). Never writes.';
