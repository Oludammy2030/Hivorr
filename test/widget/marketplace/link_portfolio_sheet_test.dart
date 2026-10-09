import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/link_portfolio_sheet.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_portfolio.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers({
    required FakeServiceListingRepository listingRepo,
    required FakePortfolioRemoteDataSource portfolioRemote,
  }) => <SingleChildWidget>[
    Provider<ServiceListingService>.value(
      value: ServiceListingService(repository: listingRepo),
    ),
    Provider<PortfolioRepository>.value(
      value: PortfolioRepositoryImpl(remote: portfolioRemote),
    ),
  ];

  /// Hosts a button that opens the sheet and records its result.
  Future<void> pumpOpener(
    WidgetTester tester, {
    required FakeServiceListingRepository listingRepo,
    required FakePortfolioRemoteDataSource portfolioRemote,
    List<String> initialSelection = const <String>[],
    required void Function(Future<bool?>) onResult,
  }) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => HivorrButton(
            label: 'Open sheet',
            onPressed: () {
              onResult(
                LinkPortfolioSheet.show(
                  context,
                  listingId: 'd1',
                  ownerEntityId: 'entity-1',
                  initialSelection: initialSelection,
                ),
              );
            },
          ),
        ),
      ),
      providers: providers(
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
      ),
    );
  }

  FakePortfolioRemoteDataSource portfolioWithItems(
    List<PortfolioItemDto> items,
  ) => FakePortfolioRemoteDataSource(
    result: seedPublicProfileDto(entityId: 'entity-1', portfolioItems: items),
  );

  group('LinkPortfolioSheet', () {
    testWidgets('lists owner items and saves the selection', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository();
      final FakePortfolioRemoteDataSource portfolioRemote =
          portfolioWithItems(<PortfolioItemDto>[
            seedPortfolioItemDto(id: 'p1', title: 'First piece'),
            seedPortfolioItemDto(id: 'p2', title: 'Second piece'),
          ]);
      bool? saved;
      await pumpOpener(
        tester,
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
        onResult: (Future<bool?> future) {
          unawaited(future.then((bool? value) => saved = value));
        },
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('First piece'), findsOneWidget);
      expect(find.text('Second piece'), findsOneWidget);
      // Save is disabled with an empty selection.
      expect(
        tester
            .widget<HivorrButton>(
              find.byWidgetPredicate(
                (Widget w) => w is HivorrButton && w.label == 'Save (0)',
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Save (1)'), findsOneWidget);

      await tester.tap(find.text('Save (1)'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      expect(listingRepo.proofLinkCalls, 1);
    });

    testWidgets('pre-selects the current links and supports unlink-all', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository();
      final FakePortfolioRemoteDataSource portfolioRemote =
          portfolioWithItems(<PortfolioItemDto>[
            seedPortfolioItemDto(id: 'p1', title: 'First piece'),
          ]);
      bool? saved;
      await pumpOpener(
        tester,
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
        initialSelection: const <String>['p1'],
        onResult: (Future<bool?> future) {
          unawaited(future.then((bool? value) => saved = value));
        },
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Save (1)'), findsOneWidget);

      // Clearing the selection unlinks every previously linked piece.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save (0)'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      expect(listingRepo.proofUnlinkCalls, 1);
      expect(listingRepo.proofLinkCalls, 0);
    });

    testWidgets('blocks selection beyond the cap', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository();
      final FakePortfolioRemoteDataSource portfolioRemote =
          portfolioWithItems(<PortfolioItemDto>[
            for (int i = 0; i < 9; i++)
              seedPortfolioItemDto(id: 'p$i', title: 'Piece $i'),
          ]);
      await pumpOpener(
        tester,
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
        onResult: (_) {},
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      for (int i = 0; i < 8; i++) {
        final Finder label = find.text('Piece $i');
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        await tester.tap(
          find.ancestor(of: label, matching: find.byType(CheckboxListTile)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Save (8)'), findsOneWidget);

      final Finder ninth = find.text('Piece 8');
      await tester.ensureVisible(ninth);
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: ninth, matching: find.byType(CheckboxListTile)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save (8)'), findsOneWidget);
      expect(
        find.text('You can only link up to 8 pieces.'),
        findsOneWidget,
      );
    });

    testWidgets('empty profile shows guidance without save', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository();
      final FakePortfolioRemoteDataSource portfolioRemote =
          portfolioWithItems(const <PortfolioItemDto>[]);
      await pumpOpener(
        tester,
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
        onResult: (_) {},
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('No portfolio pieces yet'), findsOneWidget);
    });

    testWidgets('server failure shows the error state with retry', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository();
      final FakePortfolioRemoteDataSource portfolioRemote =
          FakePortfolioRemoteDataSource(
            error: const ApiException(
              kind: ApiExceptionKind.server,
              message: 'Portfolio is unavailable.',
              code: 'PLT999',
            ),
          );
      await pumpOpener(
        tester,
        listingRepo: listingRepo,
        portfolioRemote: portfolioRemote,
        onResult: (_) {},
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load portfolio'), findsOneWidget);
    });
  });
}
