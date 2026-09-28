import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_validators.dart';

void main() {
  group('service-listing-media bucket config (EP-03-08)', () {
    test('bucket is allowlisted with 10MiB public jpeg/png/webp/pdf', () {
      expect(
        StorageBuckets.serviceListingMedia,
        'service-listing-media',
      );
      expect(
        StorageBuckets.all.contains(StorageBuckets.serviceListingMedia),
        isTrue,
      );
      expect(
        StorageLimits.forBucket(StorageBuckets.serviceListingMedia),
        10485760,
      );
      expect(
        StorageMimeTypes.forBucket(StorageBuckets.serviceListingMedia),
        <String>{
          'image/jpeg',
          'image/png',
          'image/webp',
          'application/pdf',
        },
      );
      expect(
        StorageBucketVisibilities.forBucket(
          StorageBuckets.serviceListingMedia,
        ),
        isTrue,
      );
    });

    test('validators accept image/pdf within limit, reject html', () {
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.serviceListingMedia,
        mimeType: 'image/jpeg',
        byteLength: 1024,
      );
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.serviceListingMedia,
        mimeType: 'application/pdf',
        byteLength: 10485760,
      );
      expect(
        () => StorageValidators.validateForBucket(
          bucket: StorageBuckets.serviceListingMedia,
          mimeType: 'text/html',
          byteLength: 10,
        ),
        throwsA(isA<Object>()),
      );
      expect(
        () => StorageValidators.validateForBucket(
          bucket: StorageBuckets.serviceListingMedia,
          mimeType: 'image/png',
          byteLength: 10485761,
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  group('StoragePaths.listingMedia', () {
    test('formats {entityId}/{listingId}/{uuid}_{sanitized}', () {
      final String path = StoragePaths.listingMedia(
        entityId: 'entity-1',
        listingId: 'listing-1',
        fileName: 'Cover Photo.PNG',
      );
      final List<String> parts = path.split('/');
      expect(parts, hasLength(3));
      expect(parts[0], 'entity-1');
      expect(parts[1], 'listing-1');
      expect(parts[2], endsWith('coverphoto.png'));
      expect(
        parts[2].split('_').first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('rejects empty listing id', () {
      expect(
        () => StoragePaths.listingMedia(
          entityId: 'entity-1',
          listingId: '',
          fileName: 'a.png',
        ),
        throwsA(isA<Object>()),
      );
    });
  });
}
