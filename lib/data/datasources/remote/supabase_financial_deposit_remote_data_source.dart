import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/models/deposit_dto.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [FinancialDepositRemoteDataSource]
/// (EP-02-16).
///
/// Reads `financial_deposits` rows through the REST transport seam (granted
/// to `authenticated` at migration line 555, RLS-scoped to `auth.uid()`).
/// Read-only: writing/verifying deposits is service-role only and deliberately
/// never invoked from the client.
class SupabaseFinancialDepositRemoteDataSource extends BaseApiService
    implements FinancialDepositRemoteDataSource {
  SupabaseFinancialDepositRemoteDataSource({
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
  Future<List<DepositDto>> listDeposits() => _guard(() async {
        final String? entityId = supabase.auth.currentUser?.id;
        final PostgrestFilterBuilder<PostgrestList> filtered =
            supabase.from('financial_deposits').select();
        final PostgrestTransformBuilder<PostgrestList> query =
            (entityId == null || entityId.isEmpty)
                ? filtered.order('created_at', ascending: false)
                : filtered
                    .eq('entity_id', entityId)
                    .order('created_at', ascending: false);
        final PostgrestList rows = await query;
        return rows.map(DepositDto.fromJson).toList(growable: false);
      });
}