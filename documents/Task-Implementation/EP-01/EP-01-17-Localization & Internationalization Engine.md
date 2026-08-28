# TASK IMPLEMENTATION PLAN: EP-01-17

## Localization & Internationalization Engine

---

## 1. Task Objective

Implement the complete localization and internationalization engine in `lib/core/localization/` so that **every user-facing string in EP-02+ is served from typed translation keys backed by JSON translation files**, with dynamic language switching, pluralization, parameter interpolation, and app-wide locale state propagation via Provider.

The deliverables are:

- **`HivorrLocalizations`** — custom `LocalizationsDelegate` and translation access class loading from `assets/translations/{code}.json`.
- **`TranslationKeys`** — typed, namespaced key constants for compile-time safety and IDE autocomplete.
- **`LocaleProvider`** — `ChangeNotifier` propagating the active locale app-wide, with dynamic switching and persistence.
- **`HivorrLocalizationService`** — low-level JSON loader, translation resolver, pluralization engine, and parameter interpolation.
- **`HivorrSupportedLocales`** — registry of supported locales with metadata.
- **`AppLocalizations` extension** — `BuildContext` convenience accessor (`context.tr(key)`, `context.plural(key, count)`).
- **`en.json`** — initial English translation file in `assets/translations/`.
- **`localization.dart`** barrel export.
- **App integration** — `MaterialApp.router` wired with delegates, supported locales, and `LocaleProvider` in `app.dart`.
- **pubspec.yaml update** — add `flutter_localizations` (SDK), `intl` (pinned), and register `assets/translations/`.
- **Unit + widget tests** covering the full localization pipeline.

**Dependencies:** EP-01-02 (Dependency Integration — Completed). EP-01-16 (Design System & Shared UI Foundation — Not Started, provides `BuildContextExtensions` that this task's `BuildContext` localization extension parallels).

---

## 2. Business Problem Being Solved

Without a localization engine:

- Every user-facing string in EP-02+ would be hardcoded in Dart source files, making translation impossible without code changes.
- The platform could not serve non-English-speaking markets — critical for EP-08 (Global Scale) and the Nigerian market where Pidgin English, Yoruba, Hausa, and Igbo support may be required.
- Dynamic language switching would not exist — users could not change their preferred language at runtime.
- Pluralization would be ad-hoc (`item` vs `items` hardcoded), breaking for languages with complex plural rules (e.g., Arabic has 6 plural forms).
- String interpolation would use Dart string literals, coupling translations to Dart code and preventing translator workflows.
- Locale preference would not persist across sessions.
- There would be no compile-time safety for translation keys — missing translations would surface only at runtime in production.

This task creates the **localization infrastructure** that every feature in EP-02 through EP-08 uses for all user-facing text. It enforces the discipline that no raw string appears in UI widgets — all text flows through typed translation keys.

---

## 3. Scope

### In Scope

- `lib/core/localization/hivorr_localizations.dart` — `LocalizationsDelegate<HivorrLocalizations>` and the `HivorrLocalizations` class providing typed translation access (`translate(key, {params})`, `plural(key, count, {params})`).
- `lib/core/localization/localization_service.dart` — `HivorrLocalizationService` handling JSON file loading from `assets/translations/`, flat-key resolution, `{param}` interpolation, and plural-form selection.
- `lib/core/localization/translation_keys.dart` — `TranslationKeys` class with static const `String` members organized by feature namespace (`common.*`, `auth.*`, `errors.*`, `validation.*`).
- `lib/core/localization/locale_provider.dart` — `LocaleProvider extends ChangeNotifier` managing the active `Locale`, exposing `setLocale()`, `resetToSystemLocale()`, persisting the user's choice via Hive, and restoring it on startup.
- `lib/core/localization/supported_locales.dart` — `HivorrSupportedLocales` registry defining the supported `Locale` list, default locale, and locale resolution callback.
- `lib/core/localization/localization_extension.dart` — `BuildContext` extension providing `context.tr(key, {params})`, `context.plural(key, count, {params})`, and `context.currentLocale`.
- `lib/core/localization/localization_config.dart` — `LocalizationConfig` immutable configuration (default locale, fallback locale, supported locales list).
- `lib/core/localization/localization_exception.dart` — typed exception for localization failures (missing key, malformed JSON, unsupported locale).
- `lib/core/localization/localization.dart` — barrel re-export of the full public API.
- `assets/translations/en.json` — initial English translation file with foundational keys (common UI labels, auth flow, error messages, validation messages).
- **App integration:** Modify `lib/app/app.dart` to wire `localizationsDelegates`, `supportedLocales`, `locale` from `LocaleProvider`, and add `LocaleProvider` to `MultiProvider`.
- **Bootstrap integration:** Modify `lib/app/app_bootstrap.dart` to initialize `LocaleProvider` (restore persisted locale) and pass it to `HivorrApp`.
- **pubspec.yaml update:** Add `flutter_localizations` (SDK), `intl` (pinned version), and register `assets/translations/` in the `flutter.assets` section.
- **Unit tests** for `HivorrLocalizationService`, `TranslationKeys`, `LocaleProvider`, `HivorrSupportedLocales`, and pluralization/interpolation logic.
- **Widget tests** for `HivorrLocalizations` delegate integration, `BuildContext` extension, and locale switching.

### Out of Scope

- Creating translation files beyond `en.json` — additional locales (fr.json, es.json, ha.json, etc.) are added by EP-02+ as needed.
- Business UI screens, feature pages, or dashboard content — EP-02+.
- Modifying design system widgets (EP-01-16 deliverables) to use translation keys — EP-02+ screens wire translations to widgets.
- Right-to-left (RTL) layout support — the engine supports RTL locales structurally, but RTL-specific layout adjustments are deferred to EP-08.
- Server-side translation storage or remote translation fetching — all translations are bundled in the app binary.
- Translation management tooling or CI-based translation validation.
- Notification engine — EP-01-18.
- Any API, auth, security, storage, sync, network, or monitoring implementation beyond what already exists.
- Supabase migrations, RPC, RLS.
- Native platform configuration changes.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md, or VISUAL-IDENTITY.md.

---

## 4. Out of Scope (Explicit Boundary Reaffirmation)

No proprietary/business rule, pricing, matching, or escrow logic is permitted in this layer. The localization engine is **infrastructure-only** — it loads, resolves, and serves translations with zero domain knowledge. It must never import from `lib/engine/`, `lib/systems/`, or `lib/data/`. No data fetching, no RPC calls, no auth token handling. Translation files contain only user-facing UI strings — never secrets, configuration values, or business rules.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles

- **Flutter-native delegation:** Use Flutter's `LocalizationsDelegate` pattern as the loading mechanism. This integrates with `MaterialApp`'s built-in locale resolution and rebuilds the widget tree automatically on locale change.
- **JSON-backed, flat-key structure:** Translations stored in flat JSON files (`{"common.ok": "OK", "auth.loginTitle": "Sign In"}`). Flat keys avoid nested-map traversal complexity and simplify translator workflows.
- **Typed key access:** All translation keys defined as `static const String` in `TranslationKeys`. No magic strings at call sites. IDE autocomplete prevents typos.
- **ICU pluralization via `intl`:** Use `Intl.plural()` from the `intl` package for proper CLDR plural rules (zero/one/two/few/many/other). This is the Flutter-standard approach.
- **Parameter interpolation:** Support `{paramName}` placeholders in translation values, resolved at runtime via `Map<String, String>` parameter. Simple regex replacement — no expression evaluation.
- **Provider-driven state:** `LocaleProvider` as `ChangeNotifier` — consistent with the existing `AuthProvider` pattern. `MaterialApp.router` reads `locale` from this provider and rebuilds on change.
- **Persistence via Hive:** Locale preference persisted using the existing Hive storage infrastructure (EP-01-11). Restored on startup before `MaterialApp` renders.
- **Fallback chain:** Missing key in active locale → fallback locale (`en`) → key name itself (never blank or crash).
- **Fail-safe loading:** If a translation JSON file is malformed or missing, the engine logs a warning and falls back to the default locale's translations.

### 5.2 Proposed Structure

```text
lib/core/localization/
├── localization.dart                  # Barrel re-export
├── hivorr_localizations.dart          # LocalizationsDelegate + HivorrLocalizations class
├── localization_service.dart          # JSON loader, resolver, interpolation, pluralization
├── translation_keys.dart              # Typed translation key constants
├── locale_provider.dart               # ChangeNotifier for active locale
├── supported_locales.dart             # Supported locale registry
├── localization_extension.dart        # BuildContext convenience accessor
├── localization_config.dart           # Immutable configuration
└── localization_exception.dart        # Typed exception

assets/translations/
└── en.json                            # Initial English translations
```

### 5.3 Component Specifications

#### `HivorrLocalizations`

The core class registered as a `LocalizationsDelegate<HivorrLocalizations>`.

```
class HivorrLocalizations extends LocalizationsDelegate<HivorrLocalizations> {
  // Delegate overrides
  bool isSupported(Locale locale);
  Future<HivorrLocalizations> load(Locale locale);
  bool shouldReload(HivorrLocalizations old);

  // Static accessor for use in widgets
  static HivorrLocalizations of(BuildContext context);

  // Translation methods
  String translate(String key, {Map<String, String>? params});
  String plural(String key, int count, {Map<String, String>? params});
}
```

- `load()` delegates to `HivorrLocalizationService.loadTranslations(locale)` to fetch and parse the JSON.
- `translate()` resolves the key, applies parameter interpolation, and falls back through the chain.
- `plural()` resolves plural-form keys (`{key}.zero`, `{key}.one`, `{key}.other`) using `Intl.plural()` logic.
- `of(context)` is a static convenience that calls `Localizations.of<HivorrLocalizations>(context, HivorrLocalizations)`.

#### `HivorrLocalizationService`

Low-level service handling file I/O and string resolution.

```
class HivorrLocalizationService {
  Future<Map<String, String>> loadTranslations(Locale locale);
  String resolve(String key, Map<String, String> translations, Map<String, String>? fallback);
  String interpolate(String template, Map<String, String> params);
  String resolvePlural(String key, int count, Map<String, String> translations, Map<String, String>? fallback);
}
```

- `loadTranslations()` reads `assets/translations/{languageCode}.json` via `rootBundle.loadString()`, decodes JSON, and flattens into `Map<String, String>`.
- `resolve()` looks up the key in the active locale's map, falls back to the fallback map, then returns the key itself if not found.
- `interpolate()` replaces `{paramName}` occurrences with values from the params map.
- `resolvePlural()` selects the correct plural form key using `Intl.pluralLogic()` and resolves it.

#### `TranslationKeys`

Organized by feature namespace. EP-01-17 defines the foundational set; EP-02+ extends.

```
class TranslationKeys {
  TranslationKeys._();

  // Common
  static const String commonOk = 'common.ok';
  static const String commonCancel = 'common.cancel';
  static const String commonSave = 'common.save';
  static const String commonDelete = 'common.delete';
  static const String commonEdit = 'common.edit';
  static const String commonDone = 'common.done';
  static const String commonRetry = 'common.retry';
  static const String commonLoading = 'common.loading';
  static const String commonError = 'common.error';
  static const String commonSuccess = 'common.success';
  static const String commonWarning = 'common.warning';
  static const String commonNoData = 'common.noData';
  static const String commonSearch = 'common.search';
  static const String commonClose = 'common.close';
  static const String commonBack = 'common.back';
  static const String commonNext = 'common.next';
  static const String commonYes = 'common.yes';
  static const String commonNo = 'common.no';
  static const String commonItemCount = 'common.itemCount';

  // Auth
  static const String authLoginTitle = 'auth.loginTitle';
  static const String authSignupTitle = 'auth.signupTitle';
  static const String authEmail = 'auth.email';
  static const String authPassword = 'auth.password';
  static const String authForgotPassword = 'auth.forgotPassword';
  static const String authLoginButton = 'auth.loginButton';
  static const String authSignupButton = 'auth.signupButton';
  static const String authLogoutButton = 'auth.logoutButton';
  static const String authNoAccount = 'auth.noAccount';
  static const String authHasAccount = 'auth.hasAccount';

  // Errors
  static const String errorGeneric = 'errors.generic';
  static const String errorNetwork = 'errors.network';
  static const String errorTimeout = 'errors.timeout';
  static const String errorUnauthorized = 'errors.unauthorized';
  static const String errorNotFound = 'errors.notFound';
  static const String errorServer = 'errors.server';

  // Validation
  static const String validationRequired = 'validation.required';
  static const String validationEmail = 'validation.email';
  static const String validationPhone = 'validation.phone';
  static const String validationMinLength = 'validation.minLength';
  static const String validationMaxLength = 'validation.maxLength';
  static const String validationPasswordStrength = 'validation.passwordStrength';

  // App
  static const String appTitle = 'app.title';
  static const String appTagline = 'app.tagline';
}
```

#### `LocaleProvider`

```
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({required this.service, required this.config});

  Locale get currentLocale;
  List<Locale> get supportedLocales;
  Locale get defaultLocale;

  Future<void> initialize();
  void setLocale(Locale locale);
  void resetToSystemLocale();
}
```

- `initialize()` restores the persisted locale from Hive (if any), validates it against supported locales, and sets it as current. Falls back to system locale or default.
- `setLocale()` validates the locale is supported, updates the current locale, persists to Hive, and calls `notifyListeners()`.
- `resetToSystemLocale()` clears the persisted preference and falls back to the device locale.
- Throws `LocalizationException` if an unsupported locale is passed.

#### `HivorrSupportedLocales`

```
class HivorrSupportedLocales {
  HivorrSupportedLocales._();

  static const Locale defaultLocale = Locale('en');
  static const List<Locale> supported = [Locale('en')];

  static Locale resolve(Locale? deviceLocale, List<Locale?> supportedLocales);
}
```

- `resolve()` is the `localeResolutionCallback` for `MaterialApp`. Matches device language code against supported locales; falls back to `defaultLocale`.
- EP-02+ adds locales to the `supported` list as translation files are created.

#### `BuildContext` Extension (`localization_extension.dart`)

```
extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? params});
  String plural(String key, int count, {Map<String, String>? params});
  Locale get currentLocale;
  HivorrLocalizations get l10n;
}
```

- `tr()` delegates to `HivorrLocalizations.of(context).translate(key, params: params)`.
- `plural()` delegates to `HivorrLocalizations.of(context).plural(key, count, params: params)`.
- `l10n` returns the `HivorrLocalizations` instance.

#### `LocalizationConfig`

```
class LocalizationConfig {
  const LocalizationConfig({
    required this.defaultLocale,
    required this.fallbackLocale,
    required this.supportedLocales,
  });

  final Locale defaultLocale;
  final Locale fallbackLocale;
  final List<Locale> supportedLocales;
}
```

#### `LocalizationException`

```
class LocalizationException implements Exception {
  const LocalizationException(this.message, {this.key, this.locale});
  final String message;
  final String? key;
  final Locale? locale;
}
```

### 5.4 Translation File Format (`en.json`)

```json
{
  "common.ok": "OK",
  "common.cancel": "Cancel",
  "common.save": "Save",
  "common.delete": "Delete",
  "common.edit": "Edit",
  "common.done": "Done",
  "common.retry": "Retry",
  "common.loading": "Loading...",
  "common.error": "An error occurred",
  "common.success": "Success",
  "common.warning": "Warning",
  "common.noData": "No data available",
  "common.search": "Search",
  "common.close": "Close",
  "common.back": "Back",
  "common.next": "Next",
  "common.yes": "Yes",
  "common.no": "No",
  "common.itemCount.zero": "No items",
  "common.itemCount.one": "1 item",
  "common.itemCount.other": "{count} items",

  "auth.loginTitle": "Sign In",
  "auth.signupTitle": "Create Account",
  "auth.email": "Email Address",
  "auth.password": "Password",
  "auth.forgotPassword": "Forgot Password?",
  "auth.loginButton": "Sign In",
  "auth.signupButton": "Create Account",
  "auth.logoutButton": "Sign Out",
  "auth.noAccount": "Don't have an account?",
  "auth.hasAccount": "Already have an account?",

  "errors.generic": "Something went wrong. Please try again.",
  "errors.network": "No internet connection. Check your network and try again.",
  "errors.timeout": "The request timed out. Please try again.",
  "errors.unauthorized": "Your session has expired. Please sign in again.",
  "errors.notFound": "The requested resource was not found.",
  "errors.server": "A server error occurred. Please try again later.",

  "validation.required": "{field} is required",
  "validation.email": "Enter a valid email address",
  "validation.phone": "Enter a valid phone number",
  "validation.minLength": "{field} must be at least {min} characters",
  "validation.maxLength": "{field} must not exceed {max} characters",
  "validation.passwordStrength": "Password must be at least 8 characters with uppercase, lowercase, and number",

  "app.title": "Hivorr",
  "app.tagline": "Your world. Your way."
}
```

### 5.5 Pluralization Convention

Plural forms use suffixed keys: `{baseKey}.zero`, `{baseKey}.one`, `{baseKey}.two`, `{baseKey}.few`, `{baseKey}.many`, `{baseKey}.other`. The `other` form is **required** for every pluralizable key. All other forms are optional and fall back to `other`.

The engine uses `Intl.pluralLogic()` to select the correct form based on the count and the active locale's CLDR rules. For English, this resolves to `one` (count == 1) or `other` (everything else). For Arabic, all six forms would be used.

### 5.6 Parameter Interpolation Convention

Parameters use `{paramName}` syntax in translation values. The `interpolate()` method performs simple string replacement — no expression evaluation, no Dart code execution. This is safe for translator-authored content.

Example: `"validation.required": "{field} is required"` with `params: {'field': 'Email'}` → `"Email is required"`.

### 5.7 App Integration

#### `app.dart` modifications:

- Add `ChangeNotifierProvider<LocaleProvider>` to `MultiProvider`.
- Wire `MaterialApp.router` with:
  - `localizationsDelegates: [HivorrLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]`
  - `supportedLocales: HivorrSupportedLocales.supported`
  - `locale: localeProvider.currentLocale`
  - `localeResolutionCallback: HivorrSupportedLocales.resolve`

#### `app_bootstrap.dart` modifications:

- Initialize `LocaleProvider` (call `initialize()` to restore persisted locale).
- Pass `LocaleProvider` to `HivorrApp` alongside `AuthProvider`.

#### `pubspec.yaml` modifications:

- Add `flutter_localizations: sdk: flutter` to `dependencies`.
- Add `intl: ^0.20.0` to `dependencies` (pinned).
- Add `- assets/translations/` to `flutter.assets`.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `HivorrLocalizations` | `lib/core/localization/` | `LocalizationsDelegate` + translation access |
| `HivorrLocalizationService` | `lib/core/localization/` | JSON loading, key resolution, interpolation, pluralization |
| `TranslationKeys` | `lib/core/localization/` | Typed translation key constants |
| `LocaleProvider` | `lib/core/localization/` | Active locale state management + persistence |
| `HivorrSupportedLocales` | `lib/core/localization/` | Supported locale registry + resolution |
| `LocalizationExtension` | `lib/core/localization/` | `BuildContext` convenience accessor |
| `LocalizationConfig` | `lib/core/localization/` | Immutable configuration |
| `LocalizationException` | `lib/core/localization/` | Typed exception |
| `localization.dart` | `lib/core/localization/` | Barrel re-export |
| `en.json` | `assets/translations/` | English translation file |
| App integration | `lib/app/app.dart` | `MaterialApp.router` wiring |
| Bootstrap integration | `lib/app/app_bootstrap.dart` | `LocaleProvider` initialization |
| Dependency update | `pubspec.yaml` | `flutter_localizations`, `intl`, asset registration |
| Test suite | `test/unit/localization/`, `test/widget/localization/` | Unit + widget tests |

---

## 7. Data Requirements

No business, user, or domain data is introduced. The localization engine operates on:

- **Translation JSON files** — static assets bundled in the app binary. No user data.
- **Locale preference** — a single `String` (language code) persisted in Hive. No PII.
- **Translation keys and parameters** — primitive `String` and `Map<String, String>` values. Parameters are caller-controlled and never logged.

---

## 8. Database Considerations

**Not applicable.** This task does not interact with the Supabase database. Locale preference persistence uses the existing Hive local storage infrastructure (EP-01-11).

---

## 9. API Requirements

**Not applicable.** This task does not make API calls. Translation files are loaded from bundled assets, not fetched from a remote server.

---

## 10. User Interface Requirements

- **No UI widgets are created** — this is an infrastructure/engine task. The localization engine provides data to UI widgets; it does not render UI itself.
- **All user-facing strings in EP-02+ will use `context.tr(key)` or `context.plural(key, count)`** — no hardcoded strings in widgets.
- **Locale switching triggers full widget tree rebuild** — `MaterialApp` rebuilds with the new locale, causing all `Localizations.of()` lookups to resolve to the new locale's translations.
- **The engine supports RTL locales structurally** — `MaterialApp` automatically applies `TextDirection.rtl` when the active locale is RTL. RTL-specific layout adjustments are deferred to EP-08.

---

## 11. User Experience Considerations

- **Instant language switching:** Changing the locale via `LocaleProvider.setLocale()` triggers an immediate widget tree rebuild — no app restart required.
- **Persistent preference:** The user's language choice survives app restarts. Restored during bootstrap before the first frame renders.
- **Graceful degradation:** Missing translations never crash or show blank text. The fallback chain (active locale → English → key name) ensures the user always sees meaningful text.
- **System locale respect:** On first launch (no persisted preference), the engine matches the device locale against supported locales. If the device language is unsupported, it falls back to English.
- **Pluralization correctness:** Users see grammatically correct plural forms in their language — not hardcoded "1 item" / "N items" English-only patterns.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Secrets in translation files | Translation JSON files contain only user-facing UI strings. Static analysis scan confirms no secrets. |
| Injection via interpolation | Parameter interpolation uses simple string replacement — no expression evaluation, no `dart:mirrors`, no code execution. Parameters are `Map<String, String>` — caller controls content. |
| PII in locale persistence | Only a language code string (e.g., `"en"`) is persisted in Hive. No PII. |
| Translation file tampering | Assets are bundled in the signed app binary. Platform code signing prevents tampering. |
| Business logic in translations | Translation values are display strings only. No business rules, formulas, or operational logic. |
| Logging translation content | The engine does not log translation values or parameters. Only structural errors (missing file, malformed JSON) are logged. |

---

## 13. Performance Considerations

- **Asset loading is one-time per locale:** `rootBundle.loadString()` loads the JSON file once per locale. Flutter's asset bundle caches the result. Subsequent `load()` calls for the same locale hit the cache.
- **Translation map is O(1) lookup:** After loading, translations are stored in a `Map<String, String>`. Key resolution is a hash-map lookup — O(1).
- **Interpolation is O(n) string replacement:** Where n is the number of parameters. Typical translations have 0-3 parameters — negligible cost.
- **No rebuilds beyond locale change:** `LocaleProvider.notifyListeners()` fires only on explicit locale change. The widget tree does not rebuild on every `translate()` call.
- **Minimal memory footprint:** A typical `en.json` with 200 keys produces a `Map<String, String>` consuming ~10-20 KB. Negligible for the 15-20 MB installer budget.
- **No new native dependencies:** `flutter_localizations` and `intl` are pure Dart packages with no native code. Negligible impact on installer size.
- **Hive persistence is async and non-blocking:** Locale preference is written asynchronously — no UI jank on locale change.

---

## 14. Testing Strategy

### 14.1 Unit Tests — `HivorrLocalizationService`

- `loadTranslations()` loads `en.json` and returns a non-empty `Map<String, String>`.
- `loadTranslations()` throws `LocalizationException` for a non-existent locale file.
- `loadTranslations()` throws `LocalizationException` for malformed JSON.
- `resolve()` returns the correct value for an existing key.
- `resolve()` returns the fallback locale value when the key is missing in the active locale.
- `resolve()` returns the key name itself when missing in both active and fallback locales.
- `interpolate()` replaces a single `{param}` correctly.
- `interpolate()` replaces multiple `{param}` placeholders correctly.
- `interpolate()` returns the template unchanged when params map is empty or null.
- `interpolate()` leaves `{unknownParam}` placeholders unchanged when not in params map.
- `resolvePlural()` selects `.one` for count=1 (English).
- `resolvePlural()` selects `.other` for count=0, 2, 5, 100 (English).
- `resolvePlural()` selects `.zero` for count=0 when `.zero` key exists.
- `resolvePlural()` falls back to `.other` when specific plural form is missing.

### 14.2 Unit Tests — `TranslationKeys`

- All key constants are non-empty strings.
- All keys follow the `namespace.keyName` naming convention.
- No duplicate key values.
- All keys in `TranslationKeys` exist in `en.json` (cross-reference test).

### 14.3 Unit Tests — `LocaleProvider`

- `initialize()` restores a previously persisted locale.
- `initialize()` falls back to system locale when no preference is persisted.
- `initialize()` falls back to default locale when persisted locale is no longer supported.
- `setLocale()` updates `currentLocale` and notifies listeners.
- `setLocale()` persists the new locale.
- `setLocale()` throws `LocalizationException` for an unsupported locale.
- `resetToSystemLocale()` clears persisted preference and sets system locale.
- `notifyListeners()` fires exactly once per `setLocale()` call.

### 14.4 Unit Tests — `HivorrSupportedLocales`

- `supported` list contains at least `Locale('en')`.
- `defaultLocale` is `Locale('en')`.
- `resolve()` returns the matching locale for a supported device locale.
- `resolve()` returns `defaultLocale` for an unsupported device locale.
- `resolve()` returns `defaultLocale` when device locale is null.

### 14.5 Unit Tests — `LocalizationConfig`

- Constructor creates valid config with all required fields.
- Default and fallback locales are in the supported list.

### 14.6 Unit Tests — `LocalizationException`

- Exception message is preserved.
- Optional `key` and `locale` fields are preserved.
- `toString()` includes all available fields.

### 14.7 Widget Tests — `HivorrLocalizations` Delegate

- `HivorrLocalizations` loads successfully for `Locale('en')`.
- `isSupported()` returns `true` for `en`, `false` for unsupported locales.
- `shouldReload()` returns `true` when locale changes, `false` when same.
- `translate()` returns correct value for known keys.
- `translate()` with params returns interpolated value.
- `plural()` returns correct plural form for count=0, 1, 2.
- Widget tree rebuilds with new translations after locale change.

### 14.8 Widget Tests — `LocalizationExtension`

- `context.tr(key)` returns the correct translation.
- `context.tr(key, params: {...})` returns interpolated translation.
- `context.plural(key, count)` returns correct plural form.
- `context.currentLocale` returns the active locale.
- `context.l10n` returns the `HivorrLocalizations` instance.

### 14.9 Integration Test — `en.json` Validation

- `en.json` is valid JSON.
- All values are non-empty strings.
- All plural key groups have at least an `.other` form.
- All `{param}` placeholders in values are documented.

### 14.10 Project Validation

- `flutter analyze` — strict lints, no issues.
- `flutter test` — all new tests pass.
- Available platform smoke builds (Android, iOS, Web) — app compiles and renders with localization engine active.

### 14.11 Scope Validation

- Diff review: only `lib/core/localization/`, `assets/translations/`, `lib/app/app.dart`, `lib/app/app_bootstrap.dart`, `pubspec.yaml`, and `test/unit/localization/` + `test/widget/localization/` changes. No modifications to `lib/app/theme/`, `lib/shared/`, `lib/engine/`, `lib/systems/`, `lib/data/`, or any phase document.

---

## 15. Recommended Implementation Sequence

1. **Inspect existing deliverables:** Confirm `lib/core/localization/` contains only `.gitkeep`. Confirm `assets/translations/` contains only `.gitkeep`. Confirm `pubspec.yaml` does not already include `flutter_localizations` or `intl`. Confirm existing tests pass.
2. **Update `pubspec.yaml`:**
   - Add `flutter_localizations` (SDK) to `dependencies`.
   - Add `intl: ^0.20.0` (pinned) to `dependencies`.
   - Add `- assets/translations/` to `flutter.assets` section.
   - Run `flutter pub get` and verify clean resolution.
3. **Create `lib/core/localization/localization_exception.dart`** — typed exception (no dependencies).
4. **Create `lib/core/localization/localization_config.dart`** — immutable configuration (no dependencies).
5. **Create `lib/core/localization/supported_locales.dart`** — supported locale registry + resolution callback.
6. **Create `lib/core/localization/translation_keys.dart`** — typed key constants.
7. **Create `assets/translations/en.json`** — initial English translation file with all foundational keys.
8. **Create `lib/core/localization/localization_service.dart`** — JSON loader, key resolver, interpolation, pluralization engine.
9. **Create `lib/core/localization/hivorr_localizations.dart`** — `LocalizationsDelegate` + `HivorrLocalizations` class.
10. **Create `lib/core/localization/locale_provider.dart`** — `ChangeNotifier` for locale state + Hive persistence.
11. **Create `lib/core/localization/localization_extension.dart`** — `BuildContext` convenience accessor.
12. **Create `lib/core/localization/localization.dart`** — barrel re-export.
13. **Modify `lib/app/app_bootstrap.dart`** — initialize `LocaleProvider`, pass to `HivorrApp`.
14. **Modify `lib/app/app.dart`** — add `LocaleProvider` to `MultiProvider`, wire `MaterialApp.router` with localization delegates, supported locales, and locale from provider.
15. **Write unit tests** for `HivorrLocalizationService`, `TranslationKeys`, `LocaleProvider`, `HivorrSupportedLocales`, `LocalizationConfig`, `LocalizationException`.
16. **Write widget tests** for `HivorrLocalizations` delegate, `LocalizationExtension`, and locale switching.
17. **Write `en.json` validation test** — cross-reference all `TranslationKeys` against `en.json`.
18. **Run `flutter analyze`** and fix any lint issues.
19. **Run `flutter test`** and ensure all tests pass.
20. **Perform available platform smoke builds** (Android, iOS, Web).
21. **Review final diff** for strict EP-01-17 scope containment and phase-document integrity.
22. **Stop at the approval gate** — do not build feature screens, notifications, or additional translation files.

---

## 16. Expected Outcome

- A complete **localization engine** in `lib/core/localization/` — loading translations from `assets/translations/{code}.json`, with typed key access, ICU pluralization via `intl`, parameter interpolation, and fallback chain.
- **`LocaleProvider`** in `lib/core/localization/` — `ChangeNotifier` managing the active locale with Hive persistence, dynamic switching, and system locale fallback.
- **`TranslationKeys`** with ~40 foundational keys organized by namespace (common, auth, errors, validation, app).
- **`en.json`** in `assets/translations/` — complete English translation file covering all foundational keys.
- **`BuildContext` extension** providing `context.tr()`, `context.plural()`, `context.l10n` for ergonomic translation access.
- **App integration** — `MaterialApp.router` wired with localization delegates, supported locales, and `LocaleProvider`. Bootstrap initializes locale preference before first frame.
- **pubspec.yaml** updated with `flutter_localizations`, `intl`, and `assets/translations/` registration.
- **Comprehensive test suite** — unit tests for service, keys, provider, config, exception; widget tests for delegate, extension, and locale switching.
- **EP-02+ ready** — every future UI screen can use `context.tr(TranslationKeys.someKey)` for all user-facing text. Adding a new language requires only creating a new `{code}.json` file and adding the locale to `HivorrSupportedLocales`.

---

## 17. Definition of Done (DoD)

- [ ] `lib/core/localization/hivorr_localizations.dart` contains the `LocalizationsDelegate` and `HivorrLocalizations` class with `translate()` and `plural()` methods.
- [ ] `lib/core/localization/localization_service.dart` contains JSON loading, key resolution, parameter interpolation, and plural-form selection.
- [ ] `lib/core/localization/translation_keys.dart` contains all foundational typed key constants organized by namespace.
- [ ] `lib/core/localization/locale_provider.dart` contains `ChangeNotifier` with `setLocale()`, `resetToSystemLocale()`, Hive persistence, and system locale fallback.
- [ ] `lib/core/localization/supported_locales.dart` contains the supported locale registry and resolution callback.
- [ ] `lib/core/localization/localization_extension.dart` contains `BuildContext` extension with `tr()`, `plural()`, `l10n`, and `currentLocale`.
- [ ] `lib/core/localization/localization_config.dart` contains immutable configuration.
- [ ] `lib/core/localization/localization_exception.dart` contains typed exception.
- [ ] `lib/core/localization/localization.dart` barrel file re-exports all public APIs.
- [ ] `assets/translations/en.json` contains valid JSON with all foundational translation keys, including plural forms for `common.itemCount`.
- [ ] `pubspec.yaml` includes `flutter_localizations` (SDK), `intl` (pinned), and `assets/translations/` registration.
- [ ] `lib/app/app.dart` wires `MaterialApp.router` with localization delegates, supported locales, and `LocaleProvider`.
- [ ] `lib/app/app_bootstrap.dart` initializes `LocaleProvider` and passes it to `HivorrApp`.
- [ ] All `TranslationKeys` constants have corresponding entries in `en.json` (cross-reference test passes).
- [ ] `translate()` returns correct value for known keys with and without parameters.
- [ ] `plural()` returns correct plural form using `Intl.pluralLogic()` for count=0, 1, and N>1.
- [ ] Fallback chain works: missing key in active locale → fallback locale → key name.
- [ ] `LocaleProvider.setLocale()` updates locale, persists to Hive, and notifies listeners.
- [ ] `LocaleProvider.initialize()` restores persisted locale on startup.
- [ ] Unsupported locale passed to `setLocale()` throws `LocalizationException`.
- [ ] Widget tree rebuilds with new translations after locale change.
- [ ] Unit tests cover `HivorrLocalizationService`, `TranslationKeys`, `LocaleProvider`, `HivorrSupportedLocales`, `LocalizationConfig`, `LocalizationException`.
- [ ] Widget tests cover `HivorrLocalizations` delegate, `LocalizationExtension`, and locale switching.
- [ ] `en.json` validation test confirms valid JSON, non-empty values, and plural form completeness.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (Android, iOS, Web).
- [ ] No business logic, domain model, repository, security, monitoring, or notification code included.
- [ ] No modifications to `lib/app/theme/`, `lib/shared/`, `lib/engine/`, `lib/systems/`, `lib/data/`, or any phase document.
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, AGENT.md, and VISUAL-IDENTITY.md remain unchanged.
- [ ] Final diff contains only approved EP-01-17 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** High — building a localization engine requires precise understanding of Flutter's `LocalizationsDelegate` lifecycle, `MaterialApp` locale wiring, `Intl.pluralLogic()` CLDR plural rules, JSON asset loading, `ChangeNotifier` state propagation, and Hive persistence. The integration with `app.dart` and `app_bootstrap.dart` must not break the existing initialization sequence.
- **Business impact:** High — this is the localization infrastructure that every user-facing string in EP-02 through EP-08 flows through. Defects here (missing fallback, broken pluralization, lost locale preference) affect every screen. The typed key system establishes the discipline that prevents hardcoded strings project-wide.
- **Security risk:** Low — no data access, no API calls, no auth, no secrets. Translation files are static assets. Interpolation uses simple string replacement with no code execution.
- **Performance sensitivity:** Medium — translation lookups must be O(1). Locale switching must trigger a single widget tree rebuild, not cascading rebuilds. Asset loading must be one-time per locale.
- **Data complexity:** Low — translation data is flat `Map<String, String>`. Locale preference is a single string. No domain entities, no database, no API.
- **Integration complexity:** Medium — must correctly wire into `MaterialApp.router` (already configured in EP-01-15), integrate with `AppBootstrap.initialize()` (already configured in EP-01-15), and persist via Hive (EP-01-11). Must not modify any existing code outside `app.dart` and `app_bootstrap.dart`.

High reasoning matches the approved EP-01 matrix (EP-01-17 = High) and the breadth of integration points requiring precise, non-breaking implementation.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-17-Localization & Internationalization Engine.md` and implementation will begin only after a separate implementation approval. No production code is written during planning.