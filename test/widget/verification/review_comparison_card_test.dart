import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/systems/verification/widgets/review_detail_panels.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/fakes/fake_manage_user.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    ManageUserProvider? users,
    String entityName = 'Test Entity',
  }) async {
    final List<SingleChildWidget> providers = <SingleChildWidget>[
      if (users != null)
        ChangeNotifierProvider<ManageUserProvider>.value(value: users),
    ];
    await pumpApp(
      tester,
      ReviewComparisonCard(
        entry: adminQueueEntry(entityId: 'u1', entityName: entityName),
      ),
      providers: providers,
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  ManageUserProvider providerWith({ManageUserDetail? detail}) {
    final FakeManageUserRepository repo = FakeManageUserRepository();
    if (detail != null) repo.setDetail(detail);
    return ManageUserProvider(repo: repo);
  }

  group('ReviewComparisonCard', () {
    testWidgets('shows differ state for mismatched names', (
      WidgetTester tester,
    ) async {
      await pumpCard(
        tester,
        users: providerWith(detail: manageUserDetail(id: 'u1')),
      );
      // Registered legal name ('Legal Test User') vs submitted ('Test Entity').
      expect(find.text('Legal Test User'), findsOneWidget);
      expect(find.text('Test Entity'), findsOneWidget);
      expect(find.text('Differs'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows matched state for equal names', (
      WidgetTester tester,
    ) async {
      await pumpCard(
        tester,
        users: providerWith(detail: manageUserDetail(id: 'u1')),
        entityName: 'Legal Test User',
      );
      expect(find.text('Legal Test User'), findsNWidgets(2));
      expect(find.text('Differs'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows unavailable state without a user provider', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      expect(find.text('Registered data unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('retry recovers after a failed fetch', (
      WidgetTester tester,
    ) async {
      final FakeManageUserRepository repo = FakeManageUserRepository();
      final ManageUserProvider users = ManageUserProvider(repo: repo);
      addTearDown(users.dispose);
      await pumpCard(tester, users: users);
      expect(find.text('Registered data unavailable.'), findsOneWidget);

      repo.setDetail(manageUserDetail(id: 'u1'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Legal Test User'), findsOneWidget);
      expect(find.text('Differs'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
