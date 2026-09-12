// ignore_for_file: avoid_redundant_argument_values

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../support/fakes/fake_trade_verification.dart';
import '../support/onboarding/onboarding_test_support.dart';

/// Fake-E2E integration for EP-02-18 (DoD TT-17..TT-20).
///
/// Wires the real [OnboardingProvider]/[OnboardingService] seam against the
/// fake collaborators (taxonomy, identity/trade verification, entity
/// repository, storage, in-memory progress store) — no widgets and no live
/// backend. Exercises the full wizard, exit-and-resume, the bid gate, and the
/// `PLT005` no-fire-hammer contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> runProfileStep(OnboardingTestStack stack) async {
    await stack.provider.advance(); // profile → capability
    final Uint8List avatarBytes = seedPngBytes();
    await stack.provider.completeProfile(
      legalName: 'Ada Lovelace',
      displayName: 'Ada',
      bio: 'Analytical engine pioneer',
      avatarBytes: avatarBytes,
      avatarFileName: 'me.png',
      avatarMimeType: 'image/png',
    );
    expect(stack.provider.submitState, SubmitState.success);
    await stack.provider.advance(); // capability → industry
  }

  Future<void> runTaxonomySteps(OnboardingTestStack stack) async {
    await selectTechnologyProfession(stack.taxonomy);
    // The merged industry & profession step binds in place — no intermediate
    // advance between the two pickers.
    await stack.provider.bindProfession(
      industryId: stack.taxonomy.selectedIndustry!.id,
      professionId: stack.taxonomy.selectedProfession!.id,
    );
    expect(stack.provider.submitState, SubmitState.success);
    await stack.provider.advance(); // industry → identity
  }

  Future<void> runVerificationSteps(OnboardingTestStack stack) async {
    await stack.provider.submitIdentityDocument(
      documentType: DocumentType.nationalId,
      bytes: seedPngBytes(),
      mimeType: 'image/png',
      fileName: 'id.png',
    );
    await stack.provider.advance(); // identity → trade-proof

    await stack.provider.submitTradeProof(
      type: TradeProofType.certificate,
      professionId: stack.taxonomy.selectedProfession!.id,
      bytes: seedPngBytes(),
      mimeType: 'image/png',
      fileName: 'proof.png',
    );
    await stack.provider.advance(); // trade-proof → completed
  }

  group('Onboarding fake-E2E flow', () {
    test('TT-17: fresh entity completes the full 5-step wizard', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      expect(await stack.service.isResumable('u1'), isFalse,
          reason: 'a fresh entity must not be dropped into a resume point');

      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.profile);

      await runProfileStep(stack);
      expect(stack.provider.currentStep, OnboardingStepCode.industry);

      // Avatar ordering contract: upload before RPC, canonical key persisted.
      expect(stack.storage.uploadCallCount, 1);
      expect(stack.storage.lastBucket, 'profile-avatars');
      expect(await stack.store.read('u1'), isNotNull);
      expect(stack.remote.updateAvatarPathCallCount, 1);
      expect(stack.remote.lastAvatarPath, stack.storage.returnedKey);

      await runTaxonomySteps(stack);
      expect(stack.remote.bindProfessionCallCount, 1);
      expect(stack.remote.lastBoundProfessionId, 'prof-sw');
      expect(stack.remote.activateRoleCallCount, 1,
          reason: 'the professional role activates on the profession bind');
      expect(stack.remote.lastActivatedRole, 'professional');
      expect(stack.provider.currentStep, OnboardingStepCode.identityDocument);

      await runVerificationSteps(stack);

      expect(stack.provider.isComplete, isTrue);
      expect(stack.provider.progress!.hasIdentitySubmission, isTrue);
      expect(stack.provider.progress!.hasTradeProofSubmission, isTrue,
          reason: 'UX mirrors set after successful submissions');
      final OnboardingProgress saved = (await stack.store.read('u1'))!;
      expect(saved.isComplete, isTrue,
          reason: 'finish persists to the resume key');
      expect(await stack.service.isResumable('u1'), isFalse,
          reason: 'completed progress is not resumable-worthy');
      stack.provider.dispose();
    });

test('TT-18: exit at step 3, relaunch resumes exactly at the industry step',
    () async {
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();
      final OnboardingTestStack first = buildOnboardingStack(store: store);
      await first.hydrate('u1');

      await runProfileStep(first); // → industry (the merged selection step)
      await selectTechnologyProfession(first.taxonomy);

      // Exit protocol persists the current position without moving.
      await first.provider.saveAndExit();
      expect(first.provider.currentStep, OnboardingStepCode.industry);

      // Relaunch: a brand-new provider/service over the same store resumes.
      final OnboardingTestStack second = buildOnboardingStack(store: store);
      expect(await second.service.isResumable('u1'), isTrue);
      await second.hydrate('u1');
      expect(second.provider.currentStep, OnboardingStepCode.industry,
          reason: 'resumes exactly at the exit point');
      expect(second.provider.progress!.completedSteps,
          <OnboardingStepCode>[
        OnboardingStepCode.profile,
        OnboardingStepCode.capability,
      ], reason: 'steps 1–2 restored as complete');

      first.provider.dispose();
      second.provider.dispose();
    });

    test('TT-19: gate maps approved → open and pending/unverified → locked',
        () async {
      final OnboardingTestStack approved = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: const <String, String>{'prof-sw': 'approved'},
          ),
        ),
      );
      await approved.hydrate('u1');
      await selectTechnologyProfession(approved.taxonomy);
      await approved.provider.refreshGateStatus();
      expect(approved.provider.isTradeGateOpen, isTrue,
          reason: 'approved unlocks bidding');
      approved.provider.dispose();

      for (final String status in const <String>[
        'pending',
        'unverified',
      ]) {
        final OnboardingTestStack locked = buildOnboardingStack(
          tradeRepo: FakeTradeVerificationRepository(
            status: tradeStatusEntity(
              statuses: <String, String>{'prof-sw': status},
            ),
          ),
        );
        await locked.hydrate('u1');
        await selectTechnologyProfession(locked.taxonomy);
        await locked.provider.refreshGateStatus();
        expect(locked.provider.isTradeGateOpen, isFalse,
            reason: '$status must not fake an unlocked gate');
        locked.provider.dispose();
      }
    });

test('TT-20: duplicate binding surfaces PLT005 and never fire-hammers',
    () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await runProfileStep(stack);
      await selectTechnologyProfession(stack.taxonomy);

      stack.remote.throwConflictOnBind = true;
      await stack.provider.bindProfession(
        industryId: 'ind-tech',
        professionId: 'prof-sw',
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT005');
      expect(stack.remote.bindProfessionCallCount, 1,
          reason: 'the failure path must not auto-retry');

      // Guidance only — retry happens on an explicit user action.
      stack.remote.throwConflictOnBind = false;
      await stack.provider.bindProfession(
        industryId: 'ind-tech',
        professionId: 'prof-sw',
      );
      expect(stack.provider.submitState, SubmitState.success);
      expect(stack.remote.bindProfessionCallCount, 2);
      stack.provider.dispose();
    });

    test('TT-21: hire-only entity completes after capability, skips professional',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.completeProfile(
        legalName: 'Ada Lovelace',
        displayName: 'Ada',
      );
      expect(stack.provider.submitState, SubmitState.success);
      await stack.provider.advance(); // profile → capability (step 2)
      expect(stack.provider.currentStep, OnboardingStepCode.capability);

      await stack.provider.selectCapability(EntityCapability.hire);
      expect(stack.provider.progress!.capability, EntityCapability.hire);
      expect(stack.provider.isComplete, isTrue,
          reason: 'a hire-only entity never enters the professional steps');
      expect(stack.remote.bindProfessionCallCount, 0);
      expect(stack.remote.activateRoleCallCount, 0,
          reason: 'consumer-only capability activates no professional role');

      final OnboardingProgress saved = (await stack.store.read('u1'))!;
      expect(saved.completedSteps, <OnboardingStepCode>[
        OnboardingStepCode.profile,
        OnboardingStepCode.capability,
      ]);
      stack.provider.dispose();
    });
  });
}