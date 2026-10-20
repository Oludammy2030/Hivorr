// Run: flutter test test/integration/marketplace/dispute_freeze_resolve_gate_integration_test.dart
//
// EP-03-20 VP12 — Dispute: freeze → resolve gate → withdraw.
// Composes the REAL DisputeService + DisputeProvider over
// FakeDisputeRepository (which deliberately exposes **no resolve method** —
// resolution is server-authoritative and only ever *read back* through
// `service_dispute_get`). The escrow freeze is proven fail-closed by the
// EP-03-11 orchestrator refusing release on a `disputed` contract before any
// escrow write. The `EscrowFrozenBanner` renders the hold posture.
//
// The full RPC-based freeze→evidence→withdraw E2E (server semantics) lives in
// `test/integration/support/service_dispute_flow_test.dart:209-273` — cited,
// not duplicated.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_state.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:hivorr/systems/support/widgets/escrow_frozen_banner.dart';

import '../../support/fakes/fake_contract_escrow.dart';
import '../../support/fakes/fake_service_contract.dart';
import '../../support/fakes/finance/fake_escrow_repository.dart';
import '../../support/fakes/support/fake_dispute_repository.dart';
import '../../support/harnesses/widget_harness.dart';

/// Builds the provider over the fake dispute repository.
({DisputeProvider provider, FakeDisputeRepository repo}) _build() {
  final FakeDisputeRepository repo = FakeDisputeRepository();
  final DisputeService service = DisputeService(repository: repo);
  final DisputeProvider provider = DisputeProvider(service: service);
  return (provider: provider, repo: repo);
}

void main() {
  group('EP-03-20 VP12 — dispute freeze/resolve gate', () {
    test(
      'DoD-VP12a: file-by-contract selects the case (freeze entry)',
      () async {
        final ({DisputeProvider provider, FakeDisputeRepository repo}) built =
            _build();
        addTearDown(built.provider.dispose);

        // Act: file the contract-scoped dispute through the real provider.
        final filed = await built.provider.fileForContract(
          contractId: 'contract-1',
          disputeType: 'milestone_disagreement',
          reason: 'The milestone was marked complete without delivering scope.',
          desiredOutcome: 'refund_to_payer',
          priority: 'high',
        );

        // Assert: the write reached the contract-scoped RPC seam and the
        // returned authoritative case became the selection.
        expect(built.repo.fileServiceCallCount, 1);
        expect(built.repo.lastContractId, 'contract-1');
        expect(built.repo.lastDisputeType, 'milestone_disagreement');
        expect(built.repo.lastPriority, 'high');
        expect(filed.id, 'dispute-service-1');
        expect(filed.contractId, 'contract-1');
        expect(built.provider.selected?.id, 'dispute-service-1');
      },
    );

    test('DoD-VP12b: disputed contract blocks escrow release BEFORE any write '
        '(fail-closed freeze)', () async {
      // Arrange: the server froze the contract via the dispute.
      final ServiceContract disputed = seedLinkedContract(
        id: 'c1',
        status: 'disputed',
      );
      final FakeServiceContractRepository contracts =
          FakeServiceContractRepository(seed: <ServiceContract>[disputed]);
      final FakeEscrowRepository escrows = FakeEscrowRepository(
        writeAvailable: true,
      );
      final ContractEscrowOrchestrator orchestrator =
          ContractEscrowOrchestrator(
            contracts: ContractService(repository: contracts),
            escrows: EscrowService(repository: escrows),
            clock: () => DateTime.fromMillisecondsSinceEpoch(9999999999),
          );

      // Act: attempt release while the dispute hold is active.
      final ContractEscrowReleaseState state = await orchestrator
          .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

      // Assert: refused before any fund movement — the freeze is the server's
      // hold, mirrored fail-closed client-side (no partial escrow state).
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(state.blockReason, ContractEscrowBlockReason.disputed);
      expect(state.ok, isFalse);
      expect(state.code, 'PLT005');
      expect(
        escrows.releaseMilestoneCallCount,
        0,
        reason: 'no escrow write while disputed',
      );
    });

    test(
      'DoD-VP12c: release resolution is READ verbatim (server authority)',
      () async {
        final ({DisputeProvider provider, FakeDisputeRepository repo}) built =
            _build();
        addTearDown(built.provider.dispose);

        // Arrange: the server resolved the case with a release to the payee.
        built.repo.setDetail(
          seedDisputeDetailEntity(
            id: 'd1',
            status: 'resolved',
            contractId: 'contract-1',
            resolution: seedDisputeResolutionEntity(
              caseId: 'd1',
              resolutionType: 'release_to_payee',
              payerRefundAmount: 0,
              payeeReleaseAmount: 30000,
            ),
          ),
        );

        // Act: read the authoritative detail back.
        await built.provider.select('d1');

        // Assert: amounts are surfaced verbatim — the client never decides,
        // splits, or rounds the resolution (AGENT.md Rule 4).
        final DisputeResolution? resolution = built.provider.resolution;
        expect(resolution, isNotNull);
        expect(resolution!.resolutionType, 'release_to_payee');
        expect(resolution.payeeReleaseAmount, 30000);
        expect(resolution.payerRefundAmount, 0);
        expect(built.provider.isLoaded, isTrue);
        expect(built.repo.getServiceCaseCallCount, 1);
      },
    );

    test(
      'DoD-VP12d: refund resolution is READ verbatim (server authority)',
      () async {
        final ({DisputeProvider provider, FakeDisputeRepository repo}) built =
            _build();
        addTearDown(built.provider.dispose);

        // Arrange: the server resolved the case with a partial refund.
        built.repo.setDetail(
          seedDisputeDetailEntity(
            id: 'd2',
            status: 'resolved',
            resolution: seedDisputeResolutionEntity(
              id: 'resolution-2',
              caseId: 'd2',
              resolutionType: 'refund_to_payer',
              payerRefundAmount: 15000,
              payeeReleaseAmount: 15000,
              reasoning: 'Partial delivery; funds split per the evidence.',
            ),
          ),
        );

        // Act: read the authoritative detail back.
        await built.provider.select('d2');

        // Assert: split surfaced verbatim, never recomputed client-side.
        final DisputeResolution? resolution = built.provider.resolution;
        expect(resolution!.resolutionType, 'refund_to_payer');
        expect(resolution.payerRefundAmount, 15000);
        expect(resolution.payeeReleaseAmount, 15000);
        expect(
          resolution.payerRefundAmount + resolution.payeeReleaseAmount,
          30000,
          reason: 'sum matches the seeded contract total (read, not derived)',
        );
      },
    );

    test('DoD-VP12e: no client resolve method exists on the repository '
        'contract', () {
      // Static proof that resolution cannot be issued from the client: the
      // DisputeRepository seam exposes file/evidence/withdraw/read methods
      // only. Resolution arrives exclusively through server-authored rows
      // read back via `getServiceCase`.
      final String source = File(
        'lib/data/repositories/dispute_repository.dart',
      ).readAsStringSync();

      expect(source, contains('fileServiceDispute'));
      expect(source, contains('getServiceCase'));
      expect(source, contains('withdrawDispute'));
      expect(
        RegExp(r'Future<[^>]*>\s+resolve\w*\s*\(').hasMatch(source),
        isFalse,
        reason: 'DisputeRepository must not declare a client resolve call',
      );
      // The provider likewise exposes no resolve entry point.
      final String provider = File(
        'lib/data/providers/dispute_provider.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'Future<[^>]*>\s+resolve\w*\s*\(').hasMatch(provider),
        isFalse,
        reason: 'DisputeProvider must not expose a client resolve call',
      );
    });

    test('DoD-VP12f: withdraw releases the hold (selection flips)', () async {
      final ({DisputeProvider provider, FakeDisputeRepository repo}) built =
          _build();
      addTearDown(built.provider.dispose);

      // Arrange: an open selected case (frozen posture).
      built.repo.setDetail(seedDisputeDetailEntity(id: 'd3', status: 'open'));
      await built.provider.select('d3');
      expect(built.provider.selected!.status, 'open');

      // Act: withdraw the filing.
      final withdrawn = await built.provider.withdraw('d3');

      // Assert: the authoritative re-read flips to withdrawn (the server
      // released both holds — full RPC semantics cited from
      // service_dispute_flow_test.dart:267-273).
      expect(withdrawn.status, 'withdrawn');
      expect(built.repo.withdrawCallCount, 1);
      expect(built.provider.selected!.status, 'withdrawn');
      expect(built.provider.selected!.withdrawnAt, isNotNull);
    });
  });

  group('EP-03-20 VP12 — frozen escrow banner (hold posture)', () {
    testWidgets('DoD-VP12g: banner renders the freeze copy + dispute CTA', (
      WidgetTester tester,
    ) async {
      var routed = 0;
      await pumpTheme(
        tester,
        EscrowFrozenBanner(onViewDispute: () => routed++),
      );

      // Assert: explicit freeze copy, gavel affordance, and the CTA.
      expect(
        find.text(
          'This escrow is in dispute — all actions are frozen until resolved',
        ),
        findsOneWidget,
      );
      expect(find.text('View dispute'), findsOneWidget);
      expect(find.byIcon(Icons.gavel), findsOneWidget);

      // Act: tap the CTA.
      await tester.tap(find.text('View dispute'));
      await tester.pump();
      expect(routed, 1);
    });

    testWidgets('DoD-VP12h: banner hides the CTA when no route is provided', (
      WidgetTester tester,
    ) async {
      await pumpTheme(tester, const EscrowFrozenBanner());

      expect(
        find.text(
          'This escrow is in dispute — all actions are frozen until resolved',
        ),
        findsOneWidget,
      );
      expect(find.text('View dispute'), findsNothing);
    });
  });
}
