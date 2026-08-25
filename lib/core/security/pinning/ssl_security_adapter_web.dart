import 'dart:typed_data';

import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

import 'certificate_pinner.dart';

/// Web build: Dart cannot customize TLS, so pinning is delegated to the
/// browser. The adapter is a pass-through (R3 — accepted residual risk).
class SslSecurityAdapter implements HttpClientAdapter {
  SslSecurityAdapter({required this.pinner, required this.enablePinning})
    : _delegate = BrowserHttpClientAdapter();

  final CertificatePinner pinner;
  final bool enablePinning;
  final HttpClientAdapter _delegate;

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

  /// Mirrors the native enforcement decision so the pinning path is
  /// unit-testable on every platform. On Web the adapter is a pass-through
  /// (R3), so this is intentionally never wired into a TLS validation hook.
  static bool verifyDer(CertificatePinner pinner, Uint8List der) =>
      pinner.verifyDer(der);
}
