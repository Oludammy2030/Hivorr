-- EP-01-06: Entity Taxonomy Tables (Two-Tier Industry → Profession)
--
-- Tier-1 `industries` and tier-2 `professions` registry structure validating
-- the AGENT.md Rule 2 taxonomy architecture (EP-01-06 Plan §5.3).
--
-- Conventions inherited from EP-01-05:
--   Audit columns + platform_set_updated_at() trigger on every mutable table.
--   RLS enablement, grants, policies, and Realtime exclusion are applied by
--   the follow-up migration (20260821090003_entity_model_rls_policies.sql).
--   No seed/business data is inserted here — EP-02 owns registry population
--   (EP-01-06 Plan decision D8).
--
-- Slugs are SEO-stable public identifiers supporting /p/:profession_slug/:id.

-- ─── 1. industries ──────────────────────────────────────────────────────────
create table public.industries (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint industries_slug_format check (
    slug = lower(slug)
    and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    and char_length(slug) <= 140
  ),
  constraint industries_name_length check (
    char_length(btrim(name)) between 1 and 255
  )
);

create trigger industries_set_updated_at
  before update on public.industries
  for each row
  execute function public.platform_set_updated_at();

create unique index industries_slug_key
  on public.industries (slug);

create index industries_is_active_sort_idx
  on public.industries (is_active, sort_order);

create index industries_created_at_idx
  on public.industries (created_at desc);

comment on table public.industries is
  'Two-tier taxonomy tier 1: top-level industry registry. Publicly readable; writes are service-role only (EP-01-02+ admin tooling). Populated via approved EP-02 registry flows, never by migrations.';
comment on column public.industries.slug is
  'SEO-stable lowercase identifier used in public URLs. Format-enforced and globally unique.';
comment on column public.industries.is_active is
  'Soft activation switch; inactive industries cannot bind new professions.';

-- ─── 2. professions ─────────────────────────────────────────────────────────
create table public.professions (
  id uuid primary key default gen_random_uuid(),
  industry_id uuid not null references public.industries (id) on delete restrict,
  slug text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint professions_slug_format check (
    slug = lower(slug)
    and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    and char_length(slug) <= 140
  ),
  constraint professions_name_length check (
    char_length(btrim(name)) between 1 and 255
  )
);

create trigger professions_set_updated_at
  before update on public.professions
  for each row
  execute function public.platform_set_updated_at();

create unique index professions_slug_key
  on public.professions (slug);

create index professions_industry_id_idx
  on public.professions (industry_id);

create index professions_is_active_industry_idx
  on public.professions (industry_id, is_active, sort_order);

create index professions_created_at_idx
  on public.professions (created_at desc);

comment on table public.professions is
  'Two-tier taxonomy tier 2: profession registry scoped to an industry (AGENT.md Rule 2 Industry → Profession). Publicly readable; writes are service-role only.';
comment on column public.professions.industry_id is
  'Owning industry. RESTRICT delete prevents taxonomy orphaning.';
comment on column public.professions.slug is
  'SEO-stable lowercase identifier powering /p/:profession_slug/:entity_id URLs. Globally unique.';
