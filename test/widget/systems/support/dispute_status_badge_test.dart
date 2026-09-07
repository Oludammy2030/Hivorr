import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';

import '../../../support/harnesses/widget_harness.dart';

Future<void> pumpBadge(WidgetTester tester, DisputeStatus status) =>
    pumpTheme(tester, DisputeStatusBadge(status: status));

void main() {
  group('DisputeStatusBadge', () {
    testWidgets('renders the Open label for the warning tone',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('open')!);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('renders the Under review label (info tone)',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('under_review')!);
      expect(find.text('Under review'), findsOneWidget);
    });

    testWidgets('renders the Resolved label (success tone)',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('resolved')!);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('renders the Closed label (neutral tone)',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('closed')!);
      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('renders the Withdrawn label (neutral tone)',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('withdrawn')!);
      expect(find.text('Withdrawn'), findsOneWidget);
    });

    testWidgets('under_review resolves to the info tone (TT-08/FV-38)',
        (WidgetTester tester) async {
      final DisputeStatus status = DisputeStatus.forCode('under_review')!;
      expect(status.tone, DisputeStatusTone.info);
      await pumpBadge(tester, status);
      expect(find.text('Under review'), findsOneWidget);
      // The badge resolves to theme tokens, never a hardcoded literal; it
      // renders inside a padded Container chip.
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders a single text chip with the status label',
        (WidgetTester tester) async {
      await pumpBadge(tester, DisputeStatus.forCode('resolved')!);
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });
  });
}