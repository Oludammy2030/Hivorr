-- EP-01-06: Entity Model RLS, Grants & Realtime Exclusion
--
-- Default-deny posture applied to all nine entity-model tables. Explicit
-- minimal grants mirroring the proven platform_demo_records pattern plus
-- column-level ACLs protecting privileged verification state (decision D5).
-- Realtime excluded from all nine tables.
--
-- Inherits: EP-01-05 migration 1 default-privilege revokes + platform_*
-- helpers + platform_set_updated_at() trigger + PLT### error contract.

-- ─── 1. RLS enablement ──────────────────────────────────────────────────────
alter table public.entities enable row level security;
alter table public.entity_profiles enable row level security;
alter table public.entity_roles enable row level security;
alter table public.entity_credentials enable row level security;
alter table public.entity_professions enable row level security;
alter table public.entity_settings enable row level security;
alter table public.entity_devices enable row level security;
alter table public.industries enable row level security;
alter table public.professions enable row level security;

-- ─── 2. Revoke blanket privileges (belt & suspenders — EP-01-05 migration 1
-- set default privileges; explicit revokes here are idempotent) ──────────────
revoke all on table public.entities, public.entity_profiles, public.entity_roles,
  public.entity_credentials, public.entity_professions, public.entity_settings,
  public.entity_devices, public.industries, public.professions
from anon, authenticated;

-- ─── 3. Taxonomy: public read, service-role write ───────────────────────────
grant select on table public.industries, public.professions to anon, authenticated;
grant select, insert, update on table public.industries, public.professions to service_role;

create policy industries_anon_select
  on public.industries for select to anon
  using (true);

create policy industries_authenticated_select
  on public.industries for select to authenticated
  using (true);

create policy professions_anon_select
  on public.professions for select to anon
  using (true);

create policy professions_authenticated_select
  on public.professions for select to authenticated
  using (true);

comment on policy industries_anon_select on public.industries is
  'Public read for pre-auth onboarding pickers and SEO pages.';
comment on policy professions_anon_select on public.professions is
  'Public read for pre-auth onboarding pickers and SEO pages.';

-- ─── 4. Entity tables: owner-scoped access ──────────────────────────────────

-- entities: root identity — self CRUD except DELETE
grant select, insert, update on table public.entities to authenticated;
grant select on table public.entities to service_role;

create policy entities_authenticated_select
  on public.entities for select to authenticated
  using (id = auth.uid());

create policy entities_authenticated_insert
  on public.entities for insert to authenticated
  with check (id = auth.uid());

create policy entities_authenticated_update
  on public.entities for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- entity_profiles: 1:1 profile — legal_name frozen after creation via
-- column-level grant exclusion; update only through validating RPC
grant select, insert on table public.entity_profiles to authenticated;
grant update (entity_id, display_name, bio, avatar_path, country_code)
  on table public.entity_profiles to authenticated;
grant select on table public.entity_profiles to service_role;

create policy entity_profiles_authenticated_select
  on public.entity_profiles for select to authenticated
  using (entity_id = auth.uid());

create policy entity_profiles_authenticated_insert
  on public.entity_profiles for insert to authenticated
  with check (entity_id = auth.uid());

create policy entity_profiles_authenticated_update
  on public.entity_profiles for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

-- entity_roles: fluid multi-role — self CRUD except DELETE
grant select, insert, update on table public.entity_roles to authenticated;
grant select on table public.entity_roles to service_role;

create policy entity_roles_authenticated_select
  on public.entity_roles for select to authenticated
  using (entity_id = auth.uid());

create policy entity_roles_authenticated_insert
  on public.entity_roles for insert to authenticated
  with check (entity_id = auth.uid());

create policy entity_roles_authenticated_update
  on public.entity_roles for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

-- entity_credentials: immutable submissions — SELECT/INSERT only; no UPDATE/DELETE
grant select, insert (entity_id, profession_id, kind, title, document_path, expires_at)
  on table public.entity_credentials to authenticated;
grant select on table public.entity_credentials to service_role;

create policy entity_credentials_authenticated_select
  on public.entity_credentials for select to authenticated
  using (entity_id = auth.uid());

create policy entity_credentials_authenticated_insert
  on public.entity_credentials for insert to authenticated
  with check (entity_id = auth.uid());

-- entity_professions: binding + verification gate — self CRUD on permitted columns
-- trade_verification_status, verified_at, verified_by excluded from client grants (D5)
grant select, insert (entity_id, profession_id, is_primary),
  update (entity_id, profession_id, is_primary)
  on table public.entity_professions to authenticated;
grant select on table public.entity_professions to service_role;

create policy entity_professions_authenticated_select
  on public.entity_professions for select to authenticated
  using (entity_id = auth.uid());

create policy entity_professions_authenticated_insert
  on public.entity_professions for insert to authenticated
  with check (entity_id = auth.uid());

create policy entity_professions_authenticated_update
  on public.entity_professions for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

-- entity_settings: full self CRUD incl. DELETE
grant select, insert, update, delete on table public.entity_settings to authenticated;
grant select on table public.entity_settings to service_role;

create policy entity_settings_authenticated_select
  on public.entity_settings for select to authenticated
  using (entity_id = auth.uid());

create policy entity_settings_authenticated_insert
  on public.entity_settings for insert to authenticated
  with check (entity_id = auth.uid());

create policy entity_settings_authenticated_update
  on public.entity_settings for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

create policy entity_settings_authenticated_delete
  on public.entity_settings for delete to authenticated
  using (entity_id = auth.uid());

-- entity_devices: full self CRUD incl. DELETE (token lifecycle)
grant select, insert, update, delete on table public.entity_devices to authenticated;
grant select on table public.entity_devices to service_role;

create policy entity_devices_authenticated_select
  on public.entity_devices for select to authenticated
  using (entity_id = auth.uid());

create policy entity_devices_authenticated_insert
  on public.entity_devices for insert to authenticated
  with check (entity_id = auth.uid());

create policy entity_devices_authenticated_update
  on public.entity_devices for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

create policy entity_devices_authenticated_delete
  on public.entity_devices for delete to authenticated
  using (entity_id = auth.uid());

-- ─── 5. Realtime exclusion ───────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in (
         'entities', 'entity_profiles', 'entity_roles', 'entity_credentials',
         'entity_professions', 'entity_settings', 'entity_devices',
         'industries', 'professions'
       )
  ) then
    alter publication supabase_realtime
      drop table public.entities, public.entity_profiles, public.entity_roles,
        public.entity_credentials, public.entity_professions, public.entity_settings,
        public.entity_devices, public.industries, public.professions;
  end if;
end;
$$;

-- ─── 6. Documentation comments on policies ──────────────────────────────────
comment on policy entities_authenticated_select on public.entities is
  'Self-scoped read: entities row owns itself (id = auth.uid()).';
comment on policy entity_profiles_authenticated_select on public.entity_profiles is
  'Self-scoped read: profile belongs to its entity.';
comment on policy entity_roles_authenticated_select on public.entity_roles is
  'Self-scoped read: role assignments of the owning entity.';
comment on policy entity_credentials_authenticated_select on public.entity_credentials is
  'Self-scoped read: credentials submitted by the owning entity.';
comment on policy entity_professions_authenticated_select on public.entity_professions is
  'Self-scoped read: profession bindings of the owning entity.';
comment on policy entity_settings_authenticated_select on public.entity_settings is
  'Self-scoped read: keyed preferences of the owning entity.';
comment on policy entity_devices_authenticated_select on public.entity_devices is
  'Self-scoped read: registered devices of the owning entity.';