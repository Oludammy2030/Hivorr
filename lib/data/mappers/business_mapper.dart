import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/models/business_dto.dart';

/// Maps business DTOs into domain entities (no I/O, no logic).
///
/// The single transformation boundary between the RLS-CRUD rows and the
/// domain — null-safe field copying only (EP-01-08 §5.3).
abstract final class BusinessMapper {
  /// Maps a business row (with optional embedded membership) verbatim.
  static Business businessToEntity(BusinessDto dto) => Business(
    id: dto.id,
    tradingName: dto.tradingName,
    registeredLegalName: dto.registeredLegalName,
    cacNumber: (dto.cacNumber == null || dto.cacNumber!.isEmpty)
        ? null
        : dto.cacNumber,
    status: dto.status,
    membership: dto.membership == null
        ? null
        : membershipToEntity(dto.membership!),
  );

  /// Maps a membership row verbatim.
  static BusinessMembership membershipToEntity(BusinessMembershipDto dto) =>
      BusinessMembership(
        businessId: dto.businessId,
        entityId: dto.entityId,
        role: dto.role,
        isAuthorized: dto.isAuthorized,
      );
}
