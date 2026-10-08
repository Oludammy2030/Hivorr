import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Bottom-sheet slot picker for a booking day (EP-03-14 §8 D10).
///
/// Maps the professional's weekly [slots] for the sheet's weekday into
/// concrete local wall-clock windows on [day] by stepping each slot's
/// `[start_time, end_time)` by `slot_duration_min`. Pure display + selection:
/// overlap authority stays server-side (`PLT005` on conflict).
class SlotPickerSheet extends StatelessWidget {
  const SlotPickerSheet({
    super.key,
    required this.day,
    required this.slots,
    required this.takenWindows,
    this.onPick,
  });

  /// The booking day (local wall-clock date; time component ignored).
  final DateTime day;

  /// Template slots covering this weekday (already filtered by caller).
  final List<AvailabilitySlot> slots;

  /// Windows already known-taken (from a `PLT005` conflict refresh).
  final List<DateTime> takenWindows;

  /// Called with the picked window start (local wall-clock).
  final ValueChanged<DateTime>? onPick;

  /// Concrete window starts for [day] derived from [slots].
  static List<DateTime> windowsForDay(
    DateTime day,
    List<AvailabilitySlot> slots,
  ) {
    final List<DateTime> windows = <DateTime>[];
    for (final AvailabilitySlot slot in slots) {
      if (!slot.isActive) continue;
      final List<String> startParts = slot.startTime.split(':');
      final List<String> endParts = slot.endTime.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;
      final int startMinutes =
          (int.tryParse(startParts[0]) ?? 0) * 60 +
          (int.tryParse(startParts[1]) ?? 0);
      final int endMinutes =
          (int.tryParse(endParts[0]) ?? 0) * 60 +
          (int.tryParse(endParts[1]) ?? 0);
      final int step = slot.slotDurationMin <= 0
          ? 60
          : slot.slotDurationMin;
      for (int m = startMinutes; m + step <= endMinutes; m += step) {
        windows.add(
          DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
        );
      }
    }
    windows.sort();
    return windows;
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> windows = windowsForDay(day, slots);
    return HivorrBottomSheet(
      title: 'Pick a time',
      child: windows.isEmpty
          ? const HivorrEmptyState(
              title: 'No availability',
              subtitle: 'The professional has no slots on this day.',
            )
          : Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              children: <Widget>[
                for (final DateTime window in windows)
                  HivorrChip(
                    label: HivorrFormatters.time(window),
                    isSelected: false,
                    onSelected: takenWindows.any(
                      (DateTime taken) => taken.isAtSameMomentAs(window),
                    )
                        ? null
                        : (_) => onPick?.call(window),
                  ),
              ],
            ),
    );
  }
}
