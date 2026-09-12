import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/systems/onboarding/screens/identity_verification_step_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OnboardingTestStack, OnboardingStepController)> pumpIdentity(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    PickDocumentCallback? pickFile,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    final OnboardingStepController controller = OnboardingStepController();
    await s.hydrate('u1');
    await pumpOnboardingScreen(
      tester,
      IdentityVerificationStepScreen(
        active: true,
        controller: controller,
        pickFile: pickFile,
      ),
      path: '/onboarding/identity',
      providers: s.buildProviders(),
    );
    return (s, controller);
  }

  group('IdentityVerificationStepScreen (FV-22, FV-24)', () {
    testWidgets('renders intro copy and all five document-type chips',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) = await pumpIdentity(tester);
      expect(
        find.text('Verify your identity with a government-issued document.'),
        findsOneWidget,
      );
      for (final DocumentType type in DocumentType.values) {
        expect(find.text(type.label), findsOneWidget);
      }
      expect(find.text('Identity document'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('primary is disabled until both type and file are picked',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpIdentity(tester);
      expect(controller.primaryLabel, 'Upload & submit');
      expect(controller.canPrimary, isFalse);

      await tester.tap(find.text('Passport'));
      await tester.pump();
      expect(controller.canPrimary, isFalse);

      await pumpIdentity(
        tester,
        stack: stack,
        pickFile: () async => seedPickedFile(),
      );
      await tester.pump();
      expect(controller.canPrimary, isFalse, reason: 'type lost on re-pump');
      stack.provider.dispose();
    });

    testWidgets('a document type + picked file enables the primary action',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpIdentity(tester, pickFile: () async => seedPickedFile());
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('document.png'), findsOneWidget);
      expect(controller.canPrimary, isTrue);
      stack.provider.dispose();
    });

    testWidgets('oversized file is rejected inline before upload',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpIdentity(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List(10 * 1024 * 1024 + 1),
          fileName: 'huge.png',
          mimeType: 'image/png',
        ),
      );
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(
        find.text('This file is too large — please use a file under 10 MB.'),
        findsOneWidget,
      );
      expect(controller.canPrimary, isFalse);
      stack.provider.dispose();
    });

    testWidgets('javascript-invalid MIME type is rejected inline',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) = await pumpIdentity(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'notes.txt',
          mimeType: 'text/plain',
        ),
      );
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This file type is not supported. Please use JPG, PNG, WebP, or PDF.',
        ),
        findsOneWidget,
      );
      stack.provider.dispose();
    });

    testWidgets('submit delegates, shows reviewed copy, advances to trade',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpIdentity(tester, pickFile: () async => seedPickedFile());
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(stack.identityRepo.submitCallCount, 1);
      expect(stack.provider.progress!.hasIdentitySubmission, isTrue,
          reason: 'mirror flag set after a successful submission');
      expect(stack.provider.currentStep, isNotNull);
      expect(find.text('ONBOARDING-TRADE-PROOF'), findsOneWidget);
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('pending-verification conflict offers skip + view-status',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack();
      s.identityRepo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'You already have a pending verification for this document.',
        code: 'PLT005',
      );
      final (_, OnboardingStepController controller) =
          await pumpIdentity(tester, stack: s, pickFile: () async => seedPickedFile());
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(
        find.text('You already have a pending verification for this document.'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.text('View status'), findsOneWidget);

      await tester.tap(find.text('View status'));
      await tester.pumpAndSettle();
      expect(find.text('VERIFICATION-STATUS'), findsOneWidget);
      controller.dispose();
      s.provider.dispose();
    });

    testWidgets('skip-for-now advances without a submission or mirror flag',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack();
      s.identityRepo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'You already have a pending verification for this document.',
        code: 'PLT005',
      );
      final (_, OnboardingStepController controller) =
          await pumpIdentity(tester, stack: s, pickFile: () async => seedPickedFile());
      await tester.tap(find.text('Passport'));
      await tester.pump();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(find.text('ONBOARDING-TRADE-PROOF'), findsOneWidget,
          reason: 'skip continues the wizard to the trade step');
      expect(s.identityRepo.submitCallCount, 1,
          reason: 'the failed attempt is not re-fired by skip');
      expect(s.provider.progress!.hasIdentitySubmission, isFalse,
          reason: 'no submission succeeded, so no UX mirror flag');
      controller.dispose();
      s.provider.dispose();
    });
  });
}