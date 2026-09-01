import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/name_enquiry_service.dart';
import 'package:hivorr/integrations/payment_gateways/nibss_name_enquiry_adapter.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';

import '../../../support/support.dart';
import 'payment_env_source.dart';

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  PaymentGatewayConfig nibssConfig() => PaymentGatewayConfig.fromEnvironment(
        paymentEnvSource(
          overrides: <String, String>{
            AppConstants.envNibssBaseUrl: 'https://nibss.example.com',
            AppConstants.envNibssApiKey: 'nibss-cred',
          },
        ),
      );

  group('verifyAccount (direct NIBSS configured)', () {
    late MockDioAdapter httpMock;
    late Dio dio;
    late NibssNameEnquiryAdapter adapter;

    setUp(() {
      httpMock = MockDioAdapter();
      dio = Dio(BaseOptions())..httpClientAdapter = httpMock;
      adapter = NibssNameEnquiryAdapter(
        dio: dio,
        mapper: mapper,
        config: nibssConfig(),
      );
    });

    test('posts to {baseUrl}/nip/name-enquiry and returns the name', () async {
      httpMock.body = <String, dynamic>{
        'data': <String, dynamic>{'account_name': 'ADEOLA OYEKANMI'},
      };

      final result = await adapter.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );

      expect(result.accountName, 'ADEOLA OYEKANMI');
      expect(result.accountNumber, '0123456789');
      expect(result.bankCode, '058');
      expect(httpMock.capturedUrl, 'https://nibss.example.com/nip/name-enquiry');

      final Map<String, dynamic>? body = httpMock.capturedBody;
      expect(body?['account_number'], '0123456789');
      expect(body?['bank_code'], '058');
      expect(body?['api_key'], 'nibss-cred');
    });

    test('accepts a trailing slash on the base url', () async {
      final trailing = NibssNameEnquiryAdapter(
        dio: dio,
        mapper: mapper,
        config: PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envNibssBaseUrl: 'https://nibss.example.com/',
            },
          ),
        ),
      );
      httpMock.body = <String, dynamic>{
        'data': <String, dynamic>{'account_name': 'A NAME'},
      };

      await trailing.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );

      expect(
        httpMock.capturedUrl,
        'https://nibss.example.com/nip/name-enquiry',
      );
    });

    test('reads alternate name field spellings', () async {
      httpMock.body = <String, dynamic>{
        'data': <String, dynamic>{'accountName': 'SPELLING TWO'},
      };
      final result = await adapter.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );
      expect(result.accountName, 'SPELLING TWO');
    });

    test('reads the root-level name field when data does not nest it', () async {
      httpMock.body = <String, dynamic>{
        'name': 'TOP LEVEL NAME',
      };
      final result = await adapter.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );
      expect(result.accountName, 'TOP LEVEL NAME');
    });

    test('throws server error when no name is returned', () async {
      httpMock.body = <String, dynamic>{
        'data': <String, dynamic>{'account_number': '0123456789'},
      };
      await expectLater(
        adapter.verifyAccount(
          bankCode: '058',
          accountNumber: '0123456789',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });

    test('fails fast on an invalid account number', () async {
      await expectLater(
        adapter.verifyAccount(
          bankCode: '058',
          accountNumber: '123',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
      expect(httpMock.requests, isEmpty);
    });

    test('fails fast on an invalid bank code', () async {
      await expectLater(
        adapter.verifyAccount(
          bankCode: '58',
          accountNumber: '0123456789',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(httpMock.requests, isEmpty);
    });
  });

  group('verifyAccount (fallback resolution)', () {
    late MockDioAdapter httpMock;
    late Dio dio;

    setUp(() {
      httpMock = MockDioAdapter();
      dio = Dio(BaseOptions())..httpClientAdapter = httpMock;
    });

    test('delegates to the fallback when NIBSS is unconfigured', () async {
      final adapter = NibssNameEnquiryAdapter(
        dio: dio,
        mapper: mapper,
        config: PaymentGatewayConfig.fromEnvironment(paymentEnvSource()),
        fallback: _FakeResolver('FROM_FALLBACK'),
      );

      final result = await adapter.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );

      expect(result.accountName, 'FROM_FALLBACK');
      expect(httpMock.requests, isEmpty);
      expect(result.accountNumber, '0123456789');
      expect(result.bankCode, '058');
    });

    test('falls back to the resolver when the direct NIBSS call fails', () async {
      final adapter = NibssNameEnquiryAdapter(
        dio: dio,
        mapper: mapper,
        config: nibssConfig(),
        fallback: _FakeResolver('AFTER_FAILURE'),
      );
      httpMock.error = 'not json';

      final result = await adapter.verifyAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );

      expect(result.accountName, 'AFTER_FAILURE');
      expect(httpMock.requests.length, 1);
    });

    test('throws PLT999 when no NIBSS and no fallback exist', () async {
      final adapter = NibssNameEnquiryAdapter(
        dio: dio,
        mapper: mapper,
        config: PaymentGatewayConfig.fromEnvironment(paymentEnvSource()),
      );

      await expectLater(
        adapter.verifyAccount(
          bankCode: '058',
          accountNumber: '0123456789',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });
  });
}

class _FakeResolver implements NameEnquiryService {
  _FakeResolver(this.accountName);

  final String accountName;

  String? lastAccountNumber;
  String? lastBankCode;

  @override
  Future<NameEnquiryResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    lastBankCode = bankCode;
    lastAccountNumber = accountNumber;
    return NameEnquiryResult(
      accountNumber: accountNumber,
      accountName: accountName,
      bankCode: bankCode,
    );
  }
}
