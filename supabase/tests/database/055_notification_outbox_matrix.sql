-- EP-03-18: notification outbox behavior matrix
--
-- Exercises the durable fan-out end to end (rollback-safe):
--   - notification_enqueue validation + exactly-once dedup
--   - authenticated direct INSERT blocked; claim/ack service_role-only
--   - representative trigger firings across the matrix (listing, contract
--     offer/accept/cancel, message, appointment, milestone complete/verify,
--     review submit/reveal, milestone+earnings release)
--   - PII-safe bodies, allowlisted channels/routes
--   - dispute_notify untouched (direct path preserved)

begin;
set search_path to extensions, public;
select plan(53);

-- ─── 0. Fixtures ────────────────────────────────────────────────────────────
set role postgres;
select set_config('test.a', 'a1111111-1111-4111-8111-111111111111', true);
select set_config('test.b', 'b2222222-2222-4222-8222-222222222222', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'notify-a@example.com'),
       (current_setting('test.b')::uuid, 'notify-b@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active')
on conflict (id) do nothing;

select set_config('test.prof1',
  coalesce(
    (select id::text from public.professions where slug = 'legal-consultant'),
    (select id::text from public.professions limit 1)
  ), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- ─── 1. notification_enqueue validation ─────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select throws_ok(
  $$ select public.notification_enqueue('k1', '00000000-0000-0000-0000-000000000000'::uuid, 'contract_offered', 't', 'b') $$,
  '42501', null, 'anon enqueue blocked (no EXECUTE grant)');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok(
  $$ select public.notification_enqueue('k-bad-event', current_setting('test.a')::uuid, 'nope', 't', 'b') $$,
  'P0001', 'PLT003: Invalid event type.', 'invalid event type rejected');
select throws_ok(
  $$ select public.notification_enqueue('k-bad-route', current_setting('test.a')::uuid, 'contract_offered', 't', 'b', 'hivorr_contracts', 'normal', 'https://evil.example/x') $$,
  'P0001', 'PLT003: Invalid action route.', 'non-allowlisted action route rejected');
select throws_ok(
  $$ select public.notification_enqueue('k-bad-recipient', '00000000-0000-0000-0000-000000000000'::uuid, 'contract_offered', 't', 'b') $$,
  'P0001', 'PLT004: Recipient not found.', 'unknown recipient rejected');

-- ─── 2. Exactly-once dedup ──────────────────────────────────────────────────
select is(
  ((select public.notification_enqueue(
    'matrix-dedup-1', current_setting('test.a')::uuid, 'contract_offered',
    'New contract offer', 'Contract ***1111 is awaiting your review.',
    'hivorr_contracts', 'normal', '/contracts/00000000-0000-0000-0000-000000000001',
    '{}'::jsonb
  ))->'data'->>'enqueued')::boolean,
  true, 'first enqueue accepted');
select is(
  ((select public.notification_enqueue(
    'matrix-dedup-1', current_setting('test.a')::uuid, 'contract_offered',
    'New contract offer', 'Contract ***1111 is awaiting your review.',
    'hivorr_contracts', 'normal', '/contracts/00000000-0000-0000-0000-000000000001',
    '{}'::jsonb
  ))->'data'->>'enqueued')::boolean,
  false, 'duplicate dedup_key is a no-op');
select is(
  (select count(*)::int from public.notification_outbox where dedup_key = 'matrix-dedup-1'),
  1, 'single row for duplicate dedup_key');
select throws_ok(
  $$ select public.notification_enqueue('k-pii', current_setting('test.a')::uuid, 'contract_offered', 'New offer', 'Mail me at joe@example.com please', 'hivorr_contracts', 'normal', '/contracts/x', '{}'::jsonb) $$,
  'P0001', 'PLT003: Title/body must not contain contact details.', 'contact-details PII in body rejected');
select throws_ok(
  $$ select public.notification_enqueue('k-nonparty', current_setting('test.a')::uuid, 'contract_offered', 'New contract offer', 'Contract ***0001 is awaiting review.', 'hivorr_contracts', 'normal', '/contracts/00000000-0000-0000-0000-000000000001', '{"contractId":"00000000-0000-0000-0000-000000000001","event":"contract_offered"}'::jsonb) $$,
  'P0001', 'PLT004: Recipient not found.', 'non-party enqueue for unknown contract rejected (no oracle)');

-- ─── 3. Direct writes + claim/ack guards ────────────────────────────────────
select throws_ok(
  $$ insert into public.notification_outbox (dedup_key, recipient_entity_id, event_type, title, body) values ('direct-1', current_setting('test.a')::uuid, 'contract_offered', 't', 'b') $$,
  '42501', null, 'authenticated direct INSERT blocked (no grant)');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok(
  $$ select public.notification_claim_batch(5) $$,
  '42501', null, 'claim_batch rejects non-service_role (no EXECUTE grant)');
select throws_ok(
  $$ select public.notification_ack('00000000-0000-0000-0000-000000000000'::uuid, true) $$,
  '42501', null, 'ack rejects non-service_role (no EXECUTE grant)');

-- ─── 4. listing_published (owner self-confirm) ──────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.l1', (select (public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Matrix Listing Fixture Title',
  'Matrix listing description that is definitely longer than fifty characters for notify testing.',
  'fixed', 5000, 10000)->'data'->>'id')), true);
select set_config('test.l1_pub', (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'), true);

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'listing_published'
      and recipient_entity_id = current_setting('test.a')::uuid
      and payload->>'listingId' = current_setting('test.l1')),
  1, 'listing_published fired for owner');
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'listing_published'
      and payload ? 'listingId' and (payload->>'listingId') <> ''),
  1, 'listing payload carries listingId');

-- ─── 5. contract offer/accept ───────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.c1', (select (public.service_contract_offer(
  current_setting('test.l1')::uuid, 5000, 'NGN',
  '[{"milestone_number":1,"title":"Phase one delivery","amount":5000}]'::jsonb
)->'data'->'contract'->>'id')), true);

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'contract_offered'
      and recipient_entity_id = current_setting('test.a')::uuid
      and payload->>'contractId' = current_setting('test.c1')),
  1, 'contract_offered fired for professional');
select is(
  (select action_route from public.notification_outbox
    where event_type = 'contract_offered'
      and payload->>'contractId' = current_setting('test.c1')
    limit 1),
  '/contracts/' || current_setting('test.c1'), 'offer route is canonical');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_contract_accept(current_setting('test.c1')::uuid) $$,
  'accept c1 as professional');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'contract_accepted'
      and recipient_entity_id = current_setting('test.b')::uuid
      and payload->>'contractId' = current_setting('test.c1')),
  1, 'contract_accepted fired for client');

-- ─── 6. message_received (counterparty only, generic body) ─────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.conv', (select (public.conversation_ensure_for_contract(
  current_setting('test.c1')::uuid)->'data'->'conversation'->>'id')), true);
select lives_ok(
  $$ select public.message_send(
    current_setting('test.conv')::uuid,
    '{"c":"QUJDREVGR0hJSktMTU5PUA==","i":"QUJDREVGR0hJ","t":"QUJDREVGR0hJSktMTU5PUA=="}',
    'Hello preview') $$,
  'message sent as professional');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'message_received'
      and recipient_entity_id = current_setting('test.b')::uuid),
  1, 'message_received fired counterparty-only');
select is(
  (select body from public.notification_outbox
    where event_type = 'message_received'
      and recipient_entity_id = current_setting('test.b')::uuid
    limit 1) like 'Contract ***% has a new message.',
  true, 'message body is generic (no ciphertext/preview)');

-- ─── 7. appointment_booked (counterparty of booker) ─────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.appt1', (select (public.appointment_book(
  current_setting('test.c1')::uuid, null,
  now() + interval '2 days', now() + interval '2 days' + interval '1 hour'
)->'data'->>'id')), true);

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'appointment_booked'
      and recipient_entity_id = current_setting('test.a')::uuid
      and payload->>'contractId' = current_setting('test.c1')),
  1, 'appointment_booked fired for professional');

-- Reschedule appt1 (fires rescheduled for old + booked for the new row).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.appt2', (select (public.appointment_reschedule(
  current_setting('test.appt1')::uuid,
  now() + interval '3 days', now() + interval '3 days' + interval '1 hour'
)->'data'->'new_appointment'->>'id')), true);

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'appointment_rescheduled'
      and recipient_entity_id = current_setting('test.a')::uuid
      and payload->>'contractId' = current_setting('test.c1')),
  1, 'appointment_rescheduled fired for professional');

-- Cancel the rescheduled appointment (fires cancelled for counterparty).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.appointment_cancel(current_setting('test.appt2')::uuid, 'Running late') $$,
  'appointment cancelled as client');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'appointment_cancelled'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'appointment_cancelled fired for professional');

-- ─── 8. milestone complete/verify ───────────────────────────────────────────
select set_config('test.m1', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.c1')::uuid limit 1), true);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid) $$,
  'milestone completed as professional');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'milestone_completed'
      and recipient_entity_id = current_setting('test.b')::uuid),
  1, 'milestone_completed fired for client');

-- Revision round-trip on the same milestone (completed -> pending).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid, 'revision_requested') $$,
  'revision requested as client');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'milestone_revision_requested'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'milestone_revision_requested fired for professional');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid) $$,
  'milestone re-completed as professional');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'milestone_completed'
      and recipient_entity_id = current_setting('test.b')::uuid),
  2, 're-completion fires a second milestone_completed (dedup per event)');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid, 'verified') $$,
  'milestone verified as client');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'milestone_verified'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'milestone_verified fired for professional');

-- ─── 9. review submit/reveal ────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'Excellent delivery with clear communication throughout.') $$,
  'review submitted as client');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'review_submitted'
      and recipient_entity_id = current_setting('test.b')::uuid),
  1, 'review_submitted self-confirm for reviewer');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok(
  $$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'Great client with prompt feedback and fair expectations.') $$,
  'review submitted as professional');

set role postgres;
select set_config('test.reveal', (select public.service_review_reveal_if_ready(
  current_setting('test.c1')::uuid)->>'code'), true);
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'review_revealed'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'review_revealed fired for professional');
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'review_revealed'
      and recipient_entity_id = current_setting('test.b')::uuid),
  1, 'review_revealed fired for client');

-- ─── 10. milestone+earnings release (simulated settlement flip) ─────────────
set role postgres;
update public.contract_milestones set status = 'released', released_at = now()
 where id = current_setting('test.m1')::uuid and status <> 'released';
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'milestone_released'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'milestone_released fired for professional');
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'earnings_released'
      and recipient_entity_id = current_setting('test.a')::uuid),
  1, 'earnings_released fired for professional');
select is(
  (select action_route from public.notification_outbox
    where event_type = 'earnings_released'
    limit 1),
  '/finance/earnings', 'earnings route is canonical');

-- ─── 11. second contract cancelled ──────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.c2', (select (public.service_contract_offer(
  current_setting('test.l1')::uuid, 2000, 'NGN',
  '[{"milestone_number":1,"title":"Scope review call","amount":2000}]'::jsonb
)->'data'->'contract'->>'id')), true);
select lives_ok(
  $$ select public.service_contract_cancel(current_setting('test.c2')::uuid, 'Changed my mind') $$,
  'second contract cancelled as client');

set role postgres;
select is(
  (select count(*)::int from public.notification_outbox
    where event_type = 'contract_cancelled'
      and recipient_entity_id = current_setting('test.a')::uuid
      and payload->>'contractId' = current_setting('test.c2')),
  1, 'contract_cancelled fired for professional');

-- ─── 12. hygiene: lengths, PII, channels, routes ───────────────────────────
select is(
  (select count(*)::int from public.notification_outbox
    where char_length(btrim(title)) not between 1 and 120
       or char_length(btrim(body)) not between 1 and 500),
  0, 'all titles/bodies within length bounds');
select is(
  (select count(*)::int from public.notification_outbox
    where title like '%@%' or body like '%@%'),
  0, 'no email-shaped PII in titles/bodies');
select is(
  (select count(*)::int from public.notification_outbox
    where channel_id !~ '^[a-zA-Z0-9_]+$'),
  0, 'all channels use safe ids');
select is(
  (select count(*)::int from public.notification_outbox
    where action_route is not null
      and action_route !~ '^/(contracts|dashboard|appointments|support|finance|services|s|p)(/|$|\\?)'),
  0, 'all action routes allowlisted');

-- ─── 13. claim/ack drain (service_role) ─────────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select ok(
  ((select public.notification_claim_batch(5))->>'success')::boolean,
  'claim_batch succeeds as service_role');
select set_config('test.ack_id', (select id::text from public.notification_outbox
  where status = 'leased' limit 1), true);
select ok(
  ((select public.notification_ack(current_setting('test.ack_id')::uuid, true))->>'success')::boolean,
  'ack sent succeeds as service_role');

set role postgres;
select is(
  (select status from public.notification_outbox where id = current_setting('test.ack_id')::uuid),
  'sent', 'acked row marked sent');

-- Crashed-lease recovery: backdate a leased row past its 5-minute lease,
-- then prove the next sweep re-leases it (never stranded).
select set_config('test.stale', (select id::text from public.notification_outbox
  where status = 'leased' limit 1), true);
update public.notification_outbox set next_retry_at = now() - interval '1 minute'
 where id = current_setting('test.stale')::uuid;
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok(
  $$ select public.notification_claim_batch(5) $$,
  're-claim sweep runs as service_role');
set role postgres;
select is(
  (select attempts from public.notification_outbox where id = current_setting('test.stale')::uuid),
  2, 'expired lease re-leased (attempts incremented, never stranded)');

-- ─── 14. dispute path untouched ─────────────────────────────────────────────
-- dispute_notify is an Edge Function (supabase/functions/dispute_notify),
-- not a DB function: assert no DB function shadows it so the direct
-- counterparty path stays exactly as approved (no outbox duplicate).
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'dispute_notify'),
  0, 'dispute_notify is an Edge Function (not a DB function); direct path preserved');

select finish();
rollback;
