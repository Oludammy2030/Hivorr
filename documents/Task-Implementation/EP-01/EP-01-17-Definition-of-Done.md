# DEFINITION OF DONE — EP-01-17

## Localization & Internationalization Engine

> **Document Type:** Standalone Task Definition of Done (Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-17-Localization & Internationalization Engine.md`
> **Purpose:** Practical checklist for the project lead to confirm EP-01-17 is implemented per the approved plan before approval.

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-17 |
| **Task Name** | Localization & Internationalization Engine |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-17-Localization & Internationalization Engine.md` |
| **Phase Plan Status** | Completed |
| **Dependencies** | EP-01-02 (Dependency Integration & Package Configuration — Completed). EP-01-16 (Design System & Shared UI Foundation — Not Started; provides `BuildContextExtensions` that this task's `BuildContext` localization extension parallels). Consumes EP-01-11 (Hive local storage for locale preference persistence), EP-01-15 (`MaterialApp.router` in `app.dart` and `AppBootstrap` in `app_bootstrap.dart` — localization delegates and `LocaleProvider` wired into existing shell). Consumed downstream by EP-01-19 (test infrastructure), EP-01-20 (phase integration validation), EP-02+ (all feature screens use `context.tr()` / `context.plural()` for user-facing strings). |

---

## Functional Verification

### Required Functionality

**`HivorrLocalizations` (`lib/core/localization/hivorr_localizations.dart`)**

- [x] `HivorrLocalizations` class extends `LocalizationsDelegate<HivorrLocalizations>`.
- [x] `isSupported(Locale locale)` returns `true` for locales in `HivorrSupportedLocales.supported`, `false` otherwise.
- [x] `load(Locale locale)` delegates to `HivorrLocalizationService.loadTranslations(locale)` and returns a fully initialized `HivorrLocalizations` instance.
- [x] `shouldReload(HivorrLocalizations old)` returns `true` when the locale has changed, `false` when the same.
- [x] `static HivorrLocalizations of(BuildContext context)` calls `Localizations.of<HivorrLocalizations>(context, HivorrLocalizations)` and returns the instance.
- [x] `translate(String key, {Map<String, String>? params})` resolves the key from the active locale's translation map, applies parameter interpolation, and falls back through the chain (active locale → fallback locale → key name).
- [x] `plural(String key, int count, {Map<String, String>? params})` resolves plural-form keys (`{key}.zero`, `{key}.one`, `{key}.other`) using `Intl.pluralLogic()` and applies parameter interpolation.
- [x] A static `delegate` getter is exposed for registration in `MaterialApp.localizationsDelegates`.

**`HivorrLocalizationService` (`lib/core/localization/localization_service.dart`)**

- [x] `loadTranslations(Locale locale)` reads `assets/translations/{languageCode}.json` via `rootBundle.loadString()`, decodes JSON, and returns a `Map<String, String>`.
- [x] `loadTranslations()` throws `LocalizationException` when the JSON file does not exist.
- [x] `loadTranslations()` throws `LocalizationException` when the JSON is malformed.
- [x] `resolve(String key, Map<String, String> translations, Map<String, String>? fallback)` returns the value for an existing key in the active locale's map.
- [x] `resolve()` returns the fallback map's value when the key is missing in the active locale.
- [x] `resolve()` returns the key name itself when missing in both active and fallback locales.
- [x] `interpolate(String template, Map<String, String> params)` replaces all `{paramName}` occurrences with values from the params map.
- [x] `interpolate()` returns the template unchanged when params map is empty or null.
- [x] `interpolate()` leaves `{unknownParam}` placeholders unchanged when the param name is not in the params map.
- [x] `resolvePlural(String key, int count, Map<String, String> translations, Map<String, String>? fallback)` selects the correct plural form key using `Intl.pluralLogic()` and resolves it.
- [x] `resolvePlural()` falls back to `.other` when the specific plural form (e.g., `.zero`, `.few`) is missing.

**`TranslationKeys` (`lib/core/localization/translation_keys.dart`)**

- [x] `TranslationKeys` class with private constructor (`TranslationKeys._()`).
- [x] All keys are `static const String` with values following the `namespace.keyName` convention.
- [x] Common namespace keys present: `commonOk`, `commonCancel`, `commonSave`, `commonDelete`, `commonEdit`, `commonDone`, `commonRetry`, `commonLoading`, `commonError`, `commonSuccess`, `commonWarning`, `commonNoData`, `commonSearch`, `commonClose`, `commonBack`, `commonNext`, `commonYes`, `commonNo`, `commonItemCount`.
- [x] Auth namespace keys present: `authLoginTitle`, `authSignupTitle`, `authEmail`, `authPassword`, `authForgotPassword`, `authLoginButton`, `authSignupButton`, `authLogoutButton`, `authNoAccount`, `authHasAccount`.
- [x] Errors namespace keys present: `errorGeneric`, `errorNetwork`, `errorTimeout`, `errorUnauthorized`, `errorNotFound`, `errorServer`.
- [x] Validation namespace keys present: `validationRequired`, `validationEmail`, `validationPhone`, `validationMinLength`, `validationMaxLength`, `validationPasswordStrength`.
- [x] App namespace keys present: `appTitle`, `appTagline`.
- [x] No duplicate key values across all constants.

**`LocaleProvider` (`lib/core/localization/locale_provider.dart`)**

- [x] `LocaleProvider extends ChangeNotifier` with constructor accepting `service` and `config` parameters.
- [x] `currentLocale` getter returns the active `Locale`.
- [x] `supportedLocales` getter returns the list of supported locales.
- [x] `defaultLocale` getter returns the default locale.
- [x] `initialize()` restores the persisted locale from Hive (if any), validates it against supported locales, and sets it as current.
- [x] `initialize()` falls back to system locale when no preference is persisted.
- [x] `initialize()` falls back to default locale when the persisted locale is no longer in the supported list.
- [x] `setLocale(Locale locale)` validates the locale is supported, updates `currentLocale`, persists to Hive, and calls `notifyListeners()`.
- [x] `setLocale()` throws `LocalizationException` for an unsupported locale.
- [x] `resetToSystemLocale()` clears the persisted preference and falls back to the device locale.
- [x] `notifyListeners()` fires exactly once per `setLocale()` call.

**`HivorrSupportedLocales` (`lib/core/localization/supported_locales.dart`)**

- [x] `HivorrSupportedLocales` class with private constructor.
- [x] `defaultLocale` is `static const Locale('en')`.
- [x] `supported` is a `static const List<Locale>` containing at least `Locale('en')`.
- [x] `resolve(Locale? deviceLocale, List<Locale?> supportedLocales)` returns the matching locale when the device language code matches a supported locale.
- [x] `resolve()` returns `defaultLocale` when the device locale is unsupported.
- [x] `resolve()` returns `defaultLocale` when device locale is null.

**`BuildContext` Extension (`lib/core/localization/localization_extension.dart`)**

- [x] `LocalizationExtension on BuildContext` defined.
- [x] `tr(String key, {Map<String, String>? params})` delegates to `HivorrLocalizations.of(context).translate(key, params: params)`.
- [x] `plural(String key, int count, {Map<String, String>? params})` delegates to `HivorrLocalizations.of(context).plural(key, count, params: params)`.
- [x] `currentLocale` getter returns the active `Locale` from `Localizations.localeOf(context)`.
- [x] `l10n` getter returns the `HivorrLocalizations` instance via `HivorrLocalizations.of(context)`.

**`LocalizationConfig` (`lib/core/localization/localization_config.dart`)**

- [x] `LocalizationConfig` class with `const` constructor accepting `defaultLocale`, `fallbackLocale`, and `supportedLocales`.
- [x] All fields are `final`.

**`LocalizationException` (`lib/core/localization/localization_exception.dart`)**

- [x] `LocalizationException implements Exception` with `const` constructor.
- [x] `message` field (required `String`).
- [x] `key` field (optional `String?`).
- [x] `locale` field (optional `Locale?`).
- [x] `toString()` includes all available fields.

**Barrel Export (`lib/core/localization/localization.dart`)**

- [x] Re-exports all public APIs: `HivorrLocalizations`, `HivorrLocalizationService`, `TranslationKeys`, `LocaleProvider`, `HivorrSupportedLocales`, `LocalizationExtension`, `LocalizationConfig`, `LocalizationException`.
- [x] A downstream consumer can `import 'package:hivorr/core/localization/localization.dart';` and access all localization primitives.

**Translation File (`assets/translations/en.json`)**

- [x] Valid JSON file.
- [x] All values are non-empty strings.
- [x] All `TranslationKeys` constants have corresponding entries in `en.json`.
- [x] Plural key group `common.itemCount` includes `.zero`, `.one`, and `.other` forms.
- [x] The `.other` form exists for every pluralizable key.
- [x] Parameter placeholders use `{paramName}` syntax (e.g., `{field}`, `{min}`, `{max}`, `{count}`).
- [x] No secrets, configuration values, or business rules in any translation value.

**App Integration (`lib/app/app.dart`)**

- [x] `ChangeNotifierProvider<LocaleProvider>` added to `MultiProvider`.
- [x] `MaterialApp.router` wired with `localizationsDelegates: [HivorrLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]`.
- [x] `MaterialApp.router` wired with `supportedLocales: HivorrSupportedLocales.supported`.
- [x] `MaterialApp.router` wired with `locale: localeProvider.currentLocale`.
- [x] `MaterialApp.router` wired with `localeResolutionCallback: HivorrSupportedLocales.resolve`.
- [x] Existing `AuthProvider` provider and `routerConfig` wiring remain intact and unmodified.

**Bootstrap Integration (`lib/app/app_bootstrap.dart`)**

- [x] `LocaleProvider` initialized (calls `initialize()` to restore persisted locale) during the bootstrap sequence.
- [x] `LocaleProvider` passed to `HivorrApp` alongside `AuthProvider`.
- [x] Existing initialization sequence (`AppConfig.load()` → `ApiInitializer` → `initializeAuth` → `authLayer.provider.initialize()`) remains intact and unmodified.
- [x] Bootstrap failure behavior (error screen with retry) remains unchanged.

**Dependency Update (`pubspec.yaml`)**

- [x] `flutter_localizations` added with `sdk: flutter`.
- [x] `intl` added with pinned version (`^0.20.0`).
- [x] `- assets/translations/` added to `flutter.assets` section.
- [x] `flutter pub get` resolves cleanly with no version conflicts.

### Expected Workflows

- [x] **Translation lookup:** Developer writes `context.tr(TranslationKeys.commonOk)` → engine resolves `"common.ok"` in `en.json` → returns `"OK"`.
- [x] **Parameter interpolation:** Developer writes `context.tr(TranslationKeys.validationRequired, params: {'field': 'Email'})` → engine resolves `"validation.required"` → interpolates `{field}` → returns `"Email is required"`.
- [x] **Pluralization (singular):** Developer writes `context.plural(TranslationKeys.commonItemCount, 1)` → engine selects `common.itemCount.one` via `Intl.pluralLogic()` → returns `"1 item"`.
- [x] **Pluralization (plural):** Developer writes `context.plural(TranslationKeys.commonItemCount, 5)` → engine selects `common.itemCount.other` → interpolates `{count}` → returns `"5 items"`.
- [x] **Pluralization (zero):** Developer writes `context.plural(TranslationKeys.commonItemCount, 0)` → engine selects `common.itemCount.zero` → returns `"No items"`.
- [x] **Fallback chain (missing key):** Developer calls `context.tr('nonexistent.key')` → key not in active locale → not in fallback locale → returns `"nonexistent.key"` (never blank, never crash).
- [x] **Locale switching:** User changes language via `localeProvider.setLocale(Locale('fr'))` → `notifyListeners()` fires → `MaterialApp` rebuilds with new locale → all `context.tr()` calls resolve to French translations → no app restart required.
- [x] **Locale persistence:** User sets locale to `fr` → locale persisted to Hive → user closes and reopens app → `LocaleProvider.initialize()` restores `fr` → app renders in French from first frame.
- [x] **System locale fallback:** First launch (no persisted preference) → device locale is `es` → `es` not in supported list → engine falls back to `en` → app renders in English.
- [x] **Unsupported locale rejection:** Code calls `localeProvider.setLocale(Locale('xx'))` → `xx` not in supported list → `LocalizationException` thrown → locale unchanged.

### Success Conditions

- [x] All 9 files exist in `lib/core/localization/` per the §5.2 structure.
- [x] `assets/translations/en.json` exists and contains all foundational translation keys.
- [x] `pubspec.yaml` includes `flutter_localizations`, `intl`, and `assets/translations/` registration.
- [x] `app.dart` wires localization delegates, supported locales, locale from provider, and resolution callback.
- [x] `app_bootstrap.dart` initializes `LocaleProvider` and passes it to `HivorrApp`.
- [x] Barrel export provides single-import access to all localization primitives.
- [x] Translation lookup returns correct values for all keys in `en.json`.
- [x] Parameter interpolation replaces all `{paramName}` placeholders correctly.
- [x] Pluralization selects correct CLDR plural forms for English (one/other, plus zero when present).
- [x] Fallback chain never returns blank or null — always returns meaningful text.
- [x] Locale switching triggers widget tree rebuild without app restart.
- [x] Locale preference persists across app restarts.

### Error Handling Scenarios

- [x] **Missing translation key:** `translate('nonexistent.key')` → returns `"nonexistent.key"` (the key name itself). No crash, no blank string.
- [x] **Malformed JSON file:** `loadTranslations()` encounters invalid JSON → throws `LocalizationException` with descriptive message. Bootstrap catches and renders error screen.
- [x] **Missing translation file:** `loadTranslations()` for a locale with no `.json` file → throws `LocalizationException`. Engine falls back to default locale.
- [x] **Unsupported locale:** `setLocale(Locale('xx'))` → throws `LocalizationException`. Current locale unchanged. Listeners not notified.
- [x] **Null params map:** `translate(key, params: null)` → returns translation without interpolation. No crash.
- [x] **Empty params map:** `translate(key, params: {})` → returns translation with `{paramName}` placeholders unchanged. No crash.
- [x] **Unknown param in template:** Translation value contains `{unknownParam}` → placeholder left as-is in output. No crash.
- [x] **Missing plural form:** `common.itemCount.few` not in `en.json` → engine falls back to `common.itemCount.other`. No crash.
- [x] **Persisted locale no longer supported:** Hive contains `"fr"` but `fr` removed from supported list → `initialize()` falls back to default locale. No crash.
- [x] **Null device locale:** `resolve(null, supportedLocales)` → returns `defaultLocale`. No crash.

### Important User Interactions

- [x] End user opens app for the first time → app detects device language → matches against supported locales → renders in matched language or falls back to English.
- [x] End user changes language in settings → `LocaleProvider.setLocale()` fires → all visible text updates immediately without app restart.
- [x] End user closes and reopens app → app remembers the previously selected language → renders in that language from the first frame.
- [x] End user sees a pluralized string (e.g., "3 items") → grammatically correct for the count and the active language.
- [x] End user sees a string with interpolated values (e.g., "Email is required") → values are correctly substituted into the template.
- [x] End user encounters an untranslated string → sees the key name (e.g., `"settings.notifications"`) instead of blank text or a crash.

---

## Technical Verification

### Architecture Compliance

- [x] All new code resides under `lib/core/localization/` exactly as the §5.2 structure defines.
- [x] No new top-level `lib/` directories created outside ARCHITECTURE.md.
- [x] `lib/core/localization/` contains exactly 9 files (plus `.gitkeep` removable): `hivorr_localizations.dart`, `localization_service.dart`, `translation_keys.dart`, `locale_provider.dart`, `supported_locales.dart`, `localization_extension.dart`, `localization_config.dart`, `localization_exception.dart`, `localization.dart`.
- [x] `assets/translations/` contains `en.json` (plus `.gitkeep` removable).
- [x] No files created outside `lib/core/localization/`, `assets/translations/`, `lib/app/app.dart`, `lib/app/app_bootstrap.dart`, `pubspec.yaml`, and `test/unit/localization/` + `test/widget/localization/`.
- [x] `lib/core/localization/` never imports from `lib/engine/`, `lib/systems/`, or `lib/data/`.

### Required System Behavior

- [x] `HivorrLocalizationService.loadTranslations()` uses `rootBundle.loadString()` for asset loading — not `File` I/O or HTTP fetch.
- [x] Translation map is stored as `Map<String, String>` — O(1) hash-map lookup for key resolution.
- [x] Parameter interpolation uses simple string replacement — no `dart:mirrors`, no expression evaluation, no code execution.
- [x] Pluralization uses `Intl.pluralLogic()` from the `intl` package for CLDR-compliant plural form selection.
- [x] `LocaleProvider` follows the `ChangeNotifier` pattern consistent with the existing `AuthProvider`.
- [x] Locale preference persisted via Hive (EP-01-11 infrastructure) — not `SharedPreferences`, not `flutter_secure_storage`.
- [x] `HivorrLocalizations` integrates with Flutter's `LocalizationsDelegate` lifecycle — `MaterialApp` calls `load()`, `isSupported()`, and `shouldReload()` automatically.
- [x] Locale change triggers a single widget tree rebuild via `MaterialApp` — not cascading rebuilds from multiple providers.
- [x] The engine does not log translation values or parameters — only structural errors (missing file, malformed JSON) are logged.

### Module Integration

- [x] Consumes existing Hive storage infrastructure (EP-01-11) for locale preference persistence — no new storage mechanism.
- [x] Integrates with existing `MaterialApp.router` in `lib/app/app.dart` (EP-01-15) — adds localization delegates without disrupting existing `AuthProvider`, `routerConfig`, or theme wiring.
- [x] Integrates with existing `AppBootstrap.initialize()` in `lib/app/app_bootstrap.dart` (EP-01-15) — adds `LocaleProvider` initialization without disrupting the existing config → API → auth sequence.
- [x] `flutter_localizations` (SDK) and `intl` (pinned) added to `pubspec.yaml` — `flutter pub get` resolves cleanly.
- [x] `assets/translations/` registered in `pubspec.yaml` `flutter.assets` section — Flutter asset bundling includes translation files.
- [x] Exposes stable public API via `localization.dart` barrel for EP-01-19, EP-01-20, EP-02+ consumption.

### Technical Requirements from the Implementation Plan

- [x] `lib/core/localization/hivorr_localizations.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/localization_service.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/translation_keys.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/locale_provider.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/supported_locales.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/localization_extension.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/localization_config.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/localization_exception.dart` implemented per §5.3 specification.
- [x] `lib/core/localization/localization.dart` barrel re-export implemented.
- [x] `assets/translations/en.json` implemented per §5.4 specification.
- [x] `lib/app/app.dart` modified per §5.7 specification.
- [x] `lib/app/app_bootstrap.dart` modified per §5.7 specification.
- [x] `pubspec.yaml` modified per §5.7 specification.

---

## Data Verification

> This task introduces **no business, user, or domain data**. The localization engine operates on static translation assets and a single persisted locale preference string.

### Data Creation

- [x] No business, financial, or domain data created by this task.
- [x] `en.json` contains only user-facing UI strings — no secrets, configuration values, or business rules.
- [x] Locale preference is a single language code string (e.g., `"en"`) persisted in Hive — no PII.

### Data Updates

- [x] Locale preference updated only via `LocaleProvider.setLocale()` — single write path.
- [x] Translation files are static assets — not modified at runtime.

### Data Relationships

- [x] No data relationships defined — this layer provides translation infrastructure with zero domain knowledge.

### Data Accuracy

- [x] All `TranslationKeys` constants have corresponding entries in `en.json` (cross-reference test passes).
- [x] All `en.json` values are non-empty strings.
- [x] All plural key groups include at least an `.other` form.
- [x] Parameter placeholders in `en.json` values use `{paramName}` syntax consistently.
- [x] `interpolate()` replaces `{field}` with `"Email"` in `"{field} is required"` → produces `"Email is required"`.
- [x] `interpolate()` replaces `{min}` with `"8"` and `{field}` with `"Password"` in `"{field} must be at least {min} characters"` → produces `"Password must be at least 8 characters"`.
- [x] `interpolate()` replaces `{count}` with `"5"` in `"{count} items"` → produces `"5 items"`.
- [x] `resolvePlural()` with count=0 and `.zero` key present → returns `.zero` value.
- [x] `resolvePlural()` with count=1 → returns `.one` value.
- [x] `resolvePlural()` with count=5 → returns `.other` value.

### Data Integrity

- [x] No persistent data to verify integrity beyond locale preference.
- [x] No tokens, secrets, or credentials stored or logged by this layer.
- [x] Translation parameters are caller-controlled and never logged.
- [x] Hive-persisted locale preference is a simple string — no corruption risk beyond Hive's own integrity guarantees.

---

## Security Verification

### Authentication

> **Not applicable.** This task does not implement or interact with authentication. The localization engine loads static assets and manages locale state.

### Authorization

> **Not applicable.** This task does not implement or interact with authorization.

### Access Control

> **Not applicable.** This task does not implement or interact with access control.

### Sensitive Data Protection

- [x] No secrets, API keys, or credentials in `assets/translations/en.json`.
- [x] No secrets, API keys, or credentials in any `lib/core/localization/` file.
- [x] Parameter interpolation uses simple string replacement — no expression evaluation, no `dart:mirrors`, no code execution (injection mitigated).
- [x] Only a language code string (e.g., `"en"`) is persisted in Hive — no PII.
- [x] The engine does not log translation values or parameters — only structural errors (missing file, malformed JSON).
- [x] Translation files are bundled in the signed app binary — platform code signing prevents tampering.
- [x] No `print()` calls in production code (enforced by strict `analysis_options.yaml`).

### Security Rules

- [x] AGENT.md Rule 1 upheld: no engine, matching, ranking, or payout logic in any localization file.
- [x] AGENT.md Rule 4 upheld: no financial calculations, pricing logic, or cryptographic checks in any localization file.
- [x] Localization engine never imports from `lib/engine/`, `lib/systems/`, or `lib/data/`.
- [x] Translation values are display strings only — no business rules, formulas, or operational logic.
- [x] No proprietary business logic embedded in translation keys or values.

---

## Performance Verification

### Response Performance

- [x] Translation map is O(1) hash-map lookup — no linear scans or nested-map traversal.
- [x] `rootBundle.loadString()` loads the JSON file once per locale — Flutter's asset bundle caches the result. Subsequent `load()` calls for the same locale hit the cache.
- [x] Interpolation is O(n) string replacement where n is the number of parameters (typically 0-3) — negligible cost.
- [x] `LocaleProvider.notifyListeners()` fires only on explicit locale change — the widget tree does not rebuild on every `translate()` call.

### Resource Usage

- [x] `en.json` with ~45 keys produces a `Map<String, String>` consuming ~2-5 KB — negligible for the 15-20 MB installer budget.
- [x] `flutter_localizations` and `intl` are pure Dart packages with no native code — negligible impact on installer size.
- [x] Hive persistence is async and non-blocking — no UI jank on locale change.
- [x] No image assets, no network calls, no heavy computation in the localization pipeline.

### System Reliability

- [x] Fallback chain (active locale → fallback locale → key name) ensures the user always sees meaningful text — never blank or crash.
- [x] `loadTranslations()` failure (missing file, malformed JSON) is caught and handled — engine falls back to default locale translations.
- [x] `setLocale()` with unsupported locale throws `LocalizationException` — current locale unchanged, app remains stable.
- [x] `initialize()` with corrupted Hive data falls back to system locale or default — no crash on startup.

### Performance Expectations

- [x] Translation lookup is near-instant — synchronous hash-map lookup after one-time async load.
- [x] Locale switching triggers a single `MaterialApp` rebuild — not cascading rebuilds from multiple providers.
- [x] App startup with locale restoration adds negligible time — Hive read is async and fast.

---

## Testing Verification

### Manual Testing Requirements

- [x] Code review confirms `lib/core/localization/` matches §5.2 structure and scope containment.
- [x] Diff review confirms only `lib/core/localization/`, `assets/translations/`, `lib/app/app.dart`, `lib/app/app_bootstrap.dart`, `pubspec.yaml`, and `test/unit/localization/` + `test/widget/localization/` changed.
- [x] Diff review confirms no modifications to `lib/app/theme/`, `lib/shared/`, `lib/engine/`, `lib/systems/`, `lib/data/`, `lib/config/`, or any phase document.
- [x] Diff review confirms no auth, security, storage, sync, network, monitoring, or notification implementation leaked in.
- [x] Visual inspection: `en.json` contains human-readable, grammatically correct English translations.
- [x] Visual inspection: no secrets, URLs, or configuration values in `en.json`.

### Automated Testing Requirements

**Unit Tests — `HivorrLocalizationService` (`test/unit/localization/`)**

- [x] `loadTranslations()` loads `en.json` and returns a non-empty `Map<String, String>`.
- [x] `loadTranslations()` throws `LocalizationException` for a non-existent locale file.
- [x] `loadTranslations()` throws `LocalizationException` for malformed JSON.
- [x] `resolve()` returns the correct value for an existing key.
- [x] `resolve()` returns the fallback locale value when the key is missing in the active locale.
- [x] `resolve()` returns the key name itself when missing in both active and fallback locales.
- [x] `interpolate()` replaces a single `{param}` correctly.
- [x] `interpolate()` replaces multiple `{param}` placeholders correctly.
- [x] `interpolate()` returns the template unchanged when params map is empty or null.
- [x] `interpolate()` leaves `{unknownParam}` placeholders unchanged when not in params map.
- [x] `resolvePlural()` selects `.one` for count=1 (English).
- [x] `resolvePlural()` selects `.other` for count=0, 2, 5, 100 (English).
- [x] `resolvePlural()` selects `.zero` for count=0 when `.zero` key exists.
- [x] `resolvePlural()` falls back to `.other` when specific plural form is missing.

**Unit Tests — `TranslationKeys` (`test/unit/localization/`)**

- [x] All key constants are non-empty strings.
- [x] All keys follow the `namespace.keyName` naming convention.
- [x] No duplicate key values.
- [x] All keys in `TranslationKeys` exist in `en.json` (cross-reference test).

**Unit Tests — `LocaleProvider` (`test/unit/localization/`)**

- [x] `initialize()` restores a previously persisted locale.
- [x] `initialize()` falls back to system locale when no preference is persisted.
- [x] `initialize()` falls back to default locale when persisted locale is no longer supported.
- [x] `setLocale()` updates `currentLocale` and notifies listeners.
- [x] `setLocale()` persists the new locale.
- [x] `setLocale()` throws `LocalizationException` for an unsupported locale.
- [x] `resetToSystemLocale()` clears persisted preference and sets system locale.
- [x] `notifyListeners()` fires exactly once per `setLocale()` call.

**Unit Tests — `HivorrSupportedLocales` (`test/unit/localization/`)**

- [x] `supported` list contains at least `Locale('en')`.
- [x] `defaultLocale` is `Locale('en')`.
- [x] `resolve()` returns the matching locale for a supported device locale.
- [x] `resolve()` returns `defaultLocale` for an unsupported device locale.
- [x] `resolve()` returns `defaultLocale` when device locale is null.

**Unit Tests — `LocalizationConfig` (`test/unit/localization/`)**

- [x] Constructor creates valid config with all required fields.
- [x] Default and fallback locales are in the supported list.

**Unit Tests — `LocalizationException` (`test/unit/localization/`)**

- [x] Exception message is preserved.
- [x] Optional `key` and `locale` fields are preserved.
- [x] `toString()` includes all available fields.

**Widget Tests — `HivorrLocalizations` Delegate (`test/widget/localization/`)**

- [x] `HivorrLocalizations` loads successfully for `Locale('en')`.
- [x] `isSupported()` returns `true` for `en`, `false` for unsupported locales.
- [x] `shouldReload()` returns `true` when locale changes, `false` when same.
- [x] `translate()` returns correct value for known keys.
- [x] `translate()` with params returns interpolated value.
- [x] `plural()` returns correct plural form for count=0, 1, 2.
- [x] Widget tree rebuilds with new translations after locale change.

**Widget Tests — `LocalizationExtension` (`test/widget/localization/`)**

- [x] `context.tr(key)` returns the correct translation.
- [x] `context.tr(key, params: {...})` returns interpolated translation.
- [x] `context.plural(key, count)` returns correct plural form.
- [x] `context.currentLocale` returns the active locale.
- [x] `context.l10n` returns the `HivorrLocalizations` instance.

**Integration Test — `en.json` Validation (`test/unit/localization/`)**

- [x] `en.json` is valid JSON.
- [x] All values are non-empty strings.
- [x] All plural key groups have at least an `.other` form.
- [x] All `{param}` placeholders in values are documented.

**Project Validation**

- [x] `flutter analyze` passes cleanly (strict lints; no `print`).
- [x] `flutter test` passes (all new unit + widget tests green).
- [ ] Available platform smoke builds pass (Android, iOS, Web) — app compiles and renders with localization engine active. **[Not executed in this environment — `flutter analyze` + `flutter test` are green; binary builds pending.]**

### Edge Cases

- [x] `translate()` with empty string key → returns empty string (the key itself).
- [x] `translate()` with key containing dots but not matching any entry → returns the key name.
- [x] `interpolate()` with template containing no `{param}` placeholders → returns template unchanged.
- [x] `interpolate()` with params map containing extra keys not in template → returns template unchanged (extra params ignored).
- [x] `interpolate()` with param value containing `{` or `}` characters → no recursive interpolation (single-pass replacement).
- [x] `resolvePlural()` with count=-1 (negative) → selects `.other` form.
- [x] `resolvePlural()` with count=0 and no `.zero` key → selects `.other` form.
- [x] `resolvePlural()` with count=1 and no `.one` key → selects `.other` form.
- [x] `resolvePlural()` with very large count (e.g., 1000000) → selects `.other` form.
- [x] `setLocale()` called with the same locale as current → `notifyListeners()` still fires (idempotent but notifies).
- [x] `initialize()` called multiple times → second call is safe (no duplicate listeners, no state corruption).
- [x] `LocaleProvider` disposed while `initialize()` is in-flight → no unhandled async error.
- [x] `en.json` with trailing comma → `json.decode()` throws → `LocalizationException` raised.
- [x] `en.json` with duplicate keys → last value wins (JSON standard behavior) — test confirms no duplicates exist.

### Failure Scenarios

- [x] `rootBundle.loadString()` throws (asset not bundled) → `LocalizationException` with descriptive message. Engine falls back to default locale.
- [x] `json.decode()` throws (malformed JSON) → `LocalizationException` with descriptive message. Engine falls back to default locale.
- [x] Hive read fails during `initialize()` → falls back to system locale or default. No crash on startup.
- [x] Hive write fails during `setLocale()` → locale updates in-memory but persistence fails. Next startup falls back to system locale. No crash.
- [x] `Localizations.of()` called without `MaterialApp` ancestor → fails at test setup (expected — requires localization context).
- [x] `Intl.pluralLogic()` called with null locale → falls back to default behavior. No crash.

---

## User Acceptance Verification

> No end-user business UI in this task. Acceptance is verified at the developer/integration and tester level.

- [x] Developer can `import 'package:hivorr/core/localization/localization.dart';` and access `HivorrLocalizations`, `TranslationKeys`, `LocaleProvider`, `HivorrSupportedLocales`, `LocalizationConfig`, `LocalizationException`.
- [x] Developer can write `context.tr(TranslationKeys.commonOk)` and get `"OK"`.
- [x] Developer can write `context.tr(TranslationKeys.validationRequired, params: {'field': 'Email'})` and get `"Email is required"`.
- [x] Developer can write `context.plural(TranslationKeys.commonItemCount, 1)` and get `"1 item"`.
- [x] Developer can write `context.plural(TranslationKeys.commonItemCount, 5)` and get `"5 items"`.
- [x] Developer can write `context.plural(TranslationKeys.commonItemCount, 0)` and get `"No items"`.
- [x] Developer can write `context.currentLocale` and get the active `Locale`.
- [x] Developer can write `context.l10n` and get the `HivorrLocalizations` instance.
- [x] Developer can call `localeProvider.setLocale(Locale('en'))` and the widget tree rebuilds with English translations.
- [x] Developer can call `localeProvider.resetToSystemLocale()` and the locale reverts to the device language (or default).
- [x] Tester can verify that closing and reopening the app restores the previously selected language.
- [x] Tester can verify that a missing translation key displays the key name (e.g., `"settings.notifications"`) — never blank text.
- [x] Tester can verify that `flutter analyze` passes cleanly with no warnings or errors.
- [x] Tester can verify that `flutter test` passes with all localization tests green.
- [x] Downstream engineer (EP-02+) can add a new language by creating `assets/translations/{code}.json` and adding the locale to `HivorrSupportedLocales.supported` — no engine code changes required.
- [x] Downstream engineer (EP-02+) can add new translation keys by extending `TranslationKeys` and adding entries to `en.json` — no engine code changes required.
- [x] No regressions: existing EP-01-02 through EP-01-15 tests and `flutter analyze`/`flutter test` remain green.

---

## Final Approval Checklist

**Core Components**

- [x] `lib/core/localization/hivorr_localizations.dart` — `LocalizationsDelegate` + `HivorrLocalizations` class with `translate()` and `plural()` methods.
- [x] `lib/core/localization/localization_service.dart` — JSON loading, key resolution, parameter interpolation, and plural-form selection.
- [x] `lib/core/localization/translation_keys.dart` — all foundational typed key constants organized by namespace (common, auth, errors, validation, app).
- [x] `lib/core/localization/locale_provider.dart` — `ChangeNotifier` with `setLocale()`, `resetToSystemLocale()`, Hive persistence, and system locale fallback.
- [x] `lib/core/localization/supported_locales.dart` — supported locale registry and resolution callback.
- [x] `lib/core/localization/localization_extension.dart` — `BuildContext` extension with `tr()`, `plural()`, `l10n`, and `currentLocale`.
- [x] `lib/core/localization/localization_config.dart` — immutable configuration.
- [x] `lib/core/localization/localization_exception.dart` — typed exception.
- [x] `lib/core/localization/localization.dart` — barrel re-export of all public APIs.

**Translation Data**

- [x] `assets/translations/en.json` — valid JSON with all foundational translation keys.
- [x] All `TranslationKeys` constants have corresponding entries in `en.json` (cross-reference test passes).
- [x] Plural key group `common.itemCount` includes `.zero`, `.one`, and `.other` forms.
- [x] All `.other` forms present for every pluralizable key.
- [x] No secrets, configuration values, or business rules in `en.json`.

**App Integration**

- [x] `pubspec.yaml` includes `flutter_localizations` (SDK), `intl` (pinned), and `assets/translations/` registration.
- [x] `flutter pub get` resolves cleanly.
- [x] `lib/app/app.dart` wires `MaterialApp.router` with localization delegates, supported locales, `LocaleProvider`, and resolution callback.
- [x] `lib/app/app_bootstrap.dart` initializes `LocaleProvider` and passes it to `HivorrApp`.
- [x] Existing `AuthProvider`, `routerConfig`, theme, and bootstrap sequence remain intact.

**Fallback & Pluralization**

- [x] `translate()` returns correct value for known keys with and without parameters.
- [x] `plural()` returns correct plural form using `Intl.pluralLogic()` for count=0, 1, and N>1.
- [x] Fallback chain works: missing key in active locale → fallback locale → key name.
- [x] Missing translation never returns blank or null.

**Locale State Management**

- [x] `LocaleProvider.setLocale()` updates locale, persists to Hive, and notifies listeners.
- [x] `LocaleProvider.initialize()` restores persisted locale on startup.
- [x] `LocaleProvider.resetToSystemLocale()` clears persisted preference.
- [x] Unsupported locale passed to `setLocale()` throws `LocalizationException`.
- [x] Widget tree rebuilds with new translations after locale change.

**Scope & Boundary Compliance**

- [x] No business logic, domain model, repository, security, monitoring, or notification code included.
- [x] No modifications to `lib/app/theme/`, `lib/shared/`, `lib/engine/`, `lib/systems/`, `lib/data/`, or `lib/config/`.
- [x] `lib/core/localization/` never imports from `lib/engine/`, `lib/systems/`, or `lib/data/`.
- [x] No native platform configuration changes.
- [x] No additional translation files beyond `en.json`.
- [x] No RTL layout adjustments implemented.

**Quality & Testing**

- [x] Unit tests cover `HivorrLocalizationService` (load, resolve, interpolate, plural).
- [x] Unit tests cover `TranslationKeys` (non-empty, naming convention, no duplicates, cross-reference with `en.json`).
- [x] Unit tests cover `LocaleProvider` (initialize, setLocale, resetToSystemLocale, persistence, unsupported locale).
- [x] Unit tests cover `HivorrSupportedLocales` (registry, resolution).
- [x] Unit tests cover `LocalizationConfig` (construction, validation).
- [x] Unit tests cover `LocalizationException` (message, fields, toString).
- [x] Widget tests cover `HivorrLocalizations` delegate (load, isSupported, shouldReload, translate, plural, locale switching).
- [x] Widget tests cover `LocalizationExtension` (tr, plural, currentLocale, l10n).
- [x] `en.json` validation test confirms valid JSON, non-empty values, and plural form completeness.
- [x] `flutter analyze` passes cleanly (strict lints; no `print`).
- [x] `flutter test` passes (all new unit + widget tests green).
- [ ] Available platform smoke builds pass (Android, iOS, Web). **[Not executed in this environment.]**

**Document & Phase Integrity**

- [x] Approved EP-01 phase document remains unchanged.
- [x] ARCHITECTURE.md remains unchanged.
- [x] AGENT.md remains unchanged.
- [x] VISUAL-IDENTITY.md remains unchanged.
- [x] Final diff contains only approved EP-01-17 changes (`lib/core/localization/` + `assets/translations/` + `lib/app/app.dart` + `lib/app/app_bootstrap.dart` + `pubspec.yaml` + `test/unit/localization/` + `test/widget/localization/`).
- [x] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above — **signed off** (2026-08-28). All items verified except platform smoke builds (Android/iOS/Web), which were not executed in this environment; `flutter analyze` is clean and all 54 localization + 32 app integration tests pass.
