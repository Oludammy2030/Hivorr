import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/financial_remote_data_source.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

/// Supabase-backed implementation of [FinancialRemoteDataSource].
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). Every read/write goes through the financial
/// RPCs (`financial_profile_get` / `financial_balance_get` /
/// `financial_status_get` / `financial_profile_create`) — never direct table
/// writes. Status mutation is server-authoritative (AGENT.md Rule 4).
class SupabaseFinancialRemoteDataSource extends BaseApiService
    implements FinancialRemoteDataSource {
  SupabaseFinancialRemoteDataSource({
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
  Future<FinancialProfileDto?> getProfile() => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_profile_get',
        );
        final Map<String, dynamic> envelope =
            FinancialEnvelopeParser.unwrap(response);
        // Profile may not exist — the RPC returns an empty data object
        // with a null profile key.
        final Map<String, dynamic>? profile =
            envelope['profile'] as Map<String, dynamic>?;
        if (profile == null || profile.isEmpty) return null;
        return FinancialProfileDto.fromJson(profile);
      });

  @override
  Future<BalanceDto> getBalance(String currencyCode) => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_balance_get',
          params: <String, dynamic>{'p_currency_code': currencyCode},
        );
        final Map<String, dynamic> data =
            FinancialEnvelopeParser.unwrap(response);
        return BalanceDto.fromJson(data);
      });

  @override
  Future<FinancialStatusDto> getStatus() => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_status_get',
        );
        final Map<String, dynamic> data =
            FinancialEnvelopeParser.unwrap(response);
        return FinancialStatusDto.fromJson(data);
      });

  @override
  Future<FinancialProfileDto> createProfile({
    String defaultCurrency = 'NGN',
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_profile_create',
          params: <String, dynamic>{
            'p_default_currency': defaultCurrency,
          },
        );
        FinancialEnvelopeParser.unwrap(response);
        // Re-read the profile to confirm creation (server-authoritative).
        final FinancialProfileDto? profile = await getProfile();
        if (profile == null) {
          throw const ApiException(
            kind: ApiExceptionKind.server,
            message:
                'Profile creation succeeded but profile could not be read.',
            code: 'PLT999',
          );
        }
        return profile;
      });
}
