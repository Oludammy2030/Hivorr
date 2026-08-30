/// Pure Dart domain model for the two-tier taxonomy tier-1: an `industry`.
///
/// Mirrors the `industries` table (EP-01-06) without any framework or backend
/// dependency. Holds data and getters only — no business logic (AGENT.md
/// Rule 4, EP-02-07 plan §5.2).
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

  /// The `industries.id` UUID.
  final String id;

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
