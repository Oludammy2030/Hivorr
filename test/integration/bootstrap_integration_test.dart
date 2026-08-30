import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/app.dart';
import 'package:hivorr/app/app_bootstrap.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/app/router/app_router.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/startup/splash_screen.dart';
import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fakes/fake_taxonomy.dart';
import '../test_helpers.dart';

void main() {
  group('Bootstrap integration — §5.16', () {
    group('1. Initialization order', () {
      test('AppBootstrap.initialize wires systems in dependency order',
          () async {
        final List<String> order = <String>[];

        final BootstrapResult result = await AppBootstrap.initialize(
          loadConfig: () {
            order.add('config');
            return fakeLoadConfig();
          },
          initializeApi: (EnvironmentConfig config) {
            order.add('api');
            return fakeInitializeApi(config);
          },
          initializeAuthLayer: (
            GoTrueClient authClient,
            SupabaseClient supabaseClient,
            AuthConfig config,
          ) {
            order.add('auth');
            return fakeInitializeAuthLayer(
              authClient,
              supabaseClient,
              config,
            );
          },
          initializeStorage: (EnvironmentConfig config) async {
            order.add('storage');
            return FakeStorageEngine();
          },
        );

        // config -> API -> auth -> storage must run before locale finalization.
        expect(
          order,
          <String>['config', 'api', 'auth', 'storage'],
        );

        // Observable post-conditions: every later system depends on its
        // predecessor, so each must be present and non-null.
        expect(result.appConfig, isNotNull);
        expect(result.apiLayer, isA<ApiLayer>());
        expect(result.authLayer.provider, isA<FakeAuthProvider>());
        expect(result.localeProvider, isA<LocaleProvider>());
      });
    });

    group('2. Provider registration', () {
      testWidgets('HivorrApp registers AuthProvider and LocaleProvider',
          (tester) async {
        final FakeAuthProvider authProvider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final FakeLocaleProvider localeProvider = FakeLocaleProvider();
        final AppLifecycleObserver observer = AppLifecycleObserver();
        final taxonomyRepository = FakeTaxonomyRepository();
        final taxonomyProvider = TaxonomyProvider(repository: taxonomyRepository);

        await tester.pumpWidget(
          HivorrApp(
            authProvider: authProvider,
            localeProvider: localeProvider,
            lifecycleObserver: observer,
            taxonomyRepository: taxonomyRepository,
            taxonomyProvider: taxonomyProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HivorrApp), findsOneWidget);

        final BuildContext ctx = tester.element(find.byType(MaterialApp));
        expect(
          Provider.of<AuthProvider>(ctx, listen: false),
          same(authProvider),
        );
        expect(
          Provider.of<LocaleProvider>(ctx, listen: false),
          same(localeProvider),
        );

        observer.dispose();
      });

      testWidgets('MultiProvider exposes ChangeNotifierProviders for core types',
          (tester) async {
        final FakeAuthProvider authProvider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final FakeLocaleProvider localeProvider = FakeLocaleProvider();
        final AppLifecycleObserver observer = AppLifecycleObserver();
        final taxonomyRepository = FakeTaxonomyRepository();
        final taxonomyProvider = TaxonomyProvider(repository: taxonomyRepository);

        await tester.pumpWidget(
          HivorrApp(
            authProvider: authProvider,
            localeProvider: localeProvider,
            lifecycleObserver: observer,
            taxonomyRepository: taxonomyRepository,
            taxonomyProvider: taxonomyProvider,
          ),
        );
        await tester.pumpAndSettle();

        // The MultiProvider inside HivorrApp exposes the core providers and
        // resolves them to the exact instances supplied to the app shell.
        final BuildContext ctx = tester.element(find.byType(MaterialApp));
        expect(
          Provider.of<AuthProvider>(ctx, listen: false),
          same(authProvider),
        );
        expect(
          Provider.of<LocaleProvider>(ctx, listen: false),
          same(localeProvider),
        );
        observer.dispose();
      });
    });

    group('3. Router configuration', () {
      test('GoRouter exposes public, protected, and SEO-friendly routes', () {
        final FakeAuthProvider authProvider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final GoRouter router = AppRouter.create(authProvider: authProvider);

        final List<RouteBase> routeBases = router.configuration.routes;
        final List<String> paths = routeBases
            .whereType<GoRoute>()
            .map((GoRoute r) => r.path)
            .toList();

        // Public auth routes.
        expect(paths, contains(RoutePaths.login));
        expect(paths, contains(RoutePaths.signup));
        expect(paths, contains(RoutePaths.forgotPassword));
        // Protected routes.
        expect(paths, contains(RoutePaths.profile));
        expect(paths, contains(RoutePaths.settings));
        expect(paths, contains(RoutePaths.home));
        // Public, SEO-friendly content routes.
        expect(paths, contains(RoutePaths.publicProfileRoute));
        expect(paths, contains(RoutePaths.publicStoreRoute));
        expect(RoutePaths.publicProfile(slug: 'electrician', id: 'abc-123'),
            '/p/electrician/abc-123');
        expect(RoutePaths.publicStore(storeId: 'xyz-456'), '/store/xyz-456');

        router.dispose();
      });

      test('auth redirect bounces unauthenticated users to /login', () {
        final FakeAuthProvider authProvider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final RouteGuard guard = RouteGuard(authProvider: authProvider);

        expect(guard.redirectResolver(RoutePaths.home), RoutePaths.login);
        expect(guard.redirectResolver(RoutePaths.profile), RoutePaths.login);
        expect(guard.redirectResolver(RoutePaths.login), isNull);
        expect(
          guard.redirectResolver(
            RoutePaths.publicProfile(slug: 'john', id: '1'),
          ),
          isNull,
        );
      });

      test('auth redirect keeps authenticated users on protected routes', () {
        final FakeAuthProvider authProvider =
            FakeAuthProvider(initialStatus: AuthStatus.authenticated);
        final RouteGuard guard = RouteGuard(authProvider: authProvider);

        expect(guard.redirectResolver(RoutePaths.home), isNull);
        expect(guard.redirectResolver(RoutePaths.profile), isNull);
        expect(guard.redirectResolver(RoutePaths.login), RoutePaths.home);
      });
    });

    group('4. Splash sequence', () {
      testWidgets('SplashScreen renders the brand logo and loader during init',
          (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(LogoHorizontal), findsOneWidget);
        expect(find.byType(HivorrLoader), findsOneWidget);
      });

      testWidgets(
          'successful bootstrap hands off to the app shell (authenticated)',
          (WidgetTester tester) async {
        final BootstrapResult result = await AppBootstrap.initialize(
          loadConfig: fakeLoadConfig,
          initializeApi: fakeInitializeApi,
          initializeAuthLayer: fakeInitializeAuthLayer,
          initializeStorage: (_) async => FakeStorageEngine(),
        );

        final FakeAuthProvider authProvider =
            result.authLayer.provider as FakeAuthProvider;
        authProvider.setStatus(AuthStatus.authenticated);

        final AppLifecycleObserver observer = AppLifecycleObserver();
        await tester.pumpWidget(
          HivorrApp(
            authProvider: authProvider,
            localeProvider: result.localeProvider,
            lifecycleObserver: observer,
            taxonomyRepository: result.taxonomyRepository,
            taxonomyProvider: result.taxonomyProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HivorrApp), findsOneWidget);

        final RouteGuard guard = RouteGuard(authProvider: authProvider);
        expect(guard.redirectResolver(RoutePaths.home), isNull);

        // Cancel the Supabase auto-refresh timer started by the scripted
        // ApiLayer so the test binding does not report a pending timer.
        result.apiLayer.supabaseClient.auth.stopAutoRefresh();
        observer.dispose();
      });

      test('unauthenticated bootstrap redirects to login (not home)', () async {
        final BootstrapResult result = await AppBootstrap.initialize(
          loadConfig: fakeLoadConfig,
          initializeApi: fakeInitializeApi,
          initializeAuthLayer: fakeInitializeAuthLayer,
          initializeStorage: (_) async => FakeStorageEngine(),
        );

        final FakeAuthProvider authProvider =
            result.authLayer.provider as FakeAuthProvider;
        authProvider.setStatus(AuthStatus.unauthenticated);

        final RouteGuard guard = RouteGuard(authProvider: authProvider);
        expect(guard.redirectResolver(RoutePaths.home), RoutePaths.login);
      });
    });
  });
}
