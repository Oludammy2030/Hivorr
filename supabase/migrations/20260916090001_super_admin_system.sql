-- EP-04: Super Admin System & Admin-Gated Verification Review
--
-- Introduces the Super Admin authorization layer and replaces the service-role
-- verification review seam with an authenticated-admin path.
--
-- ARCHITECTURE
--   1. platform_admins           — platform-level admin identity (NOT an entity role)
--   2. is_platform_admin()       — SECURITY DEFINER lookup helper for RLS + RPC
--                                   guards (definer breaks the RLS recursion it
--                                   would otherwise trigger on platform_admins)
--   3. Admin RLS policies        — cross-entity read/write for admins on all
--                                   verification-related tables + storage
--   4. D5 guard triggers         — prevent direct PostgREST writes to
--                                   verification-gated columns
--   5. REPLACE review RPCs       — verification_review_approve/reject now check
--                                   is_platform_admin(); service_role remains for
--                                   backward compat (Edge Functions)
--   6. New admin RPCs            — queue get, start, admin provision/revoke/list
--   7. Storage admin policy      — credential-documents SELECT for admin signed URLs
--
-- DESIGN PRINCIPLES (EP-01-05, AGENT.md)
--   - SECURITY INVOKER for all new functions (single exception: is_platform_admin
--     is SECURITY DEFINER to break RLS recursion on the RLS-protected admin table)
--   - RLS applies inside every function body
--   - admin check is is_platform_admin(auth.uid()) — the EXECUTE grant is NOT
--     the access control gate; the body check is
--   - D5 guard triggers protect verification columns from direct PostgREST writes
--   - platform_admins is platform-level, NOT entity_roles (no vocabulary change)
--   - Envelope: {success, code, message, data}; codes PLT000..PLT999
--
-- MIGRATION POSTURE
--   - No DDL on existing EP-01/EP-02 migration files (Rule 3 write discipline)
--   - All new tables, functions, policies, triggers, grants
--   - Idempotent where possible (DROP IF EXISTS before CREATE)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. platform_admins (admin identity registry)
-- ═══════════════════════════════════════════════════════════════════════════════

create table public.platform_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  is_active boolean not null default true,
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint platform_admins_user_active_check check (
    (is_active and revoked_at is null)
    or (not is_active and revoked_at is not null)
  )
);

create trigger platform_admins_set_updated_at
  before update on public.platform_admins
  for each row
  execute function public.platform_set_updated_at();

comment on table public.platform_admins is
  'Platform-level admin identity registry. NOT an entity_roles value — admin is a system-granted property, not a self-selected capability. Lifecycle: provision (is_active=true) → revoke (is_active=false, revoked_at set). Bootstrap via migration seed.';
comment on column public.platform_admins.user_id is
  'References auth.users.id. UNIQUE — one admin record per user.';
comment on column public.platform_admins.is_active is
  'Active flag. Only active admins pass is_platform_admin(). Revocation sets is_active=false.';
comment on constraint platform_admins_user_active_check on public.platform_admins is
  'Active admins must not have revoked_at; revoked admins must have revoked_at. Enforces lifecycle consistency.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. is_platform_admin() helper
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.is_platform_admin(p_user_id uuid default null)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_target uuid;
begin
  v_target := coalesce(p_user_id, auth.uid());
  if v_target is null then
    return false;
  end if;
  return exists (
    select 1 from public.platform_admins
     where user_id = v_target and is_active
  );
end;
$$;

comment on function public.is_platform_admin(uuid) is
  'Returns true when the given user (or auth.uid()) is an active platform admin. SECURITY DEFINER (avoids RLS recursion, since it reads RLS-protected platform_admins), STABLE. Used in both RLS policies and RPC body checks.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. Column-grant expansions for admin RPCs
-- ═══════════════════════════════════════════════════════════════════════════════
-- The review RPCs (SECURITY INVOKER) run with the calling user's privileges.
-- When called by an authenticated admin, they need UPDATE on verification-gated
-- columns that were previously service_role-only. The D5 guard triggers (§4)
-- prevent direct PostgREST writes, so the expanded grants are safe.

-- entity_professions: add trade gate columns to authenticated UPDATE
-- (existing: entity_id, profession_id, is_primary)
grant update (trade_verification_status, verified_at, verified_by)
  on table public.entity_professions to authenticated;

-- verification_submissions: add UPDATE for admin status transitions
-- (existing: select, insert)
grant update on table public.verification_submissions to authenticated;

-- entity_kyc_levels: add INSERT + UPDATE for admin KYC assignment
-- (existing: select only)
grant insert, update on table public.entity_kyc_levels to authenticated;

-- verification_reviews: add INSERT for admin decision records
-- (existing: select only)
grant insert on table public.verification_reviews to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. D5 guard triggers (prevent direct PostgREST writes)
-- ═══════════════════════════════════════════════════════════════════════════════

-- entity_professions: guard trade_verification_status / verified_at / verified_by
create or replace function public.entity_professions_guard_verification_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.trade_verification_status is distinct from old.trade_verification_status
      or new.verified_at is distinct from old.verified_at
      or new.verified_by is distinct from old.verified_by)
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on'
     and current_user = 'authenticated' then
    perform public.platform_raise_error(
      'PLT002',
      'Trade verification state may only be changed through the verification review RPCs.'
    );
  end if;
  return new;
end;
$$;

comment on function public.entity_professions_guard_verification_state() is
  'D5 guard: blocks direct authenticated (client) mutation of trade_verification_status, verified_at, verified_by. Trusted roles (postgres/service_role) and review RPCs that set platform.rpc_invocation may write.';

drop trigger if exists entity_professions_guard_verification_state_update on public.entity_professions;

create trigger entity_professions_guard_verification_state_update
  before update on public.entity_professions
  for each row
  execute function public.entity_professions_guard_verification_state();

comment on trigger entity_professions_guard_verification_state_update on public.entity_professions is
  'D5 guard trigger: blocks non-RPC mutation of trade verification columns. Pairs with verification_review_approve/reject setting platform.rpc_invocation.';

-- verification_submissions: guard status / reviewed_at / reviewed_by / decision_notes
create or replace function public.verification_submissions_guard_review_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.status is distinct from old.status
      or new.reviewed_at is distinct from old.reviewed_at
      or new.reviewed_by is distinct from old.reviewed_by
      or new.decision_notes is distinct from old.decision_notes)
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on'
     and current_user = 'authenticated' then
    perform public.platform_raise_error(
      'PLT002',
      'Submission review state may only be changed through the verification review RPCs.'
    );
  end if;
  return new;
end;
$$;

comment on function public.verification_submissions_guard_review_state() is
  'D5 guard: blocks direct authenticated (client) mutation of status, reviewed_at, reviewed_by, decision_notes. Trusted roles (postgres/service_role) and review RPCs that set platform.rpc_invocation may write.';

drop trigger if exists verification_submissions_guard_review_state_update on public.verification_submissions;

create trigger verification_submissions_guard_review_state_update
  before update on public.verification_submissions
  for each row
  execute function public.verification_submissions_guard_review_state();

comment on trigger verification_submissions_guard_review_state_update on public.verification_submissions is
  'D5 guard trigger: blocks non-RPC mutation of review state columns.';

-- entity_kyc_levels: guard all columns (table is RPC-only)
create or replace function public.entity_kyc_levels_guard_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on'
     and current_user = 'authenticated' then
    perform public.platform_raise_error(
      'PLT002',
      'KYC level may only be changed through the verification review RPCs.'
    );
  end if;
  return new;
end;
$$;

comment on function public.entity_kyc_levels_guard_state() is
  'D5 guard: blocks all direct authenticated (client) mutation on entity_kyc_levels. Trusted roles (postgres/service_role) and review RPCs that set platform.rpc_invocation may write.';

drop trigger if exists entity_kyc_levels_guard_state_insert on public.entity_kyc_levels;
drop trigger if exists entity_kyc_levels_guard_state_update on public.entity_kyc_levels;

create trigger entity_kyc_levels_guard_state_insert
  before insert on public.entity_kyc_levels
  for each row
  execute function public.entity_kyc_levels_guard_state();

create trigger entity_kyc_levels_guard_state_update
  before update on public.entity_kyc_levels
  for each row
  execute function public.entity_kyc_levels_guard_state();

comment on trigger entity_kyc_levels_guard_state_insert on public.entity_kyc_levels is
  'D5 guard trigger: blocks non-RPC INSERT on entity_kyc_levels.';
comment on trigger entity_kyc_levels_guard_state_update on public.entity_kyc_levels is
  'D5 guard trigger: blocks non-RPC UPDATE on entity_kyc_levels.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. Admin RLS policies
-- ═══════════════════════════════════════════════════════════════════════════════

-- platform_admins: admins can see/manage the admin list
alter table public.platform_admins enable row level security;

revoke all on table public.platform_admins from anon, authenticated;
grant select, insert, update on table public.platform_admins to authenticated;
grant select on table public.platform_admins to service_role;

create policy platform_admins_admin_select
  on public.platform_admins for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy platform_admins_admin_insert
  on public.platform_admins for insert to authenticated
  with check (is_platform_admin(auth.uid()));

create policy platform_admins_admin_update
  on public.platform_admins for update to authenticated
  using (is_platform_admin(auth.uid()))
  with check (is_platform_admin(auth.uid()));

comment on policy platform_admins_admin_select on public.platform_admins is
  'Admin-scoped read: only active platform admins can view the admin list.';
comment on policy platform_admins_admin_insert on public.platform_admins is
  'Admin-scoped insert: only active platform admins can provision new admins.';
comment on policy platform_admins_admin_update on public.platform_admins is
  'Admin-scoped update: only active platform admins can modify admin records.';

-- verification_submissions: admin cross-entity read + update
create policy verification_submissions_admin_select
  on public.verification_submissions for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy verification_submissions_admin_update
  on public.verification_submissions for update to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy verification_submissions_admin_select on public.verification_submissions is
  'Admin cross-entity read: platform admins can view all submissions for the review queue.';
comment on policy verification_submissions_admin_update on public.verification_submissions is
  'Admin cross-entity update: platform admins can transition submission status through review RPCs.';

-- entity_credentials: admin cross-entity read (for document preview)
create policy entity_credentials_admin_select
  on public.entity_credentials for select to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entity_credentials_admin_select on public.entity_credentials is
  'Admin cross-entity read: platform admins can view credential metadata for the review queue.';

-- entity_professions: admin cross-entity read + update
create policy entity_professions_admin_select
  on public.entity_professions for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy entity_professions_admin_update
  on public.entity_professions for update to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entity_professions_admin_select on public.entity_professions is
  'Admin cross-entity read: platform admins can view profession bindings for the review queue.';
comment on policy entity_professions_admin_update on public.entity_professions is
  'Admin cross-entity update: platform admins can flip trade_verification_status through review RPCs.';

-- entity_kyc_levels: admin cross-entity read + insert + update
create policy entity_kyc_levels_admin_select
  on public.entity_kyc_levels for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy entity_kyc_levels_admin_insert
  on public.entity_kyc_levels for insert to authenticated
  with check (is_platform_admin(auth.uid()));

create policy entity_kyc_levels_admin_update
  on public.entity_kyc_levels for update to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entity_kyc_levels_admin_select on public.entity_kyc_levels is
  'Admin cross-entity read: platform admins can view KYC assignments for the review queue.';
comment on policy entity_kyc_levels_admin_insert on public.entity_kyc_levels is
  'Admin cross-entity insert: platform admins can assign KYC tiers through review RPCs.';
comment on policy entity_kyc_levels_admin_update on public.entity_kyc_levels is
  'Admin cross-entity update: platform admins can update KYC tiers through review RPCs.';

-- verification_reviews: admin cross-entity read + insert
create policy verification_reviews_admin_select
  on public.verification_reviews for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy verification_reviews_admin_insert
  on public.verification_reviews for insert to authenticated
  with check (is_platform_admin(auth.uid()));

comment on policy verification_reviews_admin_select on public.verification_reviews is
  'Admin cross-entity read: platform admins can view all decision records.';
comment on policy verification_reviews_admin_insert on public.verification_reviews is
  'Admin cross-entity insert: platform admins can create decision records through review RPCs.';

-- verification_audit_trail: admin cross-entity read + insert
create policy verification_audit_trail_admin_select
  on public.verification_audit_trail for select to authenticated
  using (is_platform_admin(auth.uid()));

create policy verification_audit_trail_admin_insert
  on public.verification_audit_trail for insert to authenticated
  with check (is_platform_admin(auth.uid()));

comment on policy verification_audit_trail_admin_select on public.verification_audit_trail is
  'Admin cross-entity read: platform admins can view all audit trail entries.';
comment on policy verification_audit_trail_admin_insert on public.verification_audit_trail is
  'Admin cross-entity insert: platform admins can append audit trail entries through review RPCs.';

-- entities: admin cross-entity read (for entity info in queue)
-- (No admin UPDATE policy — admins never mutate entity rows directly)
create policy entities_admin_select
  on public.entities for select to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entities_admin_select on public.entities is
  'Admin cross-entity read: platform admins can view entity records for the review queue.';

-- entity_profiles: admin cross-entity read (for display name in queue)
create policy entity_profiles_admin_select
  on public.entity_profiles for select to authenticated
  using (is_platform_admin(auth.uid()));

comment on policy entity_profiles_admin_select on public.entity_profiles is
  'Admin cross-entity read: platform admins can view profiles for the review queue.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. Storage admin policy (credential-documents SELECT)
-- ═══════════════════════════════════════════════════════════════════════════════

drop policy if exists credential_documents_select_admin on storage.objects;

create policy credential_documents_select_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'credential-documents'
    and public.is_platform_admin(auth.uid())
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. REPLACE: verification_review_approve (admin-gated)
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.verification_review_approve(
  p_submission_id uuid,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_sub public.verification_submissions;
  v_cred public.entity_credentials;
  v_reviewer uuid;
  v_row public.verification_submissions;
begin
  -- Authorization: admin (authenticated) or service_role (backward compat)
  if current_user = 'service_role' then
    v_reviewer := null;
  elsif v_actor is not null then
    if not public.is_platform_admin(v_actor) then
      perform public.platform_raise_error('PLT002', 'Admin access required.');
    end if;
    v_reviewer := v_actor;
  else
    v_reviewer := null;
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  select * into v_sub
    from public.verification_submissions
   where id = p_submission_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Submission not found.');
  end if;

  if v_sub.status in ('approved', 'rejected', 'requires_resubmission') then
    perform public.platform_raise_error('PLT005', 'Submission has already been reviewed.');
  end if;

  select * into v_cred
    from public.entity_credentials
   where id = v_sub.credential_id;

  if v_cred is null then
    perform public.platform_raise_error('PLT004', 'Linked credential not found.');
  end if;

  -- Set GUC to pass D5 guard triggers
  perform set_config('platform.rpc_invocation', 'on', true);

  -- Advance submission state
  update public.verification_submissions
     set status = 'approved',
         reviewed_at = now(),
         reviewed_by = v_reviewer,
         decision_notes = nullif(btrim(p_notes), ''),
         updated_at = now()
   where id = p_submission_id
   returning * into v_row;

  -- Immutable decision record
  insert into public.verification_reviews (submission_id, entity_id, reviewer_id, decision, decision_notes)
  values (p_submission_id, v_sub.entity_id, v_reviewer, 'approved', nullif(btrim(p_notes), ''));

  -- Authoritative audit: review approved
  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
  ) values (
    v_sub.entity_id, 'review_approved', 'submission', p_submission_id, v_sub.status, 'approved', v_reviewer,
    jsonb_build_object('submission_type', v_sub.submission_type)
  );

  -- Status propagation (the trust gate)
  if v_sub.submission_type = 'trade_proof' then
    if v_cred.profession_id is not null then
      update public.entity_professions
         set trade_verification_status = 'approved',
             verified_at = now(),
             verified_by = v_reviewer,
             updated_at = now()
       where entity_id = v_sub.entity_id
         and profession_id = v_cred.profession_id;

      insert into public.verification_audit_trail (
        entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
      ) values (
        v_sub.entity_id, 'trade_status_propagated', 'trade_binding', v_cred.profession_id, 'approved', v_reviewer,
        jsonb_build_object('submission_id', p_submission_id)
      );
    end if;
  elsif v_sub.submission_type in ('identity_document', 'certification') then
    insert into public.entity_kyc_levels (entity_id, tier_code, status, assigned_at, assigned_by)
    values (v_sub.entity_id, 'tier_1', 'active', now(), v_reviewer)
    on conflict (entity_id) do update
      set tier_code = case
            when public.entity_kyc_levels.tier_code < excluded.tier_code
              then excluded.tier_code else public.entity_kyc_levels.tier_code end,
          status = case
            when public.entity_kyc_levels.tier_code < excluded.tier_code
              then excluded.status else public.entity_kyc_levels.status end,
          assigned_at = case
            when public.entity_kyc_levels.tier_code < excluded.tier_code
              then excluded.assigned_at else public.entity_kyc_levels.assigned_at end,
          assigned_by = case
            when public.entity_kyc_levels.tier_code < excluded.tier_code
              then excluded.assigned_by else public.entity_kyc_levels.assigned_by end,
          updated_at = now()
      where public.entity_kyc_levels.tier_code < excluded.tier_code;

    insert into public.verification_audit_trail (
      entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
    ) values (
      v_sub.entity_id, 'kyc_level_assigned', 'kyc_level', v_sub.entity_id, 'tier_1', v_reviewer,
      jsonb_build_object('submission_id', p_submission_id)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Submission approved.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_review_approve(uuid, text) is
  'Approves a submission and propagates status. Admin-gated: authenticated callers must be active platform admins. service_role remains for backward compat (Edge Functions). Sets platform.rpc_invocation to pass D5 guard triggers. Identity/certification approval assigns KYC tier_1; trade proof approval flips the Rule 2 gate. Audit-logged.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. REPLACE: verification_review_reject (admin-gated + resubmission)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Drop the legacy (uuid, text) overload left behind by migration
-- 20260829090003 so CREATE OR REPLACE replaces it cleanly and callers
-- resolve to the new 3-arg variant (which provides defaults for the
-- third parameter).
drop function if exists public.verification_review_reject(uuid, text);

create or replace function public.verification_review_reject(
  p_submission_id uuid,
  p_notes text default null,
  p_requires_resubmission boolean default false
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_sub public.verification_submissions;
  v_reviewer uuid;
  v_row public.verification_submissions;
  v_final_status text;
begin
  -- Authorization: admin (authenticated) or service_role (backward compat)
  if current_user = 'service_role' then
    v_reviewer := null;
  elsif v_actor is not null then
    if not public.is_platform_admin(v_actor) then
      perform public.platform_raise_error('PLT002', 'Admin access required.');
    end if;
    v_reviewer := v_actor;
  else
    v_reviewer := null;
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  select * into v_sub
    from public.verification_submissions
   where id = p_submission_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Submission not found.');
  end if;

  if v_sub.status in ('approved', 'rejected', 'requires_resubmission') then
    perform public.platform_raise_error('PLT005', 'Submission has already been reviewed.');
  end if;

  -- Determine final status
  v_final_status := case
    when p_requires_resubmission then 'requires_resubmission'
    else 'rejected'
  end;

  -- Set GUC to pass D5 guard triggers
  perform set_config('platform.rpc_invocation', 'on', true);

  update public.verification_submissions
     set status = v_final_status,
         reviewed_at = now(),
         reviewed_by = v_reviewer,
         decision_notes = nullif(btrim(p_notes), ''),
         updated_at = now()
   where id = p_submission_id
   returning * into v_row;

  insert into public.verification_reviews (submission_id, entity_id, reviewer_id, decision, decision_notes)
  values (p_submission_id, v_sub.entity_id, v_reviewer, v_final_status, nullif(btrim(p_notes), ''));

  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
  ) values (
    v_sub.entity_id,
    case when v_final_status = 'requires_resubmission' then 'review_resubmitted' else 'review_rejected' end,
    'submission', p_submission_id, v_sub.status, v_final_status, v_reviewer,
    jsonb_build_object('submission_type', v_sub.submission_type)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', case when v_final_status = 'requires_resubmission'
      then 'Submission requires resubmission.'
      else 'Submission rejected.' end,
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_review_reject(uuid, text, boolean) is
  'Rejects or requires resubmission. Admin-gated: authenticated callers must be active platform admins. service_role remains for backward compat. Sets platform.rpc_invocation to pass D5 guard triggers. Never propagates KYC or trade-gate state. Audit-logged.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. New RPC: platform_admin_check
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.platform_admin_check()
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_is_admin boolean;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  v_is_admin := public.is_platform_admin();

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Admin status checked.',
    'data', jsonb_build_object('is_admin', v_is_admin)
  );
end;
$$;

comment on function public.platform_admin_check() is
  'Returns whether the calling user is an active platform admin. Self-scoped. Used by the Flutter app to gate admin UI.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. New RPC: platform_admin_provision
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.platform_admin_provision(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.platform_admins;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_user_id is null then
    perform public.platform_raise_error('PLT003', 'User id is required.');
  end if;

  -- Upsert: reactivate if revoked
  -- Existence is enforced by the user_id FK -> auth.users; catching the FK
  -- violation here preserves the PLT004 error envelope without SELECT on
  -- auth.users (unreadable by the authenticated invoker).
  begin
    insert into public.platform_admins (user_id, granted_by, is_active, granted_at, revoked_at)
    values (p_user_id, v_actor, true, now(), null)
    on conflict (user_id) do update
      set is_active = true,
          granted_by = v_actor,
          granted_at = now(),
          revoked_at = null,
          updated_at = now()
    returning * into v_row;
  exception
    when foreign_key_violation then
      perform public.platform_raise_error('PLT004', 'User not found.');
  end;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Admin provisioned.',
    'data', jsonb_build_object('user_id', p_user_id, 'is_active', v_row.is_active)
  );
end;
$$;

comment on function public.platform_admin_provision(uuid) is
  'Grants platform admin to a user. Only callable by existing admins. Upserts: reactivates a revoked admin.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. New RPC: platform_admin_revoke
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.platform_admin_revoke(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_target_count int;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_user_id is null then
    perform public.platform_raise_error('PLT003', 'User id is required.');
  end if;

  -- Prevent self-revocation (must have at least one active admin)
  if p_user_id = v_actor then
    perform public.platform_raise_error('PLT005', 'Cannot revoke your own admin access.');
  end if;

  update public.platform_admins
     set is_active = false,
         revoked_at = now(),
         updated_at = now()
   where user_id = p_user_id and is_active;

  if not found then
    perform public.platform_raise_error('PLT004', 'Active admin not found.');
  end if;

  -- Ensure at least one active admin remains
  select count(*) into v_target_count
    from public.platform_admins where is_active;

  if v_target_count < 1 then
    -- Rollback: reactivate
    update public.platform_admins
       set is_active = true,
           revoked_at = null,
           updated_at = now()
     where user_id = p_user_id;
    perform public.platform_raise_error('PLT005', 'Cannot revoke the last active admin.');
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Admin revoked.',
    'data', jsonb_build_object('user_id', p_user_id, 'is_active', false)
  );
end;
$$;

comment on function public.platform_admin_revoke(uuid) is
  'Revokes platform admin from a user. Only callable by existing admins. Prevents self-revocation and ensures at least one active admin remains.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. New RPC: platform_admin_list
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.platform_admin_list()
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_admins jsonb;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', pa.user_id,
    'is_active', pa.is_active,
    'granted_at', pa.granted_at,
    'revoked_at', pa.revoked_at
  ) order by pa.granted_at desc), '[]'::jsonb)
    into v_admins
    from public.platform_admins pa;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Admin list retrieved.',
    'data', jsonb_build_object('admins', v_admins)
  );
end;
$$;

comment on function public.platform_admin_list() is
  'Lists all platform admins (active and revoked). Only callable by existing admins. Email is intentionally omitted: auth.users is not readable by the authenticated invoker.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. New RPC: verification_review_queue_get
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.verification_review_queue_get(
  p_status text default 'pending',
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

  select count(*) into v_total_count
    from public.verification_submissions vs
   where (p_status is null or vs.status = p_status);

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

comment on function public.verification_review_queue_get(text, int, int) is
  'Paginated admin review queue. Returns submissions joined with entity/credential/profession metadata. Admin-gated. Supports status filter and pagination.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. New RPC: verification_review_start
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.verification_review_start(
  p_submission_id uuid
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.verification_submissions;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  -- Set GUC to pass D5 guard trigger
  perform set_config('platform.rpc_invocation', 'on', true);

  update public.verification_submissions
     set status = 'in_review',
         assigned_reviewer = v_actor,
         updated_at = now()
   where id = p_submission_id
     and status = 'pending'
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT005', 'Submission is not in pending status.');
  end if;

  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
  ) values (
    v_row.entity_id, 'submission_assigned', 'submission', p_submission_id,
    'pending', 'in_review', v_actor,
    jsonb_build_object('submission_type', v_row.submission_type)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Submission assigned for review.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_review_start(uuid) is
  'Claims a pending submission for review (status -> in_review, assigned_reviewer set). Admin-gated. Idempotent: only claims pending submissions.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. New RPC: verification_review_audit_get
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.verification_review_audit_get(
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
  v_audit jsonb;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', vat.id,
    'event_type', vat.event_type,
    'subject_type', vat.subject_type,
    'subject_id', vat.subject_id,
    'from_state', vat.from_state,
    'to_state', vat.to_state,
    'actor_id', vat.actor_id,
    'details', vat.details,
    'created_at', vat.created_at
  ) order by vat.created_at asc), '[]'::jsonb)
    into v_audit
    from public.verification_audit_trail vat
   where vat.subject_id = p_submission_id
      or (vat.subject_type = 'submission' and vat.subject_id = p_submission_id);

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Audit trail retrieved.',
    'data', jsonb_build_object('audit_entries', v_audit)
  );
end;
$$;

comment on function public.verification_review_audit_get(uuid) is
  'Returns the audit trail for a specific submission. Admin-gated. Shows all state transitions from submission creation through decision.';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. EXECUTE grants
-- ═══════════════════════════════════════════════════════════════════════════════

-- Reset all function grants (belt & suspenders)
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

-- Verification review RPCs (NOW granted to authenticated for admin path)
grant execute on function public.verification_review_approve(uuid, text) to authenticated, service_role;
grant execute on function public.verification_review_reject(uuid, text, boolean) to authenticated, service_role;

-- Admin system RPCs
grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_check() to authenticated, service_role;
grant execute on function public.platform_admin_provision(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_revoke(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_list() to authenticated, service_role;
grant execute on function public.verification_review_queue_get(text, int, int) to authenticated, service_role;
grant execute on function public.verification_review_start(uuid) to authenticated, service_role;
grant execute on function public.verification_review_audit_get(uuid) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. Realtime exclusion
-- ═══════════════════════════════════════════════════════════════════════════════

do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'platform_admins'
  ) then
    alter publication supabase_realtime
      drop table public.platform_admins;
  end if;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. Documentation
-- ═══════════════════════════════════════════════════════════════════════════════

comment on column public.verification_submissions.assigned_reviewer is
  'UUID of the admin who claimed this submission for review (set by verification_review_start). Separate from reviewed_by which is set on decision.';
