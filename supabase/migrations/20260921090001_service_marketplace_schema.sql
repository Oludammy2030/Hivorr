-- EP-03-01: Professional Service Marketplace Schema & Server-Side Enforcement
--
-- Atomic marketplace foundation: 3 tables (service_listings,
-- service_listing_media, service_favorites), the service-listing-media Storage
-- bucket, and 7 SECURITY INVOKER RPCs with the trade-verification gate.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER everywhere (RLS applies inside every RPC body); no new
--     SECURITY DEFINER function (008/013/015 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT002/
--     PLT003/PLT004/PLT005 per the 20260829100004 vocabulary.
--   - Trade gate: entity_professions.trade_verification_status = 'approved'
--     is re-checked server-side on every publish transition (AGENT.md Rule 2).
--
-- APPROVED DEVIATION (D5 guard instead of grant absence)
--   SECURITY INVOKER RPCs called by `authenticated` must write status,
--   published_at and is_trade_verified_cache, so those three columns carry an
--   UPDATE (and, for the create path, INSERT) column grant to authenticated.
--   Direct client writes are blocked by the service_listings_guard_publish_state
--   D5 trigger (platform.rpc_invocation GUC), mirroring the entity_professions /
--   verification_submissions / entity_kyc_levels / entities precedent
--   (20260916090001 + 20260915090001). Direct PostgREST PATCH/INSERT of publish
--   state raises PLT002 instead of 42501. search_vector, avg_rating,
--   review_count and view_count remain with zero client grants.
--
--   view_count is NOT incremented by service_listing_get (approved deferral):
--   the read stays STABLE/PostgREST-cacheable; analytics land in EP-03-06/09.
--
-- FTS STRATEGY
--   search_vector is recomputed by trigger from title || description ||
--   profession name and is never client-supplied; GIN(search_vector) feeds the
--   EP-03-06 ranking and EP-03-07 search targets.
--
-- MIGRATION POSTURE
--   - No DDL on any prior table/function/policy (Rule 3 write discipline); only
--     new objects plus additive storage.objects policies for the new bucket.
--   - Idempotent: if-not-exists / drop-if-exists / create-or-replace throughout.

-- =============================================================================
-- SECTION 1: service_listings
-- =============================================================================
create table if not exists public.service_listings (
  id                     uuid primary key default gen_random_uuid(),
  entity_id              uuid not null references public.entities (id) on delete cascade,
  profession_id          uuid not null references public.professions (id) on delete restrict,
  industry_id            uuid not null references public.industries (id) on delete restrict,
  slug                   text not null,
  title                  text not null,
  description            text not null,
  status                 text not null default 'draft',
  pricing_type           text not null,
  price_min              numeric,
  price_max              numeric,
  currency_code          char(3) not null default 'NGN'
                         references public.financial_supported_currencies (currency_code),
  search_vector          tsvector,
  avg_rating             numeric not null default 0,
  review_count           integer not null default 0,
  is_trade_verified_cache boolean not null default false,
  view_count             integer not null default 0,
  published_at           timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  created_by             uuid default auth.uid(),
  constraint service_listings_slug_format check (
    slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 1 and 140
  ),
  constraint service_listings_title_length check (
    char_length(btrim(title)) between 10 and 120
  ),
  constraint service_listings_description_length check (
    char_length(btrim(description)) between 50 and 5000
  ),
  constraint service_listings_status_allowed check (
    status in ('draft', 'published', 'paused', 'archived', 'reported')
  ),
  constraint service_listings_pricing_type_allowed check (
    pricing_type in ('fixed', 'hourly', 'custom', 'per_milestone')
  ),
  constraint service_listings_price_min_nonneg check (price_min is null or price_min >= 0),
  constraint service_listings_price_max_nonneg check (price_max is null or price_max >= 0),
  constraint service_listings_price_range check (
    price_max is null or price_min is null or price_max >= price_min
  ),
  constraint service_listings_price_required check (price_min is not null or pricing_type = 'custom'),
  constraint service_listings_currency_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint service_listings_avg_rating_range check (avg_rating between 0 and 5),
  constraint service_listings_review_count_nonneg check (review_count >= 0),
  constraint service_listings_view_count_nonneg check (view_count >= 0),
  constraint service_listings_published_at_semantics check (
    (status = 'published' and published_at is not null)
    or (status <> 'published' and published_at is null)
  ),
  constraint service_listings_entity_slug_key unique (entity_id, slug)
);

comment on table public.service_listings is
  'Marketplace supply primitive: a service listing bound to professions (taxonomy) and owned by an entity. Publish transitions are RPC-only (trade gate + D5 guard trigger); search_vector is trigger-generated; avg_rating/review_count are EP-03-03 caches; view_count is reserved for EP-03-06/09 analytics.';
comment on column public.service_listings.status is
  'Lifecycle: draft/published/paused/archived/reported. Mutable only through service_listing_publish/unpublish (guarded columns for authenticated).';
comment on column public.service_listings.is_trade_verified_cache is
  'Denormalized trade-gate snapshot set at publish time by service_listing_publish (never client-writable).';
comment on column public.service_listings.search_vector is
  'Trigger-generated FTS vector (title || description || profession name). Zero client grants; recomputed on every relevant change.';
comment on column public.service_listings.published_at is
  'NOT NULL iff status=published (CHECK-enforced). Guarded column for authenticated (D5).';
comment on column public.service_listings.view_count is
  'Reserved for EP-03-06/09 analytics. Not incremented by service_listing_get (approved deferral). Zero client grants.';

create index if not exists service_listings_entity_idx
  on public.service_listings (entity_id, status);
create index if not exists service_listings_profession_idx
  on public.service_listings (profession_id, status);
create index if not exists service_listings_industry_idx
  on public.service_listings (industry_id, status);
create index if not exists service_listings_status_published_idx
  on public.service_listings (status) where status = 'published';
create index if not exists service_listings_currency_idx
  on public.service_listings (currency_code);
create index if not exists service_listings_published_at_idx
  on public.service_listings (published_at desc) where status = 'published';
create index if not exists service_listings_search_vector_gin
  on public.service_listings using gin (search_vector);

-- ─── 1b. search_vector + industry parity trigger ────────────────────────────
-- Recomputes the FTS vector and re-derives industry_id from the bound
-- profession (denormalized parity is enforced here, never trusted from input:
-- a client-supplied industry_id is overwritten on INSERT and on any
-- title/description/profession_id change).
create or replace function public.service_listings_search_vector_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_industry_id uuid;
  v_prof_name text;
begin
  select p.industry_id, p.name
    into v_industry_id, v_prof_name
    from public.professions p
   where p.id = new.profession_id;

  new.industry_id := v_industry_id;
  new.search_vector := to_tsvector('english',
    coalesce(new.title, '') || ' ' || coalesce(new.description, '') || ' ' || coalesce(v_prof_name, ''));

  return new;
end;
$$;

comment on function public.service_listings_search_vector_update() is
  'BEFORE INSERT/UPDATE trigger: recomputes search_vector (title+description+profession name) and re-derives industry_id from professions, guaranteeing taxonomy parity and preventing search_vector injection.';

drop trigger if exists service_listings_search_vector_tg on public.service_listings;

create trigger service_listings_search_vector_tg
  before insert or update of title, description, profession_id
  on public.service_listings
  for each row
  execute function public.service_listings_search_vector_update();

comment on trigger service_listings_search_vector_tg on public.service_listings is
  'Keeps search_vector and industry_id consistent with title/description/profession binding.';

-- ─── 1c. D5 guard: publish state is RPC-only (approved deviation) ────────────
create or replace function public.service_listings_guard_publish_state()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_violation boolean;
begin
  if tg_op = 'INSERT' then
    -- Direct client INSERTs may only create drafts with default gate state.
    v_violation := (new.status <> 'draft')
                or new.is_trade_verified_cache
                or (new.published_at is not null);
  else
    v_violation := (new.status is distinct from old.status)
               or (new.published_at is distinct from old.published_at)
               or (new.is_trade_verified_cache is distinct from old.is_trade_verified_cache);
  end if;

  if v_violation
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on'
     and current_user = 'authenticated' then
    perform public.platform_raise_error(
      'PLT002',
      'Listing publish state may only be changed through the service listing RPCs.'
    );
  end if;

  return new;
end;
$$;

comment on function public.service_listings_guard_publish_state() is
  'D5 guard: blocks direct authenticated (client) mutation of status, published_at and is_trade_verified_cache. Trusted roles (postgres/service_role) and the listing RPCs that set platform.rpc_invocation may write.';

drop trigger if exists service_listings_guard_publish_state on public.service_listings;

create trigger service_listings_guard_publish_state
  before insert or update on public.service_listings
  for each row
  execute function public.service_listings_guard_publish_state();

comment on trigger service_listings_guard_publish_state on public.service_listings is
  'D5 guard trigger: publish-state columns mutate only through service_listing_create/publish/unpublish (which set platform.rpc_invocation); direct PostgREST writes raise PLT002.';

-- ─── 1d. updated_at trigger ─────────────────────────────────────────────────
drop trigger if exists service_listings_set_updated_at on public.service_listings;

create trigger service_listings_set_updated_at
  before update on public.service_listings
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: service_listing_media
-- =============================================================================
create table if not exists public.service_listing_media (
  id            uuid primary key default gen_random_uuid(),
  listing_id    uuid not null references public.service_listings (id) on delete cascade,
  entity_id     uuid not null references public.entities (id) on delete cascade,
  storage_path  text not null,
  mime_type     text,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid default auth.uid(),
  constraint service_listing_media_storage_path_owner_prefix check (
    storage_path like 'service-listing-media/' || entity_id::text || '/%'
  ),
  constraint service_listing_media_mime_allowed check (
    mime_type is null
    or mime_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')
  ),
  constraint service_listing_media_sort_order_nonneg check (sort_order >= 0)
);

comment on table public.service_listing_media is
  'Media rows for a listing, bound to the service-listing-media bucket. storage_path must be prefixed with the owning entity id (CHECK parity with the storage.objects foldername policies).';
comment on column public.service_listing_media.storage_path is
  'Storage object path; CHECK enforces the service-listing-media/{entity_id}/ owner prefix.';

create index if not exists service_listing_media_listing_idx
  on public.service_listing_media (listing_id, sort_order);
create index if not exists service_listing_media_entity_idx
  on public.service_listing_media (entity_id);

drop trigger if exists service_listing_media_set_updated_at on public.service_listing_media;

create trigger service_listing_media_set_updated_at
  before update on public.service_listing_media
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 3: service_favorites
-- =============================================================================
create table if not exists public.service_favorites (
  id          uuid primary key default gen_random_uuid(),
  entity_id   uuid not null references public.entities (id) on delete cascade,
  listing_id  uuid not null references public.service_listings (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint service_favorites_entity_listing_key unique (entity_id, listing_id)
);

comment on table public.service_favorites is
  'Consumer-side favorite shortlist (immutable toggle: insert/delete only, no updated_at). Self-favorite and non-published targets are rejected by service_favorite_toggle (PLT005).';

create index if not exists service_favorites_entity_idx
  on public.service_favorites (entity_id, created_at desc);
create index if not exists service_favorites_listing_idx
  on public.service_favorites (listing_id);

-- =============================================================================
-- SECTION 4: Storage bucket + storage.objects policies
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'service-listing-media', 'service-listing-media', true, 10485760 /* 10 MiB */,
  '{image/jpeg,image/png,image/webp,application/pdf}'
)
on conflict (id) do update
   set public = excluded.public,
       file_size_limit = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types,
       updated_at = now();

drop policy if exists service_listing_media_select_public on storage.objects;
drop policy if exists service_listing_media_insert_owner   on storage.objects;
drop policy if exists service_listing_media_update_owner   on storage.objects;
drop policy if exists service_listing_media_delete_owner   on storage.objects;

-- Public read: published listing media is served via public bucket URLs; draft
-- media paths are unguessable and never enumerated by service_listing_get.
create policy service_listing_media_select_public
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'service-listing-media');

create policy service_listing_media_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'service-listing-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy service_listing_media_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'service-listing-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'service-listing-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy service_listing_media_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'service-listing-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =============================================================================
-- SECTION 5: RLS enable + REVOKE + column-level grants
-- =============================================================================
alter table public.service_listings enable row level security;
alter table public.service_listing_media enable row level security;
alter table public.service_favorites enable row level security;

revoke all on
  public.service_listings,
  public.service_listing_media,
  public.service_favorites
from anon, authenticated, service_role;

-- service_listings -------------------------------------------------------------
-- anon: public read of published rows (RLS-scoped) for the SECURITY INVOKER
-- service_listing_get path. No write grant of any kind.
grant select on public.service_listings to anon, authenticated;
-- authenticated INSERT: the create-RPC column list. status / published_at /
-- is_trade_verified_cache are included (approved deviation) and protected by
-- the D5 guard trigger. industry_id is trigger-derived; search_vector,
-- avg_rating, review_count, view_count have zero grants.
grant insert (
  entity_id, profession_id, slug, title, description, pricing_type,
  price_min, price_max, currency_code, status, published_at,
  is_trade_verified_cache
) on public.service_listings to authenticated;
-- authenticated UPDATE: mutable fields (owner-scoped by RLS) plus the guarded
-- publish-state columns (D5 guard trigger blocks direct writes with PLT002).
grant update (
  title, description, pricing_type, price_min, price_max, currency_code,
  profession_id, status, published_at, is_trade_verified_cache
) on public.service_listings to authenticated;
grant select, insert, update, delete on public.service_listings to service_role;

-- service_listing_media --------------------------------------------------------
grant select on public.service_listing_media to anon, authenticated;
grant insert (entity_id, listing_id, storage_path, mime_type, sort_order)
  on public.service_listing_media to authenticated;
grant update (sort_order) on public.service_listing_media to authenticated;
grant delete on public.service_listing_media to authenticated;
grant select, insert, update, delete on public.service_listing_media to service_role;

-- service_favorites ------------------------------------------------------------
grant select, insert (entity_id, listing_id), delete
  on public.service_favorites to authenticated;
grant select, insert, delete on public.service_favorites to service_role;

-- =============================================================================
-- SECTION 6: RLS policies (self-scoped + public published)
-- =============================================================================
create policy service_listings_select_public
  on public.service_listings for select to anon, authenticated
  using (status = 'published');

create policy service_listings_select_own
  on public.service_listings for select to authenticated
  using (entity_id = auth.uid());

create policy service_listings_insert_own
  on public.service_listings for insert to authenticated
  with check (entity_id = auth.uid());

create policy service_listings_update_own
  on public.service_listings for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

comment on policy service_listings_update_own on public.service_listings is
  'Owner-scoped direct updates of mutable fields remain possible; publish-state columns are additionally blocked by the service_listings_guard_publish_state D5 trigger (PLT002) unless set by the listing RPCs.';

-- Media: public read for published listings, owner-managed rows otherwise.
-- The insert WITH CHECK also requires the target listing to be owned by the
-- caller so media rows cannot be attached to someone else's listing.
create policy service_listing_media_select
  on public.service_listing_media for select to anon, authenticated
  using (
    exists (
      select 1 from public.service_listings sl
       where sl.id = listing_id
         and sl.status = 'published'
    )
    or entity_id = auth.uid()
  );

create policy service_listing_media_insert_own
  on public.service_listing_media for insert to authenticated
  with check (
    entity_id = auth.uid()
    and exists (
      select 1 from public.service_listings sl
       where sl.id = listing_id
         and sl.entity_id = auth.uid()
    )
  );

create policy service_listing_media_update_own
  on public.service_listing_media for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

create policy service_listing_media_delete_own
  on public.service_listing_media for delete to authenticated
  using (entity_id = auth.uid());

-- Favorites: private per fan; RPC enforces published-target + no-self-favorite.
create policy service_favorites_select_own
  on public.service_favorites for select to authenticated
  using (entity_id = auth.uid());

create policy service_favorites_insert_own
  on public.service_favorites for insert to authenticated
  with check (entity_id = auth.uid());

create policy service_favorites_delete_own
  on public.service_favorites for delete to authenticated
  using (entity_id = auth.uid());

-- =============================================================================
-- SECTION 7: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 7a. service_listing_create ──────────────────────────────────────────────
create or replace function public.service_listing_create(
  p_profession_id uuid,
  p_title text,
  p_description text,
  p_pricing_type text,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_currency_code char(3) default 'NGN',
  p_status text default 'draft'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_title text;
  v_description text;
  v_slug text;
  v_status text;
  v_is_verified boolean;
  v_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;

  if nullif(btrim(p_title), '') is null
     or char_length(btrim(p_title)) not between 10 and 120 then
    perform public.platform_raise_error('PLT003', 'Title must be between 10 and 120 characters.');
  end if;

  if nullif(btrim(p_description), '') is null
     or char_length(btrim(p_description)) not between 50 and 5000 then
    perform public.platform_raise_error('PLT003', 'Description must be between 50 and 5000 characters.');
  end if;

  if p_pricing_type not in ('fixed', 'hourly', 'custom', 'per_milestone') then
    perform public.platform_raise_error('PLT003', 'Invalid pricing type.');
  end if;

  if p_price_min is not null and p_price_min < 0 then
    perform public.platform_raise_error('PLT003', 'Minimum price must be zero or greater.');
  end if;

  if p_price_max is not null and p_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required when a maximum price is provided.');
  end if;

  if p_price_max is not null and p_price_max < p_price_min then
    perform public.platform_raise_error('PLT003', 'Maximum price must be greater than or equal to the minimum price.');
  end if;

  if p_pricing_type <> 'custom' and p_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required for this pricing type.');
  end if;

  if p_status not in ('draft', 'published') then
    perform public.platform_raise_error('PLT003', 'Invalid initial status.');
  end if;

  if not exists (
    select 1 from public.financial_supported_currencies c
     where c.currency_code = p_currency_code
       and c.is_active
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;

  if not exists (
    select 1 from public.professions p
     where p.id = p_profession_id
       and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if not exists (
    select 1 from public.entity_professions ep
     where ep.entity_id = v_actor
       and ep.profession_id = p_profession_id
  ) then
    perform public.platform_raise_error('PLT005', 'Bind this profession to your profile before creating a listing.');
  end if;

  v_title := btrim(p_title);
  v_description := btrim(p_description);
  v_slug := btrim(regexp_replace(regexp_replace(lower(v_title), '[^a-z0-9]+', '-', 'g'), '-+', '-', 'g'), '-');
  v_slug := btrim(left(v_slug, 140), '-');
  if nullif(v_slug, '') is null then
    perform public.platform_raise_error('PLT003', 'Title must contain letters or numbers.');
  end if;

  if p_status = 'published' then
    if not exists (
      select 1 from public.entity_professions ep
       where ep.entity_id = v_actor
         and ep.profession_id = p_profession_id
         and ep.trade_verification_status = 'approved'
    ) then
      perform public.platform_raise_error('PLT005', 'Trade verification required. Complete verification before publishing.');
    end if;
    v_is_verified := true;
  else
    v_is_verified := exists (
      select 1 from public.entity_professions ep
       where ep.entity_id = v_actor
         and ep.profession_id = p_profession_id
         and ep.trade_verification_status = 'approved'
    );
  end if;
  v_status := p_status;

  perform set_config('platform.rpc_invocation', 'on', true);

  begin
    insert into public.service_listings (
      entity_id, profession_id, slug, title, description, status,
      pricing_type, price_min, price_max, currency_code,
      is_trade_verified_cache, published_at
    ) values (
      v_actor, p_profession_id, v_slug, v_title, v_description, v_status,
      p_pricing_type, p_price_min, p_price_max, p_currency_code,
      v_is_verified, case when v_status = 'published' then now() else null end
    )
    returning id into v_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'A listing with this title already exists.');
  end;

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = v_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_create', 'service_listings',
      jsonb_build_object('listing_id', v_id, 'status', v_status)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing created.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_create(uuid, text, text, text, numeric, numeric, char(3), text) is
  'Security invoker. Creates a draft (default) or, if the trade gate passes for the bound profession, a published listing. Validates profession (active), currency (active), pricing and title; slug is derived from the title. Publish-state columns are written under platform.rpc_invocation (D5 guard). Audit-logged.';

-- ─── 7b. service_listing_update ──────────────────────────────────────────────
create or replace function public.service_listing_update(
  p_listing_id uuid,
  p_title text default null,
  p_description text default null,
  p_profession_id uuid default null,
  p_pricing_type text default null,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_currency_code char(3) default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.service_listings%rowtype;
  v_title text;
  v_description text;
  v_profession_id uuid;
  v_pricing_type text;
  v_price_min numeric;
  v_price_max numeric;
  v_currency_code char(3);
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  if p_title is null and p_description is null and p_profession_id is null
     and p_pricing_type is null and p_price_min is null and p_price_max is null
     and p_currency_code is null then
    perform public.platform_raise_error('PLT003', 'At least one field is required to update.');
  end if;

  select * into v_row
    from public.service_listings l
   where l.id = p_listing_id
     and l.entity_id = v_actor
   for update;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_row.status in ('archived', 'reported') then
    perform public.platform_raise_error('PLT005', 'Archived or reported listings cannot be updated.');
  end if;

  if v_row.status = 'published'
     and (p_title is not null or p_profession_id is not null or p_pricing_type is not null
          or p_price_min is not null or p_price_max is not null or p_currency_code is not null) then
    perform public.platform_raise_error('PLT005', 'Unpublish the listing before changing pricing or taxonomy.');
  end if;

  v_title := v_row.title;
  v_description := v_row.description;
  v_profession_id := v_row.profession_id;
  v_pricing_type := v_row.pricing_type;
  v_price_min := v_row.price_min;
  v_price_max := v_row.price_max;
  v_currency_code := v_row.currency_code;

  if p_title is not null then
    if char_length(btrim(p_title)) not between 10 and 120 then
      perform public.platform_raise_error('PLT003', 'Title must be between 10 and 120 characters.');
    end if;
    v_title := btrim(p_title);
  end if;

  if p_description is not null then
    if char_length(btrim(p_description)) not between 50 and 5000 then
      perform public.platform_raise_error('PLT003', 'Description must be between 50 and 5000 characters.');
    end if;
    v_description := btrim(p_description);
  end if;

  if p_pricing_type is not null then
    if p_pricing_type not in ('fixed', 'hourly', 'custom', 'per_milestone') then
      perform public.platform_raise_error('PLT003', 'Invalid pricing type.');
    end if;
    v_pricing_type := p_pricing_type;
  end if;

  if p_price_min is not null and p_price_min < 0 then
    perform public.platform_raise_error('PLT003', 'Minimum price must be zero or greater.');
  end if;
  if p_price_min is not null then
    v_price_min := p_price_min;
  end if;

  if p_price_max is not null and p_price_max < 0 then
    perform public.platform_raise_error('PLT003', 'Maximum price must be zero or greater.');
  end if;
  if p_price_max is not null then
    v_price_max := p_price_max;
  end if;

  if v_pricing_type <> 'custom' and v_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required for this pricing type.');
  end if;

  if v_price_max is not null and v_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required when a maximum price is provided.');
  end if;

  if v_price_max is not null and v_price_max < v_price_min then
    perform public.platform_raise_error('PLT003', 'Maximum price must be greater than or equal to the minimum price.');
  end if;

  if p_currency_code is not null then
    if not exists (
      select 1 from public.financial_supported_currencies c
       where c.currency_code = p_currency_code
         and c.is_active
    ) then
      perform public.platform_raise_error('PLT003', 'Currency is not supported.');
    end if;
    v_currency_code := p_currency_code;
  end if;

  if p_profession_id is not null and p_profession_id is distinct from v_row.profession_id then
    if not exists (
      select 1 from public.professions p
       where p.id = p_profession_id
         and p.is_active
    ) then
      perform public.platform_raise_error('PLT004', 'Profession not found.');
    end if;

    if not exists (
      select 1 from public.entity_professions ep
       where ep.entity_id = v_actor
         and ep.profession_id = p_profession_id
    ) then
      perform public.platform_raise_error('PLT005', 'Bind this profession to your profile before creating a listing.');
    end if;

    v_profession_id := p_profession_id;
  end if;

  update public.service_listings
     set title = v_title,
         description = v_description,
         profession_id = v_profession_id,
         pricing_type = v_pricing_type,
         price_min = v_price_min,
         price_max = v_price_max,
         currency_code = v_currency_code
   where id = p_listing_id
     and entity_id = v_actor;

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = p_listing_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_update', 'service_listings',
      jsonb_build_object('listing_id', p_listing_id)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing updated.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_update(uuid, text, text, uuid, text, numeric, numeric, char(3)) is
  'Security invoker, owner-only. State-aware whitelist: published listings accept description changes only (PLT005 otherwise); archived/reported are immutable. Profession changes re-validate the binding and re-derive industry_id + search_vector via trigger. Audit-logged.';

-- ─── 7c. service_listing_publish ─────────────────────────────────────────────
create or replace function public.service_listing_publish(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_profession_id uuid;
  v_status text;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  select l.status, l.profession_id
    into v_status, v_profession_id
    from public.service_listings l
   where l.id = p_listing_id
     and l.entity_id = v_actor
   for update;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_status not in ('draft', 'paused') then
    perform public.platform_raise_error('PLT005', 'Listing is not in a publishable state.');
  end if;

  if not exists (
    select 1 from public.professions p
     where p.id = v_profession_id
       and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  perform 1
    from public.entity_professions ep
   where ep.entity_id = v_actor
     and ep.profession_id = v_profession_id
     and ep.trade_verification_status = 'approved'
   for update;

  if not found then
    perform public.platform_raise_error('PLT005', 'Trade verification required. Complete verification before publishing.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.service_listings
     set status = 'published',
         published_at = now(),
         is_trade_verified_cache = true
   where id = p_listing_id
     and entity_id = v_actor;

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = p_listing_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_publish', 'service_listings',
      jsonb_build_object('listing_id', p_listing_id)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing published.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_publish(uuid) is
  'Security invoker, owner-only. draft/paused -> published after re-checking the trade gate (entity_professions approved, profession active) under row locks. Sets published_at and is_trade_verified_cache under platform.rpc_invocation (D5 guard). Audit-logged.';

-- ─── 7d. service_listing_unpublish ───────────────────────────────────────────
create or replace function public.service_listing_unpublish(
  p_listing_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_status text;
  v_target text;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  if p_reason is not null and p_reason not in ('paused', 'reported') then
    perform public.platform_raise_error('PLT003', 'Invalid unpublish reason.');
  end if;

  -- Owner scope for authenticated callers; service_role may unpublish (moderate)
  -- any listing, which is the only path to status='reported'.
  select l.status
    into v_status
    from public.service_listings l
   where l.id = p_listing_id
     and (l.entity_id = v_actor or current_user = 'service_role')
   for update;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_status <> 'published' then
    perform public.platform_raise_error('PLT005', 'Only published listings can be unpublished.');
  end if;

  v_target := case when p_reason = 'reported' then 'reported' else 'paused' end;

  if v_target = 'reported' and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT002', 'Only the service role can report listings.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.service_listings
     set status = v_target,
         published_at = null
   where id = p_listing_id
     and (entity_id = v_actor or current_user = 'service_role');

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = p_listing_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_unpublish', 'service_listings',
      jsonb_build_object('listing_id', p_listing_id, 'reason', p_reason)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing unpublished.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_unpublish(uuid, text) is
  'Security invoker. published -> paused (owner) or -> reported (service_role only, PLT002 otherwise); clears published_at. service_role may act on any listing (moderation); authenticated callers are owner-scoped. Guarded columns written under platform.rpc_invocation. Audit-logged.';

-- ─── 7e. service_listing_get ─────────────────────────────────────────────────
-- Public read (published) for anon/authenticated + owner read of private
-- states; RLS performs the visibility split, so draft rows are simply "not
-- found" (identical PLT004 — no enumeration oracle).
-- NOTE: errors are raised inline with the platform_raise_error contract
-- (errcode P0001, message '<CODE>: <text>', detail '<CODE>') because anon holds
-- no EXECUTE grant on platform_raise_error and the 004 posture audit pins
-- anon-executable platform_% functions to platform_health only.
create or replace function public.service_listing_get(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_listing record;
  v_media jsonb;
begin
  if p_listing_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PLT003: Listing id is required.',
      detail  = 'PLT003';
  end if;

  select l.id, l.entity_id, l.profession_id, l.industry_id, l.slug, l.title,
         l.description, l.status, l.pricing_type, l.price_min, l.price_max,
         l.currency_code, l.avg_rating, l.review_count, l.is_trade_verified_cache,
         l.view_count, l.published_at, l.created_at, l.updated_at,
         p.slug as profession_slug, p.name as profession_name,
         i.slug as industry_slug, i.name as industry_name
    into v_listing
    from public.service_listings l
    join public.professions p on p.id = l.profession_id
    join public.industries i on i.id = l.industry_id
   where l.id = p_listing_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'PLT004: Listing not found.',
      detail  = 'PLT004';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id,
           'storage_path', m.storage_path,
           'mime_type', m.mime_type,
           'sort_order', m.sort_order,
           'created_at', m.created_at
         ) order by m.sort_order, m.created_at), '[]'::jsonb)
    into v_media
    from public.service_listing_media m
   where m.listing_id = p_listing_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing retrieved.',
    'data', jsonb_build_object(
      'id', v_listing.id,
      'entity_id', v_listing.entity_id,
      'profession_id', v_listing.profession_id,
      'industry_id', v_listing.industry_id,
      'slug', v_listing.slug,
      'title', v_listing.title,
      'description', v_listing.description,
      'status', v_listing.status,
      'pricing_type', v_listing.pricing_type,
      'price_min', v_listing.price_min,
      'price_max', v_listing.price_max,
      'currency_code', v_listing.currency_code,
      'avg_rating', v_listing.avg_rating,
      'review_count', v_listing.review_count,
      'is_trade_verified_cache', v_listing.is_trade_verified_cache,
      'view_count', v_listing.view_count,
      'published_at', v_listing.published_at,
      'created_at', v_listing.created_at,
      'updated_at', v_listing.updated_at,
      'profession_slug', v_listing.profession_slug,
      'profession_name', v_listing.profession_name,
      'industry_slug', v_listing.industry_slug,
      'industry_name', v_listing.industry_name,
      'media', v_media
    )
  );
end;
$$;

comment on function public.service_listing_get(uuid) is
  'Security invoker, STABLE. Public read of published listings (anon capable) and owner read of private states via RLS. Identical PLT004 for unknown or non-visible listings (no enumeration oracle). Whitelisted projection: search_vector is never returned. view_count is not incremented (analytics deferred to EP-03-06/09).';

-- ─── 7f. service_listing_list_mine ───────────────────────────────────────────
create or replace function public.service_listing_list_mine(
  p_status text default null,
  p_limit int default 20,
  p_cursor uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_cursor_ts timestamptz;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_status is not null
     and p_status not in ('draft', 'published', 'paused', 'archived', 'reported') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select s.created_at
      into v_cursor_ts
      from public.service_listings s
     where s.id = p_cursor
       and s.entity_id = v_actor;

    if not found then
      -- Unknown or foreign cursor: treat as exhausted (no oracle).
      return jsonb_build_object(
        'success', true,
        'code', 'PLT000',
        'message', 'Listings retrieved.',
        'data', jsonb_build_object(
          'items', '[]'::jsonb,
          'has_more', false,
          'next_cursor', null
        )
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc)
                    filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select l.id, l.slug, l.title, l.description, l.status, l.pricing_type,
             l.price_min, l.price_max, l.currency_code,
             l.is_trade_verified_cache, l.avg_rating, l.review_count,
             l.view_count, l.published_at, l.created_at, l.updated_at,
             row_number() over (order by l.created_at desc, l.id desc) as rn
        from public.service_listings l
       where l.entity_id = v_actor
         and (p_status is null or l.status = p_status)
         and (p_cursor is null
              or (l.created_at, l.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then
    v_next := null;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listings retrieved.',
    'data', jsonb_build_object(
      'items', v_items,
      'has_more', v_has_more,
      'next_cursor', v_next
    )
  );
end;
$$;

comment on function public.service_listing_list_mine(text, integer, uuid) is
  'Security invoker, STABLE. Owner-scoped keyset pagination (created_at desc, id desc) with optional status filter; returns {items, has_more, next_cursor}. search_vector never returned.';

-- ─── 7g. service_favorite_toggle ─────────────────────────────────────────────
create or replace function public.service_favorite_toggle(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_owner uuid;
  v_status text;
  v_favorited boolean;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  select l.entity_id, l.status
    into v_owner, v_status
    from public.service_listings l
   where l.id = p_listing_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_status <> 'published' then
    perform public.platform_raise_error('PLT005', 'Only published listings can be favorited.');
  end if;

  if v_owner = v_actor then
    perform public.platform_raise_error('PLT005', 'You cannot favorite your own listing.');
  end if;

  perform 1
    from public.service_favorites f
   where f.entity_id = v_actor
     and f.listing_id = p_listing_id;

  if found then
    delete from public.service_favorites
     where entity_id = v_actor
       and listing_id = p_listing_id;
    v_favorited := false;
  else
    insert into public.service_favorites (entity_id, listing_id)
    values (v_actor, p_listing_id)
    on conflict (entity_id, listing_id) do nothing;
    v_favorited := true;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Favorite toggled.',
    'data', jsonb_build_object(
      'listing_id', p_listing_id,
      'favorited', v_favorited
    )
  );
end;
$$;

comment on function public.service_favorite_toggle(uuid) is
  'Security invoker, VOLATILE. Idempotent favorite toggle: published listings only (PLT005), never the caller own listing (PLT005), unknown listings PLT004.';

-- =============================================================================
-- SECTION 8: EXECUTE grants (anon receives only service_listing_get)
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_listing_create(uuid, text, text, text, numeric, numeric, char(3), text)
  to authenticated, service_role;
grant execute on function public.service_listing_update(uuid, text, text, uuid, text, numeric, numeric, char(3))
  to authenticated, service_role;
grant execute on function public.service_listing_publish(uuid)
  to authenticated, service_role;
grant execute on function public.service_listing_unpublish(uuid, text)
  to authenticated, service_role;
grant execute on function public.service_listing_get(uuid)
  to anon, authenticated, service_role;
grant execute on function public.service_listing_list_mine(text, integer, uuid)
  to authenticated, service_role;
grant execute on function public.service_favorite_toggle(uuid)
  to authenticated, service_role;

-- =============================================================================
-- SECTION 9: Realtime exclusion (marketplace tables never stream)
-- =============================================================================
do $$
begin
  if exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('service_listings', 'service_listing_media', 'service_favorites')
  ) then
    alter publication supabase_realtime
      drop table public.service_listings, public.service_listing_media, public.service_favorites;
  end if;
end;
$$;
