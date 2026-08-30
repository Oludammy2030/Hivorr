import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/core/storage/storage_paths.dart';

void main() {
  group('StoragePaths.sanitize', () {
    test('lower-cases and strips characters outside a-z0-9._-', () {
      expect(StoragePaths.sanitize('My.Resume!.PDF'), 'my.resume.pdf');
    });

    test('strips path separators forward and backslash', () {
      expect(StoragePaths.sanitize(r'a/b\c'), 'abc');
    });

    test('strips control characters', () {
      expect(StoragePaths.sanitize('ab\x00\x1fcd\u007f'), 'abcd');
    });

    test('collapses traversal payload to a single safe token', () {
      final safe = StoragePaths.sanitize('../../etc/passwd');
      expect(safe.contains('..'), isFalse);
      expect(safe.contains('/'), isFalse);
      expect(safe, isNot(contains(r'\')));
      expect(safe, matches(RegExp(r'^[a-z0-9._-]+$')));
      expect(safe, isNotEmpty);
    });

    test('truncates longer than 180 characters', () {
      final name = 'x' * 300;
      final safe = StoragePaths.sanitize(name);
      expect(safe.length, StoragePaths.maxFileNameLength);
    });

    test('empty or unusable input yields empty string', () {
      expect(StoragePaths.sanitize(''), isEmpty);
      expect(StoragePaths.sanitize('!!![][['), isEmpty);
    });
  });

  group('StoragePaths.credentialDocument', () {
    test('formats {entityId}/{submissionId}/{uuid}_{sanitized}', () {
      final path = StoragePaths.credentialDocument(
        entityId: 'user-123',
        submissionId: 'sub-ABC',
        fileName: 'Passport.Scan.pdf',
      );
      final parts = path.split('/');
      expect(parts, hasLength(3));
      expect(parts[0], 'user-123');
      expect(parts[1], 'sub-abc');
      final name = parts[2];
      final uuid = name.split('_').first;
      expect(
        uuid,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
      );
      expect(name, endsWith('passport.scan.pdf'));
    });

    test('uses the uuid only when the sanitized name is empty', () {
      final path = StoragePaths.credentialDocument(
        entityId: 'e',
        submissionId: 's',
        fileName: '!!!',
      );
      final name = path.split('/').last;
      expect(name.contains('_'), isFalse);
      expect(
        name,
        matches(RegExp(r'^[0-9a-f]{8}-' r'[0-9a-f]{4}-' r'[0-9a-f]{4}-' r'[0-9a-f]{4}-' r'[0-9a-f]{12}$')),
      );
    });

    test('rejects empty submissionId', () {
      expect(
        () => StoragePaths.credentialDocument(
          entityId: 'e',
          submissionId: '',
          fileName: 'a.pdf',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('rejects empty entityId', () {
      expect(
        () => StoragePaths.credentialDocument(
          entityId: '',
          submissionId: 's',
          fileName: 'a.pdf',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('sanitizes traversal-laden file names in the final segment', () {
      final path = StoragePaths.credentialDocument(
        entityId: 'user-1',
        submissionId: 'sub-ABC',
        fileName: '..\\..\\etc/Passwd.PDF',
      );
      final parts = path.split('/');
      final name = parts.last;
      expect(name.contains('..'), isFalse);
      expect(name.contains('/'), isFalse);
      expect(StoragePaths.sanitize('..\\..\\etc/Passwd.PDF'),
          matches(RegExp(r'^[a-z0-9._-]+$')));
      expect(parts, hasLength(3));
    });
  });

  group('StoragePaths.avatar', () {
    test('produces {entityId}/avatar.{ext}', () {
      expect(StoragePaths.avatar(entityId: 'user-1', ext: 'png'),
          'user-1/avatar.png');
    });

    test('lower-cases an uppercase extension', () {
      expect(StoragePaths.avatar(entityId: 'user-1', ext: 'JPG'),
          'user-1/avatar.jpg');
    });

    test('rejects an empty extension', () {
      expect(
        () => StoragePaths.avatar(entityId: 'user-1', ext: ''),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('rejects an entityId containing a path separator', () {
      expect(
        () => StoragePaths.avatar(entityId: 'a/b', ext: 'png'),
        throwsA(isA<StorageValidationException>()),
      );
      expect(
        () => StoragePaths.avatar(entityId: r'a\b', ext: 'png'),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('StoragePaths.portfolioItem', () {
    test('formats {entityId}/{itemId}/{sanitizedFileName}', () {
      expect(
        StoragePaths.portfolioItem(
          entityId: 'user-1',
          itemId: 'item-9',
          fileName: 'website_Mockup.png',
        ),
        'user-1/item-9/website_mockup.png',
      );
    });

    test('rejects an empty itemId', () {
      expect(
        () => StoragePaths.portfolioItem(
          entityId: 'user-1',
          itemId: '',
          fileName: 'a.png',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('rejects a file name with no usable characters', () {
      expect(
        () => StoragePaths.portfolioItem(
          entityId: 'user-1',
          itemId: 'i',
          fileName: '///',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });
}
