import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_registry_browser.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  final List<Industry> industries = <Industry>[
    const Industry(id: 'ind-legal', slug: 'legal', name: 'Legal', isActive: true, sortOrder: 10),
    const Industry(id: 'ind-tech', slug: 'technology', name: 'Technology', isActive: true, sortOrder: 20),
  ];

  final Map<String, List<Profession>> professionsByIndustry =
      <String, List<Profession>>{
    'ind-tech': <Profession>[
      const Profession(id: 'prof-web', industryId: 'ind-tech', slug: 'web-developer', name: 'Web Developer', isActive: true, sortOrder: 20),
      const Profession(id: 'prof-sw', industryId: 'ind-tech', slug: 'software-engineer', name: 'Software Engineer', isActive: true, sortOrder: 10),
    ],
  };

  Future<void> pumpBrowser(
    WidgetTester tester,
    TaxonomyProvider provider, {
    ProfessionRegistryBrowser Function()? build,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      build?.call() ?? const ProfessionRegistryBrowser(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TaxonomyProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();
  }

  TaxonomyProvider newProvider() => TaxonomyProvider(
        repository: FakeTaxonomyRepository(
          industries: industries,
          professionsByIndustry: professionsByIndustry,
        ),
      );

  testWidgets('renders industry picker in Step 1', (tester) async {
    await pumpBrowser(tester, newProvider());

    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Technology'), findsOneWidget);
  });

  testWidgets('selecting an industry advances to Step 2 with professions',
      (tester) async {
    await pumpBrowser(tester, newProvider());

    await tester.tap(find.text('Technology'));
    await tester.pumpAndSettle();

    expect(find.text('Web Developer'), findsOneWidget);
    expect(find.text('Software Engineer'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets(
      'Continue is disabled until a profession is selected and reports it',
      (tester) async {
    Profession? selected;
    await pumpBrowser(
      tester,
      newProvider(),
      build: () => ProfessionRegistryBrowser(
        onContinue: (Profession p) => selected = p,
      ),
    );

    await tester.tap(find.text('Technology'));
    await tester.pumpAndSettle();

    final ElevatedButton button =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Web Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    expect(selected?.name, 'Web Developer');
  });
}
