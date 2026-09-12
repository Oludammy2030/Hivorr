import 'dart:typed_data';

/// A user-selected profile avatar (bytes + name + MIME), mirroring the
/// [StorageService] upload payload (`Uint8List` via `XFile.readAsBytes()`).
class PickedAvatar {
  const PickedAvatar({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Image contents (validated against `profile-avatars` before upload).
  final Uint8List bytes;

  /// Original file name (canonical path derives `avatar.{ext}` after upload).
  final String fileName;

  /// Declared MIME type (e.g. `image/jpeg`, `image/png`, `image/webp`).
  final String mimeType;
}