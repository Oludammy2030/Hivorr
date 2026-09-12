import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Step 2 — capability selection (EP-02-18 capability correction).
///
/// One account, fluid roles: after Basic Information the entity picks how it
/// will use Hivorr — [EntityCapability.hire] (consumer-only, finishes the
/// wizard), [EntityCapability.offer] (professional), or [EntityCapability.both].
/// Selection is one tap and auto-advances; professional choices continue into
/// industry selection (mirrors the industry step), a hire choice finishes.
/// Roles are activated server-side on the professional bind for the
/// professional paths; [EntityCapability.hire] keeps the consumer role
/// provisioned at sign-in.
class CapabilitySelectionScreen extends StatefulWidget {
  const CapabilitySelectionScreen({
    super.key,
    required this.active,
    required this.controller,
  });

  final bool active;
  final OnboardingStepController controller;

  @override
  State<CapabilitySelectionScreen> createState() =>
      _CapabilitySelectionScreenState();
}

class _CapabilitySelectionScreenState extends State<CapabilitySelectionScreen> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final ColorScheme colors = context.colorScheme;
    widget.controller.hidePrimary();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What will you do on Hivorr?',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'One account — pick the experience you need now. You can add the '
            'other side any time later.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          for (final EntityCapability capability
              in EntityCapability.values) ...<Widget>[
            _CapabilityCard(
              capability: capability,
              onTap: () => _select(capability),
            ),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          if (provider.lastError != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              provider.lastError!.message,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _select(EntityCapability capability) async {
    if (_advanced) {
      return;
    }
    _advanced = true;
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    await provider.selectCapability(capability);
    if (!mounted) {
      return;
    }
    if (provider.submitState == SubmitState.success) {
      // Hire-only entities finish after the capability step; professional/
      // `both` entities continue into industry selection.
      context.goNamed(
        provider.isComplete
            ? RouteNames.onboardingComplete
            : RouteNames.onboardingIndustry,
      );
    } else {
      _advanced = false;
    }
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability, required this.onTap});

  final EntityCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      onTap: onTap,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _iconFor(capability),
            size: 28,
            color: colors.primary,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(capability.label, style: context.textTheme.titleSmall),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  capability.description,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Icon(Icons.chevron_right, size: 24, color: colors.outline),
        ],
      ),
    );
  }

  static IconData _iconFor(EntityCapability capability) => switch (capability) {
        EntityCapability.hire => Icons.search_rounded,
        EntityCapability.offer => Icons.work_outline,
        EntityCapability.both => Icons.swap_horiz_rounded,
      };
}