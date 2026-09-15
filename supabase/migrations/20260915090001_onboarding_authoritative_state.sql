-- EP-01-06 / EP-02: Onboarding Authoritative State
--
-- Fixes onboarding-regression root causes: completion previously existed only
-- in the client's volatile OnboardingProgress store, with no backend authority
-- (browser Back/Forward could re-enter a finished wizard and profile/capability
-- data was invisible outside the app). This migration makes onboarding state
-- server-authoritative using the D5 pattern already proven by the legal_name
-- anchor (20260821090006):
--
--   1. entities.capability            — hire | offer | both (persisted as soon
--                                       as the wizard step is reached; the
--                                       vocabulary mirrors the client model).
--   2. entities.onboarding_completed_at — single completion stamp set only by
--                                       the validating RPC after server-side
--                                       step verification.
--   3. BEFORE UPDATE guard trigger on entities: direct PostgREST writes to
--      capability / onboarding_completed_at are blocked unless the calling RPC
--      set the platform.rpc_invocation GUC (AGENT.md Rule 3 write discipline,
--      no new SECURITY DEFINER, EP-01-06 Plan §14.4 keeps entity_* invoker-only).
--   4. RPC set             entity_onboarding_status_update(text, boolean)
--   5. RPC get             entity_onboarding_status_get()
--   6. RPC reset           entity_onboarding_reset(uuid) — service_role only
--   7. Audit trail         entity_onboarding_audit_trail — append-only service
--      trail following the verification_audit_trail precedent (service_role has
--      no JWT, so platform_audit_log_add is unusable there).
--
-- Client changes (documented in the approved plan) wire Hive as a cache-only
-- store and make the route guard server-backed and fail-closed; no business
-- data is duplicated into auth.users.user_metadata.

-- ─── 1. Schema: authoritative columns on entities ───────────────────────────
alter table public.entities
  add column capability text,
  add column onboarding_completed_at timestamptz;

alter table public.entities
  add constraint entities_capability_allowed check (
    capability is null or capability in ('hire', 'offer', 'both')
  );

comment on column public.entities.capability is
  'Onboarding capability selection (hire | offer | both), persisted server-side as soon as the wizard step is reached. NULL means onboarding not yet started. Authority for the client model, which stays cache-only.';
comment on column public.entities.onboarding_completed_at is
  'Authoritative onboarding completion stamp. Set exclusively by entity_onboarding_status_update after server-side step verification; cleared by entity_onboarding_reset (service_role) for re-onboarding. NULL = incomplete.';
comment on constraint entities_capability_allowed on public.entities is
  'Capability vocabulary is fixed by CHECK for forward-safe extensibility (decision D2), mirroring the client EntityCapability model.';

-- ─── 2. Narrow entity grants: column-level UPDATE ACL (D5) ──────────────────
-- Replaces the previous table-level UPDATE grant with an explicit column list:
-- id (upsert conflict target), status (lifecycle), capability + onboarding_
-- completed_at (guarded by the trigger below). Collateral narrowing removes an
-- accidental UPDATE-on-created_at/created_by footgun introduced by the old
-- table-level grant.
revoke all on table public.entities from anon, authenticated;

grant select, insert on table public.entities to authenticated;
grant update (id, status, capability, onboarding_completed_at)
  on table public.entities to authenticated;

grant select on table public.entities to service_role;
grant update (capability, onboarding_completed_at)
  on table public.entities to service_role;

-- ─── 3. Mutation gate trigger (D5 pattern) ──────────────────────────────────
create or replace function public.entities_guard_onboarding_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.capability is distinct from old.capability
      or new.onboarding_completed_at is distinct from old.onboarding_completed_at)
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on' then
    perform public.platform_raise_error(
      'PLT002',
      'Onboarding state may only be changed through the entity_onboarding_status_update RPC.'
    );
  end if;
  return new;
end;
$$;

comment on function public.entities_guard_onboarding_state() is
  'Enforces AGENT.md Rule 3 write discipline: capability and onboarding_completed_at mutate only through entity_onboarding_status_update / entity_onboarding_reset (both set platform.rpc_invocation); direct PostgREST PATCH is blocked. SECURITY INVOKER by design.';

drop trigger if exists entities_guard_onboarding_state_update on public.entities;

create trigger entities_guard_onboarding_state_update
  before update on public.entities
  for each row
  execute function public.entities_guard_onboarding_state();

comment on trigger entities_guard_onboarding_state_update on public.entities is
  'Blocks non-RPC mutation of onboarding state; pairs with entity_onboarding_status_update and entity_onboarding_reset setting platform.rpc_invocation.';

-- ─── 4. Admin audit trail for service-role mutations ────────────────────────
-- platform_audit_log_add requires auth.uid() (platform_is_authenticated) and the
-- verification RPCs established that service_role carries auth.uid() = NULL.
-- Following that precedent (20260829090003 verification_audit_trail), the reset
-- RPC writes to an append-only trail with zero client grants.
create table public.entity_onboarding_audit_trail (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  actor_id uuid,
  created_at timestamptz not null default now(),
  constraint entity_onboarding_audit_trail_action_allowed check (
    action in ('onboarding_reset')
  )
);

create index entity_onboarding_audit_trail_entity_idx
  on public.entity_onboarding_audit_trail (entity_id);

create index entity_onboarding_audit_trail_created_at_idx
  on public.entity_onboarding_audit_trail (created_at desc);

alter table public.entity_onboarding_audit_trail enable row level security;

revoke all on table public.entity_onboarding_audit_trail from anon, authenticated;

grant select, insert on table public.entity_onboarding_audit_trail to service_role;

comment on table public.entity_onboarding_audit_trail is
  'Append-only audit trail for service-role onboarding mutations. No updated_at column and zero UPDATE/DELETE grants to any role; zero client grants. Written directly by entity_onboarding_reset (service_role carries auth.uid() = NULL, so platform_audit_log_add is unusable — same constraint as verification_audit_trail).';

do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'entity_onboarding_audit_trail'
  ) then
    alter publication supabase_realtime
      drop table public.entity_onboarding_audit_trail;
  end if;
end;
$$;

-- ─── 5. RPC: status update (capability + completion) ────────────────────────
create or replace function public.entity_onboarding_status_update(
  p_capability text default null,
  p_completed boolean default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entities;
  v_resolved_capability text;
  v_audit_details jsonb := '{}'::jsonb;
  v_changed boolean := false;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_capability is null and p_completed is null then
    perform public.platform_raise_error('PLT003', 'Provide a capability or a completion flag.');
  end if;

  -- Validate capability vocabulary
  if p_capability is not null then
    if nullif(btrim(p_capability), '') is null then
      perform public.platform_raise_error('PLT003', 'Capability cannot be empty.');
    end if;
    if btrim(p_capability) not in ('hire', 'offer', 'both') then
      perform public.platform_raise_error('PLT003', 'Invalid capability value.');
    end if;
    v_audit_details := v_audit_details || jsonb_build_object('capability', btrim(p_capability));
    v_changed := true;
  end if;

  -- Server-side step verification before stamping completion
  if p_completed then
    if not exists (
      select 1 from public.entity_profiles p where p.entity_id = auth.uid()
    ) then
      perform public.platform_raise_error('PLT003', 'Complete your profile before finishing onboarding.');
    end if;

    select coalesce(p_capability, e.capability) into v_resolved_capability
      from public.entities e where e.id = auth.uid();

    if v_resolved_capability is null then
      perform public.platform_raise_error('PLT003', 'Choose your capability before finishing onboarding.');
    end if;

    v_resolved_capability := btrim(v_resolved_capability);

    if v_resolved_capability in ('offer', 'both') then
      if not exists (
        select 1 from public.entity_roles r
         where r.entity_id = auth.uid() and r.role = 'professional' and r.is_active
      ) then
        perform public.platform_raise_error('PLT003', 'Activate the professional role before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_professions b where b.entity_id = auth.uid()
      ) then
        perform public.platform_raise_error('PLT003', 'Bind at least one profession before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_credentials c
         where c.entity_id = auth.uid() and c.kind = 'identity_document'
      ) then
        perform public.platform_raise_error('PLT003', 'Submit an identity document before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_credentials c
         where c.entity_id = auth.uid() and c.kind = 'trade_proof'
      ) then
        perform public.platform_raise_error('PLT003', 'Submit trade proof before finishing onboarding.');
      end if;
    end if;

    v_audit_details := v_audit_details || jsonb_build_object('completed_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'));
    v_changed := true;
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.entities
     set capability = coalesce(p_capability, capability),
         onboarding_completed_at = case
           when p_completed then now()
           when p_completed is false then null
           else onboarding_completed_at
         end
   where id = auth.uid()
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Entity not found.');
  end if;

  perform public.platform_audit_log_add(
    'entity_onboarding_status_update',
    'entities',
    v_audit_details
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Onboarding status updated.',
    'data', jsonb_build_object(
      'capability', v_row.capability,
      'onboarding_completed_at', v_row.onboarding_completed_at
    )
  );
end;
$$;

comment on function public.entity_onboarding_status_update(text, boolean) is
  'Authoritative onboarding state mutation. capability vocabulary validated (PLT003 on unknown value); completion stamped only after server-side step verification (profile, capability, and for offer/both: professional role + profession binding + identity document + trade proof). p_completed = false clears the stamp (re-onboarding intent). Audit-logged. Guarded by entities_guard_onboarding_state — direct PATCH is blocked.';

-- ─── 6. RPC: status get (self-scoped hydration source) ──────────────────────
create or replace function public.entity_onboarding_status_get()
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_row public.entities;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select * into v_row from public.entities e where e.id = auth.uid();

  if not found then
    perform public.platform_raise_error('PLT004', 'Entity not found.');
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Onboarding status retrieved.',
    'data', jsonb_build_object(
      'capability', v_row.capability,
      'onboarding_completed_at', v_row.onboarding_completed_at,
      'completed', v_row.onboarding_completed_at is not null,
      'profile_exists', exists (
        select 1 from public.entity_profiles p where p.entity_id = auth.uid()
      ),
      'professional_role_active', exists (
        select 1 from public.entity_roles r
         where r.entity_id = auth.uid() and r.role = 'professional' and r.is_active
      ),
      'profession_exists', exists (
        select 1 from public.entity_professions b where b.entity_id = auth.uid()
      )
    )
  );
end;
$$;

comment on function public.entity_onboarding_status_get() is
  'Self-scoped hydration source for the route guard: returns server-authoritative capability, completion stamp, and probe flags the client uses to decide resume vs blocked. No cross-entity data exposure (RLS + auth.uid()).';

-- ─── 7. RPC: reset (admin re-onboarding, service_role only) ─────────────────
create or replace function public.entity_onboarding_reset(p_entity_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entities;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    perform public.platform_raise_error('PLT001', 'Service role required.');
  end if;

  if p_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Entity id is required.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.entities
     set capability = null,
         onboarding_completed_at = null
   where id = p_entity_id
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Entity not found.');
  end if;

  -- platform_audit_log_add cannot be used here: it requires auth.uid(), which
  -- is NULL under service_role. Append to the dedicated trail instead.
  insert into public.entity_onboarding_audit_trail (entity_id, action, details, actor_id)
  values (p_entity_id, 'onboarding_reset', '{}'::jsonb, null);

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Onboarding reset.',
    'data', jsonb_build_object(
      'entity_id', p_entity_id,
      'capability', v_row.capability,
      'onboarding_completed_at', v_row.onboarding_completed_at
    )
  );
end;
$$;

comment on function public.entity_onboarding_reset(uuid) is
  'Service-role-only onboarding reset for authorized re-onboarding (EP-02 admin flow). Clears capability and completion stamp for any entity; append-only audit-trailed. SECURITY INVOKER — the execute grant to service_role is the access control, preserving the no-entity-SECURITY-DEFINER posture.';

-- ─── 8. Execute grants ──────────────────────────────────────────────────────
-- New functions default to PUBLIC execute; re-baseline the whole schema the
-- way modules 20260821090004 / 20260829090002 / 20260913090001 do.
revoke execute on all functions in schema public from public;

grant execute on function public.platform_health() to anon, authenticated, service_role;
grant execute on function public.platform_is_authenticated() to authenticated, service_role;
grant execute on function public.platform_current_user_id() to authenticated, service_role;
grant execute on function public.platform_set_updated_at() to authenticated, service_role;
grant execute on function public.platform_raise_error(text, text) to authenticated, service_role;
grant execute on function public.platform_validate_payload(jsonb, text[]) to authenticated, service_role;

grant execute on function public.platform_demo_records_get(uuid) to authenticated, service_role;
grant execute on function public.platform_demo_records_create(text, jsonb) to authenticated, service_role;
grant execute on function public.platform_demo_records_update(uuid, jsonb) to authenticated, service_role;
grant execute on function public.platform_audit_log_add(text, text, jsonb) to authenticated, service_role;

grant execute on function public.entity_profile_update(text, text, text) to authenticated, service_role;
grant execute on function public.entity_roles_activate(text) to authenticated, service_role;
grant execute on function public.entity_roles_deactivate(text) to authenticated, service_role;
grant execute on function public.entity_profession_bind(uuid) to authenticated, service_role;
grant execute on function public.entity_credentials_submit(text, text, uuid, text, timestamptz) to authenticated, service_role;

grant execute on function public.entity_onboarding_status_update(text, boolean) to authenticated, service_role;
grant execute on function public.entity_onboarding_status_get() to authenticated, service_role;
grant execute on function public.entity_onboarding_reset(uuid) to service_role;

-- ─── 9. Backfill for existing identities ────────────────────────────────────
-- Pre-launch data only (demo/e2e seeds). A profile is the universal minimum,
-- so profile-bearing entities are complete (hire) or complete-once-profession-
-- bound (offer/both). Guard the writes by setting platform.rpc_invocation:
-- the backfill runs under the migration role, not a client JWT.
select set_config('platform.rpc_invocation', 'on', false);

update public.entities e
   set capability = case
         when exists (
           select 1 from public.entity_roles r
            where r.entity_id = e.id and r.role = 'professional' and r.is_active
         ) then 'both'
         else 'hire'
       end,
       onboarding_completed_at = coalesce(
         (select p.updated_at from public.entity_profiles p where p.entity_id = e.id),
         e.created_at
       )
 where e.capability is null
   and exists (select 1 from public.entity_profiles p where p.entity_id = e.id)
   and (
     not exists (
       select 1 from public.entity_roles r
        where r.entity_id = e.id and r.role = 'professional' and r.is_active
     )
     or exists (select 1 from public.entity_professions b where b.entity_id = e.id)
   );

select set_config('platform.rpc_invocation', 'off', false);