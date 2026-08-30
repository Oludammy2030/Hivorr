import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/core/storage/storage_validators.dart';

void main() {
  group('StorageValidators.validateMime', () {
    test('credential-documents accepts all 4 allowed MIME types', () {
      for (final mime in const <String>[
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
      ]) {
        expect(
          () => StorageValidators.validateMime(
            StorageBuckets.credentialDocuments,
            mime,
          ),
          returnsNormally,
          reason: mime,
        );
      }
    });

    test('profile-avatars accepts only the 3 image MIME types', () {
      for (final mime in const <String>[
        'image/jpeg',
        'image/png',
        'image/webp',
      ]) {
        expect(
          () => StorageValidators.validateMime(
            StorageBuckets.profileAvatars,
            mime,
          ),
          returnsNormally,
          reason: mime,
        );
      }
    });

    test('profile-avatars rejects application/pdf (allowed elsewhere)', () {
      final error = _captureValidation(
        () => StorageValidators.validateMime(
          StorageBuckets.profileAvatars,
          'application/pdf',
        ),
      );
      expect(error.field, 'mimeType');
      expect(error.message, contains('Avatars'));
    });

    test('portfolio-items accepts pdf', () {
      expect(
        () => StorageValidators.validateMime(
          StorageBuckets.portfolioItems,
          'application/pdf',
        ),
        returnsNormally,
      );
    });

    test('MIME matching is case-insensitive', () {
      expect(
        () => StorageValidators.validateMime(
          StorageBuckets.credentialDocuments,
          'IMAGE/JPEG',
        ),
        returnsNormally,
      );
      expect(
        () => StorageValidators.validateMime(
          StorageBuckets.profileAvatars,
          'IMAGE/Png ',
        ),
        returnsNormally,
      );
    });

    test('rejects text/html before network', () {
      final error = _captureValidation(
        () => StorageValidators.validateMime(
          StorageBuckets.credentialDocuments,
          'text/html',
        ),
      );
      expect(error.code, 'PLT003');
      expect(error.kind, ApiExceptionKind.validation);
    });

    test('rejects application/octet-stream before network', () {
      final error = _captureValidation(
        () => StorageValidators.validateMime(
          StorageBuckets.credentialDocuments,
          'application/octet-stream',
        ),
      );
      expect(error.code, 'PLT003');
      expect(error.message, contains('not supported'));
    });

    test('rejects application/x-msdownload before network', () {
      expect(
        () => StorageValidators.validateMime(
          StorageBuckets.credentialDocuments,
          'application/x-msdownload',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('unknown bucket throws validation exception', () {
      final error = _captureValidation(
        () => StorageValidators.validateMime('evil-bucket', 'image/png'),
      );
      expect(error.field, 'bucket');
    });
  });

  group('StorageValidators.validateSize', () {
    test('credential-documents accepts up to 10485760 bytes', () {
      expect(
        () => StorageValidators.validateSize(
          StorageBuckets.credentialDocuments,
          StorageLimits.credentialDocuments,
        ),
        returnsNormally,
      );
    });

    test('credential-documents rejects exactly limit+1 byte', () {
      final error = _captureValidation(
        () => StorageValidators.validateSize(
          StorageBuckets.credentialDocuments,
          StorageLimits.credentialDocuments + 1,
        ),
      );
      expect(error.field, 'byteLength');
      expect(error.code, 'PLT003');
      expect(error.message, contains('File too large'));
    });

    test('profile-avatars caps at 5242880 and rejects beyond', () {
      expect(
        () => StorageValidators.validateSize(
          StorageBuckets.profileAvatars,
          StorageLimits.profileAvatars,
        ),
        returnsNormally,
      );
      expect(
        () => StorageValidators.validateSize(
          StorageBuckets.profileAvatars,
          StorageLimits.profileAvatars + 1,
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('portfolio-items caps at 10485760', () {
      expect(
        () => StorageValidators.validateSize(
          StorageBuckets.portfolioItems,
          StorageLimits.portfolioItems,
        ),
        returnsNormally,
      );
    });

    test('0-byte boundary is accepted', () {
      expect(
        () => StorageValidators.validateSize(StorageBuckets.profileAvatars, 0),
        returnsNormally,
      );
    });

    test('negative byte length is rejected', () {
      expect(
        () => StorageValidators.validateSize(StorageBuckets.profileAvatars, -1),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('unknown bucket in validateSize throws validation exception', () {
      final error = _captureValidation(
        () => StorageValidators.validateSize('evil-bucket', 1024),
      );
      expect(error.field, 'bucket');
    });
  });

  group('StorageValidators helpers', () {
    test('validateForBucket validates MIME and size together', () {
      expect(
        () => StorageValidators.validateForBucket(
          bucket: StorageBuckets.credentialDocuments,
          mimeType: 'application/pdf',
          byteLength: 4096,
        ),
        returnsNormally,
      );
    });

    test('validateForBucket surfaces MIME errors first', () {
      final error = _captureValidation(
        () => StorageValidators.validateForBucket(
          bucket: StorageBuckets.profileAvatars,
          mimeType: 'application/pdf',
          byteLength: 1024,
        ),
      );
      expect(error.kind, ApiExceptionKind.validation);
    });
  });

  group('StorageValidators MIME/extension helpers', () {
    test('mimeForFileName maps extensions case-insensitively', () {
      expect(StorageValidators.mimeForFileName('a.PDF'), 'application/pdf');
      expect(StorageValidators.mimeForFileName('b.JpG'), 'image/jpeg');
      expect(StorageValidators.mimeForFileName('noext'), isNull);
    });

    test('extensionMatchesMime compares normalized values', () {
      expect(
        StorageValidators.extensionMatchesMime('a.png', 'IMAGE/PNG'),
        isTrue,
      );
      expect(
        StorageValidators.extensionMatchesMime('a.pdf', 'image/jpeg'),
        isFalse,
      );
      expect(StorageValidators.extensionMatchesMime('noext', 'image/png'),
          isFalse);
    });

    test('isKnownBucket reflects the allowlist', () {
      expect(StorageValidators.isKnownBucket('profile-avatars'), isTrue);
      expect(StorageValidators.isKnownBucket('evil-bucket'), isFalse);
    });
  });
}

StorageValidationException _captureValidation(void Function() body) {
  try {
    body();
  } on StorageValidationException catch (error) {
    return error;
  }
  fail('Expected StorageValidationException');
}
