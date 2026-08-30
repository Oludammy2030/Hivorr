/// Pure Dart domain model for a tier-2 Profession in the two-tier taxonomy.
///
/// Mirrors the `professions` table columns (EP-02-01/EP-02-07) — including the
/// `industry_id` foreign key used by the hierarchical `Industry → Profession`
/// constraint (AGENT.md Rule 2). No framework or backend dependency and no
/// business logic are present.
///
/// See also: EP-02-07 implementation plan §7.2.
class Profession {
  const Profession({
    required this.id,
    required this.industryId,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
  });

  /// Primary key (UUID).
  final String id;

  /// FK → [Industry.id] (ON DELETE RESTRICT).
  final String industryId;

  /// SEO-stable, globally unique slug.
  final String slug;

  /// Display name.
  final String name;

  /// Optional descriptive text.
  final String? description;

  /// Whether the profession is active (soft gate).
  final bool isActive;

  /// Display order, scoped to the owning industry.
  final int sortOrder;

  /// Audit timestamp.
  final DateTime? createdAt;
}
