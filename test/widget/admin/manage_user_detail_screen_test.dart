import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/admin/screens/manage_user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_manage_user.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<ManageUserProvider> pumpScreenWith(
    WidgetTester tester, {
    FakeManageUserRepository? repo,
    String userId = 'u1',
  }) async {
    final FakeManageUserRepository resolvedRepo =
        repo ?? FakeManageUserRepository(detail: manageUserDetail(id: userId));
    final ManageUserProvider provider = ManageUserProvider(repo: resolvedRepo);
    await pumpApp(
      tester,
      ManageUserDetailScreen(userId: userId),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ManageUserProvider>.value(value: provider),
      ],
    );
    // Let the post-frame loadDetail settle.
    await tester.pump();
    await tester.pump();
    return provider;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('ManageUserDetailScreen layout', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      expect(find.text('User detail'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the entity posture', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      // Name appears in the entity header + profile card row.
      expect(find.text('Test User'), findsWidgets);
      expect(find.text('active'), findsOneWidget);
      await scrollTo(tester, find.text('Verification summary'));
      expect(find.text('Verification summary'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the not-found state for an unknown user', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeManageUserRepository(detail: manageUserDetail(id: 'other')),
        userId: 'missing',
      );
      expect(find.text('User not found'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('lifecycle actions', () {
    testWidgets('active users show suspend + deactivate actions', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(tester);
      await scrollTo(tester, find.text('Suspend'));
      expect(find.text('Suspend'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('suspended users show reactivate', (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeManageUserRepository(
          detail: manageUserDetail(id: 'u1', status: 'suspended'),
        ),
      );
      await scrollTo(tester, find.text('Reactivate'));
      expect(find.text('Reactivate'), findsOneWidget);
      expect(find.text('Suspend'), findsNothing);
      await unmount(tester);
    });

    testWidgets('suspend confirms and issues the status change', (
      WidgetTester tester,
    ) async {
      final FakeManageUserRepository repo = FakeManageUserRepository(
        detail: manageUserDetail(id: 'u1', status: 'active'),
      );
      await pumpScreenWith(tester, repo: repo);

      await scrollTo(tester, find.widgetWithText(HivorrButton, 'Suspend'));
      await tester.tap(find.widgetWithText(HivorrButton, 'Suspend'));
      await tester.pumpAndSettle();
      // Confirmation dialog.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Suspend'));
      await tester.pumpAndSettle();

      expect(repo.setStatusCallCount, 1);
      expect(repo.lastStatusChange, 'suspended');
      expect(
        find.textContaining('Status updated to suspended'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('reset onboarding confirms and resets', (
      WidgetTester tester,
    ) async {
      final FakeManageUserRepository repo = FakeManageUserRepository(
        detail: manageUserDetail(id: 'u1', status: 'active'),
      );
      await pumpScreenWith(tester, repo: repo);

      await scrollTo(
        tester,
        find.widgetWithText(HivorrButton, 'Reset onboarding'),
      );
      await tester.tap(find.widgetWithText(HivorrButton, 'Reset onboarding'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(repo.resetCallCount, 1);
      expect(repo.lastResetId, 'u1');
      expect(find.textContaining('Onboarding reset'), findsOneWidget);
      await unmount(tester);
    });
  });
}
