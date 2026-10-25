import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_document_upload_tile.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/widgets/document_type_picker.dart';
import 'package:provider/provider.dart';

/// File-pick contract for the identity step (matches the verification screen).
typedef PickDocumentCallback = Future<PickedDocument?> Function();

/// Step 4 — identity verification (EP-02-18 FV-22, FV-24, FV-32).
///
/// `DocumentType` picker (5 options) → validated file pick
/// ([StorageValidators.validateForBucket] against `credential-documents`) →
/// progress via `onProgress` → `submitIdentityDocument`. `PLT005`
/// active-submission conflicts surface as inline guidance with a
/// `Skip`/view-status escape. After submit, "reviewed within 24 hours" copy.
class IdentityVerificationStepScreen extends StatefulWidget {
  const IdentityVerificationStepScreen({
    super.key,
    required this.active,
    required this.controller,
    this.pickFile,
    this.onFinished,
  });

  final bool active;
  final OnboardingStepController controller;
  final PickDocumentCallback? pickFile;

  /// Invoked after the step is submitted or skipped, instead of navigating to
  /// the next wizard step. Used by checklist deep links to return to the
  /// requirements screen.
  final VoidCallback? onFinished;

  @override
  State<IdentityVerificationStepScreen> createState() =>
      _IdentityVerificationStepScreenState();
}

class _IdentityVerificationStepScreenState
    extends State<IdentityVerificationStepScreen> {
  DocumentType? _type;
  PickedDocument? _picked;
  String? _fieldError;
  int _sent = 0;
  int _total = 0;
  bool _submitted = false;
  bool _restoredLocalState = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredLocalState) {
      return;
    }
    _restoredLocalState = true;
    // A persisted submission stays "under review" across re-entry/refresh;
    // approval remains server-authoritative.
    _submitted =
        context.read<OnboardingProvider>().progress?.hasIdentitySubmission ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final ColorScheme colors = context.colorScheme;
    final VerificationStatus? verificationStatus = _verificationStatus(context);
    final VerificationSubmissionSummary? latest =
        verificationStatus?.latestIdentitySubmission;
    final bool identityVerified = verificationStatus?.identityVerified ?? false;
    final bool needsAction = latest?.status.needsAction ?? false;
    final bool underReview = latest != null && !latest.status.isTerminal;
    // Backend state wins when available; the local mirror is only a same-device
    // fallback for aggregates that do not project per-lane review state.
    final bool submitted =
        !identityVerified && !needsAction && (underReview || _submitted);

    if (identityVerified || submitted) {
      widget.controller.hidePrimary();
    } else {
      widget.controller.configure(
        label: 'Upload & submit',
        canPrimary: _type != null && _picked != null,
        loading: provider.isBusy,
        onPrimary: () => _submit(context),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Verify your identity with a government-issued document.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          if (identityVerified)
            const _IdentityStatusNotice(
              title: 'Identity verified',
              body: 'Your identity has been approved.',
            )
          else if (submitted)
            const _IdentityStatusNotice(
              title: 'Identity document under review',
              body:
                  'Your document has been submitted and is waiting for an '
                  'admin decision. This can take up to 24 hours.',
            )
          else ...<Widget>[
            if (needsAction) ...<Widget>[
              const _IdentityStatusNotice(
                title: 'Identity document needs attention',
                body:
                    'Your previous document was not approved. Upload a new '
                    'document to try again.',
                isError: true,
              ),
              const SizedBox(height: HivorrSpacing.lg),
            ],
            DocumentTypePicker(
              selected: _type,
              onChanged: (DocumentType type) {
                setState(() {
                  _type = type;
                  _fieldError = null;
                });
              },
            ),
            const SizedBox(height: HivorrSpacing.lg),
            OnboardingDocumentUploadTile(
              label: 'Identity document',
              fileName: _picked?.fileName ?? '',
              byteLength: _picked?.bytes.length ?? 0,
              mimeType: _picked?.mimeType,
              submitState: provider.submitState,
              error: _fieldError,
              progress: _total == 0 ? null : _sent / _total,
              onPick: _pick,
            ),
          ],
          if (provider.submitState == SubmitState.error) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            _ConflictPanel(
              message: provider.lastError?.message ?? 'Submission failed.',
              onSkip: _advance,
              onViewStatus: _viewStatus,
            ),
          ],
        ],
      ),
    );
  }

  /// Reads the optional verification aggregate without making it a hard
  /// dependency of the onboarding shell (older widget seams omit it).
  VerificationStatus? _verificationStatus(BuildContext context) {
    try {
      return Provider.of<VerificationProvider>(context).status;
    } on ProviderNotFoundException {
      return null;
    }
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
  PickDocumentCallback? _resolvePick() {
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

  Future<void> _submit(BuildContext context) async {
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    final PickedDocument doc = _picked!;
    final DocumentType type = _type!;
    setState(() {
      _sent = 0;
      _total = doc.bytes.length;
    });
    await provider.submitIdentityDocument(
      documentType: type,
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
      if (!mounted) {
        return;
      }
      if (widget.onFinished != null) {
        widget.onFinished!();
        return;
      }
      if (context.mounted) {
        context.go(RoutePaths.onboardingTradeProof);
      }
    }
  }

  Future<void> _advance() async {
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    await provider.advance();
    if (!mounted) {
      return;
    }
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    context.go(RoutePaths.onboardingTradeProof);
  }

  void _viewStatus() {
    unawaited(context.push(RoutePaths.verificationStatus));
  }
}

class _IdentityStatusNotice extends StatelessWidget {
  const _IdentityStatusNotice({
    required this.title,
    required this.body,
    this.isError = false,
  });

  final String title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.textTheme.titleMedium),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          body,
          style: context.textTheme.bodySmall?.copyWith(
            color: isError ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConflictPanel extends StatelessWidget {
  const _ConflictPanel({
    required this.message,
    required this.onSkip,
    required this.onViewStatus,
  });

  final String message;
  final VoidCallback onSkip;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    if (message.contains('pending verification')) {
      // "You already have a pending verification for this document" — offer
      // the Skip / view-status escape (FV-24).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'You already have a pending verification for this document.',
            style: context.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              HivorrButton(
                label: 'Skip for now',
                variant: HivorrButtonVariant.outline,
                size: HivorrButtonSize.small,
                onPressed: onSkip,
              ),
              const SizedBox(width: HivorrSpacing.sm),
              TextButton(
                onPressed: onViewStatus,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('View status'),
              ),
            ],
          ),
        ],
      );
    }
    return Text(
      message,
      style: context.textTheme.bodySmall?.copyWith(color: colors.error),
    );
  }
}
