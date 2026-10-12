// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/business_repository.dart';

/// Thin facade over [BusinessRepository] for business identity
/// (identity audit Phase 2a).
///
/// Owns the client-side validation mirrors (server CHECKs stay authoritative
/// per `AGENT.md` Rule 4) and delegates reads/writes. Verification decisions
/// never pass through here.
class BusinessService {
  BusinessService({required BusinessRepository repository, HivorrLogger? logger})
    : _repository = repository,
      _logger = logger;

  final BusinessRepository _repository;
  final HivorrLogger? _logger;

  /// Maximum lengths mirroring the server CHECKs.
  static const int maxTradingNameLength = 120;
  static const int maxLegalNameLength = 255;
  static const int maxCacLength = 64;
  static const int maxTitleLength = 255;

  /// Mirrors `businesses_trading_name_length` ( UX only).
  static bool validateTradingName(String value) {
    final String v = value.trim();
    return v.isNotEmpty && v.length <= maxTradingNameLength;
  }

  /// Mirrors `businesses_legal_name_length` (UX only).
  static bool validateLegalName(String value) {
    final String v = value.trim();
    return v.isNotEmpty && v.length <= maxLegalNameLength;
  }

  /// Mirrors `businesses_cac_length` (UX only; null = not supplied).
  static bool validateCacNumber(String? value) {
    if (value == null) return true;
    final String v = value.trim();
    return v.isNotEmpty && v.length <= maxCacLength;
  }

  /// Mirrors the credential title length (UX only).
  static bool validateDocumentTitle(String value) {
    final String v = value.trim();
    return v.isNotEmpty && v.length <= maxTitleLength;
  }

  /// Lists the caller's businesses with membership attached.
  Future<List<Business>> listMine({required String entityId}) {
    _logger?.info('Business list requested', <String, Object?>{
      'entityIdSuffix': entityId.length > 8
          ? entityId.substring(entityId.length - 8)
          : entityId,
    });
    return _repository.myBusinesses(entityId: entityId);
  }

  /// Creates a `pending` business row (membership joined separately).
  Future<Business> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) => _repository.createBusiness(
    tradingName: tradingName,
    registeredLegalName: registeredLegalName,
    cacNumber: cacNumber,
  );

  /// Joins [businessId] as the caller's representative membership.
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  }) => _repository.joinBusiness(businessId: businessId, entityId: entityId);

  /// Deletes the caller's membership row (leave).
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  }) => _repository.leaveBusiness(businessId: businessId, entityId: entityId);

  /// Uploads CAC evidence and queues a `business_verification` submission.
  Future<VerificationSubmission> submitDocument({
    required String businessId,
    required String title,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) => _repository.submitDocument(
    businessId: businessId,
    title: title,
    bytes: bytes,
    mimeType: mimeType,
    fileName: fileName,
    onProgress: onProgress,
  );
}
