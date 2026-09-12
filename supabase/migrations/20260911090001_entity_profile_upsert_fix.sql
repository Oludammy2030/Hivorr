-- Corrective migration: entity_profile_update UPSERT fix
--
-- Root cause: the original entity_profile_update RPC performed only an UPDATE
-- (entity_model_rpcs.sql:76). New users have no entity_profiles row at onboarding
-- time — the row is only created on first "Save & Continue". The UPDATE matched
-- zero rows, raising PLT004 / 42501 and surfacing "Operation not permitted."
--
-- Fix: replace the UPDATE-only path with INSERT … ON CONFLICT (entity_id)
-- DO UPDATE so the RPC creates the profile on first call and updates it on
-- subsequent calls.  The legal-name guard trigger (entity_profile_legal_name_guard)
-- still fires on the UPDATE path; the INSERT path is safe because it flows
-- exclusively through this validated RPC (security invoker, authenticated-only).
--
-- No new SECURITY DEFINER functions. No privilege changes. No column grants
-- altered. The envelope contract (PLT000..PLT999) is preserved.

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
  v_is_insert boolean;
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

  -- Determine whether the profile already exists to decide insert vs update.
  -- On INSERT path the legal_name guard trigger does not fire (BEFORE UPDATE only),
  -- so no GUC setup is needed.  On UPDATE path the GUC must be set first.
  v_is_insert := not exists (
    select 1 from public.entity_profiles where entity_id = auth.uid()
  );

  if v_is_insert then
    -- Guard: first-time save must carry both required name fields.
    if p_legal_name is null or p_display_name is null then
      perform public.platform_raise_error(
        'PLT003',
        'Legal name and display name are required to create your profile.'
      );
    end if;

    insert into public.entity_profiles (entity_id, legal_name, display_name, bio)
    values (auth.uid(), btrim(p_legal_name), btrim(p_display_name), p_bio)
    returning * into v_row;
  else
    -- Existing profile: gated UPDATE (legal_name guard trigger enforces
    -- platform.rpc_invocation GUC — only this RPC may change legal_name).
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
  end if;

  perform public.platform_audit_log_add(
    'entity_profile_update',
    'entity_profiles',
    v_audit_details || jsonb_build_object('is_insert', v_is_insert)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', case when v_is_insert then 'Profile created.' else 'Profile updated.' end,
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_profile_update(text, text, text) is
  'Validated upsert of entity profile. Creates the profile row on first Save (new users) and updates it thereafter. legal_name (AGENT.md Rule 3 anchor) and display_name/bio trimmed and length-checked. Audit-logged. Direct column-level grants block raw legal_name updates — only this RPC path succeeds.';
