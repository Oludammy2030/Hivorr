import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/service_review_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/service_review_remote_data_source.dart';
import 'package:hivorr/data/models/service_review_dto.dart';

/// Supabase-backed implementation of [ServiceReviewRemoteDataSource]
/// (EP-03-12 §7.1).
///
/// Wraps the three client-callable review RPCs via `supabase.rpc(...)` and
/// unwraps the standard `{success, code, message, data}` envelope with
/// [ServiceReviewEnvelopeParser]. Mirrors
/// `SupabaseServiceContractRemoteDataSource` (`_guard(mapDataException)` +
/// `p_*` params). This class never writes review tables directly, never
/// calls `service_review_reveal_if_ready`, and never references
/// service-role-only transitions.
class SupabaseServiceReviewRemoteDataSource extends BaseApiService
    implements ServiceReviewRemoteDataSource {
  SupabaseServiceReviewRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<ReviewSubmitEnvelopeDto> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_review_submit',
          params: <String, dynamic>{
            'p_contract_id': contractId,
            'p_rating': rating,
            'p_comment': comment,
          },
        );
    return ReviewSubmitEnvelopeDto.fromJson(
      ServiceReviewEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<MyReviewStatusEnvelopeDto> getMyStatus(String contractId) => _guard(
    () async {
      final Map<String, dynamic> response = await supabase
          .rpc<Map<String, dynamic>>(
            'service_review_get_mine',
            params: <String, dynamic>{'p_contract_id': contractId},
          );
      return MyReviewStatusEnvelopeDto.fromJson(
        ServiceReviewEnvelopeParser.unwrap(response),
      );
    },
  );

  @override
  Future<ListingReviewsEnvelopeDto> getForListing({
    required String listingId,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_review_get_for_listing',
          params: <String, dynamic>{
            'p_service_listing_id': listingId,
            'p_limit': limit,
            'p_cursor': cursor,
          },
        );
    return ListingReviewsEnvelopeDto.fromJson(
      ServiceReviewEnvelopeParser.unwrap(response),
    );
  });
}
