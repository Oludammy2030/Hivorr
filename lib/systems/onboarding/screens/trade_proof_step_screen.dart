import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_document_upload_tile.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:provider/provider.dart';

/// File-pick contract for the trade-proof step.
typedef PickTradeProofCallback = Future<PickedDocument?> Function();

/// Step 5 — trade proof (EP-02-18 FV-23, FV-26, FV-33).
///
/// Shows the bound-profession chip, a `TradeProofType` picker, the same
/// validated upload pipeline, and the Rule 2 gate-status panel sourced from
/// [OnboardingProvider.refreshGateStatus]. Proofs are bound to the selected
/// profession id.
class TradeProofStepScreen extends StatefulWidget {
  const TradeProofStepScreen({
    super.key,
    required this.active,
    required this.controller,
    this.pickFile,
  });

  final bool active;
  final OnboardingStepController controller;
  final PickTradeProofCallback? pickFile;

  @override
  State<TradeProofStepScreen> createState() => _TradeProofStepScreenState();
}

class _TradeProofStepScreenState extends State<TradeProofStepScreen> {
  TradeProofType? _type;
  PickedDocument? _picked;
  String? _fieldError;
  int _sent = 0;
  int _total = 0;
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant TradeProofStepScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshGate());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGate());
    }
  }

  Future<void> _refreshGate() async {
    if (!mounted) {
      return;
    }
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    await provider.refreshGateStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final TaxonomyProvider taxonomy = context.watch<TaxonomyProvider>();
    final ColorScheme colors = context.colorScheme;
    final Profession? profession = taxonomy.selectedProfession;

    widget.controller.configure(
      label: 'Upload & submit',
      canPrimary: _type != null && _picked != null && !_submitted,
      loading: provider.isBusy,
      onPrimary: () => _submit(context, profession),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (profession != null) ...<Widget>[
            Row(
              children: <Widget>[
                Text('Profession', style: context.textTheme.titleSmall),
                const SizedBox(width: HivorrSpacing.sm),
                HivorrChip(label: profession.name, variant: HivorrChipVariant.surface),
              ],
            ),
            const SizedBox(height: HivorrSpacing.lg),
          ],
          _GatePanel(isOpen: provider.isTradeGateOpen),
          const SizedBox(height: HivorrSpacing.lg),
          Text(
            'Proof of your trade unlocks bidding. Choose a proof type, then '
            'upload a clear photo or PDF.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            children: <Widget>[
              for (final TradeProofType type in TradeProofType.values)
                HivorrChip(
                  label: type.label,
                  isSelected: _type == type,
                  onSelected: (bool selected) {
                    setState(() {
                      _type = selected ? type : null;
                      _fieldError = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.lg),
          OnboardingDocumentUploadTile(
            label: 'Trade proof document',
            fileName: _picked?.fileName ?? '',
            byteLength: _picked?.bytes.length ?? 0,
            mimeType: _picked?.mimeType,
            submitState: provider.submitState,
            error: _fieldError,
            progress: _total == 0 ? null : _sent / _total,
            onPick: _pick,
          ),
          if (_submitted) ...<Widget>[
            const SizedBox(height: HivorrSpacing.lg),
            Text(
              'Your trade proof has been queued for review. Bidding unlocks '
              'as soon as it is approved.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final callback = _resolvePick();
    if (callback == null) {
      return;
    }
    final PickedDocument? doc = await callback();
    if (doc == null || !mounted) {
      return;
    }
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
      final String lower = e.toString().toLowerCase();
      setState(() {
        _fieldError = lower.contains('large')
            ? 'This file is too large — please use a file under 10 MB.'
            : 'This file type is not supported. Please use JPG, PNG, WebP, or '
                  'PDF.';
      });
    }
  }

  /// Resolves the document picker callback: the injected test seam first, else
  /// the app-wide [PlatformFilePicker] (silent stub when no provider is
  /// registered — test harnesses that omit the picker stay disabled).
  PickTradeProofCallback? _resolvePick() {
    if (widget.pickFile != null) {
      return widget.pickFile;
    }
    try {
      final PlatformFilePicker platform = context.read<PlatformFilePicker>();
      return platform.pickDocument;
    } on Object {
      return null;
    }
  }

  Future<void> _submit(BuildContext context, Profession? profession) async {
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    final PickedDocument doc = _picked!;
    final TradeProofType type = _type!;
    final String professionId = profession?.id ?? '';
    if (professionId.isEmpty) {
      return;
    }
    setState(() {
      _sent = 0;
      _total = doc.bytes.length;
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
              if (!mounted) {
                return;
              }
              setState(() {
                _sent = sent;
                _total = total;
              });
            },
    );
    if (!mounted) {
      return;
    }
    if (provider.submitState == SubmitState.success) {
      setState(() => _submitted = true);
      await provider.advance();
      if (context.mounted) {
        context.goNamed(RouteNames.onboardingComplete);
      }
    }
  }
}

class _GatePanel extends StatelessWidget {
  const _GatePanel({required this.isOpen});

  final bool? isOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool? open = isOpen;

    final IconData icon;
    final String title;
    final String body;
    final Color accent;
    if (open == null) {
      icon = Icons.lock_clock_outlined;
      title = 'Checking your trade status…';
      body = 'You can start work immediately — bidding unlocks once your '
          'trade proof is approved.';
      accent = colors.onSurfaceVariant;
    } else if (open) {
      icon = Icons.lock_open_outlined;
      title = 'Bidding unlocked';
      body = 'Your trade proof is approved — you can place bids right away.';
      accent = ext.success;
    } else {
      icon = Icons.lock_outline;
      title = 'Bidding will unlock after approval';
      body = 'You can start work immediately — bidding unlocks once your '
          'trade proof is approved.';
      accent = colors.onSurfaceVariant;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.textTheme.titleSmall),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  body,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}