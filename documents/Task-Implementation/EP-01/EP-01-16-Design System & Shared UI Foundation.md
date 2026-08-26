# TASK IMPLEMENTATION PLAN: EP-01-16

## Design System & Shared UI Foundation

---

## 1. Task Objective

Complete the remaining deliverables of the shared design system in `lib/shared/` so that **every UI in EP-02+ is built from consistent, token-driven primitives** and never hardcodes color or typography. The visual-identity foundation (color tokens, typography, theme extension, logo widgets, `HivorrLoader`) was already delivered. This plan covers the pending sub-steps:

- **Atomic widgets** (`lib/shared/widgets/`) — `HivorrButton`, `HivorrTextField`, `HivorrCard`, `HivorrChip`, plus loading/empty/error state widgets, all consuming `AppTheme` tokens exclusively.
- **Composite components** (`lib/shared/components/`) — multi-widget complex UI blocks (form field with label + error, list tile variants, section headers).
- **Responsive layouts** (`lib/shared/layouts/`) — mobile and web responsive scaffolds with adaptive breakpoint logic.
- **Validators** (`lib/shared/validators/`) — reusable form input validation rules.
- **Extensions** (`lib/shared/extensions/`) — `BuildContext`, `String`, and numeric convenience extensions.
- **Helpers** (`lib/shared/helpers/`) — UI formatters and UI utilities.
- **Mixins** (`lib/shared/mixins/`) — reusable Flutter mixins for shared widget behavior.
- **Barrel exports** — a `shared.dart` barrel file re-exporting the full public API.

**Dependencies:** EP-01-02 (Dependency Integration & Package Configuration — Completed). EP-01-15 (App Bootstrap, Lifecycle & Routing — Completed) wires `MaterialApp.theme = AppTheme.lightTheme/darkTheme`, which this task's widgets consume.

---

## 2. Business Problem Being Solved

Without a shared design system of atomic widgets, responsive layouts, and utility primitives:

- Every screen in EP-02+ would build UI from scratch, leading to visual inconsistency, duplicated code, and ad-hoc color/font usage that violates AGENT.md Rule 5.
- Developers (human or AI) would hardcode `Colors.*` or `fontFamily` in widgets because no convenient, token-driven alternative exists.
- Mobile and web layouts would diverge — no shared responsive scaffold means each screen implements its own breakpoint logic.
- Form validation would be reimplemented per-screen with inconsistent rules and error messaging.
- `BuildContext` convenience accessors (e.g., `context.colorScheme`, `context.textTheme`) would not exist, forcing verbose `Theme.of(context)` calls everywhere.
- Loading, empty, and error states would be bespoke per feature, creating a fragmented user experience.

This task creates the **UI primitive layer** that every feature in EP-02 through EP-08 builds upon. It enforces visual consistency by making the correct approach (consuming tokens) the easiest approach.

---

## 3. Scope

### In Scope

- `lib/shared/widgets/` — Atomic, single-purpose widgets:
  - `HivorrButton` — primary, secondary, outline, text variants; loading state; disabled state; icon support.
  - `HivorrTextField` — Material text input with label, hint, prefix/suffix, error text, character counter; themed borders.
  - `HivorrCard` — surface container with themed elevation, border radius, padding.
  - `HivorrChip` — selectable/dismissible chip with primary/secondary/surface variants.
  - `HivorrLoadingState` — centered `HivorrLoader` with optional message text.
  - `HivorrEmptyState` — illustration slot + title + subtitle + optional action button.
  - `HivorrErrorState` — error icon + message + retry button.
  - `HivorrAvatar` — circular avatar with initials fallback and image support.
  - `HivorrDivider` — themed horizontal divider using `outline` token.
  - `HivorrBadge` — small count/status indicator with semantic color variants.
  - `HivorrSnackbar` — themed snack bar with success/error/warning/info variants.
- `lib/shared/components/` — Multi-widget composite blocks:
  - `HivorrFormField` — `HivorrTextField` + label + validation error + helper text composition.
  - `HivorrListTile` — themed list tile with leading/trailing, subtitle, tap handler.
  - `HivorrSectionHeader` — section title + optional action button.
  - `HivorrDialog` — themed alert dialog with title, content, actions.
  - `HivorrBottomSheet` — themed modal bottom sheet scaffold.
- `lib/shared/layouts/` — Responsive layout scaffolds:
  - `HivorrResponsiveScaffold` — adaptive layout switching between mobile (single-column) and web (sidebar + content) based on breakpoint width.
  - `HivorrScreenScaffold` — standard screen wrapper with safe area, padding, optional AppBar.
  - `Breakpoints` — breakpoint constants (mobile, tablet, desktop) and helper.
- `lib/shared/validators/` — Form validation rules:
  - `HivorrValidators` — email, phone, password strength, required, min/max length, numeric, URL validators returning `String?` (null = valid).
- `lib/shared/extensions/` — Dart extensions:
  - `BuildContextExtensions` — `context.colorScheme`, `context.textTheme`, `context.appExtension`, `context.mediaQuery`, `context.isDarkMode`.
  - `StringExtensions` — `capitalize`, `truncate`, `initials`, `isValidEmail`, `isValidPhone`.
  - `NumericExtensions` — `currency` formatting, `ordinal` suffix.
- `lib/shared/helpers/` — UI formatters and utilities:
  - `HivorrFormatters` — date, time, number, file-size formatters.
  - `HivorrSpacing` — spacing constants derived from `AppThemeExtension.spacing`.
- `lib/shared/mixins/` — Reusable mixins:
  - `LoadingStateMixin` — `isLoading` / `hasError` / `errorMessage` state management for widgets.
  - `FormValidationMixin` — `validate()` orchestration for forms with multiple fields.
- `lib/shared/shared.dart` — Barrel file re-exporting the full public API.
- Widget tests for every atomic widget and composite component.
- Unit tests for validators, extensions, helpers, and breakpoints.

### Out of Scope

- Theme token modifications — existing `lib/app/theme/` is consumed as-is. No changes to `AppColors`, `AppTextTheme`, `AppTheme`, or `AppThemeExtension`.
- Logo widgets or `HivorrLoader` — already delivered in `lib/app/widgets/`.
- Business UI screens, feature pages, or dashboard content — EP-02+.
- Localization engine — EP-01-17.
- Notification engine — EP-01-18.
- Any API, auth, security, storage, sync, network, or monitoring implementation.
- Supabase migrations, RPC, RLS.
- Native platform configuration changes.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md, or VISUAL-IDENTITY.md.
- Adding new package dependencies — all widgets built with Flutter SDK + already-pinned packages only.

---

## 4. Out of Scope (Explicit Boundary Reaffirmation)

No proprietary/business rule, pricing, matching, or escrow logic is permitted in this layer. The design system is **presentation-only** — it provides visual primitives with zero domain knowledge. Widgets must never import from `lib/engine/`, `lib/systems/`, `lib/data/`, or `lib/core/` (except `lib/app/theme/` for token consumption). No data fetching, no state management beyond local widget state, no RPC calls.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles

- **Token-only theming:** Every widget reads colors from `Theme.of(context).colorScheme.*` and semantic colors from `Theme.of(context).extension<AppThemeExtension>()`. Zero hardcoded `Colors.*` or raw hex (AGENT.md Rule 5).
- **Typography from TextTheme:** Every text widget uses `Theme.of(context).textTheme.*`. Never set `fontFamily` per-widget (VISUAL-IDENTITY.md §6).
- **Atomic composition:** Widgets are small, single-purpose, and composable. Complex UI is built by combining atoms, not by creating monolithic widgets.
- **Null-safe and defensive:** All widgets handle null/empty inputs gracefully. `HivorrEmptyState` renders correctly with no data. `HivorrButton` handles null `onPressed` as disabled.
- **Accessibility-first:** All interactive widgets have proper `Semantics` labels. Touch targets meet 48×48dp minimum. Color contrast meets WCAG AA.
- **Responsive by default:** Layout widgets use `Breakpoints` to adapt between mobile and web. No hardcoded widths.
- **Testable in isolation:** Every widget is testable with `pumpWidget` + `MaterialApp` wrapper. No dependency on providers, API, or auth.

### 5.2 Proposed Structure

```text
lib/shared/
├── shared.dart                          # Barrel re-export
├── widgets/
│   ├── hivorr_button.dart               # Button (primary/secondary/outline/text)
│   ├── hivorr_text_field.dart           # Text input with theming
│   ├── hivorr_card.dart                 # Surface container
│   ├── hivorr_chip.dart                 # Selectable/dismissible chip
│   ├── hivorr_loading_state.dart        # Centered loader + message
│   ├── hivorr_empty_state.dart          # Empty state illustration slot
│   ├── hivorr_error_state.dart          # Error + retry
│   ├── hivorr_avatar.dart               # Circular avatar with initials
│   ├── hivorr_divider.dart              # Themed divider
│   ├── hivorr_badge.dart                # Count/status badge
│   └── hivorr_snackbar.dart             # Themed snack bar variants
├── components/
│   ├── hivorr_form_field.dart           # TextField + label + validation
│   ├── hivorr_list_tile.dart            # Themed list tile
│   ├── hivorr_section_header.dart       # Section title + action
│   ├── hivorr_dialog.dart               # Themed alert dialog
│   └── hivorr_bottom_sheet.dart         # Themed modal bottom sheet
├── layouts/
│   ├── breakpoints.dart                 # Breakpoint constants + helper
│   ├── hivorr_responsive_scaffold.dart  # Adaptive mobile/web layout
│   └── hivorr_screen_scaffold.dart      # Standard screen wrapper
├── validators/
│   └── hivorr_validators.dart           # Form validation rules
├── extensions/
│   ├── build_context_extensions.dart    # Theme/size convenience accessors
│   ├── string_extensions.dart           # capitalize, truncate, initials
│   └── numeric_extensions.dart          # currency, ordinal formatting
├── helpers/
│   ├── hivorr_formatters.dart           # Date, time, number formatters
│   └── hivorr_spacing.dart              # Spacing constants from tokens
└── mixins/
    ├── loading_state_mixin.dart          # isLoading/hasError state
    └── form_validation_mixin.dart        # Multi-field validate orchestration
```

### 5.3 Atomic Widget Specifications

#### `HivorrButton`

| Property | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | required | Button text |
| `onPressed` | `VoidCallback?` | required | Tap handler; `null` = disabled |
| `variant` | `HivorrButtonVariant` | `primary` | `primary`, `secondary`, `outline`, `text` |
| `isLoading` | `bool` | `false` | Shows `HivorrLoader` (small) in place of label |
| `icon` | `Widget?` | `null` | Leading icon |
| `isExpanded` | `bool` | `false` | Full-width button |
| `size` | `HivorrButtonSize` | `medium` | `small`, `medium`, `large` |

- **Primary:** `colorScheme.primary` background, `onPrimary` text.
- **Secondary:** `colorScheme.secondary` background, `onSecondary` text.
- **Outline:** Transparent background, `colorScheme.primary` border + text.
- **Text:** No background, `colorScheme.primary` text.
- **Disabled:** `surfaceContainerHighest` background, `onSurfaceVariant` text (50% opacity).
- **Loading:** Replaces label with a small `HivorrLoader` (size 20) tinted to `onPrimary`/`onSecondary`/`primary` depending on variant.
- **Border radius:** `AppThemeExtension.radiusSm` (8dp).
- **Minimum touch target:** 48dp height.

#### `HivorrTextField`

| Property | Type | Default | Description |
|---|---|---|---|
| `controller` | `TextEditingController?` | `null` | Text controller |
| `label` | `String?` | `null` | Floating label |
| `hint` | `String?` | `null` | Placeholder text |
| `errorText` | `String?` | `null` | Error message (shows red border + text) |
| `helperText` | `String?` | `null` | Helper text below input |
| `prefix` | `Widget?` | `null` | Prefix widget |
| `suffix` | `Widget?` | `null` | Suffix widget |
| `obscureText` | `bool` | `false` | Password masking |
| `maxLines` | `int` | `1` | Multi-line support |
| `maxLength` | `int?` | `null` | Character counter |
| `keyboardType` | `TextInputType?` | `null` | Keyboard type |
| `onChanged` | `ValueChanged<String>?` | `null` | Change callback |
| `enabled` | `bool` | `true` | Enabled state |

- **Border:** `OutlineInputBorder` with `colorScheme.outline` (enabled), `colorScheme.primary` (focused), `colorScheme.error` (error).
- **Border radius:** `AppThemeExtension.radiusSm` (8dp).
- **Fill:** `colorScheme.surface` background.
- **Label/hint colors:** `onSurfaceVariant` (unfocused), `primary` (focused).

#### `HivorrCard`

| Property | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | Card content |
| `padding` | `EdgeInsets?` | `EdgeInsets.all(16)` | Internal padding |
| `elevation` | `double` | `0` | Shadow elevation |
| `onTap` | `VoidCallback?` | `null` | Makes card tappable |
| `borderRadius` | `double?` | `null` | Override; defaults to `radiusMd` (12dp) |

- **Surface:** `colorScheme.surface` background.
- **Border:** 1px `colorScheme.outline` when `elevation == 0`.
- **Tappable:** `InkWell` with `colorScheme.primary` splash at 12% opacity.

#### `HivorrChip`

| Property | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | required | Chip text |
| `isSelected` | `bool` | `false` | Selected state |
| `onSelected` | `ValueChanged<bool>?` | `null` | Selection toggle handler |
| `onDismissed` | `VoidCallback?` | `null` | Dismiss handler (shows delete icon) |
| `variant` | `HivorrChipVariant` | `primary` | `primary`, `secondary`, `surface` |

- **Selected:** Filled with variant color.
- **Unselected:** Outlined with `colorScheme.outline`.
- **Border radius:** `radiusLg` (20dp, fully rounded).

#### State Widgets (`HivorrLoadingState`, `HivorrEmptyState`, `HivorrErrorState`)

- All three are full-width, vertically centered `Column` widgets designed to fill a screen's content area.
- `HivorrLoadingState`: `HivorrLoader` (size 64) + optional `message` text (`bodyMedium`, `onSurfaceVariant`).
- `HivorrEmptyState`: Icon slot (default `Icons.inbox_outlined`) + `title` + optional `subtitle` + optional `actionButton` (`HivorrButton`).
- `HivorrErrorState`: Error icon (`Icons.error_outline`, `colorScheme.error`) + `message` + `HivorrButton` "Retry" (outline variant).

### 5.4 Responsive Layout Specifications

#### `Breakpoints`

| Name | Width Range | Layout |
|---|---|---|
| `mobile` | `< 600dp` | Single column, bottom navigation |
| `tablet` | `600–1023dp` | Two-column, side rail |
| `desktop` | `≥ 1024dp` | Sidebar + content area |

- Exposed as `static const double` values and a `Breakpoint.fromWidth(double)` factory.
- `Breakpoint.current(BuildContext)` reads `MediaQuery.sizeOf(context).width`.

#### `HivorrResponsiveScaffold`

- **Mobile (< 600dp):** `Scaffold` with `body` + optional `bottomNavigationBar`.
- **Tablet/Desktop (≥ 600dp):** `Row` with `NavigationRail` sidebar + expanded content area.
- Accepts `mobileBody`, `sidebar` (optional), `appBar` (optional), `bottomNavigationBar` (optional).
- Uses `LayoutBuilder` for breakpoint detection — no `MediaQuery` dependency at the call site.

#### `HivorrScreenScaffold`

- Wraps content in `SafeArea` + standard horizontal padding (`HivorrSpacing.md`).
- Accepts optional `AppBar`, `FloatingActionButton`, `backgroundColor` override.
- Default `backgroundColor` is `colorScheme.surface` (not `scaffoldBackgroundColor`) to allow nested cards to use `scaffoldBackgroundColor` for contrast.

### 5.5 Validator Specifications

`HivorrValidators` is a class with static methods returning `String?` (null = valid, non-null = error message):

| Validator | Signature | Error Message |
|---|---|---|
| `required` | `(String? value, {String? field})` | `"{field} is required"` |
| `email` | `(String? value)` | `"Enter a valid email address"` |
| `phone` | `(String? value)` | `"Enter a valid phone number"` |
| `minLength` | `(String? value, int min, {String? field})` | `"{field} must be at least {min} characters"` |
| `maxLength` | `(String? value, int max, {String? field})` | `"{field} must not exceed {max} characters"` |
| `passwordStrength` | `(String? value)` | `"Password must be at least 8 characters with uppercase, lowercase, and number"` |
| `numeric` | `(String? value)` | `"Enter a valid number"` |
| `url` | `(String? value)` | `"Enter a valid URL"` |
| `compose` | `(String? value, List<String? Function(String?)> validators)` | First non-null result |

### 5.6 Extension Specifications

#### `BuildContextExtensions`

| Extension | Returns | Source |
|---|---|---|
| `context.colorScheme` | `ColorScheme` | `Theme.of(context).colorScheme` |
| `context.textTheme` | `TextTheme` | `Theme.of(context).textTheme` |
| `context.appExtension` | `AppThemeExtension` | `Theme.of(context).extension<AppThemeExtension>()!` |
| `context.mediaQuery` | `MediaQueryData` | `MediaQuery.sizeOf(context)` |
| `context.screenWidth` | `double` | `MediaQuery.sizeOf(context).width` |
| `context.screenHeight` | `double` | `MediaQuery.sizeOf(context).height` |
| `context.isDarkMode` | `bool` | `Theme.of(context).brightness == Brightness.dark` |
| `context.breakpoint` | `Breakpoint` | `Breakpoint.current(context)` |

#### `StringExtensions`

| Extension | Returns | Logic |
|---|---|---|
| `.capitalize` | `String` | First letter uppercase, rest unchanged |
| `.truncate(int max)` | `String` | Truncate + `…` if exceeds `max` |
| `.initials` | `String` | First letter of each word, max 2 chars, uppercase |
| `.isValidEmail` | `bool` | RFC 5322 simplified regex |
| `.isValidPhone` | `bool` | E.164 or local format regex |

#### `NumericExtensions`

| Extension | Returns | Logic |
|---|---|---|
| `.toCurrency({String symbol})` | `String` | `NumberFormat.currency` with symbol (default `₦`) |
| `.toOrdinal` | `String` | `1st`, `2nd`, `3rd`, `4th`... |

### 5.7 Helper Specifications

#### `HivorrSpacing`

Derived from `AppThemeExtension.spacing` (base = 8dp):

| Constant | Value | Usage |
|---|---|---|
| `xs` | `4.0` | Tight gaps (icon-to-text) |
| `sm` | `8.0` | Standard element gaps |
| `md` | `16.0` | Section padding, card padding |
| `lg` | `24.0` | Screen horizontal padding |
| `xl` | `32.0` | Major section separation |
| `xxl` | `48.0` | Page-level vertical spacing |

#### `HivorrFormatters`

| Method | Signature | Example Output |
|---|---|---|
| `date` | `(DateTime dt, {String? locale})` | `"26 Aug 2026"` |
| `time` | `(DateTime dt, {String? locale})` | `"14:30"` |
| `dateTime` | `(DateTime dt, {String? locale})` | `"26 Aug 2026, 14:30"` |
| `number` | `(num value, {int decimals})` | `"1,234.56"` |
| `fileSize` | `(int bytes)` | `"2.4 MB"` |
| `relative` | `(DateTime dt)` | `"3 hours ago"`, `"yesterday"` |

### 5.8 Mixin Specifications

#### `LoadingStateMixin`

```
mixin LoadingStateMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  Future<void> runWithLoading(Future<void> Function() action);
}
```

- `runWithLoading` sets `_isLoading = true`, clears `_errorMessage`, executes `action`, catches exceptions into `_errorMessage`, and sets `_isLoading = false` in `finally`. Notifies listeners on each state change.

#### `FormValidationMixin`

```
mixin FormValidationMixin {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool validate() => formKey.currentState?.validate() ?? false;
  void reset() => formKey.currentState?.reset();
  Map<String, String?> get fieldErrors;
}
```

- Provides a `formKey` for `Form` widgets and a `validate()` shortcut.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `HivorrButton` | `lib/shared/widgets/` | Themed button with variants, loading, disabled |
| `HivorrTextField` | `lib/shared/widgets/` | Themed text input |
| `HivorrCard` | `lib/shared/widgets/` | Surface container |
| `HivorrChip` | `lib/shared/widgets/` | Selectable/dismissible chip |
| `HivorrLoadingState` | `lib/shared/widgets/` | Loading placeholder |
| `HivorrEmptyState` | `lib/shared/widgets/` | Empty data placeholder |
| `HivorrErrorState` | `lib/shared/widgets/` | Error display + retry |
| `HivorrAvatar` | `lib/shared/widgets/` | Circular avatar |
| `HivorrDivider` | `lib/shared/widgets/` | Themed divider |
| `HivorrBadge` | `lib/shared/widgets/` | Status/count badge |
| `HivorrSnackbar` | `lib/shared/widgets/` | Themed snack bar |
| `HivorrFormField` | `lib/shared/components/` | Composed form field |
| `HivorrListTile` | `lib/shared/components/` | Themed list tile |
| `HivorrSectionHeader` | `lib/shared/components/` | Section header |
| `HivorrDialog` | `lib/shared/components/` | Themed dialog |
| `HivorrBottomSheet` | `lib/shared/components/` | Themed bottom sheet |
| `Breakpoints` | `lib/shared/layouts/` | Breakpoint constants |
| `HivorrResponsiveScaffold` | `lib/shared/layouts/` | Adaptive mobile/web layout |
| `HivorrScreenScaffold` | `lib/shared/layouts/` | Standard screen wrapper |
| `HivorrValidators` | `lib/shared/validators/` | Form validation rules |
| `BuildContextExtensions` | `lib/shared/extensions/` | Theme/size accessors |
| `StringExtensions` | `lib/shared/extensions/` | String utilities |
| `NumericExtensions` | `lib/shared/extensions/` | Number formatting |
| `HivorrFormatters` | `lib/shared/helpers/` | Date/time/number formatters |
| `HivorrSpacing` | `lib/shared/helpers/` | Spacing constants |
| `LoadingStateMixin` | `lib/shared/mixins/` | Loading/error state |
| `FormValidationMixin` | `lib/shared/mixins/` | Form validation orchestration |
| `shared.dart` | `lib/shared/` | Barrel re-export |
| Test suite | `test/widget/shared/`, `test/unit/shared/` | Widget + unit tests |

**No new dependencies added.** All widgets built with Flutter SDK, `flutter_svg` (already pinned), and existing theme tokens.

---

## 7. Data Requirements

No business, user, or domain data is introduced. The design system is purely presentational:

- Widgets accept primitive inputs (`String`, `bool`, `VoidCallback`, `Widget`) — no domain entities.
- Validators operate on raw `String?` values — no entity awareness.
- Formatters operate on `DateTime`, `num`, `int` — no domain knowledge.
- Extensions operate on `BuildContext`, `String`, `num` — no data fetching.

---

## 8. Database Considerations

**Not applicable.** This task does not interact with the database. All data access remains server-side via EP-01-05/06/07/08.

---

## 9. API Requirements

**Not applicable.** This task does not make API calls. Widgets are stateless or manage only local widget state (text input, loading toggle).

---

## 10. User Interface Requirements

- **All widgets consume `AppTheme` tokens exclusively** — `ColorScheme` for standard slots, `AppThemeExtension` for semantic colors (success/warning/info), spacing, and radii. Zero hardcoded values (AGENT.md Rule 5).
- **All text uses `TextTheme`** — `Theme.of(context).textTheme.bodyMedium` etc. Never `fontFamily` per-widget.
- **Light and dark theme support** — every widget renders correctly in both themes. Verified by widget tests that pump with both `AppTheme.lightTheme` and `AppTheme.darkTheme`.
- **Accessibility:**
  - All interactive widgets have `Semantics` labels.
  - Touch targets ≥ 48×48dp.
  - Color contrast meets WCAG AA (enforced by token selection in VISUAL-IDENTITY.md).
  - `HivorrButton` announces disabled state to screen readers.
  - `HivorrTextField` associates label with input via `Semantics`.
- **Responsive:** Layout widgets adapt at 600dp and 1024dp breakpoints.
- **Animation:** Button press ripple, chip selection transition, dialog/bottom-sheet entrance — all use Flutter's standard `Material` animations. No custom animation controllers.

---

## 11. User Experience Considerations

- **Consistent visual language:** Every screen in EP-02+ uses the same button, input, card, and chip — users learn the interaction patterns once.
- **Loading states are branded:** `HivorrLoadingState` uses the `HivorrLoader` (hub-and-spoke animation) instead of a generic spinner, reinforcing brand identity.
- **Empty states are informative:** `HivorrEmptyState` provides context ("No messages yet") and a call-to-action, not a blank screen.
- **Error states are recoverable:** `HivorrErrorState` always includes a retry action — users are never stuck.
- **Form validation is immediate:** `HivorrFormField` shows inline errors on blur and on submit — no page-level error dumps.
- **Responsive transitions:** `HivorrResponsiveScaffold` smoothly adapts between mobile and web layouts without jarring reflows.
- **Snackbar feedback:** `HivorrSnackbar` provides semantic-colored feedback (green success, red error, amber warning, blue info) that is immediately recognizable.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Hardcoded colors/fonts | All values from `AppTheme` tokens; widget tests assert no `Colors.*` literals |
| Business logic in widgets | Zero domain imports; widgets are purely presentational |
| Sensitive data in formatters | Formatters operate on primitive types; no PII handling or logging |
| XSS in text rendering | Flutter's `Text` widget auto-escapes; no `Html` rendering in this task |
| Token leakage via error messages | `HivorrErrorState` accepts a `message` string — caller controls content; widget does not generate or log messages |
| Accessibility bypass | All interactive widgets have `Semantics`; tested in widget tests |

---

## 13. Performance Considerations

- **No runtime theme lookups in build():** Widgets use `Theme.of(context)` which is O(1) via inherited widget. No expensive computations in build methods.
- **Const constructors where possible:** `HivorrCard`, `HivorrDivider`, `HivorrSpacing` use `const` constructors to enable widget tree caching.
- **No unnecessary rebuilds:** Widgets accept only the props they need. `HivorrButton` does not rebuild when unrelated theme properties change (Flutter's `Theme` rebuilds are already optimized).
- **LayoutBuilder over MediaQuery:** `HivorrResponsiveScaffold` uses `LayoutBuilder` (scoped to parent) instead of `MediaQuery` (app-wide) to minimize rebuild scope on resize.
- **No image loading:** `HivorrAvatar` accepts an `ImageProvider` but does not fetch network images itself — caller provides `NetworkImage` or `AssetImage`.
- **Negligible impact on installer size:** No new packages, no new assets. All widgets are pure Dart/Flutter code.
- **HivorrSpacing as const:** Spacing values are compile-time constants, not runtime calculations.

---

## 14. Testing Strategy

### 14.1 Widget Tests — Atomic Widgets

For each widget (`HivorrButton`, `HivorrTextField`, `HivorrCard`, `HivorrChip`, `HivorrLoadingState`, `HivorrEmptyState`, `HivorrErrorState`, `HivorrAvatar`, `HivorrDivider`, `HivorrBadge`, `HivorrSnackbar`):

- Renders correctly with default properties.
- Renders correctly with all properties specified.
- Renders correctly in light theme.
- Renders correctly in dark theme.
- Disabled/loading/error states render correctly.
- Tap handlers fire correctly.
- Null `onPressed` renders disabled state.
- No hardcoded colors — assert themed values are used (e.g., button background equals `colorScheme.primary`).

### 14.2 Widget Tests — Composite Components

For each component (`HivorrFormField`, `HivorrListTile`, `HivorrSectionHeader`, `HivorrDialog`, `HivorrBottomSheet`):

- Renders correctly with all properties.
- Composed sub-widgets render correctly.
- Form field validation displays error text.
- Dialog/bottom-sheet show and dismiss correctly.

### 14.3 Widget Tests — Layouts

- `HivorrResponsiveScaffold` renders mobile layout at width < 600dp.
- `HivorrResponsiveScaffold` renders tablet/desktop layout at width ≥ 600dp.
- `HivorrScreenScaffold` applies `SafeArea` and standard padding.
- `Breakpoints` constants match documented values.

### 14.4 Unit Tests — Validators

- Each validator returns `null` for valid input.
- Each validator returns the correct error message for invalid input.
- `compose` returns the first non-null error.
- Edge cases: `null` input, empty string, whitespace-only.

### 14.5 Unit Tests — Extensions

- `BuildContext` extensions return correct theme values (tested with a `MaterialApp` wrapper).
- `String.capitalize` handles empty, single-char, already-capitalized.
- `String.truncate` handles strings shorter than, equal to, and longer than max.
- `String.initials` handles single word, multi-word, empty.
- `NumericExtensions.toCurrency` formats correctly with default and custom symbols.
- `NumericExtensions.toOrdinal` handles 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st.

### 14.6 Unit Tests — Helpers

- `HivorrSpacing` constants match expected values (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48).
- `HivorrFormatters.date` formats correctly.
- `HivorrFormatters.time` formats correctly.
- `HivorrFormatters.fileSize` handles bytes, KB, MB, GB.
- `HivorrFormatters.relative` handles "just now", minutes, hours, days, weeks.

### 14.7 Unit Tests — Mixins

- `LoadingStateMixin` transitions through loading → success → not-loading.
- `LoadingStateMixin` captures exception into `errorMessage` on failure.
- `FormValidationMixin.validate()` returns `true` when form is valid, `false` when invalid.

### 14.8 Project Validation

- `flutter analyze` — strict lints, no issues.
- `flutter test` — all new tests pass.
- Available platform smoke builds (Android, iOS, Web) — app compiles and renders design system gallery.

### 14.9 Scope Validation

- Diff review: only `lib/shared/` and `test/widget/shared/` + `test/unit/shared/` changes. No modifications to `lib/app/theme/`, `lib/app/widgets/`, `lib/core/`, `lib/engine/`, `lib/systems/`, `lib/data/`, or any phase document.

---

## 15. Recommended Implementation Sequence

1. **Inspect existing deliverables:** Confirm `lib/shared/` subdirectories contain only `.gitkeep`. Confirm `lib/app/theme/` tokens are stable and tests pass.
2. **Create `lib/shared/helpers/hivorr_spacing.dart`** — spacing constants (no dependencies, consumed by all widgets).
3. **Create `lib/shared/extensions/build_context_extensions.dart`** — `BuildContext` convenience accessors (consumed by all widgets).
4. **Create `lib/shared/extensions/string_extensions.dart`** — string utilities.
5. **Create `lib/shared/extensions/numeric_extensions.dart`** — number formatting.
6. **Create `lib/shared/helpers/hivorr_formatters.dart`** — date/time/number formatters.
7. **Create `lib/shared/validators/hivorr_validators.dart`** — form validation rules.
8. **Create `lib/shared/mixins/loading_state_mixin.dart`** — loading/error state mixin.
9. **Create `lib/shared/mixins/form_validation_mixin.dart`** — form validation mixin.
10. **Create `lib/shared/layouts/breakpoints.dart`** — breakpoint constants.
11. **Create atomic widgets** (in order, each building on prior):
    - `hivorr_divider.dart` (simplest — no interaction)
    - `hivorr_badge.dart` (simple display)
    - `hivorr_avatar.dart` (display + initials fallback)
    - `hivorr_button.dart` (interactive — variants, loading, disabled)
    - `hivorr_text_field.dart` (interactive — input, validation display)
    - `hivorr_card.dart` (container)
    - `hivorr_chip.dart` (interactive — selection, dismiss)
    - `hivorr_loading_state.dart` (uses `HivorrLoader` from `lib/app/widgets/`)
    - `hivorr_empty_state.dart` (uses `HivorrButton` for action)
    - `hivorr_error_state.dart` (uses `HivorrButton` for retry)
    - `hivorr_snackbar.dart` (uses `AppThemeExtension` semantic colors)
12. **Create composite components:**
    - `hivorr_form_field.dart` (composes `HivorrTextField` + validation)
    - `hivorr_list_tile.dart` (composes themed tile)
    - `hivorr_section_header.dart` (composes title + action)
    - `hivorr_dialog.dart` (themed dialog wrapper)
    - `hivorr_bottom_sheet.dart` (themed bottom sheet wrapper)
13. **Create layout widgets:**
    - `hivorr_screen_scaffold.dart` (standard screen wrapper)
    - `hivorr_responsive_scaffold.dart` (adaptive mobile/web)
14. **Create `lib/shared/shared.dart`** — barrel re-export of all public APIs.
15. **Write unit tests** for validators, extensions, helpers, breakpoints, and mixins.
16. **Write widget tests** for all atomic widgets, composite components, and layouts.
17. **Run `flutter analyze`** and fix any lint issues.
18. **Run `flutter test`** and ensure all tests pass.
19. **Perform available platform smoke builds** (Android, iOS, Web).
20. **Review final diff** for strict EP-01-16 scope containment and phase-document integrity.
21. **Stop at the approval gate** — do not build feature screens, localization, or notifications.

---

## 16. Expected Outcome

- A complete set of **11 atomic widgets** in `lib/shared/widgets/` — all consuming `AppTheme` tokens exclusively, supporting light/dark themes, accessible, and responsive.
- **5 composite components** in `lib/shared/components/` — multi-widget blocks composed from atoms.
- **3 responsive layout widgets** in `lib/shared/layouts/` — breakpoint constants, adaptive scaffold, and standard screen wrapper enabling mobile/web adaptation.
- **Form validation rules** in `lib/shared/validators/` — reusable, composable validators returning `String?`.
- **Dart extensions** in `lib/shared/extensions/` — `BuildContext` theme accessors, string utilities, number formatting.
- **UI helpers** in `lib/shared/helpers/` — spacing constants and date/time/number formatters.
- **Reusable mixins** in `lib/shared/mixins/` — loading state and form validation orchestration.
- **Barrel export** (`shared.dart`) providing a single import for all shared primitives.
- **Comprehensive test suite** — widget tests for every widget/component/layout, unit tests for every validator/extension/helper/mixin.
- **Zero hardcoded colors or fonts** — verified by tests and static analysis.
- **EP-02+ ready** — every future UI screen can import `package:hivorr/shared/shared.dart` and build from consistent primitives.

---

## 17. Definition of Done (DoD)

- [ ] `lib/shared/widgets/` contains all 11 atomic widgets (`HivorrButton`, `HivorrTextField`, `HivorrCard`, `HivorrChip`, `HivorrLoadingState`, `HivorrEmptyState`, `HivorrErrorState`, `HivorrAvatar`, `HivorrDivider`, `HivorrBadge`, `HivorrSnackbar`).
- [ ] `lib/shared/components/` contains all 5 composite components (`HivorrFormField`, `HivorrListTile`, `HivorrSectionHeader`, `HivorrDialog`, `HivorrBottomSheet`).
- [ ] `lib/shared/layouts/` contains `Breakpoints`, `HivorrResponsiveScaffold`, and `HivorrScreenScaffold`.
- [ ] `lib/shared/validators/hivorr_validators.dart` contains all documented validators.
- [ ] `lib/shared/extensions/` contains `BuildContextExtensions`, `StringExtensions`, `NumericExtensions`.
- [ ] `lib/shared/helpers/` contains `HivorrFormatters` and `HivorrSpacing`.
- [ ] `lib/shared/mixins/` contains `LoadingStateMixin` and `FormValidationMixin`.
- [ ] `lib/shared/shared.dart` barrel file re-exports all public APIs.
- [ ] All widgets consume `AppTheme` tokens exclusively — zero hardcoded `Colors.*`, raw hex, or `fontFamily` (AGENT.md Rule 5).
- [ ] All widgets render correctly in both light and dark themes.
- [ ] All interactive widgets have `Semantics` labels and ≥ 48×48dp touch targets.
- [ ] `HivorrResponsiveScaffold` adapts at 600dp and 1024dp breakpoints.
- [ ] `HivorrButton` supports primary, secondary, outline, text variants with loading and disabled states.
- [ ] `HivorrTextField` supports label, hint, error, helper, prefix/suffix, obscure, multiline, maxLength.
- [ ] `HivorrLoadingState` uses `HivorrLoader` from `lib/app/widgets/`.
- [ ] Widget tests cover every atomic widget, composite component, and layout widget (light + dark theme, all states).
- [ ] Unit tests cover every validator, extension, helper, and mixin.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (Android, iOS, Web).
- [ ] No business logic, domain model, repository, security, monitoring, localization, or notification code included.
- [ ] No modifications to `lib/app/theme/`, `lib/app/widgets/`, `lib/core/`, `lib/engine/`, `lib/systems/`, or `lib/data/`.
- [ ] No new package dependencies added.
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, AGENT.md, and VISUAL-IDENTITY.md remain unchanged.
- [ ] Final diff contains only approved EP-01-16 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** High — building a comprehensive set of atomic widgets, composite components, responsive layouts, validators, extensions, helpers, and mixins requires precise understanding of Flutter's theming system, `ThemeExtension` API, `LayoutBuilder` breakpoint logic, form validation patterns, and mixin composition. Each widget must correctly consume `ColorScheme` + `AppThemeExtension` tokens across light and dark themes without hardcoding.
- **Business impact:** High — this is the UI primitive layer that every screen in EP-02 through EP-08 builds upon. Inconsistencies or defects here propagate to every feature screen. Getting the token consumption pattern right establishes the discipline that prevents AGENT.md Rule 5 violations project-wide.
- **Security risk:** Low — no data access, no API calls, no auth, no secrets. Widgets are purely presentational.
- **Performance sensitivity:** Medium — widgets must not introduce unnecessary rebuilds; `LayoutBuilder` must be used correctly for responsive detection; const constructors should be used where possible.
- **Data complexity:** Low — no domain entities, no database, no API. Widgets accept primitive types only.
- **Integration complexity:** Medium — must correctly consume the existing `AppTheme`/`AppThemeExtension`/`AppColors`/`AppTextTheme` tokens and the `HivorrLoader` widget from `lib/app/widgets/`. Must not modify any existing code. Must integrate cleanly with the `MaterialApp.router` already wired in EP-01-15.

High reasoning matches the approved EP-01 matrix (EP-01-16 = High) and the breadth of deliverables requiring consistent, token-driven implementation across many files.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-16-Design System & Shared UI Foundation.md` (replacing the current partial-status document) and implementation will begin only after a separate implementation approval. No production code is written during planning.
