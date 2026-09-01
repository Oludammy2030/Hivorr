import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/screens/verification_status_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_verification.dart';
import '../../support/harnesses/widget_harness.dart';

/// A repository whose status fetch never completes, so the screen stays in its
/// loading state (the provider's `refreshStatus` hangs).
class _BlockingRepo implements VerificationRepository {
  _BlockingRepo();
  final Completer<void> _never = Completer<void>();

  @override
  Future<VerificationStatus> getStatus() => _never.future.then((_) => throw StateError('never'));

  @override
  Future<KycLevel> getKycLevel() => Future<KycLevel>.value(const KycLevel(
        tierCode: 'tier_0',
        status: 'pending',
        limits: KycLimits(daily: 0, weekly: 0, monthly: 0, cashout: 0),
      ));

  @override
  Future<KycLevel> getLimits() => getKycLevel();

  @override
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();
}

void main() {
  Future<VerificationProvider> pumpScreenWith(
    WidgetTester tester, {
    VerificationRepository? repo,
  }) async {
    final VerificationProvider provider =
        VerificationProvider(repo: repo ?? FakeVerificationRepository());
    await pumpApp(
      tester,
      const VerificationStatusScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<VerificationProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  // Unmounts the screen so its dispose() cancels the polling timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('VerificationStatusScreen layout', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();
      expect(find.text('Verification'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('unverified shows the upload CTA and header',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: false),
      );
      await tester.pump();

      expect(find.text('Upload a document'), findsOneWidget);
      expect(find.textContaining('Complete your identity verification'),
          findsOneWidget);
      expect(find.text('Identity Verified'), findsNothing);
      await unmount(tester);
    });

    testWidgets('verified shows the identity badge and no upload CTA',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: true),
      );
      await tester.pump();

      // 'Identity Verified' appears in the badge and the tier_1 KYC card.
      expect(find.text('Identity Verified'), findsWidgets);
      expect(find.text('Upload a document'), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows the pending + total submission counters',
        (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();

      expect(find.text('Pending submissions'), findsOneWidget);
      expect(find.text('Total submissions'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders the "Not verified" KYC card for a tier_0 account',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: false),
      );
      await tester.pump();

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('Cashout'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('status-derived timeline', () {
    testWidgets('unverified timelines render the pending stage as current',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: false),
      );
      await tester.pump();

      // The header is shown, so we are unverified; the timeline shows the
      // 'Pending review' stage as the current (bold) step.
      expect(find.text('Pending review'), findsOneWidget);
      final Text pending = tester.widget<Text>(find.text('Pending review'));
      expect(pending.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('verified timelines render the approved stage as current',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: true),
      );
      await tester.pump();

      final Text approved = tester.widget<Text>(find.text('Approved'));
      expect(approved.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('in-review derived from an existing submission with no review',
        (WidgetTester tester) async {
      // A pending submission that has already been submitted maps to in-review.
      final VerificationStatus pendingWithSubmissions = VerificationStatus(
        entityId: 'u1',
        kycLevel: const KycLevel(
          tierCode: 'tier_0',
          status: 'pending',
          limits: KycLimits(daily: 0, weekly: 0, monthly: 0, cashout: 0),
        ),
        identityVerified: false,
        tradeVerifications: const <TradeVerification>[],
        pendingSubmissions: 1,
        totalSubmissions: 1,
      );
      final repo = FakeVerificationRepository()..setStatus(pendingWithSubmissions);
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();

      final Text inReview = tester.widget<Text>(find.text('In review'));
      expect(inReview.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });
  });

  group('KYC card for verified accounts', () {
    testWidgets('renders limits for a verified tier_1 account',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeVerificationRepository(identityVerified: true),
      );
      await tester.pump();

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Cashout'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('async states', () {
    testWidgets('shows loading while the first refresh is in flight',
        (WidgetTester tester) async {
      await pumpScreenWith(tester, repo: _BlockingRepo());
      await tester.pump();

      expect(find.text('Checking your verification status…'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows an error state with retry after a failed refresh',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'status unavailable',
          code: 'X9',
        );
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();
      await tester.pump();

      expect(find.text('status unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('recovers to content after tapping retry',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'status unavailable',
          code: 'X9',
        );
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();
      await tester.pump();
      expect(find.text('status unavailable'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('status unavailable'), findsNothing);
      expect(find.text('Total submissions'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('action-required (resubmission)', () {
    testWidgets('renders the error block with a Resubmit CTA instead of upload',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository()
        ..setStatus(seedStatusEntity(
          identityVerified: false,
          pendingSubmissions: 0,
          totalSubmissions: 1,
        ));
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();

      expect(find.text("Your document couldn't be verified."), findsOneWidget);
      expect(find.text('Resubmit'), findsOneWidget);
      expect(find.text('Upload a document'), findsNothing);
      expect(find.text('Identity Verified'), findsNothing);
      await unmount(tester);
    });

    testWidgets('does not render the action-required block while pending',
        (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();

      expect(find.text('Resubmit'), findsNothing);
      expect(find.text("Your document couldn't be verified."), findsNothing);
      expect(find.text('Upload a document'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('pull-to-refresh', () {
    testWidgets('dragging the list triggers a fresh status refresh',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository();
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();
      final int callsBefore = repo.statusCallCount;

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(repo.statusCallCount, greaterThan(callsBefore));
      await unmount(tester);
    });
  });

  group('lifecycle-aware polling', () {
    testWidgets('backgrounding pauses polling; foregrounding resumes it',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository();
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();
      final int callsAfterInitial = repo.statusCallCount;

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.statusCallCount, callsAfterInitial);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 16));
      expect(repo.statusCallCount, greaterThan(callsAfterInitial));
      await unmount(tester);
    });
  });
}
