import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
import 'package:hivorr/systems/verification/models/picked_document.dart';

/// Real platform file picker (EP-02-18 / EP-02-10 / EP-02-17 wiring).
///
/// Wraps the `file_picker` package so feature screens never import the plugin
/// directly. Web is served through the in-memory byte carrier
/// ([PlatformFile.readAsBytes]); mobile uses the same read. All results cross
/// the boundary as the platform-agnostic [PickedDocument] / [PickedAvatar]
/// carriers (AGENT.md separation of concerns).
///
/// Every method is cancel-safe: a dismissed dialog returns `null`.
class PlatformFilePicker {
  /// Allowed extensions for credential documents, mirrored from the
  /// `credential-documents` bucket rules (JPG/PNG/WebP/PDF).
  static const List<String> documentExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  ];

  /// Allowed extensions for profile avatars (`profile-avatars` bucket rules).
  static const List<String> avatarExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// Picks an identity/trade document and returns its bytes + name + MIME.
  ///
  /// Returns `null` when the user cancels the platform dialog.
  Future<PickedDocument?> pickDocument() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
    );
    final Uint8List? bytes = await _readBytes(file);
    if (bytes == null) {
      return null;
    }
    return PickedDocument(
      bytes: bytes,
      fileName: file!.name,
      mimeType: _mimeFor(file.extension),
    );
  }

  /// Picks a profile avatar and returns its bytes + name + MIME.
  ///
  /// Returns `null` when the user cancels the platform dialog.
  Future<PickedAvatar?> pickAvatar() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: avatarExtensions,
    );
    final Uint8List? bytes = await _readBytes(file);
    if (bytes == null) {
      return null;
    }
    return PickedAvatar(
      bytes: bytes,
      fileName: file!.name,
      mimeType: _mimeFor(file.extension),
    );
  }

  /// Reads the file bytes, tolerating platform read failures (returns `null`
  /// so the caller treats it as a cancelled/metrics-neutral pick).
  ///
  /// `readAsBytes` is the single cross-platform read surface for the current
  /// `file_picker` static API (the abstract [PlatformFile] carries no inline
  /// bytes); on web it serves the picked file's in-memory content directly.
  static Future<Uint8List?> _readBytes(PlatformFile? file) async {
    if (file == null) {
      return null;
    }
    try {
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  /// Maps a file extension to its MIME type for the storage upload payload.
  static String _mimeFor(String? extension) => switch (extension?.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'image/jpeg',
      };
}