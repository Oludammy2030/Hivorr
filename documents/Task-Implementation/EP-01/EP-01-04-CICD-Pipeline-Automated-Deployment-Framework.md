# TASK IMPLEMENTATION PLAN: EP-01-04

## CI/CD Pipeline & Automated Deployment Framework

---

## Task Identification

| Field | Value |
|---|---|
| Task ID | EP-01-04 |
| Task Name | CI/CD Pipeline & Automated Deployment Framework |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Ready for Approval |
| Dependencies | EP-01-01 completed; EP-01-03 completed |
| Repository State | `.github/workflows/.gitkeep` exists; no workflows implemented |
| Current Branch | `master` |

---

## 1. Task Objective

Implement a secure GitHub Actions CI/CD framework that:

- Validates pull requests automatically.
- Runs formatting, analysis, tests, security checks, and platform builds.
- Deploys approved changes to Staging automatically.
- Promotes the exact staged commit to Production through explicit approval.
- Enforces Development → Staging → Production flow.
- Maps GitHub environment values to the EP-01-03 `--dart-define` configuration contract.
- Produces traceable, reproducible build artifacts without exposing secrets.

---

## 2. Business Problem Being Solved

Without automated CI/CD:

- Code quality checks may be skipped or applied inconsistently.
- Broken builds can reach staging or production.
- Development and production configuration may become contaminated.
- Production deployments may occur without staging validation.
- Release artifacts cannot be reliably traced to source commits.
- Manual deployment increases human error and recovery time.
- Future teams cannot safely scale releases across platforms and environments.

---

## 3. Scope

### In Scope

- GitHub Actions workflows under `.github/workflows/`.
- Pull request validation workflow.
- Staging build and deployment workflow.
- Production promotion workflow.
- Reusable workflow logic where it prevents duplicated validation behavior.
- Flutter and Dart toolchain setup using the approved SDK constraint.
- `flutter pub get`, formatting, analysis, testing, secret scanning, and builds.
- Web, Android, and iOS build validation where runners are available.
- Desktop build validation where supported by available runners.
- GitHub Environment separation for Development, Staging, and Production.
- GitHub branch protection requirements.
- Secure mapping of EP-01-03 variables to `--dart-define`.
- Artifact upload, checksum, provenance, retention, and rollback support.
- Deployment checks and post-deployment smoke validation.
- Workflow syntax and security validation.

---

## 4. Out of Scope

- Flutter application feature code.
- Changes to `lib/` production code.
- Changes to EP-01 or other approved planning documents.
- Supabase project provisioning.
- Database migrations, RPC functions, RLS policies, or backend deployment.
- Authentication, API, monitoring, or application bootstrap implementation.
- UI, UX, routing, or native platform feature work.
- Creation or storage of real credentials in the repository.
- Selection or provisioning of an unapproved hosting provider.
- App Store or Google Play account setup.
- Mobile store metadata, signing policy, or release management beyond CI build support.
- Industry-specific deployment pipelines.
- Final feature documentation.

---

## 5. Recommended Technical Approach

### 5.1 Deployment Flow

Use the repository's current `master` branch as the protected promotion branch unless the project lead approves a different branch model.

```text
Development branch
        |
        v
Pull request validation
        |
        v
Protected master merge
        |
        v
Automatic Staging build and deployment
        |
        v
Manual Production promotion of the same commit
```

Development is represented by local development and pull request validation. Staging deployment occurs only after successful required checks. Production deployment requires a protected GitHub Environment and approval.

### 5.2 Recommended Workflow Structure

| Workflow | Trigger | Responsibility |
|---|---|---|
| `pr-validation.yml` | Pull requests to `master` | Format, analyze, test, security checks, build validation |
| `staging-deployment.yml` | Successful push to protected `master` | Validate, build, publish artifacts, deploy to Staging |
| `production-promotion.yml` | Manual dispatch | Verify staged commit, require approval, build with Production config, deploy |
| `reusable-validation.yml` | `workflow_call` | Shared validation and build logic |

The reusable workflow should prevent PR, Staging, and Production pipelines from implementing different quality standards.

### 5.3 Pull Request Validation

The PR workflow should:

- Checkout the immutable pull request commit.
- Use Flutter stable compatible with Dart SDK `^3.12.2`.
- Cache Flutter and Pub dependencies using lockfile-based cache keys.
- Run `dart format --set-exit-if-changed`.
- Run `flutter analyze`.
- Run `flutter test`.
- Run repository secret and credential scans.
- Validate workflow syntax and action permissions.
- Build the Web target.
- Build Android and iOS targets where runner support is available.
- Avoid using Staging or Production secrets.
- Use safe test-only compile-time values where configuration defines are required.

### 5.4 Staging Deployment

The Staging workflow should:

- Run only after a successful merge to protected `master`.
- Reuse the same validation workflow used by pull requests.
- Build using `HIVORR_ENV=staging`.
- Obtain Staging configuration through GitHub Environment variables and secrets.
- Validate that the selected environment is exactly `staging`.
- Reject missing or inconsistent configuration.
- Publish artifacts tied to the source commit SHA.
- Deploy the approved artifact to the configured Staging target.
- Run post-deployment smoke checks.
- Record commit SHA, workflow run ID, artifact digest, environment, and deployment result.
- Prevent concurrent Staging deployments from racing.

### 5.5 Production Promotion

The Production workflow should:

- Be manually triggered.
- Accept an immutable staged commit SHA or approved release reference.
- Verify that the commit originated from protected `master`.
- Verify that the same commit successfully completed Staging deployment.
- Require approval from the protected `production` GitHub Environment.
- Build using `HIVORR_ENV=production`.
- Validate that the selected environment is exactly `production`.
- Never deploy directly from a pull request.
- Never accept arbitrary branch input for production deployment.
- Publish Production artifacts with provenance and checksums.
- Deploy only after approval.
- Run non-destructive post-deployment smoke checks.
- Preserve the previous successful artifact for rollback.

Because environment values are compiled into Flutter artifacts, the Production artifact must be rebuilt from the exact staged commit using Production configuration. It must not reuse a Staging-configured binary.

### 5.6 Environment Configuration Mapping

The pipeline must map the EP-01-03 variables directly to Flutter compile-time defines:

| Variable | Source |
|---|---|
| `HIVORR_ENV` | GitHub Environment variable |
| `HIVORR_SUPABASE_URL` | Environment-scoped variable or protected secret |
| `HIVORR_SUPABASE_ANON_KEY` | Environment-scoped protected value |
| `HIVORR_CONFIG_SCHEMA_VERSION` | Repository or environment variable |
| `HIVORR_FEATURE_*` | Environment-scoped variables |

Requirements:

- Do not create `.env` files inside workflows.
- Do not bundle `.env` files into artifacts.
- Do not pass Supabase service-role keys.
- Do not pass private backend secrets to Flutter builds.
- Validate expected environment identity before building.
- Fail closed when required values are absent.
- Mask sensitive values in workflow logs.
- Do not print full `--dart-define` command lines containing protected values.

### 5.7 Branch Protection

The `master` branch should require:

- Pull request approval before merge.
- Successful PR validation checks.
- Successful build checks.
- Stale approval dismissal after new commits.
- Resolved review conversations.
- No direct pushes.
- No force pushes.
- No deletion by ordinary contributors.
- Restricted deployment workflow permissions.
- Required status checks from the reusable validation workflow.

Production deployment should additionally require:

- Protected GitHub Environment reviewers.
- Restricted deployment branch.
- No self-approval where organizational policy supports that control.
- Serialized Production deployments.
- Complete deployment audit history.

### 5.8 Deployment Target

The approved architecture specifies GitHub Actions but does not identify a hosting or distribution provider.

The implementation should therefore use a provider-neutral deployment boundary. Before implementation, the project lead must approve at least one actual Staging and Production target, preferably Web hosting initially. Provider-specific credentials must be configured through GitHub Environments rather than committed files.

If no deployment target is approved, workflows may validate and publish artifacts, but the task cannot claim completed automated deployment.

---

## 6. Required Systems, Modules, and Components

| Component | Location or System | Responsibility |
|---|---|---|
| PR validation workflow | `.github/workflows/pr-validation.yml` | Automated quality gates |
| Staging workflow | `.github/workflows/staging-deployment.yml` | Staging build and deployment |
| Production workflow | `.github/workflows/production-promotion.yml` | Controlled production promotion |
| Reusable validation workflow | `.github/workflows/reusable-validation.yml` | Shared validation logic |
| GitHub Environments | GitHub repository settings | Environment isolation and approvals |
| Branch protection | GitHub repository settings | Merge and release controls |
| Flutter SDK setup | GitHub Actions runner | Reproducible toolchain |
| Dart formatter/analyzer/test | Flutter tooling | Code quality verification |
| Secret scanner | Approved CI security tooling | Credential leakage detection |
| Artifact storage | GitHub Actions artifacts or approved registry | Build and provenance storage |
| Deployment adapter | Approved hosting or distribution integration | Environment deployment |
| EP-01-03 configuration contract | `lib/config/environments/` | Compile-time configuration source |
| Platform runners | Ubuntu, macOS, Windows as required | Cross-platform build validation |

No new Dart application module is required.

---

## 7. Data Requirements

No business or user data is introduced.

The pipeline will produce operational metadata:

- Source commit SHA.
- Branch or release reference.
- Workflow run ID.
- Build number.
- Target environment.
- Artifact names and checksums.
- Test results.
- Deployment status.
- Deployment timestamp.
- Rollback reference.

Requirements:

- Do not use Production data for tests.
- Do not include secrets in artifacts or logs.
- Keep Staging and Production deployment credentials isolated.
- Apply an explicit artifact retention policy.
- Preserve enough metadata to reproduce or roll back a release.

---

## 8. Database Considerations

**Not applicable.**

This task must not:

- Provision Supabase projects.
- Run database migrations.
- Execute RPC functions.
- Modify RLS policies.
- Deploy database changes.
- Connect CI tests to Production databases.
- Require EP-01-05 or EP-01-06 functionality.

CI should remain capable of validating the Flutter project without a live backend.

---

## 9. API Requirements

No application API endpoints are introduced.

The workflow may interact with:

- GitHub Actions APIs.
- Artifact storage APIs.
- The approved deployment target API or CLI.

These integrations must remain isolated to workflow configuration. No Dio, Supabase client, authentication, or application network code should be added.

---

## 10. User Interface Requirements

**Not applicable.**

No Flutter widgets, screens, routes, or user-facing configuration controls should be changed.

---

## 11. User Experience Considerations

Developer and operator experience should include:

- Clear check names such as `format`, `analyze`, `test`, `build`, and `deploy-staging`.
- Explicit environment names in workflow summaries.
- Actionable failure messages that never reveal secrets.
- Links to generated artifacts and deployment results.
- Clear production approval prompts.
- Deterministic release behavior.
- Safe cancellation of obsolete PR and Staging runs.
- Serialized Production deployment behavior.
- Documented rollback references.

---

## 12. Security Considerations

- Pin third-party GitHub Actions to immutable commit SHAs.
- Use least-privilege job permissions.
- Default workflow permissions to read-only.
- Grant write permissions only to artifact or deployment jobs that require them.
- Use GitHub Environments for environment-scoped secrets.
- Do not expose secrets to pull request workflows from forks.
- Do not use `pull_request_target` for build or execution steps.
- Never pass service-role keys or private backend credentials to Flutter.
- Prefer OIDC federation over long-lived cloud deployment keys where supported.
- Mask protected values before any command execution.
- Avoid interpolating untrusted PR input into shell commands.
- Validate workflow dispatch inputs.
- Restrict Production deployment to approved branches and staged commit SHAs.
- Scan source and generated artifacts for credentials.
- Verify artifact checksums and provenance.
- Prevent workflow logs from printing configuration values.
- Keep separate deployment credentials for Development, Staging, and Production.
- Use concurrency controls to prevent conflicting deployments.
- Preserve GitHub audit records for approvals and deployments.
- Review workflow dependencies periodically for supply-chain changes.

---

## 13. Performance Considerations

- Cache Flutter and Pub dependencies.
- Use lockfile-based cache invalidation.
- Run independent validation jobs in parallel.
- Avoid repeating identical validation unnecessarily.
- Cancel obsolete PR runs.
- Serialize Production runs.
- Set explicit job and deployment timeouts.
- Upload artifacts once and reuse them where configuration permits.
- Rebuild Production from the same commit because compile-time environment values differ.
- Avoid live backend calls during ordinary PR validation.
- Measure build duration and artifact size.
- Monitor the 15–20 MB base installer target for applicable platform artifacts.
- Avoid adding CI-only runtime dependencies to the Flutter application.

---

## 14. Testing Strategy

| Test Area | Required Validation |
|---|---|
| Workflow syntax | Validate YAML and GitHub Actions syntax |
| Formatting | `dart format --set-exit-if-changed` |
| Static analysis | `flutter analyze` |
| Unit and widget tests | `flutter test` |
| Environment contract | Verify Development, Staging, and Production define mapping |
| Secret protection | Scan source, workflows, artifacts, and logs |
| PR isolation | Confirm PR workflows receive no Production secrets |
| Build validation | Web, Android, iOS, and supported desktop targets |
| Staging deployment | Verify deployment succeeds for the expected commit |
| Staging smoke test | Verify the deployed artifact is reachable and healthy |
| Production promotion | Verify only a successfully staged commit can be promoted |
| Approval enforcement | Verify protected Production approval is required |
| Rollback | Verify a prior artifact can be selected and redeployed |
| Concurrency | Verify obsolete PR/Staging jobs are cancelled safely |
| Artifact integrity | Verify checksums, names, metadata, and retention |
| Scope validation | Confirm no application, database, or phase-plan changes exist |

No test should depend on Production data or Production backend availability.

---

## 15. Recommended Implementation Sequence

1. Confirm EP-01-01 and EP-01-03 outputs remain intact.
2. Confirm the approved deployment target and deployment credential model.
3. Confirm the repository's protected branch policy using the current `master` branch.
4. Configure GitHub Environments for Development, Staging, and Production.
5. Configure branch protection and required status checks.
6. Define environment variables and secrets according to the EP-01-03 contract.
7. Define least-privilege workflow permissions.
8. Add the reusable Flutter validation workflow.
9. Add pull request validation triggers and checks.
10. Add cross-platform build validation.
11. Add repository secret scanning and workflow security checks.
12. Add automatic Staging build, artifact publication, deployment, and smoke checks.
13. Add manual Production promotion with exact staged commit verification.
14. Add Production approval, artifact provenance, and rollback support.
15. Validate workflow syntax and run CI against a controlled pull request.
16. Validate Staging deployment using isolated Staging values.
17. Validate Production promotion using a controlled release candidate.
18. Review logs and artifacts for secret leakage.
19. Measure pipeline execution time and artifact sizes.
20. Review the final diff for strict EP-01-04 scope containment.
21. Stop at the implementation approval gate.

---

## 16. Expected Outcome

- Pull requests automatically run formatting, analysis, tests, security checks, and builds.
- Changes merged to protected `master` automatically flow to Staging.
- Production deployment requires explicit approval.
- Production can only promote a commit already validated in Staging.
- Development, Staging, and Production configuration remain isolated.
- No private secrets or service-role credentials enter the Flutter client.
- Build artifacts are traceable, checksummed, and recoverable.
- Cross-platform build readiness is continuously verified.
- EP-01-19 and EP-01-20 receive a reliable CI/CD foundation.

---

## 17. Definition of Done (DoD)

- [ ] GitHub Actions workflows exist under `.github/workflows/`.
- [ ] Pull request validation runs automatically.
- [ ] Formatting validation passes.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Secret scanning passes.
- [ ] Web build validation passes.
- [ ] Android build validation passes where the runner is available.
- [ ] iOS build validation passes where the macOS runner is available.
- [ ] Supported desktop build validation is included or its limitation is documented.
- [ ] Staging deployment runs only after required checks pass.
- [ ] Staging uses only Staging configuration values.
- [ ] Production deployment is manually approved.
- [ ] Production promotion verifies the exact commit successfully staged.
- [ ] Production cannot be deployed directly from a pull request.
- [ ] Branch protection rules are configured and documented.
- [ ] GitHub Environments are isolated.
- [ ] Environment variables map to the EP-01-03 `--dart-define` contract.
- [ ] Missing or mismatched environment configuration fails closed.
- [ ] No `.env` files are generated or bundled.
- [ ] No service-role key or private backend secret is passed to Flutter.
- [ ] Workflow actions are pinned to immutable references.
- [ ] Workflow permissions follow least privilege.
- [ ] PR workflows do not receive protected deployment secrets.
- [ ] Artifact checksums and commit provenance are recorded.
- [ ] Artifact retention is configured.
- [ ] Production deployments are serialized.
- [ ] Rollback to a prior approved artifact is supported.
- [ ] Post-deployment smoke checks pass.
- [ ] Pipeline execution and artifact sizes are reviewed.
- [ ] No production Dart code was added or modified.
- [ ] No database, RPC, RLS, API, authentication, UI, or native implementation was added.
- [ ] The approved EP-01 phase document remains unchanged.
- [ ] `AGENT.md` and `ARCHITECTURE.md` remain unchanged.
- [ ] No unrelated working-tree changes were modified.
- [ ] An approved Staging and Production deployment target is configured.
- [ ] The final implementation is limited to EP-01-04.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** High due to reusable workflows, platform matrices, artifact handling, deployment sequencing, branch protection, and release promotion.
- **Business impact:** High because every future release depends on this delivery framework.
- **Security risk:** High because the task controls Production access, deployment credentials, environment isolation, and supply-chain execution.
- **Performance sensitivity:** Medium to high because CI duration, caching, runner cost, build time, and installer size must be controlled.
- **Data complexity:** Low because no business data or database schema is introduced.
- **Integration complexity:** High because GitHub Actions must integrate with Flutter tooling, EP-01-03 configuration, platform runners, artifact storage, and an approved deployment target.

`High` is appropriate because the task is security-sensitive and foundational, but it does not introduce complex business algorithms, financial logic, or database architecture requiring `Very High` or `Extremely High` reasoning.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the implementation phase will begin, executing the recommended sequence and delivering all specified outcomes.

---

> **Status:** Approved
>
> **Approval Note:** The task implementation plan has been reviewed and approved. This document serves as the single source of truth for EP-01-04 implementation.
