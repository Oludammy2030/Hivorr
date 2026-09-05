import 'package:hivorr/data/entities/conversion_preview.dart';

/// Data Transfer Object for a locally-computed conversion estimate (EP-02-15).
///
/// The preview itself is pure local math (gross/fee/net against the trusted
/// rate seam) and is never transported; this DTO defines the canonical
/// serialized shape of a preview (`from_currency`, `to_currency`,
/// `from_amount`, `gross_amount`, `fee`, `to_amount`, `exchange_rate`) for
/// future state restoration / deep-linking, and maps it back to the domain
/// [ConversionPreview] via [ConversionMapper.previewToEntity].
class ConversionPreviewDto {
  const ConversionPreviewDto({
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.grossAmount,
    required this.fee,
    required this.toAmount,
    required this.exchangeRate,
  });

  factory ConversionPreviewDto.fromJson(Map<String, dynamic> json) =>
      ConversionPreviewDto(
        fromCurrency: (json['from_currency'] as String?) ?? '',
        toCurrency: (json['to_currency'] as String?) ?? '',
        fromAmount: _toDouble(json['from_amount']),
        grossAmount: _toDouble(json['gross_amount']),
        fee: _toDouble(json['fee']),
        toAmount: _toDouble(json['to_amount']),
        exchangeRate: _toDouble(json['exchange_rate']),
      );

  final String fromCurrency;
  final String toCurrency;
  final double fromAmount;
  final double grossAmount;
  final double fee;
  final double toAmount;
  final double exchangeRate;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}