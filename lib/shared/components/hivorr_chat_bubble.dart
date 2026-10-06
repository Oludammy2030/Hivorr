import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';

/// Single chat message bubble (VISUAL-IDENTITY.md §§15b, 21j).
///
/// Domain-free: callers pass decrypted `text` + `timestamp` (messaging
/// providers own decryption); this widget owns only layout. Mine messages
/// fill with `primary`; theirs fill with `surface` + hairline border.
/// Undecryptable (`text == null`) renders the honest placeholder in italics —
/// never guessed plaintext.
///
/// Set [elevated] to add the soft Level-1 shadow on incoming bubbles (used by
/// the two-pane messages view); the full-screen thread keeps bubbles flat.
class HivorrChatBubble extends StatelessWidget {
  const HivorrChatBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.mine,
    this.elevated = true,
  });

  /// Decrypted body, or `null` when authentication failed.
  final String? text;

  final DateTime timestamp;

  final bool mine;

  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Alignment alignment = mine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final Color fill = mine ? colors.primary : colors.surface;
    final Color foreground = mine ? colors.onPrimary : colors.onSurface;
    final double maxBubble = MobileCompact.bubbleMaxWidth(
      context.screenWidth,
    );
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubble),
        margin: const EdgeInsets.symmetric(vertical: HivorrSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: colors.outlineVariant),
          boxShadow: mine || !elevated
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              text ?? 'This message couldn’t be decrypted.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontStyle: text == null ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              HivorrFormatters.time(timestamp),
              style: context.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
