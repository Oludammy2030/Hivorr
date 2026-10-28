-- ─────────────────────────────────────────────────────────────────────────────
-- Business Admin Queue Extensions
--
-- Grows the existing admin queue additively:
--   - accepts submission_type = 'business_verification'
--   - searches business trading name, registered legal name and CAC number
--   - business rows additionally carry business_id / trading name / legal
--     name / CAC / business verification status
--
-- The 16 canonical keys asserted by test 021 are unchanged for non-business
-- rows; business keys are appended only for business_verification rows whose
-- credential is linked to a business. Signature, defaults, filters, sort and
-- `total_count` are preserved so existing clients and tests keep working.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.verification_review_queue_get(
  p_status text default 'pending',
  p_offset int default 0,
  p_limit int default 20,
  p_submission_type text default null,
  p_search text default null,
  p_profession_id uuid default null,
  p_sort text default 'newest'
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_sort text := coalesce(p_sort, 'newest');
  v_submissions jsonb;
  v_total_count int;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_status is not null and p_status not in (
    'pending', 'in_review', 'approved', 'rejected', 'requires_resubmission'
  ) then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  if p_submission_type is not null and p_submission_type not in (
    'trade_proof', 'identity_document', 'certification', 'business_verification'
  ) then
    perform public.platform_raise_error('PLT003', 'Invalid submission type filter.');
  end if;

  if v_sort not in ('newest', 'oldest', 'name') then
    perform public.platform_raise_error('PLT003', 'Invalid sort (newest/oldest/name).');
  end if;

  select count(*) into v_total_count
    from public.verification_submissions vs
    join public.entity_profiles ep on ep.entity_id = vs.entity_id
    left join public.entity_credentials ec on ec.id = vs.credential_id
    left join public.businesses b on b.id = ec.business_id
   where (p_status is null or vs.status = p_status)
     and (p_submission_type is null or vs.submission_type = p_submission_type)
     and (p_profession_id is null or ec.profession_id = p_profession_id)
     and (
       v_search is null
       or ep.display_name ilike '%' || v_search || '%'
       or coalesce(ep.legal_name, '') ilike '%' || v_search || '%'
       or coalesce(ec.title, '') ilike '%' || v_search || '%'
       or coalesce(b.trading_name, '') ilike '%' || v_search || '%'
       or coalesce(b.registered_legal_name, '') ilike '%' || v_search || '%'
       or coalesce(b.cac_number, '') ilike '%' || v_search || '%'
     );

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_submissions
    from (
      select (
        jsonb_build_object(
          'id', vs.id,
          'entity_id', vs.entity_id,
          'entity_display_name', ep.display_name,
          'entity_legal_name', ep.legal_name,
          'entity_avatar_path', ep.avatar_path,
          'credential_id', vs.credential_id,
          'credential_title', ec.title,
          'credential_kind', ec.kind,
          'document_path', ec.document_path,
          'profession_id', ec.profession_id,
          'profession_name', pr.name,
          'submission_type', vs.submission_type,
          'status', vs.status,
          'submitted_at', vs.submitted_at,
          'assigned_reviewer', vs.assigned_reviewer,
          'decision_notes', vs.decision_notes
        )
        || case
             when ec.business_id is not null
              and vs.submission_type = 'business_verification'
             then jsonb_build_object(
               'business_id', ec.business_id,
               'business_trading_name', b.trading_name,
               'business_legal_name', b.registered_legal_name,
               'business_cac_number', b.cac_number,
               'business_verification_status', b.verification_status
             )
             else '{}'::jsonb
           end
      ) as entry
      from public.verification_submissions vs
      join public.entity_profiles ep on ep.entity_id = vs.entity_id
      left join public.entity_credentials ec on ec.id = vs.credential_id
      left join public.professions pr on pr.id = ec.profession_id
      left join public.businesses b on b.id = ec.business_id
     where (p_status is null or vs.status = p_status)
       and (p_submission_type is null or vs.submission_type = p_submission_type)
       and (p_profession_id is null or ec.profession_id = p_profession_id)
       and (
         v_search is null
         or ep.display_name ilike '%' || v_search || '%'
         or coalesce(ep.legal_name, '') ilike '%' || v_search || '%'
         or coalesce(ec.title, '') ilike '%' || v_search || '%'
         or coalesce(b.trading_name, '') ilike '%' || v_search || '%'
         or coalesce(b.registered_legal_name, '') ilike '%' || v_search || '%'
         or coalesce(b.cac_number, '') ilike '%' || v_search || '%'
       )
     order by
       case when v_sort = 'name' then lower(ep.display_name) end asc,
       case when v_sort = 'oldest' then vs.submitted_at end asc,
       case when v_sort = 'newest' then vs.submitted_at end desc,
       vs.submitted_at desc
     limit p_limit offset p_offset
    ) sub;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Review queue retrieved.',
    'data', jsonb_build_object(
      'submissions', v_submissions,
      'total_count', v_total_count
    )
  );
end;
$$;

comment on function public.verification_review_queue_get(text, int, int, text, text, uuid, text) is
  'Paginated admin review queue. Returns submissions joined with entity/credential/profession metadata plus additive business identity fields for business_verification rows. Admin-gated. Filters by status, submission type (including business_verification), free-text search (display/legal/credential/business names/CAC), and profession; sorts newest/oldest/name.';

grant execute on function public.verification_review_queue_get(text, int, int, text, text, uuid, text) to authenticated, service_role;
