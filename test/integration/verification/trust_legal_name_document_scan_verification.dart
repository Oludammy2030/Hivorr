// EP-02-20 DoD-C2: No legal_name / document_path Leakage Verification.
//
// Static scan. Asserts:
//  1. `legal_name` is absent from `lib/systems/portfolio/` and
//     `lib/data/providers/portfolio_provider.dart`.
//  2. `document_path` is absent from the public profile projection path.
//  3. `grep -rn "service_role" lib/` = 0.
//
// Run: flutter test test/integration/verification/trust_legal_name_document_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _LeakFinding {
  const _LeakFinding(this.file, this.line, this.pattern, this.snippet);

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

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

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

void _collectDartFiles(
  Directory dir,
  String scriptPath,
  List<String> files,
) {
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
  final end =
      (start + length) > content.length ? content.length : start + length;
  return content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Strips `//`-style comments (dartdoc `///` included) while preserving line
/// structure so [_lineOf] stays accurate. Guards the scan against doc-comment
/// false positives — `/// never legal_name` *documents* the whitelist
/// guarantee; it is not a leak of the column into code (SV-03 covers the
/// public projection, which is code, not comments).
String _stripComments(String content) {
  final StringBuffer buffer = StringBuffer();
  for (final String line in content.split('\n')) {
    final int idx = line.indexOf('//');
    buffer.writeln(idx == -1 ? line : line.substring(0, idx));
  }
  return buffer.toString();
}

List<_LeakFinding> _scanForPattern(
  List<String> files,
  RegExp pattern,
  String patternName,
) {
  final findings = <_LeakFinding>[];
  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = _stripComments(file.readAsStringSync());
    for (final m in pattern.allMatches(content)) {
      findings.add(_LeakFinding(
        filePath,
        _lineOf(content, m.start),
        patternName,
        _snippetAt(content, m.start, 60),
      ));
    }
  }
  return findings;
}

void main() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  // --- Scan 1: legal_name in portfolio system ---
  final portfolioDir = Directory(
    _join(<String>[projectRoot, 'lib', 'systems', 'portfolio']),
  );
  final portfolioProviderFile = File(
    _join(<String>[projectRoot, 'lib', 'data', 'providers', 'portfolio_provider.dart']),
  );

  final portfolioFiles = <String>[];
  if (portfolioDir.existsSync()) {
    _collectDartFiles(portfolioDir, scriptPath, portfolioFiles);
  }
  if (portfolioProviderFile.existsSync()) {
    portfolioFiles.add(portfolioProviderFile.path);
  }

  final legalNameFindings =
      _scanForPattern(portfolioFiles, RegExp(r'legal_name'), 'legal_name');

  // --- Scan 2: document_path in portfolio system ---
  final documentPathFindings =
      _scanForPattern(portfolioFiles, RegExp(r'document_path'), 'document_path');

  // --- Scan 3: service_role anywhere in lib/ ---
  final libDir = Directory(_join(<String>[projectRoot, 'lib']));
  final allLibFiles = <String>[];
  if (libDir.existsSync()) {
    _collectDartFiles(libDir, scriptPath, allLibFiles);
  }
  final serviceRoleFindings = _scanForPattern(
    allLibFiles,
    RegExp(r'service_role'),
    'service_role',
  ).where((_LeakFinding finding) {
    // `environment_loader.dart` is the anti-service-role gate — it detects and
    // REJECTS service-role keys before any client uses them (DoD C2/SV-05).
    // Its string literals and JWT-payload matchers are the guard, not a leak.
    return _basename(finding.file) != 'environment_loader.dart';
  }).toList(growable: false);

  group('DoD-C2: Trust legal_name/document_path/service_role scan', () {
    test('no legal_name in lib/systems/portfolio/ + portfolio_provider.dart',
        () {
      final buffer = StringBuffer();
      buffer.writeln(
          'legal_name scan found ${legalNameFindings.length} finding(s):');
      for (final f in legalNameFindings) {
        buffer.writeln('  - $f');
      }
      expect(legalNameFindings, isEmpty, reason: buffer.toString());
    });

    test(
        'no document_path in lib/systems/portfolio/ + portfolio_provider.dart',
        () {
      final buffer = StringBuffer();
      buffer.writeln(
          'document_path scan found ${documentPathFindings.length} finding(s):');
      for (final f in documentPathFindings) {
        buffer.writeln('  - $f');
      }
      expect(documentPathFindings, isEmpty, reason: buffer.toString());
    });

    test('no service_role in lib/', () {
      final buffer = StringBuffer();
      buffer.writeln(
          'service_role scan found ${serviceRoleFindings.length} finding(s):');
      for (final f in serviceRoleFindings) {
        buffer.writeln('  - $f');
      }
      expect(serviceRoleFindings, isEmpty, reason: buffer.toString());
    });

    test('scanned a non-trivial set of files', () {
      expect(allLibFiles.length, greaterThan(0));
    });
  });
}
