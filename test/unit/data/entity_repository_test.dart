import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';

import 'entity_fakes.dart';

void main() {
  group('EntityRepositoryImpl', () {
    test('getProfile caches remote result locally', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      remote.profile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Ada',
        displayName: 'Ada L.',
      );
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repo =
          EntityRepositoryImpl(remote: remote, local: local);

      final EntityProfile profile = await repo.getProfile('e1');

      expect(profile.legalName, 'Ada');
      expect(local.cachedProfile?.legalName, 'Ada');
    });

    test('getProfile uses local cache when present', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      local.cachedProfile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Cached',
        displayName: 'C',
      );
      final EntityRepositoryImpl repo =
          EntityRepositoryImpl(remote: remote, local: local);

      final EntityProfile profile = await repo.getProfile('e1');

      expect(profile.legalName, 'Cached');
    });

    test('updateProfile returns mapped entity and caches it', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repo =
          EntityRepositoryImpl(remote: remote, local: local);

      final EntityProfile profile = await repo.updateProfile(
        entityId: 'e1',
        legalName: 'New',
        displayName: 'N',
        bio: 'b',
      );

      expect(profile.legalName, 'New');
      expect(local.cachedProfile?.legalName, 'New');
    });

    test('activateRole propagates ApiException on failure', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource()
        ..throwOnActivate = true;
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repo =
          EntityRepositoryImpl(remote: remote, local: local);

      expect(
        () => repo.activateRole(entityId: 'e1', role: 'merchant'),
        throwsA(isA<ApiException>()),
      );
    });

    test('getRoles maps remote role bindings', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      remote.roles = <EntityRoleDto>[
        const EntityRoleDto(entityId: 'e1', role: 'rider', isActive: true),
      ];
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repo =
          EntityRepositoryImpl(remote: remote, local: local);

      final List<EntityRole> roles = await repo.getRoles('e1');

      expect(roles.length, 1);
      expect(roles.first.role, EntityRoleValue.rider);
    });
  });
}
