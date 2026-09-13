import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_info_row.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/security` page — the trust architecture (roadmap §II trust layer)
/// described for visitors without revealing proprietary mechanics.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _SecurityHeader(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublicInfoRow(
            icon: Icons.verified_user_outlined,
            title: 'Verified identity',
            body:
                'Entities are classified through a two-tier taxonomy '
                '(industry → profession). Identity documents are submitted and '
                'administered before trade activities unlock.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.fact_check_outlined,
            title: 'Trade verification gates',
            body:
                'Professionals get dashboard access immediately, but job '
                'bidding and accepting stay locked until their trade proof is '
                'approved.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.lock_outline,
            title: 'Escrow-backed transactions',
            body:
                'Funds are held securely against milestone completion, '
                'protecting both buyers and sellers on every engagement.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.key_outlined,
            title: 'KYC-driven limits',
            body:
                'Cashout limits and bound payout accounts are tied to '
                'verification depth, containing financial risk proportionally.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.gavel_outlined,
            title: 'Evidence-based disputes',
            body:
                'Conflicts are resolved through a structured, evidence-based '
                'process rather than ad-hoc complaints.',
          ),
          SizedBox(height: HivorrSpacing.xl),
        ],
      ),
    );
  }
}

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Security & trust',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Trust is Hivorr’s foundational competitive advantage — enforced at '
          'every layer from verification to escrow and fair resolution.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.lg),
        HivorrButton(
          label: 'Create your free account',
          onPressed: () => context.go(RoutePaths.signup),
        ),
      ],
    );
  }
}