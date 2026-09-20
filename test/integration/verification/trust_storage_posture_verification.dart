// EP-02-20 DoD-C4: Storage Posture Verification.
//
// Re-runs the `017_storage_posture.sql` + `018_portfolio_public_profile.sql`
// pgTAP lens conceptually by asserting that the client-side StorageConfig
// constants match the frozen migration specifications exactly.
//
// Private bucket `credential-documents`: 10 MiB, jpeg/png/webp/pdf, signed-URL only.
// Public bucket `profile-avatars`: 5 MiB, jpeg/png/webp.
// Public bucket `portfolio-items`: 10 MiB, jpeg/png/webp/pdf.
//
// Run: flutter test test/integration/verification/trust_storage_posture_verification.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/storage/storage_config.dart';

void main() {
  group('DoD-C4: Storage posture verification', () {
    test('credential-documents is private (not public-read)', () {
      expect(
        StorageBucketVisibilities.credentialDocuments,
        isFalse,
        reason:
            'credential-documents must be private per 017_storage_posture.sql',
      );
    });

    test('profile-avatars is public-read', () {
      expect(
        StorageBucketVisibilities.profileAvatars,
        isTrue,
        reason: 'profile-avatars must be public-read per 20260830100001',
      );
    });

    test('portfolio-items is public-read', () {
      expect(
        StorageBucketVisibilities.portfolioItems,
        isTrue,
        reason: 'portfolio-items must be public-read per 20260830100001',
      );
    });

    test('credential-documents: 10 MiB, jpeg/png/webp/pdf', () {
      expect(StorageLimits.credentialDocuments, 10485760);
      expect(StorageMimeTypes.credentialDocuments, <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
      });
    });

    test('profile-avatars: 5 MiB, jpeg/png/webp (no pdf)', () {
      expect(StorageLimits.profileAvatars, 5242880);
      expect(StorageMimeTypes.profileAvatars, <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
      });
      expect(
        StorageMimeTypes.profileAvatars.contains('application/pdf'),
        isFalse,
        reason: 'profile-avatars must not allow PDF',
      );
    });

    test('portfolio-items: 10 MiB, jpeg/png/webp/pdf', () {
      expect(StorageLimits.portfolioItems, 10485760);
      expect(StorageMimeTypes.portfolioItems, <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
      });
    });

    test('all expected buckets are registered', () {
      expect(StorageBuckets.all, <String>{
        'credential-documents',
        'profile-avatars',
        'portfolio-items',
      });
    });

    test('StorageLimits.forBucket returns correct limits', () {
      expect(StorageLimits.forBucket('credential-documents'), 10485760);
      expect(StorageLimits.forBucket('profile-avatars'), 5242880);
      expect(StorageLimits.forBucket('portfolio-items'), 10485760);
      expect(StorageLimits.forBucket('unknown-bucket'), isNull);
    });

    test('StorageMimeTypes.forBucket returns correct sets', () {
      expect(StorageMimeTypes.forBucket('credential-documents'), hasLength(4));
      expect(StorageMimeTypes.forBucket('profile-avatars'), hasLength(3));
      expect(StorageMimeTypes.forBucket('portfolio-items'), hasLength(4));
      expect(StorageMimeTypes.forBucket('unknown-bucket'), isNull);
    });

    test('StorageBucketVisibilities.forBucket returns correct flags', () {
      expect(
        StorageBucketVisibilities.forBucket('credential-documents'),
        isFalse,
      );
      expect(StorageBucketVisibilities.forBucket('profile-avatars'), isTrue);
      expect(StorageBucketVisibilities.forBucket('portfolio-items'), isTrue);
      expect(StorageBucketVisibilities.forBucket('unknown-bucket'), isNull);
    });
  });
}
