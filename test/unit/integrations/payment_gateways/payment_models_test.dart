import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';

void main() {
  group('Amount', () {
    test('exposes minor units and currency', () {
      const a = Amount(minorUnits: 500000, currency: 'NGN');
      expect(a.minorUnits, 500000);
      expect(a.currency, 'NGN');
    });

    test('isPositive reflects minorUnits sign', () {
      expect(const Amount(minorUnits: 1, currency: 'NGN').isPositive, isTrue);
      expect(const Amount(minorUnits: 0, currency: 'NGN').isPositive, isFalse);
      expect(
        const Amount(minorUnits: -5, currency: 'NGN').isPositive,
        isFalse,
      );
    });

    test('equality compares minorUnits and currency', () {
      const a = Amount(minorUnits: 100, currency: 'NGN');
      const same = Amount(minorUnits: 100, currency: 'NGN');
      const diffUnits = Amount(minorUnits: 200, currency: 'NGN');
      const diffCurrency = Amount(minorUnits: 100, currency: 'GHS');

      expect(a == same, isTrue);
      expect(a == diffUnits, isFalse);
      expect(a == diffCurrency, isFalse);
      final Object nonAmount = 'not-an-amount';
      expect(a == nonAmount, isFalse);
      expect(a.hashCode, same.hashCode);
    });

    test('toString renders minorUnits and currency', () {
      expect(
        const Amount(minorUnits: 100, currency: 'NGN').toString(),
        'Amount(100 NGN)',
      );
    });
  });

  group('model instantiation', () {
    test('webhook event equality and provider fields', () {
      final event = WebhookEvent(
        provider: 'paystack',
        eventType: 'charge.success',
        reference: 'uuid-1',
        status: PaymentStatus.success,
        raw: const <String, dynamic>{'event': 'charge.success'},
      );
      expect(event.provider, 'paystack');
      expect(event.status, PaymentStatus.success);
      expect(event.raw, isNotNull);
    });

    test('name enquiry result carries all fields', () {
      final result = NameEnquiryResult(
        accountNumber: '0123456789',
        accountName: 'ADEOLA OYEKANMI',
        bankCode: '058',
      );
      expect(result.accountNumber, '0123456789');
      expect(result.accountName, 'ADEOLA OYEKANMI');
      expect(result.bankCode, '058');
    });

    test('all provider/status enums expose their values', () {
      expect(PaymentProvider.paystack.name, 'paystack');
      expect(PaymentProvider.flutterwave.name, 'flutterwave');
      expect(PaymentStatus.pending.name, 'pending');
      expect(PaymentStatus.success.name, 'success');
      expect(PaymentStatus.failed.name, 'failed');
      expect(PaymentStatus.abandoned.name, 'abandoned');
      expect(PaymentStatus.reversed.name, 'reversed');
      expect(TransferStatus.pending.name, 'pending');
      expect(TransferStatus.success.name, 'success');
      expect(TransferStatus.failed.name, 'failed');
      expect(TransferStatus.reversed.name, 'reversed');
    });
  });
}
