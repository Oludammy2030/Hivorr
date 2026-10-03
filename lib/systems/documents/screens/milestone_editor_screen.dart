import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/documents/widgets/milestone_evidence_tile.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:provider/provider.dart';

/// Milestone evidence manager (EP-03-10 §8 D9).
///
/// `GET /contracts/:id/milestones/edit`. Post-accept evidence mode:
/// per-milestone [MilestoneEvidenceTile] (thumbnail via `getPublicUrl`,
/// `LinearProgressIndicator`, retry, replace/delete with confirm).
/// Upload-then-link ordering with orphan cleanup in [ContractService].
/// Pre-offer array editing lives in `contract_offer_screen.dart`. Tokens only
/// (`AGENT.md` Rule 5).
class MilestoneEditorScreen extends StatefulWidget {
  const MilestoneEditorScreen({super.key, required this.contractId});

  /// The contract whose milestones carry evidence.
  final String contractId;

  @override
  State<MilestoneEditorScreen> createState() => _MilestoneEditorScreenState();
}

class _PendingEvidence {
  _PendingEvidence({
    required this.milestoneId,
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String milestoneId;
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  double progress = 0;
  String? error;
}

class _MilestoneEditorScreenState extends State<MilestoneEditorScreen> {
  bool _initialized = false;
  final Map<String, _PendingEvidence> _pending = <String, _PendingEvidence>{};
  final Set<String> _busy = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            context.read<ServiceContractProvider>().select(widget.contractId),
          );
        }
      });
    }
  }

  Future<void> _pickAndUpload(ContractMilestone milestone) async {
    final PlatformFilePicker picker = context.read<PlatformFilePicker>();
    final PickedDocument? picked = await picker.pickListingMedia();
    if (picked == null || !mounted) return;
    final _PendingEvidence pending = _PendingEvidence(
      milestoneId: milestone.id,
      fileName: picked.fileName,
      bytes: picked.bytes,
      mimeType: picked.mimeType,
    );
    setState(() => _pending[milestone.id] = pending);
    await _uploadPending(pending);
  }

  Future<void> _uploadPending(_PendingEvidence pending) async {
    final ContractService service = context.read<ContractService>();
    setState(() {
      pending.error = null;
      pending.progress = 0;
      _busy.add(pending.milestoneId);
    });
    try {
      await service.completeMilestoneWithEvidence(
        contractId: widget.contractId,
        milestoneId: pending.milestoneId,
        bytes: pending.bytes,
        mimeType: pending.mimeType,
        fileName: pending.fileName,
        onProgress: (int sent, int total) {
          if (!mounted || total <= 0) return;
          setState(() => pending.progress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() => _pending.remove(pending.milestoneId));
      await context.read<ServiceContractProvider>().select(widget.contractId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Evidence attached.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.error = e.message);
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() => pending.error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(pending.milestoneId));
      }
    }
  }

  Future<void> _confirmRemoveEvidence(ContractMilestone milestone) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: 'Remove evidence?',
        content: const Text(
          'The attached evidence reference will be cleared. This cannot be undone.',
        ),
        actions: <Widget>[
          HivorrButton(
            label: 'Keep',
            variant: HivorrButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HivorrButton(
            label: 'Remove',
            variant: HivorrButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(
        context,
        message:
            'Evidence removal is handled by resubmitting the milestone.',
        variant: HivorrSnackbarVariant.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Milestone evidence')),
      body: Consumer2<ServiceContractProvider, ContractService>(
        builder:
            (
              BuildContext context,
              ServiceContractProvider provider,
              ContractService service,
              _,
            ) {
              switch (provider.loadState) {
                case ServiceContractLoadState.idle:
                case ServiceContractLoadState.loading:
                  if (provider.selected == null) {
                    return const HivorrLoadingState(
                      message: 'Loading milestones…',
                    );
                  }
                  return _MilestoneList(
                    contract: provider.selected!,
                    service: service,
                    pending: _pending,
                    onPick: _pickAndUpload,
                    onRetry: (ContractMilestone m) {
                      final _PendingEvidence? p = _pending[m.id];
                      if (p != null) unawaited(_uploadPending(p));
                    },
                    onDelete: _confirmRemoveEvidence,
                  );
                case ServiceContractLoadState.loaded:
                  final ServiceContract? contract = provider.selected;
                  if (contract == null || contract.milestones.isEmpty) {
                    return const HivorrEmptyState(
                      title: 'No milestones',
                      subtitle:
                          'Milestones appear here once the offer is created.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: HivorrSpacing.md,
                      ),
                      children: <Widget>[
                        _MilestoneList(
                          contract: contract,
                          service: service,
                          pending: _pending,
                          onPick: _pickAndUpload,
                          onRetry: (ContractMilestone m) {
                            final _PendingEvidence? p = _pending[m.id];
                            if (p != null) unawaited(_uploadPending(p));
                          },
                          onDelete: _confirmRemoveEvidence,
                        ),
                      ],
                    ),
                  );
                case ServiceContractLoadState.error:
                  final ApiException? error = provider.lastError;
                  if (error?.kind == ApiExceptionKind.notFound) {
                    return const HivorrEmptyState(
                      title: 'Contract not found',
                      subtitle:
                          'It may have been removed or you may not have access.',
                    );
                  }
                  return HivorrErrorState(
                    message: 'Could not load milestones',
                    detail: error?.message,
                    onRetry: () => unawaited(
                      provider.select(widget.contractId),
                    ),
                  );
              }
            },
      ),
    );
  }
}

class _MilestoneList extends StatelessWidget {
  const _MilestoneList({
    required this.contract,
    required this.service,
    required this.pending,
    required this.onPick,
    required this.onRetry,
    required this.onDelete,
  });

  final ServiceContract contract;
  final ContractService service;
  final Map<String, _PendingEvidence> pending;
  final ValueChanged<ContractMilestone> onPick;
  final ValueChanged<ContractMilestone> onRetry;
  final ValueChanged<ContractMilestone> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'Attach delivery evidence per milestone. Uploads replace nothing until the milestone is marked complete.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        for (final ContractMilestone m in contract.milestones)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: MilestoneEvidenceTile(
              milestone: m,
              currencyCode: contract.currencyCode,
              evidenceUrl: m.evidencePath == null
                  ? null
                  : service.evidencePublicUrl(m.evidencePath!),
              progress: pending[m.id]?.progress,
              error: pending[m.id]?.error,
              onPick: m.isPending ? () => onPick(m) : null,
              onRetry: pending[m.id]?.error != null
                  ? () => onRetry(m)
                  : null,
              onDelete: m.evidencePath != null && m.isPending
                  ? () => onDelete(m)
                  : null,
            ),
          ),
      ],
    );
  }
}
