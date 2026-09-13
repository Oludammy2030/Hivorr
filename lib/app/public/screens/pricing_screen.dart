import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_info_row.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/pricing` page — an honest structure preview. No committed fee
/// figures exist yet; wording states fees are disclosed at transaction time
/// rather than inventing numbers (correction plan §15/Q3).
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _PricingHeader(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublicInfoRow(
            icon: Icons.check_circle_outline,
            title: 'Always free to start',
            body:
                'Creating your account, completing Basic Information and '
                'getting verified are free. There is no subscription required '
                'to register or browse.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pay when value moves',
            body:
                'Fees apply to transactions on the platform — professional '
                'services, commerce and logistics — and are always disclosed '
                'clearly before you confirm. No hidden charges.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.shield_outlined,
            title: 'Protected at every step',
            body:
                'Funds are held in escrow against milestones and released only '
                'on delivery. Payouts go to bound, verified accounts, with '
                'limits tied to your verification depth.',
          ),
          SizedBox(height: HivorrSpacing.xl),
        ],
      ),
    );
  }
}

class _PricingHeader extends StatelessWidget {
  const _PricingHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pricing',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'We earn when you do. Pricing on Hivorr is transparent, '
          'transaction-based and disclosed up front.',
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