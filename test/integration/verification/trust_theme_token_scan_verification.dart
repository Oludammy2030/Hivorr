// Design Token Scan Verification (AGENT.md Rule 5).
//
// Static scan. Walks ALL Dart files under `lib/` and asserts the token rules
// from `documents/Context/VISUAL-IDENTITY.md` + `FLUTTER-UI-IMPLEMENTATION-
// RULES.md` hold outside the documented exceptions below:
//
//  1. No `Colors.*` (must use Theme/ColorScheme) — except `Colors.transparent`
//     (sanctioned unselected/overlay layer, §27) and the per-file allowlist.
//  2. No `Color(0xFF...)` hex literals (must use theme/AppThemeExtension).
//  3. No `fontFamily:` hardcoded strings (must use TextTheme).
//  4. No per-widget `fontSize:` (§6 scale mapping instead).
//  5. No `FontWeight.w800` in functional UI (§6a landing-display exception).
//
// `lib/app/theme/` is excluded throughout: it DEFINES the tokens.
// Grandfathered files below carry pre-scan violations with a reason; they may
// only shrink. Any finding outside this allowlist — including any NEW file
// with a finding — fails the suite.
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

// NOTE: `(?<![A-Za-z])` keeps `AppColors.*` (token definitions/reads) from
// matching the `Colors.*` rule.
final List<(RegExp, String)> _tokenPatterns = <(RegExp, String)>[
  (RegExp(r'(?<![A-Za-z])Colors\.\w+'), 'Colors.*'),
  (RegExp(r'Color\(0xFF[0-9A-Fa-f]{6}\)'), 'Color(0xFF...)'),
  (RegExp(r'''fontFamily:\s*['"]'''), 'fontFamily:'),
  (RegExp(r'fontSize:'), 'fontSize:'),
  (RegExp(r'FontWeight\.w800'), 'FontWeight.w800'),
];

/// Directories that define tokens (never scanned).
bool _isExcluded(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  return normalized.startsWith('lib/app/theme/');
}

/// Globally sanctioned literals (§27): transparent unselected/overlay layers.
bool _isGloballyAllowed(String snippet) =>
    snippet.startsWith('Colors.transparent');

/// Grandfathered files: pre-scan violations with a reason. New files must be
/// clean; entries here may only shrink (shrinkage is verified by review, not
/// by count — do not add new violations to these files).
const Map<String, Map<String, String>> _fileAllow = <String, Map<String, String>>{
  'lib/app/auth/screens/login_screen.dart': <String, String>{
    'Colors.*': 'pixel-matched log in.png reference, white-on-brand (§2)',
    'Color(0xFF...)':
        'reference page/field fills (#F7F7F4, #FFF2F4F7, #E5E7EB)',
    'fontSize:': 'reference marketing type (shares §6a exception)',
    'FontWeight.w800': 'marketing display (§6a, documented at call sites)',
  },
  'lib/app/auth/screens/auth_scaffold.dart': <String, String>{
    'Colors.*': 'brand-panel white-on-brand (§2)',
  },
  'lib/shared/components/hivorr_hero_panel.dart': <String, String>{
    'Colors.*': 'white-on-gradient hero actions (§2)',
  },
  'lib/systems/dashboard/widgets/overview_display_widgets.dart':
      <String, String>{
    'Colors.*': 'white-on-gradient hero tiles (§2)',
  },
  'lib/app/widgets/logo_variants.dart': <String, String>{
    'Colors.*': 'monochrome default (tintable white)',
  },
  'lib/systems/dashboard/shell/dashboard_sidebar.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
    'fontSize:': 'grandfathered — migrate per-feature',
    'FontWeight.w800': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/shell/dashboard_more_sheet.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
    'FontWeight.w800': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/widgets/dashboard_cards.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
    'fontSize:': 'grandfathered — migrate per-feature',
    'FontWeight.w800': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/opportunities_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
    'Color(0xFF...)': 'grandfathered — migrate per-feature',
    'fontSize:': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/finance_hubs_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/dashboard_overview_screen.dart':
      <String, String>{
    'Colors.*': 'reference rows + white-on-gradient heroes — migrate rows',
    'Color(0xFF...)': 'reference rows — migrate per-feature',
  },
  'lib/systems/dashboard/screens/profile_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
    'Color(0xFF...)':
        'grandfathered — includes off-palette #DB2777, needs design review',
  },
  'lib/systems/dashboard/screens/hires_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/job_form_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/my_jobs_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
  'lib/systems/dashboard/screens/messages_screen.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
  'lib/systems/admin/widgets/super_admin_sidebar.dart': <String, String>{
    'Colors.*': 'grandfathered — migrate per-feature',
  },
};

void main() {
  final scriptPath = Platform.script.toFilePath();
  final projectRoot = _computeProjectRoot(scriptPath);

  final files = <String>[];
  final libDir = Directory(_join(projectRoot, 'lib'));
  if (libDir.existsSync()) {
    _collectDartFiles(libDir, scriptPath, files);
  }

  // Scan.
  final findings = <_TokenFinding>[];
  final allowed = <_TokenFinding>[];
  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final relative = _relative(filePath).replaceAll('\\', '/');
    if (_isExcluded(relative)) continue;
    final content = file.readAsStringSync();

    for (final (pattern, label) in _tokenPatterns) {
      for (final m in pattern.allMatches(content)) {
        final snippet = _snippetAt(content, m.start, 60);
        final finding = _TokenFinding(
          filePath,
          _lineOf(content, m.start),
          label,
          snippet,
        );
        if (_isGloballyAllowed(snippet)) continue;
        if ((_fileAllow[relative]?[label]) != null) {
          allowed.add(finding);
          continue;
        }
        findings.add(finding);
      }
    }
  }

  group('Design token scan (Rule 5, all of lib/)', () {
    test('no token violations outside the documented allowlist', () {
      final buffer = StringBuffer();
      buffer.writeln('Theme token scan found ${findings.length} finding(s):');
      for (final f in findings) {
        buffer.writeln('  - $f');
      }
      expect(findings, isEmpty, reason: buffer.toString());
    });

    test('scanned a non-trivial set of lib files', () {
      expect(
        files.length,
        greaterThan(100),
        reason: 'must scan substantially all of lib/',
      );
    });
  });
}
