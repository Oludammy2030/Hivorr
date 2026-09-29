import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/widgets/messaging_thread_meta.dart';
import 'package:provider/provider.dart';

/// One contract-scoped message thread (EP-04-04).
///
/// Loads verified-plaintext history (oldest first), offers earlier paging,
/// and sends AES-GCM-encrypted replies. Messages that fail authentication
/// render an undecryptable placeholder — never guessed plaintext.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume reload: realtime is excluded for messaging tables, so the open
    // thread refreshes when the app foregrounds (mirrors dispute/escrow
    // lifecycle screens).
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<MessagingProvider>().refresh());
    }
  }

  Future<void> _load() =>
      context.read<MessagingProvider>().select(widget.conversationId);

  String _title() {
    final MessagingProvider messaging = context.read<MessagingProvider>();
    final Conversation? selected = messaging.selected;
    if (selected == null) return 'Conversation';
    HireProvider? hires;
    try {
      hires = context.read<HireProvider>();
    } on ProviderNotFoundException {
      hires = null;
    }
    for (final Hire hire in hires?.hires ?? const <Hire>[]) {
      if (hire.contractId == selected.contractId &&
          (hire.jobTitle ?? '').isNotEmpty) {
        return hire.jobTitle!;
      }
    }
    return 'Conversation';
  }

  Future<void> _send() async {
    final String text = _composer.text;
    if (!MessagingService.validateText(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Message must be 1 to 4000 characters.',
          variant: HivorrSnackbarVariant.error,
        ),
      );
      return;
    }
    _composer.clear();
    try {
      await context.read<MessagingProvider>().send(text);
      if (!mounted) return;
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MessagingProvider messaging = context.watch<MessagingProvider>();
    final Conversation? selected =
        messaging.selected?.id == widget.conversationId
        ? messaging.selected
        : null;
    final String? entityId = context
        .watch<AuthProvider>()
        .currentSession
        ?.entityId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(), style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: MobileSafeBody(
        child: messaging.isLoading && selected == null
            ? const HivorrLoadingState()
            : messaging.lastError != null && selected == null
            ? HivorrErrorState(
                message: 'Could not load conversation',
                detail: messaging.lastError!.message,
                onRetry: () => unawaited(_load()),
              )
            : selected == null
            ? const HivorrLoadingState()
            : Builder(
                builder: (BuildContext context) {
                  final List<Hire> threadHires = _threadHires(context);
                  final String workTitle =
                      MessagingThreadMeta.workTitleFor(
                        threadHires,
                        selected,
                      );
                  final Hire? threadHire = MessagingThreadMeta.hireFor(
                    threadHires,
                    selected,
                  );
                  return Column(
                    children: <Widget>[
                      _ThreadWorkBanner(
                        workTitle: workTitle,
                        hire: threadHire,
                      ),
                      if (messaging.messagesHasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: HivorrSpacing.xs,
                      ),
                      child: HivorrButton(
                        label: messaging.isRefreshing
                            ? 'Loading…'
                            : 'Load earlier messages',
                        variant: HivorrButtonVariant.text,
                        onPressed: messaging.isRefreshing
                            ? null
                            : () => unawaited(
                                context.read<MessagingProvider>().loadEarlier(),
                              ),
                      ),
                    ),
                  Expanded(
                    child: messaging.messages.isEmpty
                        ? const HivorrEmptyState(
                            title: 'No messages yet',
                            subtitle:
                                'Say hello — messages are encrypted end to end between you and the other party.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(HivorrSpacing.md),
                            itemCount: messaging.messages.length,
                            itemBuilder: (BuildContext context, int i) {
                              final message = messaging.messages[i];
                              final bool mine =
                                  entityId != null &&
                                  entityId == message.senderEntityId;
                              return _Bubble(message: message, mine: mine);
                            },
                          ),
                  ),
                  _Composer(
                    controller: _composer,
                    sending: messaging.isSending,
                    onSend: _send,
                  ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  List<Hire> _threadHires(BuildContext context) {
    try {
      return context.watch<HireProvider>().hires;
    } on ProviderNotFoundException {
      return const <Hire>[];
    }
  }
}

/// Banner binding the open thread to its Service Request.
///
/// Resolved per conversation from the linked hire — selecting another
/// thread updates this title automatically because it reads
/// `MessagingProvider.selected` on every build.
class _ThreadWorkBanner extends StatelessWidget {
  const _ThreadWorkBanner({required this.workTitle, required this.hire});

  final String workTitle;
  final Hire? hire;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: hire == null
          ? null
          : () => context.go(RoutePaths.dashboardHireDetail(hire!.id)),
      child: Container(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.business_center_outlined,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: Text(
                workTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hire != null)
              Icon(Icons.chevron_right, size: 20, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ConversationMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? text = message.decryptedBody;
    final Alignment alignment = mine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final Color fill = mine ? colors.primary : colors.surface;
    final Color foreground = mine ? colors.onPrimary : colors.onSurface;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxBubble = MobileCompact.bubbleMaxWidth(screenWidth);
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubble),
        margin: const EdgeInsets.symmetric(vertical: HivorrSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              text ?? 'This message couldn’t be decrypted.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontStyle: text == null ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              HivorrFormatters.time(message.createdAt),
              style: context.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    // SafeArea keeps the composer above the home indicator/gesture bar;
    // the Scaffold's resize handles the keyboard so no manual viewInsets
    // padding is added (that would double-offset above the keyboard).
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          border: Border(
            top: BorderSide(color: context.colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          HivorrSpacing.md,
          HivorrSpacing.sm,
          HivorrSpacing.md,
          HivorrSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: MessageCrypto.maxPlaintextLength,
                decoration: const InputDecoration(
                  hintText: 'Write a message…',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            IconButton.filled(
              tooltip: 'Send',
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: sending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
