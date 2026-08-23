import 'dart:convert';
import 'dart:typed_data';

/// SHA-256 (FIPS 180-4) implemented synchronously in pure Dart.
///
/// Synchronous hashing is required by the `badCertificateCallback` TLS hook
/// (which cannot await). This is a self-contained implementation used only
/// for certificate pinning; AES/PBKDF2 continue to use `cryptography`.
Uint8List sha256(List<int> message) {
  final int bitLength = message.length * 8;

  // Pre-processing: padding to a multiple of 64 bytes, then 8-byte length.
  final List<int> padded = List<int>.from(message);
  padded.add(0x80);
  while ((padded.length % 64) != 56) {
    padded.add(0x00);
  }
  for (int i = 7; i >= 0; i--) {
    padded.add((bitLength >> (8 * i)) & 0xFF);
  }

  int h0 = 0x6a09e667;
  int h1 = 0xbb67ae85;
  int h2 = 0x3c6ef372;
  int h3 = 0xa54ff53a;
  int h4 = 0x510e527f;
  int h5 = 0x9b05688c;
  int h6 = 0x1f83d9ab;
  int h7 = 0x5be0cd19;

  final Uint32List w = Uint32List(64);
  for (int offset = 0; offset < padded.length; offset += 64) {
    for (int i = 0; i < 16; i++) {
      int word = 0;
      for (int j = 0; j < 4; j++) {
        word = (word << 8) | padded[offset + i * 4 + j];
      }
      w[i] = word;
    }
    for (int i = 16; i < 64; i++) {
      final int s0 =
          _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final int s1 =
          _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }

    int a = h0;
    int b = h1;
    int c = h2;
    int d = h3;
    int e = h4;
    int f = h5;
    int g = h6;
    int h = h7;

    for (int i = 0; i < 64; i++) {
      final int bigS1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final int ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final int temp1 = (h + bigS1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
      final int bigS0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int temp2 = (bigS0 + maj) & 0xFFFFFFFF;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
    h5 = (h5 + f) & 0xFFFFFFFF;
    h6 = (h6 + g) & 0xFFFFFFFF;
    h7 = (h7 + h) & 0xFFFFFFFF;
  }

  final Uint8List out = Uint8List(32);
  final List<int> hs = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
  for (int i = 0; i < 8; i++) {
    for (int j = 3; j >= 0; j--) {
      out[i * 4 + (3 - j)] = (hs[i] >> (8 * j)) & 0xFF;
    }
  }
  return out;
}

/// Base64-encoded SHA-256 digest of [message].
String sha256Base64(List<int> message) => base64Encode(sha256(message));

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
