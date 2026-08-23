import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/security/crypto/sha256.dart';
import 'package:hivorr/core/security/pinning/certificate_pinner.dart';

void main() {
  group('CertificatePinner', () {
    // Build a minimal, structurally-valid X.509 DER certificate so the SPKI
    // walker can be exercised without a real CA chain.
    final Uint8List spki = _derSequence(<int>[
      0x02,
      0x01,
      0x00, // INTEGER 0 placeholder for the public key material.
    ]);
    final Uint8List cert = _buildCert(spki);

    test('extractSpki returns the SPKI SEQUENCE TLV', () {
      final List<int> extracted = CertificatePinner.extractSpki(cert);
      expect(extracted, spki);
    });

    test('verifyDer is fail-closed for an empty certificate', () {
      final CertificatePinner pinner = CertificatePinner(<String>['abc']);
      expect(pinner.verifyDer(Uint8List(0)), isFalse);
    });

    test('verifyDer succeeds for the matching pin', () {
      final String pin = sha256Base64(spki);
      final CertificatePinner pinner = CertificatePinner(<String>[pin]);
      expect(pinner.verifyDer(cert), isTrue);
    });

    test('verifyDer rejects a non-matching pin', () {
      final CertificatePinner pinner =
          CertificatePinner(<String>['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=']);
      expect(pinner.verifyDer(cert), isFalse);
    });

    test('verifyHash matches by exact pin', () {
      final String pin = sha256Base64(spki);
      final CertificatePinner pinner = CertificatePinner(<String>[pin]);
      expect(pinner.verifyHash(pin), isTrue);
      expect(pinner.verifyHash('other'), isFalse);
    });

    test('spkiSha256Base64 is consistent with sha256 of the SPKI', () {
      final CertificatePinner pinner = CertificatePinner(<String>[sha256Base64(spki)]);
      expect(pinner.spkiSha256Base64(cert), sha256Base64(spki));
    });
  });
}

/// Encodes a DER TLV with the given tag and content.
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

/// Assembles Certificate ::= SEQUENCE { TBSCertificate, algorithm, signature }.
/// The walker only navigates the TBSCertificate to the SPKI, so the trailing
/// fields are placeholders.
Uint8List _buildCert(Uint8List spki) {
  final Uint8List serial = _derTlv(0x02, <int>[0x01]); // INTEGER 1
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
