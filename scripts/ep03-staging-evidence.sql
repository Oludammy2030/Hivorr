-- EP-03-20 Staging Evidence SQL (operator tooling — READ-ONLY)
--
-- Captures the DB-side evidence for the EP-03-20 verification report:
-- §10 phase-completion counts, MT-02 ranking-weight provenance, AT-03 object
-- presence (RPCs), and the §10:238 RLS default-deny matrix.
--
-- Usage (staging, read-only role is enough for every query below):
--   psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f scripts/ep03-staging-evidence.sql
-- Or via the Supabase SQL editor (paste whole file; all statements SELECT).
--
-- This file contains ONLY SELECT statements against catalogues and tables;
-- it never writes, never migrates, never grants. Output is intended to be
-- pasted verbatim into the EP-03-20 verification report as evidence.

\set ON_ERROR_STOP on

SELECT 'ep03-staging-evidence' AS label, now() AS captured_at,
       current_database() AS database;

-- ---------------------------------------------------------------------------
-- §10:219  Service marketplace posture (listings by lifecycle state)
-- ---------------------------------------------------------------------------
SELECT 'listing_status_counts' AS metric, status, count(*) AS n
FROM public.service_listings
GROUP BY status
ORDER BY status;

SELECT 'listing_media_count' AS metric, count(*) AS n
FROM public.service_listing_media;

SELECT 'listing_favorites_count' AS metric, count(*) AS n
FROM public.service_favorites;

-- ---------------------------------------------------------------------------
-- §10:220  Contract + milestone state machine + escrow linkage
-- ---------------------------------------------------------------------------
SELECT 'contract_status_counts' AS metric, status, count(*) AS n
FROM public.service_contracts
GROUP BY status
ORDER BY status;

SELECT 'milestone_status_counts' AS metric, status, count(*) AS n,
       count(*) FILTER (WHERE escrow_milestone_id IS NOT NULL) AS escrow_linked
FROM public.contract_milestones
GROUP BY status
ORDER BY status;

SELECT 'contract_event_count' AS metric, count(*) AS n
FROM public.contract_events;

-- ---------------------------------------------------------------------------
-- §10:221  Double-blind review invariant (is_revealed)
-- ---------------------------------------------------------------------------
SELECT 'review_reveal_counts' AS metric,
       is_revealed, count(*) AS n
FROM public.service_reviews
GROUP BY is_revealed
ORDER BY is_revealed;

-- An unrevealed row must never expose its rating to the listing page; the
-- aggregate rows must equal the revealed review count.
SELECT 'review_aggregate_rows' AS metric, count(*) AS n
FROM public.service_review_aggregates;

-- ---------------------------------------------------------------------------
-- §10:222  Messaging (rows + Realtime publication — participant vs anon)
-- ---------------------------------------------------------------------------
SELECT 'messaging_counts' AS metric,
       (SELECT count(*) FROM public.conversations) AS conversations,
       (SELECT count(*) FROM public.conversation_participants) AS participants,
       (SELECT count(*) FROM public.messages) AS messages;

SELECT 'messaging_realtime_publication' AS metric, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('conversations', 'conversation_participants', 'messages')
ORDER BY tablename;

-- ---------------------------------------------------------------------------
-- §10:223  Scheduling posture (availability + appointments)
-- ---------------------------------------------------------------------------
SELECT 'scheduling_counts' AS metric,
       (SELECT count(*) FROM public.availability_slots) AS slots,
       (SELECT count(*) FROM public.appointments) AS appointments,
       (SELECT count(*) FROM public.appointment_events) AS appointment_events;

SELECT 'appointment_status_counts' AS metric, status, count(*) AS n
FROM public.appointments
GROUP BY status
ORDER BY status;

-- ---------------------------------------------------------------------------
-- §10:224  service-listing-media bucket provisioned with RLS
-- ---------------------------------------------------------------------------
SELECT 'storage_bucket' AS metric, id, public, created_at
FROM storage.buckets
WHERE id IN ('service-listing-media', 'portfolio-items')
ORDER BY id;

-- ---------------------------------------------------------------------------
-- MT-02  Ranking provenance: weights live in platform_config (server-side)
-- and the ranking/search RPCs exist (client never re-sorts — scan-backed).
-- ---------------------------------------------------------------------------
SELECT 'ranking_weights_provenance' AS metric, key, updated_at
FROM public.platform_config
WHERE key = 'service_ranking_weights';

SELECT 'ranking_search_rpcs' AS metric, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'service_ranking_search',
    'service_listing_create',
    'service_listing_update',
    'service_listing_publish',
    'service_listing_unpublish',
    'service_contract_offer',
    'service_contract_accept',
    'service_review_submit',
    'service_review_reveal_if_ready',
    'message_send',
    'appointment_book',
    'dispute_file',
    'dispute_resolve',
    'service_earnings_summary',
    'service_transaction_history'
  )
ORDER BY p.proname;

-- §10:226  FTS discovery: search_vector GIN index on service_listings.
SELECT 'fts_gin_index' AS metric, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'service_listings'
  AND indexdef ILIKE '%search_vector%';

-- ---------------------------------------------------------------------------
-- §10:235  Service-engagement disputes (freeze / resolve)
-- ---------------------------------------------------------------------------
SELECT 'dispute_status_counts' AS metric, status, count(*) AS n
FROM public.dispute_cases
GROUP BY status
ORDER BY status;

SELECT 'dispute_resolution_counts' AS metric, resolution_type, count(*) AS n
FROM public.dispute_resolutions
GROUP BY resolution_type
ORDER BY resolution_type;

-- ---------------------------------------------------------------------------
-- MT-04 aid  Notification outbox drain posture (live 054/055 evidence is a
-- separate CI/Supabase CLI run; this is the row-count snapshot).
-- ---------------------------------------------------------------------------
SELECT 'notification_outbox_counts' AS metric, status, count(*) AS n
FROM public.notification_outbox
GROUP BY status
ORDER BY status;

SELECT 'notification_events_count' AS metric, count(*) AS n
FROM public.notification_events;

-- ---------------------------------------------------------------------------
-- §10:238  RLS default-deny matrix: every EP-03 table must have RLS
-- ENABLED and at least one policy (fail-closed: enabled + 0 policies and
-- not enabled are both red flags for the report).
-- ---------------------------------------------------------------------------
SELECT 'rls_enablement' AS metric, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'service_listings', 'service_listing_media', 'service_favorites',
    'service_contracts', 'contract_milestones', 'contract_events',
    'service_reviews', 'service_review_aggregates',
    'conversations', 'conversation_participants', 'messages',
    'availability_slots', 'appointments', 'appointment_events',
    'dispute_cases', 'dispute_evidence', 'dispute_resolutions',
    'dispute_audit_trail'
  )
ORDER BY rowsecurity, tablename;

SELECT 'rls_policy_matrix' AS metric, tablename, count(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'service_listings', 'service_listing_media', 'service_favorites',
    'service_contracts', 'contract_milestones', 'contract_events',
    'service_reviews', 'service_review_aggregates',
    'conversations', 'conversation_participants', 'messages',
    'availability_slots', 'appointments', 'appointment_events',
    'dispute_cases', 'dispute_evidence', 'dispute_resolutions',
    'dispute_audit_trail'
  )
GROUP BY tablename
ORDER BY tablename;

-- ---------------------------------------------------------------------------
-- §10:238 / SV-02  Explicit identity probes (anon + authenticated member).
--
--   RLS only applies to non-owner roles, and operators normally connect as
--   the (superuser) owner — which bypasses RLS entirely. These probes
--   therefore SET LOCAL ROLE to the real `anon` / `authenticated` roles,
--   inside transaction-local scopes, so the policies are actually enforced.
--
--   Expected outcomes: 0 rows wherever the policy filters (anon cannot see
--   unpublished listings; non-participants cannot see messages/contracts)
--   and, where a grant is default-deny, a permission error. Both are PASS
--   evidence. Errors in this final section are captured as evidence and
--   never mask the catalog sections above (ON_ERROR_STOP is relaxed here
--   only), and every probe is rolled back.
-- ---------------------------------------------------------------------------
\echo '--- identity probes (anon / authenticated; expect 0 rows for denied scopes) ---'
\set ON_ERROR_STOP off

-- Probe 1: anon CAN read published listings (public discovery must work).
begin;
  set local role anon;
  set local request.jwt.claims to '{"role":"anon","sub":null}';
  select 'probe_anon_published_listings' as metric,
         'expect > 0 where published listings exist' as expectation,
         count(*) as rows_visible
  from public.service_listings
  where status = 'published';
rollback;

-- Probe 2: anon CANNOT read non-published listings (draft lifecycle is private).
begin;
  set local role anon;
  set local request.jwt.claims to '{"role":"anon","sub":null}';
  select 'probe_anon_unpublished_listings' as metric,
         'expect 0' as expectation,
         count(*) as rows_visible
  from public.service_listings
  where status <> 'published';
rollback;

-- Probe 3: anon CANNOT read messages.
begin;
  set local role anon;
  set local request.jwt.claims to '{"role":"anon","sub":null}';
  select 'probe_anon_messages' as metric,
         'expect 0 or permission denied' as expectation,
         count(*) as rows_visible
  from public.messages;
rollback;

-- Probe 4: an authenticated NON-participant CANNOT read conversations/messages.
begin;
  set local role authenticated;
  set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-0000-0000-00000000dead"}';
  select 'probe_member_nonparticipant_messages' as metric,
         'expect 0 (not a participant)' as expectation,
         count(*) as rows_visible
  from public.messages;
rollback;

-- Probe 5: an authenticated NON-participant CANNOT read service contracts.
begin;
  set local role authenticated;
  set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-0000-0000-00000000dead"}';
  select 'probe_member_nonparticipant_contracts' as metric,
         'expect 0 (not a party)' as expectation,
         count(*) as rows_visible
  from public.service_contracts;
rollback;

-- Probe 6: an authenticated NON-owner CANNOT read private dispute evidence.
begin;
  set local role authenticated;
  set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-0000-0000-00000000dead"}';
  select 'probe_member_nonparty_dispute_evidence' as metric,
         'expect 0 (not a party)' as expectation,
         count(*) as rows_visible
  from public.dispute_evidence;
rollback;

\set ON_ERROR_STOP on

-- End of read-only evidence capture.
SELECT 'ep03-staging-evidence-end' AS label, now() AS captured_at;
