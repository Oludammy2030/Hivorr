# Task Definition of Done — EP-01-001
## Entry gate closure and decision register

| Field | Value |
|---|---|
| **Task ID** | `EP-01-001` |
| **Task Name** | Entry gate closure and decision register |
| **Related Phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-001 — Entry gate closure and decision register.md` |
| **Artifact under verification** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` |
| **Supporting evidence** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/evidence/` |
| **Verification owner** | Project lead, with architect review and founder signature |
| **Verification date** | ______________ |
| **Overall result** | ☐ Pass  ☐ Pass with recorded exception  ☐ Fail |

**Verification boundary.** This DoD verifies only the EP-01 entry record produced by `EP-01-001`, its evidence folder, and the G0 work-package record. It does **not** verify any later EP-01 item (`002`–`072`), any database, API, worker, frontend bundle, staging environment or CI change. Those remain `Not started` or `Blocked` exactly as the record's blocker matrix states.

**Pre-condition for the verifier.** Read `EP-01-001` §6.3 before starting. The record may legitimately end at either `Ready` or `Blocked`; this DoD verifies that the correct one was chosen **from the evidence**, not that a particular outcome was reached.

---

## 1. Functional Verification

### 1.1 Required functionality

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **F-01** | Record exists at the exact approved path | `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` exists and opens | File path + open file |
| **F-02** | Record identity is complete | Document ID `EP-01-001`; phase `EP-01`; task name matches the approved plan; class, status, author role, approver roles and dates present | Record §1 |
| **F-03** | Authority basis is explicit | Names the approved documents with versions/dates and the sections relied on: EP-01 plan §1/§4.2/§4.3/§5.2/§7/§9/§11/§13; `EP-00-ENTRY-RECORD.md`; `EP-00-010`; `EP-00-011`; `BRANCH_PROTECTION.md` §5/§6/§8/§9; `ARCHITECTURE.md` §16.3/§16.4 `#1`,`#14`,`#17`,`#25`; Standards §1.4/§13.2/§13.3 (`EX-02`,`EX-10`,`DEV-001`)/§16 `#1`,`#2`,`#3`,`#6`,`#8`,`#9`/§19.3; EES §5.2/§5.6/§7.1/§7.3/§8.2/§9.1–§9.3/§11.2 | Record §2 |
| **F-04** | EP-00 exit is verified, not assumed | All of C1–C14 appear, each with: criterion text, the artifact **inspected today**, a result (`Met` / `Unmet` / `Partially met`), and the exact command output or URL | Record §3 + transcripts in `evidence/` |
| **F-05** | G5 state is recorded truthfully | C14 is marked `Unmet` unless a signed founder closure exists in `EP-00-011` §6; the unsigned state is named, not implied | Record §3 + `EP-00-011` §6 |
| **F-06** | C8 is stated correctly | Host protection is `Unmet`; the local pre-push hook and CI `verify-pr` guard are described as a **compensating control**, never as protection; `BRANCH_PROTECTION.md` §6 limitations are cited | Record §3/§9 |
| **F-07** | C10 asymmetry is recorded | The tag predates CI; the green run is on the evidence commit, not the tag SHA; no run URL is invented | Record §3 + `EP-00-010` §4 |
| **F-08** | Drift from the EP-01 planning snapshot is recorded | The record carries a drift table covering at least: commits now exist, tag `v0.0.1-bootstrap` exists, six CI jobs exist, tests exist, branch model exists — where the plan says "zero commits, no CI, no test runner" | Record drift section |
| **F-09** | All 16 decision rows are present | Exactly these owning IDs appear: `ARCHITECTURE §16.4 #1`; `#17`; `#14`; `EES §11.2 #2`/`DEV-001`; EP-00 exit basis; phase opening; `standards §16 #1`; `#2`; `#3`; `#6`; `#8`; `#9`; `EX-10` residual; `EP-01 §4.3-R1`; `EP-01 §4.3-R2`; `EP-01-002/021` technical selections | Record §5 |
| **F-10** | Every row carries the full field set | Owning ID, decision text, owning register, class, owner (role), date, outcome (`RECORDED`/`PENDING`), evidence, follow-up | Record §5 |
| **F-11** | No decision is resolved by the record | Every row that was not supplied in writing is `PENDING` with a named owner; no provider, vendor, library, session lifetime, migration runner, queue or OpenAPI generator is chosen | Record §5 |
| **F-12** | G0 scope rulings are recorded | EP-01 §4.3 ruling 1 (four bundles / five deployments) and ruling 2 (slice-only extraction) are quoted faithfully, or `PENDING` with the architect named | Record §6 |
| **F-13** | `DEV-001` expiry is tested, not assumed | The record compares the expiry (before auth/capability/migration work, and no later than 2026-12-31) with the signing date and records either an appointment or a complete GOV-13 re-deviation with rule, scope, reason, risk, compensating control, owner, expiry, approval and no G4 extension | Record §7 + Standards §13.3 |
| **F-14** | Blocker matrix covers every remaining item | All 38 items `002`–`072` appear, each with an EES §9.1 status, at least one blocker or "none", an owner and a clearing condition | Record §8 |
| **F-15** | Blocker scope is not inflated | The deliberately-excluded list in plan §4.3 (`standards §16 #4`,`#5`,`#10`,`#16`,`#17`; `ARCHITECTURE §16.4 #2/#6/#8`) does not appear as entry blockers | Record §5/§8 cross-check |
| **F-16** | Phase status is exactly one permitted value | `Ready` only if every condition in plan §6.3 holds; otherwise `Blocked`. No third value, no percentage | Record §9 |
| **F-17** | Record's own status is honest | `In review` while drafted/unsigned; `Verified` only after review and signature; never `Completed`, `Released` or "landed" | Record §1 |
| **F-18** | The two conflicts are recorded, not resolved | (a) register fold-in vs. EP-01 §4.2's ban on editing `ARCHITECTURE.md` — recorded as an architect/founder follow-up; (b) the stale planning snapshot — recorded as drift. Neither is silently fixed | Record §10 |
| **F-19** | AR-0 impact note is present | `standards §19.3` impact note recorded because the record authorises identity, authentication and migration work; requirement classes stated as `R3`/`[OPEN]`; no legal, regulatory or contractual obligation asserted | Record §10 |
| **F-20** | Non-implementation is stated | The record states that no database, API, UI, module, worker, package or service was created by `EP-01-001` | Record §9–§11 |
| **F-21** | Evidence is inspectable | `evidence/` contains the transcripts for: git log/tag, empty `App.tsx` diff, reproduced protection `403` body, CI run URL reference, `pnpm test` / `pnpm lint` / `pnpm security:secrets` output | Evidence folder |
| **F-22** | Signature block is complete | Architect review and founder signature with role, name, date and scope of approval; author ≠ approver; no agent in an approver field; the phase-opening act is attributed to the founder | Record §11 |
| **F-23** | Handoff is explicit | The record states what `002`, `020`, `021` and `070` may do next and from which condition | Record §8/§11 |

### 1.2 Expected workflows

| ID | Workflow | Pass condition |
|---|---|---|
| **W-01** | Verify → draft → review → sign → finalise → hand off | Each step evidenced; signature is the opening act; handoff explicit |
| **W-02** | A required decision is not supplied | Work stops at plan step 3; row is `PENDING` with owner; phase is `Blocked`; no default adopted |
| **W-03** | A document conflict is found | Conflict recorded in §10 and work stops; nothing resolved in code or prose (`GOV-05`) |
| **W-04** | Existing controls are used, not rebuilt | `pnpm security:secrets` and the existing CI jobs are the only verification machinery; no new tooling, linter or script was added |
| **W-05** | Change delivery | Work lands on `docs/ep-01-001-entry-record` → PR into `staging` → `main`; the local hook and `verify-pr` guard pass; no direct push to `main` or `staging` |
| **W-06** | Seeded failure | At least three gates are deliberately broken on a scratch copy/branch, detected, then restored; transcripts retained |

### 1.3 Success conditions

| ID | Condition | Pass condition |
|---|---|---|
| **S-01** | EP-01 criterion C1 gains its artifact | The signed record is the linked artifact for C1 |
| **S-02** | Minimal footprint | One record file, its `evidence/` content and the already-approved G0 record; nothing else |
| **S-03** | No parallel register | Every decision row names its owning register; no new register, no new ID scheme |
| **S-04** | Truthful phase state | `Ready` or `Blocked`, with owners; EP-01 is not marked `In build` by this task |
| **S-05** | Indexable | `EP-01-070` can deep-link every decision row and every blocker row from stable headings |
| **S-06** | Platform untouched | No code, schema, API, UI, dependency, lockfile, workflow or prototype change |

### 1.4 Error handling scenarios

| ID | Scenario | Required behaviour | Verify |
|---|---|---|---|
| **E-01** | EP-00 is not exited (the live case) | Phase is `Blocked`; G5, C8 and C14 named with the founder as owner; no workaround asserted | Record §3/§9 |
| **E-02** | `#1`, `#17` or `#14` not supplied | Row `PENDING — owner: Founder`; dependent items listed as blocked; no default chosen | Record §5/§8 |
| **E-03** | `DEV-001` expired at signing | All auth/capability/migration items marked `Blocked` even if the phase opens; no silent continuation | Record §7/§8 |
| **E-04** | Host protection absent but described as present | Rejected: the record must say "compensating control" and cite the GitHub Free 403 | Record §3/§9 |
| **E-05** | Conflicting approved documents | Conflict recorded; no resolution invented; owner named | Record §10 |
| **E-06** | Self-approval or agent approval attempted | Rejected by the signature check; correction recorded in the amendment log | Record §11 |
| **E-07** | Secret appears in evidence | Removed/redacted; no token-bearing URL retained; incident note if exposed | Scan + evidence review |
| **E-08** | Broken relative link | Fixed before approval; link check passes | Link check |
| **E-09** | Post-signature edit needed | Amendment-log entry with date, reason and author; no silent overwrite | Record §11 |
| **E-10** | A stale fact is carried forward | Drift register entry; the plan's snapshot is not presented as current | Record drift section |
| **E-11** | A decision is invented under pressure | Rejected: `PENDING` stands; reviewer names the invention | Row-by-row comparison |
| **E-12** | The implementer edits `ARCHITECTURE.md` or `standards` to "fold in" a decision | Rejected: EP-01 §4.2 forbids it; the fold-in is a follow-up owned by architect/founder | Diff + Record §10 |

### 1.5 Important user interactions

| ID | Consumer | Pass condition |
|---|---|---|
| **U-01** | Founder | Can read the phase status and every blocker with owner in one pass, and can see exactly which signature is outstanding |
| **U-02** | Architect | Can trace each of the 16 decisions to its owning register and source section, and confirm no scope expansion |
| **U-03** | Reviewer | Can confirm no `[OPEN]` decision was resolved and no ruling was paraphrased into a new meaning |
| **U-04** | Work-package owner (`002`, `020`, `021`, `032`, `050`) | Can tell from the record alone whether their item may start and what clears it |
| **U-05** | `EP-01-070` owner | Can index every row without re-reading the phase plan |
| **U-06** | Future phase author | Can reuse the record structure without copying EP-01 content |

---

## 2. Technical Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **A-01** | Architecture compliance | No runtime module, service, API, worker, database, schema, migration, queue, package, bundle, auth component or UI component created or modified | File list + `git status` |
| **A-02** | Approved documents untouched | `documents/Context/*`, root `AGENTS.md`, `CLAUDE.md`, both phase plans and the EP-00 records are byte-identical to the pre-task state | SHA-256 manifest before/after |
| **A-03** | Prototype untouched | `git diff v0.0.1-bootstrap..HEAD -- src/app/App.tsx` is empty; SHA-256 unchanged across the task | Command output |
| **A-04** | No dependency, toolchain or CI change | `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.mise.toml`, `tsconfig.json`, `vite*.config.ts`, `eslint.config.js`, `.lint-baseline.json`, `.githooks/*`, `.github/workflows/*` unchanged | Manifest comparison |
| **A-05** | Structure compliance | Record contains the 11 sections of `EP-00-000` plan §6.2 in order, with stable numbering | Section-by-section checklist |
| **A-06** | Status-logic compliance | Record applies plan §6.3 line by line, including the "local hook does not satisfy C8" and "`DEV-001` expired blocks auth items" lines | Record §9 |
| **A-07** | Class compliance | Record states `[FOUNDER]` and justifies it under `GOV-08` (founder decisions + phase opening engaged) | Record §1 |
| **A-08** | Register integration | Every row resolves to a real register section; no new identifier scheme; no duplicate source of truth | Link + row audit |
| **A-09** | Markdown validity | UTF-8; ISO-8601 dates; numbered headings; tables render; code fences closed; no truncation | Render check |
| **A-10** | Path and naming exactness | Directory `EP-01`, filename `EP-01-ENTRY-RECORD.md`; em dash preserved elsewhere; case exact | Path comparison |
| **A-11** | Evidence convention | Evidence lives under `Engineering-Phase-Records/EP-01/evidence/`; the pre-existing second evidence root is **recorded as a finding for `070`**, not moved or merged | Folder listing + Record §10 |
| **A-12** | Delivery discipline | PR from `docs/ep-01-001-entry-record` into `staging`, then `staging` → `main`; hook and `verify-pr` pass; no direct or force push; no history rewrite | `git log`, PR links, guard runs |
| **A-13** | No template or docs tooling added | No `PHASE-ENTRY-RECORD-TEMPLATE.md`, README, index file, docs linter or script was created | File list |
| **A-14** | CI parity not weakened | All six jobs still run; none skipped, `continue-on-error`, path-filtered out or removed for this change | Workflow diff + run page |
| **A-15** | Controlled verification inputs | Read-only commands only against git and the GitHub API; no settings mutation attempted; the `403` was reproduced, not provoked | Command log |

**Practical method for A-02–A-04:** capture a SHA-256 manifest of the protected paths before the task and after, and compare. A `git status` alone is insufficient once later items have touched the same working tree.

---

## 3. Data Verification

**Applicability:** applicable in the document sense. No database exists and none is created; the record, its decision rows, its blocker rows and its evidence set are the data under verification.

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **D-01** | Required records created | Exactly one entry record; evidence files only inside `evidence/`; no duplicate or orphan file | File list |
| **D-02** | Decision-row completeness | 16 rows, one per required owning ID; no duplicates; none missing | Record §5 |
| **D-03** | Blocker-row completeness | 38 rows for `002`–`072`; no gaps; no row for a non-existent item | Record §8 |
| **D-04** | Relationships correct | Every blocked item's blocker resolves to a decision row or a named precondition; every decision row lists the items it blocks; no orphan blocker | Cross-reference audit |
| **D-05** | Data accuracy | Roles, classes, dates and evidence references are accurate; `PENDING` is used wherever written approval is absent; no date is invented | Row review vs. source input |
| **D-06** | Data integrity | Append-only after signature; no blank owner, date or clearing condition; EES §9.1 vocabulary only | Record + row scan |
| **D-07** | No invented data | No decision, approval, date, CI run or evidence reference exists beyond what was supplied or observed | Comparison against transcripts |
| **D-08** | Evidence-to-claim traceability | Every `Met` row in §3 points to a transcript that exists and says what the row claims | Transcript cross-check |
| **D-09** | Drift data accuracy | Each drift entry is supported by a command run on the verification date | Drift table + command log |
| **D-10** | No database artefact | No table, schema, migration, grant, RLS policy, role, provider or connection definition created | File list + Record §9 |

---

## 4. Security Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **SEC-01** | No secrets | `pnpm security:secrets` exits 0; no token, key, password, connection string, webhook URL or `.env` content in the record or evidence | Scan output |
| **SEC-02** | No credential-bearing URLs | The reproduced `403` body and every URL are credential-free; no signed parameter, no embedded token | URL review |
| **SEC-03** | Sensitive data protection | No customer or personal data; approver names are governance identities only; any settings export is redacted before reference | Record + evidence review |
| **SEC-04** | No access-control change | No authentication, authorisation, role, grant, session or permission introduced or altered | File list |
| **SEC-05** | AI boundary respected | An agent drafted and verified only; no agent signature, approval, decision, phase-status change or second-reviewer role (`EES §5.6`, `AI-20`, `AI-21`) | Signature block + commit history |
| **SEC-06** | Vendor rule respected | If `#8` or `#9` names a vendor receiving personal data or source code, `TEC-12` data flow, region and retention are recorded before it is treated as approved | Record rows `#8`/`#9` |
| **SEC-07** | Integrity control | Signature block, author ≠ approver, explicit approval scope, dates, append-only amendment log | Record §11 |
| **SEC-08** | Gate integrity | `GOV-20` no gate bypassed; `GOV-21` the missing host control (C8) is stated as missing, not implied | Record §3/§9 |
| **SEC-09** | No control weakened | No check disabled, no self-approval, no hook bypass, no test-only or debug path introduced to make the record pass | Diff review |
| **SEC-10** | Claim discipline | Nothing is described as secure, compliant, hardened, certified or production-ready; the record states what was verified and how | Wording review |
| **SEC-11** | Findings reported, not silently fixed | The evidence-root divergence, the register fold-in conflict and the stale snapshot are reported as findings with owners; none is repaired inside this task | Record §10 |
| **SEC-12** | Audit-readiness artefact | AR-0 impact note present with requirement classes and data classes stated; no obligation asserted beyond `[OPEN]` | Record §10 |

---

## 5. Performance Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **P-01** | No runtime impact | No executable artefact, dependency or configuration added; runtime behaviour unchanged | File list |
| **P-02** | Reviewability | The decision and blocker summary is readable in one sitting; detail is linked, not duplicated from the phase plan | Size + structure review |
| **P-03** | Link and render performance | All links resolve; tables and headings render; no encoding defect | Render + link check |
| **P-04** | Reliability and consistency | No contradictory status between §3, §8 and §9; no decision row contradicts a blocker row | Consistency audit |
| **P-05** | Decision latency | The founder can determine phase status and outstanding signatures without re-reading the EP-01 plan | Founder read-through |

---

## 6. Testing Verification

**Applicability:** manual document gates plus the reusable secret scan and CI pipeline. No new automated test is written; none is claimed.

| ID | Test | Pass condition | Evidence |
|---|---|---|---|
| **TV-01** | T1 — EP-00 exit coverage | C1–C14 all present, each with an inspected artifact or an explicit unmet mark | Checklist |
| **TV-02** | T2 — Evidence re-verification | Every `Met` cites an output or URL reproduced on the verification date, not a summary | Transcripts |
| **TV-03** | T3 — Decision completeness | All 16 rows carry ID, register, class, owner, date, status, evidence | Row audit |
| **TV-04** | T4 — No invented decision | Ruling text matches the supplied text; no `[OPEN]` row marked decided | Side-by-side |
| **TV-05** | T5 — Register non-duplication | Every row names an owning register; no new register | Row audit |
| **TV-06** | T6 — Status honesty | `Ready` only with every §6.3 condition; otherwise `Blocked` with owners | Record §9 |
| **TV-07** | T7 — Blocker coverage | All 38 items with status, blocker or "none", owner, clearing condition | Matrix audit |
| **TV-08** | T8 — Drift accuracy | Commands re-run on the verification date; differences recorded, not ignored | Command output |
| **TV-09** | T9 — Scope discipline | Diff contains only the EP-01 files; protected paths unchanged | Manifest + file list |
| **TV-10** | T10 — Secret / PII scan | Scan exits 0; seeded key is detected then removed | Scan transcripts |
| **TV-11** | T11 — Independent approval | Author ≠ approver; agent not an approver; roles and dates present | Signature block |
| **TV-12** | T12 — Link integrity | Every relative link resolves; no absolute path | Link check |
| **TV-13** | T13 — Markdown integrity | Tables, headings, fences and encoding valid | Render check |
| **TV-14** | T14 — CI parity | PR green on all six jobs; nothing newly excluded | Run page |
| **TV-15** | Seeded failures demonstrated | At least three: e.g. remove a C-row, remove a blocker row, insert a fake key. Each detected; each restored; transcripts retained | Seeded-failure note |
| **TV-16** | Edge cases exercised | Both branches verified on a scratch copy: all conditions met → `Ready`; one missing → `Blocked`. Plus: `DEV-001` expired; C8 accepted vs. not; §4.3 rulings `PENDING` | Verification note |
| **TV-17** | Failure scenarios honoured | Stop conditions observed: missing entry decision, missing second reviewer, conflicting documents, self-approval, secret in evidence | Verification note |
| **TV-18** | No false automated claim | No CI run, test, scanner result or protection is claimed that did not actually occur | Record review |
| **TV-19** | Real-outcome consistency | The final status in the record equals the status produced by the checklist when applied independently by the project lead | Independent re-derivation |
| **TV-20** | Reversible verification | Every scratch branch, fixture and seeded failure was removed; `git branch -a` shows only the approved branches | Branch list |

---

## 7. User Acceptance Verification

| ID | Real-world check | Pass condition |
|---|---|---|
| **UA-01** | Founder read-through | Founder can state, unaided, whether EP-01 is `Ready` or `Blocked`, and who owns each outstanding act |
| **UA-02** | Architect fidelity review | Architect confirms the 16 rows and both §4.3 rulings are faithful, complete and free of scope expansion |
| **UA-03** | Project lead C1 check | EP-01 criterion C1 is supported by the signed record as its linked artifact |
| **UA-04** | Blocker actionability | The owner of `020` (database) and the owner of `032` (sessions) can each tell from the record what must land before they start |
| **UA-05** | Indexability | `EP-01-070` can link every decision and blocker row from stable anchors |
| **UA-06** | Discoverability | A contributor finds the record at the agreed path and understands the phase basis without the full plan |
| **UA-07** | No-surprise diff | The only repository change is the EP-01 record, its evidence and the approved G0 record; nothing in `documents/Context/*`, the prototype or configuration moved |
| **UA-08** | Handoff correctness | `002` is marked startable only if its dependencies (workspace selections) are recorded; otherwise it stays blocked with a named owner |

---

## 8. Final Approval Checklist

A single unchecked item blocks approval unless recorded as an approved exception in §9.

- [ ] **FA-01** Functional checks F-01–F-23 pass.
- [ ] **FA-02** Technical checks A-01–A-15 pass.
- [ ] **FA-03** Data checks D-01–D-10 pass.
- [ ] **FA-04** Security checks SEC-01–SEC-12 pass.
- [ ] **FA-05** Performance checks P-01–P-05 pass.
- [ ] **FA-06** Testing checks TV-01–TV-20 pass, including at least three seeded failures.
- [ ] **FA-07** User acceptance checks UA-01–UA-08 pass.
- [ ] **FA-08** EP-01 status is exactly `Ready` or `Blocked`, correctly derived from plan §6.3.
- [ ] **FA-09** C1–C14 are each verified against an artifact inspected on the verification date.
- [ ] **FA-10** All 16 decision rows exist, with owning register, class, owner, date, outcome and evidence.
- [ ] **FA-11** No `[OPEN]` decision is silently resolved; no provider, vendor, library, lifetime, runner, queue or generator is chosen beyond what was ruled.
- [ ] **FA-12** Both EP-01 §4.3 rulings are recorded faithfully, or `PENDING` with the architect named.
- [ ] **FA-13** `DEV-001` expiry is tested against the verification date; the EP-01 arrangement is an appointment or a complete GOV-13 re-deviation with expiry and no G4 extension.
- [ ] **FA-14** All 38 items `002`–`072` have a status, a blocker or "none", an owner and a clearing condition.
- [ ] **FA-15** C8 is described as a compensating control only; no claim of protected `main` appears anywhere.
- [ ] **FA-16** No parallel decision register and no parallel deviations register exist; no new identifier scheme was introduced.
- [ ] **FA-17** The two conflicts (register fold-in vs. EP-01 §4.2; stale snapshot) are recorded as findings with owners, not resolved in this task.
- [ ] **FA-18** No secret, credential, token-bearing URL or personal data is present; `pnpm security:secrets` exits 0.
- [ ] **FA-19** `src/app/App.tsx`, `documents/Context/*`, both phase plans, dependencies, lockfiles, workflows and hooks are unchanged.
- [ ] **FA-20** Only the EP-01 record, its evidence and the approved G0 record exist as new artifacts; no template, README, index or script was added.
- [ ] **FA-21** Author ≠ approver; the agent is not an approver; architect review and founder signature, dates and scope are recorded.
- [ ] **FA-22** The record itself is `Verified`; it is not marked `Completed`, `Released`, or given a percentage.
- [ ] **FA-23** The change was delivered through `feature → staging → main` with all six CI jobs green; no direct or force push; no history rewrite.
- [ ] **FA-24** Any deviation is recorded under Standards §13.3 with an owner and an expiry; no deviation extends to G4.
- [ ] **FA-25** AR-0 impact note is present and asserts no legal, regulatory or contractual obligation.
- [ ] **FA-26** The project lead has signed the approval record in §9.

### Mandatory stop conditions — do not approve if any is true

- EP-01 is marked `Ready` while EP-00's G5 is unsigned, or while `#1`, `#17`, `#14` or the second reviewer is missing, unless a valid recorded founder ruling exists.
- `DEV-001` has expired and no replacement appointment or re-deviation is recorded.
- Host protection is described as present when only the local hook and CI guard exist.
- A decision, approval, date, CI run or evidence reference was invented.
- A decision was resolved by the implementer, or an owning register was edited to fold it in.
- More than the approved artifacts were created, or a template/index/script was added.
- A secret, credential or token-bearing URL is present.
- A protected file, the prototype, a dependency, a workflow or a hook changed.
- The record is self-approved, agent-approved or unsigned.
- The phase status is anything other than exactly `Ready` or `Blocked`.

---

## 9. Approval Record

| Field | Value |
|---|---|
| **Project lead** | |
| **Decision** | ☐ Approved  ☐ Approved with recorded exception  ☐ Rejected |
| **Conditions / notes** | |
| **Date** | |
| **Next action** | |

---

This DoD is specific to `EP-01-001`. It verifies the EP-01 entry record, the EP-00 exit re-verification, the 16 decision rows, the two G0 scope rulings, the 38-item blocker matrix and the phase-status determination — and nothing from `EP-01-002` onward.
