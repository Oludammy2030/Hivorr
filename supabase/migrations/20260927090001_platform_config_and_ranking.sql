-- EP-03-06: Deterministic Ranking & Matching Engine
--
-- Platform-level deterministic ranking primitive: platform_config weight store
-- + service_ranking_search SECURITY INVOKER STABLE RPC + ranking indexes.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER for service_ranking_search (RLS applies inside body);
--     no new SECURITY DEFINER (023/025/027/029 posture audits stay green where
--     prose recounts exactly one SECURITY DEFINER already: service_review_reveal_if_ready).
--     This migration keeps prose count at 1 by staying INVOKER.
--   - Envelope: {success, code, message, data}; codes PLT000/PLT003/PLT004/PLT999
--     per 20260829100004 vocabulary (authenticated path via platform_raise_error).
--     anon path raises via errcode/detail contract (service_listing_get precedent
--     20260921090001:1036) because anon lacks EXECUTE on platform_raise_error.
--   - Weights: platform_config.key='service_ranking_weights' JSONB read per call;
--     never hardcoded. COALESCE fallback defaults keep ranking functional if row
--     missing (graceful bootstrap).
--   - Scoring signals (auditable, weighted sum):
--     score = w_verify*kyc_tier_weight + w_rating*bayesian_avg + w_completion*completion_rate
--           + w_recency*decay(now()-published_at) + w_relevance*ts_rank + w_activity*login_recency
--     See §0 comments for each signal. Tie-break id DESC for total determinism.
--   - Pagination: keyset (score DESC, id DESC) via WHERE (score, id) < (cursor_score, cursor_id)
--     + ORDER BY score DESC, id DESC LIMIT p_limit+1 => has_more. No OFFSET.
--   - RLS: ranking is public read (status='published' only); is_trade_verified_cache fast path,
--     service_review_aggregates pre-materialized, completion via service_contracts lateral,
--     login via entities.

-- =============================================================================
-- SECTION 0: platform_config table
-- =============================================================================
-- /* RANKING FORMULA v1 — 2026-09-26 — weights via platform_config service_ranking_weights
--    score = w_verify*kyc_tier_weight + w_rating*bayesian_avg + w_completion*completion_rate
--          + w_recency*decay(now()-published_at) + w_relevance*ts_rank + w_activity*login_recency
--    kyc_tier_weight: tier_3=1.0 tier_2=0.66 tier_1=0.33 else 0.0; is_trade_verified_cache bonus +0.15
--    bayesian_avg: (C*m + avg_rating*review_count)/(C+review_count) where C=bayesian_prior_count, m=bayesian_prior_mean
--    completion_rate: completed|closed contracts / total per professional_entity_id
--    decay: exp(-ln2*age_days/half_life) age_days=extract(epoch FROM now()-published_at)/86400 half_life=recency_half_life_days
--    ts_rank: ts_rank(search_vector, plainto_tsquery('english', p_query), 32) capped 0..1
--    login_recency: exp(-age_days/activity_half_life) on coalesce(last_seen_at, created_at)
--    DENOM: bayesian_avg scaled /5 to 0..1, ts_rank capped, completion/decay already 0..1
--    Tie-break id DESC. Weights read per call from platform_config, not hardcoded.
-- */

create table if not exists public.platform_config (
  key text primary key,
  value jsonb not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint platform_config_key_format check (key ~ '^[a-z_]+$'),
  constraint platform_config_value_is_object check (jsonb_typeof(value) = 'object'),
  constraint platform_config_weights_required_keys check (
    key <> 'service_ranking_weights'
    or (value ?& array['w_verify','w_rating','w_completion','w_recency','w_relevance','w_activity'])
  ),
  constraint platform_config_weights_range check (
    key <> 'service_ranking_weights'
    or (
      coalesce((value->>'w_verify')::numeric, 0) between 0 and 1
      and coalesce((value->>'w_rating')::numeric, 0) between 0 and 1
      and coalesce((value->>'w_completion')::numeric, 0) between 0 and 1
      and coalesce((value->>'w_recency')::numeric, 0) between 0 and 1
      and coalesce((value->>'w_relevance')::numeric, 0) between 0 and 1
      and coalesce((value->>'w_activity')::numeric, 0) between 0 and 1
    )
  ),
  constraint platform_config_weights_sum check (
    key <> 'service_ranking_weights'
    or (
      coalesce((value->>'w_verify')::numeric, 0)
      + coalesce((value->>'w_rating')::numeric, 0)
      + coalesce((value->>'w_completion')::numeric, 0)
      + coalesce((value->>'w_recency')::numeric, 0)
      + coalesce((value->>'w_relevance')::numeric, 0)
      + coalesce((value->>'w_activity')::numeric, 0)
      between 0.999 and 1.001
    )
  ),
  constraint platform_config_weights_priors check (
    key <> 'service_ranking_weights'
    or (
      coalesce((value->>'bayesian_prior_count')::numeric, 5) between 1 and 100
      and coalesce((value->>'bayesian_prior_mean')::numeric, 3.0) between 0 and 5
      and coalesce((value->>'recency_half_life_days')::numeric, 30) > 0
      and coalesce((value->>'activity_half_life_days')::numeric, 14) > 0
      and coalesce((value->>'ts_rank_normalization')::numeric, 32) between 0 and 128
    )
  )
);

comment on table public.platform_config is
  'Engine weight store — versioned JSONB per key (service_ranking_weights, future logistics_weights). Service-role-writable only. RANKING FORMULA v1 see table comment §0.';
comment on column public.platform_config.key is 'Primary key matching ^[a-z_]+$ (e.g., service_ranking_weights).';
comment on column public.platform_config.value is 'JSONB value; service_ranking_weights holds {w_verify, w_rating, w_completion, w_recency, w_relevance, w_activity, bayesian_prior_count/mean, recency/activity_half_life_days, ts_rank_normalization} summing ~1.0.';
comment on column public.platform_config.description is 'Human-readable description / version tag.';
comment on column public.platform_config.updated_at is 'Set by platform_set_updated_at trigger; RPC returns as weights_version for cache invalidation.';

drop trigger if exists platform_config_set_updated_at on public.platform_config;
create trigger platform_config_set_updated_at
  before update on public.platform_config
  for each row
  execute function public.platform_set_updated_at();

alter table public.platform_config enable row level security;

revoke all on public.platform_config from anon, authenticated, service_role;

grant select on public.platform_config to anon, authenticated, service_role;
grant insert (key, value, description) on public.platform_config to service_role;
grant update (value, description) on public.platform_config to service_role;
grant delete on public.platform_config to service_role;

drop policy if exists platform_config_select on public.platform_config;
create policy platform_config_select
  on public.platform_config for select to anon, authenticated
  using (true);

drop policy if exists platform_config_service_role_select on public.platform_config;
create policy platform_config_service_role_select
  on public.platform_config for select to service_role
  using (true);

drop policy if exists platform_config_service_role_insert on public.platform_config;
create policy platform_config_service_role_insert
  on public.platform_config for insert to service_role
  with check (true);

drop policy if exists platform_config_service_role_update on public.platform_config;
create policy platform_config_service_role_update
  on public.platform_config for update to service_role
  using (true)
  with check (true);

drop policy if exists platform_config_service_role_delete on public.platform_config;
create policy platform_config_service_role_delete
  on public.platform_config for delete to service_role
  using (true);

insert into public.platform_config (key, value, description)
values (
  'service_ranking_weights',
  '{
    "w_verify": 0.28,
    "w_rating": 0.26,
    "w_completion": 0.16,
    "w_recency": 0.12,
    "w_relevance": 0.12,
    "w_activity": 0.06,
    "bayesian_prior_count": 5,
    "bayesian_prior_mean": 3.0,
    "recency_half_life_days": 30,
    "activity_half_life_days": 14,
    "ts_rank_normalization": 32
  }'::jsonb,
  'Deterministic ranking v1 — 2026-09-26 — weights via platform_config service_ranking_weights (see migration §0).'
)
on conflict (key) do nothing;

-- =============================================================================
-- SECTION 1: Additive ranking indexes + additive entities.last_seen_at column
-- =============================================================================
create index if not exists service_listings_published_ranking_idx
  on public.service_listings (profession_id, avg_rating desc, published_at desc)
  where status = 'published';

alter table public.entities add column if not exists last_seen_at timestamptz default now();

create index if not exists entities_last_seen_at_idx
  on public.entities (last_seen_at desc);

comment on column public.entities.last_seen_at is
  'Additive for EP-03-06 w_activity login_recency = exp(-age_days/activity_half_life) on coalesce(last_seen_at, created_at). Default now(); future sync from auth.users via Edge Function (out of scope). Idempotent.';

-- =============================================================================
-- SECTION 2: Helper service_ranking_weights_get (optional, anon readable)
-- =============================================================================
create or replace function public.service_ranking_weights_get()
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_value jsonb;
begin
  select value into v_value from public.platform_config where key = 'service_ranking_weights';
  if not found then
    v_value := '{
      "w_verify": 0.28, "w_rating": 0.26, "w_completion": 0.16,
      "w_recency": 0.12, "w_relevance": 0.12, "w_activity": 0.06,
      "bayesian_prior_count": 5, "bayesian_prior_mean": 3.0,
      "recency_half_life_days": 30, "activity_half_life_days": 14, "ts_rank_normalization": 32
    }'::jsonb;
  end if;
  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Ranking weights retrieved.',
    'data', v_value
  );
end;
$$;

comment on function public.service_ranking_weights_get() is
  'SECURITY INVOKER STABLE. Public read of service_ranking_weights value for Dart mirror bootstrap. Never writes. anon+authenticated.';

-- =============================================================================
-- SECTION 3: RPC service_ranking_search — deterministic ranking primitive
-- =============================================================================
create or replace function public.service_ranking_search(
  p_profession_id uuid default null,
  p_query text default null,
  p_filters jsonb default '{}'::jsonb,
  p_cursor jsonb default null,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_weights jsonb;
  v_weights_version timestamptz;
  v_w_verify numeric := 0.28;
  v_w_rating numeric := 0.26;
  v_w_completion numeric := 0.16;
  v_w_recency numeric := 0.12;
  v_w_relevance numeric := 0.12;
  v_w_activity numeric := 0.06;
  v_prior_count numeric := 5;
  v_prior_mean numeric := 3.0;
  v_half_recency numeric := 30;
  v_half_activity numeric := 14;
  v_ts_norm integer := 32;
  v_query_trim text;
  v_query_tsquery tsquery;
  v_cursor_score numeric;
  v_cursor_id uuid;
  v_filter_profession_id uuid;
  v_filter_industry_id uuid;
  v_filter_price_min numeric;
  v_filter_price_max numeric;
  v_filter_currency char(3);
  v_filter_rating_min numeric;
  v_filter_verified_only boolean;
  v_items jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb;
  v_last_score numeric;
  v_last_id uuid;
  v_elem jsonb;
  v_filtered jsonb;
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    if current_user = 'anon' then
      raise exception using errcode='P0001', message='PLT003: Limit must be between 1 and 50.', detail='PLT003';
    else
      perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 50.');
    end if;
  end if;

  if p_profession_id is not null then
    if not exists (select 1 from public.professions p where p.id = p_profession_id and p.is_active) then
      if current_user = 'anon' then
        raise exception using errcode='P0001', message='PLT004: Resource not found.', detail='PLT004';
      else
        perform public.platform_raise_error('PLT004', 'Resource not found.');
      end if;
    end if;
  end if;

  v_query_trim := nullif(btrim(coalesce(p_query, '')), '');
  if v_query_trim is not null then
    if char_length(v_query_trim) > 100 then
      v_query_trim := left(v_query_trim, 100);
    end if;
    begin
      v_query_tsquery := plainto_tsquery('english', v_query_trim);
      if v_query_tsquery::text = '' then
        v_query_tsquery := null;
      end if;
    exception when others then
      v_query_tsquery := null;
    end;
  end if;

  if p_cursor is not null then
    if jsonb_typeof(p_cursor) <> 'object' then
      if current_user = 'anon' then
        raise exception using errcode='P0001', message='PLT003: Invalid cursor.', detail='PLT003';
      else
        perform public.platform_raise_error('PLT003', 'Invalid cursor.');
      end if;
    end if;
    begin
      v_cursor_score := (p_cursor->>'score')::numeric;
      v_cursor_id := (p_cursor->>'id')::uuid;
      if v_cursor_score is null or v_cursor_id is null then
        raise exception using errcode='P0001', message='Invalid cursor.', detail='PLT003';
      end if;
    exception when others then
      if current_user = 'anon' then
        raise exception using errcode='P0001', message='PLT003: Invalid cursor.', detail='PLT003';
      else
        perform public.platform_raise_error('PLT003', 'Invalid cursor.');
      end if;
    end;
  end if;

  if p_filters is not null and jsonb_typeof(p_filters) <> 'object' then
    if current_user = 'anon' then
      raise exception using errcode='P0001', message='PLT003: Filters must be an object.', detail='PLT003';
    else
      perform public.platform_raise_error('PLT003', 'Filters must be an object.');
    end if;
  end if;

  begin
    if p_filters ? 'profession_id' and (p_filters->>'profession_id') is not null then
      v_filter_profession_id := (p_filters->>'profession_id')::uuid;
      if not exists (select 1 from public.professions p where p.id = v_filter_profession_id and p.is_active) then
        if current_user = 'anon' then
          raise exception using errcode='P0001', message='PLT004: Resource not found.', detail='PLT004';
        else
          perform public.platform_raise_error('PLT004', 'Resource not found.');
        end if;
      end if;
    end if;
  exception when others then
    if sqlerrm like '%PLT004%' then raise; end if;
    if current_user = 'anon' then
      raise exception using errcode='P0001', message='PLT003: Invalid profession filter.', detail='PLT003';
    else
      perform public.platform_raise_error('PLT003', 'Invalid profession filter.');
    end if;
  end;

  begin
    if p_filters ? 'industry_id' and (p_filters->>'industry_id') is not null then
      v_filter_industry_id := (p_filters->>'industry_id')::uuid;
      if not exists (select 1 from public.industries i where i.id = v_filter_industry_id) then
        if current_user = 'anon' then
          raise exception using errcode='P0001', message='PLT004: Resource not found.', detail='PLT004';
        else
          perform public.platform_raise_error('PLT004', 'Resource not found.');
        end if;
      end if;
    end if;
  exception when others then
    if sqlerrm like '%PLT004%' then raise; end if;
    if current_user = 'anon' then
      raise exception using errcode='P0001', message='PLT003: Invalid industry filter.', detail='PLT003';
    else
      perform public.platform_raise_error('PLT003', 'Invalid industry filter.');
    end if;
  end;

  if p_filters ? 'price_min' and (p_filters->>'price_min') is not null then
    begin
      v_filter_price_min := (p_filters->>'price_min')::numeric;
      if v_filter_price_min < 0 then raise exception using errcode='P0001', message='PLT003: price_min must be >=0.', detail='PLT003'; end if;
    exception when others then
      if sqlerrm like '%PLT003%' then raise; end if;
      if current_user = 'anon' then raise exception using errcode='P0001', message='PLT003: Invalid price_min.', detail='PLT003'; else perform public.platform_raise_error('PLT003', 'Invalid price_min.'); end if;
    end;
  end if;

  if p_filters ? 'price_max' and (p_filters->>'price_max') is not null then
    begin
      v_filter_price_max := (p_filters->>'price_max')::numeric;
      if v_filter_price_max < 0 then raise exception using errcode='P0001', message='PLT003: price_max must be >=0.', detail='PLT003'; end if;
      if v_filter_price_min is not null and v_filter_price_max < v_filter_price_min then
        if current_user = 'anon' then raise exception using errcode='P0001', message='PLT003: price_max must be >= price_min.', detail='PLT003'; else perform public.platform_raise_error('PLT003', 'price_max must be >= price_min.'); end if;
      end if;
    exception when others then
      if sqlerrm like '%PLT003%' then raise; end if;
      if current_user = 'anon' then raise exception using errcode='P0001', message='PLT003: Invalid price_max.', detail='PLT003'; else perform public.platform_raise_error('PLT003', 'Invalid price_max.'); end if;
    end;
  end if;

  if p_filters ? 'currency_code' and nullif(btrim(p_filters->>'currency_code'), '') is not null then
    v_filter_currency := btrim(p_filters->>'currency_code');
    if v_filter_currency !~ '^[A-Z]{3}$' or not exists (select 1 from public.financial_supported_currencies c where c.currency_code = v_filter_currency and c.is_active) then
      if current_user = 'anon' then raise exception using errcode='P0001', message='PLT003: Currency is not supported.', detail='PLT003'; else perform public.platform_raise_error('PLT003', 'Currency is not supported.'); end if;
    end if;
  end if;

  if p_filters ? 'rating_min' and (p_filters->>'rating_min') is not null then
    begin
      v_filter_rating_min := (p_filters->>'rating_min')::numeric;
      if v_filter_rating_min < 0 or v_filter_rating_min > 5 then raise exception using errcode='P0001', message='PLT003: rating_min must be between 0 and 5.', detail='PLT003'; end if;
    exception when others then
      if sqlerrm like '%PLT003%' then raise; end if;
      if current_user = 'anon' then raise exception using errcode='P0001', message='PLT003: Invalid rating_min.', detail='PLT003'; else perform public.platform_raise_error('PLT003', 'Invalid rating_min.'); end if;
    end;
  end if;

  if p_filters ? 'is_trade_verified_only' and (p_filters->>'is_trade_verified_only') is not null then
    begin v_filter_verified_only := (p_filters->>'is_trade_verified_only')::boolean; exception when others then if current_user='anon' then raise exception using errcode='P0001', message='PLT003: Invalid is_trade_verified_only.', detail='PLT003'; else perform public.platform_raise_error('PLT003','Invalid is_trade_verified_only.'); end if; end;
  end if;
  if p_filters ? 'is_verified_only' and (p_filters->>'is_verified_only') is not null then
    begin v_filter_verified_only := coalesce(v_filter_verified_only, (p_filters->>'is_verified_only')::boolean); exception when others then if current_user='anon' then raise exception using errcode='P0001', message='PLT003: Invalid is_verified_only.', detail='PLT003'; else perform public.platform_raise_error('PLT003','Invalid is_verified_only.'); end if; end;
  end if;

  select value, updated_at into v_weights, v_weights_version from public.platform_config where key = 'service_ranking_weights';
  if not found then
    v_weights := '{"w_verify":0.28,"w_rating":0.26,"w_completion":0.16,"w_recency":0.12,"w_relevance":0.12,"w_activity":0.06,"bayesian_prior_count":5,"bayesian_prior_mean":3.0,"recency_half_life_days":30,"activity_half_life_days":14,"ts_rank_normalization":32}'::jsonb;
    v_weights_version := now();
  end if;
  v_w_verify := coalesce((v_weights->>'w_verify')::numeric, 0.28);
  v_w_rating := coalesce((v_weights->>'w_rating')::numeric, 0.26);
  v_w_completion := coalesce((v_weights->>'w_completion')::numeric, 0.16);
  v_w_recency := coalesce((v_weights->>'w_recency')::numeric, 0.12);
  v_w_relevance := coalesce((v_weights->>'w_relevance')::numeric, 0.12);
  v_w_activity := coalesce((v_weights->>'w_activity')::numeric, 0.06);
  v_prior_count := coalesce((v_weights->>'bayesian_prior_count')::numeric, 5);
  v_prior_mean := coalesce((v_weights->>'bayesian_prior_mean')::numeric, 3.0);
  v_half_recency := coalesce((v_weights->>'recency_half_life_days')::numeric, 30);
  v_half_activity := coalesce((v_weights->>'activity_half_life_days')::numeric, 14);
  v_ts_norm := coalesce((v_weights->>'ts_rank_normalization')::numeric, 32)::int;

  with
  filtered as (
    select
      sl.id, sl.entity_id, sl.profession_id, sl.industry_id, sl.slug, sl.title, sl.description,
      sl.pricing_type, sl.price_min, sl.price_max, sl.currency_code,
      sl.avg_rating, sl.review_count, sl.is_trade_verified_cache, sl.published_at, sl.created_at,
      p.slug as profession_slug, p.name as profession_name,
      i.slug as industry_slug, i.name as industry_name,
      sl.search_vector,
      e.last_seen_at as entity_last_seen, e.created_at as entity_created
    from public.service_listings sl
    join public.professions p on p.id = sl.profession_id
    join public.industries i on i.id = sl.industry_id
    left join public.entities e on e.id = sl.entity_id
    where sl.status = 'published'
      and (p_profession_id is null or sl.profession_id = p_profession_id)
      and (v_filter_profession_id is null or sl.profession_id = v_filter_profession_id)
      and (v_filter_industry_id is null or sl.industry_id = v_filter_industry_id)
      and (v_filter_price_min is null or sl.price_min is null or sl.price_min >= v_filter_price_min or coalesce(sl.price_max, sl.price_min) >= v_filter_price_min)
      and (v_filter_price_max is null or sl.price_min is null or sl.price_min <= v_filter_price_max)
      and (v_filter_currency is null or sl.currency_code = v_filter_currency)
      and (v_filter_verified_only is null or v_filter_verified_only = false or sl.is_trade_verified_cache = true)
      and (v_filter_rating_min is null or sl.avg_rating >= v_filter_rating_min)
      and (v_query_tsquery is null or sl.search_vector @@ v_query_tsquery)
  ),
  scored as (
    select
      f.*,
      coalesce(case ek.tier_code when 'tier_3' then 1.0 when 'tier_2' then 0.66 when 'tier_1' then 0.33 else 0.0 end, 0.0) as kyc_weight,
      case when f.is_trade_verified_cache then 0.15 else 0.0 end as verify_bonus,
      coalesce( (v_prior_count * v_prior_mean + coalesce(agg.avg_rating,0) * coalesce(agg.review_count,0) ) / (v_prior_count + coalesce(agg.review_count,0)::numeric), v_prior_mean) as bayesian_raw,
      coalesce(cr.completion_rate, 0.0) as completion_rate,
      case when f.published_at is null then 0.0 else exp(-ln(2) * extract(epoch from (now() - f.published_at))/86400 / nullif(v_half_recency,0)) end as recency_decay,
      case when v_query_tsquery is null then 0.0 else coalesce(ts_rank(f.search_vector, v_query_tsquery, v_ts_norm)::double precision, 0.0) end as ts_rank_val,
      exp(- extract(epoch from (now() - coalesce(f.entity_last_seen, f.entity_created, now())))/86400 / nullif(v_half_activity,0))::double precision as activity_decay
    from filtered f
    left join public.entity_kyc_levels ek on ek.entity_id = f.entity_id and ek.status = 'active'
    left join public.service_review_aggregates agg on agg.professional_entity_id = f.entity_id and agg.profession_id = f.profession_id
    left join lateral (
      select (count(*) filter (where c.status in ('completed','closed'))::float / nullif(count(*),0)::float) as completion_rate
      from public.service_contracts c
      where c.professional_entity_id = f.entity_id
    ) cr on true
  ),
  with_score as (
    select s.*,
      round((
        v_w_verify * (s.kyc_weight + s.verify_bonus)
        + v_w_rating * (least(s.bayesian_raw,5.0)/5.0)
        + v_w_completion * least(s.completion_rate,1.0)
        + v_w_recency * least(s.recency_decay,1.0)
        + v_w_relevance * least(s.ts_rank_val,1.0)
        + v_w_activity * least(s.activity_decay,1.0)
      )::numeric, 6) as score
    from scored s
  ),
  ordered as (
    select * from with_score
    where (v_cursor_score is null or v_cursor_id is null or (score, id) < (v_cursor_score, v_cursor_id))
    order by score desc, id desc
    limit p_limit + 1
  ),
  paged as (
    select * from ordered order by score desc, id desc limit p_limit
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'entity_id', p.entity_id, 'profession_id', p.profession_id, 'industry_id', p.industry_id,
      'slug', p.slug, 'title', p.title, 'description', p.description,
      'pricing_type', p.pricing_type, 'price_min', p.price_min, 'price_max', p.price_max,
      'currency_code', p.currency_code, 'avg_rating', p.avg_rating, 'review_count', p.review_count,
      'is_trade_verified_cache', p.is_trade_verified_cache, 'published_at', p.published_at,
      'created_at', p.created_at, 'profession_slug', p.profession_slug, 'profession_name', p.profession_name,
      'industry_slug', p.industry_slug, 'industry_name', p.industry_name,
      'score', p.score
    ) order by p.score desc, p.id desc), '[]'::jsonb),
    (select count(*) > p_limit from ordered),
    (select jsonb_build_object('score', p2.score, 'id', p2.id) from paged p2 order by p2.score desc, p2.id desc offset (p_limit -1) limit 1)
  into v_items, v_has_more, v_next_cursor
  from paged p;

  v_has_more := coalesce(v_has_more, false);
  if not v_has_more then
    v_next_cursor := null;
  else
    if jsonb_array_length(v_items) = 0 then
      v_has_more := false;
      v_next_cursor := null;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Ranked results retrieved.',
    'data', jsonb_build_object(
      'items', v_items,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'weights_version', v_weights_version
    )
  );
end;
$$;

comment on function public.service_ranking_search(uuid, text, jsonb, jsonb, integer) is
  'SECURITY INVOKER STABLE — deterministic ranking v1: weighted sum over kyc_tier_weight, bayesian_avg, completion_rate, recency decay, ts_rank, login_recency. anon+authenticated,service_role. RLS published-only, keyset (score,id). See migration §0 for formula.';

-- =============================================================================
-- SECTION 4: REVOKE / GRANT execute (new objects only)
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_ranking_weights_get() to anon, authenticated, service_role;
grant execute on function public.service_ranking_search(uuid, text, jsonb, jsonb, integer) to anon, authenticated, service_role;

-- Re-apply prior anon grants that were revoked via 'revoke from public' collateral where needed
-- Marketplace anon read RPCs (EP-03-01 & EP-03-03) must remain anon-capable post-revoke
grant execute on function public.service_listing_get(uuid) to anon, authenticated, service_role;
grant execute on function public.service_review_get_for_listing(uuid, integer, uuid) to anon, authenticated, service_role;

comment on function public.service_ranking_weights_get() is
  'SECURITY INVOKER STABLE. Public read of service_ranking_weights value. anon+authenticated,service_role.';
comment on function public.service_ranking_search(uuid, text, jsonb, jsonb, integer) is
  'SECURITY INVOKER STABLE — deterministic ranking v1: weighted sum over kyc_tier_weight, bayesian_avg, completion_rate, recency decay, ts_rank, login_recency. anon+authenticated,service_role. Keyset (score,id), RLS published-only. See migration §0.';

-- =============================================================================
-- SECTION 5: Realtime exclusion (guarded)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'platform_config'
  ) then
    alter publication supabase_realtime drop table public.platform_config;
  end if;
end;
$$;
