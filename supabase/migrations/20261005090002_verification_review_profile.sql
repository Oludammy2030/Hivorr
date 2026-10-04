-- Professional Verification Queue: applicant profile depth (Phase 3).
--
-- No experience/education/skills storage exists anywhere (audit: only the
-- taxonomy industry named 'education' and `entity_credentials.title`).
-- This migration adds three owner-managed tables so the review panel can
-- show real Work Experience / Education / Skills sections instead of
-- "not collected" placeholders:
--
--   - entity_work_experiences: title, organization, start/end year+month,
--     is_current flag, free-text description.
--   - entity_educations: school, degree, field of study, graduation year.
--   - entity_skills: skill name (+ optional years), no proficiency scale
--     (the dashboard never showed proficiency — years only).
--
-- Write posture mirrors `portfolio_items`: owners CRUD their own rows
-- directly (applicant capture UI lands separately); admins read
-- cross-entity through `verification_review_profile_get` (SECURITY INVOKER,
-- `is_platform_admin()` body gate). No realtime, no notifications.
--
-- OUTPUT CONTRACT (asserted in supabase/tests/database/041):
--   verification_review_profile_get -> data {
--     experiences[], educations[], skills[]
--   }
--     experiences[] keys: id, title, organization, start_year, start_month,
--       end_year, end_month, is_current, description
--     educations[] keys: id, school, degree, field_of_study, graduation_year
--     skills[] keys: id, name, years_experience

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. entity_work_experiences
-- ═══════════════════════════════════════════════════════════════════════════════

create table public.entity_work_experiences (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  title text not null,
  organization text not null,
  start_year int,
  start_month int,
  end_year int,
  end_month int,
  is_current boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_work_experiences_title_length check (
    char_length(btrim(title)) between 1 and 255
  ),
  constraint entity_work_experiences_organization_length check (
    char_length(btrim(organization)) between 1 and 255
  ),
  constraint entity_work_experiences_start_month_range check (
    start_month is null or (start_month between 1 and 12)
  ),
  constraint entity_work_experiences_end_month_range check (
    end_month is null or (end_month between 1 and 12)
  ),
  constraint entity_work_experiences_year_range check (
    (start_year is null or (start_year between 1900 and 2100))
    and (end_year is null or (end_year between 1900 and 2100))
  ),
  constraint entity_work_experiences_description_length check (
    description is null or char_length(description) <= 2000
  )
);

create trigger entity_work_experiences_set_updated_at
  before update on public.entity_work_experiences
  for each row
  execute function public.platform_set_updated_at();

create index entity_work_experiences_entity_idx
  on public.entity_work_experiences (entity_id, start_year desc nulls last);

comment on table public.entity_work_experiences is
  'Owner-managed employment history per entity. Read by the admin verification review panel (profile RPC); applicant capture UI lands separately.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. entity_educations
-- ═══════════════════════════════════════════════════════════════════════════════

create table public.entity_educations (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  school text not null,
  degree text,
  field_of_study text,
  graduation_year int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_educations_school_length check (
    char_length(btrim(school)) between 1 and 255
  ),
  constraint entity_educations_degree_length check (
    degree is null or char_length(btrim(degree)) between 1 and 255
  ),
  constraint entity_educations_field_length check (
    field_of_study is null or char_length(btrim(field_of_study)) between 1 and 255
  ),
  constraint entity_educations_graduation_year_range check (
    graduation_year is null or (graduation_year between 1900 and 2100)
  )
);

create trigger entity_educations_set_updated_at
  before update on public.entity_educations
  for each row
  execute function public.platform_set_updated_at();

create index entity_educations_entity_idx
  on public.entity_educations (entity_id, graduation_year desc nulls last);

comment on table public.entity_educations is
  'Owner-managed education history per entity. Read by the admin verification review panel (profile RPC); applicant capture UI lands separately.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. entity_skills
-- ═══════════════════════════════════════════════════════════════════════════════

create table public.entity_skills (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  name text not null,
  years_experience int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_skills_name_length check (
    char_length(btrim(name)) between 1 and 100
  ),
  constraint entity_skills_years_range check (
    years_experience is null or (years_experience between 0 and 100)
  ),
  constraint entity_skills_owner_name_key unique (entity_id, (lower(name)))
);

create trigger entity_skills_set_updated_at
  before update on public.entity_skills
  for each row
  execute function public.platform_set_updated_at();

create index entity_skills_entity_idx
  on public.entity_skills (entity_id, name);

comment on table public.entity_skills is
  'Owner-managed professional skills per entity (years only, no proficiency scale). Read by the admin verification review panel (profile RPC); applicant capture UI lands separately.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. RLS: owner self-CRUD + admin cross-entity read
-- ═══════════════════════════════════════════════════════════════════════════════

alter table public.entity_work_experiences enable row level security;
alter table public.entity_educations enable row level security;
alter table public.entity_skills enable row level security;

-- Owner read (capture UI reads its own rows; the admin RPC reads via the
-- admin policy below).
create policy entity_work_experiences_owner_select
  on public.entity_work_experiences for select to authenticated
  using (entity_id = auth.uid());
create policy entity_educations_owner_select
  on public.entity_educations for select to authenticated
  using (entity_id = auth.uid());
create policy entity_skills_owner_select
  on public.entity_skills for select to authenticated
  using (entity_id = auth.uid());

-- Owner writes (capture UI writes directly, portfolio_items pattern).
create policy entity_work_experiences_owner_insert
  on public.entity_work_experiences for insert to authenticated
  with check (entity_id = auth.uid());
create policy entity_work_experiences_owner_update
  on public.entity_work_experiences for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());
create policy entity_work_experiences_owner_delete
  on public.entity_work_experiences for delete to authenticated
  using (entity_id = auth.uid());

create policy entity_educations_owner_insert
  on public.entity_educations for insert to authenticated
  with check (entity_id = auth.uid());
create policy entity_educations_owner_update
  on public.entity_educations for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());
create policy entity_educations_owner_delete
  on public.entity_educations for delete to authenticated
  using (entity_id = auth.uid());

create policy entity_skills_owner_insert
  on public.entity_skills for insert to authenticated
  with check (entity_id = auth.uid());
create policy entity_skills_owner_update
  on public.entity_skills for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());
create policy entity_skills_owner_delete
  on public.entity_skills for delete to authenticated
  using (entity_id = auth.uid());

-- Admin cross-entity read for the review panel RPC.
create policy entity_work_experiences_admin_select
  on public.entity_work_experiences for select to authenticated
  using (public.is_platform_admin(auth.uid()));
create policy entity_educations_admin_select
  on public.entity_educations for select to authenticated
  using (public.is_platform_admin(auth.uid()));
create policy entity_skills_admin_select
  on public.entity_skills for select to authenticated
  using (public.is_platform_admin(auth.uid()));

-- Default-deny revokes, then least-privilege grants.
revoke all on table public.entity_work_experiences from anon, authenticated;
revoke all on table public.entity_educations from anon, authenticated;
revoke all on table public.entity_skills from anon, authenticated;

grant select, insert, update, delete on table public.entity_work_experiences to authenticated;
grant select, insert, update, delete on table public.entity_educations to authenticated;
grant select, insert, update, delete on table public.entity_skills to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. RPC: verification_review_profile_get
-- ═══════════════════════════════════════════════════════════════════════════════

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
      e.is_current desc,
      e.start_year desc nulls last,
      e.start_month desc nulls last,
      e.created_at desc
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
      e.is_current, e.start_year, e.start_month, e.created_at
      from public.entity_work_experiences e
     where e.entity_id = v_entity_id
    ) sub;

  select coalesce(jsonb_agg(entry order by
      e.graduation_year desc nulls last,
      e.created_at desc
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
      e.graduation_year, e.created_at
      from public.entity_educations e
     where e.entity_id = v_entity_id
    ) sub;

  select coalesce(jsonb_agg(entry order by e.name asc), '[]'::jsonb)
    into v_skills
    from (
      select jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'years_experience', s.years_experience
      ) as entry,
      s.name
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
  'Applicant work experience / education / skills for one verification submission (resolved via its entity). Admin-gated. Canonical output shape asserted by test 041.';

grant execute on function public.verification_review_profile_get(uuid) to authenticated, service_role;
