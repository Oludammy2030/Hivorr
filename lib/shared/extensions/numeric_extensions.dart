import 'package:hivorr/shared/helpers/hivorr_formatters.dart';

/// Convenience formatting utilities on [num].
extension NumericExtensions on num {
  /// Formats this number as currency with thousands separators and two
  /// decimals. Defaults to the Naira symbol (`₦`).
  ///
  /// Example: `1500.toCurrency()` → `"₦1,500.00"`.
  String toCurrency({String symbol = '₦'}) {
    final String formatted = HivorrFormatters.number(this, decimals: 2);
    return '$symbol$formatted';
  }

  /// Appends an English ordinal suffix (`st`, `nd`, `rd`, `th`).
  ///
  /// Example: `1.toOrdinal()` → `"1st"`, `11.toOrdinal()` → `"11th"`.
  String toOrdinal() {
    final int value = round();
    final String sign = value < 0 ? '-' : '';
    final int abs = value.abs();
    final int mod100 = abs % 100;
    final String suffix;
    if (mod100 >= 11 && mod100 <= 13) {
      suffix = 'th';
    } else {
      switch (abs % 10) {
        case 1:
          suffix = 'st';
        case 2:
          suffix = 'nd';
        case 3:
          suffix = 'rd';
        default:
          suffix = 'th';
      }
    }
    return '$sign$abs$suffix';
  }
}
