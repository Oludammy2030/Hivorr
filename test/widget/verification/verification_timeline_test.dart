import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/systems/verification/widgets/verification_timeline.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  final DateTime submitted = DateTime(2026, 3, 14, 9, 30);
  final DateTime reviewed = DateTime(2026, 3, 15, 11, 0);

  Future<void> pump(WidgetTester tester, VerificationTimeline timeline) =>
      pumpTheme(tester, timeline);

  group('VerificationTimeline layout', () {
    testWidgets('renders all four step titles', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(status: VerificationStatusKind.pending),
      );

      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Decision'), findsOneWidget);
    });

    testWidgets('marks the pending step as the current selection', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(status: VerificationStatusKind.pending),
      );

      final Text pendingTitle =
          tester.widget<Text>(find.text('Pending review'));
      expect(pendingTitle.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('marks the in-review step as current when in review', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(status: VerificationStatusKind.inReview),
      );

      final Text inReviewTitle =
          tester.widget<Text>(find.text('In review'));
      expect(inReviewTitle.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('approved uses the Approved label and selected-decided step',
        (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(status: VerificationStatusKind.approved),
      );

      expect(find.text('Approved'), findsOneWidget);
      final Text approvedTitle =
          tester.widget<Text>(find.text('Approved'));
      expect(approvedTitle.style?.fontWeight, FontWeight.w600);
    });
  });

  group('VerificationTimeline captions & decisions', () {
    testWidgets('renders the submitted date caption', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(
          status: VerificationStatusKind.inReview,
          submittedAt: submitted,
        ),
      );

      expect(find.text('Mar 14, 2026 · 9:30 AM'), findsOneWidget);
    });

    testWidgets('renders the reviewed date caption on the decided step', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(
          status: VerificationStatusKind.approved,
          reviewedAt: reviewed,
        ),
      );

      expect(find.text('Mar 15, 2026 · 11:00 AM'), findsOneWidget);
    });

    testWidgets('rejected shows decision notes', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(
          status: VerificationStatusKind.rejected,
          decisionNotes: 'ID was illegible',
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('ID was illegible'), findsOneWidget);
    });

    testWidgets('requiresResubmission shows its label + notes', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(
          status: VerificationStatusKind.requiresResubmission,
          decisionNotes: 'Please sharpen the photo',
        ),
      );

      expect(find.text('Requires resubmission'), findsOneWidget);
      expect(find.text('Please sharpen the photo'), findsOneWidget);
    });

    testWidgets('approved does not render decision notes', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(
          status: VerificationStatusKind.approved,
          decisionNotes: 'ignored',
        ),
      );

      expect(find.text('ignored'), findsNothing);
    });

    testWidgets('omits captions when dates are absent', (WidgetTester tester) async {
      await pump(
        tester,
        VerificationTimeline(status: VerificationStatusKind.pending),
      );

      expect(find.textContaining('Mar'), findsNothing);
    });
  });

  group('VerificationTimeline.stepIndexFor', () {
    test('maps each status to the expected step index', () {
      expect(VerificationTimeline.stepIndexFor(VerificationStatusKind.pending), 1);
      expect(
        VerificationTimeline.stepIndexFor(VerificationStatusKind.inReview),
        2,
      );
      expect(
        VerificationTimeline.stepIndexFor(VerificationStatusKind.approved),
        3,
      );
      expect(
        VerificationTimeline.stepIndexFor(VerificationStatusKind.rejected),
        3,
      );
      expect(
        VerificationTimeline.stepIndexFor(
            VerificationStatusKind.requiresResubmission),
        3,
      );
    });
  });
}

