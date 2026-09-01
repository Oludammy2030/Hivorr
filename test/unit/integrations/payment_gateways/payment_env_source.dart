import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// A valid payment-gateway [MapEnvironmentValueSource] for tests, with
/// placeholder keys that pass validation.
///
/// Tests override individual keys by spreading this map.
MapEnvironmentValueSource paymentEnvSource({
  Map<String, String> overrides = const <String, String>{},
}) {
  final Map<String, String> values = <String, String>{
    AppConstants.envPaystackPublicKey: 'pk_test_abc123',
    AppConstants.envPaystackSecretKey: 'sk_test_abc123',
    AppConstants.envFlutterwavePublicKey: 'FLWPUBK_TEST_abc123',
    AppConstants.envFlutterwaveSecretKey: 'FLWSECK_TEST_abc123',
    AppConstants.envPaymentDefaultProvider: 'paystack',
  };
  values.addAll(overrides);
  return MapEnvironmentValueSource(values);
}
