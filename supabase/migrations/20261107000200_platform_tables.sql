-- Platform backbone: append-only audit, transactional outbox, idempotency,
-- feature flags, and reference counters. These tables are owned by the
-- `platform` module; other modules write to them only through a service call.

create table platform.audit_log (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  actor_type text not null check (actor_type in ('user', 'staff', 'admin', 'partner', 'developer', 'system')),
  actor_id uuid,
  actor_audience text check (actor_audience in ('app', 'control', 'staff', 'partner', 'system')),
  environment text not null check (environment in ('development', 'test', 'staging', 'production')),
  action text not null,
  target_type text,
  target_id text,
  before_summary jsonb,
  after_summary jsonb,
  ip inet,
  user_agent text,
  correlation_id text
);

comment on table platform.audit_log is
  'Append-only privileged and state-changing action record. No update or delete path.';

create index audit_log_occurred_at_idx on platform.audit_log (occurred_at desc);
create index audit_log_actor_idx on platform.audit_log (actor_id, occurred_at desc);
create index audit_log_target_idx on platform.audit_log (target_type, target_id, occurred_at desc);
create index audit_log_correlation_idx on platform.audit_log (correlation_id);

create or replace function platform.reject_append_only_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'platform.audit_log is append-only';
end;
$$;

create trigger audit_log_no_update
before update or delete on platform.audit_log
for each row execute function platform.reject_append_only_mutation();

create table platform.outbox (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id text not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  available_at timestamptz not null default now(),
  processed_at timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  last_error text
);

comment on table platform.outbox is
  'Transactional outbox. Events are written in the state-change transaction and delivered at least once.';

create index outbox_pending_idx
  on platform.outbox (available_at)
  where processed_at is null;

create table platform.idempotency_keys (
  key text primary key,
  scope text not null,
  request_hash text not null,
  response_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

comment on table platform.idempotency_keys is
  'Idempotency records for money mutations and other replay-sensitive commands.';

create index idempotency_keys_expiry_idx on platform.idempotency_keys (expires_at);

create table platform.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now()
);

comment on table platform.feature_flags is
  'Non-financial feature flags. Financial limits and rules are not stored here.';

create table platform.reference_counters (
  name text primary key,
  value bigint not null default 0 check (value >= 0),
  updated_at timestamptz not null default now()
);

comment on table platform.reference_counters is
  'Monotonic counters for human-readable reference numbers. Allocation is transactional.';
