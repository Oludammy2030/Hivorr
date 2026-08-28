import 'package:flutter/material.dart';

import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/startup/initialization_screen.dart';
import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/core/database/database.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a successful bootstrap initialization sequence.
///
/// Returned to callers that need the wired artifacts (e.g. the root widget).
class BootstrapResult {
  const BootstrapResult({
    required this.appConfig,
    required this.apiLayer,
    required this.authLayer,
    required this.localeProvider,
  });

  final AppConfig appConfig;
  final ApiLayer apiLayer;
  final AuthLayer authLayer;
  final LocaleProvider localeProvider;
}

/// Orchestrates the application's initialization sequence and launch.
///
/// This is the single entrypoint that wires every EP-01 core system into a
/// functional application shell. The sequence is fail-closed: any step
/// throwing prevents the app from launching and renders a user-safe error
/// screen with retry (EP-01-15 §5.3).
class AppBootstrap {
  const AppBootstrap._();

  /// Executes the full initialization sequence with injectable steps.
  ///
  /// [loadConfig], [initializeApi], [initializeAuthLayer], and
  /// [initializeStorage] default to the production implementations. Tests
  /// inject fakes to verify ordering and failure behavior without a live
  /// backend.
  static Future<BootstrapResult> initialize({
    AppConfig Function() loadConfig = AppConfig.load,
    Future<ApiLayer> Function(EnvironmentConfig) initializeApi =
        ApiInitializer.initializeApi,
    AuthLayer Function(GoTrueClient, SupabaseClient, AuthConfig)
        initializeAuthLayer = _defaultInitializeAuth,
    Future<StorageEngine> Function(EnvironmentConfig) initializeStorage =
        _defaultInitializeStorage,
  }) async {
    final AppConfig appConfig = loadConfig();
    final ApiLayer apiLayer =
        await initializeApi(appConfig.environmentConfig);
    final AuthLayer authLayer = initializeAuthLayer(
      apiLayer.supabaseClient.auth,
      apiLayer.supabaseClient,
      AuthConfig.fromEnvironment(appConfig.environmentConfig),
    );
    await authLayer.provider.initialize();
    final StorageEngine storage =
        await initializeStorage(appConfig.environmentConfig);
    final LocaleProvider localeProvider = LocaleProvider(
      config: defaultLocalizationConfig,
      storage: storage,
    );
    await localeProvider.initialize();
    return BootstrapResult(
      appConfig: appConfig,
      apiLayer: apiLayer,
      authLayer: authLayer,
      localeProvider: localeProvider,
    );
  }

  /// Initializes the Hive-backed storage subsystem and returns its engine.
  static Future<StorageEngine> _defaultInitializeStorage(
    EnvironmentConfig config,
  ) async {
    final Database db = await Database.initialize(config);
    return db.engine;
  }

  static AuthLayer _defaultInitializeAuth(
    GoTrueClient authClient,
    SupabaseClient supabaseClient,
    AuthConfig config,
  ) =>
      initializeAuth(
        authClient: authClient,
        supabaseClient: supabaseClient,
        config: config,
      );

  /// Application entrypoint invoked from [main].
  ///
  /// Registers the lifecycle observer, then renders [InitializationScreen]
  /// which runs the bootstrap sequence, shows the brand splash, and swaps to
  /// the app shell on success or a user-safe error screen with retry on
  /// failure (never a raw crash).
  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    final AppLifecycleObserver lifecycleObserver = AppLifecycleObserver();
    WidgetsBinding.instance.addObserver(lifecycleObserver);

    runApp(InitializationScreen(lifecycleObserver: lifecycleObserver));
  }
}
