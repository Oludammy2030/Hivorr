# HIVORR — ENGINEERING EXECUTION STRUCTURE

| Field | Value |
| --- | --- |
| **Document** | `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` |
| **Version** | 2.0 |
| **Date** | 4 November 2026 |
| **Status** | **APPROVED — 4 November 2026.** Binding. |
| **Owner** | Founder (AfriNova) for phase approval, launch approval and production release. Architect for phase content, sequencing and technical gates. |
| **Applies to** | Every human contributor and every AI coding agent that plans, builds, reviews, tests, releases or reports on Hivorr engineering work. |
| **Supersedes** | `ENGINEERING_EXECUTION_STRUCTURE.md` version 1.0 (199 lines, supplied as an attachment, never in this repository). The attached original is not modified. |
| **Companion documents** | `VISION.md`, `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`, `VISUAL-IDENTITY.md`, `AGENTS.md`, `Business-Development-Roadmap.md` |

> **Status note.** Approved by the founder on **4 November 2026**, version 2.0 as written. The phase
> sequence in §6, the gates in §7, the work-package protocol in §8, the status vocabulary in §9 and
> the execution decisions in §10 are binding from that date, and every item labelled **[PROPOSED]**
> took effect with the approval.
>
> Approval of this document does **not** approve any phase for build, does **not** approve the
> standards document, does **not** settle any **[OPEN]** item, and does **not** authorise a production
> release (§14). Those remain separate acts by the person named in §5.2.

---

## Label key

| Label | Meaning | Effect |
| --- | --- | --- |
| **[DECIDED]** | Fixed by an approved document, the prototype, or an explicit founder instruction. | Binding. Changing it requires a recorded revision of the document that owns it. |
| **[PROPOSED]** | Introduced by this document. | Binding from the 4 November 2026 approval; changing it requires a revision of this document. |
| **[OPEN]** | Not settled by any source. | Nothing may be built on it. §11 lists the ones this document surfaces. |
| **[FACT]** | Verified against the repository or an approved document on the stated date. | Evidence, not opinion. |
| **[CORRECTED]** | A v1 statement that was wrong, stale or unsupported, and what replaced it. | Recorded in §12. |

**Governance classes.** `[FOUNDER]`, `[REVIEW]` and `[REC]` are not labels of this document. They are
the change classes defined in `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` `GOV-09`, and they
determine who must approve a change. This document uses them without redefining them.

---

## 1. Purpose, scope and authority

### 1.1 What this document governs

This document answers one question: **in what order does Hivorr's engineering work happen, who
authorises each step, and what evidence proves a step is finished?**

It governs:

1. The engineering phase model — identifiers, scope boundaries, dependencies and exit criteria.
2. The gate sequence every change passes, and the evidence required at each gate.
3. The work-package protocol that turns a phase into reviewable units of work.
4. Role boundaries — what the founder, architect, developer, reviewer and AI agent may each decide
   and do, including who may deploy to production.
5. The status vocabulary, and the rule that a status without evidence is not a status.

### 1.2 What this document does not govern

This document **defers** to the approved documents below. It does not restate them, and where it
appears to conflict with one, that document wins and this document has a defect.

| Concern | Authority | This document does |
| --- | --- | --- |
| Product purpose, activities, business principles | `VISION.md` | Sequence the engineering that serves them |
| System design, modules, data layer, environments, CI/CD | `ARCHITECTURE.md` | Reference its sections; never redesign |
| Account, activity and permission model | `Unified-Account-and-Activity-Permission-Matrix.md` | Treat capabilities as the unit of authorisation |
| Migrations, grants, RLS, Data API | `Database-Migration-and-Supabase-Data-API-Rules.md` | Gate migrations; never define them |
| Engineering, security and quality rules | `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | Apply its gates; never duplicate its rules |
| Visual identity | `src/app/App.tsx` (the prototype) | Require visual regression; never restyle |
| AI working rules and vocabulary | `AGENTS.md` | Define agent boundaries within it |
| Business phase gates, pricing, custody, launch configuration | `Business-Development-Roadmap.md` | Map engineering phases onto its maturity gates |

**Rule 1.2.1 [PROPOSED]** This document adds no technical decision. If a statement here is not
traceable to a `[DECIDED]` source, it is `[PROPOSED]` and needs founder approval.

### 1.3 Reading order for a contributor

1. `AGENTS.md` — working rules and guardrails.
2. `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` — how work is done and verified.
3. `ARCHITECTURE.md` — what the system is.
4. This document — what is built in what order, and by whom.
5. `Business-Development-Roadmap.md` §14 — the business gate the current phase serves.

An agent that skips steps 1–3 is not permitted to start step 4 (`AI-01`).

### 1.4 Relationship to the business roadmap

**[DECIDED]** The roadmap defines phases by **business maturity**, not by feature surface and not by
date (`Business-Development-Roadmap.md` §14). Its six phases are Phase 0 to Phase 5.

**[DECIDED]** Engineering phases are therefore **not** a renaming of business phases. Several
engineering phases can serve one business phase, and one engineering phase can span two. The mapping
is stated per phase in §6 and summarised in §6.3.

**[PROPOSED]** An engineering phase may be built before the business gate that uses it, but it may
not be **released to production** before that gate is met. Building ahead of the gate is allowed;
launching ahead of it is not.

---

## 2. What changed from version 1.0

Version 1.0 was a phase list. It had no gate definitions, no roles, no evidence requirements, no
production-release authority and no work-package protocol. It also asserted a status and a business
mapping that the repository and the approved documents do not support. This section records exactly
what happened to each part of it.

### 2.1 Retained

| v1 element | Why it was kept |
| --- | --- |
| Phase identifiers `EP-01`…`EP-08` and their names | Stable references; no reason to renumber |
| The dependency principle: foundation → trust → 2-party → 3-party → logistics → AI → ecosystem → global | Correct and consistent with `ARCHITECTURE.md` §13 |
| The per-phase attribute schema (objective, capability, dependencies, priority, status) | Sound; scope, entry gate, exit gate and evidence added |
| Deterministic-core supremacy | Matches `AGENTS.md` Rule 1 and Rule 4 |
| Server-side enforcement; the client is an unprivileged presentation layer | Matches `AGENTS.md` Rule 4 and `ARCHITECTURE.md` §10.2 |
| Unified account with six activities and no "Both" value | Matches `AGENTS.md` Rule 6 and the permission matrix §4 |
| Dual taxonomy (Profession + Product) | Matches `AGENTS.md` Rule 2 |
| Provider-agnostic financial infrastructure | Matches `ARCHITECTURE.md` §13.2 and the roadmap's ledger rule |
| "Universal platform before industry verticals" | Matches `ARCHITECTURE.md` §13.3–§13.4 |
| Scalability without structural redesign | Matches `ARCHITECTURE.md` §13.1–§13.5 |

### 2.2 Corrected

| v1 statement | Problem | Replacement |
| --- | --- | --- |
| EP-01/02/03 status "In Progress — … landed" | **No phase scope exists.** There is no `server/`, no API, no schema, no auth, no router in use, no CI and no commit in the repository. See §4. | Every phase is `Not started`. Status now requires evidence (§9.3). |
| "Maps to Business Phase 1…7" | The roadmap has **Phase 0–5** maturity gates, not seven business phases. v1 mapped to a superseded model. | Re-mapped in §6.3. |
| "PostgreSQL server-side architecture (RPC + RLS)" | The decided model is a **TypeScript service layer as the authoritative policy point**, with RLS as defence in depth. Supabase, if used, is managed Postgres only — Data API disabled (Position A). | §6.4 EP-01 scope; `ARCHITECTURE.md` §2.3, §10.2; database rules §2.4. |
| "Universal Entity data model" | Not approved vocabulary. The approved model is account → user → profile → activity activation. | §6.4 EP-01 scope; permission matrix §3.3. |
| "SSL pinning" | A native-app control. Hivorr is a web product at MVP. | Removed. TLS 1.2+, HSTS, host-only cookies and session audiences instead (`ARCHITECTURE.md` §10.3, §10.11). |
| "Unified multi-currency financial profile… currency conversion" in EP-02 | The currency model is **[OPEN]** (`ARCHITECTURE.md` §16.4 #8) and the roadmap defers multi-currency to Phase 4 (BD-D07). | The ledger carries a currency dimension from day one and has no conversion feature; which currencies are enabled stays open. |
| AI positioned at EP-06 as a committed phase | AI launch scope is **[OPEN]** (`ARCHITECTURE.md` §16.4 #20) and retention must not depend on it (roadmap §8.7). | EP-06 reclassified as **Reserved / conditional**; it is not on the critical path. |
| Errand absent from every phase | Errand is an approved activity (`VISION.md` §6, matrix §4) and one of six. | Added to EP-04, with its shared request pool and dispatch dependency stated. |
| No phase owned the `control.` platform | Verification review is impossible without it, yet v1 assumed an "Admin review gate" existed. | Owned by EP-02, with its own exit criterion. |
| EP-07 and EP-08 presented as committed phases | Both are roadmap Phase 4–5 **options**, not commitments, and both depend on decisions that are open. | Reclassified as **conditional**, each with a named precondition. |

### 2.3 Removed

| Removed | Reason |
| --- | --- |
| Offline sync engine (EP-01) | No approved requirement. Mobile strategy is **[OPEN]** (`ARCHITECTURE.md` §16.4 #19) and the architecture explicitly defers a sync engine to a funded mobile app. |
| SSL pinning | Wrong platform (see §2.2). |
| "Task auto-completion agents", "natural language transaction processing", "platform-wide capability access" for AI | Conflicts with `AGENTS.md` Rule 1 and Rule 4 — AI never decides ranking, pricing, splits or payouts. AI scope is open. |
| Thunes named as a due-diligence provider (EP-08) | Not an approved decision. BD-D11 made VFD the single payment and custody partner. Cross-border providers are **[OPEN]**. |
| "Approved Engineering Execution Structure" as the closing status | It was never approved. This version is approved as of 4 November 2026. |
| Percentage-complete or "landed" claims without an artifact | Unverifiable. Replaced by the evidence rule (§9.3). |

### 2.4 Added

| Added | Why it is needed |
| --- | --- |
| **EP-00 Execution Readiness** as a prerequisite gate (§6.2) | Nothing can be built until the toolchain, lockfile, first commit and CI exist. v1 assumed this was already done. |
| Roles and decision-rights matrix (§5) | v1 named no actors. The founder asked for explicit boundaries. |
| Production deployment authority as a hard rule (§5.5) | v1 was silent; `ARCHITECTURE.md` §12.5 requires per-release founder approval. |
| Gate definitions **G0–G5** with required evidence (§7) | v1 had "Status" but no definition of done at phase level. |
| Work-package protocol (§8) | A phase is not a unit of work; a reviewable diff is. |
| Status vocabulary and the evidence rule (§9) | Prevents the v1 failure mode of claiming progress that does not exist. |
| Conflict register (§12) | Records every v1 statement that was corrected, so the correction is auditable. |
| Open-decision list (§11) | Surfaces the decisions this document cannot make. |

---

## 3. The execution model

### 3.1 Three levels, never conflated

| Level | Definition | Example | Owner |
| --- | --- | --- | --- |
| **Phase** | A capability boundary with an entry gate and an exit gate. | `EP-02` Trust, Identity and Financial Integrity | Architect proposes, founder closes |
| **Work package** | The smallest unit that can be reviewed, tested and reverted independently. | `EP-02-014` — verification decision endpoint and its tests | Developer |
| **Change** | One diff, one pull request, one class from `GOV-09`. | A single PR inside a work package | Developer |

A phase is never "mostly done". It is open or closed, and closure is evidenced (§7, G5).

### 3.2 Why phases are gates, not dates

**[PROPOSED]** No phase in this document carries a date. Dates create pressure to declare a phase
finished when it is not, which is precisely the failure the roadmap's entry gates exist to prevent.
A phase starts when its entry gate is met and closes when its exit evidence exists. Duration is an
output, not an input.

### 3.3 What may run in parallel

**[PROPOSED]** Two rules:

1. **Within a phase**, work packages may run in parallel if they touch different modules and no
   package depends on another's schema or contract.
2. **Across phases**, only the *next* phase may begin, and only its work that does not depend on the
   current phase's exit evidence. A phase may not begin while the phase two steps back is open.

The reason is not bureaucracy. Financial and trust logic compounds: a defect in the ledger or the
capability check is inherited by every later phase, and the cost of finding it rises with each phase
built on top of it.

### 3.4 One phase in build at a time

**[PROPOSED]** The repository may have exactly one phase `In build`. Others are `Not started`,
`Ready`, `Reserved` or `Blocked`. This is a work-in-progress limit, not a scheduling preference: a
small team building two phases at once finishes neither, and the review capacity assumed by
`GOV-09` does not exist twice.

---

## 4. Verified starting position

### 4.1 Why this section exists

Version 1.0 claimed that EP-01, EP-02 and EP-03 were "In Progress" and listed systems that had
"landed". Those claims are not supported by the repository. Any execution plan built on a false
starting position is worthless, so the position is recorded here with evidence.

### 4.2 What actually exists

**[FACT]** Measured in the repository on 4 November 2026:

| Item | State | Evidence |
| --- | --- | --- |
| Git repository | Initialised, **zero commits**, branch `main` has no history | `git log` fails with "does not have any commits yet"; every path is untracked |
| Application code | The prototype only: `src/app/App.tsx`, 3,814 lines, plus an unused shadcn component kit | `src/` tree |
| API / server | **Does not exist** | no `server/`, no `apps/`, no `packages/` |
| Database schema or migrations | **Do not exist** | no migration directory, no SQL |
| Authentication | **Does not exist** | no identity module; `react-router` installed but unused |
| Router in use | **No** | `App.tsx` switches on local state; `react-router` is dormant |
| CI/CD | **Does not exist** | no `.github/`, no pipeline file |
| Automated tests | **Zero** | no test files; no test runner installed |
| Lint script | **Absent** | `package.json` has `dev`, `build`, `preview`, `format`, `typecheck` only |
| Lockfile | **Stale** — the importer block no longer matches `package.json` (`EX-19`) | `pnpm-lock.yaml` |
| Node / pnpm on PATH | **Absent** in the current environment | `Get-Command node` fails |
| Prototype dev server | Documented as always-on at `$PORT` (default 8443) | `AGENTS.md` |

### 4.3 What this means for the plan

**[PROPOSED]** Three consequences follow, and none is negotiable:

1. **EP-00 is not optional.** The toolchain, lockfile, first commit and CI must exist before any
   phase work begins. v1 skipped this because it assumed the work was done.
2. **No phase is `In build`.** Every phase is `Not started`. EP-00 became `Ready` on approval of
   this document.
3. **The prototype is the only production-grade artifact.** It is the visual authority and the
   source of the design system, and it is not modified except by an explicit founder product
   decision (`AGENTS.md` §1, `GOV-09`).

### 4.4 Known blocking constraints

| ID | Constraint | Blocks | Resolution |
| --- | --- | --- | --- |
| `EX-19` | `pnpm-lock.yaml` importer block is stale; dependencies cannot be installed reproducibly | Every build, typecheck and test | `pnpm install`, review the lockfile diff, commit it |
| `EX-10` | No test runner or linter is installed | G1 and G2 evidence | Add Vitest and a linter as an `[REVIEW]` change (`GOV-09`) |
| `EX-01`/`EX-02` | 1,065 inline style objects, 151 inline `font-family`, 228 hex literals force `style-src 'unsafe-inline'` | CSP posture (`SEC-49`) | Accepted exception; migrate as files are touched, never in a sweeping refactor |
| `EX-12` | No CI provider chosen | G2 evidence, deployment gates | Founder decision (`standards` §16 #18) |
| `EX-15` | `packages/` layout does not exist | Shared design and type packages | Created only when the first package is extracted |
| — | Managed Postgres provider not chosen | Migrations, staging, production | Founder decision (`ARCHITECTURE.md` §16.4 #1) |

**[PROPOSED]** EP-00's exit gate is met when `EX-19`, `EX-10` and `EX-12` are closed. The provider
decision (`#1`) blocks EP-01's database work, not EP-00.

---

## 5. Roles, authority and decision rights

### 5.1 The five actors

**[PROPOSED]** Five actors, no more. Every action in this document is attributable to one of them.
An actor may hold more than one role in a small team, but the roles are never merged in the record:
the approval names the role that approved.

| Actor | Who | Holds | Cannot |
| --- | --- | --- | --- |
| **Founder** | AfriNova founder | Business authority, product authority, release authority, all `[FOUNDER]` decisions | Delegate a production release approval to an agent; approve their own self-review where `GOV-09` requires a second reviewer |
| **Architect** | Technical owner (may be the founder) | Architecture, phase content, technical gate approval, `[REVIEW]` decisions | Change a business rule, a fee, a custody model or the visual identity |
| **Developer** | Human contributor | Implementation, tests, work-package definition | Approve their own `[REVIEW]` or `[FOUNDER]` change; deploy to production |
| **Reviewer** | A second person, or the architect acting as second reviewer where permitted | Code review, security review, migration review | Approve a change they authored; waive a gate |
| **AI agent** | Any automated coding agent, including sub-agents | Read anything, propose anything, edit within an assigned work package | Approve anything, deploy anything, widen a permission, change the prototype, decide an `[OPEN]` item |

### 5.2 Decision rights

**[PROPOSED]** The matrix below is the summary. `GOV-09` remains the authoritative classification
table for changes; where the two differ, `GOV-09` wins.

| Decision | Founder | Architect | Developer | Reviewer | AI agent |
| --- | --- | --- | --- | --- | --- |
| Approve this document | **A** | R | I | I | I |
| Open or close a phase | **A** | R | I | C | I |
| Phase scope change | **A** | R | C | C | I |
| New module or schema | C | **A** | R | R | I |
| New endpoint in an existing module | I | **A** | R | R | I |
| Capability or grant logic | C | **A** | R | **R (second)** | I |
| Anything that widens who can do something | **A** | R | R | R | I |
| Fee, escrow, payout, refund, ledger rule | **A** | R | I | C | I |
| New payment provider or inbound webhook | **A** | R | R | R | I |
| New colour, type size, radius, shadow, spacing | **A** | I | I | I | I |
| Change to `src/app/App.tsx` | **A** | I | I | I | I |
| New infrastructure, paid service, data-receiving vendor | **A** | R | I | I | I |
| New dependency | I | **A** | R | R | I |
| Destructive migration | **A** | R | R | **R** | I |
| Production deployment | **A (per release)** | C | I | I | **never** |
| Incident response action | I (notified) | **A** | R | I | I |

**A** = accountable/approves · **R** = responsible/does the work · **C** = consulted · **I** = informed.

### 5.3 The founder's boundaries

**[PROPOSED]** The founder approves; the founder does not bypass. Specifically, the founder may not:

- approve a release whose migration has not run on staging (`ARCHITECTURE.md` §12.8);
- approve a change that fails a gate without recording a deviation (`GOV-12`–`GOV-15`);
- approve a production release without a named artifact digest and migration set (§7, G4);
- ask an agent to make a business decision that belongs in the roadmap's decision briefs.

### 5.4 The architect's boundaries

**[PROPOSED]** The architect owns technical sequencing and may:

- define and reorder work packages inside an approved phase;
- approve `[REVIEW]` changes, including new modules, endpoints, RLS policies and dependencies;
- reject a work package that duplicates an existing capability.

The architect may not:

- change a `[FOUNDER]` decision, a fee, a custody model, a permission rule or the visual identity;
- close a phase — that is the founder's signature (§7, G5);
- approve a release.

### 5.5 Production deployment authority — the hard rule

**[DECIDED]** Every production release requires **explicit founder approval, per deployment**
(`ARCHITECTURE.md` §12.5; `GOV-09`).

**[PROPOSED]** Restated as an execution rule because it is the one boundary most likely to erode:

1. No AI agent may trigger, approve, promote or roll back a production deployment. An agent may
   prepare an artifact and open a release request; it stops there.
2. No developer may deploy from a workstation (`ARCHITECTURE.md` §12.8).
3. Approval attaches to a specific artifact digest **and** a specific migration set. A re-promotion
   of a previously approved artifact needs approval again.
4. There is no standing "auto-deploy to production" setting, and no environment variable, flag or
   script may create one.
5. The approval record states: who, when, artifact digest, migration set, what changed since the
   last release, and the rollback digest.
6. An emergency change follows `standards` §9.8: compressed review, named approver, founder
   notified, full review within one business day.

### 5.6 AI agent boundaries

**[PROPOSED]** This extends `AGENTS.md` and `standards` §12; it does not replace them.

An agent working under this document must:

- state which work package it is working in, and refuse work with no work-package ID;
- perform the reuse check before writing code (`ENG-03`, `AI-02`) and record what it inspected;
- never edit `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or
  the architecture without an explicit founder instruction;
- never resolve an `[OPEN]` decision by choosing a default;
- never claim a status above `Not started` without the artifact that proves it (§9.3);
- stop and report when a task requires a `[FOUNDER]` decision.

An agent may not be the sole reviewer of its own work, and may not be the approver of any gate.

---

## 6. The phase model

### 6.1 The dependency graph

**[PROPOSED]** The sequence is unchanged from v1 in order and intent. What changed is that EP-00
now precedes it, and two phases are marked conditional.

```
EP-00  Execution Readiness            (prerequisite — toolchain, lockfile, first commit, CI)
  │
  └── EP-01  Core Platform Foundation & Infrastructure
        │
        └── EP-02  Trust, Identity & Financial Integrity Engine
              │
              ├── EP-03  Two-Party Transaction Engine & Professional Services
              │     │
              │     └── EP-04  Three-Party Commerce Orchestration Engine
              │           │        (+ Errand, + shared request pool)
              │           │
              │           └── EP-05  Logistics & Delivery Network Engine
              │                 │
              │                 └── EP-06  AI Intelligence & Automation  [RESERVED]
              │                       │
              │                       └── EP-07  Platform Ecosystem      [CONDITIONAL]
              │                             │
              │                             └── EP-08  Global Scale      [CONDITIONAL]
```

**[PROPOSED]** `[RESERVED]` means the phase may never be built and nothing is built in advance for
it. `[CONDITIONAL]` means the phase is a roadmap option with a named precondition; it is not a
commitment and no work is scheduled for it.

### 6.2 EP-00 — Execution Readiness

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-00 |
| **Phase name** | Execution Readiness |
| **Engineering objective** | Make the repository buildable, testable, reviewable and deployable before any product capability is written. |
| **Business capability enabled** | None directly. It is the precondition for every other phase; without it, no phase can produce evidence. |
| **Roadmap phase served** | Phase 0 — Foundation and preparation |
| **Scope — in** | Toolchain pinned via `.mise.toml` (Node 22, pnpm 10.34.3); `pnpm install` and a reviewed lockfile commit (`EX-19`); a first commit with a complete tree; `.gitignore` verified to exclude secrets and build output; branch model and protected `main` (`ARCHITECTURE.md` §12.1); CI provider chosen and a pipeline skeleton that runs install → lint → typecheck → test → build (`EX-12`, `standards` §16 #18); Vitest and a linter added (`EX-10`); `typecheck` green on the prototype; a written local-run instruction that starts Postgres, API, worker and Vite (`ARCHITECTURE.md` §11.6); secret-scanning and dependency-scanning enabled. |
| **Scope — out** | Any product feature; any schema beyond a health check; any deployment to a public host; any provider integration. |
| **Depends on** | Nothing. This is the origin. |
| **Entry gate** | This document approved; founder available to approve the CI provider. |
| **Exit gate** | A clean clone installs from the frozen lockfile, typechecks, lints and runs the test command green in CI; `main` is protected; the first commit exists and is tagged `v0.0.1-bootstrap`; the pipeline is green on that commit. |
| **Evidence of completion** | CI run URL on the first commit; lockfile diff reviewed and committed; `pnpm typecheck` output; the protected-branch setting; the tagged commit SHA. |
| **Priority** | Critical — blocks every phase |
| **Status** | `Ready` |

**Why this phase exists.** v1 assumed the foundation was already in place and reported it as "In
Progress". It is not in place: there are zero commits, no test runner and a stale lockfile. Starting
EP-01 on that base would produce code that cannot be reproducibly installed or verified, which
defeats every gate in §7.

**Why it is separate from EP-01.** EP-00 is repository and pipeline hygiene. EP-01 is architecture.
Merging them lets pipeline debt hide inside a product phase, which is how the v1 status claims became
unverifiable.

### 6.3 Mapping to the business roadmap

**[CORRECTED]** v1 mapped EP-01…EP-08 onto seven "Business Phases". The roadmap has six phases,
defined by maturity gates. The correct mapping is:

| Engineering phase | Roadmap phase(s) served | Nature of the dependency |
| --- | --- | --- |
| EP-00 Execution Readiness | Phase 0 | Enables all engineering evidence |
| EP-01 Core Platform Foundation | Phase 0 → 1 | Must exist before any transaction can be taken |
| EP-02 Trust, Identity & Financial Integrity | Phase 0 → 1 | Phase 0 exit requires reviewer capacity and a settled funds structure; Phase 1 requires verification operations |
| EP-03 Two-Party Transaction Engine | Phase 1 | Delivers the first revenue-capable flow |
| EP-04 Three-Party Commerce Orchestration | Phase 1 → 2 | Phase 2 (depth and repeat behaviour) requires local commerce and errand volume |
| EP-05 Logistics & Delivery Network | Phase 2 → 3 | Phase 3 introduces logistics-as-a-service; the engine must be proven first |
| EP-06 AI Intelligence & Automation | Phase 2 → 5 | Optional; retention must not depend on it |
| EP-07 Platform Ecosystem | Phase 5 | A roadmap option requiring API stability and demand |
| EP-08 Global Scale | Phase 4 → 5 | Requires the multi-currency decision and a durable home market |

**[PROPOSED]** The mapping is directional, not a schedule. An engineering phase does not entitle the
business to skip a business gate, and a business gate does not require an engineering phase that the
gate does not use.

### 6.4 EP-01 — Core Platform Foundation & Infrastructure

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-01 |
| **Phase name** | Core Platform Foundation & Infrastructure |
| **Engineering objective** | Establish the architecture, the module boundaries, the server-side enforcement path and the core platform services that every later phase depends on. |
| **Business capability enabled** | The engineering bedrock. No business capability can be built, tested or deployed without it. |
| **Roadmap phase served** | Phase 0 → 1 |
| **Scope — in** | Modular monolith skeleton: NestJS + Fastify API, ten module boundaries with schema ownership (`ARCHITECTURE.md` §9.2), REST + OpenAPI with a generated client; PostgreSQL 16 with schema-per-module, migration tooling, and separated roles (migrator, API, worker) per database rules §6.9; RLS scaffolding as defence in depth, with the service layer authoritative (`ARCHITECTURE.md` §10.2); identity and authentication foundation — accounts, users, credentials, sessions, devices, memberships, session audiences (`ARCHITECTURE.md` §5, §10.3); the activity registry and capability computation skeleton; the five frontend bundles and route table (`react-router`), with screens extracted from `App.tsx` **without visual change**; the prototype's primitives as the design system, with the shadcn kit dormant (`ARCHITECTURE.md` §2.4, §8.3); visual regression baseline (`ARCHITECTURE.md` §16.1 #11); structured logging, the append-only `audit_log` skeleton, error tracking (vendor open); the three-environment separation with staging mirroring production topology (`ARCHITECTURE.md` §11). |
| **Scope — out** | Verification lanes and KYC; any financial ledger or provider adapter; any activity transaction flow; AI; public API; multi-region; offline sync; native apps. |
| **Depends on** | EP-00 |
| **Entry gate** | EP-00 exit; managed Postgres provider decided (`ARCHITECTURE.md` §16.4 #1); hosting, DNS and TLS decided (#17); sign-in identifier decided (#14). |
| **Exit gate** | One vertical slice works end to end on staging: sign in → session issued for the correct audience → a capability check denies and allows correctly → the action writes an audit record. Typecheck, lint and tests are green in CI. The visual regression baseline is approved by the founder. Staging runs the same artifact digest as the candidate release. |
| **Evidence of completion** | CI run; staging URL and artifact digest; the allow/deny test pair for the capability check; the audit record; the approved visual baseline; the migration that created the schemas, reviewed per §12.4. |
| **Priority** | Critical — blocks all product phases |
| **Status** | `Not started` |

**Why this phase must occur first.** Every later phase depends on the module boundary, the
capability check and the audit trail. A defect in any of the three is inherited by every phase above
it. The visual baseline is included here because extracting screens from a 3,814-line file without a
regression gate is how visual drift begins — and the prototype is the only UI authority.

### 6.5 EP-02 — Trust, Identity & Financial Integrity Engine

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-02 |
| **Phase name** | Trust, Identity & Financial Integrity Engine |
| **Engineering objective** | Build the verification, KYC, financial-ledger and payout infrastructure that makes a stranger-to-stranger transaction safe, without yet enabling any marketplace flow. |
| **Business capability enabled** | Roadmap Phase 0 exit (reviewer capacity, settled funds structure) and Phase 1 entry (verification operations). Enables registration, the six verification lanes, KYC gating, a provider-agnostic ledger, bound payout accounts and the `control.` review platform. |
| **Roadmap phase served** | Phase 0 → 1 |
| **Scope — in** | Profile and verification module: six independent lanes with their own state machines (identity, KYC tier, trade, seller, logistics, business), evidence storage in a private bucket, and an immutable decision record (matrix §7); the `control.hivorr.com` review queue, dual control on overrides, and the admin-scope model (matrix §14, `ARCHITECTURE.md` §10.5); dual taxonomy registries — Profession (Industry → Profession) and Product (vertical → category → subcategory → product type → attributes), admin-configurable (`AGENTS.md` Rule 2); financial module: double-entry append-only ledger, provider-agnostic, currency-dimensioned from day one with no conversion feature; the provider adapter boundary and the VFD adapter for collections, escrow and payouts; the `Payer Name == Entity Profile Name` deposit rule; bound payout accounts with KYC-driven limits; the dispute case record and evidence model; audit coverage for every verification and financial mutation. |
| **Scope — out** | Any marketplace transaction; escrow release timing and dispute outcomes (BD-D03 is open); fee computation (BD-D02 rates are open); multi-currency and FX; lending or credit; crypto. |
| **Depends on** | EP-01 |
| **Entry gate** | EP-01 exit; funds custody model recorded (BD-D01 — partner-held) and the `ARCHITECTURE.md` §16.4 #2 register updated to match; VFD's written licence-scope confirmation obtained, per the conditions recorded with BD-D11; KYC tier ladder decided (`ARCHITECTURE.md` §16.4 #6); verification vendor decided (#15). |
| **Exit gate** | A test account can register, submit evidence for each lane, be reviewed in `control.`, and reach `APPROVED` or `REJECTED` with an audit trail. The ledger balances under property-based invariant tests. A sandbox deposit is matched by payer name and posted to the ledger; a mismatched payer is rejected. A payout to an unbound or unverified account is refused by the service layer and by RLS independently. The VFD adapter passes its sandbox certification. |
| **Evidence of completion** | Lane state-machine tests including every deny branch; ledger invariant report; VFD sandbox certification record; reconciliation report; `control.` review-flow E2E test; the RLS test proving the second line of defence. |
| **Priority** | Critical — blocks all marketplace phases |
| **Status** | `Not started` |

**Why this phase must occur at this stage.** Trust infrastructure must exist before the first
transaction, not alongside it. A verification lane that is retrofitted after money moves cannot
retroactively protect the users who already transacted. The ledger and the payout boundary are the
same: their invariants are cheap to prove on an empty system and expensive to prove on a live one.

**Two boundaries stated explicitly.**

1. **The ledger is provider-agnostic; VFD is the launch provider.** A second provider is a new
   adapter plus a provider-reference column — never a second ledger. This is the roadmap's rule and
   it is what makes BD-R14 (single-provider concentration) survivable.
2. **The escrow state machine is built here; its release policy is not.** Release timing, dispute
   outcomes and refund rules are BD-D03 and remain **[OPEN]**. The state machine ships with the
   transitions the decision defines, not with an invented default.

### 6.6 EP-03 — Two-Party Transaction Engine & Professional Services Platform

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-03 |
| **Phase name** | Two-Party Transaction Engine & Professional Services Platform |
| **Engineering objective** | Build the reusable two-party transaction engine and launch the professional services flow — one requester, one provider, no dispatch and no multi-party split. |
| **Business capability enabled** | Roadmap Phase 1 — anchor cluster launch. Enables Hire (`services.hire`) and Offer services (`services.offer`): discovery, contract, escrow-backed payment and review, with no logistics dependency. |
| **Roadmap phase served** | Phase 1 |
| **Scope — in** | Deterministic, server-side ranking and matching (no AI); service listing, discovery and search — the Hire browse step (`discover` is a capability inside Hire, not an activity); contract and milestone state machine; escrow integration through the EP-02 adapter, with release governed by BD-D03; double-blind review and rating; encrypted messaging; scheduling and appointment management; portfolio and proof-of-work display; earnings visibility with KYC-gated withdrawal; the services dispute flow; trade-lane enforcement on publish, bid and accept. |
| **Scope — out** | Buy, Sell, Errand and logistics; dispatch; multi-party split; AI assistance; subscriptions; promoted placement. |
| **Depends on** | EP-01, EP-02 |
| **Entry gate** | EP-02 exit; BD-D03 decided (escrow timing and dispute rules); BD-D04 decided (launch configuration naming services in scope); trade verification lane operating within its SLA; the ranking engine's inputs documented and free of client-supplied authority. |
| **Exit gate** | A complete cycle runs on staging with the sandbox provider: professional publishes → requester discovers → contract → milestone → escrow → release → review. Every deny path is proven by test: unverified professional cannot publish; `tier_0` cannot withdraw; a non-party cannot read the contract. No financial calculation exists in client code. |
| **Evidence of completion** | E2E run of the full cycle on staging; the deny-path test set; the OpenAPI contract for the services module; a reconciliation statement showing escrow in, release out and platform fee; the visual regression pass for every touched screen. |
| **Priority** | High — first revenue-capable flow |
| **Status** | `Not started` |

**Why this phase must occur at this stage.** It is the lowest-complexity marketplace flow: no
physical fulfilment, no third party, no split arithmetic. It proves the trust and ledger work of
EP-02 under real conditions before orchestration is attempted. It also proves the deterministic
engines — ranking, matching, release — while the state space is still small enough to test
exhaustively.

**What "two-party" means here.** Exactly two accounts hold an interest in the transaction and exactly
one payee is settled. If a flow needs a third party to fulfil or a split between two payees, it
belongs in EP-04, not here.

### 6.7 EP-04 — Three-Party Commerce Orchestration Engine

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-04 |
| **Phase name** | Three-Party Commerce Orchestration Engine |
| **Engineering objective** | Build the orchestration engine that coordinates buyer, seller and rider in one flow, settles multiple payees from one payment, and adds Errand on the same request and dispatch substrate. |
| **Business capability enabled** | Roadmap Phase 1 → 2. Enables Buy (`market.buy`), Sell (`market.sell`), Provide logistics (`logistics.provide`) and Errand (`errands.request`). |
| **Roadmap phase served** | Phase 1 → 2 |
| **Scope — in** | Local Market module: stores, products, taxonomy bindings, carts, orders, fulfilments; seller-lane enforcement on publishing and stock; order and fulfilment workflow; the multi-party split engine (one buyer payment → seller payout + rider payout + platform fee), with every payee KYC-gated; geo-radius broadcast dispatch with logistics-lane enforcement before any dispatch is visible; the shared errand/logistics request pool with separate capability namespaces; the errand flow — create, review, submit, match, track, complete; real-time delivery tracking; multi-stop delivery within one order; merchant analytics and sales reporting; buyer, seller and rider ratings; rider performance tracking; refund and cancellation paths within the BD-D03 rules. |
| **Scope — out** | Advanced routing optimisation and fleet capacity planning (EP-05); external logistics-as-a-service API (EP-05); subscriptions and promoted placement (Phase 2 commercial work); AI. |
| **Depends on** | EP-01, EP-02, EP-03 |
| **Entry gate** | EP-03 exit; map and geo provider decided (`ARCHITECTURE.md` §16.4 #18); logistics verification lane operating; BD-D04 naming commerce and errand in the launch configuration; the split arithmetic specified and signed off as a financial rule (`GOV-09` requires founder approval). |
| **Exit gate** | Buy: order → payment → dispatch → delivery → split → settlement reconciles to the ledger, with the platform fee, seller payout and rider payout each proven by invariant tests. Errand: create → match → complete → settle, with the same evidence. Cancellation and refund paths return the ledger to balance. A rider without an `APPROVED` logistics lane cannot see or accept a dispatch. |
| **Evidence of completion** | E2E runs for buy and errand on staging; the split invariant report; the reconciliation statement for a multi-payee order; deny-path tests for seller and logistics lanes; the dispatch eligibility test; the visual regression pass. |
| **Priority** | High — increases transaction frequency and addressable market |
| **Status** | `Not started` |

**Why this phase must occur at this stage.** Multi-party settlement is the point where financial
defects become expensive: three payees, one payment, and a refund path that must unwind all three.
It is built on the two-party escrow model that EP-03 has already proven, so a failure here is a
splitting defect, not a payment defect. Attempting it earlier means debugging trust, payment and
orchestration simultaneously.

**Errand is added here, and why.** v1 omitted errand entirely, although it is one of the six
approved activities. Errand is placed in EP-04 rather than EP-03 because it depends on two things
EP-04 introduces: the **shared request pool** it holds with logistics (matrix §4.2), and **dispatch**
— an errand provider travels to a location, which is the same capability a rider needs. Placing it
in EP-03 would have forced dispatch into a phase whose defining boundary is that it has none.

**[PROPOSED]** If BD-D04 configures errand as a launch activity without rider supply, errand may be
delivered as the first work packages of EP-04, ahead of the multi-party split. The phase boundary
does not move; the internal order does.

### 6.8 EP-05 — Logistics & Delivery Network Engine

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-05 |
| **Phase name** | Logistics & Delivery Network Engine |
| **Engineering objective** | Turn the dispatch capability built in EP-04 into an efficient network that serves internal orders and, only when the business gate allows, external demand. |
| **Business capability enabled** | Roadmap Phase 2 → 3. Improves delivery cost and time per order, and produces the reliability evidence Phase 3 requires before logistics-as-a-service can be offered to external businesses. |
| **Roadmap phase served** | Phase 2 → 3 |
| **Scope — in** | Multi-stop routing and delivery optimisation; fleet capacity and availability planning; geo-radius broadcast tuning; delivery analytics, SLA monitoring and provider benchmarking; demand forecasting and surge handling; provider incentive and earnings optimisation, with payouts still KYC-gated; delivery quality assurance and loss prevention; internal logistics performance dashboards. |
| **Scope — out** | The external partner API and partner onboarding — these are the Phase 3 commercial work and require a separate founder decision; cross-border logistics. |
| **Depends on** | EP-04 |
| **Entry gate** | EP-04 exit; sustained order density in at least one cluster (roadmap Phase 2 exit evidence); a measured baseline for delivery time and cost per delivery, so improvement is provable rather than asserted. |
| **Exit gate** | Delivery time and cost per delivery improve against the recorded baseline, with the measurement method stated. Routing changes are deterministic and testable. No optimisation reduces provider earnings below the recorded floor without founder approval. |
| **Evidence of completion** | Before/after measurement report with method; routing test suite; SLA dashboard; the decision record that authorised any change to provider economics. |
| **Priority** | Medium-High — turns logistics from a cost centre into a capability |
| **Status** | `Not started` |

**Why this phase must occur at this stage.** Optimisation without volume is guesswork: there is
nothing to optimise and no baseline to prove the change. EP-04 generates the order density that makes
routing meaningful. External logistics-as-a-service additionally requires the internal network to be
demonstrably reliable, because a partner experiences Hivorr's failures as its own.

### 6.9 EP-06 — AI Intelligence & Automation Framework `[RESERVED]`

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-06 |
| **Phase name** | AI Intelligence & Automation Framework |
| **Engineering objective** | If, and only if, the founder opens AI scope: add an assistance layer that helps users write, summarise and navigate, while deterministic engines keep every decision. |
| **Business capability enabled** | None that the business depends on. The roadmap requires retention to work without AI (§8.7), so this phase cannot be a launch dependency. |
| **Roadmap phase served** | Phase 2 → 5 (opportunistic) |
| **Scope — in** | Only what a founder decision names. The plausible surface is: conversational help, drafting (messages, job posts, product descriptions), document generation from existing records (invoice, quote), and summarisation of a thread the user can already read. Every output is a draft the user must confirm. |
| **Scope — out** | Ranking, matching, pricing, dispatch, payouts, splits, refunds, verification decisions, account suspension, or any autonomous state change. AI never writes to the ledger, the capability table or the verification state machine (`AGENTS.md` Rule 1 and Rule 4). |
| **Depends on** | EP-03 and EP-04 for real data; a stable deterministic core; an evaluation harness. |
| **Entry gate** | AI scope decided (`ARCHITECTURE.md` §16.4 #20) with a named surface; a data-processing basis for any personal data sent to a model provider; a model provider chosen as a `[FOUNDER]` vendor decision; an evaluation set and a failure policy written. |
| **Exit gate** | The assistant cannot perform a write without an explicit user confirmation that is itself audited. Every model call is logged with its prompt version. A red-team set of prompts fails safely. Turning the feature off leaves the product fully usable. |
| **Evidence of completion** | The no-write guarantee proven by test; prompt-version registry; evaluation results; the feature-flag proof that the product works with AI disabled. |
| **Priority** | Low — optional, and never on the critical path |
| **Status** | `Reserved` |

**Why it is reserved rather than sequenced.** v1 placed AI at EP-06 as a committed phase with
"task auto-completion agents" and "natural language transaction processing". Both conflict with the
guardrails: AI may not complete a transaction or decide an outcome. AI scope is also **[OPEN]**, and
the roadmap explicitly requires retention to work without it. A phase that may never be built must
not sit on the critical path, or it silently becomes a dependency.

### 6.10 EP-07 — Platform Ecosystem & Integration Framework `[CONDITIONAL]`

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-07 |
| **Phase name** | Platform Ecosystem & Integration Framework |
| **Engineering objective** | If the business reaches the point where external developers and partners need programmatic access: expose a stable, scoped API and a partner programme. |
| **Business capability enabled** | Roadmap Phase 5, option 3 — third-party integrations and developer access. |
| **Roadmap phase served** | Phase 5 |
| **Scope — in** | Public API with versioning; developer documentation; scoped API credentials and rate limits; partner onboarding, membership and performance monitoring; revenue-share billing and settlement; ecosystem quality and governance rules. |
| **Scope — out** | White-label licensing (an explicit roadmap non-goal until the core business is profitable); a self-service connector builder; a plugin runtime; module federation. |
| **Depends on** | EP-01 through EP-05, plus proven API stability. |
| **Entry gate** | API stability demonstrated over a recorded period; demonstrated external demand; the partner programme approved as a business decision; the `partners.` capability boundary confirmed (no activity capability — `standards` §16 #20). |
| **Exit gate** | One external partner completes a real integration against the documented API without bespoke support. Revenue share settles correctly and is auditable. |
| **Evidence of completion** | Partner integration record; settlement reconciliation; API versioning policy; the developer documentation as shipped. |
| **Priority** | Low — requires maturity and demand |
| **Status** | `Conditional` |

**Why it is conditional.** An ecosystem opened before the API is stable produces partner churn and a
support burden that a small team cannot absorb. The precondition is evidence, not enthusiasm: API
stability measured over time, and demand that exists before the programme is announced.

### 6.11 EP-08 — Global Scale & Multi-Region Infrastructure `[CONDITIONAL]`

| Attribute | Detail |
| --- | --- |
| **Phase ID** | EP-08 |
| **Phase name** | Global Scale & Multi-Region Infrastructure |
| **Engineering objective** | If the business expands beyond Nigeria: replicate the proven model in a second market without redesigning the core. |
| **Business capability enabled** | Roadmap Phase 4 — African expansion, and Phase 5 selective global markets. |
| **Roadmap phase served** | Phase 4 → 5 |
| **Scope — in** | Multi-region data architecture with geographic isolation; localisation of language, currency, support hours and dispute norms; local payment and payout partners; local identity and verification norms; local entity and compliance per jurisdiction; regional analytics. |
| **Scope — out** | Crypto or digital-asset custody; lending; selling personal data; white-label licensing (roadmap §14 explicit non-goals); any named cross-border provider before it is selected. |
| **Depends on** | EP-01 through EP-05, and a durable home market. |
| **Entry gate** | Multi-currency model decided (BD-D07; `ARCHITECTURE.md` §16.4 #8); data residency and primary region decided (#16); at least one market outside Nigeria at roadmap Phase 2 maturity; local entity and counsel in place. |
| **Exit gate** | One market outside Nigeria operates at Phase 2 maturity with acceptable settlement and FX cost; localisation is complete for that market; no core module was forked to achieve it. |
| **Evidence of completion** | Market launch record; FX cost as a share of transaction value; the localisation coverage matrix; proof that the core modules were reused, not copied. |
| **Priority** | Long-term — depends on everything before it |
| **Status** | `Conditional` |

**Why it is conditional, and what changed.** v1 named Thunes and other providers as "under due
diligence". No such decision exists. BD-D11 made VFD the single payment and custody partner for
Nigeria; cross-border providers are **[OPEN]** and must not be pre-selected in an execution plan.
Expansion is also gated on the multi-currency decision, which is open — building a multi-region
architecture before it is settled would encode an assumption into the schema.

### 6.12 Summary matrix

| Phase | Name | Roadmap phase | Priority | Depends on | Status |
| --- | --- | --- | --- | --- | --- |
| EP-00 | Execution Readiness | 0 | Critical | — | `Ready` |
| EP-01 | Core Platform Foundation & Infrastructure | 0 → 1 | Critical | EP-00 | `Not started` |
| EP-02 | Trust, Identity & Financial Integrity Engine | 0 → 1 | Critical | EP-01 | `Not started` |
| EP-03 | Two-Party Transaction Engine & Professional Services | 1 | High | EP-01, EP-02 | `Not started` |
| EP-04 | Three-Party Commerce Orchestration Engine | 1 → 2 | High | EP-01, EP-02, EP-03 | `Not started` |
| EP-05 | Logistics & Delivery Network Engine | 2 → 3 | Medium-High | EP-04 | `Not started` |
| EP-06 | AI Intelligence & Automation Framework | 2 → 5 | Low | EP-03, EP-04 | `Reserved` |
| EP-07 | Platform Ecosystem & Integration Framework | 5 | Low | EP-01…EP-05 | `Conditional` |
| EP-08 | Global Scale & Multi-Region Infrastructure | 4 → 5 | Long-term | EP-01…EP-05 | `Conditional` |

**Activities covered, with no gaps.** Every one of the six approved activities is owned by exactly
one phase:

| Activity | ID | Phase |
| --- | --- | --- |
| Buy | `market.buy` | EP-04 |
| Hire | `services.hire` | EP-03 |
| Errand | `errands.request` | EP-04 |
| Sell | `market.sell` | EP-04 |
| Offer services | `services.offer` | EP-03 |
| Provide logistics | `logistics.provide` | EP-04 |

**[PROPOSED]** This table is a completeness check, not a launch commitment. Which activities ship at
launch is BD-D04 and `ARCHITECTURE.md` §16.4 #3, both **[OPEN]**.

---

## 7. Gate definitions

### 7.1 The six gates

**[PROPOSED]** Every work package passes the same six gates. A gate is not a meeting; it is a
condition with evidence. Skipping a gate is a deviation and follows `GOV-12`–`GOV-15`.

| Gate | Name | Purpose | Required evidence | Approver | On failure |
| --- | --- | --- | --- | --- | --- |
| **G0** | Ready | The work is defined, classified and unblocked before code is written | Work-package record with objective, class (`GOV-09`), scope, reuse check, test plan and rollback; every `[OPEN]` decision it depends on is settled | Architect | Do not start. Return to definition. |
| **G1** | Build complete | The change exists and is locally verified | Code, tests written, `pnpm typecheck` green, lint green, test command green locally, migration self-contained if any | Developer self-check | Not ready for review |
| **G2** | Verified | The change is independently reviewed and CI-verified | Green CI run on the exact commit; review approval by someone other than the author; security review where `GOV-09` requires it; migration reviewed with `db diff`; visual regression pass where UI changed; OpenAPI diff clean or explicitly accepted | Reviewer; architect for `[REVIEW]` | Do not merge |
| **G3** | Staging | The change works in an environment that mirrors production | Artifact deployed to staging; migrations applied in order; smoke test; E2E for the touched flow; founder review where the change is user-visible and material | Architect | Do not promote |
| **G4** | Release | The change reaches production under explicit authority | Founder approval record naming artifact digest, migration set, change summary and rollback digest; post-deploy smoke test; 30-minute error-rate and queue-depth watch | **Founder, per deployment** | Roll back to the previous digest; record the incident |
| **G5** | Phase exit | The phase's capability is complete and its evidence exists | Every exit criterion in §6 met, each with a linked artifact; no open `[FOUNDER]` decision inside the phase's scope; the phase's capability demonstrated on staging | **Founder**, on the architect's recommendation | Phase stays open |

### 7.2 What counts as evidence

**[PROPOSED]** Evidence is an artifact a third party can inspect without trusting the author:

- a commit SHA, a pull request, or a CI run URL;
- a test that fails when the behaviour is removed;
- a staging URL and the artifact digest deployed to it;
- a signed founder approval record;
- a migration file and its `db diff` output;
- a measurement with its method stated.

Evidence is **not**: a sentence in a status field, a screenshot without a commit, a verbal approval,
or an agent's summary of its own work.

### 7.3 Gate exceptions

**[PROPOSED]** There are no silent exceptions. A gate may be passed by deviation only, and a
deviation requires the record in `GOV-13` with an owner and an expiry. A deviation that expires
re-opens the gate. A deviation on **G4** (production release) or on a **`[FOUNDER]`** decision is
invalid — those gates have no deviation path.

### 7.4 Emergency changes

**[DECIDED]** Emergency changes follow `standards` §9.8: compressed review, a named approver, the
founder notified, and full review within one business day. **[PROPOSED]** In addition, the incident
record must state which gate was compressed and why, and the phase status is not advanced by an
emergency fix.

---

## 8. Work-package protocol

### 8.1 Identifier

`EP-<phase>-<nnn>`, for example `EP-02-014`. Identifiers are never reused. A work package that is
abandoned keeps its ID and is marked `Cancelled`, so history stays readable.

**[DECIDED]** The founder ruled on 4 November 2026 that work-package identifiers carry the `EP-`
prefix, matching the phase identifiers and the EP-01 phase plan. The `WP-` form used in version 2.0
of this document is retired; no identifier in either form is reused.

### 8.2 Required fields

**[PROPOSED]** A work package is not ready (G0) until all of these exist:

| Field | Content |
| --- | --- |
| **ID** | `EP-<phase>-<nnn>` |
| **Phase** | The one phase it belongs to |
| **Objective** | One sentence: what is true after this that was not true before |
| **Class** | The `GOV-09` class, highest engaged rule wins |
| **Scope — in / out** | Files, modules, endpoints and screens touched; and what is deliberately not touched |
| **Reuse check** | What existing code, component, service, utility, schema or adapter was inspected, and why it could not be reused (`ENG-03`, `AI-02`) |
| **Dependencies** | Other work packages, decisions and provider prerequisites |
| **Test plan** | The tests that will fail before and pass after, including every deny branch |
| **Evidence** | What artifact will prove completion at G2 |
| **Rollback** | How the change is reverted, including any data consideration |
| **Approver** | The role required by `GOV-09` |

### 8.3 Size

**[PROPOSED]** One work package is one reviewable diff. Split it when any of these is true:

- it changes more than one module's public contract;
- it mixes a schema change with a behaviour change;
- it cannot be reviewed in one sitting by someone who did not write it;
- it would need more than one rollback decision.

A work package that is too large to review is too large to verify, and an unverified change is a
defect waiting for a user.

### 8.4 The reuse check is mandatory

**[DECIDED]** Reuse before creating is an approved engineering principle (`ENG-03`, `AI-02`, and
`AGENTS.md` §3). **[PROPOSED]** In this document's terms: a work package with an empty or trivial
reuse check is not ready. "Nothing similar exists" is only acceptable with the list of what was
searched.

### 8.5 What a work package is not

- It is not a phase. A phase contains many.
- It is not a sprint. There is no timebox; there is a gate.
- It is not a place to resolve an `[OPEN]` decision. If the work needs a decision, the decision comes
  first and the work package records it as a dependency.
- It is not a licence to refactor adjacent code. Bounded scope limits edits, not understanding
  (`AGENTS.md` §3).

---

## 9. Status vocabulary

### 9.1 The only permitted statuses

**[PROPOSED]** Phase and work-package status uses exactly these values. No percentages, no "almost
done", no "landed".

| Status | Meaning |
| --- | --- |
| `Not started` | No work exists. |
| `Ready` | Entry gate met; G0 satisfied; work may begin. |
| `In build` | Work is being implemented; G1 not yet passed. |
| `In review` | G1 passed; awaiting G2. |
| `Verified` | G2 passed; awaiting staging or release. |
| `Released` | G4 passed; live in production. |
| `Blocked` | Cannot proceed; the blocker and its owner are named. |
| `Reserved` | May never be built; nothing is built in advance. |
| `Conditional` | A roadmap option with a named precondition; not scheduled. |
| `Cancelled` | Abandoned; the ID is retained. |

### 9.2 Transitions

`Not started → Ready → In build → In review → Verified → Released`, with `Blocked` reachable from
any state and returning to the state it left. A phase closes only through **G5**, which is a founder
signature, not a status change.

### 9.3 The evidence rule

**[PROPOSED]** This is the rule that prevents the v1 failure:

> A status above `Not started` requires a linked artifact. If the artifact cannot be produced, the
> status is `Not started`.

Corollaries:

1. A phase is not `In build` because someone is thinking about it.
2. A work package is not `Verified` because the author says the tests pass.
3. A module is not "landed" because a directory exists. An empty directory is not an implementation.
4. An agent's report of its own work is a claim, not evidence. The artifact is the evidence.

### 9.4 Correction of the v1 statuses

**[CORRECTED]** For the record, and so no later reader inherits the error:

| v1 claim | Verified position |
| --- | --- |
| EP-01 "In Progress — scaffolding, environments, Universal Entity model, auth, router, design system landed" | **`Not started`.** No scaffolding, no environments, no entity model, no auth, no router in use, no design-system extraction. The prototype and its tokens exist; that is the input to EP-01, not EP-01. |
| EP-02 "In Progress — taxonomy, verification, financial integrity, onboarding, Admin review landed" | **`Not started`.** None of these exist. There is no taxonomy registry, no verification lane, no ledger and no `control.` platform. |
| EP-03 "In Progress — Services Marketplace subset" | **`Not started`.** There is no services module. The prototype contains screens; screens are not a marketplace. |
| EP-04 to EP-08 "Not Started" | Correct, and unchanged. |

---

## 10. Execution decisions this document introduces

**[PROPOSED]** These are the decisions this document makes. Each takes effect on approval, and each
states what reversing it would cost, so the founder can judge it rather than accept it blindly.

| ID | Decision | Why | Cost to reverse |
| --- | --- | --- | --- |
| **ED-01** | A phase is a gate, not a date. No phase carries a target date. | Dates create pressure to declare completion without evidence. | Low — dates can be added as planning aids without changing the gate. |
| **ED-02** | **EP-00 Execution Readiness** precedes EP-01 and is a real phase with an exit gate. | The repository has no commits, no test runner and a stale lockfile. Building on that base produces unverifiable work. | Low, but reversing it means accepting unverifiable phases. |
| **ED-03** | Exactly one phase may be `In build` at a time. | A small team plus a two-reviewer rule cannot support two phases in parallel without both degrading. | Medium — parallel phases would need more review capacity first. |
| **ED-04** | Errand belongs to EP-04, not EP-03, because it depends on the shared request pool and dispatch. | v1 omitted errand entirely; placing it in EP-03 would import dispatch into a phase defined by not having it. | Low — internal ordering inside EP-04 can change without moving the boundary. |
| **ED-05** | EP-06 AI is `Reserved`, not sequenced. Nothing is built in advance for it. | AI scope is open, and the roadmap requires retention to work without it. | Low — if AI is approved, the phase opens with its own entry gate. |
| **ED-06** | EP-07 and EP-08 are `Conditional` roadmap options, not commitments. | Both depend on open decisions and on business gates several phases away. | Low. |
| **ED-07** | A status above `Not started` requires a linked artifact (§9.3). | v1's status claims were unsupported, which made the whole plan untrustworthy. | None — this is the minimum standard for a plan. |
| **ED-08** | Engineering may build ahead of a business gate, but may not release ahead of it (§1.4). | Prevents both idle engineering and premature launch. | Low. |
| **ED-09** | Every work package must record a reuse check before it is `Ready` (§8.4). | Reuse-first is already an approved principle; this makes it auditable rather than aspirational. | None. |
| **ED-10** | No AI agent may trigger, approve or roll back a production deployment (§5.5). | Restates `ARCHITECTURE.md` §12.5 as an execution rule, because it is the boundary most likely to erode under delivery pressure. | This is not reversible without amending `ARCHITECTURE.md`. |

---

## 11. Open decisions

### 11.1 Already-open decisions that block this plan

**[OPEN]** Nothing below may be implemented as though it were decided. This is not a new register —
`ARCHITECTURE.md` §16.4 is the single consolidated list. The rows here are the ones that block
**sequencing**, not just implementation.

| Decision | Register | Blocks |
| --- | --- | --- |
| Managed Postgres provider | `ARCHITECTURE.md` §16.4 #1 | EP-01 database work; staging |
| Hosting platform, DNS, TLS | `ARCHITECTURE.md` §16.4 #17 | EP-01 staging; G3 |
| Sign-in identifier | `ARCHITECTURE.md` §16.4 #14 | EP-01 authentication |
| KYC tier ladder and limits | `ARCHITECTURE.md` §16.4 #6 | EP-02 financial gating |
| Verification vendor | `ARCHITECTURE.md` §16.4 #15 | EP-02 identity lane |
| Map / geo provider | `ARCHITECTURE.md` §16.4 #18 | EP-04 dispatch and errand |
| Escrow timing and dispute rules (BD-D03) | roadmap §21 | EP-02 escrow policy; EP-03 exit |
| Launch configuration (BD-D04) | roadmap §21 | EP-03 and EP-04 entry |
| MVP activity scope | `ARCHITECTURE.md` §16.4 #3 | Which phase work is launch-blocking |
| Currency model (BD-D07) | `ARCHITECTURE.md` §16.4 #8 | EP-08; any multi-currency work |
| AI scope | `ARCHITECTURE.md` §16.4 #20 | EP-06 entirely |
| CI provider and repository hosting | `standards` §16 #18 | EP-00 exit; every G2 |
| Coverage gate for authorisation and financial modules | `standards` §16 #16 | EP-02 and EP-03 exit evidence |
| Test toolchain approval | `GOV-09` — adding the test toolchain | EP-00 exit |

### 11.2 New decisions this document surfaces

**[OPEN]** These are not in any existing register. They are recorded here for the founder and should
be folded into `ARCHITECTURE.md` §16.4 when decided, so the single list stays single. Row 1 was closed
on 4 November 2026 and is kept for history.

| # | Decision | Why it matters | Blocks | Proposed default |
| --- | --- | --- | --- | --- |
| 1 | **Was `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` v1.3 approved?** It was marked "Proposed — awaiting founder approval". | Every gate in §7 and every `GOV-09` class this document relies on lives in that document. If it is not approved, those gates have no authority and this document's G0–G5 are only local convention. | The binding force of §7 and §8 | **Resolved 4 November 2026** — the founder approved that document as version 2.0. `GOV-09`, the gate set in its §13.4 and its exceptions register now bind, and the §7 gates above have the authority this document assumed. No other row in this table is affected |
| 2 | **Who is the second reviewer when the team is one person plus agents?** `GOV-09` requires two reviewers for authentication, capability and migration changes. | With a one-person team the rule is either impossible or quietly ignored. Both outcomes are worse than a recorded exception. | EP-01 authentication; EP-02 capability work | Either appoint an external reviewer, or record a time-boxed deviation with compensating controls (founder review plus an agent-assisted checklist) |
| 3 | **May an AI agent ever hold `platform.engineering`?** `ARCHITECTURE.md` §4.4 defines the grant for humans and time-boxes it; agents are not addressed. | Agents already edit the repository. If they act without a grant, the grant model is decorative. | How agent work is authorised | No standing grant. Agents act inside a named work package under a human's grant, and every agent change is reviewed by a human |
| 4 | **Should EP-07 and EP-08 remain in this document, or move to the roadmap as options?** | They are not engineering commitments and may never be built. Keeping them here risks them being read as planned work. | Nothing today | Keep them, marked `Conditional`, as the completeness check for the architecture's expansion tiers |
| 5 | **Does errand launch with rider supply, or with errand-only providers?** | Determines whether errand can be the first EP-04 delivery, ahead of multi-party settlement. | Internal order inside EP-04 | Decide with BD-D04, not separately |
| 6 | **Is `ARCHITECTURE.md` §16.4 #2 (funds custody) still open?** BD-D01 decided partner-held custody, and §3.1 row 10 was amended for VFD, but the register still lists custody as open. | Two documents disagree about whether a foundational decision is settled. Anything built on the wrong reading is built on sand. | EP-02 entry gate | Mark #2 decided, citing BD-D01, and keep the VFD conditions as the operational precondition |

---

## 12. Conflict register — version 1.0 against the approved documents

**[CORRECTED]** Every v1 statement that conflicts with an approved document, and what replaced it.
This table exists so the correction is auditable and does not have to be rediscovered.

| # | v1 statement | Authority it conflicts with | Resolution in this version |
| --- | --- | --- | --- |
| 1 | EP-01/02/03 "In Progress", systems "landed" | The repository: zero commits, no server, no schema, no tests | All phases `Not started`; evidence rule added (§9.3) |
| 2 | Maps to "Business Phase 1…7" | Roadmap §14: Phase 0–5, defined by maturity gates | Re-mapped in §6.3 |
| 3 | "PostgreSQL server-side architecture (RPC + RLS)" | `ARCHITECTURE.md` §10.2: service layer authoritative, RLS defence in depth; database rules §2.4 Position A | §6.4 scope |
| 4 | "Universal Entity data model" | Matrix §3.3: account → user → profile → activity | §6.4 scope |
| 5 | "SSL pinning" | `ARCHITECTURE.md` §10.11: web product, TLS/HSTS/cookies | Removed (§2.3) |
| 6 | Multi-currency and currency conversion in EP-02 | `ARCHITECTURE.md` §16.4 #8 open; roadmap BD-D07 deferred to Phase 4 | Currency-dimensioned ledger; no conversion feature; enabled currencies stay open |
| 7 | AI as a committed phase with autonomous task completion and natural-language transactions | `AGENTS.md` Rule 1 and Rule 4; `ARCHITECTURE.md` §16.4 #20 open; roadmap §8.7 | EP-06 `Reserved`; write-free scope only (§6.9) |
| 8 | No errand anywhere in the phase model | `VISION.md` §6; matrix §4: errand is one of six activities | Added to EP-04 (§6.7) |
| 9 | "Admin review gate" assumed but no phase builds it | `ARCHITECTURE.md` §4.4, §10.5: `control.` platform with scoped admin | Owned by EP-02, with its own exit criterion |
| 10 | Thunes and other cross-border providers named as under due diligence | BD-D11: VFD is the single payment and custody partner; no cross-border provider decided | Removed; cross-border is `[OPEN]` (§6.11) |
| 11 | Offline sync engine in EP-01 | `ARCHITECTURE.md` §16.4 #19: mobile open; sync deferred to a funded app | Removed (§2.3) |
| 12 | "Approved Engineering Execution Structure" | No approval existed | Status was `Proposed` until approved on 4 November 2026; approval record in §14 |
| 13 | Phase statuses with no artifact behind them | `GOV-09`, `QUA-37`: completion requires evidence | §9.3 evidence rule |

---

## 13. Changelog

### 4 November 2026 — version 2.0, identifier convention amended

The founder ruled that work-package identifiers take the `EP-` prefix: `EP-<phase>-<nnn>`, for
example `EP-00-001`. The `WP-` form written in version 2.0 is retired.

**Why.** §8.1 mandated `WP-` while the EP-01 phase plan already enumerated its items as
`EP-01-001`, so the repository carried two conventions and one plan referenced a prefix that existed
nowhere else. The founder chose the `EP-` form. The EP-00 plan's items were renamed once, rather than
renaming every EP-01 item, and the prefix now matches the phase identifier it belongs to.

**What changed in this document.** §3.1 example, §8.1, and the §8.2 field table now use `EP-`. The
rule text is otherwise unchanged.

**What did not change.** Identifiers are still never reused; a cancelled package keeps its ID; the
`nnn` space, the G0 fields and the size rule are untouched.

### 4 November 2026 — version 2.0, post-approval note

`ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` was approved by the founder as version 2.0 on
4 November 2026. Two consequences for this document:

- §11.2 #1 is closed. The `GOV-09` change classes, the standards' gate set and its exceptions
  register now bind, so the gates in §7 rest on an approved document rather than on this one alone.
- Nothing else changes. Approval of the standards does not approve EP-00, any work package, or any
  release, and does not settle any `[OPEN]` row in §11.

### 4 November 2026 — version 2.0

**Rebuilt from version 1.0 (attachment, 199 lines).** The original is preserved unchanged at
`C:\Users\user\Downloads\Engineering-Execution-Structure.md` and is not part of this repository.

**Approved** — 4 November 2026 by the founder, version 2.0 as written, with no conditions recorded.

**Retained**

- EP-01…EP-08 identifiers, names and order; the dependency principle; the per-phase attribute
  schema; deterministic-core supremacy; server-side enforcement; the unified account with six
  activities and no "Both"; dual taxonomy; provider-agnostic financial infrastructure; universal
  platform before industry verticals; scalability without redesign.

**Corrected**

- Status claims, business-phase mapping, database access model, entity vocabulary, SSL pinning,
  multi-currency scope, AI sequencing, errand omission, `control.` ownership, ecosystem and global
  phases presented as commitments. See §12.

**Removed**

- Offline sync engine; SSL pinning; autonomous AI task completion and natural-language transaction
  processing; the Thunes reference; v1's "Approved" closing status; unverifiable progress claims. See §2.3.

**Added**

- EP-00 Execution Readiness; roles and decision rights; production deployment authority as a hard
  rule; gates G0–G5 with evidence; work-package protocol; status vocabulary and evidence rule;
  conflict register; open-decision list; approval record. See §2.4.

---

## 14. Approval

**Approved.** The founder approved this document on 4 November 2026. Approval covers the phase
sequence (§6), the gate definitions (§7), the work-package protocol (§8), the status vocabulary (§9)
and the execution decisions in §10.

| Field | Value |
| --- | --- |
| **Approved by** | Founder (AfriNova) |
| **Date** | 4 November 2026 |
| **Version approved** | 2.0 |
| **Conditions of approval** | None recorded. The open items in §11 remain open and are unaffected by this approval. |
| **Next review** | On any change to `ARCHITECTURE.md` §16.4, the roadmap's phase gates, or the standards document's governance section |

**What approval does not do.** It does not approve any phase for build, does not approve the
standards document, does not settle any `[OPEN]` decision in §11, and does not authorise a
production release. Each of those is a separate act by the person named in §5.2.
