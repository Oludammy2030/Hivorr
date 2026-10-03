import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/systems/marketplace/widgets/service_media_carousel.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  const List<ListingMedia> media = <ListingMedia>[
    ListingMedia(
      id: 'm1',
      storagePath: 'entity-1/l1/cover.jpg',
      mimeType: 'image/jpeg',
      sortOrder: 0,
    ),
    ListingMedia(
      id: 'm2',
      storagePath: 'entity-1/l1/second.jpg',
      mimeType: 'image/jpeg',
      sortOrder: 1,
    ),
  ];

  group('ServiceMediaCarousel', () {
    testWidgets('shows empty state when no media', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const ServiceMediaCarousel(media: <ListingMedia>[]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('renders cover badge and position in server order', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const ServiceMediaCarousel(media: media),
      );
      await tester.pumpAndSettle();

      // First page carries the cover badge (sort_order 0) and position.
      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      // Unresolvable URLs fall back to placeholders, never broken images.
      expect(find.byIcon(Icons.image_outlined), findsWidgets);
    });
  });
}
