import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/services/messaging_service.dart';

/// Messages inbox over the [MessagingService] seam (EP-04-03).
///
/// Conversations are contract-scoped threads (one per hire). Until the
/// conversations read path is connected, the seam reports none and this
/// screen renders its honest empty state with the next action — no
/// fabricated threads. Structure (list, refresh, error/retry) stays put for
/// the RPC swap.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.service = const EmptyMessagingService(),
  });

  final MessagingService service;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<ConversationSummary> _items = const <ConversationSummary>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ConversationSummary> items = await widget.service
          .listConversations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: _loading
            ? const HivorrLoadingState()
            : _error != null
            ? HivorrErrorState(
                message: 'Could not load messages',
                detail: _error!,
                onRetry: () => unawaited(_load()),
              )
            : _items.isEmpty
            ? const HivorrEmptyState(
                title: 'No messages yet',
                subtitle:
                    'Messages with clients and professionals appear here once a hire connects you. Each hire gets its own thread.',
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(HivorrSpacing.md),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: HivorrSpacing.sm),
                  itemBuilder: (BuildContext context, int i) {
                    final ConversationSummary conversation = _items[i];
                    return HivorrCard(
                      onTap: () {},
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            conversation.title,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (conversation.lastMessage != null) ...<Widget>[
                            const SizedBox(height: HivorrSpacing.xs),
                            Text(
                              conversation.lastMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall,
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
