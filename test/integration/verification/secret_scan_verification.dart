// EP-01-20 Validation Point 10 (§5.12): No Hardcoded Secrets Verification.
//
// Static analysis secret scan. Recursively walks `lib/`, `test/`, and top-level
// config files from the computed project root and asserts that zero genuine
// hardcoded secrets are present. Patterns are intentionally conservative so they
// do not false-positive on the placeholder values the codebase legitimately uses
// (e.g. `example.supabase.co`, `test.example.com`, `fake-access-token`).
//
// Run: flutter test test/integration/verification/secret_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A single secret finding with enough context to triage.
class SecretFinding {
  const SecretFinding(this.category, this.file, this.line, this.snippet);

  final String category;
  final String file;
  final int line;
  final String snippet;

  @override
  String toString() => '$category | ${_relative(file)}:$line | $snippet';
}

/// Result of a full codebase scan, bucketed by category.
class ScanResult {
  const ScanResult(
    this.privateKeys,
    this.supabaseUrls,
    this.jwts,
    this.secretAssignments,
    this.scannedFileCount,
  );

  final List<SecretFinding> privateKeys;
  final List<SecretFinding> supabaseUrls;
  final List<SecretFinding> jwts;
  final List<SecretFinding> secretAssignments;
  final int scannedFileCount;
}

const List<String> _placeholderSupabaseHosts = <String>[
  'example.supabase.co',
  'dev.hivorr.supabase.co',
  'staging.hivorr.supabase.co',
  'prod.hivorr.supabase.co',
  'your-project.supabase.co',
  'YOURPROJECT.supabase.co',
  'super-secret.supabase.co',
  'secret.supabase.co',
  'dev-abc1234.supabase.co',
  'staging-def5678.supabase.co',
  'prod-ghi9012.supabase.co',
];

// ----- Patterns (conservative, high-signal only) -----

// Private key blocks.
final RegExp _privateKeyPattern = RegExp(r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----');

// Real Supabase project URLs. A genuine Supabase project reference is exactly a
// 20-character lowercase alphanumeric subdomain. Placeholder hosts (example,
// dev.hivorr, etc.) never satisfy this, so they are never flagged.
final RegExp _supabaseUrlPattern = RegExp(r'https?://([a-z0-9]{20})\.supabase\.co');

// JWTs: three base64url segments, each at least 16 chars, with the first two
// starting with `eyJ`. Placeholder fakes like `eyJhbGciOi.eyJzdWIi.signed`
// (short segments) do not match.
final RegExp _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}',
);

// Secret-bearing variable/field assigned a string literal.
final RegExp _secretAssignmentPattern = RegExp(
  r'''\b(apiKey|api_key|secret|clientSecret|privateKey|private_key|password|'''
  r'''accessToken|authToken|token)\b\s*[:=]\s*['"]([^'"]+)['"]''',
  caseSensitive: false,
);

// A literal value that looks like a genuine secret (strong provider prefixes or
// a long high-entropy alphanumeric string).
final RegExp _realSecretValue = RegExp(
  r'^(AIza[0-9A-Za-z_\-]{16,}|'
  r'sk-[A-Za-z0-9]{16,}|'
  r'pk_[A-Za-z0-9]{16,}|'
  r'AKIA[0-9A-Z]{12,}|'
  r'gh[pousr]_[A-Za-z0-9]{16,}|'
  r'xox[baprs]-[A-Za-z0-9\-]{10,}|'
  r'glpat-[A-Za-z0-9_\-]{16,}|'
  r'eyJ[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}|'
  r'[A-Za-z0-9+/=_\-]{32,})$',
);

// Top-level config files to additionally scan.
final RegExp _configFilePattern = RegExp(
  r'^(\.env(\..*)?|.*\.(ya?ml|json|properties|ini|toml|cfg))$',
);

final ScanResult _scanResult = _scanCodebase();

String _relative(String path) {
  final root = _computeProjectRoot(Platform.script.toFilePath());
  if (path.startsWith(root)) {
    return path.substring(root.length).replaceAll(RegExp(r'^[\\/]'), '');
  }
  return path;
}

String _basename(String path) {
  final normalized =
      path.endsWith(Platform.pathSeparator) ? path.substring(0, path.length - 1) : path;
  final idx = normalized.lastIndexOf(Platform.pathSeparator);
  return idx == -1 ? normalized : normalized.substring(idx + 1);
}

String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

String _computeProjectRoot(String scriptPath) {
  var dir = Directory(File(scriptPath).parent.path);
  while (true) {
    final parent = Directory(dir.parent.path);
    if (parent.path == dir.path) break; // filesystem root
    if (_basename(dir.path) == 'test') {
      return parent.path;
    }
    dir = parent;
  }
  // Fallback: assume CWD is project root.
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
  final end = (start + length) > content.length ? content.length : start + length;
  return content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
}

ScanResult _scanCodebase() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  final files = <String>[];
  for (final dirName in const <String>['lib', 'test']) {
    final dir = Directory(_join(projectRoot, dirName));
    if (dir.existsSync()) {
      _collectDartFiles(dir, scriptPath, files);
    }
  }
  final rootDir = Directory(projectRoot);
  if (rootDir.existsSync()) {
    for (final entity in rootDir.listSync()) {
      if (entity is File) {
        if (entity.path == scriptPath) continue;
        if (_configFilePattern.hasMatch(_basename(entity.path))) {
          files.add(entity.path);
        }
      }
    }
  }

  final privateKeys = <SecretFinding>[];
  final supabaseUrls = <SecretFinding>[];
  final jwts = <SecretFinding>[];
  final secretAssignments = <SecretFinding>[];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();

    for (final m in _privateKeyPattern.allMatches(content)) {
      privateKeys.add(SecretFinding(
        'private-key',
        filePath,
        _lineOf(content, m.start),
        _snippetAt(content, m.start, 40),
      ));
    }

    for (final m in _supabaseUrlPattern.allMatches(content)) {
      final host = m.group(1);
      if (host != null && _placeholderSupabaseHosts.contains('$host.supabase.co')) {
        continue;
      }
      supabaseUrls.add(SecretFinding(
        'supabase-url',
        filePath,
        _lineOf(content, m.start),
        _snippetAt(content, m.start, 60),
      ));
    }

    for (final m in _jwtPattern.allMatches(content)) {
      jwts.add(SecretFinding(
        'jwt',
        filePath,
        _lineOf(content, m.start),
        _snippetAt(content, m.start, 60),
      ));
    }

    for (final m in _secretAssignmentPattern.allMatches(content)) {
      final literal = m.group(2);
      if (literal == null) continue;
      if (!_realSecretValue.hasMatch(literal)) continue;
      secretAssignments.add(SecretFinding(
        'secret-assignment',
        filePath,
        _lineOf(content, m.start),
        _snippetAt(content, m.start, 80),
      ));
    }
  }

  return ScanResult(
    privateKeys,
    supabaseUrls,
    jwts,
    secretAssignments,
    files.length,
  );
}

String _reason(String category, List<SecretFinding> findings) {
  final buffer = StringBuffer();
  buffer.writeln('Secret scan found ${findings.length} $category finding(s):');
  for (final f in findings) {
    buffer.writeln('  - $f');
  }
  return buffer.toString();
}

void main() {
  group('Secret scan (Validation Point 10)', () {
    test('no private key blocks', () {
      expect(
        _scanResult.privateKeys,
        isEmpty,
        reason: _reason('private-key', _scanResult.privateKeys),
      );
    });

    test('no real supabase project urls', () {
      expect(
        _scanResult.supabaseUrls,
        isEmpty,
        reason: _reason('supabase-url', _scanResult.supabaseUrls),
      );
    });

    test('no JWTs', () {
      expect(
        _scanResult.jwts,
        isEmpty,
        reason: _reason('jwt', _scanResult.jwts),
      );
    });

    test('no secret assignments', () {
      expect(
        _scanResult.secretAssignments,
        isEmpty,
        reason: _reason('secret-assignment', _scanResult.secretAssignments),
      );
    });

    test('scanned a non-trivial set of files', () {
      // Guards against the scanner silently scanning nothing.
      expect(_scanResult.scannedFileCount, greaterThan(0));
    });
  });
}
