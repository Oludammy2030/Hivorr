import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/shared/components/hivorr_list_tile.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Scrollable list of professions for the selected industry, ordered by
/// [Profession.sortOrder]. Tapping a row calls [onSelected]. Shows a branded
/// [HivorrEmptyState] when the corpus (or search results) are empty.
class ProfessionList extends StatelessWidget {
  const ProfessionList({
    super.key,
    required this.professions,
    required this.onSelected,
    this.query = '',
  });

  /// The professions to render (already filtered + `sortOrder`-ordered).
  final List<Profession> professions;

  /// Emits the tapped profession (owner integration — no router push here).
  final ValueChanged<Profession> onSelected;

  /// The active search query, used for empty-state guidance.
  final String query;

  @override
  Widget build(BuildContext context) {
    if (professions.isEmpty) {
      final bool searching = query.trim().isNotEmpty;
      return HivorrEmptyState(
        icon: Icon(Icons.search_off_outlined),
        title: searching ? 'No professions found' : 'No professions yet',
        subtitle: searching
            ? 'Try a different keyword'
            : 'None are available for this industry yet',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: HivorrSectionHeader(title: 'Professions'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: professions.length,
            itemBuilder: (BuildContext context, int index) {
              final Profession profession = professions[index];
              return HivorrListTile(
                title: profession.name,
                subtitle: profession.description,
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                onTap: () => onSelected(profession),
              );
            },
          ),
        ),
      ],
    );
  }
}
