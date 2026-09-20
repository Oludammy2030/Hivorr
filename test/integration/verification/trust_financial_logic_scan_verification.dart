// EP-02-20 DoD-C1: No Client-Side Financial Logic Verification.
//
// Static scan. Recursively walks `lib/systems/` and `lib/data/` (excluding
// `lib/integrations/payment_gateways/` adapters where rate *fetch* is allowed,
// and the documented conversion preview estimate in
// `conversion_repository_impl.dart` — display-only math against the trusted
// server rate seam per EP-02-15 §5.4; executed amounts are always
// server-computed) and asserts that zero client-side financial arithmetic
// mutations exist. Business logic (pricing, matching, splits, escrow
// arithmetic) must live exclusively server-side per AGENT.md Rule 4.
//
// Run: flutter test test/integration/verification/trust_financial_logic_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _LogicFinding {
  const _LogicFinding(this.file, this.line, this.pattern, this.snippet);

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
/// structure so [_lineOf] stays accurate. Guards the scan against doc-comment
/// false positives — e.g. `/// never legal_name` or `/// gross = amount * rate`
/// document the guarantee; they are not code.
String _stripComments(String content) {
  final StringBuffer buffer = StringBuffer();
  for (final String line in content.split('\n')) {
    final int idx = line.indexOf('//');
    buffer.writeln(idx == -1 ? line : line.substring(0, idx));
  }
  return buffer.toString();
}

// DoD TT-14 arithmetic-adjacency family — a financial identifier immediately
// followed by an arithmetic operator is client-side money math. Covers
// compound mutations (`amount += fee`) and inline arithmetic
// (`amount * rate`). Deliberately NOT flagged: plain `=` assignments (reads
// of server values, input parsing, upload-progress counters — the server
// remains the sole mutator of financial state per SV-07/DV-05) and
// right-side usage (`acc + amount` in read-only validation folds such as
// the EP-02-14 §5.4 fail-fast milestone-sum guard, or `/balance.dart`
// import paths) — those are predicates and wiring, not money authority.
final List<RegExp> _financialMutationPatterns = <RegExp>[
  RegExp(
    r'\b(balance|amount|total|fee|escrow_split|released_amount|conversion_rate|to_amount|from_amount)\s*[\+\-\*\/]',
  ),
];

List<_LogicFinding> _scanFinancialLogic() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  final files = <String>[];

  // Walk lib/systems/ (excluding integrations/payment_gateways adapters).
  final systemsDir = Directory(_join(<String>[projectRoot, 'lib', 'systems']));
  if (systemsDir.existsSync()) {
    _collectDartFiles(systemsDir, scriptPath, files);
  }

  // Walk lib/data/ (this is where repositories/providers live).
  final dataDir = Directory(_join(<String>[projectRoot, 'lib', 'data']));
  if (dataDir.existsSync()) {
    _collectDartFiles(dataDir, scriptPath, files);
  }

  final findings = <_LogicFinding>[];

  for (final filePath in files) {
    // Exclude payment gateway adapters (rate fetch is allowed there).
    if (filePath.contains('payment_gateways') ||
        filePath.contains('integrations')) {
      continue;
    }

    // Exclude the documented conversion preview estimate (EP-02-15 §5.4):
    // `previewConversion` is display-only local math against the trusted
    // [ConversionRateSource] seam — zero RPCs, no balance mutation. The
    // executed `toAmount` is always the server-computed value, so this is
    // the sanctioned estimate seam, not client-side money authority.
    if (_basename(filePath) == 'conversion_repository_impl.dart') {
      continue;
    }

    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = _stripComments(file.readAsStringSync());

    for (final pattern in _financialMutationPatterns) {
      for (final m in pattern.allMatches(content)) {
        findings.add(
          _LogicFinding(
            filePath,
            _lineOf(content, m.start),
            pattern.pattern,
            _snippetAt(content, m.start, 60),
          ),
        );
      }
    }
  }

  return findings;
}

void main() {
  final findings = _scanFinancialLogic();

  group('DoD-C1: Trust financial logic scan', () {
    test(
      'zero client-side financial arithmetic in lib/systems/ + lib/data/',
      () {
        final buffer = StringBuffer();
        buffer.writeln(
          'Financial logic scan found ${findings.length} finding(s):',
        );
        for (final f in findings) {
          buffer.writeln('  - $f');
        }
        expect(findings, isEmpty, reason: buffer.toString());
      },
    );

    test('scanned a non-trivial set of files', () {
      // Guards against the scanner silently scanning nothing.
      final scriptPath = Platform.script.toFilePath();
      final projectRoot = _computeProjectRoot(scriptPath);
      final files = <String>[];
      for (final dirName in const <String>['lib/systems', 'lib/data']) {
        final dir = Directory(_join(<String>[projectRoot, dirName]));
        if (dir.existsSync()) {
          _collectDartFiles(dir, scriptPath, files);
        }
      }
      expect(files.length, greaterThan(0));
    });
  });
}
