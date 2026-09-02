import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/screens/trade_proof_upload_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_trade_verification.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<TradeVerificationProvider> pumpScreenWith(
    WidgetTester tester, {
    TradeVerificationRepository? repo,
    TradePickDocumentCallback? pickFile,
  }) async {
    final TradeVerificationProvider provider =
        TradeVerificationProvider(repo: repo ?? FakeTradeVerificationRepository());
    // Pre-refresh so the aggregate (bound professions) is non-null before the
    // first frame; otherwise the screen falls back to the empty state.
    await provider.refreshStatus();
    await pumpApp(
      tester,
      TradeProofUploadScreen(
        pickFile: pickFile,
        professionLabel: (String id) => 'Profession $id',
      ),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TradeVerificationProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  final Uint8List pdfBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  group('TradeProofUploadScreen layout', () {
    testWidgets('renders the app bar title and proof-type labels',
        (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();

      expect(find.text('Verify your trade'), findsOneWidget);
      expect(find.text('Certificate'), findsOneWidget);
      expect(find.text('Portfolio'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders the no-professions empty state when none are bound',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(statuses: const <String, String>{}),
        ),
      );
      await tester.pump();

      expect(find.text('No bound professions yet'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('submit button is disabled until a file + type selected',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: pdfBytes,
          fileName: 'proof.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pump();

      final Finder submit = find.widgetWithText(HivorrButton, 'Upload & submit');
      final HivorrButton button =
          tester.widget<HivorrButton>(submit);
      expect(button.onPressed, isNull);
      await unmount(tester);
    });
  });

  group('selection + upload', () {
    testWidgets('selecting a proof type enables the upload path',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: pdfBytes,
          fileName: 'proof.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('License'));
      await tester.pump();
      expect(find.text('Professional or occupational license'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('uploading a proof triggers a submit through the provider',
        (WidgetTester tester) async {
      final repo = FakeTradeVerificationRepository();
      await pumpScreenWith(tester, repo: repo, pickFile: () async =>
          PickedDocument(
            bytes: pdfBytes,
            fileName: 'proof.pdf',
            mimeType: 'application/pdf',
          ));
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();
      expect(find.text('proof.pdf'), findsOneWidget);

      await tester.tap(find.text('License'));
      await tester.pump();

      await tester.tap(find.text('Upload & submit'));
      await tester.pump();
      await tester.pump();

      expect(repo.submitCallCount, 1);
      expect(repo.lastType, TradeProofType.license);
      expect(repo.lastProfessionId, 'p1');
      await unmount(tester);
    });

    testWidgets('rejects an unsupported file type with a friendly error',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: pdfBytes,
          fileName: 'evil.html',
          mimeType: 'text/html',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();

      expect(
        find.text('This file type is not supported. Please use JPG, PNG, WebP, or PDF.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('cancelling the file picker leaves nothing selected',
        (WidgetTester tester) async {
      await pumpScreenWith(tester, pickFile: () async => null);
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();

      expect(find.text('Choose file'), findsOneWidget);
      expect(find.text('proof.pdf'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a picked PDF shows the PDF icon, name, and change action',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: pdfBytes,
          fileName: 'proof.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.text('proof.pdf'), findsOneWidget);
      expect(find.byTooltip('Choose a different file'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a picked image shows the generic image icon',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: pdfBytes,
          fileName: 'shot.png',
          mimeType: 'image/png',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('shot.png'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('selecting Other shows its helper line', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();

      await tester.tap(find.text('Other'));
      await tester.pump();

      expect(find.text('Any other acceptable trade proof'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('file validation', () {
    testWidgets('an over-limit file shows the friendly too-large error',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        pickFile: () async => PickedDocument(
          bytes: Uint8List(StorageLimits.credentialDocuments + 1),
          fileName: 'huge.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();

      expect(
        find.text('This file is too large — please use a file under 10 MB.'),
        findsOneWidget,
      );
      expect(find.text('huge.pdf'), findsNothing);
      await unmount(tester);
    });
  });

  group('submit feedback', () {
    testWidgets('shows the success state after a successful submit',
        (WidgetTester tester) async {
      final repo = FakeTradeVerificationRepository();
      await pumpScreenWith(tester, repo: repo, pickFile: () async =>
          PickedDocument(
            bytes: pdfBytes,
            fileName: 'proof.pdf',
            mimeType: 'application/pdf',
          ));
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();
      await tester.tap(find.text('Work Sample'));
      await tester.pump();
      await tester.tap(find.text('Upload & submit'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Submitted for review'), findsOneWidget);
      expect(repo.submitCallCount, 1);
      await unmount(tester);
    });

    testWidgets(
        'a duplicate-submission conflict shows the dedup message + View status, not a retry loop',
        (WidgetTester tester) async {
      final repo = FakeTradeVerificationRepository();
      final TradeVerificationProvider provider =
          TradeVerificationProvider(repo: repo);
      await provider.refreshStatus();
      repo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: VerificationEnvelopeParser.activeConflictMessage,
        code: 'PLT005',
      );

      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.tradeProofUpload,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.tradeProofUpload,
            builder: (_, _) => TradeProofUploadScreen(
              pickFile: () async => PickedDocument(
                bytes: pdfBytes,
                fileName: 'proof.pdf',
                mimeType: 'application/pdf',
              ),
              professionLabel: (String id) => 'Profession $id',
            ),
          ),
          GoRoute(
            path: RoutePaths.tradeVerificationStatus,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('status-screen'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<TradeVerificationProvider>.value(
                value: provider),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose file'));
      await tester.pump();
      await tester.tap(find.text('Work Sample'));
      await tester.pump();
      await tester.tap(find.text('Upload & submit'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Submission failed'), findsOneWidget);
      expect(
        find.text(VerificationEnvelopeParser.activeConflictMessage),
        findsOneWidget,
      );
      final Finder viewStatus = find.widgetWithText(HivorrButton, 'View status');
      expect(viewStatus, findsOneWidget);
      expect(
        find.widgetWithText(HivorrButton, 'Try again'),
        findsNothing,
        reason: 'a duplicate submission must not retry in a loop',
      );

      await tester.ensureVisible(viewStatus);
      await tester.pumpAndSettle();
      await tester.tap(viewStatus);
      await tester.pumpAndSettle();
      expect(find.text('status-screen'), findsOneWidget);
      await unmount(tester);
    });
  });
}
