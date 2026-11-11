-- Case, evidence, approval and configuration schema (CP-006, part 2).
--
-- One case spine for support, disputes, investigations and incidents. Evidence
-- stores metadata and a hash; the object itself belongs in private storage.
-- Approvals are a narrow typed service, not a generic workflow engine.
--
-- RLS is enabled and forced on every table. Feature packages add the narrow
-- scope-checked functions and policies; this migration adds only self-service
-- read policies for a person's own assignments and work items.

create table admin.approval_requests (
  id uuid primary key default platform.uuidv7(),
  reference text not null unique,
  action_type text not null,
  target_type text not null,
  target_id text not null,
  amount numeric(20, 4),
  currency text,
  risk_level text not null default 'medium'
    check (risk_level in ('low', 'medium', 'high', 'critical')),
  requester_user_id uuid not null references identity.users (id) on delete restrict,
  reason text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled', 'expired')),
  current_stage integer not null default 1 check (current_stage >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  constraint approval_requests_amount check (amount is null or amount >= 0),
  constraint approval_requests_currency check (
    amount is null or currency is not null
  )
);

comment on table admin.approval_requests is
  'A typed request for a sensitive action. The requester can never approve it.';

create index approval_requests_status_idx on admin.approval_requests (status, created_at);
create index approval_requests_requester_idx on admin.approval_requests (requester_user_id);

create table admin.approval_steps (
  id uuid primary key default platform.uuidv7(),
  request_id uuid not null references admin.approval_requests (id) on delete cascade,
  stage integer not null check (stage >= 1),
  required_permission text not null references admin.permissions (key) on delete restrict,
  assignee_user_id uuid references identity.users (id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'skipped')),
  decided_by uuid references identity.users (id) on delete set null,
  decided_at timestamptz,
  reason text,
  created_at timestamptz not null default now(),
  unique (request_id, stage)
);

comment on table admin.approval_steps is
  'One stage of an approval. The required permission is checked at decision time.';

create index approval_steps_assignee_idx on admin.approval_steps (assignee_user_id, status);

create table admin.approval_decisions (
  id uuid primary key default platform.uuidv7(),
  request_id uuid not null references admin.approval_requests (id) on delete cascade,
  step_id uuid not null references admin.approval_steps (id) on delete cascade,
  decision text not null check (decision in ('approve', 'reject', 'request_information')),
  decided_by uuid not null references identity.users (id) on delete restrict,
  reason text not null,
  created_at timestamptz not null default now()
);

comment on table admin.approval_decisions is
  'Append-only approval decision record. A rejection requires a reason.';

create index approval_decisions_request_idx on admin.approval_decisions (request_id);

create table admin.cases (
  id uuid primary key default platform.uuidv7(),
  reference text not null unique,
  case_type text not null check (case_type in (
    'support',
    'complaint',
    'dispute',
    'investigation',
    'incident',
    'verification_review',
    'financial_exception',
    'security_incident',
    'staff_conduct',
    'partner_conduct'
  )),
  category text,
  title text not null,
  description text,
  source text,
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  severity text not null default 'medium'
    check (severity in ('low', 'medium', 'high', 'critical')),
  sensitivity text not null default 'standard'
    check (sensitivity in ('standard', 'sensitive', 'critical')),
  status text not null default 'RECEIVED' check (status in (
    'RECEIVED',
    'TRIAGED',
    'OPEN',
    'INVESTIGATING',
    'PENDING_INFORMATION',
    'ESCALATED',
    'REVIEW',
    'DECIDED',
    'ACTION_PENDING',
    'CLOSED',
    'REOPENED',
    'MERGED',
    'ARCHIVED'
  )),
  subject_type text,
  subject_id text,
  activity_id text check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request',
    'market.sell',
    'services.offer',
    'logistics.provide'
  )),
  department_id uuid references admin.departments (id) on delete set null,
  queue_key text,
  assignee_id uuid references identity.users (id) on delete set null,
  parent_case_id uuid references admin.cases (id) on delete set null,
  created_by uuid references identity.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  outcome text,
  closure_reason text
);

comment on table admin.cases is
  'One case spine for support, complaints, disputes, investigations and incidents. Typed links point at module records; records are not copied.';

create index cases_status_idx on admin.cases (status, priority, created_at);
create index cases_department_idx on admin.cases (department_id, status);
create index cases_assignee_idx on admin.cases (assignee_id, status);
create index cases_subject_idx on admin.cases (subject_type, subject_id);
create index cases_parent_idx on admin.cases (parent_case_id);

create table admin.case_events (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  event_type text not null,
  actor_user_id uuid references identity.users (id) on delete set null,
  summary text not null,
  detail jsonb,
  occurred_at timestamptz not null default now()
);

comment on table admin.case_events is
  'Append-only case timeline. A correction is a new event, never an edit.';

create index case_events_case_idx on admin.case_events (case_id, occurred_at);

create table admin.case_links (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  link_role text not null default 'related',
  linked_by uuid references identity.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (case_id, entity_type, entity_id, link_role)
);

comment on table admin.case_links is
  'Typed references from a case to module records. The case reads the record through the owning module.';

create index case_links_entity_idx on admin.case_links (entity_type, entity_id);

create table admin.case_evidence (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  storage_key text not null unique,
  file_name text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  source text,
  classification text not null default 'sensitive'
    check (classification in ('standard', 'sensitive', 'critical')),
  retention_class text,
  uploaded_by uuid references identity.users (id) on delete set null,
  uploaded_at timestamptz not null default now(),
  supersedes_id uuid references admin.case_evidence (id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'superseded', 'quarantined', 'released')),
  access_notes text
);

comment on table admin.case_evidence is
  'Evidence metadata and integrity hash. The original object is immutable in private storage; a correction supersedes it.';

create index case_evidence_case_idx on admin.case_evidence (case_id, uploaded_at);
create index case_evidence_status_idx on admin.case_evidence (status);

create table admin.case_findings (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  author_user_id uuid not null references identity.users (id) on delete restrict,
  summary text not null,
  detail text,
  policy_reference text,
  created_at timestamptz not null default now()
);

comment on table admin.case_findings is
  'An investigator finding. A decision requires a finding or a reasoned administrative closure.';

create index case_findings_case_idx on admin.case_findings (case_id, created_at);

create table admin.case_recommendations (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  author_user_id uuid not null references identity.users (id) on delete restrict,
  recommended_action text not null,
  rationale text not null,
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'approved', 'rejected', 'withdrawn')),
  approval_request_id uuid references admin.approval_requests (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table admin.case_recommendations is
  'A recommended outcome. The author cannot approve it; approval is a separate permission and record.';

create index case_recommendations_case_idx on admin.case_recommendations (case_id, created_at);

create table admin.case_decisions (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  recommendation_id uuid references admin.case_recommendations (id) on delete set null,
  decision text not null,
  reason text not null,
  decided_by uuid not null references identity.users (id) on delete restrict,
  decided_at timestamptz not null default now(),
  approval_reference text,
  outcome text
);

comment on table admin.case_decisions is
  'An authorised case decision. It records the decision, the reason and the approval reference.';

create index case_decisions_case_idx on admin.case_decisions (case_id, decided_at);

create table admin.case_actions (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  decision_id uuid references admin.case_decisions (id) on delete set null,
  action_type text not null,
  target_type text,
  target_id text,
  status text not null default 'pending'
    check (status in ('pending', 'executed', 'failed', 'cancelled')),
  executed_by uuid references identity.users (id) on delete set null,
  executed_at timestamptz,
  result jsonb,
  failure_reason text
);

comment on table admin.case_actions is
  'Execution of a case decision. Approval and execution are separate audit events.';

create index case_actions_case_idx on admin.case_actions (case_id, status);

create table admin.case_assignments (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  assignee_user_id uuid not null references identity.users (id) on delete cascade,
  assigned_by uuid references identity.users (id) on delete set null,
  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  reason text
);

comment on table admin.case_assignments is
  'Assignment history. Scope for an investigator is derived from the active assignment.';

create unique index case_assignments_active_unique
  on admin.case_assignments (case_id, assignee_user_id)
  where unassigned_at is null;

create index case_assignments_user_idx on admin.case_assignments (assignee_user_id)
  where unassigned_at is null;

create table admin.case_team_members (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references admin.cases (id) on delete cascade,
  user_id uuid not null references identity.users (id) on delete cascade,
  team_role text not null default 'member',
  added_by uuid references identity.users (id) on delete set null,
  added_at timestamptz not null default now(),
  removed_at timestamptz
);

comment on table admin.case_team_members is
  'Members of an investigation team. Team scope is derived from active membership.';

create unique index case_team_members_active_unique
  on admin.case_team_members (case_id, user_id)
  where removed_at is null;

create table admin.work_items (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  case_id uuid references admin.cases (id) on delete cascade,
  task_type text not null,
  title text not null,
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'blocked', 'done', 'cancelled')),
  due_at timestamptz,
  created_by uuid references identity.users (id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  escalated_at timestamptz
);

comment on table admin.work_items is
  'The single assignment/task spine for governance work. It is not a second project-management system.';

create index work_items_user_idx on admin.work_items (user_id, status, due_at);

create table admin.configuration_entries (
  id uuid primary key default platform.uuidv7(),
  key text not null unique,
  namespace text not null,
  description text not null,
  value_type text not null check (value_type in ('string', 'number', 'boolean', 'json')),
  sensitivity text not null default 'standard'
    check (sensitivity in ('standard', 'sensitive', 'critical')),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint configuration_entries_key_format
    check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')
);

comment on table admin.configuration_entries is
  'A governed business configuration key. Infrastructure, secrets and deployment settings are outside this table.';

create table admin.configuration_versions (
  id uuid primary key default platform.uuidv7(),
  entry_id uuid not null references admin.configuration_entries (id) on delete cascade,
  version integer not null check (version >= 1),
  value jsonb not null,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  change_reason text not null,
  created_by uuid references identity.users (id) on delete set null,
  approval_reference text,
  created_at timestamptz not null default now(),
  unique (entry_id, version),
  constraint configuration_versions_window check (
    effective_to is null or effective_to > effective_from
  )
);

comment on table admin.configuration_versions is
  'Immutable configuration versions with an effective window, reason and approval reference.';

create index configuration_versions_entry_idx
  on admin.configuration_versions (entry_id, effective_from desc);

create trigger cases_touch_updated_at
before update on admin.cases
for each row execute function platform.touch_updated_at();

create trigger case_recommendations_touch_updated_at
before update on admin.case_recommendations
for each row execute function platform.touch_updated_at();

create trigger approval_requests_touch_updated_at
before update on admin.approval_requests
for each row execute function platform.touch_updated_at();

create trigger configuration_entries_touch_updated_at
before update on admin.configuration_entries
for each row execute function platform.touch_updated_at();

create trigger case_events_no_mutation
before update or delete on admin.case_events
for each row execute function platform.reject_append_only_mutation();

create trigger approval_decisions_no_mutation
before update or delete on admin.approval_decisions
for each row execute function platform.reject_append_only_mutation();

create trigger case_decisions_no_mutation
before update or delete on admin.case_decisions
for each row execute function platform.reject_append_only_mutation();

create trigger configuration_versions_no_mutation
before update or delete on admin.configuration_versions
for each row execute function platform.reject_append_only_mutation();

alter table admin.approval_requests enable row level security;
alter table admin.approval_steps enable row level security;
alter table admin.approval_decisions enable row level security;
alter table admin.cases enable row level security;
alter table admin.case_events enable row level security;
alter table admin.case_links enable row level security;
alter table admin.case_evidence enable row level security;
alter table admin.case_findings enable row level security;
alter table admin.case_recommendations enable row level security;
alter table admin.case_decisions enable row level security;
alter table admin.case_actions enable row level security;
alter table admin.case_assignments enable row level security;
alter table admin.case_team_members enable row level security;
alter table admin.work_items enable row level security;
alter table admin.configuration_entries enable row level security;
alter table admin.configuration_versions enable row level security;

alter table admin.approval_requests force row level security;
alter table admin.approval_steps force row level security;
alter table admin.approval_decisions force row level security;
alter table admin.cases force row level security;
alter table admin.case_events force row level security;
alter table admin.case_links force row level security;
alter table admin.case_evidence force row level security;
alter table admin.case_findings force row level security;
alter table admin.case_recommendations force row level security;
alter table admin.case_decisions force row level security;
alter table admin.case_actions force row level security;
alter table admin.case_assignments force row level security;
alter table admin.case_team_members force row level security;
alter table admin.work_items force row level security;
alter table admin.configuration_entries force row level security;
alter table admin.configuration_versions force row level security;

create policy case_assignments_select_self on admin.case_assignments
  for select to hivorr_api
  using (assignee_user_id = platform.current_user_id());

create policy work_items_select_self on admin.work_items
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy approval_steps_select_self on admin.approval_steps
  for select to hivorr_api
  using (assignee_user_id = platform.current_user_id());

revoke all on admin.approval_requests from public;
revoke all on admin.approval_steps from public;
revoke all on admin.approval_decisions from public;
revoke all on admin.cases from public;
revoke all on admin.case_events from public;
revoke all on admin.case_links from public;
revoke all on admin.case_evidence from public;
revoke all on admin.case_findings from public;
revoke all on admin.case_recommendations from public;
revoke all on admin.case_decisions from public;
revoke all on admin.case_actions from public;
revoke all on admin.case_assignments from public;
revoke all on admin.case_team_members from public;
revoke all on admin.work_items from public;
revoke all on admin.configuration_entries from public;
revoke all on admin.configuration_versions from public;

grant select on admin.case_assignments to hivorr_api;
grant select on admin.work_items to hivorr_api;
grant select on admin.approval_steps to hivorr_api;
