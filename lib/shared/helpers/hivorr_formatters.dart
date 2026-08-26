/// UI formatters for dates, times, numbers, and file sizes.
///
/// All formatting is locale-naive (English) on purpose: localization is added
/// in EP-01-17. No external package (e.g. `intl`) is used so the design system
/// adds zero new dependencies (EP-01-16 DoD: "No new package dependencies").
class HivorrFormatters {
  const HivorrFormatters._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a date as `"26 Aug 2026"`.
  static String date(DateTime dt, {String? locale}) {
    final int month = dt.month;
    if (month < 1 || month > 12) {
      return '${dt.day} ${dt.year}';
    }
    return '${dt.day} ${_months[month - 1]} ${dt.year}';
  }

  /// Formats a time as `"14:30"` (24-hour, zero-padded).
  static String time(DateTime dt, {String? locale}) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formats a date-time as `"26 Aug 2026, 14:30"`.
  static String dateTime(DateTime dt, {String? locale}) {
    return '${date(dt)} ${time(dt)}';
  }

  /// Formats a number with thousands separators and fixed decimals.
  ///
  /// Example: `1234.5` with `decimals: 2` → `"1,234.50"`.
  static String number(num value, {int decimals = 2}) {
    final String fixed = value.toStringAsFixed(decimals);
    final List<String> parts = fixed.split('.');
    final String intPart = _addThousands(parts[0]);
    if (parts.length > 1) {
      return '$intPart.${parts[1]}';
    }
    return intPart;
  }

  static String _addThousands(String digits) {
    final bool negative = digits.startsWith('-');
    final String body = negative ? digits.substring(1) : digits;
    final StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = body.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(body[i]);
      count++;
    }
    final String reversed =
        buffer.toString().split('').reversed.join();
    return negative ? '-$reversed' : reversed;
  }

  /// Formats a byte count as a human-readable size (B / KB / MB / GB).
  ///
  /// Uses decimal (SI) units: 1 KB = 1,000 B, 1 MB = 1,000,000 B,
  /// 1 GB = 1,000,000,000 B — matching the documented examples.
  static String fileSize(int bytes) {
    if (bytes < 1000) {
      return '$bytes B';
    }
    final double kb = bytes / 1000;
    if (kb < 1000) {
      return '${_trim(kb)} KB';
    }
    final double mb = kb / 1000;
    if (mb < 1000) {
      return '${_trim(mb)} MB';
    }
    final double gb = mb / 1000;
    return '${_trim(gb)} GB';
  }

  static String _trim(double value) {
    final String s = value.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Formats a [DateTime] relative to now ("just now", "3 hours ago",
  /// "yesterday", "2 weeks ago", "3 months ago", "1 year ago").
  static String relative(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 45) {
      return 'just now';
    }
    if (diff.inMinutes < 2) {
      return 'a minute ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    }
    if (diff.inHours < 2) {
      return 'an hour ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    }
    if (diff.inDays < 2) {
      return 'yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    }
    if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    }
    return '${(diff.inDays / 365).floor()} year ago';
  }
}
