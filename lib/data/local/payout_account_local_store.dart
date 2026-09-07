import 'package:hivorr/data/entities/payout_account.dart';

/// Local persistence seam for bound payout accounts (EP-02-16).
///
/// The authenticated role has **no** SELECT grant on `financial_payout_accounts`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql` §17);
/// the only client-side knowledge of bound accounts comes from each successful
/// `financial_payout_account_bind`. This store is the display mirror that
/// preserves that knowledge across provider rebuilds. The server remains the
/// single write authority.
abstract class PayoutAccountLocalStore {
  /// All locally known bound accounts.
  List<PayoutAccount> readAll();

  /// Replaces [account] (by id) in the store.
  Future<void> upsert(PayoutAccount account);

  /// Removes the account with [id] from the store.
  Future<void> remove(String id);
}

/// Default in-memory [PayoutAccountLocalStore].
class InMemoryPayoutAccountLocalStore implements PayoutAccountLocalStore {
  InMemoryPayoutAccountLocalStore({
    List<PayoutAccount> seed = const <PayoutAccount>[],
  }) : _accounts = List<PayoutAccount>.of(seed);

  final List<PayoutAccount> _accounts;

  @override
  List<PayoutAccount> readAll() => List<PayoutAccount>.unmodifiable(_accounts);

  @override
  Future<void> upsert(PayoutAccount account) async {
    final int index =
        _accounts.indexWhere((PayoutAccount a) => a.id == account.id);
    if (index >= 0) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }
  }

  @override
  Future<void> remove(String id) async {
    _accounts.removeWhere((PayoutAccount a) => a.id == id);
  }
}