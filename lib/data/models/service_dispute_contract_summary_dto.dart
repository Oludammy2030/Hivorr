import 'package:hivorr/data/entities/service_dispute_contract_summary.dart';

/// Data Transfer Object for the `contract` object joined inside the
/// `service_dispute_get` envelope (EP-03-17 §5).
///
/// All keys are nullable-tolerant: a missing join degrades to field defaults
/// rather than throwing, and amounts parse defensively from either numeric
/// or string wire shapes.
class ServiceDisputeContractSummaryDto {
  const ServiceDisputeContractSummaryDto({
    required this.id,
    required this.status,
    this.escrowId,
    required this.totalAmount,
    required this.currencyCode,
    required this.serviceListingId,
    this.listingTitle,
  });

  factory ServiceDisputeContractSummaryDto.fromJson(
    Map<String, dynamic> json,
  ) =>
      ServiceDisputeContractSummaryDto(
        id: (json['id'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        escrowId: json['escrow_id'] as String?,
        totalAmount: _parseAmount(json['total_amount']),
        currencyCode: (json['currency_code'] as String?) ?? '',
        serviceListingId: (json['service_listing_id'] as String?) ?? '',
        listingTitle: json['listing_title'] as String?,
      );

  /// Maps the DTO into a domain [ServiceDisputeContractSummary], normalizing
  /// blank escrow ids to `null` (unfunded contracts).
  ServiceDisputeContractSummary toEntity() {
    final String? rawEscrow = escrowId;
    return ServiceDisputeContractSummary(
      id: id,
      status: status,
      escrowId: rawEscrow == null || rawEscrow.trim().isEmpty
          ? null
          : rawEscrow,
      totalAmount: totalAmount,
      currencyCode: currencyCode,
      serviceListingId: serviceListingId,
      listingTitle: listingTitle,
    );
  }

  final String id;
  final String status;
  final String? escrowId;
  final double totalAmount;
  final String currencyCode;
  final String serviceListingId;
  final String? listingTitle;

  static double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
