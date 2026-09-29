import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Public storefront route at `/store/:storeId`.
///
/// Local commerce storefronts are not live yet: this screen is an honest
/// holding state (never a dead-end) with the path into the live platform.
/// The `storeId` is intentionally never echoed (SEO-404 semantics, mirroring
/// the professional-profile not-found view).
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Local commerce',
            style: context.textTheme.displaySmall?.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Text(
            'Buy and sell locally inside the same Hivorr account as your '
            'professional life.',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const HivorrEmptyState(
            icon: Icon(Icons.storefront_outlined),
            title: 'Storefronts are opening soon',
            subtitle:
                'Local commerce storefronts are not live yet. Professional '
                'services, escrow-protected hiring and verification are '
                'available today.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Start with what is live today.',
            actions: <Widget>[
              HivorrButton(
                label: 'Create your free account',
                onPressed: () => context.go(RoutePaths.signup),
              ),
              HivorrButton(
                label: 'How it works',
                variant: HivorrButtonVariant.outline,
                onPressed: () => context.go(RoutePaths.howItWorks),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
