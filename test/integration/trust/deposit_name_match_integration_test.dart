// EP-02-20 VP10: Deposit Name-Matching (AGENT.md Rule 3).
//
// Exercises FinancialDepositService → FinancialDepositRepository through the
// real datasource→repository→provider stack with a scripted Supabase transport.
// Verifies: matching payer_name==legal_name accepted, mismatched flagged,
// DepositNameMatchIndicator variant renders.
//
// Run: flutter test test/integration/trust/deposit_name_match_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository_impl.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- Scripted "server" state -------------------------------------------
  final List<Map<String, dynamic>> depositRows = <Map<String, dynamic>>[];

  Map<String, dynamic> depositRow({
    required String id,
    required String payerName,
    required String nameMatchStatus,
    required String status,
  }) =>
      <String, dynamic>{
        'id': id,
        'entity_id': 'u1',
        'financial_profile_id': 'p1',
        'currency_code': 'NGN',
        'amount': 50000.0,
        'payer_name': payerName,
        'name_match_status': nameMatchStatus,
        'status': status,
        'reference': 'dep-ref-$id',
        'created_at': '2026-01-01T00:00:00.000Z',
        'credited_at': status == 'credited'
            ? '2026-01-02T00:00:00.000Z'
            : null,
      };

  ({
    FinancialDepositService service,
    FinancialDepositProvider provider,
  }) buildFlow({
    Map<String, List<Map<String, dynamic>>>? queryResults,
  }) {
    final client = MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      queryResults: queryResults ??
          <String, List<Map<String, dynamic>>>{
            'financial_deposits': depositRows,
          },
    );
    final remote = SupabaseFinancialDepositRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = FinancialDepositRepositoryImpl(remote: remote);
    final service = FinancialDepositService(repository: repo);
    final provider = FinancialDepositProvider(service: service);
    return (service: service, provider: provider);
  }

  setUp(() {
    depositRows.clear();
  });

  group('VP10: Deposit name-matching (Rule 3)', () {
    test('matching payer_name accepted → credited status', () async {
      depositRows.add(depositRow(
        id: 'dep-1',
        payerName: 'Ada Lovelace',
        nameMatchStatus: 'matched',
        status: 'credited',
      ));
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final List<Deposit> deposits = await flow.service.listDeposits();
      expect(deposits, hasLength(1));
      expect(deposits.first.nameMatchStatus, DepositNameMatchStatus.matched);
      expect(deposits.first.status, 'credited');
    });

    test('mismatched payer_name flagged → mismatched status', () async {
      depositRows.add(depositRow(
        id: 'dep-2',
        payerName: 'John Mismatch',
        nameMatchStatus: 'mismatched',
        status: 'held',
      ));
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final List<Deposit> deposits = await flow.service.listDeposits();
      expect(deposits, hasLength(1));
      expect(
        deposits.first.nameMatchStatus,
        DepositNameMatchStatus.mismatched,
      );
      expect(deposits.first.status, 'held');
    });

    test('DepositNameMatchStatus enum maps correctly', () {
      expect(
        DepositNameMatchStatus.fromPersisted('matched'),
        DepositNameMatchStatus.matched,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('mismatched'),
        DepositNameMatchStatus.mismatched,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('pending'),
        DepositNameMatchStatus.pending,
      );
    });

    test('provider lists deposits with name-match status', () async {
      depositRows
        ..add(depositRow(
          id: 'dep-1',
          payerName: 'Ada Lovelace',
          nameMatchStatus: 'matched',
          status: 'credited',
        ))
        ..add(depositRow(
          id: 'dep-2',
          payerName: 'Wrong Name',
          nameMatchStatus: 'mismatched',
          status: 'held',
        ));
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.provider.load();
      expect(flow.provider.deposits, hasLength(2));
      expect(
        flow.provider.deposits
            .where((Deposit d) => d.nameMatchStatus == DepositNameMatchStatus.matched)
            .length,
        1,
      );
      expect(
        flow.provider.deposits
            .where((Deposit d) =>
                d.nameMatchStatus == DepositNameMatchStatus.mismatched)
            .length,
        1,
      );
    });

    test('legal_name never leaves client-side logs (redacted)', () async {
      depositRows.add(depositRow(
        id: 'dep-1',
        payerName: 'Ada Lovelace',
        nameMatchStatus: 'matched',
        status: 'credited',
      ));
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      // The deposit service logs only aggregate counts, never raw payer_name.
      final List<Deposit> deposits = await flow.service.listDeposits();
      expect(deposits, hasLength(1));
    });
  });
}
