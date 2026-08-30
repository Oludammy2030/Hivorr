import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Selectable list of professions (tier-2 of the two-tier taxonomy) for a given
/// industry, respecting a client-side search query.
///
/// Shows each [Profession] as a tappable [HivorrCard] with its name as the
/// primary line and description as the subtitle. Shows [HivorrEmptyState] when
/// the list (after filtering) is empty. Built entirely from [AppTheme] tokens
/// (AGENT.md Rule 5).
class ProfessionPicker extends StatelessWidget {
  const ProfessionPicker({
    super.key,
    required this.professions,
    this.selectedId,
    this.onSelected,
  });

  /// The professions to render (already ordered and filtered by the caller).
  final List<Profession> professions;

  /// The currently selected profession id, if any.
  final String? selectedId;

  /// Called when a profession is tapped.
  final ValueChanged<Profession>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (professions.isEmpty) {
      return const HivorrEmptyState(
        title: 'No matches',
        subtitle: 'Try a broader term.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
      itemCount: professions.length,
      itemBuilder: (BuildContext context, int index) {
        final Profession profession = professions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
          child: HivorrCard(
            elevation: profession.id == selectedId ? 1 : 0,
            onTap: () => onSelected?.call(profession),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(profession.name,
                          style: context.textTheme.titleMedium),
                      if (profession.description != null &&
                          profession.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: HivorrSpacing.xs),
                          child: Text(
                            profession.description!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (profession.id == selectedId)
                  Icon(
                    Icons.check_circle,
                    color: context.colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
