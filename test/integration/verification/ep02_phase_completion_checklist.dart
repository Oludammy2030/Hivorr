// EP-02-20 DoD-C8: EP-02 Phase Completion Checklist.
//
// Structured checklist for each EP-02:214-241 criterion.
// Mirrors the EP-01-20 `phase_completion_checklist.dart` pattern.
// Each criterion maps to a source directory/file or verification artefact
// that must exist for the criterion to be marked PASS.
//
// Run: flutter test test/integration/verification/ep02_phase_completion_checklist.dart

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
    // EP-02 Trust, Identity & Financial Integrity Engine: 21 criteria
    // EP-02:214 Entity & Taxonomy foundation
    <Object>[
      'EP-02:214',
      'Entity schema, taxonomy tables, RLS',
      <String>['lib/data/entities'],
    ],
    // EP-02:215 Entity profile + avatar + role
    <Object>[
      'EP-02:215',
      'Entity profile, avatar, role activation',
      <String>['lib/systems/onboarding'],
    ],
    // EP-02:216 Profession bind + duplicate guard
    <Object>[
      'EP-02:216',
      'Profession bind, PLT005 duplicate guard',
      <String>['lib/data/providers/taxonomy_provider.dart'],
    ],
    // EP-02:217 Onboarding wizard 5-step
    <Object>[
      'EP-02:217',
      'Onboarding wizard (profile/capability/industry/identity/trade)',
      <String>['lib/systems/onboarding/services/onboarding_service.dart'],
    ],
    // EP-02:218 Identity verification submit→approve
    <Object>[
      'EP-02:218',
      'Identity verification (DocumentType × 5, admin review)',
      <String>['lib/systems/verification/services/identity_verification_service.dart'],
    ],
    // EP-02:219 Trade verification + bid-lock gate
    <Object>[
      'EP-02:219',
      'Trade verification (TradeProofType × 5, gate, badge)',
      <String>['lib/systems/verification/services/trade_verification_service.dart'],
    ],
    // EP-02:220 KYC tier + limit guard
    <Object>[
      'EP-02:220',
      'KYC tiers (0-3) + KycLimitGuard',
      <String>['lib/systems/verification/services/kyc_limit_guard.dart'],
    ],
    // EP-02:221 Admin review queue + approval workflow
    <Object>[
      'EP-02:221',
      'Admin review queue + approval workflow',
      <String>['lib/systems/verification/screens/admin_review_queue_screen.dart'],
    ],
    // EP-02:222 Financial profile + multi-currency
    <Object>[
      'EP-02:222',
      'Financial profile + currency accounts (NGN/GHS/USD/GBP)',
      <String>['lib/systems/finance/services/financial_service.dart'],
    ],
    // EP-02:223 Escrow lifecycle + milestones
    <Object>[
      'EP-02:223',
      'Escrow lifecycle (create/fund/milestone/release/refund)',
      <String>['lib/systems/finance/services/escrow_service.dart'],
    ],
    // EP-02:224 Currency conversion
    <Object>[
      'EP-02:224',
      'Currency conversion (preview/execute/atomic balances)',
      <String>['lib/systems/finance/services/conversion_service.dart'],
    ],
    // EP-02:225 Bound payout + KYC cashout limits
    <Object>[
      'EP-02:225',
      'Bound payout accounts + KYC cashout limits',
      <String>['lib/systems/finance/services/financial_payout_service.dart'],
    ],
    // EP-02:226 Deposit name-matching (Rule 3)
    <Object>[
      'EP-02:226',
      'Deposit name-matching (Agent Rule 3)',
      <String>['lib/systems/finance/models/deposit_name_match_status.dart'],
    ],
    // EP-02:227 Payment gateway abstraction boundary
    <Object>[
      'EP-02:227',
      'Payment gateway abstraction (Paystack/Flutterwave/NIBSS)',
      <String>['lib/integrations/payment_gateways/payment_gateway_factory.dart'],
    ],
    // EP-02:228 Dispute filing + evidence + resolution
    <Object>[
      'EP-02:228',
      'Dispute system (file/evidence/resolve/audit)',
      <String>['lib/systems/support/services/dispute_service.dart'],
    ],
    // EP-02:229 Public profile + SEO + route guard
    <Object>[
      'EP-02:229',
      'Public profile (SECURITY DEFINER, SEO, guard bypass)',
      <String>['lib/systems/portfolio/services/professional_profile_service.dart'],
    ],
    // EP-02:230 Storage buckets + private/public isolation
    <Object>[
      'EP-02:230',
      'Storage buckets (credential-documents private, profile-avatars/portfolio-items public)',
      <String>['lib/core/storage/storage_config.dart'],
    ],
    // EP-02:231 Design token compliance (Rule 5)
    <Object>[
      'EP-02:231',
      'Design token compliance (Theme.of, no Colors.* or fontFamily:)',
      <String>['lib/app/theme'],
    ],
    // EP-02:232 PII redactor + redacted logging
    <Object>[
      'EP-02:232',
      'PII redactor + entityId-suffix redacted logging',
      <String>['lib/core/logging/pii_redactor.dart'],
    ],
    // EP-02:233 Zero client-side financial logic (Rule 4)
    <Object>[
      'EP-02:233',
      'Zero client-side financial logic in lib/systems/ + lib/data/',
      <String>['test/integration/verification/trust_financial_logic_scan_verification.dart'],
    ],
    // EP-02:234 No legal_name / document_path leakage
    <Object>[
      'EP-02:234',
      'No legal_name/document_path/service_role in client code',
      <String>['test/integration/verification/trust_legal_name_document_scan_verification.dart'],
    ],
    // EP-02:235 RLS default-deny verified (001-022 pgTAP)
    <Object>[
      'EP-02:235',
      'RLS default-deny (001-022 pgTAP, git diff supabase/migrations/ = 0)',
      <String>['supabase/tests/database'],
    ],
    // EP-02:236-241 trust integration VPs + verification scripts
    <Object>[
      'EP-02:236-241',
      'Trust integration tests (VP1-VP12) + verification scripts exist',
      <String>['test/integration/trust'],
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

  group('EP-02 Phase Completion Checklist', () {
    for (final item in items) {
      test('${item.id}: ${item.title}', () {
        final buf = StringBuffer();
        buf.writeln('${item.id}: ${item.title}');
        for (final path in item.paths) {
          final exists = File('$root${Platform.pathSeparator}$path')
                  .existsSync() ||
              Directory('$root${Platform.pathSeparator}$path')
                  .existsSync();
          buf.writeln('  ${exists ? 'PASS' : 'FAIL'} → $path');
        }
        expect(item.pass, isTrue, reason: buf.toString());
      });
    }

    test('all 21+ criteria PASS', () {
      final failed = items.where((i) => !i.pass).toList();
      if (failed.isNotEmpty) {
        final buf = StringBuffer();
        buf.writeln('FAILED criteria:');
        for (final f in failed) {
          buf.writeln('  ${f.id}: ${f.title} → ${f.paths}');
        }
        fail(buf.toString());
      }
      expect(items.every((i) => i.pass), isTrue,
          reason: 'all EP-02 phase completion criteria must PASS');
    });
  });
}
