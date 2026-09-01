import 'dart:typed_data';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

/// Abstract contract for identity-verification data operations (EP-02-10).
///
/// Depends only on domain entities and the [DocumentType] vocabulary — never on
/// concrete backend types — so business systems and UI consume this interface,
/// not a Supabase implementation (ARCHITECTURE.md / EP-01-08 §5.6).
abstract class VerificationRepository {
  /// Submits an identity document for verification.
  ///
  /// Orchestrates validate → private-bucket upload → `entity_credentials`
  /// insert → `verification_submit` queue. [bytes] is a platform-agnostic
  /// payload (from `XFile.readAsBytes()`), and [onProgress] reports
  /// bytes sent / total during upload.
  ///
  /// Throws [StorageValidationException] (`PLT003`) for invalid MIME/size
  /// before any network call, and [ApiException] with `kind == conflict`
  /// (`PLT005`) when an active submission already exists.
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  });

  /// Fetches the full verification aggregate (KYC + identity flag + trades +
  /// submission counts) for the current entity.
  Future<VerificationStatus> getStatus();

  /// Fetches the assigned KYC level for the current entity.
  Future<KycLevel> getKycLevel();

  /// Fetches the KYC tier limits for the current entity.
  Future<KycLevel> getLimits();
}
