// EP-02-20 DoD-C5: Payment Gateway Abstraction Boundary Verification.
//
// Static scan. Asserts that no file in `lib/systems/` or `lib/data/` imports
// `paystack_gateway.dart` or `flutterwave_gateway.dart` directly — only the
// abstract `payment_gateway.dart` via `payment_gateway_factory.dart` boundary
// is allowed.
//
// Run: flutter test test/integration/verification/trust_gateway_abstraction_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _ImportFinding {
  const _ImportFinding(this.file, this.line, this.snippet);

  final String file;
  final int line;
  final String snippet;

  @override
  String toString() => '${_relative(file)}:$line | $snippet';
}

String _relative(String path) {
  final root = _computeProjectRoot(Platform.script.toFilePath());
  if (path.startsWith(root)) {
    return path.substring(root.length).replaceAll(RegExp(r'^[\\/]'), '');
  }
  return path;
}

String _basename(String path) {
  final normalized = path.endsWith(Platform.pathSeparator)
      ? path.substring(0, path.length - 1)
      : path;
  final idx = normalized.lastIndexOf(Platform.pathSeparator);
  return idx == -1 ? normalized : normalized.substring(idx + 1);
}

String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

String _computeProjectRoot(String scriptPath) {
  var dir = Directory(File(scriptPath).parent.path);
  while (true) {
    final parent = Directory(dir.parent.path);
    if (parent.path == dir.path) break;
    if (_basename(dir.path) == 'test') {
      return parent.path;
    }
    dir = parent;
  }
  return Directory.current.path;
}

void _collectDartFiles(Directory dir, String scriptPath, List<String> files) {
  for (final entity in dir.listSync()) {
    if (entity is Directory) {
      final base = _basename(entity.path);
      if (base == 'build' || base == '.dart_tool' || base == '.git') continue;
      _collectDartFiles(entity, scriptPath, files);
    } else if (entity is File) {
      if (entity.path == scriptPath) continue;
      if (entity.path.endsWith('.dart')) files.add(entity.path);
    }
  }
}

int _lineOf(String content, int index) {
  var line = 1;
  final end = index < content.length ? index : content.length;
  for (var i = 0; i < end; i++) {
    if (content.codeUnitAt(i) == 10) line++;
  }
  return line;
}

String _snippetAt(String content, int index, int length) {
  final start = index < 0 ? 0 : index;
  final end = (start + length) > content.length
      ? content.length
      : start + length;
  return content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
}

void main() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  final files = <String>[];
  for (final dirName in const <String>['lib/systems', 'lib/data']) {
    final dir = Directory(_join(projectRoot, dirName));
    if (dir.existsSync()) {
      _collectDartFiles(dir, scriptPath, files);
    }
  }

  // Pattern: import statements referencing concrete gateway implementations.
  final gatewayImportPattern = RegExp(
    r'''import\s+['"].*?(paystack_gateway|flutterwave_gateway).*?['"]''',
    caseSensitive: false,
  );

  final findings = <_ImportFinding>[];
  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    for (final m in gatewayImportPattern.allMatches(content)) {
      findings.add(
        _ImportFinding(
          filePath,
          _lineOf(content, m.start),
          _snippetAt(content, m.start, 80),
        ),
      );
    }
  }

  group('DoD-C5: Trust gateway abstraction boundary', () {
    test('no direct PaystackGateway/FlutterwaveGateway imports in '
        'lib/systems/ + lib/data/', () {
      final buffer = StringBuffer();
      buffer.writeln(
        'Gateway abstraction scan found ${findings.length} finding(s):',
      );
      for (final f in findings) {
        buffer.writeln('  - $f');
      }
      expect(findings, isEmpty, reason: buffer.toString());
    });

    test('scanned a non-trivial set of files', () {
      expect(files.length, greaterThan(0));
    });
  });
}
