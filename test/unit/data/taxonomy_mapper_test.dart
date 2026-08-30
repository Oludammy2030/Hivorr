import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/mappers/industry_mapper.dart';
import 'package:hivorr/data/mappers/profession_mapper.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

void main() {
  group('IndustryMapper', () {
    test('maps DTO to entity and back (snake -> camel)', () {
      final IndustryDto dto = IndustryDto.fromJson(<String, dynamic>{
        'id': 'ind-1',
        'slug': 'legal',
        'name': 'Legal',
        'description': 'Legal services',
        'is_active': true,
        'sort_order': 10,
        'created_at': '2026-08-30T10:00:00.000Z',
      });

      final entity = IndustryMapper.toEntity(dto);
      expect(entity.id, 'ind-1');
      expect(entity.slug, 'legal');
      expect(entity.isActive, isTrue);
      expect(entity.sortOrder, 10);

      final IndustryDto back = IndustryMapper.fromEntity(entity);
      expect(back.slug, 'legal');
      expect(back.isActive, isTrue);
      expect(back.sortOrder, 10);
    });

    test('is null-safe on optional fields', () {
      final IndustryDto dto = IndustryDto.fromJson(<String, dynamic>{
        'id': 'ind-1',
        'slug': 'legal',
        'name': 'Legal',
        'is_active': true,
        'sort_order': 0,
      });

      final entity = IndustryMapper.toEntity(dto);
      expect(entity.description, isNull);
      expect(entity.createdAt, isNull);
    });
  });

  group('ProfessionMapper', () {
    test('maps DTO to entity preserving the industry FK', () {
      final ProfessionDto dto = ProfessionDto.fromJson(<String, dynamic>{
        'id': 'prof-1',
        'industry_id': 'ind-tech',
        'slug': 'software-engineer',
        'name': 'Software Engineer',
        'is_active': true,
        'sort_order': 10,
      });

      final entity = ProfessionMapper.toEntity(dto);
      expect(entity.industryId, 'ind-tech');
      expect(entity.slug, 'software-engineer');
      expect(entity.isActive, isTrue);

      final ProfessionDto back = ProfessionMapper.fromEntity(entity);
      expect(back.industryId, 'ind-tech');
      expect(back.slug, 'software-engineer');
    });
  });
}
