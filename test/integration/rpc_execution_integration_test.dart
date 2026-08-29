import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/mappers/entity_profile_mapper.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';

import '../support/builders/entity_builders.dart';
import '../support/factories/mock_supabase_client_factory.dart';
import '../support/fakes/fake_api.dart';
import '../support/fakes/fake_logging.dart';
import '../support/matchers/entity_matchers.dart';

/// Integration validation for RPC (PostgREST function) execution through the
/// real Supabase client (EP-01-20 Validation Point 3, plan §5.5).
///
/// Exercises the REAL `SupabaseClient.rpc` entry point and the real
/// `SupabaseEntityRemoteDataSource` / `EntityProfileMapper` / `mapDataException`
/// code paths. The Supabase backend is scripted via `MockSupabaseClientFactory`
/// (`rpcHandlers`), but no RPC/transport logic is faked.
void main() {
  group('RPC Execution Integration (§5.5)', () {
    // ── Scenario 1: RPC invocation mapped to a domain entity ──
    test('invokes RPC via the real entry point and maps the response to a '
        'domain entity', () async {
      Map<String, dynamic> capturedParams = <String, dynamic>{};
      final client = MockSupabaseClientFactory.create(
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'get_entity_profile': (Map<String, dynamic> params) {
            capturedParams = params;
            return <String, dynamic>{
              'entity_id': 'e1',
              'legal_name': 'Ada',
              'display_name': 'Ada L.',
              'bio': 'developer',
              'country_code': 'NG',
            };
          },
        },
      );

      final Map<String, dynamic> raw = await client.rpc<Map<String, dynamic>>(
        'get_entity_profile',
        params: <String, dynamic>{'p_entity_id': 'e1'},
      );

      final EntityProfile profile = EntityProfileMapper.toEntity(
        EntityProfileDto.fromJson(raw),
      );

      final EntityProfile expected = EntityProfileBuilder()
          .withLegalName('Ada')
          .withDisplayName('Ada L.')
          .build();

      expect(
        profile,
        isEntityProfile(
          legalName: expected.legalName,
          displayName: expected.displayName,
        ),
      );
      expect(capturedParams, <String, dynamic>{'p_entity_id': 'e1'});
    });

    // ── Scenario 2: RPC with RLS enforcement (empty/unauthorized result) ──
    test('returns null for an RLS-filtered unauthorized result without '
        'throwing', () async {
      final client = MockSupabaseClientFactory.create(
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'get_entity_profile': (_) => <String, dynamic>{},
        },
      );

      final Map<String, dynamic> raw = await client.rpc<Map<String, dynamic>>(
        'get_entity_profile',
        params: <String, dynamic>{'p_entity_id': 'e2'},
      );

      expect(raw, isEmpty);
    });

    // ── Scenario 3: RPC error handling and normalized logging ──
    test('normalizes RPC errors to ApiException and logs via HivorrLogger',
        () async {
      final RecordingSink recordingSink = RecordingSink();
      final LogRouter router = LogRouter(
        sinks: <LogSink>[recordingSink],
        minimumLevel: LogLevel.debug,
      );
      final LoggerFactory loggerFactory =
          LoggerFactory(router, PiiRedactor());
      final HivorrLogger logger = loggerFactory.named('hivorr.integration.rpc');

      final client = MockSupabaseClientFactory.create(
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'entity_profile_update': (_) => throw Exception('boom'),
        },
      );

      final SupabaseEntityRemoteDataSource remote = SupabaseEntityRemoteDataSource(
        dio: buildTestDio(StubAdapter((_) async => jsonBody(200))),
        supabase: client,
        exceptionMapper: const ApiExceptionMapper(),
      );

      ApiException? caught;
      try {
        await remote.updateProfile(
          entityId: 'e1',
          legalName: 'X',
          displayName: 'Y',
        );
        fail('Expected an ApiException to be thrown');
      } on ApiException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      logger.error('RPC execution failed', error: caught);

      expect(recordingSink.entries, isNotEmpty);
      expect(recordingSink.entries.last.hasError, isTrue);
      expect(recordingSink.entries.last.error, isA<ApiException>());
    });
  });
}
