import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_transport.dart';

/// Flutterwave implementation of the [PaymentGateway] contract.
///
/// Own `Dio` targeting `https://api.flutterwave.com`, authenticated with
/// `Authorization: Bearer <config.flutterwaveSecretKey>`. Provider payloads
/// are mapped internally to provider-neutral models; no `FlutterwaveDto` leaks.
///
/// ## Amount units
/// Flutterwave quotes **major units** (NGN), and `Amount.minorUnits` is kobo.
/// On initialize the adapter sends `amount = minorUnits ~/ 100`; on verify it
/// converts the returned major-unit amount back to kobo
/// (`majorUnits * 100`). This keeps the neutral [Amount] in minor units and
/// prevents the 100x unit bug (EP-02-09 §5.3, FV-14).
///
/// ## Webhook signature
/// Flutterwave uses a `verif-hash` header configured on the dashboard; the
/// adapter compares it (constant-time) against the configured secret.
class FlutterwaveGateway implements PaymentGateway {
  FlutterwaveGateway({
    required this.dio,
    required this.mapper,
    required this.config,
  });

  static const int _minorUnitsPerMajor = 100;

  /// The provider-scoped [Dio] instance (baseUrl `https://api.flutterwave.com`).
  final Dio dio;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper mapper;

  /// Provider configuration (secrets, default provider).
  final PaymentGatewayConfig config;

  static const String baseUrl = 'https://api.flutterwave.com';

  @override
  PaymentProvider get provider => PaymentProvider.flutterwave;

  @override
  Future<PaymentInitializationResult> initializePayment(
    PaymentInitializationRequest request,
  ) {
    validateAmount(request.amount);
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/v3/charges',
        queryParameters: <String, dynamic>{'type': 'bank_transfer'},
        data: <String, dynamic>{
          'tx_ref': request.reference,
          'amount': _toMajorUnits(request.amount.minorUnits),
          'currency': request.currency ?? request.amount.currency,
          'email': request.email,
          'redirect_url': request.callbackUrl,
          if (request.metadata != null) 'meta': request.metadata,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
      final Object? txRef = data['tx_ref'];
      return PaymentInitializationResult(
        reference: txRef is String ? txRef : request.reference,
        authorizationUrl: data['link'] as String? ?? '',
        accessCode: data['flw_ref'] as String? ?? '',
      );
    });
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(String reference) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/v3/transactions/$reference/verify',
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
      final int majorUnits = _asInt(data['amount']) ?? 0;
      final String currency = data['currency'] as String? ?? 'NGN';
      return PaymentVerificationResult(
        reference: data['tx_ref'] as String? ?? reference,
        status: _mapStatus(data['status'] as String?),
        amount: Amount(
          minorUnits: _toMinorUnits(majorUnits),
          currency: currency,
        ),
        currency: currency,
        paidAt: _parseDateTime(data['created_at']),
        gatewayFee: null,
      );
    });
  }

  @override
  Future<TransferResult> createTransfer(TransferRequest request) {
    validateAmount(request.amount);
    requireValidNuban(request.recipientAccountNumber);
    requireValidBankCode(request.recipientBankCode);
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/v3/transfers',
        data: <String, dynamic>{
          'account_bank': request.recipientBankCode,
          'account_number': request.recipientAccountNumber,
          'amount': _toMajorUnits(request.amount.minorUnits),
          'currency': request.amount.currency,
          'reference': request.reference,
          'narration': request.reason,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
      return TransferResult(
        reference: data['id']?.toString() ?? request.reference,
        status: _mapTransferStatus(data['status'] as String?),
        amount: request.amount,
      );
    });
  }

  @override
  Future<TransferResult> verifyTransfer(String reference) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/v3/transfers/$reference',
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
      final int majorUnits = _asInt(data['amount']) ?? 0;
      final String currency = data['currency'] as String? ?? 'NGN';
      return TransferResult(
        reference: data['reference'] as String? ?? reference,
        status: _mapTransferStatus(data['status'] as String?),
        amount: Amount(
          minorUnits: _toMinorUnits(majorUnits),
          currency: currency,
        ),
      );
    });
  }

  @override
  Future<RefundResult> refundPayment(RefundRequest request) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/v3/transactions/${request.transactionReference}/refund',
        data: <String, dynamic>{
          if (request.amount != null)
            'amount': _toMajorUnits(request.amount!.minorUnits),
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
      final int majorUnits = _asInt(data['amount']) ?? 0;
      final String currency = data['currency'] as String? ?? 'NGN';
      return RefundResult(
        reference: request.transactionReference,
        status: PaymentStatus.reversed,
        amount: Amount(
          minorUnits: majorUnits == 0
              ? (request.amount?.minorUnits ?? 0)
              : _toMinorUnits(majorUnits),
          currency: currency,
        ),
      );
    });
  }

  /// Resolves an account name via Flutterwave's `v3/accounts/resolve`.
  ///
  /// Used by [NibssNameEnquiryAdapter] as a fallback when no direct NIBSS
  /// credential exists (EP-02-09 §5.5).
  Future<NameEnquiryResult> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) {
    return invokePaymentCall(mapper, () async {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/v3/accounts/resolve',
        data: <String, dynamic>{
          'account_number': accountNumber,
          'account_bank': bankCode,
        },
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Map<String, dynamic> data = _requireData(body);
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
    final Map<String, dynamic>? data =
        rawBody['data'] is Map<String, dynamic>
        ? rawBody['data'] as Map<String, dynamic>
        : null;
    final String? dataStatus = data?['status'] as String?;
    if ((event == null || event.isEmpty) &&
        (dataStatus == null || dataStatus.isEmpty)) {
      throw logicalProviderError(
        message: 'Webhook payload is missing the event type.',
        code: 'PLT003',
      );
    }
    final Object? txRef = data?['tx_ref'];
    final String reference = txRef is String ? txRef : '';
    final String effectiveEvent = event ?? dataStatus ?? '';
    return WebhookEvent(
      provider: provider.name,
      eventType: effectiveEvent,
      reference: reference,
      status: _statusForEvent(effectiveEvent),
      raw: rawBody,
    );
  }

  @override
  bool verifyWebhookSignature({
    required String rawBody,
    required String signatureHeader,
  }) {
    return _constantTimeEquals(
      signatureHeader,
      config.flutterwaveSecretKey,
    );
  }

  /// Case-insensitive header lookup; also accepts camelCase `verif_hash`.
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

  /// Major units to minor units (NGN → kobo).
  static int _toMinorUnits(int majorUnits) => majorUnits * _minorUnitsPerMajor;

  /// Minor units to major units (kobo → NGN), truncating any sub-unit.
  static int _toMajorUnits(int minorUnits) =>
      minorUnits ~/ _minorUnitsPerMajor;

  static bool _isOk(Map<String, dynamic> body) =>
      body['status'] == 'success' ||
      body['status'] == 'successful' ||
      body['status'] == true;

  static Map<String, dynamic> _requireData(Map<String, dynamic> body) {
    if (!_isOk(body)) {
      final Object? message = body['message'];
      final Object? status = body['status'];
      final bool isServerError = status == 'error' && message == null;
      throw logicalProviderError(
        message: _safeMessage(message),
        kind: isServerError ? ApiExceptionKind.server : ApiExceptionKind.validation,
        code: isServerError ? 'PLT999' : 'PLT003',
      );
    }
    final Object? data = body['data'];
    if (data is Map) {
      return data.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v as dynamic),
      );
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

  static PaymentStatus _statusForEvent(String? event) {
    if (event == null || event.isEmpty) return PaymentStatus.pending;
    if (event.contains('.success') ||
        event.contains('.completed') ||
        event.contains('successful')) {
      return PaymentStatus.success;
    }
    if (event.contains('failed')) return PaymentStatus.failed;
    if (event.contains('abandoned')) return PaymentStatus.abandoned;
    if (event.contains('reversed')) return PaymentStatus.reversed;
    return PaymentStatus.pending;
  }

  static PaymentStatus _mapStatus(String? status) {
    return switch (status) {
      'success' || 'successful' => PaymentStatus.success,
      'failed' => PaymentStatus.failed,
      'abandoned' => PaymentStatus.abandoned,
      'reversed' => PaymentStatus.reversed,
      _ => PaymentStatus.pending,
    };
  }

  static TransferStatus _mapTransferStatus(String? status) {
    return switch (status) {
      'success' || 'successful' => TransferStatus.success,
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

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
