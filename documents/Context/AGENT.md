# AGENT.md — Hivorr AI Development & Planning Directive

## Core Operational Directives
* **Strictly Bounded Scope:** Only act upon the specific tasks, prompts, or files explicitly provided in the current conversation. Do not assume, search for, or reference unprovided roadmaps, external files, or hidden plans.
* **Separation of Concerns:** Keep business logic strictly separate from presentation UI. Never hardcode platform logic or financial rules inside client presentation code.
* **Proprietary Logic Protection (Server-Side Enforcement):** Never embed proprietary business logic, pricing formulas, matching algorithms, or operational rules inside the client application code. All core business intelligence must remain hidden and execute securely on the server-side to prevent reverse-engineering or decompilation.
* **Deterministic Core Supremacy:** Internal platform recommendation algorithms and deterministic decision engines make all core operational, financial, search ranking, and routing decisions. The AI never overrides them.
* **Code Standards:** Write modular, reusable, clean, null-safe Dart/Flutter code. Always check and reuse existing utilities before creating new components.
* **Clarification First:** Always ask for clarification instead of making assumptions regarding business logic or feature requirements.

---

## Non-Negotiable System & Security Guardrails
* **Rule 1 (Engine vs. AI):** Core platform intelligence, routing, and payouts are handled by dedicated system engines. The AI handles conversational wrappers and drafting helpers only; it never decides marketplace rankings or financial splits.
* **Rule 2 (Two-Tier Taxonomy & Verification):** Onboarding follows Industry $\rightarrow$ Profession. Unverified pros receive dashboard access immediately, but job bidding/accepting is locked until `tradeVerificationStatus == APPROVED`.
* **Rule 3 (Financial Guardrails):** Deposit webhooks enforce `Payer Name == Entity Profile Name`. Payouts are restricted to bound, pre-verified bank accounts with strict KYC-driven cashout limits.
* **Rule 4 (Database-First Logic & Zero-Trust Client):** Sensitive financial calculations, pricing logic, escrow splitting, and cryptographic verification checks must **never** reside inside the client app code. All critical state changes must execute server-side via PostgreSQL Stored Procedures (RPC) protected by Row-Level Security (RLS).
* **Rule 5 (Visual Identity & Design Tokens):** All UI MUST consume `AppTheme` tokens (`ColorScheme` + `AppThemeExtension` for color, `TextTheme` for type, `assets/images/logo*.svg` for the brand mark) defined in `documents/Context/VISUAL-IDENTITY.md`. Never hardcode `Colors.*`/raw hex in widgets, never set `fontFamily` per-widget, and never introduce a third brand hue. `VISUAL-IDENTITY.md` is the project-wide source of truth across EP-01 → EP-08; any UI task that hardcodes a color or font fails its Definition of Done.