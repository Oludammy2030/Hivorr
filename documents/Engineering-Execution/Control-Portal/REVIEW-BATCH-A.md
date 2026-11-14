# Control Portal — Independent Review, Batch A

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/REVIEW-BATCH-A.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Date** | 14 November 2026 |
| **Scope** | CP-002 → CP-008 (governance authorization foundation) |
| **Subject** | Merge commit `4e29364` — `feat(control): establish P0 governance foundation (#49)` |
| **Class** | `[REVIEW]` — capability evaluation, RLS, audit contract, admin schema |
| **Reviewer** | Agent review pass under `DEV-002`; the author did not write this change |
| **Status** | **7 findings — 2 medium, 3 low, 2 informational. No package signed off.** |

> This is a review record, not an approval. Under `DEV-002` the agent records the independent pass
> and the founder still reads the diff. A package moves to `COMPLETED` only on founder sign-off.

---

## 1. Method

The diff at `4e29364` was read directly, not from its description (`QUA-30`), in this order:

1. Migrations `20261111000100` → `20261111000600` as SQL (`DEP-18`), including grants, RLS and every
   function body.
2. Pure authorization logic: `server/src/domain/capabilities.ts`,
   `server/src/modules/admin/authorization.ts`.
3. Call sites that compose authority into a capability set: `control-authority.controller.ts`,
   `users.controller.ts`, `session.controller.ts`, `audit.controller.ts`.
4. The audience guard and the request pipeline around them.
5. The tests that claim to prove the controls: `control-p0-matrix`, `admin-authorization`,
   `admin-authorization-schema`, `admin-schema`, `capabilities`, `capability-registry`.

**Not verified in this pass:** staging runtime behaviour, the real database deny paths (`pnpm
test:db`, unavailable locally), and UI rendering. Those remain open.

## 2. Findings

### F-A-01 — Medium — Scoped permissions become whole-platform capabilities on two endpoints

`platformPermissions()` exists precisely to stop this, and the session view uses it
(`session.controller.ts:66`). Two other call sites do not:

| Call site | Folds in | Should use |
|---|---|---|
| `control-authority.controller.ts:62` | `authority.permissions` — every scope | `platformPermissions(authority)` |
| `users.controller.ts:98` | `authority.permissions` — every scope | `platformPermissions(authority)` |

Consequence, step by step:

1. A user is assigned a role containing `admin.user.read` with `scope_type = 'department'`.
2. `composeAuthority` correctly records it, and `permissions` contains `admin.user.read`, because a
   scoped allow is still an allow at some scope.
3. `GET /v1/control/users` folds that unscoped list into `computeCapabilities` and **passes** the
   `requireCapability` gate at `users.controller.ts:95`.
4. The request then calls `admin.list_users`, which checks
   `admin.actor_has_platform_permission('admin.user.read')` — platform scope only — and raises
   `42501`.
5. The controller calls the function directly, unlike every service that maps `42501`
   (`staff.service.ts:96`, `roles.service.ts:135`, and six others). Nothing maps it here, so the
   error filter returns **500**, not 403.

So the gate is weaker than the function behind it, and the failure mode is a server error rather
than a denial. It fails closed, which is why this is Medium and not High — but the UI also greys
nothing out, because `/v1/control/authority` reports the scoped permission as effective, so the
operator sees a screen they cannot use and cannot tell why.

This contradicts the invariant in `authorization.ts:208–213` and follow-up 1 of the tracker, which
states that only platform-scoped assignments are folded into capabilities.

**Fix:** use `platformPermissions` in both controllers, or add an explicit scope predicate. Add a
test asserting that `control/authority` and `users` never report a non-platform permission.

### F-A-02 — Medium — Explicit denials cannot be created, and cannot cover grant capabilities

Two separate defects share one root: the denial mechanism is modelled but unreachable and partial.

**a) Nothing can write `admin.access_denials`.** The table is created, RLS'd, read by
`composeAuthority`, and honoured in evaluation — but no function inserts into it, no endpoint touches
it, and no migration seeds it. It is dead capability. A denial can currently only be inserted by
hand at the database console, which is the one path with no audit row and no reason enforcement.
Against 20 packages of governance tooling, that is a control that reads as implemented and is not.

**b) Denials cannot express intent about grant-based capabilities.**
`admin.access_denials.permission_key` is a foreign key to `admin.permissions`
(`20261111000100:152`), and the three identity grant scopes — `staff.support.handle`,
`partner.referral.read`, `platform.engineering` — are not admin permissions, so they cannot be
denied. Evaluation compounds it: `evaluateCapability` checks `rule.grant` at line 358 and only
consults a denial at line 361, and only when `rule.permission` exists. So half the grant surface is
outside the "deny wins" rule the architecture states in §6.4.

Revocation is a valid answer for that half — you remove the grant. But then the rule is "deny wins
for permissions, revocation wins for grants", which is not what the architecture says and is not
written down anywhere.

**Fix:** either add the denial write path with an audit row and a reason, and document the
grant/denial split; or state explicitly that denials apply to governance permissions only and that
grant scopes are removed by revocation.

### F-A-03 — Low — Unescaped LIKE metacharacters in the directory search

`admin.list_users` interpolates the caller's query into `ilike '%' || v_query || '%'`
(`20261111000200:101–103`). It is parameterised, so there is no injection, but `%` and `_` are not
escaped: `q=%@hivorr.com` matches every address, and `q=_` forces a full scan of
`identity.users`. The result is bounded to 101 rows, so the data exposure is what the caller is
already entitled to; the cost is query time.

**Fix:** escape `\`, `%` and `_` and use `ilike ... escape '\'`.

### F-A-04 — Low — Audit "reason is required" is asserted in a comment, not in the schema

`20261111000400` adds `reason` and `approval_reference` as nullable columns and documents
"Required by the service layer for sensitive actions." Admission of the requirement stops at the
comment: no constraint, no trigger, no check in `appendAudit`. Every call site is trusted to pass
it, and `appendAudit` accepts its absence silently.

That is defensible for an additive migration that must not break historical rows. It becomes a real
gap when the audit contract is read as evidence — an audit row with no reason is indistinguishable
from a bug.

**Fix:** record the per-action reason requirement as a table or a constant enforced in
`appendAudit`, with a test that an action marked sensitive cannot be appended without one.

### F-A-05 — Low — The P0 matrix tests assert on SQL text, not on behaviour

`control-p0-matrix.test.ts` is valuable as drift protection, but several of its claims are string
matches against the concatenated migration SQL: "enables and forces RLS" asserts the words exist,
not that any policy denies. `rls-policy.test.ts` and `test:db` carry the behavioural half, and
`test:db` runs only in CI.

The tracker describes CP-008 as a deny/allow/RLS evidence pack. It is a good pack; the phrasing
implies runtime proof that the local run cannot produce.

**Fix:** wording only — state that behavioural RLS proof is the CI database job, and cite the run.

### F-A-06 — Info — The P0 evidence pack is stale and contradicts the tracker

`P0-EVIDENCE-PACK.md` still says **"PARTIAL — local code and tests verified; database run, CI and
independent review outstanding"** and covers CP-001 → CP-008 only. `4e29364` now has green CI
`43047734311`, a green Fly deployment `43047734163` and a green staging gate `43047734228`.

Two documents describing the same packages disagree, and the older one is the more conservative. It
should be marked superseded by this register rather than left to age further. This is the same gap
recorded as `G-01`/`G-02` in `REVIEW-REGISTER.md`.

### F-A-07 — Info — `admin.access_denials` has no removal record

The table has no `revoked_at`; the comment says a denial is "removed by an authorised operator",
which means `DELETE`. Governance history then depends entirely on the audit row that the (missing)
delete path would have to write. Combined with F-A-02a, there is no such path today.

**Fix:** decide whether denials are revoked (add `revoked_at`) or deleted with an audit row, and
implement one.

## 3. Controls confirmed sound

The review is not only a defect list. These held up under reading:

- **Audience enforcement is default-deny.** `AudienceGuard` rejects an undeclared route with 500,
  rejects an unrecognised host, and requires a shared edge secret before trusting a forwarded host
  (`audience.ts:84–131`). A spoofed `Host` alone does not select a portal.
- **Identity context is transaction-local.** `platform.current_user_id()` reads a GUC set with
  `set_config(..., true)` (`identity_rls.sql:29–32`), so it cannot leak across pooled connections.
  A missing context yields `null` and every policy fails closed.
- **RLS posture is strong.** Every admin table has `enable` and `force row level security`; the only
  `using (true)` policies are on reference data (permissions, roles, role_permissions). Sensitive
  tables — cases, evidence, approvals — have **no direct `SELECT` grant** to `hivorr_api` at all;
  access is only through security-definer functions.
- **No write grants.** `hivorr_api` holds no `INSERT`/`UPDATE`/`DELETE` on any admin table, so every
  mutation must pass an audited function.
- **Deny precedence is correct where it applies.** `evaluateCapability` checks `EXPLICIT_DENY`
  before `MISSING_PERMISSION` (`capabilities.ts:361–372`), so a denial cannot be masked by an
  absent allow.
- **Scope composition is correct and tested.** Union of allows, scoped denial removes only its
  scope, platform denial removes all scopes, expiry filters in SQL — all covered by
  `admin-authorization.test.ts:26–186`.
- **The user directory is a genuine narrow exception.** Bounded page size (`1..101`), stable cursor
  ordering, cursor validated against a UUID shape, domain errors as SQLSTATE, and the capability
  re-checked inside the database rather than trusted from the caller.
- **The audit trail stays append-only.** The update/delete trigger is untouched and the migration is
  additive.

## 4. Package verdicts

| Package | Verdict | Reason |
|---|---|---|
| CP-002 | **REVIEWED** with F-A-02, F-A-07 | Model, RLS and composition are sound; the denial half is unreachable |
| CP-003 | **REVIEWED** with F-A-02 | Registry complete, deny precedence correct, grant surface outside the deny rule |
| CP-004 | **REVIEWED WITH FINDINGS** — F-A-01, F-A-03 | Function is well built; the gate in front of it is wrong |
| CP-005 | **REVIEWED** with F-A-04 | Additive and safe; the reason requirement is documentation |
| CP-006 | **REVIEWED** | Strongest part of the change: forced RLS, no write grants, function-only access |
| CP-007 | **REVIEWED WITH FINDINGS** — F-A-01 | Shell is fine; the authority endpoint over-reports |
| CP-008 | **REVIEWED WITH FINDINGS** — F-A-05, F-A-06 | Evidence exists; the description overstates the runtime half |

No package moves to `COMPLETED` from this document. F-A-01 and F-A-02 need a decision before
remediation, because both are "fix the code" or "change the rule", not obviously one or the other.

## 5. Recommended remediation

| Order | Item | Shape |
|---|---|---|
| 1 | F-A-01 | One pull request: `platformPermissions` in both controllers, plus a regression test |
| 2 | F-A-02 | A decision first — add the denial write path, or document the split |
| 3 | F-A-03, F-A-04 | Small, independent, each with a test |
| 4 | F-A-05, F-A-06, F-A-07 | Documentation and tracker reconciliation in the Phase 4 pass |

## 6. What Batch A did not cover

- Staging runtime probes of the deny paths. `test:db` covers this in CI; it cannot run locally.
- The control UI beyond the capability list it consumes.
- CP-009's audit actor snapshot, which is the next batch boundary but shares CP-005's contract.

## 7. Addendum — CP-009 audit actor snapshot, reviewed 14 November 2026

CP-009 fell between the batch boundaries: Batch A ended at CP-008 and Batch B began at CP-010, so no
record covered it. That gap was mine, not the package's. It is reviewed here.

**Subject:** `458ffec` (#55) and `92d49a5` (#56); migrations `20261112000100` and `20261112000200`;
`server/src/modules/platform/audit.ts`; the `deploy-pages` job.

**What it does:** snapshots the actor's display name, email, governance role keys and role assignment
scopes onto each audit row at write time, adds the authorising capability, and publishes all four
portal bundles from the verified release artifact.

**Checked and sound:**

- **The snapshot is a snapshot, not a join.** `resolve_audit_actor` reads the actor's assignments
  once, when the row is written; a later role change does not rewrite history. Historical rows keep
  an empty array rather than a fabricated value, which is the correct choice for evidence.
- **Scope is captured, not just the role key.** `actor_role_scopes` records `{roleKey, scopeType,
  scopeId}`, so two holders of the same role are distinguishable after the fact.
- **The text signature is deliberate.** Moving from `uuid` to `text` means a background actor with a
  non-UUID identifier resolves to an empty snapshot instead of raising a cast error inside the
  caller's transaction — a failure that would have rolled back the audited action itself.
- **Actor classification is normalised centrally** once, which is why staff actions recorded as
  `user` with a `control` audience land as `admin`.
- **Deployment parity is real.** `deploy-pages` publishes the bundles from the verified artifact
  rather than rebuilding, so what ships is what was verified (`AUD-75`).

**F-A-08 — Info — `resolve_audit_actor` is an unguarded definer lookup**

`platform.resolve_audit_actor(text)` is granted to `hivorr_api` and returns the display name, email,
role keys and role scopes for **any** user id. The grant is necessary: the audit writer runs as
`hivorr_api` and must resolve the actor inside the same transaction. The function is narrow and its
purpose is documented.

It is recorded because it is the same shape as `admin.case_view` before #108 — a definer read of
personal data with no capability check, safe only because nothing calls it with hostile input. The
difference is that this one is used and cannot simply be revoked; if the writer ever moves to a
database role with different privileges, the grant should be revisited.

**Verdict:** CP-009 is **REVIEWED** with no defects and one informational note. It is a candidate for
sign-off.
