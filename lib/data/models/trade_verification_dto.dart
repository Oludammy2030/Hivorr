import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';

/// The transport shape for the trade-verification aggregate (EP-02-11 §5.2).
///
/// Extracts the per-profession `trade_verifications` array and the
/// `identity_verified` flag from the broader `verification_status_get`
/// envelope, so the trade slice stays decoupled from the KYC portion. Each
/// entry is a [TradeVerificationDto] (profession id + server
/// `trade_verification_status`), with `rejected` derived client-side.
class TradeVerificationStatusDto {
  const TradeVerificationStatusDto({
    this.tradeVerifications = const <TradeVerificationDto>[],
    this.identityVerified = false,
  });

  /// Derives the trade aggregate from the full verification status DTO.
  factory TradeVerificationStatusDto.fromStatusDto(
    VerificationStatusDto status,
  ) =>
      TradeVerificationStatusDto(
        tradeVerifications: status.tradeVerifications,
        identityVerified: status.identityVerified,
      );

  /// The per-profession trade verification entries.
  final List<TradeVerificationDto> tradeVerifications;

  /// Whether identity is verified (server-derived).
  final bool identityVerified;
}
