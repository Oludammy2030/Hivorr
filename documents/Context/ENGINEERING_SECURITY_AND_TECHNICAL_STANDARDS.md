# Hivorr — Engineering, Security and Technical Standards

| Field | Value |
| --- | --- |
| **Document** | `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` |
| **Version** | 2.1 |
| **Date** | 6 November 2026 |
| **Status** | **APPROVED — 6 November 2026.** Binding. |
| **Owner** | Founder (AfriNova) for business risk, security posture and approval gates. Architect for technical content. |
| **Applies to** | Every human contributor and every AI coding agent that reads, designs, writes, reviews, tests, deploys or documents code for Hivorr. |
| **Review cycle** | Every six months, and on any trigger listed in §13.5. |
| **Supersedes** | Version 2.0 of this document. Versions 1.0–1.3 were proposals and were never binding; version 2.0 was the first approved version. Version 2.1 adds §19, Audit Readiness by Design, and extends `QUA-37` and `AI-21` with audit-readiness conditions. It removes or weakens no existing rule. |
| **Companion documents** | `VISION.md`, `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `VISUAL-IDENTITY.md`, `AGENTS.md` |

> **Status note.** Approved by the founder on **6 November 2026**, version 2.1. Every rule
> marked **[STD]** binds from that date; every rule marked **[REC]** is the expected default; every
> **[REVIEW]** and **[FOUNDER]** rule is a gate in the process described in §13. The change
> classes in §1.4, the gate set in §13.4 and the exceptions register in §13.3 are binding with it.
>
> Version 2.1 adds **§19, Audit Readiness by Design**. It introduces the `AUD-` and `TRC-` rule
> series, the six audit readiness checkpoints (`AR-0`–`AR-5`), the requirement classes `R1`–`R5`,
> and the traceability template in Appendix D. It removes or weakens no rule in §2–§18; `QUA-37` and
> `AI-21` gain the conditions recorded in §17, and every existing condition still applies. It does not
> settle any **[OPEN]** item and does not create a legal, regulatory or contractual obligation. The
> approval itself is recorded in §18.
>
> Approval of this document does **not** settle any **[OPEN]** item in §16 or `ARCHITECTURE.md` §16.4,
> does **not** approve any phase of engineering work, and does **not** authorise a production release.
> Those remain separate acts by the founder or architect named in Document control.

---

## How to use this document

Four reading paths. Read the one that matches what you are about to do.

**Starting work on a feature.**
§2 (principles) → §19.2–§19.5 (requirement classes, impact note, controls) → §3 (may I use this
technology) → §4–§8 (the area you are touching) → §10 (quality and tests) → §12 if you are an AI
agent.

**Reviewing someone else's work.**
Appendix B (one-page checklist) → the section for the area being changed → §13.1 (which class of
change is this) → §19.12 (audit readiness gates) → §10.6 (review requirements).

**Approving a release.**
§9.4–§9.6 (production protection, migration gate, rollback) → §19.12 (AR-4) → §13.1 → the release
record fields in §9.6.

**Preparing for, or responding to, an external assessment.**
§19.13 (external audit preparation) → §19.11–§19.12 (traceability and gates) → §11.3 (audit trail)
→ §13.3 (exceptions and deviations) → §16 (open decisions).

**Resolving a disagreement about what is allowed.**
§1.3 (authority map) → §1.4 (the four labels) → §15 (recorded conflicts) → §16 (open decisions).

---

## Document control

### Purpose

This document establishes how engineering work on Hivorr is designed, secured, built, tested,
deployed, monitored and governed. It is the single authoritative source for engineering and security
standards.

It exists because Hivorr's other approved documents answer different questions. `ARCHITECTURE.md`
says what the system is. The permission matrix says who may do what. The database rules say how the
database is reached and changed. `VISUAL-IDENTITY.md` says what it looks like. None of them says how
a change is judged safe to merge, which decisions a developer may take alone, or what an AI agent
must check before editing authentication code.

### Scope

In scope:

- Engineering principles and the judgement they imply.
- Technology selection, dependency adoption and vendor evaluation.
- Application security: injection, XSS, CSRF, input validation, uploads, abuse, error handling.
- Authentication and authorisation as engineering obligations.
- Database access, data classification, encryption, retention, backup and recovery.
- API design, rate limiting, integrations, secrets and webhooks.
- Performance budgets, query efficiency, caching, background processing.
- Environment separation, production protection, deployment records and rollback.
- Code quality, testing, security testing and code review.
- Monitoring, logging, audit, vulnerability management and incident response.
- Audit readiness by design: requirement sources, requirement-to-control-to-evidence traceability,
  audit readiness gates, and the evidence needed for independent assessment.
- The obligations of AI coding agents.
- Governance: the four decision classes, deviations, enforcement and amendment.

Out of scope — governed elsewhere, cited rather than restated:

- Product direction, activities and business model — `VISION.md`.
- System design, module boundaries, hosting topology — `ARCHITECTURE.md`.
- Account model, capabilities, verification lanes, admin scopes — the permission matrix.
- SQL mechanics, grants, RLS policy syntax, migration tooling — the database rules.
- Colour, typography, spacing, component anatomy — the prototype, then `VISUAL-IDENTITY.md`.
- Legal, tax, regulatory and funds-custody questions, and the interpretation of a statute, a
  regulator's guidance or a VFD onboarding document — founder and counsel.

Audit readiness does not create a new governance document. §19 is the authoritative engineering
standard for it; legal and contractual interpretation remains outside this document.

### Ownership and review requirements

| Role | Responsibility |
| --- | --- |
| **Founder** | Owns this document. Approves every **[FOUNDER]** item, every production release, every accepted security risk, and every change to §13.1. |
| **Architect** | Maintains the technical content. Approves **[REVIEW]** items, dependency additions, and deviations that are technical rather than business decisions. |
| **Reviewer** | Any second qualified contributor. Enforces §10.6 on every pull request. |
| **Contributor** | Follows the standards, records deviations, reports risks. Human or AI, the obligation is the same. |

A change to this document requires founder approval. A change to a **[REC]** rule's wording that does
not change its meaning may be made by the architect and recorded in §17.

### Limits of this document

**No practice in this document guarantees complete security.** Security is a property of a running
system under attack, not a checklist that can be completed. Every control here reduces a specific
risk; none eliminates it. A system that passes every rule in this document can still be breached
through a flaw nobody anticipated, a compromised dependency, a misconfigured provider, or a person
under pressure.

Two consequences follow, and they are rules:

- **[STD]** No contributor, and no AI agent, may describe Hivorr as "secure", "compliant", "hardened"
  or "production-ready" on the basis that these rules were followed. State what was verified and how
  (§12.4).
- **[STD]** A control that has never been exercised is not known to work. Backups require a restore
  drill (§6.10). Access rules require a deny test (§10.4). Alerts require a test fire (§11.4).

---

## 1. Purpose, scope and authority

### 1.1 What this document governs

This document governs **how engineering work is done, verified and gated**. It does not govern what
the system is, who may do what inside it, how the database is reached, or what it looks like.

### 1.2 What this document does not govern

- **Product decisions.** Whether an activity launches, what it costs, who may use it — `VISION.md`
  and the founder.
- **Architecture.** Module boundaries, the stack, hosting topology, bundle strategy —
  `ARCHITECTURE.md`. This document applies those decisions; it never replaces them.
- **The permission model.** Which capability a role holds — the permission matrix. This document
  requires that the matrix be enforced; it does not define it.
- **Database mechanics.** Grants, RLS policy syntax, migration tooling — the database rules.
- **Visual design.** The prototype is the only UI authority. This document may require a control
  (for example a confirmation dialog before a destructive action); it may not restyle anything.

### 1.3 Relationship to the other approved documents

Each document answers one question. When two appear to disagree, the map below decides which one is
speaking about its own subject.

| Question | Authority | This document's role |
| --- | --- | --- |
| What is Hivorr building, for whom, and why? | `VISION.md` | Cite only. |
| What is the system — modules, stack, hosts, bundles, data flow? | `ARCHITECTURE.md` | Apply its decisions. Never contradict. |
| Who may do what, under which conditions? | `Unified-Account-and-Activity-Permission-Matrix.md` | Enforce it. Never redefine a capability. |
| How is the database reached, changed, granted and tested? | `Database-Migration-and-Supabase-Data-API-Rules.md` | Apply it. Never restate SQL mechanics. |
| What does it look like? | The prototype, then `VISUAL-IDENTITY.md` | Protect it. Never override it. |
| How does an AI agent behave on this project? | `AGENTS.md` | Extend with engineering and security detail. |
| **How is engineering work done, verified, evidenced and gated?** | **This document** | **Authoritative.** |

**GOV-01 [STD]** Where this document and `ARCHITECTURE.md` disagree about *what the system is*,
`ARCHITECTURE.md` governs, and the disagreement is recorded in §15.

**GOV-02 [STD]** Where this document and the permission matrix disagree about *who may do what*, the
matrix governs. This document may only add an engineering obligation (for example "the check happens
inside the transaction"), never a capability.

**GOV-03 [STD]** Where this document and the database rules disagree about *how the database is
reached or changed*, the database rules govern.

**GOV-04 [STD]** Where any document and the prototype disagree about *anything visual*, the prototype
governs (`AGENTS.md` §1). The document has a defect, not the product.

**GOV-05 [STD]** A conflict is never resolved by silently following one document. It is recorded in
§15, the affected work stops if the conflict is material, and the founder or architect decides which
document changes.

### 1.4 The four governance classes

Every rule in this document carries exactly one label. The labels describe **who decides**, not how
important the rule is. A rule can be minor and still be **[STD]**; a rule can be significant and still
be **[REC]**.

| Label | Meaning | Who decides | What a deviation requires |
| --- | --- | --- | --- |
| **[STD]** | Mandatory standard. | Already decided. Not open to individual judgement. | An approved deviation record (§13.2) before the change merges. |
| **[REC]** | Recommended practice. The expected default. | The contributor, applying judgement. | One sentence in the pull request explaining why the default did not fit. No approval needed. |
| **[REVIEW]** | Requires technical review before merge. | Architect or a named security reviewer. | The review itself is the approval. Recorded in the pull request. |
| **[FOUNDER]** | Requires founder approval before work proceeds or before deployment. | Founder. | Explicit approval, recorded with what was approved and when. |

Two supporting markers are used where a statement is a fact rather than a rule:

| Marker | Meaning |
| --- | --- |
| **[FACT]** | A verified property of the repository, a provider or a standard, with the date it was checked. Not a requirement. |
| **[OPEN]** | Undecided. Not a requirement. Listed in §16 or in `ARCHITECTURE.md` §16.4. Nothing may be built as though it were settled. |

**Mapping to the labels used in `ARCHITECTURE.md`.** That document uses `[DECIDED]`,
`[RECOMMENDED]` and `[OPEN]`. The mapping is:

| `ARCHITECTURE.md` | This document |
| --- | --- |
| `[DECIDED]` | **[STD]** — a Hivorr decision already taken |
| `[RECOMMENDED]` | **[REC]**, unless it protects a security property, in which case **[STD]** |
| `[OPEN]` | **[OPEN]** — nothing is built |

The labels are not a severity scale and must not be read as one. The most dangerous rule in this
document is probably **[STD]**; so is the least important one.

**Why most rules are [STD].** This is a standards document, not a style guide. A rule earns a place
here because something has gone wrong before or would go wrong without it, so most of them are
mandatory. The **[REC]** class is reserved for the places where local judgement genuinely applies —
naming, test style, pull-request size, log-level conventions — where a fixed rule would produce worse
work than a considered default. The **[REVIEW]** and **[FOUNDER]** classes are reserved for decisions
whose consequences are not local. If a rule feels over-classified, that is worth raising in the next
review cycle (§13.5), because an over-classified rule trains people to treat all of them as
optional.

### 1.5 What "mandatory" does not mean

**GOV-06 [REC]** A mandatory rule is mandatory in the situation it describes, not in every
situation. "All state-changing requests validate `Origin`" is mandatory for state-changing requests;
it says nothing about `GET /health`. Applying a rule outside its stated scope is not compliance, it
is noise that makes the next reader stop reading.

**GOV-07 [STD]** When a rule's scope is genuinely ambiguous, the contributor asks rather than
guessing in either direction — neither skipping the control nor applying it where it does not belong.

### 1.6 Rule identifiers

Rules are cited by identifier, not by section number, so that sections can be reorganised without
breaking references.

| Prefix | Area | Prefix | Area |
| --- | --- | --- | --- |
| `ENG-` | Engineering principles | `PER-` | Performance and scalability |
| `TEC-` | Technology selection | `DEP-` | Environments and deployment |
| `SEC-` | Application security | `QUA-` | Code quality and testing |
| `AUT-` | Authentication and authorisation | `OPS-` | Monitoring and incidents |
| `DAT-` | Database and data protection | `AI-` | AI coding agent compliance |
| `API-` | API and integration security | `GOV-` | Governance and enforcement |
| `AUD-` | Audit readiness by design | `TRC-` | Requirement-to-control-to-evidence traceability |

A review comment should say `SEC-14`, not "the XSS bit". A deviation record must name the rule it
deviates from. `AUD-` rules govern audit readiness (§19); `TRC-` rules govern the traceability record
that connects a requirement to its control and evidence (§19.11).

---

## 2. Engineering principles

These are not aspirations. Each one has a test in §2.8 that a reviewer can apply to a real change.

### 2.1 Security by design

**ENG-01 [STD]** Security is a property of the design, not a review step. A feature that requires a
control to be remembered at every call site is designed wrongly; the control belongs in the layer
that cannot be bypassed.

Concretely:

- Authorisation is decided in the service layer, inside the transaction (`ARCHITECTURE.md` §10.2).
  A route guard and RLS are additional layers, never the only one.
- The default is deny. A new endpoint, a new query, a new bucket, a new capability starts closed and
  is opened deliberately.
- A new table starts with RLS enabled and no grants, then receives the minimum (`database rules`
  §6.1).
- A new field that holds personal data starts classified (§6.8), not "to be classified later".

**ENG-02 [STD]** Assume the client is hostile (`ARCHITECTURE.md` §10.1). Nothing sent by a browser
is trusted: not a role, not a capability, not a price, not an account id, not a hidden field, not a
header. The server re-derives every one of them from data it owns.

### 2.2 Reuse before creating

**ENG-03 [STD]** Before writing a new component, hook, utility, service, repository, validator or
query, the contributor inspects what already exists. This is not a suggestion to avoid work; it is
how a codebase of this size stays comprehensible.

The existing inventory is not hypothetical. On the frontend the shared primitives are `Av`, `Pill`,
`Btn`, `Input`, `SelectField`, `Card`, `StatCard`, `Section`, `Stars`, `JobRow`,
`PrototypeDialog`, `FinancialActionDialog`, `ActivityHero`, `WalletInfo`, `ChatUI`, `MarketShell`,
`Sidebar`, `TopBar` and the mobile navigation components (`AGENTS.md` §3). On the backend the module
boundaries are fixed (`ARCHITECTURE.md` §9.2).

**ENG-04 [STD]** A new implementation of something that already exists requires a stated reason in
the pull request: what the existing one cannot do, and why extending it is worse than duplicating it.

**ENG-05 [STD]** The 50-file shadcn kit in `src/app/components/ui/*` is dormant and imported by
nothing (`ARCHITECTURE.md` §8.3). It is not an existing implementation to reuse, and
`sidebar.tsx` must never replace the prototype `Sidebar`. Copying a shadcn component into use
requires **[REVIEW]**, because it introduces a second component language.

### 2.3 Maintainability and modular architecture

**ENG-06 [STD]** A module owns its data and exposes a narrow interface. Cross-module reads go through
that interface, not through another module's tables (`ARCHITECTURE.md` §9.3).

**ENG-07 [STD]** Business logic never lives in a React component, a route handler or a database
trigger alone. It lives in the service layer, where it can be tested without a browser and without a
database.

**ENG-08 [STD]** A file that has grown past the point where a reviewer can hold it in their head is
split by responsibility, not by line count. The prototype is the exception, not the precedent: it is
3,814 lines by design and is not being restructured (`AGENTS.md` §1, §3).

**ENG-09 [REC]** Prefer deleting code to adding an abstraction over it. Prefer one obvious
implementation to two configurable ones. Prefer a named constant to a repeated literal, once the
literal appears three times.

### 2.4 Scalability without unnecessary complexity

**ENG-10 [STD]** Hivorr is a modular monolith (`ARCHITECTURE.md` §1.2). It does not become
microservices, and it does not gain a message broker, a second database, a read replica, a cache
tier, a search cluster or a multi-region deployment, until a measured trigger in
`ARCHITECTURE.md` §13.6 fires.

**ENG-11 [STD]** "We might need it later" is not a justification. "We measured X and it is now the
bottleneck" is. The measurement goes in the pull request or the decision record.

**ENG-12 [REC]** Design the seam, not the system. If a future capability is likely, put the
interface in place and implement the simple version behind it (`ARCHITECTURE.md` §13.5).

### 2.5 Performance and reliability

**ENG-13 [STD]** Performance is a requirement, not an optimisation phase. A feature that works but
makes an ordinary screen unusable on a mid-range phone is not done (§8.1).

**ENG-14 [STD]** Every external call has a timeout. Every background job is idempotent and retryable.
Every failure path leaves the system in a state a human can reason about. A request that can hang
forever is a availability defect.

**ENG-15 [STD]** Money-moving operations are transactional, idempotent and reconciled. The ledger is
append-only and double-entry (`ARCHITECTURE.md` §9.10). A balance is derived, never stored as an
editable number.

### 2.6 Consistency with approved decisions

**ENG-16 [STD]** An approved decision is not re-litigated in a pull request. If a contributor
believes `ARCHITECTURE.md`, the matrix, the database rules or `VISUAL-IDENTITY.md` is wrong, they
report it and propose an amendment; they do not implement the alternative and explain afterwards.

**ENG-17 [STD]** Where no approved document decides a question, the contributor does not invent a
convention that will be expensive to reverse. Small, local, reversible choices are made and noted;
structural choices go to **[REVIEW]** or **[FOUNDER]** (§13.1).

### 2.7 What the principles are for

**ENG-18 [REC]** These principles exist to resolve the cases the rules do not cover. When a
contributor cannot find a rule, the correct question is not "is this allowed?" but "which principle
does this serve, and which does it violate?" A change that satisfies the letter of every rule while
violating §2.1 is still wrong, and a reviewer should say so.

**ENG-19 [STD]** A control that cannot be evidenced is treated as absent. Design the control so that it
produces the record of its own operation, and record that record where the phase's evidence index can
find it (§19.8, §19.11). This is the audit-readiness application of §2.1: the evidence belongs in the
layer that cannot be bypassed, not in a manual step remembered after the fact.

### 2.8 The principles as tests

A reviewer can apply each principle as a question with a yes/no answer.

| Principle | Test |
| --- | --- |
| Security by design | If the new check were deleted, what would still stop the attack? If the answer is "nothing", the design is wrong. |
| Reuse before creating | Name the existing thing that was considered. If nothing was considered, the search did not happen. |
| Maintainability | Could someone who has never seen this file change it without reading three others? |
| Scalability without complexity | What measurement justifies this infrastructure? If there is none, remove it. |
| Performance and reliability | What happens on a slow network, a timeout, a retry, and a duplicate delivery? |
| Consistency | Which approved document authorises this? If none, which decision class does it fall in? |
| Audit readiness | If an assessor asked for the requirement, the control and the evidence, could I produce all three from records made during the work? If not, the control is not yet assessable. |

---

## 3. Technology selection

### 3.1 The approved stack

**[FACT]** Verified against `package.json`, `tsconfig.json`, `vite.config.ts`, `pnpm-workspace.yaml`
and `.mise.toml` on 3 November 2026. The full table is `ARCHITECTURE.md` §2.1; this is the summary
that governs new work.

| Layer | Approved technology | Version | Note |
| --- | --- | --- | --- |
| UI runtime | React + React DOM | 18.3.1 | Do not upgrade the major without **[REVIEW]**. |
| Language | TypeScript | ^5.7, `strict: true` | `strict` is not negotiable (§10.1). |
| Build | Vite | 6.3.5, pinned by pnpm override | `vite.figma.config.ts` must keep working. |
| Styling | Tailwind CSS | 4.1.12 | Plus the token layer, not instead of it. |
| Tokens | CSS custom properties | `src/styles/theme.css` | The only place a colour may be defined. |
| Icons | `lucide-react` | 0.487.0 | The only icon set. |
| Routing | `react-router` | 7.13.0 | Installed, not yet used. |
| Forms | `react-hook-form` | 7.55.0 | Installed, not yet used. |
| Runtime | Node.js | 22 | `.mise.toml`. |
| Package manager | pnpm | 10.34.3 | `.mise.toml`. Lockfile committed. |
| Formatter | `oxfmt` | ^0.2.0 | Formatting is not a review topic. |
| Backend | NestJS + Fastify | — | `ARCHITECTURE.md` §2.2. |
| Database | PostgreSQL | 16 | Schema per module. |
| Object storage | Cloudflare R2 | — | `ARCHITECTURE.md` §9.12. |
| Queue | PostgreSQL-backed | — | No broker at MVP. |

**TEC-01 [STD]** The stack above is approved. Replacing any row requires **[FOUNDER]** approval,
because it changes cost, hiring, security surface and the shape of every future change.

**TEC-02 [STD]** Upgrading within a major version is a normal change, subject to §10 and §3.4. A
major-version upgrade of React, TypeScript, Vite, Tailwind, Node, PostgreSQL or the backend framework
requires **[REVIEW]** and a written migration note covering breaking changes, the test evidence, and
the rollback position.

### 3.2 What "approved" means

**TEC-03 [STD]** A technology is approved when an approved document names it, or when a **[FOUNDER]**
decision recorded in `ARCHITECTURE.md` §16 names it. Being present in `package.json` is not approval;
several packages are installed and unused (`ARCHITECTURE.md` §2.4).

**TEC-04 [STD]** A technology that is approved for one layer is not thereby approved for another.
`react-router` being available on the frontend says nothing about routing in the API.

### 3.3 Selection criteria

When a genuinely new capability is needed — a validator, a test runner, a PDF generator, a payment
provider — it is evaluated against the same criteria. The criteria are ordered: a candidate that
fails one of the first four is rejected regardless of how well it scores on the rest.

| # | Criterion | The question |
| --- | --- | --- |
| 1 | **Security** | Who maintains it, how are vulnerabilities reported and fixed, what does it execute, what does it phone home to, what is its dependency tree? |
| 2 | **Fit with the approved architecture** | Does it work with React 18, Vite 6, Node 22, PostgreSQL 16, NestJS and the module boundaries? Does it force a second way of doing something already decided? |
| 3 | **Maintainability** | Is it typed, documented, actively released, and small enough to read? Can it be removed in a week if it disappoints? |
| 4 | **Cost and lock-in** | What does it cost at 10× and 100× current volume? What does leaving it require? |
| 5 | **Performance** | What does it add to the bundle, to boot time, to the request path? |
| 6 | **Licence** | Is the licence compatible with a commercial product? Is it recorded? |
| 7 | **Operational burden** | Who patches it, who watches it, what happens when it is down? |

**TEC-05 [STD]** A frontend dependency that adds more than 30 KB gzipped to a route bundle requires
**[REVIEW]** and a measurement. The measurement is a build output, not an estimate.

**TEC-06 [STD]** A dependency that requires a background service, a second datastore, or a new
network egress path is infrastructure, not a library. It requires **[FOUNDER]** approval.

### 3.4 Adding a dependency

**TEC-07 [STD]** Every new runtime dependency requires a justification in the pull request
(`ARCHITECTURE.md` §2.5) with four answers:

1. What does it do that existing code cannot?
2. Why can it not be written in under 50 lines?
3. What is its maintenance status — last release, open security advisories, bus factor?
4. What happens on the day it is removed?

**TEC-08 [STD]** Every dependency, runtime and dev-only, is pinned to an exact version, and
`pnpm-lock.yaml` is committed. A lockfile change with no corresponding `package.json` change is a
defect. All entries were pinned on 3 November 2026 (EX-18); the lockfile still needs regenerating
(EX-19).

**TEC-09 [STD]** `minimumReleaseAge: 10080` (7 days) in `pnpm-workspace.yaml` is a supply-chain
control, not a preference. It exists so that a compromised release is caught by the community before
Hivorr installs it. Do not lower it, and do not bypass it with `--ignore-workspace`.

**TEC-10 [STD]** No dependency is installed to solve a problem that has not been reproduced. "It is
standard" is not a justification; "we hit this and here is the trace" is.

**TEC-11 [REC]** Prefer a dependency already in the tree over a new one. Prefer a platform API over a
package. Prefer 50 lines of readable code over a package that does the same thing invisibly.

### 3.5 Third-party services

**TEC-12 [FOUNDER]** Any service that receives Hivorr data, holds a credential, or sits in a request
path requires founder approval before integration. That includes email delivery, SMS and OTP,
payments, KYC and identity verification, maps and geocoding, analytics, error tracking, object
storage, CDN, and AI providers.

The approval records: what data leaves the system, where it goes, the legal basis for sending it,
the data-processing terms, the failure behaviour if the service is down, and the exit path.

**TEC-13 [STD]** A third-party service is never in the critical path of a money-moving operation
without a documented failure mode. If the provider is down, the operation fails closed and is
reconcilable — it does not half-succeed.

**TEC-14 [STD]** No third-party script runs on an authenticated page (`ARCHITECTURE.md` §10.11).
Analytics, tag managers, chat widgets and A/B tools are scripts. If one is required, it is
self-hosted or it is **[FOUNDER]** approved with the data it observes written down.

**TEC-15 [STD]** A vendor that processes personal data is recorded with its data category, region and
retention (§6.8). A vendor nobody can name is a data-protection defect.

### 3.6 Installed but not adopted

**[FACT]** The repository contains packages that are installed and imported nowhere
(`ARCHITECTURE.md` §2.4, §15.2). They are dead weight and a supply-chain surface.

**TEC-16 [STD]** The following **must not be used**: `@mui/material`, `@mui/icons-material`,
`@emotion/*`, `@popperjs/core`, `react-popper`. They constitute a second component and styling
system, which `ARCHITECTURE.md` §2.5 forbids. The four MUI and emotion entries were removed from
`package.json` on 3 November 2026 (EX-07); the remaining two are removed when the prototype retires.
Do not re-add any of them.

**TEC-17 [REC]** Removing dormant packages is a welcome, low-risk change. It is not urgent, and it is
never bundled into an unrelated pull request.

**TEC-18 [STD]** `default_shadcn_theme.css` at the project root holds the old Figma palette and is
not imported. It must not be imported (`AGENTS.md` §7 #11).

### 3.7 Prohibited technologies

**TEC-19 [STD]** The following are prohibited, and adding one is a **[FOUNDER]** decision rather
than a technical one:

| Prohibited | Reason |
| --- | --- |
| A second UI kit or CSS-in-JS library | Breaks the prototype's visual authority (`AGENTS.md` §2). |
| A second icon set | Same. |
| A second CSS palette or stylesheet defining colour | Same. |
| Dart/Flutter, or any replacement for React | Superseded directive (`AGENTS.md` §1). |
| An ORM that hides SQL and cannot express RLS-aware queries | Conflicts with the database rules. |
| `eval`, `new Function`, dynamic `import()` of a user-supplied path | Code execution. |
| A client-side database driver | The client never reaches the database (§6.1). |
| A public GraphQL or Data API surface on the primary database | `database rules` §3.2. |
| A feature-flag service that evaluates flags in the client | Capability authority must be server-side. |
| A "temporary" admin bypass, impersonation shortcut or debug backdoor | Permanent in practice, and the highest-value target in the system. |

### 3.8 Deprecation and removal

**TEC-20 [REC]** A technology is removed when it is unused, when its maintenance has stopped, or when
it has been superseded by an approved decision. Removal follows the same review as addition, and the
lockfile change is its own pull request.

---

## 4. Application security

This section states Hivorr's obligations. Where a mechanism is already specified elsewhere, the
mechanism is cited, not repeated: enforcement layers in `ARCHITECTURE.md` §10.2, session and cookie
rules in `ARCHITECTURE.md` §5.4, the error contract in the matrix §11.5, database access in the
database rules.

### 4.1 The threat model this section answers

**[FACT]** `ARCHITECTURE.md` §10.13 records the threat model. The conclusions that matter for this
section are:

- The client is hostile and the network is hostile (`ARCHITECTURE.md` §10.1).
- The highest-value targets are `control.` and the financial ledger, not the public storefront.
- `partners.` is the lowest-trust externally facing surface (`ARCHITECTURE.md` §7.4).
- A hostname proves nothing; a subdomain is a deployment boundary, not a control
  (`ARCHITECTURE.md` §10.12).
- The named threats include IDOR, cross-activity leakage, cross-audience leakage, staff and developer
  overreach, webhook spoofing, malicious uploads and supply-chain compromise.
- Broken access control is the first category of `OWASP Top 10:2025`, which is consistent with the
  threat model's emphasis on capability checks over perimeter controls.

**SEC-01 [STD]** Every new surface — endpoint, page, bucket, job, webhook, admin action — is
considered against this model before it is built. The question is not "is this feature secure?" but
"what can an attacker do with it, and what stops them?"

### 4.2 Injection

Injection is not limited to SQL. Hivorr's injection surface includes SQL, shell commands, template
rendering, log forging, header injection, LDAP-like directory filters, and prompt injection into any
AI feature.

**SEC-02 [STD]** All SQL is parameterised. No exception. String concatenation, template literals and
`format()` with untrusted values are prohibited in every query, including migrations, seeds, test
fixtures and administrative scripts.

```ts
// Prohibited
db.query(`select * from orders where id = '${id}'`);

// Required
db.query('select * from orders where id = $1', [id]);
```

**SEC-03 [STD]** Identifiers cannot be parameterised, so they are never taken from user input
directly. A dynamic column, sort direction, table or schema name is mapped through an explicit
allowlist in code, and an unknown value is rejected rather than passed through.

**SEC-04 [STD]** `LIKE` and `ILIKE` patterns escape `%`, `_` and the escape character before the
value is interpolated into the pattern. A user-supplied `%` is data, not a wildcard.

**SEC-05 [STD]** Dynamic query construction composes **predicates**, not SQL strings. A query builder
is acceptable only if it emits parameters; a builder that accepts raw fragments reintroduces the
problem.

**SEC-06 [STD]** No application code executes user-supplied SQL, and no `security definer` function
builds SQL from an argument. Where a database function must be dynamic, it uses `format()` with
`%I`/`%L` on values it has already validated against an allowlist (`database rules` §7).

**SEC-07 [STD]** OS commands are not built from user input. If a command must run, it is invoked with
an argument array, never a shell string, and the arguments are validated.

**SEC-08 [STD]** Log entries are structured, not concatenated. A value that contains a newline does
not get to create a log line. This is log injection, and it is how an attacker hides their activity
from the person reading the logs.

**SEC-09 [STD]** Any feature that passes untrusted text to a language model treats that text as
hostile input. It cannot cause a tool call, a database write, a payment or a permission change
(`AGENTS.md` Rule 1, §12.5).

### 4.3 Cross-site scripting

**FACT** React escapes interpolated text and attribute values by default. `dangerouslySetInnerHTML`
exists precisely to bypass that escaping, and the React documentation describes it as a risk
([React — Common components](https://react.dev/reference/react-dom/components/common), checked
3 November 2026). Escaping protects against the common case; it does not protect against a URL scheme,
an unsafe sink, or a sanitised-HTML decision made badly.

**SEC-10 [STD]** `dangerouslySetInnerHTML` is prohibited in Hivorr code. So are `innerHTML`,
`outerHTML`, `document.write`, `insertAdjacentHTML`, `srcdoc`, `eval`, `new Function`, and string
arguments to `setTimeout`/`setInterval`.

**SEC-11 [REVIEW]** If a genuine requirement exists — rendering trusted, already-sanitised content
from a controlled source — the exception is approved, the sanitiser is named, and the sanitiser runs
at render time on the value, not at write time on the database. Sanitising on write is not
sanitising; the stored value is later rendered by something that did not sanitise it.

**SEC-12 [STD]** A URL that comes from user input, a database field or an API response is validated
before it reaches `href`, `src`, `action` or `formAction`. The allowlist is `https:`, `http:` for
approved media, `mailto:` and `tel:`. `javascript:`, `data:` and `vbscript:` are rejected. Do not rely
on React's warning behaviour as the control.

**SEC-13 [STD]** Markdown, rich text, and any user-authored HTML are rendered through a sanitiser with
an explicit allowlist of tags and attributes. Links inside rendered content carry
`rel="noopener noreferrer"` and open in a new context only when the destination is external.

**SEC-14 [STD]** A content security policy is served from the edge on every host, not only from a
`<meta>` tag (`ARCHITECTURE.md` §8.11, §10.2). `script-src` is `'self'` plus a per-response nonce or
hash; `object-src 'none'`; `base-uri 'none'`; `frame-ancestors 'none'`. See §4.10 for the current
exception on `style-src`.

**SEC-15 [STD]** User-uploaded content is never served from the application origin as an active
document. Images are served with a correct `Content-Type` and `X-Content-Type-Options: nosniff`;
anything that is not an image is served with `Content-Disposition: attachment`. SVG uploads are
rejected or sanitised, because SVG is an XML document that can carry script (§4.7).

**SEC-16 [REC]** Once the prototype's inline styles are migrated into the token layer, enable
Trusted Types (`require-trusted-types-for 'script'`) as a second line of defence against DOM-based
XSS.

### 4.4 Cross-site request forgery

Hivorr's cookie design reduces CSRF risk but does not remove it, and the reason is worth stating
precisely.

**FACT** Session cookies are host-only, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, with the
`__Host-` prefix (`ARCHITECTURE.md` §5.4). `SameSite` is evaluated against the **registrable domain**,
not the host. `control.hivorr.com` and `hivorr.com` are therefore *same-site* even though they are
cross-origin. A page on a compromised sibling subdomain can issue a request to `hivorr.com` that
carries `hivorr.com`'s `SameSite=Lax` cookie. Host-only scoping prevents the *cookie* from leaking to
the sibling; it does not prevent the sibling from *causing* a request.

**SEC-17 [STD]** No state change occurs on `GET`, `HEAD` or `OPTIONS`. Ever. Not "log out", not
"mark as read", not "send again". This is the control that makes `SameSite=Lax`'s top-level
navigation allowance harmless.

**SEC-18 [STD]** Every state-changing request is validated on the server, in this order:

1. The method is `POST`, `PUT`, `PATCH` or `DELETE`.
2. The `Origin` header is present and **exactly** matches the allowlist entry for the entry point
   (`ARCHITECTURE.md` §4.7 #4, §4.9). An absent `Origin` on a state-changing request is rejected.
3. The `Content-Type` is `application/json` (or `multipart/form-data` for uploads). `text/plain`,
   `application/x-www-form-urlencoded` and missing content types are rejected on JSON endpoints,
   because those are the types a cross-origin HTML form can send without a preflight.
4. The session's audience matches the endpoint's audience (`ARCHITECTURE.md` §5.4).

**SEC-19 [STD]** CORS is never `Access-Control-Allow-Origin: *` on an endpoint that accepts
credentials, and `Access-Control-Allow-Credentials: true` is only ever paired with an exact origin
from the allowlist. The browser path is same-origin through the edge (`ARCHITECTURE.md` §4.9), so
the allowlist governs the edge-to-origin hop and any future public surface.

**SEC-20 [STD]** `SameSite=None` is prohibited. If a future surface genuinely requires it, that is a
**[FOUNDER]** decision, because it reopens the cross-site request path this section closes.

**SEC-21 [REC]** For the small number of endpoints that must accept `multipart/form-data` (file
uploads), the `Origin` check in SEC-18 is sufficient and a separate CSRF token is not required. If a
future endpoint must accept a browser form post without a JSON body and without a same-origin
guarantee, add a synchroniser token rather than relaxing the check.

### 4.5 Input validation

**SEC-22 [STD]** Validation happens at the trust boundary: the HTTP handler, the queue consumer, the
webhook receiver, the file parser. Everything downstream may assume the shape is valid — but only
because it was validated there, not because the client said so.

**SEC-23 [STD]** Validation is allowlist-based. Unknown fields are rejected, not ignored. A field is
valid only if it is named, of the expected type, within the expected length, and within the expected
range or enumeration.

**SEC-24 [STD]** Every string has a maximum length, every array a maximum size, every numeric field a
range, and every request body a maximum byte size. An unbounded field is a denial-of-service vector
and a storage cost.

**SEC-25 [STD]** Validation distinguishes **shape** from **business invariant**. Shape is validated at
the boundary; invariants — sufficient balance, activity active, verification approved, KYC tier high
enough — are validated in the service layer, inside the transaction, against current database state.

**SEC-26 [STD]** Text is normalised before comparison and storage where the value is used as an
identifier or for equality: Unicode NFC, trimmed, with a documented case policy. Without this,
`Admin@hivorr.com` and `admin@hivorr.com` become two accounts and two audit trails.

**SEC-27 [STD]** Validation errors return the machine code and field, never the internal reason. "This
field is invalid" is a response; "the regex /^[a-z]{3,}$/ failed" is an information leak.

**SEC-28 [REC]** One validation approach is used across the API. A single schema library, chosen once
(`ARCHITECTURE.md` §16.3 #11 already recommends `zod`; it is not installed, so the choice still needs
sign-off — §16 #1), keeps error shapes consistent and prevents three subtly different definitions of
"valid".

### 4.6 Output encoding and response types

**SEC-29 [STD]** Every response declares its content type explicitly. JSON is
`application/json; charset=utf-8`. Never `text/html` for data.

**SEC-30 [STD]** API responses are built from explicit DTOs, not from a database row. This is both an
over-fetching control and an encoding control: a column added for internal use must not appear in a
response because someone selected `*`.

**SEC-31 [STD]** User-controlled values placed in headers — `Location`, `Content-Disposition`
filenames, custom headers — are validated or encoded. A newline in a header value is a response
splitting defect.

**SEC-32 [STD]** Redirect targets are never taken from a request parameter without an allowlist.
Open redirects are used in phishing, and Hivorr has five hosts that look alike to a user in a hurry.

### 4.7 File uploads

**FACT** Object storage is Cloudflare R2 (`ARCHITECTURE.md` §9.12). Private documents are never on a
public bucket; file access is signed, short-lived and logged (matrix §11.4).

**SEC-33 [STD]** An upload is validated before it is stored:

| Check | Requirement |
| --- | --- |
| Authentication and authorisation | The caller may upload to this purpose, for this owner. |
| Size | Enforced at the edge and in the handler. A limit that exists only in the browser is not a limit. |
| Declared type | Accepted MIME types are an allowlist per purpose. |
| Actual type | Verified from the file's magic bytes, not the extension or the declared `Content-Type`. |
| Filename | Generated server-side. The original name is stored as metadata, never used as a path. |
| Content | Images are re-encoded where feasible; documents are not executed, rendered or parsed by a privileged process. |
| Destination | A private bucket, keyed by owner and purpose. Public buckets are for approved marketing assets only. |

**SEC-34 [STD]** SVG, HTML, JavaScript, executables, archives and documents that embed active content
are rejected for user-facing purposes unless a specific feature requires them and **[REVIEW]** approves
the handling.

**SEC-35 [STD]** Download URLs are short-lived signed URLs, scoped to one object, issued after an
authorisation check, and logged. A signed URL is a capability: it is not placed in a page that is
cached, shared or indexed.

**SEC-36 [STD]** Where a dedicated media origin is used, it is infrastructure, not a sixth entry
point (`ARCHITECTURE.md` §4.9). It is cookieless, serves no HTML, and is recorded in
`ARCHITECTURE.md` §4 before it is used. **[OPEN]** — see §16 #7.

**SEC-37 [STD]** Uploaded files are never trusted to be what they claim. An image that fails to
decode is rejected, not stored. A PDF is not parsed by the API process.

### 4.8 Brute force, abuse and enumeration

**FACT** `ARCHITECTURE.md` §10.10 already requires rate limits on sign-in, OTP issuance, password
reset and privileged endpoints, exponential backoff, lockout, single-use OTPs with a short TTL, and
alerts on credential stuffing, impossible travel and repeated MFA failures.

**SEC-38 [STD]** Rate limiting exists at two layers: coarse at the edge (per IP, per host) and
specific in the application (per account, per action, per endpoint class). The edge limit protects
availability; the application limit protects accounts. One without the other is incomplete.

**SEC-39 [STD]** Authentication responses do not reveal whether an account exists. Sign-in, password
reset and OTP issuance return the same shape and roughly the same timing whether or not the
identifier is known.

**SEC-40 [STD]** Enumeration is treated as a vulnerability, not a usability quirk. Sequential
identifiers, incrementing order numbers, predictable reference codes and "not found" versus
"forbidden" differences all leak (`matrix` §11.4, §11.5). Object identifiers are UUIDv7; access
control never depends on unguessability.

**SEC-41 [STD]** Expensive or abusable operations — search, export, media processing, message send,
quote generation, AI calls — have a per-account quota and a concurrency limit, not only a per-second
rate limit.

**SEC-42 [REC]** Abuse cases are written down with the feature, not discovered after launch. A
promotion, a referral scheme, a free-trial path or a review system is an abuse surface before it is a
growth feature.

### 4.9 Error handling

**FACT** The error contract is fixed by the matrix §11.5: a stable machine code plus a human message,
never a bare error, with distinguishable conditions for not-authenticated versus not-authorised,
activity inactive versus verification missing, KYC tier too low versus limit reached, and not-owned
versus not-found.

**SEC-43 [STD]** A client never receives: a stack trace, a SQL fragment, a table or column name, an
internal hostname or IP, a framework version, a dependency name, an environment variable name, an
upstream provider's raw error body, or a filesystem path.

**SEC-44 [STD]** Every error response carries a correlation id. The full detail — stack, query, input
shape with secrets redacted, provider response — is logged server-side against that id.

**SEC-45 [STD]** An unhandled exception returns a generic `500` with a correlation id and raises an
alert. It never returns the exception message, and it never returns `200` with an error body.

**SEC-46 [STD]** A record the caller does not own returns `404`, not `403`, unless the caller is
legitimately entitled to know the record exists (for example an admin with an audit reason). This is
the matrix §11.5 position and it is deliberate.

**SEC-47 [STD]** Error paths are tested. A test suite that only exercises the happy path has not
tested the error contract; the deny case is the one that matters (§10.4).

### 4.10 Security headers

**SEC-48 [STD]** Every response carries, at minimum:

| Header | Value | Why |
| --- | --- | --- |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | §4.9 of `ARCHITECTURE.md`. `preload` is deferred deliberately. |
| `Content-Security-Policy` | Per §4.3 and SEC-14 | XSS containment. |
| `X-Content-Type-Options` | `nosniff` | Stops MIME confusion. |
| `Referrer-Policy` | `strict-origin-when-cross-origin`; `no-referrer` on privileged hosts | Limits leakage of URLs that contain identifiers. |
| `Permissions-Policy` | Deny camera, microphone, geolocation, payment unless a feature needs it | Reduces the value of an injected script. |
| `frame-ancestors 'none'` (in CSP) | — | Clickjacking. Hivorr has no legitimate framing use case. |
| `Cache-Control` | `no-store` on authenticated JSON | A shared cache must never hold a session response. |

**SEC-49 [STD]** The current `style-src` position is an accepted, recorded exception, not a design
choice (§16 #6). The prototype carries inline styles on 1,065 lines — about 1,880 style objects — plus
228 hex literals (`ARCHITECTURE.md` §8.2); a policy without `style-src 'unsafe-inline'` would break
rendering and therefore the visual authority. Until the migration recorded as EX-01 in §13.3
completes, `style-src`
allows `'unsafe-inline'` while `script-src` remains strict. Inline styles are a far weaker XSS vector
than inline script, but this is a real reduction in defence and must not be forgotten.

**SEC-50 [REC]** `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Resource-Policy: same-origin` are added once the asset pipeline is settled, so that a
compromised window cannot retain a reference to a Hivorr page.

### 4.11 The client-side trust boundary

**SEC-51 [STD]** The following must never appear in any client bundle, for any host, in any
environment:

- A database connection string or database credential of any kind.
- A service-role, secret or admin key for any provider.
- A signing key, encryption key, pepper or HMAC secret.
- A third-party API secret (payment, KYC, SMS, email, maps, AI).
- Pricing formulas, matching weights, fee calculations, escrow splits, fraud thresholds.
- Admin or staff business logic, review criteria, or risk rules.
- A capability decision that the server would otherwise make.

**SEC-52 [STD]** `VITE_`-prefixed environment variables are **public by definition**. They are
inlined into the bundle at build time. Anything secret uses a server-side name with no `VITE_`
prefix and is never imported by frontend code.

**SEC-53 [STD]** Capabilities returned to the client are for presentation only (`matrix` §11.2,
§11.3). Hiding a button is a courtesy; the server check is the control.

### 4.12 Dependency and supply chain

**FACT** `OWASP Top 10:2025` promotes software supply chain failures to A03. Hivorr already has two
controls: exact pinning with a committed lockfile, and `minimumReleaseAge` (`ARCHITECTURE.md` §2.5).

**SEC-54 [STD]** CI fails on a known-vulnerable dependency at High or Critical severity. A finding is
fixed, or recorded as an accepted risk with a named owner and an expiry (§11.5).

**SEC-55 [STD]** CI fails on a secret committed to the repository. A leaked secret is rotated, not
deleted from history and forgotten.

**SEC-56 [STD]** Builds install from the frozen lockfile only. A build that resolves a different tree
than the one reviewed is not the build that was reviewed.

**SEC-57 [REC]** An SBOM is generated per release and retained with the artifact digest
(`ARCHITECTURE.md` §12.7).

**SEC-58 [STD]** A dependency's postinstall script is a code-execution path. New dependencies with
install scripts require **[REVIEW]**.

### 4.13 Coverage against OWASP Top 10:2025

**[FACT]** The current OWASP Top 10 is the **2025** edition, not 2021
([owasp.org/Top10](https://owasp.org/Top10/), checked 3 November 2026). This table is a navigation
aid, not a claim of compliance.

| OWASP 2025 category | Where this document addresses it |
| --- | --- |
| A01 Broken Access Control | §5.7–§5.10, matrix §9.3, §11 |
| A02 Security Misconfiguration | §4.10, §9.2, `database rules` §4 |
| A03 Software Supply Chain Failures | §3.4, §4.12 |
| A04 Cryptographic Failures | §6.7, §5.3 |
| A05 Injection | §4.2, §4.3, §6.2 |
| A06 Insecure Design | §2.1, §4.1, §13.1 |
| A07 Authentication Failures | §5.2–§5.6 |
| A08 Software or Data Integrity Failures | §4.12, §7.8, §9.6 |
| A09 Security Logging and Alerting Failures | §11.2–§11.4 |
| A10 Mishandling of Exceptional Conditions | §4.9, §2.5, §7.2 |

---

## 5. Authentication and authorisation

### 5.1 The distinction

**AUT-01 [STD]** Authentication answers *who is this*. Authorisation answers *may this actor do this,
to this object, now*. They are separate systems, separate code paths and separate failure modes.

Conflating them is the most common serious defect in a system of this shape. A valid session is not a
permission. A signed token is not a permission. Being signed in as an admin does not authorise a
specific admin action on a specific record.

**AUT-02 [STD]** Every request is authenticated **and** authorised. An endpoint that authenticates
and then trusts the result is an authorisation defect waiting for a user with the wrong account id.

### 5.2 Authentication requirements

**FACT** The sign-in identifier is **[OPEN]** — email-first, phone-first, or either
(`ARCHITECTURE.md` §16.4 #14). The requirements below hold regardless of which is chosen.

**AUT-03 [STD]** Registration collects credentials only. No role, mode or activity choice
(`matrix` §5.1). An account exists with zero activities and zero capabilities beyond profile
management.

**AUT-04 [STD]** Where passwords are used, they are hashed with **Argon2id** using one of the
parameter sets published by OWASP, at minimum `m=19456 KiB, t=2, p=1`
([OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html),
checked 3 November 2026). The stronger `m=47104, t=1, p=1` set is preferred where the host allows it.

**AUT-05 [STD]** Password storage never uses a general-purpose hash (SHA-256, SHA-1, MD5), a
reversible encryption, or a homemade construction. A pepper, if used, is stored in the secret manager
and is not in the database.

**AUT-06 [STD]** Where OTP is used: single-use, short TTL, bound to a purpose and an identifier,
rate-limited, stored hashed, compared in constant time, and never returned in a response or a log.

**AUT-07 [STD]** Password reset and identifier-change flows invalidate existing sessions, or at
minimum force re-authentication, and write an audit record. A reset that leaves an attacker's session
alive has not reset anything.

**AUT-08 [STD]** Sign-in, reset and OTP endpoints are rate-limited per identifier and per IP, and are
the first candidates for CAPTCHA or proof-of-work if abuse appears. They are never exempted from
limits "because they are login".

**AUT-09 [STD]** A credential is never logged, echoed, stored in a URL, placed in a query string, or
included in an error message.

### 5.3 Sessions and tokens

**FACT** Sessions are host-only cookies with four audiences — `app`, `control`, `staff`, `partners`
(`ARCHITECTURE.md` §5.4, §10.3). There is no parent-domain cookie. The API has no public hostname
(`ARCHITECTURE.md` §4.9).

**AUT-10 [STD]** A session cookie is `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, and carries the
`__Host-` prefix. `Domain` is never set. The cookie name differs per audience.

**AUT-11 [STD]** The session identifier is opaque, high-entropy and server-verified. The server holds
the session record; the client holds only the identifier. Session state is never encoded in a way the
client can read or modify.

**AUT-12 [STD]** The server rejects a session whose audience does not match the endpoint
(`ARCHITECTURE.md` §5.4). A `partners` session cannot call an activity endpoint even if the person
also holds an ordinary account — they hold a different session for that.

**AUT-13 [STD]** The session identifier is rotated on privilege change: sign-in, elevation, MFA
completion, audience switch, password change. It is destroyed on sign-out, on account suspension and
on credential reset.

**AUT-14 [STD]** Sessions have an absolute lifetime and an idle timeout. The values are **[OPEN]**
(§16 #3); until they are set, no session may be created without both, and neither may be "infinite".

**AUT-15 [STD]** Revocation is immediate and server-side. Suspending an account, closing it, or
removing a grant invalidates its sessions. A revocation that waits for a token to expire is not a
revocation.

**AUT-16 [STD]** A bearer token, if issued for a future mobile client (`ARCHITECTURE.md` §9.7), is
short-lived, audience-scoped, revocable, and paired with a rotating refresh credential. It is never
stored in `localStorage` on a web client.

**AUT-17 [STD]** No token claim is authority. Claims may carry an audience, an expiry and an
identifier; they never carry a capability set, a role that grants access, or a balance. The server
computes capabilities from database state (`matrix` §11.2).

### 5.4 Multi-factor authentication

**FACT** The MFA matrix per surface is `ARCHITECTURE.md` §10.8. This section states the engineering
obligation that makes it enforceable.

**AUT-18 [STD]** MFA is mandatory on `staff.` and `control.` (TOTP), and mandatory on `partners.` for
commission payout access (`ARCHITECTURE.md` §10.8). It is enforced server-side at session or
step-up creation, not by a prompt the client may skip.

**AUT-19 [STD]** A privileged session that has not completed MFA is a *partial* session: it can
complete MFA and nothing else. It cannot read data, call an admin endpoint, or hold a capability.

**AUT-20 [STD]** Repeated MFA failure is rate-limited, alerted, and audited (`ARCHITECTURE.md`
§10.10). A user who has lost their second factor goes through a documented recovery path with
identity re-verification, not through a support override.

**AUT-21 [REVIEW]** Requiring MFA for ordinary accounts, and requiring step-up authentication before
high-value financial actions, are policy decisions with real usability cost. **[OPEN]** — §16 #4.

### 5.5 Authorisation model

**FACT** The authoritative model is the permission matrix: capabilities derived from account,
activated activities and their states, verification lane states, KYC tier and admin role grants
(`matrix` §9.3, §11.2). The service layer is authoritative; the route guard and RLS are additional
layers (`ARCHITECTURE.md` §10.2).

**AUT-22 [STD]** Capability computation is pure, deterministic and server-side. The same inputs
always produce the same set. It is a table-driven test against every cell of matrix §9.3
(`matrix` §16.1).

**AUT-23 [STD]** Every mutating request re-checks the capability **inside the transaction**, against
current state. A check performed before the transaction, or cached from the session response, is a
race condition and a privilege-escalation path.

**AUT-24 [STD]** Authorisation failures distinguish the conditions the matrix requires (§4.9,
SEC-46). They never collapse into a single "forbidden" that leaves a user unable to act and a support
agent unable to diagnose.

**AUT-25 [STD]** Activity capabilities never imply admin capabilities, and admin roles never imply
activity capabilities (`matrix` §14.4). The two axes are orthogonal and must stay orthogonal in code:
separate namespaces, separate grants, separate checks.

**AUT-26 [STD]** No endpoint returns "all" of anything outside an admin scope with an audit reason
(`matrix` §11.4). A list endpoint is scoped to the caller's account, their parties, or their
organisation.

### 5.6 Least privilege

**AUT-27 [STD]** Every actor holds the minimum grant required for its job, for the shortest time.
Grants are explicit, time-boxed where the role is temporary, and recorded.

**AUT-28 [STD]** Database roles follow the same principle: the API role cannot alter schema, the
migration role is separate, and no application role is superuser or holds `BYPASSRLS`
(`database rules` §6.9).

**AUT-29 [STD]** A developer grant is technical only — never money, never PII by default, never
business decisions (`ARCHITECTURE.md` §4.4). It is a distinct, time-boxed grant
(`ARCHITECTURE.md` §16.3 #4), not an admin role with extra warnings.

**AUT-30 [STD]** A service credential is scoped to one service and one purpose. Two services never
share a static key, because a shared key cannot be rotated for one of them.

### 5.7 Object-level authorisation

**AUT-31 [STD]** Every user-owned row carries `owner_account_id`. Every transaction row carries its
parties (`matrix` §11.4). Authorisation for a single object is a check on those columns, in the
service layer, in the same query or the same transaction as the read or write.

**AUT-32 [STD]** An identifier in a URL is never sufficient authorisation. `/orders/{id}` must
resolve the order *for this caller*, not fetch the order and then compare.

**AUT-33 [STD]** An IDOR sweep across every endpoint is part of the security test suite
(`matrix` §16.1). It is run before the first public release and on every change to an authorisation
path.

### 5.8 Privileged and administrative operations

**AUT-34 [STD]** Privileged actions are audited without exception: verification decisions, activity
suspension, account suspension, grant changes, financial mutations, business approval, and every
admin read of private documents (`matrix` §11.6, `ARCHITECTURE.md` §10.9).

**AUT-35 [STD]** Dual control applies to the actions the matrix names (`matrix` §14.3). One person
cannot both request and approve a high-risk action, and cannot approve their own deployment
(`ARCHITECTURE.md` §12.8).

**AUT-36 [STD]** Break-glass access is time-boxed, purpose-bound, alerted in real time, and reviewed
within one business day. It is recorded as an incident, not as a routine operation.

**AUT-37 [STD]** Impersonation, if it ever exists, is a read-only, time-boxed, consented, audited
capability. It is never a silent "view as" that writes.

### 5.9 Authorisation anti-patterns

**AUT-38 [STD]** The following are defects, not shortcuts:

| Anti-pattern | Why it fails |
| --- | --- |
| Hiding a control in the UI as the only check | The endpoint is still reachable. |
| Reading a role or capability from the request body, query string or a cookie the client can set | Attacker-controlled authority. |
| Trusting a JWT claim for a role or capability | Forgeable or stale; the server must derive it. |
| A client-side route guard | Bypassable with a direct request. |
| `if (user.isAdmin)` computed from local state | Same. |
| A single `is_admin` boolean instead of scoped grants | Violates least privilege and the matrix. |
| An endpoint that authenticates and returns data without an object check | IDOR. |
| A "temporary" bypass flag | Permanent in practice. |
| Checking permission before the transaction and writing inside it | Time-of-check to time-of-use. |
| Relying on RLS as the only authorisation | `database rules` §6.2 — RLS is defence in depth, not the model. |

### 5.10 Changing authentication or authorisation code

**AUT-39 [REVIEW]** Any change to authentication, session handling, capability computation, grant
evaluation, RLS policy, or an admin endpoint requires a second reviewer who did not write it, a test
that fails before the change and passes after, and a note in the pull request describing the
security effect.

**AUT-40 [FOUNDER]** Any change that widens who can do something — a new admin scope, a new
capability, a relaxed verification gate, a new privileged surface, a new grant type — requires founder
approval before implementation. Narrowing is a normal change.

---

## 6. Database and data protection

**Detailed authority:** `Database-Migration-and-Supabase-Data-API-Rules.md`. That document governs
roles, grants, RLS policy syntax, function privileges, migration tooling and environment mechanics.
This section states the engineering obligations that surround it and the rules that apply regardless
of which managed Postgres provider is chosen.

**FACT** The provider remains **[OPEN]** (`ARCHITECTURE.md` §16.4 #1). Position A — Supabase, if
chosen, is managed Postgres only, with the Data API and GraphQL disabled, Supabase Auth unused, no
Supabase key in any client, and RLS driven by a transaction-scoped session variable — was adopted on
3 November 2026 (`database rules` §2.4). The provider-specific sections bind only if Supabase is
chosen; everything else binds now.

### 6.1 The single access path

**DAT-01 [STD]** Application code reaches the database through the service layer and its repositories.
There is no second path. In particular: no client-side database driver, no Data API surface, no
GraphQL endpoint on the primary database, no direct connection from a browser or a mobile app, and no
ad-hoc query from a notebook against a shared environment (`database rules` §3.2).

**DAT-02 [STD]** The API connects through a pooler with per-process connection limits, over TLS, with
certificate verification on (`database rules` §10.2). The connection string is an environment
variable, validated at boot, and never logged.

**DAT-03 [STD]** A migration is the only way a schema changes in a shared environment. The SQL editor
and table editor are disabled for everyone not performing a documented break-glass operation, and a
break-glass change is followed by a migration within the same working day (`database rules` §10.7).

### 6.2 Safe database access

**DAT-04 [STD]** Queries are parameterised (§4.2, SEC-02). This applies to repositories, raw SQL,
migration scripts, seeds, fixtures, administrative scripts and tests.

**DAT-05 [STD]** A query selects the columns it needs. `select *` in an application query is a defect:
it over-fetches, it leaks new columns by default, and it breaks when a column is added.

**DAT-06 [STD]** A write that depends on a read is one statement or one transaction. A
read-modify-write across two round trips without a transaction is a lost update.

**DAT-07 [STD]** Money-moving writes use the ledger invariants (`ARCHITECTURE.md` §9.10). They are
idempotent, keyed, and reconciled. A balance is derived from entries; it is never an editable column.

**DAT-08 [STD]** A query that filters on a column which is not indexed is a performance defect on a
table expected to grow. Every foreign key and every column used in an RLS policy filter is indexed as
a leading column (`database rules` §6.6).

**DAT-09 [REC]** A new query shape on a table expected to exceed roughly 10,000 rows is checked with
`EXPLAIN (ANALYZE, BUFFERS)` against realistic data before merge. The plan goes in the pull request.

### 6.3 Roles and grants

**DAT-10 [STD]** Roles are separated by function: a migration role that can change schema, an API
role that cannot, and a worker role where its privileges differ (`database rules` §6.9). No
application role is superuser and none holds `BYPASSRLS`.

**DAT-11 [STD]** Every grant is explicit and minimal. `grant all` is prohibited. `truncate` is granted
to nobody who does not need it. `execute` on a new function is revoked from `PUBLIC` before it is
granted to anyone (`database rules` §7.3).

**DAT-12 [STD]** `anon` holds nothing. If a future public read path needs `anon`, that is a
**[REVIEW]** decision with a named endpoint and a stated reason (`database rules` §5.4).

**DAT-13 [STD]** A grant is never used as a workaround for a broken policy. If a policy is wrong, the
policy is fixed (`database rules` §5.3).

### 6.4 Row-level security

**DAT-14 [STD]** RLS is enabled on every table in a module schema. A table without it fails CI
(`database rules` §11.5).

**DAT-15 [STD]** RLS is defence in depth, not the authorisation model (`database rules` §6.2). The
service layer decides; RLS ensures that a missed filter fails closed rather than leaking.

**DAT-16 [STD]** `auth.uid()` must never appear in a Hivorr policy. Supabase Auth is not used, and the
function returns `NULL`, so a policy built on it silently denies or silently allows depending on how
it is written (`database rules` §6.4).

**DAT-17 [STD]** Every policy names the role it applies to with `to`, handles the unset/NULL identity
case, has one policy per operation, and has a matching `select` policy for every `update`
(`database rules` §6.3).

**DAT-18 [STD]** Every policy has a deny test. A policy that has only been tested with a permitted
caller is untested (`database rules` §11.2; §10.4 of this document).

### 6.5 Functions and database logic

**DAT-19 [STD]** Functions are `security invoker` by default. A `security definer` function exists only
in a private schema, with `search_path` pinned, `execute` revoked from `PUBLIC`, and a stated reason
(`database rules` §7.1–§7.4).

**DAT-20 [STD]** No `security definer` function is created in an exposed schema. Ever
(`database rules` §7.4).

**DAT-21 [STD]** A trigger may enforce an invariant that must hold regardless of caller. A trigger is
never the only place a business rule lives, because it is invisible to the service layer and to the
person debugging an incident.

### 6.6 Keys, secrets and privileged credentials

**DAT-22 [STD]** A service-role key, secret key, database password, or any credential that bypasses
RLS is never present in frontend code, a client bundle, a public repository, a screenshot, a log, a
migration, a seed, a fixture, or a support ticket.

**DAT-23 [STD]** Secrets live in a managed secret store, are injected at runtime, are scoped per
environment, and are rotatable without a code change (`ARCHITECTURE.md` §10.11,
`database rules` §10.2). **[OPEN]** — the secret manager is not yet chosen (§16 #8).

**DAT-24 [STD]** A key is scoped to one purpose. The key used by the API is not the key used by a
migration job, and neither is the key used by a scheduled worker if its privileges differ.

**DAT-25 [STD]** Rotation is planned, not reactive. Every secret has a named owner and a rotation
interval, and a rotation that has never been rehearsed is an incident waiting for a bad day.

### 6.7 Encryption

**DAT-26 [STD]** TLS 1.2 or higher everywhere, with certificate verification enabled. Internal
service-to-service calls are not exempt.

**DAT-27 [STD]** Encryption at rest is required for the database and for object storage, using the
provider's managed encryption. A provider that cannot demonstrate encryption at rest is not
acceptable for production.

**DAT-28 [STD]** Bank details and other high-sensitivity financial fields receive field-level
encryption in addition to storage encryption (`ARCHITECTURE.md` §10.11). The key is held in the
secret manager, not in the database, and never in the same backup as the ciphertext.

**DAT-29 [STD]** Passwords are hashed, never encrypted (§5.2, AUT-04). A password that can be
decrypted is a password that will be decrypted.

**DAT-30 [REC]** Hashing and encryption use platform or well-reviewed libraries. No custom
cryptography, no home-made key derivation, no "simple obfuscation" for anything that matters.

### 6.8 Data classification

**DAT-31 [STD]** Every field that holds personal or sensitive data is classified before it is stored.
The class determines handling, logging, retention and access.

| Class | Examples | Handling |
| --- | --- | --- |
| **Public** | Marketing copy, public listing titles, category names | May be cached and indexed. |
| **Internal** | Feature configuration, internal identifiers, non-personal operational data | Authenticated staff only; not indexed. |
| **Personal** | Name, email, phone, address, profile photo, message content | Minimised, redacted from logs, access-scoped, retention-defined. |
| **Sensitive personal** | Identity documents, KYC evidence, verification selfies, dispute evidence | Private bucket, signed short-lived access, audited reads, never in logs. |
| **Financial** | Bank details, ledger entries, payout records, invoices | Field-level encryption where applicable, dual control, long retention, audit. |
| **Secret** | Passwords, tokens, keys, OTPs, peppers | Never logged, never returned, never stored in plaintext. |

**DAT-32 [STD]** A field's class is recorded where the schema is defined, not in a separate
spreadsheet that drifts.

**DAT-33 [STD]** A new integration or export that moves a class above **Internal** off-platform
requires **[FOUNDER]** approval (§3.5, TEC-12).

### 6.9 Retention and deletion

**FACT** Retention periods for identity documents, KYC evidence, chat history and dispute records are
**[OPEN]** and must be set with counsel (`matrix` §13.4, `ARCHITECTURE.md` §16.4 #7).

**DAT-34 [STD]** Until retention is decided, the position is **retain, do not delete**, and no
automatic purge behaviour is built (`matrix` §13.4). Deleting evidence that a regulation requires is
worse than retaining it too long.

**DAT-35 [STD]** Account closure is not deletion. Closing an account changes state and blocks access;
it does not destroy records with financial, audit or legal obligations (`matrix` §12.6).

**DAT-36 [STD]** Where a deletion obligation does exist, deletion is a documented, audited operation
that covers the database, object storage, backups' practical reach, search indexes and derived
copies. "Deleted from the table" is not deletion if the file is still in a bucket.

**DAT-37 [REC]** Retention rules, once decided, are implemented as a scheduled, idempotent,
audit-logged job with a dry-run mode, not as a manual query.

### 6.10 Backups and recovery

**FACT** `ARCHITECTURE.md` §12.6 requires PITR (7–30 days) plus daily logical dumps to a separate
bucket, plus a quarterly restore drill. `database rules` §10.6 records two provider limitations:
database backups do not include objects stored through a storage API, and daily backups do not store
passwords for custom roles.

**DAT-38 [STD]** Production has point-in-time recovery. A plan without it is insufficient for
production (`database rules` §10.6).

**DAT-39 [STD]** Object storage is backed up separately from the database, because a database restore
does not bring back deleted files. R2 lifecycle and versioning are part of the backup plan.

**DAT-40 [STD]** A restore drill is run quarterly and its result is recorded with the measured
recovery time. A backup that has never been restored is a hypothesis.

**DAT-41 [STD]** The backup destination is not the production account. A compromised production
credential must not be able to delete the backups.

**DAT-42 [OPEN]** Backup tier, PITR retention and dump destination are undecided
(`ARCHITECTURE.md` §16.4 #13). Nothing is configured.

### 6.11 Test data

**DAT-43 [STD]** Test and development environments use synthetic data or properly anonymised data.
Production personal data never reaches a laptop, a CI runner, a preview branch or a demo.

**DAT-44 [STD]** Seeds and fixtures contain no real credentials, no real personal data, and no
production identifiers. A seed that works only against production data is not a seed.

**DAT-45 [STD]** Anonymisation, where used, is irreversible for the fields that matter: names, contact
details, identity numbers and addresses. Replacing a name with "Test User" while leaving the national
ID intact is not anonymisation.

### 6.12 What is prohibited

**DAT-46 [STD]** In the database layer, the following are defects:

- A schema change applied by hand to any shared environment.
- A migration containing a credential, connection string or key.
- `drop table` or `drop column` without a destructive marker, an expand/contract plan and a second
  reviewer (`database rules` §9.6, §11.5).
- A `security definer` function in an exposed schema.
- A policy that references `auth.uid()`.
- A grant to `PUBLIC`, or `grant all`.
- A table in a module schema without RLS.
- A connection from an application role that can alter schema.
- A direct query against production from a developer workstation.
- A backup or dump stored only on the machine that made it.

---

## 7. API and integration security

### 7.1 API design

**FACT** The API is REST with an OpenAPI contract and a generated client (`ARCHITECTURE.md` §9.9).
It is reached same-origin through the edge; it has no public hostname (`ARCHITECTURE.md` §4.9). The
contract diff is a pipeline stage, and a breaking change fails the build (`ARCHITECTURE.md` §12.2).

**API-01 [STD]** The OpenAPI document is the contract. A hand-written client that disagrees with it is
a defect. Generated types are used on the frontend rather than hand-maintained interfaces.

**API-02 [STD]** Resources are nouns, plural, and stable. Actions that are not CRUD are explicit
sub-resources or commands, not verbs smuggled into a path in three different styles.

**API-03 [STD]** An endpoint returns what the caller is entitled to see and nothing else. Response
shapes are explicit DTOs (SEC-30), not database rows and not a generic envelope that includes
whatever the query returned.

**API-04 [STD]** Every endpoint declares its audience and its required capability, and both are
enforced. An endpoint with no declared capability is an endpoint nobody reviewed.

**API-05 [REVIEW]** The versioning scheme is not yet decided (§16 #2). Until it is, changes are
additive only within the existing contract, and a breaking change requires an approved versioning
decision first.

### 7.2 Request handling

**API-06 [STD]** Every request body is size-limited, every field is validated (§4.5), and unknown
fields are rejected. Validation happens before any database access.

**API-07 [STD]** Every request has a maximum execution time. A handler that can wait indefinitely on a
provider is an availability defect (ENG-14).

**API-08 [STD]** Idempotency keys are required on money-moving endpoints and on any endpoint a client
may retry. A retried payment is not a second payment.

**API-09 [STD]** Pagination is mandatory on every collection endpoint. An endpoint that can return an
unbounded list is a defect regardless of current data volume (§8.3).

**API-10 [STD]** Filtering and sorting parameters are allowlisted. A client cannot sort by an
unindexed column, filter by a column it cannot read, or request a field it is not entitled to.

**API-11 [STD]** A response never includes a field the caller's capability does not cover, even if the
field is in the same row. Redaction happens in the DTO, deliberately.

### 7.3 Rate limiting and abuse prevention

**FACT** Edge-level coarse limits and application-level specific limits are both required
(`ARCHITECTURE.md` §10.10, SEC-38).

**API-12 [STD]** Rate limits are defined per endpoint class, not one global number (the thresholds
themselves are **[OPEN]** — §16 #5):

| Class | Examples | Limit shape |
| --- | --- | --- |
| Authentication | sign-in, OTP, reset | Per identifier and per IP, strict, with lockout |
| Read | listings, profile, search | Per account and per IP, generous |
| Write | create, update, upload | Per account, moderate |
| Expensive | export, media processing, AI, quotes | Per account, tight, plus concurrency |
| Financial | withdraw, payout, transfer | Per account, strict, plus step-up auth |
| Machine | webhooks, internal jobs | Per credential, high, with anomaly alerts |

**API-13 [STD]** A rate-limited response is `429` with `Retry-After`. It never returns `200` with an
empty body, and it never silently drops the request.

**API-14 [STD]** Limits are enforced server-side. A client-side throttle is a courtesy to the user,
not a control.

**API-15 [REC]** Limits are configurable per environment so that staging can be tested without
weakening production, and the configuration is versioned.

### 7.4 Machine callers

**API-16 [STD]** A service calling another service authenticates with a scoped credential, not with a
user session and not with a shared static key (AUT-30).

**API-17 [STD]** An internal endpoint is not protected by "it is internal". Internal networks are
reachable from a compromised workload, and the edge-to-origin hop is a network path like any other.

**API-18 [STD]** A machine credential has an owner, a purpose, a scope, an expiry and a rotation
interval. An unowned credential is deleted.

### 7.5 Third-party integrations

**API-19 [STD]** Every integration is recorded with: what data it sends, where it goes, the legal
basis, the failure behaviour, the retry policy, the timeout, and the exit path (TEC-12).

**API-20 [STD]** Outbound requests are made from the server, never from the browser, unless the
provider's design requires it and the exposure is understood. A provider key in a bundle is a
published key.

**API-21 [STD]** A provider response is untrusted input. It is validated before it is stored, before
it changes a state, and before it is rendered.

**API-22 [STD]** A provider failure never leaves a half-completed financial operation. The operation
fails closed, is recorded, and is reconcilable (TEC-13).

**API-23 [STD]** Data sent to a provider is the minimum required. Sending a full user record to a
service that needs an email address is a data-protection defect and a breach multiplier.

### 7.6 Webhooks

**API-24 [STD]** A webhook is authenticated before it is parsed for meaning:

1. Verify the signature over the raw request body, using a constant-time comparison.
2. Reject a timestamp outside a short tolerance window.
3. Reject a replayed event id, using a store of recently seen ids.
4. Only then parse, validate and act.

**API-25 [STD]** The signature is computed over the raw bytes. A handler that parses JSON and
re-serialises before verifying will accept a body that was never signed.

**API-26 [STD]** A webhook handler is idempotent. Providers retry, sometimes for days, and sometimes
out of order. An event applied twice must not double a balance.

**API-27 [STD]** A webhook handler acknowledges quickly and does the work asynchronously. A slow
handler is retried, and retries amplify load during an incident.

**API-28 [STD]** A webhook endpoint is rate-limited and monitored, because it is a public write path
even though it is not a public API.

**API-29 [FOUNDER]** A new inbound webhook is a new trust boundary. It requires founder approval with
the provider, the signature scheme and the failure behaviour recorded.

### 7.7 Outbound requests and SSRF

**API-30 [STD]** The server never fetches a URL supplied by a user without an allowlist. This
includes image imports, link previews, webhook test deliveries, avatar-from-URL and document
fetching.

**API-31 [STD]** Where a fetch is unavoidable, it blocks private, loopback, link-local and cloud
metadata address ranges, disables or re-validates redirects, and enforces a timeout and a response
size limit.

**API-32 [STD]** A DNS name is resolved and validated at connection time, not only at input time.
Validation at input time alone is bypassable by a name that resolves differently later.

### 7.8 Secret management

**API-33 [STD]** A secret is stored in the secret manager, injected at runtime, scoped per
environment and per service, and never in the repository (§6.6, DAT-23).

**API-34 [STD]** A secret is never logged, never included in an error, never returned in a response,
and never placed in a URL, a query string or a client-visible header.

**API-35 [STD]** A secret that has been exposed — in a commit, a log, a screenshot, a ticket, a chat
message — is rotated immediately, even if it was "only" a staging secret. Staging secrets are how
production secrets get found.

**API-36 [STD]** `.env` files are untracked, and `.env.example` contains names and placeholder values
only. A `.env` file in a repository is a defect even if the values are fake, because the next person
fills it in and commits it.

---

## 8. Performance and scalability

### 8.1 Budgets

**PER-01 [REC]** Budgets are set from measurement, not aspiration. The first baseline is captured
before the first screen is extracted from the prototype, and it becomes the reference for regression.

Initial targets, to be confirmed against that baseline:

| Surface | Target | Measured how |
| --- | --- | --- |
| Initial route JS, per bundle | ≤ 200 KB gzipped | Build output |
| Largest contentful paint | ≤ 2.5 s on a mid-tier Android over 4G | Lighthouse, throttled |
| Interaction responsiveness | ≤ 200 ms for a local interaction | Profiler |
| API read, p95 | ≤ 300 ms, excluding third parties | Server timing |
| API write, p95 | ≤ 800 ms, excluding third parties | Server timing |
| Background job, p95 start latency | ≤ 60 s for non-urgent work | Queue metrics |

**PER-02 [STD]** A change that makes a budget worse by more than 10% requires an explanation in the
pull request. A change that breaches a budget requires **[REVIEW]**.

**PER-03 [STD]** Performance is measured on the built artifact, not the dev server. A dev-only
measurement is not a measurement.

### 8.2 Queries and indexes

**PER-04 [STD]** No N+1. A list of 50 rows does not issue 51 queries. If the ORM or query builder
cannot express the join, the query is written by hand.

**PER-05 [STD]** Every foreign key is indexed. Every column used in a policy filter, a sort, or a
frequent equality filter is indexed as a leading column.

**PER-06 [STD]** Deep `OFFSET` pagination is prohibited on large tables. Use a keyset or cursor
pagination on an indexed, stable ordering column.

**PER-07 [STD]** A count of a large table is not computed on every page load. Use an approximate
count, a cached count, or a "load more" pattern.

**PER-08 [REC]** Aggregate and reporting queries that scan large tables run against a read model or a
scheduled materialisation, not on the request path.

### 8.3 Pagination and collection endpoints

**PER-09 [STD]** Every collection endpoint is paginated with a maximum page size enforced server-side.
A client cannot request 10,000 rows by changing a parameter.

**PER-10 [STD]** The default page size is small enough that a slow client does not hold a connection
open, and the maximum is small enough that a single request cannot exhaust memory.

**PER-11 [STD]** A paginated response is stable under concurrent writes: the ordering includes a
unique tiebreaker, so a page does not repeat or skip rows.

### 8.4 Caching

**PER-12 [STD]** Hashed static assets are served `immutable` with a long max-age. `index.html` is
served `no-cache`, so a deploy is picked up immediately.

**PER-13 [STD]** Authenticated JSON is not cached by a shared cache. `Cache-Control: no-store` on
session-bearing responses (SEC-48).

**PER-14 [STD]** A cache key includes every input that changes the response — including the caller's
identity or scope when the response is user-specific. A cache that ignores identity is a data leak.

**PER-15 [STD]** No new cache tier is added before a measurement shows the database is the bottleneck
(ENG-10, ENG-11). In-process memoisation is acceptable for pure, bounded computations and must have an
invalidation story.

**PER-16 [REC]** Client-side data fetching uses a query cache with explicit staleness per resource,
rather than ad-hoc `useEffect` fetching. `ARCHITECTURE.md` §16.3 #11 recommends TanStack Query; it is
not installed, so the choice still needs sign-off (§16 #1 records the related client-library decisions).

### 8.5 Frontend performance

**PER-17 [STD]** Route-level code splitting per activity (`ARCHITECTURE.md` §8.11). The initial
payload for `hivorr.com` does not include every activity's screens.

**PER-18 [STD]** Images are served at the size they are displayed, in a modern format, with explicit
dimensions to avoid layout shift. A 4,000 px photograph in a 200 px card is a defect.

**PER-19 [STD]** Fonts are limited to the two approved families, subset, and loaded with
`font-display: swap`. A third family is prohibited (`AGENTS.md` §2.6).

**PER-20 [REC]** Fonts are self-hosted rather than fetched from a third-party CDN, which removes a
third-party request from every page and a data-protection question from the font provider. **[OPEN]** —
§16 #17.

**PER-21 [STD]** A blocking third-party script is prohibited on any page (TEC-14). If one is approved,
it is loaded asynchronously and its failure does not block rendering.

### 8.6 Rendering efficiency

**PER-22 [STD]** State that can be derived is derived. Derived state stored in an effect and kept in
sync is a defect, not a pattern
([React — Escape Hatches](https://react.dev/learn/escape-hatches), checked 3 November 2026).

**PER-23 [STD]** List keys are stable and identity-based. An array index as a key is acceptable only
for a list that never reorders, and that fact must be obvious from the code.

**PER-24 [REC]** Memoisation is applied after a measurement, not pre-emptively. `useMemo` and
`memo` around cheap computations add cost and hide the real problem.

**PER-25 [STD]** Long lists are virtualised or paginated. Rendering 500 rows of complex cards is a
defect on a mid-range phone.

**PER-26 [STD]** Effects are for synchronising with external systems, not for data flow between
components. An effect that sets state from props is a re-render loop waiting to happen.

### 8.7 Background processing

**FACT** The queue is PostgreSQL-backed (`ARCHITECTURE.md` §15.5). There is no broker at MVP.

**PER-27 [STD]** Work that is slow, retryable, or not required for the response runs in the queue:
email, SMS, notifications, media processing, webhook fan-out, reconciliation, exports, report
generation.

**PER-28 [STD]** A job is idempotent and carries an idempotency key. A retried job must not send a
second email, charge twice, or duplicate a ledger entry.

**PER-29 [STD]** A job has a maximum attempt count, exponential backoff with jitter, and a dead-letter
destination that a human reviews. A job that retries forever is an outage that never ends.

**PER-30 [STD]** A job is observable: it records start, finish, duration, attempt and outcome. A queue
nobody can see is a queue nobody can trust.

**PER-31 [STD]** A job that touches money or personal data is authorised as the actor that caused it,
not as a super-user. A background worker with unlimited privileges is a privilege-escalation path.

### 8.8 Load and performance testing

**PER-32 [STD]** A load test is run before the first public release, before any marketing event
expected to multiply traffic, and after any change to a hot path or the connection pool.

**PER-33 [STD]** The test measures the endpoints that matter — sign-in, listing, search, checkout,
wallet, message send — not a synthetic `/ping`.

**PER-34 [REC]** The load-testing tool is chosen when the first test is needed. It is not added to the
dependency tree in advance. **[OPEN]** — §16 #14.

### 8.9 Monitoring performance

**PER-35 [STD]** Server timing, queue depth, connection-pool saturation and error rate are recorded per
endpoint class, so that a regression is visible before a user reports it (§11.1).

**PER-36 [STD]** A performance regression that breaches PER-01 is treated as a defect with the same
priority as a functional bug.

### 8.10 What not to build yet

**PER-37 [STD]** The following are prohibited until a measured trigger in `ARCHITECTURE.md` §13.6
fires: read replicas, sharding, a separate cache cluster, a search cluster, a CDN-tier compute layer,
multi-region deployment, and a message broker.

**PER-38 [REC]** When the trigger fires, the measurement that fired it is recorded in the
`ARCHITECTURE.md` §16.1 decision register, so the next person knows why the complexity exists.

---

## 9. Environment and deployment security

### 9.1 Environments

**FACT** There are three deployment targets and four environments including local and CI
(`ARCHITECTURE.md` §11.1, `database rules` §10.1). The hosts are `hivorr.com`, `staging.hivorr.com`,
`control.hivorr.com`, `staff.hivorr.com` and `partners.hivorr.com` (`ARCHITECTURE.md` §4.1).

**DEP-01 [STD]** Development, staging and production are separate. They do not share a database, a
bucket, a secret, a credential, a queue or a deployment pipeline approval.

**DEP-02 [STD]** Each environment has its own configuration and its own credentials. A credential is
never reused across environments, and a production credential never exists outside the production
secret store (`database rules` §10.1, §10.2).

**DEP-03 [STD]** An environment is never a path on a production host. `hivorr.com/staging` is
forbidden (`ARCHITECTURE.md` §4.9).

**DEP-04 [STD]** Staging is structurally identical to production: same migrations, same extensions,
same roles, same headers, same CSP. It may differ in data volume and in configuration values
(`ARCHITECTURE.md` §11.3). A staging environment that cannot reproduce a production bug has no
purpose.

### 9.2 Configuration and secrets per environment

**DEP-05 [STD]** Configuration is injected at deploy time, validated at boot, and fails closed. A
missing required variable stops the process; it does not fall back to a default that silently
disables a control.

**DEP-06 [STD]** A secret is never baked into an image, a build artifact, a bundle or a layer cache.
An image is promotable only if it contains no environment-specific secret.

**DEP-07 [STD]** Environment-specific values are named explicitly (`DATABASE_URL`, `SESSION_KEY_...`)
and are never inferred from `NODE_ENV`. `NODE_ENV=production` is not a security control.

**DEP-08 [STD]** Local development uses `.env.local`, which is untracked. It contains no production
credential and no real personal data (§9.7).

### 9.3 Isolation

**DEP-09 [STD]** Staging cannot reach production resources: not the database, not the bucket, not the
queue, not a production provider key (`ARCHITECTURE.md` §11.4). Network egress from staging to
production is blocked at the infrastructure level, not by convention.

**DEP-10 [STD]** A preview deployment per pull request is ephemeral, data-less, and uses placeholder
secrets. It never receives production data or a production credential.

**DEP-11 [STD]** Test fixtures and seeds are synthetic (§6.11). A staging database restored from
production is a data-protection incident, not a convenience.

**DEP-12 [STD]** The privileged hosts are `noindex` and disallow all crawlers
(`ARCHITECTURE.md` §4.7 #7, §4.9). A search result pointing at `control.` is a finding.

### 9.4 Production protection

**FACT** Every production release requires explicit founder approval, per deployment, attached to a
specific artifact digest and migration set. There is no standing auto-deploy
(`ARCHITECTURE.md` §12.5).

**DEP-13 [STD]** Production deployment is triggered only by promoting an artifact that already ran on
staging. Deploying from a workstation is prohibited (`ARCHITECTURE.md` §12.8).

**DEP-14 [STD]** The production environment requires a named reviewer who is not the deployer, has no
self-approval, and cannot be bypassed by an administrator. An emergency override exists, is logged,
and is reviewed afterwards.

**DEP-15 [STD]** Founder approval of one release does not authorise the next. A re-promoted artifact
requires approval for that promotion.

**DEP-16 [STD]** Production configuration is changed through the pipeline or the provider's audited
interface, never by editing a file on a running host.

**DEP-17 [STD]** A production database migration runs as a separate CI job, as the migrator role,
before the application deploy, after the review gate in §9.5 (`ARCHITECTURE.md` §12.4).

### 9.5 Migration review

**FACT** The review gate is `ARCHITECTURE.md` §12.4 and the security checklist is `database rules`
§11.4. Both apply.

**DEP-18 [STD]** A migration is reviewed as SQL, not as a pull request title. The reviewer reads the
statement, the `db diff` output, and the policy changes.

**DEP-19 [STD]** A destructive change requires an expand/contract plan and explicit founder sign-off.
"Destructive" includes dropping a column, narrowing a type, adding a `not null` without a default to a
populated table, and rewriting a large table.

**DEP-20 [STD]** A migration is forward-only in production. A reversal is a new, reviewed migration
(`database rules` §10.5). A migration that cannot be rolled forward is not merged.

**DEP-21 [STD]** A migration is self-contained: it does not depend on the state of another migration's
data, and it applies cleanly to an empty database (`database rules` §9.4).

**DEP-22 [STD]** Migrations run before the new application image. Exactly one migration job runs at a
time (`database rules` §10.3).

### 9.6 Deployment records, rollback and recovery

**DEP-23 [STD]** Every production deployment records: who approved, when, the artifact digest, the
migration set, the configuration version, what changed since the last release, and the rollback
position (`ARCHITECTURE.md` §12.5, §12.7).

**DEP-24 [STD]** Application rollback is a redeploy of the previous artifact digest. It is rehearsed,
not discovered during an incident.

**DEP-25 [STD]** Database rollback is forward: a new migration that reverses the change. PITR is for
data loss, not for undoing a schema change, because it also reverts every transaction after the
restore point (`database rules` §10.5).

**DEP-26 [STD]** A restore drill runs quarterly and records the measured recovery time
(`ARCHITECTURE.md` §12.6). **[OPEN]** — the RTO target is not set (§16 #13).

**DEP-27 [STD]** Post-deploy verification is part of the deploy: smoke test, error rate and queue depth
watched for 30 minutes (`ARCHITECTURE.md` §12.2 stage 18). A deploy that is not verified is not
finished.

### 9.7 Local development

**DEP-28 [STD]** Local development uses a containerised database or a local instance, seeded with
synthetic data. It never connects to staging or production.

**DEP-29 [REC]** The local environment runs the same migrations from empty, so that "works on my
machine" means "works against the migration history".

**DEP-30 [STD]** Local secrets are placeholders. A developer who needs a real provider credential for
local testing uses a sandbox account belonging to the project, never a production key.

**DEP-31 [STD]** The prototype's dev server (`vite --host 0.0.0.0`, port 8443 by default) is a
development tool. It is never exposed to the internet, and the `0.0.0.0` binding is not carried into a
deployed environment without a deliberate decision.

### 9.8 Emergency change

**DEP-32 [STD]** An emergency change — a security fix, a data-corruption fix, a total outage — may
compress the process but not delete it: the same review, the same migration discipline, a named
approver, and a record. "Just run it on production" is prohibited even during an incident
(`ARCHITECTURE.md` §12.4).

**DEP-33 [STD]** An emergency change is reviewed in full within one business day, and the reason it was
an emergency is recorded. If the same emergency recurs, the process, not the person, is at fault.

---

## 10. Code quality and testing

### 10.1 Type safety

**FACT** `tsconfig.json` sets `strict: true` and `noFallthroughCasesInSwitch: true` (checked
3 November 2026). TypeScript's documentation describes `strict` as enabling the strict-mode family of
checks, and notes that future versions may add checks under the same flag
([TypeScript — strict](https://www.typescriptlang.org/tsconfig/strict.html), checked 3 November 2026).

**QUA-01 [STD]** `strict` stays on. Weakening it, adding `// @ts-ignore`, or adding `any` to silence a
real error is a defect. `// @ts-expect-error` is acceptable only with a comment explaining why the
type system cannot express the case, and it is reviewed.

**QUA-02 [STD]** External input is typed `unknown` until it has been validated. `any` at a trust
boundary is the type-system equivalent of turning off the check.

**QUA-03 [STD]** A non-null assertion (`!`) is not used on a value that came from outside the current
function. It asserts something the compiler cannot verify and the runtime may not honour.

**QUA-04 [REC]** `noUncheckedIndexedAccess` is enabled once the existing code tolerates it. It surfaces
real bugs at array and record access. **[OPEN]** — §16 #15.

**QUA-05 [STD]** Database rows, API responses and provider payloads are mapped into domain types at the
boundary. A domain function does not receive a `Record<string, unknown>` and hope.

### 10.2 Error handling in code

**QUA-06 [STD]** An error is either handled or propagated. A catch block that swallows an error, logs
nothing and continues is a defect, because it converts a failure into silent corruption.

**QUA-07 [STD]** A caught error carries context: what was being attempted, which entity, which
correlation id. `catch (e) { console.log(e) }` is not error handling.

**QUA-08 [STD]** User-facing messages are separate from internal detail. The service layer throws a
domain error with a machine code; the HTTP layer maps it to the error contract (SEC-43, matrix §11.5).

**QUA-09 [STD]** Expected failures — validation, not found, conflict, insufficient balance — are not
exceptions in the control flow of a domain function where a typed result is clearer. Pick one
convention per module and keep it.

**QUA-10 [STD]** A promise is awaited or its rejection is handled. An unhandled rejection is a crash
waiting for a quiet moment.

### 10.3 Structure and reuse

**QUA-11 [STD]** Modules follow the boundaries in `ARCHITECTURE.md` §9.2 and §14.1. A cross-module
import goes through the module's public interface, not into its internals.

**QUA-12 [STD]** No circular dependencies between modules. A cycle means the boundary is wrong, not
that the tool needs configuring.

**QUA-13 [STD]** Shared code lives in the shared package, not in a "utils" folder inside a feature. A
utility used by two modules is shared code; a utility used by one module is that module's business.

**QUA-14 [STD]** Components are typed, single-purpose, and free of business logic. A component that
computes a fee, decides a permission or formats a ledger entry is doing a service's job in the wrong
layer.

**QUA-15 [STD]** Reuse before creating (ENG-03). The list of existing primitives is in `AGENTS.md` §3
and `ARCHITECTURE.md` §8.3–§8.4.

**QUA-16 [REC]** Naming follows the existing vocabulary. No new synonym for an existing concept
(`AGENTS.md` §5). If a new concept is needed, it is named once, in the matrix or `ARCHITECTURE.md`, and
used consistently.

### 10.4 Testing

**FACT** The testing strategy is approved and the tooling is not installed (`ARCHITECTURE.md` §8.10).
Visual regression is mandatory. The levels are unit, component, integration, contract, end-to-end and
visual regression.

**QUA-17 [STD]** The following must have tests before merge, without exception:

| Area | Test type | What it proves |
| --- | --- | --- |
| Capability computation | Table-driven unit | Every cell of matrix §9.3, allowed **and** denied |
| Derived roles | Unit | A role exists only when its full condition holds |
| Financial calculations | Unit, property-based where possible | Rounding, splits, fees, idempotency |
| Authorisation | Integration | Account A cannot read or write account B's records |
| RLS policies | Integration | Allow and deny, per policy |
| Migrations | Integration | Apply from empty, `db reset`, policy tests |
| Money paths | Integration | Transactional, idempotent, reconciled |
| Error contract | Unit and integration | Each condition distinguishable, no leakage |
| Critical journeys | End-to-end | Onboarding → activity → order/errand → wallet → review |
| Rendering changes | Visual regression | 375 / 768 / 1280 px against the baseline |

**QUA-18 [STD]** A bug fix includes a test that fails before the fix and passes after. A fix without a
test is a fix that will regress.

**QUA-19 [STD]** A permission change includes the updated table-driven test in the same change
(`matrix` §16.3). A capability that is not in the test table does not exist.

**QUA-20 [STD]** Line coverage is not a gate. Branch coverage on authorisation and financial modules is:
every allow and deny branch is exercised. A high coverage number with an untested deny path is worse
than a low one, because it creates false confidence. The numeric gate is **[OPEN]** — §16 #16.

**QUA-21 [STD]** Tests do not depend on execution order, on a shared mutable fixture, or on the
network. A flaky test is fixed or deleted, never retried until green.

**QUA-22 [REC]** A test that asserts on an implementation detail is a maintenance cost. Assert on
behaviour that a user or a caller can observe.

**QUA-23 [REC]** Test names describe the rule being protected, not the function being called.
`rejects a write when the activity is inactive` is a test; `test createOrder 2` is not.

### 10.5 Security testing

**QUA-24 [STD]** CI runs, on every pull request: dependency vulnerability scan, secret scan, static
analysis, type check, lint, and the test suite. A failure is a stop, not a warning.

**QUA-25 [STD]** Before the first public release, an IDOR sweep across every endpoint and a privilege
escalation sweep from activity to admin are run (`matrix` §16.1).

**QUA-26 [STD]** A dynamic scan runs against staging before a public launch, not against production.

**QUA-27 [REC]** An independent penetration test is commissioned before public launch and annually
thereafter. **[OPEN]** — vendor and cadence are founder decisions (§16 #12).

**QUA-28 [STD]** A security finding is never closed by suppressing the rule. It is fixed, or it is
recorded as an accepted risk with an owner and an expiry (§11.5).

### 10.6 Code review

**QUA-29 [STD]** No change reaches `main` without review by someone other than its author. Self-merge
is prohibited on `main`.

**QUA-30 [STD]** A reviewer reads the diff, not the description. A description that does not match the
diff is itself a finding.

**QUA-31 [STD]** A pull request that changes authentication, authorisation, money, migrations, crypto,
uploads, webhooks or CI configuration requires two reviewers, one of whom is the architect or a named
security reviewer (AUT-39).

**QUA-32 [REC]** A pull request is small enough to review honestly. A change that cannot be reviewed
in one sitting is split, even if the split is artificial. The exception is a mechanical rename, which
is reviewed by its diff summary and its test result.

**QUA-33 [STD]** The reviewer checks, at minimum:

1. Does the change do what it claims, and only that (bounded scope, `AGENTS.md` §3)?
2. Does it reuse what exists, or does it duplicate (ENG-03)?
3. Is every new trust boundary validated and authorised (§4.5, §5)?
4. Are the deny paths tested (§10.4)?
5. Does it introduce a secret, a raw query, an unsafe sink or a new dependency (§4, §3.4)?
6. Does it change rendering without a visual diff (`AGENTS.md` §6)?
7. Does it record a deviation where one exists (§13.2)?
8. Is the rollback position clear (§9.6)?

**QUA-34 [REC]** A review comment cites a rule identifier or a principle (§1.6). "I don't like it" is
not a review; neither is "LGTM" on a security-sensitive change.

### 10.7 Critical logic

**QUA-35 [STD]** The following are critical, and a change to them requires **[REVIEW]**, tests and an
audit trail:

- Authentication, session handling, MFA, credential reset.
- Capability computation, grant evaluation, admin scopes.
- RLS policies, database roles, grants.
- Ledger, fees, escrow, payouts, refunds, reconciliation.
- Webhook verification and payment provider integration.
- File upload handling and signed URL issuance.
- Encryption, hashing, key handling.
- CI/CD configuration, deployment scripts, environment protection.
- Anything that widens who can do something (AUT-40, **[FOUNDER]**).

**QUA-36 [STD]** A change to critical logic is not merged on the strength of a manual test. It is
merged on the strength of an automated test that would fail if the protection were removed.

### 10.8 Definition of done

**QUA-37 [STD]** A change is done when all of the following are true. This extends `AGENTS.md` §6,
which governs UI work specifically.

| # | Condition |
| --- | --- |
| 1 | It does what the task asked, and nothing unrelated (`AGENTS.md` §3). |
| 2 | It compiles under `strict`, with no new suppression. |
| 3 | It reuses existing components, services and utilities, or states why it cannot. |
| 4 | Every new input is validated; every new endpoint is authorised; every new query is parameterised. |
| 5 | Tests cover the behaviour and the deny path. |
| 6 | No secret, no raw SQL, no unsafe sink, no unapproved dependency. |
| 7 | Rendering changes have a visual diff; no colour, type size or spacing was invented. |
| 8 | Logs contain no personal data or secret; errors carry a correlation id. |
| 9 | Any deviation is recorded (§13.2). |
| 10 | The rollback position is understood. |
| 11 | Any R1/R2 question engaged by the change is classified and, if unresolved, recorded as **[OPEN]** (§19.2–§19.3). |
| 12 | The control has a test that fails if the control is removed, and the test execution is retained (§19.9). |
| 13 | The traceability record is updated, or the change states why no record is required (§19.11, TRC-02). |

### 10.9 Documentation obligations

**QUA-38 [STD]** A change that alters an approved decision updates the document that owns it, in the
same change or an explicitly linked follow-up. An architectural decision goes to
`ARCHITECTURE.md` §16.1–§16.2. A permission change goes to the matrix. A schema change is described by
its migration. A deviation goes to §13.3 of this document.

**QUA-39 [STD]** This document does not gain a second decision register. Registers live where they
already live; this document records only engineering deviations and the decisions it introduces.

**QUA-40 [REC]** A comment explains *why*, not *what*. The code already says what it does.

---

## 11. Monitoring and incident management

### 11.1 What is monitored

**OPS-01 [STD]** The following are monitored in every environment above local, with alerts wired to a
human (the tooling is **[OPEN]** — §16 #9):

| Signal | Why |
| --- | --- |
| Uptime per host | Availability. |
| 5xx rate and latency, per endpoint class | Functional health and performance regression. |
| Database connections, pool saturation, slow queries | The most common cause of a cascade. |
| Queue depth, job failures, dead-letter count | Silent work stoppage. |
| Sign-in failures, MFA failures, lockouts | Credential stuffing and account takeover. |
| Rate-limit rejections by class | Abuse and misconfiguration. |
| Webhook failures and signature rejections | Provider breakage or an attack. |
| Payment and ledger reconciliation mismatches | Money integrity. |
| Backup success and restore-drill results | Recoverability. |
| Certificate and secret expiry | Predictable outages. |
| Deployment events and artifact digests | Correlating a change with a symptom. |

**OPS-02 [STD]** An alert has an owner, a threshold, a runbook and a defined response. An alert nobody
owns is noise, and noise trains people to ignore the real one.

### 11.2 Logging

**OPS-03 [STD]** Logs are structured (JSON), timestamped in UTC, and carry a correlation id that
appears in the error response (SEC-44).

**OPS-04 [STD]** The following are **never** logged, at any level, in any environment:

- Passwords, password hashes, OTPs, recovery codes.
- Session identifiers, bearer tokens, refresh tokens, API keys.
- Full bank account or card numbers, CVV, or national identity numbers.
- Full request bodies for authentication, KYC or payment endpoints.
- Identity documents, selfies, or the contents of private messages.
- The value of any environment variable whose name suggests a secret.

**OPS-05 [STD]** Redaction happens in the logger, not at each call site. A call site will forget.

**OPS-06 [REC]** Log levels are used consistently: `error` for a failure that needs attention, `warn`
for a degraded path, `info` for state changes worth reconstructing, `debug` for development and off in
production unless temporarily enabled.

**OPS-07 [STD]** A log entry identifies the actor by internal id, not by email address or name, unless
the log is specifically an audit record (§11.3).

**OPS-08 [STD]** Log retention is defined per environment. **[OPEN]** — the retention period is
undecided (§16 #10).

### 11.3 Audit trail

**FACT** The audit log is append-only and separate from application logs (`ARCHITECTURE.md` §10.9,
matrix §11.6). It records actor, actor type, audience, action, target type, target id, before/after
summary, IP, user agent, correlation id and timestamp.

**OPS-09 [STD]** The audit log is written by the service layer, inside the transaction that performs
the action, so that the record and the effect cannot diverge.

**OPS-10 [STD]** Audit records are never updated or deleted by application code. A correction is a new
record.

**OPS-11 [STD]** Audited actions are the list in matrix §11.6, without exception, plus every admin read
of a private document, every grant change, every break-glass use, and every production deployment.

**OPS-12 [STD]** An audit record does not contain the sensitive value it describes. It records that a
bank detail was changed, not the account number.

**OPS-13 [STD]** Audit retention is longer than application-log retention, because its purpose is
accountability rather than debugging. **[OPEN]** — the period is undecided (§16 #10).

### 11.4 Alerting and severity

**OPS-14 [STD]** Incidents are classified, and the classification determines who is told and how fast.
The definitions below are a proposal for a small team and need confirmation (§16 #19).

| Severity | Definition | Response target |
| --- | --- | --- |
| **S1** | Confirmed or suspected breach, money loss, or total outage | Immediate; founder informed within 1 hour |
| **S2** | Major function unavailable, or a security control failing | Within 4 hours |
| **S3** | Degraded function, single-tenant impact, or a High finding | Within 1 business day |
| **S4** | Cosmetic, internal, or a Low finding | Next scheduled cycle |

**OPS-15 [STD]** An alert is tested before it is trusted. A channel that has never fired is a channel
that may not work.

**OPS-16 [STD]** An alert that fires repeatedly without action is either fixed or deleted. Alert
fatigue is a security failure, because it hides the one that matters.

### 11.5 Vulnerability reporting and remediation

**OPS-17 [STD]** Anyone — contributor, contractor, user, researcher — can report a vulnerability
through a named private channel. Reports are acknowledged, triaged and tracked.

**OPS-18 [STD]** A vulnerability is remediated within a target set by severity. The targets are a
Hivorr decision, not an industry requirement; until they are approved, the proposed defaults are:

| Severity | Target |
| --- | --- |
| Critical | 7 days, or immediately if exploited |
| High | 30 days |
| Medium | 90 days |
| Low | Next scheduled cycle |

**[OPEN]** — §16 #11.

**OPS-19 [STD]** An accepted risk is recorded with the finding, the reason, the compensating control,
the owner and an expiry date. An accepted risk with no expiry is an unmanaged risk.

**OPS-20 [STD]** A dependency advisory is treated as a vulnerability in Hivorr, not as an upstream
problem. If the fix is not available, the compensating control is written down.

**OPS-21 [STD]** A public disclosure is coordinated by the founder. No contributor confirms, denies or
discusses a vulnerability publicly without approval.

### 11.6 Incident response

**OPS-22 [STD]** The response sequence is: **detect → triage and classify → contain → eradicate →
recover → review**. Containment precedes root-cause analysis, because a system still being exploited
is not a system to investigate calmly.

**OPS-23 [STD]** Roles are assigned at the start: an incident lead, a scribe, and a communications
owner. One person may hold more than one role in a small team, but the roles are named so that nobody
assumes someone else is doing it.

**OPS-24 [STD]** The scribe keeps a timestamped log of decisions and actions. It becomes the input to
the review and, if required, to a regulatory notification.

**OPS-25 [STD]** Containment actions are recorded before they are taken where possible: revoked
sessions, rotated secrets, disabled endpoints, blocked IPs, rolled-back deployments.

**OPS-26 [STD]** A confirmed or suspected personal-data breach is escalated to the founder immediately.
Whether and how to notify a regulator or affected users is a founder and counsel decision, not an
engineering one.

**OPS-27 [STD]** Evidence is preserved: logs, audit records, the affected artifact digest, and the
state of the system at the time. A rebuild that destroys the evidence makes the review impossible.

**OPS-28 [STD]** Recovery includes verifying that the vulnerability is closed, not only that the
service is up. A restored service with the same flaw is not recovered.

### 11.7 After an incident

**OPS-29 [STD]** A review is held within five business days for S1 and S2 incidents. It is blameless:
the question is what allowed the failure, not who typed the command.

**OPS-30 [STD]** Every review produces actions with an owner and a date. An action with no owner is a
wish.

**OPS-31 [STD]** If the incident revealed a gap in this document, the document is amended in the same
review cycle. A standard that did not prevent the incident is either wrong or unenforced, and both are
worth fixing.

**OPS-32 [REC]** The review is written down, even briefly. An incident that is only remembered is an
incident that will recur with a different cast.

---

## 12. AI coding agent compliance

This section applies to every AI agent working on Hivorr, including agents invoked by a human, agents
invoked by other agents, and agents that only read. It extends `AGENTS.md`, which remains the AI
development directive.

### 12.1 Inspection before creation

**AI-01 [STD]** Before changing anything, an agent reads, in this order:

1. `AGENTS.md` — the directive, the visual rules, the guardrails.
2. This document — the engineering and security standards.
3. `ARCHITECTURE.md` — what the system is, and which decisions are already taken.
4. The permission matrix — who may do what.
5. The database rules — if the change touches schema, grants, RLS or migrations.
6. `VISUAL-IDENTITY.md` — if the change touches anything a user sees.
7. The prototype, `src/app/App.tsx` — the only UI authority.

**AI-02 [STD]** Before writing a new implementation, an agent inspects the existing code, components,
services, modules, utilities, data models, configuration and assets that could already serve the need
(ENG-03). The agent states what it found. "No existing implementation was found" is a claim that must
be true.

**AI-03 [STD]** An agent does not infer the shape of the system from a single file. It checks the
module boundaries, the existing patterns and the approved documents before inventing a pattern.

### 12.2 Obedience to approved decisions

**AI-04 [STD]** An agent does not override, reinterpret or "improve" an approved architectural,
security or product decision. If a decision appears wrong, the agent reports it and proposes an
amendment; it does not implement the alternative.

**AI-05 [STD]** An agent does not resolve an **[OPEN]** decision by choosing an answer. It stops,
states the decision that is needed, and names who owns it.

**AI-06 [STD]** An agent does not treat this document's silence as permission. A structural choice with
no rule goes to **[REVIEW]** (§13.1), and the agent says so rather than proceeding.

**AI-07 [STD]** An agent does not modify the prototype. Not to fix a bug, not to improve
accessibility, not to align it with a document (`AGENTS.md` §1, §2.11).

**AI-08 [STD]** An agent does not add, substitute or approximate a colour, a type size, a spacing
value, a radius or a shadow. There is no such thing as "a close match" (`AGENTS.md` §2).

### 12.3 Sensitive areas

**AI-09 [STD]** Before modifying any of the following, an agent stops and states the security
implication, the affected rule, and the approval class required:

- Authentication, sessions, MFA, credential reset.
- Capabilities, grants, admin scopes, RLS policies, database roles.
- Payments, ledger, escrow, payouts, fees, reconciliation.
- Webhook verification, provider integrations.
- File uploads, signed URLs, storage policies.
- Encryption, hashing, key handling, secret configuration.
- CI/CD, deployment configuration, environment protection.
- Anything that widens who can do something (**[FOUNDER]**).

**AI-10 [STD]** An agent never runs a migration, a seed or a destructive query against a shared
environment. Local containers only.

**AI-11 [STD]** An agent never creates, rotates, prints or transmits a real credential. If a task
appears to require one, the agent stops and asks.

**AI-12 [STD]** An agent never disables a test, a lint rule, a type check or a CI stage to make a
change pass. If a check is wrong, the check is fixed deliberately and reviewed.

### 12.4 No unverified claims

**AI-13 [STD]** An agent does not claim that something is secure, compliant, verified, tested or
production-ready unless it performed the verification and can state how.

Acceptable: "I ran the type check and the unit tests; the visual diff was not run."
Not acceptable: "The authentication flow is now secure."

**AI-14 [STD]** An agent does not claim a screenshot, a build, a test or a deployment succeeded
without the output that shows it. "It should work" is a statement of belief, and is labelled as one.

**AI-15 [STD]** An agent does not cite a standard, a version or a provider behaviour from memory when
the claim is load-bearing. It checks the current documentation and gives the link and the date
(§14).

**AI-16 [STD]** An agent distinguishes what it verified, what it assumed, and what it did not check.
This is not hedging; it is the only way a human can review the work.

### 12.5 Reporting obligations

**AI-17 [STD]** At the end of a task, an agent reports:

| Field | Content |
| --- | --- |
| **What changed** | Files, and the substance of the change. |
| **What was verified** | The commands run, and their outcome. |
| **What was not verified** | Tests not run, visual diff not captured, environment not exercised. |
| **Security implications** | Any trust boundary touched, and what protects it. |
| **Assumptions** | Anything inferred rather than read. |
| **Deviations** | Any **[REC]** departed from, any **[STD]** deviation record raised. |
| **Unresolved decisions** | Anything **[OPEN]** that blocks or shapes the work. |
| **Risks** | What could go wrong, including what the agent could not test. |

**AI-18 [STD]** An agent reports a conflict between documents rather than choosing one silently
(GOV-05).

**AI-19 [STD]** An agent reports when a task cannot be completed within the stated scope, rather than
expanding scope to make it "work".

### 12.6 Prohibited agent behaviours

**AI-20 [STD]** An agent must not:

| Prohibited | Why |
| --- | --- |
| Modify `src/app/App.tsx` | It is the visual authority and the product's reference. |
| Add or change a colour, type size, radius or shadow | `AGENTS.md` §2. |
| Add a dependency without the justification in TEC-07 | Supply chain and maintainability. |
| Add a second component system, icon set or CSS palette | TEC-19. |
| Write raw SQL by string concatenation | SEC-02. |
| Introduce `dangerouslySetInnerHTML` or another unsafe sink | SEC-10. |
| Hardcode a secret, key, token or credential | DAT-22, API-33. |
| Commit a `.env` file or a real connection string | API-36. |
| Disable or skip a test, lint rule or type check to pass CI | AI-12. |
| Edit `pnpm-lock.yaml` by hand | TEC-08. |
| Run a migration against a non-local database | AI-10. |
| Deploy, or approve a deployment | `ARCHITECTURE.md` §12.5. |
| Change hosting, DNS, TLS or provider configuration | Out of scope for any agent. |
| Create a Supabase project, policy or credential | Out of scope for any agent. |
| Copy code of unknown licence into the repository | §3.3 criterion 6. |
| Fabricate a test result, a benchmark or a citation | AI-13 to AI-15. |
| Silently "fix" a prototype accessibility gap | `AGENTS.md` §2.11. |

### 12.7 Self-check before finishing

**AI-21 [STD]** Before reporting completion, an agent answers these questions. A "no" is either fixed
or reported.

| # | Question |
| --- | --- |
| 1 | Did I read the documents that govern this area, or did I assume? |
| 2 | Did I search for an existing implementation before writing a new one? |
| 3 | Did I touch only what the task required? |
| 4 | Did I introduce a trust boundary? Is it validated and authorised? |
| 5 | Did I add a query, and is it parameterised and indexed? |
| 6 | Did I log anything that is personal, secret or a token? |
| 7 | Did I change rendering, and is there a visual diff? |
| 8 | Did I add a dependency, and did I justify it? |
| 9 | Did I leave an **[OPEN]** decision looking decided? |
| 10 | Does my report separate what I verified from what I assumed? |
| 11 | Did I classify each requirement I relied on, and avoid presenting a recommendation as a legal or contractual obligation? |
| 12 | Did I produce the evidence and update the traceability record, or state why the change does not need one? |

**Audit readiness.** The twelve mandatory behaviours in §19.14 (`AI-22`) are part of this section's
obligations. They apply to every agent, including a sub-agent, and are reported under the AI-17 report
fields rather than as a separate status.

---

## 13. Governance, deviation and enforcement

### 13.1 Which class does this change fall in?

**GOV-08 [STD]** The class of a change is the **highest** class among the rules it engages. A change
that touches an authorisation check and also changes a button label is a **[REVIEW]** change, not a
**[REC]** change with a footnote.

**GOV-09 [STD]** The table below is the default. If a change is not listed, the contributor finds the
nearest listed change and states the analogy in the pull request.

| Change | Class | Who approves |
| --- | --- | --- |
| Copy, layout or styling using existing tokens and primitives | **[REC]** | Review only |
| New component built from existing primitives | **[REC]** | Review only |
| New shared primitive, or a change to an existing one | **[REVIEW]** | Architect |
| New colour, type size, radius, shadow or spacing value | **[FOUNDER]** — prototype change only | A colour is never added or substituted in production UI. A prototype change is a product decision taken first, by the founder; the documents follow (`AGENTS.md` §1, §2.12) |
| Any change to `src/app/App.tsx` | **[FOUNDER]** | Founder — it is the product's visual authority |
| New frontend dependency under 30 KB gzipped | **[REVIEW]** | Architect |
| New dependency over 30 KB, or with an install script | **[REVIEW]** | Architect, with a measurement |
| New infrastructure, paid service, or data-receiving vendor | **[FOUNDER]** | Founder |
| New endpoint in an existing module | **[REVIEW]** | Architect or security reviewer |
| New module, or a new database schema | **[REVIEW]** | Architect |
| New activity | **[FOUNDER]** | Founder |
| Additive migration | **[REVIEW]** | Second reviewer, per `ARCHITECTURE.md` §12.4 |
| Destructive migration | **[FOUNDER]** | Founder, with an expand/contract plan |
| RLS policy, grant or role change | **[REVIEW]** | Architect or security reviewer |
| Authentication, session or MFA change | **[REVIEW]** | Two reviewers (AUT-39) |
| Capability or grant evaluation change | **[REVIEW]** | Two reviewers |
| Anything that widens who can do something | **[FOUNDER]** | Founder (AUT-40) |
| New admin scope or privileged surface | **[FOUNDER]** | Founder |
| Fee, escrow, payout, refund or ledger rule | **[FOUNDER]** | Founder |
| New inbound webhook or payment provider | **[FOUNDER]** | Founder (API-29) |
| New hostname, DNS record, TLS change or redirect rule | **[FOUNDER]** | Founder — never an agent |
| Production deployment | **[FOUNDER]** | Founder, per deployment (`ARCHITECTURE.md` §12.5) |
| Emergency change | **[STD]** process, compressed | Named approver; founder notified; full review within one business day |
| Changing a CI gate, test threshold or lint rule | **[REVIEW]** | Architect |
| Lowering `minimumReleaseAge` or bypassing the lockfile | **[FOUNDER]** | Founder |
| Adding the test toolchain (Vitest, Playwright, Testcontainers) | **[REVIEW]** | Architect |
| A new control that implements an R1 or R2 requirement | **[REVIEW]** | Architect and founder, because the requirement class and applicability are founder decisions (§19.2) |
| A change that implements an R3 control on critical logic (QUA-35) | **[REVIEW]** | Architect or security reviewer, with a traceability record (TRC-01) |
| A change to the audit event schema, audit store or retention | **[REVIEW]** | Architect and founder |
| An external assessment pack or a public statement about audit, compliance or certification | **[FOUNDER]** | Founder — an agent may assemble evidence but may not make the claim (AUD-03, AUD-85) |
| Changing this document | **[FOUNDER]** | Founder |
| Changing `ARCHITECTURE.md`, the matrix, the database rules or `VISUAL-IDENTITY.md` | **[FOUNDER]** | Founder |
| Routine secret rotation on schedule | Operational | Recorded; no approval needed |

**GOV-10 [REC]** The class is stated in the pull request description in one line: `Class: [REVIEW] —
capability change, second reviewer requested`. This makes the gate visible before review begins
rather than after.

**GOV-11 [STD]** An approval is specific. "Approved" on a pull request approves that diff, at that
commit. A later force-push, a rebase that changes content, or an added commit after approval requires
re-approval if the substance changed.

### 13.2 Deviations

**GOV-12 [STD]** A deviation from a **[STD]** rule requires a written record approved before the change
merges. A deviation from a **[REC]** rule requires one sentence in the pull request and no approval.

**GOV-13 [STD]** A deviation record contains:

| Field | Content |
| --- | --- |
| **ID** | `DEV-###`, sequential |
| **Rule** | The identifier and the rule text being deviated from |
| **Scope** | The narrowest statement of where it applies — a file, a module, an endpoint |
| **Reason** | Why the rule cannot be followed now. "It is inconvenient" is not a reason. |
| **Risk** | What exposure the deviation creates, and who is exposed |
| **Compensating control** | What reduces the risk while the deviation stands |
| **Owner** | The person accountable for closing it |
| **Expiry** | A date, or a condition that ends it. Never "indefinitely". |
| **Approval** | Who approved, and when |

**GOV-14 [STD]** A deviation with no expiry is invalid and is treated as an unapproved deviation.

**GOV-15 [STD]** Deviations are recorded in §13.3 of this document, not in a separate file and not in
a pull request comment. A deviation that lives only in a comment is lost at the next refactor.

**GOV-16 [STD]** A deviation is reviewed at each document review cycle. An expired deviation is either
renewed with a new approval or the work stops until the rule is satisfied.

**GOV-17 [REC]** A deviation that recurs in three unrelated places is not a deviation. It is evidence
that the rule is wrong, and the rule is amended through §13.6.

### 13.3 Accepted exceptions register

These are known, accepted departures and debts. They are recorded so that nobody "discovers" them and
treats them as precedent, and so that the exit condition is visible.

| ID | Exception | Why it stands | Scope | Exit condition |
| --- | --- | --- | --- | --- |
| **EX-01** | The prototype carries inline styles on 1,065 lines (about 1,880 style objects), 228 hex literals and 151 inline `fontFamily` values | The prototype is the visual authority and is not being restructured | `src/app/App.tsx` | Inline styles migrate into the token layer as files are touched (`AGENTS.md` §2.12, §7 #12) |
| **EX-02** | `style-src 'unsafe-inline'` is required in the CSP | Strict `style-src` would break the prototype's rendering (EX-01) | All hosts | EX-01 completes, then the policy tightens (SEC-49) |
| **EX-03** | `index.html` declares `color-scheme: light dark` while `theme.css` is light-only | Recorded, deliberately not changed; the prototype is light-only | `index.html` | A dark palette is approved, or the meta tag is corrected with founder approval |
| **EX-04** | The prototype hotlinks Unsplash images | Licensed for prototype use only | `src/app/App.tsx` | Production photography is served from Hivorr-controlled storage (`ARCHITECTURE.md` §16.3 #10) |
| **EX-05** | `ActivitiesHub` is unreachable | Recorded as an MVP requirement, not a new feature | Prototype navigation | The hub is wired or removed, by product decision |
| **EX-06** | A 50-file shadcn kit exists and is imported by nothing | Dormant; the prototype's primitives are the design system | `src/app/components/ui/*` | The kit is removed, or a component is adopted through **[REVIEW]** |
| **EX-07** | `@mui/material`, `@mui/icons-material`, `@emotion/react`, `@emotion/styled`, `@popperjs/core`, `react-popper` were installed and unused | Dead weight, not adopted | `package.json` | **Partly resolved 3 November 2026** - the four MUI/emotion entries are removed from `package.json`; the lockfile still resolves them until `pnpm install` runs (EX-19). `@popperjs/core` and `react-popper` remain, removed when the prototype is retired (`ARCHITECTURE.md` §2.4) |
| **EX-08** | `@types/react` was `^19.0.0` while `react` is `18.3.1` | Types described a different runtime than the one shipped | `package.json` | **Resolved 3 November 2026** - `@types/react` `18.3.31` and `@types/react-dom` `18.3.7`, the latest 18.x definitions, matching React 18.3.1 |
| **EX-09** | `skipLibCheck: true` | Present; masks type errors inside dependencies | `tsconfig.json` | Reconsidered when the dependency tree is pruned |
| **EX-10** | No test tooling is installed | Approved strategy, unbuilt work | `package.json` | **Ruling 2, 4 November 2026:** EP-00 partially closes this row — Vitest runner only (`EP-00-003`); Playwright, Testcontainers and component-test DOM remain EP-01 work against this row. The row stays open until the EP-01 residual lands. |
| **EX-11** | No content security policy is served today | The header contract is specified, not implemented | All hosts | CSP is served from the edge before the first public release |
| **EX-12** | The repository is initialised but has no history: `.git` exists on branch `main` with zero commits and every file untracked | No commit provenance, no branch protection, no CI trigger, no review enforcement | Whole project | **Partly resolved 4 November 2026** - `.git` exists and `main` is the current branch (verified with `git rev-parse --is-inside-work-tree` and `git log`). Still open: the first commit, a branch model, protected `main` and CI. §9 and §10.6 cannot be enforced until then |
| **EX-13** | `guidelines/Guidelines.md` is an unedited Figma Make template | It contains no project rules, though `AGENTS.md` points to it | `guidelines/Guidelines.md` | **Resolved 3 November 2026** — replaced with a pointer to the approved documents; the row is kept for history (§15 #3) |
| **EX-14** | `noUncheckedIndexedAccess` is not enabled | Would surface errors across existing code | `tsconfig.json` | Enabled once the codebase tolerates it (§16 #15) |
| **EX-15** | The proposed `packages/` layout does not exist | Single-package workspace today | `pnpm-workspace.yaml` | Created when the first shared package is extracted (`ARCHITECTURE.md` §14.1) |
| **EX-16** | The dev server binds `0.0.0.0` on port 8443 | Figma Make preview requirement | `package.json` scripts | Never carried into a deployed environment (DEP-31) |
| **EX-17** | `default_shadcn_theme.css` holds the old Figma palette at the project root | Reference copy, not imported | Project root | Deleted once confirmed unreferenced |
| **EX-18** | Five dev-only entries used caret ranges (`typescript`, `oxfmt`, `@types/node`, `@types/react`, `@types/react-dom`) while every runtime dependency is exact and `ARCHITECTURE.md` §2.5 says dependencies are pinned exactly | Dev tooling, not shipped; the lockfile still pins the resolved tree | `package.json` devDependencies | **Resolved 3 November 2026** - all five are pinned exactly: `typescript` 5.9.3, `oxfmt` 0.2.0, `@types/node` 22.20.5, `@types/react` 18.3.31, `@types/react-dom` 18.3.7 |
| **EX-19** | `package.json` was changed on 3 November 2026 (EX-07, EX-08, EX-18, and the new `typecheck` script) but `pnpm-lock.yaml` was not regenerated: this environment has no Node, pnpm or npm, so nothing could be installed or verified | The lockfile's importer block no longer matches `package.json`. `pnpm install --frozen-lockfile` would fail, and no type check has been run against the React 18 types | `package.json`, `pnpm-lock.yaml` | Run `pnpm install` from the repository root, review the diff, commit the regenerated lockfile, then run `pnpm typecheck`. Until that happens, no dependency claim in this repository is verified |

**Deviation records approved under §13.2.** The register above lists standing exceptions. Approved, time-boxed deviations from a **[STD]** rule are recorded below, in the Appendix C format.

| Field | Value |
| --- | --- |
| **ID** | `DEV-001` |
| **Rule** | `QUA-29` — no change reaches `main` without review by someone other than its author; `QUA-31` — CI configuration requires two reviewers, one the architect or a named security reviewer |
| **Scope** | EP-00 CI configuration and review steps: `EP-00-006`, `EP-00-007`, `EP-00-008` |
| **Reason** | One-person team plus AI agents; no second human reviewer is available. The author is an agent and the approver is the human, but `QUA-31` requires two reviewers for CI configuration. |
| **Risk** | A CI defect or gate bypass could merge without second human review; protection could be configured incorrectly. |
| **Compensating control** | Founder review of every diff; agent-assisted review checklist; seeded-failure proof for every gate; required status checks; no self-approval by the author; protection settings exported as evidence. |
| **Owner** | Prince Abidemi Oluwadamilare (Founder) |
| **Expiry** | Before EP-01 touches authentication, capability or migration code, and no later than 2026-12-31, whichever is earlier |
| **Approval** | Founder (Prince Abidemi Oluwadamilare), 2026-11-04 |

**GOV-18 [STD]** An entry in this register is not permission to extend the exception. It describes the
current state; it does not authorise new work that depends on it.

### 13.4 Enforcement

**GOV-19 [STD]** Standards are enforced by gates, not by good intentions. The gates are:

| Gate | What it blocks | Where |
| --- | --- | --- |
| Type check | Any type error, any new suppression | CI |
| Lint and format | Style divergence | CI |
| Unit, component and integration tests | Behavioural regression | CI |
| Visual regression | Unapproved rendering change | CI |
| OpenAPI diff | Breaking contract change | CI |
| Dependency and secret scan | Known-vulnerable dependency, committed secret | CI |
| Migration lint and `db diff` | Unsafe or unreviewed schema change | CI |
| Policy tests | RLS that allows or denies incorrectly | CI |
| Required reviewers | Unreviewed change on a sensitive area | Repository settings |
| Production approval | Any deployment without founder approval | Environment protection |
| Traceability completeness | A change to critical logic with no requirement record, control or evidence (§19.11) | Review checklist, CI report |
| Audit readiness gate | A phase, release or assessment pack that has not passed the applicable AR gate (§19.12) | Phase gate, release checklist, assessment pack |
| Evidence index | A control that cannot be located in the evidence index (§19.8) | Phase close-out |

**GOV-20 [STD]** A gate is not bypassed. If a gate is wrong, it is fixed deliberately, with a reason,
through review. Bypassing a gate is an incident, not a shortcut.

**GOV-21 [STD]** The enforcement in this section depends on EX-12 being resolved. Until the project is
under version control with protected branches and CI, most of these gates do not exist, and this must
be stated in every release record. The repository host and CI provider are **[OPEN]** — §16 #18.

### 13.5 Ownership and review cycle

**GOV-22 [STD]** This document is reviewed every six months, and on any trigger below. The review
produces a changelog entry even when nothing changes.

| Trigger | Why it forces a review |
| --- | --- |
| A new activity is added | Capability, verification and schema obligations change |
| A new hostname, bundle or entry point | `ARCHITECTURE.md` §4.9 and this document's §9 boundaries change |
| A new vendor or integration | §3.5, §7.5 obligations change |
| A change of managed Postgres provider | §6 binding sections change |
| The first production release | Most of this document moves from specified to exercised |
| A security incident, internal or external | OPS-31 |
| A major framework or runtime upgrade | §3.2 and §10 assumptions change |
| A change to funds custody, KYC or retention | §6.8, §6.9, §5 obligations change |
| A new statute, regulator guidance or VFD onboarding requirement | §19.2 requirement classes and the traceability register may change |
| A change to any companion document | §1.3 authority map may need updating |

### 13.6 Amendment

**GOV-23 [STD]** Anyone may propose an amendment. The proposal states the rule, the problem with it,
the proposed replacement, and the effect on existing work.

**GOV-24 [STD]** A **[STD]** rule is amended only with founder approval. A **[REC]** rule's wording may
be amended by the architect. The changelog records who approved what, and why.

**GOV-25 [STD]** An amendment does not retroactively bless work done in violation of the previous rule.
Existing deviations remain recorded until closed.

**GOV-26 [REC]** Amendments are batched into a review cycle where possible. A document that changes
weekly is a document nobody reads.

---

## 14. External references

**[FACT]** All links were checked on **3 November 2026**. External documentation changes; a claim that
depends on a specific behaviour should be re-checked before it is relied on. Where this document
states a requirement, the source is named. Where it states a Hivorr decision, the decision is labelled
as such and is not attributed to an external standard.

### 14.1 OWASP

| Reference | What it establishes | Link |
| --- | --- | --- |
| OWASP Top 10:2025 | The current list of the ten most critical web application security risks. The 2025 edition is current; the 2021 edition is superseded. | https://owasp.org/Top10/ |
| OWASP Top 10:2025 — Introduction | Category definitions and the changes from 2021, including supply chain at A03 and exceptional conditions at A10. | https://owasp.org/Top10/2025/0x00_2025-Introduction/ |
| OWASP ASVS 5.0.0 | A verification framework of security requirements for designing, developing and testing web applications. Version 5.0.0 was published on 30 May 2025. | https://owasp.org/www-project-application-security-verification-standard/ |
| OWASP Cheat Sheet Series | The practical implementation guidance for each control area. | https://cheatsheetseries.owasp.org/ |
| Password Storage Cheat Sheet | Argon2id parameter sets used in AUT-04, and the prohibition on general-purpose hashes for passwords. | https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html |
| SQL Injection Prevention Cheat Sheet | Parameterisation, and the cases where identifiers cannot be parameterised. | https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html |
| Query Parameterization Cheat Sheet | Language-specific parameterisation patterns. | https://cheatsheetseries.owasp.org/cheatsheets/Query_Parameterization_Cheat_Sheet.html |
| Cross Site Scripting Prevention Cheat Sheet | Output encoding, safe sinks, and the limits of escaping. | https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html |
| Cross-Site Request Forgery Prevention Cheat Sheet | SameSite limits, origin validation, and token approaches. | https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html |
| Content Security Policy Cheat Sheet | Policy construction, nonces and hashes. | https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html |
| Input Validation Cheat Sheet | Allowlisting, canonicalisation, and boundary validation. | https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html |
| File Upload Cheat Sheet | Type verification, storage separation, and serving rules. | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| Authentication Cheat Sheet | Credential handling, reset flows, and enumeration resistance. | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html |
| Session Management Cheat Sheet | Session identifiers, rotation, timeouts and revocation. | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html |
| Authorization Cheat Sheet | Server-side enforcement and object-level checks. | https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html |
| Access Control Cheat Sheet | Least privilege, deny by default, and common access-control failures. | https://cheatsheetseries.owasp.org/cheatsheets/Access_Control_Cheat_Sheet.html |
| Error Handling Cheat Sheet | What an error response may and may not reveal. | https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html |
| Logging Cheat Sheet | What to log, what never to log, and how to structure it. | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html |
| Secrets Management Cheat Sheet | Storage, rotation and scoping of secrets. | https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html |
| Server Side Request Forgery Prevention Cheat Sheet | Outbound request validation and address blocking. | https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html |
| Vulnerable Dependency Management Cheat Sheet | Supply-chain controls and remediation. | https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html |
| Transport Layer Security Cheat Sheet | TLS configuration and HSTS. | https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html |
| Database Security Cheat Sheet | Least privilege and database hardening. | https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html |
| Threat Modeling Cheat Sheet | Structured threat analysis for a new surface. | https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html |
| REST Security Cheat Sheet | API-specific controls: methods, content types, rate limits, CORS. | https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html |

### 14.2 Supabase

**FACT** Supabase is **not** the confirmed provider (`ARCHITECTURE.md` §16.4 #1). If it is chosen,
Position A applies (`database rules` §2.4) and the references below are the authoritative source for
the platform behaviour those rules describe.

| Reference | What it establishes | Link |
| --- | --- | --- |
| Row Level Security | How RLS policies are written and evaluated. | https://supabase.com/docs/guides/database/postgres/row-level-security |
| API keys | The distinction between publishable and secret keys, and what a secret key bypasses. | https://supabase.com/docs/guides/api/api-keys |
| Securing your API | Exposed schemas, grants, and the Data API surface. | https://supabase.com/docs/guides/api/securing-your-api |

### 14.3 React

| Reference | What it establishes | Link |
| --- | --- | --- |
| Common components — `dangerouslySetInnerHTML` | The prop exists to bypass escaping and is documented as unsafe. | https://react.dev/reference/react-dom/components/common |
| Escape Hatches | When effects, refs and DOM access are appropriate, and when they are not. | https://react.dev/learn/escape-hatches |
| You Might Not Need an Effect | Derived state and data flow without effects (PER-22). | https://react.dev/learn/you-might-not-need-an-effect |
| Rendering Lists | Keys and identity (PER-23). | https://react.dev/learn/rendering-lists |

### 14.4 TypeScript

| Reference | What it establishes | Link |
| --- | --- | --- |
| `strict` | The strict-mode family of checks, and that future versions may add checks under the flag. | https://www.typescriptlang.org/tsconfig/strict.html |
| `noUncheckedIndexedAccess` | The indexed-access check referenced in QUA-04. | https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html |

### 14.5 Platform and tooling

| Reference | What it establishes | Link |
| --- | --- | --- |
| PostgreSQL 16 — Row Security Policies | The database-level semantics RLS depends on. | https://www.postgresql.org/docs/16/ddl-rowsecurity.html |
| PostgreSQL 16 — `PREPARE` | Server-side parameterised statements. | https://www.postgresql.org/docs/16/sql-prepare.html |
| Node.js release schedule | Which Node lines are supported; Node 22 is the approved runtime. | https://nodejs.org/en/about/previous-releases |
| pnpm settings | `minimumReleaseAge` and lockfile behaviour. | https://pnpm.io/settings |
| Vite — Building for Production | Asset hashing, chunking and base configuration. | https://vite.dev/guide/build |
| Cloudflare R2 | Object storage, lifecycle rules and access control. | https://developers.cloudflare.com/r2/ |
| MDN — `Set-Cookie` | `SameSite`, `Secure`, `HttpOnly` and cookie scope semantics. | https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie |
| MDN — Content Security Policy | Directive semantics, including `style-src` and `script-src`. | https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP |
| NIST SP 800-218 — Secure Software Development Framework | The organisational practices this document's governance section approximates. | https://csrc.nist.gov/pubs/sp/800/218/final |

### 14.6 What these references do and do not establish

**GOV-27 [STD]** An external reference establishes a technique or a risk. It does not establish a
Hivorr requirement. A requirement exists in this document because a rule says so, and the rule is
Hivorr's, not OWASP's.

**GOV-28 [STD]** A version number is stated with the reference because these documents change. OWASP
Top 10:2025 and ASVS 5.0.0 are current as of the checked date; a later reader must confirm before
citing them.

**GOV-29 [STD]** No citation in this document is a claim of compliance. Hivorr has not been assessed
against ASVS, and referencing it is not an assessment.

---

## 15. Conflicts and inconsistencies discovered

These were found while writing this document. Rows 1-9 were closed on 3 November 2026 by editing the
documents named; the founder directed that the documentation be brought into line with this one.
Rows 10 and 11 are partly closed, and what remains of each is tracked as EX-10 and EX-12. Every row
is kept so that the history is visible.

| # | Inconsistency | Why it matters | Proposed resolution | Status |
| --- | --- | --- | --- | --- |
| 1 | `AGENTS.md` §1 said "Engineering and security rules - **This document**", meaning `AGENTS.md` itself. This document is now the detailed authority. | Two documents claim the same authority. A reader will follow the shorter one. | Add one row to the `AGENTS.md` §1 table: detailed engineering and security standards → this document; `AGENTS.md` remains the AI directive and summary. | **Resolved 3 November 2026** - `AGENTS.md` §1 now carries both rows. |
| 2 | `AGENTS.md` "Key Files" did not list this document. | The entry point an agent reads first will not point at the standards. | Add it to the Key Files list. | **Resolved 3 November 2026** - listed in `AGENTS.md` Key Files. |
| 3 | `AGENTS.md` "Project Guidelines" instructed contributors to "read and always follow" `guidelines/Guidelines.md`, which was an unedited Figma Make template containing no project rules. | An instruction to follow an empty document trains readers to skip instructions. | Replace the file's content with real guidance, or remove the reference and delete the file. | **Resolved 3 November 2026** - the file is now a pointer to the approved documents, and `AGENTS.md` lists those documents directly (EX-13). |
| 4 | The task brief names `VISUAL_IDENTITY.md`; the actual file is `VISUAL-IDENTITY.md`. | A reference that does not resolve is a broken instruction. | Use the hyphenated name everywhere; check any tooling that expects the underscore form. | **Resolved 3 November 2026** - no file used the underscore form; `AGENTS.md` and this document use the hyphenated name. |
| 5 | The matrix §18 #2 and §19 #2 record errand-versus-logistics as open; the founder has since settled it as two separate activities, and `ARCHITECTURE.md` §16.5 #2 records the settlement. | The permission model's schema boundary is described as undecided when it is decided. | One-line edit to matrix §18 #2 and §19 #2 recording the settlement and its date. | **Resolved 3 November 2026** - both rows now record the settlement. |
| 6 | `AGENTS.md` Rule 6 said "buy, hire, discover"; `VISION.md` §3 listed `discover` as an activity while §6 already treated "discover professionals" as a Hire step; the matrix modelled **errand** and recorded `discover` as open. | The activity list was stated three ways. | Founder confirms the Rule 6 wording. | **Resolved 3 November 2026** - the founder ruled `discover` a capability inside Hire, not an activity. `VISION.md` §3, §9 D1 and §10 Q2, `AGENTS.md` Rule 6 and §7 #7, the matrix §4.2, §18 #1 and §19 #1, and `ARCHITECTURE.md` §16.4 #12 and §16.5 #3 now record it. |
| 7 | `AGENTS.md` §7 #12 estimated "~1,900 colours inline" and "~150" font families, while `ARCHITECTURE.md` §8.2 cites 1,065 lines carrying inline styles. The figures measured different things - lines versus style objects - so neither could be checked against the other. | A figure that cannot be reconciled with a measurement is not trusted, and an untrusted number stops being read. | State the measured figures with their units and the date of measurement. | **Resolved 3 November 2026** - `AGENTS.md` §7 #12 now states 1,065 lines (about 1,880 style objects), 151 inline `fontFamily` declarations and 228 hex literals, dated. |
| 8 | `ARCHITECTURE.md` §2.5 forbids a second UI kit, while `@mui/material`, `@mui/icons-material` and `@emotion/*` were installed. | The rule read as violated until the reader found §2.4's "do not use" note. | Not a conflict in substance - recorded as EX-07 so the state is visible in one place. | **Resolved 3 November 2026** - the four MUI/emotion entries are removed from `package.json`; `ARCHITECTURE.md` §2.4 now says so. The lockfile is pending regeneration (EX-19). |
| 9 | `package.json` declared `@types/react` `^19.0.0` against `react` `18.3.1`, and five dev-only entries used caret ranges although `ARCHITECTURE.md` §2.5 says every dependency is pinned exactly. | The type definitions described a different runtime than the one shipped. Types may accept code that fails at runtime, or reject code that works. | Pin `@types/react` and `@types/react-dom` to the React 18 line until React is upgraded, and pin the caret dev entries (EX-08, EX-18). | **Resolved 3 November 2026** - `@types/react` `18.3.31`, `@types/react-dom` `18.3.7`, and all five dev entries pinned exactly. Not yet type-checked, because no Node runtime is available here (EX-19). |
| 10 | `package.json` had no `test`, `typecheck` or `lint` script; only `build`, `dev`, `preview` and `format`. | The pipeline in `ARCHITECTURE.md` §12.2 assumes stages that have no script to run. | Add the scripts when the toolchain is added (EX-10). | **Partly resolved 3 November 2026** - `typecheck` (`tsc --noEmit`) is added; it needs no new dependency. `test` still needs Vitest and `lint` still needs a linter, both of which are dependency additions recorded as EX-10. |
| 11 | This document requires gates (GOV-19) that depend on version control, CI and protected branches; the repository has no commits and no CI. | The standards are unenforceable as written. | Resolve EX-12 before implementation begins; state the gap in every release record until then. | **Partly resolved 4 November 2026** - `.git` exists on `main`, but there is no commit, no branch protection and no CI. The gap stays open |
| 12 | §19 introduces audit readiness gates AR-0–AR-5, while `ENGINEERING_EXECUTION_STRUCTURE.md` already defines phase gates G0–G5. | Two gate ladders could be read as two approvals for the same work, or as a way to pass one and ignore the other. | State that AR gates are evidence checkpoints inside the existing G gates, not a second approval; map each AR gate to the G gate it supports. | **Resolved 6 November 2026** - §19.12 states the relationship, and `ENGINEERING_EXECUTION_STRUCTURE.md` §7 and §8.2 now cross-reference it. No new approval authority was created. |
| 13 | §19 requires an R2 record for every VFD contractual or onboarding requirement, but the full written VFD onboarding set has not been received. | An R2 control could be claimed from a remembered conversation or a provider's general security page, which would be a false compliance claim. | Record VFD onboarding as **[OPEN]**; create R2 records only from documents actually received, with the version and date. | **Open 6 November 2026** - tracked as §16 #23. No R2 control is claimed until the documents are received and reviewed. |

---

## 16. Open decisions requiring founder approval

These are the decisions this document surfaces that are **not** already listed in
`ARCHITECTURE.md` §16.4, the matrix §18, or the database rules §13. The consolidated cross-document
list remains `ARCHITECTURE.md` §16.4; this table adds only what is new.

Nothing here may be implemented as though it were decided, except where a row is explicitly marked **DECIDED**.

| # | Decision | Blocks | Owner | Proposed default |
| --- | --- | --- | --- | --- |
| 1 | **Validation and client-data library** — none is installed; `ARCHITECTURE.md` §16.3 #11 recommends `zod` and TanStack Query, which still need sign-off | Every request validator; error shape consistency (SEC-28, PER-16) | Architect | Confirm the `ARCHITECTURE.md` §16.3 #11 recommendations, then choose once and share types between client and server |
| 2 | **API versioning scheme** — path version, header, or additive-only | The first public contract (API-05) | Architect | Additive-only within v1; a new major path only for a breaking change |
| 3 | **Session lifetimes** — absolute and idle timeouts per audience | Session creation (AUT-14) | Founder + architect | Short absolute lifetime on privileged hosts, longer on `hivorr.com` |
| 4 | **MFA policy for ordinary accounts and financial step-up** | Authentication UX; high-value actions (AUT-21) | Founder | Optional at MVP on `hivorr.com`; step-up required above a KYC-tier threshold |
| 5 | **Rate-limit thresholds per endpoint class** | API-12; abuse posture | Architect | Conservative defaults, tuned from staging measurements |
| 6 | **CSP posture given EX-01** — accept `style-src 'unsafe-inline'` until migration, or restrict inline styles first | Every host's headers (SEC-49) | Architect + founder | Accept the exception, record it, migrate styles as files are touched |
| 7 | **Media origin for user uploads** — a dedicated cookieless host, or the app origin with strict headers | SEC-15, SEC-36 | Founder | Dedicated cookieless origin, recorded in `ARCHITECTURE.md` §4 |
| 8 | **Secret manager** — provider choice, rotation mechanism | DAT-23, API-33, every environment | Founder + architect | A managed secret store with per-environment scoping |
| 9 | **Error tracking and APM vendor** — and whether it receives personal data | OPS-01, §11.1 | Founder | Self-hosted or region-appropriate, with PII scrubbing configured before first use |
| 10 | **Log and audit retention periods** | OPS-08, OPS-13 | Founder + counsel | Application logs short; audit log long; both stated numerically |
| 11 | **Vulnerability remediation SLAs** | OPS-18 | Founder | 7 / 30 / 90 days by severity, as proposed |
| 12 | **Penetration test vendor and cadence** | QUA-27 | Founder | Independent test before public launch, annually thereafter |
| 13 | **RTO and RPO targets** | DEP-26, backup tier | Founder + architect | Set with the backup tier decision (`ARCHITECTURE.md` §16.4 #13) |
| 14 | **Load-testing tool** | PER-34 | Architect | Chosen when the first test is needed; not added in advance |
| 15 | **`noUncheckedIndexedAccess`** | QUA-04, EX-14 | Architect | Enable once the codebase tolerates it |
| 16 | **Coverage gate for authorisation and financial modules** | QUA-20 | Architect | Branch coverage, not line coverage; every allow and deny branch |
| 17 | **Self-hosted fonts versus a third-party CDN** | PER-20 | Architect | Self-hosted, for privacy and to remove a third-party request |
| 18 | **CI provider and repository hosting** — **DECIDED 4 November 2026:** GitHub and GitHub Actions; private repository; protected `main`; native secret and dependency scanning; `staging`/`production` as definitions only; no deployment in EP-00. Kept so cross-references stay valid. | Nothing — settled | Founder | Recorded in `ARCHITECTURE.md` §16.4 #25 and EP-00-000 |
| 19 | **Incident severity definitions and on-call expectations** | OPS-14 | Founder | The four-level table in OPS-14, confirmed for a small team |
| 20 | **Whether `partners.` may ever hold an activity capability** | §4.6 of `ARCHITECTURE.md`, matrix §9.4 | Founder | No — `ARCHITECTURE.md` §7.4 already says no |
| 21 | **External audit programme** — which assessments are commissioned, in what order, by which assessor, at what cadence and budget. VAPT is already proposed (QUA-27, §16 #12); this row covers the data-protection, financial-control, API/infrastructure and access-control assessments in §19.13 | AR-5; assessment scheduling; any public statement about assurance | Founder | Start with a VAPT and an access-control review before public launch; add financial-control and data-protection assessments once the custody and processing models are confirmed. Cadence and vendor remain founder decisions. |
| 22 | **Who may declare Hivorr "audit-ready"** — and in what scope. §19.12 defines the readiness gate but not the person who may speak for the company | AUD-03, AUD-78, AUD-85; every external communication | Founder | Founder only, in writing, with the scope and date named. No agent, contributor or document may make the statement. |
| 23 | **VFD onboarding and contractual requirements** — the full written set, the version received, and which requirements bind Hivorr | Every R2 record; provider integration controls; reconciliation and custody obligations | Founder with counsel | Do not assume. Request the written onboarding pack and the signed agreement, record each requirement as R2 with its source clause, and leave the rest **[OPEN]** (§19.2, §16 #13 row in §15). |
| 24 | **Data-protection assessment scope** — the jurisdictions, processing activities and data classes in scope, and whether a DPIA is required | AUD-32–AUD-40; the data-protection assessment in §19.13 | Founder with counsel | Record the processing inventory first; commission the assessment against the recorded scope, not a generic template. |
| 25 | **KYC/AML applicability** — whether Hivorr carries direct AML, CTF, sanctions or customer-due-diligence obligations, or only contractual obligations through VFD, and which entity reports | AUD-41–AUD-48; verification-lane design; monitoring and escalation | Founder with counsel | Treat every AML/KYC obligation as **[OPEN]** until counsel confirms applicability. Do not build a reporting path to an authority on an assumption. |
| 26 | **Evidence retention period** — how long assessment evidence and traceability records are kept, separately from the audit-log retention in #10 | AUD-57, AUD-86; assessment packs | Founder | Retain for the longest period that any applicable R1/R2 obligation requires, once known; until then, retain and do not purge. |

---

## 17. Changelog

### 6 November 2026 — version 2.1, audit readiness by design

**Approved** — 6 November 2026 by the founder, version 2.1 as written. This is an additive amendment
to version 2.0. It adds §19 and the cross-references needed to make it operative. It removes or
weakens no rule in §2–§18; `QUA-37` and `AI-21` gain the conditions recorded below, and every existing
condition still applies. It does not settle any **[OPEN]** item and creates no legal, regulatory or
contractual obligation.

**What changed**

- Front matter: version 2.1, dated 6 November 2026; the supersedes note records that 2.1 adds §19
  without changing existing rule meanings.
- Added §19, **Audit readiness by design**: requirement classes R1–R5 (§19.2), the pre-implementation
  impact note (§19.3), the secure-engineering, financial-integrity, data-protection, KYC/AML,
  audit-trail, testing and infrastructure baselines (§19.4–§19.10), the `TRC-` traceability rules
  (§19.11), the AR-0–AR-5 gates (§19.12), external-assessment preparation (§19.13), the twelve
  mandatory AI-agent behaviours (`AI-22`, §19.14), and the boundaries of the section (§19.15).
- Added `AUD-` and `TRC-` to the rule-prefix table (§1.6).
- Added `ENG-19` and an audit-readiness test to §2.8.
- Added three conditions to the definition of done (`QUA-37`) and two questions to the agent
  self-check (`AI-21`).
- Added change classes in §13.1 and enforcement gates in §13.4 for audit-readiness work.
- Recorded §15 #12 (AR gates versus G gates) and #13 (VFD requirements not received).
- Added open decisions §16 #21–#26: the external audit programme, the person who may declare
  readiness, the missing VFD onboarding set, the data-protection assessment scope, KYC/AML
  applicability, and evidence retention.
- Added Appendix D, the audit-readiness impact note and traceability template.
- Updated Appendix A and Appendix B for §19.

**What approval does not do**

- It does not assert that Hivorr is compliant, certified, audited or secure (AUD-03, AUD-91).
- It does not settle VFD onboarding requirements, KYC/AML applicability, retention periods or audit
  scope. Those remain **[OPEN]** in §16 and require founder and counsel.
- It does not approve any phase, work package or production release.

### 4 November 2026 — #18 decided and EX-10 split recorded

Recorded the founder's CI and hosting decision: §16 #18 is marked decided and points to `ARCHITECTURE.md` §16.4 #25. Recorded ruling 2 against `EX-10`: EP-00 closes the Vitest runner portion; Playwright, Testcontainers and component-test DOM remain EP-01 work against the same row. No rule changed meaning and no other **[OPEN]** item was settled.

### 4 November 2026 — deviation DEV-001 recorded

Recorded `DEV-001` in §13.3: a time-boxed deviation from `QUA-29` and `QUA-31` for EP-00 CI configuration and review steps. Approved by the founder (Prince Abidemi Oluwadamilare) on 4 November 2026. No rule changed meaning and no **[OPEN]** item was settled.

### 4 November 2026 - version 2.0, approved

**Approved** - 4 November 2026 by the founder, version 2.0 as written, with no conditions recorded.
This is the first approved version. Versions 1.0–1.3 were proposals and created no obligations.

**What approval does**

- Every **[STD]** rule binds from 4 November 2026.
- Every **[REC]** rule is the expected default, and departing from one needs a sentence in the pull
  request, not an approval.
- Every **[REVIEW]** and **[FOUNDER]** rule is a gate: it is enforced at the point §13 describes,
  through the change classes in §1.4 and the gate set in §13.4.
- The deviation process (§13.2), the exceptions register (§13.3) and the enforcement rules
  (`GOV-19`–`GOV-21`) are binding with the document.

**What changed in this version**

- Front matter: status is `APPROVED`, version 2.0, dated 4 November 2026; the supersedes note records
  that 1.0–1.3 were never binding.
- Added §18, the approval record, and the row for it in Appendix A.
- Corrected EX-12 and §15 #11: the repository **is** initialised - `.git` exists on `main` - but it
  has zero commits, no branch protection and no CI. The earlier wording said the project was not a
  git repository, which was wrong; the enforcement gap it describes is unchanged.
- No rule changed meaning. No **[OPEN]** item was settled.

**What approval does not do**

- It does not settle any **[OPEN]** item in §16 or in `ARCHITECTURE.md` §16.4. Nothing in those
  tables may be built as though it were decided.
- It does not approve any phase, work package or production release. Those are separate acts under
  `ENGINEERING_EXECUTION_STRUCTURE.md` §5.2 and §14.
- It does not make the system secure, compliant or production-ready (§1, "Limits of this document").

### 3 November 2026 - version 1.3, dependency and script cleanup

The remaining documentation-adjacent recommendations were applied to `package.json`, and one new
exception was opened because this environment cannot install anything.

**What changed**

- Removed `@mui/material` 7.3.5, `@mui/icons-material` 7.3.5, `@emotion/react` 11.14.0 and
  `@emotion/styled` 11.14.1 from `dependencies`. None is imported anywhere in `src/`, and
  `ARCHITECTURE.md` §2.5 forbids a second UI kit. `@popperjs/core` and `react-popper` stay: they are
  also unused, but removing them is prototype-retirement work, not this cleanup.
- Pinned the five caret dev entries exactly: `typescript` 5.9.3, `oxfmt` 0.2.0, `@types/node`
  22.20.5, `@types/react` 18.3.31, `@types/react-dom` 18.3.7. The first three are the versions
  already resolved in the lockfile, so their resolved tree does not move. The last two replace
  `@types/react` 19.2.6 and `@types/react-dom` 19.3.0, which described React 19 while the runtime is
  React 18.3.1.
- Added the `typecheck` script: `tsc --noEmit`. It needs no new dependency.
- Added `.gitignore`, which covers dependencies, build output, environment files, keys, test output
  and editor state. It does nothing until the repository is under version control (EX-12).
- `ARCHITECTURE.md` §2.4 and §2.5 updated to match.

**What is not done, and why**

No Node, pnpm, npm, git or mise exists in this environment, so nothing could be installed, built,
type-checked or committed. `pnpm-lock.yaml` is therefore stale: its importer block still lists the
removed packages and the old specifiers. This is recorded as EX-19, with the exit condition being
`pnpm install` followed by `pnpm typecheck`. `test` and `lint` scripts were not added, because both
need a dependency that cannot be installed here (EX-10).

### 3 November 2026 - version 1.2, `discover` settled

The founder ruled that `discover` is the browse step inside Hire, not an activity. There remain six
activities: buy, hire, errand, sell, offer services, provide logistics.

The evidence behind the ruling: `VISION.md` §6 already listed "discover professionals" as the first
step of Hire, the prototype's activity selection offers exactly six cards, and `discover` appears in
the prototype only as `emp-discover` ("Find Services") and `pro-discover` ("Find Work"), both reached
from the Hire dashboards. The only contrary line was the §3 umbrella row.

**Documents edited**

- `VISION.md` - §3 umbrella row changed from "buy, hire, discover" to "buy, hire, errand"; the
  prototype note now states the ruling; §9 D1 marked resolved; §10 Q2 marked decided; a revision
  note added to the status block.
- `AGENTS.md` - Rule 6 lists "buy, hire, errand" and states that `discover` is the Hire browse step,
  not an activity; §7 #7 marked resolved.
- `Unified-Account-and-Activity-Permission-Matrix.md` - §4.2 records the decision and cites the two
  prototype screens; §18 #1 and §19 #1 marked decided.
- `ARCHITECTURE.md` - §16.4 #12 and §16.5 #3 marked decided; §16.4 now notes that a row may be
  marked DECIDED.
- `VISUAL-IDENTITY.md` - the reconciliation row for the activity list no longer calls `discover`
  unresolved.
- `Database-Migration-and-Supabase-Data-API-Rules.md` - §12.1 states that `discover` is not an
  activation; §13 rows 4 and 5 are marked decided and the count now reads eleven open decisions.
- `VISION.md` §6 and §10 Q3 - the errand-versus-logistics question, settled earlier the same day as
  two separate activities, is now marked decided instead of open.

**In this document**

- §15 #6 is resolved. Rows 8-11 remain open.

### 3 November 2026 - version 1.1, documentation reconciliation

Six of the eleven inconsistencies recorded in §15 were closed by editing the documents named in
them, at the founder's direction. No rule in this document changed meaning.

**Documents edited**

- `AGENTS.md` - the §1 authority table now separates this document (engineering, security and
  quality standards) from the AI directive; this document is listed under Key Files; the read order
  in §0 includes it; "Project Guidelines" now lists the approved documents instead of pointing at a
  template; Rule 6 notes that the third Explore activity is disputed; §7 #12 states the measured
  prototype figures with their units and date.
- `guidelines/Guidelines.md` - replaced the unedited Figma Make template with a pointer to the
  approved documents. EX-13 is closed.
- `Unified-Account-and-Activity-Permission-Matrix.md` - §18 #2 and §19 #2 now record the founder's
  settlement that errand and logistics are two separate activities; §18 points at
  `ARCHITECTURE.md` §16.4 as the consolidated decision register.
- `Database-Migration-and-Supabase-Data-API-Rules.md` - §13 points at `ARCHITECTURE.md` §16.4 as the
  consolidated decision register.

**Corrections inside this document**

- SEC-49 and EX-01 now state the prototype measurement in the unit actually measured: 1,065 lines
  carrying inline styles, about 1,880 style objects, 228 hex literals and 151 inline `fontFamily`
  declarations. The earlier wording called 1,065 "style objects", which undercounted them.
- §15 rows 1-5 and 7 are marked resolved, with what changed. Rows 6 and 8-11 remain open; row 8 is
  recorded rather than resolved.

**Still open from §15**

- 6 - `discover` in `AGENTS.md` Rule 6 against `errand` in the matrix. Needs a founder decision;
  `ARCHITECTURE.md` §16.4 #12.
- 9, 10 - `@types/react` mismatch and missing `test` / `typecheck` / `lint` scripts. Code and
  configuration, not documentation.
- 11 - no version control, therefore no protected branches or CI. `EX-12`.

### 3 November 2026 - version 1.0, initial document

Created. No previous version exists.

**What it establishes**

- Seventeen sections and three appendices, covering areas A–K of the brief plus governance,
  references, conflicts and open decisions.
- Four governance classes — **[STD]**, **[REC]**, **[REVIEW]**, **[FOUNDER]** — with an explicit
  mapping to the `[DECIDED]` / `[RECOMMENDED]` / `[OPEN]` vocabulary already used in
  `ARCHITECTURE.md`.
- Stable rule identifiers across twelve prefixes, so that a review comment or a deviation record can
  cite a rule rather than a paragraph.
- A change-class table (§13.1) that decides who approves what, so that routine work does not require
  founder approval and security-sensitive work does not proceed without it.
- An exceptions register (§13.3) recording eighteen known departures, each with an exit condition.

**What it deliberately does not do**

- It does not restate `ARCHITECTURE.md`, the permission matrix or the database rules. Where those
  documents specify a mechanism, this one cites the section.
- It does not modify any existing document. Eleven inconsistencies were found and recorded in §15.
- It does not create a competing decision register. Architectural decisions remain in
  `ARCHITECTURE.md` §16; this document records only engineering deviations and the decisions it
  introduces.
- It does not claim that following it makes Hivorr secure (§1, "Limits of this document").

**Sources checked on 3 November 2026**

OWASP Top 10:2025, OWASP ASVS 5.0.0 (published 30 May 2025), the OWASP Cheat Sheet Series index and
the Password Storage, SQL Injection Prevention, XSS Prevention, CSRF Prevention, Content Security
Policy, Input Validation, File Upload, Authentication, Session Management, Authorization, Access
Control, Error Handling, Logging, Secrets Management, SSRF Prevention, Vulnerable Dependency
Management, Transport Layer Security, Database Security, REST Security and Threat Modeling cheat
sheets; React documentation for `dangerouslySetInnerHTML` and Escape Hatches; TypeScript `strict`;
Supabase RLS and API-key documentation; PostgreSQL 16 row-security documentation. All links are in
§14.

---

## 18. Approval

**Approved.** The founder approved this document on 4 November 2026 as version 2.0, and approved the
version 2.1 amendment on 6 November 2026. Approval covers the governance model (§1), the engineering
principles (§2), the technical standards (§3–§13), the audit-readiness standard (§19), the external
references (§14) and the registers in §15–§17.

| Field | Value |
| --- | --- |
| **Approved by** | Founder (AfriNova) |
| **Date** | 4 November 2026 (version 2.0); 6 November 2026 (version 2.1 amendment) |
| **Version approved** | 2.1 |
| **Conditions of approval** | None recorded. The **[OPEN]** items in §16 remain open and are unaffected by this approval. |
| **Next scheduled review** | 4 May 2027, and on any trigger in §13.5 |

**What version 2.1 changed.** It added §19 and extended `QUA-37` and `AI-21` with audit-readiness
conditions. It removed or weakened no rule in §2–§18: every existing condition still applies. The
`AUD-` and `TRC-` rules bind from 6 November 2026, and the `AR-0`–`AR-5` gates apply from that date to
work not yet through the corresponding phase gate. Existing work is not retroactively failed; where an
AR gate was not applied, the gap is recorded under AUD-77 and remediated in the phase it belongs to.

**What approval does not do.** It does not settle any **[OPEN]** decision in §16 or in
`ARCHITECTURE.md` §16.4, does not approve any phase or work package in
`ENGINEERING_EXECUTION_STRUCTURE.md`, does not authorise a production release, and does not assert that
Hivorr is compliant, certified or audited. Each of those is a separate act by the founder or architect
named in Document control, and by the person named in `ENGINEERING_EXECUTION_STRUCTURE.md` §5.2.

**Changing an approved version.** A change to a **[STD]** rule requires founder approval (`GOV-24`).
A change to a **[REC]** rule's wording that does not change its meaning may be made by the architect
and recorded in §17. Every change produces a changelog entry (§13.5).

---

## 19. Audit readiness by design

Audit readiness is not an activity performed before an assessment. It is a property of how work is
designed, built, tested and recorded. A control that cannot be evidenced is, for assessment purposes,
a control that does not exist.

This section does not create a second compliance framework, does not interpret a law or a contract, and
does not certify anything. It makes the work that §2–§13 already requires **traceable**: every
requirement is identified, classified and connected to the control that satisfies it and the evidence
that proves the control operated.

**AUD-01 [STD]** Audit readiness by design means that, for every requirement in scope:

1. the requirement is identified and classified (§19.2);
2. the control that satisfies it is named and implemented (§19.4–§19.10);
3. the evidence that the control exists and operated is produced as part of the work (§19.8);
4. the three are connected in a traceability record (§19.11); and
5. the connection survives review, release and the departure of the person who made it.

**AUD-02 [STD]** Evidence is produced when the work is done, not reconstructed when an assessor asks.
A screenshot taken during the assessment is a claim, not evidence that the control operated at the
time.

**AUD-03 [STD]** No document, release note, marketing statement or agent report may describe Hivorr as
compliant, certified, audited or "audit-ready" unless the specific scope, the assessor, the date and
the evidence are named. Readiness is a state of the work; a clean assessment is an opinion expressed
by an independent party, and neither is promised by this section (GOV-29).

**AUD-04 [STD]** This section applies to every change that touches money, identity, personal data,
authentication, authorisation, third parties, production infrastructure or the audit log, and to every
phase gate in `ENGINEERING_EXECUTION_STRUCTURE.md`. A change outside that scope still follows §19.2 and
§19.14; it may use the short form of §19.3.

### 19.1 What "assessable" means

**AUD-05 [REC]** A control is assessable when a reviewer who did not build it can answer four
questions from the repository and the evidence store alone:

| Question | The evidence that answers it |
| --- | --- |
| What was required, and who required it? | The requirement record, with its class and source (§19.2) |
| What control implements it? | The rule or design decision that names the control, and the code or configuration that applies it |
| How do we know the control operated? | A test that fails when the control is removed, and an execution record (§19.9) |
| Who owns it, and when was it last checked? | The traceability record's owner, review date and status (§19.11) |

### 19.2 Requirement sources and classification

Every requirement carries exactly one class. The class determines what evidence is credible and what
may be claimed. A requirement that has not been classified is not yet a requirement; it is an
assumption.

| Class | Name | Established by | What it obliges Hivorr to do | Evidence standard |
| --- | --- | --- | --- | --- |
| **R1** | Statutory or regulatory | A statute, regulation, regulator's published rule or licence condition | Only what founder and counsel have confirmed applies to Hivorr, in the jurisdiction and activity concerned | The instrument or rule cited by name and date; a written applicability note; the control; the evidence |
| **R2** | VFD contractual or onboarding | The signed VFD agreement, or a VFD onboarding requirement received in writing | Only the requirement actually received in writing, for the activity it covers | The clause or onboarding item, dated and versioned; the control; the evidence |
| **R3** | Internal Hivorr standard | This document, `ARCHITECTURE.md`, the permission matrix, the database rules, `VISUAL-IDENTITY.md` | The rule as written, with its `[STD]`, `[REC]`, `[REVIEW]` or `[FOUNDER]` label | The rule identifier; the control; the test; the evidence |
| **R4** | Industry best practice | OWASP, NIST, ISO, a vendor's security guidance, a peer's published practice | Nothing by itself. It becomes obligatory only where an R3 rule adopts it (GOV-27) | The reference and version; the adopting rule; the evidence |
| **R5** | Recommended improvement | A contributor, reviewer or agent proposal | Nothing until the founder or architect approves it through §13.1 or §13.6 | The proposal; the decision; the owner; the date |

**AUD-06 [STD]** A requirement record states its class. A statement that a practice is "required" without
a class is either reclassified or removed.

**AUD-07 [STD]** An **R1** requirement is not asserted by an engineer, an agent or this document. It is
recorded only after founder and counsel have confirmed its applicability. Until then it is an
**[OPEN]** item, described as "potentially applicable", and no control is presented as satisfying it.

**AUD-08 [STD]** An **R2** requirement is recorded only from a document Hivorr has actually received.
A remembered onboarding conversation, a sales deck, a provider's general security page or an agent's
assumption about what VFD "probably" requires is not an R2 requirement.

**AUD-09 [STD]** An **R4** reference is never presented as an obligation. "OWASP recommends" and "Hivorr
requires" are different sentences, and a report may not merge them (GOV-27–GOV-29).

**AUD-10 [STD]** An **R5** recommendation is labelled as a recommendation and assigned an owner. It is
not implemented as though approved, and it does not appear in an assessment pack as a control.

**AUD-11 [STD]** Every R1 and R2 requirement record includes: the source document, the version or date
received, the activity and jurisdiction it applies to, the person who confirmed applicability, and the
review date. A requirement whose source cannot be produced is downgraded to **[OPEN]**.

**AUD-12 [REC]** Requirement sources are re-checked when §13.5 triggers a review, when VFD onboarding
documents change, when a new activity or market is added, and before every external assessment. A
requirement does not become permanent because it was once recorded.

### 19.3 Pre-implementation analysis

**AUD-13 [STD]** Before implementation begins, a change in the AUD-04 scope produces a short
**audit-readiness impact note**. It is written before code, attached to the issue or pull request, and
kept with the change. It is not a business case and not a legal opinion.

**AUD-14 [STD]** The impact note answers, at minimum:

| Field | What it records |
| --- | --- |
| **Requirement classes engaged** | Which of R1–R5 are touched, and by what |
| **Data touched** | Classes from DAT-31 — public, internal, personal, sensitive personal, financial, secret — and whether any leaves the platform |
| **Money movement** | Whether value moves, is held, is split, is reversed or is reconciled, and which ledger invariant applies |
| **Identity and access** | Whether authentication, capability, grant, admin scope or verification changes |
| **Third parties** | Every provider, the data sent, the direction, and the failure behaviour |
| **Audit events** | Which actions become auditable, and the event names |
| **Retention** | Whether the change creates a record whose retention is undecided |
| **Evidence to produce** | The tests, records and artefacts that will prove the control operated |
| **Open questions** | Every question that needs founder, counsel or VFD before implementation |
| **Owner** | The person accountable for the note and its evidence |

**AUD-15 [STD]** A question that needs founder, counsel or VFD is recorded as **[OPEN]** and routed to
§16 or `ARCHITECTURE.md` §16.4. It is not answered by the implementer, and the implementation does not
assume an answer.

**AUD-16 [STD]** If the impact note cannot be completed because a requirement is unknown, implementation
of the affected part stops. Work that does not depend on the unknown may proceed, provided the boundary
is stated.

**AUD-17 [REC]** The impact note is reviewed with the change. A reviewer checks that every control it
promised is present, and that every open question is still open or has a recorded decision.

**AUD-18 [REC]** The template in Appendix D is the short form of this note. A copy is kept in the
evidence index for the phase, not only in the pull request.

### 19.4 Secure engineering baseline

**AUD-19 [STD]** The controls in §4–§7 are the engineering baseline. Audit readiness does not replace
them, relax them or duplicate them. A traceability record points at the rule that already requires the
control; it does not restate the control in different words.

**AUD-20 [STD]** A new surface — endpoint, webhook, upload path, admin screen, background job, provider
integration — has a recorded threat analysis before it is built. The analysis names the assets, the
actors, the trust boundaries, the abuse cases and the control for each (`ARCHITECTURE.md` §10.13).

**AUD-21 [STD]** A design decision that affects a control is recorded where the decision lives: an
architectural decision in `ARCHITECTURE.md`, a permission decision in the matrix, a schema decision in
its migration, a deviation in §13.3. §19 does not become a second decision register (QUA-39).

**AUD-22 [REC]** OWASP ASVS 5.0.0 is used as a checklist for coverage, not as a certificate. A control
that maps to an ASVS item is recorded as mapped, not as verified by ASVS (GOV-29).

**AUD-23 [REC]** Where a control is deliberately absent, the record states the exposure, the
compensating control, the owner and the expiry, using OPS-19. "Not applicable" is a finding waiting to
be challenged; it needs a reason.

### 19.5 Financial and wallet integrity

**FACT** The financial architecture is a double-entry ledger as the source of truth, append-only
entries, derived balances, idempotent provider callbacks, verified webhooks and reconciliation alerts
(`ARCHITECTURE.md` §9.10, DAT-07, ENG-15, API-22, API-24–API-29).

**AUD-24 [STD]** Every movement of value is traceable end to end: the provider event or user action,
the idempotency key, the ledger entry or entries, the resulting derived balance, the audit event and
the reconciliation record. A movement that cannot be traced is an incident.

**AUD-25 [STD]** A derived balance is never the evidence of a movement. The evidence is the ledger
entry, its paired entry, the provider reference and the audit record. A screen that displays a balance
is not a control.

**AUD-26 [STD]** Idempotency is tested, not assumed. A test applies the same provider event twice and
proves that value moves once (API-26). The execution record is retained.

**AUD-27 [STD]** Reconciliation is scheduled and evidence-producing. Every run records the period, the
source totals, the ledger totals, the differences, the owner of each difference and its resolution.
An unreconciled difference is an open finding, not a rounding note.

**AUD-28 [STD]** Dual control applies to the high-risk financial actions the matrix names (`matrix`
§14.3, AUT-35). The evidence shows both actors, both timestamps and the action, not a shared login.

**AUD-29 [STD]** A manual adjustment to a production ledger, balance or fee is prohibited except through
a documented, approved, audited operation with a named reason and a reversing entry. A direct database
edit is not an adjustment; it is an incident (`DAT-46`).

**AUD-30 [STD]** Segregation of Hivorr funds from customer funds, and the custody model that applies,
is recorded only as an **R1** or **R2** requirement after founder and counsel confirm it. This document
does not assert a custody model, a safeguarding rule or a settlement obligation.

**AUD-31 [REC]** A financial control matrix lists each control, the risk it addresses, the rule that
requires it, the test that proves it, the evidence it produces and its owner. It is reviewed at AR-4 and
before every financial-control assessment.

### 19.6 Data protection and privacy

**FACT** Data is classified before storage (DAT-31–DAT-33). Retention is **[OPEN]** and, until decided,
the position is retain, do not delete (DAT-34). Account closure is not deletion (DAT-35).

**AUD-32 [STD]** A data inventory exists for every environment above local. It records each store, the
data classes it holds, the purpose, the owner, the retention status and every recipient outside the
platform. A field with no inventory entry has no approved purpose.

**AUD-33 [STD]** Each processing activity has a recorded purpose and its lawful basis or equivalent. The
basis is an **R1** determination made by founder and counsel; engineering records the decision and
implements the control, and does not choose the basis.

**AUD-34 [STD]** A data-subject request — access, correction, deletion, restriction, objection — has a
documented handling path with a case record, the identity check performed, the decision, the action
taken and the date. A request handled only in an inbox is not evidenced.

**AUD-35 [STD]** Deletion is not built until retention and deletion obligations are decided. When they
are, deletion covers the database, object storage, backups' practical reach, search indexes and derived
copies, and produces an audited record (DAT-36).

**AUD-36 [STD]** Every processor that receives personal data is recorded with the data sent, the
direction, the location, the contractual instrument, the security evidence available and the exit path
(API-19, DAT-33). A processor with no record is an unapproved transfer.

**AUD-37 [STD]** A cross-border transfer is recorded only as an **R1** or **R2** requirement after
founder and counsel confirm the applicable mechanism. Engineering does not infer a transfer mechanism
from a provider's region setting.

**AUD-38 [STD]** A privacy impact assessment is produced before a change that introduces a new class of
personal data, a new recipient, a new purpose, profiling, or a materially different retention period.
Its findings and decisions are retained.

**AUD-39 [STD]** A personal-data breach has a documented response: detection, containment, assessment,
the decision on notification, the recipients, the content and the timing. Statutory notification
deadlines are **R1** items to be confirmed by counsel, not values an agent supplies from memory.

**AUD-40 [REC]** Privacy controls are tested like any other control: a test proves that an unauthorised
actor cannot read the data, that redaction removes the value, and that deletion reaches every copy it
claims to reach.

### 19.7 KYC and AML support

**FACT** Hivorr's account model has verification lanes and KYC tiers, and earning activities require
both the applicable lane and the required tier (`AGENTS.md` Rule 3, `matrix` §9.3, §13.4). Whether a
particular AML, CTF, sanctions or customer-due-diligence obligation applies to Hivorr, directly or
through VFD, is an **R1** or **R2** question that is not settled by this document.

**AUD-41 [STD]** Identity and verification data is **sensitive personal** data (DAT-31). It is stored in
a private store, read through short-lived signed access, and every read is audited (OPS-11).

**AUD-42 [STD]** Every verification decision records the actor, the actor type, the timestamp, the
evidence reference, the decision, the reason and the tier or lane affected. A decision that exists only
as a status field is not evidenced.

**AUD-43 [STD]** The evidence relied on for a verification decision is retained with the decision, in a
form that can be produced without reconstructing it from a user's account.

**AUD-44 [STD]** Sanctions, politically-exposed-person and adverse-media screening is built only to the
extent an **R1** or **R2** requirement demands it, and only where the selected provider actually offers
it. Provider capability is verified from the provider's documentation or contract, never assumed.

**AUD-45 [STD]** Transaction-monitoring rules, thresholds and risk scores are documented, versioned and
auditable. A rule change is a reviewed change with a reason and an effective date, not a silent tuning.

**AUD-46 [STD]** The escalation path for a suspicious transaction or customer is documented, names the
decision-maker, and produces a record. Whether a suspicion must be reported to an authority, to VFD, or
to neither is an **R1**/**R2** determination by founder and counsel.

**AUD-47 [STD]** KYC and verification records are retained for the period counsel sets. Until that period
is set, they are retained and not purged (DAT-34). No agent invents a retention number.

**AUD-48 [REC]** A KYC control matrix records each requirement, its class and source, the control, the
evidence, the owner and the last test. It is reviewed before every financial-control or access-control
assessment.

### 19.8 Audit trails and evidence

**FACT** The audit log is append-only, separate from application logs, written inside the transaction,
and never updated or deleted by application code (OPS-09–OPS-13, `ARCHITECTURE.md` §10.9, `matrix`
§11.6).

**AUD-49 [STD]** Every action on the OPS-11 list emits an audit event with the schema in §11.3. An
action that changes money, access, identity, verification or a production environment without an audit
event is a defect, not an observability gap.

**AUD-50 [STD]** The audit event and the effect commit or roll back together (OPS-09). A record written
after the commit, or by a separate best-effort call, is not evidence that the effect occurred.

**AUD-51 [STD]** The audit store is access-controlled, append-only in practice as well as in policy, and
its access is itself audited. An actor who can edit the audit log can defeat every other control in
this section.

**AUD-52 [STD]** Audit timestamps use a single time source in UTC, synchronised to a known reference.
A timestamp whose source is unknown cannot order two events.

**AUD-53 [STD]** Evidence is stored in the phase's evidence index with a stable identifier, the date,
the commit or artifact digest, the environment, the command or procedure that produced it, and the
result. A file named `screenshot-final.png` is not evidence.

**AUD-54 [STD]** Evidence is immutable once recorded. A correction is a new evidence item that
supersedes the old one; the old item is retained.

**AUD-55 [STD]** Simulated, illustrative or synthesised evidence is labelled as such. It is never
presented as a record of a real run. A demonstration environment is not production evidence.

**AUD-56 [STD]** Evidence contains no secret and no unnecessary personal data. Where a record must show
that a value was present, it shows a hash, a redacted form or a reference, not the value (OPS-12).

**AUD-57 [REC]** Evidence retention follows the audit-retention decision when it is made (§16 #10).
Until then, evidence is retained. Deleting an assessment record before the assessment is a defect.

**AUD-58 [REC]** The evidence index is reviewed at each phase gate. An evidence item that cannot be
located is treated as missing, not as present.

### 19.9 Testing and verification

**FACT** Security testing is required by QUA-24–QUA-28, and a change to critical logic merges on an
automated test that fails when the protection is removed (QUA-36).

**AUD-59 [STD]** Every control has a test that fails if the control is removed or inverted. A test that
passes with the control deleted proves the test, not the control.

**AUD-60 [STD]** Every access-control test includes the deny path: an actor without the capability, an
actor from the wrong tenant, an actor whose grant was revoked, and an unauthenticated caller where the
endpoint is not public.

**AUD-61 [STD]** Financial invariants are tested directly: debits equal credits, a replay does not
double a balance, a failed provider call leaves no half-completed operation, and reconciliation reports
the difference it is given.

**AUD-62 [STD]** Migration tests prove that the schema applies from empty and from the previous
production state, and that RLS denies the cases it is meant to deny (DEP-21, `database rules` §9.4,
§11.4).

**AUD-63 [STD]** Restore drills produce a record: the backup used, the restore point, the measured
recovery time, the verification performed and the person who performed it (DAT-40, DEP-26).

**AUD-64 [STD]** The execution record of a test — the CI run, the artifact, the log and the result — is
retained with the commit or release it verifies. A green badge on a branch that no longer exists is not
evidence.

**AUD-65 [STD]** Independent testing, including a penetration test, is recorded with its scope,
methodology, findings, severity, remediation and retest. It does not replace an external audit, and a
clean penetration test is not a compliance opinion (QUA-27).

**AUD-66 [REC]** A control-test traceability matrix maps each R1, R2 and critical R3 control to its
test, its last execution and its evidence. It is the first artefact an assessor should be given.

### 19.10 Infrastructure and deployment security

**FACT** Production is protected by per-release founder approval, promotion from staging, a separate
migration job, recorded deployment details and a rehearsed rollback (DEP-13–DEP-27).

**AUD-67 [STD]** An environment inventory records every environment, its purpose, its owner, the data
classes it holds, whether it is internet-reachable, and its connection to production. An environment
that is not inventoried is treated as production for access purposes.

**AUD-68 [STD]** Production access is least-privilege, individually attributable and reviewed on a
schedule. Shared accounts, standing administrator access and unowned credentials are findings
(API-18, AUT-30).

**AUD-69 [STD]** Infrastructure and configuration changes are made through versioned, reviewed change
records or infrastructure as code, not by editing a running host (DEP-16). The change record is the
evidence.

**AUD-70 [STD]** Every production deployment produces the DEP-23 record, including the approval, the
artifact digest, the migration set, the configuration version and the rollback position. The record is
evidence; the chat message approving it is not.

**AUD-71 [STD]** Vulnerability scanning, dependency advisories and patch actions retain their results
and their remediation dates (OPS-17–OPS-20, QUA-24). An accepted risk has an owner and an expiry
(OPS-19).

**AUD-72 [STD]** Monitoring and alerting configuration is versioned, and every alert has a recorded
test that proves it fires (OPS-15). An untested alert is an assumption.

**AUD-73 [STD]** Backup configuration records what is backed up, how often, where the copy lives, who
can delete it and when it was last restored (DAT-38–DAT-42). A backup that has never been restored is
a hypothesis.

**AUD-74 [REC]** An asset and endpoint inventory records every public hostname, API surface, webhook and
storage bucket, its owner and its data class. It is reviewed before every API and infrastructure
assessment.

### 19.11 Requirement-to-control-to-evidence traceability

**TRC-01 [STD]** Every R1 and R2 requirement, and every R3 rule that governs critical logic (QUA-35),
has a traceability record with the fields below. The record is the unit an assessor samples.

| Field | Content |
| --- | --- |
| **Requirement ID** | `REQ-###`, stable for the life of the requirement |
| **Class** | R1, R2, R3, R4 or R5 (§19.2) |
| **Source** | The instrument, contract clause, rule identifier or decision, with version or date |
| **Requirement** | One sentence, in the source's terms and without embellishment |
| **Applicability** | The activity, jurisdiction, environment and data class it covers |
| **Control** | The rule identifier and the design decision or code that implements the control |
| **Test** | The test or procedure that proves the control operates, and where it runs |
| **Evidence** | The evidence identifier(s) and where they are stored |
| **Owner** | The person accountable for the control and its evidence |
| **Status** | Implemented, partially implemented, not implemented, or not applicable with a reason |
| **Last verified** | The date of the most recent test execution or review |
| **Gaps** | Every known gap, its risk, its compensating control and its expiry |

**TRC-02 [STD]** A traceability record is created or updated in the same change that creates or alters
the control. It is not a separate documentation phase after the work.

**TRC-03 [STD]** A record's status is **implemented** only when the control exists, the test exists and
the evidence exists. Two of three is **partially implemented**, and the missing part is named.

**TRC-04 [STD]** A gap is recorded as a gap. It is not closed by reclassifying the requirement, by
narrowing its scope after the fact, or by pointing at a policy that says the right thing without a
control that does it.

**TRC-05 [STD]** A traceability record is not deleted when a requirement stops applying. It is marked
superseded, with the date and the reason, so that the history remains auditable.

**TRC-06 [REC]** The traceability register is reviewed at AR-2, AR-4 and AR-5, and whenever a
requirement source changes. The review records who checked it and what changed.

### 19.12 Audit readiness gates

These gates sit alongside the G0–G5 phase gates in `ENGINEERING_EXECUTION_STRUCTURE.md`. They do not
replace them, and passing a gate here does not approve a phase or a release.

| Gate | When it applies | Question it answers | Minimum evidence | Who signs |
| --- | --- | --- | --- | --- |
| **AR-0** | Architecture and design, before implementation | Are the requirements identified and classified, and does the design name a control for each? | Impact note, threat analysis, requirement records, open-question list | Architect; founder for R1/R2 conflicts |
| **AR-1** | Feature implementation, before review | Is each promised control implemented, with a test that fails if it is removed? | Code, tests, test execution, updated traceability | Author, verified by the reviewer |
| **AR-2** | Security and privacy verification | Do the controls actually deny, redact, retain and audit as claimed? | Deny-path tests, privacy checks, audit-event samples, evidence index entries | Security reviewer; founder where R1/R2 is engaged |
| **AR-3** | Integration security, before a provider is enabled | Is the third party authenticated, minimised, failure-safe and reconcilable? | Provider record, signature and replay tests, failure tests, reconciliation evidence | Architect and founder (`API-29`) |
| **AR-4** | Pre-production, before a release is approved | Is the evidence complete enough that a reviewer who was not involved could reach the same conclusion? | Traceability register, deployment record, restore drill, vulnerability status, open findings | Founder, with the release approval (DEP-23) |
| **AR-5** | External audit readiness, before an assessment | Can the assessment pack be produced from records that already exist, without new assertions? | Assessment pack, evidence index, gap register, scope statement | Founder |

**AUD-75 [STD]** A gate is passed on evidence, not on assertion. "Reviewed" without a record, "tested"
without a result, and "considered" without a decision do not pass a gate.

**AUD-76 [STD]** A gate that cannot be passed is recorded as not passed, with the reason, the owner and
the date it will be revisited. It is not waived by silence, and it is not marked passed with a caveat
buried in a comment.

**AUD-77 [STD]** A gate applies at the point the work reaches it. Retrofitting AR-0 evidence after
implementation is a finding, unless the change is explicitly an audit-readiness remediation with that
fact recorded.

**AUD-78 [STD]** AR-5 is a readiness gate, not a prediction. It confirms that the pack exists and is
consistent; it does not assert that an assessor will find no issues, and it does not authorise a public
claim (AUD-03).

**AUD-79 [REC]** Gate evidence is stored in the evidence index for the phase, using the identifier
pattern in `ENGINEERING_EXECUTION_STRUCTURE.md` §8.2, so that `EP-01-070`-style references remain
stable.

### 19.13 Preparing for an external assessment

The assessments Hivorr should expect are listed below. Each is a different lens on the same evidence;
the pack is assembled from the traceability register and the evidence index, not written from scratch.

| Assessment | What it typically examines | Hivorr artefacts it draws on | Owner |
| --- | --- | --- | --- |
| **VAPT** — vulnerability assessment and penetration test | Authentication, authorisation, injection, session handling, business-logic abuse, infrastructure exposure | Threat analyses (AR-0), deny-path tests, IDOR and privilege-escalation sweeps (QUA-25), dependency and secret scans, prior findings and retests | Architect |
| **Data-protection assessment** | Data inventory, lawful basis, minimisation, retention, subject requests, processors, cross-border transfers, breach response | Data inventory (AUD-32), processing records (AUD-33), request cases (AUD-34), processor register (AUD-36), PIA (AUD-38), breach procedure (AUD-39) | Founder with counsel |
| **Financial-control assessment** | Ledger integrity, reconciliation, dual control, provider settlement, manual adjustments, access to financial functions | Ledger and reconciliation evidence (AUD-24–AUD-29), financial control matrix (AUD-31), audit samples (AUD-49), deployment and access records | Founder |
| **API and infrastructure assessment** | Contract, authentication, rate limits, webhook verification, secret management, environment isolation, logging, backup | OpenAPI contract and diff, webhook tests, secret-management record, environment inventory (AUD-67), alert tests (AUD-72), restore drills (AUD-73) | Architect |
| **Access-control assessment** | Capability model, least privilege, admin scopes, dual control, break-glass, access reviews, joiner/mover/leaver | Matrix and enforcement tests, grant-change audit, access reviews (AUD-68), break-glass records (AUT-36), dual-control evidence (AUD-28) | Founder |

**AUD-80 [STD]** An assessment pack is assembled from records that already exist. If an artefact has to
be created for the assessment, the pack states that it was created late and why. A pack that presents
late-created artefacts as contemporaneous evidence is a misrepresentation.

**AUD-81 [STD]** The pack begins with a scope statement: what was assessed, what was excluded, the
period covered, the environments and the version or commit. An assessment of an unnamed scope cannot be
relied on.

**AUD-82 [STD]** An external assessor receives scoped, time-boxed, logged access to the minimum
environment needed. The access is granted by the founder, recorded, and revoked at the end of the
engagement (AUT-36).

**AUD-83 [STD]** Findings are tracked to closure with an owner, a severity, a remediation date and a
retest. A finding is not closed by disagreement alone; if the risk is accepted, it is recorded under
OPS-19 with an expiry.

**AUD-84 [STD]** A management response is factual and specific. It does not claim a control that the
evidence does not show, does not describe a plan as if it were implemented, and does not dispute a
finding without a record.

**AUD-85 [STD]** No agent, contributor or document may describe an assessment as passed, clean,
successful or certified before the assessor's written report says so, and then only within the scope
the report names.

**AUD-86 [REC]** After an assessment, the traceability register is updated with every finding, the
control that changed, and the evidence of the retest. The next pack starts from that register.

### 19.14 Obligations of AI coding agents

**AI-22 [STD]** Every AI coding agent follows the twelve behaviours below. They are mandatory in
addition to §12, and a failure is reported under AI-16–AI-19 rather than hidden.

| # | Behaviour | Why it matters | Related rule |
| --- | --- | --- | --- |
| 1 | Inspect the governing documents and the existing implementation before proposing a change | An invented requirement or a duplicated control cannot be evidenced | AI-01, AI-02 |
| 2 | Classify every requirement it relies on as R1–R5, and state the class | A recommendation presented as law is a false claim | AUD-06–AUD-10 |
| 3 | Produce the audit-readiness impact note before writing code for an in-scope change | Controls designed after the fact are usually missing | AUD-13–AUD-18 |
| 4 | Never invent a statute, regulator requirement, VFD requirement, provider capability or security guarantee | Fabricated compliance is worse than a gap | AUD-07, AUD-08, AI-15 |
| 5 | Record an unknown as **[OPEN]** and route it to the correct register instead of assuming an answer | An assumed answer becomes an unaudited control | AUD-15, AI-17 |
| 6 | Implement the control and a test that fails if the control is removed | An untested control is a claim | AUD-59, QUA-36 |
| 7 | Produce the evidence as part of the work, with the identifier, date, commit and environment | Reconstructed evidence is not evidence | AUD-02, AUD-53 |
| 8 | Update the traceability record in the same change | A control that is not mapped is invisible to an assessor | TRC-02 |
| 9 | Separate what was verified from what was assumed in its report | A confident report is not a verified one | AI-16 |
| 10 | State any gate it could not pass, and why, rather than marking it passed | A false pass removes the only warning | AUD-76 |
| 11 | Never describe Hivorr, a feature or a release as compliant, certified, audited or secure | Only an independent assessment can support that, within its scope | AUD-03, AI-14 |
| 12 | Escalate every R1 or R2 question, every irreversible action and every conflict between documents to the founder or architect | These are decisions, not implementation details | AUD-15, GOV-23, AI-18, AI-19 |

**AUD-87 [STD]** An agent's completion report states, for each control it touched, the requirement
class, the control, the test and the evidence. A report that says only "implemented" does not satisfy
this rule.

**AUD-88 [STD]** An agent that cannot determine the class of a requirement stops and asks. Guessing
between R1 and R5 is not permitted, because the two carry different obligations.

### 19.15 Boundaries and what this section does not do

**AUD-89 [STD]** This section does not create a legal, regulatory or contractual obligation. It records
how Hivorr will demonstrate that it meets obligations that are established elsewhere, by a source that
is named and classified.

**AUD-90 [STD]** This section does not replace counsel, VFD onboarding, a data-protection authority's
guidance or an independent assessor. Where they disagree with a record here, the record is corrected;
the external source is not edited to match the record (GOV-25).

**AUD-91 [STD]** This section does not certify Hivorr, does not promise a clean assessment and does not
convert a Hivorr standard into an industry certification. A reference to ASVS, OWASP or any other
framework remains a reference (GOV-27–GOV-29).

**AUD-92 [REC]** When a new statute, regulator guidance or VFD requirement is received, it is added as
an R1 or R2 record with its source and applicability note, and the affected traceability records are
reviewed. The document is not rewritten around it.

---

## Appendix A — Requirement map (brief areas A–K)

| Area | Requirement | Section |
| --- | --- | --- |
| **A** | Engineering principles | §2 |
| **B** | Technology selection standards | §3 |
| **C** | Application security — SQLi, XSS, CSRF, validation, encoding, uploads, brute force, error handling | §4 |
| **D** | Authentication and authorisation | §5 |
| **E** | Database and data protection | §6 |
| **F** | API and integration security | §7 |
| **G** | Performance and scalability | §8 |
| **H** | Environment and deployment security | §9 |
| **I** | Code quality and testing | §10 |
| **J** | Monitoring and incident management | §11 |
| **K** | AI coding agent compliance | §12 |
| — | Governance and enforcement | §1, §13 |
| — | Audit readiness by design | §19 |
| — | Requirement classes and traceability | §19.2, §19.11 |
| — | Audit readiness gates AR-0–AR-5 | §19.12 |
| — | External assessment preparation | §19.13 |
| — | Research and accuracy | §14 |
| — | Document control | Front matter, §17 |
| — | Approval record | §18 |

---

## Appendix B — Reviewer checklist

One page. If a change fails any item, it does not merge.

**Scope and honesty**

- [ ] The change does what the task asked, and nothing unrelated.
- [ ] The description matches the diff.
- [ ] The change class is stated (§13.1), and the required approver has approved.

**Security**

- [ ] Every new input is validated at the boundary; unknown fields are rejected (§4.5).
- [ ] Every new query is parameterised; no identifier comes from user input (§4.2).
- [ ] Every new endpoint declares an audience and a capability, and enforces both inside the
      transaction (§5.5).
- [ ] No new unsafe sink: no `dangerouslySetInnerHTML`, no `innerHTML`, no `eval` (§4.3).
- [ ] State-changing requests validate `Origin`; no state change on `GET` (§4.4).
- [ ] No secret, key or credential in the diff, the bundle or the logs (§4.11, §6.6, §11.2).
- [ ] Errors carry a machine code and a correlation id; no internal detail leaks (§4.9).

**Data**

- [ ] RLS is enabled on any new table; policies have allow and deny tests (§6.4).
- [ ] New personal or sensitive fields are classified (§6.8).
- [ ] Migrations are self-contained, forward-only, and apply from empty (§9.5).
- [ ] A destructive change has a plan and founder sign-off (§9.5).

**Quality**

- [ ] Types are strict; no new suppression (§10.1).
- [ ] Existing components, services and utilities were reused or the duplication is justified
      (§2.2).
- [ ] Tests cover the behaviour and the deny path (§10.4).
- [ ] No new dependency without a justification and a measurement (§3.4).

**Visual**

- [ ] Rendering changes have a visual diff at 375 / 768 / 1280 px (`AGENTS.md` §6).
- [ ] No new colour, type size, radius, shadow or spacing value (§13.1).
- [ ] The prototype was not modified.

**Operations**

- [ ] New background work is idempotent, retryable and observable (§8.7).
- [ ] New alerts have an owner and a runbook (§11.1).
- [ ] The rollback position is clear (§9.6).

**Audit readiness**

- [ ] Every requirement relied on is classified R1–R5, and an R4 or R5 item is not presented as an
      obligation (§19.2).
- [ ] Every R1/R2 question is recorded as **[OPEN]** unless founder and counsel have confirmed it
      (§19.2).
- [ ] The impact note exists for an in-scope change, and its open questions are still visible (§19.3).
- [ ] Each new control has a test that fails if the control is removed, and the test execution is
      retained (§19.9).
- [ ] Money, identity, access and personal-data actions emit the audit event the rule requires
      (§19.5–§19.8).
- [ ] The traceability record is updated, with control, test, evidence, owner and gaps (§19.11).
- [ ] No statement claims compliance, certification or a clean assessment (§19.13).
- [ ] The applicable AR gate has been passed on evidence, or its failure is recorded (§19.12).

---

## Appendix C — Deviation record template

Copy this into §13.3 when a **[STD]** rule cannot be followed.

```markdown
| Field | Value |
| --- | --- |
| ID | DEV-00N |
| Rule | SEC-XX — <rule text> |
| Scope | <file / module / endpoint — the narrowest true statement> |
| Reason | <why the rule cannot be followed now> |
| Risk | <what exposure this creates, and who is exposed> |
| Compensating control | <what reduces the risk while this stands> |
| Owner | <name> |
| Expiry | <date, or the condition that ends it> |
| Approval | <who approved, and when> |
```

A deviation record is not a waiver of the rule's intent. It is a dated acknowledgement that the
intent is not yet met, with a named person responsible for meeting it.

---

## Appendix D — Audit-readiness impact note and traceability template

Copy the impact note before implementation (§19.3), and the traceability record into the phase's
register (`TRC-01`, §19.11). Both are evidence; neither replaces the rule that requires the control.

### D.1 Impact note, before implementation

```markdown
| Field | Content |
| --- | --- |
| Change | <one sentence: what is being built or changed> |
| Owner | <name> |
| Requirement classes engaged | <R1 / R2 / R3 / R4 / R5, and the source of each> |
| Data touched | <DAT-31 classes; state whether any data leaves the platform> |
| Money movement | <value moved, held, split, reversed or reconciled; ledger invariant> |
| Identity and access | <authentication, capability, grant, admin scope or verification change> |
| Third parties | <provider, data sent, direction, failure behaviour, exit path> |
| Audit events | <action and event name for each new auditable action> |
| Retention | <record created, and whether retention is decided> |
| Evidence to produce | <test, record or artefact that will prove the control operated> |
| Open questions | <question, who must answer, and the register it is recorded in> |
| Gate | <AR-0 to AR-5, and the phase gate it supports> |
```

### D.2 Traceability record

```markdown
| Field | Content |
| --- | --- |
| Requirement ID | REQ-### |
| Class | R1 / R2 / R3 / R4 / R5 |
| Source | <instrument, contract clause, rule ID or decision — with version or date> |
| Requirement | <one sentence, in the source's terms> |
| Applicability | <activity, jurisdiction, environment, data class> |
| Control | <rule ID and the design decision or code that implements it> |
| Test | <test or procedure, and where it runs> |
| Evidence | <evidence ID(s), and where they are stored> |
| Owner | <name> |
| Status | Implemented / partially implemented / not implemented / not applicable with reason |
| Last verified | <date> |
| Gaps | <gap, risk, compensating control, expiry> |
```

### D.3 Rules for using the template

1. A record with a status of **implemented** must have a control, a test and evidence. Two out of three
   is **partially implemented**, and the missing part is named (`TRC-03`).
2. An **R1** or **R2** record names the person who confirmed applicability. Without that name, it is an
   **[OPEN]** item, not a requirement (`AUD-07`, `AUD-08`).
3. An **R4** or **R5** item is labelled as such in the register and is never counted as a control in an
   assessment pack (`AUD-09`, `AUD-10`).
4. Evidence is identified by where it lives and what produced it, not by a filename alone (`AUD-53`).
5. A gap is recorded as a gap. It is not closed by narrowing the requirement after the fact (`TRC-04`).
6. A superseded record is retained and marked, not deleted (`TRC-05`).


