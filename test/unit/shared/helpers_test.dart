import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

void main() {
  group('HivorrSpacing', () {
    test('scale values', () {
      expect(HivorrSpacing.xs, 4.0);
      expect(HivorrSpacing.sm, 8.0);
      expect(HivorrSpacing.md, 16.0);
      expect(HivorrSpacing.lg, 24.0);
      expect(HivorrSpacing.xl, 32.0);
      expect(HivorrSpacing.xxl, 48.0);
    });
  });

  group('HivorrFormatters', () {
    test('date / time / dateTime', () {
      expect(HivorrFormatters.date(DateTime(2026, 8, 26)), '26 Aug 2026');
      expect(HivorrFormatters.time(DateTime(2026, 1, 1, 14, 30)), '14:30');
      expect(
        HivorrFormatters.dateTime(DateTime(2026, 8, 26, 9, 5)),
        '26 Aug 2026 09:05',
      );
    });

    test('number adds thousands separators', () {
      expect(HivorrFormatters.number(1234.5), '1,234.50');
      expect(HivorrFormatters.number(1000000, decimals: 0), '1,000,000');
      expect(HivorrFormatters.number(-1234), '-1,234.00');
    });

    test('fileSize', () {
      expect(HivorrFormatters.fileSize(500), '500 B');
      expect(HivorrFormatters.fileSize(1024), '1 KB');
      expect(HivorrFormatters.fileSize(1500), '1.5 KB');
      expect(HivorrFormatters.fileSize(1048576), '1 MB');
      expect(HivorrFormatters.fileSize(2000000000), '2 GB');
      expect(HivorrFormatters.fileSize(2400000), '2.4 MB');
    });

    test('relative', () {
      final DateTime now = DateTime.now();
      expect(HivorrFormatters.relative(now), 'just now');
      expect(
        HivorrFormatters.relative(now.subtract(const Duration(hours: 3))),
        '3 hours ago',
      );
      expect(
        HivorrFormatters.relative(now.subtract(const Duration(days: 3))),
        '3 days ago',
      );
    });
  });

  group('Breakpoints', () {
    test('fromWidth resolves correct tier', () {
      expect(Breakpoints.fromWidth(100), Breakpoint.mobile);
      expect(Breakpoints.fromWidth(599), Breakpoint.mobile);
      expect(Breakpoints.fromWidth(600), Breakpoint.tablet);
      expect(Breakpoints.fromWidth(1023), Breakpoint.tablet);
      expect(Breakpoints.fromWidth(1024), Breakpoint.desktop);
      expect(Breakpoints.fromWidth(2000), Breakpoint.desktop);
    });
  });
}
