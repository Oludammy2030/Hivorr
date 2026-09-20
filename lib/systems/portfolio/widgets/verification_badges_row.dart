import 'package:flutter/material.dart';

import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Trust-signal row for the public professional profile (EP-02-19 §5.6,
/// DoD FV-16).
///
/// Shows the identity-verified badge (KYC tier + status), the trade-approved
/// badge, and the approved-credential count. All state is passed in from the
/// service-derived view-model — this widget never classifies or invents trust
/// signals itself.
class VerificationBadgesRow extends StatelessWidget {
  const VerificationBadgesRow({
    super.key,
    required this.identityVerified,
    required this.tradeVerified,
    required this.credentialCount,
    this.kycTierCode,
    this.kycStatus,
  });

  /// Identity trust signal (approved identity credential or active KYC ≥ tier_1).
  final bool identityVerified;

  /// Trade trust signal (profile passed the approved-gate).
  final bool tradeVerified;

  /// Number of approved credentials on the profile.
  final int credentialCount;

  /// Optional KYC tier code shown as the identity badge subtitle.
  final String? kycTierCode;

  /// Optional KYC level status (e.g. `active`).
  final String? kycStatus;

  @override
  Widget build(BuildContext context) {
    final List<String> identityLabels = <String>[
      if (identityVerified) 'Identity Verified',
      if (kycTierCode != null && kycTierCode!.isNotEmpty)
        kycTierCode!.toUpperCase(),
      if (kycStatus != null && kycStatus!.isNotEmpty) kycStatus!,
    ];

    return HivorrCard(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Wrap(
        spacing: HivorrSpacing.sm,
        runSpacing: HivorrSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (identityLabels.isNotEmpty)
            HivorrBadge(
              label: identityLabels.join(' · '),
              variant: HivorrBadgeVariant.success,
            ),
          if (tradeVerified)
            HivorrBadge(
              label: 'Trade Verified',
              variant: HivorrBadgeVariant.success,
            ),
          HivorrBadge(
            label:
                '$credentialCount Approved '
                '${credentialCount == 1 ? 'Credential' : 'Credentials'}',
            variant: HivorrBadgeVariant.info,
          ),
        ],
      ),
    );
  }
}
