// EP-03-20: EP-03 Phase Completion Checklist (plan §6.4, "New (clone of ep02_*)").
//
// Structured checklist mapping each phase §10 criterion to the evidence
// artefact (test file / scan / pgTAP SQL) that must exist for PASS.
// Mirrors `ep02_phase_completion_checklist.dart` (file-existence + evidence
// mapping, aggregate fail lists misses).
//
// Row IDs are the phase plan §10 table rows:
//   EP-03:219-239 → the 21 technical criteria (aggregate test asserts 21/21)
//   EP-03:240     → "All EP-03 items at Completed" (phase-plan audit row;
//                   excluded from the technical aggregate — status audit is
//                   owned by the project lead and recorded, with entry debts
//                   (EP-03-16 proposed, EP-03-19 unchecked) documented in the
//                   EP-03-20 verification report).
//
// Run: flutter test test/integration/verification/ep03_phase_completion_checklist.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    // EP-03:219 Service marketplace schema + trade-gate RPCs
    <Object>[
      'EP-03:219',
      'service_listings/media/favorites + RLS + trade-gated RPCs',
      <String>[
        'supabase/tests/database/023_service_marketplace_schema_posture.sql',
        'supabase/tests/database/024_service_marketplace_rpc_enforcement.sql',
        'test/integration/marketplace/trade_gate_block_integration_test.dart',
      ],
    ],
    // EP-03:220 Contract & milestone schema + state machine + escrow linkage
    <Object>[
      'EP-03:220',
      'service_contracts/contract_milestones/contract_events state machine + escrow linkage',
      <String>[
        'supabase/tests/database/025_service_contract_schema_posture.sql',
        'supabase/tests/database/026_service_contract_rpc_enforcement.sql',
        'supabase/tests/database/042_contract_escrow_linkage_posture.sql',
      ],
    ],
    // EP-03:221 Review schema + double-blind atomicity
    <Object>[
      'EP-03:221',
      'service_reviews + review_submit/review_reveal atomicity (is_revealed invariant)',
      <String>[
        'supabase/tests/database/027_service_review_schema_posture.sql',
        'supabase/tests/database/028_service_review_rpc_enforcement.sql',
        'test/integration/marketplace/double_blind_review_integration_test.dart',
      ],
    ],
    // EP-03:222 Messaging schema + Realtime publication + encryption-at-rest
    <Object>[
      'EP-03:222',
      'conversations/messages + Realtime policies + encryption-at-rest',
      <String>[
        'supabase/tests/database/029_service_messaging_schema_posture.sql',
        'supabase/tests/database/030_service_messaging_rpc_enforcement.sql',
        'test/integration/marketplace/messaging_realtime_offline_integration_test.dart',
      ],
    ],
    // EP-03:223 Scheduling schema + exclusion constraint + booking RPCs
    <Object>[
      'EP-03:223',
      'availability_slots/appointments exclusion constraint + booking RPCs',
      <String>[
        'supabase/tests/database/031_service_scheduling_schema_posture.sql',
        'supabase/tests/database/032_service_scheduling_rpc_enforcement.sql',
        'test/integration/marketplace/scheduling_booking_conflict_integration_test.dart',
      ],
    ],
    // EP-03:224 service-listing-media bucket + RLS
    <Object>[
      'EP-03:224',
      'service-listing-media bucket RLS (owner-write, participant-read evidence)',
      <String>[
        'supabase/tests/database/017_storage_posture.sql',
        'test/integration/verification/trust_storage_posture_verification.dart',
      ],
    ],
    // EP-03:225 Deterministic ranking RPC + no client override
    <Object>[
      'EP-03:225',
      'service_ranking_search deterministic + AI does not override result order',
      <String>[
        'supabase/tests/database/034_service_ranking_rpc_enforcement.sql',
        'test/integration/marketplace/ranking_determinism_integration_test.dart',
        'test/integration/verification/marketplace_ranking_override_scan_verification.dart',
      ],
    ],
    // EP-03:226 FTS discovery + filtered paginated ranked results
    <Object>[
      'EP-03:226',
      'search_vector GIN + service_search filtered/paginated/ranked results',
      <String>[
        'test/integration/marketplace/search_pagination_integration_test.dart',
        'test/widget/marketplace/marketplace_search_screen_test.dart',
      ],
    ],
    // EP-03:227 Listing management + trade-gate blocked client path
    <Object>[
      'EP-03:227',
      'create/edit/publish + media upload + trade-gate blocked client path',
      <String>[
        'test/integration/marketplace/listing_publish_discovery_integration_test.dart',
        'test/integration/marketplace/trade_gate_block_integration_test.dart',
        'test/widget/marketplace/service_listing_form_screen_test.dart',
      ],
    ],
    // EP-03:228 Discovery screens + token assertions
    <Object>[
      'EP-03:228',
      'browse/filter/search/ranked list/listing detail screens + theme-token assertions',
      <String>[
        'test/widget/marketplace/marketplace_discovery_screen_test.dart',
        'test/widget/marketplace/discovery_filter_sheet_test.dart',
        'test/integration/verification/trust_theme_token_scan_verification.dart',
      ],
    ],
    // EP-03:229 Contract lifecycle E2E + atomic ledger movement
    <Object>[
      'EP-03:229',
      'offer→accept→milestone→verify→escrow release with ledger+audit rows',
      <String>[
        'test/integration/marketplace/contract_lifecycle_integration_test.dart',
        'test/integration/marketplace/milestone_release_ledger_integration_test.dart',
        'supabase/tests/database/043_contract_escrow_release_enforcement.sql',
      ],
    ],
    // EP-03:230 Double-blind review E2E + pre-reveal disclosure impossible
    <Object>[
      'EP-03:230',
      'both parties submit → auto-reveal; pre-reveal disclosure impossible',
      <String>[
        'test/integration/marketplace/double_blind_review_integration_test.dart',
        'test/unit/reviews/service_review_repository_test.dart',
      ],
    ],
    // EP-03:231 Messaging E2E + offline queue replay
    <Object>[
      'EP-03:231',
      'send/receive Realtime + offline queue replay + encrypted body',
      <String>[
        'test/integration/marketplace/messaging_realtime_offline_integration_test.dart',
        'test/integration/offline_sync_integration_test.dart',
      ],
    ],
    // EP-03:232 Scheduling conflict detection
    <Object>[
      'EP-03:232',
      'availability CRUD, booking, reschedule, cancel; overlap rejected (PLT005)',
      <String>[
        'test/integration/marketplace/scheduling_booking_conflict_integration_test.dart',
        'test/widget/scheduling/scheduling_screens_test.dart',
      ],
    ],
    // EP-03:233 Portfolio linkage + HivorrEmptyState
    <Object>[
      'EP-03:233',
      'listing detail renders linked portfolio proof; empty state branded slot',
      <String>[
        'test/integration/service_listing_proof_flow_test.dart',
        'test/widget/marketplace/service_proof_section_test.dart',
      ],
    ],
    // EP-03:234 Financial reporting + no client settlement math
    <Object>[
      'EP-03:234',
      'earnings summary/history read server-aggregated RPCs; no client ledger reduce',
      <String>[
        'test/integration/marketplace/earnings_ledger_parity_integration_test.dart',
        'test/integration/verification/trust_financial_logic_scan_verification.dart',
      ],
    ],
    // EP-03:235 Service-engagement dispute freeze/resolve
    <Object>[
      'EP-03:235',
      'dispute_file freezes escrow (disputed); resolve outcome → ledger',
      <String>[
        'test/integration/marketplace/dispute_freeze_resolve_gate_integration_test.dart',
        'test/integration/support/service_dispute_flow_test.dart',
        'supabase/tests/database/049_service_dispute_enforcement.sql',
      ],
    ],
    // EP-03:236 Lifecycle notifications
    <Object>[
      'EP-03:236',
      'push+local for contract/milestone/review/message/appointment events',
      <String>[
        'test/unit/core/notifications/lifecycle_notification_templates_test.dart',
        'supabase/tests/database/055_notification_outbox_matrix.sql',
      ],
    ],
    // EP-03:237 Public routes + SEO + responsive shell
    <Object>[
      'EP-03:237',
      'public /s/... + /contracts/... routes deep-linkable, SEO, responsive scaffold',
      <String>[
        'test/widget/app/seo_router_shapes_test.dart',
        'test/support/harnesses/router_harness.dart',
        'test/widget/marketplace/marketplace_discovery_seo_test.dart',
      ],
    ],
    // EP-03:238 RLS default-deny + no authenticated INSERT bypass
    <Object>[
      'EP-03:238',
      'all new tables RLS default-deny; RPC-canonical writes (pgTAP audit)',
      <String>[
        'supabase/tests/database/001_rls_leakage_matrix.sql',
        'supabase/tests/database/004_security_posture_audit.sql',
        'supabase/tests/database',
      ],
    ],
    // EP-03:239 Zero client-side matching/financial logic + no hardcoded colors/fonts
    <Object>[
      'EP-03:239',
      'zero client financial/matching logic; no hardcoded colors/fonts; no PII echoes',
      <String>[
        'test/integration/verification/trust_financial_logic_scan_verification.dart',
        'test/integration/verification/trust_theme_token_scan_verification.dart',
        'test/integration/verification/marketplace_pii_scan_verification.dart',
      ],
    ],
    // EP-03:240 All EP-03 items at Completed (phase-plan audit row — status
    // audit recorded in the EP-03-20 report with entry debts owned by the
    // project lead; excluded from the 21/21 technical aggregate).
    <Object>[
      'EP-03:240',
      'All EP-03 items at Completed (phase plan audit — entry debts recorded in EP-03-20 report)',
      <String>[
        'documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md',
        'documents/Task-Implementation/EP-03/EP-03-20-Marketplace-Verification-Report.md',
      ],
    ],
  ];

  return entries.map((List<Object> entry) {
    return _ChecklistItem(
      id: entry[0] as String,
      title: entry[1] as String,
      paths: entry[2] as List<String>,
      pass: _verifyPaths(root, entry[2] as List<String>),
    );
  }).toList();
}

void main() {
  final root = _findProjectRoot();
  final items = _buildChecklist(root);
  final technical = items
      .where((i) => i.id != 'EP-03:240')
      .toList(growable: false);

  group('EP-03 Phase Completion Checklist', () {
    for (final item in items) {
      test('${item.id}: ${item.title}', () {
        final buf = StringBuffer();
        buf.writeln('${item.id}: ${item.title}');
        for (final path in item.paths) {
          final exists =
              File('$root${Platform.pathSeparator}$path').existsSync() ||
              Directory('$root${Platform.pathSeparator}$path').existsSync();
          buf.writeln('  ${exists ? 'PASS' : 'FAIL'} → $path');
        }
        expect(item.pass, isTrue, reason: buf.toString());
      });
    }

    test('checklist covers all 22 §10 rows (21 technical + 1 audit)', () {
      expect(items, hasLength(22));
      expect(technical, hasLength(21));
      expect(items.first.id, 'EP-03:219');
      expect(items.last.id, 'EP-03:240');
    });

    test('21/21 technical criteria PASS (EP-03:219-239)', () {
      final failed = technical.where((i) => !i.pass).toList();
      if (failed.isNotEmpty) {
        final buf = StringBuffer();
        buf.writeln('FAILED technical criteria:');
        for (final f in failed) {
          buf.writeln('  ${f.id}: ${f.title} → ${f.paths}');
        }
        fail(buf.toString());
      }
      expect(
        technical.every((i) => i.pass),
        isTrue,
        reason: 'all 21 EP-03 technical phase completion criteria must PASS',
      );
    });
  });
}
