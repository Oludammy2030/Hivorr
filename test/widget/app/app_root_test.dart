import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/app.dart';
import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('HivorrApp mounts and exposes the AuthProvider', (tester) async {
    final provider = FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
    final observer = AppLifecycleObserver();

    await tester.pumpWidget(
      HivorrApp(
        authProvider: provider,
        localeProvider: FakeLocaleProvider(),
        lifecycleObserver: observer,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HivorrApp), findsOneWidget);

    final BuildContext ctx = tester.element(find.byType(MaterialApp));
    expect(Provider.of<AuthProvider>(ctx, listen: false), same(provider));
  });
}
