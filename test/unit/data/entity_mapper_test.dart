import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/mappers/entity_profile_mapper.dart';
import 'package:hivorr/data/mappers/entity_role_mapper.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

void main() {
  group('EntityProfileMapper', () {
    test('maps DTO to entity and back', () {
      const EntityProfileDto dto = EntityProfileDto(
        entityId: 'e1',
        legalName: 'Ada',
        displayName: 'Ada L.',
        bio: 'developer',
        avatarPath: 'a.png',
        countryCode: 'NG',
      );

      final EntityProfile entity = EntityProfileMapper.toEntity(dto);
      expect(entity.legalName, 'Ada');
      expect(entity.displayName, 'Ada L.');
      expect(entity.bio, 'developer');
      expect(entity.avatarPath, 'a.png');
      expect(entity.countryCode, 'NG');

      final EntityProfileDto back =
          EntityProfileMapper.fromEntity(entity, 'e1');
      expect(back.legalName, dto.legalName);
      expect(back.countryCode, dto.countryCode);
    });

    test('tolerates null optional fields', () {
      const EntityProfileDto dto = EntityProfileDto(
        entityId: 'e1',
        legalName: 'A',
        displayName: 'B',
      );

      final EntityProfile entity = EntityProfileMapper.toEntity(dto);
      expect(entity.bio, isNull);
      expect(entity.avatarPath, isNull);
      expect(entity.countryCode, isNull);

      final EntityProfileDto back =
          EntityProfileMapper.fromEntity(entity, 'e1');
      expect(back.bio, isNull);
    });
  });

  group('EntityRoleMapper', () {
    test('maps DTO to entity and back', () {
      const EntityRoleDto dto = EntityRoleDto(
        entityId: 'e1',
        role: 'professional',
        isActive: true,
      );

      final EntityRole role = EntityRoleMapper.toEntity(dto);
      expect(role.role, EntityRoleValue.professional);
      expect(role.isActive, isTrue);

      final EntityRoleDto back = EntityRoleMapper.fromEntity(role, 'e1');
      expect(back.role, 'professional');
      expect(back.isActive, isTrue);
    });
  });
}
