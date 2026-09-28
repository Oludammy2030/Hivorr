import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/service_listing_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/models/listing_media_dto.dart';

/// Supabase-backed implementation of [ServiceListingRemoteDataSource]
/// (EP-03-08 §11).
///
/// Wraps the six owner listing RPCs plus the `service_favorite_toggle`
/// read-through via `supabase.rpc(...)` and unwraps the standard
/// `{success, code, message, data}` envelope with
/// [ServiceListingEnvelopeParser]. Mirrors
/// `SupabaseDisputeRemoteDataSource` (`_guard(mapDataException)` + `p_*`
/// params). This class never writes `service_listings` tables directly and
/// never references service-role-only transitions (`reported`).
class SupabaseServiceListingRemoteDataSource extends BaseApiService
    implements ServiceListingRemoteDataSource {
  SupabaseServiceListingRemoteDataSource({
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
  Future<Map<String, dynamic>> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  }) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
          'service_listing_create',
          params: <String, dynamic>{
            'p_profession_id': professionId,
            'p_title': title,
            'p_description': description,
            'p_pricing_type': pricingType,
            'p_price_min': ?priceMin,
            'p_price_max': ?priceMax,
            'p_currency_code': currencyCode,
            'p_status': status,
          },
        );
        return ServiceListingEnvelopeParser.unwrap(response);
      });

  @override
  Future<Map<String, dynamic>> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  }) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
          'service_listing_update',
          params: <String, dynamic>{
            'p_listing_id': listingId,
            'p_title': ?title,
            'p_description': ?description,
            'p_profession_id': ?professionId,
            'p_pricing_type': ?pricingType,
            'p_price_min': ?priceMin,
            'p_price_max': ?priceMax,
            'p_currency_code': ?currencyCode,
          },
        );
        return ServiceListingEnvelopeParser.unwrap(response);
      });

  @override
  Future<Map<String, dynamic>> publishListing(String listingId) => _guard(
        () async {
          final Map<String, dynamic> response = await supabase
              .rpc<Map<String, dynamic>>(
            'service_listing_publish',
            params: <String, dynamic>{'p_listing_id': listingId},
          );
          return ServiceListingEnvelopeParser.unwrap(response);
        },
      );

  @override
  Future<Map<String, dynamic>> unpublishListing(String listingId) => _guard(
        () async {
          final Map<String, dynamic> response = await supabase
              .rpc<Map<String, dynamic>>(
            'service_listing_unpublish',
            params: <String, dynamic>{'p_listing_id': listingId},
          );
          return ServiceListingEnvelopeParser.unwrap(response);
        },
      );

  @override
  Future<Map<String, dynamic>> getListing(String listingId) => _guard(
        () async {
          final Map<String, dynamic> response = await supabase
              .rpc<Map<String, dynamic>>(
            'service_listing_get',
            params: <String, dynamic>{'p_listing_id': listingId},
          );
          return ServiceListingEnvelopeParser.unwrap(response);
        },
      );

  @override
  Future<MyListingPageDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
          'service_listing_list_mine',
          params: <String, dynamic>{
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
        final Map<String, dynamic> data =
            ServiceListingEnvelopeParser.unwrap(response);
        return MyListingPageDto.fromJson(data);
      });

  @override
  Future<Map<String, dynamic>> toggleFavorite(String listingId) => _guard(
        () async {
          final Map<String, dynamic> response = await supabase
              .rpc<Map<String, dynamic>>(
            'service_favorite_toggle',
            params: <String, dynamic>{'p_listing_id': listingId},
          );
          return ServiceListingEnvelopeParser.unwrap(response);
        },
      );
}
