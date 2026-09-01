import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

/// A group of selectable document-type chips (EP-02-10 §5.6).
///
/// Renders all [DocumentType] values as wrapping chips. The selected chip is
/// filled with `ColorScheme.primaryContainer` (never a hardcoded color) per the
/// visual identity, with `onPrimaryContainer` text. Each chip is a 48dp touch
/// target and carries a one-line helper caption when selected.
class DocumentTypePicker extends StatelessWidget {
  const DocumentTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Currently selected document type (`null` = none selected).
  final DocumentType? selected;

  /// Selection callback.
  final ValueChanged<DocumentType> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final TextTheme textTheme = context.textTheme;

    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final DocumentType type in DocumentType.values)
          _TypeChip(
            type: type,
            selected: selected == type,
            textTheme: textTheme,
            colors: colors,
            radius: ext.radiusLg,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.textTheme,
    required this.colors,
    required this.radius,
    required this.onTap,
  });

  final DocumentType type;
  final bool selected;
  final TextTheme textTheme;
  final ColorScheme colors;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final Color foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final Color border = selected ? colors.primary : colors.outline;

    final Widget inner = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _iconFor(type),
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: HivorrSpacing.xs),
          Flexible(
            child: Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: type.label,
      selected: selected,
      toggled: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.primary.withValues(alpha: 0.12),
        child: inner,
      ),
    );
  }

  static IconData _iconFor(DocumentType type) => switch (type) {
        DocumentType.nationalId => Icons.badge_outlined,
        DocumentType.passport => Icons.picture_as_pdf_outlined,
        DocumentType.driversLicense => Icons.drive_eta_outlined,
        DocumentType.votersCard => Icons.how_to_vote_outlined,
        DocumentType.ninSlip => Icons.assignment_ind_outlined,
      };
}
