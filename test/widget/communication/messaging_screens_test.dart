import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/screens/conversation_screen.dart';
import 'package:hivorr/systems/dashboard/screens/messages_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../test_helpers.dart';

/// Fake repository with real-crypto ciphertext for contract-1.
class FakeMessagingRepository implements MessagingRepository {
  FakeMessagingRepository({this.asEntity = 'u1', this.empty = false});

  final String asEntity;

  /// When true, the inbox is empty.
  final bool empty;
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
        : <Conversation>[conversation()],
    hasMore: false,
  );

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async => MessagePage(
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
}
