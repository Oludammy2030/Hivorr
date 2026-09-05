import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:hivorr/systems/finance/widgets/escrow_status_badge.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';

import '../../../support/fakes/finance/fake_escrow_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  AppThemeExtension ext() =>
      AppTheme.lightTheme.extension<AppThemeExtension>()!;

  Future<void> pumpCard(
    WidgetTester tester, {
    List<EscrowMilestone> milestones = const <EscrowMilestone>[],
    double totalAmount = 50000,
    String currencyCode = 'NGN',
  }) =>
      pumpTheme(
        tester,
        MilestoneListCard(
          milestones: milestones,
          totalAmount: totalAmount,
          currencyCode: currencyCode,
        ),
      );

  Color chipColor(WidgetTester tester) {
    final Container container = tester.widget<Container>(
      find.descendant(
        of: find.byType(MilestoneStatusBadge),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  group('MilestoneListCard', () {
    testWidgets('renders the header and milestone rows sorted by sortOrder',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(
            id: 'ms-1',
            milestoneNumber: 2,
            sortOrder: 2,
            title: 'Build',
            amount: 20000,
          ),
          seedMilestoneEntity(
            id: 'ms-0',
            milestoneNumber: 1,
            sortOrder: 1,
            title: 'Design',
            amount: 30000,
          ),
        ],
        totalAmount: 50000,
      );

      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('1. Design'), findsOneWidget);
      expect(find.text('2. Build'), findsOneWidget);
    });

    testWidgets('renders milestone amounts via BalanceFormatter',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(title: 'Design', amount: 30000),
        ],
        totalAmount: 50000,
      );

      expect(find.text('\u20A630,000.00'), findsOneWidget);
    });

    testWidgets('pending chip → "Pending" on surfaceContainerHighest',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'pending'),
        ],
      );

      expect(
        MilestoneStatus.forCode('pending')!.label,
        'Pending',
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(
        chipColor(tester),
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('completed chip → primaryContainer',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'completed'),
        ],
      );

      expect(find.text('Completed — awaiting release'), findsOneWidget);
      expect(
        chipColor(tester),
        AppTheme.lightTheme.colorScheme.primaryContainer,
      );
    });

    testWidgets('released chip → successContainer',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'released'),
        ],
      );

      expect(find.text('Released'), findsOneWidget);
      expect(chipColor(tester), ext().successContainer);
    });

    testWidgets('progress equals releasedTotal / total',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'released', amount: 25000),
          seedMilestoneEntity(
            id: 'ms-2',
            status: 'pending',
            amount: 25000,
          ),
        ],
        totalAmount: 50000,
      );

      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.5, 0.0001));
    });

    testWidgets('progress is 0 when nothing is released',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'pending', amount: 25000),
        ],
        totalAmount: 50000,
      );

      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.0);
    });

    testWidgets('progress clamps to 1.0 when releases exceed total',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'released', amount: 60000),
        ],
        totalAmount: 50000,
      );

      final LinearProgressIndicator bar =
          tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
    });

    testWidgets('released total appears in the header row',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'released', amount: 20000),
          seedMilestoneEntity(
            id: 'ms-2',
            status: 'pending',
            amount: 30000,
          ),
        ],
        totalAmount: 50000,
      );

      expect(find.text('\u20A620,000.00'), findsNWidgets(2));
    });

    testWidgets('unknown milestone status renders no chip',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(status: 'bogus'),
        ],
      );

      expect(find.byType(MilestoneStatusBadge), findsNothing);
    });
  });
}