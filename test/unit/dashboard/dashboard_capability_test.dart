import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

void main() {
  group('DashboardCapability', () {
    test('maps from the entity capability one-to-one', () {
      expect(
        DashboardCapability.fromEntity(EntityCapability.hire),
        DashboardCapability.hire,
      );
      expect(
        DashboardCapability.fromEntity(EntityCapability.offer),
        DashboardCapability.offer,
      );
      expect(
        DashboardCapability.fromEntity(EntityCapability.both),
        DashboardCapability.both,
      );
    });

    test('hire sees hiring, offer sees work, both sees everything', () {
      expect(DashboardCapability.hire.showsHiring, isTrue);
      expect(DashboardCapability.hire.showsWork, isFalse);
      expect(DashboardCapability.offer.showsHiring, isFalse);
      expect(DashboardCapability.offer.showsWork, isTrue);
      expect(DashboardCapability.both.showsHiring, isTrue);
      expect(DashboardCapability.both.showsWork, isTrue);
    });

    test('labels use Hivorr terminology', () {
      expect(DashboardCapability.hire.label, 'Client');
      expect(DashboardCapability.offer.label, 'Professional');
      expect(DashboardCapability.both.label, 'Both');
    });
  });

  group('dashboardNavItems visibility', () {
    List<String> visible({required bool hire, required bool offer}) =>
        dashboardNavItems
            .where(
              (DashboardNavItem item) =>
                  item.visibleFor(hire: hire, offer: offer),
            )
            .map((DashboardNavItem item) => item.label)
            .toList();

    test('hire sees hiring + shared, not work', () {
      final List<String> labels = visible(hire: true, offer: false);
      expect(
        labels,
        containsAll(<String>[
          'Overview',
          'Post a Job',
          'My Jobs',
          'Find Services',
          'Applications',
          'Payments',
        ]),
      );
      // Client hires live under My Jobs (consolidated) — no Hires entry.
      expect(labels, isNot(contains('Hires')));
      expect(labels, isNot(contains('Find Jobs')));
      expect(labels, isNot(contains('My Applications')));
      expect(labels, isNot(contains('Earnings')));
    });

    test('offer sees work + shared, not hiring', () {
      final List<String> labels = visible(hire: false, offer: true);
      expect(
        labels,
        containsAll(<String>[
          'Overview',
          'Find Jobs',
          'My Applications',
          'My Work',
          'Earnings',
        ]),
      );
      expect(labels, isNot(contains('Post a Job')));
      expect(labels, isNot(contains('My Jobs')));
      expect(labels, isNot(contains('Find Services')));
      expect(labels, isNot(contains('Applications')));
      expect(labels, isNot(contains('Payments')));
    });

    test('both sees the single combined navigation', () {
      final List<String> labels = visible(hire: true, offer: true);
      expect(labels.length, dashboardNavItems.length);
    });

    test('sections order work before hiring before shared', () {
      // Overview (shared) leads; the grouped sections follow.
      final List<DashboardNavSection> sections = dashboardNavItems
          .skip(1)
          .map((DashboardNavItem item) => item.section)
          .toList();
      final int firstWork = sections.indexOf(DashboardNavSection.work);
      final int firstHiring = sections.indexOf(DashboardNavSection.hiring);
      final int firstShared = sections.indexOf(DashboardNavSection.shared);
      expect(firstWork, lessThan(firstHiring));
      expect(firstHiring, lessThan(firstShared));
    });
  });
}
