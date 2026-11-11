# Control Portal — P0 Handoff

| Field | Value |
|---|---|
| **Branch** | `feat/control-portal-p0` |
| **Commit** | `40d1883` — `feat(control): establish P0 governance foundation` |
| **Base** | `staging` |
| **Status** | Committed locally; **not pushed** (the environment could not resolve `github.com`) |
| **Review state** | `REQUIRES_REVIEW` — CI, independent review and staging verification outstanding |

---

## 1. PR title

`feat(control): establish P0 governance foundation`

## 2. PR body

### Summary

Establishes the P0 Control Portal foundation: scoped governance authorization, a corrected
administrative read path, an extended audit contract, the `admin` schema, and a routed
permission-aware control shell.

### What changed

- **Authorization:** hybrid RBAC/ABAC composition; roles as permission collections; individual
  grants; explicit scope-aware denials; expired assignments ignored; platform denials remove every
  scope, scoped denials remove only their scope.
- **User directory:** replaced the account-scoped read with `admin.list_users`, a narrow
  security-definer function that checks `admin.user.read` against `platform.current_user_id()`.
  Account RLS is unchanged. Every read is audited.
- **Audit:** added `reason`, `approval_reference` and `session_id`; filtered, cursor-paged reads;
  every audit read writes `admin.audit_read`.
- **Admin schema:** permissions, roles, assignments, denials, staff, departments, partner
  organisations, cases, evidence, findings, recommendations, decisions, actions, approvals, work
  items and versioned configuration.
- **Control shell:** `react-router` routes, permission-aware navigation, 404 and unauthorised states,
  and `GET /v1/control/authority`.
- **Governance:** decision record, administrative governance architecture, implementation plan,
  execution tracker, P0 evidence pack and database evidence log.

### Verification

| Command | Result |
|---|---|
| `pnpm typecheck` | PASS |
| `pnpm test` | PASS — 50 files, 356 tests, 31 skipped |
| `pnpm test:db` | PASS — 23 migrations on PostgreSQL 16.15 |
| `pnpm lint` | PASS — 20 known baseline, 0 new |
| `pnpm lint:boundaries` | PASS |
| `pnpm lint:migrations` | PASS |
| `pnpm format:check` | PASS |
| `pnpm docs:check` | PASS |
| `pnpm build:portals` | PASS |
| `pnpm build:server` | PASS |
| `pnpm openapi:generate` | PASS — 27 paths |
| `pnpm security:secrets` | PASS — clean |

### Security review notes

- No account-scoped RLS policy was relaxed.
- The user-directory function is `security definer`, pins `search_path = ''`, checks the actor from
  the session, and is executable only by `hivorr_api`.
- Every `admin` table has RLS enabled and forced; no API write grants were added.
- No secret, production data or hosted environment was touched.
- Residual: control shell still uses its local `foundation.css` palette; token extraction is a
  CP-007 follow-up.

### Review checklist

- [ ] `admin.list_users` cannot be reached without `admin.user.read`.
- [ ] Explicit denials behave per scope.
- [ ] Audit remains append-only and every read is audited.
- [ ] Admin tables have RLS and no write grants.
- [ ] Case/approval/configuration records have the intended immutability.
- [ ] Control routes and navigation match the approved IA.
- [ ] No duplicate capability, audit, role or design system was introduced.
- [ ] Migrations are forward-only and self-contained.

## 3. CI expectations

The pipeline should run, in order:

1. `pnpm check:toolchain`
2. `pnpm docs:check`
3. `pnpm lint`
4. `pnpm lint:boundaries`
5. `pnpm lint:migrations`
6. `pnpm typecheck`
7. `pnpm test`
8. `pnpm test:db` (or the CI database job)
9. `pnpm openapi:check`
10. `pnpm build:all`
11. `pnpm build:server`
12. `pnpm security:deps`, `pnpm security:secrets`

Expected: all green. If any migration test fails, do not merge.

## 4. Post-merge staging steps

1. Deploy the release artifact to staging.
2. Apply all 23 migrations.
3. Run `bootstrap-staging-admin.ps1` for the founder account to create the grants and founder role.
4. Sign in at `control-staging.hivorr.com`.
5. Verify:
   - Users lists more than the founder's own account.
   - The audit entry `admin.users_listed` exists.
   - The Audit screen loads and writes `admin.audit_read`.
   - Direct navigation to `/users` without the capability shows the unauthorised panel.
6. Record the staging artifact digest and evidence.

## 5. Open decisions before P1

- O-01 funds custody
- O-02 take rate
- O-03 escrow/dispute rules
- O-04 KYC tiers
- O-05 verification vendor
- O-06 retention/legal hold
- O-08 investigation authority limits
- O-11 export policy

## 6. Known residuals

- CI has not run on this commit.
- No independent reviewer has signed.
- Staging has not been deployed.
- Control shell token migration is partial.
- Session view does not yet compose governance permissions; the control shell uses
  `/v1/control/authority`.
- No staff/partner/case feature endpoints yet.

---

**End of handoff.**
