-- EP-02-18 Registration Identity Extension
--
-- Restructures registration to capture basic identity at account creation while
-- keeping onboarding focused on capability / professional configuration (plan
-- §2-§7, reuse-first §1). Extends the authoritative `entity_profiles` table
-- which already holds the 1:1 profile (20260821090002) instead of creating a
-- duplicate identity table.
--
-- Schema:
--   entity_profiles.first_name   text  required on create, 1-120 (btrim)
--   entity_profiles.middle_name  text  optional, 0-120 (btrim)
--   entity_profiles.last_name    text  required on create, 1-120 (btrim)
--   entity_profiles.phone_number text  required on create, 7-15 digits E.164
--
-- legal_name remains the financial anchor (AGENT.md Rule 3) and is derived
-- server-side from first+middle+last so existing logic / RLS / audit remain
-- valid. Direct `legal_name` mutation still requires the RPC GUC guard
-- (20260821090006). New columns participate in `entity_profiles_authenticated_update`
-- via column-level ACL narrowing (D5 pattern, 20260915090001 §2).
--
-- RPC:
--   entity_profile_update(p_first_name, p_middle_name, p_last_name,
--                         p_display_name, p_phone_number, p_bio, [p_legal_name legacy])
--   Backwards-compatible: legacy callers passing only p_legal_name/p_display_name/p_bio
--   continue to work (first/last derived by split). New registration path
--   passes split names + phone; legal_name derived as trim(first + ' ' + middle + ' ' + last).
--
-- No new SECURITY DEFINER. Envelope {success,code,message,data} + PLT contract.
-- No data deletion. Nullable columns for existing rows (backfill optional, offline).

-- ─── 1. Columns ───────────────────────────────────────────────────────────
alter table public.entity_profiles
  add column if not exists first_name text,
  add column if not exists middle_name text,
  add column if not exists last_name text,
  add column if not exists phone_number text;

comment on column public.entity_profiles.first_name is
  'Given name captured at registration. Required on profile creation; 1-120 chars (btrim). Part of the derived legal_name anchor.';
comment on column public.entity_profiles.middle_name is
  'Middle name captured at registration. Optional; 0-120 chars (btrim). Included in legal_name when present.';
comment on column public.entity_profiles.last_name is
  'Family name captured at registration. Required on profile creation; 1-120 chars (btrim). Part of the derived legal_name anchor.';
comment on column public.entity_profiles.phone_number is
  'Contact phone captured at registration. Required on profile creation; 7-15 digits after stripping formatting. Minimal-PII extension for account identity.';

-- ─── 2. Constraints ───────────────────────────────────────────────────────
-- Length checks use btrim parity with RPC validation.
alter table public.entity_profiles
  add constraint entity_profiles_first_name_length check (
    first_name is null or char_length(btrim(first_name)) between 1 and 120
  ),
  add constraint entity_profiles_middle_name_length check (
    middle_name is null or middle_name = '' or char_length(btrim(middle_name)) between 1 and 120
  ),
  add constraint entity_profiles_last_name_length check (
    last_name is null or char_length(btrim(last_name)) between 1 and 120
  ),
  add constraint entity_profiles_phone_format check (
    phone_number is null or
    (
      char_length(regexp_replace(phone_number, '\D', '', 'g')) between 7 and 15
      and phone_number ~ '^\+?[0-9\s\-()]{7,20}$'
    )
  );

-- ─── 3. Column-level grants (D5 narrowing) ─────────────────────────────────
-- Existing grants from 20260821090006 included legal_name et al. Extend to
-- include the new columns so the RLS UPDATE policies can enforce self-scope
-- while RPC remains the validated path for legal_name derivation.
revoke all on table public.entity_profiles from anon, authenticated;

grant select, insert on table public.entity_profiles to authenticated;
grant update (entity_id, first_name, middle_name, last_name, display_name, bio, avatar_path, country_code, phone_number)
  on table public.entity_profiles to authenticated;
-- legal_name remains updatable only via RPC GUC (trigger guards it), but grant
-- must exist so the RPC (invoker running as authenticated JWT) can write it.
grant update (legal_name)
  on table public.entity_profiles to authenticated;
grant select on table public.entity_profiles to service_role;

-- Re-create RLS policies (idempotent) — they reference auth.uid() self-scope.
drop policy if exists entity_profiles_authenticated_select on public.entity_profiles;
create policy entity_profiles_authenticated_select
  on public.entity_profiles for select to authenticated
  using (entity_id = auth.uid());

drop policy if exists entity_profiles_authenticated_insert on public.entity_profiles;
create policy entity_profiles_authenticated_insert
  on public.entity_profiles for insert to authenticated
  with check (entity_id = auth.uid());

drop policy if exists entity_profiles_authenticated_update on public.entity_profiles;
create policy entity_profiles_authenticated_update
  on public.entity_profiles for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

-- ─── 4. RPC: entity_profile_update — extended signature ───────────────────
-- Replaces 20260911090001 implementation. Keeps security invoker + PLT envelope.
-- Adds p_first_name, p_middle_name, p_last_name, p_phone_number. Legal_name is
-- derived from names when provided; legacy callers may still pass p_legal_name
-- (which is split-derived backwards) for compatibility with existing onboarding.
create or replace function public.entity_profile_update(
  p_first_name text default null,
  p_middle_name text default null,
  p_last_name text default null,
  p_display_name text default null,
  p_phone_number text default null,
  p_bio text default null,
  p_legal_name text default null
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
  -- Keep empty string vs null distinction for middle_name (optional)
  if p_middle_name is not null and btrim(p_middle_name) = '' then
    v_middle := null;
  end if;
  -- Better: allow explicitly clearing middle_name via empty string -> null
  if p_middle_name is not null and btrim(coalesce(p_middle_name,'')) = '' then
    v_middle := null;
  end if;
  v_last := nullif(btrim(coalesce(p_last_name, '')), '');
  v_display := nullif(btrim(coalesce(p_display_name, '')), '');
  v_phone := nullif(btrim(coalesce(p_phone_number, '')), '');
  v_bio := p_bio; -- validated later
  -- Legacy compat: if names not supplied but legal_name is, split it
  if v_first is null and v_last is null and p_legal_name is not null and nullif(btrim(p_legal_name),'') is not null then
    -- Split legacy legal_name into first/middle/last for insertion compatibility
    -- first token = first_name, last token = last_name, middle = remainder
    declare
      v_parts text[] := regexp_split_to_array(btrim(p_legal_name), '\s+');
    begin
      if array_length(v_parts,1) = 1 then
        v_first := v_parts[1];
        -- last_name remains null -> will fail required check on insert (expected, caller must supply split)
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

  -- Validation per field when supplied (or required on insert, checked below)
  if p_first_name is not null or v_first is not null then
    if v_first is not null and char_length(v_first) > 120 then
      perform public.platform_raise_error('PLT003', 'First name must be 120 characters or fewer.');
    end if;
    -- When p_first_name supplied explicitly, enforce non-empty (caller intended to set it)
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

  -- Determine insert vs update
  v_is_insert := not exists (
    select 1 from public.entity_profiles where entity_id = auth.uid()
  );

  if v_is_insert then
    -- Creation requires split names, display_name, phone
    if v_first is null or v_last is null or v_display is null or v_phone is null then
      perform public.platform_raise_error('PLT003', 'First name, last name, display name, and phone number are required to create your profile.');
    end if;
    -- Derive legal_name from components
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
    -- Update path: derive legal_name if any name component is changing
    -- Fetch current row for coalescing
    declare
      v_cur public.entity_profiles;
    begin
      select * into v_cur from public.entity_profiles where entity_id = auth.uid();
      v_first := coalesce(v_first, v_cur.first_name);
      -- middle_name: allow clearing via explicit null/empty when param was provided
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
      -- v_bio coalesce: allow explicit null to clear? keep semantics of original: bio = p_bio (which may be null -> not updating? original used coalesce for names but bio = p_bio (allowing clearing). We preserve: if p_bio is not null, use it else keep cur.)
      if p_bio is null then
        v_bio := v_cur.bio;
      else
        v_bio := p_bio;
      end if;
      -- Derive legal_name from resolved components if any name changed
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

      -- Track audit
      if p_first_name is not null then v_audit_details := v_audit_details || jsonb_build_object('first_name', v_first); v_updated := true; end if;
      if p_middle_name is not null then v_audit_details := v_audit_details || jsonb_build_object('middle_name', v_middle); v_updated := true; end if;
      if p_last_name is not null then v_audit_details := v_audit_details || jsonb_build_object('last_name', v_last); v_updated := true; end if;
      if p_display_name is not null then v_audit_details := v_audit_details || jsonb_build_object('display_name', v_display); v_updated := true; end if;
      if p_phone_number is not null then v_audit_details := v_audit_details || jsonb_build_object('phone_number', v_phone); v_updated := true; end if;
      if p_bio is not null then v_audit_details := v_audit_details || jsonb_build_object('bio', v_bio); v_updated := true; end if;
      -- Also consider legacy legal_name param alone as update intent
      if p_legal_name is not null and p_first_name is null and p_middle_name is null and p_last_name is null then
        v_updated := true;
      end if;
      if not v_updated and p_bio is null and p_legal_name is null then
        -- At least one mutable field should be provided, but allow no-op? Keep PLT003 for empty update like original.
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
  'Validated upsert of entity profile with split identity (first/middle/last, display_name, phone_number, bio). legal_name derived server-side from names for AGENT.md Rule 3. Backwards-compatible with legacy p_legal_name callers via split. Audit-logged. Direct legal_name patch still guarded.';

-- ─── 5. Grants ──────────────────────────────────────────────────────────────
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
