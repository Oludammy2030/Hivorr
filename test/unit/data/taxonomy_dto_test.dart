import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

void main() {
  group('IndustryDto', () {
    test('fromJson maps snake_case columns exactly', () {
      final IndustryDto dto = IndustryDto.fromJson(<String, dynamic>{
        'id': 'ind-1',
        'slug': 'legal',
        'name': 'Legal',
        'description': 'Legal services',
        'is_active': true,
        'sort_order': 10,
        'created_at': '2026-08-30T10:00:00.000Z',
      });

      expect(dto.id, 'ind-1');
      expect(dto.slug, 'legal');
      expect(dto.name, 'Legal');
      expect(dto.description, 'Legal services');
      expect(dto.isActive, isTrue);
      expect(dto.sortOrder, 10);
      expect(dto.createdAt, isNotNull);
    });

    test('toJson round-trips, omitting null optionals', () {
      final IndustryDto dto = IndustryDto.fromJson(<String, dynamic>{
        'id': 'ind-1',
        'slug': 'legal',
        'name': 'Legal',
        'is_active': true,
        'sort_order': 10,
      });
      final Map<String, dynamic> json = dto.toJson();
      expect(json['slug'], 'legal');
      expect(json['is_active'], isTrue);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });

    test('tolerates null description and createdAt', () {
      final IndustryDto dto = IndustryDto.fromJson(<String, dynamic>{
        'id': 'ind-1',
        'slug': 'legal',
        'name': 'Legal',
        'is_active': false,
        'sort_order': 0,
      });
      expect(dto.description, isNull);
      expect(dto.createdAt, isNull);
      expect(dto.isActive, isFalse);
    });
  });

  group('ProfessionDto', () {
    test('fromJson maps snake_case columns including industry_id', () {
      final ProfessionDto dto = ProfessionDto.fromJson(<String, dynamic>{
        'id': 'prof-1',
        'industry_id': 'ind-tech',
        'slug': 'software-engineer',
        'name': 'Software Engineer',
        'description': 'Build software',
        'is_active': true,
        'sort_order': 10,
      });

      expect(dto.id, 'prof-1');
      expect(dto.industryId, 'ind-tech');
      expect(dto.slug, 'software-engineer');
      expect(dto.name, 'Software Engineer');
      expect(dto.isActive, isTrue);
      expect(dto.sortOrder, 10);
    });

    test('toJson round-trips preserving industry_id', () {
      final ProfessionDto dto = ProfessionDto.fromJson(<String, dynamic>{
        'id': 'prof-1',
        'industry_id': 'ind-tech',
        'slug': 'web-developer',
        'name': 'Web Developer',
        'is_active': true,
        'sort_order': 20,
      });
      final Map<String, dynamic> json = dto.toJson();
      expect(json['industry_id'], 'ind-tech');
      expect(json['slug'], 'web-developer');
    });
  });
}
