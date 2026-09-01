import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';

/// Wraps [call] so that any [DioException] is normalized to an [ApiException].
///
/// Mirrors `BaseApiService.invoke` (lib/core/api/services/base_api_service.dart:33)
/// but keeps the gateway adapters pure `Dio` — no `SupabaseClient` dependency
/// (EP-02-09 §5.1, TV-05). Already-normalized errors are rethrown as-is.
Future<T> invokePaymentCall<T>(
  ApiExceptionMapper mapper,
  Future<T> Function() call,
) async {
  try {
    return await call();
  } on DioException catch (e) {
    final Object? existing = e.error;
    if (existing is ApiException) {
      throw existing;
    }
    throw mapper.map(e);
  }
}

/// Builds a provider-scoped [ApiException] for the HTTP-200-but-`status:false`
/// logical-error envelope that Paystack/Flutterwave return on business
/// failures. Prevents raw provider JSON from leaking to callers.
ApiException logicalProviderError({
  required String message,
  ApiExceptionKind kind = ApiExceptionKind.validation,
  int? statusCode,
  String code = 'PLT003',
}) {
  return ApiException(
    kind: kind,
    message: message,
    code: code,
    statusCode: statusCode,
  );
}

/// Highest allowed amount in minor units (NGN 99M Paystack cap,
/// EP-02-09 §7.1). 99,000,000 NGN * 100 kobo = 9,900,000,000.
const int maxAmountMinorUnits = 9900000000;

/// Validates [amount] fail-fast before any network call.
///
/// Throws `validation` (PLT003) when `minorUnits <= 0` or above the provider
/// cap, or when [currency] is not a supported code (EP-02-09 §7.1, DV-07).
void validateAmount(
  Amount amount, {
  Set<String> supportedCurrencies = _defaultCurrencies,
}) {
  if (amount.minorUnits <= 0) {
    throw logicalProviderError(message: 'Amount must be greater than zero.');
  }
  if (amount.minorUnits > maxAmountMinorUnits) {
    throw logicalProviderError(
      message: 'Amount exceeds the maximum allowed value.',
    );
  }
  if (!supportedCurrencies.contains(amount.currency)) {
    throw logicalProviderError(
      message: 'Unsupported currency: ${amount.currency}.',
    );
  }
}

/// Validates a NUBAN account number (exactly 10 digits) fail-fast, before
/// any network call (EP-02-09 §5.5, DV-06).
String requireValidNuban(String accountNumber) {
  if (!_nubanRegExp.hasMatch(accountNumber)) {
    throw logicalProviderError(
      message: 'Account number must be 10 digits.',
    );
  }
  return accountNumber;
}

/// Validates a 3-digit CBN bank code fail-fast.
String requireValidBankCode(String bankCode) {
  if (!_bankCodeRegExp.hasMatch(bankCode)) {
    throw logicalProviderError(
      message: 'Bank code must be 3 digits.',
    );
  }
  return bankCode;
}

/// Supported currencies per EP-02:189 (4-currency financial infra).
const Set<String> _defaultCurrencies = <String>{
  'NGN',
  'GHS',
  'USD',
  'GBP',
};

final RegExp _nubanRegExp = RegExp(r'^\d{10}$');
final RegExp _bankCodeRegExp = RegExp(r'^\d{3}$');
