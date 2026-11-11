-- Administrative organisation schema (CP-006, part 1).
--
-- Staff, departments and partner organisations. These are governance records,
-- not identity records: every person remains an `identity.users` row and every
-- session remains audience-scoped. No feature endpoint is added here.
--
-- RLS is enabled and forced on every table. No API write grant is issued and no
-- broad read policy is created; the feature packages add the narrow,
-- scope-checked functions and policies they need.

create table admin.departments (
  id uuid primary key default platform.uuidv7(),
  key text not null unique,
  name text not null,
  description text,
  parent_id uuid references admin.departments (id) on delete set null,
  leader_user_id uuid references identity.users (id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint departments_key_format check (key ~ '^[a-z][a-z0-9_]*$')
);

comment on table admin.departments is
  'Internal department. Departments carry scope and reporting responsibility, never a capability by themselves.';

create index departments_parent_idx on admin.departments (parent_id);
create index departments_leader_idx on admin.departments (leader_user_id);

create table admin.staff_profiles (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null unique references identity.users (id) on delete cascade,
  employee_reference text unique,
  job_title text,
  department_id uuid references admin.departments (id) on delete set null,
  supervisor_user_id uuid references identity.users (id) on delete set null,
  engagement_status text not null default 'invited'
    check (engagement_status in (
      'invited',
      'active',
      'suspended',
      'leave',
      'offboarded'
    )),
  started_on date,
  ended_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint staff_profiles_dates check (
    ended_on is null or started_on is null or ended_on >= started_on
  )
);

comment on table admin.staff_profiles is
  'Internal staff record. Offboarding revokes grants and sessions; this row and the audit history are retained.';

create index staff_profiles_department_idx on admin.staff_profiles (department_id);
create index staff_profiles_status_idx on admin.staff_profiles (engagement_status);

create table admin.department_members (
  id uuid primary key default platform.uuidv7(),
  department_id uuid not null references admin.departments (id) on delete cascade,
  user_id uuid not null references identity.users (id) on delete cascade,
  membership_role text not null default 'member'
    check (membership_role in ('lead', 'member')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by uuid references identity.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint department_members_dates check (
    effective_to is null or effective_to > effective_from
  )
);

comment on table admin.department_members is
  'Department membership with an effective window. Scope is derived from this table, never from a request parameter.';

create unique index department_members_active_unique
  on admin.department_members (department_id, user_id)
  where effective_to is null;

create index department_members_user_idx on admin.department_members (user_id);

create table admin.partner_organisations (
  id uuid primary key default platform.uuidv7(),
  legal_name text not null,
  trading_name text,
  registration_number text unique,
  category text,
  status text not null default 'applicant'
    check (status in ('applicant', 'active', 'suspended', 'terminated')),
  country text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table admin.partner_organisations is
  'External partner organisation. It is not an account, has no wallet and holds no activity capability.';

create index partner_organisations_status_idx on admin.partner_organisations (status);

create table admin.partner_representatives (
  id uuid primary key default platform.uuidv7(),
  organisation_id uuid not null references admin.partner_organisations (id) on delete cascade,
  user_id uuid not null references identity.users (id) on delete cascade,
  representative_role text not null default 'member'
    check (representative_role in ('owner', 'admin', 'member', 'viewer')),
  authority_evidence_reference text,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by uuid references identity.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint partner_representatives_dates check (
    effective_to is null or effective_to > effective_from
  )
);

comment on table admin.partner_representatives is
  'A user authorised to act for one partner organisation. Organisation scope is derived from this row.';

create unique index partner_representatives_active_unique
  on admin.partner_representatives (organisation_id, user_id)
  where effective_to is null;

create index partner_representatives_user_idx on admin.partner_representatives (user_id);

create table admin.partner_applications (
  id uuid primary key default platform.uuidv7(),
  organisation_id uuid not null references admin.partner_organisations (id) on delete cascade,
  status text not null default 'submitted'
    check (status in (
      'draft',
      'submitted',
      'under_review',
      'approved',
      'rejected',
      'withdrawn'
    )),
  submitted_at timestamptz,
  reviewed_by uuid references identity.users (id) on delete set null,
  reviewed_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table admin.partner_applications is
  'Partner application and its review decision. One active submission per organisation is enforced by a partial unique index.';

create index partner_applications_org_idx on admin.partner_applications (organisation_id);

create unique index partner_applications_active_unique
  on admin.partner_applications (organisation_id)
  where status in ('submitted', 'under_review');

create table admin.partner_agreements (
  id uuid primary key default platform.uuidv7(),
  organisation_id uuid not null references admin.partner_organisations (id) on delete cascade,
  reference text not null unique,
  starts_on date not null,
  ends_on date,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'expired', 'terminated')),
  document_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_agreements_dates check (
    ends_on is null or ends_on >= starts_on
  )
);

comment on table admin.partner_agreements is
  'Partnership agreement metadata. Contract documents live in private object storage and are linked, not copied.';

create index partner_agreements_org_idx on admin.partner_agreements (organisation_id);

create table admin.partner_scopes (
  id uuid primary key default platform.uuidv7(),
  organisation_id uuid not null references admin.partner_organisations (id) on delete cascade,
  scope_key text not null,
  granted_by uuid references identity.users (id) on delete set null,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table admin.partner_scopes is
  'The programme or service scope assigned to a partner organisation. Scope never includes an activity capability or a wallet.';

create index partner_scopes_org_idx on admin.partner_scopes (organisation_id)
  where revoked_at is null;

create unique index partner_scopes_active_unique
  on admin.partner_scopes (organisation_id, scope_key)
  where revoked_at is null;

create trigger departments_touch_updated_at
before update on admin.departments
for each row execute function platform.touch_updated_at();

create trigger staff_profiles_touch_updated_at
before update on admin.staff_profiles
for each row execute function platform.touch_updated_at();

create trigger partner_organisations_touch_updated_at
before update on admin.partner_organisations
for each row execute function platform.touch_updated_at();

create trigger partner_applications_touch_updated_at
before update on admin.partner_applications
for each row execute function platform.touch_updated_at();

create trigger partner_agreements_touch_updated_at
before update on admin.partner_agreements
for each row execute function platform.touch_updated_at();

alter table admin.departments enable row level security;
alter table admin.staff_profiles enable row level security;
alter table admin.department_members enable row level security;
alter table admin.partner_organisations enable row level security;
alter table admin.partner_representatives enable row level security;
alter table admin.partner_applications enable row level security;
alter table admin.partner_agreements enable row level security;
alter table admin.partner_scopes enable row level security;

alter table admin.departments force row level security;
alter table admin.staff_profiles force row level security;
alter table admin.department_members force row level security;
alter table admin.partner_organisations force row level security;
alter table admin.partner_representatives force row level security;
alter table admin.partner_applications force row level security;
alter table admin.partner_agreements force row level security;
alter table admin.partner_scopes force row level security;

-- A staff member may see their own staff record and own partner representation.
-- Administrative reads and all writes use narrow, audited functions added by the
-- feature packages.
create policy staff_profiles_select_self on admin.staff_profiles
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy partner_representatives_select_self on admin.partner_representatives
  for select to hivorr_api
  using (user_id = platform.current_user_id());

revoke all on admin.departments from public;
revoke all on admin.staff_profiles from public;
revoke all on admin.department_members from public;
revoke all on admin.partner_organisations from public;
revoke all on admin.partner_representatives from public;
revoke all on admin.partner_applications from public;
revoke all on admin.partner_agreements from public;
revoke all on admin.partner_scopes from public;

grant select on admin.staff_profiles to hivorr_api;
grant select on admin.partner_representatives to hivorr_api;
