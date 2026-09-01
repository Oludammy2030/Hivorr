import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_transport.dart';

/// Paystack implementation of the [PaymentGateway] contract.
///
/// Own `Dio` targeting `https://api.paystack.co`, authenticated with
/// `Authorization: Bearer <config.paystackSecretKey>`. Provider payloads are
/// mapped internally to provider-neutral models; no `Paystack*Dto` leaks to
/// callers (ARCHITECTURE.md:151-152).
///
/// ## Amount units
/// Paystack quotes kobo — `minorUnits` is sent verbatim (e.g. `500000` for
/// NGN 5,000), so no unit conversion is required on this adapter.
///
/// ## createTransfer 2-step
/// Paystack requires a `transferrecipient` before a `transfer`. This adapter
/// hides that sequence: it creates the recipient first, then the transfer,
/// returning a single [TransferResult].
///
/// ## Webhook signature
/// `x-paystack-signature` = `sha512=` + hex(`HMAC_SHA512(secret, rawBody)`).
class PaystackGateway implements PaymentGateway {
  PaystackGateway({
    required this.dio,
    required this.mapper,
    required this.config,
  });

  /// The provider-scoped [Dio] instance (baseUrl `https://api.paystack.co`).
  final Dio dio;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper mapper;

  /// Provider configuration (secrets, default provider).
  final PaymentGatewayConfig config;

  static const String baseUrl = 'https://api.paystack.co';

  @override
  PaymentProvider get provider => PaymentProvider.paystack;

  @override
  Future<PaymentInitializationResult> initializePayment(
    PaymentInitializationRequest request,
  ) {
    validateAmount(request.amount);
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/transaction/initialize',
        data: <String, dynamic>{
          'email': request.email,
          'amount': request.amount.minorUnits,
          'reference': request.reference,
          'callback_url': request.callbackUrl,
          'currency': request.currency ?? request.amount.currency,
          if (request.metadata != null) 'metadata': request.metadata,
        },
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      return PaymentInitializationResult(
        reference: data['reference'] as String? ?? request.reference,
        authorizationUrl: data['authorization_url'] as String? ?? '',
        accessCode: data['access_code'] as String? ?? '',
      );
    });
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(String reference) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/transaction/verify/$reference',
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      final int amount = _asInt(data['amount']) ?? 0;
      final String currency = data['currency'] as String? ?? 'NGN';
      final int? fees = _asInt(data['fees']);
      return PaymentVerificationResult(
        reference: data['reference'] as String? ?? reference,
        status: _mapStatus(data['status'] as String?),
        amount: Amount(minorUnits: amount, currency: currency),
        currency: currency,
        paidAt: _parseDateTime(data['paid_at']),
        gatewayFee: fees == null
            ? null
            : Amount(minorUnits: fees, currency: currency),
      );
    });
  }

  @override
  Future<TransferResult> createTransfer(TransferRequest request) {
    validateAmount(request.amount);
    requireValidNuban(request.recipientAccountNumber);
    requireValidBankCode(request.recipientBankCode);
    return invokePaymentCall(mapper, () async {
      final String recipientCode = await _ensureRecipient(request);
      final Response<dynamic> response = await dio.post<dynamic>(
        '/transfer',
        data: <String, dynamic>{
          'source': 'balance',
          'reason': request.reason,
          'amount': request.amount.minorUnits,
          'recipient': recipientCode,
          'reference': request.reference,
        },
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      return TransferResult(
        reference: data['reference'] as String? ?? request.reference,
        status: _mapTransferStatus(data['status'] as String?),
        amount: request.amount,
      );
    });
  }

  /// Creates the transfer recipient and returns its `recipient_code`.
  ///
  /// Hidden 2-step detail of Paystack transfers (EP-02-09 §5.4).
  Future<String> _ensureRecipient(TransferRequest request) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/transferrecipient',
        data: <String, dynamic>{
          'type': 'nuban',
          'name': 'Hivorr Payout Recipient',
          'account_number': request.recipientAccountNumber,
          'bank_code': request.recipientBankCode,
          'currency': request.amount.currency,
        },
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      final String? code = data['recipient_code'] as String?;
      if (code == null || code.isEmpty) {
        throw logicalProviderError(
          message: 'Payment provider did not return a recipient code.',
          kind: ApiExceptionKind.server,
          code: 'PLT999',
        );
      }
      return code;
    });
  }

  @override
  Future<TransferResult> verifyTransfer(String reference) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/transfer/verify/$reference',
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      final int amount = _asInt(data['amount']) ?? 0;
      final String currency = data['currency'] as String? ?? 'NGN';
      return TransferResult(
        reference: data['reference'] as String? ?? reference,
        status: _mapTransferStatus(data['status'] as String?),
        amount: Amount(minorUnits: amount, currency: currency),
      );
    });
  }

  @override
  Future<RefundResult> refundPayment(RefundRequest request) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/refund',
        data: <String, dynamic>{
          'transaction': request.transactionReference,
          if (request.amount != null) 'amount': request.amount!.minorUnits,
          if (request.reason != null) 'merchant_note': request.reason,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      if (!_isOk(body)) {
        throw logicalProviderError(
          message: _safeMessage(body['message']),
          kind: ApiExceptionKind.server,
          code: 'PLT999',
        );
      }
      final Map<String, dynamic>? data =
          body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : null;
      final int amount =
          _asInt(data?['amount']) ?? request.amount?.minorUnits ?? 0;
      final String currency = data?['currency'] as String? ?? 'NGN';
      return RefundResult(
        reference: request.transactionReference,
        status: PaymentStatus.reversed,
        amount: Amount(minorUnits: amount, currency: currency),
      );
    });
  }

  /// Resolves an account name via Paystack's NIBSS-backed `bank/resolve`.
  ///
  /// Used by [NibssNameEnquiryAdapter] as a fallback when no direct NIBSS
  /// credential exists (EP-02-09 §5.5).
  Future<NameEnquiryResult> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/bank/resolve',
        queryParameters: <String, dynamic>{
          'account_number': accountNumber,
          'bank_code': bankCode,
        },
      );
      final Map<String, dynamic> data = _requireData(_asMap(response.data));
      return NameEnquiryResult(
        accountNumber: data['account_number'] as String? ?? accountNumber,
        accountName: data['account_name'] as String? ?? '',
        bankCode: bankCode,
      );
    });
  }

  @override
  WebhookEvent parseWebhookEvent(
    Map<String, dynamic> rawBody,
    Map<String, String> headers,
  ) {
    final String? event = rawBody['event'] as String?;
    if (event == null || event.isEmpty) {
      throw logicalProviderError(
        message: 'Webhook payload is missing the event field.',
        code: 'PLT003',
      );
    }
    final Object? data = rawBody['data'];
    final Map<String, dynamic>? dataMap =
        data is Map<String, dynamic> ? data : null;
    final Object? transfer =
        dataMap?['transfer'] is Map<String, dynamic>
        ? dataMap!['transfer']
        : null;
    final String reference =
        (dataMap?['reference'] as String?) ??
        (transfer is Map<String, dynamic> ? transfer['reference'] as String? : null) ??
        '';
    return WebhookEvent(
      provider: provider.name,
      eventType: event,
      reference: reference,
      status: _statusForEvent(event),
      raw: rawBody,
    );
  }

  @override
  bool verifyWebhookSignature({
    required String rawBody,
    required String signatureHeader,
  }) {
    final String expected =
        'sha512=${_hmacSha512(config.paystackSecretKey, rawBody)}';
    return _constantTimeEquals(expected, signatureHeader);
  }

  /// Returns the value of a case-insensitive header [name], or `null`.
  static String? headerValue(
    Map<String, String> headers,
    String name,
  ) {
    for (final MapEntry<String, String> entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  static bool _isOk(Map<String, dynamic> body) =>
      body['status'] == true || body['status'] == 'true';

  /// Extracts the provider `data` map, mapping `status:false` logical errors.
  static Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    if (!_isOk(body)) {
      throw logicalProviderError(
        message: _safeMessage(body['message']),
      );
    }
    final Object? data = body['data'];
    if (data is Map) {
      return data
          .map(
            (dynamic k, dynamic v) => MapEntry<dynamic, dynamic>(k, v),
          )
          .cast<String, dynamic>();
    }
    throw logicalProviderError(
      message: 'Payment provider returned an unexpected response.',
      kind: ApiExceptionKind.server,
      code: 'PLT999',
    );
  }

  static String _safeMessage(Object? raw) {
    final String? value = raw is String ? raw : null;
    if (value == null || value.trim().isEmpty) {
      return 'Payment provider rejected the request.';
    }
    final String trimmed = value.trim();
    return trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
  }

  static PaymentStatus _statusForEvent(String event) {
    if (event.contains('.success')) return PaymentStatus.success;
    if (event.contains('failed')) return PaymentStatus.failed;
    if (event.contains('abandoned')) return PaymentStatus.abandoned;
    if (event.contains('reversed')) return PaymentStatus.reversed;
    return PaymentStatus.pending;
  }

  static PaymentStatus _mapStatus(String? status) {
    return switch (status) {
      'success' => PaymentStatus.success,
      'failed' => PaymentStatus.failed,
      'abandoned' => PaymentStatus.abandoned,
      'reversed' => PaymentStatus.reversed,
      _ => PaymentStatus.pending,
    };
  }

  static TransferStatus _mapTransferStatus(String? status) {
    return switch (status) {
      'success' => TransferStatus.success,
      'failed' => TransferStatus.failed,
      'reversed' => TransferStatus.reversed,
      _ => TransferStatus.pending,
    };
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v as dynamic),
      );
    }
    return <String, dynamic>{};
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _hmacSha512(String secret, String body) {
    final Hmac hmac = Hmac(sha512, utf8.encode(secret));
    return hmac.convert(utf8.encode(body)).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
