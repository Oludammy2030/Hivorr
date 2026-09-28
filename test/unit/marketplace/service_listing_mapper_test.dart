import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/mappers/service_listing_mapper.dart';
import 'package:hivorr/data/models/listing_media_dto.dart';

void main() {
  group('ServiceListingMapper.toMediaEntity', () {
    test('maps media DTO verbatim', () {
      const dto = ListingMediaDto(
        id: 'media-1',
        storagePath: 'entity-1/listing-1/uuid_cover.png',
        mimeType: 'image/png',
        sortOrder: 0,
      );
      final ListingMedia entity = ServiceListingMapper.toMediaEntity(dto);
      expect(entity.id, 'media-1');
      expect(entity.storagePath, contains('listing-1'));
      expect(entity.sortOrder, 0);
      expect(entity.isCover, isTrue);
    });
  });

  group('ServiceListingMapper.toOwnerEntity', () {
    Map<String, dynamic> row() => <String, dynamic>{
          'id': 'listing-1',
          'entity_id': 'entity-1',
          'profession_id': 'prof-1',
          'industry_id': 'ind-1',
          'slug': 'listing-listing-1',
          'title': 'Certified plumbing repair service',
          'description':
              'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
          'status': 'published',
          'pricing_type': 'fixed',
          'price_min': 5000,
          'currency_code': 'NGN',
          'avg_rating': 0,
          'review_count': 0,
          'is_trade_verified_cache': true,
          'media': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'media-2',
              'storage_path': 'entity-1/listing-1/b.png',
              'mime_type': 'image/png',
              'sort_order': 1,
            },
            <String, dynamic>{
              'id': 'media-1',
              'storage_path': 'entity-1/listing-1/a.png',
              'mime_type': 'image/png',
              'sort_order': 0,
            },
          ],
        };

    test('maps status and preserves media order verbatim', () {
      final listing = ServiceListingMapper.toOwnerEntity(row());
      expect(listing.status, 'published');
      expect(listing.isPublished, isTrue);
      expect(listing.media, hasLength(2));
      // Verbatim server order (not re-sorted client-side in this fixture —
      // the fixture itself is ordered; mapper must not reorder).
      expect(listing.media.first.id, 'media-2');
    });

    test('defaults missing media to empty', () {
      final Map<String, dynamic> noMedia = row()..remove('media');
      final listing = ServiceListingMapper.toOwnerEntity(noMedia);
      expect(listing.media, isEmpty);
    });

    test('exposes lifecycle helpers', () {
      final draft = ServiceListingMapper.toOwnerEntity(
        <String, dynamic>{...row(), 'status': 'draft'},
      );
      expect(draft.canPublish, isTrue);
      expect(draft.canUnpublish, isFalse);
      final published = ServiceListingMapper.toOwnerEntity(row());
      expect(published.canUnpublish, isTrue);
    });
  });

  group('ServiceListingMapper.toOwnerPage', () {
    test('preserves list order verbatim', () {
      final page = ServiceListingMapper.toOwnerPage(
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a',
            'entity_id': 'e',
            'profession_id': 'p',
            'industry_id': 'i',
            'slug': 's-a',
            'title': 'Certified plumbing repair service A',
            'description':
                'Full home plumbing inspection, leak repair, and fixture replacement with warranty included.',
            'status': 'draft',
            'pricing_type': 'custom',
            'currency_code': 'NGN',
          },
          <String, dynamic>{
            'id': 'b',
            'entity_id': 'e',
            'profession_id': 'p',
            'industry_id': 'i',
            'slug': 's-b',
            'title': 'Certified plumbing repair service B',
            'description':
                'Full home plumbing inspection, leak repair, and fixture replacement with warranty included.',
            'status': 'published',
            'pricing_type': 'custom',
            'currency_code': 'NGN',
          },
        ],
        hasMore: true,
        nextCursor: 'b',
      );
      expect(page.items.map((e) => e.id).toList(), <String>['a', 'b']);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'b');
    });
  });
}
