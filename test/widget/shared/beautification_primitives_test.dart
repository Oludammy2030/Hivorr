import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/entry/screens/welcome_screen.dart';
import 'package:hivorr/app/public/screens/pricing_screen.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_faq_item.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
import 'package:hivorr/shared/components/hivorr_hero_panel.dart';
import 'package:hivorr/shared/components/hivorr_mini_bars.dart';
import 'package:hivorr/shared/components/hivorr_pricing_tier.dart';
import 'package:hivorr/shared/components/hivorr_stat_band.dart';
import 'package:hivorr/shared/components/hivorr_step_card.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/router_harness.dart';
import '../../support/harnesses/widget_harness.dart';

/// Pumps [child] at [width] and fails on any layout exception (e.g.
/// RenderFlex overflow on narrow phones).
Future<void> _pumpClean(
  WidgetTester tester,
  Widget child, {
  required double width,
}) async {
  await pumpScreen(tester, child, width: width, height: 800);
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'layout exception at ${width.toInt()}dp',
  );
}

Widget _themed(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('Beautification primitives (Phase 0)', () {
    for (final double width in <double>[390, 1280]) {
      testWidgets('hero + stats render cleanly at ${width.toInt()}dp', (
        tester,
      ) async {
        await _pumpClean(
          tester,
          _themed(
            HivorrHeroPanel(
              eyebrow: 'EYEBROW',
              title: 'Title',
              subtitle: 'Subtitle copy for the hero panel.',
              primaryLabel: 'Primary',
              secondaryLabel: 'Secondary',
              statistics: const <HivorrHeroStat>[
                HivorrHeroStat(value: '1', label: 'one'),
                HivorrHeroStat(value: '2', label: 'two'),
              ],
            ),
          ),
          width: width,
        );
      });

      testWidgets('stat band + feature cards render at ${width.toInt()}dp', (
        tester,
      ) async {
        await _pumpClean(
          tester,
          _themed(
            const Column(
              children: <Widget>[
                HivorrStatBand(
                  items: <HivorrStatItem>[
                    HivorrStatItem(value: '1', label: 'one'),
                    HivorrStatItem(value: '2', label: 'two'),
                  ],
                ),
                HivorrFeatureCard(
                  icon: Icons.star_outline,
                  title: 'Feature',
                  body: 'Body copy.',
                ),
                HivorrStepCard(step: 1, title: 'Step', body: 'Body copy.'),
                HivorrFaqItem(question: 'Q?', answer: 'A.'),
              ],
            ),
          ),
          width: width,
        );
      });

      testWidgets('pricing tiers + CTA band render at ${width.toInt()}dp', (
        tester,
      ) async {
        await _pumpClean(
          tester,
          _themed(
            Column(
              children: <Widget>[
                const HivorrPricingTier(
                  name: 'TIER',
                  price: 'Free',
                  caption: 'Caption.',
                  features: <String>['One', 'Two'],
                  ctaLabel: 'Go',
                  highlighted: true,
                ),
                HivorrCtaBand(
                  title: 'CTA title',
                  actions: <Widget>[
                    HivorrButton(label: 'Go', onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
          width: width,
        );
      });
    }

    testWidgets('welcome renders without overflow on a 390dp phone', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/welcome'),
        ),
        width: 390,
        height: 800,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('pricing renders without overflow on a 390dp phone', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/pricing'),
        ),
        width: 390,
        height: 800,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PricingScreen), findsOneWidget);
    });

    for (final String location in <String>['/login', '/signup']) {
      testWidgets('$location renders without overflow at 390 and 1280dp', (
        tester,
      ) async {
        for (final double width in <double>[390, 1280]) {
          await pumpScreen(
            tester,
            MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: doorRouter(initialLocation: location),
            ),
            width: width,
            height: 800,
            providers: <SingleChildWidget>[
              ChangeNotifierProvider<AuthProvider>.value(
                value: FakeAuthProvider(),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$location @$width');
        }
      });
    }

    testWidgets('store route renders the honest holding state', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/store/demo-store'),
        ),
        width: 390,
        height: 800,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Storefronts are opening soon'), findsOneWidget);
      expect(find.text('demo-store'), findsNothing);
    });

    group('dark theme', () {
      testWidgets('hero + CTA band render cleanly in dark', (tester) async {
        await pumpScreen(
          tester,
          _themed(
            Column(
              children: <Widget>[
                const HivorrHeroPanel(
                  eyebrow: 'EYEBROW',
                  title: 'Title',
                  subtitle: 'Subtitle copy.',
                  primaryLabel: 'Primary',
                ),
                HivorrCtaBand(
                  title: 'CTA title',
                  subtitle: 'Subtitle copy.',
                  actions: <Widget>[
                    HivorrButton(label: 'Go', onPressed: () {}),
                  ],
                ),
              ],
            ),
            dark: true,
          ),
          width: 390,
          height: 800,
          dark: true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('stats + tiers + table + bars render cleanly in dark', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          _themed(
            const Column(
              children: <Widget>[
                HivorrStatBand(
                  items: <HivorrStatItem>[
                    HivorrStatItem(value: '1', label: 'one'),
                  ],
                ),
                HivorrPricingTier(
                  name: 'TIER',
                  price: 'Free',
                  caption: 'Caption.',
                  features: <String>['One'],
                  ctaLabel: 'Go',
                  highlighted: true,
                ),
                HivorrMiniBars(
                  items: <HivorrBarDatum>[
                    HivorrBarDatum(label: 'A', value: 3),
                    HivorrBarDatum(label: 'B', value: 1),
                  ],
                ),
              ],
            ),
            dark: true,
          ),
          width: 1280,
          height: 800,
          dark: true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  });
}
