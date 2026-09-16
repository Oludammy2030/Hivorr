import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/systems/admin/screens/manage_user_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/fakes/fake_manage_user.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<(ManageUserProvider, AdminReviewProvider)> pumpScreenWith(
    WidgetTester tester, {
    FakeManageUserRepository? manageRepo,
    FakeAdminReviewRepository? adminRepo,
  }) async {
    final FakeManageUserRepository resolvedManage =
        manageRepo ?? FakeManageUserRepository();
    final FakeAdminReviewRepository resolvedAdmin =
        adminRepo ?? FakeAdminReviewRepository(isAdmin: true);
    final ManageUserProvider manageProvider =
        ManageUserProvider(repo: resolvedManage);
    final AdminReviewProvider adminProvider =
        AdminReviewProvider(repo: resolvedAdmin);
    await pumpApp(
      tester,
      const ManageUserScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ManageUserProvider>.value(value: manageProvider),
        ChangeNotifierProvider<AdminReviewProvider>.value(
          value: adminProvider,
        ),
      ],
    );
    // Let the post-frame checkAdmin + loadUsers settle.
    await tester.pump();
    await tester.pump();
    return (manageProvider, adminProvider);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('ManageUserScreen layout', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      expect(find.text('Manage users'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the admin gate when the user is not an admin',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        adminRepo: FakeAdminReviewRepository(isAdmin: false),
      );
      expect(find.text('Admin access required'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the empty state when the directory is empty',
        (WidgetTester tester) async {
      await pumpScreenWith(tester);
      expect(find.text('No users found'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('lists users with status + role metadata',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        manageRepo: FakeManageUserRepository(
          users: <ManageUserListItem>[
            manageUserListItem(
              id: 'u1',
              displayName: 'Ada Lovelace',
              status: 'active',
            ),
            manageUserListItem(
              id: 'u2',
              displayName: 'Grace Hopper',
              status: 'suspended',
            ),
          ],
        ),
      );
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('suspended'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('initial load', () {
    testWidgets('fetches the directory for admins on first build',
        (WidgetTester tester) async {
      final FakeManageUserRepository repo = FakeManageUserRepository(
        users: <ManageUserListItem>[
          manageUserListItem(id: 'u1', displayName: 'Ada Lovelace'),
        ],
      );
      await pumpScreenWith(tester, manageRepo: repo);

      expect(repo.listCallCount, greaterThanOrEqualTo(1));
      expect(find.text('Ada Lovelace'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('does not fetch the directory for non-admins',
        (WidgetTester tester) async {
      final FakeManageUserRepository repo = FakeManageUserRepository(
        users: <ManageUserListItem>[manageUserListItem(id: 'u1')],
      );
      await pumpScreenWith(
        tester,
        manageRepo: repo,
        adminRepo: FakeAdminReviewRepository(isAdmin: false),
      );

      expect(repo.listCallCount, 0);
      await unmount(tester);
    });
  });
}