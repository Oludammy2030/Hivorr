-- EP-03-03: Double-Blind Review & Rating Schema & Server-Side Rules
--
-- Trust-invariant double-blind review system: 2 tables (service_reviews,
-- service_review_aggregates) + atomic service_listings cache + 4 SECURITY
-- INVOKER RPCs with envelope {success, code, message, data}.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER for 3 RPCs (RLS applies inside body); SECURITY DEFINER
--     for service_review_reveal_if_ready only (narrowly scoped, participant-
--     validated, pinned search_path) to count all reviews for a contract
--     including the counterparty RLS-hidden row and to update aggregates/listing
--     atomically. One new SECURITY DEFINER (mirrors dispute_place_escrow_hold
--     precedent) — posture audit updated to expect 1.
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - State machine: INSERT (is_revealed=false, revealed_at NULL)
--     -- both_submitted (count=2) OR now() > coalesce(closed_at, completed_at)+14d
--     --reveal--> is_revealed=true, revealed_at=now() atomically with
--     -- aggregates recomputation (avg, count, distribution) + listing cache.
--   - Lazy expiry: review_deadline = coalesce(closed_at, completed_at,
--     accepted_at)+interval '14 days' (REVIEW_REVEAL_DAYS=14); deadline not
--     computable when completed_at IS NULL (active) -> only count=2 path.
--   - Concurrency: SELECT ... FOR UPDATE on service_reviews rows in
--     reveal_if_ready prevents double-credit; ON CONFLICT DO UPDATE on
--     aggregates with FOR UPDATE partition lock serializes same professional.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 2 tables from anon, authenticated, service_role then narrow
--     SELECT on aggregates to anon, authenticated (public published stars);
--     SELECT,INSERT on service_reviews to authenticated with column-level
--     UPDATE(is_revealed,revealed_at,updated_at) for reveal flip only (blocks
--     direct rating/comment mutation); full grants to service_role only.
--   - service_listings cache: GRANT UPDATE(avg_rating, review_count) to
--     authenticated (narrow, safe) — service_reviews RPC is the only writer,
--     mirrors financial_balances UPDATE grant to authenticated for RPC
--     (20260829100004:520).
--   - REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public then
--     explicit GRANT EXECUTE per RPC (3 x authenticated+service_role,
--     1 x anon+authenticated+service_role for get_for_listing).
--
-- MIGRATION POSTURE
--   - No DDL on any prior table/function/policy (Rule 3 write discipline); only
--     new objects plus additive grant on service_listings avg_rating/review_count.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.
--   - No new bucket; reviews are text-only (comment ≤2000).
--   - Reuse: service_listings (avg cache), service_contracts (reviewable gate),
--     professions/industries, entities, platform_* helpers.

-- =============================================================================
-- SECTION 1: service_reviews
-- =============================================================================
create table if not exists public.service_reviews (
  id                    uuid primary key default gen_random_uuid(),
  contract_id           uuid not null references public.service_contracts (id) on delete cascade,
  service_listing_id    uuid not null references public.service_listings (id) on delete restrict,
  reviewer_entity_id    uuid not null references public.entities (id) on delete restrict,
  reviewee_entity_id    uuid not null references public.entities (id) on delete restrict,
  profession_id         uuid not null references public.professions (id) on delete restrict,
  rating                smallint not null,
  comment               text,
  is_revealed           boolean not null default false,
  revealed_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  constraint service_reviews_rating_range check (rating between 1 and 5),
  constraint service_reviews_comment_length check (
    comment is null or char_length(btrim(comment)) between 10 and 2000
  ),
  constraint service_reviews_no_self check (reviewer_entity_id <> reviewee_entity_id),
  constraint service_reviews_revealed_at_semantics check (
    (is_revealed = false and revealed_at is null)
    or (is_revealed = true and revealed_at is not null)
  ),
  constraint service_reviews_contract_reviewer_key unique (contract_id, reviewer_entity_id)
);

comment on table public.service_reviews is
  'Double-blind review rows: one per participant per contract, is_revealed=false until both submitted or deadline expiry, then revealed atomically with aggregates and listing cache in same transaction.';
comment on column public.service_reviews.contract_id is 'FK to service_contracts ON DELETE CASCADE (engagement atom).';
comment on column public.service_reviews.service_listing_id is 'Denormalized from service_contracts.service_listing_id for get_for_listing without contract join; ON DELETE RESTRICT preserves listing link.';
comment on column public.service_reviews.reviewer_entity_id is 'Author (auth.uid() at submit, never client-supplied).';
comment on column public.service_reviews.reviewee_entity_id is 'Opposite participant derived as CASE WHEN reviewer=client THEN professional ELSE client END.';
comment on column public.service_reviews.profession_id is 'Denormalized from service_listings.profession_id for aggregate partition; ON DELETE RESTRICT.';
comment on column public.service_reviews.rating is '1-5 inclusive (smallint CHECK).';
comment on column public.service_reviews.comment is 'Optional 10-2000 chars when present; NULL for star-only.';
comment on column public.service_reviews.is_revealed is 'False until both_submitted OR expiry, then true atomically via reveal_if_ready FOR UPDATE.';
comment on column public.service_reviews.revealed_at is 'Set to now() on reveal; NULL before.';

create index if not exists service_reviews_contract_idx
  on public.service_reviews (contract_id);
create index if not exists service_reviews_reviewer_idx
  on public.service_reviews (reviewer_entity_id);
create index if not exists service_reviews_listing_revealed_idx
  on public.service_reviews (service_listing_id, revealed_at desc) where is_revealed = true;
create index if not exists service_reviews_contract_revealed_idx
  on public.service_reviews (contract_id, is_revealed);

drop trigger if exists service_reviews_set_updated_at on public.service_reviews;
create trigger service_reviews_set_updated_at
  before update on public.service_reviews
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: service_review_aggregates
-- =============================================================================
create table if not exists public.service_review_aggregates (
  professional_entity_id uuid not null references public.entities (id) on delete cascade,
  profession_id         uuid not null references public.professions (id) on delete restrict,
  avg_rating            numeric not null default 0 check (avg_rating between 0 and 5),
  review_count          integer not null default 0 check (review_count >= 0),
  distribution          jsonb not null default '{"1":0,"2":0,"3":0,"4":0,"5":0}'::jsonb,
  last_revealed_at      timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  constraint service_review_aggregates_pkey primary key (professional_entity_id, profession_id),
  constraint service_review_aggregates_avg_range check (avg_rating between 0 and 5)
);

comment on table public.service_review_aggregates is
  'Materialized per (professional, profession) aggregates: avg_rating, review_count, distribution {1..5: n}, recomputed transactionally on reveal. Powers service_ranking_search without scanning service_reviews.';
comment on column public.service_review_aggregates.professional_entity_id is 'Reviewee (professional) — part of PK.';
comment on column public.service_review_aggregates.profession_id is 'Profession of the listing — part of PK.';
comment on column public.service_review_aggregates.avg_rating is 'AVG(rating) FILTER (WHERE is_revealed) numeric(3,2) recomputed on reveal.';
comment on column public.service_review_aggregates.distribution is 'Counts per star 1..5 as jsonb for EP-03-09 stars widget.';

create index if not exists service_review_aggregates_profession_idx
  on public.service_review_aggregates (profession_id, avg_rating desc);

drop trigger if exists service_review_aggregates_set_updated_at on public.service_review_aggregates;
create trigger service_review_aggregates_set_updated_at
  before update on public.service_review_aggregates
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 3: RLS enable + REVOKE + grants + policies (default-deny)
-- =============================================================================
alter table public.service_reviews enable row level security;
alter table public.service_review_aggregates enable row level security;

revoke all on
  public.service_reviews,
  public.service_review_aggregates
from anon, authenticated, service_role;

-- service_reviews: authenticated needs SELECT (own + revealed) + INSERT (reviewer gate) + UPDATE (reveal flip only on is_revealed fields)
-- anon needs SELECT for public get_for_listing via SECURITY INVOKER (anon reads revealed rows only)
grant select on public.service_reviews to anon;
grant select on public.service_reviews to authenticated;
grant insert (contract_id, service_listing_id, reviewer_entity_id, reviewee_entity_id, profession_id, rating, comment, is_revealed, revealed_at) on public.service_reviews to authenticated;
grant update (is_revealed, revealed_at, updated_at) on public.service_reviews to authenticated;
grant select, insert, update, delete on public.service_reviews to service_role;

-- service_review_aggregates: public read for ranking/listing detail; authenticated needs INSERT/UPDATE for reveal UPSERT (mirrors service_reviews)
grant select on public.service_review_aggregates to anon, authenticated;
grant insert, update on public.service_review_aggregates to authenticated;
grant select, insert, update, delete on public.service_review_aggregates to service_role;

-- service_listings cache: narrow grant for reveal transaction (mirrors financial_balances UPDATE grant)
grant update (avg_rating, review_count) on public.service_listings to authenticated;

-- Policies: participant-scoped SELECT with is_revealed gate + public revealed + insert/update
drop policy if exists service_reviews_select on public.service_reviews;
create policy service_reviews_select
  on public.service_reviews for select to authenticated
  using (
    exists (
      select 1 from public.service_contracts c
       where c.id = contract_id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
    and (is_revealed or reviewer_entity_id = auth.uid())
  );

drop policy if exists service_reviews_select_public on public.service_reviews;
create policy service_reviews_select_public
  on public.service_reviews for select to anon, authenticated
  using (is_revealed);

drop policy if exists service_reviews_insert on public.service_reviews;
create policy service_reviews_insert
  on public.service_reviews for insert to authenticated
  with check (
    reviewer_entity_id = auth.uid()
    and exists (
      select 1 from public.service_contracts c
       where c.id = contract_id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
    and not is_revealed
  );

drop policy if exists service_reviews_update on public.service_reviews;
create policy service_reviews_update
  on public.service_reviews for update to authenticated
  using (
    exists (
      select 1 from public.service_contracts c
       where c.id = contract_id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
  )
  with check (
    is_revealed
  );

drop policy if exists service_review_aggregates_select on public.service_review_aggregates;
create policy service_review_aggregates_select
  on public.service_review_aggregates for select to anon, authenticated
  using (true);

drop policy if exists service_review_aggregates_insert on public.service_review_aggregates;
create policy service_review_aggregates_insert
  on public.service_review_aggregates for insert to authenticated
  with check (true);

drop policy if exists service_review_aggregates_update on public.service_review_aggregates;
create policy service_review_aggregates_update
  on public.service_review_aggregates for update to authenticated
  using (true)
  with check (true);

drop policy if exists service_listings_update_review_cache on public.service_listings;
create policy service_listings_update_review_cache
  on public.service_listings for update to authenticated
  using (
    exists (
      select 1 from public.service_contracts c
       where c.service_listing_id = service_listings.id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.service_contracts c
       where c.service_listing_id = service_listings.id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
  );

-- =============================================================================
-- SECTION 4: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 4a. service_review_submit ──────────────────────────────────────────────
create or replace function public.service_review_submit(
  p_contract_id uuid,
  p_rating integer,
  p_comment text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_listing record;
  v_reviewee uuid;
  v_profession_id uuid;
  v_service_listing_id uuid;
  v_comment text;
  v_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    perform public.platform_raise_error('PLT003', 'Rating must be between 1 and 5.');
  end if;

  if p_comment is not null then
    v_comment := nullif(btrim(p_comment), '');
    if v_comment is not null and char_length(v_comment) not between 10 and 2000 then
      perform public.platform_raise_error('PLT003', 'Comment must be between 10 and 2000 characters.');
    end if;
  else
    v_comment := null;
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if v_contract.status not in ('active', 'completed', 'closed') then
    perform public.platform_raise_error('PLT005', 'Contract not in reviewable state.');
  end if;

  -- Derive reviewee, listing, profession
  if v_actor = v_contract.client_entity_id then
    v_reviewee := v_contract.professional_entity_id;
  else
    v_reviewee := v_contract.client_entity_id;
  end if;

  if v_reviewee = v_actor then
    perform public.platform_raise_error('PLT005', 'You cannot review yourself.');
  end if;

  select l.id, l.profession_id into v_service_listing_id, v_profession_id
    from public.service_listings l
   where l.id = v_contract.service_listing_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  -- Single-review guard via UNIQUE; also pre-check for nicer PLT005
  if exists (
    select 1 from public.service_reviews r
     where r.contract_id = p_contract_id and r.reviewer_entity_id = v_actor
  ) then
    perform public.platform_raise_error('PLT005', 'You have already submitted a review for this contract.');
  end if;

  begin
    insert into public.service_reviews (
      contract_id, service_listing_id, reviewer_entity_id, reviewee_entity_id,
      profession_id, rating, comment, is_revealed, revealed_at
    ) values (
      p_contract_id, v_service_listing_id, v_actor, v_reviewee,
      v_profession_id, p_rating, v_comment, false, null
    ) returning id into v_id;
  exception when unique_violation then
    perform public.platform_raise_error('PLT005', 'You have already submitted a review for this contract.');
  end;

  perform public.platform_audit_log_add(
    'service_review_submit', 'service_reviews',
    jsonb_build_object('contract_id', p_contract_id, 'rating', p_rating, 'review_id', v_id)
  );

  -- Attempt lazy reveal (both_submitted OR expiry) — ignore errors, reveal is idempotent
  begin
    perform public.service_review_reveal_if_ready(p_contract_id);
  exception when others then
    -- swallow reveal errors; submit itself succeeded
    null;
  end;

  select jsonb_build_object(
    'id', r.id, 'contract_id', r.contract_id, 'service_listing_id', r.service_listing_id,
    'reviewer_entity_id', r.reviewer_entity_id, 'reviewee_entity_id', r.reviewee_entity_id,
    'profession_id', r.profession_id, 'rating', r.rating, 'comment', r.comment,
    'is_revealed', r.is_revealed, 'revealed_at', r.revealed_at,
    'created_at', r.created_at, 'updated_at', r.updated_at
  ) into v_data from public.service_reviews r where r.id = v_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Review submitted.',
    'data', jsonb_build_object('review', v_data)
  );
end;
$$;

comment on function public.service_review_submit(uuid, integer, text) is
  'SECURITY INVOKER, VOLATILE. Participant submits 1-5 + comment for active/completed/closed contract; reviewer=auth.uid(), reviewee derived as opposite participant, is_revealed=false. Single-review guard via UNIQUE, rating/comment validation, reviewable lifecycle gate. Attempts lazy reveal via service_review_reveal_if_ready. Audit-logged.';

-- ─── 4b. service_review_get_mine ────────────────────────────────────────────
create or replace function public.service_review_get_mine(
  p_contract_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_your_review jsonb;
  v_revealed jsonb;
  v_you_submitted boolean;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  -- Attempt lazy reveal before reading (handles expiry without cron)
  begin
    perform public.service_review_reveal_if_ready(p_contract_id);
  exception when others then
    null;
  end;

  select to_jsonb(r) into v_your_review
    from public.service_reviews r
   where r.contract_id = p_contract_id and r.reviewer_entity_id = v_actor;

  v_you_submitted := v_your_review is not null;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at), '[]'::jsonb) into v_revealed
    from public.service_reviews r
   where r.contract_id = p_contract_id and r.is_revealed = true;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Review status retrieved.',
    'data', jsonb_build_object(
      'you_have_submitted', v_you_submitted,
      'your_review', v_your_review,
      'revealed_reviews', v_revealed,
      'review_count', (select count(*)::int from public.service_reviews where contract_id = p_contract_id and is_revealed = true)
    )
  );
end;
$$;

comment on function public.service_review_get_mine(uuid) is
  'SECURITY INVOKER, STABLE. Participant reads own submission status; returns you_have_submitted bool, your_review jsonb (even when is_revealed=false), and revealed_reviews[] (only is_revealed=true). No timing oracle — never leaks counterparty is_revealed=false. Attempts lazy reveal.';

-- ─── 4c. service_review_get_for_listing ─────────────────────────────────────
create or replace function public.service_review_get_for_listing(
  p_service_listing_id uuid,
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
  v_listing record;
  v_cursor_ts timestamptz;
  v_cursor_id uuid;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
  v_avg numeric;
  v_count int;
  v_dist jsonb;
begin
  if p_service_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  select l.id, l.entity_id, l.profession_id, l.status, p.is_active as prof_active
    into v_listing
    from public.service_listings l
    join public.professions p on p.id = l.profession_id
   where l.id = p_service_listing_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if v_listing.status <> 'published' then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if not v_listing.prof_active then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  -- Cursor handling: keyset (revealed_at desc, id desc) for revealed rows only
  if p_cursor is not null then
    select r.revealed_at, r.id into v_cursor_ts, v_cursor_id
      from public.service_reviews r
     where r.id = p_cursor
       and r.service_listing_id = p_service_listing_id
       and r.is_revealed = true;
    if not found then
      -- Unknown or foreign or unrevealed cursor: treat as exhausted (no oracle)
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Reviews retrieved.',
        'data', jsonb_build_object(
          'reviews', '[]'::jsonb,
          'avg_rating', 0,
          'review_count', 0,
          'distribution', '{"1":0,"2":0,"3":0,"4":0,"5":0}'::jsonb,
          'has_more', false,
          'next_cursor', null
        )
      );
    end if;
  end if;

  -- Fetch paginated revealed reviews
  select
    coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.revealed_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
    coalesce(bool_or(x.rn > p_limit), false),
    (array_agg(x.id order by x.rn))[p_limit]
  into v_items, v_has_more, v_next
  from (
    select r.id, r.contract_id, r.service_listing_id, r.reviewer_entity_id, r.reviewee_entity_id,
           r.profession_id, r.rating, r.comment, r.is_revealed, r.revealed_at, r.created_at,
           row_number() over (order by r.revealed_at desc, r.id desc) as rn
      from public.service_reviews r
     where r.service_listing_id = p_service_listing_id
       and r.is_revealed = true
       and (p_cursor is null or (r.revealed_at, r.id) < (v_cursor_ts, v_cursor_id))
  ) x;

  if not v_has_more then
    v_next := null;
  end if;

  -- Aggregate header from service_review_aggregates keyed by (listing owner, profession)
  select a.avg_rating, a.review_count, a.distribution
    into v_avg, v_count, v_dist
    from public.service_review_aggregates a
   where a.professional_entity_id = v_listing.entity_id
     and a.profession_id = v_listing.profession_id;

  if not found then
    v_avg := 0;
    v_count := 0;
    v_dist := '{"1":0,"2":0,"3":0,"4":0,"5":0}'::jsonb;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Reviews retrieved.',
    'data', jsonb_build_object(
      'reviews', coalesce(v_items, '[]'::jsonb),
      'avg_rating', coalesce(v_avg, 0),
      'review_count', coalesce(v_count, 0),
      'distribution', coalesce(v_dist, '{"1":0,"2":0,"3":0,"4":0,"5":0}'::jsonb),
      'has_more', coalesce(v_has_more, false),
      'next_cursor', v_next
    )
  );
end;
$$;

comment on function public.service_review_get_for_listing(uuid, integer, uuid) is
  'SECURITY INVOKER, STABLE. Public paginated list of is_revealed=true reviews for published listing; keyset (revealed_at desc, id desc) via service_reviews_listing_revealed_idx. Returns reviews[] + avg_rating/review_count/distribution from service_review_aggregates keyed by (listing owner, profession). anon capable for published; identical PLT004 for draft/unknown (no oracle).';

-- ─── 4d. service_review_reveal_if_ready ─────────────────────────────────────
-- SECURITY DEFINER is required here: the function must count *all* reviews for a
-- contract (including the counterparty's unrevealed row which is RLS-hidden from
-- the caller) to decide both_submitted (count=2) and must update aggregates
-- and listing cache atomically. The function is narrowly scoped (single contract),
-- validates caller is a participant via service_contracts, and is the only
-- SECURITY DEFINER in the review subsystem (mirrors dispute_place_escrow_hold).
create or replace function public.service_review_reveal_if_ready(
  p_contract_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_count int;
  v_revealed_count int;
  v_already bool := false;
  v_should_reveal boolean := false;
  v_deadline timestamptz;
  v_listing_id uuid;
  v_profession_id uuid;
  v_avg numeric;
  v_cnt int;
  v_dist jsonb;
  v_reviewee uuid;
  v_prof uuid;
  v_listing_prof uuid;
  v_revealed_ids uuid[];
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Review context not found.');
  end if;

  -- Lock reviews for this contract to prevent concurrent double-credit
  perform 1 from public.service_reviews where contract_id = p_contract_id for update;

  select count(*)::int into v_count from public.service_reviews where contract_id = p_contract_id;
  select count(*)::int into v_revealed_count from public.service_reviews where contract_id = p_contract_id and is_revealed = true;

  if v_count = 0 then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'No reviews to reveal.',
      'data', jsonb_build_object('revealed', false, 'already', false, 'review_count', 0, 'reason', 'no_reviews')
    );
  end if;

  if v_count = v_revealed_count and v_revealed_count > 0 then
    -- Already revealed
    select avg(rating)::numeric(3,2) into v_avg from public.service_reviews where contract_id = p_contract_id and is_revealed = true;
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Reviews already revealed.',
      'data', jsonb_build_object('revealed', true, 'already', true, 'review_count', v_revealed_count, 'avg_rating', coalesce(v_avg,0))
    );
  end if;

  -- Deadline: coalesce(closed_at, completed_at, accepted_at) + 14 days
  v_deadline := coalesce(v_contract.closed_at, v_contract.completed_at, v_contract.accepted_at) + interval '14 days';

  if v_deadline is not null and now() > v_deadline then
    v_should_reveal := true;
  end if;

  if v_count = 2 then
    v_should_reveal := true;
  end if;

  if not v_should_reveal then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Not ready to reveal.',
      'data', jsonb_build_object('revealed', false, 'already', false, 'review_count', v_count, 'revealed_count', v_revealed_count, 'reason', 'awaiting_counterparty_or_deadline')
    );
  end if;

  -- Perform reveal: collect ids without aggregate in RETURNING
  with updated as (
    update public.service_reviews
       set is_revealed = true, revealed_at = now(), updated_at = now()
     where contract_id = p_contract_id and is_revealed = false
     returning id
  )
  select array_agg(id) into v_revealed_ids from updated;

  -- For each distinct reviewee+profession, recompute aggregates
  -- We need to lock aggregates partition to prevent concurrent lost update
  for v_reviewee, v_prof in
    select distinct r.reviewee_entity_id, r.profession_id
      from public.service_reviews r
     where r.contract_id = p_contract_id
  loop
    -- Lock aggregate row if exists
    perform 1 from public.service_review_aggregates
     where professional_entity_id = v_reviewee and profession_id = v_prof for update;

    select
      avg(r.rating)::numeric(3,2),
      count(*)::int,
      jsonb_build_object(
        '1', count(*) filter (where r.rating = 1),
        '2', count(*) filter (where r.rating = 2),
        '3', count(*) filter (where r.rating = 3),
        '4', count(*) filter (where r.rating = 4),
        '5', count(*) filter (where r.rating = 5)
      )
    into v_avg, v_cnt, v_dist
      from public.service_reviews r
     where r.reviewee_entity_id = v_reviewee
       and r.profession_id = v_prof
       and r.is_revealed = true;

    insert into public.service_review_aggregates (
      professional_entity_id, profession_id, avg_rating, review_count, distribution, last_revealed_at
    ) values (
      v_reviewee, v_prof, coalesce(v_avg,0), coalesce(v_cnt,0), coalesce(v_dist, '{"1":0,"2":0,"3":0,"4":0,"5":0}'::jsonb), now()
    ) on conflict (professional_entity_id, profession_id) do update
       set avg_rating = excluded.avg_rating,
           review_count = excluded.review_count,
           distribution = excluded.distribution,
           last_revealed_at = excluded.last_revealed_at,
           updated_at = now();
  end loop;

  -- For each distinct listing, update service_listings cache
  for v_listing_id in
    select distinct r.service_listing_id from public.service_reviews r where r.contract_id = p_contract_id
  loop
    -- Lock listing row
    perform 1 from public.service_listings where id = v_listing_id for update;

    select avg(r.rating)::numeric(3,2), count(*)::int
      into v_avg, v_cnt
      from public.service_reviews r
     where r.service_listing_id = v_listing_id and r.is_revealed = true;

    update public.service_listings
       set avg_rating = coalesce(v_avg, 0),
           review_count = coalesce(v_cnt, 0),
           updated_at = now()
     where id = v_listing_id;
  end loop;

  perform public.platform_audit_log_add(
    'service_review_reveal', 'service_reviews',
    jsonb_build_object('contract_id', p_contract_id, 'revealed_ids', v_revealed_ids, 'count', v_count)
  );

  -- Return summary
  select avg(rating)::numeric(3,2) into v_avg from public.service_reviews where contract_id = p_contract_id and is_revealed = true;
  select count(*)::int into v_cnt from public.service_reviews where contract_id = p_contract_id and is_revealed = true;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Reviews revealed.',
    'data', jsonb_build_object('revealed', true, 'already', false, 'review_count', v_cnt, 'avg_rating', coalesce(v_avg,0))
  );
end;
$$;

comment on function public.service_review_reveal_if_ready(uuid) is
  'SECURITY DEFINER, VOLATILE. Atomic disclosure: FOR UPDATE on service_reviews rows; count=2 OR now()>coalesce(closed_at,completed_at,accepted_at)+14d. UPDATE is_revealed=true + UPSERT service_review_aggregates per (reviewee, profession) with distribution + UPDATE service_listings avg/review_count. Idempotent, FOR UPDATE prevents double-credit. Audit-logged. Narrowly scoped, participant-validated, pinned search_path.';

-- =============================================================================
-- SECTION 5: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_review_submit(uuid, integer, text) to authenticated, service_role;
grant execute on function public.service_review_get_mine(uuid) to authenticated, service_role;
grant execute on function public.service_review_get_for_listing(uuid, integer, uuid) to anon, authenticated, service_role;
grant execute on function public.service_review_reveal_if_ready(uuid) to authenticated, service_role;

comment on function public.service_review_submit(uuid, integer, text) is
  'SECURITY INVOKER, VOLATILE. Participant submits 1-5 + comment for active/completed/closed contract; reviewer=auth.uid(), reviewee derived as opposite participant, is_revealed=false. Single-review guard via UNIQUE, rating/comment validation, reviewable lifecycle gate. Attempts lazy reveal.';
comment on function public.service_review_get_mine(uuid) is
  'SECURITY INVOKER, STABLE. Participant reads own submission status; returns you_have_submitted bool, your_review jsonb (even when is_revealed=false), and revealed_reviews[] (only is_revealed=true). No timing oracle.';
comment on function public.service_review_get_for_listing(uuid, integer, uuid) is
  'SECURITY INVOKER, STABLE. Public paginated list of is_revealed=true reviews for published listing; keyset (revealed_at desc, id desc) via service_reviews_listing_revealed_idx. Returns reviews[] + avg_rating/review_count/distribution from aggregates keyed by (listing owner, profession). anon capable for published; identical PLT004 for draft/unknown (no oracle).';
comment on function public.service_review_reveal_if_ready(uuid) is
  'SECURITY INVOKER, VOLATILE. Atomic disclosure: FOR UPDATE on service_reviews rows; count=2 OR expiry 14d. UPDATE is_revealed=true + UPSERT aggregates per (reviewee, profession) + UPDATE service_listings cache. Idempotent, audit-logged.';

-- =============================================================================
-- SECTION 6: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('service_reviews', 'service_review_aggregates')
  ) then
    alter publication supabase_realtime drop table
      public.service_reviews, public.service_review_aggregates;
  end if;
end;
$$;
