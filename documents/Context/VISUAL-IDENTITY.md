# Hivorr — Visual Identity, Design System & Preservation Rules

**Status:** Active — derived from the prototype on 1 November 2026. Binding for all UI work.
**Authority:** The prototype (`src/app/App.tsx`) is the visual authority for Hivorr.
**Owner:** Every UI task, every component, and every agent working on the frontend.
**Supersedes:** the previous Flutter-era `VISUAL-IDENTITY.md`, which described a stack
(Dart/Flutter, `ThemeData`, `AppColors`) that Hivorr no longer uses.

---

## How to use this document

> **THE PROTOTYPE IS THE ONLY SOURCE OF TRUTH FOR UI.**
> `src/app/App.tsx` defines Hivorr's frontend and design: colour, typography, spacing, shape,
> shadow, layout, navigation, copy, and behaviour. This document, `AGENTS.md` §2, and
> `ARCHITECTURE.md` §4 all derive from it and none of them outranks it.
>
> - If a document and the prototype disagree, **the prototype is correct** and the document has a
>   defect. Report it; never change the prototype to match the text.
> - If the prototype disagrees with **itself**, both behaviours are recorded (§31) and neither is
>   altered. A divergence is a fact to document, not a defect to fix.
> - No document, checklist, or accessibility guideline authorises a change to the prototype. A
>   change to the prototype is a product decision, made explicitly, and it comes before the
>   documentation — never the other way round.

This document therefore defines **what Hivorr looks like** and **what must not change**. It is
descriptive, not prescriptive: every value in it was read out of the prototype, not invented here.

The rules are ordered by authority:

1. **The prototype wins, always.** It is the only UI source of truth.
2. **`documents/Context/AGENTS.md` §2** is the engineering expression of the same rules. Where
   the two overlap, they agree.
3. **This document** is the detailed reference: exact values, component anatomy, per-activity
   colour, and the preservation rules.
4. **`documents/Context/ARCHITECTURE.md`** governs how the frontend is built and migrated. It may
   never require a restyle.

Two token layers exist and both derive from the prototype:

| Layer | Location | Used by |
| --- | --- | --- |
| Prototype tokens | `const C` in `src/app/App.tsx` | the inline-styled prototype components |
| CSS theme tokens | `src/styles/theme.css` (`--hivorr-*` + Tailwind utilities) | new React components and `shadcn` primitives |

Never create a third. Never add a parallel palette in a component or a second stylesheet.

---

## 1. Purpose & Design Philosophy

Hivorr is **one account with many activities**: Explore with Hivorr (buy, hire, request an errand)
and Earn with Hivorr (sell, offer professional services, provide logistics), plus a separate
privileged Admin environment. The interface must communicate **trust, professionalism, operational
competence, simplicity, local relevance, and premium digital-product quality** on every surface.

The interface must feel **intentionally designed, not assembled**. Every page has:

```text
Purpose + Visual hierarchy + Structured content
+ Meaningful whitespace + Clear actions + Consistent visual language
```

### 1.1 The five standing principles

| # | Principle | Meaning in practice |
| --- | --- | --- |
| 1 | **One ecosystem, many accents** | The shell, typography, spacing, radii, and shadows are shared everywhere. Colour is how activities stay distinguishable. |
| 2 | **Colour carries meaning** | Blue = primary/action. Green = success and earning. Orange = attention and errands. Purple = selling and administration. Red = danger. Cyan = category/info. Amber = rating. |
| 3 | **Structure before decoration** | Hierarchy comes from typography, spacing, grouping, and surface — not from ornament. |
| 4 | **Density is deliberate** | Hivorr is an operational product. Screens are information-dense by design, not sparse marketing pages. |
| 5 | **Never silently modernise** | A restyle is a product change. It requires founder approval and a documented reason. |

---

## 2. Brand Identity

### 2.1 Name and lockup

- Product: **Hivorr**. Company: **AfriNova Digital Limited**.
- The prototype's mark is a **`Zap` icon in white on a brand-blue rounded tile**: 36×36 at radius 10
  in navigation, 96×96 at radius 28 on the splash screen.
- The wordmark is **"Hivorr"** set in Plus Jakarta Sans 800, `#0F1626` on light surfaces, white on
  dark gradients. Splash wordmark is 48px with `letter-spacing: -2px`.
- Clear space: at least 25% of the mark height on all sides.
- The mark is never recoloured to a hue outside this document, never rotated, never outlined, and
  never placed on a photographic background without a contrast-safe surface behind it.

> Asset files from the previous implementation (`logo.svg`, `logo_wordmark.svg`, …) are **not**
> present in this repository. The prototype draws the mark with an icon, not an asset. Treat the
> icon-tile treatment above as canonical until real assets are supplied (see §32).

### 2.2 Brand expression: Explore and Earn

The product is framed in two halves, and the framing is part of the identity:

| Half | Promise (verbatim from the prototype) | Activities |
| --- | --- | --- |
| **Explore with Hivorr** | "Shop, hire trusted professionals, or request help with a local errand." | Buy · Hire · Errand |
| **Earn with Hivorr** | "Earn through product sales, professional services, or logistics fulfilment." | Sell · Offer services · Provide logistics |

The activity-select screen is the canonical expression of this: a centred 1080px page, an eyebrow
"WELCOME TO YOUR HIVORR" in brand blue 12px/800 with 1.5px tracking, a 40px/800 headline ("How do
you want to use Hivorr today?"), a 15px supporting line, then two labelled sections of three cards.

### 2.3 Interface voice

Labels are plain, active, and short: "I Want to Buy", "Open Client Dashboard", "Create an Errand",
"Add Product", "Available Requests". Status words are sentence case in body contexts and uppercase
in pill/eyebrow contexts. The interface never uses exclamation marks, never uses jargon where a
plain word exists, and never addresses the user as "user".

---

## 3. Core Colour System

These are the only base hues. Every value below is read from `const C` in `src/app/App.tsx` and
mirrored in `src/styles/theme.css`.

### 3.1 Core palette

| Token | Hex | Prototype name | Used for |
| --- | --- | --- | --- |
| Brand blue | `#2D3FE7` | `C.primary` | primary buttons, links, selected navigation, focus rings, Buy and Hire accents |
| Brand blue tint | `#EEF0FD` | `C.primaryLight` | selected rows, icon chips, secondary buttons, tinted panels |
| Green | `#16A34A` | `C.green` | success, verified, available, completed, Professional and Logistics accents |
| Green tint | `#DCFCE7` | `C.greenLight` | success chips, tinted panels |
| Orange | `#F97316` | `C.orange` | pending, awaiting, held, priority, Errand accent |
| Orange tint | `#FFF7ED` | `C.orangeLight` | pending chips, warm panels, caution notes |
| Purple | `#8B5CF6` | `C.purple` | Seller accent, **Admin identity**, analytics, informational |
| Purple tint | `#F3F0FF` | `C.purpleLight` | seller/admin chips and panels |
| Red | `#EF4444` | `C.red` | destructive actions, cancelled, rejected, failed, out of stock |
| Red tint | `#FEF2F2` | `C.redLight` | danger chips, error banners |
| Cyan | `#0891B2` | `C.cyan` | category identity, informational accents |
| Cyan tint | `#E0F2FE` | `C.cyanLight` | info chips, map/route placeholders |
| Amber | `#F59E0B` | — | rating stars only |
| Ink | `#0F1626` | `C.ink` | headings and primary text |
| Gray | `#6B7280` | `C.gray` | body and secondary text |
| Muted | `#9CA3AF` | `C.muted` | meta text, captions, placeholders |
| App background | `#F0F2F8` | `C.bg` | every page background |
| Card surface | `#FFFFFF` | `C.card` | cards, panels, sidebars, top bars |
| Border | `rgba(15,22,38,0.07)` | `C.border` | default borders and dividers |

### 3.2 Extended neutrals and surfaces

Observed in the prototype and required for fidelity. These are supporting values, not new hues.

| Value | Role |
| --- | --- |
| `#374151` | body text, form labels |
| `#4B5563` | secondary body text |
| `#F4F6FB` | input background, ghost button, table header, chat background (55 uses — the dominant neutral) |
| `#F8F9FC` | very subtle panel fill (26 uses) |
| `#FAFBFD` | faintest surface wash |
| `#FFFCF8` | warm wash on priority assignment cards |
| `#DDE1EB` | strong border, inactive step |
| `#E5E7EB` | strong border, divider (11 uses) |
| `#CBD5E1` | inactive pagination dot, neutral rule |
| `#ECEFF5` `#E9ECF5` `#E9ECF3` | disabled inputs, draft chips |
| `#E6E9F2` `#D7DBE6` `#C9CFE0` | low-emphasis dividers and tracks |
| `#A5B4FC` | pale indigo accent on dark surfaces only |

### 3.3 Gradient anchor colours

These exist **only inside gradients**. They are never used as flat text or flat background.

| Family | Stops |
| --- | --- |
| Deep blue | `#1A2AD4` `#1727BE` `#1D2CC9` |
| Mid blue | `#2D3FE7` `#3D50F1` |
| Bright blue | `#4F5FEF` `#5263F4` `#5363F2` |
| Deep green | `#116530` `#15803D` |
| Mid green | `#16A34A` |
| Bright green | `#32B965` `#22C55E` |
| Deep orange | `#B9380A` |
| Mid orange | `#EA580C` |
| Bright orange | `#FB7B32` |
| Deep purple | `#5B21B6` |
| Mid purple | `#7C3AED` |
| Bright purple | `#9B66F3` |
| Teal (logistics) | `#0F5F5A` `#0F766E` |

### 3.4 Auth and onboarding gradient

```text
linear-gradient(135deg, #1A2AD4 0%, #2D3FE7 40%, #4F5FEF 100%)   ×6  login / signup / onboarding
linear-gradient(145deg, #1A2AD4 0%, #2D3FE7 50%, #4F5FEF 100%)   ×2  splash / auth
linear-gradient(135deg, #1A2AD4, #2D3FE7)                        ×2  auth brand panel, blue info card
```

The auth card sits on this gradient: white, radius 28, `max-width: 940px`,
`box-shadow: 0 32px 80px rgba(0,0,0,0.2)`.

The auth card sits on this gradient: white, radius 28, `max-width: 940px`,
`box-shadow: 0 32px 80px rgba(0,0,0,0.2)`.

### 3.5 The palette is closed

The prototype's colours are final. They are the only source of truth for colour in this product.

- No value may be added to the palette, including a "darker text" partner for a tint.
- No value may be substituted for another, even to improve contrast.
- A contrast shortfall is **recorded** in §24.1 and §31, never corrected by inventing a colour.

If a future design genuinely needs a colour the prototype does not contain, that is a prototype
change and a product decision — not a documentation or implementation detail.

---

## 4. Activity Colour System — Non-Negotiable

**Hivorr is multi-accent by design. Uniformity is not a goal.**

Each activity owns an accent, a tint, a signature gradient, and its own navigation set. These
distinctions are part of the product's identity and must survive every refactor.

### 4.1 Activity accents

| Activity | Accent | Tint | Signature gradient | Shell label |
| --- | --- | --- | --- | --- |
| **Buy** — Local Market | blue `#2D3FE7` | `#EEF0FD` | `linear-gradient(125deg,#1D2CC9,#3D50F1)` | "Local Market" |
| **Hire** — Client | blue `#2D3FE7` | `#EEF0FD` | `linear-gradient(125deg,#1727BE 0%,#2D3FE7 58%,#5263F4 100%)` | "Client" |
| **Errand** — Requester | orange `#F97316` | `#FFF7ED` | `linear-gradient(125deg,#B9380A 0%,#EA580C 55%,#FB7B32 100%)` | "Errand Dashboard" |
| **Sell** — Seller | purple `#8B5CF6` | `#F3F0FF` | `linear-gradient(125deg,#5B21B6 0%,#7C3AED 58%,#9B66F3 100%)` | "Seller Dashboard" |
| **Offer services** — Professional | green `#16A34A` | `#DCFCE7` | `linear-gradient(125deg,#116530 0%,#16A34A 58%,#32B965 100%)` | "Professional" |
| **Provide logistics** | green `#16A34A` | `#DCFCE7` | `linear-gradient(125deg,#0F5F5A 0%,#0F766E 52%,#16A34A 100%)` | "Logistics Provider" |
| **Admin** | purple `#8B5CF6` | `#F3F0FF` | none — solid surfaces | "Admin" |

**Professional and Logistics both use green, but they are not the same identity.** They have
different gradients (green-forward vs teal-forward), different navigation, different labels, and
different dashboards. Never merge them, never re-tint one to match the other, and never "simplify"
the pair into one green.

**The chooser and the dashboard disagree for two activities.** Hire is purple on entry and blue
inside; Logistics is orange on entry and green inside. Both surfaces are the prototype, so both are
correct and neither is changed. The divergence is recorded in §31 #1 and #2. Do not resolve it in
code, and do not assume one side is the defect.

### 4.2 Secondary gradients inside activity screens

| Purpose | Gradient | Where |
| --- | --- | --- |
| Client promo card | `linear-gradient(135deg,#1A2AD4,#2D3FE7 58%,#5363F2)` | Client dashboard |
| Professional promo card | `linear-gradient(135deg,#116530,#16A34A 58%,#22C55E)` | Professional dashboard |
| Green info panel | `linear-gradient(135deg,#15803D,#16A34A)` | Professional/earnings panels |
| Route / map placeholder | `linear-gradient(145deg,#E0F2FE,#EEF0FD)` | Logistics tracking |
| Priority assignment wash | `linear-gradient(180deg,#FFFFFF 0%,#FFFCF8 100%)` | Errand / logistics priority cards |

### 4.3 The activity-select screen

The chooser uses one tinted icon tile per activity, and its colour assignments are **not** identical
to the dashboard accents. This is recorded as found, not corrected:

| Card | Icon tile | Tile background | Dashboard accent |
| --- | --- | --- | --- |
| I Want to Buy | blue | `#EEF0FD` | blue |
| I Want to Hire | **purple** | `#F3F0FF` | **blue** |
| Send an Errand | orange | `#FFF7ED` | orange |
| I Want to Sell | purple | `#F3F0FF` | purple |
| I Want to Offer My Services | green | `#DCFCE7` | green |
| I Want to Provide Logistics | **orange** | `#FFF7ED` | **green / teal** |

See §32 for the two divergences. Until a founder decision is recorded, **implement the dashboard
accent (§4.1) inside each dashboard, and reproduce the chooser exactly as prototyped.** Do not
"harmonise" either direction.

### 4.4 Rules

- An activity's accent governs: its sidebar active state, its primary buttons inside that shell,
  its hero gradient, its stat icons, its chart series, and its focus ring.
- An accent never governs body text, never becomes a full-bleed page background, and never replaces
  a semantic status colour.
- Activity accents are **never** unified for visual convenience. A page that makes Sell look like
  Buy has failed review.
- Colour is not the only signal. Every activity also carries its own label, icon, and navigation
  set — see §25.

---

## 5. Semantic & Status Colours

Semantic meaning is global and does not change per activity.

| Meaning | Base | Container | Examples in the prototype |
| --- | --- | --- | --- |
| Success, active, completed, paid, available, verified, approved | green `#16A34A` | `#DCFCE7` | "Completed", "IDENTITY VERIFIED", "READY FOR REVIEW" |
| Pending, awaiting, in progress, held, attention, review | orange `#F97316` | `#FFF7ED` | "PENDING", "IN PROGRESS", "Awaiting acceptance" |
| Danger, cancelled, rejected, suspended, failed, out of stock | red `#EF4444` | `#FEF2F2` | "Urgent", failed payments |
| Primary action, link, selected navigation | blue `#2D3FE7` | `#EEF0FD` | "Primary", selected nav item |
| Seller, admin, analytics, informational | purple `#8B5CF6` | `#F3F0FF` | "FEATURED STORE", "PLATFORM ADMIN" |
| Category identity | cyan `#0891B2` or the category's assigned token | `#E0F2FE` | category tiles |
| Rating | amber `#F59E0B` | — | star fills |

### 5.1 Pill anatomy (the status primitive)

```text
color: <semantic base>
background: <semantic container>
font-size: 11px · font-weight: 600 · padding: 3px 9px
border-radius: 20px · display: inline-block
max-width: 100% · overflow: hidden · text-overflow: ellipsis · white-space: nowrap
```

Neutral and draft states use `#6B7280` on `#E9ECF3`. A pill on a dark gradient may use a white
background with a coloured label (`color: C.orange, bg: #fff` appears once for "PICKUP CONFIRMED").

### 5.2 Rules

- Never repurpose a status colour for decoration, or a decorative colour for status.
- A status is never communicated by colour alone — always pair it with a word or an icon (§25).
- In a green-accented activity, success green and activity green are the same hue. Pair status
  with an explicit label so the two readings never collide.
- Orange means *attention required*. Do not use it for celebration, emphasis, or brand warmth.

---

## 6. Colour Usage & Hierarchy

### 6.1 Proportion

The interface is predominantly **neutral**: `#F0F2F8` page, white surfaces, ink text, hairline
borders. Accent colour is a minority signal. A screen where accent colour covers more than roughly
a fifth of the surface area is over-coloured.

| Layer | Colour | Share |
| --- | --- | --- |
| Page background | `#F0F2F8` | dominant |
| Surfaces | `#FFFFFF`, `#F4F6FB`, `#F8F9FC` | dominant |
| Text | `#0F1626` → `#6B7280` → `#9CA3AF` | dominant |
| Accent | activity colour, status colour | minority |
| Gradient | hero, auth, promo card | single large moment per screen |

### 6.2 Where each colour may appear

| Colour | May appear as | May **not** appear as |
| --- | --- | --- |
| Brand blue | primary button, link, active nav, focus ring, icon, hero gradient, selected row | body text, page background, decorative border |
| Green | success pill, verified badge, earnings figure, professional/logistics accent | generic "nice" emphasis, decoration |
| Orange | pending pill, priority card, errand accent, caution note | celebration, primary CTA in a non-errand shell |
| Purple | seller accent, admin identity, analytics series, featured badge | warning, error |
| Red | destructive button, error pill, negative delta | emphasis, urgency marketing |
| Cyan | category tile, info chip, map placeholder | primary action |
| Amber | rating stars only | anything else |

### 6.3 Text on colour

- On `#2D3FE7`, white text is safe (7.06:1). On green, orange, purple, and red fills, white text
  passes only as *large* text or as a UI component (≥3:1). See §25 for the measured values and the
  required mitigation.
- Never place small body copy directly on a gradient without a contrast check.
- Never derive a text colour by opacity on a coloured surface (`rgba(255,255,255,.45)` is a defect,
  not a style).

---

## 7. Design Tokens

### 7.1 The CSS layer

`src/styles/theme.css` is the single CSS token layer and carries the prototype palette. It exposes:

**Colour tokens** — `--hivorr-blue`, `--hivorr-blue-tint`, `--hivorr-green`, `--hivorr-green-tint`,
`--hivorr-orange`, `--hivorr-orange-tint`, `--hivorr-purple`, `--hivorr-purple-tint`,
`--hivorr-red`, `--hivorr-red-tint`, `--hivorr-cyan`, `--hivorr-cyan-tint`, `--hivorr-amber`,
`--hivorr-ink`, `--hivorr-body`, `--hivorr-body-soft`, `--hivorr-muted-text`,
`--hivorr-surface`, `--hivorr-surface-subtle`, `--hivorr-surface-muted`, `--hivorr-surface-faint`,
`--hivorr-border`, `--hivorr-border-strong`, `--hivorr-disabled`.

**Shape and depth** — `--radius: 12px` with `sm 8 / md 10 / lg 12 / xl 16`;
`--hivorr-shadow-rest`, `--hivorr-shadow-hover`, `--hivorr-shadow-overlay`.

**Type** — `--hivorr-font-display`, `--hivorr-font-body`.

**Tailwind utilities** — `bg-brand`, `bg-brand-tint`, `text-success`, `bg-success-tint`,
`bg-attention`, `bg-attention-tint`, `text-seller`, `bg-seller-tint`, `bg-danger`,
`bg-danger-tint`, `text-info`, `bg-info-tint`, `text-rating`, `text-ink`, `text-body`,
`text-body-soft`, `text-subtle`, `bg-surface`, `bg-surface-subtle`, `bg-surface-muted`,
`bg-surface-faint`, `border-strong`, `bg-disabled`, `font-display`, `font-body`, `shadow-rest`,
`shadow-hover`, `shadow-overlay`.

### 7.2 Token discipline

- Every colour in new work resolves to a named token. No raw hex outside the token layer.
- Prefer a `theme.css` token or Tailwind utility over a new inline colour.
- Existing literals migrate into the token layer **as files are touched** — never in a sweeping,
  unrelated refactor.
- `theme.css` is the only place that may define colour values in CSS.
- `src/styles/fonts.css` is the only place that may declare font families and load them.
- A new colour, a new gradient, or a new shadow requires founder approval (§32).

### 7.3 Known token gaps

The prototype uses these values that `theme.css` does not yet expose as tokens. They are approved
values (§3.2) but need tokens before they can be used in new CSS:

`#6B7280` as a dedicated `--hivorr-gray` (it currently lives only as `--muted-foreground`),
`#E5E7EB`, `#CBD5E1`, `#FFEDD5`, `#FED7AA`, `#FFFCF8`, and every gradient stop in §3.3.

Recommended: add `--hivorr-gradient-*` tokens and `--hivorr-gray` so gradients stop being inline
string literals. This is additive and changes no rendering.

---

## 8. Typography

### 8.1 Families

Two families only. Do not introduce a third.

| Role | Family | Loaded by | Weights |
| --- | --- | --- | --- |
| Display — headings, numbers, brand, buttons, pills, nav | `'Plus Jakarta Sans'` | `fonts.css` (Google Fonts) | 400, 500, 600, 700, 800 |
| Body — paragraphs, inputs, tables | `'Inter'` | `fonts.css` (Google Fonts) | 400, 500, 600 |

The prototype sets `body { font-family: 'Inter', sans-serif; }` globally, and then applies
`'Plus Jakarta Sans'` inline on **150** elements. That pattern is the identity: **Inter is the
reading voice; Plus Jakarta Sans is the interface voice.**

A 900 weight is used in exactly three places, all 9px uppercase micro-labels
("PLATFORM ADMIN"). It is permitted there and nowhere else.

### 8.2 Observed size distribution

Measured across `App.tsx`. Preserve the *shape* of this distribution, not only individual values.

| Size | Count | Typical use |
| --- | --- | --- |
| 9px | 21 | uppercase section labels, table headers, micro-meta |
| 10px | 82 | eyebrow text, dense meta, small labels |
| 11px | 121 | pill labels, captions, secondary meta |
| 12px | 173 | the dominant meta size — nav labels, stat labels, chips |
| 13px | 129 | body, list rows, form labels |
| 14px | 73 | body, button md, input text |
| 15px | 77 | section titles, card titles |
| 16px | 24 | page titles on mobile, prominent card titles |
| 17–19px | 27 | card headings, dialog titles, brand wordmark |
| 20–24px | 34 | stat values, page headings |
| 26–31px | 40 | page and hero titles |
| 36–40px | 2 | activity-select headline |
| 48px | 1 | splash wordmark |

### 8.3 Weight system — a correction to the previous document

The previous document retired `font-weight: 800` from functional UI. **The prototype uses 800
more than any other weight** (221 occurrences vs 700 at 180, 600 at 52, 500 at 8). 800 is the
signature of Hivorr's headings and figures. It is not a violation.

| Weight | Count | Role |
| --- | --- | --- |
| 800 | 221 | headings, hero titles, stat values, nav group labels, brand |
| 700 | 180 | buttons, card titles, section titles, strong labels |
| 600 | 52 | pills, secondary labels, muted emphasis |
| 500 | 8 | rare — a single input family and a few captions |
| 900 | 3 | 9px uppercase micro-labels only |

The actual constraint is **hierarchy**, not a weight ceiling: if more than roughly 15% of the
visible words on a screen are 700-or-heavier, the hierarchy has flattened and the screen fails
review.

### 8.4 Type roles

| Role | Size | Weight | Family | Notes |
| --- | --- | --- | --- | --- |
| Splash wordmark | 48 | 800 | display | `letter-spacing: -2px` |
| Marketing headline | 40 / 30 mobile | 800 | display | `letter-spacing: -1.2px`, `line-height: 1.15` |
| Hero title | 31 / 25 mobile | 800 | display | `letter-spacing: -0.5px`, `line-height: 1.18` |
| Page title | 22 | 800 | display | admin and dashboard headers |
| Section title | 15–21 | 700–800 | display | `Section` primitive uses 15/700 |
| Card title | 15 | 700–800 | display | |
| Stat value | 22 | 800 | display | `line-height: 1.1` |
| Dialog title | 19 | 800 | display | |
| Body | 13–14 | 400–500 | body | `line-height: 1.5–1.7` |
| Button label | 12 / 14 / 16 by size | 700 | display | |
| Pill label | 11 | 600 | display | |
| Eyebrow | 10–12 | 800 | display | uppercase, `letter-spacing: 0.8–1.5px` |
| Meta | 11–12 | 400–600 | body | `#6B7280` or `#9CA3AF` |

### 8.5 Tracking and line-height

- Large headings: `-0.5px` to `-2px`, scaling with size.
- Uppercase eyebrows and micro-labels: `+0.8px` to `+1.5px`.
- Headings: `1.15–1.3`. Body: `1.5–1.7`.
- Never use tracking to compensate for a size that is wrong.

### 8.6 Rules

- Do not introduce another family, including a "display" serif for marketing.
- Do not set `font-family` per element in new code — use `font-display` / `font-body`.
- One hero size per page. Section titles share one style. Card titles share one style.
- Do not use `font-weight: 900` outside 9px uppercase micro-labels.
- Do not use text below 12px for anything a user must read (§25).

---

## 9. Spacing & Layout

### 9.1 Observed scale

The prototype uses a 2px-granularity scale with strong clusters at **6, 8, 10, 12, 14** for gaps
and **9–14, 16** for padding.

| Use | Values in use |
| --- | --- |
| Micro gap (icon → text) | 3, 4, 5, 6 |
| Element gap | 8, 10, 12 |
| Card / section gap | 14, 16, 18, 20 |
| Major section gap | 24, 26, 28 |
| Card padding | 16, 18, 20, 22, 24, 28 |
| Page gutter — mobile | 16, 18, 20 |
| Page gutter — desktop | 28, 32, 42, 48 |
| Page bottom padding — mobile | 48, 90 (to clear bottom navigation) |

Rule of thumb: related elements sit closer; unrelated elements get visibly more space. The
relationship is the design; the number is the implementation.

### 9.2 Content widths

| Context | Max width |
| --- | --- |
| Activity chooser | 1080px |
| Local Market home | 1240px |
| Auth card | 940px |
| Focused content / forms | 680–720px |
| General dashboard content | 880–1200px |
| Dialog | 520px default, `min(760px, 100vh - 40px)` max height |
| Sidebar | 224px expanded, 66px collapsed |

Content is centred with symmetric gutters. A wide parent is never a reason for full-bleed text.

### 9.3 Grid behaviour

| Context | Columns |
| --- | --- |
| Activity cards | 1 mobile / 1 tablet / 3 desktop |
| Product grid | 2 mobile / 3 tablet / 4 desktop |
| Stat row | 2 mobile / 2–3 tablet / 4 desktop |
| Hero | 1 column below 1024 / `minmax(0,1.3fr) minmax(260px,.7fr)` at desktop |
| Split detail | 1 column mobile / `.85fr 1.15fr` desktop |

No fixed-height content blocks. Height is content-driven. Media is the only documented exception.

---

## 10. Shape & Radius

Radius is a language, not a preference. Observed distribution: 12px (47), 10px (36), 13px (34),
11px (32), 50% (31), 8px (28), 14px (22), 16px (18), 20px (15), 22px (15), 18px (11).

| Radius | Use |
| --- | --- |
| 4–6px | micro inner elements, tiny tags |
| 6–8px | compact chips, small inner tiles |
| 8–10px | chips, small controls, nav sub-items |
| 10–11px | icon tiles, navigation items, 36px toolbar buttons |
| 12–13px | **buttons and inputs** (both are 12), standard icon tiles (13) |
| 14–16px | compact cards, media thumbnails, 52px activity icon tiles (16) |
| 18px | **default card radius** (`Card` primitive) and `StatCard` |
| 20–22px | hero images (20), activity cards (20), dialogs (22) |
| 24px | **hero sections** |
| 28px | auth card, splash mark |
| 50% / 999px | avatars, pills, dots |

Composite radii are part of the identity and must be preserved:

```text
"22px 22px 0 0"          mobile dialog / bottom sheet, top corners only
"24px 24px 0 0"          mobile sheet variant
"18px 18px 4px 18px"     chat bubble, incoming
"18px 18px 18px 4px"     chat bubble, outgoing
```

Do not use extreme rounding everywhere. Do not mix unrelated radius styles on one screen without
purpose. Nested cards do not stack radii — they do not nest at all (§21).

---

## 11. Elevation & Shadow

Elevation is soft. There are no hard drop shadows and no heavy contrast.

| Level | Treatment | Use |
| --- | --- | --- |
| 0 — flat | `1px solid rgba(15,22,38,0.07)`, no shadow | static containment, list rows, table wrappers |
| 1 — rest | `0 2px 12px rgba(15,22,38,0.05)` | cards, stat cards (the canonical resting shadow) |
| 2 — hover | `0 8px 24px rgba(45,63,231,0.10)` | interactive card hover, clickable stat cards |
| 3 — overlay | `0 28px 80px rgba(15,22,38,0.28)` | dialogs, sheets, menus |
| 4 — auth | `0 32px 80px rgba(0,0,0,0.2)` | the auth card only |
| 5 — dock | `0 -8px 24px rgba(15,22,38,0.06)` | mobile bottom navigation |

Coloured lift is permitted on exactly three surfaces, using the accent's own hue:

```text
orange  card: 0 14px 34px rgba(249,115,22,.13)
blue    card: 0 16px 38px rgba(45,63,231,.2)
green   card: 0 16px 38px rgba(22,163,74,.18)
hero image:   0 16px 34px rgba(8,15,35,.2)
```

Everything else uses neutral shadow. Never tint a shadow with a hue that is not that surface's own
accent.

Prefer borders for static containment and shadows for interactive or modal surfaces. A card
normally carries **both** a hairline border and the Level-1 shadow — this is the prototype's
pattern and differs from the previous document's "never both" rule.

---

## 12. Borders

- Default: `1px solid rgba(15,22,38,0.07)`.
- Strong: `1px solid #DDE1EB` or `#E5E7EB` — dividers, inactive steps.
- Active / selected: `1.5px`–`2px` in the accent colour. The selected gallery thumbnail uses
  `2px solid #2D3FE7`; the priority errand card uses `1.5px solid rgba(249,115,22,0.21)`.
- Inputs: `1.5px solid transparent` at rest, border becomes the accent on focus.
- Do not outline every element. Do not use a border and a heavy shadow on the same static surface.

---

## 13. Iconography

- **`lucide-react` only.** No second icon set, no emoji as icons, no custom SVG icon library.
- Sizes: 12–24px in UI (12, 13, 14, 15, 17, 18, 20 are the common steps), 48–56px in onboarding
  art, 96px on the splash mark.
- Colour: the current activity accent, the semantic colour, or `#6B7280` / `#9CA3AF` for neutral.
  Never a random hue.
- Icons support meaning; they do not decorate. An icon never replaces a label where the label is
  needed to understand the action.
- Status icons are always paired with text (§25).
- Icon tiles: a coloured tint square at radius 11–16 with a 12–22px icon in the matching base
  colour. `StatCard` uses 46×46 at radius 13; the activity chooser uses 52×52 at radius 16.

---

## 14. Imagery & Illustration

- **Photography is canonical.** Five activity hero images are Unsplash photographs
  (hiring, selling, services, logistics, errands) and product photography fills the Local Market.
- Hero image treatment: `border-radius: 20px`, `border: 4px solid rgba(255,255,255,.18)`,
  `box-shadow: 0 16px 34px rgba(8,15,35,.2)`, `object-fit: cover`, `object-position: center`.
- Product media: radius 10–22 depending on size, `object-fit: cover`, no border.
- A rotated promotional image uses `transform: rotate(3deg)` with a 5px white-18% border. This is
  a single sanctioned brand moment, not a general pattern.
- Do not replace photography with placeholder graphics, abstract blobs, or an illustration set.
- Do not add decorative stock imagery to fill space. Every image must communicate trust, identity,
  product, or context.
- Images must degrade gracefully: fixed aspect boxes so layout never jumps, and a neutral surface
  behind the image while it loads.

---

## 15. Navigation & Shells

### 15.1 Desktop sidebar

| Property | Value |
| --- | --- |
| Width | 224px expanded · 66px collapsed |
| Surface | `#FFFFFF`, `1px solid rgba(15,22,38,0.07)` right border |
| Position | sticky, full viewport height |
| Header | 36×36 brand tile (radius 10, `#2D3FE7`, white `Zap`) + "Hivorr" 800 |
| Identity block | role dot + role label in the role colour, 34px avatar |
| Item | icon 17px + label 12px/700, padding ~10–12px, radius 11 |
| Active item | accent tint background + accent text + 800 weight |
| Inactive item | transparent background, `#6B7280` text |
| Transition | `width 0.25s` |

The sidebar is **activity-specific**. `MarketShell` builds its own navigation from the activity.

| Shell | Navigation |
| --- | --- |
| Local Market (Buy) | Market Home · Browse Products · Saved Products · Cart · My Orders · Payments · Profile |
| Client (Hire) | Dashboard · Find Services · Post a Job · My Jobs · Applications · Messages · Payments · Profile |
| Professional | Dashboard · Find Work · My Jobs · Messages · Earnings · Earnings Analysis · Profile |
| Seller | Overview · Products · Add Product · Orders · Inventory · Invoices · Sales Analysis · Earnings · Profile |
| Errand | Errand Home · Create Errand · My Errands · Active Tracking · Payments · Profile |
| Logistics | Overview · Available Requests · Active Assignments · Delivery History · Earnings · Analysis · Profile · Provider Details |
| Admin | Explore group (Buyer · Client · Errand) · Earn group (Seller · Professional · Logistics) · Platform Admin (Support · Security Logs) |

The Client shell has **eight** destinations; every other shell has six to nine. Mobile reduces each
to five (§15.3). Do not invent a shared "one size" navigation set.

### 15.2 Top bar

- Height 62px, white, `1px` bottom border, sticky, `z-index: 30`.
- Left: a 36×36 control at radius 10, `#F4F6FB` background — menu on root screens, back arrow on
  detail screens — then the page title at 16px/700 (14px on mobile).
- Right: contextual actions, then notifications/avatar.
- The top bar owns the page title. A screen inside a shell **must not** render a duplicate in-body
  H1. In-body headers carry the eyebrow, subtitle, and actions only.

### 15.3 Mobile navigation

- **Drawer**: 260px wide, fixed left, `z-index: 51`, over a `rgba(0,0,0,.42)` scrim at `z-index: 50`.
  It contains the same activity sidebar, uncollapsed.
- **Bottom bar**: fixed, full width, white, `1px` top border, `0 -8px 24px rgba(15,22,38,.06)`,
  `padding-bottom: env(safe-area-inset-bottom, 4px)`, `z-index: 40`.
- Exactly **five** destinations per activity. The primary destination (e.g. "Add Product",
  "New Errand") renders as a 40×40 accent tile at radius 13.
- Icons sit above 10–11px labels; the active item uses the activity accent.
- Content reserves ~90px bottom padding so the bar never covers the last row.

### 15.4 Shell rules

- Chrome comes from the shell only. No per-screen top bars, sidebars, or nav rows.
- Every interactive chrome control exposes at least a 44px hit area, even when the visible tile is
  36–40px.
- The shell never changes colour between screens of the same activity. The accent changes only
  when the activity changes.

---

## 16. Components & Interface Patterns

These are the prototype's shared primitives. They are the component library. Reuse them; do not
fork them.

| Primitive | Purpose |
| --- | --- |
| `Av` | initials avatar — circular, `color + "20"` fill, `2px solid color + "30"` ring, display font |
| `Pill` | status chip (§5.1) |
| `Btn` | primary / secondary / ghost / danger, three sizes |
| `Input` | labelled field, optional textarea |
| `SelectField` | labelled select |
| `Card` | white surface, radius 18, padding 20, hairline border, Level-1 shadow |
| `StatCard` | metric tile: icon chip → label → value → delta |
| `Section` | section title + optional action link + stacked children |
| `Stars` | amber rating display |
| `JobRow` | job/opportunity list row |
| `PrototypeDialog` | modal on desktop, bottom sheet on mobile |
| `FinancialActionDialog` | money confirmation flow |
| `ActivityHero` | the activity hero band (§18) |
| `WalletInfo` | shared wallet summary |
| `ChatUI` | thread, bubbles, composer |
| `MarketShell` | activity shell: sidebar + top bar + mobile nav |
| `Sidebar` / `TopBar` / `MobileNavBar` | chrome |

### 16.1 Buttons

| Variant | Background | Text |
| --- | --- | --- |
| primary | `#2D3FE7` | `#FFFFFF` |
| secondary | `#EEF0FD` | `#2D3FE7` |
| ghost | `#F4F6FB` | `#6B7280` |
| danger | `#FEF2F2` | `#EF4444` |

| Size | Padding | Font |
| --- | --- | --- |
| sm | `7px 14px` | 12px / 700 |
| md | `12px 20px` | 14px / 700 |
| lg | `15px 24px` | 16px / 700 |

All buttons: radius 12, display font, `display: flex`, centred, `gap: 6px`, `transition: opacity
0.15s`, hover `opacity: 0.85`, disabled `opacity: 0.65` with `cursor: default`.

One primary button per view. Everything else is secondary, ghost, or a text link.

### 16.2 Inputs and forms

```text
background: #F4F6FB · radius: 12px · padding: 13px 14px
border: 1.5px solid transparent · font: Inter 14px · color: #0F1626
focus: border-color #2D3FE7 · transition: border-color 0.2s
label: 13px / 600 · #374151 · 6px above the field
```

- Field height must remain comfortable — never below 44px total.
- Placeholder text is `#9CA3AF`; it is never the only label.
- Errors use the red base and are paired with text, not colour alone.
- Two-column form grids collapse to one column below 768px.

### 16.3 Cards

- Default: white, radius 18, padding 20, `1px solid rgba(15,22,38,0.07)`,
  `0 2px 12px rgba(15,22,38,0.05)`.
- Padding range: 16–28. `20` is the default; `16` for dense lists; `28` for hero panels.
- Cards do not nest inside cards. Use a divider, a section, or a list row.
- Height is content-driven; long text is clamped, not accommodated by a fixed height.
- Interactive cards lift to the hover shadow; static cards do not.

### 16.4 Stat cards

46×46 icon tile at radius 13 in the metric's tint → 12px label in `#9CA3AF` → 22px/800 value in
`#0F1626` → optional 12px/600 delta in the semantic colour. The tile's accent is the activity or
semantic colour, never an arbitrary one.

### 16.5 Dialogs and sheets

- Desktop: centred, radius 22, `max-width: 520px`, `box-shadow: 0 28px 80px rgba(15,22,38,.28)`,
  24px padding, scrim `rgba(15,22,38,.46)` at `z-index: 80`.
- Mobile: bottom sheet, `border-radius: 22px 22px 0 0`, full width, `max-height: 88vh`,
  `padding-bottom: calc(20px + env(safe-area-inset-bottom))`.
- Anatomy: optional eyebrow pill → 19px/800 title → close control → content → footer actions.
- `role="dialog"`, `aria-modal="true"`, `aria-label` from the title, Escape and scrim close.
- Financial actions always confirm amount, counterparty, and consequence before committing.

### 16.6 Lists and rows

- Row: 12–14px title/700, 11–12px meta, optional trailing pill, `gap: 10–14`, hairline divider or
  tinted hover.
- Avatars 34–44px in rows.
- A row that navigates must look interactive and must be keyboard reachable.
- Tables are wrapped in a card and never overflow horizontally on mobile — they become rows.

### 16.7 Chat

- Thread surface `#F4F6FB`.
- Bubbles radius `18px 18px 4px 18px` (outgoing) and `18px 18px 18px 4px` (incoming).
- Outgoing bubbles use the activity accent; incoming bubbles use white with a hairline border.
- Timestamps 10–11px in `#9CA3AF`.
- The composer is sticky above the safe area on mobile.

---

## 17. Dashboard Visual Standards

Every activity dashboard follows the same **structural** rhythm and its own **colour** identity.

### 17.1 Anatomy

```text
ActivityHero        gradient band, greeting, eyebrow, supporting copy, one action, one image
Stat row            3–4 StatCards, activity accent, one semantic delta
Primary work area   the two or three things this activity is actually for
Supporting sections Section + cards / rows
Wallet strip        shared wallet summary where money is involved
```

Density is deliberate: a dashboard is a working surface, not a landing page. There is no large
empty hero on a dashboard — the hero is a compact band (18px padding mobile, 28px desktop).

### 17.2 Per-activity identity

| Activity | Hero gradient | Accent in UI | Character |
| --- | --- | --- | --- |
| Local Market | `#1D2CC9 → #3D50F1` | blue | product-led, photographic, price-forward |
| Client | `#1727BE → #2D3FE7 → #5263F4` | blue | job-led, list-forward, application counts |
| Errand | `#B9380A → #EA580C → #FB7B32` | orange | urgency-led, priority card, live tracking |
| Seller | `#5B21B6 → #7C3AED → #9B66F3` | purple | catalogue-led, order/inventory figures |
| Professional | `#116530 → #16A34A → #32B965` | green | credibility-led, earnings and ratings |
| Logistics | `#0F5F5A → #0F766E → #16A34A` | green/teal | dispatch-led, active assignment, route |
| Admin | none — white surfaces, purple controls | purple | governance-led, tables, review queues |

A user switching between dashboards must feel a **change of context**, not a change of product.

### 17.3 Wallet

The wallet is shared across activities and uses **brand blue** (`#2D3FE7` / `#EEF0FD`) with the
label "UNIFIED HIVORR WALLET" or "SHARED HIVORR WALLET". It shows total, available, pending, and
withdrawable as distinct figures. Activity transaction records are listed with an activity label
and the activity's accent, so money is legible per activity without fragmenting the balance.

### 17.4 Admin

- Identity: purple `#8B5CF6` in the sidebar, role badge, pills, and controls.
- `#1A2AD4` is **not** admin identity. It appears only as a gradient anchor.
- Admin screens that impersonate a managed dashboard inherit **that dashboard's** accent for the
  content area, while the admin chrome stays purple.
- Admin is denser than any user dashboard: tables, review queues, audit rows, configuration panels.
  Small type is acceptable for data, never for actions or labels a user must read.

---

## 18. Hero Sections

`ActivityHero` is the canonical band.

| Property | Mobile | Desktop |
| --- | --- | --- |
| Radius | 24 | 24 |
| Padding | 18 | 28 |
| Layout | 1 column | `minmax(0,1.3fr) minmax(260px,.7fr)` |
| Gap | 18 | 24 |
| Title | 25px / 800 | 31px / 800 |
| Image height | 150 | 220 |
| Image radius | 20 | 20 |

Anatomy:

1. Eyebrow pill — `rgba(255,255,255,.14)` fill, `1px solid rgba(255,255,255,.2)` border,
   `rgba(255,255,255,.88)` text, 10px/800, `letter-spacing: .8px`, radius 20.
2. Greeting title — time-aware ("Good morning, {name}.").
3. Supporting copy — 13–15px, white at high opacity.
4. One primary action (a `Btn`).
5. Optional highlight stats (desktop only).
6. Photographic image with the §14 treatment.

The hero is the one place a gradient may dominate. It must communicate the activity's value within
seconds. Do not build an empty hero for spaciousness.

---

## 19. Page Composition & Section Rhythm

Before building a screen, answer: what is the purpose, what is the primary action, what should the
user notice second, and what belongs together?

```text
Page purpose → Primary action → Primary information
→ Supporting information → Secondary actions → Additional information
```

Long pages need rhythm. Vary structure coherently:

```text
Hero → Stat row → Card grid → Split content → Feature panel
→ List / timeline → Wallet strip → CTA
```

Never stack identical sections. Never add a section to inflate length. Alternate `#F0F2F8` and
`#FFFFFF` surfaces to separate bands, and keep the spacing scale constant while the structure
varies.

### 19.1 "Do not look static"

A page must not read as heading → paragraph → button → paragraph. When information can be grouped,
group it: cards, stat blocks, timelines, category tiles, tables, panels, split layouts, list rows.

Structure exists to create hierarchy — not decoration.

### 19.2 Decoration budget

Decoration is permitted only in these slots:

| Slot | Allowed |
| --- | --- |
| Activity hero | gradient, photograph, one highlight stat block |
| Auth / onboarding | the deep-blue gradient, brand tile, one supporting panel |
| Celebration | one restrained moment per completed flow, brand hues only |
| Empty state | one line-art or icon treatment, brand-tinted, with guidance and a next action |
| Route placeholder | the `#E0F2FE → #EEF0FD` wash with a map/route motif |

Guardrails: palette-locked, static, one decorative element per viewport, removable without layout
collapse, never on errors or financial figures, and never a substitute for missing content.

---

## 20. Card Hierarchy

Different domains must not look alike. All cards share the same surface language; they differ in
accent and anatomy.

| Card | Accent | Anatomy |
| --- | --- | --- |
| Product (Local Market) | blue | media 1:1 → title → price (the hero) → store row with rating → fulfilment chip |
| Service / professional | green | title → professional row → rating + completed count → rate/duration → CTA |
| Store | blue | logo → store name + verified → categories → rating + location → visit |
| Job / opportunity | blue or activity accent | title → client → rate → tags → apply/save |
| Order / contract | neutral + status pill | id + date → parties → amount + escrow state → progress → exactly one next action |
| Errand | orange | request summary → pickup/drop-off → window → provider → status |
| Delivery / tracking | green + status pill | 3–5 step timeline → provider row → ETA → tracking action |
| Metric | dashboard accent | label → value → delta |
| Wallet | blue | balance → available/pending/withdrawable → actions → recent activity |

Rules: one primary action per card; the price or the trust signal is the hero, never hidden behind
a tap; no card-inside-card; no fixed heights for text.

---

## 21. Whitespace & Density

Hivorr is dense but never cramped. The difference is grouping, not padding.

- Every screen has deliberate breathing room at its edges: 16–20px mobile, 28–32px desktop.
- Related items are closer than unrelated items. A uniform gap everywhere destroys hierarchy.
- Dense regions (tables, queues, audit logs) may use 9–12px type for data. Actions, labels, and
  anything a user must read stay at 12px or above.
- Cards are not the answer to every layout. Lists, tables, timelines, and split panels are often
  better and are used in the prototype.
- Never fill space with decoration. Empty space is resolved with hierarchy or grouping first.

---

## 22. Responsive Design

Breakpoints are fixed by the prototype (`useBreakpoint`):

```text
isMobile   width < 768
isTablet   768 ≤ width < 1024
isDesktop  width ≥ 1024
```

The previous document used 600 / 1024. **That is superseded.** Do not introduce a third breakpoint
or a new grid system.

### 22.1 Mobile — below 768

- Single column.
- Drawer navigation + bottom bar with five destinations.
- Dialogs become bottom sheets with `22px 22px 0 0` top corners.
- Gutters 16–20px; bottom padding ~90px to clear the navigation.
- Hero collapses to one column, title 25px, image height 150.
- Tables become stacked rows. No horizontal scrolling except intentional carousels.

### 22.2 Tablet — 768 to 1023

- Sidebar **collapsed** to 66px (except Admin, which stays expanded).
- Two-column grids; hero remains single column.
- Gutters 20–28px.
- Bottom navigation is not shown.

### 22.3 Desktop — 1024 and above

- Full 224px sidebar.
- Three- and four-column grids.
- Hero splits into the 1.3fr / 0.7fr layout.
- Content capped at 880–1240px and centred.

### 22.4 Verification

Every screen is verified at **375, 768, and 1280px** before it is considered complete, and visually
compared against the prototype at each width. Responsive behaviour is part of the design, not an
afterthought — never simply shrink the desktop layout.

---

## 23. Interaction States & Motion

| State | Treatment |
| --- | --- |
| Rest | as specified per component |
| Hover | `opacity: 0.85` on buttons; Level-2 shadow on interactive cards; tint background on nav rows |
| Focus | visible accent outline / ring; never removed, never replaced by shadow alone |
| Active / selected | accent tint background, accent text, 700–800 weight, 1.5–2px accent border where a border applies |
| Disabled | `opacity: 0.65`, `cursor: default`, `#ECEFF5` fill for fields; always paired with a reason in the UI |
| Loading | skeleton or branded state; never a bare spinner |
| Empty | branded state with guidance and a next action; never a dead end |

Motion:

- Transitions 0.15–0.3s, ease-out. `width 0.25s` for the sidebar, `background 0.4s` for onboarding
  slides, `border-color 0.2s` on inputs.
- No continuous animation. Celebration runs once.
- Honour `prefers-reduced-motion` — replace movement with the end state.
- Motion never delays a financial confirmation or hides a state change.

---

## 24. Accessibility

The palette is fixed and is **not** adjusted for contrast. Report, do not alter.

### 24.1 Measured contrast in the prototype

These are computed WCAG 2.1 ratios against the actual token pairs. They are reported, not
silently corrected.

| Pair | Ratio | AA normal text (4.5) | AA large / UI (3.0) |
| --- | --- | --- | --- |
| blue `#2D3FE7` on `#EEF0FD` | 6.22 | pass | pass |
| green `#16A34A` on `#DCFCE7` | 3.00 | **fail** | pass |
| orange `#F97316` on `#FFF7ED` | 2.64 | **fail** | **fail** |
| purple `#8B5CF6` on `#F3F0FF` | 3.77 | **fail** | pass |
| red `#EF4444` on `#FEF2F2` | 3.44 | **fail** | pass |
| cyan `#0891B2` on `#E0F2FE` | 3.21 | **fail** | pass |
| `#6B7280` on white | 4.83 | pass | pass |
| `#9CA3AF` on white | 2.54 | **fail** | **fail** |
| `#9CA3AF` on `#F4F6FB` | 2.35 | **fail** | **fail** |
| white on `#2D3FE7` | 7.06 | pass | pass |
| white on `#16A34A` | 3.30 | **fail** | pass |
| white on `#F97316` | 2.80 | **fail** | **fail** |
| white on `#8B5CF6` | 4.23 | **fail** | pass |
| white on `#EF4444` | 3.76 | **fail** | pass |

Gradient ends where white text sits in the prototype: `#32B965` 2.54, `#22C55E` 2.28,
`#FB7B32` 2.63, `#EA580C` 3.56, `#9B66F3` 3.76, `#5263F4` 4.72, `#4F5FEF` 4.98.

### 24.2 Required practice

- **Pill text is the base hue on its tint, exactly as the prototype renders it.** The measured
  ratios are in §24.1; five of six fail 4.5:1 at 11px. That shortfall is **recorded, not
  corrected** — a darker label colour would be a colour the prototype does not contain (§3.5).
  Mitigate through usage only: never let a pill be the sole carrier of a status, and pair it with a
  word or an icon.
- **Body text** must reach 4.5:1. Use `#6B7280` or darker on white. `#9CA3AF` is meta only.
- **On gradients**, use white at exactly the opacity the prototype uses. Do not add a scrim, and do
  not darken or move a gradient stop — both introduce a colour or a surface the prototype does not
  have. The shortfall on light stops (`#32B965` 2.54, `#22C55E` 2.28, `#FB7B32` 2.63, `#9B66F3`
  3.76) is recorded in §31 #9.
- **Sizes** are exactly the prototype's: 13–14px body, 12px meta, 11px pill labels, 9–10px
  uppercase micro-labels. Do not raise a size the prototype sets.
- **Touch targets** ≥ 44px, even when the visible control is 36px.
- **Focus** is always visible, in every context, and never removed.
- **Status is never colour alone** — always a word or an icon with it.
- **Text scale**: at 1.3× no functional screen may overflow or clip.
- **Reduced motion** is honoured everywhere.

---

## 25. Visual Consistency & Reuse

- Search the shared primitives (§16) before building anything. A new private duplicate of an
  existing primitive fails review.
- A new page inherits the established language. It must feel like *"another Hivorr page"*, never
  *"a new page that happens to live inside Hivorr"*.
- Consistency means: same shell, same spacing scale, same radius language, same shadow language,
  same type roles, correct activity accent.
- Consistency does **not** mean: every activity the same colour, every card the same anatomy, every
  screen the same structure.
- When a genuinely reusable pattern appears, promote it into the shared layer and document it here.
  The system grows richer without growing inconsistent.

---

## 26. Design Preservation Rules

These are non-negotiable for every task, human or agent.

1. **Do not replace the palette.** Not with the previous Flutter palette, not with a stock design
   system, not with a "cleaner" neutral set.
2. **Do not unify the six activities.** Their accents, gradients, and navigation sets are product
   identity.
3. **Do not flatten gradients, tints, or accent treatments** into flat fills for convenience.
4. **Do not introduce a hue** that is not in §3, §4, or §5. New colours require founder approval.
5. **Do not restyle to match a component library.** `shadcn` and Tailwind primitives are consumed
   through `theme.css`; they never impose their own look.
6. **Do not change typography.** Two families, the documented weights, the documented scale.
7. **Do not change the breakpoints** (768 / 1024) or invent a new grid.
8. **Do not redesign while refactoring.** Extraction preserves rendering; a visual change is a
   separate, approved change.
9. **Do not silently "fix" the prototype.** Report the discrepancy and propose a change.
10. **Do not add dark mode.** The prototype is light-only; no dark palette exists.

---

## 27. Anti-Patterns (forbidden)

- Raw hex, `rgb()`, or `rgba()` outside the token layer.
- A second palette in a component, a stylesheet, or a one-off gradient.
- `font-family` set per element in new code instead of `font-display` / `font-body`.
- A third font family, including a "premium" display serif.
- Accent colour used as body text, as a full-bleed page background, or as decoration.
- Status conveyed by colour alone.
- Card-inside-card-inside-card; every card heavily shadowed; every element outlined.
- Fixed-height blocks for text-bearing content.
- Generic "header + three cards + table" on every page, regardless of the domain.
- Duplicated chrome: a second sidebar lockup, a private stat card, a private dialog, a private
  chat bubble, a private section header.
- A second H1 inside a shell that already titles the page.
- Bare spinners, dead-end empty states, skeleton-less first paint for tables and grids.
- Product rendered as a service (a "bid" on a product) or a service as a product ("stock" on a
  service).
- Marketing decoration on a financial figure, an error, or a verification decision.
- "Modernising" a screen without approval.

---

## 28. Enforcement & Definition of Done

A UI task is complete only when:

1. Colours, typography, radii, shadows, and spacing match the prototype.
2. The correct activity accent is preserved; nothing was unified for convenience.
3. All colours resolve to approved tokens; no new hex was introduced.
4. The screen works at 375px, 768px, and 1280px.
5. Keyboard focus is visible and text contrast meets 4.5:1 (§24).
6. No unreachable screens, dead controls, or duplicated primitives were added.
7. Any deliberate divergence from the prototype is documented and approved.
8. The visual-regression comparison against the prototype passes at all three widths
   (`ARCHITECTURE.md` §18).

Automated checks that should exist as the codebase grows:

- token scan for raw hex and `rgba()` outside `theme.css`;
- scan for `fontFamily` outside the token layer;
- scan for breakpoints other than 768 / 1024;
- contrast check on pill and body text pairs;
- screenshot diff at 375 / 768 / 1280.

---

## 29. Change Process & Evolution

To change a colour, gradient, font, radius, shadow, motion, or the logo:

1. Update **this document** first, with the reason and the affected surfaces.
2. Obtain founder approval (§32).
3. Update `src/styles/theme.css` (and assets) to match.
4. Update the affected components and their visual-regression baselines.
5. Never edit tokens in code without updating this source of truth.

When a new component introduces a reusable pattern: decide whether it becomes shared, document the
visual rule here if it is reusable, and reuse it afterwards.

**The permanent rule:** every new page inherits the established visual language rather than
inventing its own. Prioritise consistency, hierarchy, purposeful composition, spacing, reusable
components, activity-aware colour, meaningful surfaces, responsive behaviour, and professional
polish — in that order.

---

## 30. Visual Quality Checklist

Before a page is considered complete:

- Is the purpose clear and the primary action obvious?
- Is the page structured, not static? Is whitespace intentional?
- Are cards used where they help, and other layouts where they do not?
- Is the correct **activity** accent present, and is it the only one in the content area?
- Are the shared primitives reused rather than duplicated?
- Is the hierarchy legible at a glance — eyebrow, title, body, action?
- Does it work at 375 / 768 / 1280 without horizontal scroll or clipping?
- Do contrast, focus, target size, and labels pass §24?
- Does it avoid generic-template looks and decoration without purpose?
- Does it look like *another Hivorr page*?

Density check: card padding 16–28; section gaps 14–24; columns reach the §9.3 counts; no fixed
heights; no weight escalation above ~15% of visible words; no text below 12px that a user must
read; no raw hex.

---

## 31. Known Inconsistencies

These were properties of the prototype as it stood. They are recorded here so that no one
"corrects" them silently. Each was decided on 1 November 2026 — see §32.

| # | Inconsistency | Detail | Status |
| --- | --- | --- | --- |
| 1 | **Hire accent** | The activity chooser uses **purple** for "I Want to Hire"; the Client dashboard, its hero gradient, and its role colour are **blue**. | **Accepted** — both surfaces are the prototype. Renders as-is. |
| 2 | **Logistics accent** | The activity chooser uses **orange** for "I Want to Provide Logistics"; the Logistics dashboard, hero, and role colour are **green/teal**. | **Accepted** — both surfaces are the prototype. Renders as-is. |
| 3 | **Errand vs logistics ownership** | "Send an Errand" says it "connect[s] you with an eligible logistics provider", so the errand and logistics activities overlap in the product narrative. Not a visual defect, but it affects the colour story. | **Open** — product decision (matrix §18 #2). |
| 4 | **Orange overload** | Orange carries pending status, priority, errand accent, and caution notes. In the errand and logistics shells these readings collide. | **Accepted** — inherent to the approved accent system. Status semantics win in content. |
| 5 | **Green overload** | Green is success, Professional accent, and Logistics accent. | **Accepted** — the two activities keep different gradients and different navigation. |
| 6 | **Currency in one wallet** | The prototype mixes USD (hire, professional) and NGN (market, errand, logistics) inside one wallet surface. Not visual, but it is visible on screen. | **Open** — product decision (§32 item 9). |
| 7 | **Small type** | 21 uses of 9px and 82 of 10px, including table headers and uppercase labels. | **Accepted** — renders as the prototype does. |
| 8 | **Muted text** | `#9CA3AF` is used for 12px meta on white (2.54:1). | **No change** — the prototype already uses `#9CA3AF` for meta and `#6B7280` for body. Renders as the prototype does. |
| 9 | **White on gradients** | White text sits on light gradient stops that cannot carry it (2.28–3.76:1). | **Recorded, not corrected** — no scrim, no darkened stop. Renders as the prototype does. |
| 10 | **Inline styling** | ~1,882 inline style objects, ~150 inline `font-family` declarations, and three `className` uses. This is a migration concern, not a visual one. | **Open** — migrate as files are touched. |

---

## 32. Prototype Fidelity — Decisions Recorded

Decided 1 November 2026; revised 3 November 2026. The governing rule is: **the prototype is the
only source of truth for UI, and nothing in this document changes it.** Its colours are final
(§3.5). Where the prototype contradicts itself, both behaviours stand and the divergence is recorded
in §31.

The net result is that **no UI change is authorised.** Every item below resolves to *render exactly
what the prototype renders*.

| # | Item | Decision | Effect |
| --- | --- | --- | --- |
| 1 | Hire accent | **No change.** The chooser stays purple, the Client dashboard stays blue. Both are the prototype. | Recorded in §31 #1. |
| 2 | Logistics accent | **No change.** The chooser stays orange, the Logistics dashboard stays green/teal. Both are the prototype. | Recorded in §31 #2. |
| 3 | Pill text | **No change.** Pills keep the base hue on its tint. The six darker label values proposed earlier are **rejected** — five do not exist in the prototype, and the sixth is a gradient stop. | Renders exactly as the prototype. Gap recorded in §31 #8. |
| 4 | Hero text on gradients | **No change.** White at the opacity the prototype uses; no scrim, no darkened or moved stop. | Renders exactly as the prototype. Gap recorded in §31 #9. |
| 5 | Readable floor | **No change.** Type sizes are exactly as the prototype sets them, including 9–10px micro-labels. | Recorded in §31 #7. |
| 6 | Muted text | **No change needed.** The prototype already uses `#6B7280` for body and `#9CA3AF` for meta, which is what §24.2 and `AGENTS.md` §2.11 already require. | None. |
| 7 | Tokens | **Add the activity gradients and the gray scale to `theme.css`.** | No visual change; inline literals gain a home. |
| 8 | Canonical mark | **The icon tile is canonical** until real logo assets exist. | No asset dependency. |
| 9 | Wallet currency | **Keep the prototype's presentation**: each activity's amounts in their own currency, side by side in the shared wallet, with no implied conversion. | The underlying currency model stays a product decision (`ARCHITECTURE.md` Appendix C #3). |

### 32.1 What these decisions do not permit

- No new colour of any kind, and no substitution of one prototype colour for another. The palette
  is closed (§3.5).
- No change to any base colour, tint, gradient stop, radius, shadow, or type size.
- No accessibility override. A pair that falls short of 4.5:1 is recorded in §24, not corrected.
- No restructuring of a screen, a card, or a navigation set.
- No "modernising" pass, and no resolving the prototype's internal divergences in code.

---

## Appendix — What changed from the previous document

| Previous specification | Status now | Reason |
| --- | --- | --- |
| Flutter / Dart / `ThemeData` / `AppColors` / `RoleThemeExtension` | **Replaced** | The stack is React 18 + Vite 6 + TypeScript + Tailwind 4; tokens live in `theme.css`. |
| `lib/` paths, `HivorrCard`, `HivorrSpacing`, `Breakpoints` | **Replaced** | React primitives and `theme.css` tokens replace the Flutter layer. |
| Dark theme tokens and dark-theme rules | **Removed** | The prototype is light-only; no dark palette exists. |
| Admin `#1A2AD4` + purple accent | **Changed** | Admin identity is purple `#8B5CF6`; `#1A2AD4` is a gradient anchor only. |
| "Never introduce a third brand hue" | **Removed** | The six-activity accent system is intentional. |
| Explore = blue, Earn = green | **Refined** | Buy/Hire blue, Errand orange, Sell purple, Professional green, Logistics green/teal. |
| Breakpoints 600 / 1024 | **Changed** | Prototype uses 768 / 1024. |
| `w800` retired from functional UI | **Reversed** | 800 is the prototype's dominant weight (221 uses). |
| Inter "retained as fallback" | **Changed** | Inter is the body family; Plus Jakarta Sans is the display family. Both are loaded. |
| Card padding 12 / 16, `20` retired | **Changed** | Default card padding is 20; range 16–28. |
| Flat **or** raised cards, never both | **Changed** | Cards carry a hairline border **and** the Level-1 shadow. |
| Icon family = Material icons | **Changed** | `lucide-react` only. |
| Typography delivered from bundled `assets/fonts` | **Changed** | `fonts.css` loads Plus Jakarta Sans and Inter. |
| Six activities as `buy / hire / discover / sell / offer / logistics` | **Changed** | The prototype's Explore set is buy / hire / **errand**. `discover` is the browse step inside Hire, not an activity (settled 3 November 2026). |
| Status language registry, density contracts, overlay rules, card hierarchy | **Retained** | Sound guidance, restated against the prototype's primitives. |
| "Do not look static", section rhythm, whitespace, decoration budget, anti-patterns, change process, quality checklist | **Retained** | Still correct and still binding. |
| Accessibility floors and reduced-motion requirements | **Retained and strengthened** | Now measured against the prototype's actual pairs (§24). |

---

*This document describes and protects the prototype. It does not redesign it. Where it and the
prototype disagree, the prototype wins — report the defect, do not restyle the product.*
