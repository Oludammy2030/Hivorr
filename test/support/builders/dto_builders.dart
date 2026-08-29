import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Builds valid [EntityProfileDto] instances with sensible defaults.
///
/// [toMap] always includes optional keys (even when null) so it can be diffed
/// against the server column contract, unlike [EntityProfileDto.toJson] which
/// omits nulls. This matches the EP-01-19 DoD edge-case expectation.
class EntityProfileDtoBuilder {
  String _entityId = 'test-entity-001';
  String _legalName = 'Test Legal Name';
  String _displayName = 'test_display';
  String? _bio;
  String? _avatarPath;
  String? _countryCode;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  String? _createdBy;

  EntityProfileDtoBuilder withEntityId(String value) => this.._entityId = value;
  EntityProfileDtoBuilder withLegalName(String value) =>
      this.._legalName = value;
  EntityProfileDtoBuilder withDisplayName(String value) =>
      this.._displayName = value;
  EntityProfileDtoBuilder withBio(String? value) => this.._bio = value;
  EntityProfileDtoBuilder withAvatarPath(String? value) =>
      this.._avatarPath = value;
  EntityProfileDtoBuilder withCountryCode(String? value) =>
      this.._countryCode = value;
  EntityProfileDtoBuilder withCreatedAt(DateTime? value) =>
      this.._createdAt = value;
  EntityProfileDtoBuilder withUpdatedAt(DateTime? value) =>
      this.._updatedAt = value;
  EntityProfileDtoBuilder withCreatedBy(String? value) =>
      this.._createdBy = value;

  EntityProfileDto build() => EntityProfileDto(
        entityId: _entityId,
        legalName: _legalName,
        displayName: _displayName,
        bio: _bio,
        avatarPath: _avatarPath,
        countryCode: _countryCode,
        createdAt: _createdAt,
        updatedAt: _updatedAt,
        createdBy: _createdBy,
      );

  /// Serializes to the snake_case `entity_profiles` column contract with all
  /// keys present (nulls included).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'entity_id': _entityId,
        'legal_name': _legalName,
        'display_name': _displayName,
        'bio': _bio,
        'avatar_path': _avatarPath,
        'country_code': _countryCode,
        'created_at': _createdAt?.toIso8601String(),
        'updated_at': _updatedAt?.toIso8601String(),
        'created_by': _createdBy,
      };
}

/// Builds valid [EntityRoleDto] instances with sensible defaults.
class EntityRoleDtoBuilder {
  String _entityId = 'test-entity-001';
  String _role = 'consumer';
  bool _isActive = true;
  DateTime? _activatedAt;

  EntityRoleDtoBuilder withEntityId(String value) => this.._entityId = value;
  EntityRoleDtoBuilder withRole(String value) => this.._role = value;
  EntityRoleDtoBuilder withIsActive(bool value) => this.._isActive = value;
  EntityRoleDtoBuilder withActivatedAt(DateTime? value) =>
      this.._activatedAt = value;

  EntityRoleDto build() => EntityRoleDto(
        entityId: _entityId,
        role: _role,
        isActive: _isActive,
        activatedAt: _activatedAt,
      );

  /// Serializes to the snake_case `entity_roles` column contract.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'entity_id': _entityId,
        'role': _role,
        'is_active': _isActive,
        'activated_at': _activatedAt?.toIso8601String(),
      };
}
