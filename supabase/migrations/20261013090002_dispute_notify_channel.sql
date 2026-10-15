-- =============================================================================
-- R2 (EP-03-17 follow-up): notification_events push channel + Realtime wiring
-- -----------------------------------------------------------------------------
-- Migration: 20261013090002_dispute_notify_channel.sql
-- Depends on: 20260821090002_entity_core_tables.sql (entities)
--
-- PURPOSE
--   Provide the server-side row the EP-01-18 Realtime push receiver already
--   subscribes to (`pushChannelName`, default `notification_events`):
--   `SupabasePushRealtimeGateway` listens for INSERTs on
--   `public.<pushChannelName>` filtered by `entity_id`, so a row inserted for
--   the counterparty wakes their device with a locally-rendered notification.
--   The `dispute_notify` Edge Function (supabase/functions/dispute_notify) is
--   the sole writer, using the service-role key; end users never insert here.
--
-- EXECUTION MODEL
--   - No RPCs, no DEFINER functions, no triggers in this migration.
--   - RLS default-deny: recipient-only SELECT/UPDATE(read_at); writes are
--     service_role-only (RLS bypass + explicit INSERT grant).
--   - Realtime: ADD TABLE to supabase_realtime (INSERT delivery for the
--     postgres_changes subscriber), guarded + idempotent.
-- =============================================================================

create table if not exists public.notification_events (
  id                      bigint generated always as identity primary key,
  entity_id               uuid not null
                          references public.entities(id) on delete cascade,
  title                   text not null
                          check (char_length(btrim(title)) between 1 and 120),
  body                    text not null
                          check (char_length(btrim(body)) between 1 and 500),
  channel_id              text not null default 'hivorr_default',
  priority                text not null default 'normal'
                          check (priority in ('low', 'normal', 'high', 'urgent')),
  action_route            text,
  payload                 jsonb not null default '{}'::jsonb,
  read_at                 timestamptz,
  created_at              timestamptz not null default now()
);

comment on table public.notification_events is
  'Push-channel rows for the Realtime postgres_changes subscriber (EP-01-18 pushChannelName, default notification_events). Written service-side only (dispute_notify Edge Function); rendered locally on the recipient device.';

create index if not exists notification_events_entity_idx
  on public.notification_events (entity_id, created_at desc)
  where read_at is null;

alter table public.notification_events enable row level security;

revoke all on public.notification_events from anon, authenticated, service_role;

grant select on public.notification_events to authenticated;
grant select, insert, update on public.notification_events to service_role;

drop policy if exists notification_events_select on public.notification_events;
create policy notification_events_select
  on public.notification_events for select to authenticated
  using (entity_id = auth.uid());

drop policy if exists notification_events_update on public.notification_events;
create policy notification_events_update
  on public.notification_events for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());

-- Realtime INSERT delivery for the push subscriber (mirrors the messages
-- ADD pattern in 20260925090001:602-607).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notification_events'
  ) then
    alter publication supabase_realtime add table public.notification_events;
  end if;
end;
$$;
