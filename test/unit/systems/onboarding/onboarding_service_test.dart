import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';

import '../../../support/fakes/fake_datasource.dart';
import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/fake_taxonomy.dart';
import '../../../support/fakes/fake_trade_verification.dart';
import '../../../support/fakes/fake_verification.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.onboarding',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  group('OnboardingService facade (FV-06..FV-09)', () {
    test('resume returns the furthest step incl. completed progress',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack(
        store: InMemoryOnboardingProgressStore(
          seed: <OnboardingProgress>[
            OnboardingProgress(entityId: 'u1')
                .advanceTo(OnboardingStepCode.tradeProof)
                .finish(),
          ],
        ),
      );
      final OnboardingStepCode step = await stack.service.resume('u1');
      expect(step, OnboardingStepCode.tradeProof);
      expect(stack.service.progress!.isComplete, isTrue);
    });

    test('resume of a fresh entity starts at profile (FV-08)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      final OnboardingStepCode step = await stack.service.resume('u1');
      expect(step, OnboardingStepCode.profile);
      expect(stack.service.currentStep, OnboardingStepCode.profile);
    });

    test('advance never skips a required step (FV-09 ordering contract)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      final List<OnboardingStepCode> walked =
          <OnboardingStepCode>[];
      for (int i = 0; i < OnboardingStepCode.values.length; i++) {
        if (stack.service.progress!.isComplete) {
          break;
        }
        final OnboardingStepCode before = stack.service.currentStep!;
        await stack.service.advance();
        walked.add(before);
      }
      expect(
        walked,
        <OnboardingStepCode>[
          OnboardingStepCode.profile,
          OnboardingStepCode.capability,
          OnboardingStepCode.industry,
          OnboardingStepCode.identityDocument,
          OnboardingStepCode.tradeProof,
        ],
      );
      expect(stack.service.progress!.isComplete, isTrue);
      expect(stack.service.progress!.completedSteps,
          OnboardingStepCode.values,
          reason: 'frozen order capability â†’ â€¦ â†’ tradeProof â†’ completed');
    });

    test('advance persists after every step (TV-10)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      await stack.service.advance();
      expect((await stack.store.read('u1'))!.step,
          OnboardingStepCode.capability);
    });

    test('selectCapability records the choice and advances to industry',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      await stack.service.advance(); // profile → capability
      await stack.service.selectCapability(EntityCapability.offer);
      expect(stack.service.progress!.capability, EntityCapability.offer);
      expect(stack.service.currentStep, OnboardingStepCode.industry);
      expect((await stack.store.read('u1'))!.capability,
          EntityCapability.offer,
          reason: 'the capability decision persists for resume');
      await stack.service.advance();
      expect(stack.service.currentStep, OnboardingStepCode.identityDocument,
          reason: 'offer keeps the professional steps');
    });

    test('hire resume skips professional steps and finishes after capability',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      await stack.service.advance(); // profile → capability
      await stack.service.selectCapability(EntityCapability.hire); // finishes
      expect(stack.service.progress!.isComplete, isTrue);
      expect(stack.service.progress!.requiredSteps, hasLength(2));
    });

    test('advance/back are no-ops before hydration', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.advance();
      await stack.service.back();
      expect(stack.service.progress, isNull);
    });
  });

  group('completeProfile call ordering (TT-04, FV-49)', () {
    test('avatar upload â†’ profile RPC â†’ avatar_path REST update', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      final int uploadsBefore = stack.storage.uploadCallCount;
      final EntityProfile profile = (await stack.service
          .completeProfile(
        entityId: 'u1',
        legalName: 'Jane Doe',
        displayName: 'Jane',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
        avatarFileName: 'me.png',
        avatarMimeType: 'image/png',
      ));
      expect(profile, isNotNull);
      expect(stack.storage.uploadCallCount, uploadsBefore + 1);
      expect(stack.remote.updateProfileCallCount, 1);
      expect(stack.remote.updateAvatarPathCallCount, 1);
      expect(stack.remote.lastAvatarPath, stack.storage.returnedKey);
      expect(stack.storage.lastPath, 'u1/avatar.png');
      expect(stack.storage.lastBucket, 'profile-avatars');
      expect(profile.legalName, 'Jane Doe');
    });

    test('no avatar â†’ profile RPC only, no avatar_path update', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      await stack.service.completeProfile(
        entityId: 'u1',
        legalName: 'Jane Doe',
        displayName: 'Jane',
      );
      expect(stack.storage.uploadCallCount, 0);
      expect(stack.remote.updateProfileCallCount, 1);
      expect(stack.remote.updateAvatarPathCallCount, 0);
    });
  });

  group('bindProfession + verification delegation (FV-21, FV-25)', () {
    test('bindProfession validates taxonomy selection first (PLT003)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      await expectLater(
        stack.service.bindProfession(
          industryId: 'ind-tech',
          professionId: 'prof-sw',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT003')),
      );
      expect(stack.remote.bindProfessionCallCount, 0,
          reason: 'mismatched selection is rejected without a network call');
    });

    test('bindProfession maps PLT005 conflict unchanged (FV-52)', () async {
      final OnboardingTestStack stack = buildOnboardingStack(
        remote: FakeEntityRemoteDataSource()
          ..throwConflictOnBind = true,
      );
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      await expectLater(
        stack.service.bindProfession(
          industryId: 'ind-tech',
          professionId: 'prof-sw',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT005')),
      );
    });

    test('successful bind activates the professional role once (idempotent)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      await stack.service.bindProfession(
        industryId: 'ind-tech',
        professionId: 'prof-sw',
      );
      expect(stack.remote.activateRoleCallCount, 1);
      expect(stack.remote.lastActivatedRole, 'professional');
      stack.remote.throwConflictOnBind = true;
      await expectLater(
        stack.service.bindProfession(
          industryId: 'ind-tech',
          professionId: 'prof-sw',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(stack.remote.activateRoleCallCount, 1,
          reason: 'a failed bind never activates the role');
    });

    test('submitIdentity delegates 1:1 and sets the mirror flag', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.service.resume('u1');
      final submission = await stack.service.submitIdentityDocument(
        documentType: DocumentType.passport,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        fileName: 'id.png',
      );
      expect(submission.id, 'sub-1');
      expect(stack.service.progress!.hasIdentitySubmission, isTrue,
          reason: 'flag is a UX mirror, never trust state');
      expect(stack.identityRepo.submitCallCount, 1);
    });

    test('submitTradeProof delegates with the bound professionId', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      await stack.service.submitTradeProof(
        type: TradeProofType.workSample,
        professionId: 'prof-sw',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'image/png',
        fileName: 'proof.png',
      );
      expect(stack.tradeRepo.lastProfessionId, 'prof-sw');
      expect(stack.service.progress!.hasTradeProofSubmission, isTrue);
    });

    test('refreshTradeGate reads the server authority (SV-12)', () async {
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(statuses: <String, String>{
            'prof-sw': 'approved',
          }),
        ),
      );
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      final bool open = await stack.service.refreshTradeGate();
      expect(open, isTrue);
      expect(stack.tradeRepo.statusCallCount, 1);
    });

    test('refreshTradeGate maps pending/unverified to closed', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      expect(await stack.service.refreshTradeGate(), isFalse);
    });
  });

  group('logging + redaction (FV-10, TT-04)', () {
    test('resume + advance emit structured, redacted info entries', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      await stack.service.resume('u1');
      await stack.service.advance();
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.level == LogLevel.info &&
              e.message == 'Onboarding progress hydrated',
        ),
        isTrue,
      );
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.level == LogLevel.info &&
              e.message == 'Onboarding progress persisted',
        ),
        isTrue,
      );
      final LogEntry persist = sink.entries.firstWhere(
        (LogEntry e) => e.message == 'Onboarding progress persisted',
      );
expect(persist.context['step'], 'capability');
      expect(persist.context['isComplete'], isFalse);
    });

    test('resume hydration failure is logged and rethrown', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingService service = OnboardingService(
        store: _ThrowingProgressStore(),
        entityRepository: EntityRepositoryImpl(
          remote: FakeEntityRemoteDataSource(),
          local: FakeEntityLocalDataSource(),
        ),
        taxonomy: TaxonomyProvider(repository: seedTaxonomyRepository()),
        identityVerification: IdentityVerificationService(
          repo: FakeVerificationRepository(),
        ),
        tradeVerification: TradeVerificationService(
          repo: FakeTradeVerificationRepository(),
        ),
        storage: FakeStorageService(),
        logger: makeLogger(sink),
      );
      await expectLater(service.resume('u1'), throwsStateError);
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.level == LogLevel.error &&
              e.message == 'Onboarding progress hydration failed',
        ),
        isTrue,
      );
    });

    test('persistence failure is logged and rethrown', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingService service = OnboardingService(
        store: _ThrowingSaveStore(),
        entityRepository: EntityRepositoryImpl(
          remote: FakeEntityRemoteDataSource(),
          local: FakeEntityLocalDataSource(),
        ),
        taxonomy: TaxonomyProvider(repository: seedTaxonomyRepository()),
        identityVerification: IdentityVerificationService(
          repo: FakeVerificationRepository(),
        ),
        tradeVerification: TradeVerificationService(
          repo: FakeTradeVerificationRepository(),
        ),
        storage: FakeStorageService(),
        logger: makeLogger(sink),
      );
      await service.resume('u1');
      await expectLater(service.advance(), throwsStateError);
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.level == LogLevel.error &&
              e.message == 'Onboarding progress persistence failed',
        ),
        isTrue,
      );
    });
  });

  group('edge branches (all 3 MIME mappings)', () {
    test('webp avatar maps to avatar.webp and logs completion', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      await stack.service.resume('u1');
      await stack.service.completeProfile(
        entityId: 'u1',
        legalName: 'Jane Doe',
        displayName: 'Jane',
        avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
        avatarFileName: 'me.webp',
        avatarMimeType: 'image/webp',
      );
      expect(stack.storage.lastPath, 'u1/avatar.webp');
      expect(stack.remote.lastAvatarPath, stack.storage.returnedKey);
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.message == 'Profile submission completed',
        ),
        isTrue,
      );
    });

    test('profile submission failure is logged and rethrown', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      await stack.service.resume('u1');
      stack.storage.nextError = const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'This image is too large.',
        code: 'PLT003',
      );
      await expectLater(
        stack.service.completeProfile(
          entityId: 'u1',
          legalName: 'Jane Doe',
          displayName: 'Jane',
          avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
          avatarFileName: 'me.png',
          avatarMimeType: 'image/png',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT003')),
      );
      expect(
        sink.entries.any(
          (LogEntry e) => e.message == 'Profile submission failed',
        ),
        isTrue,
      );
    });

    test('bindProfession success + failure log redacted context', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      await stack.service.bindProfession(
        industryId: 'ind-tech',
        professionId: 'prof-sw',
      );
      expect(
        sink.entries.any(
          (LogEntry e) =>
              e.message == 'Profession binding completed',
        ),
        isTrue,
      );

      stack.remote.throwConflictOnBind = true;
      await expectLater(
        stack.service.bindProfession(
          industryId: 'ind-tech',
          professionId: 'prof-sw',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT005')),
      );
      final LogEntry failure = sink.entries.firstWhere(
        (LogEntry e) => e.message == 'Profession binding failed',
      );
      expect(failure.context['professionId'],
          PiiRedactor().redact('prof-sw'),
          reason: 'ids pass through the redactor; only PII shapes change');
    });

    test('PII-shaped ids are masked before they reach a log sink', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        taxonomyRepo: FakeTaxonomyRepository(
          industries: <Industry>[
            Industry(
              id: 'ind-tech',
              slug: 'technology',
              name: 'Technology',
              description: 'Software and IT',
              isActive: true,
              sortOrder: 20,
            ),
          ],
          professionsByIndustry: <String, List<Profession>>{
            'ind-tech': <Profession>[
              Profession(
                id: 'jane.doe@example.com',
                industryId: 'ind-tech',
                slug: 'email-id-profession',
                name: 'Email-Id Profession',
                description: 'A profession whose id is PII-shaped',
                isActive: true,
                sortOrder: 10,
              ),
            ],
          },
        ),
        logger: makeLogger(sink),
        remote: FakeEntityRemoteDataSource()..throwConflictOnBind = true,
      );
      await stack.taxonomy.loadIndustries();
      await stack.taxonomy.loadProfessions('ind-tech');
      stack.taxonomy.selectIndustry('ind-tech');
      stack.taxonomy.selectProfession(
        Profession(
          id: 'jane.doe@example.com',
          industryId: 'ind-tech',
          slug: 'email-id-profession',
          name: 'Email-Id Profession',
          description: 'A profession whose id is PII-shaped',
          isActive: true,
          sortOrder: 10,
        ),
      );
      await stack.service.resume('u1');
      await expectLater(
        stack.service.bindProfession(
          industryId: 'ind-tech',
          professionId: 'jane.doe@example.com',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT005')),
      );
      final LogEntry failure = sink.entries.firstWhere(
        (LogEntry e) => e.message == 'Profession binding failed',
      );
      expect(failure.context['professionId'], '***@***.***',
          reason: 'PiiRedactor strips email-shaped ids from logs (SV-10)');
    });

    test('trade proof failure is logged and rethrown', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        logger: makeLogger(sink),
      );
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      stack.tradeRepo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'You already have a pending verification for this document.',
        code: 'PLT005',
      );
      await expectLater(
        stack.service.submitTradeProof(
          type: TradeProofType.workSample,
          professionId: 'prof-sw',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'image/png',
          fileName: 'proof.png',
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT005')),
      );
      expect(
        sink.entries.any(
          (LogEntry e) => e.message == 'Trade proof submission failed',
        ),
        isTrue,
      );
    });

    test('refreshTradeGate logs the gate state', () async {
      final RecordingSink sink = RecordingSink();
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(statuses: <String, String>{
            'ind-tech': 'approved',
          }),
        ),
        logger: makeLogger(sink),
      );
      await selectTechnologyProfession(stack.taxonomy);
      await stack.service.resume('u1');
      await stack.service.refreshTradeGate(professionId: 'prof-sw');
      final LogEntry gate = sink.entries.firstWhere(
        (LogEntry e) => e.message == 'Trade gate refreshed',
      );
      expect(gate.context['isTradeGateOpen'], isFalse,
          reason: 'prof-sw remains unverified for this aggregate');
    });
  });
}

class _ThrowingProgressStore implements OnboardingProgressStore {
  @override
  Future<OnboardingProgress?> read(String entityId) =>
      throw StateError('read failed');

  @override
  Future<void> save(OnboardingProgress progress) async {}

  @override
  Future<void> clear(String entityId) async {}
}

class _ThrowingSaveStore implements OnboardingProgressStore {
  @override
  Future<OnboardingProgress?> read(String entityId) async => null;

  @override
  Future<void> save(OnboardingProgress progress) =>
      throw StateError('persist failed');

  @override
  Future<void> clear(String entityId) async {}
}