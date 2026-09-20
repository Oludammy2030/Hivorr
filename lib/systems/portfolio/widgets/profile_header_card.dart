import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';

/// Identity summary card for the public professional profile (EP-02-19 §5.6,
/// DoD FV-16/UA-02).
///
/// Renders the [HivorrAvatar] from the public `avatar_path`, the display name
/// (never `legal_name`), bio, country chip (when present, as ISO-3166-1) and
/// one chip per approved profession/industry badge. All theming via
/// [AppTheme] tokens (AGENT.md Rule 5).
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.avatarUrl,
    this.onProfessionTap,
  });

  /// The public profile payload (whitelisted fields only).
  final PublicProfile profile;

  /// Resolved public avatar URL, or `null` to fall back to initials.
  final String? avatarUrl;

  /// Optional per-profession navigation (e.g. open the SEO route). When `null`
  /// the profession badges render read-only.
  final ValueChanged<PublicProfession>? onProfessionTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final List<PublicProfession> badges = profile.professions;
    final String? country = _displayCountry(profile.countryCode);

    return HivorrCard(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HivorrAvatar(
                image: avatarUrl == null ? null : NetworkImage(avatarUrl!),
                name: profile.displayName,
                size: 72,
              ),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.displayName,
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (country != null) ...<Widget>[
                      const SizedBox(height: HivorrSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.public,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: HivorrSpacing.xs),
                          Text(
                            country,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio != null &&
              profile.bio!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Text(
              profile.bio!.trim(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (profile.bio == null || profile.bio!.trim().isEmpty)
            const SizedBox(height: HivorrSpacing.md),
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              children: <Widget>[
                for (final PublicProfession profession in badges)
                  _professionChip(context, ext, profession),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _professionChip(
    BuildContext context,
    AppThemeExtension ext,
    PublicProfession profession,
  ) {
    final String label = profession.industryName.isEmpty
        ? profession.professionName
        : '${profession.professionName} · ${profession.industryName}';
    return Tooltip(
      message: profession.professionName,
      child: HivorrChip(
        label: label,
        isSelected: profession.isPrimary,
        variant: HivorrChipVariant.primary,
        onSelected: onProfessionTap == null
            ? null
            : (_) => onProfessionTap!(profession),
      ),
    );
  }

  /// Maps an optional ISO-3166-1 alpha-2 code to a display string (uppercase
  /// pass-through — no client-side country database lookup).
  static String? _displayCountry(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final String trimmed = code.trim();
    return trimmed.length == 2 ? trimmed.toUpperCase() : trimmed;
  }
}
