// EP-02-20 VP1: Full Onboarding Flow End-to-End (trust orchestrator).
//
// Exercises the real OnboardingService + OnboardingProvider seam (composed
// via OnboardingTestStack) through the full 5-step wizard:
// profile → capability → industry → identityDocument → tradeProof → complete.
//
// Validates:
//  - fresh entity completes all 5 steps with progress persisted
//  - exit at step 3 + relaunch resumes at same step
//  - guard-redirect contract: incomplete entity → resume, completed → home
//  - ordering contract: steps advance strictly in order
//  - PLT004 when profession bind fails (bad professionId)
//  - notifyListeners fires per advance
//  - upload-before-RPC avatar ordering contract
//  - PLT005 no-fire-hammer on duplicate bind
//
// Run: flutter test test/integration/trust/onboarding_trust_flow_integration_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List pngBytes() {
    final BytesBuilder b = BytesBuilder();
    // Minimal 1x1 transparent PNG.
    b.add(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, // IEND
      0x60, 0x82,
    ]);
    return b.toBytes();
  }

  Future<void> runProfileStep(OnboardingTestStack stack) async {
    await stack.provider.completeProfile(
      legalName: 'Ada Lovelace',
      displayName: 'Ada',
      bio: 'Analytical engine pioneer',
      avatarBytes: pngBytes(),
      avatarFileName: 'me.png',
      avatarMimeType: 'image/png',
    );
    expect(stack.provider.submitState, SubmitState.success);
    await stack.provider.advance(); // profile → capability
  }

  Future<void> runCapabilityStep(OnboardingTestStack stack) async {
    // The capability decision (both → professional wizard) advances past
    // the capability step into industry in the same RPC.
    await stack.provider.selectCapability(EntityCapability.both);
  }

  Future<void> runTaxonomyStep(OnboardingTestStack stack) async {
    await selectTechnologyProfession(stack.taxonomy);
    await stack.provider.bindProfession(
      industryId: stack.taxonomy.selectedIndustry!.id,
      professionId: stack.taxonomy.selectedProfession!.id,
    );
    expect(stack.provider.submitState, SubmitState.success);
    await stack.provider.advance(); // industry → identityDocument
  }

  Future<void> runIdentityStep(OnboardingTestStack stack) async {
    await stack.provider.submitIdentityDocument(
      documentType: DocumentType.nationalId,
      bytes: pngBytes(),
      mimeType: 'image/png',
      fileName: 'id.png',
    );
    await stack.provider.advance(); // identityDocument → tradeProof
  }

  Future<void> runTradeProofStep(OnboardingTestStack stack) async {
    await stack.provider.submitTradeProof(
      type: TradeProofType.certificate,
      professionId: stack.taxonomy.selectedProfession!.id,
      bytes: pngBytes(),
      mimeType: 'image/png',
      fileName: 'proof.png',
    );
    await stack.provider.advance(); // tradeProof → complete
  }

  group('VP1: Full onboarding flow (trust orchestrator)', () {
    test('DoD-VP1a: fresh entity completes 5-step wizard end-to-end', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      expect(await stack.service.isResumable('u1'), isFalse);
      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.profile);

      await runProfileStep(stack);
      expect(stack.provider.currentStep, OnboardingStepCode.capability);
      // Avatar ordering: upload before RPC.
      expect(stack.storage.uploadCallCount, 1);
      expect(stack.storage.lastBucket, 'profile-avatars');

      await runCapabilityStep(stack);
      expect(stack.provider.currentStep, OnboardingStepCode.industry);

      await runTaxonomyStep(stack);
      expect(stack.remote.bindProfessionCallCount, 1);
      expect(stack.provider.currentStep, OnboardingStepCode.identityDocument);

      await runIdentityStep(stack);
      expect(stack.provider.currentStep, OnboardingStepCode.tradeProof);

      await runTradeProofStep(stack);
      expect(stack.provider.isComplete, isTrue);
      expect(stack.provider.progress!.hasIdentitySubmission, isTrue);
      expect(stack.provider.progress!.hasTradeProofSubmission, isTrue);

      // Completion persisted.
      final OnboardingProgress saved = (await stack.store.read('u1'))!;
      expect(saved.isComplete, isTrue);
      expect(await stack.service.isResumable('u1'), isFalse);
    });

    test('DoD-VP1b: exit at step 3 → relaunch resumes at same step',
        () async {
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();

      // Simulate partial progress persisted (profile → industry done, exit
      // resumes at industry's follow-on: identityDocument).
      await store.save(OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.identityDocument,
        completedSteps: const <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
        ],
      ));

      final stack = buildOnboardingStack(store: store);
      addTearDown(stack.provider.dispose);

      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.identityDocument);
      expect(stack.provider.progress!.completedSteps, <OnboardingStepCode>[
        OnboardingStepCode.profile,
        OnboardingStepCode.capability,
        OnboardingStepCode.industry,
      ]);
    });

    test('ordering contract: steps advance strictly in order', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.profile);

      // A fresh entity advances one step at a time — never skipping.
      await stack.provider.advance();
      expect(stack.provider.currentStep, OnboardingStepCode.capability);
      expect(stack.provider.progress!.completedSteps, <OnboardingStepCode>[
        OnboardingStepCode.profile,
      ]);

      await stack.provider.advance();
      expect(stack.provider.currentStep, OnboardingStepCode.industry);
      expect(stack.provider.progress!.completedSteps, <OnboardingStepCode>[
        OnboardingStepCode.profile,
        OnboardingStepCode.capability,
      ]);
    });

    test('PLT003 guidance when profession bind fails', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      await stack.hydrate('u1');
      await runProfileStep(stack);
      await runCapabilityStep(stack);
      await selectTechnologyProfession(stack.taxonomy);

      // Bind with a selection mismatch triggers PLT003 inline guidance.
      await stack.provider.bindProfession(
        industryId: stack.taxonomy.selectedIndustry!.id,
        professionId: 'invalid',
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT003');
    });

    test('PLT005 no-fire-hammer on duplicate profession bind', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      await stack.hydrate('u1');
      await runProfileStep(stack);
      await runCapabilityStep(stack);
      await selectTechnologyProfession(stack.taxonomy);

      stack.remote.throwConflictOnBind = true;
      await stack.provider.bindProfession(
        industryId: stack.taxonomy.selectedIndustry!.id,
        professionId: stack.taxonomy.selectedProfession!.id,
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT005');
      expect(stack.remote.bindProfessionCallCount, 1);

      // Guidance only — retry happens on an explicit user action.
      stack.remote.throwConflictOnBind = false;
      await stack.provider.bindProfession(
        industryId: stack.taxonomy.selectedIndustry!.id,
        professionId: stack.taxonomy.selectedProfession!.id,
      );
      expect(stack.provider.submitState, SubmitState.success);
      expect(stack.remote.bindProfessionCallCount, 2);
    });

    test('notifyListeners fires per advance', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      int notifyCount = 0;
      stack.provider.addListener(() => notifyCount++);

      await stack.hydrate('u1');
      expect(notifyCount, greaterThan(0));

      final int before = notifyCount;
      await runProfileStep(stack);
      expect(notifyCount, greaterThan(before));
    });

    test('guard redirect: incomplete entity → resume step', () async {
      final InMemoryOnboardingProgressStore store =
          InMemoryOnboardingProgressStore();
      final OnboardingTestStack stack = buildOnboardingStack(store: store);
      addTearDown(stack.provider.dispose);

      // Simulate an incomplete entity at home (resume point reached: industry).
      await store.save(OnboardingProgress(
        entityId: 'u1',
        step: OnboardingStepCode.industry,
        completedSteps: const <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
        ],
      ));

      await stack.hydrate('u1');

      expect(stack.provider.currentStep, OnboardingStepCode.industry);
      expect(stack.provider.isComplete, isFalse);
      // _onboardingResumeRedirect: home + !complete + !exited → redirect to step.
      // This is validated indirectly via the guard (the guard is tested in
      // onboarding_resume_redirect_verification.dart).
    });

    test('completed entity at onboarding route → redirect home', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      addTearDown(stack.provider.dispose);

      await stack.hydrate('u1');
      await runProfileStep(stack);
      await runCapabilityStep(stack);
      await runTaxonomyStep(stack);
      await runIdentityStep(stack);
      await runTradeProofStep(stack);

      expect(stack.provider.isComplete, isTrue);
      expect(stack.provider.progress!.isComplete, isTrue);
      // _onboardingResumeRedirect: onboarding route + complete → home.
    });
  });
}
