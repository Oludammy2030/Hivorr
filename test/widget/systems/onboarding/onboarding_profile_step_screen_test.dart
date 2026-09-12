import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
import 'package:hivorr/systems/onboarding/screens/profile_setup_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileSetupScreen (FV-29, FV-38)', () {
    Future<(OnboardingTestStack, OnboardingStepController)> pumpProfile(
      WidgetTester tester, {
      OnboardingTestStack? stack,
      Future<PickedAvatar?> Function()? pickAvatar,
    }) async {
      final OnboardingTestStack s = stack ?? buildOnboardingStack();
      final OnboardingStepController controller = OnboardingStepController();
      await s.hydrate('u1');
      await pumpOnboardingScreen(
        tester,
        ProfileSetupScreen(
          active: true,
          controller: controller,
          pickAvatar: pickAvatar,
        ),
        path: '/onboarding/profile',
        providers: s.buildProviders(),
      );
      return (s, controller);
    }

    testWidgets('renders profile fields, avatar picker, and helper copy', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, _) = await pumpProfile(tester);
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Middle name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Profile avatar'), findsOneWidget);
      expect(find.text('No avatar selected'), findsOneWidget);
      expect(
        find.text('This name appears publicly on your profile.'),
        findsOneWidget,
      );
      stack.provider.dispose();
    });

    testWidgets(
      'primary CTA is disabled until first and last names are provided',
      (WidgetTester tester) async {
        final (OnboardingTestStack stack, OnboardingStepController controller) =
            await pumpProfile(tester);
        expect(controller.primaryLabel, 'Save & continue');
        expect(controller.canPrimary, isFalse);

        await tester.enterText(find.byType(TextField).at(0), 'Jane');
        await tester.enterText(find.byType(TextField).at(2), 'Doe');
        await tester.enterText(find.byType(TextField).at(3), 'Jane');
        await tester.pump();
        expect(controller.canPrimary, isTrue);
        stack.provider.dispose();
      },
    );

    testWidgets('legal name is required even when display name is filled', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).at(3), 'Jane');
      await tester.pump();
      expect(controller.canPrimary, isFalse);
      stack.provider.dispose();
    });

    testWidgets('bio remains optional', (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Jane');
      await tester.enterText(find.byType(TextField).at(2), 'Doe');
      await tester.enterText(find.byType(TextField).at(3), 'Jane');
      await tester.pump();
      expect(controller.canPrimary, isTrue);
      stack.provider.dispose();
    });

    testWidgets(
      'picking a valid avatar shows the file name + change affordance',
      (WidgetTester tester) async {
        final (OnboardingTestStack stack, _) = await pumpProfile(
          tester,
          pickAvatar: () async => seedPickedAvatar(),
        );
        await tester.ensureVisible(find.text('Choose avatar'));
        await tester.pump();
        await tester.tap(find.text('Choose avatar'));
        await tester.pumpAndSettle();
        expect(find.text('me.png'), findsOneWidget);
        expect(find.text('Change avatar'), findsOneWidget);
        expect(find.text('No avatar selected'), findsNothing);
        stack.provider.dispose();
      },
    );

    testWidgets('rejecting an unsupported avatar type surfaces inline error', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, _) = await pumpProfile(
        tester,
        pickAvatar: () async => PickedAvatar(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'anim.gif',
          mimeType: 'image/gif',
        ),
      );
      await tester.ensureVisible(find.text('Choose avatar'));
      await tester.pump();
      await tester.tap(find.text('Choose avatar'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This image type is not supported. Please use JPEG, PNG, or WebP.',
        ),
        findsOneWidget,
      );
      expect(find.text('No avatar selected'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('submit runs completeProfile then advances to capability', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Jane');
      await tester.enterText(find.byType(TextField).at(2), 'Doe');
      await tester.enterText(find.byType(TextField).at(3), 'Jane');
      await tester.pump();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(stack.remote.updateProfileCallCount, 1);
      expect(stack.remote.profile?.legalName, 'Jane Doe');
      expect(stack.provider.currentStep, isNotNull);
      expect(find.text('ONBOARDING-CAPABILITY'), findsOneWidget);
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('middle name is included in combined legal name', (
      WidgetTester tester,
    ) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Jane');
      await tester.enterText(find.byType(TextField).at(1), 'Marie');
      await tester.enterText(find.byType(TextField).at(2), 'Doe');
      await tester.enterText(find.byType(TextField).at(3), 'Jane');
      await tester.pump();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(stack.remote.updateProfileCallCount, 1);
      expect(stack.remote.profile?.legalName, 'Jane Marie Doe');
      controller.dispose();
      stack.provider.dispose();
    });

    testWidgets('PLT003 upload rejection surfaces the error inline', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      final OnboardingStepController controller = OnboardingStepController();
      await stack.hydrate('u1');
      stack.storage.nextError = const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'This image is too large — please use a JPEG, PNG, or WebP under 5 MB.',
        code: 'PLT003',
      );
      await pumpOnboardingScreen(
        tester,
        ProfileSetupScreen(
          active: true,
          controller: controller,
          pickAvatar: () async => seedPickedAvatar(),
        ),
        path: '/onboarding/profile',
        providers: stack.buildProviders(),
      );
      await tester.ensureVisible(find.text('Choose avatar'));
      await tester.pump();
      await tester.tap(find.text('Choose avatar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Jane');
      await tester.enterText(find.byType(TextField).at(2), 'Doe');
      await tester.enterText(find.byType(TextField).at(3), 'Jane');
      await tester.pump();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();

      expect(stack.provider.submitState, SubmitState.error);
      expect(stack.provider.lastError?.code, 'PLT003');
      expect(
        stack.storage.uploadCallCount,
        0,
        reason: 'reject-before-upload: validation failures never hit network',
      );
      expect(
        find.text(
          'This image is too large — please use a JPEG, PNG, or WebP '
          'under 5 MB.',
        ),
        findsOneWidget,
      );
      controller.dispose();
      stack.provider.dispose();
    });
  });
}
