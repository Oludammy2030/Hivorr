# AfriNova — OWASP Application Security Standard

| Field | Value |
| --- | --- |
| **Document** | `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md` |
| **Version** | 1.0 |
| **Date** | 6 November 2026 |
| **Status** | **APPROVED — 6 November 2026. Binding.** Ratified by the founder. The decisions in §8 are recorded in §8.1; parameters expressly left open there remain **[OPEN]**, and the stricter applicable control governs. |
| **Owner** | Founder (AfriNova). Application security content maintained by the architect. |
| **Applies to** | Every AfriNova product, service, API, integration, script and data flow — and every human contributor and AI coding agent that designs, writes, reviews, tests, deploys or documents them. |
| **Review cycle** | Every six months, on any trigger in §7.4, and whenever OWASP publishes a new edition of the Top 10, API Security Top 10 or ASVS. |
| **Companion documents** | `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` (Hivorr), `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `AGENTS.md`, `VISUAL-IDENTITY.md`, `VISION.md` |
| **Framework basis** | OWASP Top 10:2025, OWASP API Security Top 10:2023, OWASP Application Security Verification Standard (ASVS) 5.0.0 |

> **Status note.** This is the company-wide AfriNova application security baseline. It is the
> OWASP-aligned layer that sits above, and is applied through, the Hivorr
> `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`. It does not replace that document, does not
> restate its detailed controls, and does not change any approved product or architecture decision.
>
> **Approval.** The founder ratified version 1.0 on **6 November 2026** with no conditions. The
> eighteen decisions in §8 are recorded in §8.1. Approval does not assert that any product is
> secure, compliant, certified or assessed, and does not approve any product or production release.
>
> It creates no legal, regulatory or contractual obligation, and it certifies nothing. A reference
> to OWASP is a reference, not an assessment. No product, feature, release or team may be described
> as "secure", "compliant", "certified", "hardened" or "production-ready" because this standard was
> followed. Only an independent assessment, within a named scope, can support such a statement, and
> only the founder may authorise it (§8.1, decision 12).
>
> **Precedence.** The Hivorr standards remain the authoritative source for Hivorr engineering and
> security detail. This standard adds AfriNova-wide OWASP obligations and applies to products and
> code outside Hivorr. Where this standard and an approved Hivorr document both apply and differ,
> the stricter control governs; the difference is recorded in the Hivorr standards §15 and in §9 of
> this document, and work that depends on the answer stops until the founder or architect decides
> (§1.4).

---

## How to use this standard

Four reading paths. Read the one that matches what you are about to do.

**Building or changing a feature, API, or integration.**
§1 (scope and precedence) → §2 (normative language and rule IDs) → the control sections in §3 that
your change touches → §4 (OWASP mapping) → §5 (evidence) → §6 if you are an AI agent.

**Changing authentication, authorisation, sessions, credentials, or permissions.**
§1 → §2 → §3.1–§3.4 → §3.13 where personal or financial data is involved → §5 → §6. These are
sensitive changes: they require a second qualified reviewer and pass the gates in §3.12.

**Reviewing a pull request or an agent's work.**
§2 (what MUST means) → the §3 section for the area changed → §3.12 (testing and review) → §5
(evidence) → §6.5 (what an agent report must contain) → §9 (known conflicts).

**Approving a release, a product launch, or an external statement.**
§5 (verification and evidence) → §7 (governance) → §8 (decisions that require the founder) → §10
(approval record). A release record must state which controls were exercised and which were not.

**Resolving a disagreement about what is required.**
§1.4 (precedence and conflict rule) → §7.3 (deviations) → §9 (recorded conflicts) → §8 (open
decisions). Never resolve a conflict by silently following one document.

---

## 1. Purpose, scope and authority

### 1.1 Purpose

**AFS-GOV-01 [MUST]** AfriNova MUST maintain a single, written, enforceable application security
standard that applies to every product it builds or operates.

This document is that standard. It exists so that:

- every application has a common, testable security baseline rather than a per-team interpretation;
- OWASP Top 10, OWASP API Security Top 10 and ASVS obligations are mapped to concrete controls,
  named owners and evidence;
- AI coding agents have an explicit, non-negotiable set of behaviours when they touch security-
  relevant code;
- gaps, exceptions and open decisions are visible instead of being rediscovered as incidents.

### 1.2 Scope

In scope:

- every AfriNova web application, API, mobile or desktop client, background worker, scheduled job,
  CLI tool and integration that processes AfriNova or user data;
- every environment: local, preview, staging, production, and any shared sandbox;
- every contributor: founder, employee, contractor, vendor and AI coding agent;
- every change to source code, configuration, infrastructure, database schema, dependency, secret,
  build pipeline or deployment;
- Hivorr specifically, as the first AfriNova product, including the current React prototype and the
  planned TypeScript API and PostgreSQL data layer.

Out of scope — governed elsewhere, cited rather than restated:

- product direction, activities and business model — `VISION.md`;
- system design, module boundaries and hosting topology — `ARCHITECTURE.md`;
- who may do what inside Hivorr — `Unified-Account-and-Activity-Permission-Matrix.md`;
- SQL mechanics, grants, RLS policy syntax and migration tooling —
  `Database-Migration-and-Supabase-Data-API-Rules.md`;
- visual design and the prototype's authority — the prototype, then `VISUAL-IDENTITY.md`;
- legal, tax, regulatory, funds-custody and KYC/AML interpretation — founder and counsel.

### 1.3 Relationship to the Hivorr engineering standards

The Hivorr `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` (version 2.1, approved 6 November 2026)
is the authoritative source for how Hivorr engineering work is designed, secured, built, tested,
deployed, monitored and governed. It already contains detailed controls for application security
(§4), authentication and authorisation (§5), database and data protection (§6), API security (§7),
environment and deployment security (§9), quality and testing (§10), monitoring and incidents (§11),
AI agent compliance (§12), governance (§13) and audit readiness (§19).

**AFS-GOV-02 [MUST]** This standard MUST be read as the AfriNova-wide baseline that is applied
*through* the Hivorr standards for Hivorr work, and directly for any AfriNova work outside Hivorr.
It MUST NOT be used to bypass, weaken or reinterpret an approved Hivorr rule.

**AFS-GOV-03 [MUST]** Where this standard names a control that the Hivorr standards already define in
more detail, the Hivorr rule remains the implementation reference. This standard adds the OWASP
mapping, the company-wide applicability, the agent trigger list and the evidence expectations.

### 1.4 Precedence and conflict rule

**AFS-GOV-04 [MUST]** Precedence is applied in this order, most specific first:

1. an approved legal, regulatory or contractual obligation, interpreted by counsel;
2. the approved Hivorr document that owns the subject (architecture, permissions, database rules,
   visual identity, engineering standards);
3. this standard;
4. an external framework or reference (OWASP, NIST, vendor documentation).

**AFS-GOV-05 [MUST]** Where two applicable controls differ and neither is clearly more specific, the
**stricter control** governs until the conflict is decided. The stricter control is the one that
reduces the attack surface, grants less privilege, retains less data, or produces more evidence.

**AFS-GOV-06 [MUST]** A material conflict MUST be recorded in §9 of this standard and in the Hivorr
standards §15, and the affected work MUST stop if proceeding would require choosing a side. It MUST
NOT be resolved silently by an agent, a contributor or a reviewer.

**AFS-GOV-07 [MUST]** A conflict is decided by the founder for business, legal, risk-acceptance or
product questions, and by the architect for technical questions that do not change risk acceptance.
The decision, the date, the scope and the reasoning are recorded.

### 1.5 What this standard does not do

**AFS-GOV-08 [MUST NOT]** This standard MUST NOT be represented as a certification, an audit, a
legal opinion, a guarantee of security, or evidence of compliance with any law or regulation.

**AFS-GOV-09 [MUST NOT]** This standard MUST NOT be used to approve a production release, to settle
an **[OPEN]** decision, or to authorise a change to an approved document. Those remain separate acts
by the person who owns them.

**AFS-GOV-10 [MUST]** No control in this standard removes the need for judgement. A control that has
never been exercised is not known to work. Tests, restore drills, alert test-fires and deny-path
exercises are part of the requirement, not optional extras.

---

## 2. Normative language, identifiers and evidence

### 2.1 Normative terms

| Term | Meaning |
| --- | --- |
| **MUST / MUST NOT** | An absolute requirement. A deviation requires an approved, recorded exception under §7.3 before the change merges. |
| **SHOULD / SHOULD NOT** | The expected default. Departing from it requires a written reason in the pull request; no approval is needed. |
| **MAY** | Genuinely optional. Choosing it does not create an obligation. |
| **[FACT]** | A verified property of the repository, a provider or a standard, with the date checked. Not a requirement. |
| **[OPEN]** | Undecided. Not a requirement. Listed in §8 or in the owning document's open-decision register. Nothing may be built as though it were settled. |

### 2.2 Rule identifiers

Rules are cited by identifier, never by section number, so sections can be reorganised without
breaking references. The prefix identifies the control family.

| Prefix | Control family | Section |
| --- | --- | --- |
| `AFS-GOV` | Governance, scope and precedence | §1, §7 |
| `AFS-AUTH` | Authentication and authorization | §3.1 |
| `AFS-AUTHZ` | RBAC, permissions and object-level access | §3.2 |
| `AFS-CRED` | Passwords and credentials | §3.3 |
| `AFS-SESS` | Sessions and tokens | §3.4 |
| `AFS-IO` | Input validation and output encoding | §3.5 |
| `AFS-API` | API and integration security | §3.6 |
| `AFS-DATA` | Database and data access | §3.7 |
| `AFS-CRYPTO` | Encryption and sensitive data | §3.8 |
| `AFS-FILE` | File upload and download | §3.9 |
| `AFS-LOG` | Errors, logging and alerting | §3.10 |
| `AFS-SUPPLY` | Dependencies and supply chain | §3.11 |
| `AFS-TEST` | Security testing and review | §3.12 |
| `AFS-PRIV` | Confidential, financial and personal data | §3.13 |
| `AFS-CONF` | Configuration and secrets | §3.14 |
| `AFS-IR` | Monitoring and incident handling | §3.15 |
| `AFS-AI` | AI coding agent obligations | §6 |

A review comment cites the identifier, for example `AFS-AUTHZ-04`, not "the object-access bit".

### 2.3 Evidence

**AFS-GOV-11 [MUST]** Every control that is claimed MUST have evidence that it exists and operated.
Evidence is produced when the work is done, not reconstructed later. Acceptable evidence includes a
test that fails when the control is removed, a CI gate result, a reviewed configuration file, a
timestamped log or alert record, a signed-off review, or an assessment report.

**AFS-GOV-12 [MUST]** Evidence MUST identify the control, the commit or release, the environment,
the date and the person or pipeline that produced it.

**AFS-GOV-13 [MUST]** A claim that cannot be evidenced MUST be reported as unverified, not softened
into a claim. "Implemented" without a test or a record is not evidence.

---

## 3. Control requirements

The fifteen control areas below are the minimum baseline for every AfriNova application. Each
requirement is normative. The Hivorr implementation detail lives in the section of
`ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` named in the "Implementation reference" line.

### 3.1 Authentication and authorization

*Implementation reference: Hivorr standards §5.1–§5.10.*

**AFS-AUTH-01 [MUST]** Every non-public request MUST be authenticated server-side. A client-side
flag, a stored user object, a route guard, a feature flag or a signed token is never proof of
identity on its own.

**AFS-AUTH-02 [MUST]** Every request MUST also be authorised — for this actor, this action, this
object, in this tenant, now. Authentication without authorisation is a defect.

**AFS-AUTH-03 [MUST NOT]** A control MUST NOT rely on hiding a route, button, field or endpoint.
Hidden UI is usability, not access control.

**AFS-AUTH-04 [MUST]** Each application MUST use one reviewed authentication mechanism. A parallel
login path, a legacy endpoint kept "for testing", or a second token format is prohibited unless it
is an approved deviation.

**AFS-AUTH-05 [MUST]** Registration, credential recovery, email or phone change, MFA enrolment and
MFA reset MUST be treated as authentication-equivalent. They MUST use high-entropy, single-use,
short-lived tokens bound to the account, resist enumeration, and invalidate prior tokens on
completion.

**AFS-AUTH-06 [MUST]** Privileged and administrative authentication MUST require multi-factor
authentication. High-risk actions — payout, bank-account change, role grant, large refund, data
export, secret rotation — MUST require step-up authentication or an equivalent approval control.

**AFS-AUTH-07 [MUST]** Authentication failures MUST return a uniform response that does not reveal
whether the account exists. Authentication endpoints MUST be rate-limited, monitored and alerted on
abuse patterns.

**AFS-AUTH-08 [MUST NOT]** Custom cryptography, a bespoke authentication protocol, or a hand-rolled
token format MUST NOT be introduced. Use a maintained library or identity provider, or record an
approved deviation with a security review.

**AFS-AUTH-09 [MUST]** Authentication events — success, failure, lockout, MFA challenge, recovery,
privilege change — MUST be logged with actor, result, source address, user agent where available,
and a correlation identifier. Secrets and full tokens MUST NOT be logged.

**AFS-AUTH-10 [MUST]** Sign-out MUST invalidate the server-side session or refresh token. Client-side
deletion of a token is not sign-out.

### 3.2 RBAC, permissions and object-level access

*Implementation reference: Hivorr standards §5.5–§5.10 and the permission matrix.*

**AFS-AUTHZ-01 [MUST]** Roles, capabilities and permission names MUST come from the approved
permission model. Code MUST NOT invent, rename or infer a capability.

**AFS-AUTHZ-02 [MUST]** Access control MUST be deny-by-default and least-privilege. An unrecognised
role, a missing permission entry, a failed policy lookup or an unexpected error MUST deny access,
never allow it.

**AFS-AUTHZ-03 [MUST]** Authorisation MUST be enforced in one server-side policy layer, not scattered
across controllers, components or ad-hoc conditionals. Duplicated checks drift and diverge.

**AFS-AUTHZ-04 [MUST]** Every read and write of an object MUST include an ownership, membership or
tenant predicate in the server-side query or policy. Fetching by identifier and then checking
afterwards is not equivalent unless the check is atomic with the read.

**AFS-AUTHZ-05 [MUST]** Function-level authorisation MUST be explicit for every endpoint and every
administrative operation. A valid session MUST NOT imply permission to call any endpoint.

**AFS-AUTHZ-06 [MUST]** Field-level and property-level access MUST be authorised separately where a
record mixes public, confidential and restricted fields. Responses MUST NOT serialise the whole
record and rely on the client to hide fields (mass assignment and excessive data exposure).

**AFS-AUTHZ-07 [MUST]** Role grants, privilege escalation, impersonation and super-admin actions MUST
require an elevated approval, be auditable, and be revocable. Self-service privilege escalation is
prohibited.

**AFS-AUTHZ-08 [MUST]** Administrative and super-administrative roles MUST be privileged platform
roles, never selectable at registration or activity selection, and MUST be subject to separation of
duties where the operation is financially or legally significant.

**AFS-AUTHZ-09 [MUST]** Every allow path and every deny path MUST have a test. A permission control
with only a happy-path test is unverified.

**AFS-AUTHZ-10 [MUST]** Permission changes MUST take effect server-side on the next request and MUST
NOT depend on a client refresh, a cached menu or a token that outlives the revocation window.

### 3.3 Passwords and credentials

*Implementation reference: Hivorr standards §5.2 and §6.6.*

**AFS-CRED-01 [MUST]** Passwords MUST be stored with a memory-hard password hash — Argon2id with
reviewed parameters, or an approved equivalent. Reversible encryption, MD5, SHA-1, SHA-256 and other
fast general-purpose hashes MUST NOT be used for passwords.

**AFS-CRED-02 [MUST]** Password policy MUST prioritise length over composition: a minimum of 12
characters, support for at least 64, no forced composition rules and no forced periodic rotation.
Screened breached-password lists SHOULD be used. Maximum length MUST NOT be truncated below 64
characters.

**AFS-CRED-03 [MUST NOT]** Passwords, one-time codes, recovery tokens, API keys and session
identifiers MUST NOT appear in logs, analytics, error messages, URLs, query strings, client-side
storage in plaintext, source code or test fixtures.

**AFS-CRED-04 [MUST]** Recovery and verification tokens MUST be generated from a cryptographically
secure random source, stored only as a hash, single-use, short-lived, bound to the account and
invalidated on use, expiry or credential change.

**AFS-CRED-05 [MUST]** Authentication endpoints MUST resist brute force, credential stuffing and
enumeration through rate limits, progressive backoff, lockout or equivalent controls, and monitoring.

**AFS-CRED-06 [MUST]** Machine credentials — service accounts, API keys, webhook secrets — MUST be
scoped to the minimum permission, rotatable without a code change, stored in the approved secret
store, and unique per environment and per consumer. Shared static credentials are prohibited.

**AFS-CRED-07 [MUST NOT]** Default, demo, seed or vendor-supplied credentials MUST NOT exist in any
deployed environment. Seed data for local development MUST be clearly non-production and must not
grant production-equivalent access.

**AFS-CRED-08 [MUST]** A password or credential change MUST require the current credential or an
equivalent step-up, and MUST revoke other sessions and outstanding recovery tokens.

**AFS-CRED-09 [MUST]** Credential material MUST be excluded from version control. A secret found in
history is rotated, not merely deleted from the latest commit.

### 3.4 Sessions and tokens

*Implementation reference: Hivorr standards §5.3 and §5.4.*

**AFS-SESS-01 [MUST]** Session identifiers MUST be generated server-side from a cryptographically
secure random source with sufficient entropy, and MUST NOT be predictable, sequential or derived
from user data.

**AFS-SESS-02 [MUST]** Session cookies MUST be `HttpOnly`, `Secure` and `SameSite=Lax` or stricter,
with the narrowest practical `Path` and `Domain`. Long-lived credentials MUST NOT be stored in
`localStorage` or `sessionStorage` where an `HttpOnly` cookie or platform secure storage is
available.

**AFS-SESS-03 [MUST]** The session MUST be rotated on sign-in, on privilege change and on any
suspected compromise. Logout, password change, MFA reset and account disablement MUST invalidate all
active sessions and refresh tokens for that account.

**AFS-SESS-04 [MUST]** Absolute and idle timeouts MUST be defined per audience and enforced
server-side. The policy is approved (§8.1, decision 4); the numeric absolute and idle values remain
**[OPEN]**, and the stricter short default applies until they are recorded.

**AFS-SESS-05 [MUST]** Self-contained tokens MUST be signed with an approved algorithm; the
verifier MUST check signature, algorithm, issuer, audience, expiry and not-before; and a revocation
or short-lifetime strategy MUST exist. `alg: none` and algorithm confusion MUST be rejected.

**AFS-SESS-06 [MUST NOT]** Sensitive data — personal data, financial data, role authority beyond what
is required, secrets — MUST NOT be placed in an unencrypted token or in a URL.

**AFS-SESS-07 [MUST]** Cookie-based state-changing requests MUST be protected against CSRF through
`SameSite`, `Origin`/`Referer` validation and, where needed, a per-session token.

**AFS-SESS-08 [MUST]** Concurrent-session policy, session listing and remote revocation SHOULD be
available for accounts that can move money, change permissions or access restricted data.

**AFS-SESS-09 [MUST]** Client applications MUST store tokens in the platform's secure storage and
MUST NOT embed a secret, a signing key or a privileged API key in a frontend bundle, mobile binary or
desktop package.

**AFS-SESS-10 [MUST]** Session and token failures MUST fail closed. An expired, revoked, malformed
or unverifiable token MUST be rejected, and the rejection MUST be logged without logging the token.

### 3.5 Input validation and output encoding

*Implementation reference: Hivorr standards §4.2–§4.6.*

**AFS-IO-01 [MUST]** All input MUST be validated server-side against an allowlist schema — type,
length, range, format and allowed values. Unknown or unexpected fields MUST be rejected, not ignored
silently.

**AFS-IO-02 [MUST]** Input MUST be canonicalised (Unicode, encoding, case where relevant) before
validation and use. Validation MUST happen at the trust boundary, not only in the browser.

**AFS-IO-03 [MUST]** Every database query MUST be parameterised. String concatenation, interpolation
and template building of SQL are prohibited. Identifiers that cannot be parameterised — table, column,
sort order — MUST be selected from a fixed allowlist.

**AFS-IO-04 [MUST]** Output MUST be encoded for its context: HTML body, HTML attribute, JavaScript,
CSS, URL, SQL, shell, log and JSON each have distinct rules. A single generic escape is insufficient.

**AFS-IO-05 [MUST NOT]** Unsafe sinks MUST NOT receive untrusted data. This includes
`dangerouslySetInnerHTML`, `innerHTML`, `outerHTML`, `document.write`, `eval`, `new Function`,
`setTimeout`/`setInterval` with strings, dynamic `import()` of user input, and raw HTML templating.
A reviewed sanitiser plus an approved deviation is required where HTML rendering is unavoidable.

**AFS-IO-06 [MUST]** Client-supplied prices, totals, fees, discounts, roles, ownership identifiers,
status transitions and timestamps MUST NOT be trusted. The server MUST recompute or re-derive them
from authoritative data.

**AFS-IO-07 [MUST]** Redirects, return URLs, callback URLs and media URLs MUST be validated against
an allowlist. Open redirects are prohibited.

**AFS-IO-08 [MUST]** Deserialisation of untrusted data MUST use a safe format and a schema. Native
object deserialisation, pickle-like formats and unvalidated JSON-to-object binding are prohibited.

**AFS-IO-09 [MUST]** Business-logic limits — quantity, amount, frequency, sequence, ownership,
state-machine transitions — MUST be enforced server-side. Validation of syntax without validation of
business meaning is incomplete.

**AFS-IO-10 [MUST]** Parsers, importers, calculators and state machines SHOULD have negative tests,
boundary tests and, where the input is complex, fuzz or property-based tests.

### 3.6 API and integration security

*Implementation reference: Hivorr standards §7.1–§7.8.*

**AFS-API-01 [MUST]** Every API endpoint — public, partner, internal and service-to-service — MUST
authenticate and authorise the caller. "Internal" is a network location, not an authorisation model.

**AFS-API-02 [MUST]** Object-level authorisation (BOLA) and function-level authorisation (BFLA) MUST
be enforced on every endpoint and every method. An endpoint that accepts an object identifier MUST
prove the caller may act on that specific object.

**AFS-API-03 [MUST]** Requests MUST be schema-validated, size-limited and content-type-checked before
processing. Unsupported methods and content types MUST be rejected.

**AFS-API-04 [MUST]** Rate limits and quotas MUST exist per identity, per source and per endpoint
class, including limits on page size, query depth, batch size, upload size and expensive operations.
The policy is approved (§8.1, decision 6); the numeric thresholds remain **[OPEN]** until they are
set from staging measurements. Conservative defaults apply meanwhile.

**AFS-API-05 [MUST]** Every endpoint MUST be inventoried with an owner, version, exposure level and
documented contract. Shadow, debug, deprecated-but-reachable and undocumented endpoints are
prohibited in production. Deprecated endpoints MUST be removed, not merely hidden.

**AFS-API-06 [MUST]** CORS MUST deny by default and allow only named origins, methods and headers.
Wildcard origins MUST NOT be combined with credentials.

**AFS-API-07 [MUST]** Error responses MUST be uniform and MUST NOT reveal stack traces, SQL, internal
hostnames, library versions, secrets or object existence.

**AFS-API-08 [MUST]** Webhooks and callbacks MUST verify a signature or shared secret, check a
timestamp or nonce to prevent replay, be idempotent, and reject unsigned or stale requests.

**AFS-API-09 [MUST]** Outbound requests to user-supplied or third-party URLs MUST be protected against
SSRF: scheme allowlist, host allowlist where possible, blocked private, link-local, loopback and
cloud-metadata addresses, and DNS-rebinding resistance.

**AFS-API-10 [MUST]** Responses from third-party APIs MUST be treated as untrusted: validate the
schema, enforce timeouts, verify TLS, limit response size and handle malformed data without crashing
or leaking.

**AFS-API-11 [MUST]** Sensitive business flows — sign-up bonuses, refunds, payouts, resale, referrals,
booking, bidding — MUST have anti-automation, velocity and step-up controls proportionate to the
financial or abuse risk.

**AFS-API-12 [MUST NOT]** API keys, tokens and session identifiers MUST NOT be accepted in query
strings where a header or cookie is available.

**AFS-API-13 [MUST]** Machine-to-machine callers MUST use scoped credentials, rotation, IP or network
restrictions where available, and an auditable identity — not a shared human account.

### 3.7 Database and data access

*Implementation reference: Hivorr standards §6.1–§6.12 and the database rules.*

**AFS-DATA-01 [MUST]** All data access MUST go through the approved server-side access path. A
privileged database key, service-role key or direct database connection MUST NOT be exposed to a
client.

**AFS-DATA-02 [MUST]** Database roles MUST be least-privilege and separated: the runtime application
role MUST NOT own schema changes, and migration credentials MUST NOT be available to the application
at runtime.

**AFS-DATA-03 [MUST]** Row-level security, policy enforcement or an equivalent tenant/ownership
control MUST protect every table that holds personal, confidential or financial data. Policies MUST
deny by default and MUST be tested on both allow and deny paths.

**AFS-DATA-04 [MUST]** Raw SQL MUST be parameterised; ORM escape hatches and raw fragments MUST be
reviewed and justified. Database functions and views MUST NOT bypass the caller's authorisation.

**AFS-DATA-05 [MUST]** Database errors MUST be translated at the boundary. Clients receive a safe
message and a correlation identifier, never the driver error.

**AFS-DATA-06 [MUST]** Schema migrations MUST be reviewed, versioned, reproducible and reversible
where the platform allows. Destructive changes require a backup, a rollback plan and the approval
class the Hivorr standards assign.

**AFS-DATA-07 [MUST]** Backups MUST be encrypted, access-controlled, retained per policy and restore-
tested. An untested backup is not a backup.

**AFS-DATA-08 [MUST]** Retention and deletion MUST be defined per data class and enforced in code and
in the database. Legal hold and audit-retention obligations override deletion where counsel requires.

**AFS-DATA-09 [MUST]** Production data MUST NOT be copied to a lower environment without masking or
explicit approval. Test fixtures MUST NOT contain real personal or financial data.

**AFS-DATA-10 [MUST]** Database access by humans MUST be exceptional, time-boxed, logged and
approved. Standing production access is prohibited.

### 3.8 Encryption and sensitive data

*Implementation reference: Hivorr standards §6.7–§6.9.*

**AFS-CRYPTO-01 [MUST]** All network communication that carries credentials, personal data or
financial data MUST use TLS 1.2 or later, with TLS 1.3 preferred. Plain HTTP, opportunistic
downgrade and disabled certificate verification are prohibited. HSTS SHOULD be enabled on public
hosts.

**AFS-CRYPTO-02 [MUST]** Only approved, current algorithms and modes MAY be used. MD5, SHA-1 for
security purposes, DES/3DES, RC4, ECB mode, static IVs and custom cryptography are prohibited.

**AFS-CRYPTO-03 [MUST]** Sensitive data at rest — personal data, identity documents, bank details,
credentials, financial records — MUST be encrypted or stored in a service that provides equivalent
protection. Backups and snapshots inherit the same requirement.

**AFS-CRYPTO-04 [MUST]** Keys MUST be generated, stored, rotated and revoked through the approved key
or secret management mechanism. Keys MUST NOT be committed, logged, embedded in images, shared across
environments or reused for multiple purposes.

**AFS-CRYPTO-05 [MUST]** Data MUST be classified before controls are chosen. The minimum classes are
public, internal, confidential and restricted; restricted includes credentials, KYC material, bank
details and full financial records. The control applied MUST match the class.

**AFS-CRYPTO-06 [MUST]** Data collection MUST be minimised. Sensitive values SHOULD be masked,
tokenised or truncated where the full value is not required, and displayed masked by default.

**AFS-CRYPTO-07 [MUST]** Random values used for security — tokens, identifiers, salts, nonces, keys
— MUST come from a cryptographically secure random number generator.

**AFS-CRYPTO-08 [MUST]** Cryptographic operations MUST fail closed. There MUST be no silent fallback
to a weaker algorithm, a default key or plaintext.

**AFS-CRYPTO-09 [MUST]** Access to restricted data MUST be authorised, logged and periodically
reviewed. Bulk export of restricted data requires a named approver and a recorded purpose.

**AFS-CRYPTO-10 [MUST]** Key rotation and certificate expiry MUST be monitored. An expired or
compromised key is an incident, not a routine maintenance task.

### 3.9 File upload and download

*Implementation reference: Hivorr standards §4.7.*

**AFS-FILE-01 [MUST]** Uploads MUST be validated by content inspection and an allowlist of permitted
types — not by file extension or client-supplied `Content-Type` alone. A file whose detected type
differs from its declared type MUST be rejected.

**AFS-FILE-02 [MUST]** Uploads MUST enforce size, count, dimension and decompression limits. Archive
files MUST be inspected for traversal, bombs and nested content before extraction.

**AFS-FILE-03 [MUST]** Uploaded files MUST be stored outside the application web root, or in object
storage, under server-generated random names. They MUST NOT be stored with executable permissions or
in a directory that serves code.

**AFS-FILE-04 [MUST]** User-supplied content MUST be served with safe headers: an explicit
`Content-Type`, `X-Content-Type-Options: nosniff`, a restrictive `Content-Disposition`, and a
sandboxing CSP where the content can be rendered. Untrusted content SHOULD be served from a separate
cookieless origin.

**AFS-FILE-05 [MUST]** Untrusted uploads SHOULD be malware-scanned. Where scanning is not available,
the file MUST be quarantined, access-restricted and flagged for review before it is served to other
users.

**AFS-FILE-06 [MUST]** Every download MUST be authorised against the requesting actor and the specific
object. Predictable public URLs and directory listing are prohibited. Time-limited signed URLs MUST
be short-lived and scoped.

**AFS-FILE-07 [MUST]** Metadata that is not required — EXIF location, device identifiers, document
author metadata — MUST be stripped or rewritten on upload where the file is redistributed.

**AFS-FILE-08 [MUST]** Paths MUST be canonicalised and confined to the intended directory. Path
traversal, absolute paths and null-byte tricks MUST be rejected.

**AFS-FILE-09 [MUST]** Upload rejection, quarantine and malware findings MUST be logged and alerted.
Repeated attempts by an identity MUST feed the abuse controls.

### 3.10 Errors, logging and alerting

*Implementation reference: Hivorr standards §4.9 and §11.1–§11.4.*

**AFS-LOG-01 [MUST]** External error responses MUST be uniform, non-verbose and safe. They MUST NOT
contain stack traces, SQL, internal paths, hostnames, library versions, secrets or personal data. A
correlation identifier SHOULD be returned for support.

**AFS-LOG-02 [MUST]** Security-relevant events MUST be logged: authentication success and failure,
authorisation denial, privilege and role change, admin action, configuration change, secret access,
data export, financial transaction, upload rejection and webhook verification failure.

**AFS-LOG-03 [MUST]** Logs MUST be structured, timestamped in UTC, access-controlled, tamper-resistant
and retained for a defined period. The retention policy is approved (§8.1, decision 8); the numeric
periods remain **[OPEN]**. Until they are set, logs are retained and not purged.

**AFS-LOG-04 [MUST NOT]** Logs MUST NOT contain passwords, one-time codes, tokens, full card numbers,
full bank account numbers, full identity-document numbers, secret keys or unnecessary personal data.
Redaction MUST happen before the log entry is written.

**AFS-LOG-05 [MUST]** Untrusted values in logs MUST be encoded to prevent log injection and forged
entries.

**AFS-LOG-06 [MUST]** High-risk patterns MUST alert to a named owner: authentication anomalies,
spikes in authorisation denials, injection attempts, mass data access, payout anomalies, dependency
or secret findings, and error-rate spikes.

**AFS-LOG-07 [MUST]** Audit records MUST be append-only, separated from application logs, integrity-
protected and readable by an authorised auditor. They MUST record who did what, to which object,
when, from where and with what result.

**AFS-LOG-08 [MUST]** A failure in the logging pipeline MUST NOT silently disable security logging.
Pipeline health MUST be monitored, and the security consequence of a gap MUST be treated as an
incident.

**AFS-LOG-09 [MUST]** Systems MUST use synchronised time sources so that event ordering is reliable.

**AFS-LOG-10 [MUST]** Alerting MUST be test-fired. An alert that has never fired is not known to
work.

### 3.11 Dependencies, supply chain and vulnerabilities

*Implementation reference: Hivorr standards §3.4, §4.12 and §11.5.*

**AFS-SUPPLY-01 [MUST]** Dependencies MUST be pinned exactly and installed from a committed lockfile.
CI MUST install from the frozen lockfile; a build that resolves a different tree than the one reviewed
is not the reviewed build.

**AFS-SUPPLY-02 [MUST]** A new dependency MUST be justified: the problem it solves, why existing code
or an approved package cannot, its maintenance status, its licence, its transitive tree and whether it
runs install scripts. Dependencies with install scripts require explicit review.

**AFS-SUPPLY-03 [MUST]** Automated dependency and secret scanning MUST run on every change and on a
schedule. A High or Critical known vulnerability or a committed secret MUST fail the build.

**AFS-SUPPLY-04 [MUST]** Vulnerabilities MUST be remediated within severity-based SLAs owned by a
named person, or recorded as accepted risk with an owner and an expiry. The approved SLAs are
**7 days for Critical, 30 days for High and 90 days for Medium**; Low is scheduled in the next review
cycle (§8.1, decision 3).

**AFS-SUPPLY-05 [MUST NOT]** End-of-life, unmaintained, typosquatted or unverified packages MUST NOT
be added. Package provenance and registry identity MUST be confirmed before adoption.

**AFS-SUPPLY-06 [MUST]** An SBOM SHOULD be generated per release and retained with the artifact
digest. Release artifacts SHOULD be signed or integrity-verified where the platform supports it.

**AFS-SUPPLY-07 [MUST]** Builds MUST run in a trusted CI environment with least-privilege tokens.
Unreviewed local artifacts MUST NOT be promoted to production.

**AFS-SUPPLY-08 [MUST NOT]** Code MUST NOT be fetched and executed at runtime from an untrusted
source. Build-time generation from a pinned, reviewed source is permitted.

**AFS-SUPPLY-09 [MUST]** Every accepted vulnerability risk MUST name the finding, the affected
component, the compensating control, the owner and the expiry. An exception without an expiry is a
permanent hole.

### 3.12 Security testing and review

*Implementation reference: Hivorr standards §10.4–§10.8 and §19.9.*

**AFS-TEST-01 [MUST]** Every new or changed security control MUST have a test that fails if the
control is removed. Happy-path testing alone does not verify a control.

**AFS-TEST-02 [MUST]** Authentication, authorisation, permission and financial modules MUST test both
the allow and the deny branch. The coverage gate for these modules is an **[OPEN]** architect decision;
branch coverage of every allow/deny path is the interim expectation.

**AFS-TEST-03 [MUST]** Static analysis, dependency scanning and secret scanning MUST run in CI. A
failing security gate MUST block merge.

**AFS-TEST-04 [MUST]** A dynamic assessment or penetration test MUST be completed before the first
public release, annually thereafter and on a major change. The cadence is approved (§8.1, decision
10); the vendor remains **[OPEN]**.

**AFS-TEST-05 [MUST]** A threat model MUST be produced for a new attack surface, a new data flow, a
new integration or a change to trust boundaries. It MUST name the assets, actors, entry points,
threats, mitigations and residual risks.

**AFS-TEST-06 [MUST]** A sensitive change MUST be reviewed by a second qualified reviewer who is not
its author. Sensitive includes authentication, authorisation, permissions, cryptography, secrets,
database policy, financial logic, file handling and dependency additions.

**AFS-TEST-07 [MUST NOT]** A security gate MUST NOT be bypassed, disabled, skipped or marked passed
without evidence. A bypass is an incident.

**AFS-TEST-08 [MUST]** Test results and security evidence MUST be retained with the commit or release
they belong to, reproducible from the recorded command, and dated.

**AFS-TEST-09 [MUST]** AI-generated code MUST be reviewed, tested and evidenced exactly like
human-authored code. The author's identity does not lower the bar.

**AFS-TEST-10 [MUST]** Security defects found in review MUST be fixed or recorded as accepted risk
before merge. "Will fix later" without a record is prohibited.

### 3.13 Confidential, financial and personal data

*Implementation reference: Hivorr standards §6.8–§6.11 and §19.5–§19.7.*

**AFS-PRIV-01 [MUST]** Each application MUST maintain a data inventory that names every category of
personal, confidential and financial data it processes, where it is stored, who can access it, how
long it is kept and which third parties receive it.

**AFS-PRIV-02 [MUST]** Personal data MUST be collected only for a stated purpose, limited to what the
purpose requires, and not reused for an incompatible purpose without a new assessment and approval.

**AFS-PRIV-03 [MUST]** Access to personal, confidential and financial data MUST be least-privilege,
need-to-know and logged. Bulk access and export MUST require an approver and a recorded purpose.

**AFS-PRIV-04 [MUST]** Financial values and state transitions MUST be computed and enforced
server-side. Client-supplied totals, fees, balances, rates or statuses MUST NOT be trusted. Financial
operations MUST be idempotent, reconciled and recorded in an append-only ledger or audit trail.

**AFS-PRIV-05 [MUST NOT]** Personal or financial data MUST NOT appear in logs, analytics, crash
reports, error messages, URLs or test fixtures beyond what the control requires. Where it must appear,
it is masked, tokenised or redacted.

**AFS-PRIV-06 [MUST]** Retention, deletion, export and correction obligations MUST be implemented as
code and database policy, and exercised by a test or drill. Legal hold and audit-retention obligations
take precedence where counsel requires.

**AFS-PRIV-07 [MUST]** Third-party sharing MUST be minimised, contracted, documented and limited to
the fields required. A processor or sub-processor MUST NOT receive more data than the integration
needs.

**AFS-PRIV-08 [MUST]** Cross-border storage and transfer MUST follow the jurisdiction decision made by
the founder with counsel. It MUST NOT be assumed from a provider's default region.

**AFS-PRIV-09 [MUST]** Restricted data — identity documents, KYC material, bank details, credentials,
full financial records — MUST be encrypted, access-restricted, masked in the UI and logged on access.

**AFS-PRIV-10 [MUST]** Every privacy or financial requirement that is relied on MUST be classified as
R1–R5 under the Hivorr standards §19.2. A recommendation MUST NOT be presented as a legal, regulatory
or VFD requirement.

**AFS-PRIV-11 [MUST NOT]** A product MUST NOT claim compliance with a privacy or financial regime
because these controls were applied. Applicability and compliance are counsel and assessment
questions, and remain **[OPEN]** until decided.

### 3.14 Configuration and secrets

*Implementation reference: Hivorr standards §9.1–§9.6 and §7.8.*

**AFS-CONF-01 [MUST NOT]** Secrets MUST NOT be committed to source control, embedded in frontend
bundles, baked into container images, written to logs or stored in tickets and chat. Secret scanning
MUST run in CI and on the repository history.

**AFS-CONF-02 [MUST]** Secrets MUST be stored in the approved secret manager, scoped per environment
and per service, rotatable without a code change and revocable. The policy is approved (§8.1,
decision 5); the provider and rotation intervals remain **[OPEN]**.

**AFS-CONF-03 [MUST]** Environments MUST be separated by credentials, data and network boundary.
Production credentials MUST NOT be usable from local or preview environments.

**AFS-CONF-04 [MUST]** Secure defaults MUST be the default: debug mode, verbose errors, directory
listing, permissive CORS, default accounts and sample endpoints MUST be disabled in production.

**AFS-CONF-05 [MUST]** Public hosts MUST serve the approved security headers: a Content Security
Policy, HSTS where HTTPS is permanent, `X-Content-Type-Options: nosniff`, a `Referrer-Policy`, a
frame restriction and a restrictive `Permissions-Policy`. The header posture is approved (§8.1,
decision 7); `style-src 'unsafe-inline'` is permitted only as a recorded, time-boxed exception
while the prototype's inline styles remain.

**AFS-CONF-06 [MUST]** Infrastructure MUST be defined as code where the platform supports it, reviewed
like application code, and checked for drift. Cloud and CI roles MUST be least-privilege.

**AFS-CONF-07 [MUST]** Configuration changes that affect security — headers, CORS, auth, secrets,
logging, feature flags — MUST be reviewed, approved and audited. A feature flag MUST NOT be used as an
authorisation control.

**AFS-CONF-08 [MUST]** Error pages, health endpoints, metrics and diagnostic routes MUST expose the
minimum information and MUST NOT be publicly reachable without need.

**AFS-CONF-09 [MUST]** Builds and deployments MUST be reproducible from recorded inputs. A manual,
undocumented production change is prohibited except under the emergency-change rule.

**AFS-CONF-10 [MUST]** A leaked secret MUST be rotated immediately, the exposure scoped, and an
incident opened. Deleting the secret from the latest commit does not close the exposure.

### 3.15 Monitoring and incident handling

*Implementation reference: Hivorr standards §11.1–§11.7.*

**AFS-IR-01 [MUST]** Every production system MUST have centralised monitoring, alerting and a named
owner. Alerts MUST route to a person or rotation that can act.

**AFS-IR-02 [MUST]** Monitoring MUST cover, at minimum: availability, error rate, authentication
anomalies, authorisation-denial spikes, injection and abuse patterns, mass data access, payout and
financial anomalies, dependency and secret findings, certificate and key expiry, and backup success.

**AFS-IR-03 [MUST]** An incident severity model, runbooks and contact list MUST exist. The
four-level severity model and a named owner per severity are approved (§8.1, decision 9); the named
on-call rota and response times remain **[OPEN]**.

**AFS-IR-04 [MUST]** Incident response MUST include containment, eradication, recovery and evidence
preservation. Evidence MUST be captured before systems are rebuilt or logs are purged.

**AFS-IR-05 [MUST]** Notification obligations — to regulators, affected users, partners and payment
providers — MUST follow counsel's direction and the applicable legal timeline. An agent or contributor
MUST NOT make a notification decision or a public statement on behalf of AfriNova.

**AFS-IR-06 [MUST]** Every incident MUST have a post-incident review that identifies root cause,
contributing factors, detection gap and corrective actions with owners and dates. Reviews are
blameless.

**AFS-IR-07 [MUST]** Alerting and incident response MUST be exercised at least annually through a
test fire or tabletop exercise.

**AFS-IR-08 [MUST]** Incident records MUST be retained, access-controlled and minimised. They MUST NOT
become an uncontrolled copy of personal or financial data.

**AFS-IR-09 [MUST]** Third-party and supply-chain incidents MUST be covered by the same process, with
the provider's notification terms and AfriNova's obligations confirmed in advance.

**AFS-IR-10 [MUST]** A vulnerability MUST be reported through the approved private channel and MUST
NOT be publicly disclosed, demonstrated or replicated outside the minimum needed to fix it without
founder approval.

---

## 4. OWASP mapping

The tables below connect this standard's control families to the OWASP frameworks. They are a
navigation and coverage aid. They are **not** a claim of compliance, a verification result or evidence
that a control operates. A mapping says where a requirement is addressed, not that it has been
achieved.

### 4.1 OWASP Top 10:2025

**[FACT]** The current OWASP Top 10 is the **2025** edition; the 2021 edition is superseded
(checked 6 November 2026).

| OWASP 2025 category | Primary control families | Hivorr implementation reference |
| --- | --- | --- |
| **A01 Broken Access Control** | §3.2 AUTHZ, §3.6 API | standards §5.5–§5.10, permission matrix |
| **A02 Security Misconfiguration** | §3.14 CONF, §3.10 LOG | standards §4.10, §9.2, database rules |
| **A03 Software Supply Chain Failures** | §3.11 SUPPLY | standards §3.4, §4.12 |
| **A04 Cryptographic Failures** | §3.8 CRYPTO, §3.4 SESS | standards §6.7, §5.3 |
| **A05 Injection** | §3.5 IO, §3.7 DATA | standards §4.2, §4.3, §6.2 |
| **A06 Insecure Design** | §3.1 AUTH, §3.2 AUTHZ, §3.13 PRIV | standards §2.1, §4.1, §13.1 |
| **A07 Authentication Failures** | §3.1 AUTH, §3.3 CRED, §3.4 SESS | standards §5.1–§5.6 |
| **A08 Software or Data Integrity Failures** | §3.11 SUPPLY, §3.14 CONF, §3.6 API | standards §4.12, §7.8, §9.6 |
| **A09 Security Logging and Alerting Failures** | §3.10 LOG, §3.15 IR | standards §11.1–§11.4 |
| **A10 Mishandling of Exceptional Conditions** | §3.10 LOG, §3.5 IO, §3.15 IR | standards §4.9, §2.5, §7.2 |

### 4.2 OWASP API Security Top 10:2023

**[FACT]** The current OWASP API Security Top 10 is the **2023** edition (checked 6 November 2026).

| API category | Primary control families | Specific requirements |
| --- | --- | --- |
| **API1 Broken Object Level Authorization** | §3.2 AUTHZ, §3.6 API | AFS-AUTHZ-04, AFS-API-02 |
| **API2 Broken Authentication** | §3.1 AUTH, §3.3 CRED, §3.4 SESS | AFS-AUTH-01–10, AFS-CRED-05, AFS-SESS-01–10 |
| **API3 Broken Object Property Level Authorization** | §3.2 AUTHZ, §3.5 IO | AFS-AUTHZ-06, AFS-IO-06 |
| **API4 Unrestricted Resource Consumption** | §3.6 API, §3.15 IR | AFS-API-03–04, AFS-IR-02 |
| **API5 Broken Function Level Authorization** | §3.2 AUTHZ, §3.6 API | AFS-AUTHZ-05, AFS-API-01–02 |
| **API6 Unrestricted Access to Sensitive Business Flows** | §3.6 API, §3.13 PRIV | AFS-API-11, AFS-PRIV-04 |
| **API7 Server-Side Request Forgery** | §3.6 API, §3.14 CONF | AFS-API-09 |
| **API8 Security Misconfiguration** | §3.14 CONF | AFS-CONF-01–10 |
| **API9 Improper Inventory Management** | §3.6 API | AFS-API-05 |
| **API10 Unsafe Consumption of APIs** | §3.6 API, §3.11 SUPPLY | AFS-API-10, AFS-SUPPLY-02–05 |

### 4.3 OWASP ASVS 5.0.0

**[FACT]** ASVS **5.0.0** was published on 30 May 2025. The chapter titles and numbering below are
the 5.0 structure (checked 6 November 2026).

The ASVS target is **decided** (§8.1, decision 2): **Level 2 for every product**, with **Level 3
for authentication, administration, financial and restricted-data surfaces**. The per-surface
mapping is applied at design time and recorded with the surface's threat model.

| ASVS 5.0 chapter | Relevance | Primary control families |
| --- | --- | --- |
| **V1 Encoding and Sanitization** | Output encoding, injection defence | §3.5 IO |
| **V2 Validation and Business Logic** | Input validation, business rules | §3.5 IO, §3.13 PRIV |
| **V3 Web Frontend Security** | Browser controls, CSP, framing, client storage | §3.5 IO, §3.14 CONF |
| **V4 API and Web Service** | API auth, methods, content types, rate limits | §3.6 API |
| **V5 File Handling** | Upload, download, storage | §3.9 FILE |
| **V6 Authentication** | Identity proofing, credentials, recovery | §3.1 AUTH, §3.3 CRED |
| **V7 Session Management** | Session lifecycle, cookies, logout | §3.4 SESS |
| **V8 Authorization** | Roles, object and function access | §3.2 AUTHZ |
| **V9 Self-contained Tokens** | JWT and similar token validation | §3.4 SESS |
| **V10 OAuth and OIDC** | Delegated authorisation and identity | §3.1 AUTH, §3.4 SESS |
| **V11 Cryptography** | Algorithms, randomness, key management | §3.8 CRYPTO |
| **V12 Secure Communication** | TLS, HSTS, certificate validation | §3.8 CRYPTO |
| **V13 Configuration** | Secure defaults, headers, environment separation | §3.14 CONF |
| **V14 Data Protection** | Classification, retention, privacy, integrity | §3.13 PRIV, §3.7 DATA |
| **V15 Secure Coding and Architecture** | Threat modelling, design, dependency integrity | §1, §3.11 SUPPLY, §3.12 TEST |
| **V16 Security Logging and Error Handling** | Logging, audit, error safety, alerting | §3.10 LOG, §3.15 IR |
| **V17 WebRTC** | Only if real-time media is introduced | Out of scope until a WebRTC surface is approved |

### 4.4 What the mapping does and does not mean

**AFS-GOV-14 [MUST]** A gap identified against any framework MUST be recorded as a gap, with an owner
and a remediation decision. It MUST NOT be closed by editing the mapping table.

**AFS-GOV-15 [MUST NOT]** A mapping MUST NOT be cited as evidence of compliance, certification or
technical verification.

**AFS-GOV-16 [MUST]** When OWASP publishes a new edition, this section MUST be reviewed and the
version and review date updated in §10.

---

## 5. Verification, evidence and current state

### 5.1 Evidence per control family

| Control family | Minimum evidence |
| --- | --- |
| §3.1–§3.4 Identity, access, credentials, sessions | Allow and deny tests; policy test output; reviewed configuration; auth event log sample |
| §3.5 Input and output | Validator tests; injection and XSS regression tests; static analysis result |
| §3.6 API | Endpoint inventory; contract tests; authorisation tests per object and function; rate-limit test |
| §3.7–§3.8 Data and cryptography | Policy tests; encryption configuration; key rotation record; migration review; restore drill |
| §3.9 Files | Upload rejection tests; served-header test; download authorisation test |
| §3.10–§3.11 Logging and supply chain | Alert test-fire; log redaction test; dependency and secret scan result; SBOM; remediation record |
| §3.12 Testing and review | CI run; coverage report for sensitive modules; threat model; second-reviewer approval |
| §3.13 Privacy and financial | Data inventory; access log; reconciliation result; retention/deletion test; R1–R5 classification |
| §3.14–§3.15 Configuration and incidents | Header scan; secret-manager configuration; incident record; post-incident review |

### 5.2 Definition of done for a security-relevant change

A change is complete only when all of the following are true:

1. The existing control in the touched area was inspected and is preserved or deliberately improved.
2. The applicable `AFS-` requirements are identified and satisfied, or a deviation is approved.
3. A test fails if the control is removed, and the deny path is covered.
4. A second qualified reviewer approved the change where §3.12 requires it.
5. Evidence is recorded with commit, environment and date.
6. Any new gap, conflict or **[OPEN]** decision is recorded rather than hidden.
7. The change does not weaken authentication, authorisation, logging, encryption or data minimisation
   anywhere else in the system.

### 5.3 Current implementation state — Hivorr, 6 November 2026

**[FACT]** The following reflects the repository as inspected on 6 November 2026. It is a status
record, not a requirement and not a certification.

| Area | State |
| --- | --- |
| Dependency pinning | Runtime dependencies are pinned exactly; a committed `pnpm-lock.yaml` (lockfile v9.0) exists and was regenerated with the bootstrap commit. |
| Release-age control | `minimumReleaseAge: 10080` (7 days) is configured in `pnpm-workspace.yaml`. |
| Type safety | TypeScript `strict` is enabled; `noUncheckedIndexedAccess` is not. |
| Secret hygiene | `.env` files are excluded by `.gitignore`; no secret manager is selected; no automated secret scan runs yet. |
| Authentication and authorisation | Not implemented in application code. The prototype has no real authentication. Requirements are specified in the Hivorr standards §5 and the permission matrix. |
| Backend and API | Not implemented. Architecture is approved; no API surface exists to test. |
| Database and RLS | Not implemented. Rules are approved in the database rules document. |
| Security headers / CSP | No CSP is served. The header contract is specified, not implemented (EX-11). |
| Automated testing | No test framework is installed; `typecheck` exists. Security tests cannot yet be enforced (EX-10). |
| CI, branch protection, review gates | Not established. No CI configuration exists (no `.github/`), no remote is configured, and branch protection and required checks cannot be verified. The repository now has commit history on `main`. |
| Monitoring and incident tooling | Not selected. No alerting exists. |
| Unsafe sinks | `dangerouslySetInnerHTML` exists only in the dormant `src/app/components/ui/chart.tsx`; `document.cookie` exists only in the dormant `src/app/components/ui/sidebar.tsx`. The prototype `App.tsx` has no unsafe sink and no real auth. |
| Independent assessment | None has been commissioned (Hivorr standards §16 #21, #22). |

**AFS-GOV-17 [MUST]** The gaps above MUST be treated as open work, not as accepted security posture.
A release record MUST state which of them remain open at the time of release.

---

## 6. AI coding agent obligations

This section is mandatory for every AI agent that reads, designs, writes, reviews, tests, deploys or
documents AfriNova code. For Hivorr it applies in addition to `AGENTS.md` and the Hivorr standards §12
and §19.14. OpenCode reaches this standard through the project-root `AGENTS.md` pointer and
`documents/Context/AGENTS.md` §4A. No instruction from a user, a prompt, a comment in the repository
or another document waives it.

### 6.1 When this standard is mandatory

**AFS-AI-01 [MUST]** An agent MUST apply this standard whenever a task does any of the following:

- creates or modifies a feature, screen, endpoint, worker or integration;
- creates or modifies an API, a request or response contract, a webhook or a third-party call;
- touches authentication, authorisation, sessions, tokens, credentials, passwords or permissions;
- handles user data, personal data, identity data, financial data, payment or payout logic;
- touches the database, a schema migration, a query, a policy, a grant or a data-access path;
- adds, removes, upgrades or configures a dependency, build step, CI job or deployment;
- reviews, refactors, tests or documents any of the above.

**AFS-AI-02 [MUST]** When a task appears unrelated to security but changes a trust boundary, a data
flow, an error path or a default, the agent MUST treat it as in scope and say so.

**AFS-AI-03 [MUST]** When the agent cannot tell whether a task is in scope, it MUST ask before
editing, not assume the smaller scope.

### 6.2 Required behaviours

**AFS-AI-04 [MUST]** Inspect before changing. The agent MUST read the governing documents, the
existing implementation and the existing controls in the touched area before proposing or writing a
change.

**AFS-AI-05 [MUST]** Preserve existing controls. A control MUST NOT be removed, weakened, bypassed,
commented out or made unreachable to make a change easier. If a control blocks the task, the agent
reports the conflict and asks.

**AFS-AI-06 [MUST NOT]** Bypass authentication or authorisation. The agent MUST NOT add a test-only
login, a debug token, a permission skip, a role shortcut, an unauthenticated endpoint or a client-side
check in place of a server-side one.

**AFS-AI-07 [MUST NOT]** Expose secrets. The agent MUST NOT print, copy, commit, log, echo or place in
a prompt any credential, token, key or connection string. If a secret is encountered, it reports the
location and type only, and recommends rotation.

**AFS-AI-08 [MUST NOT]** Introduce an insecure pattern or dependency. The agent MUST NOT add a
dependency with a known High or Critical vulnerability, an unmaintained package, an unreviewed install
script, a custom crypto primitive or an unsafe sink.

**AFS-AI-09 [MUST]** Assess architectural security impact. Before changing a trust boundary, data
flow, permission model or integration, the agent MUST state the asset, the actor, the entry point,
the threat, the control and the residual risk, and MUST record it under the Hivorr standards §19.3
when that document applies.

**AFS-AI-10 [MUST]** Recommend tests. Every security-relevant change MUST come with the test that
proves the control, including the deny path, and the command that runs it.

**AFS-AI-11 [MUST]** Report vulnerabilities and gaps. A suspected vulnerability MUST be reported to
the founder or architect with the affected file or component, the impact, the preconditions, the
proposed fix and the test. It MUST NOT be silently fixed in an unrelated change or quietly ignored.

**AFS-AI-12 [MUST]** Explain conflicts with a secure alternative. When the requested change conflicts
with this standard, the agent MUST state the requirement, the conflict, the risk, and at least one
secure alternative. It MUST NOT implement the insecure option first and mention the risk afterwards.

**AFS-AI-13 [MUST]** Classify requirements. A legal, regulatory or contractual requirement MUST be
classified R1–R5 under the Hivorr standards §19.2. A recommendation MUST NOT be presented as law.

**AFS-AI-14 [MUST]** Record the unknown as **[OPEN]**. The agent MUST NOT invent a threshold, a
lifetime, a policy, a provider capability or a legal obligation to avoid asking.

**AFS-AI-15 [MUST]** Separate verified from assumed. The agent's report MUST distinguish what it ran
and observed from what it inferred.

**AFS-AI-16 [MUST NOT]** Describe work as secure, compliant, certified, hardened or production-ready.
The agent states what was verified and how.

### 6.3 Stop conditions

**AFS-AI-17 [MUST]** The agent MUST stop and ask, rather than proceed, when any of the following is
true:

- the change requires weakening or removing an existing security control;
- the change requires a new secret, key, credential or privileged role and no approved mechanism
  exists;
- the correct behaviour depends on an **[OPEN]** decision in §8 or in an owning document;
- two approved documents conflict and the stricter control is not obviously applicable;
- the task requires production data, a real payment, a real identity document or a live third-party
  side effect;
- the agent cannot produce a test or evidence for a control it is asked to claim.

### 6.4 Forbidden agent behaviours

**AFS-AI-18 [MUST NOT]** The agent MUST NOT:

- disable, skip or weaken a test, linter rule, type check, security scan or CI gate;
- add `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `any` casts or suppression comments to hide
  a security-relevant type or lint failure without explicit approval;
- commit a `.env` file, a key, a token or a credential, including in an example or fixture;
- modify the prototype to match a security document, or modify a security document to match the
  prototype;
- add a dependency to avoid writing a small, reviewed piece of code without justification;
- copy code from an untrusted source without review, licence check and security check;
- make a public disclosure, a regulator notification or a customer statement about a vulnerability;
- claim that a control exists because the code contains a comment, a TODO, a button or a UI label.

### 6.5 What an agent report must contain

**AFS-AI-19 [MUST]** A completion report for security-relevant work MUST state:

1. the files and components changed, and the trust boundary affected;
2. the `AFS-` requirements and the Hivorr rules applied;
3. the existing controls inspected and preserved;
4. the tests added or run, with the command and result;
5. the evidence produced, with date and environment;
6. the residual risk, the gaps and any **[OPEN]** decision;
7. any conflict, deviation or assumption, stated explicitly;
8. confirmation that no secret, credential or production personal data was exposed.

**AFS-AI-20 [MUST]** A report that says only "implemented", "secured" or "done" does not satisfy this
section and MUST be treated as incomplete.

---

## 7. Governance, deviations and review

### 7.1 Ownership

| Role | Responsibility |
| --- | --- |
| **Founder** | Owns this standard. Approves the document, every §8 decision, every accepted security risk, every production release and every external assurance statement. |
| **Architect** | Maintains the technical content. Approves technical deviations, dependency additions and threat models. |
| **Reviewer** | Enforces §3.12 on every pull request. A sensitive change needs a second qualified reviewer. |
| **Contributor** | Follows the standard, records deviations and reports risks. Human or AI, the obligation is the same. |

### 7.2 Change classes

**AFS-GOV-18 [MUST]** A change is classified before work starts:

- **Routine** — no trust boundary, data class or permission change. Normal review.
- **Sensitive** — authentication, authorisation, permissions, cryptography, secrets, database policy,
  financial logic, file handling or dependency addition. Second reviewer and security tests required.
- **Material** — changes a data class, a permission model, a trust boundary, a provider or the
  security posture. Architect approval, threat model and founder notification.
- **Founder** — changes risk acceptance, a §8 decision, a legal or regulatory position, or a
  production release. Founder approval in writing.

### 7.3 Deviations and exceptions

**AFS-GOV-19 [MUST]** A deviation from a **MUST** requirement MUST be recorded before the change
merges. The record states the rule, the scope, the reason, the risk, the compensating control, the
owner and the expiry date.

**AFS-GOV-20 [MUST]** A deviation MUST NOT be extended by relying on it. Each extension is a new
decision.

**AFS-GOV-21 [MUST]** An exception without an owner or an expiry is invalid. The founder approves
risk-acceptance exceptions; the architect approves technical ones that do not accept business risk.

**AFS-GOV-22 [MUST]** The exception register MUST be reviewed at each review cycle. Closed exceptions
are removed; expired ones become open work.

### 7.4 Review cycle and triggers

**AFS-GOV-23 [MUST]** This standard MUST be reviewed every six months and on any of these triggers:

- a new OWASP Top 10, API Security Top 10 or ASVS edition;
- a new AfriNova product, hostname, API surface or integration;
- a new data class, payment method or identity provider;
- a security incident or a near miss;
- a change to an approved Hivorr document that this standard references;
- a change to a legal, regulatory or contractual obligation;
- the first production release of a product.

**AFS-GOV-24 [MUST]** Each review produces a changelog entry even when nothing changes.

### 7.5 Amendment

**AFS-GOV-25 [MUST]** Anyone may propose an amendment. The proposal states the rule, the problem, the
proposed replacement and the effect on existing work.

**AFS-GOV-26 [MUST]** A **MUST** requirement is amended only with founder approval. A **SHOULD**
wording change that does not change meaning may be made by the architect. Every change is recorded in
§10.

**AFS-GOV-27 [MUST]** An amendment does not retroactively approve work done in violation of the
previous rule. Existing deviations remain recorded until closed.

---

## 8. Decisions and recorded outcomes

All eighteen decisions were approved by the founder on **6 November 2026** and are recorded in §8.1.
The table below preserves the approved default. Where a default did not specify a numeric value, a
vendor, a jurisdiction or a counsel opinion, that parameter remains **[OPEN]** and is named in §8.1.
Nothing may be built as though an open parameter were settled.

| # | Decision | Blocks | Approved default |
| --- | --- | --- | --- |
| 1 | **Ratification** of this standard and its enforcement model, including §6 agent obligations and §7 change classes | The formal authority of this document | Ratified version 1.0 as written with no conditions (§8.1) |
| 2 | **ASVS target level** per product and surface | §4.3, verification scope | Level 2 for every product; Level 3 for authentication, admin, financial and restricted-data surfaces |
| 3 | **Vulnerability remediation SLAs** by severity | AFS-SUPPLY-04 | 7 days Critical, 30 days High, 90 days Medium, next cycle Low |
| 4 | **Session lifetimes** — absolute and idle, per audience | AFS-SESS-04 | Short absolute lifetime for privileged surfaces; longer for consumer surfaces; enforced server-side |
| 5 | **Secret manager** — provider, rotation and scoping | AFS-CRED-06, AFS-CONF-02 | Managed secret store, per-environment scoping, automated rotation where supported |
| 6 | **Rate-limit thresholds** per endpoint class | AFS-API-04 | Conservative defaults, tuned from staging measurements, documented per class |
| 7 | **CSP and security-header posture** given the prototype's inline styles | AFS-CONF-05, Hivorr EX-02/EX-11 | Serve the full header set; accept `style-src 'unsafe-inline'` only as a recorded, time-boxed exception |
| 8 | **Log and audit retention periods**, separately | AFS-LOG-03, AFS-PRIV-06 | Application logs short and numeric; audit log long and numeric; both stated |
| 9 | **Incident severity model and on-call expectations** | AFS-IR-03 | Four-level model confirmed for a small team; a named owner per severity |
| 10 | **Penetration-test vendor and cadence** | AFS-TEST-04 | Independent test before first public release; annually and on major change thereafter |
| 11 | **External assessment programme** — which assessments, order, vendor, budget, cadence | §4.4, any assurance statement | Start with VAPT and access-control review; add data-protection and financial-control assessments once scope is confirmed |
| 12 | **Who may declare a product "audit-ready" or make an assurance statement** | AFS-GOV-08, AFS-GOV-16 | Founder only, in writing, naming scope, assessor, date and evidence |
| 13 | **Data-protection assessment scope** — jurisdictions, processing activities, data classes, DPIA need | AFS-PRIV-01, AFS-PRIV-08 | Record the processing inventory first; commission assessment against that scope |
| 14 | **KYC/AML applicability** — direct or contractual only, and which entity reports | AFS-PRIV-09, AFS-PRIV-10 | Treat as **[OPEN]** until counsel confirms; build no reporting path on an assumption |
| 15 | **Media origin for user uploads** — dedicated cookieless host or app origin | AFS-FILE-04 | Dedicated cookieless origin with strict headers |
| 16 | **Evidence retention** for security and assessment evidence | AFS-GOV-11–13, AFS-TEST-08 | Retain for the longest applicable obligation once known; retain and do not purge until then |
| 17 | **Applicability beyond Hivorr** — which AfriNova products adopt this standard and who owns exceptions for each | §1.2, §7.3 | Apply from inception to every new product; each product names an owner and an exception approver |
| 18 | **Enforcement prerequisite** — protected `main`, remote hosting, CI, required status checks, secret and dependency scanning | AFS-TEST-03, AFS-SUPPLY-03, §5.3 | Resolve before any production release; state the gap in every release record until closed |

**AFS-GOV-28 [MUST]** A decision recorded in §10 MUST state the decision, the date, the scope and the
person who made it. A verbal decision, a chat message or an inferred preference is not a recorded
decision.

### 8.1 Recorded decisions — 6 November 2026

| # | Recorded outcome | Remaining open parameter |
| --- | --- | --- |
| 1 | Version 1.0 ratified as written, with no conditions; §6 and §7 binding from 6 November 2026. | None. |
| 2 | ASVS **Level 2** for every product; **Level 3** for authentication, administration, financial and restricted-data surfaces. | Per-surface chapter mapping, recorded with the threat model. |
| 3 | Remediation SLAs: **Critical 7 days, High 30 days, Medium 90 days**; Low scheduled in the next review cycle. | None. |
| 4 | Short absolute lifetime for privileged surfaces and a longer lifetime for consumer surfaces, enforced server-side. | Numeric absolute and idle values per audience. |
| 5 | Managed secret store, per-environment and per-service scoping, rotation where supported. | Provider selection and rotation intervals. |
| 6 | Conservative rate limits per endpoint class, tuned from staging measurements and documented per class. | Numeric thresholds per endpoint class. |
| 7 | Full security-header set; `style-src 'unsafe-inline'` only as a recorded, time-boxed exception. | Removal date, tied to the inline-style migration. |
| 8 | Application logs short, audit log long; both stated numerically. | Numeric retention periods. |
| 9 | Four-level severity model, a named owner per severity, runbooks and a contact list. | Named on-call rota and response times. |
| 10 | Independent penetration test before the first public release, annually thereafter and on a major change. | Vendor selection. |
| 11 | External assessment programme starts with VAPT and an access-control review; data-protection and financial-control assessments are added once scope is confirmed. | Vendor, budget and scheduling. |
| 12 | Only the founder may declare a product "audit-ready" or make an assurance statement, in writing, naming scope, assessor, date and evidence. | None. |
| 13 | Record the processing inventory first and commission the data-protection assessment against that scope. | Jurisdictions, processing activities, data classes and DPIA determination, with counsel. |
| 14 | KYC/AML applicability remains **[OPEN]** until counsel confirms; no reporting path is built on an assumption. | Applicability determination and reporting entity. |
| 15 | Dedicated cookieless origin with strict headers for user-supplied content. | Hostname and provider. |
| 16 | Retain evidence for the longest applicable obligation; retain and do not purge until the period is known. | Numeric retention period. |
| 17 | Apply to every new AfriNova product from inception; each product names an owner and an exception approver. | Named owners per product. |
| 18 | Protected `main`, remote hosting, CI, required checks and secret/dependency scanning before any production release. | Implementation and the evidence that each gate operates. |

**AFS-GOV-31 [MUST]** A parameter recorded as open in §8.1 MUST be resolved by the named owner before
the control that depends on it is claimed to operate. The open parameter does not block unrelated work.

---

## 9. Known conflicts and gaps

These are recorded, not silently resolved. Each is either a conflict between documents or a gap
between a requirement and the current implementation.

| # | Issue | Effect | Status |
| --- | --- | --- | --- |
| 1 | The Hivorr standards describe themselves as the single authoritative source for engineering and security standards, while this document is the AfriNova-wide baseline. | Two documents could appear to claim the same authority. | **Resolved by framing** — this standard is applied *through* the Hivorr standards for Hivorr work; Hivorr detail remains authoritative there; the stricter control governs a difference; material conflicts are recorded here and in Hivorr §15. |
| 2 | ASVS target level per surface. | Verification scope and test depth follow the target. | **Decided 6 Nov 2026** — §8.1: Level 2 default; Level 3 for authentication, administration, financial and restricted-data surfaces. Per-surface mapping at design time. |
| 3 | No CSP or full security-header set is served. | AFS-CONF-05 is specified but not exercised. | **Gap** — posture approved 6 Nov 2026 (§8.1); not implemented; Hivorr EX-11; release blocker before public launch. |
| 4 | No CI configuration, protected branch, test tooling or automated security scan exists; no remote is configured. | AFS-TEST-01–03 and AFS-SUPPLY-03 cannot be enforced. | **Gap** — approved prerequisite (§8.1, decision 18) is not implemented; Hivorr EX-10; repository state verified 6 November 2026. |
| 5 | Secret-manager provider is not selected. | AFS-CRED-06 and AFS-CONF-02 have no concrete mechanism. | **Policy decided; provider [OPEN]** — §8.1, decision 5. |
| 6 | Numeric session lifetimes are not set. | AFS-SESS-04 has no numeric target. | **Policy decided; values [OPEN]** — §8.1, decision 4. Short default applies. |
| 7 | Numeric rate-limit thresholds are not set. | AFS-API-04 has no numeric target. | **Policy decided; values [OPEN]** — §8.1, decision 6. Conservative defaults apply. |
| 8 | Numeric log and audit retention periods are not set. | AFS-LOG-03 and AFS-PRIV-06 cannot be verified. | **Policy decided; values [OPEN]** — §8.1, decision 8. Retain and do not purge. |
| 9 | Remediation SLAs are approved but not yet exercised. | AFS-SUPPLY-04 has no operational history. | **Decided 6 Nov 2026** — Critical 7 days, High 30, Medium 90; Low next cycle (§8.1). |
| 10 | Media-origin hostname and provider are not selected. | AFS-FILE-04 cannot be fully configured. | **Decided 6 Nov 2026** — dedicated cookieless origin with strict headers; hostname/provider **[OPEN]** (§8.1, decision 15). |
| 11 | Data residency and cross-border transfer are not decided. | AFS-PRIV-08 has no jurisdiction target. | **[OPEN]** — §8.1, decision 13, with counsel. |
| 12 | The dormant shadcn kit contains `dangerouslySetInnerHTML` and `document.cookie` usage. | Adopting a dormant component could import an unsafe sink. | **Recorded** — Hivorr EX-06. No dormant component may be adopted without review against AFS-IO-05 and AFS-SESS-02. |
| 13 | The prototype has no backend, real authentication or live data. | Most controls are specified, not exercised. | **Fact** — §5.3. A control that has not been exercised is not known to work. |
| 14 | No independent assessment has been commissioned. | No assurance statement is supportable. | **Direction decided; scheduling [OPEN]** — §8.1, decisions 11 and 12. |
| 15 | The project is a single-package workspace and no deployed production environment is configured in the repository. | Environment separation and deployment controls are unexercised. | **Fact** — Hivorr EX-15/EX-16. State the gap in every release record. |

**AFS-GOV-29 [MUST]** A new conflict or gap discovered during work MUST be added to this table in the
same change, or reported to the architect with enough detail to add it.

---

## 10. References, approval and changelog

### 10.1 External references

**[FACT]** Links and versions checked on 6 November 2026. External documentation changes; confirm the
current edition before relying on a version-specific claim.

| Reference | What it establishes | Link |
| --- | --- | --- |
| OWASP Top 10:2025 | The current ten most critical web application security risks | https://owasp.org/Top10/ |
| OWASP Top 10:2025 — Introduction | Category definitions and changes from 2021 | https://owasp.org/Top10/2025/0x00_2025-Introduction/ |
| OWASP API Security Top 10:2023 | The current API-specific risk list | https://owasp.org/API-Security/editions/2023/en/0x00-header/ |
| OWASP ASVS 5.0.0 | Verification requirements and levels (published 30 May 2025) | https://owasp.org/www-project-application-security-verification-standard/ |
| OWASP Cheat Sheet Series | Practical implementation guidance per control area | https://cheatsheetseries.owasp.org/ |
| OWASP Password Storage Cheat Sheet | Argon2id parameters and prohibited password hashes | https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html |
| OWASP Authorization Cheat Sheet | Server-side enforcement and object-level checks | https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html |
| OWASP Session Management Cheat Sheet | Session identifiers, rotation, timeouts and revocation | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |
| OWASP File Upload Cheat Sheet | Type verification, storage separation and serving rules | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| OWASP Secrets Management Cheat Sheet | Storage, rotation and scoping of secrets | https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html |
| OWASP Logging Cheat Sheet | What to log, what never to log, and structure | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| OWASP SSRF Prevention Cheat Sheet | Outbound request validation and address blocking | https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html |
| OWASP Vulnerable Dependency Management Cheat Sheet | Supply-chain controls and remediation | https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html |
| NIST SP 800-218 | Secure software development practices referenced by the Hivorr standards | https://csrc.nist.gov/pubs/sp/800/218/final |

**AFS-GOV-30 [MUST]** An external reference establishes a technique or a risk, not an AfriNova
requirement. A requirement exists here because a rule in §3, §6 or §7 says so.

### 10.2 Approval record

| Field | Value |
| --- | --- |
| **Document** | AfriNova — OWASP Application Security Standard |
| **Version** | 1.0 |
| **Date issued** | 6 November 2026 |
| **Status** | **APPROVED — 6 November 2026. Binding.** |
| **Ratified by** | Founder (AfriNova) |
| **Date ratified** | 6 November 2026 |
| **Conditions** | None. |
| **Decisions recorded** | §8.1, decisions 1–18. Parameters listed there as open remain **[OPEN]**. |
| **Next review** | 6 May 2027, or on a trigger in §7.4 |

**Effect of approval.** §3, §6 and §7 are binding for every AfriNova product from 6 November 2026.
The eighteen decisions in §8 are recorded in §8.1. Approval does not resolve a parameter that §8.1
lists as open, does not approve a product release, and does not assert that any product is secure,
compliant, certified or audited.

### 10.3 Changelog

#### 6 November 2026 — version 1.0 ratified

- The founder ratified version 1.0 with no conditions.
- Recorded the eighteen decisions in §8.1 and updated the affected status lines in §3, §4.3 and §9.
- No control requirement changed meaning. Parameters that were not specified — numeric thresholds,
  vendors, jurisdictions and counsel opinions — remain **[OPEN]** in §8.1.
- No application code, dependency or approved Hivorr rule was changed.
- No certification, compliance or assurance claim is made.

#### 6 November 2026 — version 1.0, initial issue

- Created the AfriNova-wide OWASP application security baseline.
- Added 15 control areas with `AFS-` requirements covering the requested scope.
- Added mappings to OWASP Top 10:2025, API Security Top 10:2023 and ASVS 5.0.0.
- Added the mandatory AI-agent trigger list, behaviours, stop conditions and report format.
- Added evidence expectations, the current Hivorr implementation state, the conflict register and the
  founder-decision table.
- No application code, dependency or approved Hivorr rule was changed.
- No certification, compliance or assurance claim is made.

---

## Appendix A — Quick reference

| If you are about to… | Read | Minimum evidence |
| --- | --- | --- |
| Add a login, session, token or password flow | §3.1–§3.4 | Allow/deny tests, session configuration review, auth event log |
| Add or change a permission | §3.2 | Policy test for allow and deny, second review |
| Add an endpoint or webhook | §3.5–§3.6 | Schema validation test, object- and function-level auth tests, rate-limit test |
| Add a query, policy or migration | §3.7 | Parameterisation review, policy allow/deny test, migration review, rollback plan |
| Add encryption or a key | §3.8 | Algorithm review, key-management record, rotation plan |
| Add an upload or download | §3.9 | Type-rejection test, served-header test, download authorisation test |
| Add logging, an alert or an audit event | §3.10 | Redaction test, alert test-fire, audit schema review |
| Add or upgrade a dependency | §3.11 | Justification, scan result, pin and lockfile diff |
| Change a security-sensitive area | §3.12 | Second review, security tests, threat model where material |
| Handle personal or financial data | §3.13 | Data inventory, classification, access log, retention test |
| Change configuration, headers or a secret | §3.14 | Header scan, secret-manager configuration, change record |
| Prepare for or respond to an incident | §3.15 | Runbook, incident record, post-incident review |
| Ask an AI agent to do any of the above | §6 | The §6.5 report fields |

---

*End of standard.*

