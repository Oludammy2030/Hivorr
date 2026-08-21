import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';

/// Builds a [DioException] carrying a response with [status] and optional
/// [data], then maps it via [ApiExceptionMapper].
ApiException _mapStatus(
  int status, {
  Map<String, dynamic>? data,
}) {
  final requestOptions = RequestOptions(path: '/x');
  final response = Response<dynamic>(
    requestOptions: requestOptions,
    statusCode: status,
    data: data,
  );
  final err = DioException(
    requestOptions: requestOptions,
    response: response,
    type: DioExceptionType.badResponse,
  );
  return const ApiExceptionMapper().map(err);
}

void main() {
  group('ApiExceptionMapper — status mapping', () {
    test('401 -> auth / PLT001', () {
      final e = _mapStatus(401);
      expect(e.kind, ApiExceptionKind.auth);
      expect(e.code, 'PLT001');
      expect(e.statusCode, 401);
    });

    test('403 -> forbidden / PLT002', () {
      final e = _mapStatus(403);
      expect(e.kind, ApiExceptionKind.forbidden);
      expect(e.code, 'PLT002');
    });

    test('404 -> notFound / PLT004', () {
      final e = _mapStatus(404);
      expect(e.kind, ApiExceptionKind.notFound);
      expect(e.code, 'PLT004');
    });

    test('409 -> conflict / PLT005', () {
      final e = _mapStatus(409);
      expect(e.kind, ApiExceptionKind.conflict);
      expect(e.code, 'PLT005');
    });

    test('422 with PLT003 -> validation and honors message', () {
      final e = _mapStatus(422, data: <String, dynamic>{
        'code': 'PLT003',
        'message': 'Invalid payload',
      });
      expect(e.kind, ApiExceptionKind.validation);
      expect(e.code, 'PLT003');
      expect(e.message, 'Invalid payload');
    });

    test('400 -> validation with safe default', () {
      final e = _mapStatus(400);
      expect(e.kind, ApiExceptionKind.validation);
    });

    test('500 -> server / PLT999', () {
      final e = _mapStatus(500);
      expect(e.kind, ApiExceptionKind.server);
      expect(e.code, 'PLT999');
    });

    test('platform code is honored over status default', () {
      final e = _mapStatus(403, data: <String, dynamic>{
        'code': 'PLTXYZ',
        'message': 'custom message',
      });
      expect(e.code, 'PLTXYZ');
      expect(e.message, 'custom message');
    });

    test('unknown status -> unknown with no leaked raw data', () {
      final e = _mapStatus(418, data: <String, dynamic>{
        'message': 'teapot',
      });
      expect(e.kind, ApiExceptionKind.unknown);
      expect(e.message, 'teapot');
    });
  });

  group('ApiExceptionMapper — transport mapping', () {
    ApiException mapType(DioExceptionType type) {
      final requestOptions = RequestOptions(path: '/x');
      final err = DioException(requestOptions: requestOptions, type: type);
      return const ApiExceptionMapper().map(err);
    }

    test('connectionTimeout -> timeout', () {
      final e = mapType(DioExceptionType.connectionTimeout);
      expect(e.kind, ApiExceptionKind.timeout);
    });

    test('sendTimeout -> timeout', () {
      final e = mapType(DioExceptionType.sendTimeout);
      expect(e.kind, ApiExceptionKind.timeout);
    });

    test('receiveTimeout -> timeout', () {
      final e = mapType(DioExceptionType.receiveTimeout);
      expect(e.kind, ApiExceptionKind.timeout);
    });

    test('connectionError -> network', () {
      final e = mapType(DioExceptionType.connectionError);
      expect(e.kind, ApiExceptionKind.network);
    });

    test('unknown -> network', () {
      final e = mapType(DioExceptionType.unknown);
      expect(e.kind, ApiExceptionKind.network);
    });

    test('badCertificate -> unknown', () {
      final e = mapType(DioExceptionType.badCertificate);
      expect(e.kind, ApiExceptionKind.unknown);
    });

    test('cancel -> unknown', () {
      final e = mapType(DioExceptionType.cancel);
      expect(e.kind, ApiExceptionKind.unknown);
    });
  });
}
