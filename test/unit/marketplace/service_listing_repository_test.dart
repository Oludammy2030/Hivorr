import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/repositories/service_listing_repository_impl.dart';

import '../../support/fakes/fake_service_listing.dart';

void main() {
  const String professionId = 'prof-1';
  const String title = 'Certified plumbing repair service';
  const String description =
      'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.';

  ServiceListingRepositoryImpl repoWith(
    FakeServiceListingRemoteDataSource remote,
  ) =>
      ServiceListingRepositoryImpl(remote: remote);

  group('ServiceListingRepositoryImpl.createListing fail-fast', () {
    test('rejects short title without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: 'Short',
          description: description,
          pricingType: 'fixed',
          priceMin: 1000,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.createCalls, 0);
    });

    test('rejects short description without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: title,
          description: 'Too short',
          pricingType: 'fixed',
          priceMin: 1000,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('rejects bad pricing type without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: title,
          description: description,
          pricingType: 'per_hour',
          priceMin: 1000,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('rejects max < min without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: title,
          description: description,
          pricingType: 'fixed',
          priceMin: 5000,
          priceMax: 1000,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('rejects missing min for fixed without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: title,
          description: description,
          pricingType: 'fixed',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('allows missing min for custom and creates', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      final MyServiceListing created = await repo.createListing(
        professionId: professionId,
        title: title,
        description: description,
        pricingType: 'custom',
      );
      expect(remote.createCalls, 1);
      expect(created.pricingType, 'custom');
    });

    test('rejects bad currency without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.createListing(
          professionId: professionId,
          title: title,
          description: description,
          pricingType: 'custom',
          currencyCode: 'XYZ',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });
  });

  group('ServiceListingRepositoryImpl.listMine', () {
    test('rejects bad status without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(
        repo.listMine(status: 'unknown'),
        throwsA(isA<ApiException>()),
      );
      expect(remote.listCalls, 0);
    });

    test('rejects out-of-range limit without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = repoWith(remote);
      await expectLater(repo.listMine(limit: 0), throwsA(isA<ApiException>()));
      await expectLater(
        repo.listMine(limit: 101),
        throwsA(isA<ApiException>()),
      );
      expect(remote.listCalls, 0);
    });

    test('returns verbatim page', () async {
      final remote = FakeServiceListingRemoteDataSource(
        seed: <Map<String, dynamic>>[
          FakeServiceListingRemoteDataSource.row(
            id: 'listing-1',
            status: 'published',
          ),
          FakeServiceListingRemoteDataSource.row(
            id: 'listing-2',
            status: 'draft',
          ),
        ],
      );
      final repo = repoWith(remote);
      final page = await repo.listMine();
      expect(page.items.map((e) => e.id).toList(), <String>[
        'listing-1',
        'listing-2',
      ]);
    });
  });
}
