import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/name_enquiry_service.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_transport.dart';

/// `NameEnquiryService` backed by a direct NIBSS call when a credential is
/// provisioned, otherwise delegating to an injected [fallback] resolver.
///
/// ## Direct NIBSS
/// When [PaymentGatewayConfig.nibssBaseUrl] is set, this adapter posts to
/// `{baseUrl}/nip/name-enquiry` first. If that call fails (e.g. NIBSS is
/// unreachable or returns 5xx), it falls back to [fallback] — a gateway
/// `resolve` adapter (Paystack/Flutterwave) behind the same interface — so
/// EP-02-16 name-matching works even before a paying NIBSS credential is
/// provisioned (EP-02-09 §5.5).
///
/// ## Fail-fast validation
/// [verifyAccount] validates the NUBAN account number (`^\d{10}$`) **before**
/// any network call, throwing `validation` (PLT003) for invalid input.
class NibssNameEnquiryAdapter implements NameEnquiryService {
  NibssNameEnquiryAdapter({
    required this.dio,
    required this.mapper,
    required this.config,
    this.fallback,
  });

  /// The [Dio] used for direct NIBSS calls (baseUrl set by the factory).
  final Dio dio;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper mapper;

  /// Provider configuration (secrets, default provider).
  final PaymentGatewayConfig config;

  /// Optional resolver used when direct NIBSS fails or is unconfigured.
  final NameEnquiryService? fallback;

  @override
  Future<NameEnquiryResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    requireValidNuban(accountNumber);
    requireValidBankCode(bankCode);

    final String? nibssBaseUrl = config.nibssBaseUrl;
    if (nibssBaseUrl != null && nibssBaseUrl.isNotEmpty) {
      try {
        return await _callDirect(nibssBaseUrl, bankCode, accountNumber);
      } on ApiException {
        final NameEnquiryService? resolver = fallback;
        if (resolver != null) {
          return resolver.verifyAccount(
            bankCode: bankCode,
            accountNumber: accountNumber,
          );
        }
        rethrow;
      }
    }

    final NameEnquiryService? resolver = fallback;
    if (resolver != null) {
      return resolver.verifyAccount(
        bankCode: bankCode,
        accountNumber: accountNumber,
      );
    }
    throw logicalProviderError(
      message:
          'No name-enquiry resolver is configured — set NIBSS or provide a '
          'provider fallback.',
      kind: ApiExceptionKind.server,
      code: 'PLT999',
    );
  }

  Future<NameEnquiryResult> _callDirect(
    String baseUrl,
    String bankCode,
    String accountNumber,
  ) {
    final String endpoint =
        '${baseUrl.replaceAll(RegExp(r'/$'), '')}/nip/name-enquiry';
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        endpoint,
        data: <String, dynamic>{
          'account_number': accountNumber,
          'bank_code': bankCode,
          if (config.nibssApiKey != null) 'api_key': config.nibssApiKey,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = body['data'] is Map
          ? _asMap(body['data'])
          : body;
      final String? name = _firstString(
        data['account_name'],
        data['accountName'],
        data['name'],
      );
      if (name == null || name.isEmpty) {
        throw logicalProviderError(
          message: 'NIBSS did not return an account name.',
        );
      }
      return NameEnquiryResult(
        accountNumber: accountNumber,
        accountName: name,
        bankCode: bankCode,
      );
    });
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v as dynamic),
      );
    }
    return <String, dynamic>{};
  }

  static String? _firstString(Object? a, Object? b, Object? c) {
    for (final Object? value in <Object?>[a, b, c]) {
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
