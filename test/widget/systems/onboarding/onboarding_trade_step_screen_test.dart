import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/systems/onboarding/screens/trade_proof_step_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../../../support/fakes/fake_trade_verification.dart';
import '../../../support/fakes/fake_verification.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OnboardingTestStack, OnboardingStepController)> pumpTrade(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    PickTradeProofCallback? pickFile,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    final OnboardingStepController controller = OnboardingStepController();
    await s.hydrate('u1');
    await selectTechnologyProfession(s.taxonomy);
    await pumpOnboardingScreen(
      tester,
      TradeProofStepScreen(
        active: true,
        controller: controller,
        pickFile: pickFile,
      ),
      path: '/onboarding/trade-proof',
      providers: s.buildProviders(),
    );
    return (s, controller);
  }

  group('TradeProofStepScreen (FV-23, FV-26)', () {
    testWidgets('renders the bound profession chip + proof-type labels', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, _) = await pumpTrade(tester);
      await tester.pumpAndSettle();
      expect(find.text('Profession'), findsOneWidget);
      expect(find.text('Software Engineer'), findsOneWidget);
      expect(
        find.text(
          'Proof of your trade unlocks bidding. Choose a proof '
          'type, then upload a clear photo or PDF.',
        ),
        findsOneWidget,
      );
      for (final TradeProofType type in TradeProofType.values) {
        expect(find.text(type.label), findsOneWidget);
      }
      stack.provider.dispose();
    });

    testWidgets('pending gate shows the locked copy', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, _) = await pumpTrade(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bidding will unlock after approval'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('approved gate shows the unlocked copy', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, _) = await pumpTrade(
        tester,
        stack: buildOnboardingStack(
          tradeRepo: FakeTradeVerificationRepository(
            status: tradeStatusEntity(
              statuses: const <String, String>{'prof-sw': 'approved'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bidding unlocked'), findsOneWidget);
      expect(find.text('Bidding will unlock after approval'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets(
      'gate refreshes on activation and a pending result locks bidding',
      (WidgetTester tester) async {
        final OnboardingTestStack stack = buildOnboardingStack(
          tradeRepo: FakeTradeVerificationRepository(
            status: tradeStatusEntity(
              statuses: const <String, String>{'prof-sw': 'pending'},
            ),
          ),
        );
        final (_, _) = await pumpTrade(tester, stack: stack);
        await tester.pumpAndSettle();
        expect(
          stack.tradeRepo.statusCallCount,
          1,
          reason: 'activation triggers one gate refresh',
        );
        expect(find.text('Bidding will unlock after approval'), findsOneWidget);
        stack.provider.dispose();
      },
    );

    testWidgets('primary is enabled once a type + file are chosen', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpTrade(tester, pickFile: () async => seedPickedFile());
      await tester.pumpAndSettle();
      expect(controller.canPrimary, isFalse);
      await tester.tap(find.text(TradeProofType.certificate.label));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('document.png'), findsOneWidget);
      expect(controller.canPrimary, isTrue);
      stack.provider.dispose();
    });

    testWidgets('submit binds the profession id and stays under review', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpTrade(tester, pickFile: () async => seedPickedFile());
      await tester.pumpAndSettle();
      await tester.tap(find.text(TradeProofType.certificate.label));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(stack.tradeRepo.submitCallCount, 1);
      expect(stack.tradeRepo.lastProfessionId, 'prof-sw');
      expect(
        stack.provider.progress!.hasTradeProofSubmission,
        isTrue,
        reason: 'mirror flag set after a successful submission',
      );
      expect(find.text('Trade proof under review'), findsOneWidget);
      expect(find.text('Return to requirements'), findsOneWidget);
      expect(find.text('ONBOARDING-COMPLETE'), findsNothing);
      expect(find.text('PROFESSIONAL-REQUIREMENTS'), findsNothing);
      expect(stack.provider.isComplete, isFalse);
      expect(controller.canPrimary, isFalse);
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('under-review state survives re-entry from persisted status', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: const <String, String>{'prof-sw': 'pending'},
            latestSubmissions: <VerificationSubmissionSummary>[
              seedSubmissionSummary(
                submissionType: 'trade_proof',
                professionId: 'prof-sw',
              ),
            ],
          ),
        ),
      );
      final (_, OnboardingStepController controller) = await pumpTrade(
        tester,
        stack: stack,
      );
      await tester.pumpAndSettle();

      expect(find.text('Trade proof under review'), findsOneWidget);
      expect(find.text('Choose file'), findsNothing);
      expect(controller.canPrimary, isFalse);
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('rejected proof offers resubmission instead of review copy', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: const <String, String>{'prof-sw': 'unverified'},
            latestSubmissions: <VerificationSubmissionSummary>[
              seedSubmissionSummary(
                submissionType: 'trade_proof',
                professionId: 'prof-sw',
                status: VerificationStatusKind.rejected,
              ),
            ],
          ),
        ),
      );
      final (_, OnboardingStepController controller) = await pumpTrade(
        tester,
        stack: stack,
      );
      await tester.pumpAndSettle();

      expect(find.text('Trade proof needs attention'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
      expect(find.text('Trade proof under review'), findsNothing);
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('approved proof exposes finish registration, not submit', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: const <String, String>{'prof-sw': 'approved'},
            latestSubmissions: <VerificationSubmissionSummary>[
              seedSubmissionSummary(
                submissionType: 'trade_proof',
                professionId: 'prof-sw',
                status: VerificationStatusKind.approved,
              ),
            ],
          ),
        ),
      );
      final (_, OnboardingStepController controller) = await pumpTrade(
        tester,
        stack: stack,
      );
      await tester.pumpAndSettle();

      expect(find.text('Trade approved'), findsOneWidget);
      expect(find.text('Choose file'), findsNothing);
      expect(controller.primaryLabel, 'Finish registration');
      controller.dispose();
      stack.provider.dispose();
    });
  });
}
