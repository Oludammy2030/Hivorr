# TASK IMPLEMENTATION PLAN: EP-01-18

## Notification Engine Foundation

| Field | Value |
|---|---|
| Task ID | EP-01-18 |
| Task Name | Notification Engine Foundation |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-02 (Dependency Integration & Package Configuration — completed; notification packages to be added to `pubspec.yaml` by this task). EP-01-09 (Authentication & Authorization Framework — provides `AuthService`, `AuthProvider`, `AuthStatus` for auth-aware notification behavior and entity-targeted push subscription). Consumed downstream by EP-01-15 (bootstrap wiring), EP-01-19 (test infrastructure), EP-01-20 (phase integration validation). |
| Priority | Medium |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side notification engine foundation in the ARCHITECTURE.md-mandated directory `lib/core/notifications/`:

- **Notification Data Models** — immutable value objects defining notification payloads (`HivorrNotification`), notification channels (`NotificationChannel`), notification priority (`NotificationPriority`), and permission status (`NotificationPermissionStatus`).
- **Notification Configuration** — a `NotificationConfig` class sourced from `EnvironmentConfig` (default channel ID, push enable flag, environment-specific behavior tuning).
- **Notification Service** — an abstract `NotificationService` interface defining the unified dispatch API (`show`, `cancel`, `cancelAll`, `getPendingNotifications`) with a concrete `LocalNotificationService` implementation backed by `flutter_local_notifications`.
- **Android Channel Manager** — a `NotificationChannelManager` that creates and manages Android notification channels with environment-appropriate importance, sound, and vibration settings.
- **Push Notification Receiver** — an abstract `PushNotificationReceiver` interface defining push subscription lifecycle (`subscribe`, `unsubscribe`, `onMessage`, `onBackgroundMessage`) with a Supabase Realtime implementation (`SupabasePushReceiver`) that listens for entity-targeted push events on a `notification_events` channel.
- **Permission Manager** — a `NotificationPermissionManager` that handles runtime permission requests (Android 13+ `POST_NOTIFICATIONS`), permission status queries, and graceful degradation when permission is denied.
- **Notification Provider** — a `NotificationProvider` (`ChangeNotifier`) propagating notification state (permission status, pending count, last received notification) to the widget tree.
- **Native Platform Configuration** — Android `AndroidManifest.xml` permissions (`POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`) and iOS `Info.plist` background modes (`remote-notification`).
- **EP-01-03 additive config extensions** — `AppConstants` notification variable names + defaults, `NotificationConfig` class, `EnvironmentConfig` (`notificationConfig` field), `EnvironmentLoader` (step 11), `CompileTimeEnvironmentValueSource` (notification variables), `FeatureFlags` (`enablePushNotifications`).
- **Unit tests** proving notification dispatch, channel creation, permission flow, push subscription, config sourcing, and provider state management.

Deliverables:
- A `NotificationService` abstract interface with `LocalNotificationService` concrete implementation for local notification dispatch.
- A `NotificationChannelManager` for Android channel lifecycle.
- A `PushNotificationReceiver` abstract interface with `SupabasePushReceiver` concrete implementation.
- A `NotificationPermissionManager` for runtime permission handling.
- A `NotificationProvider` (`ChangeNotifier`) for widget tree state propagation.
- A `NotificationConfig` class sourced from `EnvironmentConfig`.
- EP-01-03 additive config extensions (`AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`).
- Native platform permission configurations (Android manifest, iOS Info.plist).
- `flutter_local_notifications` package added to `pubspec.yaml`.
- Unit tests for all components.
- `flutter analyze` (strict lints) + `flutter test` must pass.

**Dependency note:** EP-01-18 depends on EP-01-02 (package integration) and EP-01-09 (authentication framework) per the approved matrix. This task adds `flutter_local_notifications` to `pubspec.yaml` (EP-01-02 established the dependency integration pattern). The `SupabasePushReceiver` requires `AuthService.currentEntityId` from EP-01-09 to subscribe to entity-targeted push channels. This task does not modify EP-01-07, EP-01-09, EP-01-12, EP-01-13, or EP-01-14 files — it consumes their public interfaces only.

---

## 2. Business Problem Being Solved

Without a notification engine foundation:

- **Zero user re-engagement capability.** The platform cannot deliver local reminders, transaction alerts, trust notifications, or messaging alerts to users. For a Nigeria-market platform where timely communication drives engagement and trust, this is a critical gap.
- **No push notification infrastructure.** EP-02 builds messaging, transaction alerts, trust/verification notifications, and marketplace updates — all of which require a push delivery mechanism. Without EP-01-18, EP-02 notification features have no delivery layer to build on.
- **No Android notification channels.** Android 8.0+ (API 26+) requires notification channels for all notifications. Without proper channel setup, notifications are silently dropped or displayed with default (often inappropriate) importance levels.
- **No permission management.** Android 13+ (API 33+) requires runtime `POST_NOTIFICATIONS` permission. Without a structured permission flow, the app either never requests permission (notifications silently blocked) or requests it at inappropriate times (poor UX, high denial rates).
- **No notification state propagation.** The widget tree has no visibility into notification permission status, pending notification count, or recently received notifications — preventing UI elements like badge counts, permission prompts, and notification settings screens.
- **EP-01-20 phase validation requires notifications.** The phase completion criteria implicitly requires notification infrastructure for the full platform foundation to be operational.
- **Cross-cutting dependency.** Nearly every business system in EP-02+ (messaging, transactions, trust, scheduling, reviews) depends on the notification engine for user-facing alerts. Building it as an afterthought creates retrofitting debt.

This is the **notification delivery backbone** — it provides the unified dispatch API, local notification rendering, push reception, and permission management that every user-facing alert in the platform flows through.

---

## 3. Scope

### In Scope

- `lib/core/notifications/` module: `notification_config.dart`, `models/hivorr_notification.dart`, `models/notification_channel.dart`, `models/notification_priority.dart`, `models/notification_permission_status.dart`, `services/notification_service.dart`, `services/local_notification_service.dart`, `channels/notification_channel_manager.dart`, `push/push_notification_receiver.dart`, `push/supabase_push_receiver.dart`, `permission/notification_permission_manager.dart`, `providers/notification_provider.dart`, `notifications.dart` barrel + `initializeNotifications()` + `NotificationLayer` aggregate.
- **Notification configuration** (`NotificationConfig`) — default channel ID, channel name, push enable flag, environment-specific behavior tuning sourced from `EnvironmentConfig`.
- **Notification data models** — `HivorrNotification` (id, title, body, payload, channel, priority, timestamp, action route), `NotificationChannel` (id, name, description, importance, sound, vibration, led color), `NotificationPriority` enum, `NotificationPermissionStatus` enum.
- **Notification service abstraction** (`NotificationService`) — abstract interface: `show(HivorrNotification)`, `cancel(int id)`, `cancelAll()`, `getPendingNotifications()`, `onNotificationTapped` stream.
- **Local notification service** (`LocalNotificationService`) — concrete implementation backed by `flutter_local_notifications` plugin; handles Android/iOS platform initialization, notification rendering, and tap callbacks.
- **Android channel manager** (`NotificationChannelManager`) — creates default and custom Android notification channels with configurable importance, sound, vibration, and LED color.
- **Push notification receiver abstraction** (`PushNotificationReceiver`) — abstract interface: `subscribe(String entityId)`, `unsubscribe()`, `onMessage` stream, `onBackgroundMessage` stream, `dispose()`.
- **Supabase push receiver** (`SupabasePushReceiver`) — concrete implementation using Supabase Realtime to listen for entity-targeted notification events on a `notification_events` channel; maps incoming events to `HivorrNotification` and delegates to `NotificationService.show()`.
- **Permission manager** (`NotificationPermissionManager`) — handles Android 13+ runtime `POST_NOTIFICATIONS` permission request, status query, and graceful degradation; iOS permission request via `flutter_local_notifications`.
- **Notification provider** (`NotificationProvider`) — `ChangeNotifier` propagating `NotificationPermissionStatus`, pending notification count, last received notification, and push subscription status to the widget tree.
- **EP-01-03 config extensions**: additive changes to `AppConstants` (notification env variable names + defaults), `FeatureFlags` (`enablePushNotifications`), `EnvironmentConfig` (`notificationConfig` field), `EnvironmentLoader` (step 11), `CompileTimeEnvironmentValueSource` (notification variables).
- **Native platform configuration**: Android `AndroidManifest.xml` permissions (`POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`); iOS `Info.plist` `UIBackgroundModes` with `remote-notification`.
- **Package integration**: `flutter_local_notifications` added to `pubspec.yaml` with pinned version.
- Unit tests (`test/unit/core/notifications/`): notification dispatch, channel creation, permission flow, push subscription, config sourcing, provider state, model serialization.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Modifying EP-01-07 files (`lib/core/api/`) — the notification engine consumes the API layer's public interfaces (`Dio`, `SupabaseClient`) without modification.
- Modifying EP-01-09 files (`lib/core/authentication/`) — the notification engine consumes `AuthService.currentEntityId` and `AuthStatus` stream without modification.
- Modifying EP-01-12 files (`lib/core/sync/`) — sync completion notifications are added by downstream consumers of the `NotificationService`; this task provides the service only.
- Modifying EP-01-13 files (`lib/core/network/`) — connectivity-aware notification suppression is added by downstream consumers; this task provides the `NotificationProvider` state only.
- Modifying EP-01-14 files (`lib/core/logging/`, `lib/core/monitoring/`) — the notification engine obtains a `HivorrLogger` via `LoggerFactory.named('hivorr.notifications')` and emits breadcrumbs via `MonitoringService.addBreadcrumb()` without modifying those modules.
- Modifying `main.dart` or app bootstrap — EP-01-15 wires `initializeNotifications()` at startup.
- Firebase Cloud Messaging (FCM) integration — the `PushNotificationReceiver` abstraction supports future Firebase implementation; this task delivers Supabase Realtime as the initial transport.
- Server-side notification generation or Supabase Edge Functions — server-side push generation is an EP-02+ concern.
- Notification UI widgets (settings screens, in-app notification banners, badge counters) — EP-01-16/EP-02+.
- Rich media notifications (images, action buttons, custom layouts) — foundation delivers standard text notifications; rich media is a future enhancement.
- Scheduled/recurring notifications — foundation delivers immediate dispatch; scheduling is a future enhancement.
- Auth framework, token handling — EP-01-09.
- Security infrastructure (encryption, SSL pinning) — EP-01-10.
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is permitted. This layer **dispatches, renders, and manages notification delivery**; it does not authorize, compute, or decide business outcomes. The notification engine operates purely as an unprivileged client-side delivery layer — all notification content generation, targeting decisions, and business logic remain server-side (AGENT.md Rule 4). Notification payloads must never contain secrets, tokens, or credentials. The `SupabasePushReceiver` subscribes to entity-scoped Realtime channels using the authenticated Supabase client — RLS ensures only the owning entity receives their notifications. No notification content is evaluated as business logic on the client.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Abstract interfaces for transport swap | `NotificationService` + `PushNotificationReceiver` abstractions enable future Firebase/FCM swap |
| No modification of EP-01-07/09/12/13/14 files | Consume public interfaces; downstream wiring by EP-01-15 |
| Feature-gated via `FeatureFlags` | EP-01-03 (`enablePushNotifications`) |
| No business logic in client | AGENT.md Rules 1, 4 |
| PII-safe notification logging | Use `HivorrLogger` from EP-01-14 for all notification event logging |
| Environment-aware behavior | Development = verbose logging + test channels; Production = minimal logging + production channels |
| Permission-first UX | Never show notifications without explicit user permission; graceful degradation on denial |

### 5.2 Proposed Structure

```text
lib/core/notifications/
├── notification_config.dart                    # Notification config sourced from EnvironmentConfig
├── models/
│   ├── hivorr_notification.dart                # Core notification payload model
│   ├── notification_channel.dart                # Android notification channel model
│   ├── notification_priority.dart               # Priority/importance enum
│   └── notification_permission_status.dart      # Permission status enum
├── services/
│   ├── notification_service.dart                # Abstract NotificationService interface
│   └── local_notification_service.dart          # flutter_local_notifications implementation
├── channels/
│   └── notification_channel_manager.dart        # Android channel lifecycle manager
├── push/
│   ├── push_notification_receiver.dart          # Abstract push receiver interface
│   └── supabase_push_receiver.dart              # Supabase Realtime push implementation
├── permission/
│   └── notification_permission_manager.dart     # Runtime permission handler
├── providers/
│   └── notification_provider.dart               # ChangeNotifier for widget tree
└── notifications.dart                           # Barrel + initializeNotifications() + NotificationLayer
```

### 5.3 Notification Priority (`models/notification_priority.dart`)

```dart
enum NotificationPriority {
  low(0),
  normal(1),
  high(2),
  urgent(3);

  final int value;
  const NotificationPriority(this.value);
}
```

Maps to Android `NotificationChannel` importance and iOS `UNNotificationPresentationOptions`:

| `NotificationPriority` | Android Importance | iOS Presentation |
|---|---|---|
| `low` | `IMPORTANCE_LOW` (no sound) | Banner only |
| `normal` | `IMPORTANCE_DEFAULT` (sound) | Banner + sound |
| `high` | `IMPORTANCE_HIGH` (heads-up) | Banner + sound + badge |
| `urgent` | `IMPORTANCE_HIGH` (heads-up, persistent) | Alert + sound + badge |

### 5.4 Notification Permission Status (`models/notification_permission_status.dart`)

```dart
enum NotificationPermissionStatus {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
  provisional;
}
```

| Status | Meaning |
|---|---|
| `notDetermined` | Permission not yet requested |
| `granted` | User granted notification permission |
| `denied` | User denied; can re-request |
| `permanentlyDenied` | User denied with "Don't ask again" (Android) or system restriction |
| `provisional` | iOS provisional authorization (quiet notifications only) |

### 5.5 Notification Channel (`models/notification_channel.dart`)

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` | Unique channel identifier (e.g., `'hivorr_default'`, `'hivorr_messages'`) |
| `name` | `String` | User-visible channel name |
| `description` | `String?` | User-visible channel description |
| `importance` | `NotificationPriority` | Default importance for this channel |
| `enableSound` | `bool` | Whether notifications in this channel play sound |
| `enableVibration` | `bool` | Whether notifications in this channel vibrate |
| `enableLed` | `bool` | Whether the notification LED is enabled |
| `ledColor` | `int?` | ARGB color for the notification LED |

Immutable value object. Android-only concept; silently ignored on iOS and Web.

### 5.6 Hivorr Notification (`models/hivorr_notification.dart`)

| Field | Type | Purpose |
|---|---|---|
| `id` | `int` | Unique notification identifier (for cancel/update) |
| `title` | `String` | Notification title |
| `body` | `String` | Notification body text |
| `channelId` | `String` | Target notification channel |
| `priority` | `NotificationPriority` | Notification priority/importance |
| `payload` | `Map<String, dynamic>?` | Optional structured data for deep-link routing |
| `actionRoute` | `String?` | Optional GoRouter path for tap navigation |
| `timestamp` | `DateTime` | When the notification was created/received |
| `isRead` | `bool` | Whether the user has acknowledged it |

Immutable value object. Serializable via `toJson()` / `fromJson()` for persistent storage if needed by downstream tasks.

### 5.7 Notification Configuration (`notification_config.dart`)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `defaultChannelId` | `String` | `'hivorr_default'` | Default Android notification channel ID |
| `defaultChannelName` | `String` | `'Hivorr Notifications'` | Default channel user-visible name |
| `defaultChannelDescription` | `String` | `'General notifications from Hivorr'` | Default channel description |
| `enablePushNotifications` | `bool` | `false` | Master enable for push reception |
| `enableLocalNotifications` | `bool` | `true` | Master enable for local notification dispatch |
| `pushChannelName` | `String` | `'notification_events'` | Supabase Realtime channel name for push |
| `notificationIconResource` | `String` | `'@mipmap/ic_launcher'` | Android notification small icon resource |

Sourced from `EnvironmentConfig` via compile-time defines (`HIVORR_NOTIFICATION_*`). When `enablePushNotifications` is `false`, the `PushNotificationReceiver` is not initialized and push subscription is skipped.

### 5.8 Notification Service Abstraction (`services/notification_service.dart`)

```dart
abstract class NotificationService {
  Future<void> initialize();
  Future<void> show(HivorrNotification notification);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<List<HivorrNotification>> getPendingNotifications();
  Stream<HivorrNotification> get onNotificationTapped;
  void dispose();
}
```

### 5.9 Local Notification Service (`services/local_notification_service.dart`)

Concrete implementation backed by `flutter_local_notifications`:

**Initialization:**
1. Construct `FlutterLocalNotificationsPlugin` instance.
2. Configure Android initialization settings (app icon, default channel).
3. Configure iOS initialization settings (request alert, badge, sound permissions).
4. Configure Web initialization settings (if platform is web).
5. Register `onDidReceiveNotificationResponse` callback → emit to `onNotificationTapped` stream.
6. Register `onDidReceiveBackgroundNotificationResponse` callback for background handling.

**`show(HivorrNotification)`:**
1. Build platform-specific notification details:
   - Android: `AndroidNotificationDetails(channelId, channelName, importance, priority, ...)`
   - iOS: `DarwinNotificationDetails(presentAlert, presentBadge, presentSound)`
2. Construct `NotificationDetails(android, iOS)`.
3. Call `plugin.show(id, title, body, details, payload: jsonEncode(notification.payload))`.

**`cancel(int id)`:** Call `plugin.cancel(id)`.

**`cancelAll()`:** Call `plugin.cancelAll()`.

**`getPendingNotifications()`:** Call `plugin.pendingNotificationRequests()`, map to `HivorrNotification`.

**`onNotificationTapped`:** `StreamController<HivorrNotification>.broadcast()` fed by the plugin's response callback. Parses `payload` from the response to reconstruct `HivorrNotification`.

### 5.10 Notification Channel Manager (`channels/notification_channel_manager.dart`)

| Method | Purpose |
|---|---|
| `createDefaultChannel(NotificationConfig config)` | Creates the default notification channel with config-specified settings |
| `createChannel(NotificationChannel channel)` | Creates a custom notification channel |
| `deleteChannel(String channelId)` | Removes a notification channel |
| `getChannels()` | Returns list of existing channels |

Android-only operations; no-op on iOS and Web (guarded by `Platform.isAndroid`).

Default channel creation maps `NotificationPriority` to `Importance`:
- `low` → `Importance.low`
- `normal` → `Importance.defaultImportance`
- `high` → `Importance.high`
- `urgent` → `Importance.max`

### 5.11 Push Notification Receiver Abstraction (`push/push_notification_receiver.dart`)

```dart
abstract class PushNotificationReceiver {
  Future<void> subscribe(String entityId);
  Future<void> unsubscribe();
  Stream<HivorrNotification> get onMessage;
  Stream<HivorrNotification> get onBackgroundMessage;
  bool get isSubscribed;
  void dispose();
}
```

### 5.12 Supabase Push Receiver (`push/supabase_push_receiver.dart`)

Concrete implementation using Supabase Realtime:

**`subscribe(String entityId)`:**
1. Guard: if already subscribed to this entity, return.
2. Obtain `SupabaseClient` reference.
3. Subscribe to Realtime channel: `supabaseClient.channel(config.pushChannelName)`.
4. Listen for `postgres_changes` events on `notification_events` table filtered by `entity_id = entityId`.
5. On event received: parse payload → construct `HivorrNotification` → emit to `onMessage` stream.
6. Set `isSubscribed = true`.

**`unsubscribe()`:**
1. Unsubscribe from the Realtime channel.
2. Set `isSubscribed = false`.

**`onMessage`:** `StreamController<HivorrNotification>.broadcast()` fed by Realtime events in foreground.

**`onBackgroundMessage`:** `StreamController<HivorrNotification>.broadcast()` — background handling is platform-dependent; on mobile, the Realtime connection may not persist in background. This stream is populated when the app returns to foreground and processes queued events.

**Event payload mapping:**
The Supabase Realtime event payload is expected to contain:
```json
{
  "id": 12345,
  "title": "New message from John",
  "body": "Hey, are you available for a job?",
  "channel_id": "hivorr_messages",
  "priority": "high",
  "action_route": "/messages/thread/abc-123",
  "payload": { "threadId": "abc-123", "senderId": "entity-uuid" }
}
```

The receiver maps this to `HivorrNotification` and emits it. The `NotificationProvider` (or EP-01-15 bootstrap wiring) connects `onMessage` to `NotificationService.show()` for local rendering.

### 5.13 Notification Permission Manager (`permission/notification_permission_manager.dart`)

| Method | Purpose |
|---|---|
| `Future<NotificationPermissionStatus> checkStatus()` | Query current permission status |
| `Future<NotificationPermissionStatus> requestPermission()` | Request permission from the user |
| `bool get canRequestPermission` | Whether permission can still be requested (not permanently denied) |

**Implementation strategy:**

- **Android 13+ (API 33+):** Uses `flutter_local_notifications` `requestNotificationsPermission()` which wraps the Android `POST_NOTIFICATIONS` runtime permission. If the user selects "Don't allow", subsequent checks return `permanentlyDenied`.
- **Android < 13:** Notifications are granted by default (no runtime permission needed). `checkStatus()` returns `granted`.
- **iOS:** Uses `flutter_local_notifications` `requestPermissions(alert, badge, sound)` which wraps `UNUserNotificationCenter.requestAuthorization()`. Returns `granted`, `denied`, or `provisional`.
- **Web:** Uses the Web Notifications API `Notification.requestPermission()`. Returns `granted`, `denied`, or `default` (mapped to `notDetermined`).

**Graceful degradation:**
- If permission is denied, `NotificationService.show()` still functions (local notifications work without push permission on most platforms), but push subscription is suppressed.
- `NotificationProvider` exposes permission status so UI can show appropriate prompts or settings redirects.

### 5.14 Notification Provider (`providers/notification_provider.dart`)

```dart
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required NotificationService notificationService,
    required NotificationPermissionManager permissionManager,
    PushNotificationReceiver? pushReceiver,
  });
}
```

| Property | Type | Purpose |
|---|---|---|
| `permissionStatus` | `NotificationPermissionStatus` | Current notification permission state |
| `pendingCount` | `int` | Number of pending (unread) notifications |
| `lastNotification` | `HivorrNotification?` | Most recently received notification |
| `isPushSubscribed` | `bool` | Whether push receiver is actively subscribed |
| `lastError` | `String?` | Most recent error message (if any) |

| Method | Purpose |
|---|---|
| `Future<void> initialize()` | Check permission status, subscribe to push if granted |
| `Future<void> requestPermission()` | Request permission, update state, subscribe if granted |
| `Future<void> showLocal(HivorrNotification notification)` | Dispatch a local notification through the service |
| `Future<void> cancelNotification(int id)` | Cancel a specific notification |
| `Future<void> cancelAll()` | Cancel all notifications |
| `void dispose()` | Unsubscribe push, dispose streams |

**State flow:**
1. `initialize()` → `permissionManager.checkStatus()` → update `permissionStatus`.
2. If `granted` and push enabled → `pushReceiver.subscribe(entityId)` → `isPushSubscribed = true`.
3. Listen to `pushReceiver.onMessage` → emit to `onNotificationTapped` → update `lastNotification` + `pendingCount`.
4. Listen to `notificationService.onNotificationTapped` → update `pendingCount` (decrement on read).
5. `requestPermission()` → `permissionManager.requestPermission()` → if `granted`, subscribe to push.

### 5.15 Initialization Wiring

**`initializeNotifications(EnvironmentConfig config, SupabaseClient supabaseClient, {String? entityId})`:**

1. Construct `NotificationConfig.fromSource()` (already loaded via `EnvironmentConfig`).
2. Construct `NotificationPermissionManager` with platform-specific implementation.
3. Construct `LocalNotificationService(config)`.
4. Call `localNotificationService.initialize()`.
5. Construct `NotificationChannelManager`.
6. Call `channelManager.createDefaultChannel(config)` (Android only).
7. If `config.enablePushNotifications` and `entityId != null`:
   - Construct `SupabasePushReceiver(supabaseClient, config)`.
   - Call `pushReceiver.subscribe(entityId)`.
8. Construct `NotificationProvider(notificationService, permissionManager, pushReceiver)`.
9. Call `notificationProvider.initialize()`.
10. Return `NotificationLayer`.

**`NotificationLayer` aggregate:**

| Field | Type | Purpose |
|---|---|---|
| `service` | `NotificationService` | Local notification dispatch |
| `pushReceiver` | `PushNotificationReceiver?` | Push reception (null if disabled) |
| `permissionManager` | `NotificationPermissionManager` | Permission lifecycle |
| `channelManager` | `NotificationChannelManager` | Android channel lifecycle |
| `provider` | `NotificationProvider` | Widget tree state propagation |
| `config` | `NotificationConfig` | Active notification configuration |

`lib/app/` (EP-01-15) calls `initializeNotifications()` at bootstrap — **this task does not modify `main.dart` or bootstrap**; it exports the initializer only.

### 5.16 EP-01-03 Configuration Extensions (additive)

Following the established pattern from EP-01-10, EP-01-11, EP-01-12, EP-01-13, EP-01-14:

**`AppConstants` additions:**
- `envNotificationDefaultChannelId` = `'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_ID'`
- `envNotificationDefaultChannelName` = `'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_NAME'`
- `envNotificationDefaultChannelDesc` = `'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_DESC'`
- `envNotificationEnablePush` = `'HIVORR_NOTIFICATION_ENABLE_PUSH'`
- `envNotificationEnableLocal` = `'HIVORR_NOTIFICATION_ENABLE_LOCAL'`
- `envNotificationPushChannelName` = `'HIVORR_NOTIFICATION_PUSH_CHANNEL_NAME'`
- `envNotificationIconResource` = `'HIVORR_NOTIFICATION_ICON_RESOURCE'`
- Corresponding `default*` constants for each.

**`FeatureFlags` addition:**
- `enablePushNotifications` (`bool`, default `false`).
- Variable name: `featureEnablePushNotifications` = `'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS'`.

**`EnvironmentConfig` addition:**
- `notificationConfig` field (`NotificationConfig`).

**`EnvironmentLoader` addition:**
- `NotificationConfig.fromSource(source)` wiring (step 11 in load sequence).

**`CompileTimeEnvironmentValueSource` addition:**
- Notification variable mappings in the `switch` expression.

### 5.17 Native Platform Configuration

**Android `AndroidManifest.xml` additions:**

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

**iOS `Info.plist` additions:**

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### 5.18 Package Integration

Add to `pubspec.yaml` dependencies:

```yaml
# Local & push notification engine for lib/core/notifications/ (EP-01-18).
flutter_local_notifications: ^18.0.0
```

Version to be confirmed against latest stable at implementation time. The implementer must verify the version is compatible with Dart SDK `^3.12.2` and run `flutter pub get` to validate resolution.

### 5.19 Extensibility Hooks

- `NotificationService` abstract → future phases can add alternative delivery backends (e.g., custom notification renderer, in-app toast system).
- `PushNotificationReceiver` abstract → Firebase Cloud Messaging implementation can be added without changing the notification engine core. The `SupabasePushReceiver` serves as the initial transport; FCM can coexist or replace it.
- `NotificationChannel` → EP-02+ business systems define domain-specific channels (messages, transactions, trust, scheduling) via `NotificationChannelManager.createChannel()`.
- `NotificationProvider` → EP-01-16/EP-02+ UI consumes permission status, pending count, and last notification for badge counts, settings screens, and in-app notification banners.
- `HivorrNotification.actionRoute` → GoRouter deep-link navigation on notification tap (EP-01-15 routing).
- `NotificationConfig` → environment-specific tuning without code changes.
- `notifications.dart` barrel → EP-01-15 bootstrap.
- `NotificationPriority` → EP-02+ systems assign priority per notification type (e.g., `urgent` for payment received, `low` for weekly digest).

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of notification config values, feature gates |
| `flutter_local_notifications` | `pubspec.yaml` (added by this task) | Local notification rendering plugin |
| `AuthService` / `AuthProvider` | `lib/core/authentication/` (EP-01-09) | Entity ID for push subscription, auth state for subscription lifecycle |
| `SupabaseClient` | `lib/core/api/` (EP-01-07) | Realtime channel subscription for push reception |
| `HivorrLogger` | `lib/core/logging/` (EP-01-14) | Scoped notification event logging (`'hivorr.notifications'`) |
| `MonitoringService` | `lib/core/monitoring/` (EP-01-14) | Notification event breadcrumbs for Sentry |
| `NetworkStatusProvider` | `lib/core/network/` (EP-01-13) | Connectivity state for push subscription awareness (consumed, not modified) |
| `NotificationService` | `lib/core/notifications/services/` | Abstract + concrete local notification dispatch |
| `NotificationChannelManager` | `lib/core/notifications/channels/` | Android channel lifecycle |
| `PushNotificationReceiver` | `lib/core/notifications/push/` | Abstract + Supabase Realtime push reception |
| `NotificationPermissionManager` | `lib/core/notifications/permission/` | Runtime permission lifecycle |
| `NotificationProvider` | `lib/core/notifications/providers/` | Widget tree state propagation |
| `NotificationConfig` | `lib/core/notifications/` | Configuration sourced from `EnvironmentConfig` |
| EP-01-03 config extensions | `lib/config/` | Additive `AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource` |
| Android manifest | `android/app/src/main/` | Notification permissions |
| iOS Info.plist | `ios/Runner/` | Background modes for push |
| Test suites | `test/unit/core/notifications/` | Service, channel, push, permission, provider, config, model tests |

**New dependency required:** `flutter_local_notifications` (version TBD at implementation, targeting `^18.0.0`). All other dependencies (`supabase_flutter`, `provider`) are already in `pubspec.yaml`.

---

## 7. Data Requirements

- **Notification models** are transient value objects (`HivorrNotification`, `NotificationChannel`). They contain no business logic, no domain entities, no financial data.
- `HivorrNotification` is serializable (`toJson()` / `fromJson()`) for potential persistent storage by downstream tasks (notification history).
- **Push event payloads** received from Supabase Realtime are untrusted client-side data. The `SupabasePushReceiver` parses them into `HivorrNotification` but never evaluates payload content as business logic.
- **Permission status** is a transient runtime state. Not persisted to local storage (queried from the platform on each check).
- **Notification state** in `NotificationProvider` (pending count, last notification) is in-memory only. Not persisted.
- No tokens, secrets, or credentials are stored or transmitted by this layer. The Supabase Realtime subscription uses the existing authenticated `SupabaseClient` — no additional credential management.
- No business, financial, or domain data is created by this task.
- **PII in notification content:** Notification titles and bodies may contain user-facing text (names, order numbers). The notification engine does not redact content (it renders what the server sends). However, notification event logging through `HivorrLogger` applies PII redaction automatically (EP-01-14 defense-in-depth).

---

## 8. Database Considerations

**No direct schema changes by this task.** The `SupabasePushReceiver` listens for events on a `notification_events` Supabase Realtime channel. The table backing this channel (if any) is owned by EP-01-05/06 or future EP-02+ server-side notification generation tasks.

**Assumed server-side contract (for reference only — not implemented by this task):**
- A `notification_events` table (or Realtime broadcast channel) with `entity_id` column for RLS-filtered push delivery.
- RLS policy: `entity_id = auth.uid()` — each entity receives only their own notifications.
- Server-side Edge Functions or triggers insert notification events; the client only receives them.

This task's `SupabasePushReceiver` subscribes to the Realtime channel and processes incoming events. If the table does not yet exist, the receiver gracefully handles subscription errors and logs them via `HivorrLogger`.

---

## 9. API Requirements

- **No new Hivorr API endpoints or RPCs.** The notification engine operates client-side for local dispatch and listens for server-pushed events via Supabase Realtime (an existing platform capability).
- The `SupabasePushReceiver` uses `SupabaseClient.channel()` — an existing Supabase SDK method. No new HTTP endpoints.
- `LocalNotificationService` uses `flutter_local_notifications` plugin APIs — no network calls.
- Future EP-02+ tasks may add notification-related RPCs (e.g., `mark_notification_read`, `get_notification_history`) — not in this task's scope.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. The `NotificationProvider` and `NotificationService` are exported for EP-01-15/16+ to build notification settings screens, in-app notification banners, badge counters, and permission prompt UIs. `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience:
- One-call `initializeNotifications(config, supabaseClient, entityId)` yields a fully wired `NotificationLayer` with local dispatch, push subscription, and permission management.
- `NotificationProvider` gives the widget tree clean access to permission status, pending count, and notification events.
- `NotificationService.show()` gives every subsystem a simple API for dispatching local notifications.
- `NotificationChannelManager` gives EP-02+ systems a clean API for creating domain-specific Android channels.
- Feature gate (`enablePushNotifications`) allows toggling push without code changes.
- Push disabled gracefully when `enablePushNotifications` is `false` — `PushNotificationReceiver` is null, all push methods are skipped.
- Permission denied gracefully — local notifications still work; push is suppressed; UI can prompt the user to enable in settings.

End-user experience considerations:
- Permission request timing is controlled by downstream UI (EP-02+), not this task. The engine provides the `requestPermission()` API; the UI decides when to invoke it.
- Notification tap navigates to `actionRoute` via GoRouter — EP-01-15 bootstrap wires the tap callback to the router.
- Android notification channels give users granular control over notification types (system settings).
- Graceful degradation: if push is disabled or permission denied, the app remains fully functional — only push notifications are absent.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Push payload injection | `SupabasePushReceiver` parses Realtime events into `HivorrNotification` value objects. Payload content is never evaluated as code, SQL, or business logic. Treated as opaque display data. |
| Unauthorized push reception | Supabase Realtime channel subscription uses the authenticated `SupabaseClient`. RLS on the backing table ensures `entity_id = auth.uid()`. No cross-entity notification leakage. |
| Notification content PII | Notification titles/bodies may contain user names or order references. Logging of notification events uses `HivorrLogger` (EP-01-14) which applies PII redaction automatically. |
| Permission bypass | `NotificationPermissionManager` queries platform permission state before dispatch. Push subscription is gated on `granted` status. No silent notification delivery without permission. |
| Hardcoded config values | All notification parameters sourced exclusively from `EnvironmentConfig`; no `String.fromEnvironment`, no literals. |
| Business logic in client | Layer dispatches and renders only; no role/verification/pricing decisions (AGENT.md Rule 4). |
| Notification payload secrets | `HivorrNotification.payload` is display/routing data only. Must never contain tokens, credentials, or secrets. Documentation enforces this contract. |
| Supabase Realtime channel security | Channel subscription uses the existing authenticated client. No additional credentials or service-role keys. If the Realtime channel is not RLS-protected, the receiver still functions but logs a warning. |
| Android notification channel manipulation | Channel creation is limited to app-defined IDs. No user-supplied channel IDs are accepted without validation (alphanumeric + underscore only). |

---

## 13. Performance Considerations

- **Push subscription is lightweight.** Supabase Realtime maintains a single WebSocket connection (shared with other Realtime consumers in the app). Adding a notification channel does not create a new connection.
- **Local notification dispatch is asynchronous.** `flutter_local_notifications` `show()` is non-blocking. No UI thread impact.
- **Notification provider updates are batched.** `NotificationProvider` uses `ChangeNotifier` which batches `notifyListeners()` calls within a microtask. Rapid notification bursts do not cause excessive widget rebuilds.
- **Channel creation is one-time.** `NotificationChannelManager.createDefaultChannel()` runs once at initialization. Custom channels are created on-demand by EP-02+ systems.
- **No persistent storage overhead.** Notification state is in-memory only. No database, no file I/O. `flutter_local_notifications` manages its own internal state for pending notifications.
- **Memory footprint:** `NotificationProvider` holds references to service, receiver, permission manager (shared). `HivorrNotification` objects are small (~200 bytes each). Pending notification list is bounded by the platform's notification tray limit (typically 50+).
- **Push disabled = zero overhead.** When `enablePushNotifications` is `false`, no Realtime subscription is created. No WebSocket overhead.
- **Package size impact:** `flutter_local_notifications` adds approximately 1–2 MB to the APK. Within the 15–20 MB installer target when combined with other dependencies.
- **Web platform:** `flutter_local_notifications` has limited Web support. Web notification delivery may require a separate implementation in the future. The `NotificationService` abstraction enables this without changing the core engine.

---

## 14. Testing Strategy

### 14.1 Unit — Notification Priority
- `NotificationPriority.low.value` = 0, `NotificationPriority.urgent.value` = 3.
- `NotificationPriority.values` has exactly 4 entries.

### 14.2 Unit — Notification Permission Status
- `NotificationPermissionStatus.values` has exactly 5 entries.
- Enum values: `notDetermined`, `granted`, `denied`, `permanentlyDenied`, `provisional`.

### 14.3 Unit — Notification Channel
- Construction with all fields.
- Immutability verification.
- Default values applied when optional fields are null.

### 14.4 Unit — HivorrNotification
- Construction with all fields.
- `toJson()` / `fromJson()` round-trip serialization.
- `fromJson()` with missing optional fields → defaults applied.
- `fromJson()` with null `payload` → `payload` is null.
- `isRead` defaults to `false`.

### 14.5 Unit — Notification Configuration
- `NotificationConfig.fromSource()` with all values present → correct parsing.
- `NotificationConfig.fromSource()` with no values → defaults applied.
- `enablePushNotifications` defaults to `false`.
- `enableLocalNotifications` defaults to `true`.
- `defaultChannelId` defaults to `'hivorr_default'`.

### 14.6 Unit — Notification Service (LocalNotificationService)
- `initialize()` configures platform-specific initialization settings.
- `show(HivorrNotification)` delegates to `flutter_local_notifications` `plugin.show()` with correct parameters.
- `cancel(id)` delegates to `plugin.cancel(id)`.
- `cancelAll()` delegates to `plugin.cancelAll()`.
- `getPendingNotifications()` maps plugin results to `HivorrNotification` list.
- `onNotificationTapped` stream emits when plugin response callback fires.
- `dispose()` closes the stream controller.
- Tests use a fake/mock `FlutterLocalNotificationsPlugin` to verify delegation without platform dependencies.

### 14.7 Unit — Notification Channel Manager
- `createDefaultChannel(config)` creates a channel with config-specified ID, name, description, and importance.
- `createChannel(customChannel)` creates a channel with custom parameters.
- `deleteChannel(channelId)` removes the specified channel.
- `getChannels()` returns the list of created channels.
- Non-Android platforms: all methods are no-ops (verified via platform check).
- Tests use a fake `FlutterLocalNotificationsPlugin` to verify Android channel API calls.

### 14.8 Unit — Push Notification Receiver (SupabasePushReceiver)
- `subscribe(entityId)` subscribes to the correct Realtime channel with entity filter.
- `subscribe()` when already subscribed → no duplicate subscription.
- `unsubscribe()` removes the Realtime channel subscription.
- `onMessage` stream emits `HivorrNotification` when a Realtime event is received.
- Event payload mapping: JSON payload → `HivorrNotification` with correct fields.
- Malformed event payload → error logged via `HivorrLogger`, no crash, no emission.
- `isSubscribed` reflects current subscription state.
- `dispose()` unsubscribes and closes streams.
- Tests use a fake `SupabaseClient` / fake Realtime channel to verify subscription behavior.

### 14.9 Unit — Notification Permission Manager
- `checkStatus()` returns the platform-reported permission status.
- `requestPermission()` delegates to the platform permission API.
- `requestPermission()` when already granted → returns `granted` without re-prompting.
- `canRequestPermission` returns `false` when status is `permanentlyDenied`.
- Tests use a fake platform permission handler to verify delegation.

### 14.10 Unit — Notification Provider
- `initialize()` checks permission status and updates `permissionStatus`.
- `initialize()` with `granted` status and push enabled → subscribes to push.
- `initialize()` with `denied` status → push not subscribed.
- `requestPermission()` updates `permissionStatus` after platform response.
- `requestPermission()` with `granted` → subscribes to push.
- `showLocal(notification)` delegates to `NotificationService.show()`.
- `cancelNotification(id)` delegates to `NotificationService.cancel()`.
- `cancelAll()` delegates to `NotificationService.cancelAll()`.
- Push `onMessage` emission → `lastNotification` updated, `pendingCount` incremented.
- `dispose()` unsubscribes push, disposes streams.
- Tests use fake `NotificationService`, fake `PushNotificationReceiver`, fake `NotificationPermissionManager`.

### 14.11 Unit — Feature Flags Extension
- `enablePushNotifications` defaults to `false` when variable absent.
- `enablePushNotifications` = `true` when variable is `'true'`.
- `enablePushNotifications` = `false` when variable is `'false'`.
- Malformed value → `EnvironmentConfigException`.

### 14.12 Unit — EP-01-03 Config Extensions
- `AppConstants` notification variable names are correct.
- `CompileTimeEnvironmentValueSource` maps notification variables.
- `EnvironmentLoader.load()` includes step 11 (`NotificationConfig.fromSource`).
- `EnvironmentConfig` includes `notificationConfig` field.

### 14.13 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new tests pass.
- Available platform smoke build (Android manifest changes verified).

### 14.14 Scope Validation
- Diff review: only `lib/core/notifications/` + `test/unit/core/notifications/` + EP-01-03 additive config extensions (`AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`) + `pubspec.yaml` (new package) + `android/app/src/main/AndroidManifest.xml` (permissions) + `ios/Runner/Info.plist` (background modes). No modifications to EP-01-07, EP-01-09, EP-01-12, EP-01-13, or EP-01-14 files. No bootstrap/UI/DB/auth/security implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-02, EP-01-03, and EP-01-09 deliverables; confirm `lib/core/notifications/` contains only `.gitkeep`.
2. Add `flutter_local_notifications` to `pubspec.yaml`. Run `flutter pub get` to validate resolution.
3. Implement EP-01-03 additive config extensions:
   - `AppConstants` (7 notification variable names + defaults + 1 feature flag variable name).
   - `FeatureFlags` (`enablePushNotifications` field + parsing).
   - `NotificationConfig` class with `fromSource()` factory.
   - `EnvironmentConfig` (`notificationConfig` field).
   - `EnvironmentLoader` (step 11: `NotificationConfig.fromSource` wiring).
   - `CompileTimeEnvironmentValueSource` (notification variable mappings).
4. Implement `lib/core/notifications/models/notification_priority.dart` — `NotificationPriority` enum.
5. Implement `lib/core/notifications/models/notification_permission_status.dart` — `NotificationPermissionStatus` enum.
6. Implement `lib/core/notifications/models/notification_channel.dart` — `NotificationChannel` value object.
7. Implement `lib/core/notifications/models/hivorr_notification.dart` — `HivorrNotification` value object with `toJson()` / `fromJson()`.
8. Implement `lib/core/notifications/notification_config.dart` — `NotificationConfig` class (if not already done in step 3).
9. Implement `lib/core/notifications/services/notification_service.dart` — abstract `NotificationService` interface.
10. Implement `lib/core/notifications/services/local_notification_service.dart` — `LocalNotificationService` backed by `flutter_local_notifications`.
11. Implement `lib/core/notifications/channels/notification_channel_manager.dart` — `NotificationChannelManager`.
12. Implement `lib/core/notifications/push/push_notification_receiver.dart` — abstract `PushNotificationReceiver` interface.
13. Implement `lib/core/notifications/push/supabase_push_receiver.dart` — `SupabasePushReceiver` using Supabase Realtime.
14. Implement `lib/core/notifications/permission/notification_permission_manager.dart` — `NotificationPermissionManager`.
15. Implement `lib/core/notifications/providers/notification_provider.dart` — `NotificationProvider` (`ChangeNotifier`).
16. Implement `lib/core/notifications/notifications.dart` — barrel + `initializeNotifications()` + `NotificationLayer` aggregate.
17. Configure Android `AndroidManifest.xml` — add notification permissions.
18. Configure iOS `Info.plist` — add background modes.
19. Add `test/unit/core/notifications/` unit tests (models, config, service, channel manager, push receiver, permission manager, provider, feature flags, config extensions).
20. Run `flutter analyze` and `flutter test`.
21. Available platform smoke builds (Android manifest changes verified).
22. Review final diff for strict EP-01-18 scope containment and phase-document integrity.
23. **Stop at the approval gate** — do not implement EP-01-15 bootstrap wiring, EP-01-16 UI, or downstream tasks.

---

## 16. Expected Outcome

- A fully functional **local notification dispatch layer** in `lib/core/notifications/` providing `show`, `cancel`, `cancelAll`, `getPendingNotifications`, and `onNotificationTapped` via `flutter_local_notifications`.
- A fully functional **Android channel manager** creating default and custom notification channels with configurable importance, sound, vibration, and LED settings.
- A fully functional **push notification receiver** using Supabase Realtime for entity-targeted push delivery, with an abstract interface enabling future Firebase/FCM swap.
- A fully functional **permission manager** handling Android 13+ `POST_NOTIFICATIONS` runtime permission, iOS `UNUserNotificationCenter` authorization, and graceful degradation.
- A fully functional **notification provider** propagating permission status, pending count, last notification, and push subscription state to the widget tree via `ChangeNotifier`.
- `NotificationConfig` sourced from `EnvironmentConfig` — environment-tunable without code changes.
- Push gracefully disabled when `enablePushNotifications` is `false` — no Realtime subscription, no overhead.
- Permission denied gracefully — local notifications still work; push suppressed; UI can prompt settings redirect.
- Native platform permissions configured (Android manifest, iOS Info.plist).
- Unit tests proving notification dispatch, channel creation, permission flow, push subscription, config sourcing, and provider state management — all without a live backend.
- EP-01-20 phase validation criterion for notification infrastructure is achievable once EP-01-15 wires the bootstrap.
- `flutter_local_notifications` package integrated into `pubspec.yaml`.

---

## 17. Definition of Done (DoD)

**Structure & Code — Models**
- [ ] `lib/core/notifications/models/` contains `hivorr_notification.dart`, `notification_channel.dart`, `notification_priority.dart`, `notification_permission_status.dart`.
- [ ] `NotificationPriority` enum defines `low`, `normal`, `high`, `urgent` with numeric values.
- [ ] `NotificationPermissionStatus` enum defines `notDetermined`, `granted`, `denied`, `permanentlyDenied`, `provisional`.
- [ ] `NotificationChannel` is immutable with `id`, `name`, `description`, `importance`, `enableSound`, `enableVibration`, `enableLed`, `ledColor`.
- [ ] `HivorrNotification` is immutable with `id`, `title`, `body`, `channelId`, `priority`, `payload`, `actionRoute`, `timestamp`, `isRead`. Serializable via `toJson()` / `fromJson()`.

**Structure & Code — Services**
- [ ] `lib/core/notifications/services/` contains `notification_service.dart`, `local_notification_service.dart`.
- [ ] `NotificationService` abstract interface defines `initialize()`, `show()`, `cancel()`, `cancelAll()`, `getPendingNotifications()`, `onNotificationTapped`, `dispose()`.
- [ ] `LocalNotificationService` implements `NotificationService` using `flutter_local_notifications`. Platform-specific initialization for Android, iOS, and Web.
- [ ] `LocalNotificationService.show()` builds platform-specific notification details and delegates to `plugin.show()`.
- [ ] `LocalNotificationService.onNotificationTapped` emits `HivorrNotification` parsed from the plugin's response callback payload.

**Structure & Code — Channels**
- [ ] `lib/core/notifications/channels/` contains `notification_channel_manager.dart`.
- [ ] `NotificationChannelManager` creates default and custom Android notification channels. No-op on non-Android platforms.
- [ ] Default channel uses `NotificationConfig` values for ID, name, description, and importance.

**Structure & Code — Push**
- [ ] `lib/core/notifications/push/` contains `push_notification_receiver.dart`, `supabase_push_receiver.dart`.
- [ ] `PushNotificationReceiver` abstract interface defines `subscribe()`, `unsubscribe()`, `onMessage`, `onBackgroundMessage`, `isSubscribed`, `dispose()`.
- [ ] `SupabasePushReceiver` subscribes to Supabase Realtime channel filtered by `entity_id`. Maps incoming events to `HivorrNotification`.
- [ ] `SupabasePushReceiver` handles malformed payloads gracefully (logs error, no crash).
- [ ] `SupabasePushReceiver.subscribe()` is idempotent (no duplicate subscriptions).

**Structure & Code — Permission**
- [ ] `lib/core/notifications/permission/` contains `notification_permission_manager.dart`.
- [ ] `NotificationPermissionManager` queries and requests notification permissions via platform APIs.
- [ ] `requestPermission()` returns correct `NotificationPermissionStatus` for granted, denied, and permanently denied states.
- [ ] `canRequestPermission` returns `false` when permanently denied.

**Structure & Code — Provider**
- [ ] `lib/core/notifications/providers/` contains `notification_provider.dart`.
- [ ] `NotificationProvider` extends `ChangeNotifier` with `permissionStatus`, `pendingCount`, `lastNotification`, `isPushSubscribed`, `lastError`.
- [ ] `initialize()` checks permission, subscribes to push if granted and enabled.
- [ ] `requestPermission()` updates state and subscribes on grant.
- [ ] `showLocal()`, `cancelNotification()`, `cancelAll()` delegate to `NotificationService`.
- [ ] `dispose()` unsubscribes push, closes streams.

**Structure & Code — Barrel & Aggregate**
- [ ] `lib/core/notifications/notifications.dart` barrel exports public API.
- [ ] `initializeNotifications()` wired for EP-01-15 bootstrap.
- [ ] `NotificationLayer` aggregate contains `service`, `pushReceiver`, `permissionManager`, `channelManager`, `provider`, `config`.

**Cross-Cutting**
- [ ] EP-01-03 additive config extensions: `AppConstants` (7 notification variable names + defaults + 1 feature flag variable name), `FeatureFlags` (`enablePushNotifications`), `EnvironmentConfig` (`notificationConfig` field), `EnvironmentLoader` (step 11), `CompileTimeEnvironmentValueSource` (notification variables).
- [ ] `flutter_local_notifications` added to `pubspec.yaml` with pinned version. `flutter pub get` succeeds.
- [ ] Android `AndroidManifest.xml` includes `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` permissions.
- [ ] iOS `Info.plist` includes `UIBackgroundModes` with `remote-notification`.
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/DB/auth/security/network/sync/logging/monitoring code included.
- [ ] No modifications to EP-01-07, EP-01-09, EP-01-12, EP-01-13, or EP-01-14 files.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (models, config, service, channel manager, push receiver, permission manager, provider, feature flags, config extensions unit tests).
- [ ] Available platform smoke builds pass (Android manifest changes verified).
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-18 changes (+ EP-01-03 additive config extensions + `pubspec.yaml` package addition + native platform permission configs).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Medium-high — designing a correct notification engine with platform-specific initialization (Android channels, iOS permissions, Web limitations), abstract service/receiver interfaces, and Supabase Realtime integration requires careful reasoning about platform differences, notification lifecycle, and stream management. The `flutter_local_notifications` plugin API (platform initialization settings, notification details construction, response callback handling) requires understanding of the plugin's lifecycle and platform-specific behavior. However, the patterns are well-established and the implementation is largely wiring and delegation.
- **Business impact:** High — this is the notification delivery backbone. Every EP-02+ business system (messaging, transactions, trust, scheduling, reviews) depends on it for user-facing alerts. EP-01-20 phase completion requires a functional notification infrastructure. Incorrect implementation means silent notification failures, missed user engagement, and broken EP-02 notification features.
- **Security risk:** Medium — the notification engine does not handle secrets or financial data. The primary security concern is push payload injection (mitigated by treating payloads as opaque display data) and unauthorized push reception (mitigated by Supabase RLS on the authenticated client). PII in notification content is handled by EP-01-14's `HivorrLogger` redaction.
- **Performance sensitivity:** Medium — notification dispatch is asynchronous and non-blocking. Push subscription uses the existing Supabase Realtime WebSocket (no additional connection). Provider state updates are batched via `ChangeNotifier`. No persistent storage I/O.
- **Data complexity:** Low — `HivorrNotification` is a simple structured record (9 fields). `NotificationConfig` is a flat configuration class. No relational data, no persistence, no schema design.
- **Integration complexity:** High — must integrate correctly with four completed subsystems (`flutter_local_notifications` plugin, `SupabaseClient` Realtime from EP-01-07, `AuthService.currentEntityId` from EP-01-09, `HivorrLogger` from EP-01-14). The EP-01-03 config extension pattern must be followed precisely (7 new variable names + 1 feature flag, EnvironmentConfig field, EnvironmentLoader step 11, CompileTimeEnvironmentValueSource mapping, FeatureFlags addition). Native platform configurations (Android manifest, iOS Info.plist) must be correct for notifications to function.

High reasoning matches the approved EP-01 matrix (EP-01-18 = High) and the integration-heavy nature of the task — the complexity lies in correct platform-specific notification initialization, Supabase Realtime subscription management, precise config pattern adherence, and native platform permission configuration rather than algorithmic depth.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

**Approval-required decisions:**

1. **Package selection:** `flutter_local_notifications` is recommended as the local notification delivery package. It is the most mature, widely-adopted Flutter notification plugin with Android, iOS, and Web support. Alternative: `awesome_notifications` (richer UI features but larger footprint and less community adoption). Recommend `flutter_local_notifications` for alignment with the lightweight installer target.

2. **Push transport:** Supabase Realtime is recommended as the initial push transport, avoiding Firebase project setup and FCM configuration at the foundation level. The `PushNotificationReceiver` abstraction enables Firebase/FCM to be added later without changing the notification engine core. This defers Firebase infrastructure setup to a future task when push notification volume and delivery guarantees require it.

3. **`flutter_local_notifications` version:** The plan targets `^18.0.0`. The implementer must verify the latest stable version compatible with Dart SDK `^3.12.2` at implementation time.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-18-Notification-Engine-Foundation.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
