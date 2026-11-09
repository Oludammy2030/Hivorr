-- Outbox delivery fields.
--
-- The API writes an outbox row in the same transaction as the state change.
-- The worker claims a batch with `for update skip locked`, leases it, and then
-- records success or failure. A crashed worker stops refreshing its lease, so
-- another worker can reclaim the event after `WORKER_LEASE_MS`.
--
-- A failing event is retried with exponential backoff up to a fixed attempt
-- limit, then dead-lettered. Dead letters are retained for inspection and are
-- never silently dropped.

alter table platform.outbox add column locked_at timestamptz;
alter table platform.outbox add column locked_by text;
alter table platform.outbox add column dead_lettered_at timestamptz;

comment on column platform.outbox.locked_at is
  'Lease timestamp. A claim older than the worker lease is reclaimable.';
comment on column platform.outbox.dead_lettered_at is
  'Set when the event exhausted its attempts. Retained, never deleted.';

drop index if exists platform.outbox_pending_idx;

create index outbox_claimable_idx
  on platform.outbox (available_at)
  where processed_at is null and dead_lettered_at is null;

create index outbox_dead_letter_idx
  on platform.outbox (dead_lettered_at desc)
  where dead_lettered_at is not null;

-- The worker consumes delivery state; it never produces events. Its role may
-- update the rows it claims but may not insert new ones.
revoke insert on platform.outbox from hivorr_worker;

-- Queue health is read by the worker health endpoint and by operators.
create or replace function platform.outbox_health()
returns table (
  pending bigint,
  leased bigint,
  dead_lettered bigint,
  oldest_pending_at timestamptz
)
language sql
security definer
stable
set search_path = platform, pg_temp
as $$
  select
    count(*) filter (where processed_at is null and dead_lettered_at is null),
    count(*) filter (
      where processed_at is null
        and dead_lettered_at is null
        and locked_at is not null
        and locked_at > now() - interval '5 minutes'
    ),
    count(*) filter (where dead_lettered_at is not null),
    min(occurred_at) filter (where processed_at is null and dead_lettered_at is null)
  from platform.outbox
$$;

revoke all on function platform.outbox_health() from public;
grant execute on function platform.outbox_health() to hivorr_worker, hivorr_readonly;
