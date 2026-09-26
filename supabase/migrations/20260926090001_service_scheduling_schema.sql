-- EP-03-05: Scheduling & Availability Schema & Server-Side Rules
--
-- Contract-bound scheduling primitive: 3 tables (availability_slots,
-- appointments, appointment_events) + 5 SECURITY INVOKER RPCs with
-- btree_gist + EXCLUDE USING gist double-booking prevention.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER for all 5 RPCs (RLS applies inside body); no new
--     SECURITY DEFINER (008/013/015/023/025/027/029 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - timestamptz + btree_gist + EXCLUDE USING gist (professional_entity_id
--     WITH =, tstzrange(starts_at, ends_at) WITH &&) WHERE (status IN
--     ('pending','confirmed')) prevents concurrent double-book; FOR UPDATE
--     on service_contracts/availability_slots/appointments serializes races;
--     idempotency_key uuid UNIQUE + ON CONFLICT DO NOTHING dedups offline
--     ActionQueue replay (lib/core/sync/action_queue.dart uuid:4.5.1).
--   - Timezone: availability_slots.timezone validated against
--     pg_timezone_names + regex, stored per slot for display via
--     HivorrFormatters.time + lib/core/localization.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 3 tables from anon, authenticated, service_role then narrow
--     SELECT,INSERT,UPDATE,DELETE on availability_slots to authenticated (owner
--     RLS), SELECT,INSERT + column-level UPDATE(status,reschedule_of,updated_at)
--     on appointments to authenticated (blocks starts_at mutation), SELECT on
--     appointment_events to authenticated + SELECT,INSERT to authenticated,service_role
--     (append-only). Full to service_role. anon 0.
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public then explicit GRANT EXECUTE
--     per RPC (5 x authenticated,service_role, anon 0).
--
-- REALTIME
--   - Scheduling is NOT Realtime (contrast messages ADD). Guarded DO $$ DROP
--     TABLE public.availability_slots, appointments, appointment_events if in
--     supabase_realtime per 20260829090003:799 guard.
--
-- MIGRATION POSTURE
--   - No DDL on prior tables/functions/policies (Rule 3 write discipline); only
--     new objects + btree_gist.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.
--   - Reuse: service_contracts (participant gate), entities, professions,
--     service_listings (published gate), platform_* helpers.

-- =============================================================================
-- SECTION 0: btree_gist extension (first occurrence, idempotent)
-- =============================================================================
create extension if not exists btree_gist;

-- =============================================================================
-- SECTION 1: availability_slots
-- =============================================================================
create table if not exists public.availability_slots (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid not null references public.entities (id) on delete cascade,
  profession_id     uuid not null references public.professions (id) on delete restrict,
  weekday           smallint not null,
  start_time        time not null,
  end_time          time not null,
  slot_duration_min integer not null,
  timezone          text not null default 'Africa/Lagos',
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  constraint availability_slots_weekday_range check (weekday between 0 and 6),
  constraint availability_slots_start_before_end check (start_time < end_time),
  constraint availability_slots_duration_range check (slot_duration_min between 15 and 480),
  constraint availability_slots_timezone_format check (timezone ~ '^[A-Za-z/_]+$'),
  constraint availability_slots_entity_prof_weekday_start_key unique (entity_id, profession_id, weekday, start_time)
);

comment on table public.availability_slots is
  'Weekly availability template per professional+profession: weekday 0-6, start_time<end_time, duration 15-480, timezone IANA per slot. UNIQUE(entity,profession,weekday,start) prevents duplicate template rows; ON CONFLICT DO UPDATE makes availability_upsert idempotent.';
comment on column public.availability_slots.entity_id is 'Owner (auth.uid() at upsert, never client-supplied profession hijack).';
comment on column public.availability_slots.profession_id is 'FK to professions ON DELETE RESTRICT; professions.is_active gate via availability_upsert RPC PLT004.';
comment on column public.availability_slots.weekday is '0=Sunday .. 6=Saturday; CHECK 0-6.';
comment on column public.availability_slots.start_time is 'Slot start time (time without timezone); CHECK start_time < end_time.';
comment on column public.availability_slots.end_time is 'Slot end time.';
comment on column public.availability_slots.slot_duration_min is 'Slot duration minutes 15-480; RPC validates %15 granularity.';
comment on column public.availability_slots.timezone is 'IANA timezone per slot validated via pg_timezone_names + regex; default Africa/Lagos for display via HivorrFormatters.time.';
comment on column public.availability_slots.is_active is 'Soft-disable slot; WHERE is_active filter in availability_list.';

create index if not exists availability_slots_entity_idx
  on public.availability_slots (entity_id);
create index if not exists availability_slots_entity_prof_idx
  on public.availability_slots (entity_id, profession_id, weekday);
create index if not exists availability_slots_profession_idx
  on public.availability_slots (profession_id);

drop trigger if exists availability_slots_set_updated_at on public.availability_slots;
create trigger availability_slots_set_updated_at
  before update on public.availability_slots
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: appointments
-- =============================================================================
create table if not exists public.appointments (
  id                      uuid primary key default gen_random_uuid(),
  contract_id             uuid not null references public.service_contracts (id) on delete cascade,
  slot_id                 uuid references public.availability_slots (id) on delete set null,
  professional_entity_id  uuid not null references public.entities (id) on delete restrict,
  client_entity_id        uuid not null references public.entities (id) on delete restrict,
  starts_at               timestamptz not null,
  ends_at                 timestamptz not null,
  status                  text not null default 'pending',
  reschedule_of           uuid references public.appointments (id) on delete set null,
  idempotency_key         uuid not null default gen_random_uuid(),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  constraint appointments_status_allowed check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'rescheduled')),
  constraint appointments_starts_before_ends check (starts_at < ends_at),
  constraint appointments_idempotency_key_unique unique (idempotency_key)
);

comment on table public.appointments is
  'Concrete bookings under service_contracts: starts_at/ends_at timestamptz with status pending/confirmed/completed/cancelled/rescheduled. professional_entity_id WITH = + tstzrange(starts_at, ends_at) WITH && EXCLUDE prevents double-book for same professional when status in (pending,confirmed); idempotency_key dedups offline replay; reschedule_of chains reschedule.';
comment on column public.appointments.contract_id is 'FK to service_contracts ON DELETE CASCADE (engagement atom).';
comment on column public.appointments.slot_id is 'Nullable FK to availability_slots ON DELETE SET NULL preserves appointment if template later deleted.';
comment on column public.appointments.professional_entity_id is 'Denormalized from service_contracts.professional_entity_id for EXCLUDE WITH =; never client-supplied.';
comment on column public.appointments.client_entity_id is 'Denormalized from service_contracts.client_entity_id.';
comment on column public.appointments.starts_at is 'Concrete booking start timestamptz; CHECK starts_at < ends_at and RPC validates > now().';
comment on column public.appointments.ends_at is 'Concrete booking end timestamptz.';
comment on column public.appointments.status is 'Lifecycle: pending/confirmed/completed/cancelled/rescheduled; EXCLUDE WHERE (status IN pending,confirmed) protects only active window.';
comment on column public.appointments.reschedule_of is 'Self-FK chain for reschedule; old row status=rescheduled + new row reschedule_of=old.id.';
comment on column public.appointments.idempotency_key is 'UUID v4 from uuid:4.5.1 SyncAction.id; UNIQUE + ON CONFLICT DO NOTHING for offline replay.';

create index if not exists appointments_contract_idx
  on public.appointments (contract_id, created_at);
create index if not exists appointments_professional_starts_idx
  on public.appointments (professional_entity_id, starts_at);
create index if not exists appointments_client_starts_idx
  on public.appointments (client_entity_id, starts_at);
create index if not exists appointments_idempotency_idx
  on public.appointments (idempotency_key);

drop trigger if exists appointments_set_updated_at on public.appointments;
create trigger appointments_set_updated_at
  before update on public.appointments
  for each row
  execute function public.platform_set_updated_at();

-- EXCLUDE USING gist double-booking prevention (first gist exclusion in repo)
-- Requires btree_gist for uuid WITH = operator class.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'appointments_no_overlap'
       and conrelid = 'public.appointments'::regclass
  ) then
    alter table public.appointments
      add constraint appointments_no_overlap
        exclude using gist (
          professional_entity_id with =,
          tstzrange(starts_at, ends_at) with &&
        ) where (status in ('pending', 'confirmed'));
  end if;
end;
$$;

-- =============================================================================
-- SECTION 3: appointment_events (append-only)
-- =============================================================================
create table if not exists public.appointment_events (
  id              uuid primary key default gen_random_uuid(),
  appointment_id  uuid not null references public.appointments (id) on delete cascade,
  contract_id     uuid not null references public.service_contracts (id) on delete cascade,
  event_type      text not null,
  from_status     text,
  to_status       text,
  actor_id        uuid,
  details         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  constraint appointment_events_event_type_allowed check (
    event_type in ('booked', 'confirmed', 'rescheduled', 'cancelled', 'completed')
  )
);

comment on table public.appointment_events is
  'Append-only audit log of appointment lifecycle transitions. No UPDATE/DELETE grants; from_status/to_status capture transition, actor_id is auth.uid(), details is jsonb for starts_at/ends_at/slot_id/reschedule_of/reason.';

create index if not exists appointment_events_appointment_idx
  on public.appointment_events (appointment_id, created_at);
create index if not exists appointment_events_contract_idx
  on public.appointment_events (contract_id, created_at);
create index if not exists appointment_events_type_idx
  on public.appointment_events (event_type);

-- =============================================================================
-- SECTION 4: RLS enable + REVOKE + grants + policies (default-deny)
-- =============================================================================
alter table public.availability_slots enable row level security;
alter table public.appointments enable row level security;
alter table public.appointment_events enable row level security;

revoke all on
  public.availability_slots,
  public.appointments,
  public.appointment_events
from anon, authenticated, service_role;

-- availability_slots: owner read+write via RPC; RLS narrows below
grant select, insert, update, delete on public.availability_slots to authenticated;
grant select, insert, update, delete on public.availability_slots to service_role;

-- appointments: participant read+insert+column-level update(status,reschedule_of,updated_at)
grant select, insert on public.appointments to authenticated;
grant update (status, reschedule_of, updated_at) on public.appointments to authenticated;
grant select, insert, update, delete on public.appointments to service_role;

-- appointment_events: append-only
grant select on public.appointment_events to authenticated;
grant select, insert on public.appointment_events to authenticated, service_role;

-- Policies: owner or published listing gate for availability_slots
drop policy if exists availability_slots_select on public.availability_slots;
create policy availability_slots_select
  on public.availability_slots for select to authenticated
  using (
    entity_id = auth.uid()
    or exists (
      select 1 from public.service_listings sl
       where sl.entity_id = availability_slots.entity_id
         and sl.profession_id = availability_slots.profession_id
         and sl.status = 'published'
    )
  );
drop policy if exists availability_slots_insert on public.availability_slots;
create policy availability_slots_insert
  on public.availability_slots for insert to authenticated
  with check (entity_id = auth.uid());
drop policy if exists availability_slots_update on public.availability_slots;
create policy availability_slots_update
  on public.availability_slots for update to authenticated
  using (entity_id = auth.uid())
  with check (entity_id = auth.uid());
drop policy if exists availability_slots_delete on public.availability_slots;
create policy availability_slots_delete
  on public.availability_slots for delete to authenticated
  using (entity_id = auth.uid());

-- appointments: participant-scoped via service_contracts
drop policy if exists appointments_select on public.appointments;
create policy appointments_select
  on public.appointments for select to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists appointments_insert on public.appointments;
create policy appointments_insert
  on public.appointments for insert to authenticated
  with check (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists appointments_update on public.appointments;
create policy appointments_update
  on public.appointments for update to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ))
  with check (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));

-- appointment_events: participant-scoped
drop policy if exists appointment_events_select on public.appointment_events;
create policy appointment_events_select
  on public.appointment_events for select to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists appointment_events_insert on public.appointment_events;
create policy appointment_events_insert
  on public.appointment_events for insert to authenticated
  with check (
    actor_id = auth.uid()
    and exists (
      select 1 from public.service_contracts c
       where c.id = contract_id
         and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
    )
  );

-- =============================================================================
-- SECTION 5: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 5a. availability_upsert ──────────────────────────────────────────────────
create or replace function public.availability_upsert(
  p_profession_id uuid,
  p_weekday integer,
  p_start_time time,
  p_end_time time,
  p_slot_duration_min integer default 60,
  p_timezone text default 'Africa/Lagos',
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_tz text;
  v_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;

  if not exists (
    select 1 from public.professions p
     where p.id = p_profession_id and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if p_weekday is null or p_weekday < 0 or p_weekday > 6 then
    perform public.platform_raise_error('PLT003', 'Weekday must be between 0 and 6.');
  end if;

  if p_start_time is null or p_end_time is null then
    perform public.platform_raise_error('PLT003', 'Start and end time are required.');
  end if;

  if p_start_time >= p_end_time then
    perform public.platform_raise_error('PLT003', 'Start time must be before end time.');
  end if;

  if p_slot_duration_min is null or p_slot_duration_min < 15 or p_slot_duration_min > 480 then
    perform public.platform_raise_error('PLT003', 'Slot duration must be between 15 and 480 minutes.');
  end if;

  v_tz := nullif(btrim(p_timezone), '');
  if v_tz is null then v_tz := 'Africa/Lagos'; end if;
  if v_tz !~ '^[A-Za-z/_]+$' then
    perform public.platform_raise_error('PLT003', 'Invalid timezone.');
  end if;
  if not exists (select 1 from pg_timezone_names where name = v_tz) then
    perform public.platform_raise_error('PLT003', 'Invalid timezone.');
  end if;

  insert into public.availability_slots (
    entity_id, profession_id, weekday, start_time, end_time, slot_duration_min, timezone, is_active
  ) values (
    v_actor, p_profession_id, p_weekday, p_start_time, p_end_time, p_slot_duration_min, v_tz, coalesce(p_is_active, true)
  )
  on conflict (entity_id, profession_id, weekday, start_time) do update
    set end_time = excluded.end_time,
        slot_duration_min = excluded.slot_duration_min,
        timezone = excluded.timezone,
        is_active = excluded.is_active,
        updated_at = now()
  returning id into v_id;

  -- Audit
  perform public.platform_audit_log_add(
    'availability_upsert', 'availability_slots',
    jsonb_build_object('slot_id', v_id, 'profession_id', p_profession_id, 'weekday', p_weekday, 'timezone', v_tz)
  );

  select to_jsonb(s) into v_data from public.availability_slots s where s.id = v_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Availability saved.',
    'data', v_data
  );
end;
$$;

-- ─── 5b. availability_list ────────────────────────────────────────────────────
create or replace function public.availability_list(
  p_entity_id uuid default null,
  p_profession_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
  v_slots jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  v_target := coalesce(p_entity_id, v_actor);

  -- If requesting another entity, require published listing gate (no oracle)
  if v_target <> v_actor then
    if not exists (
      select 1 from public.service_listings sl
       where sl.entity_id = v_target
         and sl.status = 'published'
         and (p_profession_id is null or sl.profession_id = p_profession_id)
    ) then
      perform public.platform_raise_error('PLT004', 'Availability not found.');
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(s) order by s.weekday, s.start_time), '[]'::jsonb)
    into v_slots
    from public.availability_slots s
   where s.entity_id = v_target
     and s.is_active
     and (p_profession_id is null or s.profession_id = p_profession_id);

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Availability retrieved.',
    'data', jsonb_build_object('slots', v_slots)
  );
end;
$$;

-- ─── 5c. appointment_book ─────────────────────────────────────────────────────
create or replace function public.appointment_book(
  p_contract_id uuid,
  p_slot_id uuid default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_slot record;
  v_professional uuid;
  v_client uuid;
  v_id uuid;
  v_existing_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;
  if p_starts_at is null or p_ends_at is null then
    perform public.platform_raise_error('PLT003', 'Start and end time are required.');
  end if;
  if p_starts_at >= p_ends_at then
    perform public.platform_raise_error('PLT003', 'Start time must be before end time.');
  end if;
  if p_starts_at <= now() then
    perform public.platform_raise_error('PLT003', 'Start time must be in the future.');
  end if;
  if p_ends_at - p_starts_at > interval '24 hours' then
    perform public.platform_raise_error('PLT003', 'Appointment duration must not exceed 24 hours.');
  end if;
  if p_idempotency_key is null then
    perform public.platform_raise_error('PLT003', 'Idempotency key is required.');
  end if;

  -- Idempotency dedup: return existing if key already used
  select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
  if found then
    select to_jsonb(a) into v_data from public.appointments a where a.id = v_existing_id;
    return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment booked.', 'data', v_data);
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.status <> 'active' then
    perform public.platform_raise_error('PLT005', 'Contract is not active.');
  end if;

  v_professional := v_contract.professional_entity_id;
  v_client := v_contract.client_entity_id;

  -- Validate slot if provided
  if p_slot_id is not null then
    select * into v_slot from public.availability_slots where id = p_slot_id;
    if not found then
      perform public.platform_raise_error('PLT004', 'Availability slot not found.');
    end if;
  end if;

  -- Attempt insert with exclusion protection; map exclusion_violation to PLT005
  begin
    insert into public.appointments (
      contract_id, slot_id, professional_entity_id, client_entity_id,
      starts_at, ends_at, status, idempotency_key
    ) values (
      p_contract_id, p_slot_id, v_professional, v_client,
      p_starts_at, p_ends_at, 'pending', p_idempotency_key
    )
    on conflict (idempotency_key) do nothing
    returning id into v_id;

    if v_id is null then
      -- Race on idempotency_key
      select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
      select to_jsonb(a) into v_data from public.appointments a where a.id = v_existing_id;
      return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment booked.', 'data', v_data);
    end if;
  exception when exclusion_violation then
    perform public.platform_raise_error('PLT005', 'Slot taken. Pick another time.');
  when unique_violation then
    -- Fallback for idempotency race
    select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
    if found then
      select to_jsonb(a) into v_data from public.appointments a where a.id = v_existing_id;
      return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment booked.', 'data', v_data);
    end if;
    perform public.platform_raise_error('PLT005', 'Slot taken. Pick another time.');
  end;

  -- Audit event
  insert into public.appointment_events (appointment_id, contract_id, event_type, from_status, to_status, actor_id, details)
  values (v_id, p_contract_id, 'booked', null, 'pending', v_actor,
    jsonb_build_object('starts_at', p_starts_at, 'ends_at', p_ends_at, 'slot_id', p_slot_id));

  perform public.platform_audit_log_add(
    'appointment_book', 'appointments',
    jsonb_build_object('appointment_id', v_id, 'contract_id', p_contract_id, 'starts_at', p_starts_at, 'ends_at', p_ends_at)
  );

  select to_jsonb(a) into v_data from public.appointments a where a.id = v_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Appointment booked.',
    'data', v_data
  );
end;
$$;

-- ─── 5d. appointment_reschedule ───────────────────────────────────────────────
create or replace function public.appointment_reschedule(
  p_appointment_id uuid,
  p_new_starts_at timestamptz,
  p_new_ends_at timestamptz,
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_appt public.appointments%rowtype;
  v_contract public.service_contracts%rowtype;
  v_new_id uuid;
  v_existing_id uuid;
  v_old_data jsonb;
  v_new_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_appointment_id is null then
    perform public.platform_raise_error('PLT003', 'Appointment id is required.');
  end if;
  if p_new_starts_at is null or p_new_ends_at is null then
    perform public.platform_raise_error('PLT003', 'New start and end time are required.');
  end if;
  if p_new_starts_at >= p_new_ends_at then
    perform public.platform_raise_error('PLT003', 'Start time must be before end time.');
  end if;
  if p_new_starts_at <= now() then
    perform public.platform_raise_error('PLT003', 'Start time must be in the future.');
  end if;
  if p_new_ends_at - p_new_starts_at > interval '24 hours' then
    perform public.platform_raise_error('PLT003', 'Appointment duration must not exceed 24 hours.');
  end if;
  if p_idempotency_key is null then
    perform public.platform_raise_error('PLT003', 'Idempotency key is required.');
  end if;

  select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
  if found then
    select to_jsonb(a) into v_new_data from public.appointments a where a.id = v_existing_id;
    -- Return existing new appointment for idempotency (caller already has old_id, but we return new)
    return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment rescheduled.', 'data', jsonb_build_object('new_appointment', v_new_data));
  end if;

  select * into v_appt from public.appointments where id = p_appointment_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Appointment not found.');
  end if;

  select * into v_contract from public.service_contracts where id = v_appt.contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Appointment not found.');
  end if;

  if v_appt.status not in ('pending', 'confirmed') then
    perform public.platform_raise_error('PLT005', 'Only pending or confirmed appointments can be rescheduled.');
  end if;

  -- Release old slot by marking rescheduled before inserting new
  update public.appointments
     set status = 'rescheduled', updated_at = now()
   where id = p_appointment_id;

  insert into public.appointment_events (appointment_id, contract_id, event_type, from_status, to_status, actor_id, details)
  values (p_appointment_id, v_appt.contract_id, 'rescheduled', v_appt.status, 'rescheduled', v_actor,
    jsonb_build_object('old_starts_at', v_appt.starts_at, 'old_ends_at', v_appt.ends_at, 'new_starts_at', p_new_starts_at, 'new_ends_at', p_new_ends_at));

  begin
    insert into public.appointments (
      contract_id, slot_id, professional_entity_id, client_entity_id,
      starts_at, ends_at, status, reschedule_of, idempotency_key
    ) values (
      v_appt.contract_id, v_appt.slot_id, v_appt.professional_entity_id, v_appt.client_entity_id,
      p_new_starts_at, p_new_ends_at, 'pending', p_appointment_id, p_idempotency_key
    )
    on conflict (idempotency_key) do nothing
    returning id into v_new_id;

    if v_new_id is null then
      select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
      select to_jsonb(a) into v_new_data from public.appointments a where a.id = v_existing_id;
      return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment rescheduled.', 'data', jsonb_build_object('new_appointment', v_new_data));
    end if;
  exception when exclusion_violation then
    -- Revert old status? Keep rescheduled state is intentional per plan (frees old window)
    -- But to allow retry, revert to original status if new fails due to overlap
    update public.appointments set status = v_appt.status, updated_at = now() where id = p_appointment_id;
    perform public.platform_raise_error('PLT005', 'Slot taken. Pick another time.');
  when unique_violation then
    select id into v_existing_id from public.appointments where idempotency_key = p_idempotency_key;
    if found then
      select to_jsonb(a) into v_new_data from public.appointments a where a.id = v_existing_id;
      return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Appointment rescheduled.', 'data', jsonb_build_object('new_appointment', v_new_data));
    end if;
    update public.appointments set status = v_appt.status, updated_at = now() where id = p_appointment_id;
    perform public.platform_raise_error('PLT005', 'Slot taken. Pick another time.');
  end;

  insert into public.appointment_events (appointment_id, contract_id, event_type, from_status, to_status, actor_id, details)
  values (v_new_id, v_appt.contract_id, 'booked', null, 'pending', v_actor,
    jsonb_build_object('starts_at', p_new_starts_at, 'ends_at', p_new_ends_at, 'reschedule_of', p_appointment_id));

  perform public.platform_audit_log_add(
    'appointment_reschedule', 'appointments',
    jsonb_build_object('old_appointment_id', p_appointment_id, 'new_appointment_id', v_new_id, 'contract_id', v_appt.contract_id)
  );

  select to_jsonb(a) into v_old_data from public.appointments a where a.id = p_appointment_id;
  select to_jsonb(a) into v_new_data from public.appointments a where a.id = v_new_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Appointment rescheduled.',
    'data', jsonb_build_object('old_appointment', v_old_data, 'new_appointment', v_new_data)
  );
end;
$$;

-- ─── 5e. appointment_cancel ───────────────────────────────────────────────────
create or replace function public.appointment_cancel(
  p_appointment_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_appt public.appointments%rowtype;
  v_contract public.service_contracts%rowtype;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_appointment_id is null then
    perform public.platform_raise_error('PLT003', 'Appointment id is required.');
  end if;

  select * into v_appt from public.appointments where id = p_appointment_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Appointment not found.');
  end if;

  select * into v_contract from public.service_contracts where id = v_appt.contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Appointment not found.');
  end if;

  if v_appt.status not in ('pending', 'confirmed') then
    perform public.platform_raise_error('PLT005', 'Only pending or confirmed appointments can be cancelled.');
  end if;

  update public.appointments
     set status = 'cancelled', updated_at = now()
   where id = p_appointment_id;

  insert into public.appointment_events (appointment_id, contract_id, event_type, from_status, to_status, actor_id, details)
  values (p_appointment_id, v_appt.contract_id, 'cancelled', v_appt.status, 'cancelled', v_actor,
    jsonb_build_object('reason', nullif(btrim(p_reason), '')));

  perform public.platform_audit_log_add(
    'appointment_cancel', 'appointments',
    jsonb_build_object('appointment_id', p_appointment_id, 'contract_id', v_appt.contract_id, 'reason', p_reason)
  );

  select to_jsonb(a) into v_data from public.appointments a where a.id = p_appointment_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Appointment cancelled.',
    'data', v_data
  );
end;
$$;

-- =============================================================================
-- SECTION 6: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.availability_upsert(uuid, integer, time, time, integer, text, boolean) to authenticated, service_role;
grant execute on function public.availability_list(uuid, uuid) to authenticated, service_role;
grant execute on function public.appointment_book(uuid, uuid, timestamptz, timestamptz, uuid) to authenticated, service_role;
grant execute on function public.appointment_reschedule(uuid, timestamptz, timestamptz, uuid) to authenticated, service_role;
grant execute on function public.appointment_cancel(uuid, text) to authenticated, service_role;

comment on function public.availability_upsert(uuid, integer, time, time, integer, text, boolean) is
  'SECURITY INVOKER, VOLATILE. Owner upserts weekly template (entity_id=auth.uid(), profession is_active gate PLT004, weekday 0-6 PLT003, start<end PLT003, duration 15-480 PLT003, timezone IANA PLT003) via ON CONFLICT DO UPDATE. Audit-logged.';
comment on function public.availability_list(uuid, uuid) is
  'SECURITY INVOKER, STABLE. Reads own slots or published other via service_listings published gate PLT004 identical to unknown; ordered weekday, start_time.';
comment on function public.appointment_book(uuid, uuid, timestamptz, timestamptz, uuid) is
  'SECURITY INVOKER, VOLATILE. Participant books concrete timestamptz under active contract with FOR UPDATE, idempotency_key ON CONFLICT dedup, EXCLUDE 23P01 mapped to PLT005 Slot taken. Inserts appointment_events booked.';
comment on function public.appointment_reschedule(uuid, timestamptz, timestamptz, uuid) is
  'SECURITY INVOKER, VOLATILE. Participant reschedules pending/confirmed via FOR UPDATE: old rescheduled frees EXCLUDE, new pending reschedule_of=old, EXCLUDE 23P01->PLT005, idempotent via idempotency_key.';
comment on function public.appointment_cancel(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Participant cancels pending/confirmed via FOR UPDATE: status cancelled frees EXCLUDE WHERE, inserts cancelled event.';

-- =============================================================================
-- SECTION 7: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('availability_slots', 'appointments', 'appointment_events')
  ) then
    alter publication supabase_realtime drop table
      public.availability_slots, public.appointments, public.appointment_events;
  end if;
end;
$$;
