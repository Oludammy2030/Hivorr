import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/security/crypto/sha256.dart';
import 'package:hivorr/core/security/pinning/ssl_security_adapter.dart';

void main() {
  group('SslSecurityAdapter', () {
    // Minimal, structurally-valid X.509 DER cert so the SPKI walker / pinning
    // path can be exercised without a live TLS handshake or a real CA chain.
    final Uint8List spki = _derSequence(<int>[0x02, 0x01, 0x00]);
    final Uint8List cert = _buildCert(spki);
    final String pin = sha256Base64(spki);
    final CertificatePinner pinner = CertificatePinner(<String>[pin]);

    test('verifyDer accepts the matching SPKI pin (fail-closed enforcement)',
        () {
      expect(SslSecurityAdapter.verifyDer(pinner, cert), isTrue);
    });

    test('verifyDer rejects a non-matching pin', () {
      final CertificatePinner wrong =
          CertificatePinner(<String>['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=']);
      expect(SslSecurityAdapter.verifyDer(wrong, cert), isFalse);
    });

    test('verifyDer rejects an empty certificate', () {
      expect(SslSecurityAdapter.verifyDer(pinner, Uint8List(0)), isFalse);
    });

    test('installSslPinning wires a SslSecurityAdapter onto the Dio client', () {
      final Dio dio = Dio();
      installSslPinning(dio, pinner: pinner, enablePinning: true);
      expect(dio.httpClientAdapter, isA<SslSecurityAdapter>());
    });
  });
}

Uint8List _derTlv(int tag, List<int> content) {
  final List<int> out = <int>[tag];
  if (content.length < 0x80) {
    out.add(content.length);
  } else {
    final List<int> lenBytes = <int>[];
    int len = content.length;
    while (len > 0) {
      lenBytes.insert(0, len & 0xFF);
      len >>= 8;
    }
    out.add(0x80 | lenBytes.length);
    out.addAll(lenBytes);
  }
  out.addAll(content);
  return Uint8List.fromList(out);
}

Uint8List _derSequence(List<int> content) => _derTlv(0x30, content);

Uint8List _buildCert(Uint8List spki) {
  final Uint8List serial = _derTlv(0x02, <int>[0x01]);
  final Uint8List alg = _derSequence(<int>[0x02, 0x01, 0x00]);
  final Uint8List issuer = _derSequence(<int>[0x02, 0x01, 0x00]);
  final Uint8List validity = _derSequence(<int>[0x02, 0x01, 0x00]);
  final Uint8List subject = _derSequence(<int>[0x02, 0x01, 0x00]);
  final Uint8List tbs = _derSequence(<int>[
    ...serial,
    ...alg,
    ...issuer,
    ...validity,
    ...subject,
    ...spki,
  ]);
  return _derSequence(<int>[...tbs, ...alg, ...spki]);
}
