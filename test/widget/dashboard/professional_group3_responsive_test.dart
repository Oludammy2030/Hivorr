import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/screens/finance_hubs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/messages_screen.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/finance/fake_earnings_repository.dart';
import '../../support/harnesses/responsive_harness.dart';
import '../../support/harnesses/widget_harness.dart';

/// Phase 4 Group 3 locks: professional Earnings (live-data summary cards,
/// escrow banner, filterable history, work history) and Messages (searchable
/// conversation list). Amounts, previews, and titles are deliberately long
/// to stress narrow viewports — large-figure balances and chatty previews
/// must clamp, never overflow.
class _Group3JobService implements JobService {
  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false);

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Group3HireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    final DateTime now = DateTime.now();
    return HirePage(
      hires: <Hire>[
        Hire(
          id: 'hire-1',
          jobId: 'job-1',
          applicationId: 'app-1',
          clientEntityId: 'client-1',
          professionalEntityId: 'entity-1',
          status: 'active',
          hiredAt: now.subtract(const Duration(days: 2)),
          jobTitle:
              'Lekki Phase 1 Solar Panel Installation for Twenty Housing Units',
        ),
      ],
      hasMore: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Group3MessagingRepository implements MessagingRepository {
  @override
  Future<Conversation> ensureForContract(String contractId) =>
      throw UnimplementedError();

  @override
  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async {
    final DateTime now = DateTime.now();
    return ConversationPage(
      conversations: <Conversation>[
        Conversation(
          id: 'conv-long',
          contractId: 'contract-1',
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(minutes: 12)),
          lastMessagePreview:
              'Please find attached the revised bill of quantities for the '
              'additional wiring scope we discussed on site yesterday afternoon',
          lastMessageAt: now.subtract(const Duration(minutes: 12)),
          unreadCount: 12,
        ),
        Conversation(
          id: 'conv-short',
          contractId: 'contract-2',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 1)),
          lastMessagePreview: 'Thanks!',
          lastMessageAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      hasMore: false,
    );
  }

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

Future<List<SingleChildWidget>> _earningsProviders() async {
  final JobProvider jobs = JobProvider(service: _Group3JobService());
  final HireProvider hires = HireProvider(service: _Group3HireService());
  final FakeEarningsRepository repo = FakeEarningsRepository(
    summaries: <String, EarningsSummary>{
      'NGN': seedEarningsSummary(
        available: 9806000,
        held: 2800000,
        lifetimeEarned: 45250000,
      ),
    },
    page: seedEarningsPage(
      items: <EarningsTransaction>[
        EarningsTransaction(
          id: 'tx-long',
          type: 'escrow_release',
          currencyCode: 'NGN',
          amount: 1500000,
          direction: 'in',
          sourceEntityId: 'entity-client',
          destinationEntityId: 'entity-pro',
          referenceType: 'escrow',
          referenceId: 'escrow-9',
          description:
              'Milestone 3 released for the Lekki Phase 1 solar installation '
              'contract with additional wiring scope',
          createdAt: DateTime.utc(2026, 10, 1, 12),
          contractId: 'contract-9',
          contractStatus: 'active',
          escrowStatus: 'released',
        ),
      ],
    ),
  );
  final EarningsProvider earnings = EarningsProvider(
    service: ServiceEarningsService(repository: repo),
  );
  final TransactionHistoryProvider history = TransactionHistoryProvider(
    service: ServiceEarningsService(repository: repo),
  );
  final AuthProvider auth = AuthProvider(service: FakeAuthService());
  addTearDown(() {
    jobs.dispose();
    hires.dispose();
    earnings.dispose();
    history.dispose();
    auth.dispose();
  });
  return <SingleChildWidget>[
    ChangeNotifierProvider<JobProvider>.value(value: jobs),
    ChangeNotifierProvider<HireProvider>.value(value: hires),
    ChangeNotifierProvider<EarningsProvider>.value(value: earnings),
    ChangeNotifierProvider<TransactionHistoryProvider>.value(
      value: history,
    ),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];
}

Future<List<SingleChildWidget>> _messagesProviders() async {
  final JobProvider jobs = JobProvider(service: _Group3JobService());
  final HireProvider hires = HireProvider(service: _Group3HireService());
  final MessagingProvider messaging = MessagingProvider(
    service: MessagingService(repository: _Group3MessagingRepository()),
  );
  final OnboardingProvider onboarding = OnboardingProvider(
    service: _OfferOnboardingService(),
  );
  await onboarding.loadProgress('entity-1');
  final AuthProvider auth = AuthProvider(service: FakeAuthService());
  addTearDown(() {
    jobs.dispose();
    hires.dispose();
    messaging.dispose();
    onboarding.dispose();
    auth.dispose();
  });
  return <SingleChildWidget>[
    ChangeNotifierProvider<JobProvider>.value(value: jobs),
    ChangeNotifierProvider<HireProvider>.value(value: hires),
    ChangeNotifierProvider<MessagingProvider>.value(value: messaging),
    ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];
}

void main() {
  group('Group 3 — professional Earnings', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      testWidgets('live data, no overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const EarningsScreen(),
          width: width,
          providers: await _earningsProviders(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Earnings'), findsOneWidget);
        expect(find.text('Available Balance'), findsOneWidget);
        expect(find.text('Work history'), findsOneWidget);

        // History filter drives the server filter alongside the chips.
        await tester.tap(find.text('Earned'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _earningsProviders();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const EarningsScreen(),
        ),
      );
    });
  });

  group('Group 3 — professional Messages', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      testWidgets('long threads, no overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const MessagesScreen(),
          width: width,
          providers: await _messagesProviders(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Messages'), findsOneWidget);
      });
    }

    testWidgets('keyboard-open keeps search usable', (tester) async {
      final List<SingleChildWidget> providers = await _messagesProviders();
      await expectKeyboardSafe(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const MessagesScreen(),
        ),
      );
    });

    testWidgets('tablet split view renders without overflow', (tester) async {
      await pumpScreen(
        tester,
        const MessagesScreen(),
        width: 1024,
        height: 900,
        providers: await _messagesProviders(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Split view keeps both the app-bar title and the desktop list header.
      expect(find.text('Messages'), findsWidgets);
    });

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _messagesProviders();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const MessagesScreen(),
        ),
      );
    });
  });
}
