import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Structured verification of the 19 EP-01 phase completion areas.
///
/// Each area maps to a representative source directory/file under `lib/` (or
/// `test/`, `assets/`, docs, config) that must exist for the phase to be
/// considered complete. A checklist line is printed per area via `debugPrint`
/// and the suite passes only when every area is present.
///
/// Reference: `documents/Task-Implementation/EP-01/EP-01-20-Phase Integration Validation & Foundation Verification.md` §5.18.

class _ChecklistItem {
  const _ChecklistItem({
    required this.id,
    required this.title,
    required this.paths,
    required this.pass,
  });

  final String id;
  final String title;
  final List<String> paths;
  final bool pass;
}

String _findProjectRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  final separator = Platform.pathSeparator;
  while (true) {
    final marker = File('${dir.path}${separator}pubspec.yaml');
    if (marker.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return Directory.current.path;
}

bool _verifyPaths(String root, List<String> paths) {
  final separator = Platform.pathSeparator;
  for (final relative in paths) {
    final full = '$root$separator$relative';
    final dir = Directory(full);
    final file = File(full);
    if (!dir.existsSync() && !file.existsSync()) {
      return false;
    }
  }
  return true;
}

List<_ChecklistItem> _buildChecklist(String root) {
  final entries = <List<Object>>[
    <Object>[
      'EP-01-01',
      'Project Scaffold & Dependencies',
      <String>['pubspec.yaml'],
    ],
    <Object>[
      'EP-01-02',
      'Architecture & Agent Rules',
      <String>[
        'documents/Context/ARCHITECTURE.md',
        'documents/Context/AGENT.md',
      ],
    ],
    <Object>[
      'EP-01-03',
      'Environment Configuration',
      <String>['lib/config'],
    ],
    <Object>[
      'EP-01-04',
      'CI/CD Pipeline',
      <String>['.github/workflows'],
    ],
    <Object>[
      'EP-01-05',
      'Supabase RPC + RLS',
      <String>['lib/core/database', 'lib/core/api'],
    ],
    <Object>[
      'EP-01-06',
      'Universal Entity Schema',
      <String>['lib/data/entities'],
    ],
    <Object>[
      'EP-01-07',
      'Core API Layer',
      <String>['lib/core/api'],
    ],
    <Object>[
      'EP-01-08',
      'Unified Data Access',
      <String>['lib/data'],
    ],
    <Object>[
      'EP-01-09',
      'Authentication Framework',
      <String>['lib/core/authentication'],
    ],
    <Object>[
      'EP-01-10',
      'Security Infrastructure',
      <String>['lib/core/security'],
    ],
    <Object>[
      'EP-01-11',
      'Local Storage & Cache',
      <String>['lib/core/storage', 'lib/core/cache'],
    ],
    <Object>[
      'EP-01-12',
      'Offline Sync Engine',
      <String>['lib/core/sync'],
    ],
    <Object>[
      'EP-01-13',
      'Network Management',
      <String>['lib/core/network'],
    ],
    <Object>[
      'EP-01-14',
      'Monitoring & Logging',
      <String>['lib/core/monitoring', 'lib/core/logging'],
    ],
    <Object>[
      'EP-01-15',
      'App Bootstrap & Routing',
      <String>['lib/app'],
    ],
    <Object>[
      'EP-01-16',
      'Design System',
      <String>['lib/shared', 'lib/app/theme'],
    ],
    <Object>[
      'EP-01-17',
      'Localization',
      <String>['lib/core/localization', 'assets/translations'],
    ],
    <Object>[
      'EP-01-18',
      'Notifications',
      <String>['lib/core/notifications'],
    ],
    <Object>[
      'EP-01-19',
      'Test Infrastructure',
      <String>['test/support'],
    ],
  ];

  return entries.map((entry) {
    final id = entry[0] as String;
    final title = entry[1] as String;
    final paths = (entry[2] as List<String>);
    return _ChecklistItem(
      id: id,
      title: title,
      paths: paths,
      pass: _verifyPaths(root, paths),
    );
  }).toList();
}

const List<String> _requiredIntegrationFiles = <String>[
  'test/integration/auth_flow_integration_test.dart',
  'test/integration/api_rls_integration_test.dart',
  'test/integration/rpc_execution_integration_test.dart',
  'test/integration/data_flow_pipeline_integration_test.dart',
  'test/integration/offline_sync_integration_test.dart',
  'test/integration/sentry_capture_integration_test.dart',
  'test/integration/localization_integration_test.dart',
  'test/integration/design_system_integration_test.dart',
  'test/integration/environment_isolation_integration_test.dart',
  'test/integration/bootstrap_integration_test.dart',
];

final String _projectRoot = _findProjectRoot();
final List<_ChecklistItem> _checklist = _buildChecklist(_projectRoot);

void main() {
  group('EP-01 Phase Completion Checklist', () {
    for (final item in _checklist) {
      test('${item.id}: ${item.title}', () {
        debugPrint(
          '[${item.pass ? 'PASS' : 'FAIL'}] ${item.id} — ${item.title} '
          '(paths: ${item.paths.join(', ')})',
        );
        expect(
          item.pass,
          isTrue,
          reason: '${item.id} verification failed for: ${item.paths.join(', ')}',
        );
      });
    }

    test('All 19 EP-01 phase completion areas are present', () {
      final int passed = _checklist.where((c) => c.pass).length;
      final int total = _checklist.length;
      debugPrint('--- PHASE COMPLETION SUMMARY: $passed/$total areas present ---');
      expect(total, 19, reason: 'Expected exactly 19 EP-01 phase areas.');
      expect(_checklist.every((c) => c.pass), isTrue,
          reason: 'One or more EP-01 phase areas are missing.');
    });
  });

  group('EP-01-20 Integration Test Files', () {
    test('Test infrastructure (EP-01-19) present at test/support', () {
      final exists = Directory('$_projectRoot${Platform.pathSeparator}test/support')
          .existsSync();
      debugPrint('[${exists ? 'PASS' : 'FAIL'}] test/support directory present');
      expect(exists, isTrue, reason: 'test/support test infrastructure missing.');
    });

    test('All 10 EP-01-20 integration test files exist', () {
      final separator = Platform.pathSeparator;
      final List<String> missing = <String>[];
      for (final relative in _requiredIntegrationFiles) {
        final file = File('$_projectRoot$separator$relative');
        if (!file.existsSync()) {
          missing.add(relative);
        }
      }
      debugPrint(
        'Integration test files present: '
        '${_requiredIntegrationFiles.length - missing.length}/${_requiredIntegrationFiles.length}',
      );
      expect(missing, isEmpty,
          reason: 'Missing integration test files: ${missing.join(', ')}');
    });
  });
}
