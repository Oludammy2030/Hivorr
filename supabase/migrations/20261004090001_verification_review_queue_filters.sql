-- Professional Verification Queue: server-side queue filters (Phase 3).
--
-- Grows `verification_review_queue_get` with three optional filters so
-- triage works across pages instead of only over the loaded page:
--
--   - p_search: case-insensitive substring match over entity display name,
--     legal name, and credential title. Blank is a no-op.
--   - p_profession_id: restricts to one profession (via the credential).
--   - p_sort: 'newest' (submitted_at desc, default), 'oldest'
--     (submitted_at asc), or 'name' (display name asc, case-insensitive).
--
-- The row shape is UNCHANGED (the 16 canonical keys asserted by test 021),
-- and `p_status` keeps its default ('pending'): the client still owns the
-- pending/in_review chip locally. The old 4-arg overload is dropped so
-- PostgREST resolves named args to exactly one function (same pattern as
-- migration 20260917090001); positional 3-arg and 4-arg calls keep working
-- through defaults. New filter behavior is asserted by test 040.

drop function if exists public.verification_review_queue_get(text, int, int, text);

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
    'trade_proof', 'identity_document', 'certification'
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
   where (p_status is null or vs.status = p_status)
     and (p_submission_type is null or vs.submission_type = p_submission_type)
     and (p_profession_id is null or ec.profession_id = p_profession_id)
     and (
       v_search is null
       or ep.display_name ilike '%' || v_search || '%'
       or coalesce(ep.legal_name, '') ilike '%' || v_search || '%'
       or coalesce(ec.title, '') ilike '%' || v_search || '%'
     );

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_submissions
    from (
      select jsonb_build_object(
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
      ) as entry
      from public.verification_submissions vs
      join public.entity_profiles ep on ep.entity_id = vs.entity_id
      left join public.entity_credentials ec on ec.id = vs.credential_id
      left join public.professions pr on pr.id = ec.profession_id
     where (p_status is null or vs.status = p_status)
       and (p_submission_type is null or vs.submission_type = p_submission_type)
       and (p_profession_id is null or ec.profession_id = p_profession_id)
       and (
         v_search is null
         or ep.display_name ilike '%' || v_search || '%'
         or coalesce(ep.legal_name, '') ilike '%' || v_search || '%'
         or coalesce(ec.title, '') ilike '%' || v_search || '%'
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
  'Paginated admin review queue. Returns submissions joined with entity/credential/profession metadata. Admin-gated. Filters by status, submission type, free-text search (display/legal/credential), and profession; sorts newest/oldest/name. Row shape unchanged (test 021); filter behavior asserted by test 040.';

grant execute on function public.verification_review_queue_get(text, int, int, text, text, uuid, text) to authenticated, service_role;
