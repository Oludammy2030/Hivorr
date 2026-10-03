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
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';
import 'package:hivorr/systems/dashboard/widgets/messaging_thread_meta.dart';
import 'package:provider/provider.dart';

/// Client Messages: conversation list + active chat (EP-04-04).
///
/// Wide layouts (≥ [splitStart]) render the reference two-pane view: the
/// conversation list on the left and the active chat on the right. Narrow
/// layouts keep the established list → thread navigation.
///
/// Every conversation is bound to its own Service Request: the `re: …` line
/// in the list and the banner at the top of the active chat both resolve
/// per conversation from the linked hire's job title
/// ([MessagingThreadMeta.workTitleFor]) — never one static title.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  /// Width at or above which list + active chat render side by side.
  static const double splitStart = 900;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String? _selectedId;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final HireProvider? hires = _maybeHires(context);
    if (hires != null && hires.hires.isEmpty && !hires.isLoading) {
      unawaited(hires.loadList());
    }
    await context.read<MessagingProvider>().loadConversations();
    if (!mounted) return;
    setState(() {
      _selectedId ??= _firstId(context);
    });
    final String? id = _selectedId;
    if (id != null) {
      final MessagingProvider messaging = context.read<MessagingProvider>();
      if (messaging.selected?.id != id) {
        unawaited(messaging.select(id));
      }
    }
  }

  HireProvider? _maybeHires(BuildContext context) {
    try {
      return context.read<HireProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  String? _firstId(BuildContext context) {
    final List<Conversation> conversations = context
        .read<MessagingProvider>()
        .conversations;
    return conversations.isEmpty ? null : conversations.first.id;
  }

  List<Hire> _hiresOf(BuildContext context) {
    try {
      return context.watch<HireProvider>().hires;
    } on ProviderNotFoundException {
      return const <Hire>[];
    }
  }

  List<Conversation> _filtered(
    List<Conversation> conversations,
    List<Hire> hires,
  ) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return conversations;
    return conversations.where((Conversation c) {
      final String preview = (c.lastMessagePreview ?? '').toLowerCase();
      final String work = MessagingThreadMeta.workTitleFor(
        hires,
        c,
      ).toLowerCase();
      final String peer = MessagingThreadMeta.peerLabelFor(
        hires,
        c,
      ).toLowerCase();
      return c.id.toLowerCase().contains(q) ||
          c.contractId.toLowerCase().contains(q) ||
          preview.contains(q) ||
          work.contains(q) ||
          peer.contains(q);
    }).toList(growable: false);
  }

  void _open(BuildContext context, Conversation conversation, bool wide) {
    setState(() => _selectedId = conversation.id);
    if (wide) {
      unawaited(context.read<MessagingProvider>().select(conversation.id));
    } else {
      context.go(RoutePaths.dashboardMessageThread(conversation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MessagingProvider messaging = context.watch<MessagingProvider>();
    final List<Hire> hires = _hiresOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: MobileSafeBody(
        child: messaging.isLoading && messaging.conversations.isEmpty
            ? const HivorrLoadingState()
            : messaging.lastError != null && messaging.conversations.isEmpty
            ? HivorrErrorState(
                message: 'Could not load messages',
                detail: messaging.lastError!.message,
                onRetry: () => unawaited(_load()),
              )
            : messaging.conversations.isEmpty
            ? const HivorrEmptyState(
                title: 'No messages yet',
                subtitle:
                    'Messages with clients and professionals appear here once a hire connects you. Each hire gets its own thread.',
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  if (c.maxWidth >= MessagesScreen.splitStart) {
                    return _SplitView(
                      conversations: _filtered(
                        messaging.conversations,
                        hires,
                      ),
                      selectedId:
                          _selectedId ?? messaging.conversations.first.id,
                      search: _search,
                      onQuery: (String v) => setState(() => _query = v),
                      onSelect: (Conversation conversation) =>
                          _open(context, conversation, true),
                    );
                  }
                  return _ConversationList(
                    conversations: _filtered(messaging.conversations, hires),
                    selectedId: null,
                    search: _search,
                    showSearch: true,
                    onQuery: (String v) => setState(() => _query = v),
                    onSelect: (Conversation conversation) =>
                        _open(context, conversation, false),
                  );
                },
              ),
      ),
    );
  }
}

/// Side-by-side reference layout: list (left) + active chat (right).
class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.conversations,
    required this.selectedId,
    required this.search,
    required this.onQuery,
    required this.onSelect,
  });

  final List<Conversation> conversations;
  final String selectedId;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final ValueChanged<Conversation> onSelect;

  @override
  Widget build(BuildContext context) {
    Conversation selected = conversations.first;
    for (final Conversation c in conversations) {
      if (c.id == selectedId) selected = c;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 340,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                right: BorderSide(color: context.colorScheme.outlineVariant),
              ),
            ),
            child: _ConversationList(
              conversations: conversations,
              selectedId: selected.id,
              search: search,
              showSearch: true,
              onQuery: onQuery,
              onSelect: onSelect,
            ),
          ),
        ),
        Expanded(
          key: ValueKey<String>('thread-${selected.id}'),
          child: _ThreadPane(conversation: selected),
        ),
      ],
    );
  }
}

/// Searchable conversation list (left pane / narrow body).
class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.selectedId,
    required this.search,
    required this.showSearch,
    required this.onQuery,
    required this.onSelect,
  });

  final List<Conversation> conversations;
  final String? selectedId;
  final TextEditingController search;
  final bool showSearch;
  final ValueChanged<String> onQuery;
  final ValueChanged<Conversation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HivorrSpacing.md,
            HivorrSpacing.md,
            HivorrSpacing.md,
            HivorrSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Messages',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tooltip(
                message: 'New message',
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HivorrSpacing.md,
              0,
              HivorrSpacing.md,
              HivorrSpacing.sm,
            ),
            child: TextField(
              controller: search,
              onChanged: onQuery,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HivorrSpacing.md,
                  vertical: HivorrSpacing.sm,
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                context.read<MessagingProvider>().loadConversations(),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.md),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 76,
                color: context.colorScheme.outlineVariant,
              ),
              itemBuilder: (BuildContext context, int i) {
                final Conversation conversation = conversations[i];
                return _ConversationRow(
                  conversation: conversation,
                  selected: conversation.id == selectedId,
                  onTap: () => onSelect(conversation),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One conversation row: peer, per-thread work title, preview, time.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<Hire> hires = _hiresOf(context);
    final String workTitle = MessagingThreadMeta.workTitleFor(
      hires,
      conversation,
    );
    final String peer = MessagingThreadMeta.peerLabelFor(hires, conversation);
    final String initials = MessagingThreadMeta.peerInitials(peer);
    final (Color avatarBg, Color avatarFg) = _avatarTint(context, peer);
    final ColorScheme colors = context.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? colors.primaryContainer.withValues(alpha: 0.45) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: context.textTheme.titleSmall?.copyWith(
                  color: avatarFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          peer,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          HivorrFormatters.relative(
                            conversation.lastMessageAt!,
                          ),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    're: $workTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (conversation.lastMessagePreview != null &&
                      conversation.lastMessagePreview!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      conversation.lastMessagePreview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Hire> _hiresOf(BuildContext context) {
    try {
      return context.watch<HireProvider>().hires;
    } on ProviderNotFoundException {
      return const <Hire>[];
    }
  }

  (Color, Color) _avatarTint(BuildContext context, String seed) {
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    final int h = seed.hashCode.abs() % 3;
    return switch (h) {
      0 => (roles.clientContainer, roles.clientPrimary),
      1 => (ext.successContainer, ext.success),
      _ => (ext.warningContainer, ext.warning),
    };
  }
}

/// Active chat pane: header + per-thread work banner + messages + composer.
class _ThreadPane extends StatefulWidget {
  const _ThreadPane({required this.conversation});

  final Conversation conversation;

  @override
  State<_ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends State<_ThreadPane> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelected());
  }

  @override
  void didUpdateWidget(covariant _ThreadPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _composer.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelected());
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureSelected() {
    if (!mounted) return;
    final MessagingProvider messaging = context.read<MessagingProvider>();
    if (messaging.selected?.id != widget.conversation.id) {
      unawaited(messaging.select(widget.conversation.id));
    }
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
    final List<Hire> hires = _hiresOf(context);
    final String workTitle = MessagingThreadMeta.workTitleFor(
      hires,
      widget.conversation,
    );
    final String peer = MessagingThreadMeta.peerLabelFor(
      hires,
      widget.conversation,
    );
    final Hire? hire = MessagingThreadMeta.hireFor(hires, widget.conversation);
    final Conversation? selected =
        messaging.selected?.id == widget.conversation.id
        ? messaging.selected
        : null;
    final String? entityId = _entityId(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ThreadHeader(peer: peer, conversation: widget.conversation),
        _WorkBanner(workTitle: workTitle, hire: hire),
        if (messaging.isLoading && selected == null)
          const Expanded(child: HivorrLoadingState())
        else if (messaging.lastError != null && selected == null)
          Expanded(
            child: HivorrErrorState(
              message: 'Could not load conversation',
              detail: messaging.lastError!.message,
              onRetry: () {
                _ensureSelected();
              },
            ),
          )
        else Expanded(
          child: messaging.messages.isEmpty || selected == null
              ? const HivorrEmptyState(
                  title: 'No messages yet',
                  subtitle:
                      'Say hello — messages are encrypted end to end between you and the other party.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(HivorrSpacing.md),
                  itemCount: messaging.messages.length + 1,
                  itemBuilder: (BuildContext context, int i) {
                    if (i == 0) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: HivorrSpacing.sm,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: HivorrSpacing.md,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Today',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    final message = messaging.messages[i - 1];
                    final bool mine =
                        entityId != null &&
                        entityId == message.senderEntityId;
                    return _Bubble(message: message, mine: mine);
                  },
                ),
        ),
        _PaneComposer(
          controller: _composer,
          sending: messaging.isSending,
          onSend: _send,
        ),
      ],
    );
  }

  List<Hire> _hiresOf(BuildContext context) {
    try {
      return context.watch<HireProvider>().hires;
    } on ProviderNotFoundException {
      return const <Hire>[];
    }
  }

  String? _entityId(BuildContext context) {
    try {
      return context.watch<AuthProvider>().currentSession?.entityId;
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// Header with peer avatar/name; subtitle carries the live work context.
class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.peer, required this.conversation});

  final String peer;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String initials = MessagingThreadMeta.peerInitials(peer);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: context.textTheme.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  peer,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Contract ${MessagingThreadMeta.contractShort(conversation.contractId)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call',
            onPressed: null,
            icon: const Icon(Icons.phone_outlined),
          ),
          IconButton(
            tooltip: 'Video',
            onPressed: null,
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: null,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

/// Tappable banner binding the open chat to its Service Request.
class _WorkBanner extends StatelessWidget {
  const _WorkBanner({required this.workTitle, required this.hire});

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
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.primary,
              ),
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
          boxShadow: mine
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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

class _PaneComposer extends StatelessWidget {
  const _PaneComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    // SafeArea keeps the composer above the home indicator; Scaffold resize
    // handles the keyboard (no manual viewInsets padding — that would
    // double-offset).
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(
          HivorrSpacing.md,
          HivorrSpacing.sm,
          HivorrSpacing.md,
          HivorrSpacing.md,
        ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Attach',
            onPressed: null,
            icon: const Icon(Icons.attach_file),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: MessageCrypto.maxPlaintextLength,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HivorrSpacing.md,
                  vertical: HivorrSpacing.sm,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                onSend();
              },
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(HivorrSpacing.md),
              minimumSize: const Size(48, 48),
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined, size: 20),
          ),
        ],
        ),
      ),
    );
  }
}
