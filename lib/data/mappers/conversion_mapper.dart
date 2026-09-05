import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/models/conversion_preview_dto.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';

/// Transformations between the currency-conversion transport DTOs and the
/// pure-Dart domain entities (EP-02-15 §5.2).
///
/// The single transformation boundary between the RPC/history layer and the
/// domain — no I/O and no business logic, only null-safe field copying
/// (EP-01-08 §5.3).
abstract final class ConversionMapper {
  /// Maps a conversion DTO into a domain [CurrencyConversion].
  static CurrencyConversion conversionToEntity(CurrencyConversionDto dto) =>
      CurrencyConversion(
        id: dto.id,
        entityId: dto.entityId,
        fromCurrency: dto.fromCurrency,
        toCurrency: dto.toCurrency,
        fromAmount: dto.fromAmount,
        toAmount: dto.toAmount,
        exchangeRate: dto.exchangeRate,
        fee: dto.fee,
        status: dto.status,
        completedAt: dto.completedAt,
        createdAt: dto.createdAt,
      );

  /// Maps a preview DTO into a domain [ConversionPreview].
  static ConversionPreview previewToEntity(ConversionPreviewDto dto) =>
      ConversionPreview(
        fromCurrency: dto.fromCurrency,
        toCurrency: dto.toCurrency,
        fromAmount: dto.fromAmount,
        grossAmount: dto.grossAmount,
        fee: dto.fee,
        toAmount: dto.toAmount,
        exchangeRate: dto.exchangeRate,
      );
}