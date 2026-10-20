// EP-03-20: Marketplace PII / Escrow-Echo Scan (plan §6.4, "New (narrow)").
//
// Static scan over the EP-03 UI paths —
//   lib/systems/marketplace/, lib/systems/documents/, lib/systems/reviews/,
//   lib/systems/communication/, lib/systems/scheduling/,
//   lib/data/providers/earnings_provider.dart,
//   lib/data/providers/transaction_history_provider.dart
//
// asserting ZERO occurrences (comment-stripped, empty-findings assert) of:
//   1. PII column tokens: `legal_name`, `document_path`, `account_number`,
//      `service_role` — these live server-side (or in the EP-02 admin/KYC
//      seams); marketplace/contract/review/messaging/scheduling/earnings UI
//      must never read or echo them (AGENT.md Rule 3; EP-02-20 DoD-C2 lens
//      extended to EP-03 surfaces).
//   2. Escrow-amount column echoes: `escrow_amount`, `released_amount`,
//      `refunded_amount` (+ camelCase forms) — the client renders *entity*
//      figures that the mapper produced from server envelopes; raw escrow
//      ledger column names must not surface in UI paths (settlement is
//      server-computed, AGENT.md Rule 4; the sanctioned mapper read lives in
//      `lib/data/models/escrow_dto.dart`, outside this scope).
//
// Comment stripping guards against doc-comment false positives such as
// `/// never legal_name` — those document the guarantee; they are not code.
//
// Run: flutter test test/integration/verification/marketplace_pii_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _PiiFinding {
  const _PiiFinding(this.file, this.line, this.pattern, this.snippet);

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

/// Strips `//`-style comments (dartdoc `///` included) while preserving line
/// structure so [_lineOf] stays accurate.
String _stripComments(String content) {
  final StringBuffer buffer = StringBuffer();
  for (final String line in content.split('\n')) {
    final int idx = line.indexOf('//');
    buffer.writeln(idx == -1 ? line : line.substring(0, idx));
  }
  return buffer.toString();
}

/// EP-03 UI directories (plan §6.4 scope).
const List<String> _ep03UiDirs = <String>[
  'lib/systems/marketplace',
  'lib/systems/documents',
  'lib/systems/reviews',
  'lib/systems/communication',
  'lib/systems/scheduling',
];

/// EP-03 earnings providers (plan §6.4: "+ earnings provider").
const List<String> _ep03EarningsFiles = <String>[
  'lib/data/providers/earnings_provider.dart',
  'lib/data/providers/transaction_history_provider.dart',
];

/// PII column tokens that must never appear in EP-03 UI paths.
const Map<String, String> _piiPatterns = <String, String>{
  'legal_name': r'legal_name',
  'document_path': r'document_path',
  'account_number': r'account_number',
  'service_role': r'service_role',
};

/// Raw escrow ledger column/model echoes that must never surface in EP-03
/// UI paths (settlement figures arrive via entities, not raw ledger columns).
const Map<String, String> _escrowEchoPatterns = <String, String>{
  'escrow_amount': r'escrow_amount',
  'escrowAmount': r'\bescrowAmount\b',
  'released_amount': r'\breleased_amount\b',
  'releasedAmount': r'\breleasedAmount\b',
  'refunded_amount': r'\brefunded_amount\b',
  'refundedAmount': r'\brefundedAmount\b',
};

List<_PiiFinding> _scanForPattern(
  List<String> files,
  RegExp pattern,
  String patternName,
) {
  final findings = <_PiiFinding>[];
  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = _stripComments(file.readAsStringSync());
    for (final m in pattern.allMatches(content)) {
      findings.add(
        _PiiFinding(
          filePath,
          _lineOf(content, m.start),
          patternName,
          _snippetAt(content, m.start, 60),
        ),
      );
    }
  }
  return findings;
}

void _report(String lens, List<_PiiFinding> findings) {
  final buffer = StringBuffer();
  buffer.writeln('$lens found ${findings.length} finding(s):');
  for (final f in findings) {
    buffer.writeln('  $f');
  }
  expect(findings, isEmpty, reason: buffer.toString());
}

void main() {
  final scriptPath = Platform.script.toFilePath();
  final root = _computeProjectRoot(scriptPath);

  // Assemble the EP-03 UI scope: directories + earnings providers.
  final files = <String>[];
  for (final relative in _ep03UiDirs) {
    final dir = Directory(_join(<String>[root, ...relative.split('/')]));
    if (dir.existsSync()) {
      _collectDartFiles(dir, scriptPath, files);
    }
  }
  for (final relative in _ep03EarningsFiles) {
    final file = File(_join(<String>[root, ...relative.split('/')]));
    if (file.existsSync()) files.add(file.path);
  }

  group('EP-03-20: marketplace PII / escrow-echo scan', () {
    test('scope covers the EP-03 UI paths (5 dirs + 2 earnings providers)', () {
      expect(files, isNotEmpty);
      expect(
        files.any((String p) => p.contains('marketplace')),
        isTrue,
        reason: 'marketplace UI must be in scope',
      );
      expect(
        files.any((String p) => p.endsWith('earnings_provider.dart')),
        isTrue,
        reason: 'earnings provider must be in scope',
      );
      expect(
        files.any(
          (String p) => p.endsWith('transaction_history_provider.dart'),
        ),
        isTrue,
        reason: 'transaction history provider must be in scope',
      );
    });

    for (final entry in _piiPatterns.entries) {
      test('no `${entry.key}` in EP-03 UI paths (comment-stripped)', () {
        final findings = _scanForPattern(files, RegExp(entry.value), entry.key);
        _report('`${entry.key}` lens', findings);
      });
    }

    for (final entry in _escrowEchoPatterns.entries) {
      test('no raw `${entry.key}` escrow-column echo in EP-03 UI paths', () {
        final findings = _scanForPattern(files, RegExp(entry.value), entry.key);
        _report('`${entry.key}` lens', findings);
      });
    }

    test('aggregate: zero PII / escrow-echo findings in EP-03 UI paths', () {
      final all = <_PiiFinding>[];
      for (final entry in _piiPatterns.entries) {
        all.addAll(_scanForPattern(files, RegExp(entry.value), entry.key));
      }
      for (final entry in _escrowEchoPatterns.entries) {
        all.addAll(_scanForPattern(files, RegExp(entry.value), entry.key));
      }
      _report('aggregate lens', all);
    });
  });
}
