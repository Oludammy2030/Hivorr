// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';

/// In-memory [EarningsRepository] for provider/widget tests (EP-03-16).
///
/// Surfaces scripted summaries and history pages with call counters; set
/// [nextError] to exercise failure paths exactly as the real repository
/// throws [ApiException]. Display-only: figures pass through verbatim, never
/// recomputed.
class FakeEarningsRepository implements EarningsRepository {
  FakeEarningsRepository({
    Map<String, EarningsSummary> summaries = const <String, EarningsSummary>{},
    EarningsTransactionPage? page,
  }) : _summaries = Map<String, EarningsSummary>.from(summaries),
       _page = page;

  final Map<String, EarningsSummary> _summaries;
  EarningsTransactionPage? _page;

  ApiException? nextError;
  int summaryCallCount = 0;
  int historyCallCount = 0;
  int invalidateCallCount = 0;
  String? lastCurrency;
  String? lastType;

  /// Mutates the summary the fake serves for [currencyCode].
  void setSummary(String currencyCode, EarningsSummary summary) =>
      _summaries[currencyCode] = summary;

  /// Mutates the history page the fake serves.
  void setPage(EarningsTransactionPage? page) => _page = page;

  @override
  Future<EarningsSummary> getSummary(String currencyCode) async {
    summaryCallCount++;
    lastCurrency = currencyCode;
    if (nextError != null) throw nextError!;
    final EarningsSummary? summary = _summaries[currencyCode];
    if (summary == null) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Unsupported currency.',
        code: 'PLT003',
      );
    }
    return summary;
  }

  @override
  Future<EarningsSummary?> getCachedSummary(String currencyCode) async =>
      _summaries[currencyCode];

  @override
  Future<EarningsTransactionPage> listTransactions({
    required String currencyCode,
    String type = EarningsHistoryFilter.all,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  }) async {
    historyCallCount++;
    lastCurrency = currencyCode;
    lastType = type;
    if (nextError != null) throw nextError!;
    return _page ??
        const EarningsTransactionPage(items: <EarningsTransaction>[], hasMore: false);
  }

  @override
  Future<EarningsTransactionPage?> getCachedPage(String cacheKey) async =>
      _page;

  @override
  String historyCacheKey({
    required String currencyCode,
    required String type,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    required int limit,
    Map<String, dynamic>? cursor,
  }) => '$currencyCode|$type|$limit';

  @override
  Future<void> invalidateCache() async {
    invalidateCallCount++;
  }
}

/// Fixture builders shared across the earnings tests (EP-03-16).
EarningsSummary seedEarningsSummary({
  String currencyCode = 'NGN',
  double available = 50000,
  double held = 20000,
  double pending = 0,
  double lifetimeEarned = 120000,
  int releaseCount = 3,
  int completedContracts = 2,
  double totalWithdrawn = 40000,
  int frozenCount = 0,
  List<EarningsMonthBucket>? monthly,
}) => EarningsSummary(
  currencyCode: currencyCode,
  availableBalance: available,
  heldBalance: held,
  pendingBalance: pending,
  lifetimeEarned: lifetimeEarned,
  releaseCount: releaseCount,
  completedContracts: completedContracts,
  totalWithdrawn: totalWithdrawn,
  frozenCount: frozenCount,
  monthly:
      monthly ??
      <EarningsMonthBucket>[
        EarningsMonthBucket(
          month: DateTime.utc(2026, 5),
          earned: 20000,
          releaseCount: 1,
        ),
        EarningsMonthBucket(
          month: DateTime.utc(2026, 6),
          earned: 30000,
          releaseCount: 1,
        ),
        EarningsMonthBucket(
          month: DateTime.utc(2026, 7),
          earned: 0,
          releaseCount: 0,
        ),
        EarningsMonthBucket(
          month: DateTime.utc(2026, 8),
          earned: 40000,
          releaseCount: 1,
        ),
        EarningsMonthBucket(
          month: DateTime.utc(2026, 9),
          earned: 0,
          releaseCount: 0,
        ),
        EarningsMonthBucket(
          month: DateTime.utc(2026, 10),
          earned: 30000,
          releaseCount: 0,
        ),
      ],
);

EarningsTransaction seedEarningsTransaction({
  String id = 'tx-1',
  String type = 'escrow_release',
  String currencyCode = 'NGN',
  double amount = 10000,
  String direction = 'in',
  String? contractId = 'contract-1',
  String? contractStatus = 'active',
  String? escrowStatus = 'funded',
}) => EarningsTransaction(
  id: id,
  type: type,
  currencyCode: currencyCode,
  amount: amount,
  direction: direction,
  sourceEntityId: 'entity-client',
  destinationEntityId: 'entity-pro',
  referenceType: 'escrow',
  referenceId: 'escrow-1',
  description: 'Milestone released',
  createdAt: DateTime.utc(2026, 10, 1, 12),
  contractId: contractId,
  contractStatus: contractStatus,
  escrowStatus: escrowStatus,
);

EarningsTransactionPage seedEarningsPage({
  List<EarningsTransaction>? items,
  bool hasMore = false,
  Map<String, dynamic>? nextCursor,
}) => EarningsTransactionPage(
  items:
      items ??
      <EarningsTransaction>[
        seedEarningsTransaction(),
        seedEarningsTransaction(
          id: 'tx-2',
          type: 'withdrawal',
          amount: 2000,
          direction: 'out',
          contractId: null,
          contractStatus: null,
          escrowStatus: null,
        ),
      ],
  hasMore: hasMore,
  nextCursor: nextCursor,
);
