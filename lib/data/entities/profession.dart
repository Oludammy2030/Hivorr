/// Pure Dart domain model for the two-tier taxonomy tier-2: a `profession`.
///
/// Mirrors the `professions` table (EP-01-06). A profession always belongs to
/// exactly one [industryId] (`ON DELETE RESTRICT`). Holds data and getters
/// only — no business logic (AGENT.md Rule 2, EP-02-07 plan §5.2).
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

  /// The `professions.id` UUID.
  final String id;

  /// The owning `industries.id` (FK, `ON DELETE RESTRICT`).
  final String industryId;

  /// Globally-unique, SEO-stable lowercase kebab-case slug.
  final String slug;

  /// Display name.
  final String name;

  /// Optional description.
  final String? description;

  /// Soft activation switch.
  final bool isActive;

  /// Server-provided ordering (`sort_order ASC`).
  final int sortOrder;

  /// Optional creation timestamp.
  final DateTime? createdAt;
}
