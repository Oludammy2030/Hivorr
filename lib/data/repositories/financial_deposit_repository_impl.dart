// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/data/datasources/remote/financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/mappers/financial_deposit_mapper.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';

/// Default implementation of [FinancialDepositRepository].
///
/// Read-only, backed by the authenticated REST select on `financial_deposits`
/// (RLS-scoped). Never calls the service-role deposit RPCs.
class FinancialDepositRepositoryImpl implements FinancialDepositRepository {
  FinancialDepositRepositoryImpl({
    required FinancialDepositRemoteDataSource remote,
  }) : _remote = remote;

  final FinancialDepositRemoteDataSource _remote;

  @override
  Future<List<Deposit>> listDeposits() async {
    final rows = await _remote.listDeposits();
    return rows.map(FinancialDepositMapper.toEntity).toList(growable: false);
  }
}
