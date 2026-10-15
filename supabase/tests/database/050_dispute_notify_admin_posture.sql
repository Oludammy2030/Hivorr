-- R2 follow-up: notification_events push-channel posture
--
-- Validates the server-side row the EP-01-18 Realtime push receiver
-- subscribes to (`pushChannelName`, default `notification_events`):
--   - table + recipient/action columns, recipient-only RLS, anon zero grants,
--     no authenticated INSERT (the dispute_notify Edge Function writes with
--     the service-role key), Realtime INSERT delivery enabled.

begin;
set search_path to extensions, public;
select plan(14);

select has_table('public', 'notification_events', 'notification_events exists');
select has_column('public', 'notification_events', 'entity_id', 'recipient column exists');
select has_column('public', 'notification_events', 'action_route', 'deep-link column exists');

select is(
  (select relrowsecurity from pg_class
    where oid = 'public.notification_events'::regclass),
  true, 'RLS enabled on notification_events');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'notification_events'
      and grantee = 'anon'),
  0, 'anon holds zero grants');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'notification_events'
      and grantee = 'authenticated' and privilege_type = 'INSERT'),
  0, 'authenticated cannot INSERT (function writes service-side)');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'notification_events'
      and grantee = 'service_role' and privilege_type = 'INSERT'),
  1, 'service_role holds INSERT for the Edge Function');

select is(
  (select count(*)::int from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'notification_events'),
  1, 'notification_events published for Realtime INSERT delivery');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'notification_events'
      and policyname = 'notification_events_select'),
  1, 'recipient SELECT policy exists');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'notification_events'
      and policyname = 'notification_events_update'),
  1, 'recipient UPDATE (read_at) policy exists');

select has_function('public', 'service_dispute_admin_list', array['text', 'int', 'int'],
  'service_dispute_admin_list exists');
select has_function('public', 'service_dispute_admin_get', array['uuid'],
  'service_dispute_admin_get exists');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('service_dispute_admin_list', 'service_dispute_admin_get')
      and p.prosecdef),
  2, 'both admin RPCs are SECURITY DEFINER (pinned search_path)');

select is(
  (select count(*)::int from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('service_dispute_admin_list', 'service_dispute_admin_get')
      and grantee = 'anon'),
  0, 'anon holds zero EXECUTE on the admin RPCs');

select finish();
rollback;
