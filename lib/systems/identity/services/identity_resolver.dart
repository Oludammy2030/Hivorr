import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/public_profession.dart';

/// Which identity source won resolution (identity audit Phase 3).
///
/// Display-only provenance for debugging and tests — never persisted, never
/// shown to end users as-is.
enum IdentityKind {
  /// An admin-approved professional name for the relevant profession.
  professionalApproved,

  /// A verified business trading name (approved business + authorized rep).
  businessVerified,

  /// A verified individual name (KYC-backed).
  individualVerified,

  /// A derived fallback (`first + last` / profile display name).
  derived,
}

/// A resolved face for one participant in one context.
class ResolvedIdentity {
  const ResolvedIdentity({required this.name, required this.kind});

  /// The name to display.
  final String name;

  /// Where it came from.
  final IdentityKind kind;
}

/// Centralized context-aware identity resolution (identity audit Phase 3).
///
/// Pure-Dart, no I/O: callers supply already-authorized records and this
/// class picks the appropriate face per the founder-approved fallback order:
///
/// professional: approved professional name → derived display name.
/// client: verified business trading name → verified individual name →
/// derived display name.
///
/// Unverified business names NEVER display (a typed name is not proof of
/// registration). Legal names never display (verification/admin room only).
/// Freezing the resolved value onto engagement rows (snapshots) is the
/// caller's job — see `job_applications.applicant_display_name` precedent.
abstract final class IdentityResolver {
  /// Resolves the professional face a client (or any viewer) should see.
  ///
  /// [approvedProfessionalName] is the binding's approved name for the
  /// relevant profession (`null` when never supplied); [fallbackDisplayName]
  /// is the derived profile display name. Empty/blank inputs fall through.
  static ResolvedIdentity professionalFace({
    String? approvedProfessionalName,
    required String fallbackDisplayName,
  }) {
    final String approved = approvedProfessionalName?.trim() ?? '';
    if (approved.isNotEmpty) {
      return ResolvedIdentity(
        name: approved,
        kind: IdentityKind.professionalApproved,
      );
    }
    return ResolvedIdentity(
      name: fallbackDisplayName,
      kind: IdentityKind.derived,
    );
  }

  /// Resolves the client face a professional should see.
  ///
  /// [business] is the engagement's business when the client hires on its
  /// behalf (`null` for personal hiring). Its trading name displays only
  /// when the business is verified AND the viewer-facing membership is
  /// authorized; otherwise (pending/rejected/unlinked) the individual face
  /// applies. [individualName] is the personal name; [individualVerified]
  /// marks it KYC-backed (else it is a derived fallback).
  static ResolvedIdentity clientFace({
    Business? business,
    required String individualName,
    bool individualVerified = false,
  }) {
    if (business != null &&
        business.isVerified &&
        (business.membership?.isAuthorized ?? false) &&
        business.tradingName.trim().isNotEmpty) {
      return ResolvedIdentity(
        name: business.tradingName.trim(),
        kind: IdentityKind.businessVerified,
      );
    }
    return ResolvedIdentity(
      name: individualName,
      kind: individualVerified
          ? IdentityKind.individualVerified
          : IdentityKind.derived,
    );
  }

  /// Resolves the headline name for a public professional profile.
  ///
  /// Prefers the primary profession's approved name, then the first named
  /// approved profession, then the profile display name. Public projections
  /// only ever carry approved bindings, so any present name is approved by
  /// construction.
  static ResolvedIdentity publicProfileHeadline({
    required String displayName,
    required List<PublicProfession> professions,
  }) {
    final List<PublicProfession> ordered = <PublicProfession>[
      ...professions.where((PublicProfession p) => p.isPrimary),
      ...professions.where((PublicProfession p) => !p.isPrimary),
    ];
    for (final PublicProfession profession in ordered) {
      final String? approved = profession.professionalDisplayName?.trim();
      if (approved != null && approved.isNotEmpty) {
        return ResolvedIdentity(
          name: approved,
          kind: IdentityKind.professionalApproved,
        );
      }
    }
    return ResolvedIdentity(name: displayName, kind: IdentityKind.derived);
  }

  /// Resolves both faces of an engagement from the viewer's side.
  ///
  /// When [viewerIsClient] is true, `self` is the client face and `other` is
  /// the professional face; otherwise mirrored. Role reversal across
  /// engagements therefore resolves correctly with no account changes.
  static ({ResolvedIdentity self, ResolvedIdentity other})
  forEngagement({
    required bool viewerIsClient,
    String? approvedProfessionalName,
    required String professionalFallback,
    Business? clientBusiness,
    required String clientIndividualName,
    bool clientIndividualVerified = false,
  }) {
    final ResolvedIdentity professional = professionalFace(
      approvedProfessionalName: approvedProfessionalName,
      fallbackDisplayName: professionalFallback,
    );
    final ResolvedIdentity client = clientFace(
      business: clientBusiness,
      individualName: clientIndividualName,
      individualVerified: clientIndividualVerified,
    );
    return viewerIsClient
        ? (self: client, other: professional)
        : (self: professional, other: client);
  }
}
