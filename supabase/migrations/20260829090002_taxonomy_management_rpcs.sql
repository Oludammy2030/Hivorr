-- EP-02-02: Taxonomy Management RPCs & Server-Side Registry
--
-- Builds the server-side management layer over the two-tier taxonomy registry
-- (industries → professions), seeded in EP-02-01 (migration
-- 20260829090001_taxonomy_seed_data.sql).
--
-- Execution model: SECURITY INVOKER for all 7 RPCs (no new SECURITY DEFINER),
-- consistent with EP-01-05 / EP-01-06 RPC conventions. RLS applies inside the
-- function body.
--
-- Read RPCs (public): `taxonomy_industries_list`, `taxonomy_professions_list`
--   Granted to anon, authenticated, service_role. Data is public classification
--   (names, slugs, descriptions); the existing SELECT RLS policies (using true)
--   permit open read. Returns the standard {success, code, message, data}
--   envelope with data as a JSON array ordered by sort_order.
--
-- Write RPCs (service-role only): `taxonomy_industry_create`,
--   `taxonomy_industry_update`, `taxonomy_profession_create`,
--   `taxonomy_profession_update`, `taxonomy_profession_move`
--   EXECUTE granted to service_role ONLY. anon / authenticated receive 42501
--   (insufficient privilege) before the function body runs — the EXECUTE grant
--   is the authorization gate. No explicit platform_is_authenticated() check is
--   required because the grant already denies non-service-role callers.
--
-- All write RPCs reuse platform_raise_error() for normalized PLT### errors and
-- platform_audit_log_add() for an immutable audit trail. The audit call requires
-- an authenticated context (admin identity carried in the JWT sub); admin
-- tooling invoking these via the service_role key must pass the acting admin's
-- user id in the request JWT so actions remain attributable.
--
-- No DDL, no RLS policy changes, no table-level GRANT/REVOKE. Idempotent
-- re-runs replace the function definitions without altering data or schema.

-- ─── 1. Read RPC: industries list ──────────────────────────────────────────────
create or replace function public.taxonomy_industries_list(
  p_include_inactive boolean default false
)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_rows jsonb;
begin
  select jsonb_agg(to_jsonb(i) order by i.sort_order)
    into v_rows
    from public.industries i
   where i.is_active or p_include_inactive;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Industries retrieved.',
    'data', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

comment on function public.taxonomy_industries_list(boolean) is
  'Public read: returns all industries ordered by sort_order. Defaults to active-only; pass p_include_inactive=true for admin views. SECURITY INVOKER; granted to anon, authenticated, service_role.';

-- ─── 2. Read RPC: professions list ────────────────────────────────────────────
create or replace function public.taxonomy_professions_list(
  p_industry_id uuid default null,
  p_include_inactive boolean default false
)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_rows jsonb;
begin
  select jsonb_agg(to_jsonb(p) order by p.sort_order)
    into v_rows
    from public.professions p
   where (p.industry_id = p_industry_id or p_industry_id is null)
     and (p.is_active or p_include_inactive);

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Professions retrieved.',
    'data', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

comment on function public.taxonomy_professions_list(uuid, boolean) is
  'Public read: returns professions filtered by p_industry_id (null = all), ordered by sort_order. Defaults to active-only. SECURITY INVOKER; granted to anon, authenticated, service_role.';

-- ─── 3. Write RPC: industry create ────────────────────────────────────────────
create or replace function public.taxonomy_industry_create(
  p_slug text,
  p_name text,
  p_description text default null,
  p_sort_order integer default 0
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_slug text := btrim(p_slug);
  v_name text := btrim(p_name);
  v_row public.industries;
begin
  -- Validation
  if v_slug is null or v_slug = '' then
    perform public.platform_raise_error('PLT003', 'Industry slug is required.');
  end if;
  if v_slug <> lower(v_slug) then
    perform public.platform_raise_error('PLT003', 'Industry slug must be lowercase.');
  end if;
  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    perform public.platform_raise_error('PLT003', 'Industry slug format is invalid. Use lowercase letters, numbers, and single hyphens only.');
  end if;
  if char_length(v_slug) > 140 then
    perform public.platform_raise_error('PLT003', 'Industry slug must be 140 characters or fewer.');
  end if;
  if v_name is null or v_name = '' then
    perform public.platform_raise_error('PLT003', 'Industry name is required.');
  end if;
  if char_length(v_name) > 255 then
    perform public.platform_raise_error('PLT003', 'Industry name must be 255 characters or fewer.');
  end if;

  -- Uniqueness pre-check (meaningful PLT005 instead of raw 23505)
  if exists (select 1 from public.industries where slug = v_slug) then
    perform public.platform_raise_error('PLT005', 'An industry with this slug already exists.');
  end if;

  -- Insert (service_role bypasses RLS)
  begin
    insert into public.industries (slug, name, description, sort_order, created_by)
    values (v_slug, v_name, nullif(btrim(p_description), ''), p_sort_order, null)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'An industry with this slug already exists.');
  end;

  -- Audit trail
  perform public.platform_audit_log_add(
    'taxonomy_industry_create',
    'industries',
    jsonb_build_object('slug', v_slug, 'name', v_name)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Industry created.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.taxonomy_industry_create(text, text, text, integer) is
  'Service-role write: creates an industry after slug/name validation and slug-uniqueness check. Audit-logged. EXECUTE granted to service_role only.';

-- ─── 4. Write RPC: industry update ────────────────────────────────────────────
create or replace function public.taxonomy_industry_update(
  p_industry_id uuid,
  p_name text default null,
  p_description text default null,
  p_sort_order integer default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_name text := btrim(p_name);
  v_row public.industries;
begin
  -- At least one field must be provided
  if p_name is null and p_description is null and p_sort_order is null and p_is_active is null then
    perform public.platform_raise_error('PLT003', 'At least one field must be provided for update.');
  end if;

  -- Existence check
  if not exists (select 1 from public.industries where id = p_industry_id) then
    perform public.platform_raise_error('PLT004', 'Industry not found.');
  end if;

  -- Field validation
  if v_name is not null and v_name = '' then
    perform public.platform_raise_error('PLT003', 'Industry name cannot be empty.');
  end if;
  if v_name is not null and char_length(v_name) > 255 then
    perform public.platform_raise_error('PLT003', 'Industry name must be 255 characters or fewer.');
  end if;

  update public.industries
     set name = coalesce(v_name, name),
         description = case when p_description is not null then nullif(btrim(p_description), '') else description end,
         sort_order = coalesce(p_sort_order, sort_order),
         is_active = coalesce(p_is_active, is_active)
   where id = p_industry_id
   returning * into v_row;

  perform public.platform_audit_log_add(
    'taxonomy_industry_update',
    'industries',
    jsonb_build_object(
      'industry_id', p_industry_id,
      'name', v_name,
      'description', p_description,
      'sort_order', p_sort_order,
      'is_active', p_is_active
    )
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Industry updated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.taxonomy_industry_update(uuid, text, text, integer, boolean) is
  'Service-role write: partial update of an industry (name, description, sort_order, is_active). Unknown id raises PLT004. Audit-logged. EXECUTE granted to service_role only.';

-- ─── 5. Write RPC: profession create ──────────────────────────────────────────
create or replace function public.taxonomy_profession_create(
  p_industry_id uuid,
  p_slug text,
  p_name text,
  p_description text default null,
  p_sort_order integer default 0
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_slug text := btrim(p_slug);
  v_name text := btrim(p_name);
  v_industry_active boolean;
  v_row public.professions;
begin
  -- Validation
  if p_industry_id is null then
    perform public.platform_raise_error('PLT003', 'Industry id is required.');
  end if;
  if v_slug is null or v_slug = '' then
    perform public.platform_raise_error('PLT003', 'Profession slug is required.');
  end if;
  if v_slug <> lower(v_slug) then
    perform public.platform_raise_error('PLT003', 'Profession slug must be lowercase.');
  end if;
  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    perform public.platform_raise_error('PLT003', 'Profession slug format is invalid. Use lowercase letters, numbers, and single hyphens only.');
  end if;
  if char_length(v_slug) > 140 then
    perform public.platform_raise_error('PLT003', 'Profession slug must be 140 characters or fewer.');
  end if;
  if v_name is null or v_name = '' then
    perform public.platform_raise_error('PLT003', 'Profession name is required.');
  end if;
  if char_length(v_name) > 255 then
    perform public.platform_raise_error('PLT003', 'Profession name must be 255 characters or fewer.');
  end if;

  -- Industry existence + active check
  select i.is_active into v_industry_active
    from public.industries i
   where i.id = p_industry_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Industry not found.');
  end if;
  if not v_industry_active then
    perform public.platform_raise_error('PLT004', 'Industry is not active.');
  end if;

  -- Uniqueness pre-check
  if exists (select 1 from public.professions where slug = v_slug) then
    perform public.platform_raise_error('PLT005', 'A profession with this slug already exists.');
  end if;

  -- Insert
  begin
    insert into public.professions (industry_id, slug, name, description, sort_order, created_by)
    values (p_industry_id, v_slug, v_name, nullif(btrim(p_description), ''), p_sort_order, null)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'A profession with this slug already exists.');
    when foreign_key_violation then
      perform public.platform_raise_error('PLT004', 'Industry not found.');
  end;

  perform public.platform_audit_log_add(
    'taxonomy_profession_create',
    'professions',
    jsonb_build_object('industry_id', p_industry_id, 'slug', v_slug, 'name', v_name)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profession created.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.taxonomy_profession_create(uuid, text, text, text, integer) is
  'Service-role write: creates a profession under an existing active industry. Validates slug/name, industry FK, and slug uniqueness. Audit-logged. EXECUTE granted to service_role only.';

-- ─── 6. Write RPC: profession update ──────────────────────────────────────────
create or replace function public.taxonomy_profession_update(
  p_profession_id uuid,
  p_name text default null,
  p_description text default null,
  p_sort_order integer default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_name text := btrim(p_name);
  v_row public.professions;
begin
  if p_name is null and p_description is null and p_sort_order is null and p_is_active is null then
    perform public.platform_raise_error('PLT003', 'At least one field must be provided for update.');
  end if;

  if not exists (select 1 from public.professions where id = p_profession_id) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if v_name is not null and v_name = '' then
    perform public.platform_raise_error('PLT003', 'Profession name cannot be empty.');
  end if;
  if v_name is not null and char_length(v_name) > 255 then
    perform public.platform_raise_error('PLT003', 'Profession name must be 255 characters or fewer.');
  end if;

  update public.professions
     set name = coalesce(v_name, name),
         description = case when p_description is not null then nullif(btrim(p_description), '') else description end,
         sort_order = coalesce(p_sort_order, sort_order),
         is_active = coalesce(p_is_active, is_active)
   where id = p_profession_id
   returning * into v_row;

  perform public.platform_audit_log_add(
    'taxonomy_profession_update',
    'professions',
    jsonb_build_object(
      'profession_id', p_profession_id,
      'name', v_name,
      'description', p_description,
      'sort_order', p_sort_order,
      'is_active', p_is_active
    )
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profession updated.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.taxonomy_profession_update(uuid, text, text, integer, boolean) is
  'Service-role write: partial update of a profession (name, description, sort_order, is_active). Unknown id raises PLT004. Audit-logged. EXECUTE granted to service_role only.';

-- ─── 7. Write RPC: profession move (re-parent) ────────────────────────────────
create or replace function public.taxonomy_profession_move(
  p_profession_id uuid,
  p_new_industry_id uuid
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_profession public.professions;
  v_new_industry_active boolean;
  v_old_industry_id uuid;
begin
  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;
  if p_new_industry_id is null then
    perform public.platform_raise_error('PLT003', 'New industry id is required.');
  end if;

  -- Profession existence
  select * into v_profession
    from public.professions
   where id = p_profession_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  -- No-op detection
  if v_profession.industry_id = p_new_industry_id then
    perform public.platform_raise_error('PLT003', 'Profession is already in the target industry.');
  end if;

  -- Target industry existence + active
  select i.is_active into v_new_industry_active
    from public.industries i
   where i.id = p_new_industry_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Industry not found.');
  end if;
  if not v_new_industry_active then
    perform public.platform_raise_error('PLT004', 'Industry is not active.');
  end if;

  v_old_industry_id := v_profession.industry_id;

  update public.professions
     set industry_id = p_new_industry_id
   where id = p_profession_id
   returning * into v_profession;

  perform public.platform_audit_log_add(
    'taxonomy_profession_move',
    'professions',
    jsonb_build_object(
      'profession_id', p_profession_id,
      'old_industry_id', v_old_industry_id,
      'new_industry_id', p_new_industry_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Profession moved to new industry.',
    'data', to_jsonb(v_profession)
  );
end;
$$;

comment on function public.taxonomy_profession_move(uuid, uuid) is
  'Service-role write: re-parents a profession to a different active industry. Validates both existence and rejects same-industry no-op. Audit-logged with old/new industry ids. EXECUTE granted to service_role only.';

-- ─── 8. EXECUTE grants: revoke from public pseudo-role, then grant explicitly ─
revoke execute on all functions in schema public from public;

-- Read RPCs: public access
grant execute on function public.taxonomy_industries_list(boolean) to anon, authenticated, service_role;
grant execute on function public.taxonomy_professions_list(uuid, boolean) to anon, authenticated, service_role;

-- Write RPCs: service-role only
grant execute on function public.taxonomy_industry_create(text, text, text, integer) to service_role;
grant execute on function public.taxonomy_industry_update(uuid, text, text, integer, boolean) to service_role;
grant execute on function public.taxonomy_profession_create(uuid, text, text, text, integer) to service_role;
grant execute on function public.taxonomy_profession_update(uuid, text, text, integer, boolean) to service_role;
grant execute on function public.taxonomy_profession_move(uuid, uuid) to service_role;
