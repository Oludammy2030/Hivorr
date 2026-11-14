# Control Portal — Independent Review, Batch B

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/REVIEW-BATCH-B.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Date** | 14 November 2026 |
| **Scope** | CP-010 → CP-015 (staff, departments, roles, account governance, partners, partner isolation) |
| **Subjects** | `176054e` → `a7b4ca6` (CP-010), `d8f4b62` (CP-011), `cc4dee6` → `92213dd` (CP-012), `30b4964` (CP-013), `57f94b1` (CP-014), `5946647` + `48bfb2d` (CP-015) |
| **Class** | `[REVIEW]` — personal data, lifecycle revocation, partner isolation |
| **Reviewer** | Agent review pass under `DEV-002`; the author did not write these changes |
| **Status** | **6 findings — 2 medium, 2 low, 2 informational. No package signed off.** |

> This is a review record, not an approval. `COMPLETED` remains a founder act.

---

## 1. Method

Read directly at the merge commits, not from descriptions (`QUA-30`):

1. `admin.set_staff_status`, `admin.create_staff_invite`, `admin.accept_staff_invite`,
   `admin.get_staff_invite`, `admin.set_staff_department`, `admin.list_staff` as SQL.
2. `staff.service.ts` end to end, including the rate limiter and the email delivery path.
3. `invite.html` for token and response handling.
4. Account governance: `admin.govern_account` self-action and state guards.
5. Partner isolation: `admin.list_own_partner_organisations` and `PartnerPortalService`.
6. `appendAudit` actor classification, because staff actions label themselves `user`.

**Not verified:** staging runtime, the real database paths for staff (no staff integration suite
exists — G-07), and UI rendering of the Staff screen.

## 2. Findings

### F-B-01 — Medium — Offboarding leaves individual permission grants in place

`admin.set_staff_status` revokes sessions, then on `offboarded` revokes `identity.grants` and
`admin.role_assignments`, and ends department membership
(`20261113000100:295–316`). It never touches `admin.permission_grants`.

That table is read by `loadAdminAuthority` (`authorization.ts:166–177`) and is a first-class authority
source, not a legacy one. So a person offboarded while holding an individually-granted governance
permission — `admin.user.manage`, say — keeps it. Their sessions are revoked, but sign-in is not
blocked, so they can obtain a fresh session and the permission is still there.

This is not theoretical asymmetry: **CP-013 already handles it.** `admin.govern_account` revokes
`admin.permission_grants` on closure (`20261114000400:114`). Staff offboarding, written earlier,
predates that table being populated by any path, and was never revisited.

The tracker's CP-010 row claims "offboard with immediate revocation", and the G0 record says
"offboarding also revokes grants, role assignments and membership". Both are true of identity grants
and false of governance permission grants.

**Fix:** add the `permission_grants` revocation to `set_staff_status`, count it in the returned
`grants_revoked`, and add a test that an individual grant does not survive offboarding.

### F-B-02 — Medium — Staff status has no self-action or last-manager guard

`admin.set_staff_status` checks the capability and the target's existence, then acts. There is no
`p_user_id <> platform.current_user_id()` guard, and no check on how many platform holders of
`admin.user.manage` or `admin.role.manage` remain.

An operator can therefore suspend or offboard themselves. Offboarding revokes their own role
assignments and identity grants, including — if they are the last holder — the authority needed to
undo it. Recovery then needs direct database access.

Both neighbouring packages guard this:

| Package | Guard |
| --- | --- |
| CP-012 `assign_role` / `revoke_role` | `self_role_change_forbidden`, last role manager cannot be removed |
| CP-013 `govern_account` | `self_account_action_forbidden` |

CP-010 is the outlier. The impact is self-lockout rather than escalation, which is why it is Medium
and not High — but a governance portal should not depend on break-glass because someone clicked the
wrong row.

**Fix:** refuse self-target in `set_staff_status`, and refuse an `offboarded` transition that would
leave no platform holder of `admin.user.manage`.

### F-B-03 — Low — The audit before-state is silently empty for every target except the actor

`StaffService.setStatus` reads the previous state with a direct select inside the caller's
transaction:

```
select engagement_status from admin.staff_profiles where user_id = $1
```

`admin.staff_profiles` has RLS with the policy `staff_profiles_select_self`
(`20261111000500:239`), so for any target other than the caller this returns **no rows**. The audit
row then carries `beforeSummary: undefined`, and the record reads as though the previous status never
existed.

The change itself still happens, because the write goes through a security-definer function. Only
the evidence is degraded — which is exactly what an audit trail must not do.

**Fix:** return the previous status from `set_staff_status`, or read it through a narrow definer
function, and assert in a test that the before-state is present for another user.

### F-B-04 — Low — The staff lifecycle has no automated test at any level

CP-010's G0 record lists a test plan covering invalid email, short reason, unknown department,
existing account, single-use token, attach, suspend and offboard. No test file references
`/control/staff`, `accept_staff_invite`, `offboard` or `attach_staff_profile`; the only staff tests
cover the invite link builder, the acceptance rate limit and the email template.

With #103 merged, the database suites now run in CI — but CP-010 has no suite to run. The lifecycle
that creates identities, hashes passwords and revokes authority is asserted only by the migration
text checks and by hand on staging.

**Fix:** a `staff.test.ts` following `roles-integration.test.ts`: bootstrap a founder, invite with a
personal delivery address, assert the official address becomes the account, accept once and fail the
second time, offboard, then assert sessions, identity grants, role assignments **and permission
grants** are gone.

### F-B-05 — Info — Invite rate limiting is per process, not per deployment

`StaffService` holds a `FixedWindowRateLimiter` instance. The budget is therefore per API process;
with more than one Fly machine the effective limit multiplies, and a restart resets it.

Acceptance is unauthenticated and hashes the password before the token is validated, so the limiter
is the only bound on expensive work. On staging this is acceptable; at production scale the limiter
needs shared state.

**Fix:** record it as a known limit now; move to a shared store when the API runs more than one
instance.

### F-B-06 — Info — Acceptance makes the new staff user the owner of a fresh account

`admin.accept_staff_invite` creates a new `identity.accounts` row and an `owner` membership for the
staff user. That is consistent with "every user is an account owner" in the identity model, but it
gives every employee a consumer account with no activity, and it means an offboarded employee still
owns an account.

Nothing is exploitable here. It is recorded because the account is created implicitly, not by a
recognised onboarding action, and a future account-lifecycle feature will need to know that.

## 3. Controls confirmed sound

- **Partner isolation is genuinely parameterless.** `list_own_partner_organisations(p_user_id)` is
  keyed by the session user; the controller passes no organisation id, so there is nothing to tamper
  with. Terminated organisations disappear, and the endpoint is `@Audience("partner")` only.
- **The official-address rule is enforced in the database, not just the service.**
  `create_staff_invite` rejects any address whose suffix is not `@<work domain>`, so a bypassed
  service check still cannot create a personal-address staff identity.
- **Acceptance cannot be replayed.** The invite row is selected `for update` with
  `consumed_at is null`, `revoked_at is null` and `expires_at > now()`, then consumed in the same
  transaction. The token is stored as a hash and the page receives only the official address.
- **`get_staff_invite` does not leak the delivery address.** It returns email, job title, department
  and expiry, and only while the invitation is pending.
- **Account governance has both guards** — self-action refused and state transitions validated —
  which makes F-B-02 an inconsistency rather than a design position.
- **Self-service pages escape their output.** `invite.html` uses `textContent` for the account
  address, the TOTP secret and recovery codes; `innerHTML` is only used to clear.
- **Audit actor classification is centralised**, so staff actions recorded as `user` with a `control`
  audience are normalised to `admin` in one place (`platform/audit.ts:34–41`) rather than at each
  call site.
- **Departments carry no authority.** CP-011 adds a nullable `department_id` on grants and nothing in
  evaluation reads it; re-homing a grant is audited with a reason.

## 4. Package verdicts

| Package | Verdict | Reason |
|---|---|---|
| CP-010 | **REVIEWED WITH FINDINGS** — F-B-01, F-B-02, F-B-03, F-B-04, F-B-05, F-B-06 | The lifecycle works; revocation is incomplete and untested |
| CP-011 | **REVIEWED** | Departments are labels, correctly non-authoritative |
| CP-012 | **REVIEWED** | Self-change and last-manager guards present and tested |
| CP-013 | **REVIEWED** | Self-action guard and full revocation, including permission grants |
| CP-014 | **REVIEWED** | Partner register behind `admin.partner.*`, functions only |
| CP-015 | **REVIEWED** | Self-scoped read model, audience isolated, parameterless |

CP-010 is the only package in this batch that should not be signed off until F-B-01 and F-B-02 are
fixed. The rest are fit to move to `REVIEWED` once the Phase 4 evidence sync is done.

## 5. Recommended remediation

| Order | Item | Shape |
|---|---|---|
| 1 | F-B-01 | Small migration: revoke `admin.permission_grants` on offboarding, count it, test it |
| 2 | F-B-02 | Same migration: self-target refusal and last-manager guard in `set_staff_status` |
| 3 | F-B-04 | `staff.test.ts` covering the whole lifecycle, which also proves 1 and 2 |
| 4 | F-B-03 | Return the previous status from the function so the audit before-state is real |
| 5 | F-B-05, F-B-06 | Record as known limits; no code change now |

## 6. What Batch B did not cover

- Staging runtime behaviour and the Staff screen rendering.
- CP-012's migration as SQL beyond the guards (it was read for the guard pattern in Batch A).
- The partner governance functions' internal validation, which `partners.test.ts` exercises in CI
  and which passed on first run in #103.
