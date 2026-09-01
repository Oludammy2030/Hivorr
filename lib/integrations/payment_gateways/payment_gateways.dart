/// Payment gateway abstraction layer — external financial provider adapters.
///
/// `lib/systems/finance/` (EP-02-13/14/16) must import only the abstractions
/// and factory from this barrel — never concrete adapters
/// (ARCHITECTURE.md:151-152). This barrel re-exports the provider-neutral
/// contracts, domain models, config, factory, and concrete adapters.
library;

export 'flutterwave_gateway.dart';
export 'models/payment_models.dart';
export 'name_enquiry_service.dart';
export 'nibss_name_enquiry_adapter.dart';
export 'payment_gateway.dart';
export 'payment_gateway_config.dart';
export 'payment_gateway_factory.dart';
export 'payment_gateway_transport.dart';
export 'paystack_gateway.dart';
