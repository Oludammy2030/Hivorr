import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/systems/verification/widgets/trade_verification_timeline.dart';

import '../../support/harnesses/widget_harness.dart';

/// Widget coverage for the per-profession trade timeline (EP-02-11 §5.6,
/// §10; TT-10).
void main() {
  final DateTime submitted = DateTime.utc(2026, 1, 1);
  final DateTime reviewed = DateTime.utc(2026, 1, 2);

  Widget wrap(TradeVerification entry, {
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? decisionNotes,
  }) =>
      TradeVerificationTimeline(
        entry: entry,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        decisionNotes: decisionNotes,
      );

  TradeVerification entry(String status) =>
      TradeVerification(professionId: 'p1', status: status);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('step titles', () {
    testWidgets('renders the full Unverified → Submitted → Pending → Decided '
        'progression', (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('approved')));
      await tester.pump();

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('decided step is bold for an approved entry',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('approved')));
      await tester.pump();

      final Text approved = tester.widget<Text>(find.text('Approved'));
      expect(approved.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('pending step is bold while review is pending',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('pending')));
      await tester.pump();

      final Text pending = tester.widget<Text>(find.text('Pending review'));
      expect(pending.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('unverified step is bold when nothing has been submitted',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('unverified')));
      await tester.pump();

      final Text unverified = tester.widget<Text>(find.text('Unverified'));
      expect(unverified.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('rejected entry titles the decided step Rejected',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('rejected')));
      await tester.pump();

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Approved'), findsNothing);
      await unmount(tester);
    });
  });

  group('decision notes', () {
    testWidgets('rejected entry surfaces the admin notes in error tone',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        wrap(
          entry('rejected'),
          decisionNotes: 'Blurred image — please resubmit.',
        ),
      );
      await tester.pump();

      final Text notes = tester.widget<Text>(
        find.text('Blurred image — please resubmit.'),
      );
      expect(notes.style?.color, isNotNull);
      await unmount(tester);
    });

    testWidgets('rejected entry without notes renders no notes line',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('rejected')));
      await tester.pump();

      expect(find.textContaining('Blurred'), findsNothing);
      await unmount(tester);
    });

    testWidgets('approved entry never renders rejection notes',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        wrap(entry('approved'), decisionNotes: 'stale rejection notes'),
      );
      await tester.pump();

      expect(find.text('stale rejection notes'), findsNothing);
      await unmount(tester);
    });
  });

  group('captions + semantics', () {
    testWidgets('renders submitted and reviewed captions once each',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        wrap(
          entry('approved'),
          submittedAt: submitted,
          reviewedAt: reviewed,
        ),
      );
      await tester.pump();

      expect(find.textContaining('2026-01-01'), findsOneWidget);
      expect(find.textContaining('2026-01-02'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no captions render when the timestamps are null',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('approved')));
      await tester.pump();

      expect(find.textContaining('2026-'), findsNothing);
      await unmount(tester);
    });

    testWidgets('marks the current step as Semantics.selected',
        (WidgetTester tester) async {
      await pumpApp(tester, wrap(entry('approved')));
      await tester.pump();

      final Finder decidedSemantics = find
          .ancestor(
            of: find.text('Approved'),
            matching: find.byType(Semantics),
          )
          .first;
      expect(
          tester.getSemantics(decidedSemantics).flagsCollection.isSelected,
          Tristate.isTrue);

      final Finder submittedSemantics = find
          .ancestor(
            of: find.text('Submitted'),
            matching: find.byType(Semantics),
          )
          .first;
      expect(
          tester.getSemantics(submittedSemantics).flagsCollection.isSelected,
          Tristate.isFalse);
      await unmount(tester);
    });
  });

  group('stepIndexFor', () {
    test('maps each kind to the correct active step', () {
      expect(
        TradeVerificationTimeline.stepIndexFor(
          TradeVerification(professionId: 'p', status: 'unverified').statusKind,
        ),
        0,
      );
      expect(
        TradeVerificationTimeline.stepIndexFor(
          TradeVerification(professionId: 'p', status: 'pending').statusKind,
        ),
        2,
      );
      expect(
        TradeVerificationTimeline.stepIndexFor(
          TradeVerification(professionId: 'p', status: 'approved').statusKind,
        ),
        3,
      );
      expect(
        TradeVerificationTimeline.stepIndexFor(
          TradeVerification(professionId: 'p', status: 'rejected').statusKind,
        ),
        3,
      );
    });
  });
}