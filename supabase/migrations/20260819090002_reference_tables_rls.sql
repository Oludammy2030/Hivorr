-- EP-01-05: Reference Tables & RLS
--
-- Minimal, clearly-documented reference surface demonstrating the default-
-- deny RLS / RPC enforcement pattern (EP-01-05 Plan §5.5). This is NOT the
-- EP-01-06 Universal Entity model — it is the pattern template those entity
-- tables will follow.
--
-- Access model:
--   platform_audit_log      append-only; direct client access denied; writes
--                           flow exclusively through platform_audit_log_add.
--   platform_demo_records   owner-scoped; authenticated role receives the
--                           minimal SELECT/INSERT/UPDATE grants needed to
--                           prove per-user isolation under RLS.

-- ─── 1. platform_audit_log ──────────────────────────────────────────────────
create table public.platform_audit_log (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  entity text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  actor_id uuid,
  created_at timestamptz not null default now()
);

alter table public.platform_audit_log enable row level security;

revoke all on table public.platform_audit_log from anon, authenticated;

create index platform_audit_log_created_at_idx
  on public.platform_audit_log (created_at desc);

comment on table public.platform_audit_log is
  'Append-only audit trail. Direct client access is denied; writes occur only via public.platform_audit_log_add.';

-- ─── 2. platform_demo_records ───────────────────────────────────────────────
create table public.platform_demo_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  title text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid()
);

alter table public.platform_demo_records enable row level security;

-- Minimal grants for the approved RLS flow. No DELETE, no anon access.
grant select, insert, update on table public.platform_demo_records to authenticated;

-- Service tooling bypasses RLS but still requires explicit table grants.
grant select on table public.platform_demo_records to service_role;
grant select on table public.platform_audit_log to service_role;

-- Policy naming convention: <table>_<role>_<op>
create policy platform_demo_records_authenticated_select
  on public.platform_demo_records
  for select
  to authenticated
  using (owner_id = auth.uid());

create policy platform_demo_records_authenticated_insert
  on public.platform_demo_records
  for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy platform_demo_records_authenticated_update
  on public.platform_demo_records
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create trigger platform_demo_records_set_updated_at
  before update on public.platform_demo_records
  for each row
  execute function public.platform_set_updated_at();

create index platform_demo_records_owner_id_idx
  on public.platform_demo_records (owner_id);

create index platform_demo_records_created_at_idx
  on public.platform_demo_records (created_at desc);

create unique index platform_demo_records_owner_title_key
  on public.platform_demo_records (owner_id, title);

comment on table public.platform_demo_records is
  'Owner-scoped reference table demonstrating the default-deny RLS pattern. Documented as the pattern template that EP-01-06 entities follow.';

-- ─── 3. Realtime exclusion ──────────────────────────────────────────────────
-- Realtime must never expose these tables (EP-01-05 Plan §5.5, §12).

do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('platform_audit_log', 'platform_demo_records')
  ) then
    alter publication supabase_realtime
      drop table public.platform_audit_log, public.platform_demo_records;
  end if;
end;
$$;