/// Pure Dart domain model for a tier-1 Industry in the two-tier taxonomy.
///
/// Mirrors the `industries` table columns (EP-02-01/EP-02-07) without any
/// framework or backend dependency. No business logic is present.
///
/// See also: `documents/Context/AGENT.md` Rule 2 (Industry → Profession) and
/// the EP-02-07 implementation plan §7.1.
class Industry {
  const Industry({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
  });

  /// Primary key (UUID).
  final String id;

  /// SEO-stable, globally unique slug (`^[a-z0-9]+(-[a-z0-9]+)*$`).
  final String slug;

  /// Display name (`1-255` chars).
  final String name;

  /// Optional descriptive text.
  final String? description;

  /// Whether the industry is active (soft gate; filtered by default).
  final bool isActive;

  /// Display order (increments of 10).
  final int sortOrder;

  /// Audit timestamp.
  final DateTime? createdAt;
}
