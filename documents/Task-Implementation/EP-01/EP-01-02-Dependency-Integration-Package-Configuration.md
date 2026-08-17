# TASK IMPLEMENTATION PLAN: EP-01-02

## Dependency Integration & Package Configuration

---

## 1. Task Objective

Integrate the approved foundational Flutter packages into `pubspec.yaml`, preserve reproducible dependency versions in `pubspec.lock`, and configure strict Dart/Flutter analysis rules in `analysis_options.yaml`.

The result must establish stable package boundaries for the API, routing, state, authentication, security, monitoring, and future application foundation layers.

---

## 2. Business Problem Being Solved

The current project only contains Flutter defaults:

- `cupertino_icons`
- `flutter_test`
- `flutter_lints`

Without the approved dependency ecosystem:

- Downstream infrastructure tasks cannot be implemented consistently.
- Package choices may become inconsistent across modules.
- Uncontrolled dependency versions can introduce security, compatibility, and build risks.
- Weak linting can permit unsafe null handling, dynamic typing, architectural drift, and poor maintainability.
- Unnecessary packages may increase the base installer beyond the 15–20 MB target.

---

## 3. Scope

### In Scope

- Review the existing Flutter/Dart dependency baseline.
- Integrate the confirmed foundational runtime packages:
  - `dio`
  - `go_router`
  - `provider`
  - `supabase_flutter`
  - `flutter_secure_storage`
  - `sentry_flutter`
- Preserve `flutter`, `cupertino_icons`, `flutter_test`, and `flutter_lints`.
- Add only SDK-supported localization dependencies if required by the approved localization foundation.
- Use exact, SDK-compatible direct dependency versions.
- Generate and validate `pubspec.lock`.
- Configure strict analyzer language settings and lint rules.
- Audit direct and transitive dependencies for:
  - SDK compatibility
  - platform support
  - security
  - licensing
  - maintenance health
  - package size
- Validate `flutter pub get`, `flutter analyze`, and `flutter test`.
- Perform available cross-platform build and package-size checks.

---

## 4. Out of Scope

- Implementing API clients, interceptors, repositories, authentication, routing, monitoring, or storage services.
- Initializing Supabase, Sentry, Dio, Provider, or secure storage in application code.
- Adding production Dart code or package imports.
- Selecting the local storage technology. SQLite, Hive, or Isar remain an EP-01-11 decision.
- Selecting notification, connectivity, encryption, SSL-pinning, or other unconfirmed plugin packages.
- Environment configuration or secret management implementation.
- Database schema, migrations, RPC, or RLS.
- Native permission or platform configuration changes.
- CI/CD workflow implementation.
- UI, UX, design system, or localization feature implementation.
- Modifying the approved phase document.
- Creating final feature documentation.

---

## 5. Recommended Technical Approach

### 5.1 Dependency Boundary Matrix

| Package | Intended Boundary | Purpose |
|---|---|---|
| `dio` | `lib/core/api/`, approved integration adapters | HTTP transport and future interceptor support |
| `go_router` | `lib/app/router/` | Deep links, route configuration, and SEO-friendly URLs |
| `provider` | `lib/app/`, `lib/data/providers/` | Application and data state propagation |
| `supabase_flutter` | Core API/auth/data infrastructure | Supabase Auth, PostgreSQL access, RPC, Realtime, and Storage |
| `flutter_secure_storage` | `lib/core/storage/`, `lib/core/security/` | Secure platform storage wrappers |
| `sentry_flutter` | `lib/core/logging/`, `lib/core/monitoring/` | Error reporting and performance telemetry |
| Existing Flutter SDK packages | Application and test layers | Flutter runtime and test support |

Business systems, deterministic engines, and presentation components must not directly depend on infrastructure implementation details.

### 5.2 Versioning Policy

- Keep the approved Dart SDK constraint `^3.12.2` unless compatibility testing proves it must change.
- Pin direct dependencies to exact versions verified against the available Flutter SDK.
- Do not use unapproved Git, local-path, or unpublished package sources.
- Generate `pubspec.lock` through Flutter tooling rather than manually editing it.
- Retain the lockfile in version control for reproducible application builds.
- Do not perform broad major-version upgrades unrelated to this task.

### 5.3 Package Selection Policy

Only confirmed foundational packages should be added.

The following remain deferred because their architecture or implementation task explicitly requires later evaluation:

- SQLite/Hive/Isar storage packages
- Connectivity packages
- Notification packages
- Encryption and SSL-pinning packages
- Mocking and code-generation packages

This prevents premature vendor lock-in and avoids adding native plugins before their owning task defines the required platform behavior.

### 5.4 Analyzer Configuration

Base `analysis_options.yaml` on `package:flutter_lints/flutter.yaml`.

Enable strict, maintainable analysis behavior, including:

- Strict casts
- Strict inference
- Strict raw types
- Explicit return types where appropriate
- Prohibition of `print` in production code
- Override and directive consistency
- Safe handling of asynchronous resources
- Avoidance of unnecessary dynamic calls
- Existing Flutter lint recommendations

Rules must not be enabled indiscriminately if they conflict with Flutter framework patterns or approved infrastructure boundaries. Any exception must be narrow, justified, and local rather than globally disabling analysis.

---

## 6. Required Systems, Modules, and Components

- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- Flutter SDK `^3.12.2`
- Dart analyzer
- Pub.dev package registry
- Existing project structure created by EP-01-01
- Existing Flutter smoke test
- Flutter package and build tooling

No new application modules or runtime services are required for this task.

---

## 7. Data Requirements

No business data, domain entities, DTOs, local records, or data transformations are introduced.

The only generated artifact is dependency metadata in `pubspec.lock`, including resolved versions and package integrity hashes.

---

## 8. Database Considerations

**Not applicable.**

Supabase is added as a client dependency only. No database connection, migration, schema, RPC, or RLS implementation is permitted in this task.

---

## 9. API Requirements

No API endpoints or network requests are implemented.

`dio` and `supabase_flutter` are configured as dependencies for later infrastructure work. No credentials, Supabase URLs, service-role keys, or client initialization may be added.

---

## 10. User Interface Requirements

**Not applicable.**

No UI changes are required.

The existing Flutter application and widget smoke test must continue to compile and run.

---

## 11. User Experience Considerations

**Not applicable.**

There is no user-facing feature in this task. Dependency integration must not alter application behavior, startup flow, visual design, navigation, or user-visible messaging.

---

## 12. Security Considerations

- Use only trusted, maintained package sources.
- Review direct and transitive dependencies for known vulnerabilities and suspicious ownership.
- Reject unnecessary Git or local-path dependencies.
- Commit the lockfile to prevent uncontrolled transitive upgrades.
- Do not add secrets, service-role keys, DSNs, certificates, or environment values.
- Supabase credentials must remain deferred to EP-01-03.
- Sentry initialization and PII redaction remain deferred to EP-01-14.
- Secure storage integration must remain behind `lib/core/storage/`; adding the package does not authorize direct use throughout the application.
- Review package licenses for compatibility with the project.
- Verify that no package introduces unauthorized tracking or telemetry before initialization.
- Confirm that no package weakens the zero-trust client boundary.

---

## 13. Performance Considerations

- Avoid duplicate HTTP, state-management, storage, or logging packages.
- Do not add future feature packages speculatively.
- Audit direct and transitive package size before and after integration.
- Measure release artifacts using the appropriate platform/build configuration.
- Compare package impact against the 15–20 MB base installer target.
- Confirm that no industry-specific modules or business-system packages are bundled.
- Avoid code-generation dependencies unless an approved task requires them.
- Confirm dependency resolution does not materially increase build time.

---

## 14. Testing Strategy

### 14.1 Dependency Resolution

- Run `flutter pub get`.
- Confirm all approved direct packages resolve successfully.
- Confirm no unauthorized package sources are present.
- Review the dependency graph with `flutter pub deps`.

### 14.2 Static Analysis

- Run `flutter analyze`.
- Confirm no errors, warnings, or newly introduced lint violations.
- Verify strict analyzer settings are active.

### 14.3 Regression Testing

- Run `flutter test`.
- Confirm the existing widget smoke test passes.
- Confirm no production source files were required merely to validate package installation.

### 14.4 Platform Compatibility

Where toolchains are available:

- Build Web.
- Build Android.
- Validate iOS and desktop compatibility through the appropriate supported environment or CI runner.
- Do not modify native platform configuration as part of this task.

### 14.5 Security and License Review

- Review direct and transitive package metadata.
- Check package maintenance status and known advisories.
- Confirm lockfile integrity hashes are present.
- Confirm no credentials or sensitive configuration are introduced.

### 14.6 Size Audit

- Record the baseline release artifact size.
- Measure the artifact after dependency integration.
- Record platform, build mode, and ABI details.
- Flag any material regression or breach of the approved installer target.

---

## 15. Recommended Implementation Sequence

1. Verify EP-01-01 scaffolding and record the clean baseline.
2. Confirm Flutter and Dart versions against the approved SDK constraint.
3. Inventory current direct and transitive dependencies.
4. Validate the approved package list for SDK, platform, security, licensing, and maintenance compatibility.
5. Update `pubspec.yaml` with only the approved foundational dependencies and exact compatible versions.
6. Resolve dependencies with Flutter tooling and regenerate `pubspec.lock`.
7. Configure strict analyzer language options and lint rules.
8. Run dependency graph, analyzer, and test validation.
9. Perform security, license, platform, and package-size audits.
10. Review the final diff to confirm only `pubspec.yaml`, `pubspec.lock`, and `analysis_options.yaml` changed.
11. Confirm no phase document, native configuration, environment file, or production Dart file was modified.
12. Stop at the approval gate before implementing any downstream infrastructure.

---

## 16. Expected Outcome

- `pubspec.yaml` contains the approved foundational package ecosystem.
- `pubspec.lock` provides reproducible dependency resolution.
- `analysis_options.yaml` enforces strict, maintainable Dart/Flutter standards.
- Dependency boundaries are clear for future implementation tasks.
- Package security, licensing, compatibility, and size risks are assessed.
- Existing Flutter tests and analysis pass.
- No runtime behavior or production feature code is introduced.

---

## 17. Definition of Done (DoD)

- [ ] Approved foundational packages are added to `pubspec.yaml`.
- [ ] Existing required Flutter and development dependencies remain functional.
- [ ] Direct dependencies use exact, SDK-compatible versions.
- [ ] No unapproved Git, local-path, or speculative dependencies are present.
- [ ] `pubspec.lock` is regenerated and reproducible.
- [ ] Strict analyzer settings are configured.
- [ ] `flutter pub get` passes.
- [ ] `flutter analyze` passes cleanly.
- [ ] `flutter test` passes.
- [ ] Available platform build checks pass.
- [ ] Dependency graph and transitive package sources are reviewed.
- [ ] Security and license review is complete.
- [ ] Package-size impact is measured against the 15–20 MB target.
- [ ] No secrets or environment-specific values are introduced.
- [ ] No database, API, UI, native, CI/CD, or production feature implementation is included.
- [ ] Only approved task files are modified.
- [ ] The EP-01 phase document remains unchanged.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Medium**

### Reasoning Level Justification

- **Technical complexity:** Medium. The task requires dependency compatibility analysis, version control, lint configuration, and multi-platform validation, but no business logic or complex algorithms.
- **Business impact:** High because these choices establish the package ecosystem for all later foundation work.
- **Security risk:** Medium due to transitive dependencies, Supabase client handling, secure storage, and telemetry packages.
- **Performance sensitivity:** Medium to high because package selection directly affects application size and build performance.
- **Data complexity:** Low. No application data or schema is introduced.
- **Integration complexity:** Medium because several cross-platform packages must coexist under Flutter SDK constraints.

Medium reasoning is consistent with the approved EP-01 plan while requiring careful review of package boundaries, security, compatibility, and size impact.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the implementation phase will begin, executing the recommended sequence and delivering all specified outcomes.

---

> **Status:** Approved
>
> **Approval Note:** The task implementation plan has been reviewed and approved. This document serves as the single source of truth for EP-01-02 implementation.
