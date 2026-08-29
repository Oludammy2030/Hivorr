import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Matches an [ApiException], optionally asserting its [kind] and that its
/// [message] contains a substring. Produces a readable failure description.
Matcher isApiException({
  ApiExceptionKind? kind,
  String? messageContains,
}) =>
    _ApiExceptionMatcher(kind: kind, messageContains: messageContains);

class _ApiExceptionMatcher extends Matcher {
  const _ApiExceptionMatcher({this.kind, this.messageContains});

  final ApiExceptionKind? kind;
  final String? messageContains;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! ApiException) {
      return false;
    }
    if (kind != null && item.kind != kind) {
      return false;
    }
    if (messageContains != null &&
        !item.message.contains(messageContains!)) {
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is an ApiException');
    if (kind != null) {
      description.add(' with kind <$kind>');
    }
    if (messageContains != null) {
      description.add(' whose message contains "$messageContains"');
    }
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! ApiException) {
      return description.add('was not an ApiException (${item?.runtimeType})');
    }
    final List<String> reasons = <String>[];
    if (kind != null && item.kind != kind) {
      reasons.add('kind was <${item.kind}>');
    }
    if (messageContains != null &&
        !item.message.contains(messageContains!)) {
      reasons.add('message was "${item.message}"');
    }
    return description.add(reasons.join(', '));
  }
}

/// Matches an [ApiException] with the exact [ApiExceptionKind].
Matcher hasErrorKind(ApiExceptionKind expected) =>
    isApiException(kind: expected);

/// Matches an [ApiException] or [Response] carrying the given HTTP status code.
Matcher hasStatusCode(int expected) => _HasStatusCode(expected);

class _HasStatusCode extends Matcher {
  const _HasStatusCode(this.expected);

  final int expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is ApiException) {
      return item.statusCode == expected;
    }
    if (item is Response<dynamic>) {
      return item.statusCode == expected;
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('has HTTP status code <$expected>');

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is ApiException) {
      return description.add(
        'had status code <${item.statusCode}> (ApiException)',
      );
    }
    if (item is Response<dynamic>) {
      return description.add('had status code <${item.statusCode}> (Response)');
    }
    return description.add('was not an ApiException or Response');
  }
}
