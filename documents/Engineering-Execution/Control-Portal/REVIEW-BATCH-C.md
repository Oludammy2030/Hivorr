# Control Portal — Independent Review, Batch C

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/REVIEW-BATCH-C.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Date** | 14 November 2026 |
| **Scope** | CP-016 → CP-020 (case spine, evidence, case decisions, verification, approvals) |
| **Subjects** | `b467536` (CP-016), `a7fc3c4` (CP-017), `2441f6e` (CP-018), `eedefac` (CP-019), `9f215e3` (CP-020) |
| **Class** | `[REVIEW]` — irreversible decisions, evidence handling, separation of duties |
| **Reviewer** | Agent review pass under `DEV-002` |
| **Status** | **5 findings — 2 high, 1 medium, 2 informational. No package signed off.** |

> This is a review record, not an approval. `COMPLETED` remains a founder act.

---

## 1. Method

Read as SQL at the merge commits: `20261114000500` (approvals), `…0800` (case spine), `…0900`
(evidence), `…1000` (case decisions), `…1100` (verification), plus `evidence.service.ts` and
`cases.service.ts` for what the API actually calls.

The question this batch exists to answer: **does the portal implement the separation of duties it
claims?** The answer is yes at the decision boundary, and no at the visibility boundary.

## 2. Findings

### F-C-01 — High — Case access has no resource scope

`admin.list_cases` checks a platform permission and then returns **every case**:

```
if not (admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
     or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign'))
```

There is no `assignee_id = actor`, no `queue_key`, no department predicate. The same holds for
`admin.case_view` and for the case detail. `admin.case.read` is seeded with the description "Read
cases within the assigned scope"; no scope exists to read within.

Consequence: the `support_officer` role — described in the catalogue as "Handles support cases and
customer context within an assigned queue" — can open every case in the system, including
`investigation`, `staff_conduct`, `partner_conduct`, `security_incident` and `financial_exception`
cases. Case titles and descriptions are free text and will contain personal data.

This is the resource-scope gap the architecture assessment recorded as "No resource-level scope —
a permission is all-or-nothing across the module". CP-016 did not narrow it, and CP-017–CP-019
inherit it.

**This needs a design decision, not a patch.** The options are a queue/assignee predicate in every
case read, a department predicate, or an explicit statement that case visibility is
platform-wide for any case reader — with the role catalogue amended to say so. The third is the
cheapest and the most honest, and it should be written down either way.

### F-C-02 — High — Evidence is readable with the case permission, not the evidence permission

`admin.list_case_evidence` and `admin.record_evidence_access` both gate on `admin.case.read` or
`admin.case.assign` (`…0900:31–38`, `…0900:240–246`). `admin.evidence.read` — seeded as
**critical** sensitivity, "Read case evidence within scope", and granted to `verification_officer`,
`investigator` and `compliance_reviewer` — is checked by nothing.

So the roles that were deliberately **not** given evidence access can still read evidence metadata:
`support_officer` and `operations_officer` hold `admin.case.read` and will see file names, MIME
types, sizes, SHA-256 hashes, classification and uploader for evidence attached to any case. The
only thing protecting the content is that binary download does not exist yet.

That is the inverse of the intended model, and it is a one-line class of fix: require
`admin.evidence.read` in the evidence functions instead of `admin.case.read`.

### F-C-03 — Medium — "Recommend an outcome" is gated by the assignment permission

`admin.request_case_decision` requires `admin.case.assign`, not `admin.case.recommend`
(`…1000:44–46`). The request carries the `outcome` that the approver later records, so requesting a
decision *is* the recommendation.

`support_officer` and `operations_officer` hold `admin.case.assign` and not `admin.case.recommend`,
so they can recommend an outcome while the permission whose description is "Recommend a case outcome"
grants nothing. `admin.case.recommend` is held only by `investigator`, where it has no effect.

The approval boundary itself is sound — the approver must hold `admin.case.approve` at decision time
— so this does not bypass four-eyes. It misstates who may put a case forward.

### F-C-04 — Info — Seven governance permissions are declared and unenforced

| Permission | Enforced by |
|---|---|
| `admin.case.recommend` | nothing (F-C-03) |
| `admin.case.investigate` | nothing — CP-021 unbuilt |
| `admin.evidence.read` | nothing (F-C-02) |
| `admin.payment.review` | nothing — CP-031 unbuilt |
| `admin.dispute.resolve` | nothing |
| `admin.account.suspend` | nothing — suspension is `admin.user.manage` |
| `admin.configuration.write` | nothing — CP-022 unbuilt |
| `admin.report.export` | nothing — CP-035 unbuilt |

Most are legitimately forward-looking. The problem is presentational: `/v1/control/authority` turns
every one of them into a capability, and the control UI lists capabilities as authority. An operator
holding `admin.account.suspend` is told they can suspend accounts; the account endpoint instead
checks `admin.user.manage`.

**Fix:** mark unbuilt permissions in the seed description, or exclude them from the capability list
until the endpoint that checks them exists.

### F-C-05 — Low — "Every evidence access is audited" is not yet true

The G0 record for CP-017 says every access appends a timeline event, and `record_evidence_access`
does exactly that. But it is a separate call: `list_case_evidence` does not record anything, and the
API only writes an access event when the UI asks for one.

Until binary download exists, the metadata listing is the only access there is, and it is unaudited.
The claim should be scoped to "every recorded access", or the list should record access itself.

## 3. Controls confirmed sound

- **Four-eyes is real at the decision boundary.** Both approval variants refuse
  `requester_user_id = actor` inside the same `for update` lock, and the request row is locked before
  the status is checked, so a double decision cannot race.
- **The approval carries the authority, not the request.** At decision time the approver must hold
  both `admin.approval.decide` and the action permission — `admin.case.approve` for a case decision,
  `admin.user.manage` for an account closure. Requesting does not delegate.
- **Verification decisions are evidence-gated.** `record_verification_decision` refuses with
  `23514` when the case has no evidence, and requires a reason and a valid decision.
- **The case timeline is append-only** and every meaningful transition writes an event with the
  actor and a summary.
- **Evidence is immutable by construction.** `hivorr_api` holds no `UPDATE` or `DELETE` on
  `admin.case_evidence`; superseding writes `supersedes_id` and leaves the original intact.
- **Evidence listings do not leak the storage key** — file name, MIME type, size, hash,
  classification and uploader only.
- **Unsupported actions fail closed.** `decide_approval` raises on any `action_type` it does not
  implement rather than falling through.

## 4. Package verdicts

| Package | Verdict | Reason |
|---|---|---|
| CP-016 | **REVIEWED WITH FINDINGS** — F-C-01 | Spine, timeline and assignment are sound; visibility is unscoped |
| CP-017 | **REVIEWED WITH FINDINGS** — F-C-02, F-C-05 | Immutability is good; the read gate is the wrong permission |
| CP-018 | **REVIEWED WITH FINDINGS** — F-C-03 | Approval wiring is correct; the request gate is wrong |
| CP-019 | **REVIEWED** | Evidence gate, reason, and permission all enforced |
| CP-020 | **REVIEWED** | Self-decision, double-decision, action permission and fail-closed all present |

## 5. Recommended remediation

| Order | Item | Shape |
|---|---|---|
| 1 | F-C-02 | One migration: evidence functions require `admin.evidence.read`. Expect support and operations roles to lose evidence visibility — which is the intent — so the UI must handle the 403 |
| 2 | F-C-03 | Same migration: `request_case_decision` requires `admin.case.recommend` |
| 3 | F-C-01 | A decision, not a patch: queue/assignee scope, department scope, or a written statement that case visibility is platform-wide |
| 4 | F-C-04 | Documentation: mark unbuilt permissions, or filter them from the capability list |
| 5 | F-C-05 | Wording in the CP-017 evidence record |

## 6. What Batch C did not cover

- Staging runtime behaviour of the decision and verification flows.
- The Approvals and Cases screens beyond the capability calls they make.
- CP-021 (investigation workspace), which is where `admin.case.investigate` and `admin.evidence.read`
  on investigator cases become load-bearing.
