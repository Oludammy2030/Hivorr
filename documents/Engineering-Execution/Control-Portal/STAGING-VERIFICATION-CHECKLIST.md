# Control Portal — Manual Staging Verification Checklist

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/STAGING-VERIFICATION-CHECKLIST.md` |
| **Date** | 15 November 2026 |
| **Purpose** | Close the last evidence gap: a real pass on staging, behind Cloudflare Access |
| **Who runs it** | The founder, or a person explicitly authorised on the control host |
| **Why manual** | Staging is behind Cloudflare Access. No credential belongs in the repository, chat or an agent's environment |

> The local browser pass (#116) proved routing, layout and rendering against a mocked API. This
> checklist proves the parts a mock cannot: real sessions, the edge proxy, Cloudflare Access, live
> email delivery and the deployed database.

---

## 1. Before you start

| Check | Detail |
|---|---|
| Identity | The Cloudflare Access identity on the control host is **not** the Hivorr account. Access first, then sign in as the official `admin@hivorr.com` |
| Official address only | Any staff or admin identity must be an `@hivorr.com` address. A personal address is delivery-only |
| MFA | An authenticator app enrolled for the control account |
| Commit | Note the `staging` SHA you are verifying: `git rev-parse --short origin/staging` |
| Cold start | Fly scales to zero. The first request may take a few seconds; wait, then re-check before recording a failure |
| Scope | Use staff and test data only. No real customer identity, no real payment data |

**Never** paste a password, token, Cloudflare secret or TOTP code into a ticket, commit, chat or
screenshot. Record outcomes, not credentials.

## 2. Access and sign-in

- [ ] `control-staging.hivorr.com` prompts for Cloudflare Access before any portal content
- [ ] After Access, the portal shows **Sign in**, not a session
- [ ] Sign in with the official control address and password → MFA challenge
- [ ] A wrong TOTP is rejected; the correct one signs in
- [ ] The topbar shows the environment badge `staging`
- [ ] Sign out returns to the sign-in view and the session no longer works on refresh

## 3. Control portal — read paths

- [ ] **Overview** loads; capabilities listed match the account's roles
- [ ] **Users**: list paginates ("Load more" changes the rows); search narrows; status filter works
- [ ] **Users** detail shows notes and the account timeline; adding a note appears with a timestamp
- [ ] **Audit** lists entries; filters work; opening the screen writes a read record
- [ ] **Partners** lists the register; a detail opens
- [ ] **Cases** lists; filters by status and type; opening a case shows its timeline

## 4. Access — roles, grants, denials

- [ ] The Access page shows three tabs: **Roles**, **Grants**, **Denials**
- [ ] **Roles**: catalogue expands with permissions; assignments list
- [ ] **Grants**: a grant lists its department; the department drill-in filters
- [ ] **Denials**: the list renders; a revoked denial shows its lift reason
- [ ] **Create a denial** for a second test account on a harmless permission, with a reason
- [ ] The denied account loses that capability after its session refreshes
- [ ] The denial appears in **Audit** with operator, reason and capability
- [ ] **Lift** the denial with a reason; the capability returns; the lift is audited
- [ ] A denial of your own authority is refused with a clear message
- [ ] A duplicate active denial is refused as a conflict, not a server error

## 5. Staff lifecycle

- [ ] Invite a staff member: official `@hivorr.com` address plus a personal delivery address
- [ ] The response offers the single-use link even when email delivery is slow
- [ ] The invitation email arrives at the **personal** address only
- [ ] The email renders: brand mark, wordmark, working link, plausible expiry
- [ ] `/invite` opens, shows the **official** address locked, accepts a password and display name
- [ ] The same link is refused on second use
- [ ] The new account can sign in at the staff host and shows the session plus capabilities
- [ ] Suspending the staff member revokes their sessions immediately
- [ ] Offboarding revokes sessions, identity grants, individual permission grants and role assignments — verify by signing in and confirming the capability is gone
- [ ] The same operator cannot change their own staff status

## 6. Cases, evidence and decisions

- [ ] Create a case; it lands in the creator's department
- [ ] A second account outside that department **cannot** see it, and a direct URL answers not found
- [ ] Assign the case to the second account; it becomes visible to them
- [ ] Add a note and change the status; both appear on the timeline
- [ ] Attach evidence metadata; it lists with classification and hash
- [ ] A user with `admin.case.read` but without `admin.evidence.read` **cannot** read evidence
- [ ] Request a decision; the request appears in **Approvals**
- [ ] The requester cannot approve their own request
- [ ] A second administrator approves; the case reaches `DECIDED` with the recorded outcome

## 7. Account governance and approvals

- [ ] Request an account closure for a test account; it appears in **Approvals**
- [ ] Rejecting it leaves the account active with grants intact
- [ ] Requesting again and approving closes it and revokes what it should
- [ ] The direct `POST /users/{id}/close` answers `409`, not a closure

## 8. Verification review

- [ ] The verification queue lists review cases with evidence counts
- [ ] Approving a case **without** evidence is refused
- [ ] With evidence, approve/reject records a decision and a timeline event

## 9. Email and recovery pages

- [ ] Request a password reset; the email arrives at the official address with the shared layout
- [ ] `/reset` (the host 308-redirects `/reset.html`) opens and accepts the token
- [ ] A used or expired reset token is refused
- [ ] `/verify` opens from a verification email and confirms the address
- [ ] No email contains a bare token without a working link

## 10. Edge and failure behaviour

- [ ] An unauthenticated `/api/v1/control/*` call answers `401` or `403`, never `200`
- [ ] A control route opened on the staff host is refused
- [ ] An unknown path shows the portal's not-found state, not a blank screen
- [ ] No response body, header or error message echoes a secret, token or connection string
- [ ] Security headers are present (`content-security-policy`, `strict-transport-security`)

## 11. Mobile

For each portal page touched above, at 375×667:

- [ ] No horizontal page overflow
- [ ] The navigation is usable; the Access tabs wrap rather than push the page wide
- [ ] Wide tables scroll **inside** their panel, not the page

## 12. Record the result

Store one row per check in `evidence/staging-pass-<date>.md`, and screenshots as
`evidence/staging-<area>-<viewport>.png`. Screenshots are Git LFS objects: run
`git lfs push --all origin <branch>` before pushing, or the remote rejects the push.

| Field | Value |
|---|---|
| Date and time | |
| Operator | |
| Staging SHA | |
| API release | Fly release number, from `flyctl releases` |
| Result | pass / fail / blocked, per check |
| Failures | what happened, expected versus observed, screenshot name |
| Evidence files | |

Then update tracker follow-up 27 with the outcome: a pass closes it, a failure becomes a new finding
with its own id. A failure recorded honestly is worth more than a checklist that says "done".

## 13. What this pass still does not prove

- Production behaviour: different configuration, different database, different secrets
- Load or concurrency
- Disaster recovery — that is the restore drill in `PRODUCTION-READINESS.md` Phase 3
- Partner and staff portal depth: both are foundation shells, so only sign-in and session are in scope
