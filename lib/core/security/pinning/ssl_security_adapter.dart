import 'package:dio/dio.dart';

import 'certificate_pinner.dart';

import 'ssl_security_adapter_io.dart'
    if (dart.library.html) 'ssl_security_adapter_web.dart';

export 'certificate_pinner.dart';
export 'ssl_security_adapter_io.dart'
    if (dart.library.html) 'ssl_security_adapter_web.dart';

/// Installs SSL certificate pinning onto [dio] using [pinner].
///
/// This is the EP-01-07 Dio integration seam: it sets
/// [HttpClientAdapter] without modifying the API layer (EP-01-10 §5.4).
/// The adapter is only applied when [enablePinning] is `true`; on Web it is a
/// no-op because the browser owns TLS (R3 — accepted residual risk).
void installSslPinning(
  Dio dio, {
  required CertificatePinner pinner,
  required bool enablePinning,
}) {
  dio.httpClientAdapter = SslSecurityAdapter(
    pinner: pinner,
    enablePinning: enablePinning,
  );
}
