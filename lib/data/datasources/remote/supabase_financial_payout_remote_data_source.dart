import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/financial_payout_remote_data_source.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';

/// Supabase-backed implementation of [FinancialPayoutRemoteDataSource]
/// (EP-02-16).
///
/// Both writes go through the authenticated, self-scoped financial RPCs with
/// the standard `{success, code, message, data}` envelope, unwrapped by
/// [FinancialEnvelopeParser]. The client never touches the
/// `financial_payout_accounts` table directly.
class SupabaseFinancialPayoutRemoteDataSource extends BaseApiService
    implements FinancialPayoutRemoteDataSource {
  SupabaseFinancialPayoutRemoteDataSource({
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
  Future<PayoutBindDto> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_payout_account_bind',
          params: <String, dynamic>{
            'p_currency_code': currencyCode,
            'p_bank_name': bankName,
            'p_account_number': accountNumber,
            'p_account_name': accountName,
          },
        );
        final Map<String, dynamic> data =
            FinancialEnvelopeParser.unwrap(response);
        return PayoutBindDto.fromJson(data);
      });

  @override
  Future<WithdrawalDto> withdraw({
    required String payoutAccountId,
    required double amount,
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_withdraw',
          params: <String, dynamic>{
            'p_payout_account_id': payoutAccountId,
            'p_amount': amount,
          },
        );
        final Map<String, dynamic> data =
            FinancialEnvelopeParser.unwrap(response);
        return WithdrawalDto.fromJson(data);
      });
}