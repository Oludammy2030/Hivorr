/// Data Transfer Object for the financial profile read model (EP-02-13).
///
/// Mirrors the `financial_profile_get` RPC envelope `profile` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:683-714`).
/// camelCase Dart fields map the snake_case server keys via [fromJson].
class FinancialProfileDto {
  const FinancialProfileDto({
    required this.id,
    required this.entityId,
    required this.status,
    required this.defaultCurrency,
    required this.createdAt,
    this.currencyAccounts = const <CurrencyAccountDto>[],
  });

  factory FinancialProfileDto.fromJson(Map<String, dynamic> json) =>
      FinancialProfileDto(
        id: (json['id'] as String?) ?? '',
        entityId: (json['entity_id'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'active',
        defaultCurrency: (json['default_currency'] as String?) ?? 'NGN',
        createdAt: _parseDateTime(json['created_at']),
        currencyAccounts: _parseCurrencyAccounts(json['currency_accounts']),
      );

  final String id;
  final String entityId;
  final String status;
  final String defaultCurrency;
  final DateTime createdAt;
  final List<CurrencyAccountDto> currencyAccounts;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<CurrencyAccountDto> _parseCurrencyAccounts(dynamic value) {
    if (value is! List) return const <CurrencyAccountDto>[];
    return value
        .map((e) => CurrencyAccountDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

/// Data Transfer Object for a currency account read model (EP-02-13).
///
/// Mirrors the `currency_accounts` array objects within the
/// `financial_profile_get` RPC response.
class CurrencyAccountDto {
  const CurrencyAccountDto({
    required this.id,
    required this.financialProfileId,
    required this.entityId,
    required this.currencyCode,
    required this.accountStatus,
    this.receivingAccountNumber,
    this.receivingBankName,
    this.providerReference,
    this.activatedAt,
  });

  factory CurrencyAccountDto.fromJson(Map<String, dynamic> json) =>
      CurrencyAccountDto(
        id: (json['id'] as String?) ?? '',
        financialProfileId: (json['financial_profile_id'] as String?) ?? '',
        entityId: (json['entity_id'] as String?) ?? '',
        currencyCode: (json['currency_code'] as String?) ?? '',
        accountStatus: (json['account_status'] as String?) ?? 'pending',
        receivingAccountNumber: json['receiving_account_number'] as String?,
        receivingBankName: json['receiving_bank_name'] as String?,
        providerReference: json['provider_reference'] as String?,
        activatedAt: json['activated_at'] != null
            ? _parseDateTime(json['activated_at'])
            : null,
      );

  final String id;
  final String financialProfileId;
  final String entityId;
  final String currencyCode;
  final String accountStatus;
  final String? receivingAccountNumber;
  final String? receivingBankName;
  final String? providerReference;
  final DateTime? activatedAt;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
