import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/support/models/picked_evidence.dart';
import 'package:hivorr/systems/support/screens/dispute_evidence_form_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  final Uint8List pdfBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  DisputeProvider providerWith(DisputeRepository repository) =>
      DisputeProvider(service: DisputeService(repository: repository));

  Future<void> pumpForm(
    WidgetTester tester,
    DisputeProvider provider, {
    PickEvidenceCallback? pickFile,
    UploadEvidenceCallback? uploadFile,
  }) async {
    await pumpApp(
      tester,
      DisputeEvidenceFormScreen(
        caseId: 'dispute-1',
        pickFile: pickFile,
        uploadFile: uploadFile,
      ),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<DisputeProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.tap(find.text('Evidence type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(WidgetTester tester, String title) async {
    await tester.enterText(find.widgetWithText(TextField, 'Title'), title);
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Submit evidence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit evidence'));
    await tester.pumpAndSettle();
  }

  HivorrButton submitWidget(WidgetTester tester) =>
      tester.widget<HivorrButton>(
        find.ancestor(
          of: find.text('Submit evidence'),
          matching: find.byType(HivorrButton),
        ),
      );

  group('DisputeEvidenceFormScreen', () {
    testWidgets('renders the Add evidence app bar and evidence-type dropdown',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpForm(tester, provider);

      expect(find.widgetWithText(AppBar, 'Add evidence'), findsOneWidget);
      await tester.tap(find.text('Evidence type'));
      await tester.pumpAndSettle();
      for (final String label in <String>[
        'Document',
        'Screenshot',
        'Description',
        'Photo',
      ]) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('surfaces the permanent-record immutability notice',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpForm(tester, provider);

      expect(
        find.textContaining('recorded permanently and cannot be edited'),
        findsOneWidget,
      );
    });

    testWidgets('submit stays disabled until a type and title are entered',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpForm(tester, provider);
      expect(submitWidget(tester).onPressed, isNull);

      await selectType(tester, 'Description');
      await tester.pump();
      expect(submitWidget(tester).onPressed, isNull); // title missing

      await enterTitle(tester, 'My evidence');
      await tester.pump();
      expect(submitWidget(tester).onPressed, isNotNull);
    });

    testWidgets('description-type evidence needs no attachment and submits',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpForm(tester, provider);
      await selectType(tester, 'Description');
      await enterTitle(tester, 'Written account');

      // No Choose-file card for description-type evidence.
      expect(find.text('Choose file'), findsNothing);

      await tapSubmit(tester);

      expect(repository.submitEvidenceCallCount, 1);
      expect(repository.lastEvidenceTypeCode, 'description');
      expect(repository.lastFileUrl, isNull);
    });

    testWidgets('an attachment type stays disabled until a file is picked',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpForm(
        tester,
        provider,
        pickFile: () async => null,
        uploadFile: (_) async => 'entity/dispute-1/file.pdf',
      );
      await selectType(tester, 'Document');
      await enterTitle(tester, 'Delivery note');

      expect(submitWidget(tester).onPressed, isNull); // no file picked
      expect(find.text('Choose file'), findsOneWidget);
    });

    testWidgets('an invalid file type shows the friendly pick error',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpForm(
        tester,
        provider,
        pickFile: () async => PickedEvidence(
          bytes: pdfBytes,
          fileName: 'movie.mp4',
          mimeType: 'video/mp4',
        ),
        uploadFile: (_) async => 'entity/dispute-1/movie.mp4',
      );
      await selectType(tester, 'Document');
      await enterTitle(tester, 'Delivery note');

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This file type is not supported'),
        findsOneWidget,
      );
      expect(submitWidget(tester).onPressed, isNull);
    });

    testWidgets('a valid pick + upload submits with the storage path',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);
      String? uploaded;

      await pumpForm(
        tester,
        provider,
        pickFile: () async => PickedEvidence(
          bytes: pdfBytes,
          fileName: 'delivery.pdf',
          mimeType: 'application/pdf',
        ),
        uploadFile: (PickedEvidence evidence) async {
          uploaded = evidence.fileName;
          return 'entity/dispute-1/delivery.pdf';
        },
      );
      await selectType(tester, 'Document');
      await enterTitle(tester, 'Delivery note');

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('delivery.pdf'), findsOneWidget);

      await tapSubmit(tester);

      expect(uploaded, 'delivery.pdf'); // storage-before-RPC: upload happened
      expect(repository.submitEvidenceCallCount, 1);
      expect(repository.lastFileUrl, 'entity/dispute-1/delivery.pdf');
      expect(
        repository.lastFileMetadata,
        <String, dynamic>{
          'mimeType': 'application/pdf',
          'sizeBytes': 4,
          'originalName': 'delivery.pdf',
        },
      );
    });

    testWidgets('a failed upload never calls submitEvidence',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpForm(
        tester,
        provider,
        pickFile: () async => PickedEvidence(
          bytes: pdfBytes,
          fileName: 'delivery.pdf',
          mimeType: 'application/pdf',
        ),
        uploadFile: (_) async => null,
      );
      await selectType(tester, 'Document');
      await enterTitle(tester, 'Delivery note');

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      expect(find.textContaining('Upload failed'), findsOneWidget);
      expect(repository.submitEvidenceCallCount, 0);
    });

    testWidgets('a successful submit pops the screen',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpForm(
        tester,
        provider,
        pickFile: () async => PickedEvidence(
          bytes: pdfBytes,
          fileName: 'note.png',
          mimeType: 'image/png',
        ),
        uploadFile: (_) async => 'entity/dispute-1/note.png',
      );
      await selectType(tester, 'Photo');
      await enterTitle(tester, 'Delivery photo');

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      await tapSubmit(tester);

      // The form pops back to its host route.
      expect(find.byType(DisputeEvidenceFormScreen), findsNothing);
      expect(repository.submitEvidenceCallCount, 1);
    });
  });
}