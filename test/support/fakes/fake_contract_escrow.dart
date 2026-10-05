import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';

/// Escrow-linkage fixtures for EP-03-11 orchestrator tests.
///
/// Builds [ServiceContract] rows with `escrow_id` / `escrow_milestone_id`
/// backfilled (the `service_role`-only linkage), plus `review_period_expires_at`
/// variants for the 7-day expiry path. Pure builders — no I/O, no Supabase.
ServiceContract seedLinkedContract({
  String id = 'c1',
  String status = 'active',
  String clientId = 'client-1',
  String professionalId = 'pro-1',
  String? escrowId = 'escrow-1',
  double total = 30000,
  String currency = 'NGN',
  List<ContractMilestone>? milestones,
}) => ServiceContract(
  id: id,
  serviceListingId: 'listing-1',
  clientEntityId: clientId,
  professionalEntityId: professionalId,
  status: status,
  escrowId: escrowId,
  totalAmount: total,
  currencyCode: currency,
  milestones:
      milestones ??
      <ContractMilestone>[
        ContractMilestone(
          id: 'm1',
          contractId: id,
          escrowMilestoneId: 'em1',
          milestoneNumber: 1,
          title: 'Inspection visit',
          amount: 10000,
          status: 'verified',
          sortOrder: 0,
          completedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          verifiedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        ContractMilestone(
          id: 'm2',
          contractId: id,
          escrowMilestoneId: 'em2',
          milestoneNumber: 2,
          title: 'Repair works',
          amount: 10000,
          status: 'pending',
          sortOrder: 1,
        ),
        ContractMilestone(
          id: 'm3',
          contractId: id,
          escrowMilestoneId: 'em3',
          milestoneNumber: 3,
          title: 'Testing and handover',
          amount: 10000,
          status: 'pending',
          sortOrder: 2,
        ),
      ],
  events: const <ContractEvent>[
    ContractEvent(id: 'e1', contractId: 'c1', eventType: 'offered'),
  ],
);

/// A `completed` milestone whose review deadline has passed (cron-eligible).
ContractMilestone seedExpiredMilestone({
  String id = 'm1',
  String contractId = 'c1',
}) => ContractMilestone(
  id: id,
  contractId: contractId,
  escrowMilestoneId: 'em1',
  milestoneNumber: 1,
  title: 'Inspection visit',
  amount: 10000,
  status: 'completed',
  sortOrder: 0,
  completedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  reviewPeriodExpiresAt: DateTime.fromMillisecondsSinceEpoch(2000),
);

/// A `completed` milestone still inside its review window.
ContractMilestone seedUnexpiredMilestone({
  String id = 'm1',
  String contractId = 'c1',
  DateTime? expiresAt,
}) => ContractMilestone(
  id: id,
  contractId: contractId,
  escrowMilestoneId: 'em1',
  milestoneNumber: 1,
  title: 'Inspection visit',
  amount: 10000,
  status: 'completed',
  sortOrder: 0,
  completedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  reviewPeriodExpiresAt:
      expiresAt ?? DateTime.now().add(const Duration(days: 6)),
);
