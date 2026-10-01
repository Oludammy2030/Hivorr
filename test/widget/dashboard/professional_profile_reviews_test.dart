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
  _SessionAuth()
      : super(initialStatus: AuthStatus.authenticated);

  @override
  AuthSession? get currentSession => const AuthSession(
        entityId: 'entity-1',
        email: 'amara.diallo@example.com',
        firstName: 'Amara',
        lastName: 'Diallo',
      );
}

void main() {
  group('Professional Profile → Reviews tab', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late _SessionAuth auth;

    setUp(() async {
      jobs = JobProvider(service: _StubJobService());
      hires = HireProvider(service: _StubHireService());
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = _SessionAuth();
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

    testWidgets('renders the reference reviews content', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();

      expect(find.text('TechVentures Africa'), findsOneWidget);
      expect(find.text('React Developer · 2 weeks ago'), findsOneWidget);
      expect(
        find.text(
          'Exceptional work. Amara delivered a production-ready fintech dashboard 2 weeks ahead of schedule.',
        ),
        findsOneWidget,
      );
      expect(find.text('StartupHub GH'), findsOneWidget);
      expect(find.text('Brand Platform · 1 month ago'), findsOneWidget);
      expect(
        find.text(
          'Outstanding design intuition paired with clean code. Our product is 10x better because of Amara.',
        ),
        findsOneWidget,
      );
      // Cover star + five stars per review card.
      expect(find.byIcon(Icons.star), findsNWidgets(11));
      // Reviews replace the other tab contents; header + tabs stay.
      expect(find.text('Personal Information'), findsNothing);
      expect(find.text('Portfolio Items'), findsNothing);
      expect(find.text('Amara Diallo'), findsWidgets);
    });

    testWidgets('switching tabs swaps reviews and portfolio', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      expect(find.text('Portfolio Items'), findsOneWidget);
      expect(find.text('TechVentures Africa'), findsNothing);

      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();
      expect(find.text('TechVentures Africa'), findsOneWidget);
      expect(find.text('Portfolio Items'), findsNothing);

      // Settings renders the settings content.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('TechVentures Africa'), findsNothing);
    });
  });
}
