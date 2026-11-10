# Task Implementation Plan — EP-01-001
## Entry gate closure and decision register

### 1. Task Objective

Produce **one signed phase-entry record** for EP-01 that:

1. Re-verifies EP-00's exit evidence criterion by criterion (not by trusting `EP-00-010`'s summary).
2. Records every decision EP-01 depends on, by reference to the register that owns it, with owner, date, class, evidence and follow-up.
3. Records the G0 scope readings in EP-01 §4.3 (four bundles / eight deployments; slice-only extraction).
4. Carries an item-level blocker matrix for all 38 remaining EP-01 items listed in the EP-01 entry record §8.
5. Sets EP-01 to exactly one status — **`Ready`** or **`Blocked`** — with named owners for anything missing.

It writes no code, creates no schema, changes no phase plan, and decides nothing itself.

---

### 2. Business Problem Being Solved

EP-01 is the phase that builds identity, sessions, capabilities, audit and the delivery pipeline. Every one of those is a security control. If EP-01 starts on assumptions — an unknown Postgres provider, an undecided sign-in identifier, an expired second-reviewer arrangement, a "protected main" that isn't protected — the phase will produce code that must later be rebuilt, and the audit trail will show that it was knowingly built on unsettled ground.

The specific risk today is the v1 failure mode returning in a new shape: EP-01 marked "Ready" because the folder exists, while three founder decisions, six architect decisions, an expired deviation and an unmet EP-00 exit criterion remain open.

**Verified position today (2026-11-06).** EP-00 is **not exited**: `EP-00-010` records **C8 unmet** (GitHub Free cannot protect a private repository), **C14 unmet** (no G5 founder signature), and **C10 partially met** (tag predates CI). `EP-00-011` is `Blocked — HOLD`. Under EES §7.3 a gate may only be passed by a recorded deviation, and a deviation on a `[FOUNDER]` gate is invalid — G5 is a founder signature. Therefore **on present evidence EP-01-001's honest outcome is `Blocked`**, and this plan is designed to record that truthfully rather than to route around it.

---

### 3. Scope

#### 3.1 In scope

| # | Content |
|---|---|
| 1 | Record identity: `EP-01-001`, phase, class, status, author, approver roles, dates |
| 2 | Authority basis: exact paths, versions, approval dates, sections relied on |
| 3 | EP-00 exit verification: C1–C14 each mapped to an inspectable artifact or marked unmet |
| 4 | Drift register: differences between the EP-01 plan's planning snapshot and today's repository |
| 5 | Decision register — reference-only rows for the 3 founder entry decisions, the second-reviewer arrangement, the 6+ architect decisions, the test-toolchain residual, and the technical selections EP-01-002/021 depend on |
| 6 | G0 scope rulings: EP-01 §4.3 items 1 and 2, recorded verbatim as ruled |
| 7 | Item blocker matrix for the 38 remaining items: status, blockers, owner, clearing condition |
| 8 | Phase status determination with the checklist that produces `Ready` or `Blocked` |
| 9 | Residual risks and carried conditions (including `DEV-001` expiry and the C8 compensating control) |
| 10 | Signature block and append-only amendment log |
| 11 | Evidence folder with the read-only transcripts used (git, tag, CI runs, API 403 reproduction, secret-scan proof) |

#### 3.2 Out of scope — must not do these

- Any production code, config, dependency, script, test, schema, migration, API or UI.
- Any edit to `src/app/App.tsx`, `documents/Context/*`, or the approved EP-00/EP-01 phase plans.
- Resolving any `[OPEN]` decision, choosing a default, naming a provider, a linter, a migration runner, a vendor or a session lifetime.
- Creating the remote, enabling protection, provisioning staging, or touching CI configuration.
- Building the EP-01-070 evidence index or the EP-01-072 closure record.
- Creating a second decision register or a second deviations register.
- Signing, approving, or declaring the phase status on the founder's or architect's behalf.
- Fixing the two pre-existing divergences this task will *record* (see §5.4).

---

### 4. Existing Asset and Dependency Analysis

#### 4.1 Assets inspected (all read today)

| Asset | Path | What it gives this task | Reuse decision |
|---|---|---|---|
| EP-01 phase plan | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` | Task definition, entry gate, §4.3 scope readings, §7 dependencies, §9 items, §13 criteria | **Reuse as the single source of truth**; do not modify or restate |
| EP-00 entry record | `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` | Proven record structure, decision-row format, status logic, blocker-matrix format, amendment-log discipline | **Reuse the structure verbatim**; do not copy the content |
| EP-00-000 plan §6.2–§6.5 | `documents/Task-Implementation/EP-00/EP-00-000 — Phase entry record…md` | The fixed, reusable section list and decision-row rules | **Reuse as the template definition** |
| EP-00 evidence pack | `documents/Task-Implementation/EP-00/EP-00-010 — Phase evidence pack and traceability index.md` | C1–C14 with artifacts and unmet flags | **Reuse as input, re-verify**; do not restate as truth |
| EP-00 closure record | `documents/Task-Implementation/EP-00/EP-00-011 — G5 phase closure record.md` | Unmet items, residual risks, EP-01 entry conditions inherited | **Reuse as input**; its unsigned state is a finding |
| `EP-00-001 — Decision record and amendment log.md` | same folder | Precedent for recording decisions *alongside* a task without amending the plan | **Reuse the pattern**; do not create a second one for EP-01-001 |
| Branch protection policy | `documents/Engineering-Execution/BRANCH_PROTECTION.md` | The real compensating control for C8: local pre-push hook, CI `verify-pr` guard, deployment gates, GitHub Free limits | **Reuse as the described control**; not as a claim of protection |
| Architecture open-decision register | `documents/Context/ARCHITECTURE.md` §16.4 (`#1`, `#14`, `#17`, `#25`), §16.3 | The owning register for the three entry decisions | **Reuse by reference only** |
| Standards open decisions | `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` §16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9`; §13.3 `EX-02`,`EX-10`,`DEV-001`; §1.4 classes; §13.2 deviation rules; §19.3 AR-0 | The owning register and class definitions for the architect-level decisions | **Reuse by reference only** |
| Execution structure | `…/ENGINEERING_EXECUTION_STRUCTURE.md` §5.2 roles, §5.6 AI limits, §7.1 gates, §7.3 exceptions, §8.2 required fields, §9.1–§9.3 status and evidence rule, §11.2 #2 | The gate logic the record must apply | **Reuse as authority** |
| CI pipeline | `.github/workflows/ci.yml` (6 jobs: install, lint+format, typecheck, test, build, secret+dependency), `branch-guard.yml`, `deploy-staging.yml`, `deploy-production.yml` | The G2 evidence path; the required status-check names | **Reuse**; no change |
| Secret scan | `scripts/secret-scan.mjs` → `pnpm security:secrets` | A real control that can prove the record contains no secret | **Reuse** |
| Format/lint gates | `scripts/format-check.mjs` (JS/TS only), `scripts/lint.mjs` | Confirmed **not engaged** by a Markdown-only change; state this rather than silently skipping | **Inspected, correctly not triggered** |
| Evidence conventions | `…/EP-00/evidence/`; `documents/Engineering-Execution/evidence/branch-protection/` | Two existing evidence roots | **Reuse the EP-00 phase-record root**; record the divergence as a finding |
| Prototype / UI | `src/app/App.tsx` | Must remain byte-identical | **Do not touch** |

#### 4.2 Dependencies

| Dependency | Type | Effect |
|---|---|---|
| EP-00 exit (G5) | Founder act | **Hard blocker.** Not evidenced today |
| `#1` managed Postgres provider | `[FOUNDER]` | Blocks `020`–`026`, `060`, `062` |
| `#17` hosting/DNS/TLS | `[FOUNDER]` | Blocks `041`, `054`, `060`, `063` |
| `#14` sign-in identifier | `[FOUNDER]` | Blocks `031`, `032`, `053` |
| Second reviewer / `DEV-001` re-deviation | `[FOUNDER]` | Expires before EP-01 touches auth/capability/migration, and by 2026-12-31 — blocks `023`,`025`,`030`–`036` |
| `standards §16 #1,#2,#3,#6,#8,#9` | `[REVIEW]` / `[FOUNDER]` | Block `003`,`011`,`013`,`020`,`032`,`040`,`041`,`043` |
| `EX-10` residual (Playwright, Testcontainers, Testing Library) | `[REVIEW]` via GOV-09 | Blocks `004`,`025`,`050`,`063` |
| Technical selections (DB driver, migration runner, queue, OpenAPI generator, boundary lint) | `[REVIEW]` | EP-01-002 and EP-01-021 name these as *from EP-01-001* |
| EP-01 §4.3 rulings 1–2 | `[REVIEW]` | Confirms phase scope; no item may start without it |
| Reviewer capacity | Human | One-person team; `DEV-001` compensating controls apply |

#### 4.3 Deliberately **not** carried as entry blockers

Examined and excluded, so scope does not creep: `standards §16 #4` (MFA policy — EP-01 builds MFA-*ready schema* only), `#5` (rate-limit thresholds — belongs to `042`), `#10` (retention — no purge is built), `#16` (coverage gate — EP-02/03 exit), `#17` (fonts), and `ARCHITECTURE §16.4 #2/#6/#8` (finance, KYC, currency — no money or KYC code exists in EP-01).

---

### 5. Reuse / Extension / Refactoring Assessment

| Proposed asset | Options considered | Decision | Justification |
|---|---|---|---|
| **Entry record** | Extend `EP-00-ENTRY-RECORD.md`; create new file in `EP-00/`; create new file under `EP-01/` | **Create new, under a new `EP-01/` folder** | The EP-00 record is a signed, phase-specific artifact; appending would make a closed governance record mutable and destroy its evidentiary value. The folder convention is explicitly designed to scale per phase. Same filename shape (`EP-01-ENTRY-RECORD.md`) keeps it discoverable. |
| **Record structure** | Invent a new layout; reuse EP-00-000 §6.2 | **Reuse the 11-section structure verbatim** | A second phase record is the moment the structure proves itself reusable. Deviating now would create two documentation languages. |
| **Decision register** | New register table; reuse owning registers | **Reference-only rows, naming the owning register** | `QUA-38`/`QUA-39` and EES §11.1 forbid a competing register. The record states outcome/evidence and the fold-in follow-up. |
| **Decision IDs** | New `D-01` scheme; reuse owning IDs | **Reuse owning IDs** (`#1`, `#17`, `#14`, `standards §16 #3`, `EES §11.2 #2`, `EP-01 §4.3-R1`, `EX-10`) | EP-00-000 §6.3 rule. A local row number is display-only. |
| **Blocker matrix** | 38 separate files; one table | **One derived table, no new plan** | EES §8.3/§8.5: per-package plans are not created; the matrix is a view over EP-01 §9. |
| **Template file** (`PHASE-ENTRY-RECORD-TEMPLATE.md`) | Create now; defer | **Do not create now** (recommended) | EP-00-000 deferred this to EP-01 "if a second record proves it worthwhile". It has, but creating docs tooling inside a gate-closure task adds a third artifact and diff surface for no gate benefit. Revisit at `070`, which is the third instance. *(Flagged as a decision in §21.)* |
| **Evidence location** | New root; reuse EP-00 root | **Reuse `Engineering-Phase-Records/EP-01/evidence/`** | Mirrors the existing phase-record convention. The pre-existing second root (`Engineering-Execution/evidence/`) is recorded as a finding for `070`, **not fixed here**. |
| **Verification tooling** | Write a docs linter | **Reuse existing controls only** | `pnpm security:secrets` is real and can fail. Markdown is outside `format:check` and `lint`'s target set (verified in the scripts). No new tooling. |
| **Decisions database** | Persist decisions in a schema | **Rejected** | No database exists; it would be a parallel register and pre-empt EP-01-021. |

**Why the new file is nevertheless necessary:** no existing artifact can hold a dated, signed, evidenced EP-01 opening decision without mutating a signed EP-00 record or creating a second register.

---

### 6. Recommended Technical Approach

#### 6.1 Artifacts

```text
documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md   ← the signed record
documents/Engineering-Execution/Engineering-Phase-Records/EP-01/evidence/              ← read-only transcripts
documents/Task-Implementation/EP-01/EP-01-001 — Entry gate closure and decision register.md  ← the G0 work-package record (this plan, approved)
```

Markdown, UTF-8, ISO-8601 dates, repo-relative links, no absolute paths, no token-bearing URLs. The G0 record carries the EES §8.2 fields (objective, class, scope, reuse check, test plan, evidence, AR-0 impact, rollback, approver); the entry record is the artifact.

#### 6.2 Verification method for EP-00 exit (the core of the task)

For each of C1–C14, the record states: criterion, **artifact inspected today**, result (`Met` / `Unmet` / `Partially met`), and the exact command or URL. Reuse the read-only set already established:

| Check | Command / source |
|---|---|
| History and tag | `git log --oneline -20`, `git rev-parse v0.0.1-bootstrap^{}`, `git show --stat` |
| CI green run | run URL recorded in `EP-00-010` §3; verify it exists and targets the stated SHA |
| Protection state | reproduce `GET /repos/.../branches/main/protection` → `403` and record the body; do **not** attempt to change it |
| Local compensating control | `.githooks/pre-push`, `scripts/pre-push.mjs`, `branch-guard.yml`, `BRANCH_PROTECTION.md` §8–§9 transcripts |
| Prototype integrity | `git diff v0.0.1-bootstrap..HEAD -- src/app/App.tsx` (must be empty) |
| Test/lint/scan | current `pnpm test`, `pnpm lint`, `pnpm security:secrets` output |
| G5 | `EP-00-011` §6 signature block — unsigned |

#### 6.3 Status logic (must be applied, not paraphrased)

| Condition | Result |
|---|---|
| G5 signed **and** C1–C14 all `Met`/accepted-and-recorded **and** `#1`,`#17`,`#14` recorded **and** second reviewer settled **and** §4.3 rulings recorded | EP-01 = `Ready` |
| Any one missing | EP-01 = `Blocked`, every missing item named with an owner |
| Local hook exists but host protection does not | **Does not satisfy C8.** It is a compensating control; only the founder can rule whether it is an accepted basis for entry, and that ruling is recorded, never assumed |
| Second reviewer absent or `DEV-001` expired | `Blocked` for every auth/capability/migration item, even if the phase opens |
| Record drafted with `PENDING` rows | Record status `In review`; phase stays `Blocked` |

Record status vocabulary is EES §9.1 only — no percentages, no "almost".

#### 6.4 Decision register — required rows

| Owning register ID | Decision | Class | Owner | Blocks |
|---|---|---|---|---|
| `ARCHITECTURE §16.4 #1` | Managed Postgres provider | `[FOUNDER]` | Founder + architect | `020`–`026`, `060`, `062` |
| `ARCHITECTURE §16.4 #17` | Hosting platform, DNS, TLS | `[FOUNDER]` | Founder + architect | `041`, `054`, `060`, `063` |
| `ARCHITECTURE §16.4 #14` | Sign-in identifier | `[FOUNDER]` | Founder | `031`, `032`, `053` |
| `EES §11.2 #2` / `DEV-001` | Second reviewer: appoint, or re-deviate with full GOV-13 fields, owner and expiry | `[FOUNDER]` | Founder + architect | `023`,`025`,`030`–`036` |
| EP-00 exit basis | Whether the C8 compensating control plus the recorded C10/C14 position is an accepted entry basis, or EP-00 must complete first | `[FOUNDER]` | Founder | The phase status itself |
| Phase opening | EP-01 opened for build | `[FOUNDER]` | Founder | Every item |
| `standards §16 #1` | Validation library (confirm zod) | `[REVIEW]` | Architect | `003`, `011` |
| `standards §16 #2` | API versioning | `[REVIEW]` | Architect | `011`, `013` |
| `standards §16 #3` | Session lifetimes per audience | `[FOUNDER]`+`[REVIEW]` | Founder + architect | `032` |
| `standards §16 #6` | CSP posture accepting `EX-02` | `[FOUNDER]`+`[REVIEW]` | Architect + founder | `041` |
| `standards §16 #8` | Secret manager and rotation | `[FOUNDER]`+`[REVIEW]` | Founder + architect | `020`, `043`, `060` |
| `standards §16 #9` | Error-tracking / APM vendor and PII posture | `[FOUNDER]` | Founder | `040` (the seam can ship with the no-op adapter) |
| `EX-10` residual | Test toolchain: Playwright, Testcontainers, Testing Library | `[REVIEW]` via `GOV-09` | Architect | `004`, `025`, `050`, `063` |
| `EP-01 §4.3-R1` | Four bundles, eight deployments | `[REVIEW]` | Architect | `002`, `054` |
| `EP-01 §4.3-R2` | Slice-only extraction | `[REVIEW]` | Architect | `050`–`053` |
| `EP-01-002/021` selections | DB driver, migration runner, queue, OpenAPI generator, boundary lint | `[REVIEW]` | Architect | `002`, `014`, `021` |

Class of the record overall: **`[FOUNDER]`** (`GOV-08`, highest engaged rule — it carries founder decisions and the phase-opening act).

#### 6.5 Two conflicts the record must state, not resolve

1. **Register fold-in vs. scope guard.** `QUA-38`/`QUA-39` require a settled decision to be folded into its owning register, but EP-01 §4.2 forbids editing `ARCHITECTURE.md`. Recommendation: the record names the follow-up, and the fold-in is performed by the architect/founder as a separate recorded act — the EP-00-000 precedent (`#18` → `§16.4 #25`). This is presented as a follow-up row, never silently executed by the implementing agent.
2. **Stale planning snapshot.** EP-01's opening verdict ("zero commits, no CI, no test runner…") is no longer true. The record carries a drift table (mirroring EP-00-000 §4.3). The plan itself is not edited.

---

### 7. Required Systems, Modules and Components

| Component | Role | New? |
|---|---|---|
| `Engineering-Phase-Records/EP-01/` | Discoverable location for EP-01 phase records | **New, minimal** (one directory) |
| `EP-01-ENTRY-RECORD.md` | The signed decision artifact | **New** |
| `evidence/` subtree | Read-only transcripts backing each verification row | **New, minimal** |
| `documents/Task-Implementation/EP-01/` + G0 record | Work-package record required by EES §8.2 | **New (this plan)** |
| `scripts/secret-scan.mjs`, CI jobs, `.githooks` | Reused verification and delivery controls | Existing |
| Owning decision registers | Referenced, never duplicated | Existing |

**No** runtime module, service, API, worker, database, schema, migration, queue, auth component, package or UI component is created or modified.

---

### 8. Data Requirements

The "data" is the record. Required fields per decision row: owning ID, decision text, owning register, class, owner (role, never "the agent"), date, outcome (`RECORDED` / `PENDING`), evidence, follow-up. Required fields per blocker row: item, status (EES §9.1 only), blockers, owner, clearing condition. Rules: no blank cells; every unresolved item visibly `PENDING` with an owner; every settled item cites an artifact; nothing stores a credential, token, connection string or customer personal data; the record is append-only after signature.

---

### 9. Database Considerations

**None.** No table, schema, migration, grant, RLS policy, role or provider is created or changed. The record must say so explicitly — it *authorises* database work but performs none — so a later reader does not infer a persistence layer was introduced.

---

### 10. API Requirements

**None.** No endpoint, contract, OpenAPI document or versioning act. The API-versioning decision (`standards §16 #2`) is *recorded as pending or decided*, never pre-empted.

---

### 11. UI Requirements

**None user-facing.** No screen, token, colour, type size or copy change. `src/app/App.tsx` must remain byte-identical (`git diff` empty) — a C11-relevant constraint for the phase.

---

### 12. UX Considerations (reader experience)

Consumers: founder, architect, reviewer, and every later work package that needs to know why it is blocked.

- Decision-first ordering: the reader sees what blocks the phase before the verification detail.
- Stable heading numbers and IDs so `EP-01-070` can deep-link to individual decisions and rows.
- Every assertion is a table row with an owner, date and artifact — no prose-only claims.
- Reviewable in one sitting; link to the phase plan instead of copying it.
- Four states only, clearly distinguished: **decided**, **pending**, **not applicable**, **deferred**. "Partially" appears only where a criterion genuinely is (C10).
- State the source-read date, so a future reader knows what was true at signature.

---

### 13. Security Considerations

| Concern | Control |
|---|---|
| Secrets in the record | No tokens, keys, passwords, connection strings, webhook URLs or `.env` content. Providers and settings may be named; credentials never. Proven by `pnpm security:secrets`, plus a seeded fixture to show the gate can fail. |
| Credential-bearing evidence | Settings exports redacted before being referenced; no token-bearing URL is copied. |
| Personal data | Only governance identities (approver names), never customer data. |
| Vendor data flow | If `#8`/`#9` name a vendor that receives personal data or source code, `TEC-12` applies: record data flow, region and retention before the vendor is treated as approved. |
| Integrity | Signature block, explicit approval scope, ISO dates, append-only amendment log. An unsigned or expired record is not evidence. |
| AI boundary | The agent may draft and verify; it may **not** sign, approve, settle a decision, change phase status, or act as second reviewer (`EES §5.6`, `AI-20`, `AI-21`). |
| Authority confusion | The record never implies it approves anything; it records approvals given elsewhere by named roles. |
| Gate integrity | `GOV-20`: no gate is bypassed. `GOV-21`: if a gate does not exist (C8), the record says so rather than implying protection. |
| Audit readiness | An AR-0 impact note (`standards §19.3`) is recorded because the record authorises identity, authentication and migration work. Requirement classes engaged are recorded as `R3`/`[OPEN]` — no legal or regulatory obligation is asserted. |
| Claim discipline | The record must not call anything secure, compliant, hardened or production-ready. It states what was verified and how. |

---

### 14. Performance Considerations

No runtime impact. The only cost is review latency: the record must be short enough to review honestly (`QUA-32`). Target: a one-page decision and blocker summary up front, with detail behind links; no duplication of the phase plan.

---

### 15. Testing Strategy

No code, so the tests are document gates — each must be able to fail.

| # | Test | Pass condition | Seeded-failure check |
|---|---|---|---|
| T1 | EP-00 exit coverage | C1–C14 all present, each with an inspected artifact or explicit unmet mark | Delete C8's row; the coverage check flags it |
| T2 | Evidence re-verification | Every "Met" cites a command output or URL reproduced today, not a summary | Downgrade a command output; the check fails |
| T3 | Decision completeness | All 16 required rows exist with ID, register, class, owner, date, status, evidence | Remove the `#17` row; completeness fails |
| T4 | No invented decision | Ruling text matches the supplied text; no `[OPEN]` row marked decided | Insert a plausible "Supabase chosen" default; review must reject it |
| T5 | Register non-duplication | Every row names an owning register; no new register is created | Add a standalone decision with no owner; check fails |
| T6 | Status honesty | `Ready` only when every §6.3 condition holds; otherwise `Blocked` with owners | Remove G5; status must become `Blocked` |
| T7 | Blocker coverage | All 38 remaining items appear with a status and at least one blocker or "none" | Delete one row; check fails |
| T8 | Drift accuracy | Read-only commands re-run on the signing date; drift from the plan's snapshot recorded | Change one fact silently; comparison fails |
| T9 | Scope discipline | Diff contains only the new EP-01 files; `App.tsx`, `documents/Context/*`, both phase plans and all config unchanged | Add an unrelated edit; diff check fails |
| T10 | Secret / PII scan | `pnpm security:secrets` exit 0; no credential pattern, token URL or customer data | Insert a fake key on a scratch branch; the gate must fail, then remove it |
| T11 | Independent approval | Author ≠ approver; the agent is not an approver; roles and dates named | Self-approval must be rejected by the signature check |
| T12 | Link integrity | Every relative link resolves inside the repo; no absolute path | Break a link; check fails |
| T13 | Markdown integrity | Tables render, headings numbered and stable, no truncation | Remove a table separator; rendering check fails |
| T14 | CI parity | PR green on the six existing jobs; nothing newly excluded | Push with a lint/type error on a scratch branch; the pipeline blocks |

**Evidence produced:** the signed record, the architect's review note, the founder's signature block, `git` transcripts (log, tag, empty `App.tsx` diff), the reproduced `403`, CI run URLs, and the secret-scan output. At least three gates are demonstrated failing before passing.

---

### 16. Recommended Implementation Sequence

| Step | Work | Owner | Gate |
|---|---|---|---|
| 0 | Confirm EP-01-001 is doc-only and does not need Postgres, hosting or a toolchain change | Developer | Pre-check |
| 1 | Build the authority index (paths, versions, sections) | Agent | — |
| 2 | Re-verify EP-00 C1–C14 with read-only commands; capture transcripts into `evidence/` | Agent | — |
| 3 | Collect the founder decisions (`#1`,`#17`,`#14`, second reviewer, EP-00 entry basis), the architect decisions and the §4.3 rulings **in writing** | Founder / architect | **Hard stop if absent** |
| 4 | Draft the record from supplied text only; every missing item `PENDING` with an owner; apply §6.3 status logic | Agent | — |
| 5 | Run T1–T14, including the seeded failures | Agent | Self-check |
| 6 | Commit on `docs/ep-01-001-entry-record`, open a PR into `staging` (local hook and `verify-pr` guard in force) | Developer | CI green |
| 7 | Architect review for fidelity, completeness, class and scope | Architect | `[REVIEW]` |
| 8 | Founder signs the decisions and the phase status | Founder | `[FOUNDER]` |
| 9 | Finalise the record and the amendment log; promote `staging` → `main` by PR | Developer | `G2` |
| 10 | Hand off: `002` starts only if the record says `Ready` for that item's dependencies | Developer | — |

Critical path: `1 → 2 → 3 → 4 → 5 → 6 → 7 → 8`. Step 3 is human and cannot be compressed or delegated.

**Stop conditions:** if the three entry decisions or the second-reviewer arrangement are not supplied, stop at step 3 — do not choose a default and do not mark EP-01 `Ready`. If a document conflict is found, record it and stop (`GOV-05`).

---

### 17. Expected Outcome

One signed `EP-01-ENTRY-RECORD.md` that:

- proves, criterion by criterion, what EP-00 did and did not evidence on a stated date;
- records all 16 decisions by reference, with owner, class, date, evidence and fold-in follow-up;
- records the two G0 scope rulings;
- lists all 38 EP-01 items with status, blockers, owner and clearing condition;
- sets EP-01 to `Ready` or `Blocked` — nothing in between — with named owners for every gap;
- creates no code, schema, API, UI, or parallel register;
- is structured so `EP-01-070`, `EP-01-072` and later phases can reuse it.

On today's evidence the outcome is `Blocked`, with EP-00's G5, C8 and C14 named as founder acts and the architect's seven decisions named as `[REVIEW]` items.

---

### 18. Definition of Done

- [ ] The EP-01 record exists at the approved path; no other file changed except the G0 record and the new evidence files.
- [ ] `git diff v0.0.1-bootstrap..HEAD -- src/app/App.tsx` is empty; `documents/Context/*`, both phase plans, `package.json`, the lockfile and CI config are unchanged.
- [ ] All 11 sections and all decision-row fields from §6.2–§6.4 are present.
- [ ] C1–C14 are each marked `Met` / `Unmet` / `Partially met` with an artifact inspected today.
- [ ] All 16 decision rows exist; none is invented; each names its owning register.
- [ ] Both §4.3 rulings are recorded verbatim, or marked `PENDING` with the architect named.
- [ ] All 38 remaining items appear with a status and a named blocker or "none".
- [ ] Phase status is exactly `Ready` or `Blocked`, justified by the §6.3 checklist.
- [ ] No `[OPEN]` decision is silently resolved; no provider, vendor, library, lifetime or runner is chosen beyond what was ruled.
- [ ] `DEV-001`'s expiry is tested against the current date; the arrangement for EP-01 is recorded as appointment or full GOV-13 re-deviation.
- [ ] The C8 compensating control is described as a compensating control, never as protection.
- [ ] T1–T14 pass, with at least three seeded failures demonstrated.
- [ ] `pnpm security:secrets` exit 0; no secret, credential, token URL or customer data appears.
- [ ] Author ≠ approver; the agent is not an approver; roles and dates recorded.
- [ ] PR green on all six CI jobs; merged through `feature → staging → main`.
- [ ] EP-01 completion criterion **C1** gains a linkable artifact, and `EP-01-070` is handed a record it can index.

---

### 19. Implementation AI Execution Profile

| Field | Recommendation |
|---|---|
| **Recommended coding reasoning level** | **Low** |
| **Justification** | The task writes governance Markdown and runs read-only checks. There is no algorithm, no schema, no API, no trust boundary to implement and no performance surface. The dominant risk is **fidelity and completeness** — transcribing rulings exactly, refusing to invent a decision, applying a deterministic checklist — which is controlled by the fixed section structure, T1–T14, architect review and founder signature, not by reasoning depth. This matches the approved EP-01 plan's own profile (`Planning — Very High · Coding — Low`). A higher coding tier would add cost without adding a control. Note the *planning* tier for this task was Very High, and it was earned: the interaction between EP-00's unmet G5, `DEV-001`'s expiry and the register-ownership rule is where the real judgement sits. |

---

### 20. Platform Integration

There is no domain, service or schema integration, because nothing is built. Integration is at the governance layer, and it must be explicit:

- The record becomes the single referenced source for **why each EP-01 item is blocked**, so no work package re-litigates its blockers.
- Decisions stay in their owning registers (`ARCHITECTURE §16.4`, `standards §16`, EES §11.2) with a recorded fold-in follow-up — no divergence between the record and the register.
- The record defines the identity/session/capability/audit work that `030`–`036` inherit, without pre-empting any later-phase semantic (no KYC, verification or financial default is set).
- The structure is the second instance of the phase-record convention, so `EP-01-070`, `EP-01-072` and EP-02..08 reuse it rather than inventing one.

---

### 21. Decisions Needed Before Implementation

1. **EP-00 is not exited.** Confirm the handling: **(a, recommended)** draft the record now in `Blocked` form with `PENDING` rows and named owners — the EP-00-000 precedent, which required explicit approval; or **(b)** wait until G5 is signed and draft only then. Note the EP-00-000 plan originally said "do not draft a speculative record", so (a) needs your explicit approval.
2. **Artifact path** — approve `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` and the `EP-01/evidence/` subtree.
3. **Class** — confirm `[FOUNDER]` for the record.
4. **Template file** — confirm we do **not** create `PHASE-ENTRY-RECORD-TEMPLATE.md` now (recommended), deferring it to `070`.
5. **Register fold-in** — confirm the architect/founder performs the `ARCHITECTURE §16.4` / `standards §16` fold-in as a separate act, since EP-01 §4.2 forbids the implementing agent from editing those files.
6. **C8 basis** — confirm whether the local hook + CI `verify-pr` guard is offered to the founder as an accepted entry basis, or whether EP-01 stays `Blocked` until host protection exists.
