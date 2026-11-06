# Task Implementation Plan — EP-00-000
## Phase entry record, G0 rulings and decision closure

> Note: the instruction referenced `@AGENT.md`; the approved file in this repository is `documents/Context/AGENTS.md` (the root `AGENTS.md` is only a pointer). I followed the approved file.

---

### 0. Verified starting position (inspected today)

| Fact | Verified state |
|---|---|
| Git | `.git` exists, branch `main`, **zero commits**, no remote |
| Working tree | 19 untracked top-level entries, no tracked files |
| Toolchain | `node`, `pnpm`, `npm`, `mise` **absent** from `PATH`; `git` present |
| CI | No `.github/`, no pipeline, no lint/test configuration |
| Tests | Zero test files; no test runner |
| Governance records | No `documents/Engineering-Execution/Engineering-Phase-Records/` directory exists |
| Phase status | EP-00 is `Ready` (not opened); EP-00-000 is `Not started` |
| Approved sources | EES v2.0, Standards v2.0, Architecture, AGENTS.md, database rules, matrix, roadmap — all readable |

**Consequence:** EP-00-000 is documentation-only and can be executed without a toolchain. R1 (no Node/pnpm) blocks `EP-00-001` and `EP-00-002`, not `000`. This distinction must be stated in the record so the phase is not blocked for the wrong reason.

---

### 1. Task Objective

Produce a single, signed **phase entry record** for EP-00 that:

1. Verifies and records the true starting position on the date of signing.
2. Records every decision EP-00 depends on, with owner, date, status and evidence:
   - founder decision **#18** — repository hosting and CI provider;
   - the **four G0 rulings** in EP-00 §4.3 (one already ruled; three pending);
   - the **second-reviewer arrangement** (EES §11.2 #2 / risk R6);
   - the phase-opening act itself.
3. Records, for each item `EP-00-001`–`EP-00-011`, its current status and its named blockers with owners.
4. Sets EP-00 to exactly one status — **`In build`** or **`Blocked`** — with named owners, "nothing in between".
5. Does so without resolving any `[OPEN]` decision, inventing a ruling, or creating a parallel decision register.

---

### 2. Business Problem Being Solved

The v1 failure mode was that progress was asserted instead of evidenced (EES §2.2, §9.3, §12). EP-00 is the first phase that must produce inspectable artifacts, and it fails by being *declared* done. Before any repository, toolchain or CI work begins, the phase needs a record that:

- proves the entry gate was actually met;
- proves every blocking decision is either settled or explicitly blocking with an owner;
- prevents work from starting on an unresolved decision (EES §8.5);
- gives the founder a single signature that opens the phase on a known basis.

Without EP-00-000, `EP-00-001` and later items would begin against assumptions — the exact defect EP-00 exists to eliminate.

---

### 3. Scope

#### 3.1 In scope

A single new governance artifact containing:

| # | Content |
|---|---|
| 1 | Record identity: `EP-00-000`, phase, class, status, date, author, approvers |
| 2 | Authority basis: exact document paths, versions/dates, and the sections the record relies on |
| 3 | Entry-gate verification against EP-00 §1 |
| 4 | Re-verified starting position, with the date and the read-only commands used |
| 5 | Decision closure register — **reference-only rows** pointing at the owning register, plus the ruling text and evidence |
| 6 | The four G0 rulings, recorded verbatim as ruled (no paraphrase that changes meaning) |
| 7 | Founder decision #18 with its required content: host, CI service, repository visibility, protection mechanism, native scanning features, environment definitions (`staging`, `production` as definitions only), exit path |
| 8 | Second-reviewer arrangement: appointment **or** a GOV-13-compliant time-boxed deviation with compensating controls |
| 9 | Blocker matrix for `EP-00-001`–`EP-00-011`: item, status, blockers, owner, clearing condition |
| 10 | Phase status determination and the checklist that justifies `In build` vs `Blocked` |
| 11 | Residual risks and carried conditions, including follow-ups to fold settled decisions into their owning register |
| 12 | Signature block and amendment log |

Also in scope: creating the directory that holds phase-level records, so the artifact is discoverable and future phases can follow the same convention.

#### 3.2 Out of scope — EP-00-000 must not do these

- Any production code, configuration, dependency, script, test, schema, migration, API or UI.
- Any edit to `src/app/App.tsx` or the prototype.
- Any edit to `documents/Context/*` (AGENTS, ARCHITECTURE, standards, matrix, database rules, visual identity).
- Any edit to the approved EP-00 or EP-01 phase plans.
- Creating the remote repository, enabling protection, creating CI, enabling scanners, or choosing the CI provider (that is the founder's decision; execution is `EP-00-005`+).
- Provisioning Node/pnpm/mise (`EP-00-002` prerequisite / R1).
- Selecting Vitest, a linter, a rule set or a dependency (`EP-00-003` / `EP-00-004`).
- Building the evidence index (`EP-00-010`) or the G5 closure record (`EP-00-011`).
- Creating a per-work-package plan file for `EP-00-001` (already elaborated in the EP-00 plan §9).
- Creating a second decision register or a second deviations register.
- Committing or pushing (the first commit belongs to `EP-00-001`).
- Signing, approving or deciding anything on behalf of the founder, architect or reviewer.

---

### 4. Existing Asset and Dependency Analysis

#### 4.1 Assets inspected

| Asset | Path | What it gives EP-00-000 | Reuse decision |
|---|---|---|---|
| Engineering Execution Structure | `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` §5, §7, §8, §9, §11 | G0/G5 definitions, required work-package fields, status vocabulary, evidence rule, role boundaries, open decisions | **Reuse as authority**; do not restate |
| EP-00 phase plan | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-00 — Execution Readiness.md` §1, §4.3, §6, §7, §9, §11, §13 | Task definition, rulings, blockers, completion criteria C1, verified starting position | **Reuse as the source of truth**; do not modify, do not duplicate |
| EP-01 phase plan | `.../EP-01 — Core Platform Foundation & Infrastructure.md` | Proof of the `EP-` identifier convention and of how a phase plan handles G0 interpretations | **Reuse as pattern only**; no EP-01 work |
| Engineering standards | `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` GOV-05, GOV-08–GOV-19, QUA-29–QUA-37, TEC-12, §12, §13.3, §16 | Change classes, deviations, evidence, review rules, AI limits, accepted exceptions, open decision #18 | **Reuse as authority**; deviations stay in §13.3 |
| Architecture | `documents/Context/ARCHITECTURE.md` §2.3, §2.5, §11.6, §12.1–§12.8, §15.5, §16.3 #6/#8, §16.4 | Provider dependency, branch model, CI expectations, protection recommendation, consolidated open-decision register | **Reuse as authority**; do not create a second register |
| AI directive | `documents/Context/AGENTS.md` §1, §3, §7 | Bounded scope, reuse-first, AI limits, no prototype edits | **Reuse as authority** |
| Database rules / matrix / roadmap | `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md`, permission matrix, `Business-Development-Roadmap.md` §14 | Confirm they are **not engaged** by this task; roadmap Phase 0 context | **Reference only** |
| Repository state | `.git`, `package.json`, `.mise.toml`, `.gitignore`, `.gitattributes`, `pnpm-workspace.yaml`, `pnpm-lock.yaml` | Facts for the starting-position section | **Inspect only**; no edits |
| Figma Make wrappers | `.figma/make/install`, `deploy`, `dev`, `format` | Not a project pipeline; not governance | **Rejected for reuse** |
| Governance records | none exist | — | Genuine gap (see §5) |

#### 4.2 Dependencies

| Dependency | Type | Blocks |
|---|---|---|
| Founder opens EP-00 | Human act | The record's final status; cannot be delegated to an agent |
| Founder decision #18 | `[FOUNDER]` | `EP-00-005`–`008`; therefore the record's "unblocked" determination |
| Architect/founder rulings on EP-00 §4.3 items 1–3 | `[REVIEW]` / `[FOUNDER]` where scope changes | `EP-00-000` closure; every later item |
| Second-reviewer arrangement | `[FOUNDER]` / `[REVIEW]` | `EP-00-007`, and later authentication/capability work |
| Toolchain provisioning (R1) | External prerequisite | `EP-00-001`+, **not** `000` |
| Approved documents remain authoritative | Constraint | Any conflict must be recorded, not resolved (GOV-05) |

---

### 5. Reuse / Extension / Refactoring Assessment

| Proposed asset | Options considered | Decision | Justification |
|---|---|---|---|
| **Phase entry record** | Reuse EP-00 plan; extend it; create new | **Create new** | The EP-00 plan is an approved planning artifact and the task rules forbid modifying it. It has no signature block, no dated re-verification, and no place for decision evidence. Appending would also make the plan mutable and destroy the planning record. |
| **Record location convention** | Put at repo root; put in `documents/Context/`; put under `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/` | **Create new, under Engineering-Execution** | `documents/Context/` holds approved governing documents and must not be touched. A sibling of `Engineering-Phase-Plan` keeps planning, execution and records distinct. Per-phase subfolders scale to later phases. |
| **Decision closure table** | New register; reuse existing registers | **Reuse existing registers by reference** | `ARCHITECTURE.md` §16.4 is the single consolidated register and standards §16 adds only what is new (QUA-39). The record may state a decision's outcome and evidence, but must name the owning register and the follow-up that folds it in. It must not become a competing source of truth. |
| **G0 rulings** | New rulings file; record in entry record | **Record in the entry record** | The rulings are phase-scope interpretations, not reusable standards. They must live with the phase record, not in `documents/Context/`. |
| **Blocker matrix** | Per-package files; one table | **Reuse EP-00 §9 item list; one table** | EP-00 §9 explicitly keeps one plan and no parallel per-package files. The matrix is a derived view, not a new plan. |
| **Deviation record** | New file | **Reuse standards §13.3** | GOV-15 forbids deviations living anywhere else. The entry record cites the deviation ID; it does not host it. |
| **Evidence index** | Build early | **Defer to EP-00-010** | Building it now would duplicate `010` and exceed this task's scope. The entry record carries only its own evidence pointers. |
| **Template file** | Create `PHASE-ENTRY-RECORD-TEMPLATE.md` | **Do not create now** | Bounded scope. The record's fixed heading structure is the convention; extraction into a template is EP-01+ work if a second phase record proves it worthwhile. |
| **Tooling** | Add a docs linter / link checker | **Not added** | No linter exists yet (`EP-00-004`), and adding tooling here would be a dependency change outside scope. Verification is a manual checklist plus read-only commands. |
| **Decision database / table** | Persist decisions in a schema | **Rejected** | No database exists; creating one would be a parallel register and would pre-empt EP-01. |

**Why the new asset is necessary:** no existing artifact can hold a dated, signed, evidenced phase-opening decision without either mutating an approved document or creating a second register. The new asset is deliberately limited to one file plus its directory, and its structure is designed to be reused by EP-01 and later phases.

**Reuse design of the new asset:** stable section headings, reference-only decision rows, explicit owner/date/status fields, relative links, and no phase-specific assumptions outside the EP-00 sections. A future phase can copy the structure without copying EP-00 content.

---

### 6. Recommended Technical Approach

#### 6.1 Artifact

Create exactly one file:

```text
documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md
```

- Markdown, UTF-8, ISO-8601 dates (`2026-11-04`), repo-relative links.
- Document ID: `EP-00-000`.
- No absolute Windows paths, no external secrets, no token-bearing URLs.
- The directory is created only to hold the record; no README, index or template in this task.

#### 6.2 Record structure (fixed, reusable)

| Section | Required content |
|---|---|
| **1. Identity** | Record ID, phase, task name, class, status, author role, approver roles, date |
| **2. Authority basis** | Documents, versions, approval dates and the exact sections relied on |
| **3. Entry-gate verification** | EP-00 §1 entry gate; met/not met; what evidence supports it |
| **4. Verified starting position** | Date, commands run, outputs summarised, drift from EP-00 §9's 4 Nov 2026 snapshot |
| **5. Decision closure** | One row per decision: ID, decision, owning register, ruling/outcome, decided by (role), date, class, evidence, follow-up |
| **6. G0 rulings** | The four §4.3 rulings, verbatim, with the already-ruled item marked as historical |
| **7. Second reviewer** | Appointment or GOV-13 deviation; scope; compensating controls; expiry; G4 exclusion |
| **8. Item blocker matrix** | `EP-00-001`–`011`: status, blockers, owner, clearing condition |
| **9. Phase status determination** | The checklist and the resulting single status |
| **10. Residual risks and carried conditions** | What EP-01 inherits; register follow-ups; unresolved conflicts |
| **11. Signature and amendment log** | Role, name, date, scope of approval; append-only amendments |

#### 6.3 Decision row format

| Field | Rule |
|---|---|
| Decision ID | Reuse the owning register's identifier (`#18`, `§4.3-1`, etc.); do not invent a new global ID scheme |
| Owning register | `standards §16 #18`, `EP-00 §4.3`, `EES §11.2 #2`, etc. |
| Ruling / outcome | Verbatim or a faithful, minimal transcription; never a paraphrase that changes scope |
| Decided by | Role, never "the agent" |
| Date | ISO-8601 |
| Class | Per GOV-09 |
| Evidence | Link or artifact reference; settings export, written approval, or recorded transcript |
| Follow-up | Where the settled decision must be folded into its owning register, with owner and target |

#### 6.4 Decision content the record must carry (no pre-emption)

1. **#18 — repository hosting and CI provider.** Record the founder's decision only. If not decided, row = `PENDING — owner: Founder`, and the phase is `Blocked`.
2. **Ruling 1 — local-run scope.** Record the ruling on whether EP-00 delivers only the verified bootstrap for existing components and explicitly reassigns Postgres/API/worker to EP-01.
3. **Ruling 2 — `EX-10`.** Record whether it closes at EP-00 or is partially closed with Playwright/Testcontainers/component DOM named as EP-01 work against the same row.
4. **Ruling 3 — linter.** Record that a real linter is the gate and `oxfmt` remains the formatter, with the linter choice deferred to `EP-00-004` as a `[REVIEW]` decision. The record must **not** name a linter.
5. **Ruling 4 — identifier convention.** Already ruled 4 Nov 2026 (`EP-` prefix; EES §8.1 amended). Record as historical, not re-opened.
6. **Second reviewer.** Appointment or deviation. If a deviation, it needs all GOV-13 fields and must state it does not extend to G4.
7. **Phase opening.** The founder's signature is the opening act. Until signed, the phase remains `Ready`; the record must not claim `In build`.

#### 6.5 Status logic

The record must apply this gate explicitly:

| Condition | Result |
|---|---|
| Founder opens the phase **and** #18 recorded **and** all three rulings recorded **and** second-reviewer arrangement recorded | `In build` |
| Any one missing | `Blocked`, with each missing item named and its owner |
| No toolchain | Does **not** block `EP-00-000`; it blocks `EP-00-001`+ and must be listed there |

For the record's own status: `Not started` → `In review` when drafted → `Verified` when reviewed and signed. Do not use "Completed" or a percentage; the EES vocabulary has no such values.

#### 6.6 Approval flow

1. Agent/developer drafts the record from supplied decision text only.
2. Architect reviews for fidelity, completeness and absence of scope expansion (`[REVIEW]`).
3. Founder signs #18, the rulings, the second-reviewer arrangement and the phase-opening line (`[FOUNDER]`).
4. The record is finalised; no silent edits afterwards — corrections go in the amendment log.
5. `EP-00-001` includes the record in the first commit so provenance attaches. Until then, the signed document itself is the evidence.

**Recommended class:** `[FOUNDER]`, because the record carries a phase-scope change (ruling 1, EES §5.2) and the #18 provider decision, and GOV-08 requires the highest engaged class. If the founder rules that ruling 1 changes no scope, the class could be `[REVIEW]`; the record must state the class it was reviewed under.

---

### 7. Required Systems, Modules, and Components

| Component | Role | New? |
|---|---|---|
| Git working tree | Holds the record until `EP-00-001` commits it | Existing |
| `Engineering-Phase-Records/EP-00/` directory | Discoverable location for phase records | **New, minimal** |
| `EP-00-ENTRY-RECORD.md` | The signed record | **New** |
| Read-only verification commands (`git status`, `git log`, `Get-Command`/`command -v`) | Starting-position evidence | Existing tools |
| Existing decision registers | Referenced, not duplicated | Existing |

**No** runtime module, service, API, worker, database, schema, migration, queue, container, auth component or UI component is created or modified.

---

### 8. Data Requirements

The "data" is the decision record itself. Required fields per decision and per blocker are defined in §6.2–§6.3. Additional requirements:

- Every row has an owner and a date.
- Every unresolved item is visibly `PENDING` with an owner — never blank.
- Every settled item cites evidence.
- No field stores a credential, token, connection string or personal data.
- The record is append-only after signature.

---

### 9. Database Considerations

**None.** No table, schema, migration, grant, RLS policy, Supabase project or data API is created or changed. A decisions table is explicitly rejected: it would be a second register, and no database exists in EP-00. The record must state this so a later reader does not assume a persistence layer was introduced.

---

### 10. API Requirements

**None.** No endpoint, contract, OpenAPI document or versioning decision. The record must not pre-empt the API versioning decision (standards §16 #2). It records only that EP-00 has no API surface.

---

### 11. User Interface Requirements

**None user-facing.** No screen, token, colour, type size or copy change. `src/app/App.tsx` must remain byte-identical, and `documents/Context/*` unmodified. This is a C12-relevant constraint for the phase.

---

### 12. User Experience Considerations (reader experience)

The consumers are the founder, architect, reviewer and future contributors.

- Decision-first ordering: the reader must see what is blocking the phase before reading the starting-position detail.
- Stable headings and IDs so later records and the evidence index can link to individual decisions.
- No prose-only claims: every assertion is a table row with an owner, date and evidence.
- Keep the record reviewable in one sitting; link to the phase plan instead of copying it.
- Distinguish clearly: **decided**, **pending**, **not applicable**, **deferred**. Do not use "partially" except where the approved `EX-10` ruling explicitly requires it.
- Record the reading date of each source so a future reader knows what was true when the record was signed.

---

### 13. Security Considerations

| Concern | Control |
|---|---|
| Secrets in the record | No tokens, keys, passwords, connection strings, webhook URLs or `.env` content. The #18 row names providers and settings, never credentials. |
| Credential-bearing evidence | Settings exports are redacted before being referenced; never paste a URL containing a token. |
| Personal data | None expected; if a person's name is used as an approver, that is a governance identity, not customer data. |
| Vendor decision | If #18 implies a third-party scanner that receives source code, it is a data-receiving vendor and requires TEC-12 founder approval with data flow, region and retention. Native scanning is preferred (R9). The record must not treat a vendor as approved because the host was chosen. |
| Integrity | Signature block, approval scope, date and append-only amendment log. An unsigned or expired record is not evidence. |
| AI boundary | An agent may draft and verify; it may not sign, approve, decide #18, change the phase status, or act as second reviewer (EES §5.6, AI-20). |
| Authority confusion | The record must never imply it approves anything. It records approvals given elsewhere and by named roles. |
| Leakage through screenshots | Avoid screenshots; use text exports with secrets removed. |
| Supply chain | No dependency, lockfile or toolchain change in this task. |

---

### 14. Performance Considerations

No runtime impact. The only performance concern is review latency: the record must be short enough to review honestly (QUA-32) and must not duplicate the phase plan. Target: a decision summary the founder can act on without re-reading the whole plan, with links to the authoritative sections.

---

### 15. Testing Strategy

There is no code, so "tests" are document verification gates. Each must be capable of failing.

| # | Test | Pass condition | Seeded-failure check |
|---|---|---|---|
| **T1** | Completeness against EES §8.2 and EP-00 §9 | Every required field and every expected-outcome element is present | Remove one field; the checklist must flag it |
| **T2** | Decision traceability | Every decision has ID, owning register, decided-by, date, class, evidence or explicit `PENDING` | Remove an owner; the check fails |
| **T3** | No invented decision | Ruling text matches the supplied ruling; no `[OPEN]` item is marked decided | Insert a plausible default; review must reject it |
| **T4** | Blocker coverage | All `EP-00-001`–`011` appear with a status and at least one blocker or "none" | Delete a row; the check fails |
| **T5** | Starting-position accuracy | Read-only commands re-run on the signing date; drift from EP-00 §9 recorded, not ignored | Change one fact silently; the comparison fails |
| **T6** | Scope discipline | Diff contains only the new record file and its directory; `App.tsx` and `documents/Context/*` unchanged | Add an unrelated edit; the diff check fails |
| **T7** | Secret/PII scan | No credential pattern, token-bearing URL, `.env` content or personal data | Insert a fake key; the scan must flag it, then remove it |
| **T8** | Status honesty | `In build` only when all four opening conditions hold; otherwise `Blocked` | Remove #18; status must become `Blocked` |
| **T9** | Independent approval | Author ≠ approver; agent is not an approver; roles named | Self-approval must be rejected by the signature check |
| **T10** | Register non-duplication | Every decision row names an owning register; no new register is created | Add a standalone decision with no owner; the check fails |
| **T11** | Link integrity | Every relative link resolves inside the repo; no absolute path | Break a link; the check fails |
| **T12** | Markdown integrity | Tables render; headings stable; no truncation | Remove a table separator; rendering check fails |

Evidence for this task: the reviewed record, the architect's review note, the founder's signature block, and the read-only command output recorded in §4 of the record. No CI run exists at this point, and the record must say so rather than imply otherwise.

---

### 16. Recommended Implementation Sequence

| Step | Work | Owner | Gate |
|---|---|---|---|
| **0** | Confirm EP-00 is `Ready` and that `000` is doc-only (toolchain not required) | Agent/developer | Pre-check |
| **1** | Collect the authority index: document paths, versions, sections | Agent/developer | — |
| **2** | Re-verify the starting position with read-only commands; record date and outputs | Agent/developer | — |
| **3** | Obtain the three rulings, #18, and the second-reviewer arrangement **in writing** from the founder/architect | Founder/architect | **Hard stop if absent** |
| **4** | Draft the record from the supplied text only; mark every missing item `PENDING` with an owner | Agent/developer | — |
| **5** | Run T1–T12, including at least one seeded failure | Agent/developer | Self-check |
| **6** | Architect review for fidelity, completeness, class and scope | Architect | `[REVIEW]` |
| **7** | Founder signs #18, rulings, second-reviewer arrangement and phase opening | Founder | `[FOUNDER]` |
| **8** | Finalise status (`In build` or `Blocked`) and the amendment log | Agent/developer records; founder's signature authorises | — |
| **9** | Hand off to `EP-00-001`; the record enters the first commit | Developer | Provenance attaches |

**Critical path:** `1 → 2 → 3 → 4 → 5 → 6 → 7 → 9`. Step 3 is human and cannot be compressed by the agent.

**Stop conditions:** If #18 or any ruling is not provided, stop at step 3. Do not draft a speculative record, do not choose a default, and do not mark the phase `In build`. If a document conflict is found, record it and stop rather than resolving it (GOV-05).

---

### 17. Expected Outcome

A single signed `EP-00-ENTRY-RECORD.md` that:

- proves the entry gate and the starting position on a stated date;
- records #18, the four G0 rulings, the second-reviewer arrangement and the phase opening, each with owner, date, class and evidence;
- lists every EP-00 item's blockers with owners;
- sets EP-00 to `In build` or `Blocked` — nothing in between;
- creates no code, no schema, no API, no UI and no parallel register;
- is structured so EP-01 and later phases can reuse the pattern.

---

### 18. Definition of Done

- [ ] Exactly one new file exists: `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md`.
- [ ] No other file changed; `git status` shows no edits to `src/app/App.tsx`, `documents/Context/*`, the phase plans, `package.json`, the lockfile or any config.
- [ ] The record contains all sections in §6.2 and all fields in §6.3.
- [ ] All four G0 rulings are present; the already-ruled one is marked historical and not re-opened.
- [ ] #18 is recorded with host, CI service, visibility, protection mechanism, scanning features, environment definitions and exit path — or is `PENDING` with the founder named.
- [ ] The second-reviewer arrangement is recorded as an appointment or a GOV-13-compliant deviation with expiry and no G4 extension.
- [ ] Every `EP-00-001`–`011` item has a status and a named blocker or "none".
- [ ] Phase status is exactly `In build` or `Blocked`, justified by the checklist.
- [ ] No `[OPEN]` decision is silently resolved; no default is chosen; no linter, test runner or provider is selected beyond what is ruled.
- [ ] No decision register is duplicated; every row names its owning register.
- [ ] No secret, credential, token-bearing URL or personal data appears.
- [ ] T1–T12 pass, including at least one seeded failure.
- [ ] Author ≠ approver; the agent is not an approver; approver roles and dates are recorded.
- [ ] The record is included in `EP-00-001`'s first commit, and the handoff is stated.
- [ ] EP-00 completion criterion **C1** is satisfied by this record, with the record itself as the linked artifact.

---

### 19. Implementation AI Execution Profile

| Field | Recommendation |
|---|---|
| **Recommended coding reasoning level** | **Low** |
| **Justification** | This task writes one governance document and runs read-only checks. It has no algorithmic complexity, no schema, no API, no security boundary to implement and no performance surface. The dominant risk is **fidelity and completeness**, not reasoning depth: the agent must transcribe rulings exactly, refuse to invent decisions, and apply a deterministic checklist. That risk is controlled by the fixed record structure, the T1–T12 gates, architect review and founder signature — not by a higher reasoning tier. The approved EP-00 plan itself specifies `Planning — Very High · Coding — Low`, and this profile follows it. A higher coding level would add cost without adding a control. |

---

### 20. Decisions Needed Before Implementation

These are the only points where I would proceed differently depending on your answer:

1. **Record location** — approve `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` as the convention.
2. **Class** — confirm `[FOUNDER]` for the record (because of the phase-scope ruling and #18), or confirm `[REVIEW]` if the scope ruling is treated as non-changing.
3. **Template** — confirm we create only the record now, not a reusable template file.
4. **Decision inputs** — the three rulings, #18 and the second-reviewer arrangement must come from the founder/architect. I cannot supply them, and the plan deliberately does not pre-fill them.
