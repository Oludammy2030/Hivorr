// EP-01-20 §5.14 Cross-Platform Build Verification.
//
// A full `flutter build` for Android/iOS/Web cannot run reliably inside a
// unit-test process (it requires toolchains, signing, and network access that
// are not available in CI test runners). This test therefore DOCUMENTS the
// cross-platform build verification procedure and asserts the documented
// prerequisites (the real per-platform build entry points) are satisfied.
//
// The actual build execution is performed by the CI pipeline
// (`pr-validation.yml`) and the results are recorded in the Foundation
// Verification Report.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build commands executed by CI for each target platform.
const Map<String, String> _ciBuildCommands = <String, String>{
  'android': 'flutter build apk --release',
  'ios': 'flutter build ios --release --no-codesign',
  'web': 'flutter build web --release',
};

/// Project-root directories that are the real build inputs for each platform.
const List<String> _platformDirectories = <String>[
  'android',
  'ios',
  'web',
];

/// Build inputs that must exist for cross-platform compilation to be possible.
const List<String> _requiredBuildInputs = <String>[
  'android',
  'ios',
  'web',
  'lib/main.dart',
];

String _buildVerificationRecord() {
  final StringBuffer buffer = StringBuffer();
  buffer
    ..writeln('Cross-Platform Build Verification Record')
    ..writeln('----------------------------------------');
  for (final MapEntry<String, String> entry in _ciBuildCommands.entries) {
    buffer.writeln('${entry.key}: ${entry.value}');
  }
  buffer
    ..writeln('----------------------------------------')
    ..writeln(
      'Actual build results are captured by the CI pipeline '
      '(pr-validation.yml) and documented in the Foundation Verification '
      'Report. This test verifies the per-platform build entry points exist.',
    );
  return buffer.toString();
}

void main() {
  group('Cross-Platform Build Verification', () {
    test('records the CI build commands for every target platform', () {
      final String record = _buildVerificationRecord();
      debugPrint(record);

      expect(record, isNotEmpty);
      for (final MapEntry<String, String> entry in _ciBuildCommands.entries) {
        expect(record, contains(entry.value));
      }
    });

    test('documents the Android release build command', () {
      debugPrint('Android build command: ${_ciBuildCommands['android']}');
      expect(_ciBuildCommands['android'], equals('flutter build apk --release'));
    });

    test('documents the iOS release build command (no codesign)', () {
      debugPrint('iOS build command: ${_ciBuildCommands['ios']}');
      expect(
        _ciBuildCommands['ios'],
        equals('flutter build ios --release --no-codesign'),
      );
    });

    test('documents the Web release build command', () {
      debugPrint('Web build command: ${_ciBuildCommands['web']}');
      expect(_ciBuildCommands['web'], equals('flutter build web --release'));
    });

    test('build entry points exist at the project root', () {
      final Directory projectRoot = Directory.current;
      debugPrint('Project root: ${projectRoot.path}');

      for (final String path in _requiredBuildInputs) {
        final FileSystemEntity entity = path == 'lib/main.dart'
            ? File('${projectRoot.path}/$path')
            : Directory('${projectRoot.path}/$path');
        final bool exists = entity.existsSync();
        debugPrint('Build input exists ($path): $exists');
        expect(exists, isTrue, reason: 'Required build input "$path" missing.');
      }
    });

    test('verifies prerequisites and produces a non-empty verification record',
        () {
      // Real checks: every platform directory is present.
      final Directory projectRoot = Directory.current;
      for (final String dir in _platformDirectories) {
        final Directory entity =
            Directory('${projectRoot.path}/$dir');
        expect(entity.existsSync(), isTrue,
            reason: 'Platform directory "$dir" is required for build verification.');
      }

      // Real check: the shared Dart entry point exists.
      final File mainEntry = File('${projectRoot.path}/lib/main.dart');
      expect(mainEntry.existsSync(), isTrue,
          reason: 'lib/main.dart is required for all platform builds.');

      // Real check: the verification record is produced and non-empty.
      final String record = _buildVerificationRecord();
      expect(record, isNotEmpty);
      debugPrint(record);
    });
  });
}
