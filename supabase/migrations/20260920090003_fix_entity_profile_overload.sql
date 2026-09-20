-- Fix overload ambiguity from 20260920090001
-- Previous migration left two overloads: 3-arg (legacy) and 7-arg (new, with
-- p_first_name first). Positional calls like
--   select public.entity_profile_update('New Legal','New Display','bio')
-- became ambiguous (42725). Keep a single 7-arg function whose first 3
-- parameters match the legacy order so positional tests still pass, while
-- named RPC calls (supabase.rpc with p_first_name etc) work by name.

drop function if exists public.entity_profile_update(text, text, text);
drop function if exists public.entity_profile_update(text, text, text, text, text, text, text);

create or replace function public.entity_profile_update(
  p_legal_name text default null,
  p_display_name text default null,
  p_bio text default null,
  p_first_name text default null,
  p_middle_name text default null,
  p_last_name text default null,
  p_phone_number text default null
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
  v_first text;
  v_middle text;
  v_last text;
  v_phone text;
  v_display text;
  v_legal text;
  v_bio text;
  v_digits text;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  -- Normalize: btrim. Middle/phone may be null or empty.
  v_first := nullif(btrim(coalesce(p_first_name, '')), '');
  v_middle := nullif(btrim(coalesce(p_middle_name, '')), '');
  if p_middle_name is not null and btrim(coalesce(p_middle_name,'')) = '' then
    v_middle := null;
  end if;
  v_last := nullif(btrim(coalesce(p_last_name, '')), '');
  v_display := nullif(btrim(coalesce(p_display_name, '')), '');
  v_phone := nullif(btrim(coalesce(p_phone_number, '')), '');
  v_bio := p_bio;
  -- Legacy compat: if split names not supplied but legal_name is, split it
  if v_first is null and v_last is null and p_legal_name is not null and nullif(btrim(p_legal_name),'') is not null then
    declare
      v_parts text[] := regexp_split_to_array(btrim(p_legal_name), '\s+');
    begin
      if array_length(v_parts,1) = 1 then
        v_first := v_parts[1];
      elsif array_length(v_parts,1) = 2 then
        v_first := v_parts[1];
        v_last := v_parts[2];
      elsif array_length(v_parts,1) >= 3 then
        v_first := v_parts[1];
        v_last := v_parts[array_length(v_parts,1)];
        v_middle := array_to_string(v_parts[2:array_length(v_parts,1)-1], ' ');
      end if;
    end;
  end if;

  if p_first_name is not null or v_first is not null then
    if v_first is not null and char_length(v_first) > 120 then
      perform public.platform_raise_error('PLT003', 'First name must be 120 characters or fewer.');
    end if;
    if p_first_name is not null and v_first is null then
      perform public.platform_raise_error('PLT003', 'First name cannot be empty.');
    end if;
  end if;
  if p_middle_name is not null then
    if v_middle is not null and char_length(v_middle) > 120 then
      perform public.platform_raise_error('PLT003', 'Middle name must be 120 characters or fewer.');
    end if;
  end if;
  if p_last_name is not null or v_last is not null then
    if v_last is not null and char_length(v_last) > 120 then
      perform public.platform_raise_error('PLT003', 'Last name must be 120 characters or fewer.');
    end if;
    if p_last_name is not null and v_last is null then
      perform public.platform_raise_error('PLT003', 'Last name cannot be empty.');
    end if;
  end if;
  if p_display_name is not null then
    if v_display is null then
      perform public.platform_raise_error('PLT003', 'Display name cannot be empty.');
    end if;
    if char_length(v_display) > 255 then
      perform public.platform_raise_error('PLT003', 'Display name must be 255 characters or fewer.');
    end if;
  end if;
  if p_phone_number is not null then
    if v_phone is not null then
      v_digits := regexp_replace(v_phone, '\D', '', 'g');
      if char_length(v_digits) < 7 or char_length(v_digits) > 15 then
        perform public.platform_raise_error('PLT003', 'Enter a valid phone number.');
      end if;
      if v_phone !~ '^\+?[0-9\s\-()]{7,20}$' then
        perform public.platform_raise_error('PLT003', 'Enter a valid phone number.');
      end if;
    else
      perform public.platform_raise_error('PLT003', 'Phone number cannot be empty.');
    end if;
  end if;
  if p_bio is not null then
    if char_length(btrim(coalesce(v_bio,''))) > 5000 then
      perform public.platform_raise_error('PLT003', 'Bio must be 5000 characters or fewer.');
    end if;
  end if;

  v_is_insert := not exists (
    select 1 from public.entity_profiles where entity_id = auth.uid()
  );

  if v_is_insert then
    if v_first is null or v_last is null or v_display is null or v_phone is null then
      perform public.platform_raise_error('PLT003', 'First name, last name, display name, and phone number are required to create your profile.');
    end if;
    if v_middle is not null and v_middle <> '' then
      v_legal := v_first || ' ' || v_middle || ' ' || v_last;
    else
      v_legal := v_first || ' ' || v_last;
    end if;
    if char_length(v_legal) > 255 then
      perform public.platform_raise_error('PLT003', 'Legal name must be 255 characters or fewer.');
    end if;
    v_audit_details := jsonb_build_object('first_name', v_first, 'last_name', v_last, 'display_name', v_display, 'is_insert', true);
    insert into public.entity_profiles (entity_id, first_name, middle_name, last_name, legal_name, display_name, phone_number, bio)
    values (auth.uid(), v_first, v_middle, v_last, v_legal, v_display, v_phone, v_bio)
    returning * into v_row;
  else
    declare
      v_cur public.entity_profiles;
    begin
      select * into v_cur from public.entity_profiles where entity_id = auth.uid();
      v_first := coalesce(v_first, v_cur.first_name);
      if p_middle_name is not null then
        v_middle := nullif(btrim(coalesce(p_middle_name, '')), '');
        if p_middle_name is not null and btrim(coalesce(p_middle_name,'')) = '' then
          v_middle := null;
        end if;
      else
        v_middle := v_cur.middle_name;
      end if;
      v_last := coalesce(v_last, v_cur.last_name);
      v_display := coalesce(v_display, v_cur.display_name);
      v_phone := coalesce(v_phone, v_cur.phone_number);
      if p_bio is null then
        v_bio := v_cur.bio;
      else
        v_bio := p_bio;
      end if;
      if p_first_name is not null or p_middle_name is not null or p_last_name is not null or v_cur.legal_name is null then
        if v_first is not null and v_last is not null then
          if v_middle is not null and v_middle <> '' then
            v_legal := v_first || ' ' || v_middle || ' ' || v_last;
          else
            v_legal := v_first || ' ' || v_last;
          end if;
          if char_length(v_legal) > 255 then
            perform public.platform_raise_error('PLT003', 'Legal name must be 255 characters or fewer.');
          end if;
        else
          v_legal := v_cur.legal_name;
        end if;
      else
        v_legal := v_cur.legal_name;
      end if;

      if p_first_name is not null then v_audit_details := v_audit_details || jsonb_build_object('first_name', v_first); v_updated := true; end if;
      if p_middle_name is not null then v_audit_details := v_audit_details || jsonb_build_object('middle_name', v_middle); v_updated := true; end if;
      if p_last_name is not null then v_audit_details := v_audit_details || jsonb_build_object('last_name', v_last); v_updated := true; end if;
      if p_display_name is not null then v_audit_details := v_audit_details || jsonb_build_object('display_name', v_display); v_updated := true; end if;
      if p_phone_number is not null then v_audit_details := v_audit_details || jsonb_build_object('phone_number', v_phone); v_updated := true; end if;
      if p_bio is not null then v_audit_details := v_audit_details || jsonb_build_object('bio', v_bio); v_updated := true; end if;
      if p_legal_name is not null and p_first_name is null and p_middle_name is null and p_last_name is null then
        v_updated := true;
      end if;
      if not v_updated and p_bio is null and p_legal_name is null then
        if p_first_name is null and p_middle_name is null and p_last_name is null and p_display_name is null and p_phone_number is null then
          perform public.platform_raise_error('PLT003', 'At least one field must be provided.');
        end if;
      end if;

      perform set_config('platform.rpc_invocation', 'on', true);
      update public.entity_profiles
         set first_name = v_first,
             middle_name = v_middle,
             last_name = v_last,
             legal_name = v_legal,
             display_name = v_display,
             phone_number = v_phone,
             bio = v_bio
       where entity_id = auth.uid()
      returning * into v_row;
      if not found then
        perform public.platform_raise_error('PLT004', 'Profile not found.');
      end if;
      v_audit_details := v_audit_details || jsonb_build_object('is_insert', false);
    end;
  end if;

  perform public.platform_audit_log_add(
    'entity_profile_update',
    'entity_profiles',
    v_audit_details
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', case when v_is_insert then 'Profile created.' else 'Profile updated.' end,
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.entity_profile_update(text, text, text, text, text, text, text) is
  'Validated upsert of entity profile with split identity (first/middle/last, display_name, phone_number, bio). legal_name derived server-side. Backward-compatible positional call (p_legal_name, p_display_name, p_bio) kept as first 3 params.';

-- Grants for the single 7-arg overload (named RPC via PostgREST)
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
grant execute on function public.entity_profile_update(text, text, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.entity_roles_activate(text) to authenticated, service_role;
grant execute on function public.entity_roles_deactivate(text) to authenticated, service_role;
grant execute on function public.entity_profession_bind(uuid) to authenticated, service_role;
grant execute on function public.entity_credentials_submit(text, text, uuid, text, timestamptz) to authenticated, service_role;
grant execute on function public.entity_onboarding_status_update(text, boolean) to authenticated, service_role;
grant execute on function public.entity_onboarding_status_get() to authenticated, service_role;
grant execute on function public.entity_onboarding_reset(uuid) to service_role;
grant execute on function public.verification_submit(uuid, text) to authenticated, service_role;
grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
grant execute on function public.verification_kyc_level_get() to authenticated, service_role;
grant execute on function public.verification_limits_get() to authenticated, service_role;
grant execute on function public.verification_review_approve(uuid, text) to authenticated, service_role;
grant execute on function public.verification_review_reject(uuid, text, boolean) to authenticated, service_role;
grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_check() to authenticated, service_role;
grant execute on function public.platform_admin_provision(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_revoke(uuid) to authenticated, service_role;
grant execute on function public.platform_admin_list() to authenticated, service_role;
grant execute on function public.verification_review_queue_get(text, int, int, text) to authenticated, service_role;
grant execute on function public.verification_review_start(uuid) to authenticated, service_role;
grant execute on function public.verification_review_audit_get(uuid) to authenticated, service_role;
grant execute on function public.manage_user_list(text, text, int, int) to authenticated, service_role;
grant execute on function public.manage_user_get(uuid) to authenticated, service_role;
grant execute on function public.manage_user_set_status(uuid, text) to authenticated, service_role;
grant execute on function public.manage_user_reset_onboarding(uuid) to authenticated, service_role;
