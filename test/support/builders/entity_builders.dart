import 'package:hivorr/data/entities/entity.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';

/// Builds valid [EntityProfile] instances with sensible defaults.
///
/// Each call to [build] returns an independent instance; overrides never leak
/// between builders (EP-01-19 reference pattern).
class EntityProfileBuilder {
  String _legalName = 'Test Legal Name';
  String _displayName = 'test_display';
  String? _bio;
  String? _avatarPath;
  String? _countryCode = 'US';

  EntityProfileBuilder withLegalName(String value) => this.._legalName = value;
  EntityProfileBuilder withDisplayName(String value) =>
      this.._displayName = value;
  EntityProfileBuilder withBio(String? value) => this.._bio = value;
  EntityProfileBuilder withAvatarPath(String? value) =>
      this.._avatarPath = value;
  EntityProfileBuilder withCountryCode(String? value) =>
      this.._countryCode = value;

  EntityProfile build() => EntityProfile(
        legalName: _legalName,
        displayName: _displayName,
        bio: _bio,
        avatarPath: _avatarPath,
        countryCode: _countryCode,
      );
}

/// Builds valid [EntityRole] instances with sensible defaults.
class EntityRoleBuilder {
  EntityRoleValue _role = EntityRoleValue.consumer;
  bool _isActive = true;
  DateTime? _activatedAt;

  EntityRoleBuilder withRole(EntityRoleValue value) => this.._role = value;
  EntityRoleBuilder withRoleName(String value) =>
      this.._role = EntityRoleValue.fromString(value);
  EntityRoleBuilder withIsActive(bool value) => this.._isActive = value;
  EntityRoleBuilder withActivatedAt(DateTime? value) =>
      this.._activatedAt = value;

  EntityRole build() => EntityRole(
        role: _role,
        isActive: _isActive,
        activatedAt: _activatedAt,
      );
}

/// Builds valid [Entity] aggregates with sensible defaults.
///
/// With no overrides, [build] returns an [Entity] with a default profile and a
/// single default (active consumer) role.
class EntityBuilder {
  String _id = 'test-entity-001';
  EntityStatus _status = EntityStatus.active;
  EntityProfile? _profile;
  List<EntityRole> _roles = <EntityRole>[];
  bool _rolesExplicit = false;

  EntityBuilder withId(String value) => this.._id = value;
  EntityBuilder withStatus(EntityStatus value) => this.._status = value;
  EntityBuilder withProfile(EntityProfile? value) => this.._profile = value;
  EntityBuilder withRoles(List<EntityRole> value) =>
      this.._roles = List<EntityRole>.of(value).._rolesExplicit = true;
  EntityBuilder addRole(EntityRole value) =>
      this.._roles.add(value).._rolesExplicit = true;

  Entity build() {
    final EntityProfile profile = _profile ?? EntityProfileBuilder().build();
    final List<EntityRole> roles = _rolesExplicit
        ? List<EntityRole>.of(_roles)
        : <EntityRole>[EntityRoleBuilder().build()];
    return Entity(id: _id, status: _status, profile: profile, roles: roles);
  }
}
