import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Messages inbox: contract-scoped threads (EP-04-04).
///
/// Threads resolve titles from the hire list (job title per linked
/// contract); unknown contracts fall back to a short contract reference.
/// Each thread shows the server-redacted preview — opening it decrypts the
/// full history. Empty/error/loading/refresh states included.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final HireProvider? hires = _maybeHires(context);
    if (hires != null && hires.hires.isEmpty && !hires.isLoading) {
      unawaited(hires.loadList());
    }
    await context.read<MessagingProvider>().loadConversations();
  }

  HireProvider? _maybeHires(BuildContext context) {
    try {
      return context.read<HireProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  String _titleFor(BuildContext context, Conversation conversation) {
    HireProvider? hires;
    try {
      hires = context.watch<HireProvider>();
    } on ProviderNotFoundException {
      hires = null;
    }
    final List<Hire> all = hires?.hires ?? const <Hire>[];
    for (final Hire hire in all) {
      if (hire.contractId == conversation.contractId &&
          (hire.jobTitle ?? '').isNotEmpty) {
        return hire.jobTitle!;
      }
    }
    final String contract = conversation.contractId;
    final String short = contract.length <= 8
        ? contract
        : contract.substring(contract.length - 8);
    return 'Contract …$short';
  }

  @override
  Widget build(BuildContext context) {
    final MessagingProvider messaging = context.watch<MessagingProvider>();

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
      body: SafeArea(
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
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(HivorrSpacing.md),
                  itemCount: messaging.conversations.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: HivorrSpacing.sm),
                  itemBuilder: (BuildContext context, int i) {
                    final Conversation conversation =
                        messaging.conversations[i];
                    return HivorrCard(
                      onTap: () => context.go(
                        RoutePaths.dashboardMessageThread(conversation.id),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  _titleFor(context, conversation),
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
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (conversation.lastMessagePreview != null &&
                              conversation
                                  .lastMessagePreview!
                                  .isNotEmpty) ...<Widget>[
                            const SizedBox(height: HivorrSpacing.xs),
                            Text(
                              conversation.lastMessagePreview!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
