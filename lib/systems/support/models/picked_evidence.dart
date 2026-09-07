import 'dart:typed_data';

/// A file selected by the user as dispute evidence (EP-02-17).
///
/// Platform-agnostic carrier matching the [StorageService] upload payload
/// (`Uint8List` via `XFile.readAsBytes()`), so the same value works on mobile
/// and Web. Mirrors `PickedDocument` in the verification system but lives in
/// the support system so filing screens never depend on a sibling system's
/// internals.
class PickedEvidence {
  const PickedEvidence({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// File contents.
  final Uint8List bytes;

  /// Original file name (sanitized before upload).
  final String fileName;

  /// Declared MIME type (e.g. `image/jpeg`, `application/pdf`).
  final String mimeType;
}