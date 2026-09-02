import 'package:hivorr/data/entities/trade_verification_status.dart';

/// Pure-function marketplace bid-lock gate (EP-02-11 §5.4, `AGENT.md:15`
/// Rule 2).
///
/// Trade verification is the second trust checkpoint (`EP-02:357-366`): an
/// entity may bid on a profession only once its `trade_verification_status` is
/// `approved`. [canBid] mirrors that server rule for client UI (bid-lock panel)
/// with **no I/O, no globals** — trivially unit-testable. Server-side
/// enforcement belongs to marketplace `EP-03`.
abstract final class TradeVerificationGate {
  /// Returns `true` iff [professionId]'s trade verification is [approved]
  /// within [status].
  ///
  /// An absent/unknown profession resolves to `unverified` → `false` (locked),
  /// consistent with the fail-closed bid-lock posture and `AGENT.md:15`
  /// Rule 2.
  static bool canBid(TradeVerificationStatus status, String professionId) =>
      status.kindFor(professionId).canBid;
}
