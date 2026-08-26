# ENGINEERING PHASE PLAN — EP-01: Core Platform Foundation & Infrastructure

> **Document Type:** Engineering Phase Plan | **Source:** Engineering Execution Structure EP-01 | **Status:** Ready for Review | **Priority:** Critical — Blocks All Other Phases

---

## 1. Phase Overview

| Attribute | Detail |
|---|---|
| **Phase ID** | EP-01 |
| **Phase Name** | Core Platform Foundation & Infrastructure |
| **Phase Objective** | Establish the foundational architecture, development infrastructure, server-side enforcement layer, core platform services, and data model that all subsequent engineering phases depend on. |
| **Business Capability Enabled** | Creates the engineering bedrock — without this phase, no business capability can be built, tested, or deployed. |
| **Priority** | Critical — blocks all other phases |
| **Status** | In Progress |
| **Dependencies** | None — this is the origin phase |

---

## 2. Engineering Objectives

1. **Establish the Database-First Zero-Trust Architecture** — Configure Supabase as the backend platform with PostgreSQL RPC (stored procedures) for all sensitive logic and Row-Level Security (RLS) for all data access, enforcing the principle that the client is an unprivileged presentation layer.
2. **Build the Universal Entity Data Model** — Design and implement the foundational database schema that supports multi-role, multi-industry, fluid-shift entity operation from day one.
3. **Create the Development Infrastructure** — Set up project scaffolding, multi-environment configuration (Dev/Staging/Prod), CI/CD pipelines, and automated testing frameworks.
4. **Implement the Client-Side Platform Foundation** — Build the core API layer, data access layer, authentication framework, security infrastructure, offline sync engine, and all low-level platform services.
5. **Establish the Application Shell** — Configure app bootstrap, lifecycle management, GoRouter-based routing with SEO-friendly deep links, design system foundation, and localization engine.
6. **Enforce Security-By-Design** — Implement encryption, SSL pinning, token rotation, secure storage, and zero-trust client constraints from the foundation.

---

## 3. Technical Goals

| Goal | Target |
|---|---|
| Server-side enforcement | All proprietary logic executes via PostgreSQL RPC + RLS — zero sensitive logic in client code |
| Multi-environment isolation | Three fully isolated environments (Dev/Staging/Prod) with separate databases, configs, credentials |
| Deployment discipline | Strict Dev → Staging → Prod flow enforced via CI/CD pipelines |
| App size constraint | Base installer ultra-lightweight (15–20 MB) |
| Cross-platform readiness | Flutter app compiles and runs on Android, iOS, and Web with responsive layouts |
| Data model scalability | Universal Entity model supports multi-role, multi-industry operation without schema redesign |
| Zero hardcoded secrets | All sensitive configuration via environment variables |
| Test infrastructure | Unit, widget, and integration test structure with automated CI execution |

---

## 4. Technology Stack (Confirmed)

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart SDK ^3.12.2) |
| Backend-as-a-Service | Supabase (PostgreSQL + Auth + RPC + RLS + Realtime + Storage + Edge Functions) |
| HTTP Client | Dio (with interceptors) |
| Routing | GoRouter (deep-linking, SEO-friendly URLs) |
| State Management | Provider |
| Local Storage | SQLite / Hive / Isar (evaluate during EP-01-11) |
| Secure Storage | flutter_secure_storage |
| Monitoring | Sentry |
| CI/CD | GitHub Actions |
| Code Quality | flutter_lints, dart analyze, flutter test |

---

## 5. Required Systems, Modules & Components

| System / Module | Location | Purpose |
|---|---|---|
| Project scaffolding | `lib/` (14 top-level directories) | Enforces architectural boundaries |
| CI/CD pipelines | `.github/workflows/` | Automated testing, building, deployment |
| Environment configuration | `lib/config/environments/` | Dev/Staging/Prod isolation (ENV-001 to ENV-010) |
| Supabase enforcement layer | Supabase SQL migrations, RPC, RLS | Database-first zero-trust enforcement |
| Universal Entity data model | Supabase database schema | Core multi-role entity schema |
| Authentication framework | `lib/core/authentication/` | Session management, token handling |
| Core API layer | `lib/core/api/` | Dio HTTP client, Supabase client, interceptors |
| Data access layer | `lib/data/` | Models, entities, repositories, providers, datasources, mappers |
| Security infrastructure | `lib/core/security/` | Encryption, SSL pinning, token rotation |
| Secure storage | `lib/core/storage/` | Encrypted local storage wrappers |
| Local storage & cache | `lib/core/database/`, `lib/core/cache/` | Storage drivers, transient memory cache |
| Offline sync engine | `lib/core/sync/` | Action queue, conflict resolution |
| Network management | `lib/core/network/` | Connectivity listeners, payload optimizers |
| Monitoring & logging | `lib/core/logging/`, `lib/core/monitoring/` | Sentry, telemetry, performance metrics |
| Notification engine | `lib/core/notifications/` | Local and push notification infrastructure |
| Localization engine | `lib/core/localization/` | Multi-language support framework |
| App bootstrap & routing | `lib/app/` | MaterialApp, GoRouter, splash, lifecycle |
| Design system | `lib/shared/` | Atomic widgets, components, layouts, validators |
| Utility layer | `lib/core/utilities/` | Platform-agnostic helpers |
| Native platform config | `android/`, `ios/`, `web/` | Permissions, build settings, PWA config |

---

## 6. Recommended Engineering Development Order

**Stage 1 — Project Skeleton:** EP-01-01, EP-01-02 (directory architecture + dependency integration)

**Stage 2 — Environment & DevOps:** EP-01-03, EP-01-04 (multi-environment config + CI/CD pipelines)

**Stage 3 — Server-Side Foundation:** EP-01-05, EP-01-06 (Supabase RPC+RLS + Universal Entity schema)

**Stage 4 — Client-Side Infrastructure:** EP-01-07 through EP-01-14 (API, data access, auth, security, storage, sync, network, monitoring)

**Stage 5 — Application Shell & UI:** EP-01-15 through EP-01-18 (app bootstrap, routing, design system, localization, notifications)

**Stage 6 — Quality & Validation:** EP-01-19, EP-01-20 (test infrastructure + end-to-end phase validation)

---

## 7. Internal and External Dependencies

### Internal Dependencies

| Item | Depends On |
|---|---|
| EP-01-02 | EP-01-01 |
| EP-01-03 | EP-01-01 |
| EP-01-04 | EP-01-01, EP-01-03 |
| EP-01-05 | EP-01-03 |
| EP-01-06 | EP-01-05 |
| EP-01-07 | EP-01-02, EP-01-03 |
| EP-01-08 | EP-01-06, EP-01-07 |
| EP-01-09 | EP-01-05, EP-01-07 |
| EP-01-10 | EP-01-09, EP-01-07 |
| EP-01-11 | EP-01-02 |
| EP-01-12 | EP-01-07, EP-01-11 |
| EP-01-13 | EP-01-07 |
| EP-01-14 | EP-01-02, EP-01-03 |
| EP-01-15 | EP-01-09, EP-01-03 |
| EP-01-16 | EP-01-02 |
| EP-01-17 | EP-01-02, EP-01-16 |
| EP-01-18 | EP-01-02, EP-01-09 |
| EP-01-19 | EP-01-04, EP-01-07 |
| EP-01-20 | All items |

### External Dependencies

| Dependency | Type | Impact |
|---|---|---|
| Supabase project provisioning (×3) | Infrastructure | Required before EP-01-05 |
| Supabase service keys & credentials | Configuration | Required for EP-01-03 |
| GitHub repository & Actions | DevOps | Required for EP-01-04 |
| Sentry DSN / project setup | Monitoring | Required for EP-01-14 |
| Flutter SDK ^3.12.2 stable | Tooling | Already available |
| Apple Developer Account | Platform | Required for iOS build config |
| Google Play Console Account | Platform | Required for Android build config |

---

## 8. Risks, Assumptions & Engineering Considerations

### Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Universal Entity data model designed incorrectly | Catastrophic — affects all future phases | Extremely High reasoning. Validate against EP-02 through EP-08 requirements before finalizing. |
| RLS policies too permissive | High — data leakage | Default deny all, explicitly grant per operation. Security review before completion. |
| Supabase vendor lock-in | Medium — migration cost | Abstract all Supabase interactions behind repository interfaces. |
| Offline sync complexity exceeds scope | Medium — delays phase | EP-01 delivers the framework (queue, storage, retry). Complex conflict resolution matures later. |
| App size exceeds 15–20 MB | Medium — violates constraint | Audit dependency sizes during EP-01-02. No industry modules bundled. |
| Environment contamination | High — data integrity breach | Strict ENV isolation. Separate Supabase projects. CI/CD enforces flow. |
| SSL pinning certificate rotation | Medium — app breakage | Implement rotation strategy with fallback chain. Monitor expiry. |

### Assumptions

1. Supabase free/Pro tier sufficient for dev/staging during EP-01.
2. Flutter SDK ^3.12.2 remains stable throughout development.
3. GitHub Actions provides sufficient CI/CD capacity.
4. The 14-directory `lib/` structure is final.
5. Provider state management is sufficient for EP-01 data access complexity.
6. Local storage technology selected during EP-01-11 based on sync requirements.

### Engineering Considerations

1. **Server-side enforcement is non-negotiable.** Every RPC + RLS pattern set here propagates to all future phases.
2. **Universal Entity must support fluid role-shifting** — professional, consumer, merchant, rider simultaneously.
3. **Two-tier taxonomy placeholder** required in schema to validate Industry → Profession architecture.
4. **Supabase Edge Functions** may be needed for operations beyond stored procedures (webhooks, external APIs).
5. **Database migrations must be versioned and reproducible** — SQL files in repository.
6. **No business logic in client code** — even at foundation level, establish the discipline.

---

## 9. Expected Phase Outcome

A fully operational development environment with a secure, scalable, zero-trust architecture where the Flutter client is an unprivileged presentation layer and all sensitive logic executes server-side via Supabase PostgreSQL RPC + RLS. A Universal Entity data model designed for multi-role, multi-industry fluid-shift operation. Three isolated environments with automated CI/CD. A complete client-side platform foundation ready for EP-02.

---

## 10. Phase Completion Criteria

| Criterion | Verification |
|---|---|
| All 14 `lib/` directories exist with correct structure | Directory audit |
| App compiles on Android, iOS, and Web | `flutter build` per platform |
| Three Supabase environments provisioned and isolated | Connectivity tests |
| RLS enforces zero-trust (unauthenticated = no data) | Automated RLS test suite |
| At least one RPC function demonstrates server-side enforcement | Integration test |
| Universal Entity schema with core tables and relationships | Schema review + migration verification |
| Auth flow works: register, login, refresh, logout | End-to-end auth test |
| API layer communicates with backend | API integration test |
| Data access layer (repo + provider + datasource + mapper) functional | Data flow test |
| Environment config loads correct settings per env | Config verification |
| CI/CD runs on push: lint, analyze, test, build | GitHub Actions verification |
| Design system renders basic widgets | Widget test + visual check |
| Router handles deep links + SEO-friendly URLs | Router integration test |
| No hardcoded secrets | Static analysis scan |
| Offline sync queue captures + replays actions | Sync integration test |
| Sentry captures errors + metrics | Monitoring verification |
| Localization loads translations + switches languages | Localization test |
| App installer size within 15–20 MB | Build size measurement |
| All EP-01 items at "Completed" | Phase plan audit |

---

## 11. Engineering Roadmap Items

### EP-01-01: Project Directory Architecture & Scaffolding Setup

| Attribute | Detail |
|---|---|
| **Objective** | Create the complete `lib/` directory structure (14 top-level directories with sub-directories), asset directories, test directories, and `.github/` as defined in ARCHITECTURE.md. |
| **Engineering Purpose** | Enforces separation of concerns from day one. Prevents structural drift as features are added. |
| **Dependencies** | None |
| **Expected Outcome** | All directories created per ARCHITECTURE.md. `.gitignore` updated. Structure verified. |
| **Priority** | Critical | **Status** | Completed |
| **Planning Reasoning** | Medium | **Coding Reasoning** | Medium |

### EP-01-02: Dependency Integration & Package Configuration

| Attribute | Detail |
|---|---|
| **Objective** | Integrate all foundational packages (Dio, GoRouter, Provider, Supabase Flutter SDK, flutter_secure_storage, Sentry, etc.) into `pubspec.yaml`. Configure strict `analysis_options.yaml`. |
| **Engineering Purpose** | Establishes the package ecosystem. Choices here become permanent architectural decisions. |
| **Dependencies** | EP-01-01 |
| **Expected Outcome** | `pubspec.yaml` with pinned dependencies. `analysis_options.yaml` with strict lints. `flutter pub get` and `flutter analyze` pass clean. Dependency size audit confirms 15–20 MB target alignment. |
| **Priority** | Critical | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | Medium |

### EP-01-03: Multi-Environment Configuration System

| Attribute | Detail |
|---|---|
| **Objective** | Implement environment configuration in `lib/config/environments/` with isolated Dev/Staging/Prod profiles loaded via environment variables. Zero hardcoded secrets (ENV-001 through ENV-010). |
| **Engineering Purpose** | Enforces environment isolation. Every system reads config from this layer. Prevents contamination and secret leakage. |
| **Dependencies** | EP-01-01 |
| **Expected Outcome** | Environment classes with Supabase URLs/keys, feature flags, constants. Config switching mechanism. `.env` templates documented. Zero hardcoded secrets verified. |
| **Priority** | Critical | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-04: CI/CD Pipeline & Automated Deployment Framework

| Attribute | Detail |
|---|---|
| **Objective** | Create GitHub Actions workflows for PR validation (lint + analyze + test), staging deployment, and production deployment with branch protection. |
| **Engineering Purpose** | Automates quality gates and deployment discipline. Enforces Dev → Staging → Prod flow (ENV-007). |
| **Dependencies** | EP-01-01, EP-01-03 |
| **Expected Outcome** | Workflows in `.github/workflows/`. PR checks run automatically. Branch protection documented. |
| **Priority** | High | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-05: Supabase Server-Side Enforcement Architecture (RPC + RLS)

| Attribute | Detail |
|---|---|
| **Objective** | Provision 3 Supabase projects (Dev/Staging/Prod), establish migration strategy, configure RLS with default-deny on all tables, and create foundational RPC patterns demonstrating server-side enforcement. |
| **Engineering Purpose** | **Most architecturally significant item in EP-01.** Establishes the Database-First Zero-Trust Architecture that every future phase operates under. |
| **Dependencies** | EP-01-03 |
| **Expected Outcome** | 3 Supabase projects connected. SQL migrations in repo. RLS default-deny. Foundational RPC functions (authenticated read, authenticated write, validation, error handling). RLS test suite confirms zero data leakage. |
| **Priority** | Critical | **Status** | Completed |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-01-06: Universal Entity Data Model & Core Schema Design

| Attribute | Detail |
|---|---|
| **Objective** | Design and implement the foundational database schema for the Universal Entity model — core tables for entities, profiles, roles, credentials, two-tier taxonomy (industries, professions), settings, and devices. |
| **Engineering Purpose** | **Most critical data architecture decision.** Must support multi-role fluid-shift operation and scale across all future phases without redesign. |
| **Dependencies** | EP-01-05 |
| **Expected Outcome** | Tables: `entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `industries`, `professions`, `entity_professions`, `entity_settings`, `entity_devices`. Audit columns on all tables. All RLS-protected. Validated against EP-02 requirements. |
| **Priority** | Critical | **Status** | Completed (schema implemented + Staging promoted 2026-08-21; Prod promotion gated on EP-01-07/08/09 app validation) |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-01-07: Core API Layer & HTTP Client Architecture

| Attribute | Detail |
|---|---|
| **Objective** | Build core API infrastructure in `lib/core/api/` using Dio + Supabase Flutter SDK with interceptors for auth token injection, token refresh on 401, error normalization, retry, and environment-aware endpoints. |
| **Engineering Purpose** | Single communication channel between client and backend. Every data operation flows through this layer. |
| **Dependencies** | EP-01-02, EP-01-03 |
| **Expected Outcome** | Dio client with interceptors (auth, error, logging, retry). Supabase client initialized per environment. Base API service class for all repositories. |
| **Priority** | Critical | **Status** | Completed (implemented 2026-08-21; full test suite passing; DoD verified) |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-01-08: Unified Data Access Layer

| Attribute | Detail |
|---|---|
| **Objective** | Implement the structured data access layer in `lib/data/` — domain entities, DTOs, remote/local datasources, mappers, repositories, and Provider-based state management. |
| **Engineering Purpose** | Establishes the data flow pattern for every feature in EP-02+. Repository pattern abstracts Supabase, mitigating vendor lock-in. |
| **Dependencies** | EP-01-06, EP-01-07 |
| **Expected Outcome** | One complete vertical slice (Entity + DTO + Datasource + Mapper + Repository + Provider) as reference implementation. Abstract interfaces for repositories. |
| **Priority** | High | **Status** | Completed (implemented 2026-08-21; unit tests passing; DoD verified) |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-01-09: Authentication & Authorization Framework

| Attribute | Detail |
|---|---|
| **Objective** | Implement auth in `lib/core/authentication/` using Supabase Auth — registration, login, session persistence, token refresh, logout, and auth state propagation via Provider. |
| **Engineering Purpose** | Gateway to all platform operations. EP-02 builds registration, verification, and trust directly on top of this. |
| **Dependencies** | EP-01-05, EP-01-07 |
| **Expected Outcome** | Auth service (sign up/in/out, session persistence, auto-refresh, state changes). Auth provider app-wide. Token injection into API layer. Route guarding (auth vs unauth routes). |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-01-10: Security Infrastructure

| Attribute | Detail |
|---|---|
| **Objective** | Build security foundation in `lib/core/security/` and `lib/core/storage/` — encryption utilities, SSL pinning, token rotation, secure storage wrappers for sensitive data. |
| **Engineering Purpose** | Zero-trust requires strict client-side handling of sensitive data. SSL pinning prevents MITM. Secure storage prevents credential extraction. |
| **Dependencies** | EP-01-09, EP-01-07 |
| **Expected Outcome** | AES encryption utilities. SSL pinning for Dio. Token rotation helper. Secure storage wrapping `flutter_secure_storage` with typed accessors. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-01-11: Local Storage & Cache Management System

| Attribute | Detail |
|---|---|
| **Objective** | Implement local storage drivers in `lib/core/database/` and transient memory cache in `lib/core/cache/` with LRU eviction, TTL expiration, and typed accessors. |
| **Engineering Purpose** | Foundation for offline capability, cache-first reads, and the offline sync engine (EP-01-12). |
| **Dependencies** | EP-01-02 |
| **Expected Outcome** | Storage driver selected (SQLite/Hive/Isar), configured, and abstracted. Cache manager with LRU, TTL, invalidation API. Both ready for sync engine and data access layer. |
| **Priority** | High | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-12: Offline Sync Engine & Action Queue

| Attribute | Detail |
|---|---|
| **Objective** | Build offline sync engine in `lib/core/sync/` — action queue (FIFO + priority), persistent storage, connectivity-triggered replay, retry with exponential backoff, basic conflict detection. |
| **Engineering Purpose** | Ensures platform usability with unreliable connectivity (critical for Nigeria market). No user data lost during offline periods. |
| **Dependencies** | EP-01-07, EP-01-11 |
| **Expected Outcome** | Action queue with persistent storage. Auto-replay on reconnection. Retry with backoff + jitter. Basic conflict detection. Sync status observable. Complex conflict resolution deferred. |
| **Priority** | High | **Status** | Completed |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-01-13: Network Management & Connectivity Infrastructure

| Attribute | Detail |
|---|---|
| **Objective** | Implement network management in `lib/core/network/` — connectivity monitoring, network type detection, state propagation via Provider, payload optimization utilities. |
| **Engineering Purpose** | Feeds connectivity state to sync engine, UI (offline indicators), and API layer. Payload optimization reduces data costs. |
| **Dependencies** | EP-01-07 |
| **Expected Outcome** | Connectivity status stream. Network type detection. Connectivity change triggers sync replay. Payload utilities. Network state via Provider. |
| **Priority** | Medium | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-14: Monitoring, Logging & Telemetry Infrastructure

| Attribute | Detail |
|---|---|
| **Objective** | Implement logging in `lib/core/logging/` and monitoring in `lib/core/monitoring/` — Sentry integration, structured logging with PII redaction, environment-aware verbosity, performance tracking. |
| **Engineering Purpose** | Essential from day one for issue detection across dev/staging/prod. Structured logging enables debugging without exposing sensitive data. |
| **Dependencies** | EP-01-02, EP-01-03 |
| **Expected Outcome** | Structured logger (debug/info/warning/error/fatal) with PII redaction. Sentry init, crash capture, performance tracing, breadcrumbs. API layer error reporting integration. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-15: App Bootstrap, Lifecycle & Routing Architecture

| Attribute | Detail |
|---|---|
| **Objective** | Build app shell in `lib/app/` — MaterialApp init with providers, GoRouter with auth-guarded routes, splash sequence, lifecycle observer, SEO-friendly web URLs. |
| **Engineering Purpose** | Orchestration layer wiring all core systems at startup. GoRouter supports deep-linking, web SEO URLs, and route guarding. |
| **Dependencies** | EP-01-09, EP-01-03 |
| **Expected Outcome** | `app.dart` with all core providers. GoRouter with public/protected routes + auth redirects. Splash screen + init sequence. Lifecycle observer. SEO URLs (`/p/:slug/:id`). |
| **Priority** | High | **Status** | Completed |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-01-16: Design System & Shared UI Foundation

| Attribute | Detail |
|---|---|
| **Objective** | Build design system in `lib/shared/` — design tokens (theme), atomic widgets (button, input, card, chip), responsive layouts (mobile/web scaffolds), validators, extensions, helpers. |
| **Engineering Purpose** | Ensures visual/behavioral consistency. Every UI in EP-02+ built from these primitives. Prevents ad-hoc UI creation. |
| **Dependencies** | EP-01-02 |
| **Expected Outcome** | HivorrTheme (light/dark). HivorrButton, HivorrTextField, HivorrCard, HivorrChip, loading/empty states. Mobile + web responsive scaffolds. Validators, extensions, helpers. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-17: Localization & Internationalization Engine

| Attribute | Detail |
|---|---|
| **Objective** | Implement localization in `lib/core/localization/` — JSON translation loading, dynamic language switching, pluralization, typed translation key access. |
| **Engineering Purpose** | Core infrastructure for EP-08 (Global Scale). All user-facing strings from EP-02+ must use this system. |
| **Dependencies** | EP-01-02, EP-01-16 |
| **Expected Outcome** | Localization engine loading from `assets/translations/`. Dynamic switching. Typed key access. Pluralization. `en.json` created. Locale provider app-wide. |
| **Priority** | Medium | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-18: Notification Engine Foundation

| Attribute | Detail |
|---|---|
| **Objective** | Implement notifications in `lib/core/notifications/` — local notifications, push reception/handling, permission management, unified dispatch API. |
| **Engineering Purpose** | Cross-cutting service used by nearly every business system. Must exist before EP-02 builds messaging, transaction alerts, trust notifications. |
| **Dependencies** | EP-01-02, EP-01-09 |
| **Expected Outcome** | Local notification dispatch. Push listener (foreground/background). Permission flow. Android channels. Unified `NotificationService`. Native permissions configured. |
| **Priority** | Medium | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-19: Test Infrastructure & Quality Assurance Framework

| Attribute | Detail |
|---|---|
| **Objective** | Establish testing framework — test utilities, mock factories (Supabase, API), repository test patterns, widget test patterns, integration test scaffolding. |
| **Engineering Purpose** | Defines quality bar for entire project. Mock factories enable CI testing without live backends. |
| **Dependencies** | EP-01-04, EP-01-07 |
| **Expected Outcome** | Mock Supabase client, mock API service, test data builders. Unit tests for one repository. Widget tests for design system. Integration test scaffold for auth. All pass in CI. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-01-20: Phase Integration Validation & Foundation Verification

| Attribute | Detail |
|---|---|
| **Objective** | End-to-end validation of all EP-01 systems: auth flow through full stack, API → RPC → RLS → response → cache → UI, offline/online sync, environment isolation, CI/CD, security, EP-02 readiness. |
| **Engineering Purpose** | Individual systems may work in isolation but fail when integrated. Final gate before EP-01 is marked complete. |
| **Dependencies** | All EP-01 items |
| **Expected Outcome** | 10-point validation: (1) auth flow, (2) API+RLS, (3) RPC execution, (4) data flow pipeline, (5) offline sync, (6) Sentry capture, (7) localization, (8) design system on mobile+web, (9) CI/CD passes, (10) no hardcoded secrets. EP-01 complete, EP-02 unblocked. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

---

## 12. Roadmap Summary Matrix

| Task ID | Task Name | Priority | Plan Reasoning | Code Reasoning | Dependencies | Status |
|---|---|---|---|---|---|---|
| EP-01-01 | Project Directory Architecture & Scaffolding | Critical | Medium | Medium | None | Completed |
| EP-01-02 | Dependency Integration & Package Config | Critical | High | Medium | 01 | Completed |
| EP-01-03 | Multi-Environment Configuration | Critical | High | High | 01 | Completed |
| EP-01-04 | CI/CD Pipeline & Deployment Framework | High | High | High | 01, 03 | Completed |
| EP-01-05 | Supabase Server-Side Enforcement (RPC+RLS) | Critical | **Extremely High** | **Extremely High** | 03 | Completed |
| EP-01-06 | Universal Entity Data Model & Schema | Critical | **Extremely High** | **Extremely High** | 05 | Completed |
| EP-01-07 | Core API Layer & HTTP Client | Critical | Very High | Very High | 02, 03 | Completed |
| EP-01-08 | Unified Data Access Layer | High | Very High | Very High | 06, 07 | Completed |
| EP-01-09 | Authentication & Authorization Framework | Critical | **Extremely High** | **Extremely High** | 05, 07 | Not Started |
| EP-01-10 | Security Infrastructure | High | **Extremely High** | **Extremely High** | 09, 07 | Not Started |
| EP-01-11 | Local Storage & Cache Management | High | High | High | 02 | Completed |
| EP-01-12 | Offline Sync Engine & Action Queue | High | Very High | Very High | 07, 11 | Completed |
| EP-01-13 | Network Management & Connectivity | Medium | High | High | 07 | Completed |
| EP-01-14 | Monitoring, Logging & Telemetry | High | High | High | 02, 03 | Not Started |
| EP-01-15 | App Bootstrap, Lifecycle & Routing | High | Very High | Very High | 09, 03 | Completed |
| EP-01-16 | Design System & Shared UI Foundation | High | High | High | 02 | Not Started |
| EP-01-17 | Localization & Internationalization | Medium | High | High | 02, 16 | Not Started |
| EP-01-18 | Notification Engine Foundation | Medium | High | High | 02, 09 | Not Started |
| EP-01-19 | Test Infrastructure & QA Framework | High | High | High | 04, 07 | Not Started |
| EP-01-20 | Phase Integration Validation | Critical | High | High | All | Not Started |

---

## 13. Reasoning Level Distribution

| Level | Items | Count |
|---|---|---|
| **Extremely High** | EP-01-05, EP-01-06, EP-01-09, EP-01-10 | 4 |
| **Very High** | EP-01-07, EP-01-08, EP-01-12, EP-01-15 | 4 |
| **High** | EP-01-02, EP-01-03, EP-01-04, EP-01-11, EP-01-13, EP-01-14, EP-01-16, EP-01-17, EP-01-18, EP-01-19, EP-01-20 | 11 |
| **Medium** | EP-01-01 | 1 |
| **Low** | None | 0 |

The concentration of Extremely High and Very High items (8 of 20) reflects the foundational nature of this phase — architectural decisions here propagate to every subsequent phase.

---

> **Next Step:** Upon approval, EP-01-01 (Project Directory Architecture & Scaffolding Setup) begins execution.
