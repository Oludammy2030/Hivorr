import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/entry/screens/intro_screen.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/local/entry_state_store.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/harnesses/widget_harness.dart';

GoRouter _doorRouter({required String initialLocation}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/intro', builder: _intro),
      GoRoute(path: '/login', builder: _placeholder),
      GoRoute(path: '/', builder: _placeholder),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Widget _intro(BuildContext context, GoRouterState state) => const IntroScreen();
Widget _placeholder(BuildContext context, GoRouterState state) =>
    Scaffold(body: Center(child: Text(state.matchedLocation)));

void main() {
  group('IntroScreen (native first launch)', () {
    testWidgets('renders the first value-prop page and a skip action',
        (tester) async {
      await pumpScreen(
        tester,
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EntryStateProvider>.value(
              value: EntryStateProvider(store: InMemoryEntryStateStore()),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: _doorRouter(initialLocation: '/intro'),
          ),
        ),
      );

      expect(find.text('Verified professionals'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text("Let's begin"), findsOneWidget);
    });

    testWidgets('walks through the pages and reaches "Get started"',
        (tester) async {
      await pumpScreen(
        tester,
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EntryStateProvider>.value(
              value: EntryStateProvider(store: InMemoryEntryStateStore()),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: _doorRouter(initialLocation: '/intro'),
          ),
        ),
      );

      await tester.tap(find.text("Let's begin"));
      await tester.pumpAndSettle();
      expect(find.text('Escrow-protected payments'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Work backed by a record'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('finishing marks the intro seen and navigates to /login',
        (tester) async {
      final entryState =
          EntryStateProvider(store: InMemoryEntryStateStore());
      final GoRouter router = _doorRouter(
        initialLocation: '/intro',
      );
      await pumpScreen(
        tester,
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EntryStateProvider>.value(
                value: entryState),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text("Let's begin"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(entryState.introSeen, isTrue);
      expect(
        router.routerDelegate.state.matchedLocation,
        '/login',
      );
    });

    testWidgets('finishing preserves a carried ?next destination',
        (tester) async {
      final entryState =
          EntryStateProvider(store: InMemoryEntryStateStore());
      final GoRouter router = _doorRouter(
        initialLocation: '/intro?next=/p/acme/1',
      );
      await pumpScreen(
        tester,
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EntryStateProvider>.value(
                value: entryState),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text("Let's begin"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      final GoRouterState state = router.routerDelegate.state;
      expect(state.matchedLocation, '/login');
      expect(state.uri.queryParameters['next'], '/p/acme/1');
    });

    testWidgets('skipping also marks the intro seen', (tester) async {
      final entryState =
          EntryStateProvider(store: InMemoryEntryStateStore());
      final GoRouter router = _doorRouter(
        initialLocation: '/intro',
      );
      await pumpScreen(
        tester,
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EntryStateProvider>.value(
                value: entryState),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(entryState.introSeen, isTrue);
      expect(
        router.routerDelegate.state.matchedLocation,
        '/login',
      );
    });
  });
}
