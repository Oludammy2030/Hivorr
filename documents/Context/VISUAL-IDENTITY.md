# Hivorr — Visual Identity, Design System & Beautification Rules

**Status:** Active — binding across the entire project (EP-01 → EP-08).
**Owner:** Design System (EP-01-16) is the first implementer; every later UI task and agent MUST conform.
**Authority:** This document is the canonical specification for Hivorr's visual identity, UI design language, layout principles and beautification standards. The runtime values in `lib/app/theme/app_colors.dart`, `lib/app/theme/app_text_theme.dart` and `lib/app/theme/app_theme.dart` (`AppThemeExtension` + `RoleThemeExtension`) MUST equal the hex/weights/durations defined here. If code and this document disagree, this document wins and the code is fixed. Do not create a duplicate visual document.

> How to use this document: when a developer or AI agent creates a completely new Hivorr page, follow this file top to bottom — §1 purpose → §13 composition → §14 hierarchy → §15 surfaces → §22 workflow → §31 checklist. No separate "make it beautiful" instruction is needed. The system itself teaches how to make Hivorr beautiful.

---

## 1. Purpose & Design Philosophy

Hivorr is a modern professional-services ecosystem built on trust and financial integrity. The visual identity must communicate **trust, professionalism, quality, modern technology, simplicity, convenience, confidence, accessibility, African-market relevance, and premium digital-product quality** across every surface — mobile, web, and desktop.

The interface must feel **intentionally designed rather than assembled from unrelated components**. Every page has:

```text
Purpose + Visual hierarchy + Structured content
+ Meaningful whitespace + Clear actions + Consistent visual language
```

§2–§12 govern *what* the tokens are; §13–§25 govern *how they are composed* into polished pages and are binding alongside the tokens.

---

## 2. Core Hivorr Colors

Single unified ecosystem. These are the only hues permitted.

| Token | Hex | Used for |
|---|---|---|
| Primary brand | `#2D3FE7` | Brand signature, Client primary, key CTAs, active states, links, focus rings, primary navigation |
| Light brand / primaryContainer | `#EEF0FD` | Low-emphasis primary fills (selected chips, banners, role tint backgrounds) |
| Brand deep (gradient start / admin primary) | `#1A2AD4` | Gradient start, Admin primary, text on `primaryContainer` |
| Brand bright (gradient end) | `#4F5FEF` | Gradient end only — never as flat text/background |
| Orange | `#F97316` | Warning surfaces/controls |
| Light orange / warningContainer | `#FFF7ED` | Warning banners |
| Cyan | `#0891B2` | Information surfaces/controls |
| Light cyan / infoContainer | `#E0F2FE` | Info banners |
| Red | `#EF4444` | Error / destructive surfaces/controls |
| Light red / errorContainer | `#FEF2F2` | Error banners/snackbars |
| Purple (Both / secondary) | `#8B5CF6` | Both-account identity, combined controls, mode indicators, secondary brand surfaces |
| Light purple / secondaryContainer | `#F3F0FF` | Low-emphasis purple fills |
| Background | `#F0F2F8` | App background (light) |
| Surface | `#FFFFFF` | Cards, sheets, dialogs (light) |
| Primary text | `#0F1626` | Primary text on light surfaces/background |
| Secondary text | `#6B7280` | Secondary text, icons, hints (light) |
| Muted text | `#9CA3AF` | Captions, placeholders, disabled hints (light) |

**Brand gradient (constrained use only):**

```text
#1A2AD4 → #2D3FE7 → #4F5FEF
```

Use only for hero accents, Both/admin identity moments, and primary CTA fills where the gradient measurably improves hierarchy. Never as random decoration (§23). Never place small body text directly on the gradient without verified contrast.

**Usage rules**

- Primary (`#2D3FE7`) is used for: app bars, key CTAs, active states, links, focus rings, primary navigation, hiring actions, job-management emphasis, Client dashboard accents.
- Purple (`#8B5CF6`) is used for: unified Both identity, combined controls, secondary brand surfaces. Never as full-screen background.
- Never introduce a third brand hue outside this section.
- Widgets MUST use `Theme.of(context).colorScheme.*` / `AppThemeExtension` / `RoleThemeExtension` — never hardcode `Colors.*` or raw hex.

---

## 3. Role-Based Color System (accent-only)

Hivorr remains **one unified visual ecosystem**. Operating contexts use different **accent colors** — not different themes. There is no per-role `ThemeData`. Roles resolve through `RoleThemeExtension` (accent-only) on top of the single `ColorScheme`.

| Context | Primary | Light | Use for |
|---|---|---|---|
| Client | `#2D3FE7` | `#EEF0FD` | Client navigation, primary/hiring actions, job-management emphasis, Client dashboard accents |
| Professional | `#16A34A` | `#DCFCE7` | Professional navigation, job discovery, application actions, professional work, earnings, Professional dashboard accents |
| Both | `#8B5CF6` | `#F3F0FF` | Unified Both identity, combined controls, mode indicators, Both navigation, combined hiring/professional sections |
| Admin | `#1A2AD4` + accent `#8B5CF6` | — | Distinct operational environment while recognizably Hivorr (sidebar, operational panels, management controls) |

Rules:

- Role color affects **navigation, primary actions in that context, and dashboard accents** — never body text, never full-bleed backgrounds.
- A "Both" user sees the purple identity in mode indicators and combined sections; drilling into a Client-only or Professional-only flow uses that flow's accent for its primary action.
- `DashboardCapability` (hire/offer/both) drives visibility; `RoleThemeExtension` drives color. Never hardcode role hex at call sites — read `context.roleTheme.clientPrimary`, `.professionalPrimary`, `.bothPrimary`, `.adminPrimary`.
- Status is never communicated through color alone (see §25).

---

## 4. Semantic Colors

Semantic colors retain their meaning across the entire platform, in every role context.

| Role | Base | Container | On-container |
|---|---|---|---|
| Success | `#16A34A` | `#DCFCE7` | `#14532D` |
| Warning | `#F97316` | `#FFF7ED` | `#78350F` |
| Information | `#0891B2` | `#E0F2FE` | `#0C4A6E` |
| Error / destructive | `#EF4444` | `#FEF2F2` | `#7F1D1D` |

Notes:

- Professional green (`#16A34A`) doubles as the Professional role accent (§3) and the success token. In a Professional context, pair it with explicit labels/icons so "role" and "status" are never ambiguous.
- `onSuccess #FFFFFF`, `onWarning #1F2937`, `onInfo #FFFFFF`, `onError #FFFFFF` for text/icons on the base fills.
- Dark-theme semantic values live in `AppThemeExtension.dark` (see §5.2) and MUST be used via the extension — never derived inline.

---

## 5. Color Tokens (ColorScheme)

All tokens are exposed through `ColorScheme` (light/dark) in `lib/app/theme/app_colors.dart`. Semantic success/warning/info live in `AppThemeExtension` (no `ColorScheme` slot). Role accents live in `RoleThemeExtension`.

### 5.1 Light theme

| Token | Hex | Used for |
|---|---|---|
| `primary` | `#2D3FE7` | Primary brand surfaces/controls |
| `onPrimary` | `#FFFFFF` | Text/icon on primary |
| `primaryContainer` | `#EEF0FD` | Low-emphasis primary fills |
| `onPrimaryContainer` | `#1A2AD4` | Text/icon on primaryContainer |
| `secondary` | `#8B5CF6` | Both/unified accent surfaces |
| `onSecondary` | `#FFFFFF` | Text/icon on secondary |
| `secondaryContainer` | `#F3F0FF` | Low-emphasis accent fills |
| `onSecondaryContainer` | `#5B21B6` | Text/icon on secondaryContainer |
| `surface` | `#FFFFFF` | Cards, sheets, dialogs |
| `onSurface` | `#0F1626` | Primary text on surface |
| `surfaceContainerHighest` | `#E6EAF3` | Disabled fills, dividers, track |
| `onSurfaceVariant` | `#6B7280` | Secondary text, icons, hints |
| `outline` | `#D8DFEA` | Borders, dividers |
| `background` | `#F0F2F8` | App background |
| `onBackground` | `#0F1626` | Text on background |
| `error` | `#EF4444` | Error controls |
| `onError` | `#FFFFFF` | Text/icon on error |
| `errorContainer` | `#FEF2F2` | Error banners/snackbars |
| `onErrorContainer` | `#7F1D1D` | Text on errorContainer |

Muted text `#9CA3AF` is used for captions/placeholders via `TextStyle.color` from the extension — never as a surface fill.

### 5.2 Dark theme

Derived for contrast on dark surfaces (AA). Light hexes MUST NOT be reused on dark backgrounds.

| Token | Hex |
|---|---|
| `primary` | `#8B9DFF` |
| `onPrimary` | `#0F173D` |
| `primaryContainer` | `#1A2AD4` |
| `onPrimaryContainer` | `#E0E4FF` |
| `secondary` | `#B7A6FF` |
| `onSecondary` | `#2A1650` |
| `secondaryContainer` | `#4C2FB3` |
| `onSecondaryContainer` | `#EDE9FE` |
| `surface` | `#131A2E` |
| `onSurface` | `#E8EBF3` |
| `surfaceContainerHighest` | `#232C47` |
| `onSurfaceVariant` | `#A7B0C2` |
| `outline` | `#334155` |
| `background` | `#0F1626` |
| `onBackground` | `#E8EBF3` |
| `error` | `#F87171` |
| `onError` | `#7F1D1D` |
| `errorContainer` | `#450A0A` |
| `onErrorContainer` | `#FCA5A5` |
| `success` (ext) | `#22C55E` |
| `onSuccess` (ext) | `#052E16` |
| `successContainer` (ext) | `#14532D` |
| `onSuccessContainer` (ext) | `#BBF7D0` |
| `warning` (ext) | `#FBBF24` |
| `onWarning` (ext) | `#3A2A06` |
| `warningContainer` (ext) | `#5C3B00` |
| `onWarningContainer` (ext) | `#FDE68A` |
| `info` (ext) | `#38BDF8` |
| `onInfo` (ext) | `#062A3A` |
| `infoContainer` (ext) | `#0C4A6E` |
| `onInfoContainer` (ext) | `#BAE6FD` |

---

## 6. Typography

| Property | Value |
|---|---|
| Family | **Plus Jakarta Sans** (OFL), bundled offline (`assets/fonts/PlusJakartaSans-Variable.ttf`, weights 400/500/600/700). Inter retained as fallback during migration. |
| Delivery | No runtime fetch. Registered in `pubspec.yaml`; applied via `TextTheme` in `lib/app/theme/app_text_theme.dart`. Never set `fontFamily` per-widget. |
| Colors | `colorScheme.onSurface` / `onSurfaceVariant` / muted `#9CA3AF` — never hardcoded. |

**Hivorr type roles → TextTheme mapping (hierarchy, not decoration):**

| Hivorr role | TextTheme | Weight | Use |
|---|---|---|---|
| Display / hero heading | `displaySmall` (36) / `displayMedium` (45) | 700 | Landing heroes, major public headers only |
| Page heading | `headlineMedium` (28) / `headlineSmall` (24) | 600 | Dashboard / detail page titles, auth titles |
| Section heading | `titleLarge` (22) | 600 | `HivorrSectionHeader`, content sections |
| Card heading | `titleMedium` (16) / `titleSmall` (14) | 500 | `HivorrCard` titles, list-tile titles |
| Body text | `bodyLarge` (16) / `bodyMedium` (14) | 400 | Paragraphs, descriptions |
| Supporting text | `bodySmall` (12) | 400 | Hints, secondary explanations |
| Metadata / labels | `labelLarge` (14) / `labelMedium` (12) | 500 | Buttons, chips, badges, form labels |
| Captions | `labelSmall` (11) | 500 | Timestamps, counts, muted `#9CA3AF` |

Avoid excessive size variation. One hero size per page; section headings share one style; card headings share one style. Line-heights and letter-spacing come from the theme — never ad-hoc.

### 6a. Font-Weight Usage Rules

Weights are hierarchy tools with exactly four jobs: (1) page/section/card titles, (2) key numeric values, (3) the primary action label in a group, (4) status words inside badges. Weight by role (binding):

| Role | Style | Weight |
|---|---|---|
| Page title | `headlineSmall` (24) | 700 |
| Section title | `titleMedium` (16) | 600–700 |
| Card title | `titleSmall` (14) | 600 |
| Stat/metric value | `titleLarge` (22) / `headlineSmall` (24) | 700 |
| Button/pill/tab labels | `labelLarge`/`labelMedium` | 500–700 |
| Body | `bodyLarge`/`bodyMedium`/`bodySmall` | 400 |
| Metadata/captions | `labelSmall` | 500 |

Rules:

- `FontWeight.w800` is retired from functional UI. It may appear only in landing/marketing display text, explicitly documented at the call site.
- Never set `fontSize` per-widget; map to the nearest §6 scale step (11→`labelSmall` 11, 11.5/12→`bodySmall` 12, 12.5/13/13.5→`bodyMedium` 14, 15→`titleSmall` 14 semibold or `titleMedium` 16, 18→`titleMedium` 16, 20→`titleLarge` 22).
- If more than ~15% of visible words on a screen are semibold-or-up, the screen fails review — weight escalation flattens hierarchy.

---

## 7. Spacing System

Token source: `HivorrSpacing` (`lib/shared/helpers/hivorr_spacing.dart`, 8pt base from `AppThemeExtension.spacing`).

| Token | Value | Use |
|---|---|---|
| `xs` | 4dp | Tight gaps (icon-to-text) |
| `sm` | 8dp | Standard element gaps |
| `smMd` | 12dp | Compact component interiors (compact card padding, pill verticals, tile gaps) |
| `md` | 16dp | Card padding, section padding, mobile screen padding |
| `lg` | 24dp | Web content-pane padding, major gaps |
| `xl` | 32dp | Major section separation |
| `xxl` | 48dp | Page-level vertical spacing |

Rules:

- Never ad-hoc `EdgeInsets`. Related elements sit closer; unrelated elements get more separation.
- Screen padding: 16dp mobile / 24dp web content panes; section gaps follow the scale.
- Content width: focused content (forms, fields, auth) lives in a centered pane (`HivorrContentPane`, max ≈ 720dp) with symmetric gutters — never full-bleed just because the parent is wide. Genuinely full-width surfaces (dashboards, data views) remain allowed.
- Related: headings → paragraphs → controls tighten; cards → headings → sections loosen.

### 7a. Interior-Spacing Rules

- Micro-gaps ≤4dp inside text stacks (title→subtitle) may stay literal.
- Everything ≥6dp MUST be a token. Raw `6/10/12/14/20/22/28` literals fail review.
- Card padding per tier: 16 standard / 12 compact (`smMd`) / 24 hero-or-sparse / 32 landing hero. `20` is retired.
- In-card rhythm: title → content `sm`–`md`; list items `sm` or hairline dividers.

---

## 8. Border Radius

Token source: `AppThemeExtension` (`radiusSm/Md/Lg`). One radius language across cards, buttons, inputs, modals.

| Token | Value | Use |
|---|---|---|
| `radiusSm` | 8dp | Buttons, text fields, badges, small chips |
| `radiusXs` | 12dp | Icon tiles, inner elements, compact pills |
| `radiusMd` | 16dp | Cards, standard surfaces, dialogs |
| `radiusLg` | 24dp | Modal bottom-sheet top corners |
| Pill | Full (`StadiumBorder` / `999`) | Filter chips, status pills, `_PageIndicator` dots |

Do not use extreme rounding everywhere. Do not mix unrelated radius styles without purpose. Sheets use `radiusLg` top corners with a drag handle (`HivorrBottomSheet`).

### 8a. Radius Policy

- Selectable chips (`HivorrChip`) are true pills (`StadiumBorder` / `999`), not fixed-corner rounding.
- Raw `10/14/20` radii collapse to the nearest token (10→8, 14→12/16, 20→16).

---

## 9. Shadows & Elevation

Elevation is token-driven and **soft/subtle** — cards lift gently; no hard drop shadows, no heavy contrast.

| Level | Treatment | Use |
|---|---|---|
| 0 (flat) | No shadow + `outline` hairline border | Static containment, lists, stacked cards |
| 1 (raised) | `0 2px 12px rgba(15,22,38,0.07)` | Interactive cards (`HivorrCard elevation>0`), hover lift on web |
| 2 (overlay) | Soft overlay shadow (dialog/sheet) | `HivorrDialog`, `HivorrBottomSheet` |
| 3 (floating) | Snackbar / FAB lift | `HivorrSnackbar`, FABs |

Prefer elevation for interactive/modal surfaces; prefer borders for static containment. Never heavily shadow every card. Some cards use no shadow + subtle border depending on importance.

---

## 10. Borders

Borders are subtle and purposeful (`colorScheme.outline`).

Use borders to: separate content, define input boundaries, organize tables, distinguish flat panels, establish structure. Do not outline every element unnecessarily. Flat cards (`elevation == 0`) carry the hairline; raised cards drop the border and use the Level-1 shadow instead — never both.

---

## 11. Iconography

One consistent icon family (Material icons). Icons must communicate meaning, support scanning, share sizing, and align correctly with text. Icon color comes from `onSurfaceVariant` / role accent — never random hues. Do not use icons purely as decoration. Where status is shown, pair the icon with a text label (never color alone).

---

## 12. Imagery & Visual Content

Use imagery intentionally where it contributes to trust, storytelling, service discovery, professional identity, marketplace understanding, or visual interest. Hero supporting visuals, service/category previews, professional portfolio photos, and contextual UI previews are appropriate. Never add random stock imagery to fill space. No image/video hero is currently canonical — when introduced, it must use brand-consistent art with clear space and contrast, and must degrade gracefully offline.

---

## 13. Page Composition

Every major page has intentional composition with a clear beginning, middle and end. Before implementing, establish:

- What is the primary purpose? Most important information? Primary action?
- What should users notice next? What belongs together vs. visually separated?
- Where do whitespace, cards, panels belong? What happens visually on scroll?

Hierarchy flows:

```text
Page purpose → Primary action → Primary information
→ Supporting information → Secondary actions → Additional information
```

Establish hierarchy with typography, size, weight, spacing, color, positioning, cards, imagery, and icons. Do not make every element visually loud.

### 13a. Shell & Chrome Rules

- The shell owns the page title. Screens mounted inside a shell MUST NOT render a duplicate in-body H1; the in-body header (title + subtitle + gap) is deleted where the shell already titles the page.
- Navigation chrome comes from shared shell components only — no per-screen top bars, sidebars, or nav rows.
- Chrome controls (menu, bell, close, back) expose a ≥48dp hit area (`IconButton` constraints), even where the visible tile is 40–44dp.
- Sidebar metrics: fixed width per shell (248 admin / 264 dashboard / 280 shared rail), nav items ≥44dp, section labels `labelSmall`.

---

## 14. The "Do Not Look Static" Rule

Pages must not feel like plain documents in a browser. Avoid structures whose primary visual is only heading → paragraph → button → paragraph → button → empty space.

When information can be meaningfully grouped, organize it into: cards, panels, feature blocks, content sections, grids, lists, statistic blocks, action panels, category tiles, information surfaces, highlighted areas, visual dividers, contextual sections.

Purpose is visual structure and hierarchy — not decoration.

---

## 15. Card Usage

Use cards when they improve grouping, readability, hierarchy, scanning, comparison, discoverability, or interaction. Appropriate: job, professional, service, category, dashboard metric, application, quotation, payment, activity, feature, testimonial, notification, and action cards (all built on `HivorrCard`).

Do not turn everything into a card. Avoid card-inside-card-inside-card and excessive borders/shadows. Use tables, lists, `HivorrSectionHeader` + dividers, timelines, and panels where they communicate better. Flat (bordered) vs. raised (shadowed) follows §9.

### 15a. Card Sizing Principles

- Functional card padding: 16 standard / 12 compact. 24 only for hero panels or genuinely sparse content; 32 for landing heroes only.
- Flat (bordered) for static containment; raised (Level-1 shadow) for interactive cards — never both (§9–§10).
- Card-in-card nesting is banned; use dividers, sections, or list rows inside one card.
- Fixed-height content blocks are banned, except media/document viewers, which carry a documented exception plus a collapsed mobile variant.
- Card height is content-driven; long text is clamped with `maxLines`, never accommodated with fixed extents.

---

## 16. Hero Sections

Major landing and important public pages may use a strong hero containing: clear headline (`displaySmall`), supporting message (`bodyLarge`), primary CTA, secondary CTA where appropriate, and a supporting visual/content element.

Do not create enormous empty heroes for spaciousness. Use space purposefully with subtle background shapes, cards, floating info panels, service/category previews, statistics, illustrations, or contextual UI previews. The hero must communicate page value within seconds.

---

## 17. Homepage Design Principle

The homepage is the entrance to a modern professional-services ecosystem — never a static information page. Compose from purposeful sections such as: hero, service discovery, popular categories, professional/service previews, marketplace activity, trust indicators, platform benefits, how Hivorr works, featured opportunities, calls to action, supporting information, footer.

Each section has a clear purpose tied to product requirements. Never add sections to inflate length.

---

## 18. Section Rhythm

Long pages need visual rhythm — never identical stacked sections. Vary coherently, e.g.:

```text
Hero → Card Grid → Split Content → Feature Panel
→ Statistics → Marketplace Cards → CTA
```

Variation stays coherent; never random layouts for variety's sake. Alternate background (background vs. surface), density, and structure (`PublicSection` eyebrow/title/body + children) while keeping spacing tokens constant.

---

## 19. Whitespace

Whitespace separates sections, groups related content, improves readability, emphasizes important elements, and prevents clutter. Be generous — one primary action per view; content breathes. But avoid accidental empty areas that feel unfinished. Whitespace is intentional, not leftover.

---

## 20. Content Density

Different surfaces need different density. Never apply one density everywhere.

- **Marketing / public:** more whitespace, stronger storytelling, larger headings, stronger imagery, larger cards, fewer dense tables.
- **Dashboards:** higher density — compact cards, summaries, tables, lists, quick actions (`Wrap`), activity panels.
- **Admin:** highest density — structured tables, filters, metrics, operational panels, charts, management controls (`SuperAdminShell` + sidebar).

### 20a. Per-Tier Density Contracts

"Highest density" is specified, not aspirational:

| Concern | Marketing / public | Dashboards | Admin |
|---|---|---|---|
| Card padding | 16–32 | 16 standard / 12 compact | 16 standard / 12 compact |
| Section gaps | 24–32 | 16 standard / 24 major | 16 standard / 24 major |
| Screen gutters | 24 | 16 mobile / 24 web | 16 mobile / 24 web |
| Stat icon tiles | 40–52 | 40 | 40 |
| Table/list rows | — | 44–52 standard | 40 dense tables / 44–52 lists |
| Content columns (≥1024) | 2–3 | 3 | 3 |
| Headings | display + 22–28 | 24 page / 16 section | 24 page / 16 section |

---

## 21. Component Consistency

Once established, reuse the visual language. Future job cards, professional cards, metric cards, CTAs, buttons, inputs, modals, and navigation items MUST reuse or extend the existing pattern instead of inventing visually unrelated versions. Hivorr grows through a system, not isolated page designs.

Canonical catalog (all token-built, in `lib/shared/` unless noted):

Buttons (`HivorrButton` primary/secondary/outline/text, s/m/l, ≥48dp) · Text fields (`HivorrTextField`, calm filled/outlined, focus ring = primary) · Cards (`HivorrCard`) · Chips (`HivorrChip` primary/secondary/surface) · Badges (`HivorrBadge` success/error/warning/info + domain badges: KYC, trade-verified, escrow, hiring, listing) · Avatar · Divider · Section header · List tile (48dp min) · Dialog / Bottom sheet · Empty / Loading / Error / Success states + `HivorrLoader` (breathing pulse, 1800ms — never a bare spinner or dead-end) · Snackbar (4s) · Hero panel (`HivorrHeroPanel`, gradient + white actions + `HivorrHeroStat`) · Stat band (`HivorrStatBand`/`HivorrStatItem`) · Feature card (`HivorrFeatureCard`, tinted icon tile, role-tintable) · CTA band (`HivorrCtaBand`) · FAQ item (`HivorrFaqItem`) · Pricing tier (`HivorrPricingTier`, honest copy only) · Step card (`HivorrStepCard`) · Data table (`HivorrDataTable` + cells, wide admin views) · Mini bars (`HivorrMiniBars`, real numbers only, no chart dependency) · Layouts (`HivorrScreenScaffold`, `HivorrResponsiveScaffold`, `HivorrContentPane`, `Breakpoints` 600/1024) · Helpers (`HivorrSpacing`, formatters, validators, `BuildContext` extensions).

### 21a. Grid & Breakpoint Policy

- Breakpoints are 600/1024 (`Breakpoints`), plus a 720 rule for table→card flips. Thresholds of 700/900/1000/1100 are retired.
- Columns follow available width + content importance:

| Content | <600 | 600–1023 | ≥1024 |
|---|---|---|---|
| Stat/metric cards | 2 | 2–3 | 3–4 |
| Content cards (jobs, listings) | 1 | 2 | 3 |
| Media tiles | 2 | 3 | 3 |
| Operational tables | cards | table | table |

- Column widths are computed by shared grid helpers (the portfolio grid is the reference implementation). Fixed `mainAxisExtent` cards are banned.
- Content-driven exception: wide action tables (6+ columns with dual row actions, e.g. Admin Users) flip table→cards at 900dp instead of 720dp — the actions column needs ~160dp and narrower viewports overflow. Document the exception at the call site.
- Tablet (600–1023) is a distinct designed layout, never a stretched phone layout (§24a).

### 21b. Status Language Registry

- One status vocabulary per domain (KYC, trade-verified, escrow, hiring, listing), each an extension of `HivorrBadge` — never a local pill reimplementation.
- Within a domain, status is exactly one construct (pill XOR dot+label XOR chip), always paired with a text label — never color alone (§25).

### 21c. Table Standard

- Operational lists use `HivorrDataTable`. Hand-rolled flex tables are banned.
- Row heights: 40 dense tables / 44–52 standard rows. The 48dp floor (§25) applies to touch rows (list tiles), not to data rows.
- Header `labelSmall` uppercase; cell padding horizontal 16, vertical 8.
- Dense-table row actions (`HivorrTableAction`, compact pill ≈34dp) are permitted inside ≥720dp admin tables, where 48dp buttons would force ≥64dp rows. Narrow-card (touch) layouts, form CTAs, dialog actions, and standalone buttons always stay ≥48dp (`HivorrButton`).
- Compact card actions in dense dashboard grids (job/hire cards at 2–3 columns) also use `HivorrTableAction`: full 48dp buttons would dominate these cards and break the reference action clusters. The exception covers tables and dense card grids only.

---

## 22. New Page Beautification Rule

Whenever a new page or feature is created:

1. Identify the page purpose (§13).
2. Identify the appropriate existing components/patterns (§21).
3. Reuse those patterns — check utilities before creating components.
4. Determine whether the page needs cards, panels, grids, lists, statistics, feature sections, imagery, CTAs, tabs, filters, or supporting visuals (§14–§15).
5. Compose with established spacing, typography, color, radius, shadow and component rules (§5–§12), applying the correct role accent (§3) and density tier (§20).
6. Check against the visual system — the result looks like a new page within Hivorr, not a new design by a different designer.

---

## 23. No Generic Template / No Decoration Without Purpose

Do not ship generic Header + Three Cards + Table layouts for every page. Choose layout by page purpose — Hivorr has its own recognizable character.

Do not add random gradients, excessive animations, unnecessary shadows, excessive rounding, random illustrations, excessive icons, decorative cards, or unnecessary badges. Every visual element must contribute to hierarchy, usability, comprehension, navigation, trust, branding, or interaction.

Motion: token durations 150–300ms, standard easing, fade + slide; animate only to communicate (press, list feedback, state change). Loader is the breathing `HivorrLoader`, not a spin.

---

## 24. Responsive Beautification

Beautification works across desktop, laptop, tablet, and mobile. Never merely shrink desktop.

Cards reorganize (`Wrap` / `LayoutBuilder` 1→2→3 cols); sections stack intelligently; navigation adapts (sidebar/rail ≥600dp, bottom nav + drawer on mobile); typography scales; spacing stays intentional. Mobile is a deliberately designed Hivorr experience — forms use available width with screen padding, never a cramped column. Tablet (600–1023) and desktop (≥1024) are distinct (`Breakpoints`), not one "wide" layout.

### 24a. Tablet Rules

- 600–1023dp is a first-class layout: 2-column content grids, rail/sidebar navigation, 16dp gutters, full-width forms in panes.
- Verify every migrated screen at 320 / 360 / 600 / 1024 / 1920dp in light AND dark before sign-off.

---

## 25. Accessibility (premium = universally usable)

Beauty never costs usability. WCAG AA contrast floor **plus**: comfortable targets (≥48dp), readable line-heights, visible focus in light and dark, touch-friendly controls, meaningful labels, icons supported by text where necessary, status never through color alone.

### 25a. Readability Floors (binding minima)

- Body text ≥12 (11 for captions only). Buttons/inputs ≥48dp total height.
- Table data-rows ≥40dp; pills/badges use `HivorrBadge` metrics or larger.
- 1.3× text-scale must produce no overflow on any functional screen.
- Any proposal below these floors fails review on accessibility grounds — density never comes from sub-floor targets.

---

## 26. Logo

| Asset | File | Description |
|---|---|---|
| Mark | `assets/images/logo.svg` | Hub-and-spoke network (silver nodes) on a brand `#2D3FE7` rounded tile |
| Wordmark | `assets/images/logo_wordmark.svg` | Brand-tile mark + "Hivorr" in Plus Jakarta Sans (`#2D3FE7` text, for light surfaces) |
| App Icon / Favicon | `assets/images/logo_icon.svg` | Mark-only (1:1) on brand `#2D3FE7` tile — source for launcher icons, favicons, badges |
| Horizontal lockup | `assets/images/logo_horizontal.svg` | Transparent (no tile); silver emblem + `#2D3FE7` wordmark for light surfaces — use monochrome on dark |
| Stacked lockup | `assets/images/logo_stacked.svg` | Brand-tile emblem above `#2D3FE7` wordmark (256:300) for login/splash/empty states |
| Monochrome lockup | `assets/images/logo_monochrome.svg` | Single-color, tintable (defaults white) for dark headers/footers |
| Loader (monochrome) | `lib/app/widgets/hivorr_loader.dart` + `assets/images/hivorr_loader.svg` | Monochrome node-network (`currentColor`); `HivorrLoader` staggered breathing pulse (no 360° spin) |

Widgets in `lib/app/widgets/logo_variants.dart` (`LogoIcon`, `LogoHorizontal`, `LogoStacked`, `LogoMonochrome`) via `flutter_svg`. Raster launcher icons generated by `flutter_launcher_icons` (config in `pubspec.yaml`).

Clear space ≥ 25% of mark height; minimum 24dp mark / 14sp wordmark. On colored backgrounds use the `onPrimary`/white or monochrome variant. Never recolor to arbitrary hues. After any palette change, re-verify logo contrast on `#2D3FE7`, `#F0F2F8`, and dark `#0F1626`.

---

## 27. Anti-Patterns (forbidden)

- Hardcoding `Colors.*` or raw hex in widgets instead of `Theme`/`AppThemeExtension`/`RoleThemeExtension`.
- Setting `fontFamily` per-widget instead of `TextTheme`.
- Introducing a hue outside §2.
- Using accent/gradient as full-bleed background or small text without contrast.
- Fetching fonts from network at runtime.
- Card-inside-card-inside-card; every card heavily shadowed; outlining every element.
- Non-token spacing, radius, elevation/shadow, or motion.
- Bare spinners / dead-end empty states (always branded state widgets with guidance + next action).
- Static heading-paragraph-button pages where grouping (§14–§15) applies.
- Generic Header + Three Cards + Table on every page; decoration without purpose.

### 27a. AI Implementation Rules

- Reuse-before-creation: before building any visual element, search `lib/shared/`. If a canonical exists, reuse or extend it. A new private visual duplicate of an existing canonical fails Definition of Done.
- Spacing ≥6dp MUST be a token; `fontSize`/`fontFamily` per-widget is banned; `Colors.*`/raw hex at call sites is banned; `w800` in functional UI is banned; non-600/1024/720 breakpoints are banned.
- Token changes follow §29: document first, then `lib/app/theme/*`, then tests.

---

## 28. Enforcement

- `documents/Context/AGENT.md` Rule: *"All UI MUST use `AppTheme` tokens defined in `VISUAL-IDENTITY.md`; never hardcode colors or fonts."*
- Tests assert `ColorScheme.primary == #2D3FE7`, `background == #F0F2F8`, `TextTheme.bodyMedium.fontFamily == 'Plus Jakarta Sans'`, and `RoleThemeExtension` role hexes.
- Any UI task (EP-02+) that hardcodes a color/font fails its Definition of Done.
- Any UI task (EP-02+) that uses **non-token** spacing, radius, elevation/shadow, or motion — or ships an unmindful/off-brand empty, loading, error, or success state — fails its Definition of Done under §21 (the finish & experience standard).
- Quality gate: §31 checklist must pass before a page is considered complete.

---

## 29. Change Process

To change a brand/role color, font, radius, shadow, motion, or the logo: update this document FIRST, then update `lib/app/theme/*` and assets to match, then bump test expectations. Never edit code tokens without updating this source of truth.

---

## 30. Design System Evolution

When a new component introduces a genuinely reusable pattern: decide whether it becomes shared (add to `lib/shared/` + barrel export), document the visual rule here if reusable, and reuse it in future features. The system grows richer without growing inconsistent.

---

## 31. Visual Quality Check + The Permanent Rule

Before considering any page complete, verify:

- Does the page have a clear purpose? Is the primary action obvious? Is hierarchy clear?
- Is the page visually structured (not static)? Is whitespace intentional?
- Are cards used where they genuinely improve the experience — and other layouts where cards would be inappropriate?
- Does the page feel visually complete, professional, and recognizably Hivorr?
- Does it use the correct role color? Are existing components reused?
- Is it responsive (desktop/tablet/mobile deliberate)? Consistent with established components?
- Does it avoid generic-template looks and unnecessary decoration?
- Contrast, focus, targets, and labels (§25) — in light AND dark?

**The permanent Hivorr visual rule:** every new page inherits the established visual language rather than inventing its own. A new page feels like *"another beautifully designed Hivorr page"* — never *"a new page that happens to be inside Hivorr."* Prioritize consistency + hierarchy + purposeful composition + beautiful spacing + reusable components + role-aware color + meaningful surfaces + responsive design + professional polish.

### 31a. Density Checklist (extends §31)

- Card padding is 12 or 16 (24+ only with a documented hero/sparse reason)?
- Section gaps 16 (24 major, 32 marketing-only)? No duplicate titles in shells?
- Columns reach the §21a counts at width? No fixed-height content blocks?
- Touch targets ≥48? Data-rows ≥40? No w800, no `fontSize:` literals, no raw hex?
- Verified at 320/600/1024/1920 in light AND dark?
