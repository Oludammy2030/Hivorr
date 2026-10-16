-- =============================================================================
-- EP-03-18: Lifecycle Notifications & Event Orchestration — durable outbox
-- -----------------------------------------------------------------------------
-- Migration: 20261014090001_notification_outbox.sql
-- Depends on: 20261013090002_dispute_notify_channel.sql (notification_events)
--             20260819090001_enforcement_foundation.sql (platform_* helpers)
--             20260821090002_entity_core_tables.sql (entities)
--
-- PURPOSE
--   Durable, exactly-once fan-out for the 15-event EP-03-18 matrix:
--   listing_published, contract_offered/accepted/cancelled,
--   milestone_completed/verified/revision_requested, milestone_released,
--   review_submitted/revealed, message_received,
--   appointment_booked/rescheduled/cancelled, earnings_released.
--   (Disputes stay on the proven dispute_notify direct path to avoid
--   duplicates; contract disputed status still notifies via contract_events.)
--
--   Writers are SECURITY DEFINER helpers + AFTER INSERT/UPDATE triggers.
--   End users never INSERT here directly (RLS default-deny, zero
--   authenticated grants). The lifecycle_notify Edge Function drains with
--   FOR UPDATE SKIP LOCKED via notification_claim_batch/notification_ack
--   (service_role only) and inserts into notification_events.
--
-- EXECUTION MODEL
--   - SECURITY DEFINER for notification_enqueue + claim/ack + trigger
--     helpers, pinned search_path = pg_catalog, public (mirrors
--     dispute_place_escrow_hold precedent). One deliberate deviation from the
--     plan's SECURITY INVOKER label: INVOKER + zero authenticated grants
--     cannot write, so DEFINER preserves the approved default-deny posture.
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - Exactly-once: dedup_key UNIQUE + INSERT ... ON CONFLICT DO NOTHING.
--     dedup_key = <event_type>:<source_id>[:<recipient>] per plan.
--   - Lease safety: claim stamps a 5-minute lease (next_retry_at); crashed
--     drains are re-leased on the next sweep, never stranded.
--   - PII: titles/bodies use ***last4 only; never emails, phones, amounts,
--     message bodies, or review text (mirrors dispute_notify shortId).
--   - Realtime: notification_outbox is NEVER published; only
--     notification_events is (existing publication preserved).
-- =============================================================================

-- =============================================================================
-- SECTION 1: notification_outbox table
-- =============================================================================
create table if not exists public.notification_outbox (
  id                  uuid primary key default gen_random_uuid(),
  dedup_key           text not null,
  recipient_entity_id uuid not null references public.entities (id) on delete cascade,
  event_type          text not null,
  title               text not null,
  body                text not null,
  channel_id          text not null default 'hivorr_default',
  priority            text not null default 'normal',
  action_route        text,
  payload             jsonb not null default '{}'::jsonb,
  status              text not null default 'pending',
  attempts            integer not null default 0,
  next_retry_at       timestamptz not null default now(),
  created_at          timestamptz not null default now(),
  constraint notification_outbox_dedup_key_not_empty check (char_length(btrim(dedup_key)) between 1 and 255),
  constraint notification_outbox_dedup_key_unique unique (dedup_key),
  constraint notification_outbox_event_type_allowed check (
    event_type in (
      'listing_published',
      'contract_offered', 'contract_accepted', 'contract_cancelled',
      'milestone_completed', 'milestone_verified', 'milestone_revision_requested',
      'milestone_released',
      'review_submitted', 'review_revealed',
      'message_received',
      'appointment_booked', 'appointment_rescheduled', 'appointment_cancelled',
      'dispute_filed', 'dispute_resolved',
      'earnings_released'
    )
  ),
  constraint notification_outbox_title_length check (char_length(btrim(title)) between 1 and 120),
  constraint notification_outbox_body_length check (char_length(btrim(body)) between 1 and 500),
  constraint notification_outbox_channel_format check (channel_id ~ '^[a-zA-Z0-9_]+$'),
  constraint notification_outbox_priority_allowed check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint notification_outbox_status_allowed check (status in ('pending', 'leased', 'sent', 'failed')),
  constraint notification_outbox_attempts_nonneg check (attempts >= 0)
);

comment on table public.notification_outbox is
  'EP-03-18 durable outbox: exactly-once delivery intents drained by lifecycle_notify into notification_events. dedup_key UNIQUE gives idempotency; triggers (DEFINER) are the sole writers besides notification_enqueue RPC and service_role Edge Functions. Never Realtime-published.';

create index if not exists notification_outbox_status_retry_idx
  on public.notification_outbox (status, next_retry_at)
  where status in ('pending', 'leased');
create index if not exists notification_outbox_recipient_idx
  on public.notification_outbox (recipient_entity_id, created_at desc);
create index if not exists notification_outbox_event_idx
  on public.notification_outbox (event_type, created_at desc);

-- =============================================================================
-- SECTION 2: RLS + grants (default-deny; service_role only)
-- =============================================================================
alter table public.notification_outbox enable row level security;

revoke all on public.notification_outbox from anon, authenticated, service_role;

grant select, insert, update, delete on public.notification_outbox to service_role;

-- No grants to anon/authenticated: direct REST writes blocked; writes go
-- through SECURITY DEFINER helpers (owner bypass) + service_role drain.
-- Authenticated EXECUTE on the RPCs below is the only entry point.

-- =============================================================================
-- SECTION 3: notification_enqueue (canonical writer, DEFINER)
-- =============================================================================
create or replace function public.notification_enqueue(
  p_dedup_key text,
  p_recipient uuid,
  p_event_type text,
  p_title text,
  p_body text,
  p_channel text default 'hivorr_default',
  p_priority text default 'normal',
  p_action_route text default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_rows integer := 0;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_dedup_key is null or char_length(btrim(p_dedup_key)) < 1 or char_length(p_dedup_key) > 255 then
    perform public.platform_raise_error('PLT003', 'Dedup key is required.');
  end if;

  if p_recipient is null then
    perform public.platform_raise_error('PLT003', 'Recipient is required.');
  end if;

  if not exists (select 1 from public.entities where id = p_recipient) then
    perform public.platform_raise_error('PLT004', 'Recipient not found.');
  end if;

  if p_event_type not in (
    'listing_published',
    'contract_offered', 'contract_accepted', 'contract_cancelled',
    'milestone_completed', 'milestone_verified', 'milestone_revision_requested',
    'milestone_released',
    'review_submitted', 'review_revealed',
    'message_received',
    'appointment_booked', 'appointment_rescheduled', 'appointment_cancelled',
    'dispute_filed', 'dispute_resolved',
    'earnings_released'
  ) then
    perform public.platform_raise_error('PLT003', 'Invalid event type.');
  end if;

  if p_title is null or char_length(btrim(p_title)) < 1 or char_length(p_title) > 120 then
    perform public.platform_raise_error('PLT003', 'Title must be 1 to 120 characters.');
  end if;

  if p_body is null or char_length(btrim(p_body)) < 1 or char_length(p_body) > 500 then
    perform public.platform_raise_error('PLT003', 'Body must be 1 to 500 characters.');
  end if;

  if p_channel is null or p_channel !~ '^[a-zA-Z0-9_]+$' then
    perform public.platform_raise_error('PLT003', 'Invalid channel id.');
  end if;

  if p_priority not in ('low', 'normal', 'high', 'urgent') then
    perform public.platform_raise_error('PLT003', 'Invalid priority.');
  end if;

  -- Action-route allowlist: deep-links only, no open redirect.
  if p_action_route is not null and p_action_route <> '' then
    if p_action_route !~ '^/(contracts|dashboard|appointments|support|finance|services|s|p)(/|$|\?)' then
      perform public.platform_raise_error('PLT003', 'Invalid action route.');
    end if;
  end if;

  -- PII guard (mirrors lib/core/logging/pii_redactor.dart defaultPatterns):
  -- titles/bodies are ***last4 templates; contact details are rejected here
  -- so a compromised/mistaken caller cannot launder PII into the push
  -- channel. Amounts stay out by template discipline (no digits rule would
  -- false-positive on ordinary words, so amounts are covered by review).
  if btrim(p_title) ~ '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
     or btrim(p_body) ~ '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
     or btrim(p_title) ~ '\+?234[ -]?[0-9]{3}[ -]?[0-9]{3}[ -]?[0-9]{4}'
     or btrim(p_body) ~ '\+?234[ -]?[0-9]{3}[ -]?[0-9]{3}[ -]?[0-9]{4}'
     or btrim(p_title) ~ '[0-9]{10,15}'
     or btrim(p_body) ~ '[0-9]{10,15}' then
    perform public.platform_raise_error('PLT003', 'Title/body must not contain contact details.');
  end if;

  -- Caller-participant binding: when the payload references a source object,
  -- the caller must belong to it (identical PLT004, no existence oracle).
  -- service_role/postgres (drain, tests, Edge Functions) bypass the check.
  -- NOTE: current_user is the DEFINER owner inside this function, so the
  -- bypass reads the JWT role claim (message_send precedent), not the role.
  if coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role', 'postgres') then
    if coalesce(p_payload->>'contractId', '') <> '' then
      if (p_payload->>'contractId') !~ '^[0-9a-fA-F-]{36}$'
         or not exists (
           select 1 from public.service_contracts c
            where c.id = (p_payload->>'contractId')::uuid
              and (c.client_entity_id = v_actor or c.professional_entity_id = v_actor)
         ) then
        perform public.platform_raise_error('PLT004', 'Recipient not found.');
      end if;
    end if;
    if coalesce(p_payload->>'conversationId', '') <> '' then
      if (p_payload->>'conversationId') !~ '^[0-9a-fA-F-]{36}$'
         or not exists (
           select 1 from public.conversation_participants cp
            where cp.conversation_id = (p_payload->>'conversationId')::uuid
              and cp.entity_id = v_actor
         ) then
        perform public.platform_raise_error('PLT004', 'Recipient not found.');
      end if;
    end if;
    if coalesce(p_payload->>'listingId', '') <> '' then
      if (p_payload->>'listingId') !~ '^[0-9a-fA-F-]{36}$'
         or not exists (
           select 1 from public.service_listings l
            where l.id = (p_payload->>'listingId')::uuid
              and l.entity_id = v_actor
         ) then
        perform public.platform_raise_error('PLT004', 'Recipient not found.');
      end if;
    end if;
  end if;

  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status, attempts, next_retry_at
  ) values (
    btrim(p_dedup_key), p_recipient, p_event_type, btrim(p_title), btrim(p_body),
    p_channel, p_priority, nullif(btrim(p_action_route), ''),
    coalesce(p_payload, '{}'::jsonb), 'pending', 0, now()
  )
  on conflict (dedup_key) do nothing;

  get diagnostics v_rows = row_count;
  -- row_count is 1 on insert, 0 on conflict (exactly-once no-op).

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Notification enqueued.',
    'data', jsonb_build_object('dedup_key', btrim(p_dedup_key), 'enqueued', (v_rows = 1))
  );
end;
$$;

revoke execute on function public.notification_enqueue(text, uuid, text, text, text, text, text, text, jsonb) from public;
grant execute on function public.notification_enqueue(text, uuid, text, text, text, text, text, text, jsonb) to authenticated, service_role;

comment on function public.notification_enqueue(text, uuid, text, text, text, text, text, text, jsonb) is
  'EP-03-18 canonical outbox writer. SECURITY DEFINER (owner bypass) so authenticated callers can enqueue without direct table grants; validates recipient/event/title/body/channel/priority/action-route allowlist, rejects contact-details PII, binds caller to payload contract/conversation/listing (PLT004, no oracle); ON CONFLICT DO NOTHING gives exactly-once.';

-- =============================================================================
-- SECTION 4: claim/ack helpers for lifecycle_notify (service_role only)
-- =============================================================================
create or replace function public.notification_claim_batch(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_items jsonb;
begin
  -- DEFINER runs as owner: read the JWT role claim (not current_user).
  if coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Not found.');
  end if;

  if p_limit is null or p_limit < 1 then p_limit := 1; end if;
  if p_limit > 100 then p_limit := 100; end if;

  -- Lease pending rows plus crashed leases (leased rows whose 5-minute
  -- lease timed out). Stamping next_retry_at on lease bounds recovery:
  -- a drain crash can strand a row for at most 5 minutes, never forever.
  with leased as (
    select id
      from public.notification_outbox
     where next_retry_at <= now()
       and status in ('pending', 'leased')
     order by created_at
     limit p_limit
     for update skip locked
  )
  update public.notification_outbox o
     set status = 'leased', attempts = o.attempts + 1,
         next_retry_at = now() + interval '5 minutes'
    from leased
   where o.id = leased.id;

  -- Collect leased rows for the drain (service_role sees all via owner bypass).
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at), '[]'::jsonb)
    into v_items
    from (
      select o.id, o.dedup_key, o.recipient_entity_id, o.event_type,
             o.title, o.body, o.channel_id, o.priority, o.action_route,
             o.payload, o.attempts, o.created_at
        from public.notification_outbox o
       where o.status = 'leased'
       order by o.created_at
       limit p_limit
    ) x;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Batch claimed.',
    'data', jsonb_build_object('items', v_items)
  );
end;
$$;

revoke execute on function public.notification_claim_batch(int) from public;
grant execute on function public.notification_claim_batch(int) to service_role;

create or replace function public.notification_ack(
  p_id uuid,
  p_ok boolean,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_attempts int;
begin
  -- DEFINER runs as owner: read the JWT role claim (not current_user).
  if coalesce(current_setting('request.jwt.claim.role', true), '') not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Not found.');
  end if;

  if p_id is null then
    perform public.platform_raise_error('PLT003', 'Outbox id is required.');
  end if;

  select attempts into v_attempts from public.notification_outbox where id = p_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Outbox row not found.');
  end if;

  if p_ok then
    update public.notification_outbox
       set status = 'sent'
     where id = p_id;
  else
    if v_attempts >= 5 then
      update public.notification_outbox
         set status = 'failed'
       where id = p_id;
    else
      update public.notification_outbox
         set status = 'pending',
             next_retry_at = now() + (v_attempts * interval '30 seconds') + interval '30 seconds'
       where id = p_id;
    end if;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Outbox acknowledged.',
    'data', jsonb_build_object('id', p_id, 'ok', p_ok)
  );
end;
$$;

revoke execute on function public.notification_ack(uuid, boolean, text) from public;
grant execute on function public.notification_ack(uuid, boolean, text) to service_role;

-- =============================================================================
-- SECTION 5: trigger helpers (DEFINER, PII-safe ***last4)
-- =============================================================================

-- 5a. contract_events fan-out -----------------------------------------------
create or replace function public.notification_on_contract_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_contract record;
  v_recipient uuid;
  v_recipient2 uuid;
  v_short text;
  v_title text;
  v_body text;
  v_channel text := 'hivorr_contracts';
  v_priority text := 'normal';
  v_route text;
  v_event text;
  v_dedup text;
begin
  select c.client_entity_id, c.professional_entity_id
    into v_contract
    from public.service_contracts c
   where c.id = NEW.contract_id;
  if not found then return NEW; end if;

  v_short := '***' || right(NEW.contract_id::text, 4);
  v_route := '/contracts/' || NEW.contract_id::text;

  case NEW.event_type
    when 'offered' then
      v_event := 'contract_offered';
      v_recipient := v_contract.professional_entity_id;
      v_title := 'New contract offer';
      v_body := 'Contract ' || v_short || ' is awaiting your review.';
    when 'accepted' then
      v_event := 'contract_accepted';
      v_recipient := v_contract.client_entity_id;
      v_title := 'Contract accepted';
      v_body := 'Contract ' || v_short || ' is now active.';
    when 'cancelled' then
      v_event := 'contract_cancelled';
      v_title := 'Contract cancelled';
      v_body := 'Contract ' || v_short || ' was cancelled.';
      -- Counterparty of the actor; fall back to both when actor unknown.
      if NEW.actor_id = v_contract.client_entity_id then
        v_recipient := v_contract.professional_entity_id;
      elsif NEW.actor_id = v_contract.professional_entity_id then
        v_recipient := v_contract.client_entity_id;
      else
        v_recipient := v_contract.client_entity_id;
        v_recipient2 := v_contract.professional_entity_id;
      end if;
    when 'milestone_completed' then
      v_event := 'milestone_completed';
      v_recipient := v_contract.client_entity_id;
      v_title := 'Milestone submitted';
      v_body := 'Contract ' || v_short || ' has work ready for review.';
    when 'milestone_verified' then
      v_event := 'milestone_verified';
      v_recipient := v_contract.professional_entity_id;
      v_title := 'Milestone approved';
      v_body := 'Contract ' || v_short || ' milestone was approved.';
    when 'milestone_revision_requested' then
      v_event := 'milestone_revision_requested';
      v_recipient := v_contract.professional_entity_id;
      v_title := 'Revision requested';
      v_body := 'Contract ' || v_short || ' needs a revision.';
    when 'disputed' then
      v_event := 'contract_cancelled';
      v_title := 'Contract disputed';
      v_body := 'Contract ' || v_short || ' is now frozen pending resolution.';
      v_recipient := v_contract.client_entity_id;
      v_recipient2 := v_contract.professional_entity_id;
    else
      -- closed and any future types: audit only, no push (plan scope).
      return NEW;
  end case;

  v_dedup := v_event || ':' || NEW.id::text || ':' || v_recipient::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, v_recipient, v_event, v_title, v_body,
    v_channel, v_priority, v_route,
    jsonb_build_object('contractId', NEW.contract_id, 'event', v_event),
    'pending'
  ) on conflict (dedup_key) do nothing;

  if v_recipient2 is not null then
    v_dedup := v_event || ':' || NEW.id::text || ':' || v_recipient2::text;
    insert into public.notification_outbox (
      dedup_key, recipient_entity_id, event_type, title, body,
      channel_id, priority, action_route, payload, status
    ) values (
      v_dedup, v_recipient2, v_event, v_title, v_body,
      v_channel, v_priority, v_route,
      jsonb_build_object('contractId', NEW.contract_id, 'event', v_event),
      'pending'
    ) on conflict (dedup_key) do nothing;
  end if;

  return NEW;
end;
$$;

drop trigger if exists notification_on_contract_event_trigger on public.contract_events;
create trigger notification_on_contract_event_trigger
  after insert on public.contract_events
  for each row
  execute function public.notification_on_contract_event();

-- 5b. appointment_events fan-out -------------------------------------------
create or replace function public.notification_on_appointment_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_appt record;
  v_recipient uuid;
  v_short text;
  v_title text;
  v_body text;
  v_event text;
  v_route text;
  v_dedup text;
begin
  select a.client_entity_id, a.professional_entity_id, a.starts_at, a.ends_at
    into v_appt
    from public.appointments a
   where a.id = NEW.appointment_id;
  if not found then return NEW; end if;

  v_short := '***' || right(NEW.contract_id::text, 4);
  v_route := '/appointments/' || NEW.appointment_id::text;

  case NEW.event_type
    when 'booked', 'confirmed' then
      v_event := 'appointment_booked';
      v_title := 'Appointment booked';
      v_body := 'Contract ' || v_short || ' has a new appointment.';
    when 'rescheduled' then
      v_event := 'appointment_rescheduled';
      v_title := 'Appointment rescheduled';
      v_body := 'Contract ' || v_short || ' appointment changed.';
    when 'cancelled' then
      v_event := 'appointment_cancelled';
      v_title := 'Appointment cancelled';
      v_body := 'Contract ' || v_short || ' appointment was cancelled.';
    else
      return NEW;
  end case;

  if NEW.actor_id = v_appt.client_entity_id then
    v_recipient := v_appt.professional_entity_id;
  elsif NEW.actor_id = v_appt.professional_entity_id then
    v_recipient := v_appt.client_entity_id;
  else
    -- System action: notify both sides with distinct dedup keys.
    v_recipient := v_appt.client_entity_id;
    v_dedup := v_event || ':' || NEW.id::text || ':' || v_recipient::text;
    insert into public.notification_outbox (
      dedup_key, recipient_entity_id, event_type, title, body,
      channel_id, priority, action_route, payload, status
    ) values (
      v_dedup, v_recipient, v_event, v_title, v_body,
      'hivorr_schedule', 'normal', v_route,
      jsonb_build_object('contractId', NEW.contract_id, 'appointmentId', NEW.appointment_id, 'event', v_event),
      'pending'
    ) on conflict (dedup_key) do nothing;

    v_recipient := v_appt.professional_entity_id;
  end if;

  v_dedup := v_event || ':' || NEW.id::text || ':' || v_recipient::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, v_recipient, v_event, v_title, v_body,
    'hivorr_schedule', 'normal', v_route,
    jsonb_build_object('contractId', NEW.contract_id, 'appointmentId', NEW.appointment_id, 'event', v_event),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_appointment_event_trigger on public.appointment_events;
create trigger notification_on_appointment_event_trigger
  after insert on public.appointment_events
  for each row
  execute function public.notification_on_appointment_event();

-- 5c. messages fan-out (counterparty only, generic body, no preview) -------
create or replace function public.notification_on_message()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_conv record;
  v_recipient uuid;
  v_short text;
  v_dedup text;
  v_route text;
begin
  select c.contract_id into v_conv
    from public.conversations c
   where c.id = NEW.conversation_id;
  if not found then return NEW; end if;

  select cp.entity_id into v_recipient
    from public.conversation_participants cp
   where cp.conversation_id = NEW.conversation_id
     and cp.entity_id <> NEW.sender_entity_id
   limit 1;
  if not found or v_recipient is null then return NEW; end if;

  v_short := '***' || right(v_conv.contract_id::text, 4);
  v_route := '/dashboard/messages/' || NEW.conversation_id::text;
  v_dedup := 'message_received:' || NEW.id::text || ':' || v_recipient::text;

  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, v_recipient, 'message_received',
    'New message',
    'Contract ' || v_short || ' has a new message.',
    'hivorr_messages', 'high', v_route,
    jsonb_build_object('contractId', v_conv.contract_id, 'conversationId', NEW.conversation_id, 'event', 'message_received'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_message_trigger on public.messages;
create trigger notification_on_message_trigger
  after insert on public.messages
  for each row
  execute function public.notification_on_message();

-- 5d. service_listings published fan-out (owner self-confirm) ---------------
create or replace function public.notification_on_listing_published()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_dedup text;
begin
  if OLD.status = 'published' or NEW.status <> 'published' then
    return NEW;
  end if;

  v_dedup := 'listing_published:' || NEW.id::text || ':' || NEW.entity_id::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, NEW.entity_id, 'listing_published',
    'Listing published',
    'Your service is now discoverable.',
    'hivorr_default', 'normal', '/services/' || NEW.id::text,
    jsonb_build_object('listingId', NEW.id, 'event', 'listing_published'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_listing_published_trigger on public.service_listings;
create trigger notification_on_listing_published_trigger
  after update of status on public.service_listings
  for each row
  execute function public.notification_on_listing_published();

-- 5e. service_reviews fan-out (submit=self, reveal=both, dedup-safe) -------
create or replace function public.notification_on_review_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_dedup text;
begin
  v_dedup := 'review_submitted:' || NEW.id::text || ':' || NEW.reviewer_entity_id::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, NEW.reviewer_entity_id, 'review_submitted',
    'Review submitted',
    'Contract ***' || right(NEW.contract_id::text, 4) || ' review recorded.',
    'hivorr_reviews', 'normal', '/contracts/' || NEW.contract_id::text || '/reviews',
    jsonb_build_object('contractId', NEW.contract_id, 'event', 'review_submitted'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_review_insert_trigger on public.service_reviews;
create trigger notification_on_review_insert_trigger
  after insert on public.service_reviews
  for each row
  execute function public.notification_on_review_insert();

create or replace function public.notification_on_review_reveal()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_dedup text;
begin
  if OLD.is_revealed = true or NEW.is_revealed <> true then
    return NEW;
  end if;

  -- Notify the reviewer (self); the counterparty row fires its own trigger
  -- with the same contract dedup per recipient, so both sides are covered
  -- exactly once even when reveal updates two rows in one transaction.
  v_dedup := 'review_revealed:' || NEW.contract_id::text || ':' || NEW.reviewer_entity_id::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, NEW.reviewer_entity_id, 'review_revealed',
    'Review revealed',
    'Contract ***' || right(NEW.contract_id::text, 4) || ' reviews are now visible.',
    'hivorr_reviews', 'normal', '/contracts/' || NEW.contract_id::text || '/reviews',
    jsonb_build_object('contractId', NEW.contract_id, 'event', 'review_revealed'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  v_dedup := 'review_revealed:' || NEW.contract_id::text || ':' || NEW.reviewee_entity_id::text;
  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    v_dedup, NEW.reviewee_entity_id, 'review_revealed',
    'Review revealed',
    'Contract ***' || right(NEW.contract_id::text, 4) || ' reviews are now visible.',
    'hivorr_reviews', 'normal', '/contracts/' || NEW.contract_id::text || '/reviews',
    jsonb_build_object('contractId', NEW.contract_id, 'event', 'review_revealed'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_review_reveal_trigger on public.service_reviews;
create trigger notification_on_review_reveal_trigger
  after update of is_revealed on public.service_reviews
  for each row
  execute function public.notification_on_review_reveal();

-- 5f. contract_milestones released fan-out (released + earnings) ------------
create or replace function public.notification_on_milestone_released()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_contract record;
  v_short text;
begin
  if OLD.status = 'released' or NEW.status <> 'released' then
    return NEW;
  end if;

  select c.client_entity_id, c.professional_entity_id
    into v_contract
    from public.service_contracts c
   where c.id = NEW.contract_id;
  if not found then return NEW; end if;

  v_short := '***' || right(NEW.contract_id::text, 4);

  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    'milestone_released:' || NEW.id::text || ':' || v_contract.professional_entity_id::text,
    v_contract.professional_entity_id, 'milestone_released',
    'Milestone released',
    'Contract ' || v_short || ' milestone was released.',
    'hivorr_escrow', 'high', '/contracts/' || NEW.contract_id::text,
    jsonb_build_object('contractId', NEW.contract_id, 'milestoneId', NEW.id, 'event', 'milestone_released'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  insert into public.notification_outbox (
    dedup_key, recipient_entity_id, event_type, title, body,
    channel_id, priority, action_route, payload, status
  ) values (
    'earnings_released:' || NEW.id::text || ':' || v_contract.professional_entity_id::text,
    v_contract.professional_entity_id, 'earnings_released',
    'Payment received',
    'Contract ' || v_short || ' earnings are available.',
    'hivorr_escrow', 'high', '/finance/earnings',
    jsonb_build_object('contractId', NEW.contract_id, 'milestoneId', NEW.id, 'event', 'earnings_released'),
    'pending'
  ) on conflict (dedup_key) do nothing;

  return NEW;
end;
$$;

drop trigger if exists notification_on_milestone_released_trigger on public.contract_milestones;
create trigger notification_on_milestone_released_trigger
  after update of status on public.contract_milestones
  for each row
  execute function public.notification_on_milestone_released();

-- =============================================================================
-- SECTION 6: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notification_outbox'
  ) then
    alter publication supabase_realtime drop table public.notification_outbox;
  end if;
end;
$$;
