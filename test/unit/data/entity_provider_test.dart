import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';

import 'entity_fakes.dart';

void main() {
  group('EntityProvider', () {
    test('loadProfile transitions idle -> loaded and exposes profile',
        () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      remote.profile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Ada',
        displayName: 'Ada L.',
      );
      final EntityProvider provider = EntityProvider(
        repository: EntityRepositoryImpl(
          remote: remote,
          local: FakeEntityLocalDataSource(),
        ),
      );

      expect(provider.state, EntityProviderState.idle);

      await provider.loadProfile('e1');

      expect(provider.state, EntityProviderState.loaded);
      expect(provider.profile?.legalName, 'Ada');
      expect(provider.error, isNull);
    });

    test('error state surfaces ApiException and does not crash', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource()
        ..throwOnActivate = true;
      final EntityProvider provider = EntityProvider(
        repository: EntityRepositoryImpl(
          remote: remote,
          local: FakeEntityLocalDataSource(),
        ),
      );

      await provider.loadProfile('e1');

      expect(provider.state, EntityProviderState.error);
      expect(provider.error, isA<ApiException>());
    });

    test('activateRole refreshes the role list on success', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      final EntityProvider provider = EntityProvider(
        repository: EntityRepositoryImpl(
          remote: remote,
          local: FakeEntityLocalDataSource(),
        ),
      );

      await provider.activateRole(entityId: 'e1', role: 'merchant');

      expect(provider.state, EntityProviderState.loaded);
      expect(provider.roles.length, 1);
      expect(provider.roles.first.role, EntityRoleValue.merchant);
    });
  });
}
