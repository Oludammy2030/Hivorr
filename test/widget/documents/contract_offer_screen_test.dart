import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/systems/documents/screens/contract_offer_screen.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_contract.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  MyServiceListing listingRow() => MyServiceListing(
    id: 'listing-1',
    entityId: 'pro-1',
    professionId: 'prof-1',
    industryId: 'ind-1',
    slug: 'listing-listing-1',
    title: 'Certified plumbing repair service',
    description:
        'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
    status: 'published',
    pricingType: 'fixed',
    priceMin: 5000,
    priceMax: 15000,
    currencyCode: 'NGN',
    avgRating: 4.5,
    reviewCount: 3,
    isTradeVerifiedCache: true,
  );

  List<SingleChildWidget> providers() {
    final contractRepo = FakeServiceContractRepository(
      seed: const <ServiceContract>[],
    );
    final contractProvider = ServiceContractProvider(
      service: ContractService(repository: contractRepo),
    );
    final listingRepo = FakeServiceListingRepository(
      seed: <MyServiceListing>[listingRow()],
    );
    return <SingleChildWidget>[
      ChangeNotifierProvider<ServiceContractProvider>.value(
        value: contractProvider,
      ),
      Provider<ServiceListingService>.value(
        value: ServiceListingService(repository: listingRepo),
      ),
    ];
  }

  /// Drags the offer list until [target] is built (lazy [ListView]).
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 6 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  group('ContractOfferScreen', () {
    testWidgets('renders listing header, milestone editor, and sum chip', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const ContractOfferScreen(listingId: 'listing-1'),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Certified plumbing repair service'),
        findsOneWidget,
      );
      expect(find.text('Milestone 1'), findsOneWidget);
      await scrollTo(tester, find.text('Send offer'));
      expect(find.text('Send offer'), findsOneWidget);
      expect(find.textContaining('Milestones sum'), findsOneWidget);
    });

    testWidgets('empty milestone title surfaces inline validation', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const ContractOfferScreen(listingId: 'listing-1'),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      // The total field is the first editable in tree order.
      await tester.enterText(find.byType(EditableText).first, '30000');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Send offer'));
      await tester.tap(find.text('Send offer'));
      await tester.pumpAndSettle();

      // Untouched empty title + zero total-amount milestone → inline errors.
      expect(
        find.text('Title must be 1 to 255 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('add milestone appends a second editor', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const ContractOfferScreen(listingId: 'listing-1'),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Add milestone'));
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();

      expect(find.text('Milestone 1'), findsOneWidget);
      expect(find.text('Milestone 2'), findsOneWidget);
    });
  });
}
