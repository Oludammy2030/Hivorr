# CP-010 — Staff Records and Lifecycle

| Field | Value |
|---|---|
| **Package** | CP-010 |
| **Status** | `REQUIRES_REVIEW` — database, API, control screen and invite page implemented |
| **Class** | `[REVIEW]` — authorization, personal data, schema |
| **Owning phase** | EP-02 |
| **Dependencies** | CP-002, CP-006 |
| **Approver** | Architect; founder for staff personal data and immediate revocation |

## 1. Objective

Give authorised administrators one staff lifecycle: invite, accept, assign a
department, suspend, reactivate and offboard. Offboarding revokes sessions,
grants, role assignments and department membership immediately, while the staff
record and audit history are retained.

## 2. Decisions applied

- Onboarding is **invite from control**, not public signup.
- Offboarding ends sessions **immediately**, in the same transaction.
- The first slice covers the **full lifecycle**; role assignment remains CP-012.

## 3. Scope in

- `admin.staff_invites` with a hashed, single-use token, expiry, reason, the
  official address that becomes the account, and the personal delivery address.
- `admin.list_staff` bounded read, gated by `admin.user.read`.
- `admin.create_staff_invite` gated by `admin.user.manage`.
- `admin.accept_staff_invite` creates the identity account, credential, owner
  membership, staff profile and department membership atomically.
- `admin.attach_staff_profile` for an existing Hivorr account that should
  become staff without a new invitation.
- Invitation email delivery through the ZeptoMail transactional API when a
  send-only token and sender are configured.
- `admin.set_staff_status` for active, suspended, leave and offboarded.
- `admin.set_staff_department` with an effective-dated membership.
- Immediate session revocation on suspension and offboarding.
- Grant, role-assignment and department-membership revocation on offboarding.

## 4. Scope out

- Role and permission assignment (CP-012).
- Approvals and maker-checker for destructive actions (CP-020).
- Staff performance or workload reporting (CP-041).
- Creating or suspending the mailbox itself. The official address is provisioned
  in the mail system first; the portal records it and ties the identity to it.
- Cloudflare Access group membership. Every staff identity and every invitee
  must be added there by the official address, never the personal one.

## 5. Design

| Concern | Decision |
|---|---|
| Invite token | 32 random bytes, stored only as a SHA-256 hash; single use; 7-day default expiry |
| Two addresses | `email` is the official company address Hivorr created (for example `firstname.lastname@hivorr.com`) and becomes the identity account. `delivery_email` is the personal address from the application and is used only to deliver the invitation. The API and the database both reject an official address outside `STAFF_EMAIL_DOMAIN` |
| Registration address | Acceptance never asks for an email, so the account can only be created with the official address. A personal address is never written to `identity.users` and cannot be used to sign in |
| Duplicate invite | One pending invite per email, enforced by a partial unique index |
| Existing account | Invite creation refuses an email that already has an identity account; the administrator adds that account as staff instead, which creates the profile and initial department membership without a new email or account |
| Acceptance | Creates account, user, credential, owner membership, staff profile and department membership in one transaction |
| Engagement status | `invited → active` on acceptance; `suspended`, `leave`, `offboarded` afterwards |
| Suspension | Revokes every active session for the user |
| Offboarding | Revokes sessions, grants, role assignments; closes department membership; sets `ended_on` |
| Department | Keyed by `admin.departments.key`; membership is effective-dated |
| Read model | Bounded to 200 rows, search by email/name/job title, status filter |
| Privilege | Every function re-checks `admin.actor_has_platform_permission`; the API role has no table privileges |
| Abuse control | Lookup and acceptance are unauthenticated, so both share the per-IP authentication rate limit before any hashing or lookup |
| Invitation email | ZeptoMail API with a send-only token; delivery runs after the invite commits, and a provider failure leaves the invite valid and the copy link available. Live on staging against the verified `mail.hivorr.com` sending domain. The message is a branded HTML layout with the inline brand mark and a plain-text fallback, built from the visual identity palette |

## 6. Test plan

- Migration run applies the table, indexes, functions and grants from empty.
- Function execution without the permission returns `42501`.
- Invite creation rejects an invalid email, a missing reason, an unknown
  department and an existing account.
- Invite creation rejects an official address outside the configured company
  domain, and delivers the invitation to the personal address while reserving
  the account for the official one.
- The acceptance page resolves a pending token to the official address; an
  expired, consumed or unknown token resolves to nothing.
- Acceptance consumes the token once; a second attempt returns not-found.
- Attaching an existing account creates the staff profile once; a second
  attempt and an unknown email are refused.
- Suspension revokes sessions; offboarding also revokes grants and role
  assignments.
- Department change closes the previous membership and opens one new row.
- The control route manifest exposes Staff only to `admin.user.read`, and the
  invite link points at the main portal rather than the control host.
- The ZeptoMail adapter sends the documented payload with a send-only token and
  fails without echoing the provider response; it stays on the capture adapter
  until a token and sender exist.

## 7. Audit impact

R2 personal and governance data: staff email, display name, job title,
department, engagement status and the operator who changed it. Every API action
must write an audit record with the reason, actor role and capability. No
evidence, financial or production data.

## 8. Rollback

Forward-only. Drop `admin.staff_invites` and the five functions in a later
approved destructive migration; existing identity accounts and staff profiles
remain valid. The API endpoints would then fail; redeploy the previous release
before dropping the functions.

## 9. Limits

- Invitations do not grant Cloudflare Access; the Access policy is separate and
  must include the staff email.
- Invitations only create new accounts. An existing account becomes staff
  through the "Add an existing account as staff" action.
- Email delivery stays off until `ZEPTOMAIL_TOKEN`, `MAIL_FROM_ADDRESS` and
  `PUBLIC_APP_ORIGIN` are set; until then the administrator sends the link.
- Invitations do not grant a Hivorr capability; CP-012 assigns roles.
- A suspended staff member keeps their account and can be reactivated.
