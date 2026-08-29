import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/providers/entity_provider.dart';

/// Matches an [EntityProvider] currently in the loading state.
Matcher hasLoadingState() => _ProviderStateMatcher(
      EntityProviderState.loading,
      'loading',
    );

/// Matches an [EntityProvider] currently in the loaded/success state,
/// optionally asserting the error message substring.
Matcher hasLoadedState() => _ProviderStateMatcher(
      EntityProviderState.loaded,
      'loaded',
    );

/// Matches an [EntityProvider] currently in the error state, optionally
/// asserting that its [EntityProvider.error] message contains [messageContains].
Matcher hasErrorState({String? messageContains}) => _ProviderErrorMatcher(
      messageContains: messageContains,
    );

class _ProviderStateMatcher extends Matcher {
  const _ProviderStateMatcher(this.expected, this.label);

  final EntityProviderState expected;
  final String label;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) =>
      item is EntityProvider && item.state == expected;

  @override
  Description describe(Description description) =>
      description.add('has provider state "$label"');

  @override
  Description describeMismatch(
    Object? item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) =>
      item is EntityProvider
          ? description.add('had state "${item.state.name}"')
          : description.add('was not an EntityProvider');
}

class _ProviderErrorMatcher extends Matcher {
  const _ProviderErrorMatcher({this.messageContains});

  final String? messageContains;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! EntityProvider) {
      return false;
    }
    if (item.state != EntityProviderState.error) {
      return false;
    }
    if (messageContains != null && item.error != null) {
      return item.error!.message.contains(messageContains!);
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('has provider error state');
    if (messageContains != null) {
      description.add(' with message containing "$messageContains"');
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
    if (item is! EntityProvider) {
      return description.add('was not an EntityProvider');
    }
    if (item.state != EntityProviderState.error) {
      return description.add('had state "${item.state.name}"');
    }
    if (messageContains != null && item.error != null) {
      return description.add('message was "${item.error!.message}"');
    }
    return description.add('was in error state');
  }
}
