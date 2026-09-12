import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

import '../../../support/fakes/fake_storage.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingProgress entity (FV-02, DV-11)', () {
    test('starts at profile (Basic Information) with empty completedSteps', () {
      final OnboardingProgress progress =
          OnboardingProgress(entityId: 'u1');
      expect(progress.entityId, 'u1');
      expect(progress.step, OnboardingStepCode.profile);
      expect(progress.completedSteps, isEmpty);
      expect(progress.capability, EntityCapability.both);
      expect(progress.isComplete, isFalse);
      expect(progress.hasIdentitySubmission, isFalse);
      expect(progress.hasTradeProofSubmission, isFalse);
    });

    test('advanceTo marks all preceding steps completed (monotonic)', () {
      final OnboardingProgress progress =
          OnboardingProgress(entityId: 'u1');
      final OnboardingProgress industry =
          progress.advanceTo(OnboardingStepCode.industry);
      expect(industry.step, OnboardingStepCode.industry);
      expect(
        industry.completedSteps,
        <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
        ],
      );
      final OnboardingProgress identity = industry.advanceTo(
        OnboardingStepCode.identityDocument,
      );
      expect(
        identity.completedSteps,
        <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
        ],
        reason: 'completedSteps advances monotonically in frozen order',
      );
    });

    test('nextStep follows the frozen professional order for offer/both', () {
      final OnboardingProgress progress =
          OnboardingProgress(entityId: 'u1');
      expect(progress.nextStep, OnboardingStepCode.capability);
      expect(
        progress.advanceTo(OnboardingStepCode.profile).nextStep,
        OnboardingStepCode.capability,
      );
      expect(
        progress.advanceTo(OnboardingStepCode.capability).nextStep,
        OnboardingStepCode.industry,
      );
      expect(
        progress
            .advanceTo(OnboardingStepCode.industry)
            .nextStep,
        OnboardingStepCode.identityDocument,
      );
      expect(
        progress
            .advanceTo(OnboardingStepCode.identityDocument)
            .nextStep,
        OnboardingStepCode.tradeProof,
      );
      expect(
        progress
            .advanceTo(OnboardingStepCode.tradeProof)
            .nextStep,
        isNull,
      );
    });

    test('hire-only nextStep finishes after the capability step', () {
      final OnboardingProgress freshHire =
          OnboardingProgress(entityId: 'u1',
            capability: EntityCapability.hire);
      expect(freshHire.nextStep, OnboardingStepCode.capability);
      final OnboardingProgress hireAtCapability = freshHire
          .advanceTo(OnboardingStepCode.capability);
      expect(hireAtCapability.nextStep, isNull,
          reason: 'hire-only entities finish after the capability step');
    });

    test('isComplete derives false for partial professional progress', () {
      final OnboardingProgress partial = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.tradeProof,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
          OnboardingStepCode.identityDocument,
        ],
      );
      expect(partial.isComplete, isFalse);
    });

    test('finish marks every required professional step complete', () {
      final OnboardingProgress done = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.tradeProof,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
          OnboardingStepCode.identityDocument,
        ],
      ).finish();
      expect(done.isComplete, isTrue);
      expect(done.completedSteps, OnboardingStepCode.values);
    });

    test('finish marks only the hire path complete', () {
      final OnboardingProgress hireDone = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.capability,
        capability: EntityCapability.hire,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
        ],
      ).finish();
      expect(hireDone.isComplete, isTrue);
      expect(
        hireDone.completedSteps,
        <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
        ],
        reason: 'hire-only never traverses the professional steps',
      );
    });

    test('withCapability preserves position and rebinds the path', () {
      final OnboardingProgress interim = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.profile,
        capability: EntityCapability.offer,
      );
      final OnboardingProgress hired = interim.withCapability(
        EntityCapability.hire,
      );
      expect(hired.capability, EntityCapability.hire);
      expect(hired.step, OnboardingStepCode.profile);
      expect(hired.requiredSteps, hasLength(2));
    });

    test('stepBack returns to previous step, keeping completedSteps', () {
      final OnboardingProgress progress = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.industry,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
        ],
      );
      final OnboardingProgress back = progress.stepBack();
      expect(back.step, OnboardingStepCode.capability);
      expect(back.completedSteps, progress.completedSteps);
      expect(progress.stepBack().stepBack().stepBack().step,
          OnboardingStepCode.profile,
          reason: 'stays put at the first step');
    });

    test('immutability: copies never mutate the original', () {
      final OnboardingProgress original =
          OnboardingProgress(entityId: 'u1');
      final OnboardingProgress next =
          original.advanceTo(OnboardingStepCode.industry);
      expect(original.step, OnboardingStepCode.profile);
      expect(identical(original, next), isFalse);
    });

    test('verification submission mirrors persist across advance', () {
      final OnboardingProgress flagged = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.identityDocument,
      ).withIdentitySubmission(true);
      expect(flagged.hasIdentitySubmission, isTrue);
      final OnboardingProgress advanced =
          flagged.advanceTo(OnboardingStepCode.tradeProof);
      expect(advanced.hasIdentitySubmission, isTrue);
      final OnboardingProgress trade = advanced.withTradeProofSubmission(true);
      expect(trade.hasTradeProofSubmission, isTrue);
    });

    test('forEntity rebinds the progress key for a new account', () {
      final OnboardingProgress rebound = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.industry,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
        ],
      ).forEntity('u2');
      expect(rebound.entityId, 'u2');
      expect(rebound.step, OnboardingStepCode.industry);
    });
  });

  group('Serialization parity (DV-16, TT-05)', () {
    test('store round-trip preserves every field including capability',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      final OnboardingProgress progress = OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.tradeProof,
        completedSteps: <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
          OnboardingStepCode.identityDocument,
        ],
        capability: EntityCapability.offer,
        hasIdentitySubmission: true,
        hasTradeProofSubmission: true,
      );
      await stack.store.save(progress);
      final OnboardingProgress? restored =
          await stack.store.read('u1');
      expect(restored, isNotNull);
      expect(restored!.entityId, 'u1');
      expect(restored.step, progress.step);
      expect(restored.completedSteps, progress.completedSteps);
      expect(restored.capability, EntityCapability.offer);
      expect(restored.hasIdentitySubmission, isTrue);
      expect(restored.hasTradeProofSubmission, isTrue);
    });

    test('legacy rows without capability default to both (safe superset)',
        () async {
      final LocalStore local = LocalStore(FakeStorageEngine());
      await local.write(
        OnboardingProgressBox.name,
        onboardingProgressKey('u1'),
        <String, dynamic>{
          'entityId': 'u1',
          'step': 'profile',
          'completedSteps': <String>[],
          'hasIdentitySubmission': false,
          'hasTradeProofSubmission': false,
          'updatedAt': 0,
        },
        (Map<String, dynamic> json) => json,
      );
      final HiveOnboardingProgressStore hive = hiveProgressStore(store: local);
      final OnboardingProgress? restored = await hive.read('u1');
      expect(restored, isNotNull);
      expect(restored!.capability, EntityCapability.both);
    });
  });
}