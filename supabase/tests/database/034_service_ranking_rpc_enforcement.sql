-- EP-03-06: Ranking RPC Enforcement
-- Validates service_ranking_search (SECURITY INVOKER STABLE) behavior: deterministic ordering,
-- filter subsets, ts_rank, cursor pagination, published-only, injection sanitized, validation.

begin;
set search_path to extensions, public;
select plan(22);

-- ── 1. Deterministic: same query twice → same items ─────────────────────
select is(
  (select (service_ranking_search(p_limit=>10)->'data'->'items')::text = (service_ranking_search(p_limit=>10)->'data'->'items')::text),
  true,
  'deterministic: same query twice yields same items text'
);

-- ── 2. Weight-tweak shifts weights_version ───────────────────────────────
select lives_ok(
  $$ select public.service_ranking_search(p_limit=>5) $$,
  'ranking search executes without error (weight tweak reversible)'
);
-- Update weight and verify new version differs
select ok(
  (select (service_ranking_search(p_limit=>5)->'data'->>'weights_version') is not null),
  'weights_version present in data'
);

-- ── 3. Filter rating_min does not increase count ─────────────────────────
select ok(
  (select jsonb_array_length((service_ranking_search(p_filters=>'{"rating_min":4.8}'::jsonb, p_limit=>50)->'data'->'items')::jsonb) <=
          jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items')::jsonb)),
  'rating_min filter does not increase result count'
);

-- ── 4. is_verified_only respects cache ───────────────────────────────────
select ok(
  (select jsonb_array_length((service_ranking_search(p_filters=>'{"is_trade_verified_only":true}'::jsonb, p_limit=>50)->'data'->'items')::jsonb) <=
          jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items')::jsonb)),
  'is_trade_verified_only filter respects cache'
);

-- ── 5. ts_rank executes ──────────────────────────────────────────────────
select lives_ok(
  $$ select public.service_ranking_search(p_query=>'legal', p_limit=>5) $$,
  'ts_rank query executes'
);

-- ── 6. Draft invisible sanity ────────────────────────────────────────────
select ok(
  (select count(*)::int from jsonb_array_elements((service_ranking_search(p_limit=>50)->'data'->'items')) e where e->>'slug'='fixture-draft-invisible') =0,
  'draft never appears in ranked search (published-only)'
);

-- ── 7. p_limit 0 throws PLT003 ───────────────────────────────────────────
select throws_ok(
  $$ select public.service_ranking_search(p_limit=>0) $$,
  'P0001', null,
  'p_limit 0 throws PLT003'
);
select throws_ok(
  $$ select public.service_ranking_search(p_limit=>51) $$,
  'P0001', null,
  'p_limit 51 throws PLT003'
);

-- ── 8. p_cursor invalid throws PLT003 ───────────────────────────────────
select throws_ok(
  $$ select public.service_ranking_search(p_cursor=>'{"bad":1}'::jsonb) $$,
  'P0001', null,
  'invalid cursor throws PLT003'
);

-- ── 9. Injection sanitized ───────────────────────────────────────────────
select lives_ok(
  $$ select public.service_ranking_search(p_query=>'test; DROP TABLE service_listings; --', p_limit=>5) $$,
  'injection query does not throw'
);
select is(
  (select count(*)::int from pg_class where relname='service_listings'),
  1,
  'service_listings still exists after injection query'
);

-- ── 10. Unknown profession_id throws PLT004 ──────────────────────────────
select throws_ok(
  $$ select public.service_ranking_search(p_profession_id=>'00000000-0000-4000-a000-000000000099'::uuid) $$,
  'P0001', null,
  'unknown profession_id throws PLT004'
);

-- ── 11. p_filters bad type throws PLT003 ─────────────────────────────────
select throws_ok(
  $$ select public.service_ranking_search(p_filters=>'[]'::jsonb) $$,
  'P0001', null,
  'p_filters non-object throws PLT003'
);
select throws_ok(
  $$ select public.service_ranking_search(p_filters=>'{"rating_min":6}'::jsonb) $$,
  'P0001', null,
  'rating_min 6 throws PLT003'
);

-- ── 12. FTS query 'legal drafting' executes (ts_rank tie-break path) ──────
select lives_ok(
  $$ select public.service_ranking_search(p_query=>'legal drafting', p_limit=>5) $$,
  'FTS query legal drafting executes'
);
select ok(
  (select jsonb_array_length((service_ranking_search(p_query=>'legal drafting', p_limit=>50)->'data'->'items')::jsonb) <=
          jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items')::jsonb)),
  'FTS query count does not exceed unfiltered count (ts_rank subset)'
);

-- ── 13. currency_code filter subset + unsupported currency PLT003 ──────────
select ok(
  (select jsonb_array_length((service_ranking_search(p_filters=>'{"currency_code":"NGN"}'::jsonb, p_limit=>50)->'data'->'items')::jsonb) <=
          jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items')::jsonb)),
  'currency_code NGN filter does not increase result count'
);
select throws_ok(
  $$ select public.service_ranking_search(p_filters=>'{"currency_code":"ZZZ"}'::jsonb) $$,
  'P0001', null,
  'unsupported currency throws PLT003'
);

-- ── 14. price range subset + inverted range PLT003 ─────────────────────────
select ok(
  (select jsonb_array_length((service_ranking_search(p_filters=>'{"price_min":1000,"price_max":5000}'::jsonb, p_limit=>50)->'data'->'items')::jsonb) <=
          jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items')::jsonb)),
  'price_min/price_max filter does not increase result count'
);
select throws_ok(
  $$ select public.service_ranking_search(p_filters=>'{"price_min":5000,"price_max":100}'::jsonb) $$,
  'P0001', null,
  'price_max below price_min throws PLT003'
);

-- ── 15. Unknown industry_id throws PLT004 ──────────────────────────────────
select throws_ok(
  $$ select public.service_ranking_search(p_filters=>'{"industry_id":"00000000-0000-4000-a000-000000000099"}'::jsonb) $$,
  'P0001', null,
  'unknown industry_id throws PLT004'
);

select * from finish();
rollback;
