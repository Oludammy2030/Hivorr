/// KYC integration layer barrels (EP-02-12).
///
/// Re-exports the external provider seam, its mock, the result model, and the
/// provider registry. Consumers import this barrel, never the internals.
library;

export 'package:hivorr/integrations/kyc/kyc_provider.dart';
export 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
export 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
export 'package:hivorr/integrations/kyc/mock_kyc_provider.dart';
