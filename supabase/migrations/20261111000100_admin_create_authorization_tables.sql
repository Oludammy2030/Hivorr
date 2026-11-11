-- Administrative governance authorization model (CP-002/CP-003).
--
-- Roles are collections of permissions. An assignment grants a role (or an
-- individual permission) to a user, with a scope and an optional expiry. An
-- explicit denial always overrides an allow. The capability engine composes
-- these rows with the existing identity grants; this migration stores the
-- governance side only.
--
-- No rows are seeded here. Role definitions and assignments are reference and
-- operational data; the founder identity is never created by a migration.

create table admin.permissions (
  key text primary key,
  namespace text not null,
  description text not null,
  sensitivity text not null default 'standard'
    check (sensitivity in ('standard', 'sensitive', 'critical')),
  created_at timestamptz not null default now(),
  constraint permissions_key_format
    check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')
);

comment on table admin.permissions is
  'Registered administrative capability keys. A permission is an action on a resource, never a role.';

create table admin.roles (
  id uuid primary key default platform.uuidv7(),
  key text not null unique,
  name text not null,
  description text,
  system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_key_format
    check (key ~ '^[a-z][a-z0-9_]*$')
);

comment on table admin.roles is
  'A named collection of permissions. A role never implies every record in its module; scope is separate.';

create table admin.role_permissions (
  role_id uuid not null references admin.roles (id) on delete cascade,
  permission_key text not null references admin.permissions (key) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_key)
);

comment on table admin.role_permissions is
  'The permissions a role grants. Multiple roles are unioned; an explicit denial still wins.';

create table admin.role_assignments (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  role_id uuid not null references admin.roles (id) on delete restrict,
  scope_type text not null
    check (scope_type in (
      'platform',
      'department',
      'organisation',
      'activity',
      'case',
      'team',
      'queue'
    )),
  scope_id uuid,
  granted_by uuid references identity.users (id) on delete set null,
  reason text,
  approval_reference text,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint role_assignments_scope_shape check (
    (scope_type = 'platform' and scope_id is null)
    or (scope_type <> 'platform' and scope_id is not null)
  ),
  constraint role_assignments_expiry_after_creation check (
    expires_at is null or expires_at > created_at
  )
);

comment on table admin.role_assignments is
  'A role grant to a user with a resource scope and validity window. An expired or revoked assignment contributes no authority.';

create index role_assignments_user_active_idx
  on admin.role_assignments (user_id, expires_at)
  where revoked_at is null;

create index role_assignments_role_idx on admin.role_assignments (role_id);

create unique index role_assignments_active_unique
  on admin.role_assignments (
    user_id,
    role_id,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where revoked_at is null;

create index role_assignments_scope_idx
  on admin.role_assignments (scope_type, scope_id)
  where revoked_at is null;

create table admin.permission_grants (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  permission_key text not null references admin.permissions (key) on delete cascade,
  scope_type text not null
    check (scope_type in (
      'platform',
      'department',
      'organisation',
      'activity',
      'case',
      'team',
      'queue'
    )),
  scope_id uuid,
  granted_by uuid references identity.users (id) on delete set null,
  reason text,
  approval_reference text,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint permission_grants_scope_shape check (
    (scope_type = 'platform' and scope_id is null)
    or (scope_type <> 'platform' and scope_id is not null)
  ),
  constraint permission_grants_expiry_after_creation check (
    expires_at is null or expires_at > created_at
  )
);

comment on table admin.permission_grants is
  'An individual permission grant outside a role. Used sparingly and always with a reason.';

create index permission_grants_user_active_idx
  on admin.permission_grants (user_id, expires_at)
  where revoked_at is null;

create unique index permission_grants_active_unique
  on admin.permission_grants (
    user_id,
    permission_key,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where revoked_at is null;

create table admin.access_denials (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  permission_key text not null references admin.permissions (key) on delete cascade,
  scope_type text
    check (scope_type in (
      'platform',
      'department',
      'organisation',
      'activity',
      'case',
      'team',
      'queue'
    )),
  scope_id uuid,
  reason text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint access_denials_scope_shape check (
    (scope_type is null and scope_id is null)
    or (scope_type = 'platform' and scope_id is null)
    or (scope_type <> 'platform' and scope_id is not null)
  ),
  constraint access_denials_expiry_after_creation check (
    expires_at is null or expires_at > created_at
  )
);

comment on table admin.access_denials is
  'Explicit denial. It overrides every allow for the same permission and scope until it expires or is removed by an authorised operator.';

create index access_denials_user_idx on admin.access_denials (user_id);

create trigger roles_touch_updated_at
before update on admin.roles
for each row execute function platform.touch_updated_at();

alter table admin.permissions enable row level security;
alter table admin.roles enable row level security;
alter table admin.role_permissions enable row level security;
alter table admin.role_assignments enable row level security;
alter table admin.permission_grants enable row level security;
alter table admin.access_denials enable row level security;

alter table admin.permissions force row level security;
alter table admin.roles force row level security;
alter table admin.role_permissions force row level security;
alter table admin.role_assignments force row level security;
alter table admin.permission_grants force row level security;
alter table admin.access_denials force row level security;

-- Reference data is readable by an authenticated API caller. The service layer
-- still decides whether the caller may administer it.
create policy permissions_select on admin.permissions
  for select to hivorr_api, hivorr_readonly using (true);

create policy roles_select on admin.roles
  for select to hivorr_api, hivorr_readonly using (true);

create policy role_permissions_select on admin.role_permissions
  for select to hivorr_api, hivorr_readonly using (true);

-- A caller may read only its own governance authority. Administrative list and
-- mutation paths use dedicated, audited functions in a later package; this
-- policy deliberately does not expose another user's assignments.
create policy role_assignments_select_own on admin.role_assignments
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy permission_grants_select_own on admin.permission_grants
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy access_denials_select_own on admin.access_denials
  for select to hivorr_api
  using (user_id = platform.current_user_id());

revoke all on admin.permissions from public;
revoke all on admin.roles from public;
revoke all on admin.role_permissions from public;
revoke all on admin.role_assignments from public;
revoke all on admin.permission_grants from public;
revoke all on admin.access_denials from public;

grant select on admin.permissions to hivorr_api, hivorr_readonly;
grant select on admin.roles to hivorr_api, hivorr_readonly;
grant select on admin.role_permissions to hivorr_api, hivorr_readonly;
grant select on admin.role_assignments to hivorr_api;
grant select on admin.permission_grants to hivorr_api;
grant select on admin.access_denials to hivorr_api;
