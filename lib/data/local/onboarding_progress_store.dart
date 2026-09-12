// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_exception.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// Stability contract for Hive progress persistence (EP-02-18 §5.3).
abstract final class OnboardingProgressBox {
  const OnboardingProgressBox._();

  /// The Hive box holding progress rows.
  static const String name = 'onboarding';
}

/// Builds the `onboarding_progress:{entityId}` storage key (plan §7.1).
String onboardingProgressKey(String entityId) =>
    'onboarding_progress:$entityId';

/// Persistence seam for the resumable wizard position.
///
/// Progress is *client-local position state only* — never trusted verification
/// state. [clear] is used only on deliberate re-onboarding or account switch.
abstract class OnboardingProgressStore {
  /// Reads the progress for [entityId], or `null` when absent.
  Future<OnboardingProgress?> read(String entityId);

  /// Persists [progress] under `onboarding_progress:{progress.entityId}`.
  Future<void> save(OnboardingProgress progress);

  /// Removes any progress for [entityId].
  Future<void> clear(String entityId);
}

/// Default in-memory [OnboardingProgressStore] (tests, unsupported platforms).
class InMemoryOnboardingProgressStore implements OnboardingProgressStore {
  InMemoryOnboardingProgressStore({
    Iterable<OnboardingProgress> seed = const <OnboardingProgress>[],
  }) : _rows = <String, OnboardingProgress>{
         for (final OnboardingProgress progress in seed)
           onboardingProgressKey(progress.entityId): progress,
       };

  final Map<String, OnboardingProgress> _rows;

  @override
  Future<OnboardingProgress?> read(String entityId) async =>
      _rows[onboardingProgressKey(entityId)];

  @override
  Future<void> save(OnboardingProgress progress) async {
    _rows[onboardingProgressKey(progress.entityId)] = progress;
  }

  @override
  Future<void> clear(String entityId) async {
    _rows.remove(onboardingProgressKey(entityId));
  }
}

/// Hive-backed [OnboardingProgressStore] over the EP-01-11 [LocalStore].
///
/// Persists under box [OnboardingProgressBox.name] at key
/// `onboarding_progress:{entityId}`. The entity owns no `json` cycle — a
/// private, store-internal serialization is used (plan §5.3). Degrades
/// gracefully (returns empty / no-ops) when the storage engine is
/// unavailable, so the wizard is never blocked by local I/O.
class HiveOnboardingProgressStore implements OnboardingProgressStore {
  /// Creates the store over [store].
  HiveOnboardingProgressStore({required LocalStore store}) : _store = store;

  final LocalStore _store;

  @override
  Future<OnboardingProgress?> read(String entityId) async {
    try {
      return await _store.read(
        OnboardingProgressBox.name,
        onboardingProgressKey(entityId),
        _progressFromJson,
      );
    } on StorageException {
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(OnboardingProgress progress) async {
    try {
      await _store.write(
        OnboardingProgressBox.name,
        onboardingProgressKey(progress.entityId),
        progress,
        _progressToJson,
      );
    } on StorageException {
      return;
    } on Object {
      return;
    }
  }

  @override
  Future<void> clear(String entityId) async {
    try {
      await _store.remove(
        OnboardingProgressBox.name,
        onboardingProgressKey(entityId),
      );
    } on StorageException {
      return;
    } on Object {
      return;
    }
  }
}

Map<String, dynamic> _progressToJson(OnboardingProgress progress) {
  return <String, dynamic>{
    'entityId': progress.entityId,
    'step': progress.step.name,
    'completedSteps': progress.completedSteps
        .map((OnboardingStepCode step) => step.name)
        .toList(growable: false),
    'capability': progress.capability.name,
    'hasIdentitySubmission': progress.hasIdentitySubmission,
    'hasTradeProofSubmission': progress.hasTradeProofSubmission,
    'updatedAt': progress.updatedAt.millisecondsSinceEpoch,
  };
}

OnboardingProgress _progressFromJson(Map<String, dynamic> json) {
  final Iterable<dynamic> raw =
      json['completedSteps'] as List<dynamic>? ?? const <dynamic>[];
  final List<String> completed =
      raw.map((dynamic e) => e as String).toList(growable: false);
  final int epoch = (json['updatedAt'] as num?)?.toInt() ?? 0;
  return OnboardingProgress(
    entityId: json['entityId'] as String? ?? '',
    step: OnboardingStepCode.values.firstWhere(
      (OnboardingStepCode step) => step.name == json['step'],
      orElse: () => OnboardingStepCode.profile,
    ),
    completedSteps: <OnboardingStepCode>[
      for (final String name in completed)
        OnboardingStepCode.values.firstWhere(
          (OnboardingStepCode step) => step.name == name,
          orElse: () => OnboardingStepCode.profile,
        ),
    ],
    capability: EntityCapability.fromName(
      json['capability'] as String?,
    ),
    hasIdentitySubmission: json['hasIdentitySubmission'] as bool? ?? false,
    hasTradeProofSubmission:
        json['hasTradeProofSubmission'] as bool? ?? false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
  );
}