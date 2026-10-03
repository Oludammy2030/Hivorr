import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/manage_user_provider.dart';

import '../../support/fakes/fake_manage_user.dart';

void main() {
  group('ManageUserProvider.fetchUserDetail (review comparison cache)', () {
    test('caches per entity without touching selectedUser', () async {
      final FakeManageUserRepository repo = FakeManageUserRepository();
      repo.setDetail(manageUserDetail(id: 'u1'));
      final ManageUserProvider provider = ManageUserProvider(repo: repo);

      final fetched = await provider.fetchUserDetail('u1');

      expect(fetched, isNotNull);
      expect(provider.cachedDetail('u1'), isNotNull);
      expect(provider.selectedUser, isNull);
      expect(repo.detailCallCount, 1);

      // Second fetch serves the cache without another RPC.
      await provider.fetchUserDetail('u1');
      expect(repo.detailCallCount, 1);
    });

    test('records failure and recovers on retry', () async {
      final FakeManageUserRepository repo = FakeManageUserRepository();
      final ManageUserProvider provider = ManageUserProvider(repo: repo);

      expect(await provider.fetchUserDetail('missing'), isNull);
      expect(provider.detailFailed('missing'), isTrue);

      // Failed ids are not retried implicitly.
      await provider.fetchUserDetail('missing');
      expect(repo.detailCallCount, 1);

      repo.setDetail(manageUserDetail(id: 'missing'));
      provider.retryUserDetail('missing');
      final fetched = await provider.fetchUserDetail('missing');

      expect(fetched, isNotNull);
      expect(provider.detailFailed('missing'), isFalse);
    });
  });
}
