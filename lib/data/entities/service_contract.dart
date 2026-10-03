import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';

/// A two-party service engagement binding a `published` service listing to a
/// client and a professional (EP-03-10).
///
/// Mirrors `service_contracts`
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`).
/// `status` spans
/// `draft | offered | active | completed | disputed | closed | cancelled`.
/// `escrowId` stays `null` until the EP-03-11 orchestrator links
/// `financial_escrow` — this slice surfaces it read-only.
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports. State is
/// server-authoritative; the `can*` helpers below are view-intent hints for
/// CTA visibility only and never enforcement (`AGENT.md` Rule 4).
class ServiceContract {
  const ServiceContract({
    required this.id,
    required this.serviceListingId,
    required this.clientEntityId,
    required this.professionalEntityId,
    required this.status,
    this.escrowId,
    required this.totalAmount,
    required this.currencyCode,
    this.offerExpiresAt,
    this.offeredAt,
    this.acceptedAt,
    this.completedAt,
    this.closedAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.listingSlug,
    this.listingTitle,
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
    this.milestones = const <ContractMilestone>[],
    this.events = const <ContractEvent>[],
  });

  /// The contract row id.
  final String id;

  /// The bound `service_listings` row.
  final String serviceListingId;

  /// The consuming client (offer author).
  final String clientEntityId;

  /// The hired professional (listing owner).
  final String professionalEntityId;

  /// Lifecycle state.
  final String status;

  /// Linked `financial_escrow` row, `null` until EP-03-11 links it.
  final String? escrowId;

  /// Contract total (equals `sum(milestones.amount)` server-side).
  final double totalAmount;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// When the offer lapses, when supplied.
  final DateTime? offerExpiresAt;

  /// Lifecycle timestamps (RPC-managed).
  final DateTime? offeredAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Denormalized listing/profession/industry context (`get` only).
  final String? listingSlug;
  final String? listingTitle;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;

  /// Milestones in server order (`get` only; empty on `list_mine` rows).
  final List<ContractMilestone> milestones;

  /// Audit events in `created_at` order (`get` only).
  final List<ContractEvent> events;

  /// Whether the offer is awaiting the professional.
  bool get isOffered => status == 'offered';

  /// Whether work is in flight.
  bool get isActive => status == 'active';

  /// Whether all milestones are verified (server-promoted).
  bool get isCompleted => status == 'completed';

  /// Whether the contract is frozen pending dispute resolution.
  bool get isDisputed => status == 'disputed';

  /// Whether the contract reached a terminal state.
  bool get isTerminal =>
      status == 'closed' || status == 'cancelled' || status == 'disputed';

  /// Whether the offer has lapsed (client-evaluated hint; server decides).
  bool get isExpired =>
      offerExpiresAt != null &&
      DateTime.now().isAfter(offerExpiresAt!) &&
      isOffered;

  /// Whether every milestone carries `verified` (display hint for the Close
  /// CTA; the server re-checks before `service_contract_close`).
  bool get allMilestonesVerified =>
      milestones.isNotEmpty &&
      milestones.every((ContractMilestone m) => m.isVerified);

  /// Count of milestones not yet `verified` (close-caption hint).
  int get unverifiedCount => milestones
      .where((ContractMilestone m) => !m.isVerified)
      .length;

  /// View-intent hint: professional accept affordance.
  bool canAccept(String viewerEntityId) =>
      isOffered && viewerEntityId == professionalEntityId && !isExpired;

  /// View-intent hint: professional milestone-complete affordance.
  bool canComplete(String viewerEntityId) =>
      isActive && viewerEntityId == professionalEntityId;

  /// View-intent hint: client verify/revision affordance.
  bool canVerify(String viewerEntityId) =>
      isActive && viewerEntityId == clientEntityId;

  /// View-intent hint: close affordance (either participant, all verified).
  bool canClose(String viewerEntityId) =>
      (isActive || isCompleted) &&
      (viewerEntityId == clientEntityId ||
          viewerEntityId == professionalEntityId) &&
      allMilestonesVerified;
}
