import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/profile_screen.dart';
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
      JobPage(jobs: const [], hasMore: false, nextCursor: null);

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async =>
      JobPage(jobs: const [], hasMore: false, nextCursor: null);

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
      HirePage(hires: const <Hire>[], hasMore: false, nextCursor: null);

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

class _SessionAuth extends FakeAuthProvider {
  _SessionAuth(this.session)
      : super(initialStatus: AuthStatus.authenticated);

  final AuthSession? session;

  @override
  AuthSession? get currentSession => session;
}

void main() {
  group('Professional Profile tab (reference)', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late _SessionAuth auth;

    setUp(() async {
      jobs = JobProvider(service: _StubJobService());
      hires = HireProvider(service: _StubHireService());
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = _SessionAuth(
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
    });

    Future<void> pumpProfile(WidgetTester tester) {
      return pumpScreen(
        tester,
        const ProfileScreen(),
        width: 1440,
        height: 900,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
    }

    testWidgets('renders one continuous Profile interface', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dynamic identity from the session — never hardcoded.
      expect(find.text('Amara Diallo'), findsWidgets);
      expect(find.text('AD'), findsWidgets);

      // Cover actions + tabs (`Profile` also matches the top-bar title).
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Profile'), findsWidgets);
      for (final String tab in <String>[
        'Portfolio',
        'Reviews',
        'Settings',
      ]) {
        expect(find.text(tab), findsOneWidget);
      }

      // Profile tab: form, stats, verification, skills — one page.
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Professional Bio'), findsOneWidget);
      expect(find.text('Hourly Rate (USD)'), findsOneWidget);
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.text('Profile Stats'), findsOneWidget);
      expect(find.text('Profile Completeness'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Verification Status'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);
      expect(find.text('Verify →'), findsOneWidget);
      expect(find.text('Skills & Expertise'), findsOneWidget);
      expect(find.text('React'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('+ Add Skill'), findsOneWidget);
    });

    testWidgets('other tabs switch in place with placeholders', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // Reviews is implemented — it swaps in the review list.
      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();
      expect(find.text('TechVentures Africa'), findsOneWidget);
      expect(find.text('Personal Information'), findsNothing);

      // Settings renders the settings content.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('TechVentures Africa'), findsNothing);

      // The tab label shares its text with the top-bar title — the tab is
      // the later match in the tree.
      final Finder profileTab = find.text('Profile').last;
      await tester.ensureVisible(profileTab);
      await tester.pumpAndSettle();
      await tester.tap(profileTab);
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets('removing a skill updates the list', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final Finder firstRemove = find.byIcon(Icons.close).first;
      await tester.ensureVisible(firstRemove);
      await tester.pumpAndSettle();
      await tester.tap(firstRemove);
      await tester.pumpAndSettle();
      expect(find.text('React'), findsNothing);
      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('save validates required fields', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '');
      final Finder save = find.text('Save Profile');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Enter your full name and email.'),
        findsOneWidget,
      );
    });
  });
}
