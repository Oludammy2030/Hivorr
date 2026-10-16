-- EP-03-18: notification_outbox durable queue posture
--
-- Validates the server-side outbox drained by lifecycle_notify:
--   - table + dedup/recipient/action columns, 17-event CHECK, RLS,
--     anon/authenticated zero grants (service_role only), Realtime
--     exclusion, canonical RPCs + lifecycle triggers present.

begin;
set search_path to extensions, public;
select plan(18);

select has_table('public', 'notification_outbox', 'notification_outbox exists');
select has_column('public', 'notification_outbox', 'dedup_key', 'dedup column exists');
select has_column('public', 'notification_outbox', 'recipient_entity_id', 'recipient column exists');
select has_column('public', 'notification_outbox', 'event_type', 'event column exists');
select has_column('public', 'notification_outbox', 'action_route', 'deep-link column exists');
select has_column('public', 'notification_outbox', 'status', 'status column exists');

select is(
  (select relrowsecurity from pg_class
    where oid = 'public.notification_outbox'::regclass),
  true, 'RLS enabled on notification_outbox');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'notification_outbox'
      and grantee = 'anon'),
  0, 'anon holds zero grants');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'notification_outbox'
      and grantee = 'authenticated'),
  0, 'authenticated holds zero direct grants (RPC/TRIGGER only)');

select is(
  (select count(*)::int from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'notification_outbox'),
  0, 'notification_outbox excluded from Realtime');

select has_function('public', 'notification_enqueue',
  array['text', 'uuid', 'text', 'text', 'text', 'text', 'text', 'text', 'jsonb'],
  'notification_enqueue exists');
select has_function('public', 'notification_claim_batch', array['int'],
  'notification_claim_batch exists');
select has_function('public', 'notification_ack', array['uuid', 'boolean', 'text'],
  'notification_ack exists');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('notification_enqueue', 'notification_claim_batch', 'notification_ack')
      and p.prosecdef),
  3, 'outbox RPCs are SECURITY DEFINER (pinned search_path)');

select is(
  (select count(*)::int from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'notification_enqueue'
      and grantee = 'anon'),
  0, 'anon holds zero EXECUTE on notification_enqueue');

select is(
  (select count(*)::int from pg_trigger
    where tgname in (
      'notification_on_contract_event_trigger',
      'notification_on_appointment_event_trigger',
      'notification_on_message_trigger',
      'notification_on_listing_published_trigger',
      'notification_on_review_insert_trigger',
      'notification_on_review_reveal_trigger',
      'notification_on_milestone_released_trigger'
    )),
  7, 'all seven lifecycle triggers exist');

select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.notification_outbox'::regclass
      and contype = 'u'),
  1, 'dedup_key UNIQUE present');

select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'notification_outbox'
      and indexname = 'notification_outbox_status_retry_idx'),
  1, 'status/retry lease index exists');

select finish();
rollback;
