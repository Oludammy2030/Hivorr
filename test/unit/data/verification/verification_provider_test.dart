import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/fake_verification.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
  const String mimeType = 'image/png';
  const String fileName = 'id.png';
  const ApiException boom = ApiException(
    kind: ApiExceptionKind.server,
    message: 'boom',
    code: 'X9',
  );

  group('initial state', () {
    test('starts idle with no snapshot', () {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      expect(provider.submitState, SubmitState.idle);
      expect(provider.status, isNull);
      expect(provider.kycLevel, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(provider.isBusy, isFalse);
      provider.dispose();
    });

    test('exposes no error before any operation', () {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      expect(provider.submitError, isNull);
      expect(provider.lastError, isNull);
      provider.dispose();
    });
  });

  group('unified account projection', () {
    test(
      'exposes identity and business lookup from the status aggregate',
      () async {
        final repo = FakeVerificationRepository()
          ..setStatus(
            VerificationStatus(
              entityId: 'u1',
              kycLevel: const KycLevel(
                tierCode: 'tier_1',
                status: 'active',
                limits: KycLimits(daily: 1, weekly: 1, monthly: 1, cashout: 1),
              ),
              identityVerified: true,
              businesses: <BusinessVerificationEntry>[
                BusinessVerificationEntry(
                  businessId: 'biz-1',
                  tradingName: 'Amara Foods',
                  registeredLegalName: 'Amara Foods Ltd',
                  cacNumber: 'CAC-001',
                  verificationStatus: 'approved',
                  role: 'representative',
                  isAuthorized: true,
                  latestSubmission: VerificationSubmissionSummary(
                    submissionType: 'business_verification',
                    status: VerificationStatusKind.approved,
                    submittedAt: DateTime.fromMillisecondsSinceEpoch(1000),
                    businessId: 'biz-1',
                    businessTradingName: 'Amara Foods',
                    decisionNotes: 'Registry extract verified',
                  ),
                ),
              ],
              eligibility: const <String, dynamic>{'identity_verified': true},
              pendingSubmissions: 0,
              totalSubmissions: 1,
            ),
          );
        final provider = VerificationProvider(repo: repo);

        await provider.refreshStatus();

        expect(provider.identityVerified, isTrue);
        expect(provider.businesses, hasLength(1));
        final BusinessVerificationEntry? business = provider.businessFor(
          'biz-1',
        );
        expect(business?.tradingName, 'Amara Foods');
        expect(business?.isAuthorized, isTrue);
        expect(
          business?.latestSubmission?.decisionNotes,
          'Registry extract verified',
        );
        expect(provider.businessFor('missing'), isNull);
        provider.dispose();
      },
    );
  });

  group('submitIdentityDocument', () {
    test('transitions idle -> submitting -> success', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      final states = <SubmitState>[];
      provider.addListener(() => states.add(provider.submitState));

      final future = provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(provider.isSubmitting, isTrue);
      await future;

      expect(provider.submitState, SubmitState.success);
      expect(provider.lastSubmission, isNotNull);
      expect(provider.lastSubmission!.documentType, DocumentType.nationalId);
      expect(states, contains(SubmitState.submitting));
      provider.dispose();
    });

    test('stores the error and sets error state on failure', () async {
      final repo = FakeVerificationRepository()..nextError = boom;
      final provider = VerificationProvider(repo: repo);

      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.submitState, SubmitState.error);
      expect(provider.submitError, boom);
      provider.dispose();
    });

    test('refreshes status after a successful submit', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());

      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.status, isNotNull);
      expect(provider.kycLevel, isNotNull);
      provider.dispose();
    });

    test('does not start a second submit while one is in flight', () async {
      final repo = FakeVerificationRepository();
      final provider = VerificationProvider(repo: repo);

      final first = provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await first;

      expect(repo.submitCallCount, 1);
      provider.dispose();
    });

    test('keeps prior successful state intact after a failed retry on a fresh '
        'submission error', () async {
      final repo = FakeVerificationRepository();
      final provider = VerificationProvider(repo: repo);
      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(provider.submitState, SubmitState.success);
      provider.dispose();
    });
  });

  group('refreshStatus', () {
    test('populates status and kyc level', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());

      await provider.refreshStatus();

      expect(provider.status, isNotNull);
      expect(provider.kycLevel, isNotNull);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('sets lastError and keeps status when refresh fails', () async {
      final repo = FakeVerificationRepository()..nextError = boom;
      final provider = VerificationProvider(repo: repo);

      await provider.refreshStatus();

      expect(provider.lastError, boom);
      expect(provider.status, isNull);
      provider.dispose();
    });

    test('isRefreshing is true while a refresh is in flight', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      final future = provider.refreshStatus();
      expect(provider.isRefreshing, isTrue);
      await future;
      expect(provider.isRefreshing, isFalse);
      provider.dispose();
    });

    test('clears a prior error on a later successful refresh', () async {
      final repo = FakeVerificationRepository()..nextError = boom;
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.lastError, boom);

      await provider.refreshStatus();
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test(
      'keeps kyc from the previous refresh if a later fetch fails',
      () async {
        final provider = VerificationProvider(
          repo: FakeVerificationRepository(),
        );
        await provider.refreshStatus();
        expect(provider.kycLevel, isNotNull);
        provider.dispose();
      },
    );
  });

  group('terminal transition', () {
    test('refresh on an already-verified provider is safe', () async {
      final provider = VerificationProvider(
        repo: FakeVerificationRepository(identityVerified: true),
      );
      await provider.refreshStatus();
      expect(provider.status!.identityVerified, isTrue);
      provider.dispose();
    });

    test('refresh on an unverified provider reports unverified', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      await provider.refreshStatus();
      expect(provider.status!.identityVerified, isFalse);
      provider.dispose();
    });
  });

  group('polling', () {
    test('startPolling refreshes after the interval', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository();
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        final callsAtStart = repo.statusCallCount;

        async.elapse(const Duration(seconds: 14));
        expect(repo.statusCallCount, callsAtStart);

        async.elapse(const Duration(seconds: 1));
        expect(repo.statusCallCount, greaterThan(callsAtStart));
        provider.dispose();
      });
    });

    test('startPolling keeps ticking while unverified', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository();
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();

        async.elapse(const Duration(seconds: 45));
        expect(repo.statusCallCount, greaterThanOrEqualTo(3));
        provider.dispose();
      });
    });

    test('startPolling stops ticking once identity is verified', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository(identityVerified: true);
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();

        async.elapse(const Duration(seconds: 120));
        // Terminal: after the first tick refreshes and learns the state is
        // verified, the periodic timer cancels itself and never ticks again.
        expect(repo.statusCallCount, 1);
        provider.dispose();
      });
    });

    test('stopPolling prevents further refreshes', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository();
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        provider.stopPolling();
        final countAfterStop = repo.statusCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(repo.statusCallCount, countAfterStop);
        provider.dispose();
      });
    });

    test('pausePolling stops ticking and resumePolling restarts it', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository();
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        provider.pausePolling();
        final countAfterPause = repo.statusCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(repo.statusCallCount, countAfterPause);

        provider.resumePolling();
        async.elapse(const Duration(seconds: 15));
        expect(repo.statusCallCount, greaterThan(countAfterPause));
        provider.dispose();
      });
    });

    test(
      'stopPolling stays stopped; a later resumePolling also stays dead',
      () {
        fakeAsync((FakeAsync async) {
          final repo = FakeVerificationRepository();
          final provider = VerificationProvider(
            repo: repo,
            pollInterval: const Duration(seconds: 15),
          );
          provider.startPolling();
          provider.stopPolling();
          provider.resumePolling();
          final countAfterStop = repo.statusCallCount;

          async.elapse(const Duration(seconds: 60));
          expect(repo.statusCallCount, countAfterStop);
          provider.dispose();
        });
      },
    );

    test('startPolling stops ticking once the submission is decided without '
        'approval (action required)', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeVerificationRepository()
          ..setStatus(
            seedStatusEntity(
              identityVerified: false,
              totalSubmissions: 1,
              pendingSubmissions: 0,
            ),
          );
        final provider = VerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();

        async.elapse(const Duration(seconds: 120));
        // Terminal: the first tick refreshes, learns the pending submission is
        // gone (decided, not approved), and the timer cancels itself.
        expect(repo.statusCallCount, 1);
        provider.dispose();
      });
    });
  });

  group('stage derivation', () {
    test('is idle before any status has been fetched', () async {
      final provider = VerificationProvider(repo: FakeVerificationRepository());
      expect(provider.stage, VerificationStage.idle);
      provider.dispose();
    });

    test('is pending when nothing has been submitted yet', () async {
      final repo = FakeVerificationRepository()
        ..setStatus(
          seedStatusEntity(
            identityVerified: false,
            totalSubmissions: 0,
            pendingSubmissions: 0,
          ),
        );
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.stage, VerificationStage.pending);
      provider.dispose();
    });

    test('is inReview while a submission is awaiting review', () async {
      final repo = FakeVerificationRepository()
        ..setStatus(
          seedStatusEntity(
            identityVerified: false,
            totalSubmissions: 1,
            pendingSubmissions: 1,
          ),
        );
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.stage, VerificationStage.inReview);
      provider.dispose();
    });

    test(
      'is actionRequired when the submission was decided without approval',
      () async {
        final repo = FakeVerificationRepository()
          ..setStatus(
            seedStatusEntity(
              identityVerified: false,
              totalSubmissions: 1,
              pendingSubmissions: 0,
            ),
          );
        final provider = VerificationProvider(repo: repo);
        await provider.refreshStatus();
        expect(provider.stage, VerificationStage.actionRequired);
        provider.dispose();
      },
    );

    test('uses the latest identity lane over aggregate counts', () async {
      final repo = FakeVerificationRepository()
        ..setStatus(
          seedStatusEntity(
            identityVerified: false,
            totalSubmissions: 1,
            pendingSubmissions: 0,
            latestSubmissions: <VerificationSubmissionSummary>[
              seedSubmissionSummary(
                submissionType: 'identity_document',
                status: VerificationStatusKind.inReview,
              ),
            ],
          ),
        );
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.stage, VerificationStage.inReview);
      provider.dispose();
    });

    test('a rejected identity lane reports actionRequired', () async {
      final repo = FakeVerificationRepository()
        ..setStatus(
          seedStatusEntity(
            identityVerified: false,
            totalSubmissions: 1,
            pendingSubmissions: 0,
            latestSubmissions: <VerificationSubmissionSummary>[
              seedSubmissionSummary(
                submissionType: 'identity_document',
                status: VerificationStatusKind.rejected,
              ),
            ],
          ),
        );
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.stage, VerificationStage.actionRequired);
      provider.dispose();
    });

    test(
      'a trade-only rejection does not mark identity as action required',
      () async {
        final repo = FakeVerificationRepository()
          ..setStatus(
            seedStatusEntity(
              identityVerified: false,
              totalSubmissions: 1,
              pendingSubmissions: 0,
              latestSubmissions: <VerificationSubmissionSummary>[
                seedSubmissionSummary(
                  submissionType: 'trade_proof',
                  professionId: 'p1',
                  status: VerificationStatusKind.rejected,
                ),
              ],
            ),
          );
        final provider = VerificationProvider(repo: repo);
        await provider.refreshStatus();
        expect(provider.stage, VerificationStage.pending);
        provider.dispose();
      },
    );

    test('is approved when identity is verified', () async {
      final repo = FakeVerificationRepository(identityVerified: true);
      final provider = VerificationProvider(repo: repo);
      await provider.refreshStatus();
      expect(provider.stage, VerificationStage.approved);
      provider.dispose();
    });
  });

  group('decision notifications', () {
    NotificationProvider buildNotificationProvider(
      FakeNotificationService service,
    ) {
      return NotificationProvider(
        service,
        NotificationPermissionManager(
          platform: FakeNotificationPermissionPlatform(
            nextStatus: NotificationPermissionStatus.granted,
          ),
        ),
      );
    }

    test('notifies once when identity becomes verified', () async {
      final service = FakeNotificationService();
      final provider = VerificationProvider(
        repo: FakeVerificationRepository(identityVerified: true),
        notificationProvider: buildNotificationProvider(service),
      );

      await provider.refreshStatus();
      await provider.refreshStatus();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, 'Verification approved');
      provider.dispose();
    });

    test(
      'notifies once when a submission is declined (action required)',
      () async {
        final service = FakeNotificationService();
        final repo = FakeVerificationRepository()
          ..setStatus(
            seedStatusEntity(
              identityVerified: false,
              totalSubmissions: 1,
              pendingSubmissions: 0,
            ),
          );
        final provider = VerificationProvider(
          repo: repo,
          notificationProvider: buildNotificationProvider(service),
        );

        await provider.refreshStatus();
        await provider.refreshStatus();

        expect(service.shown, hasLength(1));
        expect(service.shown.single.title, 'Verification action required');
        provider.dispose();
      },
    );

    test('emits approved after a resubmitted document is approved', () async {
      final service = FakeNotificationService();
      final repo = FakeVerificationRepository()
        ..setStatus(
          seedStatusEntity(
            identityVerified: false,
            totalSubmissions: 1,
            pendingSubmissions: 0,
          ),
        );
      final provider = VerificationProvider(
        repo: repo,
        notificationProvider: buildNotificationProvider(service),
      );

      await provider.refreshStatus();
      expect(service.shown.single.title, 'Verification action required');

      repo.setStatus(
        seedStatusEntity(
          identityVerified: true,
          totalSubmissions: 2,
          pendingSubmissions: 0,
        ),
      );
      await provider.refreshStatus();

      expect(service.shown, hasLength(2));
      expect(service.shown.last.title, 'Verification approved');
      provider.dispose();
    });
  });
}
