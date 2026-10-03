import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/repositories/service_listing_repository_impl.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

import '../../support/fakes/fake_service_listing.dart';

void main() {
  group('toggleFavorite (EP-03-09)', () {
    test('repository returns favorited=true from the RPC envelope', () async {
      final FakeServiceListingRemoteDataSource remote =
          FakeServiceListingRemoteDataSource();
      final ServiceListingRepositoryImpl repository =
          ServiceListingRepositoryImpl(remote: remote);

      expect(await repository.toggleFavorite('listing-1'), isTrue);
    });

    test('service passthrough returns the post-toggle state', () async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(seed: const []);
      final ServiceListingService service = ServiceListingService(
        repository: repo,
      );

      expect(await service.toggleFavorite('listing-1'), isTrue);
      expect(repo.favorites, contains('listing-1'));
      // Second toggle removes.
      expect(await service.toggleFavorite('listing-1'), isFalse);
      expect(repo.favorites, isNot(contains('listing-1')));
    });
  });
}
