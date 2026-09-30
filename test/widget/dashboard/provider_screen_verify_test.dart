import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/provider_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';

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
  _StubOnboardingService(this.capability);

  final EntityCapability capability;
  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    _progress = OnboardingProgress(entityId: entityId, capability: capability);
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

Future<void> pumpProvider(
  WidgetTester tester, {
  required String email,
  required EntityCapability capability,
  double width = 1440,
  double height = 900,
}) async {
  final Size prev = tester.view.physicalSize;
  final double dpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = prev;
    tester.view.devicePixelRatio = dpr;
  });
  final JobProvider jobs = JobProvider(service: _StubJobService());
  final HireProvider hires = HireProvider(service: _StubHireService());
  final OnboardingProvider onboarding = OnboardingProvider(
    service: _StubOnboardingService(capability),
  );
  await onboarding.loadProgress('entity-1');
  final _SessionAuth auth = _SessionAuth(
    email.isEmpty ? null : AuthSession(entityId: 'entity-1', email: email),
  );
  addTearDown(() {
    jobs.dispose();
    hires.dispose();
    onboarding.dispose();
    auth.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ChangeNotifierProvider<HireProvider>.value(value: hires),
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: ProviderScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop shows authenticated client identity, no reference data',
      (tester) async {
    await pumpProvider(
      tester,
      email: 'amara.diallo@example.com',
      capability: EntityCapability.hire,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Provider'), findsWidgets);
    expect(find.text('Provider Profile'), findsOneWidget);
    expect(find.text('Amara Diallo'), findsWidgets);
    expect(find.text('amara.diallo@example.com'), findsWidgets);
    expect(find.text('Client'), findsWidgets);
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Jobs Posted'), findsOneWidget);
    // Forbidden reference / legacy terms.
    expect(find.text('TechVentures Africa'), findsNothing);
    expect(find.text('TV'), findsNothing);
    expect(find.text('Employer'), findsNothing);
    expect(find.text('hr@techventures.ng'), findsNothing);
    expect(find.text('+234 801 234 5678'), findsNothing);
    expect(find.text('11–50 employees'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Account Stats'), findsNothing);
    expect(find.text('Rating as Employer'), findsNothing);
  });

  testWidgets('different professional user gets own identity, no stale data',
      (tester) async {
    await pumpProvider(
      tester,
      email: 'john.adewale@example.com',
      capability: EntityCapability.offer,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('John Adewale'), findsWidgets);
    expect(find.text('JA'), findsWidgets);
    expect(find.text('Professional'), findsWidgets);
    expect(find.text('My Work'), findsOneWidget);
    expect(find.text('Amara Diallo'), findsNothing);
    expect(find.text('Client'), findsNothing);
    expect(find.text('Employer'), findsNothing);
  });

  testWidgets('missing email renders honest empty states', (tester) async {
    await pumpProvider(
      tester,
      email: '',
      capability: EntityCapability.both,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Email not available'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Both'), findsWidgets);
  });

  testWidgets('no overflow across widths', (tester) async {
    for (final double w in <double>[
      320,
      360,
      375,
      390,
      414,
      480,
      599,
      600,
      1024,
      1440,
    ]) {
      await pumpProvider(
        tester,
        email: 'amara.diallo@example.com',
        capability: EntityCapability.hire,
        width: w,
        height: 844,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'exception at ${w.toInt()}px',
      );
      expect(
        find.text('Provider Profile'),
        findsOneWidget,
        reason: 'heading missing at ${w.toInt()}px',
      );
      expect(
        find.text('Sign out'),
        findsOneWidget,
        reason: 'sign out missing at ${w.toInt()}px',
      );
    }
  });
}
