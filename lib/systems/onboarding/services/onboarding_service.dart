// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/entities/onboarding_status.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/entity_repository.dart';
import 'package:hivorr/data/repositories/onboarding_repository.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show SpanStatus, ISentrySpan;

/// Thin orchestration facade for the EP-02-18 wizard (plan §5.4).
///
/// Consumed **only** by [OnboardingProvider] — never imported by widgets. It
/// composes the existing data-layer facades (`EntityRepository`,
/// `TaxonomyProvider`, `IdentityVerificationService`,
/// `TradeVerificationService`, `StorageService`) plus the
/// [OnboardingProgressStore] and the [OnboardingRepository]; it does not
/// re-implement any transport, and the only RPC wrappers added for onboarding
/// are `entity_profession_bind` and the authoritative
/// `entity_onboarding_status_*` pair.
///
/// The [OnboardingRepository] is the **authority** for completion: the local
/// store remains a cache-only resume position, and the route guard prefers
/// [serverCompleted] over the derived [OnboardingProgress.isComplete]. When no
/// repository is wired (unit/widget seams), the facade degrades to the
/// legacy local-only behavior so the wizard still works without a backend.
///
/// All operations propagate normalized [ApiException]s (and
/// [StorageValidationException] as `PLT003`) — raw Supabase/Dio exceptions
/// never cross this boundary.
class OnboardingService {
  /// Creates the facade from its composed dependencies.
  OnboardingService({
    required OnboardingProgressStore store,
    required EntityRepository entityRepository,
    required TaxonomyProvider taxonomy,
    required IdentityVerificationService identityVerification,
    required TradeVerificationService tradeVerification,
    required StorageService storage,
    OnboardingRepository? onboardingRepository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _store = store,
       _entityRepository = entityRepository,
       _taxonomy = taxonomy,
       _identityVerification = identityVerification,
       _tradeVerification = tradeVerification,
       _storage = storage,
       _onboardingRepository = onboardingRepository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final OnboardingProgressStore _store;
  final EntityRepository _entityRepository;
  final TaxonomyProvider _taxonomy;
  final IdentityVerificationService _identityVerification;
  final TradeVerificationService _tradeVerification;
  final StorageService _storage;
  final OnboardingRepository? _onboardingRepository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  OnboardingProgress? _progress;

  /// Whether the server-authoritative status was resolved for the active
  /// session. `false` until the first [resume] round-trip (or when the
  /// repository is absent / the fetch failed and we fell back to cache).
  bool _serverHydrated = false;

  /// The server-authoritative completion flag (`entities.onboarding_completed_at
  /// is not null`), or `null` while unknown.
  bool? _serverCompleted;

  /// The in-memory wizard position, or `null` before [loadProgress]/[resume].
  OnboardingProgress? get progress => _progress;

  /// The furthest step reached for the active session, if hydration happened.
  OnboardingStepCode? get currentStep => _progress?.step;

  /// Whether the server-authoritative completion flag has been resolved.
  bool get serverHydrated => _serverHydrated;

  /// The server-authoritative completion flag, or `null` while unknown. The
  /// route guard prefers this over [OnboardingProgress.isComplete] (Rule 2/3).
  bool? get serverCompleted => _serverCompleted;

  /// Whether a non-complete progress row exists for [entityId].
  ///
  /// Used by the post-auth entry guard to decide between `/onboarding`
  /// (resume) and the placeholder home.
  Future<bool> isResumable(String entityId) async {
    final OnboardingProgress? saved = await _store.read(entityId);
    return saved != null && !saved.isComplete;
  }

  /// Hydrates the wizard position for [entityId] (plan §5.5).
  ///
  /// The **server is authoritative**: when an [OnboardingRepository] is wired,
  /// the status is fetched first (Rule 2). A completed server response
  /// synthesizes a complete progress and write-through caches it — this is the
  /// fix for refresh/relaunch regressions, where the volatile local store was
  /// the only completion record. Offline/transient fetch failures degrade to
  /// the local store (cache-only) without marking the state authoritative.
  /// When nothing is saved, a fresh progress at `capability` is started (not
  /// persisted until the first [advance]) — identity basics were captured at
  /// registration, so the wizard never asks for them again. Tracing
  /// `onboarding.resume.duration` wraps the hydration.
  Future<OnboardingStepCode> resume(String entityId) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'onboarding.resume',
      'onboarding',
    );
    try {
      OnboardingProgress? progress = await _serverHydrate(entityId);
      progress ??= await _store.read(entityId);
      _progress = progress ?? OnboardingProgress(entityId: entityId);
      final OnboardingStepCode step = _progress!.step;
      _logger?.info('Onboarding progress hydrated', <String, Object?>{
        'entityId': _redactor.redact(entityId),
        'step': step.name,
        'isComplete': _progress!.isComplete,
        'isCompleteAuthoritative': _serverCompleted,
      });
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return step;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Onboarding progress hydration failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'entityId': _redactor.redact(entityId)},
      );
      rethrow;
    }
  }

  /// Resolves the server-authoritative completion for [entityId].
  ///
  /// When the repository is absent this is a no-op returning `null` (legacy
  /// local-only seam). A completed server state returns a synthesized
  /// [OnboardingProgress] (capability + full step set from the server),
  /// write-through-cached so subsequent local-only hydration agrees.
  /// Transient [ApiException]s (offline, transport) fall back to the store
  /// with `_serverCompleted` left unknown.
  Future<OnboardingProgress?> _serverHydrate(String entityId) async {
    final OnboardingRepository? repo = _onboardingRepository;
    if (repo == null) {
      _serverHydrated = false;
      _serverCompleted = null;
      return null;
    }
    try {
      final OnboardingStatus status = await repo.getStatus();
      _serverHydrated = true;
      _serverCompleted = status.completed;
      if (!status.completed) {
        return null;
      }
      final EntityCapability capability =
          status.capability ?? EntityCapability.both;
      final OnboardingProgress complete = OnboardingProgress(
        entityId: entityId,
        capability: capability,
        step: capability.requiresProfessionalWizard
            ? OnboardingStepCode.tradeProof
            : OnboardingStepCode.capability,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.capability,
          if (capability.requiresProfessionalWizard) ...<OnboardingStepCode>[
            OnboardingStepCode.industry,
            OnboardingStepCode.identityDocument,
            OnboardingStepCode.tradeProof,
          ],
        ],
      );
      await _store.save(complete);
      _logger?.info(
        'Onboarding completion hydrated from server authority',
        <String, Object?>{
          'entityId': _redactor.redact(entityId),
          'capability': capability.name,
        },
      );
      return complete;
    } on ApiException {
      // Network/transient — degrade to the local cache without trusting it
      // for completion. serverCompleted stays null so the guard fails
      // closed (never force-redirects nor skips onboarding on unknown state
      // that cannot be resolved).
      _serverHydrated = false;
      _serverCompleted = null;
      return null;
    }
  }

  /// Advances one step along the capability path and persists (plan §5.4).
  ///
  /// `capability → industry (incl. profession) → identityDocument →
  /// tradeProof` for professional/`both` entities; a hire-only entity finishes
  /// right after the capability step (industry/profession/verification are
  /// never on its path). Reaching the end first stamps completion
  /// **server-side** via `entity_onboarding_status_update` (the
  /// [OnboardingRepository] is the completion authority); only once the server
  /// accepts does the local position finish (`isComplete` becomes `true`, the
  /// shell then routes to the complete screen). A server rejection (`PLT003`,
  /// e.g. a missing required step) propagates before any local advance, so the
  /// wizard stays resumable on the final step. Never skips a required step.
  Future<void> advance() async {
    final OnboardingProgress? p = _progress;
    if (p == null || p.isComplete) {
      return;
    }
    final OnboardingStepCode? next = p.nextStep;
    if (next == null) {
      await _completeOnServer(p.capability);
    }
    final OnboardingProgress updated = next == null
        ? p.finish()
        : p.advanceTo(next);
    _progress = updated;
    await _persist(updated, 'onboarding.step.${p.step.ordinal + 1}.duration');
  }

  /// Records the entity's capability choice and advances past the decision.
  ///
  /// The capability is persisted **server-side first**
  /// (`entity_onboarding_status_update`) as soon as the decision is reached;
  /// a hire choice finishes the wizard in the same RPC (capability-only path,
  /// validated server-side), while professional/`both` choices continue into
  /// industry selection. Only after the server accepts is the local position
  /// advanced/persisted, so the local cache never lies about the authority.
  Future<void> selectCapability(EntityCapability capability) async {
    final OnboardingProgress? p = _progress;
    if (p == null) {
      return;
    }
    await _completeOrPersistCapability(capability);
    final OnboardingProgress chosen = p.withCapability(capability);
    final OnboardingStepCode? next = chosen.nextStep;
    final OnboardingProgress updated = next == null
        ? chosen.finish()
        : chosen.advanceTo(next);
    _progress = updated;
    await _persist(updated, 'onboarding.step.capability.duration');
  }

  /// Persists [capability] (and, for a hire-only choice, completion) on the
  /// server via [OnboardingRepository.update].
  Future<void> _completeOrPersistCapability(EntityCapability capability) async {
    final OnboardingRepository? repo = _onboardingRepository;
    if (repo == null) {
      _serverHydrated = false;
      _serverCompleted = null;
      return;
    }
    final OnboardingStatus status = await repo.update(
      capability: capability,
      completed: !capability.requiresProfessionalWizard,
    );
    _serverHydrated = true;
    _serverCompleted = status.completed;
  }

  /// Stamps server-side completion via [OnboardingRepository.update].
  ///
  /// No-op when no repository is wired (legacy local-only seam). The server
  /// re-verifies every required step (the registration-hydrated profile row,
  /// `capability`, and for offer/both: professional role, profession bind,
  /// identity document, trade proof) and raises `PLT003` when incomplete —
  /// that propagates unchanged.
  Future<void> _completeOnServer(EntityCapability capability) async {
    final OnboardingRepository? repo = _onboardingRepository;
    if (repo == null) {
      _serverHydrated = false;
      _serverCompleted = null;
      return;
    }
    final OnboardingStatus status = await repo.update(completed: true);
    _serverHydrated = true;
    _serverCompleted = status.completed;
    _logger?.info(
      'Onboarding completion stamped server-side',
      <String, Object?>{
        'capability': capability.name,
        'completed': status.completed,
      },
    );
  }

  /// Steps back one position and persists.
  Future<void> back() async {
    final OnboardingProgress? p = _progress;
    if (p == null) {
      return;
    }
    final OnboardingProgress updated = p.stepBack();
    _progress = updated;
    await _persist(updated, 'onboarding.step.back');
  }

  /// Persists the current position without changing it (lifecycle save).
  ///
  /// Used on app background/termination (FV-15). Deliberately does **not** set
  /// the [OnboardingProgress.exited] flag — an interrupted session resumes
  /// automatically, while only an explicit exit does.
  Future<void> exitAndSave() async {
    final OnboardingProgress? p = _progress;
    if (p == null) {
      return;
    }
    await _persist(p, 'onboarding.exit');
  }

  /// Explicit wizard exit (Save & exit, FV-37): persists the position and marks
  /// [OnboardingProgress.exited] so the guard stops force-resuming the wizard
  /// and the home screen offers "Continue registration".
  Future<void> exitWizard() async {
    final OnboardingProgress? p = _progress;
    if (p == null) {
      return;
    }
    final OnboardingProgress exited = p.withExited(true);
    _progress = exited;
    await _persist(exited, 'onboarding.exit.wizard');
  }

  /// Clears the exit flag so the resume gate re-engages ("Continue registration"
  /// from home). Position is untouched — the wizard resumes at [currentStep].
  Future<void> continueRegistration() async {
    final OnboardingProgress? p = _progress;
    if (p == null) {
      return;
    }
    final OnboardingProgress resumed = p.withExited(false);
    _progress = resumed;
    await _persist(resumed, 'onboarding.resume');
  }

  /// Writes profile data: avatar upload → profile RPC → avatar_path
  /// update (DoD TT-04 call order; plan §5.4, §5.6).
  ///
  /// Not part of the onboarding wizard anymore — identity is captured at
  /// registration — but retained as the profile-write orchestration for the
  /// Profile/Edit Profile experience (bio and avatar are optional profile
  /// concerns, never onboarding blockers). Split-identity parameters
  /// ([firstName]/[lastName] etc) are preferred; legacy [legalName] is kept
  /// for backward compatibility. When [avatarBytes] is provided the avatar is uploaded first to the
  /// canonical `profile-avatars/{entityId}/avatar.{ext}` path (`upsert: true`),
  /// validated against the profile-avatar rules (5 MiB, `jpeg/png/webp`) before
  /// any network call. Then the profile is written via `entity_profile_update`
  /// and, when an avatar path exists, persisted through the self-scoped REST
  /// update. [StorageValidationException] propagates as an inline field error.
  Future<EntityProfile> completeProfile({
    required String entityId,
    String? legalName,
    String? displayName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? phoneNumber,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarFileName,
    String? avatarMimeType,
    void Function(int sent, int total)? onAvatarProgress,
  }) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'onboarding.step.profile.submit',
      'onboarding',
    );
    _logger?.info('Profile submission started', <String, Object?>{
      'entityId': _redactor.redact(entityId),
      'byteLength': avatarBytes?.length,
      'mimeType': avatarMimeType,
    });
    try {
      String? avatarPath;
      if (avatarBytes != null) {
        final String mime = avatarMimeType ?? 'image/jpeg';
        _storage.validateForBucket(
          bucket: StorageBuckets.profileAvatars,
          mimeType: mime,
          byteLength: avatarBytes.length,
        );
        final String extension = _extensionFor(mime, avatarFileName);
        avatarPath = await _storage.upload(
          bucket: StorageBuckets.profileAvatars,
          path: StoragePaths.avatar(entityId: entityId, ext: extension),
          bytes: avatarBytes,
          mimeType: mime,
          fileName: avatarFileName,
          onProgress: onAvatarProgress,
          upsert: true,
        );
      }

      final String? resolvedLegalName =
          legalName ??
          (firstName != null && lastName != null
              ? (middleName != null && middleName.trim().isNotEmpty
                    ? '${firstName.trim()} ${middleName.trim()} ${lastName.trim()}'
                    : '${firstName.trim()} ${lastName.trim()}')
              : null);
      final EntityProfile profile = await _entityRepository.updateProfile(
        entityId: entityId,
        legalName: resolvedLegalName,
        displayName: displayName,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        bio: bio,
      );

      final EntityProfile withAvatar;
      if (avatarPath != null) {
        withAvatar = await _entityRepository.updateAvatarPath(
          entityId: entityId,
          avatarPath: avatarPath,
        );
      } else {
        withAvatar = profile;
      }

      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('Profile submission completed', <String, Object?>{
        'entityId': _redactor.redact(entityId),
        'hasAvatar': avatarPath != null,
      });
      return withAvatar;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Profile submission failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'entityId': _redactor.redact(entityId)},
      );
      rethrow;
    }
  }

  /// Binds the selected profession via `entity_profession_bind` (plan §5.4).
  ///
  /// Validates that the taxonomy selection matches [industryId]/[professionId]
  /// first. `PLT005` (duplicate binding) and `PLT004` (missing/inactive)
  /// surface unchanged as normalized [ApiException]s for inline guidance.
  Future<void> bindProfession({
    required String industryId,
    required String professionId,
  }) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'onboarding.step.profession.bind',
      'onboarding',
    );
    _logger?.info('Profession binding started', <String, Object?>{
      'entityId': _redactor.redact(_progress?.entityId ?? ''),
      'industryId': _redactor.redact(industryId),
      'professionId': _redactor.redact(professionId),
    });
    try {
      final bool valid =
          _taxonomy.selectedIndustry?.id == industryId &&
          _taxonomy.selectedProfession?.id == professionId;
      if (!valid) {
        throw const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Select a profession to continue.',
          code: 'PLT003',
        );
      }
      await _entityRepository.bindProfession(professionId: professionId);
      // Binding a profession is the professional-capability commitment —
      // activate the fluid `professional` role (idempotent upsert RPC).
      await _entityRepository.activateRole(
        entityId: _progress?.entityId ?? '',
        role: 'professional',
      );
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('Profession binding completed', <String, Object?>{
        'professionId': _redactor.redact(professionId),
        'professionalRoleActive': true,
      });
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Profession binding failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'professionId': _redactor.redact(professionId),
        },
      );
      rethrow;
    }
  }

  /// Submits an identity document, delegating 1:1 to
  /// [IdentityVerificationService] (plan §5.4).
  ///
  /// On success the UX-only mirror flag is set in the persisted progress; the
  /// verification status itself remains the server authority.
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'onboarding.submit.identity',
      'onboarding',
    );
    try {
      final VerificationSubmission submission = await _identityVerification
          .submitIdentityDocument(
            documentType: documentType,
            bytes: bytes,
            mimeType: mimeType,
            fileName: fileName,
            onProgress: onProgress,
          );
      final OnboardingProgress? p = _progress;
      if (p != null) {
        final OnboardingProgress marked = p.withIdentitySubmission(true);
        _progress = marked;
        await _persist(marked, 'onboarding.submit.identity');
      }
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return submission;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Identity submission failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Submits a trade proof, delegating 1:1 to [TradeVerificationService]
  /// (plan §5.4). The proof is bound to [professionId].
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      'onboarding.submit.trade.proof',
      'onboarding',
    );
    try {
      final VerificationSubmission submission = await _tradeVerification
          .submitTradeProof(
            type: type,
            professionId: professionId,
            bytes: bytes,
            mimeType: mimeType,
            fileName: fileName,
            onProgress: onProgress,
          );
      final OnboardingProgress? p = _progress;
      if (p != null) {
        final OnboardingProgress marked = p.withTradeProofSubmission(true);
        _progress = marked;
        await _persist(marked, 'onboarding.submit.trade.proof');
      }
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return submission;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Trade proof submission failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Refreshes `isTradeGateOpen` from the server authority
  /// (plan §5.4; AGENT.md Rule 2).
  ///
  /// Returns whether bidding is unlocked — `true` only when the trade
  /// verification status is `approved` for [professionId] (defaults to the
  /// taxonomy-selected profession when omitted).
  Future<bool> refreshTradeGate({String? professionId}) async {
    final TradeVerificationStatus status = await _tradeVerification.getStatus();
    final String id = professionId ?? _taxonomy.selectedProfession?.id ?? '';
    final bool open = id.isEmpty ? false : status.kindFor(id).canBid;
    _logger?.info('Trade gate refreshed', <String, Object?>{
      'entityId': _redactor.redact(_progress?.entityId ?? ''),
      'isTradeGateOpen': open,
    });
    return open;
  }

  /// Disposes the in-memory position (memory hygiene; playback is re-hydrated).
  void disposeProgress() => _progress = null;

  Future<void> _persist(OnboardingProgress progress, String traceName) async {
    final ISentrySpan? span = _tracer?.startTransaction(
      traceName,
      'onboarding',
    );
    try {
      await _store.save(progress);
      _logger?.info('Onboarding progress persisted', <String, Object?>{
        'entityId': _redactor.redact(progress.entityId),
        'step': progress.step.name,
        'isComplete': progress.isComplete,
      });
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Onboarding progress persistence failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'step': progress.step.name},
      );
      rethrow;
    }
  }

  /// Maps a MIME type to the canonical extension for `avatar.{ext}`.
  static String _extensionFor(String mimeType, String? fileName) {
    final String? fromName = fileName == null
        ? null
        : fileName.contains('.')
        ? fileName.split('.').last
        : null;
    final String ext = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => fromName ?? 'jpeg',
    };
    final String safe = StoragePaths.sanitize(ext);
    return safe.isEmpty ? 'jpeg' : safe;
  }
}
