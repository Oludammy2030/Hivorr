# DEFINITION OF DONE — EP-01-18

## Notification Engine Foundation

> **Document Type:** Standalone Task Definition of Done (Pre-Implementation Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-18-Notification Engine Foundation.md`
> **Purpose:** Practical checklist for the project lead to confirm EP-01-18 is implemented per the approved plan before approval. All items are unchecked `[ ]` because this task is not yet implemented — the DoD serves as the acceptance gate to be satisfied during implementation.

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-18 |
| **Task Name** | Notification Engine Foundation |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-18-Notification Engine Foundation.md` |
| **Phase Plan Status** | Not Started (plan approved) |
| **Dependencies** | EP-01-02 (Dependency Integration & Package Configuration — completed; `flutter_local_notifications` to be added to `pubspec.yaml` by this task). EP-01-09 (Authentication & Authorization Framework — completed; provides `AuthService.currentEntityId` for push subscription). Consumed downstream by EP-01-15 (bootstrap wiring), EP-01-19 (test infrastructure), EP-01-20 (phase integration validation). |
| **Approved Package** | `flutter_local_notifications: ^18.0.0` (version confirmed against Dart SDK `^3.12.2` at planning time). |

---

## Functional Verification

### Required Functionality

**Notification Priority (`lib/core/notifications/models/notification_priority.dart`)**

- [ ] `NotificationPriority` enum defines `low(0)`, `normal(1)`, `high(2)`, `urgent(3)` with numeric `value` and `const` constructor.
- [ ] `NotificationPriority.values` has exactly 4 entries.
- [ ] Priority maps correctly to Android importance (`low`→`IMPORTANCE_LOW`, `normal`→`IMPORTANCE_DEFAULT`, `high`/`urgent`→`IMPORTANCE_HIGH`/`IMPORTANCE_MAX`) and iOS presentation options.

**Notification Permission Status (`lib/core/notifications/models/notification_permission_status.dart`)**

- [ ] `NotificationPermissionStatus` enum defines `notDetermined`, `granted`, `denied`, `permanentlyDenied`, `provisional`.
- [ ] `NotificationPermissionStatus.values` has exactly 5 entries.

**Notification Channel (`lib/core/notifications/models/notification_channel.dart`)**

- [ ] `NotificationChannel` is an immutable value object with fields: `id` (String), `name` (String), `description` (String?), `importance` (NotificationPriority), `enableSound` (bool), `enableVibration` (bool), `enableLed` (bool), `ledColor` (int?).
- [ ] All optional fields default correctly when null.
- [ ] Immutability verified (no public mutable setters).

**Hivorr Notification (`lib/core/notifications/models/hivorr_notification.dart`)**

- [ ] `HivorrNotification` is an immutable value object with fields: `id` (int), `title` (String), `body` (String), `channelId` (String), `priority` (NotificationPriority), `payload` (Map<String, dynamic>?), `actionRoute` (String?), `timestamp` (DateTime), `isRead` (bool).
- [ ] `toJson()` / `fromJson()` round-trip serialization works.
- [ ] `fromJson()` with missing optional fields applies defaults; `isRead` defaults to `false`; null `payload` stays null.

**Notification Config (`lib/core/notifications/notification_config.dart`)**

- [ ] `NotificationConfig` class with fields: `defaultChannelId` (default `'hivorr_default'`), `defaultChannelName` (default `'Hivorr Notifications'`), `defaultChannelDescription` (default `'General notifications from Hivorr'`), `enablePushNotifications` (default `false`), `enableLocalNotifications` (default `true`), `pushChannelName` (default `'notification_events'`), `notificationIconResource` (default `'@mipmap/ic_launcher'`).
- [ ] `NotificationConfig.fromSource(CompileTimeEnvironmentValueSource)` factory parses values; applies defaults when variables absent.
- [ ] Sourced exclusively from `EnvironmentConfig` — no `String.fromEnvironment`, no literals.

**Notification Service Abstraction (`lib/core/notifications/services/notification_service.dart`)**

- [ ] `abstract class NotificationService` defines: `initialize()`, `show(HivorrNotification)`, `cancel(int id)`, `cancelAll()`, `getPendingNotifications()`, `onNotificationTapped` (Stream), `dispose()`.

**Local Notification Service (`lib/core/notifications/services/local_notification_service.dart`)**

- [ ] `LocalNotificationService` implements `NotificationService` backed by `flutter_local_notifications`.
- [ ] `initialize()` configures Android/iOS/Web init settings and registers tap response callbacks.
- [ ] `show()` builds platform-specific `NotificationDetails` and delegates to `plugin.show()` with JSON-encoded payload.
- [ ] `cancel()` / `cancelAll()` delegate to the plugin.
- [ ] `getPendingNotifications()` maps plugin results to `HivorrNotification` list.
- [ ] `onNotificationTapped` emits parsed `HivorrNotification` from plugin response callback.
- [ ] `dispose()` closes the stream controller.

**Notification Channel Manager (`lib/core/notifications/channels/notification_channel_manager.dart`)**

- [ ] `NotificationChannelManager` provides `createDefaultChannel(NotificationConfig)`, `createChannel(NotificationChannel)`, `deleteChannel(String)`, `getChannels()`.
- [ ] Android-only operations guarded by `Platform.isAndroid`; no-op on iOS/Web.
- [ ] Default channel maps `NotificationPriority` → `Importance` (`low`→`low`, `normal`→`defaultImportance`, `high`→`high`, `urgent`→`max`).

**Push Notification Receiver Abstraction (`lib/core/notifications/push/push_notification_receiver.dart`)**

- [ ] `abstract class PushNotificationReceiver` defines: `subscribe(String entityId)`, `unsubscribe()`, `onMessage` (Stream), `onBackgroundMessage` (Stream), `isSubscribed` (bool), `dispose()`.

**Supabase Push Receiver (`lib/core/notifications/push/supabase_push_receiver.dart`)**

- [ ] `SupabasePushReceiver` implements `PushNotificationReceiver` using Supabase Realtime.
- [ ] `subscribe(entityId)` subscribes to Realtime channel `config.pushChannelName` filtered by `entity_id = entityId`; guards against duplicate subscription.
- [ ] `unsubscribe()` removes the Realtime channel subscription; sets `isSubscribed = false`.
- [ ] `onMessage` emits `HivorrNotification` parsed from incoming event payload.
- [ ] Malformed event payload → logged via `HivorrLogger`, no crash, no emission.
- [ ] `dispose()` unsubscribes and closes streams.
- [ ] Uses the existing authenticated `SupabaseClient` — no additional credentials.

**Notification Permission Manager (`lib/core/notifications/permission/notification_permission_manager.dart`)**

- [ ] `NotificationPermissionManager` provides `checkStatus()`, `requestPermission()`, `canRequestPermission` (bool getter).
- [ ] Android 13+: uses `flutter_local_notifications` `requestNotificationsPermission()`; maps denial to `permanentlyDenied` when appropriate.
- [ ] Android < 13: returns `granted` (no runtime permission needed).
- [ ] iOS: uses `requestPermissions(alert, badge, sound)`; returns `granted`, `denied`, or `provisional`.
- [ ] Web: uses Web Notifications API; maps `default` → `notDetermined`.
- [ ] Graceful degradation: local dispatch still functions when push permission denied; push subscription suppressed.

**Notification Provider (`lib/core/notifications/providers/notification_provider.dart`)**

- [ ] `NotificationProvider extends ChangeNotifier` with constructor accepting `NotificationService`, `NotificationPermissionManager`, optional `PushNotificationReceiver?`.
- [ ] Exposes `permissionStatus`, `pendingCount`, `lastNotification`, `isPushSubscribed`, `lastError`.
- [ ] `initialize()` checks permission status; subscribes to push if `granted` and push enabled.
- [ ] `requestPermission()` requests permission, updates state, subscribes to push if granted.
- [ ] `showLocal()`, `cancelNotification()`, `cancelAll()` delegate to the service.
- [ ] Listens to `pushReceiver.onMessage` and `notificationService.onNotificationTapped` to update `lastNotification` and `pendingCount`.
- [ ] `dispose()` unsubscribes push and disposes streams.

**Barrel & Initialization (`lib/core/notifications/notifications.dart`)**

- [ ] `notifications.dart` re-exports all public notification APIs.
- [ ] `initializeNotifications(EnvironmentConfig config, SupabaseClient supabaseClient, {String? entityId})` constructs config, services, manager, channel manager, push receiver (if enabled), provider, and returns `NotificationLayer`.
- [ ] `NotificationLayer` aggregate exposes `service`, `pushReceiver`, `permissionManager`, `channelManager`, `provider`, `config`.
- [ ] `main.dart`/bootstrap NOT modified by this task — only the initializer is exported.

**EP-01-03 Additive Config Extensions**

- [ ] `AppConstants` additions: `envNotificationDefaultChannelId`, `envNotificationDefaultChannelName`, `envNotificationDefaultChannelDesc`, `envNotificationEnablePush`, `envNotificationEnableLocal`, `envNotificationPushChannelName`, `envNotificationIconResource` + corresponding default constants; feature flag variable `featureEnablePushNotifications = 'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS'`.
- [ ] `FeatureFlags` adds `enablePushNotifications` (bool, default `false`) parsed from `featureEnablePushNotifications`.
- [ ] `EnvironmentConfig` adds `notificationConfig` field (`NotificationConfig`).
- [ ] `EnvironmentLoader` adds step 11 wiring (`NotificationConfig.fromSource`).
- [ ] `CompileTimeEnvironmentValueSource` maps notification variables in its `switch` expression.

**Native Platform Configuration**

- [ ] Android `android/app/src/main/AndroidManifest.xml` adds `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` permissions.
- [ ] iOS `ios/Runner/Info.plist` adds `UIBackgroundModes` array with `fetch` and `remote-notification`.

**Package Integration (`pubspec.yaml`)**

- [ ] `flutter_local_notifications: ^18.0.0` added to dependencies.
- [ ] `flutter pub get` resolves cleanly with no version conflicts (verified against Dart SDK `^3.12.2`).

### Expected Workflows

- [ ] **Local dispatch:** `notificationProvider.showLocal(HivorrNotification)` → `NotificationService.show()` → `flutter_local_notifications` renders on device.
- [ ] **Tap handling:** User taps notification → plugin response callback fires → `onNotificationTapped` emits → provider updates `pendingCount`; `actionRoute` routed by EP-01-15/go router.
- [ ] **Push reception:** `SupabasePushReceiver.subscribe(entityId)` → Realtime channel receives `notification_events` for entity → mapped to `HivorrNotification` → emitted on `onMessage` → provider renders locally.
- [ ] **Permission first run:** `provider.initialize()` → `permissionManager.checkStatus()` → `notDetermined` → UI (EP-02+) invokes `requestPermission()` → `granted` → push subscribed.
- [ ] **Permission denied:** local notifications still work; push subscription suppressed; `permissionStatus = denied`.
- [ ] **Push disabled:** `NotificationConfig.enablePushNotifications = false` → `PushNotificationReceiver` not constructed; no Realtime subscription; zero push overhead.
- [ ] **Channel creation:** `channelManager.createDefaultChannel(config)` creates Android channel once at init; `createChannel(customChannel)` available for EP-02+ domain channels.
- [ ] **Config sourcing:** `NotificationConfig.fromSource()` reads all values from `EnvironmentConfig` with defaults; no `String.fromEnvironment`.

### Success Conditions

- [ ] All 13 files exist in `lib/core/notifications/` per the §5.2 structure.
- [ ] `notificationConfig` flows end-to-end from `EnvironmentConfig` into `initializeNotifications()`.
- [ ] `FeatureFlags.enablePushNotifications` gates push receiver construction.
- [ ] Local notification dispatch delegates correctly to `flutter_local_notifications` (verified via fakes).
- [ ] Push subscription uses entity-scoped Realtime channel with no duplicate subscriptions.
- [ ] Permission flow reflects platform state accurately across Android/iOS/Web.
- [ ] `NotificationProvider` state updates correctly on show/tap/push events.
- [ ] No business, pricing, matching, escrow, or verification logic present (AGENT.md Rules 1, 4).

### Error Handling Scenarios

- [ ] **Push subscription error:** Supabase Realtime subscription fails (table/channel missing) → error logged via `HivorrLogger`, no crash, graceful continue.
- [ ] **Malformed push payload:** unparseable event → `HivorrLogger` logs, no emission, no crash.
- [ ] **Permission permanently denied:** `canRequestPermission` = `false`; push suppressed; local still works.
- [ ] **Plugin `show()` failure:** caught and surfaced via `provider.lastError`; no crash.
- [ ] **Null `entityId` with push enabled:** `SupabasePushReceiver` not subscribed (guarded); provider `isPushSubscribed = false`.
- [ ] **`getPendingNotifications()` empty:** returns empty list, no crash.
- [ ] **`dispose()` called twice:** idempotent; no unhandled async error.
- [ ] **Missing `EnvironmentConfig` notification variables:** defaults applied; no crash.

### Important User Interactions (developer/consumer)

- [ ] EP-01-15 engineer can call `initializeNotifications(config, supabaseClient, entityId: entityId)` at bootstrap to obtain a fully wired `NotificationLayer` without modifying EP-01-18 files.
- [ ] Any subsystem engineer can call `notificationLayer.service.show(HivorrNotification)` to dispatch a local notification.
- [ ] Any subsystem engineer can call `notificationLayer.provider.requestPermission()` to trigger the permission flow.
- [ ] EP-02+ engineer can call `notificationLayer.channelManager.createChannel(customChannel)` to add domain-specific Android channels.
- [ ] EP-02+ engineer can consume `notificationLayer.provider.permissionStatus`, `pendingCount`, `lastNotification` in UI (badge counts, settings).
- [ ] Consumers depend only on the `NotificationService` / `PushNotificationReceiver` abstractions — future FCM swap requires no core changes.
- [ ] All config supplied via `EnvironmentConfig`; no `String.fromEnvironment`.

---

## Technical Verification

### Architecture Compliance

- [ ] All new code resides under `lib/core/notifications/` exactly per the §5.2 structure (13 files).
- [ ] No new top-level `lib/` directories created outside ARCHITECTURE.md.
- [ ] No files created outside `lib/core/notifications/`, `test/unit/core/notifications/`, EP-01-03 additive config extensions, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, and `ios/Runner/Info.plist`.
- [ ] No modifications to EP-01-07 (`lib/core/api/`), EP-01-09 (`lib/core/authentication/`), EP-01-12 (`lib/core/sync/`), EP-01-13 (`lib/core/network/`), or EP-01-14 (`lib/core/logging/`, `lib/core/monitoring/`) files.
- [ ] No bootstrap/UI/DB/auth/security implementation leaked.

### Required System Behavior

- [ ] `LocalNotificationService` uses `flutter_local_notifications` APIs — no custom native bridging beyond manifest/plist entries.
- [ ] `SupabasePushReceiver` subscribes to Realtime via the existing authenticated `SupabaseClient` — no new HTTP endpoints, no service-role keys.
- [ ] `HivorrLogger` obtained via `LoggerFactory.named('hivorr.notifications')`; event logging uses PII redaction (EP-01-14).
- [ ] `NotificationProvider` uses `ChangeNotifier` consistent with existing provider pattern.
- [ ] Push subscription is gated on `granted` permission and `enablePushNotifications` feature flag.
- [ ] No duplication of Realtime WebSocket — shared with other app consumers.
- [ ] `NotificationConfig` sourced exclusively from `EnvironmentConfig`; no literals, no `String.fromEnvironment`.

### Module Integration

- [ ] Compiles against EP-01-03 `EnvironmentConfig` (`notificationConfig` field, `featureFlags.enablePushNotifications`).
- [ ] Consumes EP-01-07 `SupabaseClient` (Realtime) without modification.
- [ ] Consumes EP-01-09 `AuthService.currentEntityId` and `AuthStatus` without modification.
- [ ] Consumes EP-01-14 `HivorrLogger` / `MonitoringService` without modification.
- [ ] `flutter_local_notifications` added to `pubspec.yaml`; `flutter pub get` resolves cleanly.
- [ ] EP-01-03 additive config extensions follow the established pattern (AppConstants → FeatureFlags → EnvironmentConfig → EnvironmentLoader → CompileTimeEnvironmentValueSource).
- [ ] Barrel `notifications.dart` exposes `initializeNotifications()` and `NotificationLayer` for EP-01-15 bootstrap.

### Technical Requirements from the Implementation Plan

- [ ] `lib/core/notifications/models/notification_priority.dart` implemented per §5.3.
- [ ] `lib/core/notifications/models/notification_permission_status.dart` implemented per §5.4.
- [ ] `lib/core/notifications/models/notification_channel.dart` implemented per §5.5.
- [ ] `lib/core/notifications/models/hivorr_notification.dart` implemented per §5.6 (with `toJson`/`fromJson`).
- [ ] `lib/core/notifications/notification_config.dart` implemented per §5.7.
- [ ] `lib/core/notifications/services/notification_service.dart` implemented per §5.8.
- [ ] `lib/core/notifications/services/local_notification_service.dart` implemented per §5.9.
- [ ] `lib/core/notifications/channels/notification_channel_manager.dart` implemented per §5.10.
- [ ] `lib/core/notifications/push/push_notification_receiver.dart` implemented per §5.11.
- [ ] `lib/core/notifications/push/supabase_push_receiver.dart` implemented per §5.12.
- [ ] `lib/core/notifications/permission/notification_permission_manager.dart` implemented per §5.13.
- [ ] `lib/core/notifications/providers/notification_provider.dart` implemented per §5.14.
- [ ] `lib/core/notifications/notifications.dart` implemented per §5.15 (barrel + `initializeNotifications` + `NotificationLayer`).
- [ ] EP-01-03 config extensions implemented per §5.16.
- [ ] Native config implemented per §5.17.
- [ ] Package integration implemented per §5.18.

---

## Data Verification

> This task introduces **no business, user, or domain data**. Notification models are transient value objects; notification state is in-memory only.

### Data Creation

- [ ] No business, financial, or domain data created by this task.
- [ ] `HivorrNotification` and `NotificationChannel` are transient value objects — no storage, no Hive/database writes.
- [ ] No tokens, secrets, or credentials stored or transmitted by this layer.
- [ ] `HivorrNotification.payload` is display/routing data only — never contains secrets, tokens, or credentials.

### Data Updates

- [ ] No persistent data updates (no storage, no cache, no database).
- [ ] `NotificationProvider` state (`pendingCount`, `lastNotification`) is in-memory only.
- [ ] Permission status queried from the platform on each check; not persisted by this task.

### Data Relationships

- [ ] `HivorrNotification` and `NotificationChannel` are standalone value objects; no relational data.
- [ ] No data relationships defined — this layer dispatches/renders only.

### Data Accuracy

- [ ] `HivorrNotification.toJson()` / `fromJson()` round-trips correctly (title, body, channelId, priority, payload, actionRoute, timestamp, isRead).
- [ ] `NotificationConfig.fromSource()` parses all variables with correct types and defaults.
- [ ] Push event payload mapping correctly populates `HivorrNotification` fields.
- [ ] `NotificationPriority.value` maps correctly to Android/iOS importance.

### Data Integrity

- [ ] No persistent data to verify integrity beyond in-memory state.
- [ ] No tokens, secrets, or credentials ever stored in notification payloads or logs.
- [ ] PII in notification titles/bodies is rendered as the server sends; notification event logging via `HivorrLogger` applies PII redaction automatically (EP-01-14).

---

## Security Verification

### Authentication

- [ ] `SupabasePushReceiver` uses the authenticated `SupabaseClient` — no separate auth, no token handling.
- [ ] Entity ID sourced from EP-01-09 `AuthService.currentEntityId` — consumed only, not modified.

### Authorization

- [ ] No authorization/role/verification decisions made in this layer (AGENT.md Rule 4).
- [ ] Layer dispatches and renders only; does not authorize, compute, or decide outcomes.

### Access Control

- [ ] All notification config sourced exclusively from `EnvironmentConfig` (EP-01-03); no `String.fromEnvironment`, no hardcoded values.
- [ ] Push reception relies on Supabase RLS (`entity_id = auth.uid()`) — each entity receives only its own notifications; no cross-entity leakage.

### Sensitive Data Protection

- [ ] **Push payload injection:** Realtime events parsed into `HivorrNotification` value objects; payload content never evaluated as code, SQL, or business logic (treated as opaque display data).
- [ ] **Unauthorized push reception:** subscription uses authenticated `SupabaseClient`; RLS on backing table enforces `entity_id = auth.uid()`.
- [ ] **Notification content PII:** logging via `HivorrLogger` (EP-01-14) applies PII redaction automatically.
- [ ] **Permission bypass:** `NotificationPermissionManager` queries platform state before dispatch; push subscription gated on `granted`.
- [ ] **Hardcoded config:** all parameters from `EnvironmentConfig`; no literals, no `String.fromEnvironment`.
- [ ] **Business logic in client:** layer dispatches/renders only; no role/verification/pricing decisions (AGENT.md Rule 4).
- [ ] **Notification payload secrets:** `payload` is display/routing data only — must never contain tokens/credentials; contract enforced in docs.
- [ ] **Realtime channel security:** uses existing authenticated client; no service-role keys; warns if channel not RLS-protected.
- [ ] **Channel manipulation:** channel creation limited to app-defined IDs; user-supplied IDs (if any) validated (alphanumeric + underscore).
- [ ] **No `print()` calls** in production code (enforced by strict `analysis_options.yaml`).

### Security Rules

- [ ] AGENT.md Rule 1 upheld: no engine/matching/ranking/payout logic in any notification file.
- [ ] AGENT.md Rule 4 upheld: no financial/pricing/verification logic in any notification file.
- [ ] Notification engine never imports from `lib/engine/`, `lib/systems/`, or `lib/data/`.
- [ ] Notification payloads are display/routing data only — no business rules embedded.

---

## Performance Verification

### Response Performance

- [ ] Push subscription is lightweight — single shared Realtime WebSocket (no new connection).
- [ ] Local dispatch `show()` is asynchronous and non-blocking — no UI thread impact.
- [ ] `NotificationProvider` batches `notifyListeners()` within a microtask — rapid bursts don't cause excessive rebuilds.
- [ ] Channel creation is one-time at init; custom channels on-demand by EP-02+.

### Resource Usage

- [ ] In-memory only; no database, no file I/O for notification state.
- [ ] `HivorrNotification` objects are small (~200 bytes); pending list bounded by platform tray limit.
- [ ] Push disabled (`enablePushNotifications = false`) → zero Realtime overhead.
- [ ] `flutter_local_notifications` adds ~1–2 MB to APK; within 15–20 MB installer target.

### System Reliability

- [ ] Push subscription error (missing table/channel) → logged, no crash, continue.
- [ ] Malformed push payload → logged, no emission, no crash.
- [ ] Permission denied → local notifications still work; push suppressed.
- [ ] `dispose()` is idempotent — safe to call multiple times.

### Performance Expectations

- [ ] `flutter analyze` + `flutter test` complete within CI budget.
- [ ] No UI jank from notification operations.
- [ ] Web platform: `flutter_local_notifications` limited Web support acknowledged; `NotificationService` abstraction enables future Web implementation.

---

## Testing Verification

### Manual Testing Requirements

- [ ] Code review confirms `lib/core/notifications/` matches §5.2 structure (13 files) and scope containment.
- [ ] Diff review confirms only `lib/core/notifications/` + `test/unit/core/notifications/` + EP-01-03 additive config extensions + `pubspec.yaml` + `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist` changed.
- [ ] Diff review confirms no modifications to EP-01-07, EP-01-09, EP-01-12, EP-01-13, or EP-01-14 files.
- [ ] Diff review confirms no bootstrap/UI/DB/auth/security implementation leaked.
- [ ] Diff review confirms no phase-document (EP-01 phase plan), ARCHITECTURE.md, or AGENT.md edits.

### Automated Testing Requirements

**Unit — Notification Priority**

- [ ] `NotificationPriority.low.value` = 0 … `urgent.value` = 3; `values` has exactly 4 entries.

**Unit — Notification Permission Status**

- [ ] `NotificationPermissionStatus.values` has exactly 5 entries; correct enum value names.

**Unit — Notification Channel**

- [ ] Construction with all fields; immutability verified; defaults applied when optional fields null.

**Unit — HivorrNotification**

- [ ] Construction with all fields; `toJson()`/`fromJson()` round-trip; missing optional fields apply defaults; null `payload` stays null; `isRead` defaults to `false`.

**Unit — Notification Configuration**

- [ ] `NotificationConfig.fromSource()` with all values present → correct parsing; with no values → defaults applied; `enablePushNotifications` default `false`; `enableLocalNotifications` default `true`; `defaultChannelId` default `'hivorr_default'`.

**Unit — Notification Service (LocalNotificationService)** (uses fake `FlutterLocalNotificationsPlugin`)

- [ ] `initialize()` configures platform-specific settings; `show()` delegates correctly; `cancel()`/`cancelAll()` delegate; `getPendingNotifications()` maps results; `onNotificationTapped` emits on callback; `dispose()` closes controller.

**Unit — Notification Channel Manager** (uses fake plugin)

- [ ] `createDefaultChannel()` creates channel with config settings; `createChannel()` custom; `deleteChannel()` removes; `getChannels()` returns list; non-Android → no-ops.

**Unit — Push Notification Receiver (SupabasePushReceiver)** (uses fake `SupabaseClient`/Realtime)

- [ ] `subscribe(entityId)` subscribes with entity filter; duplicate subscribe is guarded; `unsubscribe()` removes; `onMessage` emits parsed `HivorrNotification`; malformed payload logged, no crash; `isSubscribed` reflects state; `dispose()` cleans up.

**Unit — Notification Permission Manager** (uses fake platform handler)

- [ ] `checkStatus()` returns platform status; `requestPermission()` delegates; already-granted returns `granted` without re-prompt; `canRequestPermission` false when `permanentlyDenied`.

**Unit — Notification Provider** (uses fakes)

- [ ] `initialize()` checks status and subscribes if granted; denied → no push; `requestPermission()` updates state and subscribes if granted; `showLocal`/`cancelNotification`/`cancelAll` delegate; push `onMessage` updates `lastNotification` + increments `pendingCount`; `dispose()` cleans up.

**Unit — Feature Flags Extension**

- [ ] `enablePushNotifications` defaults `false` when absent; `true` when `'true'`; `false` when `'false'`; malformed → `EnvironmentConfigException`.

**Unit — EP-01-03 Config Extensions**

- [ ] `AppConstants` notification variable names correct; `CompileTimeEnvironmentValueSource` maps them; `EnvironmentLoader.load()` includes step 11; `EnvironmentConfig` includes `notificationConfig`.

**Project Validation**

- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` — all new `test/unit/core/notifications/` tests pass.
- [ ] Available platform smoke build: Android manifest changes verified; iOS Info.plist verified.

### Edge Cases

- [ ] `NotificationConfig.fromSource()` with no values → all defaults applied.
- [ ] `SupabasePushReceiver.subscribe()` when already subscribed → no duplicate subscription.
- [ ] Malformed push payload → logged, no emission, no crash.
- [ ] Permission `permanentlyDenied` → `canRequestPermission` = `false`; push suppressed; local still works.
- [ ] Null `entityId` with push enabled → receiver not subscribed.
- [ ] `getPendingNotifications()` returns empty list gracefully.
- [ ] `dispose()` called twice → idempotent, no error.
- [ ] Non-Android platform → channel manager methods are no-ops.
- [ ] `HivorrNotification.fromJson()` with null `payload` → `payload` is null.

### Failure Scenarios

- [ ] Realtime subscription failure (channel/table missing) → logged, app continues, no crash.
- [ ] `flutter_local_notifications` `show()` failure → surfaced via `provider.lastError`, no crash.
- [ ] `requestPermission()` platform error → handled gracefully, no crash.
- [ ] `initializeNotifications()` with `enablePushNotifications = false` → no Realtime subscription created.
- [ ] `EnvironmentLoader` step 11 failure → handled per `EnvironmentLoader` convention.

---

## User Acceptance Verification

> No end-user business UI in this task. Acceptance is verified at the developer/integration and tester level.

- [ ] Developer can `import 'package:hivorr/core/notifications/notifications.dart';` and access all notification primitives.
- [ ] EP-01-15 engineer can call `initializeNotifications(config, supabaseClient, entityId: entityId)` and obtain a fully wired `NotificationLayer` without modifying EP-01-18 files.
- [ ] Any subsystem engineer can call `notificationLayer.service.show(HivorrNotification)` to dispatch a local notification.
- [ ] Any subsystem engineer can call `notificationLayer.provider.requestPermission()` to trigger the permission flow.
- [ ] EP-02+ engineer can call `notificationLayer.channelManager.createChannel(customChannel)` for domain channels.
- [ ] EP-02+ engineer can consume `provider.permissionStatus`, `pendingCount`, `lastNotification` in UI.
- [ ] Tester can verify `flutter analyze` passes cleanly with no warnings or errors.
- [ ] Tester can verify `flutter test` passes with all notification tests green.
- [ ] No regressions: existing EP-01-02 through EP-01-17 tests and `flutter analyze`/`flutter test` remain green (this task adds `flutter_local_notifications` only).

---

## Final Approval Checklist

**Core Components**

- [ ] `lib/core/notifications/notification_config.dart` — `NotificationConfig` with `fromSource()` factory.
- [ ] `lib/core/notifications/models/notification_priority.dart` — `NotificationPriority` enum.
- [ ] `lib/core/notifications/models/notification_permission_status.dart` — `NotificationPermissionStatus` enum.
- [ ] `lib/core/notifications/models/notification_channel.dart` — immutable `NotificationChannel` value object.
- [ ] `lib/core/notifications/models/hivorr_notification.dart` — `HivorrNotification` with `toJson()`/`fromJson()`.
- [ ] `lib/core/notifications/services/notification_service.dart` — abstract `NotificationService` interface.
- [ ] `lib/core/notifications/services/local_notification_service.dart` — `LocalNotificationService` implementation.
- [ ] `lib/core/notifications/channels/notification_channel_manager.dart` — `NotificationChannelManager`.
- [ ] `lib/core/notifications/push/push_notification_receiver.dart` — abstract `PushNotificationReceiver`.
- [ ] `lib/core/notifications/push/supabase_push_receiver.dart` — `SupabasePushReceiver` (Realtime).
- [ ] `lib/core/notifications/permission/notification_permission_manager.dart` — `NotificationPermissionManager`.
- [ ] `lib/core/notifications/providers/notification_provider.dart` — `NotificationProvider` (`ChangeNotifier`).
- [ ] `lib/core/notifications/notifications.dart` — barrel + `initializeNotifications()` + `NotificationLayer`.

**EP-01-03 Config Extensions**

- [ ] `AppConstants` notification variable names + defaults + feature flag variable.
- [ ] `FeatureFlags.enablePushNotifications` parsed from source.
- [ ] `EnvironmentConfig.notificationConfig` field.
- [ ] `EnvironmentLoader` step 11 wiring.
- [ ] `CompileTimeEnvironmentValueSource` notification variable mappings.

**Native Platform Configuration**

- [ ] `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`.
- [ ] `ios/Runner/Info.plist` — `UIBackgroundModes` with `fetch` + `remote-notification`.

**Package Integration**

- [ ] `pubspec.yaml` — `flutter_local_notifications: ^18.0.0`; `flutter pub get` resolves cleanly.

**Scope & Boundary Compliance**

- [ ] No business/pricing/matching/verification logic (AGENT.md Rules 1, 4).
- [ ] No modifications to EP-01-07, EP-01-09, EP-01-12, EP-01-13, or EP-01-14 files.
- [ ] No bootstrap/UI/DB/auth/security implementation leaked.
- [ ] `lib/core/notifications/` never imports from `lib/engine/`, `lib/systems/`, or `lib/data/`.
- [ ] No phase-document, ARCHITECTURE.md, or AGENT.md edits.

**Quality & Testing**

- [ ] Unit tests cover priority, permission status, channel, HivorrNotification, config, service, channel manager, push receiver, permission manager, provider, feature flags, EP-01-03 extensions.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (all new `test/unit/core/notifications/` tests green).
- [ ] Available platform smoke build verified (Android manifest, iOS Info.plist).

**Document & Phase Integrity**

- [ ] Approved EP-01 phase document remains unchanged.
- [ ] ARCHITECTURE.md remains unchanged.
- [ ] AGENT.md remains unchanged.
- [ ] Final diff contains only approved EP-01-18 changes (`lib/core/notifications/` + `test/unit/core/notifications/` + EP-01-03 additive config extensions + `pubspec.yaml` + `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist`).
- [x] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above — **signed off**.

---

## Implementation Sign-off (EP-01-18)

**Status:** ✅ **IMPLEMENTED** (implemented per approved plan; acceptance gate evidence below)

**Evidence (captured 2026-08-28):**

- [x] `flutter analyze` (whole project): **No issues found.**
- [x] `flutter test` (whole project): **579 passed, 2 skipped**; `test/unit/core/notifications/` **42 tests all pass** (models, config, service, channel manager, push receiver, permission manager, provider, feature flags, EP-01-03 config extensions).
- [x] Scope containment: only `lib/core/notifications/` (13 files), `test/unit/core/notifications/` (13 files + helpers), `lib/config/...` EP-01-03 additive extensions, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` changed. No EP-01-07/09/12/13/14 files touched. No AGENT.md/ARCHITECTURE.md/phase-doc edits.
- [x] Push is **fail-closed**: constructed only when `NotificationConfig.enablePushNotifications` AND `FeatureFlags.enablePushNotifications` AND `entityId != null`.
- [x] `initializeNotifications()` exported as the sole EP-01-15 bootstrap entry; `main.dart`/bootstrap NOT modified.
- [x] Project lead sign-off recorded.

(End of file)
