import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/mappers/industry_mapper.dart';
import 'package:hivorr/data/mappers/profession_mapper.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

import '../../support/builders/taxonomy_builders.dart';

void main() {
  group('IndustryMapper', () {
    test('maps DTO to entity and back', () {
      final IndustryDto dto = IndustryDtoBuilder()
          .withId('ind1')
          .withSlug('legal')
          .withName('Legal')
          .withDescription('Legal services')
          .withSortOrder(40)
          .build();

      final Industry entity = IndustryMapper.toEntity(dto);
      expect(entity.id, 'ind1');
      expect(entity.slug, 'legal');
      expect(entity.name, 'Legal');
      expect(entity.description, 'Legal services');
      expect(entity.isActive, isTrue);
      expect(entity.sortOrder, 40);

      final IndustryDto back = IndustryMapper.fromEntity(entity);
      expect(back.slug, 'legal');
      expect(back.name, dto.name);
      expect(back.sortOrder, 40);
      expect(back.isActive, isTrue);
    });

    test('tolerates null description and createdAt', () {
      final IndustryDto dto = IndustryDtoBuilder()
          .withSlug('technology')
          .withName('Technology')
          .withDescription(null)
          .withCreatedAt(null)
          .build();

      final Industry entity = IndustryMapper.toEntity(dto);
      expect(entity.description, isNull);
      expect(entity.createdAt, isNull);

      final IndustryDto back = IndustryMapper.fromEntity(entity);
      expect(back.description, isNull);
      expect(back.createdAt, isNull);
    });

    test('fromJson parses a server row and preserves slug format', () {
      final IndustryDto dto = IndustryDto.fromJson(
        IndustryDtoBuilder()
            .withSlug('financial-services')
            .withSortOrder(50)
            .toMap(),
      );
      expect(dto.slug, 'financial-services');
      expect(dto.sortOrder, 50);
      expect(dto.isActive, isTrue);
    });

    test('fromJson rejects an invalid slug defensively', () {
      expect(
        () => IndustryDto.fromJson(
          IndustryDtoBuilder().withSlug('Bad Slug!').toMap(),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ProfessionMapper', () {
    test('maps DTO to entity and back', () {
      final ProfessionDto dto = ProfessionDtoBuilder()
          .withId('prof1')
          .withIndustryId('ind1')
          .withSlug('corporate-lawyer')
          .withName('Corporate Lawyer')
          .withDescription('Contracts and advisory')
          .withSortOrder(20)
          .withIsActive(false)
          .build();

      final Profession entity = ProfessionMapper.toEntity(dto);
      expect(entity.id, 'prof1');
      expect(entity.industryId, 'ind1');
      expect(entity.slug, 'corporate-lawyer');
      expect(entity.name, 'Corporate Lawyer');
      expect(entity.description, 'Contracts and advisory');
      expect(entity.isActive, isFalse);
      expect(entity.sortOrder, 20);

      final ProfessionDto back = ProfessionMapper.fromEntity(entity);
      expect(back.industryId, 'ind1');
      expect(back.slug, 'corporate-lawyer');
      expect(back.isActive, isFalse);
    });

    test('tolerates null optional fields', () {
      final ProfessionDto dto = ProfessionDtoBuilder()
          .withDescription(null)
          .withCreatedAt(null)
          .build();

      final Profession entity = ProfessionMapper.toEntity(dto);
      expect(entity.description, isNull);
      expect(entity.createdAt, isNull);

      final ProfessionDto back = ProfessionMapper.fromEntity(entity);
      expect(back.description, isNull);
    });

    test('fromJson parses a server row and preserves slug format', () {
      final ProfessionDto dto = ProfessionDto.fromJson(
        ProfessionDtoBuilder()
            .withSlug('electrical-engineer')
            .withSortOrder(15)
            .toMap(),
      );
      expect(dto.slug, 'electrical-engineer');
      expect(dto.sortOrder, 15);
      expect(dto.industryId, 'industry-001');
    });

    test('fromJson rejects an invalid slug defensively', () {
      expect(
        () => ProfessionDto.fromJson(
          ProfessionDtoBuilder().withSlug('Not Valid!').toMap(),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
