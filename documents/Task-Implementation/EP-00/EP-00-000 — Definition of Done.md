# Task Definition of Done — EP-00-000
## Phase entry record, G0 rulings and decision closure

| Field | Value |
|---|---|
| **Task ID** | `EP-00-000` |
| **Task Name** | Phase entry record, G0 rulings and decision closure |
| **Related Phase** | `EP-00` — Execution Readiness |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-00/EP-00-000 — Phase entry record, G0 rulings and decision closure.md` |
| **Artifact under verification** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` |
| **Verification owner** | Project lead, with architect review and founder signature |
| **Verification date** | 2026-11-06 |
| **Overall result** | ☑ Pass with recorded exception — see §9 |

**Verification boundary.** This DoD verifies only the entry record produced by `EP-00-000`. It does not verify `EP-00-001`–`011`, the toolchain, CI, branch protection, scanning, or any later phase. Those remain blocked or pending per the record's blocker matrix.

---

## 1. Functional Verification

### 1.1 Required functionality

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **F-01** | Record exists at the exact approved path | `documents/Engineering-Execution/Engineering-Phase-Records/EP-00/EP-00-ENTRY-RECORD.md` exists and is readable | File path + open file |
| **F-02** | Record identity is complete | Document ID is `EP-00-000`; phase is `EP-00`; task name matches; class, status, author role, approver roles and date are present | Record §1 |
| **F-03** | Authority basis is explicit | Lists the approved documents, versions/approval dates, and the exact sections relied on: EES §5/§7/§8/§9/§11; EP-00 §1/§4.3/§6/§7/§9/§11/§13; Standards GOV-05, GOV-08–GOV-19, QUA-29–QUA-37, TEC-12, §12, §13.3, §16; Architecture §2.3, §2.5, §11.6, §12.1–§12.8, §15.5, §16.3 #6/#8, §16.4; AGENTS.md §1/§3/§7 | Record §2 |
| **F-04** | Entry gate is verified, not assumed | EP-00 §1 entry gate is stated; met/not met is explicit; supporting evidence or absence is named | Record §3 |
| **F-05** | Starting position is re-verified on the signing date | Date and read-only commands are recorded; facts are current; any drift from the 4 Nov 2026 snapshot is explicitly recorded | Record §4 + command output |
| **F-06** | All required decisions are present | Rows exist for: #18, rulings 1–4, second reviewer, phase opening | Record §5–§7 |
| **F-07** | #18 content is complete | Host, CI service, repository visibility, protection mechanism, scanning features (native vs third-party), `staging`/`production` definitions, exit path — **or** `PENDING — owner: Founder` | Record decision row #18 |
| **F-08** | Four G0 rulings are recorded correctly | Ruling 4 (`EP-` prefix) is marked historical and dated 4 Nov 2026; rulings 1–3 are recorded verbatim; no linter, test runner or provider is selected beyond the ruling | Record §6 |
| **F-09** | Second-reviewer arrangement is closed | Appointment named, **or** a GOV-13 deviation with ID, rule, scope, reason, risk, compensating control, owner, expiry, approval; G4 exclusion stated | Record §7 + Standards §13.3 |
| **F-10** | Blocker matrix covers every EP-00 item | All `EP-00-001`–`011` appear with status, blockers (or "none"), owner, clearing condition | Record §8 |
| **F-11** | Phase status is exactly one permitted value | `In build` only if founder opened + #18 + three rulings + second reviewer; otherwise `Blocked` with missing items and owners | Record §9 |
| **F-12** | Record's own status is honest | `In review` when drafted and unsigned; `Verified` when reviewed and signed; no "Completed", percentage or "landed" | Record §1 |
| **F-13** | Signature block is complete | Founder role, name, date, scope of approval; author ≠ approver; no agent in an approver field | Record §11 |
| **F-14** | Amendment log exists | Append-only; no silent post-signature edits; any correction is dated and attributed | Record §11 |
| **F-15** | Register follow-ups are recorded | Each settled decision names the owning register and the follow-up owner/target; no consolidation is silently skipped or performed | Record §10 |
| **F-16** | Non-implementation is stated | Record states that no database, API, UI, module, service or runtime asset was created by `000` | Record §9–§11 |

### 1.2 Expected workflows

| ID | Workflow | Pass condition |
|---|---|---|
| **W-01** | Draft → architect review → founder signature → finalise → handoff to `EP-00-001` | Each step is evidenced; the founder's signature is the opening act; the handoff is explicit |
| **W-02** | Decision missing | Work stops; item is `PENDING` with owner; phase is `Blocked`; no speculative ruling is drafted |
| **W-03** | Document conflict found | Conflict is recorded and work stops; no silent resolution (GOV-05) |
| **W-04** | Scope pressure | Record stays within one file + its directory; no remote, CI, toolchain, linter or test runner is created |

### 1.3 Success conditions

| ID | Condition | Pass condition |
|---|---|---|
| **S-01** | EP-00 completion criterion C1 is supported | The signed record is the linked artifact for C1 |
| **S-02** | Single artifact | Exactly one new file and one new directory; no README, index, template or per-package file |
| **S-03** | No parallel register | Every decision row names its owning register; no new register is created |
| **S-04** | Phase state is truthful | `In build` or `Blocked`, with owners; no intermediate state |
| **S-05** | Platform hygiene preserved | No code, schema, API, UI, dependency, lockfile or prototype change |

### 1.4 Error handling scenarios

| ID | Scenario | Required behaviour | Verify |
|---|---|---|---|
| **E-01** | #18 not decided | Row is `PENDING — owner: Founder`; phase is `Blocked` | Record rows + status |
| **E-02** | Any of rulings 1–3 not provided | Row is `PENDING` with owner; phase is `Blocked`; no default adopted | Record rows + status |
| **E-03** | Second reviewer not arranged | Phase is `Blocked`; no silent omission; no claim that review is satisfied | Record §7/§9 |
| **E-04** | Conflicting approved documents | Conflict recorded; no resolution invented; owner named | Record §10 |
| **E-05** | Self-approval attempted | Rejected; signature check fails; correction recorded | Record §11 |
| **E-06** | Secret appears in evidence | Removed/redacted; no token-bearing URL retained; incident note if exposed | Record + scan |
| **E-07** | Broken relative link | Fixed before approval; link check passes | Link check |
| **E-08** | Post-signature edit needed | Amendment log entry with date and reason; no silent overwrite | Record §11 |

### 1.5 Important user interactions

| ID | Consumer | Pass condition |
|---|---|---|
| **U-01** | Founder | Can identify phase status and every blocker with owner in one read |
| **U-02** | Architect | Can trace every decision to its owning register and source section |
| **U-03** | Reviewer | Can confirm no `[OPEN]` decision was resolved and no ruling was invented |
| **U-04** | Future contributor | Can locate the record from the agreed path and understand the phase basis without reading the full plan |
| **U-05** | Project lead | Can verify C1 and the handoff to `EP-00-001` from the record alone |

---

## 2. Technical Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **A-01** | Architecture compliance | No runtime module, service, API, worker, database, schema, migration, queue, container, auth component or UI component is created or modified | File list + `git status` |
| **A-02** | Approved documents untouched | `documents/Context/*`, `AGENTS.md`, `CLAUDE.md`, the EP-00 and EP-01 phase plans are byte-identical to the pre-task state | SHA-256 manifest before/after |
| **A-03** | Prototype untouched | `src/app/App.tsx` is byte-identical | SHA-256 before/after |
| **A-04** | No dependency or toolchain change | `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.mise.toml`, `tsconfig.json`, Vite configs unchanged | SHA-256 before/after |
| **A-05** | Plan structure compliance | Record contains all 11 sections in plan §6.2 and all fields in §6.3 | Section-by-section checklist |
| **A-06** | Status logic compliance | Record applies the plan §6.5 gate exactly; no status beyond the evidence | Record §9 |
| **A-07** | Class compliance | Record states the class it was reviewed under; `[FOUNDER]` where the scope ruling and #18 are engaged, unless ruling 1 is explicitly recorded as non-scope-changing, in which case `[REVIEW]` is justified | Record §1 + GOV-08/GOV-09 |
| **A-08** | Module integration | All referenced documents and registers resolve; no duplicate decision source; no new identifier scheme | Link check + row review |
| **A-09** | Markdown validity | UTF-8; ISO-8601 dates; headings stable; tables render; code fence closed; no truncation | Render check |
| **A-10** | Git discipline | No commit or push attributable to `000`; record is designated for inclusion in `EP-00-001`'s first commit | `git log` + handoff statement |
| **A-11** | No extra artifacts | Only the record file and its containing directory were added; no template, README, index, script or config | Full untracked file list |
| **A-12** | Path and naming exactness | Directory and filename match the approved plan character-for-character, including the em dash | Path comparison |

**Practical method for A-02–A-04:** take a SHA-256 manifest of protected paths before implementation and after, and compare. Because the repository has zero commits, `git status` alone cannot prove "no other file changed" — the manifest is the evidence.

---

## 3. Data Verification

**Applicability:** applicable in the document sense. No database exists and none is created; the record is the data set under verification.

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **D-01** | Required records created | One record; no duplicate files; no orphan directory content | File list |
| **D-02** | Decision rows complete | One row per required decision; no duplicates; no missing decision | Record §5–§7 |
| **D-03** | Relationships correct | Every row names its owning register; every follow-up names a target; cross-references resolve | Record rows + link check |
| **D-04** | Data accuracy | Roles, dates, classes and evidence references are accurate; `PENDING` is used where approval is absent | Row review |
| **D-05** | Data integrity | Append-only after signature; unresolved items are visibly `PENDING`; no blank owner or date | Record §11 + row scan |
| **D-06** | Blocker data completeness | All 11 items; EES status vocabulary only; owner and clearing condition present | Record §8 |
| **D-07** | No invented data | No decision, date, approval or evidence beyond what was supplied | Compare against founder/architect input |
| **D-08** | No database artefact | No table, schema, migration, grant, RLS policy or Supabase project created | File list + record statement |

---

## 4. Security Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **SEC-01** | No secrets | No token, key, password, connection string, webhook URL or `.env` content in the record or its evidence | Secret-pattern scan |
| **SEC-02** | No credential-bearing URLs | No URL containing a token, signed parameter or embedded credential | URL review |
| **SEC-03** | Sensitive data protection | No customer personal data; approver names are governance identities only; settings exports are redacted | Record review |
| **SEC-04** | No access-control change | No authentication, authorisation, role or permission is introduced; the record inherits repository access controls | Record + file list |
| **SEC-05** | AI boundary respected | An agent drafted and verified only; no agent signature, approval, #18 decision or status change | Signature block + history |
| **SEC-06** | Vendor rule respected | If a third-party scanner is named, TEC-12 approval with data flow, region and retention is recorded; native scanning is preferred and the record says so | Record #18 row |
| **SEC-07** | Integrity control | Signature block, author ≠ approver, approval scope, date, append-only amendment log | Record §11 |
| **SEC-08** | No visual/security surface change | No prototype, header, CSP, route, host or credential configuration changed | Manifest + record |

---

## 5. Performance Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **P-01** | No runtime impact | No executable artifact, dependency or configuration is added; runtime behaviour is unchanged | File list |
| **P-02** | Reviewability | The record can be reviewed honestly in one sitting; it links to the phase plan rather than duplicating it | Size + structure review |
| **P-03** | Link and render performance | All links resolve; tables and headings render; no truncation or encoding defect | Render + link check |
| **P-04** | Reliability | No broken cross-reference, no contradictory status, no stale fact presented as current | Consistency review |
| **P-05** | Decision latency | The founder can determine phase status and blockers without re-reading the full EP-00 plan | Founder read-through |

---

## 6. Testing Verification

**Applicability:** manual document gates only. No automated test runner exists at this point; no CI run exists. The record must not claim either.

| ID | Test | Pass condition | Evidence |
|---|---|---|---|
| **TV-01** | Completeness (T1) | Every required field and expected-outcome element is present | Checklist |
| **TV-02** | Decision traceability (T2) | Every decision has ID, owning register, decided-by, date, class, evidence or explicit `PENDING` | Row audit |
| **TV-03** | No invented decision (T3) | Ruling text matches the supplied ruling; no `[OPEN]` item is marked decided | Side-by-side comparison |
| **TV-04** | Blocker coverage (T4) | All `EP-00-001`–`011` present with status and blocker or "none" | Matrix audit |
| **TV-05** | Starting-position accuracy (T5) | Re-run read-only commands; drift recorded, not ignored | Command output |
| **TV-06** | Scope discipline (T6) | Diff/asset list contains only the record and directory; protected files unchanged | Manifest + file list |
| **TV-07** | Secret/PII scan (T7) | No credential pattern, token-bearing URL, `.env` content or personal data | Scan output |
| **TV-08** | Status honesty (T8) | `In build` only with all four opening conditions; otherwise `Blocked` | Record §9 |
| **TV-09** | Independent approval (T9) | Author ≠ approver; agent not an approver; roles named | Signature block |
| **TV-10** | Register non-duplication (T10) | Every decision row names an owning register; no new register | Row audit |
| **TV-11** | Link integrity (T11) | Every relative link resolves; no absolute path | Link check |
| **TV-12** | Markdown integrity (T12) | Tables, headings, code fence and encoding valid | Render check |
| **TV-13** | Seeded failure demonstrated | At least one gate was deliberately broken and detected (e.g., remove an owner, a blocker row, or #18), then restored; the transcript is retained | Seeded-failure note |
| **TV-14** | No false automated claim | Record does not claim a CI run, automated test or scanner result that does not exist | Record review |
| **TV-15** | Edge cases exercised | Both status branches checked: all decisions present → `In build`; one missing → `Blocked`; expired deviation → rejected; stale fact → recorded | Verification note |
| **TV-16** | Failure scenarios exercised | Stop conditions honoured: missing #18, missing ruling, conflicting documents, self-approval, secret in evidence | Verification note |

---

## 7. User Acceptance Verification

| ID | Real-world check | Pass condition |
|---|---|---|
| **UA-01** | Founder read-through | Founder can state, without assistance, whether EP-00 is `In build` or `Blocked`, and who owns each blocker |
| **UA-02** | Architect fidelity review | Architect confirms the rulings and #18 text are faithful, complete, and free of scope expansion |
| **UA-03** | Project lead C1 check | C1 is supported by the record as its linked artifact |
| **UA-04** | Newcomer discoverability | A contributor can find the record at the agreed path and understand the phase basis from the record alone |
| **UA-05** | No-surprise check | The only repository change is the record and its directory; nothing in `documents/Context/*`, the prototype, or configuration moved |
| **UA-06** | Handoff check | The record explicitly hands off to `EP-00-001` and states that the record enters the first commit |

---

## 8. Final Approval Checklist

A single unchecked item below blocks approval, unless it is recorded as an approved exception in §9.

- [x] **FA-01** All Functional checks F-01–F-16 pass.
- [x] **FA-02** All Technical checks A-01–A-12 pass.
- [x] **FA-03** All Data checks D-01–D-08 pass.
- [x] **FA-04** All Security checks SEC-01–SEC-08 pass.
- [x] **FA-05** All Performance checks P-01–P-05 pass.
- [x] **FA-06** All Testing checks TV-01–TV-16 pass, including the seeded failure.
- [x] **FA-07** All User Acceptance checks UA-01–UA-06 pass.
- [x] **FA-08** Phase status is exactly `In build` or `Blocked`, correctly justified.
- [x] **FA-09** #18, rulings 1–4 and the second-reviewer arrangement are recorded with owner, date, class and evidence.
- [x] **FA-10** Every `EP-00-001`–`011` has a status, blocker or "none", owner and clearing condition.
- [x] **FA-11** No `[OPEN]` decision is silently resolved; no default is chosen; no linter, test runner or provider is selected beyond the ruling.
- [x] **FA-12** No parallel decision register and no parallel deviations register exist.
- [x] **FA-13** No secret, credential, token-bearing URL or personal data is present.
- [x] **FA-14** `src/app/App.tsx`, `documents/Context/*` and the approved phase plans are unchanged. **Recorded exception:** `documents/Context/*` and `.mise.toml` were changed only by separately approved follow-ups after `EP-00-000`; see §9.
- [x] **FA-15** Exactly one new record file and one new directory exist; no template, index, README or script.
- [x] **FA-16** Author ≠ approver; the agent is not an approver; signature, date and scope are present.
- [x] **FA-17** The record itself is `Verified`; it is not marked `Completed`, `Released`, or given a percentage.
- [x] **FA-18** No commit or push is attributed to `EP-00-000`; the handoff to `EP-00-001` is explicit.
- [x] **FA-19** Any deviation is recorded under Standards §13.3 with an owner and an expiry; no deviation extends to G4.
- [x] **FA-20** The project lead has signed the approval record below.

### Mandatory stop conditions — do not approve if any is true

- A decision, approval, date or evidence reference was invented.
- EP-00 is marked `In build` while #18, a ruling, or the second reviewer is missing.
- The record is self-approved, agent-approved, or unsigned.
- A secret, credential or token-bearing URL is present.
- A protected file, the prototype, a dependency or a config changed.
- A second decision register or deviations register was created.
- More than one new artifact exists.
- The record claims CI, automated tests, scanning or protection that do not exist.
- The phase status is anything other than `In build` or `Blocked`.

---

## 9. Approval Record

| Field | Value |
|---|---|
| **Project lead** | Prince Abidemi Oluwadamilare |
| **Decision** | ☑ Approved — with recorded exception (see notes) |
| **Conditions / notes** | **FA-14 / protected-file stop condition:** the changes to `.mise.toml`, `ARCHITECTURE.md` and the standards register were separately approved follow-ups after `EP-00-000`, recorded in the entry record `v0.8`. `EP-00-000`'s own artifact changed only the entry record and its directory. **TV-13:** seeded-failure proof executed 2026-11-06 — the `EP-00-007` blocker row was removed from a temporary copy; the checklist detected the missing row; the copy was deleted. The entry record is committed in `8029466`. |
| **Date** | 2026-11-06 |
| **Next action** | `EP-00-001` committed in `8029466`; proceed to `EP-00-002` and `EP-00-005`. |

---

This DoD is specific to `EP-00-000`. It verifies the signed entry record, the decision closure, the phase-status determination and the handoff — nothing from `EP-00-001` onward.
