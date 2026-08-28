import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/api_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/entity.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';

import '../../support/support.dart';

void main() {
  group('EntityRepositoryImpl (reference pattern)', () {
    late FakeEntityRemoteDataSource remote;
    late FakeEntityLocalDataSource local;
    late EntityRepositoryImpl repo;

    setUp(() {
      remote = FakeEntityRemoteDataSource();
      local = FakeEntityLocalDataSource();
      repo = EntityRepositoryImpl(remote: remote, local: local);
    });

    test('cache-first read: returns local without calling remote', () async {
      local.cachedProfile = EntityProfileDtoBuilder()
          .withLegalName('Cached')
          .withDisplayName('C')
          .build();
      final EntityProfile profile = await repo.getProfile('e1');

      expect(profile, isEntityProfile(legalName: 'Cached'));
      expect(remote.getProfileCallCount, 0,
          reason: 'local cache must be used without hitting remote');
    });

    test('remote fetch: fetches and writes through to local', () async {
      remote.profile = EntityProfileDtoBuilder()
          .withLegalName('Remote')
          .withDisplayName('R')
          .build();

      final EntityProfile profile = await repo.getProfile('e1');

      expect(profile, isEntityProfile(legalName: 'Remote'));
      expect(remote.getProfileCallCount, 1);
      expect(local.cachedProfile, isNotNull);
      expect(local.cachedProfile!.legalName, 'Remote');
    });

    test('error propagation: missing profile throws typed ApiException',
        () async {
      expect(
        () => repo.getProfile('missing'),
        throwsA(isApiException(kind: ApiExceptionKind.notFound)),
      );
    });

    test('write-through: updateProfile writes to remote and local', () async {
      final EntityProfile profile = await repo.updateProfile(
        entityId: 'e1',
        legalName: 'New',
        displayName: 'N',
        bio: 'b',
      );

      expect(profile, isEntityProfile(legalName: 'New'));
      expect(remote.updateProfileCallCount, 1);
      expect(local.cachedProfile!.legalName, 'New');
    });

    test('activateRole propagates ApiException on failure', () async {
      remote.throwOnActivate = true;
      expect(
        () => repo.activateRole(entityId: 'e1', role: 'merchant'),
        throwsA(isApiException()),
      );
    });

    test('getRoles maps remote role bindings', () async {
      remote.roles = <EntityRoleDto>[
        EntityRoleDtoBuilder()
            .withEntityId('e1')
            .withRole('rider')
            .withIsActive(true)
            .build(),
      ];

      final List<EntityRole> roles = await repo.getRoles('e1');

      expect(roles, hasLength(1));
      expect(roles.first, hasRole('rider'));
    });
  });

  group('Builders (reference pattern)', () {
    test('EntityProfileBuilder defaults', () {
      final EntityProfile p = EntityProfileBuilder().build();
      expect(p.legalName, 'Test Legal Name');
      expect(p.displayName, 'test_display');
      expect(p.countryCode, 'US');
    });

    test('EntityProfileBuilder override leaves defaults intact', () {
      final EntityProfile p =
          EntityProfileBuilder().withDisplayName('custom').build();
      expect(p.displayName, 'custom');
      expect(p.legalName, 'Test Legal Name');
    });

    test('EntityRoleBuilder default', () {
      final EntityRole r = EntityRoleBuilder().build();
      expect(r.role, EntityRoleValue.consumer);
      expect(r.isActive, isTrue);
    });

    test('EntityBuilder default aggregate', () {
      final Entity e = EntityBuilder().build();
      expect(e.id, 'test-entity-001');
      expect(e.profile, isNotNull);
      expect(e.roles, hasLength(1));
      expect(e, hasRole('consumer'));
    });

    test('EntityBuilder custom composition', () {
      final EntityProfile profile =
          EntityProfileBuilder().withLegalName('Custom').build();
      final EntityRole role = EntityRoleBuilder().withRoleName('merchant').build();
      final Entity e =
          EntityBuilder().withProfile(profile).addRole(role).build();
      expect(e.profile!.legalName, 'Custom');
      expect(e, hasRole('merchant'));
    });

    test('EntityProfileDtoBuilder.toMap includes null keys', () {
      final Map<String, dynamic> map =
          EntityProfileDtoBuilder().withEntityId('x').toMap();
      expect(map['entity_id'], 'x');
      expect(map['bio'], isNull);
      expect(map.containsKey('bio'), isTrue);
      expect(map['legal_name'], 'Test Legal Name');
    });

    test('ApiConfigBuilder defaults', () {
      final ApiConfig c = ApiConfigBuilder().build();
      expect(c.maxRetries, 3);
      expect(c.connectTimeout, const Duration(seconds: 15));
    });

    test('builders produce independent instances', () {
      final EntityProfileBuilder b = EntityProfileBuilder();
      final EntityProfile a = b.build();
      final EntityProfile c = b.build();
      expect(a, isNot(same(c)));
    });
  });

  group('Api matchers (reference pattern)', () {
    test('isApiException matches kind and message', () {
      final ApiException e = ApiException(
        kind: ApiExceptionKind.network,
        message: 'connection timeout',
      );
      expect(e, isApiException(kind: ApiExceptionKind.network));
      expect(e, isApiException(messageContains: 'timeout'));
      expect(e, isNot(isApiException(kind: ApiExceptionKind.server)));
    });

    test('isApiException rejects non-ApiException gracefully', () {
      expect('not an error', isNot(isApiException()));
    });

    test('hasStatusCode on ApiException', () {
      final ApiException e = ApiException(
        kind: ApiExceptionKind.auth,
        message: 'x',
        statusCode: 401,
      );
      expect(e, hasStatusCode(401));
    });
  });
}
