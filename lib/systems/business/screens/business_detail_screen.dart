import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/providers/business_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/business/widgets/business_status_badge.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:provider/provider.dart';

/// A user-selected document (bytes + name + MIME), injected by the app shell
/// via a real file picker. Mirrors the identity-upload seam.
typedef PickBusinessDocumentCallback = Future<PickedDocument?> Function();

/// Business detail + CAC verification (identity audit Phase 2a).
///
/// `GET /businesses/:id`. Header (names, status, membership role) plus a
/// verification section: title + file + submit into the
/// `business_verification` lane. Approval flips the business and authorizes
/// the submitter server-side; this screen only reflects state.
class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.businessId, this.pickFile});

  /// The `businesses.id` to display.
  final String businessId;

  /// Injected file picker. When `null`, the app-wide [PlatformFilePicker]
  /// resolves it (silent stub when unregistered â€” submission stays disabled).
  final PickBusinessDocumentCallback? pickFile;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  final TextEditingController _title = TextEditingController(
    text: 'CAC certificate',
  );
  PickedDocument? _picked;
  String? _fieldError;
  int _sent = 0;
  int _total = 0;
  bool _showProgress = false;
  bool _initialized = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  String? get _viewerId {
    try {
      return Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentSession?.entityId;
    } on Object {
      return null;
    }
  }

  Future<void> _load() async {
    final String? entityId = _viewerId;
    if (entityId == null || entityId.isEmpty) return;
    await context.read<BusinessProvider>().loadMine(entityId: entityId);
  }

  Business? _business(BusinessProvider provider) {
    for (final Business business in provider.businesses) {
      if (business.id == widget.businessId) return business;
    }
    return null;
  }

  Future<void> _pick() async {
    final PickBusinessDocumentCallback? callback = _resolvePick();
    if (callback == null) return;
    final PickedDocument? doc = await callback();
    if (doc == null || !mounted) return;
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
    } on Object {
      setState(() {
        _fieldError =
            'This file is not supported. Please use JPG, PNG, WebP, or PDF under 10 MB.';
      });
    }
  }

  PickBusinessDocumentCallback? _resolvePick() {
    if (widget.pickFile != null) {
      return widget.pickFile;
    }
    try {
      return context.read<PlatformFilePicker>().pickDocument;
    } on Object {
      return null;
    }
  }

  Future<void> _submit(Business business) async {
    final String? entityId = _viewerId;
    final PickedDocument? doc = _picked;
    if (entityId == null || entityId.isEmpty || doc == null) return;
    setState(() {
      _sent = 0;
      _total = doc.bytes.length;
      _showProgress = true;
      _fieldError = null;
    });
    try {
      await context.read<BusinessProvider>().submitDocument(
        entityId: entityId,
        businessId: business.id,
        title: _title.text.trim().isEmpty ? 'CAC certificate' : _title.text.trim(),
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
      setState(() {
        _showProgress = false;
        _picked = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Documents submitted for review.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _showProgress = false;
        _fieldError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Business')),
      body: HivorrContentPane(
        child: Consumer<BusinessProvider>(
          builder: (BuildContext context, BusinessProvider provider, _) {
            switch (provider.loadState) {
              case BusinessLoadState.loading:
                if (provider.businesses.isEmpty) {
                  return const HivorrLoadingState(
                    message: 'Loading businessâ€¦',
                  );
                }
                return _DetailBody(
                  business: _business(provider),
                  provider: provider,
                  onRefresh: _load,
                  titleController: _title,
                  picked: _picked,
                  fieldError: _fieldError,
                  showProgress: _showProgress,
                  progress: _total == 0 ? 0 : _sent / _total,
                  onPick: () => unawaited(_pick()),
                  onSubmit: _submit,
                );
              case BusinessLoadState.idle:
                return HivorrErrorState(
                  message: 'Business not loaded',
                  onRetry: () => unawaited(_load()),
                );
              case BusinessLoadState.loaded:
                return _DetailBody(
                  business: _business(provider),
                  provider: provider,
                  onRefresh: _load,
                  titleController: _title,
                  picked: _picked,
                  fieldError: _fieldError,
                  showProgress: _showProgress,
                  progress: _total == 0 ? 0 : _sent / _total,
                  onPick: () => unawaited(_pick()),
                  onSubmit: _submit,
                );
              case BusinessLoadState.error:
                final ApiException? error = provider.lastError;
                return HivorrErrorState(
                  message: 'Could not load business',
                  detail: error?.message,
                  onRetry: () => unawaited(_load()),
                );
            }
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.business,
    required this.provider,
    required this.onRefresh,
    required this.titleController,
    required this.picked,
    required this.fieldError,
    required this.showProgress,
    required this.progress,
    required this.onPick,
    required this.onSubmit,
  });

  final Business? business;
  final BusinessProvider provider;
  final Future<void> Function() onRefresh;
  final TextEditingController titleController;
  final PickedDocument? picked;
  final String? fieldError;
  final bool showProgress;
  final double progress;
  final VoidCallback onPick;
  final Future<void> Function(Business business) onSubmit;

  @override
  Widget build(BuildContext context) {
    final Business? current = business;
    if (current == null) {
      return const HivorrEmptyState(
        title: 'Business not found',
        subtitle: 'It may have been removed or you may not have access.',
      );
    }
    final BusinessMembership? membership = current.membership;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
        children: <Widget>[
          HivorrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        current.tradingName.isEmpty
                            ? 'Unnamed business'
                            : current.tradingName,
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    BusinessStatusBadge(status: current.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  current.registeredLegalName,
                  style: context.textTheme.titleMedium,
                ),
                if (current.cacNumber != null &&
                    current.cacNumber!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'CAC ${current.cacNumber}',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (membership != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    membership.isRepresentative
                        ? 'Representative${membership.isAuthorized ? ' Â· authorized' : ' Â· awaiting authorization'}'
                        : 'Member',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Verification',
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  current.isVerified
                      ? 'Verified â€” hire on behalf of this business.'
                      : current.isRejected
                      ? 'Not verified â€” review the decision and resubmit.'
                      : 'Upload registration documents to verify this business.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrTextField(
                  controller: titleController,
                  label: 'Document title',
                  hint: 'e.g. CAC certificate',
                ),
                const SizedBox(height: HivorrSpacing.md),
                _FileCard(
                  picked: picked,
                  showProgress: showProgress,
                  progress: progress,
                  onPick: onPick,
                  error: fieldError,
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrButton(
                  label: 'Upload & submit',
                  isExpanded: true,
                  isLoading: provider.isSubmitting,
                  onPressed: (picked != null && !provider.isSubmitting)
                      ? () => unawaited(onSubmit(current))
                      : null,
                ),
                const SizedBox(height: HivorrSpacing.sm),
                Text(
                  'Accepted: JPG, PNG, WebP, PDF up to 10 MB.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
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
