-- Active payment-provider setting (provider switch, 2026-11-26).
--
-- The founder directed Paystack as the active provider for fast integration,
-- with VFD paused behind the provider port. The control panel switches the
-- provider and mode; the test/live secrets remain in the deployment secret
-- store and are never stored here.
--
-- The row is read by the runtime router and written only through the audited
-- security-definer function, which requires `admin.configuration.write`.

set local lock_timeout = '5s';

create table platform.payment_provider_setting (
  id boolean primary key default true check (id),
  active_provider text not null default 'paystack'
    check (active_provider in ('vfd', 'paystack')),
  active_mode text not null default 'test'
    check (active_mode in ('test', 'live')),
  updated_by uuid references identity.users (id) on delete restrict,
  updated_at timestamptz not null default now()
);

comment on table platform.payment_provider_setting is
  'Single-row active payment provider and mode. It contains no secret; the keys stay in the deployment secret store.';

insert into platform.payment_provider_setting (id)
values (true)
on conflict do nothing;

alter table platform.payment_provider_setting enable row level security;

create policy payment_provider_setting_select on platform.payment_provider_setting
  for select to hivorr_api
  using (true);

grant select on platform.payment_provider_setting to hivorr_api;

create function platform.get_payment_provider(
  p_actor_user_id uuid
)
returns table (
  active_provider text,
  active_mode text,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not admin.actor_holds_platform_permission(
    p_actor_user_id,
    'admin.configuration.read'
  ) then
    raise exception 'payment_provider_read_forbidden' using errcode = '42501';
  end if;

  return query
    select s.active_provider, s.active_mode, s.updated_at
      from platform.payment_provider_setting s
     where s.id;
end;
$$;

revoke all on function platform.get_payment_provider(uuid) from public;
grant execute on function platform.get_payment_provider(uuid) to hivorr_api;

create function platform.set_payment_provider(
  p_actor_user_id uuid,
  p_provider text,
  p_mode text
)
returns table (
  active_provider text,
  active_mode text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not admin.actor_holds_platform_permission(
    p_actor_user_id,
    'admin.configuration.write'
  ) then
    raise exception 'payment_provider_forbidden' using errcode = '42501';
  end if;

  if p_provider is null or p_provider not in ('vfd', 'paystack') then
    raise exception 'payment_provider_invalid' using errcode = '22023';
  end if;

  if p_mode is null or p_mode not in ('test', 'live') then
    raise exception 'payment_mode_invalid' using errcode = '22023';
  end if;

  update platform.payment_provider_setting s
     set active_provider = p_provider,
         active_mode = p_mode,
         updated_by = p_actor_user_id,
         updated_at = now()
   where s.id;

  return query
    select s.active_provider, s.active_mode, s.updated_at
      from platform.payment_provider_setting s
     where s.id;
end;
$$;

revoke all on function platform.set_payment_provider(uuid, text, text) from public;
grant execute on function platform.set_payment_provider(uuid, text, text) to hivorr_api;
