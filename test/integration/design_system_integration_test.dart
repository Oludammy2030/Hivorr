import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_text_theme.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/layouts/hivorr_responsive_scaffold.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';

import '../support/harnesses/widget_harness.dart';

/// Curated set of `Colors.*` material constants (AGENT.md Rule 5 forbids
/// hardcoding these in widgets). `Colors.white`/`Colors.black`/`transparent`
/// are intentionally excluded because legitimate [ColorScheme] tokens (e.g.
/// `onPrimary`) legitimately equal them at runtime.
final Set<Color> _hardcodedColorLibrary = <Color>{
  Colors.red,
  Colors.redAccent,
  Colors.pink,
  Colors.pinkAccent,
  Colors.purple,
  Colors.purpleAccent,
  Colors.deepPurple,
  Colors.deepPurpleAccent,
  Colors.indigo,
  Colors.indigoAccent,
  Colors.blue,
  Colors.blueAccent,
  Colors.lightBlue,
  Colors.lightBlueAccent,
  Colors.cyan,
  Colors.cyanAccent,
  Colors.teal,
  Colors.tealAccent,
  Colors.green,
  Colors.greenAccent,
  Colors.lightGreen,
  Colors.lightGreenAccent,
  Colors.lime,
  Colors.limeAccent,
  Colors.yellow,
  Colors.yellowAccent,
  Colors.amber,
  Colors.amberAccent,
  Colors.orange,
  Colors.orangeAccent,
  Colors.deepOrange,
  Colors.deepOrangeAccent,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
};

const Set<WidgetState> _emptyStates = <WidgetState>{};

/// Framework fonts that may appear in widget subtrees we do not own (e.g. the
/// `EditableText` inside [HivorrTextField] sets a `monospace` `DefaultTextStyle`).
/// AGENT.md Rule 5 forbids *our* widgets from hardcoding a [fontFamily]; framework
/// internals are out of scope for that rule.
const Set<String> _allowedFontFamilies = <String>{'monospace'};

/// Pumps [child] at a fixed logical viewport, normalizing [devicePixelRatio] to
/// 1 so [width]/[height] are interpreted as logical dp (the [pumpScreen] harness
/// only sets physical size, leaving the default DPR in place).
Future<void> _pumpScreenAt(
  WidgetTester tester,
  Widget child, {
  required double width,
  required double height,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpScreen(tester, child, width: width, height: height, dark: dark);
}

void main() {
  group('EP-01-20 VP8 — Design System Integration', () {
    // ── §5.10.1 Mobile rendering (390px) ────────────────────────────────
    group('1. Mobile rendering (390px)', () {
      testWidgets('renders HivorrButton without overflow and applies tokens', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrButton(label: 'Submit', onPressed: () {}),
          width: 390,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(HivorrButton), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);

        final ElevatedButton btn = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final Color? bg = btn.style?.backgroundColor?.resolve(_emptyStates);
        expect(bg, AppTheme.lightTheme.colorScheme.primary);
      });

      testWidgets('renders HivorrTextField without overflow and applies tokens', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          const HivorrTextField(label: 'Email', hint: 'you@example.com'),
          width: 390,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(HivorrTextField), findsOneWidget);

        final TextField tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.decoration?.fillColor, AppTheme.lightTheme.colorScheme.surface);
      });

      testWidgets('renders HivorrCard without overflow and applies tokens', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          const HivorrCard(child: Text('card body')),
          width: 390,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('card body'), findsOneWidget);

        final Container container = tester.widget<Container>(
          find.descendant(
            of: find.byType(HivorrCard),
            matching: find.byType(Container),
          ),
        );
        final BoxDecoration deco = container.decoration! as BoxDecoration;
        expect(deco.color, AppTheme.lightTheme.colorScheme.surface);
        expect(
          (deco.border! as Border).top.color,
          AppTheme.lightTheme.colorScheme.outline,
        );
      });
    });

    // ── §5.10.2 Web rendering (1280px) ──────────────────────────────────
    group('2. Web rendering (1280px)', () {
      testWidgets('renders all widgets responsively without overflow', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          Column(
            children: <Widget>[
              HivorrButton(label: 'Action', onPressed: () {}),
              const SizedBox(height: 16),
              const HivorrTextField(label: 'Name'),
              const SizedBox(height: 16),
              HivorrCard(child: const Text('panel')),
            ],
          ),
          width: 1280,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(HivorrButton), findsOneWidget);
        expect(find.byType(HivorrTextField), findsOneWidget);
        expect(find.byType(HivorrCard), findsOneWidget);
        expect(find.text('panel'), findsOneWidget);
      });

      testWidgets('HivorrButton keeps token colors at web width', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrButton(label: 'Wide', onPressed: () {}),
          width: 1280,
          height: 844,
        );
        await tester.pump();

        final ElevatedButton btn = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final Color? bg = btn.style?.backgroundColor?.resolve(_emptyStates);
        expect(bg, AppTheme.lightTheme.colorScheme.primary);
      });
    });

    // ── §5.10.3 Theme consistency (light → dark) ────────────────────────
    group('3. Theme consistency', () {
      testWidgets('colors derive from AppTheme.lightTheme', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrButton(label: 'Light', onPressed: () {}),
          width: 390,
          height: 844,
          dark: false,
        );
        await tester.pump();

        final ElevatedButton btn = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final Color? bg = btn.style?.backgroundColor?.resolve(_emptyStates);
        expect(bg, AppTheme.lightTheme.colorScheme.primary);
        expect(bg, isNot(AppTheme.darkTheme.colorScheme.primary));
      });

      testWidgets('colors update when switched to AppTheme.darkTheme', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrButton(label: 'Dark', onPressed: () {}),
          width: 390,
          height: 844,
          dark: true,
        );
        await tester.pump();

        final ElevatedButton btn = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final Color? bg = btn.style?.backgroundColor?.resolve(_emptyStates);
        expect(bg, AppTheme.darkTheme.colorScheme.primary);
        expect(bg, isNot(AppTheme.lightTheme.colorScheme.primary));
      });

      testWidgets('textTheme fontFamily is the theme token (Inter)', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          const HivorrButton(label: 'Font', onPressed: null),
          width: 390,
          height: 844,
        );
        await tester.pump();

        final Text text = tester.widget<Text>(find.text('Font'));
        expect(text.style?.fontFamily, AppTextTheme.fontFamily);
      });
    });

    // ── §5.10.4 Responsive scaffolds ────────────────────────────────────
    group('4. Responsive scaffolds', () {
      testWidgets('HivorrResponsiveScaffold shows mobile layout at 390px', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrResponsiveScaffold(
            mobileBody: const Text('mobile body'),
            sidebar: NavigationRail(
              selectedIndex: 0,
              destinations: <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
              ],
            ),
          ),
          width: 390,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('mobile body'), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      });

      testWidgets('HivorrResponsiveScaffold shows web sidebar at 1280px', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrResponsiveScaffold(
            mobileBody: const Text('web body'),
            sidebar: NavigationRail(
              selectedIndex: 0,
              destinations: <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
              ],
            ),
          ),
          width: 1280,
          height: 844,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('web body'), findsOneWidget);
        expect(find.byType(NavigationRail), findsOneWidget);
      });

      testWidgets('HivorrScreenScaffold uses surface background token', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          const HivorrScreenScaffold(body: Text('screen')),
          width: 390,
          height: 844,
        );
        await tester.pump();

        expect(find.text('screen'), findsOneWidget);
        final Scaffold scaffold = tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(HivorrScreenScaffold),
            matching: find.byType(Scaffold),
          ),
        );
        expect(scaffold.backgroundColor, AppTheme.lightTheme.colorScheme.surface);
      });
    });

    // ── §5.10.5 Design token compliance (no hardcoded Colors / fontFamily)
    group('5. Design token compliance', () {
      testWidgets('rendered tree uses only theme tokens (no Colors.*)', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrScreenScaffold(
            body: Column(
              children: <Widget>[
                HivorrButton(label: 'Primary', onPressed: () {}),
                const SizedBox(height: 16),
                const HivorrTextField(label: 'Field', errorText: 'err'),
                const SizedBox(height: 16),
                HivorrCard(child: const Text('card')),
              ],
            ),
          ),
          width: 1280,
          height: 844,
        );
        await tester.pump();

        final List<String> violations = <String>[];
        final Element root = tester.element(find.byType(MaterialApp));
        _scanTree(root, violations);
        expect(violations, isEmpty, reason: violations.join('\n'));
      });

      testWidgets('dark rendered tree uses only theme tokens', (
        WidgetTester tester,
      ) async {
        await _pumpScreenAt(
          tester,
          HivorrScreenScaffold(
            body: Column(
              children: <Widget>[
                HivorrButton(label: 'Ink', onPressed: () {}),
                const HivorrTextField(label: 'F'),
                HivorrCard(child: const Text('c')),
              ],
            ),
          ),
          width: 390,
          height: 844,
          dark: true,
        );
        await tester.pump();

        final List<String> violations = <String>[];
        final Element root = tester.element(find.byType(MaterialApp));
        _scanTree(root, violations);
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    });
  });
}

/// Recursively visits every element under [root], inspecting each widget for
/// hardcoded [Colors.*] values and per-widget [fontFamily] overrides that
/// violate AGENT.md Rule 5.
void _scanTree(Element root, List<String> violations) {
  root.visitChildElements((Element child) {
    _scanWidget(child.widget, violations);
    _scanTree(child, violations);
  });
}

void _scanWidget(Widget widget, List<String> violations) {
  if (widget is Container) {
    _checkColor(widget.color, 'Container.color', violations);
    if (widget.decoration is BoxDecoration) {
      final BoxDecoration d = widget.decoration! as BoxDecoration;
      _checkColor(d.color, 'Container.decoration.color', violations);
      if (d.border != null) {
        _checkBorder(d.border!, 'Container.decoration', violations);
      }
    }
  } else if (widget is DecoratedBox) {
    final Decoration d = widget.decoration;
    if (d is BoxDecoration) {
      _checkColor(d.color, 'DecoratedBox.color', violations);
      if (d.border != null) {
        _checkBorder(d.border!, 'DecoratedBox', violations);
      }
    }
  } else if (widget is ColoredBox) {
    _checkColor(widget.color, 'ColoredBox.color', violations);
  } else if (widget is Material) {
    _checkColor(widget.color, 'Material.color', violations);
  } else if (widget is PhysicalModel) {
    _checkColor(widget.color, 'PhysicalModel.color', violations);
  } else if (widget is Icon) {
    _checkColor(widget.color, 'Icon.color', violations);
  } else if (widget is Text) {
    _checkColor(widget.style?.color, 'Text.color', violations);
    _checkFontFamily(widget.style?.fontFamily, 'Text', violations);
  } else if (widget is DefaultTextStyle) {
    _checkColor(widget.style.color, 'DefaultTextStyle.color', violations);
    _checkFontFamily(widget.style.fontFamily, 'DefaultTextStyle', violations);
  } else if (widget is ButtonStyleButton) {
    final ButtonStyle? s = widget.style;
    if (s != null) {
      _checkColor(
        s.backgroundColor?.resolve(_emptyStates),
        'Button.background',
        violations,
      );
      _checkColor(
        s.foregroundColor?.resolve(_emptyStates),
        'Button.foreground',
        violations,
      );
      final BorderSide? side = s.side?.resolve(_emptyStates);
      if (side != null) {
        _checkColor(side.color, 'Button.side', violations);
      }
    }
  } else if (widget is InputDecorator) {
    final InputDecoration d = widget.decoration;
    _checkColor(d.fillColor, 'InputDecoration.fillColor', violations);
    _checkInputBorder(d.border, 'InputDecoration.border', violations);
    _checkInputBorder(d.enabledBorder, 'InputDecoration.enabledBorder', violations);
    _checkInputBorder(d.focusedBorder, 'InputDecoration.focusedBorder', violations);
    _checkInputBorder(d.errorBorder, 'InputDecoration.errorBorder', violations);
    _checkColor(d.labelStyle?.color, 'InputDecoration.labelStyle.color', violations);
    _checkFontFamily(
      d.labelStyle?.fontFamily,
      'InputDecoration.labelStyle',
      violations,
    );
  }
}

void _checkColor(Color? color, String where, List<String> violations) {
  if (color != null && _hardcodedColorLibrary.contains(color)) {
    violations.add('$where uses hardcoded Colors.* value: $color');
  }
}

void _checkBorder(BoxBorder border, String where, List<String> violations) {
  if (border is Border) {
    _checkColor(border.top.color, '$where.border', violations);
  }
}

void _checkInputBorder(
  InputBorder? border,
  String where,
  List<String> violations,
) {
  if (border is OutlineInputBorder) {
    _checkColor(border.borderSide.color, '$where.borderSide', violations);
  }
}

void _checkFontFamily(String? fontFamily, String where, List<String> violations) {
  if (fontFamily != null &&
      fontFamily != AppTextTheme.fontFamily &&
      !_allowedFontFamilies.contains(fontFamily)) {
    violations.add('$where uses non-theme fontFamily: $fontFamily');
  }
}
