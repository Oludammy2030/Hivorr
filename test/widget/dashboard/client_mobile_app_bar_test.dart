import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/screens/client_find_service_screen.dart';
import 'package:hivorr/systems/dashboard/screens/finance_hubs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/job_form_screen.dart';
import 'package:hivorr/systems/dashboard/screens/messages_screen.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/dashboard/screens/profile_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

class _EmptyJobService implements JobService {
  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyHireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const HirePage(hires: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HireOnboardingService implements OnboardingService {
  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    _progress = OnboardingProgress(
      entityId: entityId,
      capability: EntityCapability.hire,
    );
    return OnboardingStepCode.capability;
  }

  @override
  void disposeProgress() => _progress = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyMessagingRepository implements MessagingRepository {
  @override
  Future<Conversation> ensureForContract(String contractId) =>
      throw UnimplementedError();

  @override
  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async =>
      const ConversationPage(conversations: [], hasMore: false);

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async => const MessagePage(messages: [], hasMore: false);

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) => throw UnimplementedError();
}

void main() {
  group('ClientMobileAppBar (shared mobile chrome)', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late AuthProvider auth;

    setUp(() async {
      jobs = JobProvider(service: _EmptyJobService());
      hires = HireProvider(service: _EmptyHireService());
      onboarding = OnboardingProvider(service: _HireOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = AuthProvider(service: FakeAuthService());
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
    });

    List<SingleChildWidget> baseProviders() => <SingleChildWidget>[
      ChangeNotifierProvider<JobProvider>.value(value: jobs),
      ChangeNotifierProvider<HireProvider>.value(value: hires),
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ];

    Future<void> pumpPage(
      WidgetTester tester,
      Widget page, {
      List<SingleChildWidget>? extra,
    }) async {
      await pumpScreen(
        tester,
        page,
        width: 390,
        height: 844,
        providers: <SingleChildWidget>[...baseProviders(), ...?extra],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    void expectSharedBar(WidgetTester tester, String title) {
      // Exactly one app bar: hamburger + title share one compact row on the
      // left; bell + Client pill + avatar on the right. Home never shows.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text('My Hivorr'), findsNothing);
      expect(find.text('Hivorr'), findsNothing);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('client-indicator')),
          findsOneWidget);
      expect(find.text('Client'), findsWidgets);
      expect(find.byTooltip('Profile'), findsOneWidget);
      final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.toolbarHeight, 48);
      expect(bar.preferredSize.height, 48);
    }

    testWidgets('My Jobs uses the shared bar with its own title', (
      tester,
    ) async {
      await pumpPage(tester, const MyJobsScreen());
      expectSharedBar(tester, 'My Jobs');
    });

    testWidgets('Post Job uses the shared bar with its own title', (
      tester,
    ) async {
      await pumpPage(tester, const JobFormScreen());
      expectSharedBar(tester, 'Post a Job');
    });

    testWidgets('Applications uses the shared bar with its own title', (
      tester,
    ) async {
      await pumpPage(tester, const MyApplicationsScreen());
      expectSharedBar(tester, 'Applications');
    });

    testWidgets('Messages uses the shared bar for hire focus', (
      tester,
    ) async {
      final messaging = MessagingProvider(
        service: MessagingService(repository: _EmptyMessagingRepository()),
      );
      addTearDown(messaging.dispose);
      await pumpPage(
        tester,
        const MessagesScreen(),
        extra: <SingleChildWidget>[
          ChangeNotifierProvider<MessagingProvider>.value(value: messaging),
        ],
      );
      expectSharedBar(tester, 'Messages');
    });

    testWidgets('Messages keeps the legacy bar without a provider', (
      tester,
    ) async {
      final messaging = MessagingProvider(
        service: MessagingService(repository: _EmptyMessagingRepository()),
      );
      addTearDown(messaging.dispose);
      // No OnboardingProvider: no hamburger, legacy bar, same title.
      await pumpScreen(
        tester,
        const MessagesScreen(),
        width: 390,
        height: 844,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<MessagingProvider>.value(value: messaging),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byTooltip('Menu'), findsNothing);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('Payments uses the shared bar with its own title', (
      tester,
    ) async {
      await pumpPage(tester, const PaymentsScreen());
      expectSharedBar(tester, 'Payments');
    });

    testWidgets('Profile uses the shared bar with its own title', (
      tester,
    ) async {
      await pumpPage(tester, const ProfileScreen());
      expectSharedBar(tester, 'Profile');
    });

    testWidgets('Find Services uses the shared bar with its own title', (
      tester,
    ) async {
      const Industry industry = Industry(
        id: 'ind-1',
        slug: 'artisans',
        name: 'Artisans',
        isActive: true,
        sortOrder: 10,
      );
      const Profession profession = Profession(
        id: 'prof-9',
        industryId: 'ind-1',
        slug: 'plumber',
        name: 'Plumber',
        isActive: true,
        sortOrder: 10,
      );
      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: FakeServiceSearchRepository(items: const <ServiceListing>[]),
      );
      addTearDown(search.dispose);
      final TaxonomyProvider taxonomy = TaxonomyProvider(
        repository: FakeTaxonomyRepository(
          industries: const <Industry>[industry],
          professionsByIndustry: const <String, List<Profession>>{
            'ind-1': <Profession>[profession],
          },
        ),
      );
      addTearDown(taxonomy.dispose);
      await pumpPage(
        tester,
        const ClientFindServiceScreen(),
        extra: <SingleChildWidget>[
          ChangeNotifierProvider<MarketplaceSearchProvider>.value(
            value: search,
          ),
          ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy),
          Provider<ServiceListingService>.value(
            value: ServiceListingService(
              repository: FakeServiceListingRepository(seed: const []),
            ),
          ),
        ],
      );
      expectSharedBar(tester, 'Find Services');
    });

    testWidgets('hamburger opens the client drawer from a sub page', (
      tester,
    ) async {
      await pumpPage(tester, const MyJobsScreen());
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Reference drawer destinations resolve from the sub page too.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Post a Job'), findsWidgets);
      expect(find.text('My Hivorr'), findsNothing);
    });
  });
}
