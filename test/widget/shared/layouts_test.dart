import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

void main() {
  group('HivorrScreenScaffold', () {
    testWidgets('renders body and app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HivorrScreenScaffold(
            appBar: AppBar(title: const Text('Title')),
            body: const Text('Body'),
          ),
        ),
      );
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('HivorrResponsiveScaffold', () {
    testWidgets('mobile layout when narrow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HivorrResponsiveScaffold(
            mobileBody: const Text('body'),
            sidebar: const Text('side'),
          ),
        ),
      );
      expect(find.text('body'), findsOneWidget);
      expect(find.text('side'), findsNothing);
    });

    testWidgets('shows NavigationRail sidebar when wide', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HivorrResponsiveScaffold(
            mobileBody: const Text('body'),
            sidebar: NavigationRail(
              selectedIndex: 0,
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('falls back to mobile when sidebar is null', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HivorrResponsiveScaffold(mobileBody: const Text('body')),
        ),
      );
      expect(find.text('body'), findsOneWidget);
    });
  });
}
