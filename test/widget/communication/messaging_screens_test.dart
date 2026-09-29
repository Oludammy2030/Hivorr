import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/screens/conversation_screen.dart';
import 'package:hivorr/systems/dashboard/screens/messages_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../test_helpers.dart';

/// Fake repository with real-crypto ciphertext for contract-1.
class FakeMessagingRepository implements MessagingRepository {
  FakeMessagingRepository({this.asEntity = 'u1', this.empty = false})
    : multi = false;

  /// Three threads on three contracts (per-conversation work binding).
  FakeMessagingRepository.multi({this.asEntity = 'u1'})
    : empty = false,
      multi = true;

  final String asEntity;

  /// When true, the inbox is empty.
  final bool empty;

  /// When true, three threads are served instead of one.
  final bool multi;
  final List<ConversationMessage> sent = <ConversationMessage>[];

  static const String contractId = 'contract-1';
  static const String conversationId = 'conv-1';

  Conversation conversation() => Conversation(
    id: conversationId,
    contractId: contractId,
    createdAt: DateTime.utc(2026, 9, 5, 10),
    updatedAt: DateTime.utc(2026, 9, 5, 11),
    lastMessagePreview: 'See you Monday',
    lastMessageAt: DateTime.utc(2026, 9, 5, 11),
  );

  List<Conversation> _threads() => <Conversation>[
    Conversation(
      id: 'conv-1',
      contractId: 'contract-1',
      createdAt: DateTime.utc(2026, 9, 5, 10),
      updatedAt: DateTime.utc(2026, 9, 5, 11),
      lastMessagePreview: 'Sprint is in the repo',
      lastMessageAt: DateTime.utc(2026, 9, 5, 11),
    ),
    Conversation(
      id: 'conv-2',
      contractId: 'contract-2',
      createdAt: DateTime.utc(2026, 9, 4, 10),
      updatedAt: DateTime.utc(2026, 9, 4, 11),
      lastMessagePreview: 'Revisions by 5pm',
      lastMessageAt: DateTime.utc(2026, 9, 4, 11),
    ),
    Conversation(
      id: 'conv-3',
      contractId: 'contract-3',
      createdAt: DateTime.utc(2026, 9, 3, 10),
      updatedAt: DateTime.utc(2026, 9, 3, 11),
      lastMessagePreview: 'Payment released, thanks',
      lastMessageAt: DateTime.utc(2026, 9, 3, 11),
    ),
  ];

  Future<ConversationMessage> _row({
    required String id,
    required String sender,
    required String text,
    required DateTime at,
  }) async => ConversationMessage(
    id: id,
    conversationId: conversationId,
    senderEntityId: sender,
    bodyEncrypted: await MessageCrypto.encryptText(
      contractId: contractId,
      text: text,
    ),
    bodyPreview: text,
    clientMessageId: 'cm-$id',
    createdAt: at,
  );

  Future<ConversationMessage> _threadRow({
    required String convId,
    required String bindingContractId,
    required String id,
    required String sender,
    required String text,
    required DateTime at,
  }) async => ConversationMessage(
    id: id,
    conversationId: convId,
    senderEntityId: sender,
    bodyEncrypted: await MessageCrypto.encryptText(
      contractId: bindingContractId,
      text: text,
    ),
    bodyPreview: text,
    clientMessageId: 'cm-$id',
    createdAt: at,
  );

  @override
  Future<Conversation> ensureForContract(String contractId) async =>
      conversation();

  @override
  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async => ConversationPage(
    conversations: empty
        ? const <Conversation>[]
        : multi
        ? _threads()
        : <Conversation>[conversation()],
    hasMore: false,
  );

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async {
    if (multi) {
      final String binding = switch (conversationId) {
        'conv-2' => 'contract-2',
        'conv-3' => 'contract-3',
        _ => 'contract-1',
      };
      final String text = switch (conversationId) {
        'conv-2' => 'Revisions by 5pm',
        'conv-3' => 'Payment released, thanks',
        _ => 'Sprint is in the repo',
      };
      final DateTime at = switch (conversationId) {
        'conv-2' => DateTime.utc(2026, 9, 4, 11),
        'conv-3' => DateTime.utc(2026, 9, 3, 11),
        _ => DateTime.utc(2026, 9, 5, 11),
      };
      return MessagePage(
        messages: <ConversationMessage>[
          await _threadRow(
            convId: conversationId,
            bindingContractId: binding,
            id: 'm-$conversationId-1',
            sender: 'pro-other',
            text: text,
            at: at,
          ),
        ],
        hasMore: false,
      );
    }
    return MessagePage(
      messages: <ConversationMessage>[
        await _row(
          id: 'm-2',
          sender: 'pro-1',
          text: 'See you Monday',
          at: DateTime.utc(2026, 9, 5, 11),
        ),
        await _row(
          id: 'm-1',
          sender: asEntity,
          text: 'Can you start Monday?',
          at: DateTime.utc(2026, 9, 5, 10, 30),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) async {
    final ConversationMessage message = ConversationMessage(
      id: 'm-sent',
      conversationId: conversationId,
      senderEntityId: asEntity,
      bodyEncrypted: bodyEncrypted,
      bodyPreview: bodyPreview,
      clientMessageId: clientMessageId,
      createdAt: DateTime.utc(2026, 9, 5, 12),
    );
    sent.add(message);
    return message;
  }
}

List<SingleChildWidget> messagingProviders({
  String entity = 'u1',
  bool empty = false,
}) {
  final FakeMessagingRepository repo = FakeMessagingRepository(
    asEntity: entity,
    empty: empty,
  );
  final MessagingService service = MessagingService(repository: repo);
  return <SingleChildWidget>[
    ChangeNotifierProvider<MessagingProvider>.value(
      value: MessagingProvider(service: service),
    ),
    ChangeNotifierProvider<AuthProvider>.value(
      value: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
    ),
  ];
}

void main() {
  group('MessagesScreen', () {
    testWidgets('lists threads with previews', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const MessagesScreen(),
        providers: messagingProviders(),
      );
      await tester.pumpAndSettle();
      expect(find.text('See you Monday'), findsOneWidget);
    });

    testWidgets('empty inbox explains the next step', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MessagesScreen(),
        providers: messagingProviders(empty: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('once a hire connects you'), findsOneWidget);
    });
  });

  group('ConversationScreen', () {
    testWidgets('decrypts history and sends replies', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const ConversationScreen(conversationId: 'conv-1'),
        providers: messagingProviders(),
      );
      await tester.pumpAndSettle();

      // Both directions render as verified plaintext.
      expect(find.text('Can you start Monday?'), findsOneWidget);
      expect(find.text('See you Monday'), findsWidgets);

      // Send appends the echo without a refetch.
      await tester.enterText(find.byType(TextField), 'Perfect, see you then.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('Perfect, see you then.'), findsOneWidget);
    });

    testWidgets('undecryptable rows render a placeholder, never ciphertext', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const ConversationScreen(conversationId: 'conv-1'),
        providers: messagingProviders(),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('couldn’t be decrypted'), findsNothing);
      // Ciphertext blobs never leak into the UI.
      expect(find.textContaining('"c":'), findsNothing);
    });
  });

  group('MessagesScreen per-conversation work binding', () {
    testWidgets('selecting a thread switches chat + work title', (
      WidgetTester tester,
    ) async {
      final HireProvider hires = HireProvider(
        service: HireService(repository: _StubHireRepository.threeThreads()),
      );
      addTearDown(hires.dispose);
      final FakeMessagingRepository repo = FakeMessagingRepository.multi();
      final MessagingProvider messaging = MessagingProvider(
        service: MessagingService(repository: repo),
      );
      addTearDown(messaging.dispose);

      await pumpScreen(
        tester,
        const MessagesScreen(),
        width: 1280,
        height: 800,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<MessagingProvider>.value(value: messaging),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<AuthProvider>.value(
            value: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Each thread lists its own Service Request.
      expect(find.text('re: Senior React Developer'), findsOneWidget);
      expect(find.text('re: Brand Identity Design'), findsOneWidget);
      expect(find.text('re: Plumbing Emergency Fix'), findsOneWidget);

      // The banner starts on the first thread's work (not a static title).
      expect(find.text('Senior React Developer'), findsOneWidget);

      // Selecting another conversation swaps both chat and banner.
      await tester.tap(find.text('re: Brand Identity Design'));
      await tester.pumpAndSettle();
      expect(find.text('Brand Identity Design'), findsOneWidget);
      expect(find.text('Senior React Developer'), findsNothing);
      expect(find.text('Revisions by 5pm'), findsWidgets);
    });

    testWidgets('thread route shows its own work title', (
      WidgetTester tester,
    ) async {
      final HireProvider hires = HireProvider(
        service: HireService(repository: _StubHireRepository.threeThreads()),
      );
      addTearDown(hires.dispose);
      await hires.loadList();
      final MessagingProvider messaging = MessagingProvider(
        service: MessagingService(
          repository: FakeMessagingRepository.multi(),
        ),
      );
      addTearDown(messaging.dispose);

      await pumpApp(
        tester,
        const ConversationScreen(conversationId: 'conv-3'),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<MessagingProvider>.value(value: messaging),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<AuthProvider>.value(
            value: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Plumbing Emergency Fix'), findsWidgets);
      expect(find.text('Senior React Developer'), findsNothing);
    });
  });
}

/// Three hires binding one contract each to its Service Request title.
class _StubHireRepository implements HireRepository {
  _StubHireRepository(this._hires);

  factory _StubHireRepository.threeThreads() => _StubHireRepository(
    <Hire>[
      _hire(
        id: 'hire-1',
        contractId: 'contract-1',
        professional: 'pro-amara',
        title: 'Senior React Developer',
      ),
      _hire(
        id: 'hire-2',
        contractId: 'contract-2',
        professional: 'pro-kwame',
        title: 'Brand Identity Design',
      ),
      _hire(
        id: 'hire-3',
        contractId: 'contract-3',
        professional: 'pro-nadia',
        title: 'Plumbing Emergency Fix',
      ),
    ],
  );

  final List<Hire> _hires;

  static Hire _hire({
    required String id,
    required String contractId,
    required String professional,
    required String title,
  }) => Hire(
    id: id,
    jobId: 'job-$id',
    applicationId: 'app-$id',
    clientEntityId: 'client-1',
    professionalEntityId: professional,
    contractId: contractId,
    status: 'active',
    hiredAt: DateTime.utc(2026, 9, 1),
    effectiveStatus: 'active',
    jobTitle: title,
  );

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => HirePage(hires: _hires, hasMore: false);

  @override
  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  }) => throw UnimplementedError();

  @override
  Future<HireDetail> getHire(String hireId) => throw UnimplementedError();

  @override
  Future<JobQuotation> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) => throw UnimplementedError();

  @override
  Future<JobQuotation> withdrawQuotation(String quotationId) =>
      throw UnimplementedError();

  @override
  Future<JobQuotation> acceptQuotation(String quotationId) =>
      throw UnimplementedError();

  @override
  Future<Hire> cancelHire(String hireId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<Hire> completeHire(String hireId) => throw UnimplementedError();
}
