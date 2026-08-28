import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/entity.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';

/// Matches an [EntityProfile], optionally asserting [legalName] and
/// [displayName] fields.
Matcher isEntityProfile({
  String? legalName,
  String? displayName,
}) =>
    _EntityProfileMatcher(legalName: legalName, displayName: displayName);

class _EntityProfileMatcher extends Matcher {
  const _EntityProfileMatcher({this.legalName, this.displayName});

  final String? legalName;
  final String? displayName;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! EntityProfile) {
      return false;
    }
    if (legalName != null && item.legalName != legalName) {
      return false;
    }
    if (displayName != null && item.displayName != displayName) {
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is an EntityProfile');
    if (legalName != null) {
      description.add(' with legalName "$legalName"');
    }
    if (displayName != null) {
      description.add(' with displayName "$displayName"');
    }
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! EntityProfile) {
      return description.add('was not an EntityProfile (${item?.runtimeType})');
    }
    final List<String> reasons = <String>[];
    if (legalName != null && item.legalName != legalName) {
      reasons.add('legalName was "${item.legalName}"');
    }
    if (displayName != null && item.displayName != displayName) {
      reasons.add('displayName was "${item.displayName}"');
    }
    return description.add(reasons.join(', '));
  }
}

/// Matches an [Entity] whose [Entity.id] equals [expected].
Matcher hasEntityId(String expected) => _HasEntityId(expected);

class _HasEntityId extends Matcher {
  const _HasEntityId(this.expected);

  final String expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) =>
      item is Entity && item.id == expected;

  @override
  Description describe(Description description) =>
      description.add('has entity id "$expected"');

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) =>
      item is Entity
          ? description.add('had id "${item.id}"')
          : description.add('was not an Entity');
}

/// Matches an [Entity] or [EntityRole] bound to [roleName].
Matcher hasRole(String roleName) => _HasRole(roleName);

class _HasRole extends Matcher {
  const _HasRole(this.roleName);

  final String roleName;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Entity) {
      return item.roles.any((EntityRole r) => r.role.name == roleName);
    }
    if (item is EntityRole) {
      return item.role.name == roleName;
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('has role "$roleName"');

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Entity) {
      final names = item.roles.map((EntityRole r) => r.role.name).join(', ');
      return description.add('had roles [$names]');
    }
    if (item is EntityRole) {
      return description.add('had role "${item.role.name}"');
    }
    return description.add('was not an Entity or EntityRole');
  }
}
