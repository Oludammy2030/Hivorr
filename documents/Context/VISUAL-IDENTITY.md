# Hivorr — Visual Identity (Project Source of Truth)

**Status:** Active — binding across the entire project (EP-01 → EP-08).
**Owner:** Design System (EP-01-16) is the first implementer; every later UI task and agent MUST conform.
**Authority:** This document is the canonical specification for Hivorr's visual identity. The runtime values in `lib/app/theme/app_colors.dart` and `lib/app/theme/app_text_theme.dart` MUST equal the hex/weights defined here. If code and this document disagree, this document wins and the code is fixed.

---

## 1. Purpose

Hivorr is an "operating system for modern human existence" built on trust and financial integrity. The visual identity must communicate **trust, stability, and financial growth** across every surface — mobile, web, and desktop — and remain consistent from the first splash screen through all eight engineering phases.

This document defines:
- The project color (signature brand color) and accent
- The full light + dark color token set
- The typography system
- The logo (mark + wordmark)

It does **not** define component-level UI (buttons, cards, etc.) — that lives in the EP-01-16 Design System implementation, which consumes these tokens.

§9 defines the **premium visual finish & experience bar** — how these tokens are combined to feel *intelligent, professional, modern, and human-centered*. §2–§5 govern *what* the tokens are; §9 governs *how they look and feel* and is binding alongside the rest of this document.

---

## 2. Brand Color

| Role | Name | Hex | Rationale |
|---|---|---|---|
| **Project color (signature / primary)** | Cerulean | `#0B6E99` | Calm, confident blue — conveys trust, stability, and reliability (core to a finance/trust platform). |
| **Accent (secondary)** | Emerald | `#10B981` | Growth green — signals financial progress, prosperity, and positive outcomes (success, money, CTAs). |

These two hues are the only brand colors. All other colors in §3 are neutral or semantic support derived to work with them.

**Usage rules**
- Primary (`#0B6E99`) is used for: app bars, key CTAs, active states, links, focus rings, primary navigation.
- Accent (`#10B981`) is used for: success states, positive financial signals (balances, earnings), secondary CTAs, verification/badge accents.
- Never use the accent as a full-screen background. Never place text directly on the accent at small sizes without sufficient contrast.

---

## 3. Color Tokens

All tokens are exposed through `ColorScheme` (light/dark) in `lib/app/theme/app_colors.dart`. Widgets MUST use `Theme.of(context).colorScheme.*` / `AppThemeExtension` — never hardcode `Colors.*` or raw hex.

### 3.1 Light theme

| Token | Hex | Used for |
|---|---|---|
| `primary` | `#0B6E99` | Primary brand surfaces/controls |
| `onPrimary` | `#FFFFFF` | Text/icon on primary |
| `primaryContainer` | `#D3E7F0` | Low-emphasis primary fills (selected chips, banners) |
| `onPrimaryContainer` | `#062E40` | Text/icon on primaryContainer |
| `secondary` | `#10B981` | Accent surfaces/controls |
| `onSecondary` | `#FFFFFF` | Text/icon on secondary |
| `secondaryContainer` | `#A7F3D0` | Low-emphasis accent fills |
| `onSecondaryContainer` | `#053B29` | Text/icon on secondaryContainer |
| `surface` | `#FFFFFF` | Cards, sheets, dialogs |
| `onSurface` | `#0F172A` | Primary text on surface |
| `surfaceContainerHighest` | `#E2E8F0` | Disabled fills, dividers, track |
| `onSurfaceVariant` | `#475569` | Secondary text, icons, hints |
| `outline` | `#CBD5E1` | Borders, dividers |
| `background` | `#F7F9FB` | App background |
| `onBackground` | `#0F172A` | Text on background |
| `error` | `#DC2626` | Error controls |
| `onError` | `#FFFFFF` | Text/icon on error |
| `errorContainer` | `#FEE2E2` | Error banners/snackbars |
| `onErrorContainer` | `#7F1D1D` | Text on errorContainer |
| `success` | `#16A34A` | Positive/financial signals |
| `onSuccess` | `#FFFFFF` | Text/icon on success |
| `successContainer` | `#DCFCE7` | Success banners |
| `onSuccessContainer` | `#14532D` | Text on successContainer |
| `warning` | `#F59E0B` | Caution states |
| `onWarning` | `#1F2937` | Text/icon on warning |
| `warningContainer` | `#FEF3C7` | Warning banners |
| `onWarningContainer` | `#78350F` | Text on warningContainer |
| `info` | `#0EA5E9` | Informational states |
| `onInfo` | `#FFFFFF` | Text/icon on info |
| `infoContainer` | `#E0F2FE` | Info banners |
| `onInfoContainer` | `#0C4A6E` | Text on infoContainer |

### 3.2 Dark theme

| Token | Hex |
|---|---|
| `primary` | `#6CB8D6` |
| `onPrimary` | `#06222E` |
| `primaryContainer` | `#0B4A66` |
| `onPrimaryContainer` | `#CDE8F4` |
| `secondary` | `#34D399` |
| `onSecondary` | `#063322` |
| `secondaryContainer` | `#065F46` |
| `onSecondaryContainer` | `#A7F3D0` |
| `surface` | `#0B1220` |
| `onSurface` | `#E5E7EB` |
| `surfaceContainerHighest` | `#1E293B` |
| `onSurfaceVariant` | `#94A3B8` |
| `outline` | `#334155` |
| `background` | `#0F172A` |
| `onBackground` | `#E5E7EB` |
| `error` | `#F87171` |
| `onError` | `#7F1D1D` |
| `errorContainer` | `#450A0A` |
| `onErrorContainer` | `#FCA5A5` |
| `success` | `#22C55E` |
| `onSuccess` | `#052E16` |
| `successContainer` | `#14532D` |
| `onSuccessContainer` | `#BBF7D0` |
| `warning` | `#FBBF24` |
| `onWarning` | `#3A2A06` |
| `warningContainer` | `#5C3B00` |
| `onWarningContainer` | `#FDE68A` |
| `info` | `#38BDF8` |
| `onInfo` | `#062A3A` |
| `infoContainer` | `#0C4A6E` |
| `onInfoContainer` | `#BAE6FD` |

---

## 4. Typography

| Property | Value |
|---|---|
| Family | **Inter** (OFL license) |
| Delivery | Bundled offline as a single variable `.ttf` (`assets/fonts/Inter-Variable.ttf`) in `assets/fonts/` (no runtime fetch — required for offline-first, unreliable-network targeting). Registered with weight entries `400/500/600/700` so `fontWeight` maps to the `wght` variation. |
| Weights | Regular `400`, Medium `500`, SemiBold `600`, Bold `700` (all from the one variable file) |
| Application | Applied via `TextTheme` in `lib/app/theme/app_text_theme.dart`; every widget inherits it. Never set `fontFamily` per-widget. |

**Role mapping (TextTheme)**
- `displaySmall/Medium/Large` → Bold (700)
- `headline*` → SemiBold (600)
- `titleLarge` → SemiBold (600); `titleMedium/Small` → Medium (500)
- `bodyLarge/Medium/Small` → Regular (400)
- `labelLarge` (buttons) → Medium (500); `labelMedium/Small` → Medium (500)

Text colors come from `colorScheme.onSurface` / `onSurfaceVariant` — never hardcoded.

---

## 5. Logo

| Asset | File | Description |
|---|---|---|
| Mark | `assets/images/logo.svg` | Hub-and-spoke network: a central silver node (the Universal Entity) linked by silver connectors to three silver role-nodes, on a cerulean rounded tile |
| Wordmark | `assets/images/logo_wordmark.svg` | Mark + "Hivorr" wordmark in Inter |
| App Icon / Favicon | `assets/images/logo_icon.svg` | Mark-only: the hub-and-spoke network on a cerulean rounded square (1:1). Use for launcher icons, favicons, tab bar badges |
| Horizontal lockup | `assets/images/logo_horizontal.svg` | Emblem left + "Hivorr" wordmark in Inter, on transparent (3.2:1). Use for app headers / nav bars |
| Stacked lockup | `assets/images/logo_stacked.svg` | Emblem above the "Hivorr" wordmark, on transparent (256:300). Use for login / splash / empty states |
| Monochrome lockup | `assets/images/logo_monochrome.svg` | Single-color wordmark + emblem, no tile, tintable (defaults white). Use on dark headers / footers |
| Loading | `assets/images/logo_loading.svg` | Transparent background, full mark in primary cerulean, SMIL rotate animation — used as the loading / processing indicator |
| Loader (monochrome) | `lib/app/widgets/hivorr_loader.dart` + `assets/images/hivorr_loader.svg` | Monochrome node-network (single color, transparent, nodes filled to match the brand mark). `HivorrLoader` widget does a staggered breathing pulse (no 360° spin); `hivorr_loader.svg` is the standalone CSS-keyframe version for web/HTML |

**Reusable Flutter widgets** (in `lib/app/widgets/logo_variants.dart`, via `flutter_svg`):

| Widget | Variant | Notes |
|---|---|---|
| `LogoIcon` | App Icon | square; pass `size` |
| `LogoHorizontal` | Horizontal lockup | height-first; width derived from 3.2:1 |
| `LogoStacked` | Stacked lockup | height-first; width derived from 256:300 |
| `LogoMonochrome` | Monochrome lockup | height-first; `color` defaults to `Colors.white` (tinted via `ColorFilter`) |

**Generated raster icons** (produced by `flutter_launcher_icons`, re-run after editing the mark):
- Source inputs: `assets/images/logo_icon.png` (transparent) + `assets/images/logo_icon_ios.png` (opaque, cerulean bg, for App Store alpha compliance).
- Outputs: Android `mipmap-*` + adaptive (`ic_launcher_foreground`, adaptive bg `#0B6E99`), iOS `AppIcon.appiconset` (21 sizes), Web `favicon.png` + `web/icons/*` (192/512 + maskable).
- Config lives in `pubspec.yaml` under `flutter_launcher_icons:`.

**Notes**
- The logo is an **on-brand placeholder** generated from the project colors. It is intentionally replaceable: final brand art can drop into the same paths without code changes.
- **Concept:** a hub-and-spoke network — the central silver node is the **Universal Entity** (one identity for every user), the three silver nodes are life roles (professional, commerce, daily living), and the silver links are the compounding network effects across roles. This mirrors the EP-01 vision of an "operating system for modern human existence."
- Rendered in-app via the `flutter_svg` package (AppBar, splash). Web/app launcher icons are generated from the mark.
- **Clear space:** keep padding around the mark ≥ 25% of its height on all sides.
- **Minimum size:** mark ≥ 24dp on screen; wordmark text ≥ 14sp.
- **Color:** use the brand cerulean/emerald from §2. On colored backgrounds, use the `onPrimary`/white variant or a monochrome mark for contrast. Never recolor the mark to arbitrary hues.

---

## 6. Anti-Patterns (forbidden)

- Hardcoding `Colors.*` or raw hex in widgets instead of using `Theme`/`AppThemeExtension`.
- Setting `fontFamily` explicitly on a `TextStyle` instead of relying on `TextTheme`.
- Introducing a third brand hue outside §2.
- Using the accent (`#10B981`) as a full-bleed background.
- Fetching fonts from a network at runtime.

---

## 7. Enforcement

- `documents/Context/AGENT.md` Rule: *"All UI MUST use `AppTheme` tokens defined in `VISUAL-IDENTITY.md`; never hardcode colors or fonts."*
- Tests assert `ColorScheme.primary == #0B6E99` and `TextTheme.bodyMedium.fontFamily == 'Inter'`.
- Any UI task (EP-02+) that hardcodes a color/font fails its Definition of Done.
- Any UI task (EP-02+) that uses **non-token** spacing, border radius, elevation/shadow, or motion — or ships an unmindful/off-brand empty, loading, error, or success state — fails its Definition of Done under §9 (the finish & experience standard).

---

## 8. Change Process

To change a brand color, font, or the logo: update this document FIRST, then update `lib/app/theme/*` and the asset files to match, then bump the relevant test expectations. Never edit code tokens without updating this source of truth.

---

## 9. Visual Finish & Experience Standard

**Status:** Active — binding across the entire project (EP-01 → EP-08). Every UI task and agent MUST conform alongside §2–§7.

### 9.1 Design personality (the bar)

Every Hivorr surface must feel like an **intelligent professional ecosystem**: premium, modern, and human-centered. That means calm confidence, trust and financial integrity conveyed through restraint — **not** flashy glass, neon, or gimmick. If a screen feels busy, aggressive, or generic, it fails this standard.

### 9.2 Principles

- **Calm & uncluttered** — generous whitespace; one primary action per view; content breathes.
- **Trust-forward** — soft depth over hard edges; subtle, predictable; nothing harsh.
- **Consistency over cleverness** — every screen reads as the same product.
- **Human warmth** — friendly microcopy, smooth (never frantic) motion, warm empty/success/error states.

### 9.3 Spacing & layout rhythm

Token source: `AppThemeExtension.spacing`.

- 8pt grid base. Use the token spacings; never ad-hoc `EdgeInsets`.
- Border radius via tokens: cards/standard surfaces **16dp**; modal bottom sheets **24dp top corners**.
- Screen padding: 16dp mobile / 24dp on web content panes; section gaps follow the spacing scale.

### 9.4 Depth & elevation

- Elevation is token-driven and **soft/subtle** — cards lift gently over the background; no hard drop shadows, no heavy contrast.
- Prefer elevation for interactive/modal surfaces; prefer borders (token `outline`) for static containment.

### 9.5 Motion & micro-interactions

- Token-driven durations & curves (target **150–300ms**, standard easing). Prefer fade + slide transitions.
- Animate only to communicate: button press, list feedback, state changes. No gratuitous animation.
- Loader: use `HivorrLoader` (breathing pulse, not a spin) for brand moments.

### 9.6 Component finish (uses EP-01-16 primitives)

- **Buttons** — clear hierarchy: primary = cerulean; financial-action CTA = emerald (secondary); outline/text for low-emphasis. Confident padding; ≥48dp tap targets.
- **Text fields** — calm filled/outlined states; clear focus ring (primary); legible error text using `error` tokens.
- **Cards** — token radius + soft elevation; consistent internal padding; subtle hover lift on web.
- **Empty / loading / error / success states** — always use the branded illustrated-slot widgets (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSnackbar`). Never a bare spinner or a dead-end: provide guidance or a next action.

### 9.7 Accessibility ceiling (premium = universally usable)

- WCAG AA contrast (the existing floor) **plus** comfortable touch targets (≥48dp), readable line-heights, and visible focus in both light and dark themes.

### 9.8 Enforcement

Extends §7. A UI task fails its Definition of Done if it uses **non-token** spacing, border radius, elevation/shadow, or motion, **or** ships an unmindful/off-brand empty, loading, error, or success state — not only when it hardcodes a color or font.
