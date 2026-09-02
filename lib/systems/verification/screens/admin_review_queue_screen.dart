import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Resolves a human-readable decision outcome label.
typedef TradeReviewResultBuilder = String Function(String shortId);

/// A decision submitted through the (service-role) review seam.
typedef TradeReviewDecider = Future<void> Function({
  required String professionId,
  required bool approved,
  required String notes,
});

/// Simplified admin review queue (EP-02-11 §5.6, §10; decision log #3).
///
/// EP-02 scope is the **simplified** internal screen: a pending-submissions
/// list grouped by profession with one-step approve/reject + optional notes.
/// Advanced pagination / filters / bulk / image preview are deferred. The
/// approve/reject actions invoke the injected [onDecide] seam, which is the
/// client-side handle for the service-role `verification_review_approve/reject`
/// path — the admin UI never holds or leaks the `service_role` key.
class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({
    super.key,
    this.onDecide,
    this.professionLabel,
  });

  /// The service-role review seam. When `null`, decisions are disabled.
  final TradeReviewDecider? onDecide;

  /// Optional profession label resolver.
  final TradeReviewResultBuilder? professionLabel;

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  final Map<String, TextEditingController> _notes = <String, TextEditingController>{};
  final Set<String> _busy = <String>{};
  String? _feedback;

  @override
  void initState() {
    super.initState();
    // The queue screen is a read-mostly surface: fetch the aggregate on first
    // build so entering the route directly shows real data (the provider never
    // fetches on its own). Deferred out of the build phase because
    // refreshStatus() notifies synchronously, which is illegal mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TradeVerificationProvider>();
      if (!mounted) return;
      unawaited(provider.refreshStatus());
    });
  }

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id) =>
      _notes.putIfAbsent(id, TextEditingController.new);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TradeVerificationProvider>();
    final status = provider.status;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review queue', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(child: _body(status, provider)),
    );
  }

  Widget _body(TradeVerificationStatus? status, TradeVerificationProvider provider) {
    if (status == null) {
      return const HivorrLoadingState();
    }
    final pending = status.tradeVerifications
        .where((TradeVerification t) => !t.statusKind.isTerminal)
        .toList(growable: false);
    if (pending.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.task_alt,
          color: context.colorScheme.primary,
        ),
        title: 'Queue is clear',
        subtitle: 'No trade proofs are awaiting review.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        if (_feedback != null && _feedback!.isNotEmpty) ...<Widget>[
          Text(
            _feedback!,
            style: context.textTheme.bodyMedium
                ?.copyWith(color: context.colorScheme.primary),
          ),
          const SizedBox(height: HivorrSpacing.md),
        ],
        for (final TradeVerification entry in pending)
          _ReviewCard(
            key: ValueKey<String>(entry.professionId),
            entry: entry,
            label: _labelFor(entry.professionId),
            notesController: _controllerFor(entry.professionId),
            busy: _busy.contains(entry.professionId),
            decider: widget.onDecide,
            onResult: (String message) => setState(() => _feedback = message),
            onBusyChange: (bool busy) {
              setState(() {
                if (busy) {
                  _busy.add(entry.professionId);
                } else {
                  _busy.remove(entry.professionId);
                }
              });
            },
          ),
      ],
    );
  }

  String _labelFor(String id) => widget.professionLabel?.call(id) ??
      (id.length > 13 ? 'Profession ${id.substring(0, 8)}' : 'Profession $id');
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.entry,
    required this.label,
    required this.notesController,
    required this.busy,
    required this.decider,
    required this.onResult,
    required this.onBusyChange,
  });

  final TradeVerification entry;
  final String label;
  final TextEditingController notesController;
  final bool busy;
  final TradeReviewDecider? decider;
  final void Function(String message) onResult;
  final void Function(bool busy) onBusyChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.md),
      child: HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: context.textTheme.titleMedium),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              'Status: ${entry.status}',
              style: context.textTheme.bodySmall
                  ?.copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: HivorrSpacing.sm),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Decision notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: HivorrButton(
                    label: 'Approve',
                    isLoading: busy,
                    onPressed: decider == null
                        ? null
                        : () => _decide(context, approved: true),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: HivorrButton(
                    label: 'Reject',
                    variant: HivorrButtonVariant.outline,
                    onPressed: decider == null
                        ? null
                        : () => _decide(context, approved: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, {required bool approved}) async {
    final decider = this.decider;
    if (decider == null) return;
    onBusyChange(true);
    try {
      await decider(
        professionId: entry.professionId,
        approved: approved,
        notes: notesController.text.trim(),
      );
      onResult(approved ? 'Approved $label' : 'Rejected $label');
    } catch (e) {
      onResult('Decision failed: ${e.toString()}');
    } finally {
      onBusyChange(false);
    }
  }
}
