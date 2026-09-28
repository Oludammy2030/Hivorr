import 'package:flutter/material.dart';

import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

/// Selectable `pricing_type` chip row (EP-03-08).
///
/// Pure display + selection callback; validation stays in
/// [ServiceListingService.validatePricingType] and the server CHECKs.
class PricingTypeSelector extends StatelessWidget {
  const PricingTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// Currently selected pricing type code.
  final String? selected;

  /// Called with the chosen pricing type code.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.xs,
      children: ServiceListingService.pricingTypes
          .map(
            (String type) => HivorrChip(
              label: _labelFor(type),
              isSelected: selected == type,
              onSelected: (_) => onSelected(type),
            ),
          )
          .toList(growable: false),
    );
  }

  static String _labelFor(String type) => switch (type) {
        'fixed' => 'Fixed price',
        'hourly' => 'Hourly',
        'custom' => 'Custom',
        'per_milestone' => 'Per milestone',
        _ => type,
      };
}
