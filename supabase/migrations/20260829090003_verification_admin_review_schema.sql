-- EP-02-03: Verification & Admin Review Schema Extension
--
-- Extends the EP-01 trust-evidence tables (entity_credentials, entity_professions)
-- into a full verification workflow engine (EP-02-03 Plan §5). This is the
-- verification engine that every downstream trust, identity, and financial-limit
-- task depends on (EP-02-10, EP-02-11, EP-02-12, EP-02-16).
--
-- Execution model: SECURITY INVOKER for all 6 RPCs (no new SECURITY DEFINER),
-- consistent with EP-01-05 / EP-01-06 / EP-02-02 RPC conventions. RLS applies
-- inside the function body.
--
-- Entity-facing RPCs (verification_submit, verification_status_get,
--   verification_kyc_level_get, verification_limits_get):
--   EXECUTE granted to authenticated + service_role. They enforce
--   platform_is_authenticated() and self-scope all reads/writes to auth.uid().
--
-- Admin review RPCs (verification_review_approve, verification_review_reject):
--   EXECUTE granted to service_role ONLY. anon / authenticated receive 42501
--   (insufficient privilege) before the body runs — the EXECUTE grant IS the
--   authorization gate. No explicit auth check is required (and MUST NOT be
--   added, because service_role carries auth.uid() = NULL and an auth check
--   would incorrectly reject the authorized admin path).
--
-- Audit logging strategy (EP-02-03 Plan §5.3):
--   platform_audit_log_add() is SECURITY DEFINER but enforces
--   platform_is_authenticated() (auth.uid() IS NOT NULL). In a service_role
--   invocation context auth.uid() is NULL, so the review RPCs write directly
--   to the dedicated verification_audit_trail table (the authoritative
--   verification audit log). verification_submit (authenticated context) also
--   calls platform_audit_log_add for cross-system audit consistency.
--
-- Envelope contract: {success, code, message, data}; codes PLT000..PLT999.
-- Status propagation (the Rule 2 trust gate):
--   * identity_document / certification approval  -> upsert entity_kyc_levels
--     to tier_1 (active), never downgrading an existing higher tier.
--   * trade_proof approval (credential.profession_id set) -> set
--     entity_professions.trade_verification_status = 'approved'.
--   Only this server-side path may advance the Rule 2 gate (client grants on
--   entity_professions exclude trade_verification_status / verified_at /
--   verified_by). Rejection never propagates.
--
-- No DDL alters any EP-01 table. No client-side code is created.

-- ─── 1. kyc_tiers (config-driven KYC limit reference) ─────────────────────────
create table public.kyc_tiers (
  tier_code text primary key,
  name text not null,
  description text,
  daily_limit numeric not null default 0,
  weekly_limit numeric not null default 0,
  monthly_limit numeric not null default 0,
  cashout_limit numeric not null default 0,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint kyc_tiers_tier_code_format check (tier_code ~ '^tier_[0-9]+$'),
  constraint kyc_tiers_name_length check (char_length(btrim(name)) between 1 and 255),
  constraint kyc_tiers_limits_non_negative check (
    daily_limit >= 0 and weekly_limit >= 0 and monthly_limit >= 0 and cashout_limit >= 0
  )
);

create trigger kyc_tiers_set_updated_at
  before update on public.kyc_tiers
  for each row
  execute function public.platform_set_updated_at();

create index kyc_tiers_is_active_sort_idx
  on public.kyc_tiers (is_active, sort_order);

comment on table public.kyc_tiers is
  'Config-driven KYC verification tier registry. Each tier carries base (NGN) transaction and cashout limits. Currency-specific overrides are layered later in EP-02-16. Tier codes follow ^tier_[0-9]+$; limits are numeric to avoid precision loss.';
comment on column public.kyc_tiers.tier_code is
  'Tier identifier (tier_0..tier_3). Primary key. Freezing the vocabulary as text + CHECK (not ENUM) keeps it forward-extensible.';
comment on column public.kyc_tiers.daily_limit is
  'Base NGN daily transaction limit for the tier. Non-negative.';
comment on column public.kyc_tiers.weekly_limit is
  'Base NGN weekly transaction limit for the tier. Non-negative.';
comment on column public.kyc_tiers.monthly_limit is
  'Base NGN monthly transaction limit for the tier. Non-negative.';
comment on column public.kyc_tiers.cashout_limit is
  'Base NGN cashout limit for the tier. Non-negative.';

-- ─── 2. entity_kyc_levels (per-entity current KYC assignment) ─────────────────
create table public.entity_kyc_levels (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  tier_code text not null references public.kyc_tiers (tier_code),
  status text not null default 'pending',
  assigned_at timestamptz not null default now(),
  assigned_by uuid,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_kyc_levels_entity_id_key unique (entity_id),
  constraint entity_kyc_levels_status_allowed check (status in ('pending', 'active', 'expired'))
);

create trigger entity_kyc_levels_set_updated_at
  before update on public.entity_kyc_levels
  for each row
  execute function public.platform_set_updated_at();

comment on table public.entity_kyc_levels is
  'Per-entity current KYC tier assignment. Exactly one active row per entity (UNIQUE entity_id). Mutated only by the server-side verification_review_approve RPC (service_role); authenticated has SELECT only.';
comment on column public.entity_kyc_levels.tier_code is
  'Assigned tier; FK to kyc_tiers. Higher tiers unlock higher limits (enforced downstream in EP-02-12/16).';
comment on column public.entity_kyc_levels.status is
  'pending | active | expired. Approval of an identity/certification submission sets active.';

-- ─── 3. verification_submissions (unified review queue) ───────────────────────
create table public.verification_submissions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  credential_id uuid references public.entity_credentials (id) on delete restrict,
  submission_type text not null,
  status text not null default 'pending',
  priority integer not null default 5,
  assigned_reviewer uuid,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  decision_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint verification_submissions_type_allowed check (
    submission_type in ('identity_document', 'trade_proof', 'certification')
  ),
  constraint verification_submissions_status_allowed check (
    status in ('pending', 'in_review', 'approved', 'rejected', 'requires_resubmission')
  ),
  constraint verification_submissions_review_consistency check (
    (status in ('pending', 'in_review') and reviewed_at is null and reviewed_by is null)
    or (status in ('approved', 'rejected', 'requires_resubmission') and reviewed_at is not null)
  ),
  constraint verification_submissions_notes_length check (
    decision_notes is null or char_length(decision_notes) <= 5000
  )
);

create trigger verification_submissions_set_updated_at
  before update on public.verification_submissions
  for each row
  execute function public.platform_set_updated_at();

create index verification_submissions_entity_status_idx
  on public.verification_submissions (entity_id, status);

create index verification_submissions_credential_id_idx
  on public.verification_submissions (credential_id);

create index verification_submissions_submitted_at_idx
  on public.verification_submissions (submitted_at desc);

create unique index verification_submissions_one_active_credential_idx
  on public.verification_submissions (credential_id)
  where status in ('pending', 'in_review');

comment on table public.verification_submissions is
  'Unified, admin-reviewable verification queue for identity documents, trade proofs, and certifications. status is never client-writable (excluded from authenticated INSERT/UPDATE grants); it moves only via the service-role review RPCs. Review consistency is enforced by CHECK regardless of writer.';
comment on column public.verification_submissions.credential_id is
  'Links to the trust-evidence row in entity_credentials (RESTRICT: credential cannot be deleted while a submission references it).';
comment on constraint verification_submissions_review_consistency on public.verification_submissions is
  'Pending/in_review rows must be unreviewed; decided rows must carry reviewed_at. Enforces review-state integrity regardless of writer.';

-- ─── 4. verification_reviews (immutable decision records) ─────────────────────
create table public.verification_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.verification_submissions (id) on delete cascade,
  entity_id uuid not null references public.entities (id) on delete cascade,
  reviewer_id uuid,
  decision text not null,
  decision_notes text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint verification_reviews_decision_allowed check (
    decision in ('approved', 'rejected', 'requires_resubmission')
  ),
  constraint verification_reviews_notes_length check (
    decision_notes is null or char_length(decision_notes) <= 5000
  )
);

create index verification_reviews_submission_id_idx
  on public.verification_reviews (submission_id);

create index verification_reviews_entity_idx
  on public.verification_reviews (entity_id);

comment on table public.verification_reviews is
  'Immutable decision record per admin review action. No updated_at column and zero UPDATE/DELETE grants to any role — decisions are permanent. Written only by the service-role review RPCs.';

-- ─── 5. verification_audit_trail (append-only state-change log) ───────────────
create table public.verification_audit_trail (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid references public.entities (id) on delete set null,
  event_type text not null,
  subject_type text,
  subject_id uuid,
  from_state text,
  to_state text,
  actor_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint verification_audit_trail_event_type_allowed check (
    event_type in (
      'submission_created', 'submission_assigned', 'review_approved',
      'review_rejected', 'review_resubmitted', 'kyc_level_assigned',
      'trade_status_propagated', 'status_cleared'
    )
  )
);

create index verification_audit_trail_entity_idx
  on public.verification_audit_trail (entity_id);

create index verification_audit_trail_created_at_idx
  on public.verification_audit_trail (created_at desc);

comment on table public.verification_audit_trail is
  'Append-only, authoritative log of all verification state changes. No updated_at column and zero UPDATE/DELETE grants to any role. Written directly by the verification RPCs (the review RPCs cannot use platform_audit_log_add because service_role carries auth.uid() = NULL).';

-- ─── 6. Seed KYC tiers (idempotent) ───────────────────────────────────────────
insert into public.kyc_tiers (tier_code, name, description, daily_limit, weekly_limit, monthly_limit, cashout_limit, is_active, sort_order)
values
  ('tier_0', 'Unverified', 'No verification completed.', 0, 0, 0, 0, true, 0),
  ('tier_1', 'Identity Verified', 'Identity document approved.', 50000, 200000, 800000, 100000, true, 10),
  ('tier_2', 'Trade Verified', 'Trade proof approved.', 200000, 800000, 3000000, 500000, true, 20),
  ('tier_3', 'Fully Verified', 'Identity and trade verified.', 1000000, 4000000, 15000000, 2000000, true, 30)
on conflict (tier_code) do nothing;

-- ─── 7. RLS enablement ────────────────────────────────────────────────────────
alter table public.kyc_tiers enable row level security;
alter table public.entity_kyc_levels enable row level security;
alter table public.verification_submissions enable row level security;
alter table public.verification_reviews enable row level security;
alter table public.verification_audit_trail enable row level security;

-- ─── 8. Default-deny revokes (belt & suspenders) ──────────────────────────────
revoke all on table public.kyc_tiers, public.entity_kyc_levels, public.verification_submissions,
  public.verification_reviews, public.verification_audit_trail
from anon, authenticated;

-- ─── 9. Table-level grants (default-deny: anon gets nothing) ──────────────────
-- kyc_tiers: reference data, authenticated + service_role read; service_role writes.
grant select on table public.kyc_tiers to authenticated;
grant select, insert, update on table public.kyc_tiers to service_role;

-- entity_kyc_levels: self read (authenticated); service_role full.
grant select on table public.entity_kyc_levels to authenticated;
grant select, insert, update, delete on table public.entity_kyc_levels to service_role;

-- entity_professions: authenticated self read/write is scoped to non-gate columns
--   by the entity_model grants; the Rule-2 trade gate (trade_verification_status,
--   verified_at, verified_by) is flipped ONLY by the service-role review RPC, so
--   service_role is granted UPDATE here. This is the sole authorized path that may
--   advance the trade gate (EP-02-03 Plan §5.3).
grant update on table public.entity_professions to service_role;

-- verification_submissions: self read + limited self insert; service_role full.
grant select, insert (entity_id, credential_id, submission_type, priority)
  on table public.verification_submissions to authenticated;
grant select, insert, update on table public.verification_submissions to service_role;

-- verification_reviews: self read; service_role insert.
grant select on table public.verification_reviews to authenticated;
grant select, insert on table public.verification_reviews to service_role;

-- verification_audit_trail: self read + self insert; service_role insert.
grant select, insert (entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  on table public.verification_audit_trail to authenticated;
grant select, insert on table public.verification_audit_trail to service_role;

-- ─── 10. Self-scoped RLS policies ─────────────────────────────────────────────
create policy kyc_tiers_authenticated_select
  on public.kyc_tiers for select to authenticated
  using (true);

create policy entity_kyc_levels_authenticated_select
  on public.entity_kyc_levels for select to authenticated
  using (entity_id = auth.uid());

create policy verification_submissions_authenticated_select
  on public.verification_submissions for select to authenticated
  using (entity_id = auth.uid());

create policy verification_submissions_authenticated_insert
  on public.verification_submissions for insert to authenticated
  with check (entity_id = auth.uid());

create policy verification_reviews_authenticated_select
  on public.verification_reviews for select to authenticated
  using (entity_id = auth.uid());

create policy verification_audit_trail_authenticated_select
  on public.verification_audit_trail for select to authenticated
  using (entity_id = auth.uid());

create policy verification_audit_trail_authenticated_insert
  on public.verification_audit_trail for insert to authenticated
  with check (entity_id = auth.uid());

comment on policy kyc_tiers_authenticated_select on public.kyc_tiers is
  'Self-readable reference data; anon has no grant (default-deny verification schema).';
comment on policy entity_kyc_levels_authenticated_select on public.entity_kyc_levels is
  'Self-scoped read: KYC assignment of the owning entity.';
comment on policy verification_submissions_authenticated_select on public.verification_submissions is
  'Self-scoped read: submissions submitted by the owning entity.';
comment on policy verification_submissions_authenticated_insert on public.verification_submissions is
  'Self-scoped insert: owner may queue a submission, but status/reviewed_at/reviewed_by are excluded columns (server-side only).';
comment on policy verification_reviews_authenticated_select on public.verification_reviews is
  'Self-scoped read: review decisions concerning the owning entity.';
comment on policy verification_audit_trail_authenticated_select on public.verification_audit_trail is
  'Self-scoped read: audit events concerning the owning entity.';
comment on policy verification_audit_trail_authenticated_insert on public.verification_audit_trail is
  'Self-scoped insert: owner may append audit events; service_role bypasses RLS for review-originated events.';

-- ─── 11. RPC: verification_submit ──────────────────────────────────────────────
create or replace function public.verification_submit(
  p_credential_id uuid,
  p_submission_type text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_cred public.entity_credentials;
  v_sub_type text;
  v_row public.verification_submissions;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_credential_id is null then
    perform public.platform_raise_error('PLT003', 'Credential id is required.');
  end if;

  select * into v_cred
    from public.entity_credentials
   where id = p_credential_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Credential not found.');
  end if;

  if v_cred.entity_id <> v_actor then
    perform public.platform_raise_error('PLT004', 'Credential does not belong to this entity.');
  end if;

  v_sub_type := coalesce(nullif(btrim(p_submission_type), ''), v_cred.kind);

  if v_sub_type not in ('identity_document', 'trade_proof', 'certification') then
    perform public.platform_raise_error('PLT003', 'Invalid submission type.');
  end if;

  -- Dedup: one active submission per credential
  if exists (
    select 1
      from public.verification_submissions
     where credential_id = p_credential_id
       and status in ('pending', 'in_review')
  ) then
    perform public.platform_raise_error('PLT005', 'An active submission already exists for this credential.');
  end if;

  begin
    insert into public.verification_submissions (entity_id, credential_id, submission_type, priority)
    values (v_actor, p_credential_id, v_sub_type, 5)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'An active submission already exists for this credential.');
    when foreign_key_violation then
      perform public.platform_raise_error('PLT004', 'Credential not found.');
  end;

  -- Authoritative verification audit trail (insert policy is self-scoped)
  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
  ) values (
    v_actor, 'submission_created', 'submission', v_row.id, 'pending', v_actor,
    jsonb_build_object('submission_type', v_sub_type, 'credential_id', p_credential_id)
  );

  -- General platform audit (authenticated context guarantees auth.uid() is set)
  perform public.platform_audit_log_add(
    'verification_submit', 'verification_submissions',
    jsonb_build_object('submission_type', v_sub_type, 'credential_id', p_credential_id)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Verification submission queued.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_submit(uuid, text) is
  'Authenticated: queues an existing entity_credential for admin review. Self-scoped; enforces ownership (PLT004) and one active submission per credential (PLT005). Audit-logged to verification_audit_trail and platform_audit_log. EXECUTE granted to authenticated, service_role.';

-- ─── 12. RPC: verification_review_approve ──────────────────────────────────────
create or replace function public.verification_review_approve(
  p_submission_id uuid,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_sub public.verification_submissions;
  v_cred public.entity_credentials;
  v_reviewer uuid := auth.uid();
  v_row public.verification_submissions;
begin
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
  'Service-role only: approves a submission and propagates status. Identity/certification approval assigns KYC tier_1 (never downgrading). Trade proof approval flips entity_professions.trade_verification_status = approved (Rule 2 gate) — the only authorized path. Audit-logged to verification_audit_trail (not platform_audit_log_add, because service_role auth.uid() is NULL). EXECUTE granted to service_role only.';

-- ─── 13. RPC: verification_review_reject ───────────────────────────────────────
create or replace function public.verification_review_reject(
  p_submission_id uuid,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_sub public.verification_submissions;
  v_reviewer uuid := auth.uid();
  v_row public.verification_submissions;
begin
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

  update public.verification_submissions
     set status = 'rejected',
         reviewed_at = now(),
         reviewed_by = v_reviewer,
         decision_notes = nullif(btrim(p_notes), ''),
         updated_at = now()
   where id = p_submission_id
   returning * into v_row;

  insert into public.verification_reviews (submission_id, entity_id, reviewer_id, decision, decision_notes)
  values (p_submission_id, v_sub.entity_id, v_reviewer, 'rejected', nullif(btrim(p_notes), ''));

  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
  ) values (
    v_sub.entity_id, 'review_rejected', 'submission', p_submission_id, v_sub.status, 'rejected', v_reviewer,
    jsonb_build_object('submission_type', v_sub.submission_type)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Submission rejected.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_review_reject(uuid, text) is
  'Service-role only: rejects a submission (status = rejected, decision recorded). Never propagates KYC or trade-gate state. Audit-logged to verification_audit_trail. EXECUTE granted to service_role only.';

-- ─── 14. RPC: verification_status_get ──────────────────────────────────────────
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
      'trade_verification_status', ep.trade_verification_status
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
  'Aggregated verification status for an entity. Self-scoped for authenticated (cross-entity id raises PLT004); service_role may pass any p_entity_id. Returns KYC tier + limits, identity_verified flag, per-profession trade statuses, and submission counts. SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

-- ─── 15. RPC: verification_kyc_level_get ───────────────────────────────────────
create or replace function public.verification_kyc_level_get()
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_tier_code text;
  v_tier_status text;
  v_daily numeric;
  v_weekly numeric;
  v_monthly numeric;
  v_cashout numeric;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select kt.tier_code, ekl.status, kt.daily_limit, kt.weekly_limit, kt.monthly_limit, kt.cashout_limit
    into v_tier_code, v_tier_status, v_daily, v_weekly, v_monthly, v_cashout
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_actor;

  if not found then
    v_tier_code := 'tier_0';
    v_tier_status := 'unassigned';
    v_daily := 0; v_weekly := 0; v_monthly := 0; v_cashout := 0;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'KYC level retrieved.',
    'data', jsonb_build_object(
      'tier_code', v_tier_code,
      'status', v_tier_status,
      'limits', jsonb_build_object(
        'daily', v_daily,
        'weekly', v_weekly,
        'monthly', v_monthly,
        'cashout', v_cashout
      )
    )
  );
end;
$$;

comment on function public.verification_kyc_level_get() is
  'Current KYC tier + limits for the calling entity. Self-scoped (auth required). Returns tier_0 all-zero defaults when no assignment exists. SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

-- ─── 16. RPC: verification_limits_get ──────────────────────────────────────────
create or replace function public.verification_limits_get()
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_tier_code text;
  v_daily numeric;
  v_weekly numeric;
  v_monthly numeric;
  v_cashout numeric;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select kt.tier_code, kt.daily_limit, kt.weekly_limit, kt.monthly_limit, kt.cashout_limit
    into v_tier_code, v_daily, v_weekly, v_monthly, v_cashout
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_actor;

  if not found then
    v_tier_code := 'tier_0';
    v_daily := 0; v_weekly := 0; v_monthly := 0; v_cashout := 0;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Limits retrieved.',
    'data', jsonb_build_object(
      'tier_code', v_tier_code,
      'daily', v_daily,
      'weekly', v_weekly,
      'monthly', v_monthly,
      'cashout', v_cashout
    )
  );
end;
$$;

comment on function public.verification_limits_get() is
  'Applicable transaction/cashout limits for the calling entity (derived from its KYC tier). Self-scoped (auth required). SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

-- ─── 17. EXECUTE grants: revoke from public pseudo-role, then grant explicitly ─
revoke execute on all functions in schema public from public;

grant execute on function public.verification_submit(uuid, text) to authenticated, service_role;
grant execute on function public.verification_review_approve(uuid, text) to service_role;
grant execute on function public.verification_review_reject(uuid, text) to service_role;
grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
grant execute on function public.verification_kyc_level_get() to authenticated, service_role;
grant execute on function public.verification_limits_get() to authenticated, service_role;

-- ─── 18. Realtime exclusion ─────────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in (
         'kyc_tiers', 'entity_kyc_levels', 'verification_submissions',
         'verification_reviews', 'verification_audit_trail'
       )
  ) then
    alter publication supabase_realtime
      drop table public.kyc_tiers, public.entity_kyc_levels, public.verification_submissions,
        public.verification_reviews, public.verification_audit_trail;
  end if;
end;
$$;
