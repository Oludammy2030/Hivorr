import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:provider/provider.dart';

import '../../support/support.dart';

void main() {
  group('HivorrButton (reference)', () {
    testWidgets('renders label', (tester) async {
      await pumpTheme(tester, HivorrButton(label: 'Submit', onPressed: () {}));
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrButton(label: 'Go', onPressed: () => tapped = true),
      );
      await tester.tap(find.byType(HivorrButton));
      expect(tapped, isTrue);
    });

    testWidgets('disabled state prevents interaction', (tester) async {
      bool tapped = false;
      await pumpTheme(tester, HivorrButton(label: 'No', onPressed: null));
      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
      await tester.tap(
        find.byType(HivorrButton),
        warnIfMissed: false,
      );
      expect(tapped, isFalse);
    });
  });

  group('HivorrTextField (reference)', () {
    testWidgets('shows error message', (tester) async {
      await pumpTheme(
        tester,
        HivorrTextField(label: 'Name', errorText: 'Required'),
      );
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('fires onChanged', (tester) async {
      String? value;
      await pumpTheme(
        tester,
        HivorrTextField(onChanged: (String v) => value = v),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      expect(value, 'hello');
    });
  });

  group('HivorrCard (reference responsive)', () {
    testWidgets('renders at mobile width 390', (tester) async {
      await pumpScreen(
        tester,
        HivorrCard(child: const Text('card')),
        width: 390,
      );
      expect(find.text('card'), findsOneWidget);
      expect(tester.view.physicalSize.width, 390);
    });

    testWidgets('renders at web width 1280', (tester) async {
      await pumpScreen(
        tester,
        HivorrCard(child: const Text('card')),
        width: 1280,
      );
      expect(find.text('card'), findsOneWidget);
      expect(tester.view.physicalSize.width, 1280);
    });
  });

  group('Provider state matchers (reference)', () {
    testWidgets('hasLoadingState / hasLoadedState across a load', (
      tester,
    ) async {
      final EntityRepositoryImpl repo = EntityRepositoryImpl(
        remote: FakeEntityRemoteDataSource()
          ..profile = EntityProfileDtoBuilder().build(),
        local: FakeEntityLocalDataSource(),
      );
      final EntityProvider provider = EntityProvider(repository: repo);
      await pumpApp(
        tester,
        ChangeNotifierProvider<EntityProvider>.value(
          value: provider,
          child: const SizedBox.shrink(),
        ),
      );

      final Future<void> future = provider.loadProfile('e1');
      expect(provider, hasLoadingState());
      await future;
      expect(provider, hasLoadedState());
      expect(provider.profile, isEntityProfile());
    });

    testWidgets('hasErrorState matches a failed load', (tester) async {
      final EntityRepositoryImpl repo = EntityRepositoryImpl(
        remote: FakeEntityRemoteDataSource(),
        local: FakeEntityLocalDataSource(),
      );
      final EntityProvider provider = EntityProvider(repository: repo);
      await pumpApp(
        tester,
        ChangeNotifierProvider<EntityProvider>.value(
          value: provider,
          child: const SizedBox.shrink(),
        ),
      );

      await provider.loadProfile('missing');
      expect(provider, hasErrorState());
    });
  });

  group('Async + Sentry harnesses (reference)', () {
    testWidgets('pumpUntil polls until condition true', (tester) async {
      await pumpTheme(tester, const SizedBox.shrink());
      int ticks = 0;
      await pumpUntil(
        tester,
        () {
          ticks++;
          return ticks >= 3;
        },
        timeout: const Duration(seconds: 2),
        interval: const Duration(milliseconds: 50),
      );
      expect(ticks, greaterThanOrEqualTo(3));
    });

    testWidgets('pumpUntil times out with descriptive message', (
      tester,
    ) async {
      await pumpTheme(tester, const SizedBox.shrink());
      expect(
        () => pumpUntil(tester, () => false, timeout: Duration.zero),
        throwsA(
          isA<Exception>().having(
            (Exception e) => e.toString(),
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('SentryRecordingHarness initializes and resets', () async {
      final SentryRecordingHarness harness = SentryRecordingHarness();
      await harness.setUp();
      await harness.reset();
      expect(harness.capturedEvents, isEmpty);
      expect(harness.capturedBreadcrumbs, isEmpty);
    });
  });
}
