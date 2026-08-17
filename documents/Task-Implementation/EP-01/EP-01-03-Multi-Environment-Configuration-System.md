# TASK IMPLEMENTATION PLAN: EP-01-03

## Multi-Environment Configuration System

---

## 1. Task Objective

Implement a secure, typed, immutable multi-environment configuration system for Development, Staging, and Production under `lib/config/`.

The system will:

- Load environment-specific values through Flutter compile-time environment variables.
- Keep Development, Staging, and Production configuration isolated.
- Provide Supabase URLs and public client keys without hardcoding values.
- Expose centralized feature flags and immutable application constants.
- Fail closed when configuration is missing, invalid, or ambiguous.
- Establish one configuration contract for all future application systems.

**Dependency:** EP-01-01 scaffolding, already present.

---

## 2. Business Problem Being Solved

Without centralized environment management:

- Development code may connect to Staging or Production resources.
- Credentials may be hardcoded or committed to source control.
- Environment checks may be duplicated across API, authentication, monitoring, and storage modules.
- Feature behavior may differ unpredictably between deployments.
- Future CI/CD automation cannot reliably select the correct environment.
- Production data and authentication systems risk accidental exposure.

---

## 3. Scope

### In Scope

- Typed Development, Staging, and Production environment profiles.
- Compile-time configuration loading through `--dart-define`.
- Centralized configuration models and validation.
- Supabase URL and public client key configuration.
- Environment-specific feature flags.
- Immutable application constants.
- Fail-closed validation for missing or malformed values.
- Environment configuration templates.
- `.gitignore` exceptions for safe example templates.
- Unit and configuration-boundary tests.
- Static checks for hardcoded secrets and unauthorized environment access.
- Documentation of the variable contract for future CI/CD integration.

---

## 4. Out of Scope

- GitHub Actions workflows or deployment gates, which belong to EP-01-04.
- Supabase project provisioning, database migrations, RPC, or RLS, which belong to EP-01-05 and EP-01-06.
- Supabase client initialization or API implementation, which belong to EP-01-07.
- Authentication, secure storage, encryption, SSL pinning, or Sentry initialization.
- Remote feature-flag services.
- UI, startup screens, environment selectors, or user-facing configuration controls.
- Native platform configuration.
- Business logic, domain models, database data, or API endpoints.
- Modification of the approved EP-01 phase document.
- Production feature documentation.

---

## 5. Recommended Technical Approach

### 5.1 Configuration Source

Use Flutter compile-time defines:

```text
--dart-define=HIVORR_ENV=development
--dart-define=HIVORR_SUPABASE_URL=https://...
--dart-define=HIVORR_SUPABASE_ANON_KEY=...
--dart-define=HIVORR_CONFIG_SCHEMA_VERSION=1
```

The implementation should use `String.fromEnvironment` only inside the environment loader.

Do not add a dotenv runtime package. Actual `.env` files should not be bundled as application assets. Environment templates document the variable contract, while local tooling and future CI/CD map environment variables to `--dart-define` values.

### 5.2 Proposed Configuration Structure

```text
lib/config/
├── app_config/
│   └── app_config.dart
├── constants/
│   └── app_constants.dart
├── environments/
│   ├── app_environment.dart
│   ├── environment_config.dart
│   ├── environment_config_exception.dart
│   ├── environment_loader.dart
│   └── environment_value_source.dart
└── feature_flags/
    └── feature_flags.dart
```

### 5.3 Configuration Model

Use one immutable configuration model with an explicit environment enum rather than duplicating three separate configuration implementations.

The aggregate configuration should contain:

- `AppEnvironment`
- `SupabaseConfig`
- `FeatureFlags`
- `AppConstants`
- Configuration schema version
- Production-state metadata derived from the environment enum

### 5.4 Environment Values

| Variable | Requirement |
|---|---|
| `HIVORR_ENV` | Required; exact values: `development`, `staging`, or `production` |
| `HIVORR_SUPABASE_URL` | Required valid HTTPS URL |
| `HIVORR_SUPABASE_ANON_KEY` | Required public client key; never a service-role key |
| `HIVORR_CONFIG_SCHEMA_VERSION` | Required supported configuration schema version |
| `HIVORR_FEATURE_*` | Typed feature flags with strict boolean parsing |

The loader must reject:

- Missing required variables.
- Unknown environment names.
- Invalid URLs.
- Placeholder values.
- Unsupported configuration schema versions.
- Malformed feature-flag values.
- Any service-role or server-secret configuration.

### 5.5 Environment Isolation Rules

- Environment selection is build-time only.
- Runtime users cannot switch environments.
- There is no fallback to Production.
- Missing or invalid configuration causes a controlled configuration error.
- Production-specific behavior is determined from the validated environment enum, not `kDebugMode`.
- Each build receives one complete environment-specific configuration bundle.
- Every consumer receives the immutable configuration object rather than reading environment variables directly.

### 5.6 Feature Flags

Feature flags should be:

- Centrally declared.
- Strongly typed.
- Parsed with strict boolean rules.
- Disabled by default where safe.
- Explicitly controlled per environment.
- Free of business logic and remote-fetch behavior.

No feature flag should silently enable experimental behavior in Production.

### 5.7 Constants

Application constants should contain only non-secret, globally stable values such as:

- Configuration schema version.
- Configuration variable names.
- Application identifiers.
- Safe immutable defaults.

Security-sensitive values must not be represented as source-level constants.

### 5.8 Environment Templates

Create placeholder-only templates such as:

```text
.env.example
.env.development.example
.env.staging.example
.env.production.example
```

Templates must contain variable names and documentation only. They must not contain real Supabase URLs, keys, credentials, tokens, or deployment secrets.

Update `.gitignore` so local environment files remain ignored while example templates remain trackable.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| Environment enum | `lib/config/environments/` | Defines supported environment identities |
| Configuration model | `lib/config/environments/` | Immutable typed environment data |
| Configuration loader | `lib/config/environments/` | Reads compile-time values and constructs configuration |
| Validation exception | `lib/config/environments/` | Reports safe, non-sensitive configuration failures |
| Testable value source | `lib/config/environments/` | Allows unit tests to inject values without compile-time flags |
| Application config façade | `lib/config/app_config/` | Provides one application-facing configuration contract |
| Feature flag model | `lib/config/feature_flags/` | Provides typed environment-specific flags |
| Application constants | `lib/config/constants/` | Stores non-secret immutable constants |
| Environment templates | Repository root | Documents required variable names |
| `.gitignore` | Repository root | Prevents local environment files and credentials from being committed |
| Flutter/Dart tooling | Project tooling | Resolves compile-time defines and validates builds |
| Test suite | `test/unit/` | Verifies loading, validation, and isolation behavior |

No new dependency is required.

---

## 7. Data Requirements

No business, user, domain, or persistent data is introduced.

The configuration object contains only deployment metadata:

- Environment identity.
- Supabase endpoint.
- Public Supabase client key.
- Configuration schema version.
- Feature flags.
- Immutable application constants.

Configuration must not be persisted to local storage, written to logs, sent to analytics, or included in error reports.

---

## 8. Database Considerations

Database implementation is not applicable.

The task only defines how a future client layer receives the correct Supabase endpoint and public client key. It must not:

- Provision Supabase projects.
- Connect to Supabase.
- Create schemas or migrations.
- Add RPC functions.
- Add RLS policies.
- Include service-role credentials.

Development, Staging, and Production endpoints must remain separate and supplied independently.

---

## 9. API Requirements

No API endpoints or network requests are implemented.

The configuration layer must expose a stable contract that future API and authentication modules can consume:

- Supabase URL.
- Public Supabase client key.
- Environment identity.
- Environment-derived operational flags.

Dio and Supabase initialization remain outside this task.

---

## 10. User Interface Requirements

Not applicable.

No widgets, screens, routing, startup UI, environment selectors, or environment labels should be added.

The implementation must not modify `lib/main.dart` or alter current application behavior.

---

## 11. User Experience Considerations

Although there is no end-user feature, developer and operator experience must be predictable:

- Build commands clearly identify the target environment.
- Missing configuration produces an actionable error naming the missing variable, without exposing its value.
- Production cannot be selected accidentally through a silent default.
- Environment templates make required variables discoverable.
- No environment value is displayed in the application UI.
- Configuration loading occurs once during application initialization when later bootstrap work consumes it.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Environment contamination | Explicit environment identifier and isolated build-time value bundle |
| Production fallback | Fail closed; never default to Production |
| Hardcoded credentials | No real values in Dart code, templates, or committed configuration |
| Client secret exposure | Accept only the public Supabase client key; reject service-role keys |
| Malformed configuration | Validate environment, URL, key, schema version, and booleans |
| Secret leakage through logs | Never include configuration values in exceptions, logs, or `toString()` output |
| Unauthorized access to configuration | Restrict direct environment-variable reads to the loader |
| Placeholder deployment | Reject known placeholder values during validation |
| Source-control leakage | Ignore local `.env` files and credential formats |
| Future configuration drift | Centralize variable names and configuration schema version |

Compile-time values are embedded in application artifacts. Therefore, only values safe for client distribution may be passed to the Flutter application. Private keys must remain exclusively server-side.

---

## 13. Performance Considerations

- Read compile-time values once.
- Avoid runtime `.env` file I/O.
- Avoid network-based configuration loading.
- Avoid adding a dotenv or configuration plugin.
- Store configuration in immutable objects.
- Avoid reparsing values on every access.
- Keep feature-flag evaluation centralized and inexpensive.
- Do not add native plugins or assets.
- Confirm the configuration layer has negligible impact on the 15–20 MB base installer target.

---

## 14. Testing Strategy

### 14.1 Unit Tests

Test the loader using an injectable value source:

- Valid Development configuration.
- Valid Staging configuration.
- Valid Production configuration.
- Missing environment identifier.
- Unknown environment identifier.
- Missing Supabase URL.
- Missing public key.
- Invalid URL format.
- Non-HTTPS URL rejection.
- Placeholder value rejection.
- Unsupported configuration schema version.
- Malformed feature-flag values.
- Production-safe feature-flag defaults.
- No Production fallback when values are missing.
- No sensitive values in exception messages.
- Correct environment-derived metadata.

### 14.2 Compile-Time Define Tests

Run configuration tests with representative `--dart-define` values for each supported environment. These tests must verify that the actual compile-time source behaves consistently with the injected test source.

No test may contact a live Supabase project.

### 14.3 Static and Security Checks

Verify that:

- `String.fromEnvironment` appears only in the approved loader.
- No Supabase service-role key exists in source or templates.
- No real credentials exist in the repository.
- No environment values are hardcoded in Dart code.
- Local `.env` files remain ignored.
- Example templates contain placeholders only.
- Configuration values are not logged or serialized.

### 14.4 Project Validation

Run:

```text
flutter analyze
flutter test
```

Where toolchains are available, run platform smoke builds without changing native configuration.

### 14.5 Scope Validation

Review the final diff and confirm that no API, database, authentication, UI, native, CI/CD, or unrelated production feature implementation was introduced.

---

## 15. Recommended Implementation Sequence

1. Inspect the existing scaffolding and preserve unrelated working-tree changes.
2. Define the approved environment variable names and configuration schema version.
3. Define the environment enum and immutable configuration models.
4. Define the testable environment value-source abstraction.
5. Implement compile-time value loading through `String.fromEnvironment`.
6. Implement strict validation and fail-closed error handling.
7. Implement typed feature flags with safe defaults.
8. Implement centralized immutable application constants.
9. Implement the application-facing configuration façade.
10. Add placeholder-only environment templates.
11. Update `.gitignore` to preserve templates while excluding real environment files.
12. Add unit tests for valid, invalid, and cross-environment cases.
13. Run static secret scans, `flutter analyze`, and `flutter test`.
14. Perform available platform smoke builds.
15. Review the final diff for scope containment and phase-document integrity.
16. Stop at the approval gate without implementing downstream API, CI/CD, or application bootstrap integration.

---

## 16. Expected Outcome

- Development, Staging, and Production configurations are independently selectable at build time.
- Required environment values are typed, validated, and centrally exposed.
- No environment silently falls back to another environment.
- No real secrets or service-role credentials are committed or embedded.
- Future systems have one stable configuration boundary.
- Feature flags and constants are centralized and maintainable.
- Environment templates are available without exposing credentials.
- Automated configuration tests and static analysis pass.
- No user-facing behavior or unrelated infrastructure is changed.

---

## 17. Definition of Done (DoD)

- [ ] `lib/config/environments/` contains the typed environment model and loader.
- [ ] Development, Staging, and Production are represented explicitly.
- [ ] Configuration is loaded through compile-time environment variables.
- [ ] Direct environment-variable access is confined to the loader.
- [ ] Supabase URL and public client key are validated.
- [ ] Service-role and private server keys are rejected and never accepted by the client configuration.
- [ ] Missing or invalid configuration fails closed.
- [ ] No Production fallback exists.
- [ ] Feature flags are typed and environment-aware.
- [ ] Immutable application constants are centralized.
- [ ] Configuration schema version is validated.
- [ ] Placeholder-only environment templates exist.
- [ ] Real `.env` files remain excluded by `.gitignore`.
- [ ] No real credentials, keys, tokens, or secrets are committed.
- [ ] Unit tests cover all supported environments and failure cases.
- [ ] `flutter analyze` passes cleanly.
- [ ] `flutter test` passes cleanly.
- [ ] Available platform smoke builds pass.
- [ ] No Supabase initialization, API client, database, RPC, RLS, authentication, UI, native, or CI/CD implementation is included.
- [ ] The approved EP-01 phase document remains unchanged.
- [ ] The final diff contains only approved EP-01-03 changes.
- [ ] The configuration contract is ready for EP-01-04 and downstream foundation tasks.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Requires compile-time configuration design, typed models, validation, testability, and multi-platform build handling.
- **Business impact:** Critical because every future system depends on correct environment selection.
- **Security risk:** High due to environment contamination, credential leakage, and accidental Production access.
- **Performance sensitivity:** Medium because configuration must not add runtime I/O, packages, or meaningful installer overhead.
- **Data complexity:** Low because no business data or database schema is introduced.
- **Integration complexity:** Medium to high because the contract must support Supabase, future API infrastructure, authentication, monitoring, and CI/CD without coupling them to environment implementation details.

High reasoning is appropriate for the security-sensitive and foundational nature of the task while keeping the implementation bounded to configuration infrastructure.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the implementation phase will begin, executing the recommended sequence and delivering all specified outcomes.

---

> **Status:** Approved
>
> **Approval Note:** The task implementation plan has been reviewed and approved. This document serves as the single source of truth for EP-01-03 implementation.
