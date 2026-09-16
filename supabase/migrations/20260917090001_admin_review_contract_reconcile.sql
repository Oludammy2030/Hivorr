-- EP-02-11: Admin review wire contract reconciliation
--
-- Locks the canonical admin review wire contract shared with the Flutter
-- client (EP-02-11 §5.2). The superseding super-admin system migration
-- (20260916090001) redefined the review RPCs with a compressing signature
-- while the client datasource still parsed the pre-super-admin shape. This
-- migration:
--
--   1. Grows verification_review_queue_get to accept p_submission_type so the
--      client's type filter survives cleanly (the screen filters by submission
--      type, not status). The output shape is unchanged and canonical:
--      data.submissions[] with the fixed key set asserted by test 021.
--   2. Re-grants the new signature only (the old (text, int, int) overload is
--      dropped so PostgREST resolves named args to exactly one function).
--
-- OUTPUT CONTRACT (canonical, asserted in supabase/tests/database/021):
--   verification_review_queue_get -> data { submissions[], total_count }
--     submissions[] keys: id, entity_id, entity_display_name,
--       entity_legal_name, entity_avatar_path, credential_id,
--       credential_title, credential_kind, document_path, profession_id,
--       profession_name, submission_type, status, submitted_at,
--       assigned_reviewer, decision_notes
--   verification_review_audit_get  -> data { audit_entries[] }
--     audit_entries[] keys: id, event_type, subject_type, subject_id,
--       from_state, to_state, actor_id, details, created_at
--   platform_admin_check           -> data { is_admin }
--
-- The client adopts this shape (admin_review_dto.dart), never the reverse.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. REPLACE verification_review_queue_get (add p_submission_type filter)
-- ═══════════════════════════════════════════════════════════════════════════════

drop function if exists public.verification_review_queue_get(text, int, int);

create or replace function public.verification_review_queue_get(
  p_status text default 'pending',
  p_offset int default 0,
  p_limit int default 20,
  p_submission_type text default null
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
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

  select count(*) into v_total_count
    from public.verification_submissions vs
   where (p_status is null or vs.status = p_status)
     and (p_submission_type is null or vs.submission_type = p_submission_type);

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
     order by vs.submitted_at desc
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

comment on function public.verification_review_queue_get(text, int, int, text) is
  'Paginated admin review queue. Returns submissions joined with entity/credential/profession metadata. Admin-gated. Filters by status and/or submission type (trade_proof/identity_document/certification). Canonical output shape asserted by test 021.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Grants (new signature only; the dropped (text, int, int) grant dies with it)
-- ═══════════════════════════════════════════════════════════════════════════════

grant execute on function public.verification_review_queue_get(text, int, int, text) to authenticated, service_role;