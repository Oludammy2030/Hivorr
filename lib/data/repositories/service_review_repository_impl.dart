// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_review_remote_data_source.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/mappers/review_mapper.dart';
import 'package:hivorr/data/models/service_review_dto.dart';
import 'package:hivorr/data/repositories/service_review_repository.dart';

/// Default implementation of [ServiceReviewRepository].
///
/// Implements the server-authoritative double-blind flow (EP-03-12 §7):
/// writes via `service_review_submit` with client-side fail-fast mirrors of
/// the frozen CHECK constraints (`rating 1-5`, `comment` null-or-`10-2000`
/// after trim), reads via `service_review_get_mine` /
/// `service_review_get_for_listing`. The server remains the single authority
/// for reveal, aggregation, and pagination; the repository mirrors the codes
/// for fail-fast UX only. Never writes review tables directly and never
/// calls `service_review_reveal_if_ready` (`AGENT.md` Rule 4).
class ServiceReviewRepositoryImpl implements ServiceReviewRepository {
  ServiceReviewRepositoryImpl({
    required ServiceReviewRemoteDataSource remote,
  }) : _remote = remote;

  final ServiceReviewRemoteDataSource _remote;

  /// Minimum star rating accepted by `service_reviews_rating_range`.
  static const int minRating = 1;

  /// Maximum star rating accepted by `service_reviews_rating_range`.
  static const int maxRating = 5;

  /// Minimum comment length when a comment is supplied.
  static const int minCommentLength = 10;

  /// Maximum comment length when a comment is supplied.
  static const int maxCommentLength = 2000;

  @override
  Future<ServiceReview> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    _requireRating(rating);
    _requireComment(comment);
    final ReviewSubmitEnvelopeDto envelope = await _remote.submitReview(
      contractId: contractId,
      rating: rating,
      comment: _normalizeComment(comment),
    );
    return ReviewMapper.submitEnvelopeToEntity(envelope);
  }

  @override
  Future<MyReviewStatus> getMyStatus(String contractId) async {
    _requireNonEmpty(contractId, 'contractId');
    final MyReviewStatusEnvelopeDto dto = await _remote.getMyStatus(
      contractId,
    );
    return ReviewMapper.myStatusEnvelopeToEntity(dto, contractId);
  }

  @override
  Future<ListingReviewsPage> getForListing({
    required String listingId,
    required String professionalEntityId,
    required String professionId,
    int limit = 20,
    String? cursor,
  }) async {
    _requireNonEmpty(listingId, 'listingId');
    _requireLimit(limit);
    final ListingReviewsEnvelopeDto dto = await _remote.getForListing(
      listingId: listingId,
      limit: limit,
      cursor: cursor,
    );
    return ReviewMapper.listingEnvelopeToPage(
      dto,
      professionalEntityId: professionalEntityId,
      professionId: professionId,
    );
  }

  void _requireRating(int rating) {
    if (rating < minRating || rating > maxRating) {
      _fail('Rating must be between 1 and 5.');
    }
  }

  void _requireComment(String? comment) {
    if (comment == null || comment.trim().isEmpty) return;
    final int length = comment.trim().length;
    if (length < minCommentLength || length > maxCommentLength) {
      _fail('Comment must be between 10 and 2000 characters.');
    }
  }

  String? _normalizeComment(String? comment) {
    if (comment == null) return null;
    final String trimmed = comment.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }
}
