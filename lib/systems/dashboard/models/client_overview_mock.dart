/// MOCK money-rail data for the client overview (reference placeholders).
///
/// The `Spending Overview` and `Recent Payments` rail cards render from
/// [ClientSpendingMock.reference] / [ClientPaymentMock.reference] until the
/// backend seams land. The widgets consume these models (percentages and
/// totals are computed, not hardcoded), so connecting live data means
/// swapping the instance passed to `_SpendingOverviewCard` /
/// `_RecentPaymentsCard` — no widget changes required.
///
/// TODO(client-dashboard-backend): replace with live data when available.
/// Needed seams (none exist today):
///   * Monthly spending budget: total budget + month-to-date spend per
///     client entity (drives `spent` / `budget`).
///   * Client escrow holds: sum of held escrow amounts where the client is
///     the payer (drives `escrowHeld`).
///   * Client payment history: recent releases/holds with counterparty
///     display names, timestamps and signed amounts (drives the payments
///     list). Counterparty names are currently not exposed to the dashboard
///     at all — the app shows applications by quote/cover note instead.
library;

/// Spending summary behind the `Spending Overview` rail card.
class ClientSpendingMock {
  const ClientSpendingMock({
    required this.spent,
    required this.budget,
    required this.escrowHeld,
    required this.symbol,
  });

  /// Month-to-date spend in major units.
  final double spent;

  /// Monthly budget in major units.
  final double budget;

  /// Amount currently held in escrow in major units.
  final double escrowHeld;

  /// Currency symbol prefix (`$`, `₦`, …).
  final String symbol;

  /// Fraction of the monthly budget used, clamped to 0–1.
  double get usedShare {
    if (budget <= 0) {
      return 0;
    }
    return (spent / budget).clamp(0.0, 1.0);
  }

  /// Whole-percent of the monthly budget used.
  int get usedPercent => (usedShare * 100).round();

  /// Reference-matched placeholder values.
  static const ClientSpendingMock reference = ClientSpendingMock(
    spent: 12400,
    budget: 20000,
    escrowHeld: 1200,
    symbol: r'$',
  );
}

/// One row behind the `Recent Payments` rail card.
class ClientPaymentMock {
  const ClientPaymentMock({
    required this.title,
    required this.date,
    required this.amount,
    required this.kind,
    this.symbol = r'$',
  });

  /// Row title (`Payment to Amara Diallo`, `Escrow: Office Renovation`).
  final String title;

  /// Display date (`Today, 09:14`, `Jun 28`).
  final String date;

  /// Signed amount in major units (outflows negative).
  final double amount;

  /// Row kind (drives icon + amount tone).
  final ClientPaymentKind kind;

  /// Currency symbol prefix.
  final String symbol;

  /// Reference-matched placeholder rows.
  static const List<ClientPaymentMock> reference = <ClientPaymentMock>[
    ClientPaymentMock(
      title: 'Payment to Amara Diallo',
      date: 'Today, 09:14',
      amount: -3500,
      kind: ClientPaymentKind.payment,
    ),
    ClientPaymentMock(
      title: 'Escrow: Office Renovation',
      date: 'Jun 28',
      amount: 1200,
      kind: ClientPaymentKind.escrow,
    ),
    ClientPaymentMock(
      title: 'Payment to Kwame Asante',
      date: 'Jun 25',
      amount: -800,
      kind: ClientPaymentKind.payment,
    ),
  ];
}

/// Visual kind of a [ClientPaymentMock] row.
enum ClientPaymentKind {
  /// Outgoing payment (red, arrow-up tile).
  payment,

  /// Escrow hold (orange, lock tile).
  escrow,
}
