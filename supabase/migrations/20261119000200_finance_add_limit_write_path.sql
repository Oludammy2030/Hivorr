-- Financial limit write path (EP-02-035).
--
-- Limits are configuration. Only a user holding `admin.configuration.write` may
-- add one, and the database enforces that as well as the service. There is no
-- update or delete: a change is a new effective-dated row, so history is kept.
--
-- The read policy now also admits a configuration administrator, so a newly
-- inserted row can be returned and the control surface can list every limit.
-- Ordinary accounts still see only tier rows and their own overrides.

set local lock_timeout = '5s';

drop policy limits_select on finance.limits;

create policy limits_select on finance.limits
  for select to hivorr_api
  using (
    (
      platform.current_account_id() is not null
      and (
        account_id = platform.current_account_id()
        or (account_id is null and tier is not null)
      )
    )
    or admin.actor_holds_platform_permission(
      platform.current_user_id(),
      'admin.configuration.write'
    )
  );

create policy limits_insert on finance.limits
  for insert to hivorr_api
  with check (
    admin.actor_holds_platform_permission(
      platform.current_user_id(),
      'admin.configuration.write'
    )
  );

grant insert on finance.limits to hivorr_api;
