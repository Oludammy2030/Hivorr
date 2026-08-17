# ARCHITECTURE.md — Hivorr System Design, Directory Mapping & Environment Rules

## Complete Project Root Architecture

text
hivorr/
├── .github/                  # CI/CD workflows, automated testing & deployment scripts
├── android/                  # Native Android platform code, Gradle scripts, & permissions
├── ios/                      # Native iOS platform code, CocoaPods, & Info.plist settings
├── web/                      # Web entry point (index.html), manifest, & PWA configuration
├── linux/                    # Native Linux desktop runner & configuration
├── macos/                    # Native macOS desktop runner & configuration
├── windows/                  # Native Windows desktop runner & configuration
│
├── assets/                   # Shared static resources referenced in pubspec.yaml
│   ├── images/               # App graphics, logos, and raster assets
│   ├── icons/                # Custom app icons and SVG vectors
│   ├── fonts/                # Custom typography files
│   ├── animations/           # Lottie JSON files
│   └── translations/         # i18n localization JSON files
│
├── test/                     # Automated test suite
│   ├── unit/                 # Engine & repository logic unit tests
│   ├── widget/               # UI component tests
│   └── integration/          # End-to-end flow tests
│
├── lib/                      # Core Application Codebase (See Detailed Schema Below)
│
├── .gitignore                # Git exclusion rules
├── .metadata                 # Flutter project metadata
├── analysis_options.yaml     # Dart linter & static analysis configuration
├── pubspec.yaml              # Project dependencies, assets, and metadata
└── pubspec.lock              # Locked dependency versions


## lib/ Directory Schema Mapping
When generating features, refactoring, or building modules, you **MUST** respect the following directory schema inside lib/. Never create top-level directories inside lib/ outside this structure.

text
lib/
├── app/                      # Application bootstrap & lifecycle
│   ├── app.dart              # Root MaterialApp / Initialization
│   ├── router/               # GoRouter / Web URL Deep-linking
│   ├── startup/              # Splash & app readiness sequence
│   ├── lifecycle/            # App lifecycle state observers
│   └── theme/                # Design System tokens & themes
│
├── config/                   # Application Configuration
│   ├── environments/         # Dev, Staging, Prod environment configs
│   ├── feature_flags/        # Runtime & Remote Feature Toggles
│   ├── constants/            # Global immutable constants
│   ├── app_config/           # Core application parameters
│   └── permissions/          # Cross-platform permission matrices
│
├── core/                     # Low-level Platform Infrastructure
│   ├── authentication/       # Session & token handlers
│   ├── api/                  # HTTP/Dio clients & interceptors
│   ├── database/             # SQLite/Isar/Hive local storage drivers
│   ├── storage/              # Secure storage wrappers
│   ├── sync/                 # ⚡ Offline Sync Engine & Action Queue
│   ├── network/              # Network listeners & payload optimizers
│   ├── security/             # Encryption, SSL pinning, token rotation
│   ├── notifications/        # Local & Push notification engines
│   ├── localization/         # Dynamic multi-language engines
│   ├── logging/              # Sentry / Logger integrations
│   ├── monitoring/           # Telemetry & performance metrics
│   ├── cache/                # Transient memory cache manager
│   └── utilities/            # Platform-agnostic helpers
│
├── engine/                   # Deterministic Hivorr Core Decision & Recommendation Engines
│   ├── matching_engine/      # Spatial & 3-party dispatch routing
│   ├── recommendation_engine/ # ⚡ Internal platform algorithm (Distance, Ratings, Skills, Activity)
│   ├── workspace_engine/     # Logic for building dynamic entity views
│   ├── dashboard_engine/     # Widget layout rules & priority engines
│   ├── profession_engine/    # Trade & business capability calculators
│   ├── search_engine/        # Offline & local indexing engine
│   └── growth_engine/        # SEO metadata & referral loop engine
│
├── ai/                       # AI Assistant & Task Automation Layer
│   ├── assistant/            # Conversational AI UI & logic
│   ├── agents/               # Task auto-completion agents
│   ├── automation/           # Invoice & proposal drafting drivers
│   ├── prompts/              # System prompts & prompt registry
│   ├── memory/               # Short/long-term memory store
│   └── moderation/           # Automated safety & spam filtering
│
├── workspace/                # Dynamic Profession & Business Workspace Rendering
│   ├── workspace_blueprints/ # UI templates per trade/business (e.g., Pharmacy, Electrician, Private Chef)
│   ├── profession_registry/  # Two-Tier Industry -> Profession taxonomy lookup
│   ├── feature_registry/     # Dynamic feature capabilities lookup
│   ├── feature_loader/       # Lazy-loading feature engines
│   ├── dashboard_builder/    # Dynamic grid & tile constructors
│   └── workspace_initializer/ # Hydration logic on profile switch
│
├── systems/                  # Discrete Business & Lifestyle Systems
│   ├── marketplace/          # Discovery, sourcing, & hiring logic
│   ├── local_commerce/       # ⚡ Raw market groceries, local food, & retail catalog engines
│   ├── logistics_dispatch/   # ⚡ Real-time rider broadcast & multi-stop delivery hub
│   ├── business_management/  # Enterprise, store, & team scaling systems
│   ├── communication/        # Encrypted messaging & voice calls
│   ├── finance/              # ⚡ Escrow, first-party funding, bound payouts & dual cashout limits
│   ├── documents/            # Contracts, invoices, work orders
│   ├── scheduling/           # Appointments & project calendars
│   ├── analytics/            # Entity growth & financial tracking
│   ├── verification/         # ⚡ Trade proof upload & admin review gate system
│   ├── waitlist_demand/      # ⚡ Unlisted profession demand capture & vote counter
│   ├── reviews/              # Double-blind rating & trust engines
│   ├── portfolio/            # Project showcase & proof-of-work
│   ├── settings/             # User preferences & account security
│   └── support/              # Contextual dispute resolution hub
│
├── integrations/             # External Platform Adapters
│   ├── openai/               # LLM API abstraction layer
│   ├── payment_gateways/     # Paystack, Flutterwave, NIBSS name enquiry drivers
│   ├── maps/                 # Mapbox / Google Maps SDK wrappers
│   ├── email/                # Transactional email services
│   ├── sms/                  # Termii / Twilio OTP & broadcast adapters
│   ├── social/               # Social share & cross-posting tools
│   ├── cloud_storage/        # AWS S3 / Cloudinary adapters
│   └── third_party/          # External APIs
│
├── shared/                   # Presentation Design System
│   ├── widgets/              # Atomic buttons, inputs, cards
│   ├── components/           # Multi-widget complex UI blocks
│   ├── layouts/              # Responsive Web/Mobile Scaffolds
│   ├── helpers/              # UI Formatters & UI Utilities
│   ├── mixins/               # Reusable Flutter Mixins
│   ├── extensions/           # BuildContext, String & Numeric extensions
│   └── validators/           # Form input validation rules
│
├── data/                     # Unified Data Access Layer
│   ├── models/               # Data Transfer Objects (DTOs)
│   ├── entities/             # Core Domain Entities (Unified Entity Model)
│   ├── repositories/         # Repository implementations
│   ├── providers/            # State management providers
│   ├── datasources/          # Remote & Local Data Sources
│   └── mappers/              # Data-to-Entity transformers
│
└── main.dart                 # Application entrypoint

`
## Detailed Architectural & Implementation Rules
### Native Platform Modifications (android/, ios/, web/)
* Permissions: Native platform permissions (e.g., Camera, High-Precision Location for Riders, Notifications) must be explicitly configured in android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist.
* Build Settings: Modify Gradle scripts (android/app/build.gradle) or Podfiles (ios/Podfile) only when configuring native SDK integrations or minimum target versions.
* Dart Code Isolation: No Dart code should live in native folders; all cross-platform Dart code must strictly reside within lib/.
### Cross-Platform Adaptation (shared/layouts/ & app/router/)
* UI components inside shared/ must be responsive across Mobile (iOS/Android) and Web.
* Screens must adapt using layout scaffolds in shared/layouts/ depending on breakpoint width.
* Routing in app/router/ must generate clean, web-serializable URLs for public entities and listings to ensure SEO discoverability (e.g., /p/:profession_slug/:entity_id or /store/:store_id).
### Payment Gateway Abstraction (integrations/payment_gateways/)
* Never hardcode direct calls to Paystack, Flutterwave, or NIBSS inside systems/finance/. Financial workflows must interact with abstract interfaces defined in integrations/payment_gateways/.
### On-Demand Dynamic Module Delivery (workspace/feature_loader/)
* The base app installer across mobile and desktop must remain ultra-lightweight (15\text{--}20\text{ MB}) containing only core auth, wallet, shared UI design system, and the dynamic workspace loader.
* Industry-specific business modules must never be hard-bundled into the core installer, but lazily fetched and cached via workspace/feature_loader/.
## Intelligence, Autonomy & Human-Centric Design.
* Deterministic Core vs. AI Assistance: 
  * Core platform intelligence, spatial routing, search indexing, ranking algorithms, and financial escrow settlements are handled by rigorous, deterministic engines (`engine/`) to ensure absolute fairness and transparency.
  * The AI assistant layer (`ai/`) acts as a brilliant, proactive operational partner—drafting proposals, automating repetitive tasks, and translating natural language intent into real-world actions without overriding foundational platform rules.
## Trust, Security & Financial Integrity
* Database-First Zero-Trust Architecture: The client application functions purely as an unprivileged presentation layer. All sensitive calculations, pricing rules, cryptographic verification checks, and financial escrow divisions are enforced server-side via PostgreSQL RPC and RLS policies.
* Controlled Financial Workflows: Built with rigorous first-party funding verifications, bound payout accounts, KYC-driven cashout limits, and trade verification gates to guarantee a secure, trustworthy marketplace for every participant.
## Environment Management Rules (ENV-001 to ENV-010)
* ENV-001 (Environment Separation): Hivorr must maintain separate Development, Staging, and Production environments that operate independently without cross-contamination.
* ENV-002 (Development Environment): Used for active coding, feature writing, and debugging. Must use isolated databases, storage, authentication configs, and variables.
* ENV-003 (Staging Environment): A production-like staging ground deployed online for performance checks, network testing, user workflow validation, and release preparation.
* ENV-004 (Production Environment): The live platform used by real users containing isolated live resources. Experimental testing is strictly prohibited in production.
* ENV-005 (Single Source Code Repository): All environments must build from a single authoritative source code repository.
* ENV-006 (Environment Configuration): Configuration settings must be managed through secure environment variables. Sensitive keys must never be hardcoded.
* ENV-007 (Deployment Flow): Changes must strictly flow from Development \rightarrow Staging \rightarrow Production. No feature goes live without staging validation.
* ENV-008 (Database Isolation): Each environment must use isolated database instances. Production data must never serve as a testing environment.
* ENV-009 (Release Validation): Prior to production deployment, systems must verify feature correctness, performance bounds, security checks, and database compatibility.
* ENV-010 (Future Scalability): Architecture must accommodate multi-team development, automated CI/CD pipelines, regional expansion, and scaling user volumes without core restructuring.