-- EP-01-06: Owner-scoped entity_id defaults
--
-- Corrective migration (append-only; EP-01-06 Plan §5.3 / §3 scope "owner-scoped
-- self-CRUD"). Child tables' entity_id gains DEFAULT auth.uid() so authenticated
-- direct inserts are self-scoping under RLS, mirroring platform_demo_records.owner_id
-- default. RPC paths already pass auth.uid() explicitly; this only widens the
-- ergonomic direct-insert path for EP-01-08 repositories.

alter table public.entity_profiles alter column entity_id set default auth.uid();
alter table public.entity_roles alter column entity_id set default auth.uid();
alter table public.entity_credentials alter column entity_id set default auth.uid();
alter table public.entity_professions alter column entity_id set default auth.uid();
alter table public.entity_settings alter column entity_id set default auth.uid();
alter table public.entity_devices alter column entity_id set default auth.uid();

comment on column public.entity_profiles.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
comment on column public.entity_roles.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
comment on column public.entity_credentials.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
comment on column public.entity_professions.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
comment on column public.entity_settings.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
comment on column public.entity_devices.entity_id is
  'Owning entity; defaults to auth.uid() for self-scoped direct inserts under RLS.';
