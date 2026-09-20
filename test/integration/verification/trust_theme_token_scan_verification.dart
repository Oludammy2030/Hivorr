// EP-02-20 DoD-C3: Design Token Scan Verification (Rule 5).
//
// Static scan. Walks all Dart files under `lib/systems/{onboarding,
// verification, finance, support, portfolio}/` and asserts:
//  1. No `Colors.*` usage (must use Theme.of(context).colorScheme).
//  2. No `Color(0xFF` hex literals (must use theme/AppThemeExtension).
//  3. No `fontFamily:` hardcoded strings (must use textTheme).
//
// Run: flutter test test/integration/verification/trust_theme_token_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _TokenFinding {
  const _TokenFinding(this.file, this.line, this.pattern, this.snippet);

  final String file;
  final int line;
  final String pattern;
  final String snippet;

  @override
  String toString() => '${_relative(file)}:$line [$pattern] $snippet';
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

// Patterns that violate AGENT.md Rule 5 (hardcoded colors / fonts).
final List<(RegExp, String)> _tokenPatterns = <(RegExp, String)>[
  (RegExp(r'Colors\.\w+'), 'Colors.*'),
  (RegExp(r'Color\(0xFF[0-9A-Fa-f]{6}\)'), 'Color(0xFF...)'),
  (RegExp(r'''fontFamily:\s*['"]'''), 'fontFamily:'),
];

void main() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  // Collect Dart files in the 5 trust-system directories.
  final trustDirs = <String>[
    'lib/systems/onboarding',
    'lib/systems/verification',
    'lib/systems/finance',
    'lib/systems/support',
    'lib/systems/portfolio',
  ];

  final files = <String>[];
  for (final dirName in trustDirs) {
    final dir = Directory(_join(projectRoot, dirName));
    if (dir.existsSync()) {
      _collectDartFiles(dir, scriptPath, files);
    }
  }

  // Scan.
  final findings = <_TokenFinding>[];
  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();

    for (final (pattern, label) in _tokenPatterns) {
      for (final m in pattern.allMatches(content)) {
        findings.add(
          _TokenFinding(
            filePath,
            _lineOf(content, m.start),
            label,
            _snippetAt(content, m.start, 60),
          ),
        );
      }
    }
  }

  group('DoD-C3: Design token scan (Rule 5)', () {
    test(
      'no Colors.*, Color(0xFF...), fontFamily: in trust system widgets',
      () {
        final buffer = StringBuffer();
        buffer.writeln('Theme token scan found ${findings.length} finding(s):');
        for (final f in findings) {
          buffer.writeln('  - $f');
        }
        expect(findings, isEmpty, reason: buffer.toString());
      },
    );

    test('scanned a non-trivial set of trust system files', () {
      expect(
        files.length,
        greaterThan(0),
        reason: 'must scan at least one trust-system dart file',
      );
    });
  });
}
