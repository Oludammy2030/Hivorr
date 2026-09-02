import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/widgets/trade_proof_type_picker.dart';
import 'package:provider/provider.dart';

/// A user-selected proof file (bytes + name + MIME), injected by the app shell.
typedef TradePickDocumentCallback = Future<PickedDocument?> Function();

/// Resolves a readable profession name for display, or `null` to fall back to
/// the id.
typedef TradeProfessionLabelBuilder = String Function(String professionId);

/// Screen for selecting a bound profession + proof type, picking a file, and
/// queuing the trade verification (EP-02-11 §5.6, §10).
///
/// Consumes [TradeVerificationProvider]. All colors/type/spacing come from
/// [AppTheme] tokens — never Material color or font-family literals.
class TradeProofUploadScreen extends StatefulWidget {
  const TradeProofUploadScreen({
    super.key,
    this.pickFile,
    this.professionLabel,
  });

  /// Injected file picker. When `null`, submission stays disabled.
  final TradePickDocumentCallback? pickFile;

  /// Optional profession name resolver for display.
  final TradeProfessionLabelBuilder? professionLabel;

  @override
  State<TradeProofUploadScreen> createState() => _TradeProofUploadScreenState();
}

class _TradeProofUploadScreenState extends State<TradeProofUploadScreen> {
  String? _selectedProfessionId;
  TradeProofType? _selectedType;
  PickedDocument? _picked;
  String? _fieldError;
  int _sent = 0;
  int _total = 0;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    // Default-select the first bound profession, if any.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TradeVerificationProvider>();
      final professions = provider.status?.tradeVerifications ?? const [];
      if (!mounted) return;
      if (professions.isNotEmpty && _selectedProfessionId == null) {
        setState(() => _selectedProfessionId = professions.first.professionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TradeVerificationProvider provider =
        context.watch<TradeVerificationProvider>();
    final ColorScheme colors = context.colorScheme;
    final professions = provider.status?.tradeVerifications ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify your trade', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (professions.isEmpty)
                _NoProfessions(onAdd: _viewStatus)
              else ...<Widget>[
                _ProfessionSelector(
                  professions: professions,
                  selectedProfessionId: _selectedProfessionId,
                  labelFor: widget.professionLabel ??
                      (String id) => id
                          .replaceRange(5, id.length - 4, '…'),
                  onChanged: (String id) {
                    setState(() {
                      _selectedProfessionId = id;
                      _fieldError = null;
                    });
                  },
                ),
                const SizedBox(height: HivorrSpacing.lg),
                Text('What kind of proof are you uploading?',
                    style: context.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: HivorrSpacing.sm),
                TradeProofTypePicker(
                  selected: _selectedType,
                  onChanged: (TradeProofType type) {
                    setState(() {
                      _selectedType = type;
                      _fieldError = null;
                    });
                  },
                ),
                if (_selectedType != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    _selectedType!.helper,
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                _FileCard(
                  picked: _picked,
                  showProgress: _showProgress,
                  progress: _total == 0 ? 0 : _sent / _total,
                  onPick: _pick,
                  error: _fieldError,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                HivorrButton(
                  label: 'Upload & submit',
                  isExpanded: true,
                  isLoading: provider.isSubmitting,
                  onPressed: (_selectedProfessionId != null &&
                          _selectedType != null &&
                          _picked != null)
                      ? _submit
                      : null,
                ),
                const SizedBox(height: HivorrSpacing.sm),
                Text(
                  'Accepted: JPG, PNG, WebP, PDF up to 10 MB.',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _SubmitFeedback(
                  provider: provider,
                  onViewStatus: _viewStatus,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick() async {
    final callback = widget.pickFile;
    if (callback == null) return;
    final PickedDocument? doc = await callback();
    if (doc == null) return;
    _validateAndCache(doc);
  }

  void _validateAndCache(PickedDocument doc) {
    try {
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.credentialDocuments,
        mimeType: doc.mimeType,
        byteLength: doc.bytes.length,
      );
      setState(() {
        _picked = doc;
        _fieldError = null;
      });
    } on Object catch (e) {
      setState(() {
        _fieldError = _friendlyError(e.toString());
      });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('large') || lower.contains('too large')) {
      return 'This file is too large — please use a file under 10 MB.';
    }
    return 'This file type is not supported. Please use JPG, PNG, WebP, or PDF.';
  }

  Future<void> _submit() async {
    final TradeVerificationProvider provider =
        context.read<TradeVerificationProvider>();
    final PickedDocument doc = _picked!;
    final TradeProofType type = _selectedType!;
    final String professionId = _selectedProfessionId!;
    setState(() {
      _sent = 0;
      _total = doc.bytes.length;
      _showProgress = true;
    });
    await provider.submitTradeProof(
      type: type,
      professionId: professionId,
      bytes: doc.bytes,
      mimeType: doc.mimeType,
      fileName: doc.fileName,
      onProgress: doc.bytes.isEmpty
          ? null
          : (int sent, int total) {
              if (!mounted) return;
              setState(() {
                _sent = sent;
                _total = total;
              });
            },
    );
    if (!mounted) return;
    if (provider.submitState == SubmitState.success) {
      setState(() => _showProgress = false);
    }
  }

  void _viewStatus() {
    unawaited(context.push(RoutePaths.tradeVerificationStatus));
  }
}

class _NoProfessions extends StatelessWidget {
  const _NoProfessions({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return HivorrEmptyState(
      icon: Icon(
        Icons.work_outline,
        color: context.colorScheme.primary,
      ),
      title: 'No bound professions yet',
      subtitle:
          'Add a profession to your profile before submitting trade proof.',
      actionButton: HivorrButton(
        label: 'View status',
        variant: HivorrButtonVariant.outline,
        onPressed: onAdd,
      ),
    );
  }
}

class _ProfessionSelector extends StatelessWidget {
  const _ProfessionSelector({
    required this.professions,
    required this.selectedProfessionId,
    required this.labelFor,
    required this.onChanged,
  });

  final List<TradeVerification> professions;
  final String? selectedProfessionId;
  final TradeProfessionLabelBuilder labelFor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Choose a profession',
          style: context.textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            for (final TradeVerification entry in professions)
              _ProfessionChip(
                id: entry.professionId,
                label: labelFor(entry.professionId),
                selected: entry.professionId == selectedProfessionId,
                colors: colors,
                onTap: () => onChanged(entry.professionId),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfessionChip extends StatelessWidget {
  const _ProfessionChip({
    required this.id,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final Color background =
        selected ? colors.primaryContainer : colors.surfaceContainerHighest;
    final Color foreground =
        selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final Color border = selected ? colors.primary : colors.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ext.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(ext.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 18, color: foreground),
            const SizedBox(width: HivorrSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.picked,
    required this.showProgress,
    required this.progress,
    required this.onPick,
    this.error,
  });

  final PickedDocument? picked;
  final bool showProgress;
  final double progress;
  final VoidCallback onPick;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return HivorrCard(
      elevation: 0,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (picked == null)
            Center(
              child: HivorrButton(
                label: 'Choose file',
                variant: HivorrButtonVariant.outline,
                onPressed: onPick,
                icon: const Icon(Icons.upload_file_outlined),
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Icon(
                  picked!.mimeType == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: Text(
                    picked!.fileName,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onPick,
                  tooltip: 'Choose a different file',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
          if (showProgress) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ],
          if (error != null && error!.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              error!,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmitFeedback extends StatelessWidget {
  const _SubmitFeedback({
    required this.provider,
    required this.onViewStatus,
  });

  final TradeVerificationProvider provider;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    switch (provider.submitState) {
      case SubmitState.idle:
      case SubmitState.submitting:
        return const SizedBox.shrink();
      case SubmitState.success:
        return HivorrEmptyState(
          icon: Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: 'Submitted for review',
          subtitle: "We'll review your trade proof within 24 hours.",
          actionButton: HivorrButton(
            label: 'View status',
            onPressed: onViewStatus,
          ),
        );
      case SubmitState.error:
        return HivorrEmptyState(
          icon: const Icon(Icons.error_outline),
          title: 'Submission failed',
          subtitle: provider.submitError?.message ?? 'Please try again.',
          actionButton: HivorrButton(
            label: 'View status',
            variant: HivorrButtonVariant.outline,
            onPressed: onViewStatus,
          ),
        );
    }
  }
}
