import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/systems/support/widgets/evidence_attachment_card.dart';

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('EvidenceAttachmentCard', () {
    testWidgets('renders the title and the type icon',
        (WidgetTester tester) async {
      final evidence = seedDisputeEvidenceEntity(
        evidenceType: 'screenshot',
        title: 'Mismatch screenshot',
      );
      await pumpTheme(tester, EvidenceAttachmentCard(evidence: evidence));

      expect(find.text('Mismatch screenshot'), findsOneWidget);
      expect(find.byIcon(Icons.screenshot_monitor), findsOneWidget);
    });

    testWidgets('renders the description when present',
        (WidgetTester tester) async {
      final evidence = seedDisputeEvidenceEntity(
        evidenceType: 'description',
        title: 'Written account',
        description: 'Full account of events.',
      );
      await pumpTheme(tester, EvidenceAttachmentCard(evidence: evidence));

      expect(find.text('Full account of events.'), findsOneWidget);
    });

    testWidgets('shows an attachment chip with name and formatted size',
        (WidgetTester tester) async {
      final evidence = seedDisputeEvidenceEntity(
        evidenceType: 'photo',
        title: 'Delivery photo',
        fileUrl: 'entity-filer/dispute-1/photo.jpg',
        fileMetadata: <String, dynamic>{
          'originalName': 'delivery.jpg',
          'sizeBytes': 2048,
        },
      );
      await pumpTheme(tester, EvidenceAttachmentCard(evidence: evidence));

      expect(
        find.text('delivery.jpg · ${HivorrFormatters.fileSize(2048)}'),
        findsOneWidget,
      );
    });

    testWidgets('shows the Preview action only when onPreview and file present',
        (WidgetTester tester) async {
      final evidence = seedDisputeEvidenceEntity(
        evidenceType: 'photo',
        title: 'Delivery photo',
        fileUrl: 'entity-filer/dispute-1/photo.jpg',
        fileMetadata: <String, dynamic>{'originalName': 'delivery.jpg'},
      );
      bool previewed = false;
      await pumpTheme(
        tester,
        EvidenceAttachmentCard(
          evidence: evidence,
          onPreview: () => previewed = true,
        ),
      );

      expect(find.text('Preview'), findsOneWidget);
      await tester.tap(find.text('Preview'));
      expect(previewed, isTrue);
    });

    testWidgets('hides the Preview action when no onPreview is provided',
        (WidgetTester tester) async {
      final evidence = seedDisputeEvidenceEntity(
        evidenceType: 'photo',
        title: 'Delivery photo',
        fileUrl: 'entity-filer/dispute-1/photo.jpg',
        fileMetadata: <String, dynamic>{'originalName': 'delivery.jpg'},
      );
      await pumpTheme(tester, EvidenceAttachmentCard(evidence: evidence));

      expect(find.text('Preview'), findsNothing);
    });
  });
}