import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/screens/identity_document_upload_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_verification.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Finder submitButton() => find.byWidgetPredicate(
        (Widget w) => w is HivorrButton && w.label == 'Upload & submit',
      );

  Future<VerificationProvider> pumpScreenWith(
    WidgetTester tester, {
    FakeVerificationRepository? repo,
    Future<PickedDocument?> Function()? pickFile,
  }) async {
    final VerificationProvider provider =
        VerificationProvider(repo: repo ?? FakeVerificationRepository());
    await pumpScreen(
      tester,
      IdentityDocumentUploadScreen(pickFile: pickFile),
      width: 1170,
      height: 2532,
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<VerificationProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  Future<void> tapDocumentType(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> pickValidFile(WidgetTester tester) async {
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
  }

  group('IdentityDocumentUploadScreen layout', () {
    testWidgets('renders title and intro', (WidgetTester tester) async {
      await pumpScreenWith(tester);

      expect(find.text('Verify identity'), findsOneWidget);
      expect(
        find.text(
            'Choose a document type, then upload a clear photo or PDF.'),
        findsOneWidget,
      );
    });

    testWidgets('renders all document type chips', (WidgetTester tester) async {
      await pumpScreenWith(tester);

      expect(find.text('National ID (NIN)'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text("Driver's License (FRSC)"), findsOneWidget);
      expect(find.text("Voter's Card (INEC)"), findsOneWidget);
      expect(find.text('NIN Slip'), findsOneWidget);
    });

    testWidgets('submit is disabled until a type and file are chosen',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'id.png',
          mimeType: 'image/png',
        ),
      );

      HivorrButton button = tester.widget<HivorrButton>(submitButton());
      expect(button.onPressed, isNull);

      await tapDocumentType(tester, 'Passport');
      button = tester.widget<HivorrButton>(submitButton());
      expect(button.onPressed, isNull);

      await pickValidFile(tester);
      button = tester.widget<HivorrButton>(submitButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows the accepted-formats hint', (WidgetTester tester) async {
      await pumpScreenWith(tester);

      expect(find.text('Accepted: JPG, PNG, WebP, PDF up to 10 MB.'),
          findsOneWidget);
    });
  });

  group('document picker interaction', () {
    testWidgets('selecting a type shows its helper text', (tester) async {
      await pumpScreenWith(tester);

      await tapDocumentType(tester, 'National ID (NIN)');
      expect(find.text('Nigerian National Identity Card'), findsOneWidget);
    });

    testWidgets('picking a valid file shows its name and hides the picker',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'nin2019.png',
          mimeType: 'image/png',
        ),
      );

      await pickValidFile(tester);

      expect(find.text('nin2019.png'), findsOneWidget);
      expect(find.text('Choose file'), findsNothing);
    });

    testWidgets('rejects an oversized file with a size error',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List(10 * 1024 * 1024 + 1),
          fileName: 'big.png',
          mimeType: 'image/png',
        ),
      );

      await pickValidFile(tester);

      expect(
        find.textContaining('too large'),
        findsOneWidget,
      );
      expect(find.text('big.png'), findsNothing);
    });

    testWidgets('rejects a blocked mime type', (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List(2),
          fileName: 'page.html',
          mimeType: 'text/html',
        ),
      );

      await pickValidFile(tester);

      expect(
        find.textContaining('not supported'),
        findsOneWidget,
      );
    });
  });

  group('submission', () {
    testWidgets('successful submit shows the success feedback',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'id.png',
          mimeType: 'image/png',
        ),
      );

      await tapDocumentType(tester, 'Passport');
      await pickValidFile(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Submitted for review'), findsOneWidget);
    });

    testWidgets('failed submit shows the error feedback',
        (WidgetTester tester) async {
      final repo = FakeVerificationRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'queue unavailable',
          code: 'X1',
        );
      await pumpScreenWith(
        tester,
        repo: repo,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'id.png',
          mimeType: 'image/png',
        ),
      );

      await tapDocumentType(tester, 'Passport');
      await pickValidFile(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Submission failed'), findsOneWidget);
    });

    testWidgets('a successful submit sets the provider submit state to success',
        (WidgetTester tester) async {
      final provider = await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'id.png',
          mimeType: 'image/png',
        ),
      );

      await tapDocumentType(tester, 'Passport');
      await pickValidFile(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(provider.lastSubmission, isNotNull);
      expect(provider.lastSubmission!.documentType.name, 'passport');
    });
  });
}

