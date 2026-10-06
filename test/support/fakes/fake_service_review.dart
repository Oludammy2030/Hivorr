import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_review_remote_data_source.dart';
import 'package:hivorr/data/models/service_review_dto.dart';

/// Builds a `service_reviews` row map for fakes.
Map<String, dynamic> reviewRow({
  required String id,
  required String contractId,
  String listingId = 'listing-1',
  required String reviewerId,
  required String revieweeId,
  String professionId = 'profession-1',
  required int rating,
  String? comment,
  bool revealed = false,
}) => <String, dynamic>{
  'id': id,
  'contract_id': contractId,
  'service_listing_id': listingId,
  'reviewer_entity_id': reviewerId,
  'reviewee_entity_id': revieweeId,
  'profession_id': professionId,
  'rating': rating,
  'comment': comment,
  'is_revealed': revealed,
  'revealed_at': revealed ? '2026-09-26T12:00:00.000Z' : null,
  'created_at': '2026-09-26T10:00:00.000Z',
  'updated_at': '2026-09-26T10:00:00.000Z',
};

/// In-memory fake for [ServiceReviewRemoteDataSource] (EP-03-12 tests).
///
/// Mirrors the server blind rule: rows start `is_revealed=false`; when two
/// rows exist for the same contract both flip to `is_revealed=true`.
/// `getMyStatus` returns `you_have_submitted` for [viewerId] + only revealed
/// rows (no oracle). `getForListing` returns only revealed rows with keyset
/// pagination over insertion order.
class FakeServiceReviewRemoteDataSource
    implements ServiceReviewRemoteDataSource {
  FakeServiceReviewRemoteDataSource({
    List<Map<String, dynamic>>? seed,
    this.viewerId = 'client-1',
  }) : _rows = <Map<String, dynamic>>[...?seed];

  final List<Map<String, dynamic>> _rows;

  /// The `auth.uid()` the fake acts as.
  String viewerId;

  int submitCalls = 0;
  int getMineCalls = 0;
  int getForListingCalls = 0;

  List<Map<String, dynamic>> get rows => List.unmodifiable(_rows);

  void _maybeReveal(String contractId) {
    final List<Map<String, dynamic>> forContract = _rows
        .where((Map<String, dynamic> r) => r['contract_id'] == contractId)
        .toList(growable: false);
    if (forContract.length >= 2) {
      for (final Map<String, dynamic> r in forContract) {
        r['is_revealed'] = true;
        r['revealed_at'] ??= '2026-09-26T12:00:00.000Z';
      }
    }
  }

  @override
  Future<ReviewSubmitEnvelopeDto> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  }) async {
    submitCalls++;
    if (contractId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'contractId is required.',
        code: 'PLT003',
      );
    }
    if (rating < 1 || rating > 5) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Rating must be between 1 and 5.',
        code: 'PLT003',
      );
    }
    if (comment != null &&
        comment.trim().isNotEmpty &&
        (comment.trim().length < 10 || comment.trim().length > 2000)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Comment must be between 10 and 2000 characters.',
        code: 'PLT003',
      );
    }
    if (contractId == 'missing' || contractId == 'foreign') {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Review context not found.',
        code: 'PLT004',
      );
    }
    if (contractId == 'offered') {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Contract not in reviewable state.',
        code: 'PLT005',
      );
    }
    final bool already = _rows.any(
      (Map<String, dynamic> r) =>
          r['contract_id'] == contractId &&
          r['reviewer_entity_id'] == viewerId,
    );
    if (already) {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'You have already submitted a review for this contract.',
        code: 'PLT005',
      );
    }
    final Map<String, dynamic> row = reviewRow(
      id: 'review-${_rows.length + 1}',
      contractId: contractId,
      reviewerId: viewerId,
      revieweeId: viewerId == 'client-1' ? 'pro-1' : 'client-1',
      rating: rating,
      comment: comment?.trim().isEmpty ?? true ? null : comment!.trim(),
    );
    _rows.add(row);
    _maybeReveal(contractId);
    final Map<String, dynamic> stored = _rows.firstWhere(
      (Map<String, dynamic> r) =>
          r['contract_id'] == contractId &&
          r['reviewer_entity_id'] == viewerId,
    );
    return ReviewSubmitEnvelopeDto.fromJson(
      <String, dynamic>{'review': stored},
    );
  }

  @override
  Future<MyReviewStatusEnvelopeDto> getMyStatus(String contractId) async {
    getMineCalls++;
    if (contractId == 'missing' || contractId == 'foreign') {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Review context not found.',
        code: 'PLT004',
      );
    }
    _maybeReveal(contractId);
    Map<String, dynamic>? mine;
    for (final Map<String, dynamic> r in _rows) {
      if (r['contract_id'] == contractId &&
          r['reviewer_entity_id'] == viewerId) {
        mine = r;
      }
    }
    final List<Map<String, dynamic>> revealed = _rows
        .where(
          (Map<String, dynamic> r) =>
              r['contract_id'] == contractId && r['is_revealed'] == true,
        )
        .toList(growable: false);
    return MyReviewStatusEnvelopeDto.fromJson(<String, dynamic>{
      'you_have_submitted': mine != null,
      'your_review': mine,
      'revealed_reviews': revealed,
      'review_count': revealed.length,
    });
  }

  @override
  Future<ListingReviewsEnvelopeDto> getForListing({
    required String listingId,
    int limit = 20,
    String? cursor,
  }) async {
    getForListingCalls++;
    if (listingId == 'missing' || listingId == 'draft') {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Review context not found.',
        code: 'PLT004',
      );
    }
    if (limit < 1 || limit > 100) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Limit must be between 1 and 100.',
        code: 'PLT003',
      );
    }
    final List<Map<String, dynamic>> revealed = _rows
        .where(
          (Map<String, dynamic> r) =>
              r['service_listing_id'] == listingId &&
              r['is_revealed'] == true,
        )
        .toList(growable: false);
    int start = 0;
    if (cursor != null) {
      final int index = revealed.indexWhere(
        (Map<String, dynamic> r) => r['id'] == cursor,
      );
      // Unknown cursor yields an empty page (no oracle).
      if (index < 0) {
        return ListingReviewsEnvelopeDto.fromJson(<String, dynamic>{
          'reviews': <Map<String, dynamic>>[],
          'avg_rating': 0,
          'review_count': 0,
          'distribution': <String, int>{
            '1': 0,
            '2': 0,
            '3': 0,
            '4': 0,
            '5': 0,
          },
          'has_more': false,
          'next_cursor': null,
        });
      }
      start = index + 1;
    }
    final List<Map<String, dynamic>> window = revealed
        .skip(start)
        .take(limit + 1)
        .toList(growable: false);
    final bool hasMore = window.length > limit;
    final List<Map<String, dynamic>> items = hasMore
        ? window.sublist(0, limit)
        : window;
    final int total = revealed.length;
    final double avg = total == 0
        ? 0
        : revealed.fold<double>(
                0,
                (double acc, Map<String, dynamic> r) =>
                    acc + (r['rating'] as num).toDouble(),
              ) /
              total;
    final Map<String, int> dist = <String, int>{
      '1': 0,
      '2': 0,
      '3': 0,
      '4': 0,
      '5': 0,
    };
    for (final Map<String, dynamic> r in revealed) {
      final String key = (r['rating'] as num).toInt().toString();
      dist[key] = (dist[key] ?? 0) + 1;
    }
    return ListingReviewsEnvelopeDto.fromJson(<String, dynamic>{
      'reviews': items,
      'avg_rating': avg,
      'review_count': total,
      'distribution': dist,
      'has_more': hasMore,
      'next_cursor': hasMore ? items.last['id'] : null,
    });
  }
}
