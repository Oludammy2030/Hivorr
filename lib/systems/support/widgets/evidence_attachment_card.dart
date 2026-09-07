import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Immutable evidence display card (EP-02-17 §5.7).
///
/// Pure widget — renders the type icon, title, description, and an attachment
/// chip (name/size from `file_metadata`) for attachment-bearing types.
/// [onPreview] hooks the caller's signed-URL preview (private bucket); it is
/// only surfaced when the evidence carries a file.
class EvidenceAttachmentCard extends StatelessWidget {
  const EvidenceAttachmentCard({
    super.key,
    required this.evidence,
    this.onPreview,
  });

  final DisputeEvidence evidence;

  /// Invoked to open the private signed-URL preview in a browser.
  final VoidCallback? onPreview;

  IconData get _typeIcon {
    switch (evidence.evidenceType) {
      case 'document':
        return Icons.description;
      case 'screenshot':
        return Icons.screenshot_monitor;
      case 'photo':
        return Icons.photo_camera;
      case 'description':
      default:
        return Icons.text_snippet;
    }
  }

  String? get _attachmentName {
    final Object? name = evidence.fileMetadata['originalName'];
    if (name is String && name.isNotEmpty) return name;
    return null;
  }

  int? get _attachmentSize {
    final Object? size = evidence.fileMetadata['sizeBytes'];
    if (size is int) return size;
    if (size is double) return size.round();
    if (size is String) return int.tryParse(size);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? attachmentName = _attachmentName;
    final int? attachmentSize = _attachmentSize;
    final bool showAttachment =
        evidence.hasAttachment &&
        !evidence.isDescriptive &&
        attachmentName != null;

    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_typeIcon, size: 20, color: colors.primary),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Text(
                  evidence.title,
                  style: context.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (evidence.description != null &&
              evidence.description!.isNotEmpty) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              evidence.description!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (showAttachment) ...[
            const SizedBox(height: HivorrSpacing.sm),
            _AttachmentChip(
              name: attachmentName,
              sizeLabel: attachmentSize == null
                  ? null
                  : HivorrFormatters.fileSize(attachmentSize),
              onPreview: onPreview,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.name,
    required this.sizeLabel,
    required this.onPreview,
  });

  final String name;
  final String? sizeLabel;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String label = sizeLabel == null ? name : '$name · $sizeLabel';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.attach_file, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: HivorrSpacing.xs),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (onPreview != null) ...[
          const SizedBox(width: HivorrSpacing.sm),
          InkWell(
            onTap: onPreview,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Preview',
                style: context.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}