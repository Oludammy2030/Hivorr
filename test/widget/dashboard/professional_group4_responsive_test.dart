import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_settings_screen.dart';
import 'package:hivorr/systems/dashboard/screens/notifications_screen.dart';
import 'package:hivorr/systems/dashboard/screens/profile_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/responsive_harness.dart';
import '../../support/harnesses/widget_harness.dart';

/// Phase 4 Group 4 locks: professional Profile (cover + tabs + per-tab
/// content), and the shared Notifications/Settings hubs behind the new
/// role-aware chrome. Tab switches are really exercised (content markers),
/// the Profile form is keyboard-checked, and widths cover 320→430 plus the
/// 600dp padding transition for Settings.
class _Group4JobService implements JobService {
  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Group4HireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => HirePage(
    hires: <Hire>[
      Hire(
        id: 'hire-1',
        jobId: 'job-9',
        applicationId: 'app-9',
        clientEntityId: 'client-9',
        professionalEntityId: 'entity-1',
        status: 'active',
        hiredAt: DateTime.now().subtract(const Duration(hours: 3)),
        jobTitle: 'Solar Panel Installation for Twenty Housing Units',
      ),
    ],
    hasMore: false,
  );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _OfferOnboardingService implements OnboardingService {
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

class _SessionAuth extends FakeAuthProvider {
  _SessionAuth(this.session)
    : super(initialStatus: AuthStatus.authenticated);

  final AuthSession? session;

  @override
  AuthSession? get currentSession => session;
}

Future<List<SingleChildWidget>> _group4Providers() async {
  final JobProvider jobs = JobProvider(service: _Group4JobService());
  final HireProvider hires = HireProvider(service: _Group4HireService());
  final OnboardingProvider onboarding = OnboardingProvider(
    service: _OfferOnboardingService(),
  );
  await onboarding.loadProgress('entity-1');
  final _SessionAuth auth = _SessionAuth(
    const AuthSession(
      entityId: 'entity-1',
      email: 'amara.diallo@example.com',
      firstName: 'Amara',
      lastName: 'Diallo',
    ),
  );
  addTearDown(() {
    jobs.dispose();
    hires.dispose();
    onboarding.dispose();
    auth.dispose();
  });
  return <SingleChildWidget>[
    ChangeNotifierProvider<JobProvider>.value(value: jobs),
    ChangeNotifierProvider<HireProvider>.value(value: hires),
    ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];
}

void main() {
  group('Group 4 — professional Profile', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      testWidgets('tabs render without overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const ProfileScreen(),
          width: width,
          providers: await _group4Providers(),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Profile'), findsWidgets);
        expect(find.text('Personal Information'), findsOneWidget);

        await tester.ensureVisible(find.text('Portfolio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Portfolio'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Portfolio Items'), findsOneWidget);

        await tester.ensureVisible(find.text('Reviews'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reviews'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('TechVentures Africa'), findsOneWidget);

        await tester.ensureVisible(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Payout Account'), findsOneWidget);
      });
    }

    testWidgets('keyboard-open keeps the profile form usable', (tester) async {
      final List<SingleChildWidget> providers = await _group4Providers();
      await expectKeyboardSafe(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const ProfileScreen(),
        ),
      );
    });

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _group4Providers();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const ProfileScreen(),
        ),
      );
    });
  });

  group('Group 4 — Notifications (role-aware chrome)', () {
    for (final double width in <double>[320, 360, 390, 430, 1024]) {
      testWidgets('no overflow at ${width.toInt()}dp', (tester) async {
        await pumpScreen(
          tester,
          const NotificationsScreen(),
          width: width,
          providers: await _group4Providers(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Notifications'), findsOneWidget);
        // Professional chrome for offer focus (no client pill).
        expect(find.text('Professional'), findsWidgets);
        expect(find.byTooltip('Menu'), findsNothing);
      });
    }
  });

  group('Group 4 — Settings (role-aware chrome)', () {
    for (final double width in <double>[320, 390, 600, 1024]) {
      testWidgets('no overflow at ${width.toInt()}dp', (tester) async {
        await pumpScreen(
          tester,
          const DashboardSettingsScreen(),
          width: width,
          providers: await _group4Providers(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
      });
    }
  });
}
