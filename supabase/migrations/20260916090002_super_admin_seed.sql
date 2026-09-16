-- Dev-only admin bootstrap seed
--
-- Purpose: grants platform admin privileges to the seeded demo identity so
-- the admin review queue and related flows are testable in Development.
--
-- Production/Staging: the demo user id does not exist in those environments, so
-- the WHERE EXISTS guard makes this a genuine no-op (the FK to auth.users would
-- otherwise reject the INSERT).
--
-- The first real admin on a production/staging project must be bootstrapped by
-- an operator with DB access, e.g.:
--   insert into public.platform_admins (user_id, granted_by, notes)
--   select id, null, 'Bootstrap admin' from auth.users
--   where email = 'their@email.com' on conflict (user_id) do nothing;
--
-- Idempotent: re-running leaves the row untouched.

insert into public.platform_admins (user_id, granted_by, notes)
select '00000000-0000-4000-8000-000000000001', null, 'Dev-only bootstrap admin for demo identity'
where exists (
  select 1 from auth.users where id = '00000000-0000-4000-8000-000000000001'
)
on conflict (user_id) do nothing;
