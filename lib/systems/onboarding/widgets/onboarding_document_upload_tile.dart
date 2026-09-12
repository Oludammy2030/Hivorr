import 'package:flutter/material.dart';

import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Reusable identity/trade document upload tile (EP-02-18 FV-39).
///
/// Shows the type icon, file name, size, upload progress, and an inline error
/// with retry (re-pick) — a failed validation/upload retries without losing
/// typed data. MIME/size pre-validation is the caller's duty via
/// [StorageValidators.validateForBucket] before the file is offered here.
class OnboardingDocumentUploadTile extends StatelessWidget {
  const OnboardingDocumentUploadTile({
    super.key,
    required this.label,
    required this.fileName,
    required this.byteLength,
    required this.onPick,
    this.error,
    this.submitState = SubmitState.idle,
    this.progress,
    this.mimeType,
  });

  /// Short label, e.g. "Driver's license" or "Certificate of qualification".
  final String label;

  /// Selected file name (empty until a file is picked).
  final String fileName;

  /// Selected file size in bytes.
  final int byteLength;

  /// Opens the platform file picker.
  final VoidCallback onPick;

  /// Inline validation/upload error (from a rejected pick or failed upload).
  final String? error;

  /// Current submission state (drives progress/retry chrome).
  final SubmitState submitState;

  /// Upload progress `0..1`, when submitting.
  final double? progress;

  /// Declared MIME type (used to pick the leading icon).
  final String? mimeType;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool picked = fileName.isNotEmpty && byteLength > 0;
    final bool uploading = submitState == SubmitState.submitting;

    return HivorrCard(
      elevation: 0,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          if (!picked) ...<Widget>[
            Center(
              child: HivorrButton(
                label: 'Choose file',
                variant: HivorrButtonVariant.outline,
                size: HivorrButtonSize.small,
                onPressed: onPick,
                icon: const Icon(Icons.upload_file_outlined),
              ),
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: Text(
                    fileName,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatSize(byteLength),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: HivorrSpacing.xs),
                IconButton(
                  onPressed: submitting ? null : onPick,
                  tooltip: 'Choose a different file',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
          if (uploading) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Row(
              children: <Widget>[
                Icon(Icons.error_outline, size: 18, color: colors.error),
                const SizedBox(width: HivorrSpacing.xs),
                Expanded(
                  child: Text(
                    error!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onPick,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _isPdf => mimeType == 'application/pdf';

  bool get submitting => submitState == SubmitState.submitting;

  static String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}