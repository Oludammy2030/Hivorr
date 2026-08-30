import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_registry_widget.dart';
import 'package:provider/provider.dart';

import '../../support/builders/taxonomy_builders.dart';
import '../../support/harnesses/widget_harness.dart';
import '../../unit/data/taxonomy_fakes.dart';

void main() {
  late FakeTaxonomyRepository repository;
  late TaxonomyProvider provider;

  setUp(() {
    repository = FakeTaxonomyRepository(
      industries: <Industry>[
        IndustryBuilder()
            .withId('i1')
            .withSlug('technology')
            .withName('Technology')
            .build(),
        IndustryBuilder()
            .withId('i2')
            .withSlug('legal')
            .withName('Legal')
            .build(),
      ],
      professions: <Profession>[
        ProfessionBuilder()
            .withId('p1')
            .withIndustryId('i1')
            .withSlug('software-engineer')
            .withName('Software Engineer')
            .withDescription('Designs and builds software')
            .build(),
        ProfessionBuilder()
            .withId('p2')
            .withIndustryId('i2')
            .withSlug('corporate-lawyer')
            .withName('Corporate Lawyer')
            .build(),
        ProfessionBuilder()
            .withId('p3')
            .withIndustryId('i1')
            .withSlug('plumber')
            .withName('Plumber')
            .build(),
      ],
    );
    provider = TaxonomyProvider(repository: repository);
  });

  /// Pumps the registry inside a themed + provider-wrapped app.
  Future<void> pumpRegistry(
    WidgetTester tester, {
    String? initialIndustryId,
    bool showSearch = true,
    ValueChanged<Profession>? onSelected,
  }) async {
    await pumpApp(
      tester,
      ChangeNotifierProvider<TaxonomyProvider>.value(
        value: provider,
        child: ProfessionRegistryWidget(
          onSelected: onSelected ?? (_) {},
          initialIndustryId: initialIndustryId,
          showSearch: showSearch,
        ),
      ),
    );
    // let the async init/load future settle
    await tester.pump();
    await tester.pump();
  }

  group('ProfessionRegistryWidget', () {
    testWidgets('shows chips and empty state when no industry is pre-selected',
        (WidgetTester tester) async {
      await pumpRegistry(tester);

      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('Legal'), findsOneWidget);
      expect(find.text('Select an industry'), findsOneWidget);
    });

    testWidgets('loads professions for initialIndustryId and emits selection',
        (WidgetTester tester) async {
      final List<Profession> selected = <Profession>[];
      await pumpRegistry(
        tester,
        initialIndustryId: 'i1',
        onSelected: selected.add,
      );

      expect(find.text('Professions'), findsOneWidget);
      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Corporate Lawyer'), findsNothing);

      await tester.tap(find.text('Software Engineer'));
      await tester.pump();

      expect(selected.single.name, 'Software Engineer');
    });

    testWidgets('switching industry reloads its professions',
        (WidgetTester tester) async {
      await pumpRegistry(tester, initialIndustryId: 'i1');

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Corporate Lawyer'), findsNothing);

      await tester.tap(find.text('Legal'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Corporate Lawyer'), findsOneWidget);
      expect(find.text('Software Engineer'), findsNothing);
    });

    testWidgets('search filters in memory after the debounce',
        (WidgetTester tester) async {
      await pumpRegistry(tester, initialIndustryId: 'i1');
      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'engineer');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Plumber'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);
    });

    testWidgets('honors showSearch=false by omitting the field',
        (WidgetTester tester) async {
      await pumpRegistry(
        tester,
        initialIndustryId: 'i1',
        showSearch: false,
      );

      expect(find.byType(HivorrTextField), findsNothing);
      expect(find.text('Software Engineer'), findsOneWidget);
    });

    testWidgets('surfaces errors and recovers via retry',
        (WidgetTester tester) async {
      repository.throwError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Network unreachable',
        code: 'NW001',
      );
      await pumpRegistry(tester, initialIndustryId: 'i1');

      expect(find.text('Network unreachable'), findsOneWidget);

      repository.throwError = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Network unreachable'), findsNothing);
    });
  });
}