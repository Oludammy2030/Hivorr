# Work Package Record — EP-00-007
## Branch model, protected `main`, review settings and the bootstrap exception

| Field | Value |
|---|---|
| **ID** | `EP-00-007` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Enable protected `main`, required pull requests and status checks, linear history, no force-push and no self-approval; record the unavoidable first-commit bootstrap exception. |
| **Class** | `[REVIEW]` — repository protection and review enforcement (`QUA-29`–`QUA-31`). |
| **Status** | **`Blocked`** — GitHub rejects branch protection on a private repository on this account's plan. The block is a paid-plan/account capability, not an engineering defect. |
| **Origin** | `EP-00` §9; decision #18 (private repository, protected `main`); risk R6/R7; entry-record finding `F-05-05`. |

### What was attempted

1. **Read current protection** through the GitHub REST API:
   `GET /repos/Oludammy2030/Hivorr/branches/main/protection`.
   Result: `HTTP 403` with the body:

   ```json
   {"message":"Upgrade to GitHub Pro or make this repository public to enable this feature.","documentation_url":"https://docs.github.com/rest/branches/branch-protection#get-branch-protection","status":"403"}
   ```

2. **Read repository rulesets** through `GET /repos/Oludammy2030/Hivorr/rulesets`.
   Result: `HTTP 403` — the ruleset endpoint is unavailable for the same plan reason.

3. **Direct-push check.** Several ordinary `git push origin main` operations succeeded during this
   work (for example `6aac68f..673b71c` and `673b71c..1668c30`). A successful direct push is negative
   proof that `main` is **not** protected. No force-push was attempted against the real history,
   because it would be destructive; the capability is absent for the same reason.

4. **Repository visibility** is correctly `private`; the founder decision #18 forbids making it public
   to obtain the free feature.

### Why this is blocked, not failed

The control is a host capability. It cannot be installed from the repository, a workflow file or a
local hook. The only ways to satisfy it are:

- upgrade the owning account to **GitHub Pro** (paid), or
- change visibility to **public** (a founder decision that contradicts #18 and exposes the source),
  or
- move the repository to a host whose private-repository protection is free (a hosting change under
  decision #18).

None of those is an engineering action this agent can take without the founder's explicit approval
and, for the first option, payment.

### What is already true

- The first commit is the only justified direct-to-`main` bootstrap exception (R7).
- `v0.0.1-bootstrap` is an annotated tag on the reviewed root commit.
- CI exists and is green on the evidence commit.
- The settings that would be enabled are documented below, ready to apply the moment the host allows
  them.

### Required settings (ready to apply)

| Setting | Value |
|---|---|
| Require a pull request before merging | enabled |
| Required approvals | 1 (or the `DEV-001` compensating arrangement) |
| Dismiss stale approvals | enabled |
| Require review from Code Owners | not applicable until a CODEOWNERS file exists |
| Require status checks | `install`, `lint and format check`, `typecheck`, `test`, `build`, `secret and dependency scan` |
| Require branches to be up to date | enabled |
| Require linear history | enabled |
| Allow force pushes | disabled |
| Allow deletions | disabled |
| Require conversation resolution | enabled |
| Restrict who can push | maintainers only |
| Tag protection for `v0.0.1-bootstrap` | enabled where supported; otherwise recorded as a limitation |

### Bootstrap exception record

The root commit `8029466` and its tag were created while the repository had no protection and no
remote. That is the recorded one-time exception. It is not a precedent: from the next commit onward,
the intended rule is a pull request with a passing pipeline and a non-author approval. Because the
host cannot enforce it, the rule is currently **procedural only**, and that gap is the blocker.

### Evidence

- API `403` response quoted above, reproduced 2026-11-06.
- CI green run: <https://github.com/Oludammy2030/Hivorr/actions/runs/42257026623>.
- Direct pushes: `6aac68f..673b71c`, `673b71c..1668c30` on `main`.
- Repository metadata: `private=true`, `default_branch=main`.
- Entry-record finding `F-05-05` records the same 403 before this task started.

### Exit condition

The task moves to `Verified` only after the founder either upgrades the account or approves a
hosting/visibility change, the protection settings are applied through the API or UI, and the
following are demonstrated: rejected direct push, rejected force-push, blocked merge with a failing
or missing check, and rejected self-approval.

### Rollback

None required; nothing was changed. If protection is later enabled, rolling it back is a settings
change, not a code change.

### Approver

Founder (`[FOUNDER]` for the plan/payment decision) and architect for the settings export. `DEV-001`
does not extend to `G4`.
