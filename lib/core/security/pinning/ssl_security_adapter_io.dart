import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'certificate_pinner.dart';

/// Native (non-Web) SSL-pinning [HttpClientAdapter] for Dio.
///
/// Wraps [IOHttpClientAdapter] and installs a [validateCertificate] callback
/// that enforces the SPKI pins from [pinner] (fail-closed). When [enablePinning]
/// is `false` it delegates to the default behavior (EP-01-10 §5.4).
class SslSecurityAdapter implements HttpClientAdapter {
  SslSecurityAdapter({required this.pinner, required this.enablePinning})
    : _delegate = IOHttpClientAdapter(
        validateCertificate: enablePinning
            ? _validateCertificate(pinner)
            : null,
      );

  final CertificatePinner pinner;
  final bool enablePinning;
  final HttpClientAdapter _delegate;

  static bool Function(X509Certificate? cert, String host, int port)
  _validateCertificate(CertificatePinner pinner) {
    return (X509Certificate? cert, String host, int port) {
      final Uint8List? der = cert?.der;
      if (der == null) {
        return false;
      }
      return SslSecurityAdapter.verifyDer(pinner, der);
    };
  }

  /// The enforcement decision used by [validateCertificate]: SPKI SHA-256 of
  /// the presented certificate must match a pinned hash (fail-closed). Exposed
  /// as a static so the pinning path is unit-testable without a live TLS
  /// handshake (EP-01-10 §5.4).
  static bool verifyDer(CertificatePinner pinner, Uint8List der) =>
      pinner.verifyDer(der);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}
