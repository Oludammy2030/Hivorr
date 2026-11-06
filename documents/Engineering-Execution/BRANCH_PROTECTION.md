# Branch Protection and Push Policy

**Status:** Implemented 2026-11-06. Branch model approved by the project lead on 2026-11-06.
**Scope:** Local Git, GitHub repository configuration, CI, staging and production deployment gates.
**Not a claim of server-side enforcement:** GitHub Free does not provide branch protection or
repository rulesets for this private repository. See §5.

## 1. Branch model

| Branch | Role | Direct push | Update path |
|---|---|---|---|
| `main` | Production/release | **Blocked locally; detected in CI** | Pull request from `staging` |
| `staging` | Integration/staging | **Blocked locally; detected in CI** | Pull request from a working branch |
| `feature/*`, `fix/*`, `chore/*`, `docs/*`, `test/*` | Development | Allowed | Commit and push freely |
| `dependabot/*` | Bot updates | Allowed | Pull request into `staging` or `main` |

The canonical flow is:

```text
feature/*  --PR-->  staging  --PR-->  main
```

`main` and `staging` are listed once in `scripts/protected-branches.json`. The local hook and the
documentation read the same source.

## 2. Local pre-push control

`core.hooksPath` points at the committed `.githooks` directory. Enable it once per clone or worktree:

```sh
pnpm hooks:install
# or
git config --local core.hooksPath .githooks
```

`.githooks/pre-push` calls `scripts/pre-push.mjs`, which:

1. parses the refs Git is about to push;
2. rejects any create, update, force-push or deletion of `main` or `staging`;
3. rejects a non-fast-forward update to a protected branch;
4. runs the existing secret scan on every other push;
5. fails closed if Node is missing or the push description cannot be parsed.

Permitted work:

```sh
git switch -c feature/my-change
git add .
git commit -m "feat: my change"
git push origin HEAD:refs/heads/feature/my-change
```

Blocked work:

```sh
git push origin main          # rejected
git push origin staging       # rejected
git push --force origin main  # rejected
git push origin :main         # rejected
```

There is deliberately **no environment-variable bypass** in the hook. A bypass variable would be
disabled by the same accident it is meant to prevent, and an AI agent could set it. Emergency changes
use the documented GitHub UI path in §7.

## 3. CI-side guard (detection, not prevention)

GitHub Free cannot block the push at the server. `.github/workflows/branch-guard.yml` runs on every
push to `main` and `staging` and verifies that the pushed commit is associated with a **merged pull
request whose base is that branch**. If no such PR exists, the job fails.

This does not undo the push. It does:

- make a bypass visible in the Actions log and commit status;
- block the staging build/deployment gate, which depends on the same verification;
- block the production deployment workflow, which depends on it.

`scripts/verify-pr-merge.mjs` checks the **pushed commit itself** against the GitHub API. It
deliberately does not walk parent commits: a direct commit placed on top of a merged PR would
otherwise inherit that PR's association and pass. Merge-commit, squash-merge and rebase-merge
histories are handled because GitHub associates the resulting commit with the PR.

The guard was tested with both a merged commit (`3b1def3`, passes) and a pushed commit with no PR
(`b2e97c5`, fails).

## 4. Staging and production gates

### Staging

`.github/workflows/deploy-staging.yml` runs only on `staging` pushes.

1. `verify-pr` must pass — the push must come from a merged PR into `staging`.
2. `build-staging-artifact` builds the project and uploads `dist/` as a 14-day artifact.
3. The `staging` environment is recorded as an audit marker.
4. If `STAGING_DEPLOY_TARGET` is configured, the workflow records it. No staging host exists yet, so
   the current output states that the target is an EP-01 entry condition.

The gate is the approved-PR workflow. It does not invent a host or credentials.

### Production

`.github/workflows/deploy-production.yml` is **manual only** (`workflow_dispatch`). It requires all
of the following before it builds anything:

1. the actor equals the repository variable `FOUNDER_GITHUB_LOGIN`;
2. an explicit `approval_reference` is supplied;
3. the confirmation phrase is exactly `DEPLOY_PRODUCTION`;
4. the commit is linked to a merged Pull Request into `main`;
5. the run targets `main`.

The `production` environment is recorded. No production host exists in EP-00, so the workflow builds
and records the artifact rather than deploying it.

## 5. GitHub Free capability findings

Tested against the live repository on 2026-11-06:

| Capability | Result |
|---|---|
| Repository visibility | Private |
| Account plan | User / Free |
| Branch protection API | `403 — Upgrade to GitHub Pro or make this repository public to enable this feature.` |
| Repository ruleset API | `403` with the same upgrade message |
| Environment required reviewers | `422 — Please ensure the billing plan supports the required reviewers protection rule.` |
| Environment creation without reviewers | Allowed |
| Dependabot alerts / dependency graph | Available |

Sources: GitHub REST responses recorded in the EP-00 evidence and this document. No billing change was
made, and the repository was not made public.

## 6. Limitations under GitHub Free

These are stated so no reader mistakes the local hook for a server-side control:

1. A user with repository **write/admin** permission can push directly through the GitHub API, a
   different clone, or by disabling the local hook. GitHub Free will accept it.
2. A user can force-push or delete `main`/`staging` through the API. The local hook only sees local
   git pushes.
3. The CI guard detects a bypass after the fact; it cannot prevent it or undelete a branch.
4. Environment reviewer protection is unavailable, so the production workflow's founder check is
   **procedural**: it depends on `FOUNDER_GITHUB_LOGIN` and the founder keeping the account secure.
   An admin can change the variable.
5. Branch protection, required status checks and no-force-push rules become genuinely enforceable only
   with GitHub Pro, a GitHub Team/Enterprise plan, or a host that provides them for private
   repositories.
6. A commit SHA, a local secret or a hook cannot prove authorisation. Authorisation is the PR review
   and the founder decision.

The controls in this repository are therefore **defence in depth against accidental pushes**, not a
guarantee against a determined privileged actor.

## 7. Authorised maintainer management

- Normal change: working branch → pull request → review → merge.
- Staging: merge the working PR into `staging`; the staging gate runs automatically.
- Production: merge `staging` into `main` by PR; run the production workflow manually with the approval
  reference and confirmation phrase.
- Emergency only: a maintainer may use the GitHub UI merge path. Record the reason, the affected
  commit, the approver and the follow-up in the phase record. Do not disable the local hook as a
  shortcut, and do not force-push.
- If branch protection is later purchased or the host changes, apply the settings in
  `EP-00-007` and keep this local hook as an additional guard, not a replacement.

## 8. Tests and evidence

| Test | Expected | Evidence |
|---|---|---|
| Install hook | `core.hooksPath=.githooks` | `pnpm hooks:install` output |
| Push a permitted feature branch | Succeeds | Temporary bare-remote transcript |
| Push `main` directly | Rejected | Hook transcript |
| Push `staging` directly | Rejected | Hook transcript |
| Force-push `main` | Rejected | Hook transcript |
| Delete `main` | Rejected | Hook transcript |
| Secret-shaped content on a feature branch | Rejected by the secret scan | Existing EP-00 transcript |
| CI direct-push detection | Fails `verify-pr` | Guard test on unmerged `b2e97c5`; local transcript |
| PR-merged staging push | Passes `verify-pr` and builds artifact | Protected branch guard run 42264089981; Staging deployment gate run 42264089978 |
| PR-merged staging push (negative control) | Merged commit `3b1def3` passes the guard | `verify-pr-merge.mjs` output |
| Production without founder/confirmation | Refused | Manual workflow test |

## 9. Applied evidence — 2026-11-06

| Evidence | Result |
|---|---|
| `staging` created at `c7dd301`, the same SHA as `main` | No history rewritten; branch created through the GitHub API |
| PR #14 — `feature/push-protection` → `staging` | Merged as `3b1def3`; CI green 42263718088; guard 42264089981; staging gate 42264089978 |
| PR #15 — `fix/branch-guard-parent-walk` → `staging` | Merged as `708dad2`; CI green 42266139189; guard 42266769874; staging gate 42266769990 |
| PR #16 — `staging` → `main` | Merged as `d3b60d7`; CI green 42268369387; main guard 42268369409 |
| Permitted feature push | Succeeded (`test/evidence-permitted`, SHA `8fd53aa`), then branch deleted |
| Direct `main` push attempt | Rejected locally with `BLOCKED - direct update to a protected branch`; transcript retained |
| Guard on merged staging commit | Passed (`708dad2`) |
| Guard on unmerged commit | Blocked (`8fd53aa`) |
| Unit tests | 18 passed |
| Integration harness | 6/6 checks passed |

Sanitized transcripts are in
`documents/Engineering-Execution/evidence/branch-protection/`. They include the hook install, the
rejection, the permitted feature push, the merged/unmerged guard checks and the branch list.

The merged PRs confirm that the approved flow was used for this implementation itself: feature →
staging → main, with no direct push to either protected branch.

## 10. Rollback

- Remove the hook wiring: `git config --local --unset core.hooksPath`.
- Revert `.githooks/pre-push`, `scripts/pre-push.mjs`, `scripts/lib/push-policy.mjs`,
  `scripts/protected-branches.json`, `scripts/install-git-hooks.mjs` and the branch-guard/deployment
  workflows.
- Deleting `staging` is a structure change and requires approval. It is not part of a routine rollback.

No history is rewritten by any control in this document.
