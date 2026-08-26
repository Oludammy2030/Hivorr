/// Convenience utilities on [String].
extension StringExtensions on String {
  /// Capitalizes the first character, leaving the rest unchanged.
  String get capitalize {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Truncates to [max] characters, appending an ellipsis when cut.
  String truncate(int max) {
    if (length <= max) {
      return this;
    }
    if (max <= 0) {
      return '';
    }
    return '${substring(0, max)}…';
  }

  /// Returns up to two uppercase initials from the words in this string.
  String get initials {
    if (isEmpty) {
      return '';
    }
    final List<String> words =
        split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return '';
    }
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Whether this string is a syntactically valid email address.
  bool get isValidEmail {
    return RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
    ).hasMatch(this);
  }

  /// Whether this string is a valid phone number (E.164 or local format).
  bool get isValidPhone {
    return RegExp(r'^\+?[0-9\s\-()]{7,15}$').hasMatch(this);
  }
}
