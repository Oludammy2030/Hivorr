import 'package:web/web.dart' as web;

/// Removes the password-recovery exchange parameter (`code`) from the browser
/// address bar after it has been consumed.
///
/// The recovery deep link lands on `/reset-password?code=...`; once the code is
/// exchanged the current URL is rewritten without it so a refresh never
/// re-exchanges an already-used code. Other query parameters are preserved.
void clearAuthUrlParameters() {
  final Uri current = Uri.parse(web.window.location.href);
  if (!current.queryParameters.containsKey('code')) {
    return;
  }
  final Map<String, String> params = Map<String, String>.from(
    current.queryParameters,
  )..remove('code');
  final String cleaned = current
      .replace(queryParameters: params.isEmpty ? null : params)
      .toString();
  web.window.history.replaceState(null, '', cleaned);
}
