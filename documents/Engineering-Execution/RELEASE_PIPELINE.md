# Release Pipeline

**Status:** Release manifest generation, artifact verification, staging build-once, and founder
approval verification are implemented and tested. No hosted staging or production environment exists
yet, so rollout remains unconfigured. The pipeline verifies and records; it does not pretend to
deploy.

## 1. One release, one manifest

A release is one commit. It produces one `release-manifest.json` covering:

| Component | Source |
| --- | --- |
| `main` bundle | `dist/` excluding `dist/portals/` |
| `control` bundle | `dist/portals/control` |
| `staff` bundle | `dist/portals/staff` |
| `partner` bundle | `dist/portals/partner` |
| Backend source | `server/src` plus the API and worker entry-point digests |
| Migrations | `supabase/migrations` |

Each component records a SHA-256 tree digest, file count, and byte count. A tree digest hashes every
sorted relative path and the SHA-256 of its contents, so adding, deleting, renaming, or editing any
file changes the digest. A missing bundle directory is a failure, never an empty digest.

## 2. Commands

```bash
# Build the manifest for the current commit (CI uses this).
pnpm release:manifest --sha <40-hex> --ref staging

# Verify artifacts and source against a manifest.
pnpm release:verify --manifest release-manifest.json --sha <40-hex> --ref staging

# Verify founder approval for a production promotion.
GITHUB_TOKEN=... GITHUB_REPOSITORY=owner/repo \
  RELEASE_SHA=<40-hex> FOUNDER_GITHUB_LOGIN=<login> \
  pnpm release:approval
```

`verify-release-manifest` recomputes every digest from what is on disk. Any difference refuses the
release. Production runs it on the **downloaded staging artifact** and on the release commit's
backend source and migrations.

## 3. Staging flow

`.github/workflows/deploy-staging.yml` runs on every `staging` push after the merged-PR guard.

1. Build all four bundles once with `pnpm build:all`.
2. Generate `release-manifest.json`.
3. Verify the manifest immediately against the build.
4. Upload `staging-build-<sha>` and `release-manifest-<sha>` for 90 days.
5. If `STAGING_DEPLOY_TARGET` is configured, verify the backend target and create the
   `release-candidate` Issue with the manifest digests.

The Issue is created only after the build and manifest checks pass. It is created once per SHA; the
workflow does not duplicate an existing release issue.

## 4. Founder approval

Approval is a comment on the `release-candidate` Issue from the account in the
`FOUNDER_GITHUB_LOGIN` repository variable, whose first line is exactly:

```
/approve-release <40-character-release-sha>
```

The verification rules are:

- the Issue must carry the `release-candidate` label and reference the requested SHA in its body;
- a comment from any other account is ignored, even if it uses the command;
- a short SHA, extra words on the line, or the command on a later line is not accepted;
- the **latest** founder approval command wins, so a later approval of a different SHA supersedes an
  earlier one;
- approval of one release never authorises another.

## 5. Production flow

`.github/workflows/deploy-production.yml` is manual and **does not build**.

1. Require the founder actor, `DEPLOY_PRODUCTION`, and a 40-hex `release_sha`.
2. Verify the founder approval comment through the GitHub API.
3. Require `release_sha` to be an ancestor of `main`.
4. Resolve the successful `deploy-staging.yml` run for that exact SHA.
5. Download `staging-build-<sha>` and `release-manifest-<sha>` from that run.
6. Verify the downloaded artifact, backend source, and migrations against the staging manifest.
7. If `PRODUCTION_DEPLOY_TARGET` is configured, verify the production backend target.
8. Record the verified promotion.

Production never rebuilds. The artifact it verifies is byte-for-byte the artifact staging produced.

## 6. Rollback

A rollback is a promotion of the previous release's recorded artifact and manifest, not a rebuild.
The previous manifest is the rollback target; the same SHA, digest, and founder approval rules apply.

## 7. Tests

`pnpm test:release` builds a temporary artifact tree and proves:

- all four bundles, backend source, and migrations are recorded;
- digests are deterministic across runs;
- an edited bundle, an extra file, edited source, an extra migration, a wrong SHA, or missing
  artifacts are refused;
- approval parsing rejects short SHAs, trailing words, and later-line commands;
- non-founder approvals, wrong-SHA approvals, superseded approvals, unlabelled issues, and plain
  comments are refused.

CI runs this in the `test` job. `pnpm verify` also runs it.

## 8. Not yet implemented

- No staging or production host, DNS, Fly.io app, Cloudflare Access policy, or R2 bucket exists.
- The rollout step is intentionally absent; the workflows stop at verified promotion.
- `STAGING_DEPLOY_TARGET`, `PRODUCTION_DEPLOY_TARGET`, and `FOUNDER_GITHUB_LOGIN` are unset, so the
  staging release request and production target check are skipped rather than simulated.
- The eight-host topology is recorded in `config/environments.json` and checked by
  `pnpm topology:verify`. `TEC-12` is approved for staging; Fly apps and Pages projects exist, but no
  hostname resolves and no deployment exists. The sequence is in `STAGING_PROVISIONING.md`.
- There is no alerting on a failed manifest verification. The job fails closed; a human must act.
