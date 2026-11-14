# Control Portal — Independent Review Register

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/REVIEW-REGISTER.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Date** | 14 November 2026 |
| **Scope** | CP-001 → CP-020 (all implemented packages) |
| **Phase** | 1 of 4 — evidence harvest only |
| **Status** | **OPEN — evidence recorded, review passes not yet performed.** |
| **Approver** | None. This document does not change any package status. |

> This register states what evidence exists and where it is missing. It is **not** a review and
> **not** a sign-off. A row marked "no review pass" has not been reviewed, whatever its package
> status says. `AUD-75` applies: a gate is passed on evidence, not on assertion.

---

## 1. Why this register exists

Twenty packages are marked `REQUIRES_REVIEW` in `EXECUTION-TRACKER.md` and none are `COMPLETED`,
except CP-001. The gate those packages are waiting on has three limbs:

| Rule | Requirement |
|---|---|
| `QUA-29` / `QUA-31` | Review by someone other than the author; sensitive areas get a second reviewer |
| `QUA-33` | The reviewer reads the diff, not the description |
| `AUT-39` | Authentication, session, capability, grant, RLS and admin endpoint changes need a second reviewer who did not write the change, plus test evidence |
| `AUD-75` | A gate passed without a record is not a pass |

Under deviation `DEV-002` (one-person team), the compensating control is an agent-produced
independent review pass recorded on each pull request, with the founder still reading every diff.
This register is the index for that work: Phase 1 records the evidence, Phases 2–4 perform and
record the reviews.

## 2. Method and limits

- Evidence was read from GitHub Actions runs for the merge commit of each package, the migration
  directory, the test directory, and the tracker's G0 records.
- Commit → CI mapping uses the **merge commit on `staging`**, which is the commit that was deployed.
- No code was changed and no package status was touched in this phase.
- Absence of a test file is recorded as an evidence gap, not as a defect. Whether it is a defect is
  decided in Phase 2 against the package's stated test plan.
- Work-package CI was queried on 14 November 2026; run identifiers are GitHub Actions database IDs.

## 3. Proposed status vocabulary

A three-state ladder is proposed so that "reviewed" and "signed" are distinguishable:

| State | Meaning | Who moves it |
|---|---|---|
| `REQUIRES_REVIEW` | Implemented and deployed; no recorded independent review | automatic after merge |
| `REVIEWED` | Review pass recorded, findings closed, CI green on the merge commit, staging evidence present | the reviewing agent, with the record in this register |
| `COMPLETED` | Signed off against the reviewed evidence | **founder only** |

**Adopted 14 November 2026.** Every implemented package moved to `REVIEWED` in
`EXECUTION-TRACKER.md`; CP-012, CP-020, CP-016, CP-017, CP-018 and CP-019 have since moved to
`COMPLETED` on founder sign-off (§4.1 of the tracker). The other thirteen await the same signature.

## 4. Evidence register

Workflow columns: **CI** = `CI`, **Fly** = `Staging Fly deployment`, **Gate** = `Staging deployment
gate`; all four workflows including `Protected branch guard` unless noted.

| Package | PR(s) | Merge commit | CI | Fly | Gate | Migration | Primary tests | G0 record |
|---|---|---|---|---|---|---|---|---|
| CP-001 | — (documents) | — | n/a | — | — | — | — | `DECISION-RECORD.md` (approved 11 Nov) |
| CP-002 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | `20261111000100` | `admin-authorization`, `admin-authorization-schema` | Tracker §4 |
| CP-003 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | `20261111000300` | `capability-registry`, `capabilities` | Tracker §4 |
| CP-004 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | `20261111000200` | `control-p0-matrix`, `admin-schema` | Tracker §4 |
| CP-005 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | `20261111000400` | `audit` | **none** |
| CP-006 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | `20261111000500`, `…0600` | `admin-schema` | **none** |
| CP-007 | #47, #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | — | `control-routes`, `app-shell` | **none** |
| CP-008 | #49 | `4e29364` | 43047734311 | 43047734163 | 43047734228 | — | `control-p0-matrix`, `enforcement`, `rls-policy` | **none** |
| CP-009 | #54, #55, #56, #57 | `458ffec`, `92d49a5` | 43161627374, 43170117927 | 43161627398, 43170117865 | 43161627343, 43170117862 | `20261112000100`, `…0200` | `audit` | Tracker §4 |
| CP-010 | #61 – #77 (17 PRs) | `176054e` … `a7b4ca6` | 43292512696 → 43392666504 | see tracker | see tracker | `20261113000100`, `…0200`, `20261114000100` | `staff-invite-email`, `staff-invite-rate-limit`, `control-portal-links` | Tracker §4 + `CP-010 - Staff Records and Lifecycle.md` |
| CP-011 | #58 | `d8f4b62` | 43274236510 | 43274236456 | 43274236540 | `20261112000300` | `grants-integration` | Tracker §4 |
| CP-012 | #80 – #85 (6 PRs) | `cc4dee6`, `c5f40c9`, `04fa83d`, `49ba621`, `92213dd` | 43408590626, 43409322402, 43415812564, 43419204026, 43451505116 | **`cc4dee6` failed** (43408590772) | **`92213dd` failed** (43451505153) | `20261114000200`, `…0300` | `roles-integration`, `admin-authorization` | Tracker §4 |
| CP-013 | #88 | `30b4964` | 43459601470 | 43459601414 | 43459601682 | `20261114000400` | `account-governance` | Tracker §4 |
| CP-014 | #91 | `57f94b1` | 43471043478 | 43471043301 | 43471043386 | `20261114000600` | `partners` | Tracker §4 |
| CP-015 | #92, #93 | `5946647`, `48bfb2d` | 43474267597 | 43474267675 | 43474267825 | `20261114000700` | `partner-isolation` | Tracker §4 |
| CP-016 | #94 | `b467536` | 43482561430 | 43482561385 | 43482561929 | `20261114000800` | `cases` | Tracker §4 |
| CP-017 | #95 | `a7fc3c4` | 43489488705 | 43489488565 | 43489488581 | `20261114000900` | `cases` | Tracker §4 |
| CP-018 | #96 | `2441f6e` | 43496232826 | 43496232770 | 43496232852 | `20261114001000` | `approvals`, `cases` | Tracker §4 |
| CP-019 | #97 | `eedefac` | 43502126678 | 43502126700 | 43502126702 | `20261114001100` | `verification` | Tracker §4 |
| CP-020 | #89, #90 | `9f215e3`, `8511fd9` | 43464713022 | 43464713077 | 43464714049 | `20261114000500` | `approvals`, `account-governance` | Tracker §4 |

Every package from CP-009 onward has a green `CI`, `Staging Fly deployment` and `Staging deployment
gate` on its merge commit, with the three exceptions listed as `G-05`.

## 5. Evidence gaps

| ID | Gap | Basis |
|---|---|---|
| **G-01** | CP-005, CP-006, CP-007 and CP-008 have **no G0 record** in the execution tracker. Their only record is `P0-EVIDENCE-PACK.md`. | Tracker §4 has sections for CP-002/003/004/009/010/011–020 only |
| **G-02** | `P0-EVIDENCE-PACK.md` has not been touched since 11 November. It states **"PARTIAL — local code and tests verified; database run, CI and independent review outstanding"** and "Not signed". | Pack header; it predates the CI evidence for the same commits (`4e29364`) |
| **G-03** | **No package records an independent review pass.** There is no review column, no review document and no captured review comment for any of the twenty. | `AUT-39`, `DEV-002`, `AUD-75` |
| **G-04** | Tracker §5 "Known follow-ups" numbers **11–14 twice**. The second block was appended without renumbering. | Tracker §5 |
| **G-05** | Three merge commits have **no green deployment** at the exact commit: `cc4dee6` (Fly `43408590772` failed), `92213dd` (gate `43451505153` failed), `2e0360e` (gate `43455850715` failed). Each was followed by a green deploy, so the evidence chain works in aggregate but not per commit. | GitHub Actions |
| **G-06** | CP-001 is `COMPLETED` while every other package is not; the tracker row carries no approver and no date. The approval itself is in `DECISION-RECORD.md` (founder, 11 November). | Tracker §1 row CP-001 |
| **G-07** | CP-010's test plan claims lifecycle integration coverage — invalid email, short reason, unknown department, existing account, single-use token, attach, suspend, offboard. **No test file references `/control/staff`, `accept_staff_invite`, `offboard` or `attach_staff_profile`.** The files that exist cover the invite link, the rate limit, the email template and route registration. | `tests/` search, 14 November |
| **G-08** | **No `@Audience("staff")` controller exists.** Every controller is `control`, `app` or `partner`. `staff.support.handle` therefore authorises nothing, and CP-018 / CP-019 deliver support and verification handling on the `control` audience only. | `server/src/api/*.controller.ts` |
| **G-09** | `admin.list_departments` is gated by `admin.grant.read`/`admin.grant.manage`, but the Staff screen calls it to populate the invite form. A staff manager without a grant capability sees an error there. Recorded as follow-up 14 and still open. | Tracker §5, follow-up 14 |
| **G-10** | The 15 known follow-ups have **no owner, no date and no triage**. `AUD-58` expects the evidence index to be reviewed at each phase gate. | Tracker §5 |
| **G-11** | `pnpm test:db` cannot run locally (Docker unavailable), so all database evidence rests on CI. This is a known environment limit, not a defect. | Local environment |

## 6. Reconciliation with the 11 November assessment

The assessment recorded defects in the identity and authority layers. Several were fixed by later
packages; the register records which, so Phase 2 does not re-litigate resolved issues.

| Assessment defect | Current state | Basis |
|---|---|---|
| `adminRoles` is never populated, so five capabilities are permanently denied | **Resolved.** `adminRole` is deprecated and no rule populates it; rules use `permission`, composed from governance roles. | `capabilities.ts` — zero `adminRole:` entries |
| Admin grant scopes are only three | **Unchanged in SQL.** `identity.grant_scope_is_valid` still accepts three admin scopes. Whether that is intended now that roles supply the rest is a Phase 2 question. | `20261107001000_grant_management.sql` |
| No explicit deny | **Resolved.** Scope-aware denials compose in `composeAuthority`. | `admin/authorization.ts` |
| No separation of duties / approval model | **Resolved for account closure and case decisions.** | CP-020, CP-018, `approvals.test.ts` |
| Staff role model limited to one scope | **Unchanged, and now compounded by G-08.** | `identity.ts` `GRANT_SCOPES` |
| No resource-level scope | **Unchanged.** No resource attributes in `AccessContext`. | `capabilities.ts` |
| Partner model limited to one grant scope | **Partly resolved.** Partner governance adds `admin.partner.*` permissions via roles; the partner grant scope is still one. | CP-014 |

## 7. Review batches

Phase 2 ran on 14 November 2026 and is complete. The three records are `REVIEW-BATCH-A.md`
(CP-002 → CP-008), `REVIEW-BATCH-B.md` (CP-010 → CP-015) and `REVIEW-BATCH-C.md`
(CP-016 → CP-020). Eighteen findings were recorded; the two High and five Medium findings are fixed
on `staging`, and the rest are carried as follow-ups 20–27 in `EXECUTION-TRACKER.md`.

| Batch | Packages | Focus |
|---|---|---|
| **A** | CP-002 – CP-008 | Capability evaluation, RLS, deny paths, audit contract, admin schema |
| **B** | CP-010 – CP-015 | Staff lifecycle, personal data, role administration, partner isolation |
| **C** | CP-016 – CP-020 | Case spine, evidence, decisions, verification, approvals |

Each pass produces findings as `F-<batch>-<nn>` with a severity, the rule it breaches, and the
evidence. Confirmed findings become remediation pull requests in Phase 3; evidence and statuses are
reconciled in Phase 4.

## 8. Open questions for the founder

1. Adopt the three-state vocabulary in §3?
2. Is G-08 intentional — does support work belong in the control portal, with the staff portal
   reserved for a later release — or is `staff.support.handle` meant to gate a staff case queue now?
3. Should CP-005 – CP-008 get G0 records in the tracker, or is the P0 pack (refreshed) their record?
4. Which package does the review tackle first if the batch order is not acceptable?
