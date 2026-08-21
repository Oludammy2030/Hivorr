-- EP-01-06: Universal Entity Core Tables
--
-- The seven private tables of the Universal Entity model (EP-01-06 Plan §5.3):
--   entities            root identity node; 1:1 with auth.users (D1)
--   entity_profiles     singular profile; legal_name = Rule 3 financial anchor (D3)
--   entity_roles        fluid multi-role capability (D2)
--   entity_credentials  immutable trust-evidence submissions
--   entity_professions  taxonomy binding + Rule 2 verification gate (D4)
--   entity_settings     keyed JSONB preferences
--   entity_devices      push-token / device registry
--
-- Conventions inherited from EP-01-05: audit columns + updated_at trigger on
-- every mutable table. RLS enablement and grants are applied by the follow-up
-- migration. No `entity_type` column exists — capability lives exclusively in
-- entity_roles, which makes the model universal and fluid.
-- Vocabularies use text + CHECK constraints, not ENUMs, for forward
-- extensibility (decision D2).

-- ─── 1. entities ────────────────────────────────────────────────────────────
create table public.entities (
  id uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entities_status_allowed check (
    status in ('active', 'suspended', 'deactivated', 'deleted')
  )
);

create trigger entities_set_updated_at
  before update on public.entities
  for each row
  execute function public.platform_set_updated_at();

create index entities_status_idx
  on public.entities (status);

create index entities_created_at_idx
  on public.entities (created_at desc);

comment on table public.entities is
  'Universal Entity root identity node. One row per authenticated identity (id = auth.users.id). Capability is expressed exclusively through entity_roles — no entity_type column.';
comment on column public.entities.status is
  'Soft-delete lifecycle (D9): active | suspended | deactivated | deleted. Hard purge occurs only via the auth.users cascade.';

-- ─── 2. entity_profiles ─────────────────────────────────────────────────────
create table public.entity_profiles (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  legal_name text not null,
  display_name text not null,
  bio text,
  avatar_path text,
  country_code char(2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_profiles_entity_id_key unique (entity_id),
  constraint entity_profiles_legal_name_length check (
    char_length(btrim(legal_name)) between 1 and 255
  ),
  constraint entity_profiles_display_name_length check (
    char_length(btrim(display_name)) between 1 and 255
  ),
  constraint entity_profiles_bio_length check (
    bio is null or char_length(bio) <= 5000
  ),
  constraint entity_profiles_country_code_format check (
    country_code is null or country_code ~ '^[A-Z]{2}$'
  )
);

create trigger entity_profiles_set_updated_at
  before update on public.entity_profiles
  for each row
  execute function public.platform_set_updated_at();

create index entity_profiles_created_at_idx
  on public.entity_profiles (created_at desc);

comment on table public.entity_profiles is
  'Singular profile per entity (1:1 via UNIQUE entity_id). legal_name anchors AGENT.md Rule 3 deposit payer-name matching. Contact PII stays in Supabase Auth (minimal-PII principle).';
comment on column public.entity_profiles.legal_name is
  'Registered/verified name used for AGENT.md Rule 3 deposit verification. Mutations flow only through the validating server-side RPC.';
comment on column public.entity_profiles.avatar_path is
  'Storage object reference; bucket wiring lands in EP-02.';
comment on column public.entity_profiles.country_code is
  'ISO 3166-1 alpha-2 hint captured early to avoid a painful backfill at EP-08 global scale.';

-- ─── 3. entity_roles ────────────────────────────────────────────────────────
create table public.entity_roles (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  role text not null,
  is_active boolean not null default true,
  activated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_roles_entity_role_key unique (entity_id, role),
  constraint entity_roles_role_allowed check (
    role in ('consumer', 'professional', 'merchant', 'rider')
  )
);

create trigger entity_roles_set_updated_at
  before update on public.entity_roles
  for each row
  execute function public.platform_set_updated_at();

create index entity_roles_entity_active_idx
  on public.entity_roles (entity_id) where is_active;

comment on table public.entity_roles is
  'Fluid multi-role capability registry (VISION.md Universal Entity Principle): one entity may hold several simultaneously active roles. Deactivation sets is_active = false; clients never DELETE roles.';
comment on column public.entity_roles.role is
  'Vocabulary fixed by CHECK for forward-safe extensibility (decision D2): consumer | professional | merchant | rider.';

-- ─── 4. entity_credentials ──────────────────────────────────────────────────
create table public.entity_credentials (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  profession_id uuid references public.professions (id) on delete restrict,
  kind text not null,
  title text not null,
  document_path text,
  verification_status text not null default 'pending',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  rejection_reason text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_credentials_kind_allowed check (
    kind in ('identity_document', 'trade_proof', 'certification')
  ),
  constraint entity_credentials_title_length check (
    char_length(btrim(title)) between 1 and 255
  ),
  constraint entity_credentials_verification_status_allowed check (
    verification_status in ('pending', 'approved', 'rejected')
  ),
  constraint entity_credentials_review_consistency check (
    (verification_status = 'pending' and reviewed_at is null and reviewed_by is null)
    or (verification_status in ('approved', 'rejected') and reviewed_at is not null)
  )
);

comment on constraint entity_credentials_review_consistency on public.entity_credentials is
  'Pending rows must be unreviewed; decided rows must carry reviewed_at. Enforces review-state integrity regardless of writer.';

create trigger entity_credentials_set_updated_at
  before update on public.entity_credentials
  for each row
  execute function public.platform_set_updated_at();

create index entity_credentials_entity_status_idx
  on public.entity_credentials (entity_id, verification_status);

create index entity_credentials_profession_id_idx
  on public.entity_credentials (profession_id);

comment on table public.entity_credentials is
  'Trust-evidence submissions feeding the EP-02 admin review gate. Submissions are owner-immutable (no client UPDATE); corrections are resubmissions. Verification transitions are reserved to future server-side workflows — zero client grant exists on review columns.';
comment on column public.entity_credentials.document_path is
  'Storage object reference; bucket wiring and upload flows land in EP-02.';
-- ─── 5. entity_professions ──────────────────────────────────────────────────
create table public.entity_professions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  profession_id uuid not null references public.professions (id) on delete restrict,
  is_primary boolean not null default false,
  trade_verification_status text not null default 'unverified',
  verified_at timestamptz,
  verified_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_professions_entity_profession_key unique (entity_id, profession_id),
  constraint entity_professions_trade_status_allowed check (
    trade_verification_status in ('unverified', 'pending', 'approved')
  )
);

create trigger entity_professions_set_updated_at
  before update on public.entity_professions
  for each row
  execute function public.platform_set_updated_at();

create index entity_professions_entity_trade_idx
  on public.entity_professions (entity_id) where trade_verification_status = 'approved';

create index entity_professions_profession_id_idx
  on public.entity_professions (profession_id);

comment on table public.entity_professions is
  'M:N binding of entities to professions carrying the per-profession trade verification gate (AGENT.md Rule 2: bidding locked until trade_verification_status = approved). Verification columns have zero client grants (decision D5); transitions belong to EP-02 server-side workflows.';

-- ─── 6. entity_settings ─────────────────────────────────────────────────────
create table public.entity_settings (
  entity_id uuid not null references public.entities (id) on delete cascade,
  setting_key text not null,
  value jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_settings_pkey primary key (entity_id, setting_key),
  constraint entity_settings_setting_key_length check (
    char_length(setting_key) between 1 and 255
  ),
  constraint entity_settings_value_is_object check (jsonb_typeof(value) = 'object')
);

create trigger entity_settings_set_updated_at
  before update on public.entity_settings
  for each row
  execute function public.platform_set_updated_at();

comment on table public.entity_settings is
  'Keyed JSONB preference store per entity. Composite PK avoids surrogate overhead. Full self CRUD including DELETE (ephemeral data, D9).';

-- ─── 7. entity_devices ──────────────────────────────────────────────────────
create table public.entity_devices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  device_token text not null,
  platform text not null,
  device_name text,
  app_version text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint entity_devices_device_token_key unique (device_token),
  constraint entity_devices_platform_allowed check (
    platform in ('android', 'ios', 'web', 'macos', 'windows', 'linux')
  )
);

create trigger entity_devices_set_updated_at
  before update on public.entity_devices
  for each row
  execute function public.platform_set_updated_at();

create index entity_devices_entity_idx
  on public.entity_devices (entity_id);

create index entity_devices_last_seen_idx
  on public.entity_devices (last_seen_at desc);

comment on table public.entity_devices is
  'Push-token / device registry supporting the EP-01-18 notification engine. Tokens are globally unique; rows are self-managed including DELETE (token lifecycle, D9).';
