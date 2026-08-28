/// Single-import barrel for the EP-01-19 test infrastructure.
///
/// Importing this file exposes all fakes, factories, builders, matchers, and
/// harnesses so feature tests can set up their environment from one line:
///
/// ```dart
/// import 'support/support.dart';
/// ```
library;

export 'builders/config_builders.dart';
export 'builders/dto_builders.dart';
export 'builders/entity_builders.dart';
export 'factories/mock_api_service_factory.dart';
export 'factories/mock_supabase_client_factory.dart';
export 'fakes/fake_api.dart';
export 'fakes/fake_auth.dart';
export 'fakes/fake_datasource.dart';
export 'fakes/fake_logging.dart';
export 'fakes/fake_network.dart';
export 'fakes/fake_notifications.dart';
export 'fakes/fake_storage.dart';
export 'fakes/fake_supabase.dart';
export 'harnesses/async_harness.dart';
export 'harnesses/sentry_harness.dart';
export 'harnesses/widget_harness.dart';
export 'matchers/api_matchers.dart';
export 'matchers/entity_matchers.dart';
export 'matchers/state_matchers.dart';
