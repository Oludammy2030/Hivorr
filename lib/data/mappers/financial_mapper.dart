import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

/// Transformations between the financial transport DTOs and the pure-Dart
/// domain entities (EP-02-13 §5.2).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
abstract final class FinancialMapper {
  /// Maps a profile DTO into a domain [FinancialProfile].
  static FinancialProfile profileToEntity(FinancialProfileDto dto) =>
      FinancialProfile(
        id: dto.id,
        entityId: dto.entityId,
        status: dto.status,
        defaultCurrency: dto.defaultCurrency,
        createdAt: dto.createdAt,
      );

  /// Maps a currency-account DTO into a domain [CurrencyAccount].
  static CurrencyAccount accountToEntity(CurrencyAccountDto dto) =>
      CurrencyAccount(
        id: dto.id,
        financialProfileId: dto.financialProfileId,
        entityId: dto.entityId,
        currencyCode: dto.currencyCode,
        accountStatus: dto.accountStatus,
        receivingAccountNumber: dto.receivingAccountNumber,
        receivingBankName: dto.receivingBankName,
        providerReference: dto.providerReference,
        activatedAt: dto.activatedAt,
      );

  /// Maps a balance DTO into a domain [Balance].
  static Balance balanceToEntity(BalanceDto dto) => Balance(
        currencyCode: dto.currencyCode,
        availableBalance: dto.availableBalance,
        heldBalance: dto.heldBalance,
        pendingBalance: dto.pendingBalance,
        totalDeposited: dto.totalDeposited,
        totalWithdrawn: dto.totalWithdrawn,
        lastTransactionAt: dto.lastTransactionAt,
      );

  /// Maps the full status aggregate DTO into a domain [FinancialStatus].
  static FinancialStatus statusToEntity(FinancialStatusDto dto) =>
      FinancialStatus(
        defaultCurrency: dto.defaultCurrency,
        profileStatus: dto.profileStatus,
        balances: dto.balances
            .map(balanceToEntity)
            .toList(growable: false),
        activeEscrowCount: dto.activeEscrowCount,
        cashoutLimit: dto.cashoutLimit,
      );
}
