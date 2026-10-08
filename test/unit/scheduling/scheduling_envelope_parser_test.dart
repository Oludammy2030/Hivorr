import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/scheduling_envelope_parser.dart';

void main() {
  group('SchedulingEnvelopeParser.unwrap', () {
    test('returns data on PLT000', () {
      final Map<String, dynamic> data =
          SchedulingEnvelopeParser.unwrap(<String, dynamic>{
            'success': true,
            'code': 'PLT000',
            'message': 'Appointment booked.',
            'data': <String, dynamic>{'id': 'appt-1'},
          });
      expect(data['id'], 'appt-1');
    });

    test('maps PLT001 to auth', () {
      expect(
        () => SchedulingEnvelopeParser.unwrap(<String, dynamic>{
          'success': false,
          'code': 'PLT001',
          'message': 'Authentication required.',
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('maps PLT003 to validation', () {
      expect(
        () => SchedulingEnvelopeParser.unwrap(<String, dynamic>{
          'success': false,
          'code': 'PLT003',
          'message': 'Start time must be in the future.',
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('maps PLT004 to notFound with server message', () {
      expect(
        () => SchedulingEnvelopeParser.unwrap(<String, dynamic>{
          'success': false,
          'code': 'PLT004',
          'message': 'Contract not found.',
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.notFound)
              .having((e) => e.message, 'message', 'Contract not found.'),
        ),
      );
    });

    test('maps PLT005 to conflict with Slot taken fallback', () {
      try {
        SchedulingEnvelopeParser.unwrap(<String, dynamic>{
          'success': false,
          'code': 'PLT005',
          'message': '',
        });
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.kind, ApiExceptionKind.conflict);
        expect(e.message, 'Slot taken. Pick another time.');
      }
    });

    test('malformed envelope without object data throws server', () {
      expect(
        () => SchedulingEnvelopeParser.unwrap(<String, dynamic>{
          'success': true,
          'code': 'PLT000',
          'message': 'ok',
          'data': <String>['not-an-object'],
        }),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });
  });
}
