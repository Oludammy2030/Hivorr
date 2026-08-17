# TASK IMPLEMENTATION PLAN: EP-01-01

## Project Directory Architecture & Scaffolding Setup

---

## 1. Task Objective

Create the complete `lib/` directory structure with all 14 top-level directories and their sub-directories, asset directories, test directories, and `.github/` structure as defined in ARCHITECTURE.md, establishing the foundational architectural boundaries that enforce separation of concerns from day one.

---

## 2. Business Problem Being Solved

**Problem:** Without a well-defined directory architecture, the Hivorr platform risks architectural drift, tight coupling between concerns, difficulty scaling across multiple business systems, and inability to enforce the database-first zero-trust architecture where the client is an unprivileged presentation layer.

**Solution:** Establish a comprehensive, opinionated directory structure that:
- Enforces separation of concerns between application bootstrap, core infrastructure, business systems, AI layers, and presentation
- Prevents proprietary logic from bleeding into client code by clearly delineating server-side enforcement boundaries
- Supports multi-role, multi-industry fluid-shift operation through modular system organization
- Enables future dynamic module delivery (15-20 MB installer constraint) via workspace feature loading architecture
- Provides clear ownership boundaries for future team scaling

---

## 3. Scope

### In Scope

**Directory Structure Creation:**
- 14 top-level directories under `lib/` with all sub-directories per ARCHITECTURE.md
- Placeholder files (`.gitkeep`) to ensure Git tracks empty directories
- Asset directory structure verification and completion
- Test directory structure completion (unit/, widget/, integration/)
- `.github/workflows/` directory creation

**Configuration Updates:**
- Update `.gitignore` to exclude build artifacts, IDE files, environment files, and sensitive data
- Ensure `.metadata` reflects correct project structure

**Verification:**
- Directory structure audit against ARCHITECTURE.md specification
- Git tracking verification for all directories
- Flutter project integrity validation

---

## 4. Out of Scope

- **Dependency Integration:** No packages added to `pubspec.yaml` (EP-01-02)
- **Environment Configuration:** No environment classes or `.env` files (EP-01-03)
- **CI/CD Workflows:** No GitHub Actions YAML files (EP-01-04)
- **Database Schema:** No Supabase migrations or SQL files (EP-01-05, EP-01-06)
- **Core System Implementation:** No actual service, API, or business logic code
- **UI Components:** No design system or shared widgets (EP-01-16)
- **Platform-Specific Configuration:** No modifications to android/, ios/, web/ native code
- **Documentation:** No README updates or feature documentation

---

## 5. Recommended Technical Approach

### 5.1 Directory Creation Strategy

**Approach:** Programmatic directory creation using Flutter CLI and file system operations, followed by Git tracking enforcement via `.gitkeep` files.

**Rationale:**
- Ensures all 14 top-level directories and 70+ sub-directories are created consistently
- `.gitkeep` files maintain directory structure in version control even when empty
- Programmatic approach reduces human error and ensures completeness
- Allows for verification script to validate structure against ARCHITECTURE.md

### 5.2 Architectural Boundary Enforcement

**Approach:** Each top-level directory represents a distinct architectural layer with clear responsibilities:

1. **lib/app/** - Application orchestration only (no business logic)
2. **lib/config/** - Environment isolation and feature flags
3. **lib/core/** - Platform infrastructure (authentication, API, security, storage, sync)
4. **lib/engine/** - Deterministic platform algorithms (server-side enforcement boundary)
5. **lib/ai/** - AI assistant layer (conversational, never overrides core engines)
6. **lib/workspace/** - Dynamic profession rendering and feature loading
7. **lib/systems/** - Discrete business systems (marketplace, finance, logistics, etc.)
8. **lib/integrations/** - External service adapters (payment gateways, maps, etc.)
9. **lib/shared/** - Presentation design system (atomic widgets, components, layouts)
10. **lib/data/** - Unified data access layer (repositories, providers, datasources, mappers)

### 5.3 Git Tracking Strategy

**Approach:** Place `.gitkeep` files in leaf directories (directories with no sub-directories) to ensure Git tracks the complete structure.

**Rationale:**
- Git does not track empty directories by default
- `.gitkeep` is a convention that signals "this directory should exist"
- Minimal file footprint (0 bytes each)
- Easy to identify and remove when actual code files are added

---

## 6. Required Systems, Modules, and Components

### 6.1 Directory Structure (14 Top-Level Directories)

Based on ARCHITECTURE.md, the following structure must be created:

```
lib/
├── app/                          # Application bootstrap & lifecycle
│   ├── app.dart                  # Root MaterialApp / Initialization
│   ├── router/                   # GoRouter / Web URL Deep-linking
│   ├── startup/                  # Splash & app readiness sequence
│   ├── lifecycle/                # App lifecycle state observers
│   └── theme/                    # Design System tokens & themes
│
├── config/                       # Application Configuration
│   ├── environments/             # Dev, Staging, Prod environment configs
│   ├── feature_flags/            # Runtime & Remote Feature Toggles
│   ├── constants/                # Global immutable constants
│   ├── app_config/               # Core application parameters
│   └── permissions/              # Cross-platform permission matrices
│
├── core/                         # Low-level Platform Infrastructure
│   ├── authentication/           # Session & token handlers
│   ├── api/                      # HTTP/Dio clients & interceptors
│   ├── database/                 # SQLite/Isar/Hive local storage drivers
│   ├── storage/                  # Secure storage wrappers
│   ├── sync/                     # Offline Sync Engine & Action Queue
│   ├── network/                  # Network listeners & payload optimizers
│   ├── security/                 # Encryption, SSL pinning, token rotation
│   ├── notifications/            # Local & Push notification engines
│   ├── localization/             # Dynamic multi-language engines
│   ├── logging/                  # Sentry / Logger integrations
│   ├── monitoring/               # Telemetry & performance metrics
│   ├── cache/                    # Transient memory cache manager
│   └── utilities/                # Platform-agnostic helpers
│
├── engine/                       # Deterministic Hivorr Core Decision Engines
│   ├── matching_engine/          # Spatial & 3-party dispatch routing
│   ├── recommendation_engine/    # Internal platform algorithm
│   ├── workspace_engine/         # Logic for building dynamic entity views
│   ├── dashboard_engine/         # Widget layout rules & priority engines
│   ├── profession_engine/        # Trade & business capability calculators
│   ├── search_engine/            # Offline & local indexing engine
│   └── growth_engine/            # SEO metadata & referral loop engine
│
├── ai/                           # AI Assistant & Task Automation Layer
│   ├── assistant/                # Conversational AI UI & logic
│   ├── agents/                   # Task auto-completion agents
│   ├── automation/               # Invoice & proposal drafting drivers
│   ├── prompts/                  # System prompts & prompt registry
│   ├── memory/                   # Short/long-term memory store
│   └── moderation/               # Automated safety & spam filtering
│
├── workspace/                    # Dynamic Profession & Business Workspace
│   ├── workspace_blueprints/     # UI templates per trade/business
│   ├── profession_registry/      # Two-Tier Industry -> Profession taxonomy
│   ├── feature_registry/         # Dynamic feature capabilities lookup
│   ├── feature_loader/           # Lazy-loading feature engines
│   ├── dashboard_builder/        # Dynamic grid & tile constructors
│   └── workspace_initializer/    # Hydration logic on profile switch
│
├── systems/                      # Discrete Business & Lifestyle Systems
│   ├── marketplace/              # Discovery, sourcing, & hiring logic
│   ├── local_commerce/           # Raw market groceries, local food, retail
│   ├── logistics_dispatch/       # Real-time rider broadcast & delivery hub
│   ├── business_management/      # Enterprise, store, & team scaling
│   ├── communication/            # Encrypted messaging & voice calls
│   ├── finance/                  # Escrow, funding, bound payouts & cashout
│   ├── documents/                # Contracts, invoices, work orders
│   ├── scheduling/               # Appointments & project calendars
│   ├── analytics/                # Entity growth & financial tracking
│   ├── verification/             # Trade proof upload & admin review gate
│   ├── waitlist_demand/          # Unlisted profession demand capture
│   ├── reviews/                  # Double-blind rating & trust engines
│   ├── portfolio/                # Project showcase & proof-of-work
│   ├── settings/                 # User preferences & account security
│   └── support/                  # Contextual dispute resolution hub
│
├── integrations/                 # External Platform Adapters
│   ├── openai/                   # LLM API abstraction layer
│   ├── payment_gateways/         # Paystack, Flutterwave, NIBSS drivers
│   ├── maps/                     # Mapbox / Google Maps SDK wrappers
│   ├── email/                    # Transactional email services
│   ├── sms/                      # Termii / Twilio OTP & broadcast
│   ├── social/                   # Social share & cross-posting tools
│   ├── cloud_storage/            # AWS S3 / Cloudinary adapters
│   └── third_party/              # External APIs
│
├── shared/                       # Presentation Design System
│   ├── widgets/                  # Atomic buttons, inputs, cards
│   ├── components/               # Multi-widget complex UI blocks
│   ├── layouts/                  # Responsive Web/Mobile Scaffolds
│   ├── helpers/                  # UI Formatters & UI Utilities
│   ├── mixins/                   # Reusable Flutter Mixins
│   ├── extensions/               # BuildContext, String & Numeric extensions
│   └── validators/               # Form input validation rules
│
├── data/                         # Unified Data Access Layer
│   ├── models/                   # Data Transfer Objects (DTOs)
│   ├── entities/                 # Core Domain Entities
│   ├── repositories/             # Repository implementations
│   ├── providers/                # State management providers
│   ├── datasources/              # Remote & Local Data Sources
│   └── mappers/                  # Data-to-Entity transformers
│
└── main.dart                     # Application entrypoint (already exists)
```

### 6.2 Asset Directory Structure

```
assets/
├── images/                       # App graphics, logos, raster assets
├── icons/                        # Custom app icons and SVG vectors
├── fonts/                        # Custom typography files
├── animations/                   # Lottie JSON files
└── translations/                 # i18n localization JSON files
```

**Status:** Already exists and properly structured. No action required.

### 6.3 Test Directory Structure

```
test/
├── unit/                         # Engine & repository logic unit tests
├── widget/                       # UI component tests
└── integration/                  # End-to-end flow tests
```

**Status:** Directories exist but are empty. Need `.gitkeep` files.

### 6.4 GitHub Actions Directory

```
.github/
└── workflows/                    # CI/CD workflow YAML files
```

**Status:** `.github/` exists but `workflows/` subdirectory does not. Must be created.

---

## 7. Data Requirements

**Not Applicable.** This task is purely structural scaffolding with no data model implementation.

---

## 8. Database Considerations

**Not Applicable.** Database schema design occurs in EP-01-05 and EP-01-06.

---

## 9. API Requirements

**Not Applicable.** API layer implementation occurs in EP-01-07.

---

## 10. User Interface Requirements

**Not Applicable.** UI components and design system implementation occurs in EP-01-16.

---

## 11. User Experience Considerations

**Not Applicable.** No user-facing functionality is delivered in this task.

---

## 12. Security Considerations

### 12.1 Zero-Trust Architecture Enforcement

**Requirement:** The directory structure must clearly delineate the boundary between client-side presentation code and server-side proprietary logic.

**Implementation:**
- `lib/engine/` directory explicitly marks deterministic core algorithms that must never be exposed in client code
- `lib/core/api/` and `lib/core/security/` directories establish the infrastructure for server-side enforcement
- `lib/data/repositories/` abstracts Supabase interactions, mitigating vendor lock-in and enforcing repository pattern

### 12.2 Environment Isolation

**Requirement:** Directory structure must support multi-environment configuration (Dev/Staging/Prod) with zero cross-contamination.

**Implementation:**
- `lib/config/environments/` directory provides dedicated space for environment-specific configs
- `.gitignore` must exclude `.env` files, API keys, and sensitive credentials

### 12.3 Secrets Management

**Requirement:** Zero hardcoded secrets in version control.

**Implementation:**
- Update `.gitignore` to exclude:
  - `.env` files
  - `*.pem`, `*.key` files
  - Firebase/Supabase configuration files
  - API keys and tokens

---

## 13. Performance Considerations

### 13.1 App Size Constraint (15-20 MB Target)

**Requirement:** Base installer must remain ultra-lightweight, containing only core auth, wallet, shared UI, and dynamic workspace loader.

**Implementation:**
- Directory structure supports future dynamic module delivery via `lib/workspace/feature_loader/`
- Industry-specific modules will be lazily loaded, not hard-bundled
- No performance-sensitive code is written in this task

### 13.2 Build Performance

**Requirement:** Directory structure should not impact Flutter build times.

**Implementation:**
- Empty directories with `.gitkeep` have negligible impact on build performance
- Flutter compiler ignores directories without Dart files

---

## 14. Testing Strategy

### 14.1 Directory Structure Verification

**Test Type:** Manual verification script

**Approach:**
- Create a Dart script that reads ARCHITECTURE.md and validates all directories exist
- Verify `.gitkeep` files are present in leaf directories
- Confirm Git tracks all directories

**Success Criteria:**
- All 14 top-level `lib/` directories exist
- All sub-directories per ARCHITECTURE.md exist
- All leaf directories contain `.gitkeep` files
- `git ls-files` shows all directories are tracked

### 14.2 Flutter Project Integrity

**Test Type:** Flutter CLI validation

**Approach:**
- Run `flutter pub get` to ensure project dependencies resolve
- Run `flutter analyze` to confirm no structural issues
- Run `flutter test` to verify test infrastructure is intact

**Success Criteria:**
- `flutter pub get` completes successfully
- `flutter analyze` reports no errors
- `flutter test` runs (even if no tests exist yet)

### 14.3 Git Tracking Verification

**Test Type:** Git command validation

**Approach:**
- Run `git add .` to stage all new directories and `.gitkeep` files
- Run `git status` to verify all directories are tracked
- Run `git ls-tree -r HEAD --name-only` to list all tracked files

**Success Criteria:**
- All `.gitkeep` files are staged
- No untracked directories remain
- Directory structure is reproducible from Git history

---

## 15. Recommended Implementation Sequence

### Phase 1: Preparation (5 minutes)

1. **Read and validate ARCHITECTURE.md** - Ensure directory schema is current and approved
2. **Backup current state** - Create a Git commit of the current baseline
3. **Prepare directory creation script** - Write a Dart or shell script to create all directories programmatically

### Phase 2: Directory Creation (10 minutes)

4. **Create lib/ sub-directories** - Create all 14 top-level directories and their sub-directories
5. **Create .gitkeep files** - Place `.gitkeep` in all leaf directories
6. **Create .github/workflows/** - Add the workflows subdirectory with `.gitkeep`
7. **Verify test/ structure** - Ensure unit/, widget/, integration/ have `.gitkeep` files

### Phase 3: Configuration Updates (5 minutes)

8. **Update .gitignore** - Add rules for:
   - `.env` files
   - `*.pem`, `*.key` files
   - Firebase/Supabase configs
   - Build artifacts
   - IDE-specific files
9. **Verify .metadata** - Ensure Flutter project metadata is intact

### Phase 4: Verification (10 minutes)

10. **Run directory audit** - Execute verification script to validate structure
11. **Run Flutter validation** - Execute `flutter pub get`, `flutter analyze`, `flutter test`
12. **Run Git tracking check** - Verify all directories are tracked
13. **Manual spot-check** - Visually inspect directory tree against ARCHITECTURE.md

### Phase 5: Documentation (5 minutes)

14. **Update task status** - Mark EP-01-01 as "Completed" in phase plan
15. **Create completion notes** - Document any deviations or issues encountered

---

## 16. Expected Outcome

Upon successful completion of EP-01-01, the following will be delivered:

### 16.1 Directory Structure

- **14 top-level directories** under `lib/` with all sub-directories per ARCHITECTURE.md
- **70+ sub-directories** properly organized and Git-tracked
- **Asset directories** verified and complete
- **Test directories** with proper structure (unit/, widget/, integration/)
- **GitHub Actions directory** (`.github/workflows/`) ready for CI/CD workflows

### 16.2 Configuration

- **Updated .gitignore** excluding sensitive files, build artifacts, and environment configs
- **Verified .metadata** confirming Flutter project integrity
- **All directories tracked** in Git version control

### 16.3 Architectural Enforcement

- **Clear separation of concerns** between application, core, systems, and presentation layers
- **Zero-trust boundary markers** via `engine/`, `core/api/`, `core/security/` directories
- **Modular system organization** supporting future multi-team development
- **Foundation for dynamic module delivery** via `workspace/feature_loader/`

### 16.4 Verification

- **Directory audit passes** with 100% compliance to ARCHITECTURE.md
- **Flutter commands succeed** (pub get, analyze, test)
- **Git tracking verified** with all directories staged and committed

---

## 17. Definition of Done (DoD)

EP-01-01 is considered **complete** when ALL of the following criteria are met:

### 17.1 Structural Completeness

- [ ] All 14 top-level `lib/` directories exist per ARCHITECTURE.md
- [ ] All sub-directories within each top-level directory exist
- [ ] All leaf directories contain `.gitkeep` files
- [ ] `assets/` directories are complete and tracked
- [ ] `test/unit/`, `test/widget/`, `test/integration/` directories exist with `.gitkeep`
- [ ] `.github/workflows/` directory exists with `.gitkeep`

### 17.2 Configuration Compliance

- [ ] `.gitignore` updated to exclude `.env`, `*.pem`, `*.key`, Firebase/Supabase configs
- [ ] `.gitignore` updated to exclude build artifacts and IDE files
- [ ] `.metadata` file is intact and valid

### 17.3 Version Control

- [ ] All directories and `.gitkeep` files are staged in Git
- [ ] `git status` shows no untracked directories
- [ ] Directory structure is reproducible from Git history

### 17.4 Verification

- [ ] Directory audit script passes with 100% compliance
- [ ] `flutter pub get` completes successfully
- [ ] `flutter analyze` reports no errors or warnings
- [ ] `flutter test` runs successfully (even with no tests)
- [ ] Manual inspection confirms structure matches ARCHITECTURE.md

### 17.5 Documentation

- [ ] Task marked as "Completed" in EP-01 phase plan
- [ ] No deviations from ARCHITECTURE.md (or deviations documented and approved)

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Medium**

### Reasoning Level Justification

**Technical Complexity: Medium**
- Directory creation is a straightforward file system operation
- No complex algorithms, data structures, or business logic required
- Primary challenge is ensuring completeness and accuracy against ARCHITECTURE.md

**Business Impact: Low**
- No user-facing functionality delivered
- No proprietary logic or financial systems implemented
- Purely infrastructure scaffolding with no operational impact

**Security Risk: Low**
- No sensitive data handling or storage
- No authentication or authorization code
- Security considerations limited to `.gitignore` updates (excluding secrets from version control)

**Performance Sensitivity: Low**
- Empty directories have negligible performance impact
- No runtime code execution
- App size constraint (15-20 MB) not affected by directory structure

**Data Complexity: Low**
- No data models, schemas, or transformations
- No database interactions
- No API integrations

**Integration Complexity: Low**
- No external service integrations
- No dependency management (deferred to EP-01-02)
- No cross-system communication

**Risk Assessment:**
- **Low risk of catastrophic failure** - Directory creation is easily reversible
- **Low risk of architectural drift** - ARCHITECTURE.md provides clear specification
- **Low risk of security breach** - No sensitive data or credentials involved
- **Low risk of performance degradation** - No runtime code executed

**Justification Summary:**
Medium reasoning is appropriate because this task requires careful attention to detail and systematic verification, but does not involve complex decision-making, algorithmic design, or high-stakes architectural choices. The primary cognitive load is ensuring completeness and accuracy against a well-defined specification (ARCHITECTURE.md), which is achievable with moderate reasoning capability.

---

## 19. Risk Mitigation

### 19.1 Risk: Incomplete Directory Structure

**Impact:** Future tasks blocked due to missing directories

**Mitigation:**
- Create verification script that compares actual structure against ARCHITECTURE.md
- Perform manual spot-check of critical directories (core/, engine/, systems/)
- Document any missing directories immediately

### 19.2 Risk: Git Tracking Failure

**Impact:** Directories not preserved in version control

**Mitigation:**
- Place `.gitkeep` files in all leaf directories
- Run `git status` after creation to verify tracking
- Commit directories immediately after creation

### 19.3 Risk: Architectural Drift

**Impact:** Developers create directories outside approved structure

**Mitigation:**
- Document the 14-directory rule in README or CONTRIBUTING guide
- Add lint rule or pre-commit hook to prevent unauthorized directories (future task)
- Enforce via code review in EP-01-02 and beyond

### 19.4 Risk: Flutter Project Corruption

**Impact:** Project fails to build or analyze

**Mitigation:**
- Run `flutter pub get` and `flutter analyze` immediately after directory creation
- Do not modify `pubspec.yaml` or `analysis_options.yaml` in this task
- Revert to baseline commit if corruption detected

---

## 20. Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| Directory Completeness | 100% | Audit script validation |
| Git Tracking | 100% | `git ls-files` output |
| Flutter Integrity | Pass | `flutter analyze` exit code 0 |
| Test Infrastructure | Pass | `flutter test` exit code 0 |
| Specification Compliance | 100% | Manual inspection vs ARCHITECTURE.md |

---

## 21. Dependencies

### Internal Dependencies
- **None** - This is the origin task with no predecessors

### External Dependencies
- **Flutter SDK ^3.12.2** - Already installed and available
- **Git version control** - Already initialized
- **ARCHITECTURE.md** - Already approved and available

---

## 22. Deliverables

1. **Complete `lib/` directory structure** with all 14 top-level directories and sub-directories
2. **Git-tracked directories** with `.gitkeep` files in all leaf directories
3. **Updated `.gitignore`** excluding sensitive files and build artifacts
4. **Verification report** confirming 100% compliance with ARCHITECTURE.md
5. **Updated task status** marking EP-01-01 as "Completed"

---

## 23. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the implementation phase will begin, executing the recommended sequence and delivering all specified outcomes.

**Estimated Implementation Time:** 35 minutes (including verification)

**Recommended Execution:** Single AI session with Medium reasoning level

---

> **Status:** Approved
>
> **Approval Note:** The task implementation plan has been reviewed and approved. This document serves as the single source of truth for EP-01-01 implementation.
