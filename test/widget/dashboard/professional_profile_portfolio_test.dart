import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
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
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
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

/// Scripted avatar pick: a decodable 1x1 PNG.
class _FakePicker extends PlatformFilePicker {
  @override
  Future<PickedAvatar?> pickAvatar() async => PickedAvatar(
        bytes: Uint8List.fromList(_tinyPng),
        fileName: 'avatar.png',
        mimeType: 'image/png',
      );
}

const List<int> _tinyPng = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 250, 207, 192, 0, //
  24, 5, 3, 2, 152, 195, 66, 150, 0, 0, 0, 0, 73, 69, 78, 68, //
  174, 66, 96, 130,
];

void main() {
  group('Professional Profile → Portfolio tab', () {
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

    Future<void> pumpProfile(
      WidgetTester tester, {
      bool withPicker = true,
    }) {
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
          if (withPicker)
            Provider<PlatformFilePicker>.value(value: _FakePicker()),
        ],
      );
    }

    testWidgets('renders the reference portfolio content', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio Items'), findsOneWidget);
      expect(find.text('Add Project'), findsOneWidget);
      expect(find.text('FinTrack Dashboard'), findsOneWidget);
      expect(find.text('React / Node.js'), findsOneWidget);
      expect(find.text('AfriShop E-commerce'), findsOneWidget);
      expect(find.text('Next.js / PostgreSQL'), findsOneWidget);
      expect(find.text('POS Mobile App'), findsOneWidget);
      expect(find.text('React Native / AWS'), findsOneWidget);
      // Profile tab content is replaced, header + tabs stay.
      expect(find.text('Personal Information'), findsNothing);
      expect(find.text('Amara Diallo'), findsWidgets);
    });

    testWidgets('add project appends a card', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Project'));
      await tester.pumpAndSettle();
      expect(find.text('Add Project'), findsWidgets);

      final Finder fields = find.byType(TextField);
      final int count = tester.widgetList<TextField>(fields).length;
      await tester.enterText(fields.at(count - 2), 'Health Tracker');
      await tester.enterText(fields.at(count - 1), 'Flutter / Firebase');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      expect(find.text('Health Tracker'), findsOneWidget);
      expect(find.text('Project added.'), findsOneWidget);
    });

    testWidgets('avatar pick shows the picture on every tab', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // Initials fallback before any picture exists.
      expect(find.text('AD'), findsWidgets);
      expect(find.byType(Image), findsNothing);

      final Finder camera = find.descendant(
        of: find.byTooltip('Change profile picture'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(camera);
      await tester.pumpAndSettle();
      await tester.tap(camera);
      await tester.pumpAndSettle();

      expect(find.text('Profile picture updated.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // The shared identity follows across tabs.
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Portfolio Items'), findsOneWidget);
    });

    testWidgets('camera without a picker reports honestly', (tester) async {
      await pumpProfile(tester, withPicker: false);
      await tester.pumpAndSettle();

      final Finder camera = find.descendant(
        of: find.byTooltip('Change profile picture'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(camera);
      await tester.pumpAndSettle();
      await tester.tap(camera);
      await tester.pumpAndSettle();

      expect(
        find.text('Photo upload is not available here.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });
  });
}
