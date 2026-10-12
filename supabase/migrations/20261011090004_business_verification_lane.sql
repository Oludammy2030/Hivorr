-- Identity Phase 2a: business verification lane.
--
-- Introduces business identity as a first-class, separately-verified concept
-- (founder-approved identity audit, Phase 2):
--   - `businesses`: trading (public) name + registered legal name + CAC
--     number + verification_status (pending|approved|rejected). Names are
--     member-editable; status moves only via the review RPC (D5 guard).
--   - `business_memberships`: (business, entity) links with role
--     (representative|member). Client creates the business then joins it;
--     approval authorizes the submitting representative. Leave via own-row
--     DELETE; role/authorization changes are admin-only (documented).
--   - `entity_credentials.business_id` + kind `business_document`;
--     `verification_submissions` type `business_verification`; audit event
--     `business_status_propagated`.
--   - Approval of a business_verification submission flips the business to
--     approved + authorizes the submitter's membership. It never touches
--     personal KYC tiers or trade bindings (no cross-grant, Rule 4).
--   - CAC documents travel through the existing `credential-documents`
--     bucket (admin-only SELECT already); no new bucket.
--
-- No new RPCs: businesses/memberships are RLS-CRUD tables; evidence flows
-- through the extended credentials_submit + verification_submit + review
-- RPCs with the existing envelope and grants pattern.

-- ─── 1. Tables ───────────────────────────────────────────────────────────────
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  trading_name text not null,
  registered_legal_name text not null,
  cac_number text,
  verification_status text not null default 'pending',
  created_by uuid references public.entities (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint businesses_trading_name_length check (
    char_length(btrim(trading_name)) between 1 and 120
  ),
  constraint businesses_legal_name_length check (
    char_length(btrim(registered_legal_name)) between 1 and 255
  ),
  constraint businesses_cac_length check (
    cac_number is null or char_length(btrim(cac_number)) between 1 and 64
  ),
  constraint businesses_status_allowed check (
    verification_status in ('pending', 'approved', 'rejected')
  ),
  constraint businesses_cac_unique unique (cac_number)
);

create table if not exists public.business_memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  entity_id uuid not null references public.entities (id) on delete cascade,
  role text not null default 'representative',
  is_authorized boolean not null default false,
  created_at timestamptz not null default now(),
  constraint business_memberships_entity_business_key unique (business_id, entity_id),
  constraint business_memberships_role_allowed check (
    role in ('representative', 'member')
  )
);

create trigger businesses_set_updated_at
  before update on public.businesses
  for each row
  execute function public.platform_set_updated_at();

create index if not exists businesses_created_by_idx
  on public.businesses (created_by);
create index if not exists businesses_status_idx
  on public.businesses (verification_status);
create index if not exists business_memberships_business_idx
  on public.business_memberships (business_id);
create index if not exists business_memberships_entity_idx
  on public.business_memberships (entity_id);

comment on table public.businesses is
  'Business identities hirable on Hivorr (identity audit Phase 2a). trading_name is the public face; registered_legal_name + cac_number are the registered identity (never proof by themselves). verification_status moves only via verification_review_approve on a business_verification submission (D5 guard blocks direct client writes). Personal KYC and trade bindings are never touched by business approval (no cross-grant).';
comment on table public.business_memberships is
  'Links entities to businesses they represent or belong to. The creator joins as representative; business approval authorizes the submitting representative (is_authorized). Role/authorization changes after creation are admin-only; members may delete only their own row (leave).';

-- ─── 2. Credential business link + kind ──────────────────────────────────────
alter table public.entity_credentials
  add column if not exists business_id uuid references public.businesses (id) on delete cascade;

create index if not exists entity_credentials_business_id_idx
  on public.entity_credentials (business_id);

alter table public.entity_credentials
  drop constraint if exists entity_credentials_kind_allowed;
alter table public.entity_credentials
  add constraint entity_credentials_kind_allowed check (
    kind in ('identity_document', 'trade_proof', 'certification', 'business_document')
  );

-- ─── 3. Submission type + audit event vocabularies ───────────────────────────
alter table public.verification_submissions
  drop constraint if exists verification_submissions_type_allowed;
alter table public.verification_submissions
  add constraint verification_submissions_type_allowed check (
    submission_type in ('identity_document', 'trade_proof', 'certification', 'business_verification')
  );

alter table public.verification_audit_trail
  drop constraint if exists verification_audit_trail_event_type_allowed;
alter table public.verification_audit_trail
  add constraint verification_audit_trail_event_type_allowed check (
    event_type in (
      'submission_created', 'submission_assigned', 'review_approved',
      'review_rejected', 'review_resubmitted', 'kyc_level_assigned',
      'trade_status_propagated', 'business_status_propagated', 'status_cleared'
    )
  );

-- ─── 4. RLS (default-deny; member-scoped + admin; anon 0) ────────────────────
-- Membership checks inside policies go through is_business_member() (SECURITY
-- DEFINER, RLS-bypassing like is_platform_admin): a policy that SELECTs the
-- table it guards would otherwise recurse infinitely.
create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.business_memberships m
     where m.business_id = p_business_id
       and m.entity_id = auth.uid()
  );
$$;

comment on function public.is_business_member(uuid) is
  'RLS helper: caller membership probe for business policies. SECURITY DEFINER (table-owner bypass, same posture as is_platform_admin) so member-scoped policies never self-reference business_memberships.';

grant execute on function public.is_business_member(uuid) to authenticated, service_role;

alter table public.businesses enable row level security;
alter table public.business_memberships enable row level security;

revoke all on table public.businesses, public.business_memberships
  from anon, authenticated, service_role;

-- Businesses: members read; anyone authed can create (created_by=self);
-- members update names (verification_status excluded — D5 guard + RPC-only).
grant select on table public.businesses to authenticated;
grant insert (trading_name, registered_legal_name, cac_number, created_by)
  on table public.businesses to authenticated;
grant update (trading_name, registered_legal_name, cac_number, updated_at)
  on table public.businesses to authenticated;
grant select, insert, update, delete on table public.businesses to service_role;

create policy businesses_member_select
  on public.businesses for select to authenticated
  using (public.is_business_member(businesses.id));

create policy businesses_admin_select
  on public.businesses for select to authenticated
  using (public.is_platform_admin(auth.uid()));

create policy businesses_authenticated_insert
  on public.businesses for insert to authenticated
  with check (created_by is null or created_by = auth.uid());

create policy businesses_member_update
  on public.businesses for update to authenticated
  using (public.is_business_member(businesses.id))
  with check (public.is_business_member(businesses.id));

create policy businesses_admin_all
  on public.businesses for all to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

-- Memberships: members (+admins) read their business roster; anyone authed
-- may insert their OWN row when the business exists and they created it or
-- are already a member (invite flows stay out of scope); members may delete
-- only their own row (leave). No client UPDATE (documented).
grant select on table public.business_memberships to authenticated;
grant insert (business_id, entity_id, role)
  on table public.business_memberships to authenticated;
grant delete on table public.business_memberships to authenticated;
grant select, insert, update, delete on table public.business_memberships to service_role;

create policy business_memberships_member_select
  on public.business_memberships for select to authenticated
  using (
    business_memberships.entity_id = auth.uid()
    or public.is_business_member(business_memberships.business_id)
  );

create policy business_memberships_admin_select
  on public.business_memberships for select to authenticated
  using (public.is_platform_admin(auth.uid()));

create policy business_memberships_self_insert
  on public.business_memberships for insert to authenticated
  with check (
    business_memberships.entity_id = auth.uid()
    and exists (
      select 1 from public.businesses b
       where b.id = business_memberships.business_id
         and (
           b.created_by = auth.uid()
           or public.is_business_member(b.id)
         )
    )
  );

create policy business_memberships_self_delete
  on public.business_memberships for delete to authenticated
  using (business_memberships.entity_id = auth.uid());

create policy business_memberships_admin_all
  on public.business_memberships for all to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

-- ─── 5. D5 guard: verification_status is RPC-only ────────────────────────────
create or replace function public.businesses_guard_verification_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.verification_status is distinct from old.verification_status)
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on'
     and current_user = 'authenticated' then
    perform public.platform_raise_error(
      'PLT002',
      'Business verification state may only be changed through the verification review RPCs.'
    );
  end if;
  return new;
end;
$$;

comment on function public.businesses_guard_verification_state() is
  'D5 guard: blocks direct authenticated (client) mutation of businesses.verification_status. Trusted roles (postgres/service_role) and review RPCs that set platform.rpc_invocation may write.';

drop trigger if exists businesses_guard_verification_state_update on public.businesses;

create trigger businesses_guard_verification_state_update
  before update on public.businesses
  for each row
  execute function public.businesses_guard_verification_state();

-- Credentials: widen the client INSERT column list for the business link
-- (gate columns stay excluded — D5 unchanged).
grant insert (entity_id, profession_id, business_id, kind, title, document_path, expires_at)
  on table public.entity_credentials to authenticated;

-- ─── 6. credentials_submit: business_document kind + business link ───────────
drop function if exists public.entity_credentials_submit(text, text, uuid, text, timestamptz);

create or replace function public.entity_credentials_submit(
  p_kind text,
  p_title text,
  p_profession_id uuid default null,
  p_document_path text default null,
  p_expires_at timestamptz default null,
  p_business_id uuid default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_credentials;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if nullif(btrim(p_kind), '') is null then
    perform public.platform_raise_error('PLT003', 'Credential kind is required.');
  end if;

  if btrim(p_kind) not in ('identity_document', 'trade_proof', 'certification', 'business_document') then
    perform public.platform_raise_error('PLT003', 'Invalid credential kind.');
  end if;

  if nullif(btrim(p_title), '') is null then
    perform public.platform_raise_error('PLT003', 'Credential title is required.');
  end if;

  if char_length(btrim(p_title)) > 255 then
    perform public.platform_raise_error('PLT003', 'Credential title must be 255 characters or fewer.');
  end if;

  if p_profession_id is not null then
    if not exists (select 1 from public.professions where id = p_profession_id) then
      perform public.platform_raise_error('PLT004', 'Referenced profession not found.');
    end if;
  end if;

  -- Business documents must attach to a business the caller belongs to
  -- (PLT004 identical for foreign/unknown — no enumeration oracle).
  if btrim(p_kind) = 'business_document' then
    if p_business_id is null then
      perform public.platform_raise_error('PLT003', 'Business id is required for business documents.');
    end if;
    if not exists (
      select 1 from public.businesses b
       where b.id = p_business_id
         and exists (
           select 1 from public.business_memberships m
            where m.business_id = b.id and m.entity_id = auth.uid()
         )
    ) then
      perform public.platform_raise_error('PLT004', 'Business not found.');
    end if;
  elsif p_business_id is not null then
    perform public.platform_raise_error('PLT003', 'Business link applies to business documents only.');
  end if;

  -- verification_status defaults to 'pending' and submitted_at to now();
  -- both are kept out of invoker grants (immutable via this submit path).
  insert into public.entity_credentials (entity_id, profession_id, business_id, kind, title, document_path, expires_at)
  values (auth.uid(), p_profession_id, p_business_id, btrim(p_kind), btrim(p_title), p_document_path, p_expires_at)
  returning * into v_row;

  perform public.platform_audit_log_add(
    'entity_credentials_submit',
    'entity_credentials',
    jsonb_build_object(
      'kind', btrim(p_kind),
      'title', btrim(p_title),
      'profession_id', p_profession_id,
      'business_id', p_business_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Credential submitted for review.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_credentials_submit(text, text, uuid, text, timestamptz, uuid) is
  'Creates an immutable pending credential submission. kind/timestamped title validated; optional profession link validated (PLT004); business_document kind requires a caller-membership business link (PLT004 identical for foreign/unknown). Verification transitions (pending→approved/rejected) have zero client grant — reserved for EP-02 admin review gate. Audit-logged.';

grant execute on function public.entity_credentials_submit(text, text, uuid, text, timestamptz, uuid) to authenticated, service_role;

-- ─── 7. verification_submit: business_verification type + coherence ──────────
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

  if v_sub_type not in ('identity_document', 'trade_proof', 'certification', 'business_verification') then
    perform public.platform_raise_error('PLT003', 'Invalid submission type.');
  end if;

  -- Coherence: the business lane only carries business documents, and a
  -- business_verification submission always resolves from one.
  if v_sub_type = 'business_verification' and v_cred.kind <> 'business_document' then
    perform public.platform_raise_error('PLT003', 'Business verification requires a business document credential.');
  end if;
  if v_cred.kind = 'business_document' and v_sub_type <> 'business_verification' then
    perform public.platform_raise_error('PLT003', 'Business documents submit to business verification only.');
  end if;

  -- Dedup: one active submission per credential
  if exists (
    select 1 from public.verification_submissions vs
     where vs.credential_id = p_credential_id
       and vs.status in ('pending', 'in_review')
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
  'Authenticated: queues an existing entity_credential for admin review. Self-scoped; enforces ownership (PLT004) and one active submission per credential (PLT005). Business lane coherence enforced (business_verification <-> business_document). Audit-logged to verification_audit_trail and platform_audit_log. EXECUTE granted to authenticated, service_role.';

-- ─── 8. Approve: business branch (no personal/trade propagation) ─────────────
-- NOTE: extends the live admin-gated version from
-- 20260916090001_super_admin_system.sql:385-521 (NOT the older base
-- revision) — admin check, reviewer resolution, and the single GUC set are
-- preserved verbatim; only the propagation branch + comment change.
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
  v_business_id uuid;
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
  elsif v_sub.submission_type = 'business_verification' then
    -- Business lane: flip the linked business only. Personal KYC tiers and
    -- trade bindings are never touched here (no cross-grant, Rule 4).
    -- The GUC set above already passes this migration's D5 guard.
    if v_cred.business_id is null then
      perform public.platform_raise_error('PLT004', 'Linked business not found.');
    end if;

    update public.businesses
       set verification_status = 'approved',
           updated_at = now()
     where id = v_cred.business_id
    returning id into v_business_id;
    if not found then
      perform public.platform_raise_error('PLT004', 'Linked business not found.');
    end if;

    -- Authorize the submitting representative for the approved business.
    update public.business_memberships
       set is_authorized = true
     where business_id = v_business_id
       and entity_id = v_sub.entity_id;

    insert into public.verification_audit_trail (
      entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
    ) values (
      v_sub.entity_id, 'business_status_propagated', 'business', v_business_id, 'approved', v_reviewer,
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
  'Approves a submission and propagates status. Admin-gated: authenticated callers must be active platform admins. service_role remains for backward compat (Edge Functions). Sets platform.rpc_invocation to pass D5 guard triggers. Identity/certification approval assigns KYC tier_1; trade proof approval flips the Rule 2 gate; business verification approval flips businesses.verification_status and authorizes the submitting representative (never KYC/trade — no cross-grant). Audit-logged.';

grant execute on function public.verification_review_approve(uuid, text) to authenticated, service_role;
