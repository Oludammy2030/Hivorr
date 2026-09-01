import 'dart:typed_data';

/// A file selected by the user for identity verification (EP-02-10).
///
/// Platform-agnostic carrier matching the [StorageService] upload payload
/// (`Uint8List` via `XFile.readAsBytes()`), so the same value works on
/// mobile and Web.
class PickedDocument {
  const PickedDocument({
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
