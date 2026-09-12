/// The onboarding capability decision (EP-02-18 correction).
///
/// Mirrors the Universal Entity Principle: one account, fluid roles — the
/// wizard asks what the entity wants to do, then activates only the matching
/// [EntityRole]s. [hire] never enters the professional steps; [offer] and
/// [both] do.
enum EntityCapability {
  /// "Hire Professionals" — consumer role; profile-only onboarding.
  hire(
    label: 'Hire Professionals',
    description: 'Find and hire verified experts for projects and tasks.',
    requiresProfessionalWizard: false,
  ),

  /// "Offer Professional Services" — professional role; full onboarding.
  offer(
    label: 'Offer Professional Services',
    description: 'Get found by clients, showcase your profession, and win work.',
    requiresProfessionalWizard: true,
  ),

  /// "Both" — consumer + professional roles; full onboarding.
  both(
    label: 'Do both',
    description: 'Hire experts and offer your own professional services.',
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

  /// Parses a persisted capability string, defaulting to [both] so older saved
  /// wizard positions (written before capabilities existed) resume safely on
  /// the professional path rather than stranding the user mid-wizard.
  static EntityCapability fromName(String? name) => EntityCapability.values
      .where((EntityCapability value) => value.name == name)
      .firstOrNull ??
      EntityCapability.both;
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