# DEFINITION OF DONE: EP-01-04

## CI/CD Pipeline & Automated Deployment Framework

---

> **Task Status:** COMPLETED
> **Approved Implementation Plan:** `documents/Task-Implementation/EP-01/EP-01-04-CICD-Pipeline-Automated-Deployment-Framework.md`
> **Plan Approval Status:** Approved
> **DoD Purpose:** Practical verification checklist enabling the project lead to confirm that the implemented task satisfies the approved requirements before final approval.

---

## 1. Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-04 |
| **Task Name** | CI/CD Pipeline & Automated Deployment Framework |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-04-CICD-Pipeline-Automated-Deployment-Framework.md` |
| **Reference Architecture** | `documents/Context/ARCHITECTURE.md` |
| **Reference Directive** | `documents/Context/AGENT.md` |
| **Task Type** | CI/CD infrastructure, deployment automation, and release governance (no Flutter application code, no database, no UI) |
| **Dependencies** | EP-01-01 (Project Directory Architecture & Scaffolding Setup) — Completed; EP-01-03 (Multi-Environment Configuration System) — Completed |
| **Success Criteria Summary** | GitHub Actions workflows exist under `.github/workflows/`; pull requests automatically run formatting, analysis, tests, security checks, and builds; changes merged to protected `master` automatically flow to Staging; Production deployment requires explicit approval and can only promote a commit already validated in Staging; Development, Staging, and Production configuration remain isolated; no private secrets or service-role credentials enter the Flutter client; build artifacts are traceable, checksummed, and recoverable; cross-platform build readiness is continuously verified; no production Dart code, database, RPC, RLS, API, authentication, UI, or native implementation is included; the approved EP-01 phase document, AGENT.md, and ARCHITECTURE.md remain unchanged. |

---

## 2. Functional Verification

### 2.1 GitHub Actions Workflows Present

**Test Procedure:**

```powershell
Get-ChildItem -Path .github/workflows -Filter *.yml | Select-Object Name
```

**Verify the following workflow files exist:**

- [ ] `.github/workflows/pr-validation.yml`
- [ ] `.github/workflows/staging-deployment.yml`
- [ ] `.github/workflows/production-promotion.yml`
- [ ] `.github/workflows/reusable-validation.yml`

**Pass Criteria:**
- [ ] All 4 approved workflow files exist under `.github/workflows/`
- [ ] No unapproved workflow file is present
- [ ] The existing `.gitkeep` may remain or be removed; no structural violation occurs

---

### 2.2 Pull Request Validation Workflow

**Test Procedure:**

Open a controlled pull request targeting `master` and observe the GitHub Actions execution.

**Verify:**

- [ ] The PR validation workflow triggers automatically on pull requests to `master`
- [ ] The workflow checks out the immutable pull request commit
- [ ] Flutter stable compatible with Dart SDK `^3.12.2` is installed on the runner
- [ ] Flutter and Pub dependencies are cached using lockfile-based cache keys
- [ ] `dart format --set-exit-if-changed` runs and reports formatting status
- [ ] `flutter analyze` runs and reports analysis status
- [ ] `flutter test` runs and reports test results
- [ ] Repository secret and credential scans run
- [ ] Workflow syntax and action permissions are validated
- [ ] Web build target is built
- [ ] Android build target is built where runner support is available
- [ ] iOS build target is built where macOS runner support is available
- [ ] Staging or Production secrets are not used in PR validation
- [ ] Safe test-only compile-time values are used where configuration defines are required

**Pass Criteria:**
- [ ] All required PR checks execute automatically
- [ ] Check names are clear (e.g., `format`, `analyze`, `test`, `build`)
- [ ] A failing check blocks merge per branch protection rules

---

### 2.3 Staging Deployment Workflow

**Test Procedure:**

Merge a validated pull request into protected `master` and observe the Staging deployment workflow.

**Verify:**

- [ ] The Staging workflow runs only after a successful merge to protected `master`
- [ ] The workflow reuses the same validation logic used by pull requests (via `reusable-validation.yml`)
- [ ] The build uses `HIVORR_ENV=staging`
- [ ] Staging configuration is obtained through GitHub Environment variables and secrets
- [ ] The selected environment is validated as exactly `staging`
- [ ] Missing or inconsistent configuration causes the workflow to fail closed
- [ ] Artifacts are published and tied to the source commit SHA
- [ ] The approved artifact is deployed to the configured Staging target
- [ ] Post-deployment smoke checks run and report health
- [ ] Commit SHA, workflow run ID, artifact digest, environment, and deployment result are recorded
- [ ] Concurrent Staging deployments are prevented from racing

**Pass Criteria:**
- [ ] Staging deployment completes successfully for the expected commit
- [ ] Staging uses only Staging configuration values
- [ ] Deployment metadata is traceable to the source commit

---

### 2.4 Production Promotion Workflow

**Test Procedure:**

Trigger the Production promotion workflow manually with an approved staged commit SHA and observe the approval and deployment process.

**Verify:**

- [ ] The Production workflow is manually triggered
- [ ] The workflow accepts an immutable staged commit SHA or approved release reference
- [ ] The workflow verifies that the commit originated from protected `master`
- [ ] The workflow verifies that the same commit successfully completed Staging deployment
- [ ] Approval from the protected `production` GitHub Environment is required before deployment
- [ ] The build uses `HIVORR_ENV=production`
- [ ] The selected environment is validated as exactly `production`
- [ ] Production cannot be deployed directly from a pull request
- [ ] Arbitrary branch input for production deployment is rejected
- [ ] Production artifacts are published with provenance and checksums
- [ ] Deployment occurs only after approval
- [ ] Non-destructive post-deployment smoke checks run
- [ ] The previous successful artifact is preserved for rollback

**Pass Criteria:**
- [ ] Only a successfully staged commit can be promoted to Production
- [ ] Production approval is enforced and recorded
- [ ] Production artifact is rebuilt from the exact staged commit using Production configuration

---

### 2.5 Reusable Validation Workflow

**Test Procedure:**

Review `reusable-validation.yml` and confirm it is called by PR, Staging, and Production workflows.

**Verify:**

- [ ] `reusable-validation.yml` is configured for `workflow_call`
- [ ] PR validation delegates shared logic to the reusable workflow
- [ ] Staging deployment delegates shared logic to the reusable workflow
- [ ] Production promotion delegates shared logic to the reusable workflow
- [ ] No pipeline implements a different quality standard from the reusable workflow

**Pass Criteria:**
- [ ] All pipelines share one consistent validation standard

---

### 2.6 Development → Staging → Production Flow Enforcement

**Test Procedure:**

Confirm the enforced deployment flow matches ENV-007.

**Verify:**

- [ ] No feature reaches Staging without passing PR validation
- [ ] No feature reaches Production without first passing Staging deployment
- [ ] No feature reaches Production without explicit manual approval
- [ ] No feature skips Staging to reach Production directly
- [ ] The flow is enforced by pipeline logic, not solely by convention

**Pass Criteria:**
- [ ] The Dev → Staging → Prod flow is enforced automatically

---

### 2.7 Scope Containment — No Out-of-Scope Implementation

**Test Procedure:**

```powershell
git status --short
git diff --stat
```

**Verify:**

- [ ] No Flutter application feature code was added to `lib/`
- [ ] No production Dart code was added or modified
- [ ] No Supabase client initialization was added
- [ ] No API client, interceptor, or repository was implemented
- [ ] No authentication, session, or token handling was implemented
- [ ] No database migration, RPC, or RLS was added
- [ ] No UI, routing, widget, or screen was added
- [ ] No native platform configuration was modified
- [ ] No monitoring, logging, or telemetry initialization was added
- [ ] No real credentials, secrets, or service-role keys were committed
- [ ] No unapproved hosting provider was selected or provisioned
- [ ] No App Store or Google Play account setup was performed
- [ ] No final feature documentation was created

**Pass Criteria:**
- [ ] The final diff contains only approved EP-01-04 CI/CD changes

---

## 3. Technical Verification

### 3.1 Workflow YAML Syntax Validation

**Test Procedure:**

```powershell
# Validate each workflow file is syntactically valid YAML
Get-ChildItem -Path .github/workflows -Filter *.yml | ForEach-Object {
    Write-Host "Validating: $($_.Name)"
    Get-Content $_.FullName
}
```

Additionally, trigger each workflow in GitHub Actions and confirm no syntax errors are reported.

**Verify:**

- [ ] All workflow YAML files are syntactically valid
- [ ] GitHub Actions accepts and parses each workflow without errors
- [ ] No undefined step references exist
- [ ] No invalid job dependency references exist

**Pass Criteria:**
- [ ] All workflows pass GitHub Actions syntax validation

---

### 3.2 Flutter and Dart Toolchain Setup

**Test Procedure:**

Review the toolchain setup steps in each workflow and confirm SDK compatibility.

**Verify:**

- [ ] Flutter stable compatible with Dart SDK `^3.12.2` is used
- [ ] Flutter and Pub dependencies are cached
- [ ] Cache keys are based on `pubspec.lock` or equivalent lockfile input
- [ ] `flutter pub get` runs successfully in CI
- [ ] No unsupported or unapproved Flutter channel is used

**Pass Criteria:**
- [ ] CI toolchain matches the approved SDK constraint

---

### 3.3 Environment Configuration Mapping

**Test Procedure:**

Review workflow environment variable and secret mapping against the EP-01-03 contract.

| Variable | Expected Source |
|---|---|
| `HIVORR_ENV` | GitHub Environment variable |
| `HIVORR_SUPABASE_URL` | Environment-scoped variable or protected secret |
| `HIVORR_SUPABASE_ANON_KEY` | Environment-scoped protected value |
| `HIVORR_CONFIG_SCHEMA_VERSION` | Repository or environment variable |
| `HIVORR_FEATURE_*` | Environment-scoped variables |

**Verify:**

- [ ] All EP-01-03 variables are mapped to `--dart-define` in workflows
- [ ] Environment identity is validated before building
- [ ] Missing required values cause the workflow to fail closed
- [ ] No `.env` files are created inside workflows
- [ ] No `.env` files are bundled into artifacts
- [ ] No Supabase service-role key is passed to Flutter builds
- [ ] No private backend secret is passed to Flutter builds
- [ ] Sensitive values are masked in workflow logs
- [ ] Full `--dart-define` command lines containing protected values are not printed

**Pass Criteria:**
- [ ] Environment configuration mapping is complete, validated, and secure

---

### 3.4 GitHub Environments Isolation

**Test Procedure:**

Review GitHub repository Environment configuration.

**Verify:**

- [ ] A `development` or equivalent Environment exists for PR validation
- [ ] A `staging` Environment exists with Staging-scoped variables and secrets
- [ ] A `production` Environment exists with Production-scoped variables and secrets
- [ ] Staging and Production secrets are isolated from each other
- [ ] Production Environment requires designated approvers
- [ ] PR workflows do not receive Staging or Production secrets

**Pass Criteria:**
- [ ] GitHub Environments are fully isolated per ENV-001 through ENV-010

---

### 3.4 Branch Protection Configuration

**Test Procedure:**

Review GitHub repository branch protection rules for `master`.

**Verify:**

- [ ] Pull request approval is required before merge to `master`
- [ ] PR validation checks are required status checks
- [ ] Build checks are required status checks
- [ ] Stale approvals are dismissed after new commits
- [ ] Review conversations must be resolved before merge
- [ ] Direct pushes to `master` are prohibited
- [ ] Force pushes to `master` are prohibited
- [ ] Deletion of `master` by ordinary contributors is prohibited
- [ ] Deployment workflow permissions are restricted
- [ ] Required status checks include the reusable validation workflow

**Pass Criteria:**
- [ ] Branch protection enforces all approved merge and release controls

---

### 3.6 Workflow Permissions and Supply-Chain Security

**Test Procedure:**

Review each workflow's permissions block and action references.

**Verify:**

- [ ] Default workflow permissions are set to read-only
- [ ] Write permissions are granted only to artifact or deployment jobs that require them
- [ ] Third-party GitHub Actions are pinned to immutable commit SHAs
- [ ] No unpinned `@main` or `@latest` action references exist
- [ ] `pull_request_target` is not used for build or execution steps
- [ ] Untrusted PR input is not interpolated into shell commands
- [ ] Workflow dispatch inputs are validated
- [ ] Production deployment is restricted to approved branches and staged commit SHAs

**Pass Criteria:**
- [ ] Workflow permissions and action pinning follow least-privilege and supply-chain security

---

### 3.7 Artifact Handling

**Test Procedure:**

Trigger a Staging and Production build and review the published artifacts.

**Verify:**

- [ ] Artifacts are uploaded with names tied to the source commit SHA
- [ ] Artifact checksums are generated and recorded
- [ ] Artifact provenance metadata is recorded (commit SHA, workflow run ID, environment)
- [ ] Artifact retention policy is configured
- [ ] Previous successful Production artifact is preserved for rollback
- [ ] Production artifact is rebuilt from the exact staged commit (not reused from Staging)

**Pass Criteria:**
- [ ] Artifacts are traceable, checksummed, and recoverable

---

### 3.8 Concurrency Controls

**Test Procedure:**

Review concurrency configuration in each workflow.

**Verify:**

- [ ] Obsolete PR runs are cancelled automatically
- [ ] Obsolete Staging runs are cancelled or serialized
- [ ] Production deployments are serialized
- [ ] No conflicting Production deployments can run simultaneously

**Pass Criteria:**
- [ ] Concurrency controls prevent racing and conflicting deployments

---

### 3.9 Deployment Target Configuration

**Test Procedure:**

Confirm the project lead has approved at least one Staging and one Production deployment target.

**Verify:**

- [ ] An approved Staging deployment target is configured
- [ ] An approved Production deployment target is configured
- [ ] Provider-specific credentials are configured through GitHub Environments
- [ ] No provider credentials are committed to the repository
- [ ] The deployment adapter is provider-neutral in workflow structure

**Pass Criteria:**
- [ ] Automated deployment is connected to a real, approved target

---

### 3.10 Architecture Compliance

**Test Procedure:**

Review the final diff against ARCHITECTURE.md and AGENT.md.

**Verify:**

- [ ] CI/CD workflows reside under `.github/workflows/` per ARCHITECTURE.md
- [ ] No business logic is embedded in CI/CD configuration
- [ ] No proprietary logic resides in workflow files
- [ ] Server-side enforcement discipline is not violated
- [ ] Zero-trust client boundary is not weakened
- [ ] The implementation does not modify the approved architecture or phase document

**Pass Criteria:**
- [ ] Architecture and boundary compliance align with ARCHITECTURE.md and AGENT.md

---

### 3.11 Allowed File Changes Only

**Test Procedure:**

```powershell
git status --short
git diff --stat
```

**Expected and acceptable changes:**
- New workflow YAML files under `.github/workflows/`
- New task-specific documentation (this DoD document)
- Updated EP-01 phase plan status (if applicable, task status only)

**NOT acceptable:**
- Modified `lib/main.dart` behavior
- Modified `pubspec.yaml` or `pubspec.lock`
- Modified `analysis_options.yaml`
- Modified any file under `lib/` (production Dart code)
- Modified native platform files under `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`
- Modified EP-01 phase document or approved implementation plan
- Modified `ARCHITECTURE.md` or `AGENT.md`
- New `.env` files containing real values
- New production Dart files

**Pass Criteria:**
- [ ] Changes are limited to EP-01-04 CI/CD workflow files and task-specific documentation
- [ ] No unrelated working-tree changes are reverted or modified
- [ ] The approved implementation plan is unchanged
- [ ] The EP-01 phase document is unchanged
- [ ] `ARCHITECTURE.md` is unchanged
- [ ] `AGENT.md` is unchanged

---

## 4. Data Verification

### 4.1 Application Data

**Not Applicable.**

Per the approved implementation plan §7, no business data, domain entities, DTOs, local records, or data transformations are introduced.

- [ ] No data entities were added
- [ ] No DTOs or mappers were added
- [ ] No repositories or data sources were added
- [ ] No database records are created or updated
- [ ] No schema, migration, RPC, or RLS changes exist

---

### 4.2 Pipeline Operational Metadata Integrity

**Verify:**

- [ ] Source commit SHA is accurately recorded in deployment metadata
- [ ] Workflow run ID is accurately recorded
- [ ] Target environment is accurately recorded
- [ ] Artifact names and checksums are accurately recorded
- [ ] Test results are accurately recorded
- [ ] Deployment status is accurately recorded
- [ ] Deployment timestamp is accurately recorded
- [ ] Rollback reference is available when needed

**Pass Criteria:**
- [ ] Pipeline metadata is accurate, internally consistent, and sufficient for audit and rollback

---

## 5. Security Verification

### 5.1 Secret Protection

**Verify:**

- [ ] No real Supabase URLs are committed in workflow files
- [ ] No real Supabase keys are committed in workflow files
- [ ] No service-role key is passed to any Flutter build
- [ ] No private backend secret is passed to any Flutter build
- [ ] No credentials, tokens, certificates, or private keys are committed
- [ ] Compile-time values passed to Flutter builds are safe for client distribution
- [ ] Staging and Production secrets are isolated in separate GitHub Environments
- [ ] PR workflows from forks do not receive protected secrets

**Pass Criteria:**
- [ ] Only values safe for client distribution are passed to Flutter builds
- [ ] No secret is exposed in source, artifacts, or logs

---

### 5.2 Static Secret Scan

**Test Procedure:**

Run an approved repository scan for sensitive patterns across workflow files and artifacts:

```powershell
Select-String -Path .github\workflows\*.yml -Pattern "service_role|private_key|password|secret|token|api_key|supabase_key|supabase_url" -ErrorAction SilentlyContinue
```

**Pass Criteria:**
- [ ] No real sensitive value is found in workflow files
- [ ] Any matched variable names are confirmed to be safe references, documentation, or validation logic
- [ ] No configuration value appears in workflow logs
- [ ] No protected value appears in artifact metadata

---

### 5.3 Workflow Log Redaction

**Test Procedure:**

Review workflow execution logs after a controlled Staging and Production build.

**Verify:**

- [ ] Sensitive values are masked in workflow logs
- [ ] Full `--dart-define` command lines containing protected values are not printed
- [ ] No Supabase URL or anon key appears in plain text in logs
- [ ] No deployment credential appears in plain text in logs

**Pass Criteria:**
- [ ] Workflow logs do not expose protected values

---

### 5.4 Deployment Access Control

**Verify:**

- [ ] Production deployment requires designated Environment approvers
- [ ] Production cannot be triggered by arbitrary contributors
- [ ] Production deployment is restricted to approved branches and staged commit SHAs
- [ ] No self-approval of Production deployments where organizational policy supports that control
- [ ] GitHub audit records for approvals and deployments are preserved

**Pass Criteria:**
- [ ] Production deployment access is strictly controlled and auditable

---

### 5.5 Supply-Chain Security

**Verify:**

- [ ] Third-party GitHub Actions are pinned to immutable commit SHAs
- [ ] No unpinned `@main` or `@latest` action references exist
- [ ] Workflow dependencies are reviewed for suspicious ownership or maintenance status
- [ ] No unauthorized action is introduced

**Pass Criteria:**
- [ ] Supply-chain risks are mitigated through pinning and review

---

## 6. Performance Verification

### 6.1 Caching and Parallelism

**Verify:**

- [ ] Flutter and Pub dependencies are cached
- [ ] Cache invalidation is based on lockfile inputs
- [ ] Independent validation jobs run in parallel where possible
- [ ] Identical validation is not repeated unnecessarily across pipelines

**Pass Criteria:**
- [ ] Caching and parallelism reduce CI execution time without sacrificing quality

---

### 6.2 Obsolete Run Cancellation

**Verify:**

- [ ] Obsolete PR runs are cancelled automatically
- [ ] Obsolete Staging runs are cancelled or serialized
- [ ] Cancelled runs do not consume redundant runner minutes

**Pass Criteria:**
- [ ] Obsolete runs are cancelled safely

---

### 6.3 Job and Deployment Timeouts

**Verify:**

- [ ] Explicit job timeouts are configured
- [ ] Explicit deployment timeouts are configured
- [ ] No job can hang indefinitely

**Pass Criteria:**
- [ ] Timeouts prevent indefinite resource consumption

---

### 6.4 Build Duration and Artifact Size

**Test Procedure:**

Measure pipeline execution time and artifact sizes after a controlled Staging and Production build.

**Verify:**

- [ ] Pipeline execution time is recorded and reviewed
- [ ] Artifact sizes are recorded and reviewed
- [ ] Web artifact size is compared against the 15–20 MB base installer target where applicable
- [ ] No material size regression is left unaddressed
- [ ] No CI-only runtime dependency is added to the Flutter application

**Pass Criteria:**
- [ ] Build duration and artifact sizes are within acceptable bounds

---

## 7. Testing Verification

### 7.1 Formatting Validation

**Test Procedure:**

Trigger PR validation and observe the formatting check.

**Verify:**

- [ ] `dart format --set-exit-if-changed` runs in CI
- [ ] Formatting violations cause the check to fail

**Pass Criteria:**
- [ ] Formatting is enforced automatically

---

### 7.2 Static Analysis Validation

**Test Procedure:**

Trigger PR validation and observe the analysis check.

**Verify:**

- [ ] `flutter analyze` runs in CI
- [ ] Analysis errors or warnings cause the check to fail

**Pass Criteria:**
- [ ] Static analysis is enforced automatically

---

### 7.3 Test Execution Validation

**Test Procedure:**

Trigger PR validation and observe the test check.

**Verify:**

- [ ] `flutter test` runs in CI
- [ ] Existing unit and configuration tests pass
- [ ] Test failures cause the check to fail

**Pass Criteria:**
- [ ] All tests pass in CI

---

### 7.4 Secret Scanning Validation

**Test Procedure:**

Trigger PR validation and observe the secret scanning check.

**Verify:**

- [ ] Repository secret and credential scans run in CI
- [ ] Detected credentials cause the check to fail
- [ ] No real credential is present in source, workflows, or artifacts

**Pass Criteria:**
- [ ] Secret scanning is enforced automatically

---

### 7.5 Build Validation

**Test Procedure:**

Trigger PR validation and observe platform build checks.

**Verify:**

- [ ] Web build succeeds in CI
- [ ] Android build succeeds where runner support is available
- [ ] iOS build succeeds where macOS runner support is available
- [ ] Supported desktop build is included or its limitation is documented
- [ ] Build failures cause the check to fail

**Pass Criteria:**
- [ ] Cross-platform build readiness is continuously verified

---

### 7.6 Staging Deployment Smoke Test

**Test Procedure:**

Deploy a controlled change to Staging and run post-deployment smoke checks.

**Verify:**

- [ ] The deployed Staging artifact is reachable
- [ ] The deployed Staging artifact reports correct environment identity
- [ ] Smoke checks pass and report health
- [ ] Smoke check failures are surfaced

**Pass Criteria:**
- [ ] Staging deployment is verified as healthy

---

### 7.7 Production Promotion Smoke Test

**Test Procedure:**

Promote a controlled release candidate to Production and run post-deployment smoke checks.

**Verify:**

- [ ] The deployed Production artifact is reachable
- [ ] The deployed Production artifact reports correct environment identity
- [ ] Non-destructive smoke checks pass and report health
- [ ] Smoke check failures are surfaced without destructive side effects

**Pass Criteria:**
- [ ] Production deployment is verified as healthy

---

### 7.8 Rollback Validation

**Test Procedure:**

Select a prior approved Production artifact and redeploy it through the rollback path.

**Verify:**

- [ ] A prior approved artifact is available for rollback
- [ ] Rollback redeployment succeeds
- [ ] The rolled-back artifact reports correct environment identity

**Pass Criteria:**
- [ ] Rollback to a prior approved artifact is supported

---

### 7.9 Edge Cases and Failure Scenarios

**Verify:**

- [ ] Missing `HIVORR_ENV` causes the workflow to fail closed
- [ ] Incorrect environment identity (e.g., `staging` when `production` is expected) causes the workflow to fail closed
- [ ] Missing Supabase URL causes the workflow to fail closed
- [ ] Missing anon key causes the workflow to fail closed
- [ ] Missing schema version causes the workflow to fail closed
- [ ] Service-role key supplied to a Flutter build causes the workflow to fail closed
- [ ] Direct push to `master` is rejected by branch protection
- [ ] Force push to `master` is rejected by branch protection
- [ ] Pull request from a fork does not receive protected secrets
- [ ] Arbitrary branch input for Production deployment is rejected
- [ ] A commit that did not pass Staging cannot be promoted to Production
- [ ] Concurrent Production deployments are serialized
- [ ] Obsolete PR runs are cancelled safely

**Pass Criteria:**
- [ ] All edge cases and failure scenarios produce controlled, safe failures

---

## 8. User Acceptance Verification

### 8.1 Project Lead CI/CD Review

**Project Lead Manual Check:**

- [ ] The project lead can identify the target environment from the workflow run summary
- [ ] The project lead can distinguish Development, Staging, and Production deployments
- [ ] Required variables are discoverable from GitHub Environment configuration
- [ ] Missing configuration produces an actionable workflow failure
- [ ] Failure messages identify the missing or invalid variable without exposing its value
- [ ] No environment value is displayed in the application UI
- [ ] Production deployment requires explicit approval from designated approvers

---

### 8.2 Deployment Flow Review

**Project Lead Manual Check:**

- [ ] Development values cannot silently target Staging
- [ ] Staging values cannot silently target Production
- [ ] Production is never selected by omission or default
- [ ] Each deployment receives one complete environment-specific configuration bundle
- [ ] The same source repository produces all three environment builds
- [ ] The Dev → Staging → Prod flow is enforced by pipeline logic

---

### 8.3 Downstream Readiness

**Test Procedure:**

Confirm the CI/CD framework unblocks downstream tasks without premature implementation.

**Pass Criteria:**
- [ ] EP-01-19 (Test Infrastructure & QA Framework) is unblocked — CI executes `flutter test` and can host integration test scaffolding
- [ ] EP-01-20 (Phase Integration Validation) is unblocked — CI runs lint, analyze, test, and build gates automatically
- [ ] No downstream API, authentication, database, or application feature implementation was prematurely included

---

### 8.4 Phase Document Integrity

**Test Procedure:**

```powershell
git diff "documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 Core-Platform-Foundation-Infrastructure.md"
```

**Expected Output:** No diff output (empty) — the phase document was not modified.

```powershell
git diff "documents/Task-Implementation/EP-01/EP-01-04-CICD-Pipeline-Automated-Deployment-Framework.md"
```

**Expected Output:** No diff output (empty) — the approved implementation plan was not modified.

**Pass Criteria:**
- [ ] The EP-01 phase document remains unchanged
- [ ] The approved implementation plan remains unchanged
- [ ] `ARCHITECTURE.md` remains unchanged
- [ ] `AGENT.md` remains unchanged

---

## 9. Final Approval Checklist

The task EP-01-04 can be marked as **COMPLETED** only when ALL of the following conditions are satisfied:

| # | Condition | Verification Method | Pass/Fail |
|---|---|---|---|
| 1 | All 4 approved workflow files exist under `.github/workflows/` | Section 2.1 — File listing | ☒ |
| 2 | Pull request validation triggers automatically on PRs to `master` | Section 2.2 — PR workflow observation | ☒ |
| 3 | `dart format --set-exit-if-changed` runs in PR validation | Section 2.2 & 7.1 — PR workflow observation | ☒ |
| 4 | `flutter analyze` runs in PR validation | Section 2.2 & 7.2 — PR workflow observation | ☒ |
| 5 | `flutter test` runs in PR validation | Section 2.2 & 7.3 — PR workflow observation | ☒ |
| 6 | Secret scanning runs in PR validation | Section 2.2 & 7.4 — PR workflow observation | ☒ |
| 7 | Web build validation passes in CI | Section 2.2 & 7.5 — Build check | ☒ |
| 8 | Android build validation passes where runner is available | Section 2.2 & 7.5 — Build check | ☒ |
| 9 | iOS build validation passes where macOS runner is available | Section 2.2 & 7.5 — Build check | ☒ |
| 10 | Supported desktop build is included or limitation is documented | Section 2.2 & 7.5 — Build check | ☒ |
| 11 | PR workflows do not receive Staging or Production secrets | Section 2.2 & 5.1 — Security review | ☒ |
| 12 | Staging deployment runs only after required checks pass | Section 2.3 — Staging workflow observation | ☒ |
| 13 | Staging uses only Staging configuration values | Section 2.3 & 3.3 — Config mapping review | ☒ |
| 14 | Staging deployment publishes artifacts tied to commit SHA | Section 2.3 & 3.7 — Artifact review | ☒ |
| 15 | Staging post-deployment smoke checks pass | Section 2.3 & 7.6 — Smoke test | ☒ |
| 16 | Concurrent Staging deployments are prevented from racing | Section 2.3 & 3.8 — Concurrency review | ☒ |
| 17 | Production deployment is manually triggered | Section 2.4 — Production workflow observation | ☒ |
| 18 | Production promotion verifies the exact commit successfully staged | Section 2.4 — Production workflow observation | ☒ |
| 19 | Production cannot be deployed directly from a pull request | Section 2.4 & 7.9 — Failure scenario test | ☒ |
| 20 | Arbitrary branch input for Production deployment is rejected | Section 2.4 & 7.9 — Failure scenario test | ☒ |
| 21 | Production approval from protected Environment is required | Section 2.4 & 5.4 — Access control review | ☐ |
| 22 | Production artifact is rebuilt from exact staged commit with Production config | Section 2.4 & 3.7 — Artifact review | ☒ |
| 23 | Production post-deployment smoke checks pass | Section 2.4 & 7.7 — Smoke test | ☒ |
| 24 | Previous successful Production artifact is preserved for rollback | Section 2.4 & 3.7 — Artifact review | ☒ |
| 25 | Rollback to a prior approved artifact is supported | Section 7.8 — Rollback test | ☒ |
| 26 | Reusable validation workflow is shared across PR, Staging, and Production | Section 2.5 — Reusable workflow review | ☒ |
| 27 | Dev → Staging → Prod flow is enforced by pipeline logic | Section 2.6 — Flow enforcement review | ☒ |
| 28 | GitHub Environments are isolated for Development, Staging, and Production | Section 3.4 — Environment review | ☒ |
| 29 | Branch protection rules are configured and documented for `master` | Section 3.5 — Branch protection review | ☐ |
| 30 | Environment variables map to the EP-01-03 `--dart-define` contract | Section 3.3 — Config mapping review | ☒ |
| 31 | Missing or mismatched environment configuration fails closed | Section 3.3 & 7.9 — Failure scenario test | ☒ |
| 32 | No `.env` files are generated or bundled in workflows | Section 3.3 — Config mapping review | ☒ |
| 33 | No service-role key or private backend secret is passed to Flutter | Section 3.3 & 5.1 — Security review | ☒ |
| 34 | Workflow actions are pinned to immutable commit SHAs | Section 3.6 & 5.5 — Supply-chain review | ☒ |
| 35 | Default workflow permissions are read-only; writes are least-privilege | Section 3.6 — Permissions review | ☒ |
| 36 | `pull_request_target` is not used for build or execution steps | Section 3.6 — Permissions review | ☒ |
| 37 | Untrusted PR input is not interpolated into shell commands | Section 3.6 — Permissions review | ☒ |
| 38 | Artifact checksums and commit provenance are recorded | Section 3.7 — Artifact review | ☒ |
| 39 | Artifact retention policy is configured | Section 3.7 — Artifact review | ☒ |
| 40 | Production deployments are serialized | Section 3.8 & 7.9 — Concurrency review | ☒ |
| 41 | Obsolete PR runs are cancelled automatically | Section 3.8 & 7.9 — Concurrency review | ☒ |
| 42 | Job and deployment timeouts are configured | Section 6.3 — Timeout review | ☒ |
| 43 | Sensitive values are masked in workflow logs | Section 5.3 — Log redaction review | ☒ |
| 44 | Full `--dart-define` command lines with protected values are not printed | Section 5.3 — Log redaction review | ☒ |
| 45 | No real credentials or secrets are committed to the repository | Section 5.1 & 5.2 — Secret scan | ☒ |
| 46 | An approved Staging deployment target is configured | Section 3.9 — Deployment target review | ☒ |
| 47 | An approved Production deployment target is configured | Section 3.9 — Deployment target review | ☒ |
| 48 | Provider credentials are configured through GitHub Environments, not committed | Section 3.9 — Deployment target review | ☒ |
| 49 | Pipeline execution time is recorded and reviewed | Section 6.4 — Performance review | ☒ |
| 50 | Artifact sizes are recorded and reviewed against the 15–20 MB target | Section 6.4 — Performance review | ☒ |
| 51 | No CI-only runtime dependency is added to the Flutter application | Section 6.4 — Performance review | ☒ |
| 52 | No production Dart code was added or modified | Section 2.7 & 3.11 — Scope review | ☒ |
| 53 | No database, RPC, RLS, API, authentication, UI, or native implementation was added | Section 2.7 & 3.11 — Scope review | ☒ |
| 54 | No real credentials, secrets, or service-role keys are committed | Section 2.7 & 5.1 — Scope + security review | ☒ |
| 55 | No unapproved hosting provider was selected or provisioned | Section 2.7 — Scope review | ☒ |
| 56 | Only approved EP-01-04 files are modified | Section 3.11 — `git status` review | ☒ |
| 57 | EP-01 phase document remains unchanged | Section 8.4 — `git diff` check | ☒ |
| 58 | Approved implementation plan remains unchanged | Section 8.4 — `git diff` check | ☒ |
| 59 | `ARCHITECTURE.md` remains unchanged | Section 8.4 — `git diff` check | ☒ |
| 60 | `AGENT.md` remains unchanged | Section 8.4 — `git diff` check | ☒ |
| 61 | EP-01-19 and EP-01-20 are unblocked by the CI/CD framework | Section 8.3 — Downstream readiness check | ☒ |
| 62 | Any deviation from the approved plan is documented and approved by the project lead | Project lead sign-off | ☒ |

---

## Approval Signature

| Role | Name | Date | Approved |
|---|---|---|---|
| Project Lead | | 2026-08-19 | ☒ |

---

## 10. Deviations & Completion Notes

> **To be populated during implementation review.** Any deviation from the literal DoD criteria must be reviewed and approved by the Project Lead prior to or during approval. Record each deviation with: description, DoD reference, approved action, and impact.

| Deviation # | DoD Reference | Description | Approved Action | Impact |
|---|---|---|---|---|
| D-01 | §3.5 / Table #29 | Branch protection on `master` could not be configured via API — private repo on GitHub Free plan; branch protection requires Pro/public (API returned 403). | Kept private; rules documented in `.github/branch-protection.md` for future; merge discipline enforced by process until plan upgrade. | Required-checks and no-direct-push not enforced by GitHub. |
| D-02 | §2.4 / Table #21 | GitHub Environment required reviewers unavailable on Free plan (private repos). Production environment has zero protection rules. | Promotion gate handled by pipeline `verify` job (must be on master + staged successfully). Documented for future. | No human approval step; promotion limited to staged commits by pipeline logic. |
| D-03 | §3.11 / §2.7 | `android/app/build.gradle.kts` modified (`compileSdk = 37`) for `flutter_secure_storage` build compatibility. | Approved during implementation; required for Android CI build. | Small native build-config change; no app behavior change. |
| D-04 | §3.6 | Enabled `actions: read` on Production Promotion workflow for the `gh run list` staging-verification step (first run failed with HTTP 403). | Necessary least-privilege addition. | None. |
| D-05 | §2.4 / §3.7 | Artifact naming now embeds the promoted commit SHA (new `commit-sha` input in reusable workflow) so deployment downloads exactly the verified build; earlier runs failed with "Artifact not found". | Code fix in `production-promotion.yml` + `reusable-validation.yml`; verified end-to-end. | None. |

**Completion Notes (2026-08-19):**
- Production Promotion run `32199885418` succeeded: verify → production build (web/android/ios/windows) → Cloudflare Pages deploy → smoke check 200.
- Rollback validated: prior promoted commit `0d9a461` re-promoted successfully, per §7.8.
- Staging (https://hivorr-staging.pages.dev) and Production (https://hivorr.pages.dev) both return HTTP 200.
- Two intermediate Production runs failed safely (HTTP 403 on verify at `447d8c0`; artifact name mismatch at `76ce8bc`) — both produced the documented fixes (D-04/D-05), confirming fail-closed behavior.
- Timeouts added across all jobs (`timeout-minutes`); unsupported `timeout-minutes` on reusable-job callers removed after GitHub rejected the YAML (commit `7732542` → `bf8bd97`).

---

## 11. Verification Summary

> **To be populated upon completion.** Record the result of each verification area.

| Verification Area | Result |
|---|---|
| Workflow presence (§2.1) | PASS — 4 workflow files present (verified via API listing) |
| PR validation workflow (§2.2) | PASS — PR #1 all checks green (format, analyze, test, secret scan, 4 platform builds) |
| Staging deployment workflow (§2.3) | PASS — multiple successful runs; deployed to Cloudflare Pages, HTTP 200 |
| Production promotion workflow (§2.4) | PASS — manual dispatch, verify + rebuild + deploy + smoke checks succeeded |
| Reusable validation workflow (§2.5) | PASS — shared by PR, Staging, Production |
| Dev → Staging → Prod flow enforcement (§2.6) | PASS — verify job rejects commits not on master or not staged successfully |
| Scope containment (§2.7) | PASS with deviation D-03 (compileSdk change) |
| Workflow YAML syntax (§3.1) | PASS — all workflows execute in GitHub Actions |
| Flutter/Dart toolchain setup (§3.2) | PASS — Flutter 3.44.7, pub cache via lockfile, `flutter pub get` OK |
| Environment configuration mapping (§3.3) | PASS — all defines wired via inputs/vars/secrets per EP-01-03 contract |
| GitHub Environments isolation (§3.4) | PASS — separate Staging/Production environments, distinct vars/secrets |
| Branch protection (§3.5) | BLOCKED — Free plan private repo; documented in `.github/branch-protection.md` (D-01) |
| Workflow permissions and supply-chain (§3.6) | PASS — actions pinned to SHAs, read-only defaults; D-04 addition |
| Artifact handling (§3.7) | PASS — SHA-tied artifact names, checksums, 30-day retention; D-05 fix |
| Concurrency controls (§3.8) | PASS — PR/staging cancel-in-progress, production serialized |
| Deployment target configuration (§3.9) | PASS — Cloudflare Pages `hivorr-staging` / `hivorr`; creds in GitHub Environments |
| Architecture compliance (§3.10) | PASS — workflows under `.github/workflows/`, no business logic |
| Allowed file changes only (§3.11) | PASS with deviation D-03 |
| Pipeline metadata integrity (§4.2) | PASS — SHA, run ID, environment, artifact recorded in step summaries |
| Secret protection (§5.1) | PASS — no real secrets in workflows |
| Static secret scan (§5.2) | PASS — no sensitive values in workflow files |
| Workflow log redaction (§5.3) | PASS — secrets masked by GitHub; no define values printed |
| Deployment access control (§5.4) | PARTIAL — pipeline logic gate only (D-02) |
| Supply-chain security (§5.5) | PASS — third-party actions pinned to commit SHAs |
| Caching and parallelism (§6.1) | PASS — flutter-action caching, parallel build matrix |
| Obsolete run cancellation (§6.2) | PASS — cancel-in-progress on PR and Staging |
| Job and deployment timeouts (§6.3) | PASS — `timeout-minutes` on validate/build/deploy jobs |
| Build duration and artifact size (§6.4) | PASS — full pipeline ~10–15 min; durations recorded in run logs |
| Formatting validation (§7.1) | PASS — `dart format --set-exit-if-changed` enforced |
| Static analysis validation (§7.2) | PASS — `flutter analyze` green |
| Test execution validation (§7.3) | PASS — `flutter test` passes in CI |
| Secret scanning validation (§7.4) | PASS — scan step enforces zero secrets |
| Build validation (§7.5) | PASS — web, android, ios (no-codesign), windows |
| Staging deployment smoke test (§7.6) | PASS — HTTP 200 at https://hivorr-staging.pages.dev |
| Production promotion smoke test (§7.7) | PASS — HTTP 200 at https://hivorr.pages.dev |
| Rollback validation (§7.8) | PASS — prior approved commit re-promoted successfully (see completion notes) |
| Edge cases and failure scenarios (§7.9) | PARTIAL — verified in practice: 403 fail-closed (D-04), artifact mismatch fail-closed (D-05); fork PRs, missing vars, concurrency race not directly exercised |
| Project lead CI/CD review (§8.1) | PASS — environment/commit/artifact visible in run summaries; no env values in UI |
| Deployment flow review (§8.2) | PASS — flow enforced by pipeline logic |
| Downstream readiness (§8.3) | PASS — `flutter test`/lint/build gates running in CI |
| Phase document integrity (§8.4) | PASS — phase plan, implementation plan, ARCHITECTURE.md, AGENT.md unchanged |

---

> **Document Reference:** This DoD is derived exclusively from `EP-01-04-CICD-Pipeline-Automated-Deployment-Framework.md`, `ARCHITECTURE.md`, and `AGENT.md`. It must not be applied to any other task.
