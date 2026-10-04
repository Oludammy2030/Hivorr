import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/activities/models/hivorr_activity.dart';

void main() {
  group('HivorrActivity catalogue', () {
    test('exposes three explore and three earn activities', () {
      expect(HivorrActivity.explore.length, 3);
      expect(HivorrActivity.earn.length, 3);
      expect(
        HivorrActivity.explore.map((HivorrActivity a) => a.name),
        <String>['buy', 'hire', 'exploreServices'],
      );
      expect(
        HivorrActivity.earn.map((HivorrActivity a) => a.name),
        <String>['sell', 'offerServices', 'logistics'],
      );
    });

    test('sections split explore vs earn', () {
      for (final HivorrActivity activity in HivorrActivity.explore) {
        expect(activity.section, HivorrActivitySection.explore);
      }
      for (final HivorrActivity activity in HivorrActivity.earn) {
        expect(activity.section, HivorrActivitySection.earn);
      }
    });

    test('live today: hire + explore services + offer services', () {
      expect(HivorrActivity.hire.isLive, isTrue);
      expect(HivorrActivity.exploreServices.isLive, isTrue);
      expect(HivorrActivity.offerServices.isLive, isTrue);
    });

    test('coming soon stays honest: buy + sell + logistics', () {
      for (final HivorrActivity activity in <HivorrActivity>[
        HivorrActivity.buy,
        HivorrActivity.sell,
        HivorrActivity.logistics,
      ]) {
        expect(activity.isLive, isFalse);
        expect(activity.comingSoonLabel, isNotNull);
      }
    });

    test('every card carries a title, subtitle and icon', () {
      for (final HivorrActivity activity in HivorrActivity.values) {
        expect(activity.title, isNotEmpty);
        expect(activity.subtitle, isNotEmpty);
      }
    });
  });
}
