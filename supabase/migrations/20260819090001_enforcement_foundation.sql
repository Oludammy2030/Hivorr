-- EP-01-05: Enforcement Foundation
--
-- Establishes the Database-First Zero-Trust posture that every future phase
-- inherits (EP-01-05 Plan §5.4):
--   1. Default-deny privilege posture on the public schema.
--   2. The audit-column convention for all future tables.
--   3. Auth-context, trigger, error, and validation helpers (platform_*).
--
-- Policy: the client is an unprivileged presentation layer. Direct table
-- access is granted only where the approved RLS pattern requires it; all
-- writes flow through RPC functions protected by Row-Level Security.

-- ─── 1. Default-deny posture ────────────────────────────────────────────────
-- Remove blanket privileges from anon and authenticated on current and future
-- public-schema objects. Only explicit grants (migrations 2 and 3) may
-- re-expose any surface.

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;

revoke create on schema public from anon, authenticated;

-- ─── 2. Audit-column convention ─────────────────────────────────────────────
-- Every future Hivorr table MUST include:
--   created_at timestamptz not null default now()
--   updated_at timestamptz not null default now()
--   created_by uuid default auth.uid()
-- and attach the platform_set_updated_at() trigger.
-- EP-01-06 (Universal Entity Data Model) inherits this convention.

-- ─── 3. Auth-context helpers ────────────────────────────────────────────────
create or replace function public.platform_is_authenticated()
returns boolean
language sql
stable
as $$
  select auth.uid() is not null;
$$;

create or replace function public.platform_current_user_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;

-- ─── 4. Updated-at trigger ──────────────────────────────────────────────────
create or replace function public.platform_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ─── 5. Typed error contract ────────────────────────────────────────────────
-- Envelope: {success, code, message, data}.
-- Codes: PLT000 success, PLT001 authentication required, PLT002 forbidden,
-- PLT003 validation failed, PLT004 not found, PLT005 conflict, PLT999 internal.
-- Messages are static and must never contain data values or credentials.
create or replace function public.platform_raise_error(
  p_code text,
  p_message text
)
returns void
language plpgsql
as $$
begin
  raise exception
    using errcode = 'P0001',
          message = format('%s: %s', p_code, p_message),
          detail = p_code;
end;
$$;

-- ─── 6. Payload validation ──────────────────────────────────────────────────
create or replace function public.platform_validate_payload(
  p_payload jsonb,
  p_required_keys text[] default '{}'
)
returns void
language plpgsql
as $$
declare
  v_missing text;
begin
  if p_payload is null then
    perform public.platform_raise_error('PLT003', 'Payload is required.');
  end if;

  if jsonb_typeof(p_payload) <> 'object' then
    perform public.platform_raise_error('PLT003', 'Payload must be a JSON object.');
  end if;

  if p_required_keys is not null then
    select string_agg(k, ', ' order by k)
      into v_missing
      from unnest(p_required_keys) as k
     where not p_payload ? k;

    if v_missing is not null then
      perform public.platform_raise_error(
        'PLT003',
        format('Missing required field(s): %s.', v_missing)
      );
    end if;
  end if;
end;
$$;

-- ─── 7. Helper execution grants ─────────────────────────────────────────────
-- Internal utilities only; they contain no data access. anon receives no
-- execute grant on any helper.

grant execute on function public.platform_is_authenticated() to authenticated, service_role;
grant execute on function public.platform_current_user_id() to authenticated, service_role;
grant execute on function public.platform_set_updated_at() to authenticated, service_role;
grant execute on function public.platform_raise_error(text, text) to authenticated, service_role;
grant execute on function public.platform_validate_payload(jsonb, text[]) to authenticated, service_role;

-- ─── 8. Documentation ───────────────────────────────────────────────────────
comment on function public.platform_is_authenticated() is
  'Returns true when the caller carries a valid authenticated JWT (auth.uid() is not null).';
comment on function public.platform_current_user_id() is
  'Returns the calling user''s id from the JWT context (auth.uid()).';
comment on function public.platform_set_updated_at() is
  'BEFORE UPDATE trigger function that sets updated_at = now().';
comment on function public.platform_raise_error(text, text) is
  'Raises a typed platform error. Message format: "<PLT-code>: <message>". Detail carries the PLT code.';
comment on function public.platform_validate_payload(jsonb, text[]) is
  'Validates that a payload is a JSON object containing all required keys, raising PLT003 otherwise.';