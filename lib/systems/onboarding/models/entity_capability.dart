/// The switchable account focus (unified account, no `both`).
///
/// One Hivorr account holds one focus at a time — [hire] (Explore) or [offer]
/// (Earn) — freely changeable via the Explore/Earn launcher. Switching never
/// destroys earned state: professional roles, bindings, credentials and
/// history survive. [hire] never enters the professional steps; [offer] does.
enum EntityCapability {
  /// "Hire Professionals" — consumer focus; profile-only onboarding.
  hire(
    label: 'Hire Professionals',
    description: 'Find and hire verified experts for projects and tasks.',
    requiresProfessionalWizard: false,
  ),

  /// "Offer Professional Services" — professional focus; full onboarding.
  offer(
    label: 'Offer Professional Services',
    description:
        'Get found by clients, showcase your profession, and win work.',
    requiresProfessionalWizard: true,
  );

  const EntityCapability({
    required this.label,
    required this.description,
    required this.requiresProfessionalWizard,
  });

  /// Primary CTA label.
  final String label;

  /// One-line supporting copy.
  final String description;

  /// Whether the professional steps (industry → profession → identity →
  /// trade proof) are part of this capability's wizard path.
  final bool requiresProfessionalWizard;

  /// Parses a persisted capability string, defaulting to [hire] (Explore) so
  /// older saved positions (written before capabilities existed, or carrying
  /// the retired `both` value) resume on the hiring path — the path that
  /// needs no professional proofs — instead of stranding the user. The
  /// launcher offers the Earn side one tap away.
  static EntityCapability fromName(String? name) =>
      EntityCapability.values
          .where((EntityCapability value) => value.name == name)
          .firstOrNull ??
      EntityCapability.hire;
}

/// Adds [Iterable.firstOrNull] for null-safe lookups above (Dart 3 core
/// contract, kept local to avoid an extension import).
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
