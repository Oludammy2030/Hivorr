-- Verification review profile RPC: ORDER BY scope fix.
--
-- Corrects 20261005090002_verification_review_profile_get, whose outer
-- jsonb_agg ORDER BY clauses referenced the inner subquery alias `e`
-- (not visible outside the derived table), raising
-- `missing FROM-clause entry for table "e"` on every call.
-- The subqueries already project the ordering keys, so the outer
-- aggregation now orders by the derived-table output columns.
--
-- Re-issue via CREATE OR REPLACE (SECURITY INVOKER preserved; existing
-- EXECUTE grants are kept, so no grant rebase here).

create or replace function public.verification_review_profile_get(
  p_submission_id uuid
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_entity_id uuid;
  v_experiences jsonb;
  v_educations jsonb;
  v_skills jsonb;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  select vs.entity_id into v_entity_id
    from public.verification_submissions vs
   where vs.id = p_submission_id;

  if v_entity_id is null then
    perform public.platform_raise_error('PLT004', 'Submission not found.');
  end if;

  select coalesce(jsonb_agg(entry order by
      is_current desc,
      start_year desc nulls last,
      start_month desc nulls last,
      created_at desc
    ), '[]'::jsonb)
    into v_experiences
    from (
      select jsonb_build_object(
        'id', e.id,
        'title', e.title,
        'organization', e.organization,
        'start_year', e.start_year,
        'start_month', e.start_month,
        'end_year', e.end_year,
        'end_month', e.end_month,
        'is_current', e.is_current,
        'description', e.description
      ) as entry,
      e.is_current as is_current,
      e.start_year as start_year,
      e.start_month as start_month,
      e.created_at as created_at
      from public.entity_work_experiences e
     where e.entity_id = v_entity_id
    ) sub;

  select coalesce(jsonb_agg(entry order by
      graduation_year desc nulls last,
      created_at desc
    ), '[]'::jsonb)
    into v_educations
    from (
      select jsonb_build_object(
        'id', e.id,
        'school', e.school,
        'degree', e.degree,
        'field_of_study', e.field_of_study,
        'graduation_year', e.graduation_year
      ) as entry,
      e.graduation_year as graduation_year,
      e.created_at as created_at
      from public.entity_educations e
     where e.entity_id = v_entity_id
    ) sub;

  select coalesce(jsonb_agg(entry order by name asc), '[]'::jsonb)
    into v_skills
    from (
      select jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'years_experience', s.years_experience
      ) as entry,
      s.name as name
      from public.entity_skills s
     where s.entity_id = v_entity_id
    ) sub;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Review profile retrieved.',
    'data', jsonb_build_object(
      'experiences', v_experiences,
      'educations', v_educations,
      'skills', v_skills
    )
  );
end;
$$;

comment on function public.verification_review_profile_get(uuid) is
  'Applicant work experience / education / skills for one verification submission (resolved via its entity). Admin-gated. Canonical output shape asserted by test 041. Fixed in 20261005090003: outer ORDER BY targets derived-table columns (was: inner alias e).';
