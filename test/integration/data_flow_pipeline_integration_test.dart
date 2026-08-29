import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';

import '../support/fakes/fake_datasource.dart';
import '../support/matchers/entity_matchers.dart';
import '../support/matchers/state_matchers.dart';

/// Remote fake that always throws an [ApiException] on [getProfile].
///
/// Used to exercise error propagation end-to-end without a live backend.
class _ThrowingFakeRemoteDataSource extends FakeEntityRemoteDataSource {
  @override
  Future<EntityProfileDto?> getProfile(String entityId) async =>
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Profile not found.',
        code: 'PLT004',
      );
}

void main() {
  group('Data Flow Pipeline Integration (EP-01-20 §5.6)', () {
    test('1. Cache-first read uses local datasource and avoids remote', () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      local.cachedProfile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Cached Legal',
        displayName: 'cached_display',
        bio: 'cached bio',
        countryCode: 'NG',
      );
      final EntityRepositoryImpl repository = EntityRepositoryImpl(
        remote: remote,
        local: local,
      );

      final EntityProfile profile = await repository.getProfile('e1');

      // Remote must not be touched when the cache is warm.
      expect(remote.getProfileCallCount, 0);
      // Mapped through the real EntityProfileMapper.
      expect(profile, isEntityProfile(legalName: 'Cached Legal'));
      expect(profile.displayName, 'cached_display');
      expect(profile.bio, 'cached bio');
      expect(profile.countryCode, 'NG');
    });

    test('2. Remote fetch writes through to local and loads into provider',
        () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      remote.profile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Remote Legal',
        displayName: 'remote_display',
        bio: 'remote bio',
        avatarPath: 'a.png',
        countryCode: 'US',
      );
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repository = EntityRepositoryImpl(
        remote: remote,
        local: local,
      );
      final EntityProvider provider = EntityProvider(repository: repository);

      final EntityProfile profile = await repository.getProfile('e1');

      // Remote called exactly once.
      expect(remote.getProfileCallCount, 1);
      // Write-through to the local cache.
      expect(local.cachedProfile, isNotNull);
      expect(local.cachedProfile?.legalName, 'Remote Legal');
      // Real mapper produced the correct domain entity.
      expect(profile, isEntityProfile(legalName: 'Remote Legal'));
      expect(profile.avatarPath, 'a.png');
      expect(profile.countryCode, 'US');

      // Provider on top emits a loaded state with the correct entity.
      await provider.loadProfile('e1');
      expect(provider, hasLoadedState());
      expect(provider.profile, isEntityProfile(legalName: 'Remote Legal'));
      expect(provider.error, isNull);
    });

    test('3. Error propagation surfaces ApiException in provider', () async {
      final FakeEntityRemoteDataSource remote = _ThrowingFakeRemoteDataSource();
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repository = EntityRepositoryImpl(
        remote: remote,
        local: local,
      );
      final EntityProvider provider = EntityProvider(repository: repository);

      // Repository propagates the typed ApiException.
      expect(
        () => repository.getProfile('e1'),
        throwsA(isA<ApiException>()),
      );

      // Provider catches it and emits an error state.
      await provider.loadProfile('e1');
      expect(provider, hasErrorState());
      expect(provider.error, isA<ApiException>());
      expect(provider.state, EntityProviderState.error);
      expect(provider.profile, isNull);
    });

    test('4. Provider emits idle -> loading -> loaded transitions and notifies',
        () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      remote.profile = const EntityProfileDto(
        entityId: 'e1',
        legalName: 'Flow Legal',
        displayName: 'flow_display',
      );
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityProvider provider = EntityProvider(
        repository: EntityRepositoryImpl(remote: remote, local: local),
      );

      final List<EntityProviderState> observed = <EntityProviderState>[];
      int notifyCount = 0;
      void listener() {
        observed.add(provider.state);
        notifyCount++;
      }

      provider.addListener(listener);
      expect(provider.state, EntityProviderState.idle);

      await provider.loadProfile('e1');

      provider.removeListener(listener);

      // notifyListeners fired at least for loading + loaded transitions.
      expect(notifyCount, greaterThanOrEqualTo(2));
      // The loading state was observed before the loaded state.
      expect(observed, contains(EntityProviderState.loading));
      expect(observed, contains(EntityProviderState.loaded));
      expect(observed.indexOf(EntityProviderState.loading),
          lessThan(observed.indexOf(EntityProviderState.loaded)));
    });

    test('5. Update writes through to remote and local and updates provider',
        () async {
      final FakeEntityRemoteDataSource remote = FakeEntityRemoteDataSource();
      final FakeEntityLocalDataSource local = FakeEntityLocalDataSource();
      final EntityRepositoryImpl repository = EntityRepositoryImpl(
        remote: remote,
        local: local,
      );
      final EntityProvider provider = EntityProvider(repository: repository);

      const String entityId = 'e1';
      final EntityProfile updated = await repository.updateProfile(
        entityId: entityId,
        legalName: 'Updated Legal',
        displayName: 'updated_display',
        bio: 'updated bio',
      );

      // Remote invoked exactly once and local cache refreshed.
      expect(remote.updateProfileCallCount, 1);
      expect(local.cachedProfile, isNotNull);
      expect(local.cachedProfile?.legalName, 'Updated Legal');
      expect(updated, isEntityProfile(legalName: 'Updated Legal'));
      expect(updated.displayName, 'updated_display');
      expect(updated.bio, 'updated bio');

      // Provider emits the updated entity.
      await provider.updateProfile(
        entityId: entityId,
        legalName: 'Updated Legal',
        displayName: 'updated_display',
        bio: 'updated bio',
      );
      expect(provider, hasLoadedState());
      expect(provider.profile, isEntityProfile(legalName: 'Updated Legal'));
      expect(provider.profile?.displayName, 'updated_display');
      expect(provider.profile?.bio, 'updated bio');
    });
  });
}
