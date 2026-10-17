-- EP-03-19 corrective migration (surfaced by the SV-02 anon SEO posture test,
-- supabase/tests/database/056_service_listing_seo_posture.sql):
-- service_ranking_search could not run as the anonymous role.
--
-- The RPC has been granted to anon since 20260927090001:540 — its body even
-- carries `current_user = 'anon'` error branches — but it was declared
-- SECURITY INVOKER while reading three tables the anonymous role has no SELECT
-- grant on:
--   * public.entities         (activity decay: last_seen_at / created_at)
--   * public.entity_kyc_levels (verification weight: tier_code)
--   * public.service_contracts (completion rate)
-- All three are revoked from anon by 20260819090001:18 and re-granted only to
-- authenticated/service_role. Every anonymous call therefore failed with:
--   ERROR: permission denied for table entity_kyc_levels
-- which broke the public marketplace list behind /services, /services/search
-- and the EP-03-19 SEO route /s/:industrySlug for logged-out visitors.
--
-- Under SECURITY INVOKER the weights were also wrong for authenticated callers:
-- the self-scoped RLS policies on entity_kyc_levels and service_contracts hide
-- every *other* entity's rows, so w_verify (0.28) and w_completion (0.16)
-- silently collapsed to 0 for all peers. The pgTAP suites run as postgres
-- (table owner → RLS bypassed), which is why the RPC "passed" while mis-ranking
-- in production.
--
-- Fix: promote to SECURITY DEFINER with a pinned search_path, mirroring the
-- public-read pattern established by portfolio_public_profile_get
-- (20260913090001_portfolio_public_profile.sql:120). This is safe because the
-- function body:
--   * hard-filters `sl.status = 'published'` — owner drafts never surface;
--   * projects only the whitelisted public listing fields via
--     jsonb_build_object — kyc tier, last_seen_at and contract completion are
--     read solely to compute ranking scores and are never returned.
-- The error contract is unchanged: public.platform_raise_error formats exactly
-- like the inline `current_user = 'anon'` raises ('PLTxxx: message',
-- detail 'PLTxxx'), so anon callers receive identical codes/messages.
--
-- No new RPC, grant or policy: the anon EXECUTE grant from
-- 20260927090001:540 is untouched. This is a documented "approved deviation"
-- of the service_% SECURITY DEFINER count, which moves 5 -> 6
-- (see the updated posture assertions in 023 and 033).

alter function public.service_ranking_search(uuid, text, jsonb, jsonb, integer)
  security definer;

alter function public.service_ranking_search(uuid, text, jsonb, jsonb, integer)
  set search_path = pg_catalog, public;

comment on function public.service_ranking_search(uuid, text, jsonb, jsonb, integer) is
  'SECURITY DEFINER (EP-03-19 corrective) STABLE. Public ranked browse for anon+authenticated over published listings only. DEFINER is required to read entity_kyc_levels/service_contracts/entities for ranking weights without leaking owner-scoped rows; projects a whitelisted public projection and never returns those inputs. search_path pinned to pg_catalog, public.';
