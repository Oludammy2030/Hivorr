# Hivorr — Database Migration & Supabase Data API Rules

## 1. Purpose

This document defines the mandatory database migration, permission, security, and Supabase Data API rules for Hivorr.

These rules exist to ensure that database changes are:

- Secure
- Reproducible
- Version-controlled
- Consistent across environments
- Compatible with Supabase Data API requirements
- Protected by least-privilege access
- Suitable for long-term platform scalability
- Safe for AI-assisted development

All database-related implementation must comply with this document.

---

## 2. Migration-First Rule

All database changes must be implemented through version-controlled database migrations.

This includes:

- Tables
- Columns
- Relationships
- Foreign keys
- Indexes
- Constraints
- Enums
- Functions
- RPCs
- Triggers
- Views
- Grants
- RLS
- RLS policies
- Storage policies
- Other database permissions and security configuration

Do not make undocumented manual database changes in staging or production.

If a database change is required, it must be represented in the migration history.

---

## 3. Supabase Data API Explicit Grant Rule

Supabase is changing how new tables in the `public` schema are exposed through the Data API.

Starting **October 30, 2026**, new tables created in the `public` schema of existing Supabase projects will no longer automatically receive Data API access.

If a table needs to be accessed through the Supabase Data API, the required PostgreSQL privileges must be explicitly granted.

This applies to tables created through:

- SQL migrations
- SQL Editor
- Supabase CLI
- Management API
- AI coding tools
- Other provisioning or automation systems

A table can exist successfully in PostgreSQL while still being inaccessible through the Supabase Data API if the required grants are missing.

Reference:

https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically

---

## 4. GRANT and RLS Are Separate Controls

A `GRANT` and Row Level Security (RLS) serve different purposes.

### GRANT

A PostgreSQL `GRANT` determines whether a database role can access a table, view, sequence, or function through the Data API.

### RLS

Row Level Security determines which rows the authenticated role is allowed to access or modify.

Therefore:

> GRANT controls whether a role can reach the database object. RLS controls which rows that role can access.

Having RLS enabled does not replace the required PostgreSQL grants.

Having a GRANT does not replace RLS.

Both must be configured appropriately.

---

## 5. Least-Privilege Grant Rule

Never automatically grant every role full access to every table.

Each database object must be evaluated according to how it is actually used.

Possible Data API roles include:

- `anon`
- `authenticated`
- `service_role`

Only grant the privileges required by each role.

Example:

```sql
grant select
on table public.example_table
to authenticated;

The exact grants and policies must always be determined from the actual business and security requirements.

Do not blindly copy this example into production.

7. Functions and RPCs

Database functions and RPCs must also follow explicit permission rules.

If a function is called through the Data API, its required EXECUTE privileges must be explicitly considered.

Example:

grant execute
on function public.example_function()
to authenticated;

Do not expose sensitive administrative or internal functions to anon or authenticated unless explicitly required.

Functions using elevated privileges, including SECURITY DEFINER, must receive additional security review.

8. Row Level Security

Every table exposed through the Data API must have an intentional access-control design.

For user-owned data, RLS should normally restrict access based on the authenticated user's identity.

Example:

alter table public.example_table
enable row level security;

create policy "Users can access their own records"
on public.example_table
for select
to authenticated
using (auth.uid() = user_id);

RLS policies must be designed according to the actual business rules.

Do not use broad policies such as:

using (true)

for sensitive Hivorr business data unless the exposure is explicitly intended and approved.

9. Sensitive Data

Sensitive information must receive additional protection.

This includes, where applicable:

Government identity documents
Verification documents
Financial information
Payment information
Internal administrative records
Security information
Private user information
Moderation records
Audit information
Confidential business information

Sensitive data must not be exposed through the Data API simply because a table exists in the public schema.

Where appropriate:

Restrict Data API access.
Use RLS.
Use private storage.
Use server-side operations.
Use dedicated schemas.
Restrict administrative access.
Record important access events.
10. Storage Security

Supabase Storage must follow the same security principles as database tables.

Private documents must remain in private buckets.

Public URLs must not be used for sensitive documents.

Storage policies must ensure that users can only access files they are authorized to access.

Administrative access must also be authorization-controlled.

The existence of a file in Supabase Storage does not automatically mean that the file should be publicly accessible.

11. Migration Self-Containment

A migration that creates a new database object should contain the required configuration for that object whenever practical.

For example, a migration creating a table should consider:

Table
├── Columns
├── Constraints
├── Foreign Keys
├── Indexes
├── RLS
├── RLS Policies
├── Data API Grants
├── Functions/RPC dependencies
└── Required permissions

Do not create a table in one migration and rely on undocumented manual Dashboard configuration for its security.

The migration should represent the intended final database state.

12. Local Supabase Reset Requirement

The complete migration history must work correctly with a local Supabase environment.

The following must remain valid:

supabase db reset

A successful reset must recreate the required database structure and security configuration from migrations.

If the application works only because of manual changes made directly to a remote Supabase project, the migration system is considered incomplete.

13. Local, Staging, and Production Consistency

Hivorr must maintain consistent database architecture across:

Local development
Staging
Production

The environments may contain different data and environment-specific configuration, but their database structure and migration history must remain aligned.

Database drift must not be introduced intentionally.

If staging or production requires a database change, that change must first be represented through the approved migration process.

14. Supabase October 30, 2026 Rule

The October 30, 2026 Supabase Data API change must be treated as a permanent engineering rule for Hivorr.

Do not rely on Supabase automatically granting Data API privileges to newly created public tables.

Every new Data API-accessible table must explicitly establish the required grants.

This rule must apply to:

Human developers
AI coding agents
Cursor
CLI workflows
Database migration tools
Automated provisioning
Future engineering teams

The goal is to ensure that a database migration remains correct regardless of which tool created the database object.

15. Do Not Blindly Grant anon

The existence of the anon role does not mean every Hivorr table should be accessible to it.

Before granting access to anon, determine:

Does the application need unauthenticated access?
What operations are required?
What information is exposed?
Is RLS enabled?
Are the RLS policies intentionally designed for anonymous access?
Could the same functionality be implemented through an authenticated or server-side path?

If anonymous access is not required, do not grant it.

16. Do Not Use GRANT as a Security Workaround

A missing grant can produce a Supabase/PostgREST permission error.

Do not solve the error by blindly granting broad permissions.

Before adding a grant:

Identify the exact table or function being accessed.
Identify the role making the request.
Determine whether Data API access is actually intended.
Determine the required operation.
Review RLS.
Review existing policies.
Apply the minimum required grant.
Test the complete request.

A permission error must not automatically result in:

grant all

or broad access to:

anon
authenticated
service_role
17. Database Permission Review

Every new migration must be reviewed for:

Data API exposure
Required grants
RLS
RLS policies
Function permissions
Storage implications
Sensitive information
Ownership rules
Administrative access
Cross-user access
Potential IDOR vulnerabilities
Least-privilege compliance
18. Migration Testing

Before a migration is considered complete, test the following.

Database
Migration applies successfully.
Migration can be rolled forward.
Local database reset succeeds.
Foreign keys work.
Constraints work.
Indexes exist where required.
Data API
Authorized requests succeed.
Unauthorized requests fail.
Anonymous requests behave as intended.
Authenticated requests behave as intended.
Required RPCs work.
Missing grants produce expected failures rather than accidental exposure.
RLS

Test:

User A accessing User A data.
User A accessing User B data.
User B accessing User A data.
Unauthenticated access.
Administrative access where applicable.

The objective is to verify:

Can I access something I should not be able to access?

This test must be performed for every security-sensitive data model.

19. Production Deployment Rule

Never apply an unreviewed database migration directly to production.

Before production deployment:

Migration is version-controlled.
Migration has been reviewed.
Local migration succeeds.
Local reset succeeds.
Staging migration succeeds.
Application behavior is verified.
RLS and grants are verified.
Sensitive-data implications are reviewed.
Production deployment is approved.
Migration is applied through the approved deployment process.
20. Existing Tables

The October 30, 2026 Supabase change does not automatically remove the existing grants from existing tables.

Existing tables retain their current permissions.

Therefore:

Do not mass-rewrite every existing Hivorr table simply because Supabase announced the change.

Instead:

Audit existing tables.
Identify which tables are exposed through the Data API.
Review their grants.
Review their RLS.
Review their policies.
Remove unnecessary exposure where appropriate.
Ensure future migrations use explicit grants.

The objective is controlled improvement, not unnecessary database disruption.

21. Future Migration Standard

Every future migration that creates a Data API-accessible table must explicitly document and configure:

Data API exposure
        ↓
Required PostgreSQL grants
        ↓
RLS enabled
        ↓
RLS policies
        ↓
Function/RPC permissions
        ↓
Security testing

No step should be assumed.

22. AI Coding Agent Rule

AI coding agents must follow this process before making database changes:

Inspect → Reuse → Extend → Refactor → Create only when necessary

Before creating any new database asset, the agent must inspect the existing project for:

Existing tables
Existing columns
Existing relationships
Existing migrations
Existing functions
Existing RPCs
Existing views
Existing policies
Existing grants
Existing storage buckets
Existing storage policies
Existing services
Existing data models
Existing reusable business logic

If a suitable existing implementation exists:

Reuse it.

If it is close but incomplete:

Extend it.

If the existing implementation is structurally unsuitable:

Refactor it where appropriate.

Only create a new implementation when inspection confirms that an existing implementation cannot reasonably be reused or extended.

Do not create duplicate:

Tables
Services
APIs
Functions
Business logic
Models
Policies
Configuration
Workflows

Every new database asset must have a clear reason for existing.

23. Migration Review Checklist

Before approving a database migration, verify:

 Migration is version-controlled.
 Existing reusable database structures were inspected.
 No unnecessary duplicate table was created.
 Relationships are correct.
 Foreign keys are correct.
 Constraints are appropriate.
 Indexes are appropriate.
 RLS is enabled where required.
 RLS policies are correct.
 Data API exposure is intentional.
 Required grants are explicit.
 anon access is justified.
 authenticated access is justified.
 service_role access is justified.
 Function/RPC permissions are reviewed.
 Sensitive information is protected.
 Storage implications are reviewed.
 Local supabase db reset succeeds.
 Staging deployment succeeds.
 Security tests pass.
 Production deployment is approved.
24. Engineering Principle

Hivorr database engineering must follow this principle:

Secure by default. Explicit permissions. Reproducible migrations. Least privilege. RLS by design. Data API exposure must be intentional.

The database must remain:

Secure
Consistent
Auditable
Reproducible
Scalable
Maintainable
Environment-consistent
Compatible with Supabase platform changes

No database implementation should depend on undocumented Supabase defaults.

All important database behavior must be represented in version-controlled engineering artifacts.