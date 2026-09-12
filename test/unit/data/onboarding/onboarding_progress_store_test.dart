import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_exception.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';

import '../../../support/fakes/fake_storage.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingProgressStore contract (FV-03, FV-04)', () {
    test('InMemory read of a missing key returns null', () async {
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();
      expect(await store.read('u1'), isNull);
    });

    test('InMemory save + read round-trips', () async {
      final OnboardingProgress progress = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.industry,
      );
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();
      await store.save(progress);
      final OnboardingProgress? restored = await store.read('u1');
      expect(restored, isNotNull);
      expect(restored!.step, OnboardingStepCode.industry);
      expect(restored.entityId, 'u1');
    });

    test('InMemory clear removes the row', () async {
      final OnboardingProgress progress =
          OnboardingProgress(entityId: 'u1');
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();
      await store.save(progress);
      await store.clear('u1');
      expect(await store.read('u1'), isNull);
    });

    test('key format is onboarding_progress:{entityId}', () {
      expect(onboardingProgressKey('u1'), 'onboarding_progress:u1');
      expect(onboardingProgressKey('u-abc-123'),
          'onboarding_progress:u-abc-123');
    });

    test('Hive-backed store round-trips through the engine box', () async {
      final LocalStore local = LocalStore(FakeStorageEngine());
      final HiveOnboardingProgressStore store =
          hiveProgressStore(store: local);
      final OnboardingProgress progress = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.identityDocument,
        hasIdentitySubmission: true,
      );
      await store.save(progress);
      final OnboardingProgress? restored = await store.read('u1');
      expect(restored, isNotNull);
      expect(restored!.step, OnboardingStepCode.identityDocument);
      expect(restored.hasIdentitySubmission, isTrue);
      expect(restored.completedSteps, progress.completedSteps);
    });

    test('cross-user isolation (DV-05): u2 never sees u1 progress', () async {
      final HiveOnboardingProgressStore store = hiveProgressStore();
      await store.save(OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.tradeProof,
      ));
      expect(await store.read('u2'), isNull);
      expect(await store.read('u1'), isNotNull);
    });

    test('graceful no-op when the storage engine is unavailable', () async {
      final LocalStore broken =
          LocalStore(_ThrowingStorageEngine());
      final HiveOnboardingProgressStore store =
          HiveOnboardingProgressStore(store: broken);
      expect(await store.read('u1'), isNull);
      await store.save(OnboardingProgress(entityId: 'u1'));
      await store.clear('u1');
      expect(await store.read('u1'), isNull);
    });

    test('save swallows a write failure (no-op, never throws)', () async {
      final LocalStore broken = LocalStore(_ThrowingWriteStorageEngine());
      final HiveOnboardingProgressStore store =
          HiveOnboardingProgressStore(store: broken);
      await store.save(
        OnboardingProgress(entityId: 'u1', step: OnboardingStepCode.industry),
      );
      expect(await store.read('u1'), isNull);
    });

    test('clear swallows a remove failure (no-op, never throws)', () async {
      final LocalStore broken =
          LocalStore(_ThrowingWriteStorageEngine()..seedRemove('onboarding'));
      final HiveOnboardingProgressStore store =
          HiveOnboardingProgressStore(store: broken);
      await store.clear('u1');
      expect(await store.read('u1'), isNull);
    });

    test('read falls back to profile for an unknown step name', () async {
      final FakeStorageEngine engine = FakeStorageEngine();
      await engine.put(
        'onboarding',
        'onboarding_progress:u1',
        <String, dynamic>{
          'entityId': 'u1',
          'step': 'warp-drive',
          'completedSteps': <String>[],
          'updatedAt': 0,
        },
      );
      final HiveOnboardingProgressStore store =
          HiveOnboardingProgressStore(store: LocalStore(engine));
      final OnboardingProgress? restored = await store.read('u1');
      expect(restored, isNotNull);
      expect(restored!.step, OnboardingStepCode.profile,
          reason: 'unknown step names degrade to the entry step');
      expect(restored.completedSteps, isEmpty);
    });

    test('valid completed steps round-trip; unknown names fall back',
        () async {
      final FakeStorageEngine engine = FakeStorageEngine();
      await engine.put(
        'onboarding',
        'onboarding_progress:u1',
        <String, dynamic>{
          'entityId': 'u1',
          'step': 'tradeProof',
          'completedSteps': <String>['profile', 'industry', 'unknown-step'],
          'hasIdentitySubmission': true,
          'hasTradeProofSubmission': false,
          'updatedAt': 5000,
        },
      );
      final HiveOnboardingProgressStore store =
          HiveOnboardingProgressStore(store: LocalStore(engine));
      final OnboardingProgress? restored = await store.read('u1');
      expect(restored, isNotNull);
      expect(
        restored!.completedSteps,
        <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.industry,
          OnboardingStepCode.profile,
        ],
        reason: 'known names decode in order; the unknown one degrades',
      );
      expect(restored.hasIdentitySubmission, isTrue);
      expect(restored.updatedAt.millisecondsSinceEpoch, 5000);
    });
  });
}

class _ThrowingStorageEngine extends FakeStorageEngine {
  @override
  Future<Map<String, dynamic>?> get(String box, String key) =>
      throw const StorageException('engine unavailable');
}

class _ThrowingWriteStorageEngine extends FakeStorageEngine {
  _ThrowingWriteStorageEngine();

  final Set<String> _removable = <String>{};

  _ThrowingWriteStorageEngine seedRemove(String box) {
    _removable.add(box);
    return this;
  }

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) =>
      throw const StorageException('engine unavailable');

  @override
  Future<void> delete(String box, String key) async {
    if (_removable.contains(box)) {
      throw const StorageException('engine unavailable');
    }
    await super.delete(box, key);
  }
}