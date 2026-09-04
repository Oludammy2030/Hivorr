import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';

void main() {
  group('FinancialService vocabulary', () {
    test('exposes four supported currencies', () {
      expect(FinancialService.supportedCurrencies, hasLength(4));
      expect(FinancialService.supportedCurrencies.first.code, 'NGN');
    });

    test('isCurrencySupported validates codes', () {
      expect(FinancialService.isCurrencySupported('NGN'), isTrue);
      expect(FinancialService.isCurrencySupported('KES'), isFalse);
    });
  });

  group('FinancialService.getProfile', () {
    test('delegates to repository and returns entity', () async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(defaultCurrency: 'GBP'),
      );
      final service = FinancialService(repository: repo);

      final FinancialProfile? profile = await service.getProfile();

      expect(profile, isNotNull);
      expect(profile!.defaultCurrency, 'GBP');
      expect(repo.profileCallCount, 1);
    });
  });

  group('FinancialService.createProfile', () {
    test('delegates creation with selected currency', () async {
      final repo = FakeFinancialRepository();
      final service = FinancialService(repository: repo);

      final FinancialProfile profile =
          await service.createProfile(defaultCurrency: 'USD');

      expect(profile.defaultCurrency, 'USD');
      expect(repo.createCallCount, 1);
      expect(repo.lastDefaultCurrency, 'USD');
    });

    test('surfaces ApiException from repository', () async {
      final repo = FakeFinancialRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'exists',
          code: 'PLT005',
        );
      final service = FinancialService(repository: repo);

      expect(
        () => service.createProfile(defaultCurrency: 'NGN'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)),
      );
    });
  });

  group('FinancialService with logger', () {
    test('accepts an optional logger (does not throw)', () async {
      final repo = FakeFinancialRepository(profile: seedProfileEntity());
      final service = FinancialService(
        repository: repo,
        logger: HivorrLogger(
          'test',
          LogRouter(sinks: <LogSink>[], minimumLevel: LogLevel.debug),
          PiiRedactor(),
        ),
      );
      final profile = await service.getProfile();
      expect(profile, isNotNull);
    });
  });
}
