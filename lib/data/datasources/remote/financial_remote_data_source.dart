import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

/// Abstract contract for the remote (Supabase) side of financial profiles (EP-02-13).
///
/// Implementations must access the backend only through the EP-01-07
/// [BaseApiService] channel and the financial RPCs — never directly writing
/// `financial_profiles`, `financial_currency_accounts`, or `financial_balances`
/// (server-authoritative, AGENT.md Rule 4). All reads go through the
/// `financial_*` RPCs.
abstract class FinancialRemoteDataSource {
  /// Fetches the financial profile and attached currency accounts.
  ///
  /// Backed by `financial_profile_get`. Returns `null` when the entity has
  /// no profile row yet.
  Future<FinancialProfileDto?> getProfile();

  /// Fetches a single-currency balance.
  ///
  /// Backed by `financial_balance_get(p_currency_code)`. Returns zero
  /// defaults when no row exists.
  Future<BalanceDto> getBalance(String currencyCode);

  /// Fetches the aggregated financial status.
  ///
  /// Backed by `financial_status_get`. Combines profile status, all balances,
  /// active escrow count, and cashout limit.
  Future<FinancialStatusDto> getStatus();

  /// Creates a financial profile with a default currency.
  ///
  /// Backed by `financial_profile_create(p_default_currency)`. Returns the
  /// created profile. Throws [ApiException] with `kind == conflict` (`PLT005`)
  /// when a profile already exists for this entity.
  Future<FinancialProfileDto> createProfile({String defaultCurrency = 'NGN'});
}
