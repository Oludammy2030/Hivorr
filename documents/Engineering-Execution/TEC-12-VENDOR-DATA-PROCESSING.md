# TEC-12 — Vendor Data-Processing Record (DRAFT)

> **STATUS: APPROVED FOR STAGING — 8 November 2026.**
> The founder approved this record for the staging vendors and data categories in §2–§4. The items
> marked **[OPEN]** in §5–§10 are accepted as open for staging only and must be closed before any
> production provisioning or before real personal data is collected. This approval does not authorise
> production, identity-document processing, payment-data processing, or any vendor not listed in §2.

## 1. Why this record exists

`TEC-12` (EP-01 entry record §10.3) records that the architecture **chose** vendors but did not
authorise **integration**. Before Supabase, Cloudflare, Fly.io, Doppler or Sentry processes Hivorr
data, the record must state what data leaves the system, where it goes, the legal basis, the
processing terms, the failure behaviour, and the exit path.

This draft covers the vendors needed for the staging ecosystem. Doppler and Sentry are not
integrated and are out of scope.

## 2. Vendors in scope

| Vendor | Role | Service used | Not used |
| --- | --- | --- | --- |
| Supabase | Managed database | PostgreSQL only | Data API, Supabase Auth, Supabase Storage |
| Cloudflare | Edge, DNS, TLS, static hosting, object storage, access control | DNS, TLS, Pages, R2, Access | Workers runtime for the API |
| Fly.io | Application runtime | API process, worker process, private network | Managed Postgres |

Vendor selection is recorded in `ARCHITECTURE.md` §16.4 #1 and #17. This record does not reopen the
choice; it records the processing consequence.

## 3. Data subjects and data categories

| Category | Examples | Where it lives |
| --- | --- | --- |
| Account identifiers | Email address, phone number, account id | Supabase Postgres |
| Authentication data | Password hash, session token hash, refresh-token hash, MFA ciphertext | Supabase Postgres |
| Session metadata | Issued-at, expiry, portal audience, environment, IP, user agent | Supabase Postgres, audit log |
| Profile data | Display name, activity roles, verification status | Supabase Postgres |
| Activity data | Jobs, errands, orders, messages, referrals | Supabase Postgres |
| Governance data | Grants, audit log, outbox events | Supabase Postgres |
| Media objects | Uploaded images and documents | Cloudflare R2 (not yet created) |
| Edge request metadata | IP address, headers, cookies, URL, timing | Cloudflare edge and logs |
| Runtime metadata | Request/response metadata, process logs | Fly.io logs |

**Not yet in scope and not covered by this draft:** identity documents, bank details, payment
credentials, VFD transaction data, and any special-category data. Those require a separate record
before the corresponding feature is enabled.

## 4. Data flows

1. **Browser → Cloudflare edge.** TLS terminates at Cloudflare. Cloudflare can observe request
   metadata, cookies (host-only, `__Host-`, `SameSite=Lax`) and request bodies for `/api/*`.
2. **Cloudflare edge → Fly.io API.** The `/api/*` rewrite forwards the request over TLS to the
   environment's internal Fly.io origin. There is no public API hostname.
3. **API → Supabase Postgres.** The API and worker connect over TLS with a least-privilege role.
   Database credentials are injected at runtime and never baked into an artifact.
4. **API/worker → Cloudflare R2.** Future media reads and writes use the S3-compatible API with a
   staging-only token.
5. **Logs.** Cloudflare and Fly.io retain edge and runtime logs. Logs must not contain passwords,
   tokens, raw cookies, MFA secrets, full request bodies, or connection strings.

No data flows from staging to production. No production credential, bucket, or database is reachable
from staging.

## 5. Vendor roles and processing terms

| Vendor | Role under a processing agreement | Agreement status |
| --- | --- | --- |
| Supabase | Processor for the managed database | **[OPEN]** — founder to accept the current DPA |
| Cloudflare | Processor for edge, storage and access services | **[OPEN]** — founder to accept the current DPA |
| Fly.io | Processor for application runtime | **[OPEN]** — founder to accept the current DPA |

Sub-processors, breach-notification windows, and audit rights are defined by each vendor's current
agreement. The founder must confirm those terms rather than relying on this summary.

## 6. Residency and cross-border transfer

| Item | Recorded state |
| --- | --- |
| Fly.io region | `jnb` (Johannesburg) |
| Supabase project region | **[OPEN]** — confirm the staging project's region before provisioning |
| Cloudflare edge | Global anycast; requests are served from the nearest edge location |
| R2 jurisdiction | **[OPEN]** — choose and record a jurisdiction before creating buckets |
| Cross-border basis | **[OPEN — classify R1–R5]** |

This record does not assert that any transfer is lawful. It records where the data would go so the
founder can decide.

## 7. Legal basis and requirement classification

- Legal basis for account, profile and activity data: **[OPEN — classify R1–R5]**
- Legal basis for security logging (IP, user agent): **[OPEN]**
- Retention periods for audit log, dead letters and logs: **[OPEN]**
- Data-subject request path (access, correction, deletion): **[OPEN]**

No requirement in this section is presented as a legal or regulatory obligation until the founder
classifies it.

## 8. Security controls that apply

| Control | State |
| --- | --- |
| TLS to the database with certificate verification | Implemented in `server/src/db/pool.ts` |
| Least-privilege database roles | Implemented by migration |
| Worker cannot produce outbox events | Enforced by grant |
| No Supabase Data API, Auth or Storage | Configured at the project, to be verified |
| Secrets outside the repository | GitHub environment secrets and runtime injection |
| Private R2 buckets | Required at creation |
| Access protection on privileged hosts | Required at creation |
| No payloads or credentials in worker health output | Implemented and tested |
| Log redaction | **[OPEN]** — verify provider log settings before traffic |

## 9. Failure behaviour

| Failure | Behaviour |
| --- | --- |
| Cloudflare edge unavailable | Hosts unreachable. No fallback to another environment. |
| Fly.io API unavailable | Static bundles still serve; `/api/*` fails. No automatic failover. |
| Supabase unavailable | API readiness fails; worker retries with backoff and dead-letters. No cross-environment failover. |
| R2 unavailable | Media operations fail. No fallback bucket. |
| Staging failure | Staging never falls back to production. |

Single-region, single-instance staging is accepted for the staging ecosystem. Production availability
requirements are out of scope for this record.

## 10. Retention and exit

- Database export: `pg_dump` through the migrator or a read-only role.
- Object export: S3-compatible copy from R2.
- Static applications: rebuilt from the repository at any time.
- Exit: rotate and revoke all credentials, delete vendor resources, and record the deletion.
- Retention periods, legal holds, and deletion evidence: **[OPEN]**.

## 11. Residual risk

1. Cloudflare observes plaintext HTTP at the edge; a DPA is required and not yet accepted.
2. Fly.io holds runtime secrets and can observe process memory; a DPA is required.
3. Supabase holds the full operational database; region and DPA are unconfirmed.
4. Staging runs one instance with no high availability; an outage is an outage, not a failover.
5. Log redaction is not yet verified against real traffic.
6. Identity documents and financial data are not covered by this draft and must not be collected in
   staging until a separate record exists.
7. This draft does not establish legal compliance; it records flows and open decisions.

## 12. Approval

Approval closes `TEC-12` for the vendors and data categories in §2–§4 only.

| Field | Entry |
| --- | --- |
| Approved by | Oludammy2030 (founder account) |
| Role | Founder |
| Date | 8 November 2026 |
| Scope approved | Supabase (Postgres only), Cloudflare (DNS/TLS/Pages/R2/Access), Fly.io (API/worker, `jnb`) |
| Legal basis recorded | No — accepted as open for staging |
| DPAs accepted | No — accepted as open for staging |
| Residency recorded | Partially — Fly `jnb`; Supabase region and R2 jurisdiction open |
| Conditions | Staging only. Close the open items before production or before collecting real personal data. No identity documents or payment data in staging. |

**Founder approval note.** The approval was given explicitly on 8 November 2026 with the open items
above accepted as staging risks. An open item is not resolved by this approval; it is recorded so it
cannot be forgotten. The earlier rule that a blank field prevents closure is superseded for staging
by this explicit acceptance. It still applies to production.

## 13. What approval would and would not authorise

**Would authorise:** creating the staging vendor resources described in `STAGING_PROVISIONING.md`,
within the approved data categories. The former #26 TLS blocker is resolved by the flattened
first-level staging hostnames.

**Would not authorise:** production provisioning, identity-document or payment-data processing, a
public API hostname, cross-environment failover, or any vendor not listed in §2.
