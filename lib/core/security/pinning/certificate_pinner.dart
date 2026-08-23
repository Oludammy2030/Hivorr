import 'dart:typed_data';

import 'package:hivorr/core/security/crypto/sha256.dart';
import 'package:hivorr/core/security/security_config.dart';

/// Enforces SSL certificate pinning using SPKI SHA-256 (base64) hashes.
///
/// A pinned set of SPKI hashes is supplied (from the EP-01-03
/// [EnvironmentConfig] via [SecurityConfiguration]); a presented certificate's
/// SubjectPublicKeyInfo is hashed and compared. Verification is fail-closed:
/// a missing or non-matching certificate is rejected (EP-01-10 §5.4, §12).
class CertificatePinner {
  const CertificatePinner(this.pinnedHashes);

  /// The set of acceptable SPKI SHA-256 (base64) pins.
  final List<String> pinnedHashes;

  /// Builds a pinner from the resolved security configuration.
  factory CertificatePinner.fromConfiguration(SecurityConfiguration config) {
    return CertificatePinner(config.pinnedSpkiSha256Hashes);
  }

  /// Returns `true` if [hash] (base64 SPKI SHA-256) is among the pins.
  bool verifyHash(String hash) => pinnedHashes.contains(hash);

  /// Returns the base64 SPKI SHA-256 of a DER-encoded certificate.
  String spkiSha256Base64(Uint8List certDer) {
    return sha256Base64(extractSpki(certDer));
  }

  /// Verifies a DER-encoded certificate against the pins.
  bool verifyDer(Uint8List certDer) {
    if (certDer.isEmpty) {
      return false;
    }
    return verifyHash(spkiSha256Base64(certDer));
  }

  /// Verifies raw SPKI bytes against the pins.
  bool verifySpki(Uint8List spkiBytes) {
    return verifyHash(sha256Base64(spkiBytes));
  }

  /// Extracts the SubjectPublicKeyInfo (SPKI) bytes from a DER-encoded X.509
  /// certificate using a minimal DER walker (no external ASN.1 dependency).
  ///
  /// Pinning the SPKI (rather than the whole cert) allows certificate
  /// rotation while keeping the same public key.
  static List<int> extractSpki(Uint8List der) {
    final _Tlv cert = _readTlv(der, 0);
    _expectTag(cert, 0x30);
    final _Tlv tbs = _readTlv(der, cert.contentOffset);
    _expectTag(tbs, 0x30);

    int pos = tbs.contentOffset;
    final int end = tbs.contentOffset + tbs.contentLength;

    // Optional [0] EXPLICIT version.
    _Tlv field = _readTlv(der, pos);
    if (field.tag == 0xA0) {
      pos = field.end;
      if (pos >= end) {
        return <int>[];
      }
      field = _readTlv(der, pos);
    }
    // INTEGER serialNumber
    pos = field.end;
    // SEQUENCE signature
    field = _readTlv(der, pos);
    pos = field.end;
    // SEQUENCE issuer
    field = _readTlv(der, pos);
    pos = field.end;
    // SEQUENCE validity
    field = _readTlv(der, pos);
    pos = field.end;
    // SEQUENCE subject
    field = _readTlv(der, pos);
    pos = field.end;
    // SEQUENCE subjectPublicKeyInfo (SPKI)
    final _Tlv spki = _readTlv(der, pos);
    _expectTag(spki, 0x30);

    return der.sublist(spki.offset, spki.end);
  }

  static _Tlv _readTlv(Uint8List data, int offset) {
    final int tag = data[offset];
    final int lengthByte = data[offset + 1];
    late final int contentLength;
    late final int headerLength;
    if (lengthByte < 0x80) {
      contentLength = lengthByte;
      headerLength = 2;
    } else {
      final int numBytes = lengthByte & 0x7F;
      int value = 0;
      for (int i = 0; i < numBytes; i++) {
        value = (value << 8) | data[offset + 2 + i];
      }
      contentLength = value;
      headerLength = 2 + numBytes;
    }
    final int contentOffset = offset + headerLength;
    return _Tlv(
      tag: tag,
      offset: offset,
      headerLength: headerLength,
      contentLength: contentLength,
      contentOffset: contentOffset,
    );
  }

  static void _expectTag(_Tlv tlv, int expected) {
    if (tlv.tag != expected) {
      throw const FormatException(
        'Unexpected DER tag while extracting SPKI.',
      );
    }
  }
}

class _Tlv {
  const _Tlv({
    required this.tag,
    required this.offset,
    required this.headerLength,
    required this.contentLength,
    required this.contentOffset,
  });

  final int tag;
  final int offset;
  final int headerLength;
  final int contentLength;
  final int contentOffset;

  int get end => contentOffset + contentLength;
}
