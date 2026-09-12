import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/fake_trade_verification.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OnboardingProvider? activeProvider;

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.onboarding',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  tearDown(() {
    activeProvider?.dispose();
    activeProvider = null;
  });

  group('loadProgress / resume (FV-13, FV-14)', () {
    test('fresh entity starts at profile with an empty progress row',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.profile);
      expect(stack.provider.progress, isNotNull);
      expect(stack.provider.isComplete, isFalse);
      expect(stack.provider.entityId, 'u1');
    });

    test('resume returns the furthest step reached', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.advance();
      expect(stack.provider.currentStep, OnboardingStepCode.industry);
      final OnboardingStepCode resumed = await stack.service.resume('u1');
      expect(resumed, OnboardingStepCode.industry);
      expect(stack.provider.currentStep, OnboardingStepCode.industry);
    });

    test('advance persists every step in frozen order', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance(); // -> capability
      await stack.provider.advance(); // -> industry (incl. profession)
      await stack.provider.advance(); // -> identityDocument
      await stack.provider.advance(); // -> tradeProof
      await stack.provider.advance(); // -> completed
      expect(stack.provider.isComplete, isTrue);
      final OnboardingProgress? persisted =
          await stack.store.read('u1');
      expect(persisted, isNotNull);
      expect(persisted!.completedSteps, OnboardingStepCode.values);
    });

    test('back steps one position and persists', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      expect(stack.provider.currentStep, OnboardingStepCode.capability);
      await stack.provider.back();
      expect(stack.provider.currentStep, OnboardingStepCode.profile);
    });

    test('saveAndExit persists the current position without moving (FV-15)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.saveAndExit();
      expect(stack.provider.currentStep, OnboardingStepCode.capability);
      expect((await stack.store.read('u1'))!.step,
          OnboardingStepCode.capability);
    });

    test('account switch rebinds the progress key (SV-08)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.loadProgress('u2');
      expect(stack.provider.entityId, 'u2');
      expect(stack.provider.currentStep, OnboardingStepCode.profile,
          reason: 'u2 has no progress row — a fresh wizard must start');
    });

    test('loadProgress without an entity is a no-op', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.provider.loadProgress();
      expect(stack.provider.progress, isNull);
      expect(stack.provider.currentStep, isNull);
      expect(stack.service.progress, isNull,
          reason: 'no hydration may run for an empty key');
    });

    test('resume alias hydrates the furthest step', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.provider.resume('u1');
      expect(stack.provider.entityId, 'u1');
      expect(stack.provider.currentStep, OnboardingStepCode.profile);
    });
  });

  group('submit operations (FV-25, FV-61)', () {
    test('completeProfile success flows through and sets files/state',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.completeProfile(
        legalName: 'Jane Doe',
        displayName: 'Jane',
        bio: 'Builder',
      );
      expect(stack.provider.submitState, SubmitState.success);
      expect(stack.remote.updateProfileCallCount, 1);
      expect(stack.remote.profile!.legalName, 'Jane Doe');
    });

    test('avatar upload precedes the profile RPC (FV-49 call order)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.completeProfile(
        legalName: 'Jane Doe',
        displayName: 'Jane',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
        avatarFileName: 'me.png',
        avatarMimeType: 'image/png',
      );
      expect(stack.storage.uploadCallCount, 1);
      expect(stack.storage.lastBucket, 'profile-avatars');
      expect(stack.storage.lastPath, 'u1/avatar.png');
      expect(stack.remote.updateAvatarPathCallCount, 1);
      expect(stack.remote.lastAvatarPath, stack.storage.returnedKey);
    });

    test('PLT003 storage validation surfaces as an error before network',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      stack.storage.nextError = const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'This image is too large â€” please use a JPEG, PNG, or WebP '
            'under 5 MB.',
        code: 'PLT003',
      );
      await stack.hydrate('u1');
      await stack.provider.completeProfile(
        legalName: 'Jane Doe',
        displayName: 'Jane',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
        avatarFileName: 'me.png',
        avatarMimeType: 'image/png',
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT003');
      expect(stack.storage.uploadCallCount, 0,
          reason: 'reject-before-upload: validation failures never hit network');
    });

    test('bindProfession maps PLT005 conflict onto provider state',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      stack.remote.throwConflictOnBind = true;
      await selectTechnologyProfession(stack.taxonomy);
      await stack.hydrate('u1');
      await stack.provider.bindProfession(
        industryId: 'ind-tech',
        professionId: 'prof-sw',
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError, isNotNull);
      expect(stack.provider.lastError!.code, 'PLT005');
    });

    test('identity submission marks the mirrored flag on success', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.submitIdentityDocument(
        documentType: DocumentType.passport,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        fileName: 'id.png',
      );
      expect(stack.provider.submitState, SubmitState.success);
      expect(stack.provider.progress!.hasIdentitySubmission, isTrue);
      expect(stack.identityVerification, isNotNull);
    });

    test('trade proof submission binds the profession id', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await selectTechnologyProfession(stack.taxonomy);
      await stack.hydrate('u1');
      await stack.provider.submitTradeProof(
        type: TradeProofType.workSample,
        professionId: 'prof-sw',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        fileName: 'proof.png',
      );
      expect(stack.provider.submitState, SubmitState.success);
      expect(stack.provider.progress!.hasTradeProofSubmission, isTrue);
    });

    test('ApiException failure logs a redacted warning', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      activeProvider = stack.provider;
      stack.storage.nextError = const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'This image is too large â€” please use a JPEG, PNG, or WebP '
            'under 5 MB.',
        code: 'PLT003',
      );
      await stack.hydrate('u1');
      await stack.provider.completeProfile(
        legalName: 'Jane Doe',
        displayName: 'Jane',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
        avatarFileName: 'me.png',
        avatarMimeType: 'image/png',
      );
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT003');
      final LogEntry warning = sink.entries.firstWhere(
        (LogEntry e) => e.level == LogLevel.warning,
      );
      expect(warning.message, 'Onboarding operation failed');
      expect(warning.context['code'], 'PLT003');
    });

    test('unexpected failure maps to an unknown ApiException + error log',
        () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
        store: _ThrowingSaveStore(),
      );
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError, isNotNull);
      expect(stack.provider.lastError!.kind, ApiExceptionKind.unknown);
      expect(
        stack.provider.lastError!.message,
        'Something went wrong. Please try again.',
      );
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.level == LogLevel.error &&
              e.message == 'Onboarding operation failed unexpectedly',
        ),
        isTrue,
      );
    });
  });

  group('gate + lifecycle (FV-26, FV-15)', () {
    test('refreshGateStatus maps approved to isTradeGateOpen', () async {
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(statuses: <String, String>{
            'prof-sw': 'approved',
          }),
        ),
      );
      activeProvider = stack.provider;
      await selectTechnologyProfession(stack.taxonomy);
      await stack.hydrate('u1');
      expect(stack.provider.isTradeGateOpen, isNull);
      await stack.provider.refreshGateStatus();
      expect(stack.provider.isTradeGateOpen, isTrue);
    });

    test('refreshGateStatus maps pending to false + gate stays shut',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await selectTechnologyProfession(stack.taxonomy);
      await stack.hydrate('u1');
      await stack.provider.refreshGateStatus();
      expect(stack.provider.isTradeGateOpen, isFalse);
    });

    test('notifyListeners fires on each mutation', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      int notifications = 0;
      stack.provider.addListener(() => notifications++);
      await stack.hydrate('u1');
      final int afterHydrate = notifications;
      expect(afterHydrate, greaterThan(0));
      await stack.provider.advance();
      expect(notifications, greaterThan(afterHydrate));
    });

    test('lifecycle pause triggers saveAndExit (FV-15)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      stack.provider
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect((await stack.store.read('u1'))!.step,
          OnboardingStepCode.capability);
    });

    test('lifecycle inactive also triggers saveAndExit (FV-15)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      activeProvider = stack.provider;
      await stack.hydrate('u1');
      await stack.provider.advance();
      stack.provider
          .didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();
      expect((await stack.store.read('u1'))!.step,
          OnboardingStepCode.capability);
    });
  });
}

class _ThrowingSaveStore extends InMemoryOnboardingProgressStore {
  @override
  Future<void> save(OnboardingProgress progress) =>
      throw StateError('persist failed');
}