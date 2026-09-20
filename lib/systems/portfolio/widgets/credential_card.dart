import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';

/// Read-only card for a single approved credential (EP-02-19 §5.6, DoD FV-16).
///
/// Renders the title, a kind chip, and a read-only `Approved` state badge.
/// The RPC already filtered to `verification_status = 'approved'`, so this
/// widget only mirrors server state — it never classifies by itself.
class CredentialCard extends StatelessWidget {
  const CredentialCard({super.key, required this.credential});

  /// The approved credential (whitelisted: `kind`, `title`,
  /// `verificationStatus` — never `document_path`).
  final PublicCredential credential;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(
                context.appExtension.radiusSm,
              ),
            ),
            child: Icon(
              _iconForKind(credential.kind),
              size: 20,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  credential.title,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Wrap(
                  spacing: HivorrSpacing.xs,
                  runSpacing: HivorrSpacing.xs,
                  children: <Widget>[
                    HivorrChip(
                      label: _displayKind(credential.kind),
                      variant: HivorrChipVariant.surface,
                    ),
                    HivorrBadge(
                      label: 'Approved',
                      variant: HivorrBadgeVariant.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kind vocabulary from `entity_credentials.kind` (server-authoritative);
  /// unknown kinds fall back to a neutral identifier icon + label.
  static IconData _iconForKind(String kind) => switch (kind) {
    'identity_document' => Icons.verified_user_outlined,
    'trade_proof' => Icons.construction_outlined,
    'certification' => Icons.workspace_premium_outlined,
    _ => Icons.military_tech_outlined,
  };

  static String _displayKind(String kind) => switch (kind) {
    'identity_document' => 'Identity',
    'trade_proof' => 'Trade proof',
    'certification' => 'Certification',
    _ => kind,
  };
}
