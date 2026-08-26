import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/lifecycle/app_lifecycle_observer.dart';

void main() {
  group('AppLifecycleObserver', () {
    test('registered callbacks receive lifecycle changes', () {
      final observer = AppLifecycleObserver();
      final received = <AppLifecycleState>[];
      final unregister = observer.register((s) => received.add(s));

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(
        received,
        <AppLifecycleState>[
          AppLifecycleState.resumed,
          AppLifecycleState.paused,
        ],
      );

      unregister();
      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(received.length, 2);
    });

    test('multiple callbacks are all notified', () {
      final observer = AppLifecycleObserver();
      var a = 0;
      var b = 0;
      observer.register((_) => a++);
      observer.register((_) => b++);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(a, 1);
      expect(b, 1);
    });
  });
}
