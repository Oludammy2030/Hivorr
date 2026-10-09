import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/mappers/service_listing_mapper.dart';
import 'package:hivorr/data/models/service_listing_proof_dto.dart';

void main() {
  Map<String, dynamic> row({
    required String id,
    int? linkSortOrder = 1,
  }) => <String, dynamic>{
    'id': id,
    'item_type': 'image',
    'title': 'Proof $id',
    'description': 'Proof of completed work.',
    'media_path': 'portfolio-items/entity-9/$id.jpg',
    'sort_order': 2,
    'link_sort_order': linkSortOrder,
  };

  group('ServiceListingMapper.toProofEntity', () {
    test('maps item columns plus link order', () {
      final entity = ServiceListingMapper.toProofEntity(
        ServiceListingProofDto.fromJson(row(id: 'p1', linkSortOrder: 3)),
      );

      expect(entity.item.id, 'p1');
      expect(entity.item.itemType, 'image');
      expect(entity.item.title, 'Proof p1');
      expect(entity.item.description, 'Proof of completed work.');
      expect(entity.item.mediaPath, 'portfolio-items/entity-9/p1.jpg');
      expect(entity.item.sortOrder, 2);
      expect(entity.linkSortOrder, 3);
    });

    test('tolerates null link order', () {
      final entity = ServiceListingMapper.toProofEntity(
        ServiceListingProofDto.fromJson(row(id: 'p1', linkSortOrder: null)),
      );

      expect(entity.item.id, 'p1');
      expect(entity.linkSortOrder, isNull);
    });
  });

  group('ServiceListingMapper.toProofEntities', () {
    test('preserves RPC order verbatim', () {
      final entities = ServiceListingMapper.toProofEntities(<Map<String, dynamic>>[
        row(id: 'b', linkSortOrder: 2),
        row(id: 'a', linkSortOrder: 1),
      ]);

      expect(entities.map((e) => e.item.id), ['b', 'a']);
      expect(entities.map((e) => e.linkSortOrder), [2, 1]);
    });

    test('returns an empty list for empty input', () {
      expect(
        ServiceListingMapper.toProofEntities(const <Map<String, dynamic>>[]),
        isEmpty,
      );
    });
  });
}
