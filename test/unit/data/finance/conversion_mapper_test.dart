import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/mappers/conversion_mapper.dart';
import 'package:hivorr/data/models/conversion_preview_dto.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';

/// Unit coverage for [ConversionMapper] (EP-02-15 §5.2): pure null-safe field
/// copying between transport DTOs and the domain entities, with no I/O and no
/// business logic (EP-01-08 §5.3). Covers the `fromJson` history-row shape,
/// the `fromRpc` success-envelope shape, defaults (fee → 0, status →
/// pending), null-safe `completed_at`, and the preview mapping.
void main() {
  group('ConversionMapper.conversionToEntity', () {
    test('maps every field including nullable completion stamp', () {
      final DateTime completedAt = DateTime.utc(2026, 1, 1, 1);
      final DateTime createdAt = DateTime.utc(2026, 1, 1);
      final dto = CurrencyConversionDto(
        id: 'conversion-1',
        entityId: 'u1',
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        fromAmount: 50000,
        toAmount: 35,
        exchangeRate: 0.0007,
        fee: 0,
        status: 'completed',
        completedAt: completedAt,
        createdAt: createdAt,
      );

      final CurrencyConversion entity = ConversionMapper.conversionToEntity(dto);

      expect(entity.id, 'conversion-1');
      expect(entity.entityId, 'u1');
      expect(entity.fromCurrency, 'NGN');
      expect(entity.toCurrency, 'USD');
      expect(entity.fromAmount, 50000);
      expect(entity.toAmount, 35);
      expect(entity.exchangeRate, 0.0007);
      expect(entity.fee, 0);
      expect(entity.status, 'completed');
      expect(entity.completedAt, completedAt);
      expect(entity.createdAt, createdAt);
      expect(entity.isCompleted, isTrue);
      expect(entity.isFailed, isFalse);
    });

    test('maps a null completion stamp to null', () {
      final entity = ConversionMapper.conversionToEntity(
        CurrencyConversionDto(
          id: 'conversion-2',
          entityId: 'u1',
          fromCurrency: 'USD',
          toCurrency: 'GHS',
          fromAmount: 10,
          toAmount: 12.8,
          exchangeRate: 1.28,
          fee: 0,
          status: 'pending',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      expect(entity.completedAt, isNull);
      expect(entity.status, 'pending');
      expect(entity.isCompleted, isFalse);
      expect(entity.isFailed, isFalse);
    });

    test('status passthrough: failed maps to isFailed', () {
      final entity = ConversionMapper.conversionToEntity(
        CurrencyConversionDto(
          id: 'conversion-3',
          entityId: 'u1',
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          fromAmount: 50000,
          toAmount: 34,
          exchangeRate: 0.0007,
          fee: 0,
          status: 'failed',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      expect(entity.status, 'failed');
      expect(entity.isFailed, isTrue);
      expect(entity.isCompleted, isFalse);
    });
  });

  group('CurrencyConversionDto.fromJson (history row)', () {
    test('maps a full snake_case financial_conversions row', () {
      final dto = CurrencyConversionDto.fromJson(<String, dynamic>{
        'conversion_id': 'row-1',
        'entity_id': 'u9',
        'from_currency': 'GHS',
        'to_currency': 'NGN',
        'from_amount': '10', // numeric surfaces as string
        'to_amount': 11111.11,
        'exchange_rate': 1111.1111111111111,
        'fee': 0,
        'status': 'completed',
        'completed_at': '2026-02-01T10:00:00.000Z',
        'created_at': '2026-02-01T10:00:00.000Z',
      });

      expect(dto.id, 'row-1');
      expect(dto.entityId, 'u9');
      expect(dto.fromCurrency, 'GHS');
      expect(dto.toCurrency, 'NGN');
      expect(dto.fromAmount, 10);
      expect(dto.toAmount, 11111.11);
      expect(dto.exchangeRate, 1111.1111111111111);
      expect(dto.fee, 0);
      expect(dto.status, 'completed');
      expect(dto.completedAt, isNotNull);
    });

    test('defaults fee to 0, status to pending, and null completed_at to null',
        () {
      final dto = CurrencyConversionDto.fromJson(<String, dynamic>{
        'conversion_id': 'row-2',
        'from_currency': 'USD',
        'to_currency': 'GBP',
        'from_amount': 100,
        'to_amount': 78.74,
        'exchange_rate': 0.7874,
      });

      expect(dto.fee, 0);
      expect(dto.status, 'pending');
      expect(dto.completedAt, isNull);
    });

    test('accepts the id key fallback and stays null-safe on missing fields',
        () {
      final dto = CurrencyConversionDto.fromJson(<String, dynamic>{
        'id': 'row-3',
        'from_amount': 1,
        'to_amount': 0.0007,
      });

      expect(dto.id, 'row-3');
      expect(dto.fromCurrency, '');
      expect(dto.toCurrency, '');
      expect(dto.entityId, '');
    });

    test('falls back to the epoch when created_at is missing (never throws)',
        () {
      final dto = CurrencyConversionDto.fromJson(<String, dynamic>{
        'conversion_id': 'row-4',
      });

      expect(dto.createdAt.millisecondsSinceEpoch, 0);
      expect(dto.id, 'row-4');
    });
  });

  group('CurrencyConversionDto.fromRpc (success envelope)', () {
    test('maps conversion_id + amounts + rate with completed status and fee 0',
        () {
      final dto = CurrencyConversionDto.fromRpc(
        conversionId: 'conversion-rpc-9',
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        fromAmount: 50000,
        toAmount: 35,
        rate: 0.0007,
      );

      expect(dto.id, 'conversion-rpc-9');
      expect(dto.fromCurrency, 'NGN');
      expect(dto.toCurrency, 'USD');
      expect(dto.fromAmount, 50000);
      expect(dto.toAmount, 35);
      expect(dto.exchangeRate, 0.0007);
      expect(dto.fee, 0);
      expect(dto.status, 'completed');
    });

    test('keeps the server timestamp when supplied', () {
      final DateTime stamp = DateTime.utc(2026, 3, 15, 12);
      final dto = CurrencyConversionDto.fromRpc(
        conversionId: 'c',
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        fromAmount: 1,
        toAmount: 0.0007,
        rate: 0.0007,
        timestamp: stamp,
      );

      expect(dto.completedAt, stamp);
      expect(dto.createdAt, stamp);
    });
  });

  group('ConversionMapper.previewToEntity', () {
    test('maps the local estimate fields', () {
      final dto = ConversionPreviewDto(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        fromAmount: 50000,
        grossAmount: 35,
        fee: 0,
        toAmount: 35,
        exchangeRate: 0.0007,
      );

      final ConversionPreview preview = ConversionMapper.previewToEntity(dto);

      expect(preview.fromCurrency, 'NGN');
      expect(preview.toCurrency, 'USD');
      expect(preview.fromAmount, 50000);
      expect(preview.grossAmount, 35);
      expect(preview.fee, 0);
      expect(preview.toAmount, 35);
      expect(preview.exchangeRate, 0.0007);
      expect(preview.isActionable, isTrue);
    });

    test('a non-positive estimate is not actionable', () {
      final preview = ConversionMapper.previewToEntity(
        const ConversionPreviewDto(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          fromAmount: 0,
          grossAmount: 0,
          fee: 0,
          toAmount: 0,
          exchangeRate: 0.0007,
        ),
      );

      expect(preview.isActionable, isFalse);
    });
  });

  group('ConversionPreviewDto.fromJson', () {
    test('maps the serialized preview shape', () {
      final dto = ConversionPreviewDto.fromJson(<String, dynamic>{
        'from_currency': 'NGN',
        'to_currency': 'USD',
        'from_amount': 50000,
        'gross_amount': 35,
        'fee': 0,
        'to_amount': 35,
        'exchange_rate': 0.0007,
      });

      expect(dto.fromCurrency, 'NGN');
      expect(dto.toCurrency, 'USD');
      expect(dto.fromAmount, 50000);
      expect(dto.grossAmount, 35);
      expect(dto.fee, 0);
      expect(dto.toAmount, 35);
      expect(dto.exchangeRate, 0.0007);
    });

    test('defaults missing numeric fields to 0 (never throws)', () {
      final dto = ConversionPreviewDto.fromJson(<String, dynamic>{});

      expect(dto.fromAmount, 0);
      expect(dto.grossAmount, 0);
      expect(dto.toAmount, 0);
      expect(dto.exchangeRate, 0);
      expect(dto.fromCurrency, '');
    });
  });
}