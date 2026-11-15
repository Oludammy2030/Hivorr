# Control Portal — Production Phase 0 Decisions

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/PRODUCTION-DECISIONS.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Decision date** | 15 November 2026 |
| **Decision authority** | Founder, AfriNova Digital Limited |
| **Status** | **DECIDED — 15 November 2026.** Binding for the production readiness gate. |
| **Basis** | `PRODUCTION-READINESS.md` Phase 0 |

> These decisions settle the four questions that block provisioning. They do not provision anything
> and do not approve a release. Where a decision creates a remaining action, the action is stated.

---

## D-P0-1 — The `DEP-14` reviewer

**Decision.** A **named reviewer will be appointed** before the first production release. The reviewer
is not the deployer and has no ability to affect the release, and their name and confirmation appear
on every `DEP-23` record.

**Why.** `DEP-14` requires a reviewer who did not deploy and cannot alter the artifact. `DEV-002`
covers a one-person team and explicitly does **not** extend to `G4` production; `EES §7.3` provides no
production deviation path. Appointing a reviewer is the only route that satisfies the rule as written.

**Consequence.** `DEP-14` is **not yet satisfied**. It is satisfied when a person is named in writing
and confirms the first release. Until then the production gate remains open, whatever else is ready.

**Remaining action.** Name the reviewer, obtain written confirmation of the role, and record both here.

## D-P0-2 — Hosting region and data residency

**Decision.** The production data plane is provisioned in an **EU region**. Identity, staff, case and
audit data all reside there. Production and staging remain fully separate, with no shared database,
bucket, queue or credential.

**Why.** The portal holds R2 and R3 classes — identity, personal data, case evidence metadata and the
audit spine. An EU region offers mature managed Postgres and object storage, encryption and backup
guarantees, and a data-protection regime that is commonly accepted for African operators. Latency is
not the deciding factor: a governance portal serves a handful of users.

**Consequence.** Provider selection is constrained to an EU region. If real customer identity data is
later processed, a cross-border transfer assessment is required before that data lands — the region
choice does not substitute for one.

**Remaining action.** Confirm the chosen provider's EU region and its backup, encryption and
point-in-time recovery terms before provisioning.

## D-P0-3 — Error sink

**Decision.** Production errors ship to **Sentry in its EU data region**, with `sendDefaultPii`
disabled and scrubbing configured. Only the existing `ErrorContext` is transmitted: correlation id,
method, path without query string, status and the error itself.

**Why.** `CaptureErrorTracker` holds errors in memory and ships nothing, which is safe but leaves
production unobservable. The existing design already excludes request bodies and query strings, so the
payload reaching a vendor is narrow by construction.

**Consequence.** Adding a processor of personal data requires a vendor review (`[REVIEW]`), a data
processing agreement, and an implementation change to `CaptureErrorTracker`. Error stacks can contain
identifiers, so scrubbing is part of the requirement, not a refinement.

**Remaining action.** Vendor review and DPA; then implement the adapter and configure the DSN in the
production environment only.

## D-P0-4 — Retention and legal hold (`D-12`)

**Decision.**

| Class | Retention |
|---|---|
| Audit log | **7 years** |
| Cases, decisions, approvals | **7 years from closure** |
| Evidence metadata and binaries | **as long as its case** |
| Sessions, refresh tokens, devices | **90 days after revocation** |
| Invitations | **7 days** (existing expiry, unchanged) |
| Legal hold | **overrides every class, indefinitely until released** |

**Why.** Company law requires accounting records for six years; a seven-year window covers that floor
with a margin while remaining defensible under a "no longer than necessary" principle. Cases and the
audit rows that reference them must share a lifetime, or the audit points at records that no longer
exist.

**Consequence.** This sets the policy; it does **not** implement deletion. There is no retention job,
no legal-hold flag and no archive tier today, so nothing is deleted — the safe direction to be wrong
in. Implementation belongs to CP-035 (reporting and data governance) and CP-038 (documents), and no
retention change may ship without a legal-hold override.

**Remaining action.** None before provisioning. Implementation is scheduled with CP-035 and CP-038.

**Not legal advice.** The six-versus-seven-year question and the legal-hold procedure should receive a
professional read before regulators, investors or enterprise customers examine them.

---

## What these decisions do not change

- No package status changes; all twenty remain `COMPLETED` as recorded in the execution tracker.
- No infrastructure is provisioned and no production release is approved.
- The open informational findings (F-A-05, F-A-08, F-B-05, F-B-06, F-C-04) and the browser/UI evidence
  gap remain as recorded.

## Next gate

`PRODUCTION-READINESS.md` Phase 1 may begin once D-P0-1's reviewer is named and D-P0-2's provider terms
are confirmed. Phase 1 provisions; it does not release.
