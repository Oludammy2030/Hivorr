import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract base for all repositories and data services.
///
/// Guarantees that business systems never construct [Dio] or call Supabase
/// primitives directly — they extend this class and consume only [dio] and
/// [supabase] through safe accessors. Normalizes any residual [DioException]
/// into a typed [ApiException] so callers always receive a typed error
/// (EP-01-07 §5.6).
abstract class BaseApiService {
  BaseApiService({
    required this.dio,
    required this.supabase,
    required this.exceptionMapper,
  });

  /// The configured API [Dio] instance.
  final Dio dio;

  /// The initialized Supabase client.
  final SupabaseClient supabase;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper exceptionMapper;

  /// Wraps [call] so that any [DioException] is normalized to an
  /// [ApiException]. Already-normalized errors are rethrown as-is.
  Future<T> invoke<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final existing = e.error;
      if (existing is ApiException) {
        throw existing;
      }
      throw exceptionMapper.map(e);
    }
  }
}
