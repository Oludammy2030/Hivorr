import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/widgets/document_type_picker.dart';
import 'package:provider/provider.dart';

/// A user-selected document (bytes + name + MIME), injected by the app shell
/// via a real file picker (mobile/Web `XFile.readAsBytes()`). Defaults to
/// `null` (no picker wired) which disables the submit action.
typedef PickDocumentCallback = Future<PickedDocument?> Function();

/// Screen for selecting a document type, picking a file, and queuing the
/// identity verification (EP-02-10 §5.6, §10).
///
/// Consumes [VerificationProvider] via [provider]. All colors/type/spacing come
/// from [AppTheme] tokens — never Material color or font-family literals.
class IdentityDocumentUploadScreen extends StatefulWidget {
  const IdentityDocumentUploadScreen({
    super.key,
    this.pickFile,
  });

  /// Injected file picker. When `null`, a stub is used and submission stays
  /// disabled until the app shell wires a real picker.
  final PickDocumentCallback? pickFile;

  @override
  State<IdentityDocumentUploadScreen> createState() =>
      _IdentityDocumentUploadScreenState();
}

class _IdentityDocumentUploadScreenState
    extends State<IdentityDocumentUploadScreen> {
  DocumentType? _selectedType;
  PickedDocument? _picked;
  String? _fieldError;
  int _sent = 0;
  int _total = 0;
  bool _showProgress = false;

  @override
  Widget build(BuildContext context) {
    final VerificationProvider provider = context.watch<VerificationProvider>();
    final ColorScheme colors = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify identity', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Choose a document type, then upload a clear photo or PDF.',
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: HivorrSpacing.lg),
              DocumentTypePicker(
                selected: _selectedType,
                onChanged: (DocumentType type) {
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
                onPressed:
                    (_selectedType != null && _picked != null) ? _submit : null,
              ),
              const SizedBox(height: HivorrSpacing.sm),
              Text(
                'Accepted: JPG, PNG, WebP, PDF up to 10 MB.',
                style: context.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: HivorrSpacing.lg),
              _SubmitFeedback(provider: provider, onViewStatus: _viewStatus),
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
      final String message = e.toString();
      setState(() {
        _fieldError = _friendlyError(message);
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
    final VerificationProvider provider = context.read<VerificationProvider>();
    final PickedDocument doc = _picked!;
    final DocumentType type = _selectedType!;
    setState(() {
      _sent = 0;
      _total = doc.bytes.length;
      _showProgress = true;
    });
    await provider.submitIdentityDocument(
      documentType: type,
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
    unawaited(context.push(RoutePaths.verificationStatus));
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
                  child: Text(picked!.fileName,
                      style: context.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
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
              style: context.textTheme.bodySmall
                  ?.copyWith(color: colors.error),
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

  final VerificationProvider provider;
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
          subtitle: "We'll review your documents within 24 hours.",
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
