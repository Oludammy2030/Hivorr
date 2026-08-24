# EP-01-16: Design System & Shared UI Foundation

| Field | Value |
|---|---|
| Episode | EP-01 (Core Platform Foundation) |
| Task | Design System & Shared UI Foundation |
| Dependencies | EP-01-02 (Dependency Integration & Package Configuration) |
| Status | **Partial** — Visual-Identity foundation delivered; atomic widgets / responsive layouts / helpers pending |

## 1. Objective

Build the shared design system in `lib/shared/` (per the approved phase plan) so that **every UI in EP-02+ is built from consistent primitives** and never hardcodes color or typography. This task is the first consumer of the project-wide visual identity defined in `documents/Context/VISUAL-IDENTITY.md`.

## 2. Source of Truth

`documents/Context/VISUAL-IDENTITY.md` is the canonical spec for:
- Project color (Cerulean `#0B6E99` primary, Emerald `#10B981` accent)
- Full light + dark color token set
- Typography (Inter, bundled offline)
- Logo (mark + wordmark, placeholder)

All runtime tokens MUST equal the hex/weights in that document (see AGENT.md Rule 5).

## 3. Delivered This Session (Visual-Identity Foundation)

| Item | Path | Notes |
|---|---|---|
| Visual-identity spec (source of truth) | `documents/Context/VISUAL-IDENTITY.md` | Project-wide, EP-01 → EP-08 |
| Inter variable font (offline) | `assets/fonts/Inter-Variable.ttf` | Registered with weight entries 400/500/600/700 in `pubspec.yaml` |
| Logo mark | `assets/images/logo.svg` | Cerulean tile with hub-and-spoke network mark (silver Universal Entity + silver role nodes, silver connectors) |
| Loader (monochrome) | `lib/app/widgets/hivorr_loader.dart` + `assets/images/hivorr_loader.svg` | `HivorrLoader` widget: monochrome node-network (filled nodes matching the brand mark), staggered breathing pulse (no spin); standalone CSS-keyframe SVG for web |
| Logo wordmark | `assets/images/logo_wordmark.svg` | Mark + "Hivorr" in Inter |
| Logo icon (app/favicon) | `assets/images/logo_icon.svg` | Mark-only on cerulean rounded square (1:1) |
| Logo horizontal lockup | `assets/images/logo_horizontal.svg` | Emblem + wordmark, transparent (3.2:1) |
| Logo stacked lockup | `assets/images/logo_stacked.svg` | Emblem above wordmark, transparent (256:300) |
| Logo monochrome lockup | `assets/images/logo_monochrome.svg` | Single-color (tintable, defaults white), transparent (4:1) |
| Logo widgets | `lib/app/widgets/logo_variants.dart` | `LogoIcon`, `LogoHorizontal`, `LogoStacked`, `LogoMonochrome` (height-first `flutter_svg` wrappers) |
| Icon source (raster) | `assets/images/logo_icon.png` (transparent) + `assets/images/logo_icon_ios.png` (opaque, cerulean bg) | 1024² PNGs derived from `logo_icon.svg`; inputs to `flutter_launcher_icons` |
| Launcher icons (generated) | `android/.../mipmap-*`, `ios/Runner/.../AppIcon.appiconset`, `web/favicon.png` + `web/icons/*` | Produced by `flutter_launcher_icons` (Android adaptive bg `#0B6E99`); re-run `flutter pub run flutter_launcher_icons` after editing the mark |
| Color tokens | `lib/app/theme/app_colors.dart` | `ColorScheme` light/dark (brand + semantic raw colors) |
| Typography | `lib/app/theme/app_text_theme.dart` | `TextTheme` (Inter, responsive) |
| Theme + extension | `lib/app/theme/app_theme.dart` | `AppTheme.lightTheme`/`darkTheme` + `AppThemeExtension` (success/warning/info, radii, spacing) |
| Barrel | `lib/app/theme/theme.dart` | Re-exports the above |
| Dependency | `pubspec.yaml` | `flutter_svg: ^2.0.10` added; fonts + `assets/images/` registered |
| Enforcement | `documents/Context/AGENT.md` | Rule 5 added (UI must use `AppTheme` tokens) |
| Tests | `test/unit/app/theme/app_theme_test.dart` | Asserts `ColorScheme.primary == #0B6E99`, `TextTheme` font, light/dark build |

## 4. Remaining Within EP-01-16 (pending sub-steps)

- Atomic widgets: `button`, `input`, `card`, `chip` built from `AppTheme` tokens.
- Responsive layouts: mobile/web scaffolds.
- Validators, extensions, helpers.

These consume the tokens delivered above and are sequenced after EP-01-15 (App Bootstrap) wires `MaterialApp.theme = AppTheme.lightTheme/darkTheme`.

## 5. Integration

- **EP-01-15 (App Bootstrap & Routing):** `app.dart` `MaterialApp` uses `AppTheme.lightTheme` / `darkTheme` (via `ThemeMode` + provider). Splash screen shows `assets/images/logo.svg`; AppBar uses `logo_wordmark.svg`.
- **EP-01-17 (Localization):** Built on top of this typography.
- **EP-02+:** All screens consume `AppTheme` tokens; hardcoding a color/font fails the task DoD (AGENT.md Rule 5).

## 6. Out of Scope (this session)

- Real brand logo art (the SVG is an intentional, replaceable placeholder).
- Atomic widget library (next EP-01-16 sub-step).

## 7. Verification

- `flutter analyze lib test` — no issues.
- `flutter test test/unit/app/theme` — AppTheme assertions pass.
- Runtime tokens in `lib/app/theme/*` equal `VISUAL-IDENTITY.md` hex values (contract enforced by tests).
