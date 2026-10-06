import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/profile_screen.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

class _StubJobService implements JobService {
  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async =>
      const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async =>
      const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubHireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async =>
      const HirePage(hires: <Hire>[], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubOnboardingService implements OnboardingService {
  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    _progress = OnboardingProgress(
      entityId: entityId,
      capability: EntityCapability.offer,
    );
    return OnboardingStepCode.capability;
  }

  @override
  void disposeProgress() => _progress = null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubPayoutRepository implements FinancialPayoutRepository {
  _StubPayoutRepository(this.accounts);

  final List<PayoutAccount> accounts;

  @override
  Future<List<PayoutAccount>> listPayoutAccounts() async => accounts;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SessionAuth extends FakeAuthProvider {
  _SessionAuth()
      : super(initialStatus: AuthStatus.authenticated);

  bool signedOut = false;

  @override
  AuthSession? get currentSession => const AuthSession(
        entityId: 'entity-1',
        email: 'amara.diallo@example.com',
        firstName: 'Amara',
        lastName: 'Diallo',
      );

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

PayoutAccount _account({
  required String id,
  required String bankName,
  required String accountNumber,
  required bool isDefault,
}) =>
    PayoutAccount(
      id: id,
      currencyCode: 'NGN',
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: 'Amara Diallo',
      status: PayoutAccountStatus.active,
      isVerified: true,
      isDefault: isDefault,
    );

void main() {
  group('Professional Profile → Settings tab', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late _SessionAuth auth;
    late FinancialPayoutProvider payouts;

    setUp(() async {
      jobs = JobProvider(service: _StubJobService());
      hires = HireProvider(service: _StubHireService());
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = _SessionAuth();
      payouts = FinancialPayoutProvider(
        service: FinancialPayoutService(
          repository: _StubPayoutRepository(const []),
        ),
      );
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
        payouts.dispose();
      });
    });

    Future<void> pumpSettings(
      WidgetTester tester, {
      FinancialPayoutProvider? payoutProvider,
    }) async {
      await pumpScreen(
        tester,
        const ProfileScreen(),
        width: 1440,
        height: 900,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FinancialPayoutProvider>.value(
            value: payoutProvider ?? payouts,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Finder settings = find.text('Settings').last;
      await tester.ensureVisible(settings);
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
    }

    testWidgets('renders the reference settings content', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Available for new work'), findsOneWidget);
      expect(find.text('Open to full-time roles'), findsOneWidget);
      expect(find.text('Open to part-time'), findsOneWidget);
      expect(find.text('Remote only'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New job matches'), findsOneWidget);
      expect(find.text('Application updates'), findsOneWidget);
      expect(find.text('Payment received'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Weekly summary'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(9));
      expect(find.text('Payout Account'), findsOneWidget);
      expect(find.text('GTBank — Savings **** 4521'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Chipper Cash — @amara.diallo'), findsOneWidget);
      expect(find.text('+ Add Payout Method'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
      // Other tabs are replaced; header + tabs stay.
      expect(find.text('Personal Information'), findsNothing);
      expect(find.text('Amara Diallo'), findsWidgets);
    });

    testWidgets('toggling a switch flips its state', (tester) async {
      await pumpSettings(tester);

      final Finder first = find.byType(Switch).first;
      expect(tester.widget<Switch>(first).value, isTrue);
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(first).value, isFalse);
    });

    testWidgets('sign out uses the auth provider', (tester) async {
      await pumpSettings(tester);

      final Finder signOut = find.text('Sign Out');
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(auth.signedOut, isTrue);
    });

    testWidgets('delete account confirms and reports honestly', (tester) async {
      await pumpSettings(tester);

      final Finder delete = find.text('Delete Account');
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete Account?'), findsOneWidget);

      await tester.tap(find.text('Delete Account').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Account deletion is not available yet.'),
        findsOneWidget,
      );
    });

    testWidgets('bound payout accounts render live', (tester) async {
      final FinancialPayoutProvider live = FinancialPayoutProvider(
        service: FinancialPayoutService(
          repository: _StubPayoutRepository(<PayoutAccount>[
            _account(
              id: 'pa-1',
              bankName: 'GTBank',
              accountNumber: '0123454521',
              isDefault: true,
            ),
            _account(
              id: 'pa-2',
              bankName: 'Access Bank',
              accountNumber: '0099887766',
              isDefault: false,
            ),
          ]),
        ),
      );
      addTearDown(live.dispose);

      await pumpSettings(tester, payoutProvider: live);

      expect(find.text('GTBank — ***4521'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Access Bank — ***7766'), findsOneWidget);
      expect(find.text('Chipper Cash — @amara.diallo'), findsNothing);
    });
  });
}
