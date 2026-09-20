// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

// Re-exported for UI convenience (kept in the data layer for the ChangeNotifier).
export 'package:hivorr/data/providers/submit_state.dart';

/// Provider exposing the EP-02-18 wizard state to the widget tree (plan §5.3).
///
/// A thin state mirror over [OnboardingService] — it owns no transport and
/// re-throws nothing. Every mutation updates [progress]/[submitState]/
/// [lastError] and calls `notifyListeners()`. The [WidgetsBindingObserver]
/// lifecycle hook persists progress on app background/termination so the
/// wizard always resumes (FV-15).
class OnboardingProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service]; [logger] enables PII-safe logs.
  OnboardingProvider({required OnboardingService service, HivorrLogger? logger})
    : _service = service,
      _logger = logger {
    WidgetsBinding.instance.addObserver(this);
  }

  final OnboardingService _service;
  final HivorrLogger? _logger;

  String? _entityId;
  OnboardingProgress? _progress;
  SubmitState _submitState = SubmitState.idle;
  ApiException? _lastError;
  bool? _isTradeGateOpen;

  /// The active wizard position, or `null` before [loadProgress].
  OnboardingProgress? get progress => _progress;

  /// The current (furthest) step code.
  OnboardingStepCode? get currentStep => _progress?.step;

  /// Whether all five wizard steps are complete (derived from the local
  /// resume position).
  bool get isComplete => _progress?.isComplete ?? false;

  /// The server-authoritative completion flag
  /// (`entities.onboarding_completed_at is not null`), or `null` until the
  /// status is resolved for the active session (or the fetch failed and the
  /// service degraded to the local cache).
  ///
  /// The route guard prefers this over [isComplete]: the backend — not the
  /// volatile local store — decides whether onboarding is truly finished
  /// (Rule 2/3), fixing the refresh/relaunch regression.
  bool? get isCompleteAuthoritative => _service.serverCompleted;

  /// Whether the server-authoritative status has been resolved for the active
  /// session. `false` until the first [loadProgress] round-trip completes (or
  /// when no repository is wired and the service fell back to local-only).
  bool get serverHydrated => _service.serverHydrated;

  /// The owning entity id for progress keying.
  String? get entityId => _entityId;

  /// Whether the wizard was deliberately exited (Save & exit). Drives the home
  /// "Continue registration" affordance and suppresses the guard's resume
  /// redirect while `true`.
  bool get exited => _progress?.exited ?? false;

  /// Current submit lifecycle state (drives CTA spinners).
  SubmitState get submitState => _submitState;

  /// Whether a submit operation is in flight.
  bool get isBusy => _submitState == SubmitState.submitting;

  /// The error from the last failed operation.
  ApiException? get lastError => _lastError;

  /// Whether bidding is unlocked per the server authority (`approved`), or
  /// `null` before the first [refreshGateStatus].
  bool? get isTradeGateOpen => _isTradeGateOpen;

  /// Hydrates the wizard for [entityId] — the resume point (plan §5.5).
  ///
  /// Passing a [newEntityId] rebinds the progress key (account switch);
  /// otherwise the previously active entity is kept.
  Future<void> loadProgress([String? newEntityId]) async {
    final String target = newEntityId ?? _entityId ?? '';
    if (target.isEmpty) {
      return;
    }
    await _runAsSubmit(() async {
      _entityId = target;
      await _service.resume(target);
    });
  }

  /// Alias of [loadProgress] for the exit-then-return flow.
  Future<void> resume([String? newEntityId]) => loadProgress(newEntityId);

  /// Advances one step along the capability path and persists (FV-14).
  Future<void> advance() async {
    await _runAsSubmit(() => _service.advance());
  }

  /// Records the entity's capability choice and advances to the profile step.
  Future<void> selectCapability(EntityCapability capability) async {
    await _runAsSubmit(() => _service.selectCapability(capability));
  }

  /// Steps back one position and persists (FV-14).
  Future<void> back() async {
    await _runAsSubmit(() => _service.back());
  }

  /// Persists the current position without moving (exit protocol, FV-15).
  Future<void> saveAndExit() async {
    await _runAsSubmit(() => _service.exitAndSave());
  }

  /// Explicit wizard exit: persists the position and marks the wizard
  /// [exited], so home offers "Continue registration" instead of the guard
  /// force-resuming the wizard.
  Future<void> exitWizard() async {
    await _runAsSubmit(() => _service.exitWizard());
  }

  /// Clears the exit flag ("Continue registration" from home) so the resume
  /// gate re-engages and the wizard resumes at its saved step.
  Future<void> continueRegistration() async {
    await _runAsSubmit(() => _service.continueRegistration());
  }

  /// Completes the profile step (avatar upload → RPC → avatar_path persist).
  ///
  /// Split-identity variant preferred (registration restructuring).
  Future<void> completeProfile({
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
    final String entityId = _entityId ?? _progress?.entityId ?? '';
    await _runAsSubmit(
      () => _service.completeProfile(
        entityId: entityId,
        legalName: legalName,
        displayName: displayName,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        bio: bio,
        avatarBytes: avatarBytes,
        avatarFileName: avatarFileName,
        avatarMimeType: avatarMimeType,
        onAvatarProgress: onAvatarProgress,
      ),
    );
  }

  /// Binds the selected profession via `entity_profession_bind` (FV-21).
  Future<void> bindProfession({
    required String industryId,
    required String professionId,
  }) async {
    await _runAsSubmit(
      () => _service.bindProfession(
        industryId: industryId,
        professionId: professionId,
      ),
    );
  }

  /// Submits an identity document (FV-22, FV-25).
  Future<void> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _runAsSubmit(
      () => _service.submitIdentityDocument(
        documentType: documentType,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      ),
    );
  }

  /// Submits a trade proof bound to [professionId] (FV-23, FV-25).
  Future<void> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _runAsSubmit(
      () => _service.submitTradeProof(
        type: type,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      ),
    );
  }

  /// Refreshes `isTradeGateOpen` from the server (FV-26).
  Future<void> refreshGateStatus({String? professionId}) async {
    await _runAsSubmit(() async {
      _isTradeGateOpen = await _service.refreshTradeGate(
        professionId: professionId,
      );
    });
  }

  Future<void> _runAsSubmit(Future<void> Function() action) async {
    _submitState = SubmitState.submitting;
    _lastError = null;
    notifyListeners();
    try {
      await action();
      _progress = _service.progress;
      _submitState = SubmitState.success;
    } on ApiException catch (e) {
      _lastError = e;
      _submitState = SubmitState.error;
      _logger?.warning('Onboarding operation failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } on Object catch (e) {
      _lastError = ApiException(
        kind: ApiExceptionKind.unknown,
        message: 'Something went wrong. Please try again.',
      );
      _submitState = SubmitState.error;
      _logger?.error('Onboarding operation failed unexpectedly', error: e);
    }
    _progress = _service.progress;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(saveAndExit());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.disposeProgress();
    super.dispose();
  }
}
