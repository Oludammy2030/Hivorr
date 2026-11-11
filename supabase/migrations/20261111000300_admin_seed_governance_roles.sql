-- Governance reference data (CP-002/CP-003).
--
-- Permissions and system role definitions are reference data the application
-- depends on, so they are seeded by migration. No user, assignment or founder
-- identity is created here. Assignments remain an explicit, audited act.

insert into admin.permissions (key, namespace, description, sensitivity) values
  ('admin.verification.review', 'admin.verification', 'Review a verification submission and record a decision', 'sensitive'),
  ('admin.payment.review', 'admin.payment', 'Review a payment or payout exception', 'critical'),
  ('admin.dispute.resolve', 'admin.dispute', 'Resolve a dispute within policy', 'sensitive'),
  ('admin.account.suspend', 'admin.account', 'Suspend or restrict an account', 'critical'),
  ('admin.configuration.write', 'admin.configuration', 'Change an approved business configuration', 'critical'),
  ('admin.configuration.read', 'admin.configuration', 'Read business configuration and its history', 'standard'),
  ('admin.audit.read', 'admin.audit', 'Read the audit trail', 'sensitive'),
  ('admin.grant.read', 'admin.grant', 'Read privileged grants', 'sensitive'),
  ('admin.grant.manage', 'admin.grant', 'Create or revoke privileged grants', 'critical'),
  ('admin.user.read', 'admin.user', 'Read the user directory and account summaries', 'sensitive'),
  ('admin.user.manage', 'admin.user', 'Restrict, suspend, reactivate or close an account', 'critical'),
  ('admin.role.read', 'admin.role', 'Read governance roles and assignments', 'standard'),
  ('admin.role.manage', 'admin.role', 'Create roles and assign or revoke them', 'critical'),
  ('admin.case.read', 'admin.case', 'Read cases within the assigned scope', 'sensitive'),
  ('admin.case.assign', 'admin.case', 'Assign or reassign a case within scope', 'sensitive'),
  ('admin.case.investigate', 'admin.case', 'Investigate a case and record findings', 'sensitive'),
  ('admin.case.recommend', 'admin.case', 'Recommend a case outcome', 'sensitive'),
  ('admin.case.approve', 'admin.case', 'Approve or reject a case recommendation', 'critical'),
  ('admin.evidence.read', 'admin.evidence', 'Read case evidence within scope', 'critical'),
  ('admin.report.read', 'admin.report', 'Read governance reports', 'standard'),
  ('admin.report.export', 'admin.report', 'Export a governance report', 'critical')
on conflict (key) do nothing;

insert into admin.roles (key, name, description, system) values
  ('founder', 'Founder', 'Ultimate business authority. Scope is platform. Cannot bypass dual control or self-approval.', true),
  ('governance_admin', 'Governance Administrator', 'Administers roles, staff and partner records within a delegated scope.', true),
  ('verification_officer', 'Verification Officer', 'Reviews verification evidence and records decisions within policy.', true),
  ('support_officer', 'Support Officer', 'Handles support cases and customer context within an assigned queue.', true),
  ('operations_officer', 'Operations Officer', 'Oversees activity operations, dispatch exceptions and SLAs.', true),
  ('finance_officer', 'Finance Officer', 'Reviews ledger, reconciliation and payment exceptions.', true),
  ('investigator', 'Investigator', 'Investigates cases and records findings and recommendations.', true),
  ('compliance_reviewer', 'Compliance Reviewer', 'Reviews and decides case recommendations independently of the investigator.', true),
  ('partner_manager', 'Partner Manager', 'Administers partner organisations and agreements.', true),
  ('auditor', 'Auditor', 'Read-only access to audit and governance reports.', true),
  ('department_manager', 'Department Manager', 'Manages workload and assignment within one department.', true)
on conflict (key) do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  cross join admin.permissions p
 where r.key = 'founder'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.role.read',
    'admin.role.manage',
    'admin.user.read',
    'admin.configuration.read',
    'admin.report.read'
  )
 where r.key = 'governance_admin'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.verification.review',
    'admin.case.read',
    'admin.evidence.read'
  )
 where r.key = 'verification_officer'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.case.assign'
  )
 where r.key = 'support_officer'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.case.assign',
    'admin.report.read'
  )
 where r.key = 'operations_officer'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.payment.review',
    'admin.case.read',
    'admin.report.read'
  )
 where r.key = 'finance_officer'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.case.investigate',
    'admin.case.recommend',
    'admin.evidence.read'
  )
 where r.key = 'investigator'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.case.approve',
    'admin.evidence.read'
  )
 where r.key = 'compliance_reviewer'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.report.read'
  )
 where r.key = 'partner_manager'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.report.read',
    'admin.configuration.read'
  )
 where r.key = 'auditor'
on conflict do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in (
    'admin.case.read',
    'admin.case.assign',
    'admin.report.read'
  )
 where r.key = 'department_manager'
on conflict do nothing;
