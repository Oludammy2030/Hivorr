# AGENTS.md — Hivorr AI Development Directive

> **STATUS: APPROVED — 1 November 2026.**
> This document supersedes both the previous project `AGENTS.md` and the legacy `AGENT.md`.
> Its visual rules are derived from the new prototype, which is the visual authority for Hivorr.
> Items marked **OPEN** remain undecided and are not approved requirements.
> **Cross-reference update — 6 November 2026:** §0, §3 and §6 now point at
> `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` §19 (audit readiness by design). No rule in this
> document changed meaning; the binding policy lives in the standards.
> **Application security update — 6 November 2026:** §0, §1, §4A and §6 now point at
> `OWASP_APPLICATION_SECURITY_STANDARD.md`, the AfriNova-wide OWASP baseline applied through the
> Hivorr standards. §4A is mandatory for every change in its stated scope.

---

## About This Project

Hivorr is the product name. It is built and operated by **AfriNova**, the company. Use "Hivorr"
for anything user-facing (UI copy, titles, emails, docs about the app). Use "AfriNova" only when
referring to the company itself (legal, ownership, corporate context).

**Stack (decided 1 November 2026):** React 18 + Vite 6 + TypeScript + Tailwind CSS 4, running
inside Figma Make. This is the prototype's stack, adopted as the project stack. Do not introduce
Dart/Flutter or another framework; the legacy Flutter directive is superseded.

### Development Server

A Vite development server is always running on `$PORT` (default 8443). Source changes are
reflected through hot reload.

### Key Files

- `src/main.tsx` — browser entry point
- `src/app/App.tsx` — the prototype: all screens, shared components, and design tokens
- `src/styles/theme.css` — the CSS token layer (prototype palette, radii, sidebar tokens)
- `src/styles/fonts.css` — loads Plus Jakarta Sans and Inter
- `documents/Context/VISION.md` — approved product vision
- `documents/Context/ARCHITECTURE.md` — approved technical architecture
- `documents/Context/VISUAL-IDENTITY.md` — visual identity and design-system reference
- `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` — approved account and
  permission model
- `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` — approved database,
  migration, grant, RLS, and Supabase Data API governance
- `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` — engineering, security,
  quality and technical-decision standards: how work is done, verified and gated
- `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md` — AfriNova-wide OWASP application
  security baseline: mandatory control requirements, OWASP mappings, evidence expectations, and
  agent obligations for security-relevant work
- `vite.figma.config.ts` — Figma Make wrapper configuration
- `.mise.toml` — toolchain versions

### Project Guidelines

The project guidelines are the approved documents in `documents/Context/`. Read and follow them
unless the user requests otherwise. In order of concern:

- `VISION.md` — product direction.
- `ARCHITECTURE.md` — system design, and the consolidated open-decision register (§16.4).
- `Unified-Account-and-Activity-Permission-Matrix.md` — who may do what.
- `Database-Migration-and-Supabase-Data-API-Rules.md` — how the database is reached and changed.
- `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` — how engineering work is done, reviewed,
  tested and gated.
- `OWASP_APPLICATION_SECURITY_STANDARD.md` — the AfriNova-wide application security baseline,
  applied through the engineering standards; mandatory when a change is in its stated scope (§4A).
- `VISUAL-IDENTITY.md` — the written visual reference derived from the prototype.

`guidelines/Guidelines.md` is a pointer to these documents and holds no rules of its own.

---

## 0. Scope

This document governs how AI coding agents work on Hivorr. It does not define the product —
`documents/Context/VISION.md` does — or the system design, which
`documents/Context/ARCHITECTURE.md` does. Both the **stack** and the **architecture** are decided
(§1); implementation has not begun.

Read, in this order:

1. `documents/Context/VISION.md` — approved product direction.
2. `documents/Context/ARCHITECTURE.md` — approved technical foundation.
3. `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` — engineering, security and
   quality standards, the gates every change passes, and the audit-readiness standard in §19.
4. `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md` — the AfriNova-wide OWASP baseline,
   mandatory for any change in the scope listed in §4A.
5. This document — AI working rules, visual preservation, and vocabulary.
6. The prototype in `src/app/` — the reference implementation of the intended experience.

---

## 1. Source-of-Truth Hierarchy

| Concern | Authority |
| --- | --- |
| Product purpose, activities, business principles | `documents/Context/VISION.md` |
| **Account and permission model** | **`documents/Context/Unified-Account-and-Activity-Permission-Matrix.md`** |
| Intended experience and workflows | The prototype |
| **Visual identity** | **The prototype** |
| **Engineering, security and quality standards** | **`documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`** |
| **Application security baseline (AfriNova-wide)** | **`documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md`**, applied through the engineering standards; the stricter control governs a difference |
| **AI working rules, visual preservation, vocabulary** | **This document** |
| **Database mechanics, migrations, grants, RLS** | **`documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md`** |
| **Stack, language, styling** | **Decided — the prototype's stack: React 18 + Vite 6 + TypeScript + Tailwind CSS 4** |
| **Architecture, data layer, backend** | **Decided — `documents/Context/ARCHITECTURE.md`: modular monolith, TypeScript API, PostgreSQL** |

**Stack rule:** write React + TypeScript, styled with the tokens in §2. Do not introduce Dart,
Flutter, another framework, a CSS-in-JS library, or a component library that overrides the
prototype's visual language. New dependencies require justification against the prototype.

**Conflict rule:** the prototype is the **only source of truth for UI** — colour, typography,
spacing, shape, layout, navigation, and copy. If any written instruction, document, checklist, or
accessibility guideline disagrees with it, **the prototype wins**. Report the discrepancy; never
change the prototype to match a document. A change to the prototype is an explicit product decision
that comes first; the documentation follows it, never the reverse.

The written visual specification is `documents/Context/VISUAL-IDENTITY.md`. It was derived from
the prototype on 1 November 2026 and is the detailed reference for §2 of this file: exact palette
values, activity accents and gradients, typography scale, radii, shadows, component anatomy,
responsive rules, and the preservation and accessibility rules. Where it and the prototype
disagree, the prototype wins — the document has a defect, not the product.

---

## 2. Visual Preservation — Non-Negotiable

### 2.1 The prototype is the visual authority

The prototype is the **only source of truth for UI**: colour, typography, spacing, shape, layout,
navigation, and copy. It establishes Hivorr's design language. Preserve it in full — colours, colour
relationships, typography, proportions, spacing, radii, shadows, navigation, and responsive
behaviour.

Do not:

- replace the prototype palette with an older or generic palette;
- force every dashboard, activity, card, button, or nav element into one uniform colour;
- remove intentional colour differences between the six activities;
- flatten gradients, tints, or accent treatments;
- introduce hues that do not exist in the prototype;
- restyle the UI to resemble a stock component library.

### 2.2 Core colour system

All values below are established by the prototype and are approved tokens.

| Role | Value | Used for |
| --- | --- | --- |
| Brand blue (primary) | `#2D3FE7` | primary actions, links, selected nav, buy/hire accents |
| Brand blue tint | `#EEF0FD` | selected rows, icon chips, tinted panels |
| Deep blue anchors | `#1A2AD4` `#1727BE` `#4F5FEF` `#5263F4` `#5363F2` `#3D50F1` `#1D2CC9` | auth backgrounds, blue hero gradients |
| Green (success / professional) | `#16A34A` | success, verified, available, professional and logistics accents |
| Green tint | `#DCFCE7` | success chips, tinted panels |
| Green gradient stops | `#116530` `#15803D` `#32B965` `#22C55E` | hero gradients, chart fills |
| Orange (attention / errand) | `#F97316` | pending, awaiting, held, errand accent |
| Orange tints | `#FFF7ED` `#FFEDD5` `#FED7AA` | pending chips, warm panels |
| Orange gradient stops | `#B9380A` `#EA580C` `#FB7B32` | errand hero |
| Purple (seller / admin) | `#8B5CF6` | seller and admin accents, analytics |
| Purple tint | `#F3F0FF` | seller/admin chips and panels |
| Purple gradient stops | `#5B21B6` `#7C3AED` `#9B66F3` | seller hero |
| Red (danger) | `#EF4444` | destructive actions, cancelled, rejected, errors |
| Red tint | `#FEF2F2` | danger chips |
| Cyan (category / info) | `#0891B2` with tint `#E0F2FE` | category tiles, informational accents |
| Amber | `#F59E0B` | ratings and stars |
| Ink | `#0F1626` | primary text, headings |
| Body text | `#374151` `#4B5563` `#6B7280` | secondary and body text |
| Muted text | `#9CA3AF` | meta text only |
| App background | `#F0F2F8` | page background |
| Card surface | `#FFFFFF` | cards, panels, sidebars |
| Subtle surfaces | `#F4F6FB` `#F8F9FC` `#FAFBFD` | inputs, table headers, chat background |
| Border | `rgba(15,22,38,0.07)` | default borders and dividers |
| Border strong | `#DDE1EB` `#E5E7EB` | dividers, inactive steps |
| Disabled | `#ECEFF5` `#E9ECF5` `#E9ECF3` | disabled inputs, draft chips |

### 2.3 Activity accents — preserve these distinctions

Hivorr is **multi-accent by design**. Uniformity is not a goal.

| Activity | Accent | Signature gradient |
| --- | --- | --- |
| Buy — Local Market | blue `#2D3FE7` | none (solid surfaces) |
| Hire — Client | blue `#2D3FE7` | `#1727BE → #2D3FE7 → #5263F4` |
| Errand | orange `#F97316` | `#B9380A → #EA580C → #FB7B32` |
| Sell — Seller | purple `#8B5CF6` | `#5B21B6 → #7C3AED → #9B66F3` |
| Offer services — Professional | green `#16A34A` | `#116530 → #16A34A → #32B965` |
| Provide logistics | green `#16A34A` | `#0F5F5A → #0F766E → #16A34A` |
| Admin | purple `#8B5CF6` | none |

Professional and logistics share green but keep **different** gradients and different
navigation. Do not merge them.

### 2.4 Status colour semantics

| Meaning | Colour |
| --- | --- |
| Success, active, completed, paid, available, verified, approved | green |
| Pending, awaiting, in progress, held, attention, in review | orange |
| Danger, cancelled, rejected, suspended, failed, out of stock | red |
| Admin, seller, analytics, informational | purple |
| Primary action, link, selected navigation | blue |
| Category identity | cyan, or the category's assigned token |
| Rating | amber |

Never repurpose a status colour for decoration, or a decorative colour for status.

### 2.5 Gradients

Gradients are part of the identity, not optional decoration. Preserve:

- auth and onboarding: `145deg`/`135deg` deep-blue gradients;
- activity heroes: `125deg` three-stop gradients per §2.3;
- warm card wash: `180deg #FFFFFF → #FFFCF8` on priority assignment cards;
- soft surface gradients: `145deg #E0F2FE → #EEF0FD` for map/route placeholders.

### 2.6 Typography

Two families only. Do not introduce others.

| Role | Family | Weights |
| --- | --- | --- |
| Display: headings, numbers, brand, buttons | `'Plus Jakarta Sans'` | 700, 800 (900 for 9px uppercase labels) |
| Body: paragraphs, inputs, tables | `'Inter'` | 400–600 |

Observed scale — preserve the hierarchy, not just the fonts:

- 9–10px: uppercase eyebrows, table headers, micro-meta
- 11–12px: meta, captions, chips
- 13–14px: body, list rows, form values
- 15–16px: section titles, card titles
- 17–19px: prominent card headings
- 22–31px: page and hero titles
- 48px: splash wordmark

Line height 1.15–1.3 for headings, 1.5–1.7 for body. Negative tracking (−0.5 to −2px) on large
headings; positive tracking (+0.8 to +1.5px) on uppercase eyebrows.

### 2.7 Shape, spacing, shadow

- Radii: 8–10 chips; 11–13 inputs and buttons; 16–18 cards; 20–24 heroes and dialogs;
  fully rounded pills and avatars.
- Padding: cards 16–28; page gutters 16px mobile, 28–48px desktop.
- Resting shadow: `0 2px 12px rgba(15,22,38,0.05)`.
- Hover shadow: `0 8px 24px rgba(45,63,231,0.10)`.
- Overlay shadow: `0 28px 80px rgba(15,22,38,0.28)`.
- Borders: `1px solid rgba(15,22,38,0.07)`; active/selected states use a 1.5–2px accent border.

### 2.8 Navigation

- Desktop sidebar: 224px expanded, 66px collapsed, white, right border, brand lockup at top,
  role/activity badge, accent-tinted active item.
- Activity shells (`MarketShell`) each own their navigation set and accent colour.
- Mobile: 260px drawer plus a bottom navigation bar with at most five destinations.
- Top bar carries the page title, optional back affordance, and the mobile menu trigger.

### 2.9 Responsive behaviour

- **Mobile `< 768px`**: single column, bottom navigation, dialogs become bottom sheets,
  16px gutters, ~90px bottom padding to clear the nav.
- **Tablet `768–1023px`**: collapsed sidebar (except admin), two-column grids.
- **Desktop `≥ 1024px`**: full sidebar, three- and four-column grids, content max-width
  880–1200px.

Preserve these breakpoints. Do not introduce a new grid or spacing system.

### 2.10 Icons and imagery

- Icons: `lucide-react` only. Sizes 12–24px in UI, 48–56px in onboarding art.
- Imagery: photography, rounded 10–20px. Hero images use a 4px white border and a drop shadow
  over the gradient.
- Do not replace photography with placeholder graphics or illustration sets.

### 2.11 Accessibility

The palette is fixed; fix **usage**, not hues. **The prototype's colours are final and are the only
source of truth.** No colour may be added or substituted — not even to raise contrast. Where the
prototype's own pairings fall short, the gap is recorded in `VISUAL-IDENTITY.md` §24 and §31 and is
never "fixed" by inventing a value.

- Body text must meet 4.5:1. Use `#6B7280` or darker on white; reserve `#9CA3AF` for meta text.
- On gradient surfaces, use white at the opacity the prototype uses. Do not add a scrim or darken a
  stop.
- Type sizes are exactly the prototype's. Do not raise a size it sets.
- Never remove keyboard focus indication.
- Status must not be conveyed by colour alone — pair it with a label or icon.

### 2.12 Token discipline

Two token layers exist, and both derive from the prototype:

| Layer | File | Use |
| --- | --- | --- |
| Prototype tokens | `C` in `src/app/App.tsx` | inline-styled prototype components |
| CSS theme tokens | `src/styles/theme.css` | Tailwind utilities and `shadcn` components |

`theme.css` has been aligned to the prototype palette (1 November 2026). It exposes `--hivorr-*`
variables plus Tailwind utilities: `bg-brand`, `text-success`, `bg-attention-tint`,
`text-seller`, `bg-danger-tint`, `text-info`, `text-rating`, `text-ink`, `text-body`,
`bg-surface-subtle`, `border-strong`, `font-display`, `font-body`, `shadow-rest`, `shadow-hover`,
`shadow-overlay`.

Going forward:

- every colour must resolve to a named token from §2.2 or §2.3;
- new colours require founder approval;
- new work must not add raw hex values outside the token layer;
- prefer the `theme.css` token or Tailwind utility over a new inline colour;
- existing literals should migrate into the token layer as files are touched — not in a
  sweeping, unrelated refactor;
- `src/styles/theme.css` is the only place that may define colour values in CSS. Do not add a
  parallel palette in a component or a second stylesheet.

---

## 3. Core Operational Directives

- **Bounded change scope.** Change only what the task requires. Do not refactor, rename, or
  reorganise unrelated code. You must still *read* the approved context documents and the
  prototype before changing anything — bounded scope limits edits, not understanding.
- **Separation of concerns.** Keep business logic out of presentation code. Never hardcode
  platform logic or financial rules inside UI components.
- **Proprietary logic protection.** Pricing formulas, matching algorithms, and operational rules
  must never be embedded in client code.
- **Deterministic core supremacy.** Platform engines make ranking, routing, and financial
  decisions. AI assists with conversation and drafting only.
- **Reuse before creating.** Check existing utilities and shared components first. In the current
  prototype the shared primitives are: `Av`, `Pill`, `Btn`, `Input`, `SelectField`, `Card`,
  `StatCard`, `Section`, `Stars`, `JobRow`, `PrototypeDialog`, `FinancialActionDialog`,
  `ActivityHero`, `WalletInfo`, `ChatUI`, `MarketShell`, `Sidebar`, `TopBar`, and the mobile
  navigation components.
- **Clarification first.** Ask instead of assuming when business logic or requirements are
  ambiguous.
- **Prototype fidelity.** When building a screen, match the prototype's structure, colour
  relationships, and hierarchy — not merely its general appearance.
- **Audit readiness.** Before implementing a change that touches money, identity, personal data,
  authentication, authorisation, third parties, production infrastructure or the audit log, write the
  impact note in standards §19.3. Classify every requirement you rely on as R1–R5 (§19.2); never
  present a recommendation as a legal, regulatory or VFD requirement; produce the evidence and update
  the traceability record (§19.8, §19.11). The detailed rules live in the standards, not here.

---

## 4. Security & System Guardrails

**Rule 1 — Engine vs AI.** Core intelligence, routing, and payouts are handled by system engines.
AI handles conversational wrappers and drafting helpers only. It never decides marketplace
rankings or financial splits.

**Rule 2 — Dual taxonomy & verification.** Two taxonomies govern the platform:

- *Profession taxonomy*: Industry → Profession, trade-gated.
- *Product taxonomy*: vertical → category → subcategory → product type → attributes,
  merchant/store-catalog-gated, admin-configurable.

Anyone who sells, offers a professional service, or provides logistics must be verified:
professionals submit identity plus trade proof; sellers submit store profile, identity, and
proof-of-trade; logistics providers submit identity, KYC, and vehicle/logistics proof.
Unverified participants get dashboard access immediately, but gated writes stay locked until
verification is `APPROVED` — bidding/accepting work, publishing products, accepting dispatch.

**Rule 3 — Financial guardrails & KYC-gated access.** Deposit webhooks enforce
`Payer Name == Entity Profile Name`. Payouts are restricted to bound, pre-verified bank accounts
with KYC-driven limits. Withdrawals, payouts, conversions, and higher limits require
`tier_1` or above; `tier_0` carries zero limits. Earning activities require both the applicable
verification lane and the required KYC tier.

**Rule 4 — Database-first logic & zero-trust client.** Sensitive financial calculations, pricing,
escrow splitting, and cryptographic verification must never live in the client. Critical state
changes execute server-side.

**Rule 5 — Visual identity & design tokens.** All UI must consume the approved tokens in §2.
The prototype is the visual authority. Do not hardcode new colours, do not set arbitrary font
families, and do not introduce a hue that is not in §2.2 or §2.3.

**Rule 6 — Unified account & activities.** One account activates multiple activities:
Explore (buy, hire, errand) and Earn (sell, offer services, provide logistics). Activities are
capabilities, not account types. The "Both" value is permanently removed. Admin and Super Admin
are privileged platform roles, never selectable at registration or activity selection.

`discover` is not an activity. It is the browse step inside Hire: a requester browses professionals
before posting a job, and a professional browses open work. Settled 3 November 2026 (§7 #7).

---

## 4A. Mandatory Application Security Standard

**Rule 7 — AfriNova OWASP baseline.** `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md`
is the AfriNova-wide application security baseline, approved by the founder on 6 November 2026 and
recorded in its §8.1. It is applied through
`ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` for Hivorr. Where the two differ and both apply,
the stricter control governs; record the difference in the standard's §9 and the Hivorr standards
§15, and stop if the choice is material. This section is the operative agent instruction; the
detailed requirements live in the standard.

**When it is mandatory.** This section applies whenever a task does any of the following:

- creates or modifies a feature, screen, endpoint, worker or integration;
- creates or modifies an API, request or response contract, webhook or third-party call;
- touches authentication, authorisation, sessions, tokens, credentials, passwords or permissions;
- handles user data, personal data, identity data, financial data, payment or payout logic;
- touches the database, a schema migration, a query, a policy, a grant or a data-access path;
- adds, removes, upgrades or configures a dependency, build step, CI job or deployment;
- reviews, refactors, tests or documents any of the above.

If you cannot tell whether a task is in scope, ask before editing. Do not assume the smaller scope.

**Required agent behaviour.**

- Inspect the existing controls and the governing documents before changing anything.
- Preserve existing controls. Never remove, weaken, bypass or disable one to make a change easier.
- Never bypass authentication or authorisation, and never add a test-only login, debug token,
  permission skip or client-side check in place of a server-side one.
- Never expose, print, commit, log or copy a secret, key, token or connection string. If one is
  found, report its location and type only and recommend rotation.
- Never introduce an insecure pattern or dependency: no known High/Critical vulnerability, no
  unmaintained package, no unreviewed install script, no custom crypto, no unsafe sink.
- Assess architectural security impact before changing a trust boundary, data flow, permission model
  or integration. State asset, actor, entry point, threat, control and residual risk.
- Recommend and add the test that proves each security control, including the deny path.
- Report suspected vulnerabilities and gaps to the founder or architect with impact, preconditions,
  proposed fix and test. Do not silently fix them in an unrelated change.
- Explain conflicts with a secure alternative: state the requirement, the conflict, the risk and at
  least one secure option. Do not implement the insecure option first and mention the risk after.
- Classify legal, regulatory and contractual requirements as R1–R5 (standards §19.2), and record
  unknowns as **[OPEN]** rather than inventing a policy, threshold or obligation.
- Never describe work, a feature or a release as secure, compliant, certified, hardened or
  production-ready. State what was verified and how.
- Treat AI-generated code exactly like human-authored code for review, test and evidence purposes.

**Stop conditions.** Stop and ask when the change would weaken or remove a control, needs an
unapproved secret or privileged role, depends on an **[OPEN]** decision, hits a material document
conflict, needs production data or a live third-party side effect, or cannot be tested or evidenced.

**Reporting.** A completion report for security-relevant work states: files and trust boundary
changed; the `AFS-` and `ENG-`/`SEC-`/`AUT-` rules applied; existing controls inspected and
preserved; tests run with results; evidence with date and environment; residual risk and open
decisions; conflicts or assumptions; and confirmation that no secret or production personal data was
exposed. "Implemented" or "secured" alone is not a report.

---

## 5. Unified Account & Vocabulary

- The authoritative account and permission model is
  `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` (approved 1 November 2026).
  It defines activation, verification lanes, capabilities, dashboard access, and enforcement.
- No Client, Professional, or Both **account types**.
- The prototype uses "Client" and "Professional" as *dashboard labels* and internally as roles.
  This is unresolved terminology — see §7.
- Do not invent new synonyms for the same concept.
- Preferred platform nouns where they already exist: store, product, seller, rider/logistics
  provider, requester, professional.

---

## 6. Definition of Done — UI Work

A UI task is complete only when:

1. Colours, typography, radii, shadows, and spacing match the prototype.
2. The correct activity accent is preserved; nothing has been unified for convenience.
3. All colours resolve to approved tokens; no new hex was introduced.
4. The screen works at 375px, 768px, and 1280px.
5. Keyboard focus is visible. Contrast is exactly the prototype's; every pair that falls short of 4.5:1 is recorded in `VISUAL-IDENTITY.md` §24 and is not altered.
6. No unreachable screens, dead controls, or duplicated primitives were added.
7. Any deliberate divergence from the prototype is documented and approved.
8. Audit readiness: any R1/R2 question is classified and recorded as **[OPEN]** if unresolved, each
   new control has a test that fails if it is removed, and the traceability record is updated
   (standards §19.2–§19.11).
9. Application security: where the change falls in §4A, the applicable
   `OWASP_APPLICATION_SECURITY_STANDARD.md` requirements are satisfied or an approved deviation is
   recorded, and the §4A report fields are complete.

---

## 7. Known Conflicts and Open Decisions

These are recorded, not resolved. Do not decide them unilaterally.

| # | Issue | Status |
| --- | --- | --- |
| 1 | Legacy directive targets **Dart/Flutter**; the prototype is **React + TypeScript**. | Resolved 1 Nov 2026 — the prototype's stack is adopted (§1). The Flutter directive is superseded. |
| 2 | Legacy Admin identity was `#1A2AD4` with `#8B5CF6` accent. The prototype uses **purple `#8B5CF6`** for admin; `#1A2AD4` appears only as a gradient anchor. | Resolved in favour of prototype |
| 3 | Legacy rule "never introduce a third brand hue" contradicts the six-activity accent system. | Resolved in favour of prototype |
| 4 | `src/styles/theme.css` defined a different palette (`--primary: #030213`, white background), so any Tailwind/`shadcn` component rendered the wrong colours. | Resolved 1 Nov 2026 — `theme.css` now carries the prototype palette (§2.12). |
| 5 | `src/styles/fonts.css` was empty, so the declared fonts fell back to system sans. | Resolved 1 Nov 2026 — `fonts.css` loads Plus Jakarta Sans and Inter. |
| 6 | Terminology: legacy says merchant / rider; prototype says seller / logistics provider / client / professional. | **OPEN** |
| 7 | Vision listed `discover` as an Explore activity; prototype offers `errand`. The approved matrix models **errand** as the third Explore activity. | **Resolved 3 Nov 2026** — `errand` is the third Explore activity; `discover` is the browse step inside Hire, not an activity. Rule 6 updated. |
| 8 | Rule 4 prescribes server-side/PostgreSQL specifics; the data layer is not yet approved. | Resolved 1 Nov 2026 — architecture approved: PostgreSQL, schema per module, service-layer rules (`documents/Context/ARCHITECTURE.md`). |
| 9 | Accessibility gaps in the prototype (9px text, low-opacity white on gradients, muted text on white). | **Accepted 3 Nov 2026** — the prototype is the only UI source of truth, so its colours and type sizes are final. Contrast and size gaps are recorded in `VISUAL-IDENTITY.md` §24 and §31, never corrected with a new value, a substituted colour, or a raised size. |
| 10 | Dark mode. The prototype is light-only and no dark palette is established. | **OPEN** — do not invent one |
| 11 | `default_shadcn_theme.css` at the project root still holds the old Figma default palette. It is a reference copy and is not imported by the app. | Informational — do not import it |
| 12 | The prototype carries inline styles on 1,065 lines (about 1,880 style objects), 151 inline `font-family` declarations and 228 hex literals — measured 3 November 2026. Migrating them is a refactor, not a redesign. | **OPEN** - migrate as files are touched |
