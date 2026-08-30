import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/workspace/profession_registry/widgets/industry_picker.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_picker.dart';
import 'package:hivorr/workspace/profession_registry/widgets/taxonomy_search_field.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  final List<Industry> industries = <Industry>[
    const Industry(id: 'ind-legal', slug: 'legal', name: 'Legal', isActive: true, sortOrder: 10),
    const Industry(id: 'ind-tech', slug: 'technology', name: 'Technology', isActive: true, sortOrder: 20),
    const Industry(id: 'ind-health', slug: 'healthcare', name: 'Healthcare', isActive: true, sortOrder: 30),
  ];

  group('IndustryPicker', () {
    testWidgets('renders industries in given order and reports selection', (tester) async {
      Industry? selected;
      await pumpApp(
        tester,
        IndustryPicker(
          industries: industries,
          onSelected: (Industry i) => selected = i,
        ),
      );

      expect(find.text('Legal'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('Healthcare'), findsOneWidget);

      await tester.tap(find.text('Technology'));
      expect(selected?.id, 'ind-tech');
    });
  });

  group('ProfessionPicker', () {
    final List<Profession> professions = <Profession>[
      const Profession(id: 'p1', industryId: 'ind-tech', slug: 'software-engineer', name: 'Software Engineer', isActive: true, sortOrder: 10),
      const Profession(id: 'p2', industryId: 'ind-tech', slug: 'web-developer', name: 'Web Developer', isActive: true, sortOrder: 20),
    ];

    testWidgets('renders professions with description subtitle', (tester) async {
      await pumpApp(tester, ProfessionPicker(professions: professions));

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Web Developer'), findsOneWidget);
    });

    testWidgets('shows empty state when no professions', (tester) async {
      await pumpApp(
        tester,
        const ProfessionPicker(professions: <Profession>[]),
      );

      expect(find.text('No matches'), findsOneWidget);
    });
  });

  group('TaxonomySearchField', () {
    testWidgets('does not fire query before debounce window', (tester) async {
      String? emitted;
      await pumpApp(
        tester,
        TaxonomySearchField(
          debounce: const Duration(milliseconds: 250),
          onQueryChanged: (String q) => emitted = q,
        ),
      );

      await tester.enterText(find.byType(TextField), 'web');
      await tester.pump(const Duration(milliseconds: 100));
      expect(emitted, isNull);

      await tester.pump(const Duration(milliseconds: 200));
      expect(emitted, 'web');
    });

    testWidgets('clear button resets query', (tester) async {
      String? emitted;
      await pumpApp(
        tester,
        TaxonomySearchField(
          debounce: const Duration(milliseconds: 250),
          onQueryChanged: (String q) => emitted = q,
        ),
      );

      await tester.enterText(find.byType(TextField), 'web');
      await tester.pump(const Duration(milliseconds: 300));
      expect(emitted, 'web');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(emitted, '');
    });
  });
}
