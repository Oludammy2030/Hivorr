-- EP-01-05: Foundational RPC Set
--
-- Server-side enforcement patterns (EP-01-05 Plan §5.6): health probe,
-- authenticated read, validated write, owner-guarded update, and the
-- security-definer audit path.
--
-- Execution model:
--   SECURITY INVOKER by default so RLS applies inside every RPC.
--   SECURITY DEFINER only for platform_audit_log_add with a pinned
--   search_path = pg_catalog, public.
-- Every non-health RPC performs an explicit authentication check (PLT001)
-- in addition to the narrowed EXECUTE grants.

-- ─── 1. Health probe (public) ───────────────────────────────────────────────
create or replace function public.platform_health()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Platform connected.',
    'data', jsonb_build_object(
      'status', 'ok',
      'service', 'hivorr-platform',
      'server_time', now()
    )
  );
$$;

-- ─── 2. Authenticated read ──────────────────────────────────────────────────
create or replace function public.platform_demo_records_get(p_id uuid)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_row public.platform_demo_records;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_id is null then
    perform public.platform_raise_error('PLT003', 'Record id is required.');
  end if;

  select * into v_row
    from public.platform_demo_records
   where id = p_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Record not found.');
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Record retrieved.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- ─── 3. Validated write ─────────────────────────────────────────────────────
create or replace function public.platform_demo_records_create(
  p_title text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.platform_demo_records;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if nullif(btrim(p_title), '') is null then
    perform public.platform_raise_error('PLT003', 'Title is required.');
  end if;

  if char_length(btrim(p_title)) > 255 then
    perform public.platform_raise_error(
      'PLT003',
      'Title must be 255 characters or fewer.'
    );
  end if;

  perform public.platform_validate_payload(p_payload);

  begin
    insert into public.platform_demo_records (title, payload)
    values (btrim(p_title), p_payload)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error(
        'PLT005',
        'A record with this title already exists.'
      );
  end;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Record created.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- ─── 4. Owner-guarded update ────────────────────────────────────────────────
create or replace function public.platform_demo_records_update(
  p_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.platform_demo_records;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_id is null then
    perform public.platform_raise_error('PLT003', 'Record id is required.');
  end if;

  perform public.platform_validate_payload(p_payload);

  update public.platform_demo_records
     set payload = p_payload
   where id = p_id
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Record not found.');
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Record updated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- ─── 5. Security-definer audit path ─────────────────────────────────────────
create or replace function public.platform_audit_log_add(
  p_action text,
  p_entity text,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_id uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if nullif(btrim(p_action), '') is null then
    perform public.platform_raise_error('PLT003', 'Audit action is required.');
  end if;

  if nullif(btrim(p_entity), '') is null then
    perform public.platform_raise_error('PLT003', 'Audit entity is required.');
  end if;

  insert into public.platform_audit_log (action, entity, details, actor_id)
  values (btrim(p_action), btrim(p_entity), coalesce(p_details, '{}'::jsonb), auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

-- ─── 6. Execute grants: anon receives only the health probe ─────────────────
revoke execute on all functions in schema public from public;

grant execute on function public.platform_health() to anon, authenticated, service_role;
grant execute on function public.platform_demo_records_get(uuid) to authenticated, service_role;
grant execute on function public.platform_demo_records_create(text, jsonb) to authenticated, service_role;
grant execute on function public.platform_demo_records_update(uuid, jsonb) to authenticated, service_role;
grant execute on function public.platform_audit_log_add(text, text, jsonb) to authenticated, service_role;

-- ─── 7. Contract documentation ──────────────────────────────────────────────
comment on function public.platform_health() is
  'Public connectivity probe. Returns {success, code, message, data} with code PLT000.';
comment on function public.platform_demo_records_get(uuid) is
  'Security invoker. Requires authentication (PLT001). Returns the caller-owned record or PLT004.';
comment on function public.platform_demo_records_create(text, jsonb) is
  'Security invoker. Requires authentication (PLT001). Validates inputs (PLT003) and rejects duplicate owner titles (PLT005).';
comment on function public.platform_demo_records_update(uuid, jsonb) is
  'Security invoker. Requires authentication (PLT001). Owner-guarded via RLS; PLT004 when missing or not owned.';
comment on function public.platform_audit_log_add(text, text, jsonb) is
  'Security definer with pinned search_path. Requires authentication (PLT001). Writes the audit trail; direct table access remains denied.';