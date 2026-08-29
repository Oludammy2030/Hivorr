# ENGINEERING PHASE PLAN — EP-02: Trust, Identity & Financial Integrity Engine

> **Document Type:** Engineering Phase Plan | **Source:** Engineering Execution Structure EP-02 | **Status:** Ready for Review | **Priority:** Critical — Blocks All Marketplace Phases

---

## 1. Phase Overview

| Attribute | Detail |
|---|---|
| **Phase ID** | EP-02 |
| **Phase Name** | Trust, Identity & Financial Integrity Engine |
| **Phase Objective** | Build the universal trust, identity verification, and provider-agnostic, multi-currency financial infrastructure that makes safe marketplace transactions possible. |
| **Business Capability Enabled** | Business Phase 1 — Trust Foundation and Supply Seeding. Enables entity registration, credential verification, KYC compliance, a unified multi-currency financial profile with currency-specific receiving accounts and balances, provider-agnostic escrow protection, and bound payout channels. |
| **Priority** | Critical — blocks all marketplace phases |
| **Status** | Not Started |
| **Dependencies** | EP-01 (requires Universal Entity data model, authentication framework, server-side architecture, database infrastructure) |

---

## 2. Engineering Objectives

1. **Populate and operationalize the Two-Tier Taxonomy Framework** — Seed the `industries` → `professions` registry with initial data and build the server-side management RPCs and client-side taxonomy engine that all future industries plug into.
2. **Build the Entity Registration & Onboarding System** — Create the end-to-end onboarding flow from post-auth registration through profession selection, profile completion, and credential submission.
3. **Implement the Trade Verification Workflow** — Build the complete credential submission, admin review gate, and status propagation system that locks/unlocks marketplace participation per AGENT.md Rule 2.
4. **Establish the KYC Integration Framework** — Design verification levels, KYC data models, and the extensible integration seam for future identity verification providers.
5. **Build the Provider-Agnostic Financial Infrastructure** — Design and implement the server-side financial schema (accounts, balances, transactions, escrow, payouts) with full RLS + RPC enforcement, and the client-side payment gateway abstraction layer.
6. **Implement the Unified Multi-Currency Financial Profile** — Build currency-specific receiving accounts, multi-currency balances, and user-controlled currency conversion within a single entity profile.
7. **Build the Escrow & Milestone Payment Infrastructure** — Implement provider-agnostic escrow lifecycle management (fund, hold, release, refund) with milestone-based release conditions.
8. **Implement Bound Payout Accounts & Deposit Verification** — Build the payout account binding system with KYC-driven cashout limits and the payer-name-matching deposit verification engine per AGENT.md Rule 3.
9. **Establish the Dispute Resolution Framework** — Build the structured dispute filing, evidence submission, and resolution workflow integrated with escrow holds.
10. **Build the Professional Profile & Credential Display System** — Create the public-facing professional profile with verification badges, credential display, and portfolio showcase.

---

## 3. Technical Goals

| Goal | Target |
|---|---|
| Server-side financial enforcement | All financial calculations, escrow splits, balance mutations, and cashout limit enforcement execute via PostgreSQL RPC + RLS — zero financial logic in client code |
| Taxonomy operational | Industries → Professions registry seeded, browsable, and extensible without schema changes |
| Trade verification gate enforced | Unverified professionals have dashboard access but cannot bid/accept work (Rule 2) |
| KYC-driven financial limits | Cashout limits, feature access, and verification depth are proportional and server-enforced |
| Provider-agnostic payments | Payment gateway abstraction supports multiple providers; no direct provider calls in business logic |
| Multi-currency profile | Single entity holds multiple currency-specific receiving accounts and balances |
| Escrow integrity | Funds held in escrow are immutable until release conditions are met; all state changes audited |
| Name-matching enforcement | Deposits where payer name ≠ entity legal name are flagged/blocked server-side |
| Bound payout accounts | Withdrawals restricted to pre-verified bank accounts only |
| Storage infrastructure | Supabase Storage configured for credential documents and profile avatars with RLS-protected access |
| Financial audit trail | Every financial mutation produces an immutable audit record |
| Test coverage | Unit, widget, and integration tests for all new systems; financial systems require exhaustive edge-case coverage |

---

## 4. Technology Stack (Confirmed — Carried from EP-01)

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart SDK ^3.12.2) |
| Backend-as-a-Service | Supabase (PostgreSQL + Auth + RPC + RLS + Realtime + Storage + Edge Functions) |
| HTTP Client | Dio (with interceptors) |
| Routing | GoRouter (deep-linking, SEO-friendly URLs) |
| State Management | Provider |
| Local Storage | Hive (selected in EP-01-11) |
| Secure Storage | flutter_secure_storage |
| Monitoring | Sentry |
| CI/CD | GitHub Actions |
| Code Quality | flutter_lints, dart analyze, flutter test |
| File Storage | Supabase Storage (buckets for credentials, avatars) |
| Payment Providers | Paystack, Flutterwave (abstracted — provider-agnostic layer) |
| Name Verification | NIBSS name enquiry (abstracted — provider-agnostic layer) |

---

## 5. Required Systems, Modules & Components

| System / Module | Location | Purpose |
|---|---|---|
| Taxonomy seed data | Supabase SQL migrations | Initial industries + professions registry data |
| Taxonomy management RPCs | Supabase SQL migrations | Server-side CRUD for taxonomy administration |
| Verification schema & RPCs | Supabase SQL migrations | Extended verification tables (KYC levels, admin review queue, audit trail) |
| Financial schema & RPCs | Supabase SQL migrations | Accounts, balances, transactions, escrow, payouts, deposit verification — all RLS + RPC enforced |
| Dispute resolution schema | Supabase SQL migrations | Dispute cases, evidence, resolutions, audit trail |
| Supabase Storage config | Supabase Storage + RLS policies | Credential documents bucket, avatar bucket, access policies |
| Taxonomy engine | `lib/engine/` or `lib/workspace/profession_registry/` | Client-side taxonomy browsing, search, hierarchical lookup |
| Storage infrastructure | `lib/core/storage/` (extend) | File upload/download service for Supabase Storage |
| Payment gateway abstraction | `lib/integrations/payment_gateways/` | Provider-agnostic interfaces + Paystack/Flutterwave adapters |
| Identity verification system | `lib/systems/verification/` | Credential submission, status tracking, document upload |
| Trade verification system | `lib/systems/verification/` | Trade proof submission, admin review gate, bid-lock enforcement |
| KYC framework | `lib/systems/verification/` | KYC level management, limit calculation, provider integration seam |
| Multi-currency financial profile | `lib/systems/finance/` | Currency accounts, balances, receiving account management |
| Escrow management | `lib/systems/finance/` | Escrow lifecycle, milestone tracking, release/refund orchestration |
| Currency conversion | `lib/systems/finance/` | User-initiated conversion between supported currency balances |
| Payout account system | `lib/systems/finance/` | Bound bank accounts, KYC-driven cashout limits, withdrawal |
| Deposit verification | `lib/systems/finance/` | Payer name-matching engine, mismatch flagging |
| Dispute resolution engine | `lib/systems/support/` | Dispute filing, evidence submission, resolution workflow |
| Onboarding flow | `lib/systems/marketplace/` or feature screens | Multi-step registration → profession → profile → credentials |
| Professional profile display | `lib/systems/portfolio/` | Public profile with verification badges, credentials, portfolio |
| Extended data layer | `lib/data/` | New entities, DTOs, repositories, providers for all EP-02 domains |
| Extended routes | `lib/app/router/` | Onboarding, verification, financial, profile routes |

---

## 6. Recommended Engineering Development Order

**Stage 1 — Taxonomy & Registry Foundation:** EP-02-01, EP-02-02 (taxonomy seed data + management RPCs)

**Stage 2 — Extended Server-Side Schema:** EP-02-03, EP-02-04, EP-02-05 (verification schema, financial schema, dispute schema + storage config)

**Stage 3 — Client-Side Infrastructure:** EP-02-06, EP-02-07, EP-02-08 (taxonomy engine, storage service, payment gateway abstraction)

**Stage 4 — Trust & Verification Systems:** EP-02-09, EP-02-10, EP-02-11 (identity verification, trade verification, KYC framework)

**Stage 5 — Financial Integrity Systems:** EP-02-12, EP-02-13, EP-02-14, EP-02-15, EP-02-16 (multi-currency profile, escrow, conversion, payouts, deposit verification)

**Stage 6 — Dispute Resolution:** EP-02-17 (dispute framework)

**Stage 7 — User-Facing Workflows:** EP-02-18, EP-02-19 (onboarding flow, professional profile display)

**Stage 8 — Validation:** EP-02-20 (end-to-end phase validation)

---

## 7. Internal and External Dependencies

### Internal Dependencies

| Item | Depends On |
|---|---|
| EP-02-02 | EP-02-01 |
| EP-02-03 | EP-02-02 |
| EP-02-04 | EP-02-03 |
| EP-02-05 | EP-02-04 |
| EP-02-06 | EP-01 (storage infrastructure) |
| EP-02-07 | EP-02-02 |
| EP-02-08 | EP-02-06 |
| EP-02-09 | EP-01 (API layer) |
| EP-02-10 | EP-02-06, EP-02-07, EP-02-03 |
| EP-02-11 | EP-02-10, EP-02-06 |
| EP-02-12 | EP-02-10, EP-02-03 |
| EP-02-13 | EP-02-04, EP-02-09 |
| EP-02-14 | EP-02-04, EP-02-09 |
| EP-02-15 | EP-02-13, EP-02-04 |
| EP-02-16 | EP-02-04, EP-02-13, EP-02-12, EP-02-09 |
| EP-02-17 | EP-02-05, EP-02-14 |
| EP-02-18 | EP-02-07, EP-02-10, EP-02-11, EP-02-08 |
| EP-02-19 | EP-02-10, EP-02-11, EP-02-06 |
| EP-02-20 | All items |

### External Dependencies

| Dependency | Type | Impact |
|---|---|---|
| Supabase Storage bucket provisioning | Infrastructure | Required before EP-02-07 |
| Paystack API credentials (test mode) | Integration | Required for EP-02-08 payment gateway testing |
| Flutterwave API credentials (test mode) | Integration | Required for EP-02-08 payment gateway testing |
| NIBSS name enquiry API access | Integration | Required for EP-02-16 deposit name verification |
| KYC provider evaluation & credentials | Integration | Required for EP-02-11 (integration seam only — provider selection may be deferred) |
| Supabase Edge Functions deployment | Infrastructure | May be required for webhook handling (payment callbacks, KYC callbacks) |
| Admin review interface (or tooling) | Tooling | Required for EP-02-10 trade verification admin gate |

---

## 8. Risks, Assumptions & Engineering Considerations

### Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Financial schema designed incorrectly | Catastrophic — affects all transaction phases (EP-03+) | Extremely High reasoning. Validate against EP-03, EP-04, EP-05 financial requirements before finalizing. Exhaustive pgTAP test suite. |
| Escrow logic has edge cases (partial release, refund, dispute hold) | High — financial loss | Server-side enforcement only. Comprehensive state machine with audit trail. Edge-case test matrix. |
| Payment gateway abstraction too tightly coupled to one provider | Medium — limits provider-agnostic goal | Interface-first design. Two provider adapters (Paystack + Flutterwave) to validate abstraction. |
| KYC provider not yet selected | Medium — blocks full KYC integration | Build the integration seam (abstract interface). Concrete provider adapter deferred. Mock adapter for testing. |
| Currency conversion regulatory complexity | Medium — feature may be constrained by jurisdiction | Build the infrastructure and interface. Conversion rules are server-side config-driven, not hardcoded. |
| Name-matching false positives blocking legitimate deposits | Medium — user friction | Configurable matching threshold. Manual review queue for edge cases. Audit trail for all decisions. |
| Admin review bottleneck at scale | Medium — verification SLA breach | Build structured review queue with filtering, prioritization. Future automation seam. |
| Supabase Storage RLS misconfiguration | High — document leakage | Default-deny. Explicit per-bucket policies. pgTAP storage policy tests. |
| Multi-currency balance inconsistency | High — financial integrity breach | All balance mutations via server-side RPC with transaction-level atomicity. Double-entry accounting pattern. |

### Assumptions

1. EP-01 is fully complete with all 20 items at "Completed" status and the Foundation Verification Report confirms EP-02 readiness as GO.
2. Supabase Storage is available and configurable within the existing Supabase projects.
3. Paystack and Flutterwave test/sandbox APIs are sufficient for development and integration testing.
4. NIBSS name enquiry API is accessible for deposit verification development.
5. KYC provider selection may be deferred — the abstract integration seam is the EP-02 deliverable, not a live KYC provider connection.
6. Admin review is performed via a structured admin interface (which may be a simplified internal tool or Supabase dashboard in EP-02, with a full admin panel in a later phase).
7. Initial taxonomy seed data covers a focused set of industries and professions for the Nigerian market.
8. Currency support initially targets NGN (primary), with GHS, USD, and GBP as secondary currencies for infrastructure validation.
9. Supabase Edge Functions can handle payment webhook reception if needed.
10. Provider state management (from EP-01) is sufficient for EP-02 data complexity.

### Engineering Considerations

1. **Financial logic is server-side only.** Every balance mutation, escrow state change, cashout limit check, and name-matching comparison executes via PostgreSQL RPC. The client is purely a presentation and orchestration layer.
2. **Double-entry accounting pattern.** Financial schema should use a transaction-based model where every credit has a corresponding debit. Balance is derived, not stored as a mutable column (or stored as a materialized view/cache with server-side reconciliation).
3. **Provider-agnostic is a first-class design constraint.** The payment gateway abstraction must support adding new providers (Thunes, mobile money, stablecoin rails) without modifying business logic. EP-08 depends on this.
4. **Taxonomy is universal.** The industries → professions registry must be extensible to any future industry without schema changes. New industries are data inserts, not migrations.
5. **Trade verification gate is binary and server-enforced.** `trade_verification_status == APPROVED` is the only unlock condition for bidding/accepting work. No client-side bypass is possible.
6. **Legal name is the financial anchor.** The `entity_profiles.legal_name` field (already protected by the EP-01 guard trigger) is the single source of truth for deposit name-matching and payout account verification.
7. **Escrow is provider-agnostic.** Escrow state is managed entirely within Hivorr's database. Payment providers handle fund movement; Hivorr handles lifecycle state.
8. **All EP-02 UI must consume `AppTheme` tokens** per VISUAL-IDENTITY.md. Any hardcoded color or font fails Definition of Done.
9. **Supabase Edge Functions** may be needed for payment webhooks, KYC callbacks, and async verification results. These are server-side infrastructure, not client code.
10. **Domain separation.** No industry-specific or profession-specific logic is built in EP-02. All systems are universal platform infrastructure.

---

## 9. Expected Phase Outcome

A fully operational trust and identity engine where entities can register through a structured onboarding flow, select professions from a seeded two-tier taxonomy, submit credentials for verification, pass trade verification with admin review, and operate within a secure, provider-agnostic, multi-currency financial infrastructure — including unified financial profiles, escrow-protected transactions, bound payout accounts with KYC-driven limits, name-matching deposit verification, and structured dispute resolution — all before any marketplace transactions are enabled.

---

## 10. Phase Completion Criteria

| Criterion | Verification |
|---|---|
| Taxonomy registry seeded with initial industries + professions | Database query verification |
| Taxonomy management RPCs functional (CRUD + activate/deactivate) | RPC integration tests |
| Client-side taxonomy engine browses industries → professions | Widget + integration test |
| Verification schema extended with KYC levels + admin review queue | Schema review + migration verification |
| Financial schema with accounts, balances, transactions, escrow, payouts | Schema review + pgTAP financial test suite |
| All financial RPCs enforce server-side logic (zero client-side financial math) | RLS + RPC enforcement tests |
| Dispute resolution schema with cases, evidence, resolutions | Schema review + migration verification |
| Supabase Storage buckets configured with RLS | Storage policy tests |
| Payment gateway abstraction supports Paystack + Flutterwave adapters | Adapter integration tests |
| Identity verification flow: submit → pending → reviewed → status update | End-to-end integration test |
| Trade verification gate: unverified → pending → approved; bid-lock enforced | Integration test confirming bid-lock |
| KYC level management with server-enforced cashout limits | RPC + limit enforcement tests |
| Multi-currency financial profile: create accounts, view balances | Integration test |
| Escrow lifecycle: fund → hold → release/refund with audit trail | End-to-end escrow test |
| Currency conversion between supported balances (infrastructure) | RPC test |
| Bound payout accounts with name verification | Integration test |
| Deposit name-matching flags mismatched payer names | Name-matching RPC test |
| Dispute resolution flow: file → evidence → resolve | Integration test |
| Onboarding flow: register → profession → profile → credentials | End-to-end flow test |
| Professional profile displays verification badges + credentials | Widget test + visual check |
| All new tables RLS-protected with default-deny | pgTAP security posture audit |
| No financial logic in client code | Static analysis + code review |
| All UI consumes AppTheme tokens (no hardcoded colors/fonts) | Widget test assertions |
| All EP-02 items at "Completed" | Phase plan audit |

---

## 11. Engineering Roadmap Items

### EP-02-01: Two-Tier Taxonomy Seed Data & Registry Population

| Attribute | Detail |
|---|---|
| **Objective** | Create SQL migration(s) to seed the `industries` and `professions` tables with an initial set of industries and their associated professions for the Nigerian market. Define SEO-stable slugs, sort ordering, and active status. |
| **Engineering Purpose** | The taxonomy registry is the universal classification system all future industries plug into. Without seed data, entities cannot bind professions, verification cannot be tested, and onboarding flows cannot be validated. This is the data foundation for the entire trust system. |
| **Dependencies** | EP-01-06 (industries + professions tables exist) |
| **Expected Outcome** | SQL migration seeding with initial industries (e.g., Legal, Technology, Healthcare, Construction, Financial Services, Creative, Education, Logistics) with 3-8 professions each. All slugs unique, all FKs valid. Data verifiable via SELECT query. |
| **Priority** | Critical | **Status** | Completed |
| **Planning Reasoning** | High | **Coding Reasoning** | Medium |

### EP-02-02: Taxonomy Management RPCs & Server-Side Registry

| Attribute | Detail |
|---|---|
| **Objective** | Build server-side RPCs for taxonomy administration: `taxonomy_industries_list`, `taxonomy_professions_list` (by industry), `taxonomy_industry_create/update`, `taxonomy_profession_create/update`, `taxonomy_profession_move` (re-parent to different industry). All service-role gated for writes; public read for list operations. |
| **Engineering Purpose** | Provides the server-side management layer for the taxonomy registry. Write operations must be admin-only (service role). Read operations must be efficient and cacheable. Future admin UI and client-side taxonomy engine both consume these RPCs. |
| **Dependencies** | EP-02-01 |
| **Expected Outcome** | RPCs for taxonomy CRUD. List RPCs accessible to authenticated users. Write RPCs restricted to service role. pgTAP tests for authorization, validation, and referential integrity. Slug uniqueness enforced server-side. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-03: Verification & Admin Review Schema Extension

| Attribute | Detail |
|---|---|
| **Objective** | Design and implement extended database schema for verification workflows: `entity_kyc_levels` (verification tier with associated limits), `verification_submissions` (unified submission queue for identity documents and trade proofs), `verification_reviews` (admin review decisions with reviewer, decision, notes, timestamps), and `verification_audit_trail` (immutable log of all verification state changes). Build RPCs for submission, review, status propagation, and limit enforcement. |
| **Engineering Purpose** | Extends the EP-01 verification schema (entity_credentials, entity_professions.trade_verification_status) into a full verification workflow engine. The admin review gate is the trust checkpoint that controls marketplace access. KYC levels drive financial limits in later EP-02 items. |
| **Dependencies** | EP-02-02 |
| **Expected Outcome** | New tables with full RLS (default-deny). RPCs: `verification_submit`, `verification_review_approve`, `verification_review_reject`, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`. Admin review operations restricted to service role. Entity can only submit for self. pgTAP test suite. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-04: Financial Integrity Database Schema & Server-Side Enforcement

| Attribute | Detail |
|---|---|
| **Objective** | Design and implement the complete financial database schema: `financial_profiles` (unified per-entity financial identity), `financial_currency_accounts` (currency-specific receiving accounts: NGN, GHS, USD, GBP), `financial_balances` (currency-specific available/held/pending balances), `financial_transactions` (immutable double-entry transaction ledger), `financial_escrow` (escrow records with lifecycle state machine), `financial_escrow_milestones` (milestone-based release conditions), `financial_payout_accounts` (bound bank accounts), `financial_payouts` (withdrawal records), `financial_deposits` (incoming payment records with payer name), `financial_conversions` (currency conversion records), `financial_audit_trail` (immutable financial audit log). All mutations via RPC. All RLS-protected. |
| **Engineering Purpose** | **Most architecturally significant item in EP-02.** This schema is the financial bedrock for all marketplace transactions (EP-03+). Every escrow hold, every payout, every balance check, every name-match runs through these tables and their RPCs. Incorrect design here creates catastrophic financial risk. Must support multi-currency, provider-agnostic, double-entry accounting with full audit trail. |
| **Dependencies** | EP-02-03 |
| **Expected Outcome** | 11+ financial tables with full RLS (default-deny). RPCs for all financial operations: balance queries, transaction recording, escrow lifecycle (create/fund/hold/release/refund), payout creation, deposit recording, conversion. All balance mutations atomic and server-side. Double-entry integrity enforced. pgTAP financial test suite covering edge cases (partial release, refund, disputed hold, limit breach). Zero financial logic accessible to client. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-05: Dispute Resolution Schema & Server-Side Rules

| Attribute | Detail |
|---|---|
| **Objective** | Design and implement the dispute resolution database schema: `dispute_cases` (case with type, status, parties, linked transaction/escrow), `dispute_evidence` (evidence submissions by either party), `dispute_resolutions` (resolution decisions with outcome, reasoning, financial adjustments), `dispute_audit_trail` (immutable case history). Build RPCs for filing, evidence submission, resolution, and escrow hold/release integration. |
| **Engineering Purpose** | Provides the structured dispute resolution framework that protects both parties in transactions. Must integrate with escrow (disputed escrow cannot be released until dispute is resolved). Evidence-based resolution rather than ad-hoc complaint handling. |
| **Dependencies** | EP-02-04 |
| **Expected Outcome** | Dispute tables with full RLS. RPCs: `dispute_file`, `dispute_submit_evidence`, `dispute_resolve`, `dispute_get`, `dispute_list`. Dispute filing places an automatic hold on linked escrow. Resolution can trigger escrow release or refund. Admin/service-role for resolution operations. pgTAP test suite. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-06: Supabase Storage Infrastructure & Bucket Configuration

| Attribute | Detail |
|---|---|
| **Objective** | Configure Supabase Storage buckets for credential documents (`credential-documents`), profile avatars (`profile-avatars`), and portfolio items (`portfolio-items`). Define bucket-level and object-level RLS policies ensuring entities can only access their own documents. Implement file size limits, type restrictions, and path conventions. |
| **Engineering Purpose** | Verification workflows require document upload (identity documents, trade proofs, certifications). Profile completion requires avatar upload. Storage must be as secure as the database — RLS-protected, no public access to sensitive documents. |
| **Dependencies** | EP-01-05 (Supabase project provisioned) |
| **Expected Outcome** | Storage buckets created with RLS policies. Credential documents: private, owner-only access. Profile avatars: public read, owner write. Portfolio items: public read, owner write. File size and type constraints enforced. Storage policy tests verify no unauthorized access. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-07: Client-Side Taxonomy Engine & Profession Registry

| Attribute | Detail |
|---|---|
| **Objective** | Build the client-side taxonomy engine in `lib/workspace/profession_registry/` — industry browsing, profession listing by industry, hierarchical navigation, search/filter, and caching. Build the data layer (entities, DTOs, repositories, providers) for taxonomy data. |
| **Engineering Purpose** | Entities must browse and select industries/professions during onboarding. The taxonomy engine is also used by the professional profile display and future marketplace discovery. Must be efficient (cached) and support the two-tier hierarchy. |
| **Dependencies** | EP-02-02 |
| **Expected Outcome** | Taxonomy service with industry list, profession list (by industry), search, caching. Data layer: `Industry` entity, `Profession` entity, DTOs, mappers, repository, provider. Profession registry widget for browsing/selecting. Integration test verifying data flow from RPC → cache → UI. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-02-08: Storage Service & File Upload Infrastructure

| Attribute | Detail |
|---|---|
| **Objective** | Extend `lib/core/storage/` with a Supabase Storage service supporting file upload (with progress tracking), download, deletion, and URL generation. Implement file type validation, size limit enforcement, and path convention helpers. Integrate with the storage buckets configured in EP-02-06. |
| **Engineering Purpose** | Verification workflows, profile completion, and portfolio display all require file upload/download. The storage service abstracts Supabase Storage behind a clean interface, enabling future storage provider changes. |
| **Dependencies** | EP-02-06 |
| **Expected Outcome** | `StorageService` with upload (progress callback), download, delete, getPublicUrl. File type validation (images, PDFs). Size limit enforcement. Path helpers for credential/avatar/portfolio paths. Integration test with Supabase Storage. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-02-09: Payment Gateway Abstraction Layer

| Attribute | Detail |
|---|---|
| **Objective** | Build the provider-agnostic payment gateway abstraction in `lib/integrations/payment_gateways/` — define abstract interfaces for payment initialization, charge creation, status checking, webhook handling, and refund processing. Implement concrete adapters for Paystack and Flutterwave. Define the NIBSS name enquiry interface for deposit verification. |
| **Engineering Purpose** | AGENT.md Rule 4 and the Financial Infrastructure Strategy require provider-agnostic financial integration. No direct provider calls in business logic. Two adapters validate the abstraction is genuinely provider-agnostic. The NIBSS interface enables name-matching in EP-02-16. |
| **Dependencies** | EP-01-07 (API layer) |
| **Expected Outcome** | Abstract `PaymentGateway` interface with methods: `initializePayment`, `verifyPayment`, `createTransfer`, `verifyTransfer`, `getNameEnquiry`. Concrete `PaystackGateway` and `FlutterwaveGateway` adapters. `NameEnquiryService` interface with `NibssNameEnquiryAdapter`. Gateway factory/registry for provider selection. Unit tests with mock HTTP responses. No provider-specific types leak into business logic. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-10: Identity Verification System

| Attribute | Detail |
|---|---|
| **Objective** | Build the identity verification system in `lib/systems/verification/` — document upload flow (identity documents: national ID, passport, driver's license), submission to verification queue, real-time status tracking (pending/approved/rejected), KYC level assignment, and notification integration for status changes. Build the data layer for verification submissions and reviews. |
| **Engineering Purpose** | Identity verification is the first trust checkpoint. Entities must verify their identity before accessing financial features and before trade verification can proceed. This system connects the client-side upload UX to the server-side verification schema (EP-02-03). |
| **Dependencies** | EP-02-06 (storage), EP-02-07 (taxonomy), EP-02-03 (verification schema) |
| **Expected Outcome** | Verification service: submit identity document, check status, get KYC level. Data layer: `VerificationSubmission` entity, DTO, repository, provider. UI: document upload screen, verification status screen, status tracking widget. Notification integration for status changes. Integration test: submit → pending → (mock) approve → status update. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-11: Trade Verification Workflow & Admin Review Gate

| Attribute | Detail |
|---|---|
| **Objective** | Build the trade verification system — trade proof submission (certificates, licenses, work samples), the admin review gate workflow, `trade_verification_status` propagation (unverified → pending → approved/rejected), and the bid-lock enforcement that prevents unverified professionals from bidding or accepting work per AGENT.md Rule 2. Build admin review queue interface (simplified for EP-02). |
| **Engineering Purpose** | Trade verification is the marketplace participation gate. This is the core trust mechanism: unverified professionals have dashboard access but cannot participate in transactions. The admin review gate ensures human validation before marketplace activation. |
| **Dependencies** | EP-02-10 (identity verification), EP-02-06 (taxonomy) |
| **Expected Outcome** | Trade verification service: submit trade proof, check trade verification status, get bid-lock state. UI: trade proof upload screen, verification status with timeline. Admin review interface (simplified): pending submissions list, approve/reject with notes. Bid-lock enforcement verified server-side and reflected client-side. Integration test: bind profession → submit trade proof → admin approve → bid-lock released. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-12: KYC Integration Framework & Verification Level Management

| Attribute | Detail |
|---|---|
| **Objective** | Build the KYC framework — KYC level definitions (tier 0-3 with increasing verification depth), level-based financial limit enforcement (daily/weekly/monthly transaction limits, cashout limits), KYC status tracking, and the abstract integration seam for future KYC providers. Build the client-side KYC status display and upgrade flow. |
| **Engineering Purpose** | KYC levels drive proportional financial risk containment. Higher verification depth unlocks higher limits. The abstract KYC provider interface allows future integration with identity verification services without redesigning the limit enforcement system. |
| **Dependencies** | EP-02-10 (identity verification), EP-02-03 (verification schema with KYC levels) |
| **Expected Outcome** | KYC service: get current level, get applicable limits, request level upgrade. KYC level definitions with server-enforced limits. Abstract `KycProvider` interface with mock adapter. UI: KYC status display, level upgrade flow, limit visibility. Integration test: level upgrade → limit increase verified server-side. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-13: Multi-Currency Financial Profile System

| Attribute | Detail |
|---|---|
| **Objective** | Build the unified multi-currency financial profile system in `lib/systems/finance/` — financial profile creation, currency-specific receiving account management (request, view, activate), multi-currency balance display (available, held, pending per currency), and financial preferences. Build the complete data layer for financial profiles, currency accounts, and balances. |
| **Engineering Purpose** | The unified multi-currency financial profile is a core business capability. Each entity has one financial profile holding multiple currency accounts and balances. This is the foundation that escrow, payouts, conversions, and deposits all operate against. |
| **Dependencies** | EP-02-04 (financial schema), EP-02-09 (payment gateway abstraction) |
| **Expected Outcome** | Financial profile service: create profile, list currency accounts, get balances, request receiving account. Data layer: `FinancialProfile`, `CurrencyAccount`, `Balance` entities, DTOs, repositories, providers. UI: financial profile screen, currency accounts list, balance display per currency. Integration test: profile creation → account request → balance query. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-14: Escrow & Milestone Payment Management

| Attribute | Detail |
|---|---|
| **Objective** | Build the escrow management system — escrow creation, funding, milestone definition, milestone completion tracking, release on verified milestone completion, refund processing, and dispute-hold integration. Build the data layer for escrow records and milestones. All financial calculations server-side. |
| **Engineering Purpose** | Escrow is the financial protection mechanism for all marketplace transactions. EP-03 (professional services) and EP-04 (commerce) both depend on proven escrow infrastructure. The milestone-based release model must be validated here before transaction phases begin. |
| **Dependencies** | EP-02-04 (financial schema), EP-02-09 (payment gateway) |
| **Expected Outcome** | Escrow service: create escrow with milestones, fund escrow, report milestone completion, request release, request refund. Data layer: `Escrow`, `EscrowMilestone` entities, DTOs, repositories, providers. UI: escrow creation flow, milestone tracker widget, escrow status display. Integration test: create → fund → milestone complete → release with balance verification. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-15: Currency Conversion Infrastructure

| Attribute | Detail |
|---|---|
| **Objective** | Build the currency conversion infrastructure — user-initiated conversion between supported currency balances, rate fetching (from server-side config or provider), conversion preview with fees, and conversion execution with audit trail. Build the data layer for conversion records. |
| **Engineering Purpose** | The Financial Infrastructure Strategy requires user-controlled currency conversion between supported balances (e.g., GHS↔NGN, USD↔NGN). Conversion is server-side enforced with rate validation and fee calculation. The infrastructure must support future provider-based rate feeds. |
| **Dependencies** | EP-02-13 (multi-currency profile), EP-02-04 (financial schema) |
| **Expected Outcome** | Conversion service: get available pairs, preview conversion (rate + fees), execute conversion. Data layer: `CurrencyConversion` entity, DTO, repository. UI: conversion screen with preview and confirmation. Server-side rate validation. Integration test: preview → execute → balances updated correctly. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-16: Bound Payout Account System & Deposit Name Verification

| Attribute | Detail |
|---|---|
| **Objective** | Build two integrated financial systems: (1) Payout account system — bank account binding with ownership verification, KYC-driven cashout limit enforcement, withdrawal initiation, and payout status tracking. (2) Deposit name verification — payer name capture on incoming deposits, server-side name-matching against `entity_profiles.legal_name`, mismatch flagging/blocking per AGENT.md Rule 3. Build the data layer for payout accounts, payouts, and deposits. |
| **Engineering Purpose** | Payout accounts enforce that withdrawals only go to pre-verified bank accounts (eliminating payout fraud). Name-matching enforces that deposits come from the entity's own identity (preventing third-party fraud). Both are core trust mechanisms defined in AGENT.md Rules 3 and the Business Roadmap. |
| **Dependencies** | EP-02-04 (financial schema), EP-02-13 (financial profile), EP-02-12 (KYC limits), EP-02-09 (payment gateway with NIBSS interface) |
| **Expected Outcome** | Payout service: bind bank account, verify account ownership (name enquiry), initiate withdrawal (within limits), track payout status. Deposit verification service: record deposit with payer name, trigger name-match check, flag mismatches. Data layer: `PayoutAccount`, `Payout`, `Deposit` entities, DTOs, repositories, providers. UI: payout account management, withdrawal screen with limit display, deposit verification status. Integration tests: bind account → name verify → withdraw within limit; deposit with matching name → accepted; deposit with mismatched name → flagged. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | **Extremely High** | **Coding Reasoning** | **Extremely High** |

### EP-02-17: Dispute Resolution Framework

| Attribute | Detail |
|---|---|
| **Objective** | Build the dispute resolution system in `lib/systems/support/` — dispute filing (linked to transaction/escrow), evidence submission (documents, descriptions, screenshots), case status tracking, resolution display, and integration with escrow holds (disputed escrow frozen until resolved). Build the data layer for dispute cases, evidence, and resolutions. |
| **Engineering Purpose** | Dispute resolution is the safety net for marketplace trust. When transactions go wrong, structured evidence-based resolution protects both parties. Integration with escrow ensures disputed funds cannot be released prematurely. |
| **Dependencies** | EP-02-05 (dispute schema), EP-02-14 (escrow management) |
| **Expected Outcome** | Dispute service: file dispute, submit evidence, get case status, view resolution. Data layer: `DisputeCase`, `DisputeEvidence`, `DisputeResolution` entities, DTOs, repositories, providers. UI: dispute filing form, evidence submission screen, case tracker, resolution display. Escrow integration: filing a dispute places automatic hold on linked escrow. Integration test: file dispute → submit evidence → (mock) resolve → escrow released/refunded. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | Very High | **Coding Reasoning** | Very High |

### EP-02-18: Entity Registration & Onboarding Flow

| Attribute | Detail |
|---|---|
| **Objective** | Build the end-to-end onboarding flow — post-authentication registration completion (profile setup: legal name, display name, bio, avatar upload), industry/profession selection from the taxonomy registry, credential submission for identity verification, and trade proof submission for professional roles. Implement multi-step wizard UI with progress tracking, validation, and resumability. |
| **Engineering Purpose** | The onboarding flow is the entity's first interaction with the trust system. It must guide users through registration, profession binding, and verification submission in a structured, non-overwhelming sequence. This flow integrates taxonomy engine, storage service, identity verification, and trade verification into a cohesive user experience. |
| **Dependencies** | EP-02-07 (taxonomy engine), EP-02-10 (identity verification), EP-02-11 (trade verification), EP-02-08 (storage service) |
| **Expected Outcome** | Multi-step onboarding flow: (1) Profile completion (legal name, display name, avatar), (2) Industry selection, (3) Profession selection, (4) Identity document upload, (5) Trade proof upload (for professional role). Progress indicator. Form validation. Resumable (can exit and return). Route integration with GoRouter. Integration test: complete full onboarding flow from post-auth to verification submission. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-02-19: Professional Profile & Credential Display System

| Attribute | Detail |
|---|---|
| **Objective** | Build the professional profile display system in `lib/systems/portfolio/` — public-facing professional profile page with verification badges (identity verified, trade verified), credential display, profession information, portfolio showcase (work samples, project descriptions), and trust signals (KYC level indicator, verification status). Build the data layer for portfolio items. |
| **Engineering Purpose** | The professional profile is the trust-visible output of the entire verification system. It signals credibility to potential clients and is the foundation for EP-03 marketplace discovery. Must be SEO-friendly (public URL per ARCHITECTURE.md routing rules) and responsive across mobile/web. |
| **Dependencies** | EP-02-10 (identity verification), EP-02-11 (trade verification), EP-02-07 (taxonomy) |
| **Expected Outcome** | Professional profile screen with: entity display info, profession + industry badges, verification status badges (identity verified, trade approved), credential display, portfolio grid. Public route (`/p/:profession_slug/:entity_id`). SEO-friendly URL. Responsive layout (mobile + web). Data layer: `PortfolioItem` entity, DTO, repository, provider. Widget tests verifying badge rendering and theme compliance. |
| **Priority** | High | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

### EP-02-20: Phase Integration Validation & Trust System Verification

| Attribute | Detail |
|---|---|
| **Objective** | End-to-end validation of all EP-02 systems: complete onboarding flow through full stack, taxonomy browsing, verification submission through admin review, financial profile creation, escrow lifecycle, payout with name verification, deposit name-matching, currency conversion, dispute filing and resolution, professional profile display, EP-03 readiness verification. |
| **Engineering Purpose** | Individual systems may work in isolation but fail when integrated. This is the final gate before EP-02 is marked complete and EP-03 is unblocked. Must validate that all trust, identity, and financial systems work together under realistic conditions. |
| **Dependencies** | All EP-02 items |
| **Expected Outcome** | 12-point validation: (1) Full onboarding flow end-to-end, (2) Taxonomy browse → select → bind, (3) Identity verification submit → review → approve, (4) Trade verification submit → admin review → bid-lock released, (5) KYC level upgrade → limit increase, (6) Financial profile creation → currency account → balance display, (7) Escrow create → fund → milestone → release, (8) Currency conversion preview → execute → balances updated, (9) Payout account bind → name verify → withdraw within limit, (10) Deposit name-match → accept/flag, (11) Dispute file → evidence → resolve → escrow action, (12) Professional profile renders with badges on mobile + web. All financial operations verified server-side only. No hardcoded colors/fonts. EP-02 complete, EP-03 unblocked. |
| **Priority** | Critical | **Status** | Not Started |
| **Planning Reasoning** | High | **Coding Reasoning** | High |

---

## 12. Roadmap Summary Matrix

| Task ID | Task Name | Priority | Plan Reasoning | Code Reasoning | Dependencies | Status |
|---|---|---|---|---|---|---|
| EP-02-01 | Taxonomy Seed Data & Registry Population | Critical | High | Medium | None | Completed |
| EP-02-02 | Taxonomy Management RPCs & Registry | High | Very High | Very High | 01 | Not Started |
| EP-02-03 | Verification & Admin Review Schema | Critical | **Extremely High** | **Extremely High** | 02 | Not Started |
| EP-02-04 | Financial Integrity Schema & Enforcement | Critical | **Extremely High** | **Extremely High** | 03 | Not Started |
| EP-02-05 | Dispute Resolution Schema & Rules | High | **Extremely High** | **Extremely High** | 04 | Not Started |
| EP-02-06 | Supabase Storage Infrastructure | High | Very High | Very High | EP-01 | Not Started |
| EP-02-07 | Taxonomy Engine & Profession Registry | High | High | High | 02 | Not Started |
| EP-02-08 | Storage Service & File Upload | High | High | High | 06 | Not Started |
| EP-02-09 | Payment Gateway Abstraction Layer | Critical | **Extremely High** | **Extremely High** | EP-01 | Not Started |
| EP-02-10 | Identity Verification System | High | Very High | Very High | 06, 07, 03 | Not Started |
| EP-02-11 | Trade Verification & Admin Review Gate | Critical | Very High | Very High | 10, 06 | Not Started |
| EP-02-12 | KYC Framework & Verification Levels | High | Very High | Very High | 10, 03 | Not Started |
| EP-02-13 | Multi-Currency Financial Profile | Critical | Very High | Very High | 04, 09 | Not Started |
| EP-02-14 | Escrow & Milestone Payment Management | Critical | **Extremely High** | **Extremely High** | 04, 09 | Not Started |
| EP-02-15 | Currency Conversion Infrastructure | High | Very High | Very High | 13, 04 | Not Started |
| EP-02-16 | Payout Accounts & Deposit Verification | Critical | **Extremely High** | **Extremely High** | 04, 13, 12, 09 | Not Started |
| EP-02-17 | Dispute Resolution Framework | High | Very High | Very High | 05, 14 | Not Started |
| EP-02-18 | Entity Registration & Onboarding Flow | High | High | High | 07, 10, 11, 08 | Not Started |
| EP-02-19 | Professional Profile & Credential Display | High | High | High | 10, 11, 07 | Not Started |
| EP-02-20 | Phase Integration Validation | Critical | High | High | All | Not Started |

---

## 13. Reasoning Level Distribution

| Level | Items | Count |
|---|---|---|
| **Extremely High** | EP-02-03, EP-02-04, EP-02-05, EP-02-09, EP-02-14, EP-02-16 | 6 |
| **Very High** | EP-02-02, EP-02-06, EP-02-10, EP-02-11, EP-02-12, EP-02-13, EP-02-15, EP-02-17 | 8 |
| **High** | EP-02-01, EP-02-07, EP-02-08, EP-02-18, EP-02-19, EP-02-20 | 6 |
| **Medium** | None | 0 |
| **Low** | None | 0 |

The concentration of Extremely High items (6 of 20) reflects the financial and security-critical nature of this phase — database schema for financial integrity, escrow lifecycle, payment gateway architecture, payout/deposit verification, and dispute resolution all carry catastrophic risk if designed incorrectly. The Very High concentration (8 of 20) reflects the complex backend systems, verification workflows, and integration architecture required. No items fall below High because EP-02 builds foundational trust infrastructure where even "simpler" tasks carry significant business impact.

---

> **Next Step:** Upon approval, EP-02-01 (Two-Tier Taxonomy Seed Data & Registry Population) and EP-02-06 (Supabase Storage Infrastructure) begin execution as the first unblocked items.