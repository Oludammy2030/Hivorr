// EP-03-20: Marketplace Ranking Override Scan (plan §6.4, "New (narrow)").
//
// Static scan with three lenses:
//  1. No client re-sort of ranking/search results — walks the marketplace
//     discovery/search paths (`lib/systems/marketplace/` + the search stack:
//     provider, repositories, remote/local datasources, search index) and
//     flags any `.sort(`/`.shuffle(` on code (comment-stripped). The single
//     allowlist entry is `discovery_filter_sheet.dart`, which alphabetically
//     orders taxonomy *filter options* (industries/professions) for display —
//     it never touches result rows. Result order is decided by the server RPC
//     `service_ranking_search` and passes through verbatim (AGENT.md Rule 4 /
//     Deterministic Core; `marketplace_search_provider.dart` documents
//     "never reorders").
//  2. No ranking-formula import in those paths —
//     `lib/engine/recommendation_engine/ranking_formula.dart` (and its
//     `ranking_weights.dart` value object) must not be imported by
//     marketplace/search code. The formula belongs to the server RPC; the
//     client only *displays* `weights_version` (EP-03-06 §0). References in
//     doc comments / the `MatchingEngineSeam.boundaryNote` string are
//     documentation, not code (comments are stripped).
//  3. No `lib/ai/` (or package `hivorr/ai`) influence on ordering — the
//     directory does not exist in this repo; the scan fails closed if it
//     appears and is imported by the scanned paths.
//
// Run: flutter test test/integration/verification/marketplace_ranking_override_scan_verification.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _RankFinding {
  const _RankFinding(this.file, this.line, this.pattern, this.snippet);

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
/// structure so [_lineOf] stays accurate. Doc comments legitimately *mention*
/// the ranking formula and `service_ranking_weights` — they document the
/// server-owned boundary; they are not code.
String _stripComments(String content) {
  final StringBuffer buffer = StringBuffer();
  for (final String line in content.split('\n')) {
    final int idx = line.indexOf('//');
    buffer.writeln(idx == -1 ? line : line.substring(0, idx));
  }
  return buffer.toString();
}

/// Files whose only sorts are taxonomy filter-option display orders
/// (industries/professions alphabetical for the filter sheet UI). Exempt from
/// the no-re-sort lens: they order *options*, never ranked result rows.
const Set<String> _taxonomySortAllowlist = <String>{
  'discovery_filter_sheet.dart',
};

/// The EP-03 marketplace discovery/search paths whose contents must pass
/// server order through verbatim.
List<String> _rankingScopeFiles(String root, String scriptPath) {
  final files = <String>[];

  // Marketplace system (screens, widgets, services, DI).
  final marketplaceDir = Directory(
    _join(<String>[root, 'lib', 'systems', 'marketplace']),
  );
  if (marketplaceDir.existsSync()) {
    _collectDartFiles(marketplaceDir, scriptPath, files);
  }

  // The ranked-search stack (provider → repository → datasources → index).
  const searchStack = <String>[
    'lib/data/providers/marketplace_search_provider.dart',
    'lib/data/repositories/service_search_repository.dart',
    'lib/data/repositories/service_search_repository_impl.dart',
    'lib/data/datasources/remote/service_search_remote_data_source.dart',
    'lib/data/datasources/remote/service_search_envelope_parser.dart',
    'lib/data/datasources/local/service_search_local_data_source.dart',
    'lib/data/datasources/local/hive_service_search_local_data_source.dart',
    'lib/engine/search_engine/service_search_index.dart',
  ];
  for (final relative in searchStack) {
    final file = File(_join(<String>[root, ...relative.split('/')]));
    if (file.existsSync()) files.add(file.path);
  }
  return files;
}

List<_RankFinding> _scanFiles(
  List<String> files, {
  required RegExp pattern,
  required String patternName,
  bool Function(String path)? exempt,
}) {
  final findings = <_RankFinding>[];
  for (final filePath in files) {
    if (exempt != null && exempt(filePath)) continue;
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = _stripComments(file.readAsStringSync());
    for (final m in pattern.allMatches(content)) {
      findings.add(
        _RankFinding(
          filePath,
          _lineOf(content, m.start),
          patternName,
          _snippetAt(content, m.start, 70),
        ),
      );
    }
  }
  return findings;
}

void main() {
  final scriptPath = Platform.script.toFilePath();
  final root = _computeProjectRoot(scriptPath);
  final files = _rankingScopeFiles(root, scriptPath);

  // Lens 1: client re-sort of result rows. `.sort(` / `..sort(` / `.shuffle(`
  // anywhere in the discovery/search paths (taxonomy display sort allowlisted).
  final reSortFindings = _scanFiles(
    files,
    pattern: RegExp(r'\.\.?sort\s*\(|\.shuffle\s*\('),
    patternName: 'client-re-sort',
    exempt: (String path) => _taxonomySortAllowlist.contains(_basename(path)),
  );

  // Lens 2: ranking-formula imports in those paths (code only — comments
  // stripped, and the seam note lives in a string literal outside scope).
  final formulaImportFindings = _scanFiles(
    files,
    pattern: RegExp(
      r"import\s+.*(ranking_formula|ranking_weights|recommendation_engine)",
    ),
    patternName: 'ranking-formula-import',
  );

  // Lens 3: `lib/ai/` (or package `hivorr/ai`) imported by ordering paths.
  final aiFindings = _scanFiles(
    files,
    pattern: RegExp(r"import\s+.*(lib/ai/|package:hivorr/ai/)"),
    patternName: 'lib-ai-ordering-influence',
  );

  void expectNone(List<_RankFinding> findings, String lens) {
    final buffer = StringBuffer();
    buffer.writeln('$lens found ${findings.length} finding(s):');
    for (final f in findings) {
      buffer.writeln('  $f');
    }
    expect(findings, isEmpty, reason: buffer.toString());
  }

  group('EP-03-20: marketplace ranking override scan', () {
    test('scope covers the discovery/search paths', () {
      expect(files, isNotEmpty);
      expect(
        files.any((String p) => p.contains('marketplace_search_provider')),
        isTrue,
        reason: 'provider must be in scope',
      );
      expect(
        files.any((String p) => p.endsWith('discovery_results_view.dart')),
        isTrue,
        reason: 'discovery results renderer must be in scope',
      );
    });

    test('no client re-sort/shuffle of ranking results (order passes through '
        'verbatim; taxonomy filter-option sort allowlisted)', () {
      expectNone(reSortFindings, 'client re-sort lens');
    });

    test('no ranking-formula/ranking-weights import in discovery/search '
        'paths (server RPC owns ordering)', () {
      expectNone(formulaImportFindings, 'ranking-formula import lens');
    });

    test('no lib/ai/ influence on ordering', () {
      expectNone(aiFindings, 'lib/ai ordering-influence lens');
    });

    test('aggregate: zero ranking-override findings', () {
      final total =
          reSortFindings.length +
          formulaImportFindings.length +
          aiFindings.length;
      expect(
        total,
        0,
        reason:
            'EP-03-06 §0: AI does not override result order — '
            're-sort=${reSortFindings.length}, '
            'formulaImport=${formulaImportFindings.length}, '
            'ai=${aiFindings.length}',
      );
    });
  });
}
