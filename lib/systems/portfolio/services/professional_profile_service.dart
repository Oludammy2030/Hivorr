// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/systems/portfolio/seo/portfolio_seo_meta.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show SpanStatus, ISentrySpan;

/// Thin orchestration facade for the public professional profile (EP-02-19
/// §5.5). Consumed **only** by [ProfessionalProfileScreen] — never imported by
/// widgets (DoD FV-14, TV-03).
///
/// Composes the data-layer [PortfolioProvider] and derives the read-only
/// view-model fields the screen renders. It never re-implements transport or
/// re-parses envelopes (that stays in the data layer), and it never surfaces
/// raw Supabase/Dio exceptions — every failure propagates as a normalized
/// [ApiException] (`PLT004` → not-found UI state, network → retry).
///
/// == RPC contract ==
/// `portfolio_public_profile_get(p_entity_id)` (SECURITY DEFINER, STABLE)
/// returns the whitelisted projection: entity + profile display fields (never
/// `legal_name`), approved professions/credentials (never `document_path`),
/// KYC tier code/status (never limits), and the owner-managed `portfolio_items`
/// showcase. `PLT004` maps to `null` at the repository boundary.
///
/// == Redaction policy ==
/// Logs carry the `entityId` suffix only — never `displayName`, bio, or
/// avatar/media paths in full; no payload logging (SV-08).
class ProfessionalProfileService {
  /// Creates the facade from its composed dependencies.
  ProfessionalProfileService({
    required PortfolioProvider provider,
    StorageService? storage,
    String seoBaseUrl = '',
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _provider = provider,
       _storage = storage,
       _seoBaseUrl = seoBaseUrl,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final PortfolioProvider _provider;
  final StorageService? _storage;
  final String _seoBaseUrl;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// Delegate accessors onto the provider (the widget tree also listens to
  /// [PortfolioProvider] directly for rebuilds).
  PortfolioLoadState get state => _provider.state;

  bool get isLoading => _provider.isLoading;

  bool get isLoaded => _provider.isLoaded;

  /// The loaded profile, or `null` before a successful load.
  PublicProfile? get profile => _provider.profile;

  /// The normalized error from the last failed load.
  ApiException? get lastError => _provider.lastError;

  /// Approved professions from the payload (badges).
  List<PublicProfession> get professions =>
      profile?.professions ?? const <PublicProfession>[];

  /// Approved credentials from the payload (widgets render these as read-only
  /// cards — the RPC already filtered to `verification_status = 'approved'`).
  List<PublicCredential> get credentials =>
      profile?.credentials ?? const <PublicCredential>[];

  /// The profile's primary profession (`is_primary` first, else the first
  /// approved profession), for badge emphasis and SEO fallback.
  PublicProfession? get primaryProfession {
    final PublicProfile? p = profile;
    if (p == null) return null;
    for (final PublicProfession entry in p.professions) {
      if (entry.isPrimary) {
        return entry;
      }
    }
    return p.professions.firstOrNull;
  }

  /// Primary profession display name.
  String? get primaryProfessionName => primaryProfession?.professionName;

  /// Primary profession slug (SEO route segment).
  String? get primaryProfessionSlug => primaryProfession?.professionSlug;

  /// Primary industry display name.
  String? get primaryIndustryName => primaryProfession?.industryName;

  /// Primary industry slug.
  String? get primaryIndustrySlug => primaryProfession?.industrySlug;

  /// Identity verification trust signal (TIP §5.5): true when the payload
  /// carries an approved identity-document credential OR an active KYC tier at
  /// least `tier_1`. Always derived — never fabricated by the UI.
  bool get verifiedIdentity {
    final PublicProfile? p = profile;
    if (p == null) return false;
    for (final PublicCredential credential in p.credentials) {
      if (credential.kind == 'identity_document' &&
          credential.verificationStatus == 'approved') {
        return true;
      }
    }
    return isKycVerified(p.kycTierCode, p.kycStatus);
  }

  /// Trade-verification trust signal: the RPC approved-gate guarantees ≥1
  /// approved profession, so any loaded profile is trade-approved.
  bool get tradeVerified => profile != null && professions.isNotEmpty;

  /// KYC tier code shown as the identity badge subtitle.
  String? get kycTierCode => profile?.kycTierCode;

  /// KYC level status (e.g. `active`); `null` when unassigned.
  String? get kycStatus => profile?.kycStatus;

  /// Count of approved credentials surfaced as a trust badge.
  int get verifiedCredentialCount => credentials.length;

  /// SEO metadata resolved lazily from the payload + injected origin, or `null`
  /// before a successful load. Uses [routeSlug] as the cosmetic fallback when
  /// the payload carries no profession slug.
  PortfolioSeoMeta? seoMeta({String? routeSlug}) {
    final PublicProfile? p = profile;
    if (p == null) return null;
    return PortfolioSeoMetaBuilder.build(
      profile: p,
      baseUrl: _seoBaseUrl,
      routeSlug: routeSlug,
    );
  }

  /// Resolves an optional avatar storage path to its public URL, or `null`
  /// when absent (the avatar widget falls back to initials).
  String? avatarPublicUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    final StorageService? storage = _storage;
    if (storage == null) return null;
    try {
      return storage.getPublicUrl(
        bucket: StorageBuckets.profileAvatars,
        path: avatarPath,
      );
    } on Object {
      return null;
    }
  }

  /// Resolves a portfolio media storage path to its public URL.
  ///
  /// Returns `null` when storage resolution is unavailable (the card then
  /// renders its type placeholder instead of a broken thumbnail).
  String? mediaPublicUrl(String mediaPath) {
    if (mediaPath.isEmpty) return null;
    final StorageService? storage = _storage;
    if (storage == null) return null;
    try {
      return storage.getPublicUrl(
        bucket: StorageBuckets.portfolioItems,
        path: mediaPath,
      );
    } on Object {
      return null;
    }
  }

  /// Loads the public profile for [entityId] (TIP §5.5).
  ///
  /// Delegates to [PortfolioProvider.load]; returns `null` for `PLT004`
  /// (not-found — the same URL, no legal-name leak, SEO-404 semantics).
  /// Network / `PLT003` / `PLT999` propagate as normalized [ApiException]s for
  /// the screen to map to a retry or validation state. Wraps the load in a
  /// `portfolio.public_profile.load` Sentry span and redacted logging.
  Future<PublicProfile?> load(String entityId) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'portfolio.public_profile.load',
      'portfolio',
    );
    _logger?.info('Public profile load started', <String, Object?>{
      'entityIdSuffix': _redactor.redact(entityId),
    });
    try {
      final PublicProfile? result = await _provider.load(entityId);
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('Public profile load completed', <String, Object?>{
        'entityIdSuffix': _redactor.redact(entityId),
        'found': result != null,
        'professions': result?.professions.length ?? 0,
        'credentials': result?.credentials.length ?? 0,
        'portfolioItems': result?.portfolioItems.length ?? 0,
      });
      return result;
    } on Object catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Public profile load failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'entityIdSuffix': _redactor.redact(entityId),
        },
      );
      rethrow;
    }
  }

  /// Whether a KYC tier/status pair resolves to identity-verified.
  ///
  /// Mirrors the server authority: a tier with `isVerified` (≥ `tier_1`)
  /// is only meaningful while the level is `active`.
  bool isKycVerified(String? tierCode, String? status) {
    if (tierCode == null || tierCode.isEmpty) return false;
    if (status != null && status != 'active') return false;
    return KycTier.fromCode(tierCode).isAtLeastVerified;
  }
}

/// [Iterable] helper keeping the service dependency-light.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
