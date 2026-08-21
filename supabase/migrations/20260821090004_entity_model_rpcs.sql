-- EP-01-06: Entity Model Enforcement RPC Set
--
-- Minimal server-side invariant enforcement (EP-01-06 Plan §5.5):
--   entity_profile_update      — legal-name anchor mutation with validation + audit
--   entity_roles_activate      — fluid role activation with vocabulary validation
--   entity_roles_deactivate    — fluid role deactivation
--   entity_profession_bind     — bind profession (existence/activity/duplicate checks)
--   entity_credentials_submit  — create pending credential; audit-logged
--
-- Execution model: SECURITY INVOKER (RLS applies inside). No new SECURITY DEFINER.
-- Envelope: {success, code, message, data}; codes PLT000..PLT999.
-- Reuses EP-01-05 helpers: platform_is_authenticated(), platform_validate_payload(),
-- platform_raise_error(), platform_audit_log_add(), platform_set_updated_at().

-- ─── 1. Profile update (legal-name anchor mutation) ─────────────────────────
create or replace function public.entity_profile_update(
  p_legal_name text default null,
  p_display_name text default null,
  p_bio text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_profiles;
  v_updated boolean := false;
  v_audit_details jsonb := '{}'::jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  -- Validate and sanitize each provided field
  if p_legal_name is not null then
    if nullif(btrim(p_legal_name), '') is null then
      perform public.platform_raise_error('PLT003', 'Legal name cannot be empty.');
    end if;
    if char_length(btrim(p_legal_name)) > 255 then
      perform public.platform_raise_error('PLT003', 'Legal name must be 255 characters or fewer.');
    end if;
    v_audit_details := v_audit_details || jsonb_build_object('legal_name', btrim(p_legal_name));
    v_updated := true;
  end if;

  if p_display_name is not null then
    if nullif(btrim(p_display_name), '') is null then
      perform public.platform_raise_error('PLT003', 'Display name cannot be empty.');
    end if;
    if char_length(btrim(p_display_name)) > 255 then
      perform public.platform_raise_error('PLT003', 'Display name must be 255 characters or fewer.');
    end if;
    v_audit_details := v_audit_details || jsonb_build_object('display_name', btrim(p_display_name));
    v_updated := true;
  end if;

  if p_bio is not null then
    if char_length(btrim(p_bio)) > 5000 then
      perform public.platform_raise_error('PLT003', 'Bio must be 5000 characters or fewer.');
    end if;
    v_audit_details := v_audit_details || jsonb_build_object('bio', btrim(p_bio));
    v_updated := true;
  end if;

  if not v_updated then
    perform public.platform_raise_error('PLT003', 'At least one field (legal_name, display_name, bio) must be provided.');
  end if;

  -- Perform the update. legal_name mutation is gated by the
  -- entity_profiles_guard_legal_name trigger: only this RPC (which sets the
  -- platform.rpc_invocation GUC) may change legal_name; direct PostgREST
  -- updates are blocked (AGENT.md Rule 3 anchor discipline).
  perform set_config('platform.rpc_invocation', 'on', true);

  update public.entity_profiles
     set legal_name = coalesce(p_legal_name, legal_name),
         display_name = coalesce(p_display_name, display_name),
         bio = p_bio
   where entity_id = auth.uid()
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Profile not found.');
  end if;

  -- Audit log the mutation
  perform public.platform_audit_log_add(
    'entity_profile_update',
    'entity_profiles',
    v_audit_details
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profile updated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_profile_update(text, text, text) is
  'Validated mutation of entity profile. legal_name (AGENT.md Rule 3 anchor) and display_name/bio trimmed and length-checked. Audit-logged. Direct column-level grants block raw legal_name updates — only this RPC path succeeds.';

-- ─── 2. Role activation ─────────────────────────────────────────────────────
create or replace function public.entity_roles_activate(p_role text)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_roles;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if nullif(btrim(p_role), '') is null then
    perform public.platform_raise_error('PLT003', 'Role is required.');
  end if;

  if btrim(p_role) not in ('consumer', 'professional', 'merchant', 'rider') then
    perform public.platform_raise_error('PLT003', 'Invalid role value.');
  end if;

  insert into public.entity_roles (entity_id, role, is_active, activated_at)
  values (auth.uid(), btrim(p_role), true, now())
  on conflict (entity_id, role) do update
    set is_active = true, activated_at = now()
  returning * into v_row;

  perform public.platform_audit_log_add(
    'entity_role_activate',
    'entity_roles',
    jsonb_build_object('role', btrim(p_role))
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Role activated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_roles_activate(text) is
  'Activates a fluid role for the calling entity. Upserts with is_active = true. Vocabulary validated server-side (PLT003 on unknown role). Audit-logged.';

-- ─── 3. Role deactivation ───────────────────────────────────────────────────
create or replace function public.entity_roles_deactivate(p_role text)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_roles;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if nullif(btrim(p_role), '') is null then
    perform public.platform_raise_error('PLT003', 'Role is required.');
  end if;

  if btrim(p_role) not in ('consumer', 'professional', 'merchant', 'rider') then
    perform public.platform_raise_error('PLT003', 'Invalid role value.');
  end if;

  update public.entity_roles
     set is_active = false
   where entity_id = auth.uid() and role = btrim(p_role)
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Role not found or already inactive.');
  end if;

  perform public.platform_audit_log_add(
    'entity_role_deactivate',
    'entity_roles',
    jsonb_build_object('role', btrim(p_role))
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Role deactivated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_roles_deactivate(text) is
  'Deactivates a fluid role for the calling entity (is_active = false). Does not DELETE — preserves history. Audit-logged.';

-- ─── 4. Profession bind (taxonomy binding + verification gate init) ─────────
create or replace function public.entity_profession_bind(p_profession_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entity_professions;
  v_profession public.professions;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;

  -- Verify profession exists and is active
  select * into v_profession
    from public.professions
   where id = p_profession_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if not v_profession.is_active then
    perform public.platform_raise_error('PLT004', 'Profession is not active.');
  end if;

  -- Insert binding; trade_verification_status defaults to 'unverified'
  -- (kept out of invoker grants so it can only move via EP-02 admin paths)
  begin
    insert into public.entity_professions (entity_id, profession_id, is_primary)
    values (auth.uid(), p_profession_id, false)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'Entity already bound to this profession.');
  end;

  perform public.platform_audit_log_add(
    'entity_profession_bind',
    'entity_professions',
    jsonb_build_object('profession_id', p_profession_id)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profession bound (unverified).',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_profession_bind(uuid) is
  'Binds a profession to the calling entity after validating existence and activity (PLT004 if missing/inactive). Duplicate bindings rejected (PLT005). New bindings land as trade_verification_status = unverified — no client path to pending/approved (EP-02 admin gate). Audit-logged.';

-- ─── 5. Credential submission (immutable pending record) ────────────────────
create or replace function public.entity_credentials_submit(
  p_kind text,
  p_title text,
  p_profession_id uuid default null,
  p_document_path text default null,
  p_expires_at timestamptz default null
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

  if btrim(p_kind) not in ('identity_document', 'trade_proof', 'certification') then
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

  -- verification_status defaults to 'pending' and submitted_at to now();
  -- both are kept out of invoker grants (immutable via this submit path).
  insert into public.entity_credentials (entity_id, profession_id, kind, title, document_path, expires_at)
  values (auth.uid(), p_profession_id, btrim(p_kind), btrim(p_title), p_document_path, p_expires_at)
  returning * into v_row;

  perform public.platform_audit_log_add(
    'entity_credentials_submit',
    'entity_credentials',
    jsonb_build_object(
      'kind', btrim(p_kind),
      'title', btrim(p_title),
      'profession_id', p_profession_id
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

comment on function public.entity_credentials_submit(text, text, uuid, text, timestamptz) is
  'Creates an immutable pending credential submission. kind/timestamped title validated; optional profession link validated (PLT004). Verification transitions (pending→approved/rejected) have zero client grant — reserved for EP-02 admin review gate. Audit-logged.';

-- ─── 6. Execute grants: anon receives nothing; authenticated + service_role ───
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