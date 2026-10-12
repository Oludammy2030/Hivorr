import 'dart:typed_data';

import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/verification_submission.dart';

/// Abstract contract for business identity (identity audit Phase 2a).
///
/// Covers the business lifecycle a representative drives: create → join →
/// submit CAC evidence → queue for review → list. Verification decisions stay
/// server-side (admin review RPCs); this seam never flips status and never
/// touches personal KYC or trade bindings.
abstract class BusinessRepository {
  /// Lists the caller's businesses with membership attached.
  Future<List<Business>> myBusinesses({required String entityId});

  /// Creates a `pending` business row (no membership yet).
  Future<Business> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  });

  /// Joins [businessId] as the caller's representative membership.
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  });

  /// Deletes the caller's membership row (leave).
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  });

  /// Uploads CAC evidence and queues a `business_verification` submission.
  ///
  /// Validates names/CAC/file before any network call (fail-fast `PLT003`).
  /// Returns the queued submission.
  Future<VerificationSubmission> submitDocument({
    required String businessId,
    required String title,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  });
}
